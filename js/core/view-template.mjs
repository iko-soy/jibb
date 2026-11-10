import { readLiteral } from './literal.mjs';

// This is analysis of authenticated Core, not a second evaluator. It discovers
// only structure guaranteed by ordinary lexical bindings and raw-seal calls.
// Unknown operations, recursive names and analysis limits leave the ordinary
// view in place. The emitted gate still runs, including every crash and trace.
export const UNKNOWN = Object.freeze({ kind: 'unknown' });
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
      return environment.get(node.name) ?? UNKNOWN;
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

/** Static DOM structure and text-hole noun axes for an ordinary gate. */
export function viewTemplate(node, environment = new Map()) {
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
  const element = (value, axis) => {
    point(axis);
    if (value.kind !== 'seal' || value.value.kind !== 'cell') throw exhausted;
    const tag = ascii(value.value.head);
    const payload = value.value.tail;
    // A seal is [seal-tag raw]; raw is [tag payload].
    const at = axis * 4 + 3;
    switch (tag) {
      case 'text':
        return words(payload, at);
      case 'heading': {
        if (payload.kind !== 'cell' || payload.head.kind !== 'atom') throw exhausted;
        const level = payload.head.value;
        const tag = `h${level < 1n ? 1 : level > 6n ? 6 : Number(level)}`;
        return [tag, { tabIndex: '-1' }, [words(payload.tail, at * 2 + 1)]];
      }
      case 'row':
      case 'column':
      case 'wrap':
      case 'stack':
      case 'el': {
        if (payload.kind !== 'cell' || payload.head.kind !== 'atom' || payload.head.value !== 0n) {
          throw exhausted;
        }
        return ['div', { class: `j-${tag}` }, tag === 'el'
          ? [element(payload.tail, at * 2 + 1)]
          : children(payload.tail, at * 2 + 1)];
      }
      case 'para':
        return ['p', {}, children(payload, at)];
      default:
        throw exhausted;
    }
  };

  try {
    const value = evaluate(node.body, bind(environment, node.parameter, UNKNOWN), { nodes: LIMIT });
    return { tree: element(value, 1), axes };
  } catch (error) {
    if (error !== exhausted) throw error;
    return undefined;
  }
}
