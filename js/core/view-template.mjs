import { readLiteral } from './literal.mjs';

// This is analysis of authenticated Core, not a second evaluator. It discovers
// only structure guaranteed by ordinary lexical bindings and raw-seal calls.
// Unknown subtrees use ordinary rendering inside the fixed layout. Analysis
// limits leave the ordinary view in place. Direct hole evaluation is a
// separate strict specialization; this shape proof alone never skips work.
export const UNKNOWN = Object.freeze({ kind: 'unknown' });
// References belong to lexical bindings, not to an expression's abstract
// result. Closure snapshots retain them for the direct-hole specialization.
export const boundValue = (value, reference) => ({ kind: 'bound', reference, value });
const LIMIT = 2000;
const NODES = 128;
const exhausted = Symbol('template analysis limit');

function bind(environment, name, value) {
  return new Map([...environment, [name, value]]);
}

function evaluate(node, environment, remaining) {
  if (--remaining.nodes < 0) throw exhausted;
  switch (node.type) {
    case 'literal':
      return { kind: 'atom', value: readLiteral(node.text).value };
    case 'name':
      return unbound(environment.get(node.name) ?? UNKNOWN);
    case 'native':
      return { kind: 'native', name: node.name };
    case 'cons':
      return {
        kind: 'cell',
        head: evaluate(node.head, environment, remaining),
        tail: evaluate(node.tail, environment, remaining),
      };
    case 'slot': {
      let value = evaluate(node.value, environment, remaining);
      const axis = BigInt(node.axis);
      // Bound analysis even for Core's arbitrary-precision projection axes;
      // the ordinary slot expression retains its full runtime semantics.
      if (axis < 1n || axis > BigInt(Number.MAX_SAFE_INTEGER)) return UNKNOWN;
      for (const step of axis.toString(2).slice(1)) {
        if (value.kind !== 'cell') return UNKNOWN;
        value = step === '0' ? value.head : value.tail;
      }
      return value;
    }
    case 'let': {
      const value = evaluate(node.value, environment, remaining);
      return evaluate(node.body, bind(environment, node.name, value), remaining);
    }
    case 'lam':
      return { kind: 'closure', node, environment };
    case 'app': {
      const fn = evaluate(node.fn, environment, remaining);
      const sample = evaluate(node.argument, environment, remaining);
      if (fn.kind === 'closure') {
        return evaluate(fn.node.body, bind(fn.environment, fn.node.parameter, sample), remaining);
      }
      if (fn.kind === 'native' && fn.name === 'raw-seal') return { kind: 'seal', value: sample };
      return UNKNOWN;
    }
    case 'if': {
      const condition = evaluate(node.condition, environment, remaining);
      if (condition.kind !== 'atom' || condition.value > 1n) return UNKNOWN;
      return evaluate(condition.value === 0n ? node.then : node.else, environment, remaining);
    }
    default:
      return UNKNOWN;
  }
}

function unbound(value) {
  while (value.kind === 'bound') value = value.value;
  return value;
}

/** An immutable abstract value for one lexical binding. */
export function abstractValue(node, environment = new Map()) {
  try {
    return evaluate(node, environment, { nodes: LIMIT });
  } catch (error) {
    if (error !== exhausted) throw error;
    return UNKNOWN;
  }
}

// Non-ASCII literals remain holes so the ordinary text decoder determines
// their Unicode value or error, exactly as it does for a dynamic text value.
function ascii(value) {
  if (value.kind !== 'atom') return undefined;
  let atom = value.value;
  let result = '';
  while (atom !== 0n) {
    const byte = Number(atom & 255n);
    if (byte < 32 || byte > 126) return undefined;
    result += String.fromCharCode(byte);
    atom >>= 8n;
  }
  return result;
}

// Attribute nouns must be constant, not merely known cells with unknown leaves.
// Their decoder still runs at mount, preserving its validation and errors.
function constant(value, remaining = { nodes: NODES }) {
  if (--remaining.nodes < 0) throw exhausted;
  return value.kind === 'atom' || (value.kind === 'cell'
    && constant(value.head, remaining) && constant(value.tail, remaining));
}

// Discover a fixed child count before recording any descendant hole axes.
function properList(value) {
  let left = NODES;
  while (value.kind === 'cell') {
    if (--left < 0) throw exhausted;
    value = value.tail;
  }
  return value.kind === 'atom' && value.value === 0n;
}

/** Static DOM structure with text and element holes in the returned noun. */
export function viewTemplate(node, environment = new Map(), sample = UNKNOWN) {
  try {
    return valueTemplate(evaluate(node.body, bind(environment, node.parameter, sample), { nodes: LIMIT }));
  } catch (error) {
    if (error !== exhausted) throw error;
    return undefined;
  }
}

/** A template for an already analyzed value, with independent shape bounds. */
export function valueTemplate(value) {
  const axes = [];
  let count = NODES;
  const point = axis => {
    if (!Number.isSafeInteger(axis) || --count < 0) throw exhausted;
  };
  const words = (value, axis) => {
    point(axis);
    const text = ascii(value);
    if (text !== undefined) return text;
    axes.push(axis);
    return axes.length - 1;
  };
  const children = (value, axis) => {
    const result = [];
    while (value.kind === 'cell') {
      result.push(element(value.head, axis * 2));
      value = value.tail;
      axis = axis * 2 + 1;
    }
    if (value.kind !== 'atom' || value.value !== 0n) throw exhausted;
    return result;
  };
  const childHole = axis => {
    axes.push(axis);
    // Nonnegative indices are text holes; -1-index denotes an element hole.
    return -axes.length;
  };
  const element = (value, axis) => {
    point(axis);
    if (value.kind !== 'seal' || value.value.kind !== 'cell') return childHole(axis);
    const tag = ascii(value.value.head);
    const payload = value.value.tail;
    // A seal is [seal-tag raw]; raw is [tag payload].
    const at = axis * 4 + 3;
    switch (tag) {
      case 'text':
        return words(payload, at);
      case 'heading': {
        if (payload.kind !== 'cell' || payload.head.kind !== 'atom') return childHole(axis);
        const level = payload.head.value;
        const tag = `h${level < 1n ? 1 : level > 6n ? 6 : Number(level)}`;
        return [tag, { tabIndex: '-1' }, [words(payload.tail, at * 2 + 1)]];
      }
      case 'row':
      case 'column':
      case 'wrap':
      case 'stack':
      case 'el': {
        if (payload.kind !== 'cell' || !constant(payload.head)
          || (tag !== 'el' && !properList(payload.tail))) {
          return childHole(axis);
        }
        const empty = payload.head.kind === 'atom' && payload.head.value === 0n;
        if (!empty) point(at * 2);
        const kids = tag === 'el'
          ? [element(payload.tail, at * 2 + 1)]
          : children(payload.tail, at * 2 + 1);
        // Numeric attrs select a proven constant noun, decoded once by the
        // ordinary attribute decoder. The descriptor tag names its layout.
        return empty ? ['div', { class: `j-${tag}` }, kids] : [tag, at * 2, kids];
      }
      case 'para':
        if (!properList(payload)) return childHole(axis);
        return ['p', {}, children(payload, at)];
      default:
        return childHole(axis);
    }
  };

  try {
    const tree = element(value, 1);
    // Wrapping an entirely dynamic view would only repeat ordinary rendering.
    return typeof tree === 'number' && tree < 0 ? undefined : { tree, axes };
  } catch (error) {
    if (error !== exhausted) throw error;
    return undefined;
  }
}
