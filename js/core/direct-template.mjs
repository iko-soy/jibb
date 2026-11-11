import { readLiteral } from './literal.mjs';
import { freeNames } from './free-names.mjs';
import { UNKNOWN, abstractValue, valueTemplate } from './view-template.mjs';

// A bounded, strict specialization of a view. Known cells and seals stay
// virtual until an ordinary operation needs them. Every opaque computation
// still runs once, in source order, including work whose result is discarded.
// This private evaluator is used only by the trusted browser template path;
// the ordinary Core gate and its noun ABI remain unchanged.
const unsupported = Symbol('direct template unavailable');
const LIMIT = 2000;
const MAX_AXIS = BigInt(Number.MAX_SAFE_INTEGER);

class Environment {
  constructor(parent = null, values = new Map(), captured = null) {
    this.parent = parent;
    this.values = values;
    this.captured = captured;
  }

  get(name) {
    if (this.values.has(name)) return this.values.get(name);
    if (this.captured?.has(name)) {
      const value = imported(this.captured.get(name));
      this.values.set(name, value);
      return value;
    }
    if (this.parent) return this.parent.get(name);
    throw unsupported;
  }

  bind(name, value) {
    return new Environment(this, new Map([[name, value]]));
  }
}

const atom = value => ({ kind: 'atom', value, code: `BigInt(${JSON.stringify(value.toString())})` });
const actual = code => ({ kind: 'actual', code });
const native = (name, code = `natives[${JSON.stringify(name)}]`) => ({ kind: 'native', name, code });

function imported(value, code) {
  if (value.kind === 'bound') return imported(value.value, value.reference);
  switch (value.kind) {
    case 'atom': return { ...atom(value.value), ...(code === undefined ? {} : { code }) };
    case 'native': return native(value.name, code);
    case 'closure': return {
      kind: 'closure', node: value.node, shared: true,
      environment: new Environment(null, new Map(), value.environment), code,
      abstractEnvironment: value.environment,
    };
    default:
      if (code !== undefined) return actual(code);
      throw unsupported;
  }
}

function tick(state) {
  if (state.budget.left === 0) throw unsupported;
  state.budget.left--;
}

function fresh(state) {
  return `$v${state.budget.next++}`;
}

function emit(code, state) {
  state.budget.work++;
  const variable = fresh(state);
  state.lines.push(`const ${variable} = ${code};`);
  return actual(variable);
}

function nested(state, budget = state.budget) {
  return { budget, lines: [], cache: new Map(state.cache) };
}

function body(state, result) {
  return `${state.lines.join('\n')}\nreturn ${result};\n`;
}

function force(value, state) {
  tick(state);
  if (value.code !== undefined) return value.code;
  if (state.cache.has(value)) return state.cache.get(value);
  let code;
  if (value.origin !== undefined) {
    // A wholly needed pure wrapper can use its original gate's memo cache.
    // Its strict checks already ran at the call site; its sample is shared.
    code = `apply(${value.origin.code}, ${force(value.origin.sample, state)})`;
  } else switch (value.kind) {
    case 'cell': {
      const head = force(value.head, state);
      const tail = force(value.tail, state);
      code = `cons(${head}, ${tail})`;
      break;
    }
    case 'seal':
      code = `apply(natives["raw-seal"], ${force(value.value, state)})`;
      break;
    case 'closure': {
      // Reuse the ordinary emitter's lazy slot, including at first mount.
      // Recreating a closed callback would invalidate downstream memo samples.
      const source = JSON.stringify(value.node, (_key, item) =>
        typeof item === 'bigint' ? item.toString() : item);
      const sites = state.budget.sites.filter(site => JSON.stringify(site.node, (_key, item) =>
        typeof item === 'bigint' ? item.toString() : item) === source);
      if (sites.length !== 0) {
        const matching = sites.filter(site => [...site.references].every(([name, reference]) =>
          value.environment.get(name).code === reference));
        // Identical syntax at different lexical sites cannot pick a slot by
        // spelling. An unavailable or ambiguous capture keeps ordinary view
        // evaluation, instead of rebuilding callbacks on every update.
        if (matching.length !== 1) throw unsupported;
        return matching[0].code;
      }
      // Allocate captured cells once, at closure creation, so repeated calls
      // share their original values. Only actual free names are imported.
      const captures = new Map();
      for (const name of [...freeNames(value.node, new Set(), new Set())].sort()) {
        const captured = value.environment.get(name);
        const reference = force(captured, state);
        captures.set(name, captured.kind === 'atom'
          ? { ...captured, code: reference } : actual(reference));
      }
      const parameter = fresh(state);
      const inner = nested(state);
      const result = evaluate(value.node.body,
        new Environment(null, captures).bind(value.node.parameter, actual(parameter)), inner);
      const returned = force(result, inner);
      code = `((${parameter}) => {\n${body(inner, returned)}})`;
      break;
    }
    default: throw unsupported;
  }
  const made = emit(code, state).code;
  state.cache.set(value, made);
  return made;
}

function check(value, operation, state) {
  // A seal's payload is unchecked: raw-seal itself accepts any JS value.
  // Its wrapper is shallow-valid only when that payload is a valid part.
  if (value.kind === 'actual'
    || (value.kind === 'seal' && value.value.kind === 'actual')) {
    state.lines.push(`checkValue(${force(value, state)}, ${JSON.stringify(operation)});`);
  }
}

function project(value, axis, state) {
  const original = value;
  if (axis >= 1n && axis <= MAX_AXIS) {
    let known = true;
    for (const direction of axis.toString(2).slice(1)) {
      tick(state);
      if (value.kind === 'cell') value = direction === '0' ? value.head : value.tail;
      else if (value.kind === 'seal' && direction === '1') value = value.value;
      else { known = false; break; }
    }
    // Unknown roots still need slot's validation, including at axis 1.
    if (known && original.kind !== 'actual'
      && original.kind !== 'closure' && original.kind !== 'native'
      && !(original.kind === 'seal' && original.value.kind === 'actual')) return value;
  }
  return emit(`slot(${axis}n, ${force(original, state)})`, state);
}

function renderBranch(node, environment, state) {
  const value = evaluate(node, environment, state);
  const result = force(value, state);
  return `(() => {\n${body(state, result)}})()`;
}

function branch(node, environment, state) {
  const serial = state.budget.serial;
  const probeBudget = { ...state.budget };
  const probe = nested(state, probeBudget);
  renderBranch(node, environment, probe);
  state.budget.left = probeBudget.left;
  const shared = [...probe.cache.keys()].filter(value => !state.cache.has(value)
    && (value.shared || value.id === undefined || value.id < serial));
  for (const value of shared) force(value, state);
  return renderBranch(node, environment, nested(state));
}

function shape(value, state) {
  tick(state);
  switch (value.kind) {
    case 'atom': return { kind: 'atom', value: value.value };
    case 'native': return { kind: 'native', name: value.name };
    case 'cell': return { kind: 'cell', head: shape(value.head, state), tail: shape(value.tail, state) };
    case 'seal': return { kind: 'seal', value: shape(value.value, state) };
    case 'actual': return value.known ?? UNKNOWN;
    default: return UNKNOWN;
  }
}

function evaluate(node, environment, state) {
  tick(state);
  switch (node.type) {
    case 'literal': return atom(readLiteral(node.text).value);
    case 'name': return environment.get(node.name);
    case 'native': return native(node.name);
    case 'cons': {
      const head = evaluate(node.head, environment, state);
      const tail = evaluate(node.tail, environment, state);
      check(head, 'cons head', state);
      check(tail, 'cons tail', state);
      return { kind: 'cell', id: state.budget.serial++, head, tail };
    }
    case 'slot': return project(evaluate(node.value, environment, state), BigInt(node.axis), state);
    case 'let': {
      const value = evaluate(node.value, environment, state);
      return evaluate(node.body, environment.bind(node.name, value), state);
    }
    case 'lam': return { kind: 'closure', id: state.budget.serial++, node, environment };
    case 'app': {
      const fn = evaluate(node.fn, environment, state);
      const sample = evaluate(node.argument, environment, state);
      if (fn.kind === 'closure') {
        // Opaque results already need ordinary nouns. Keep their original
        // calls and memo caches, including validation inside keyed renderers.
        // Only a proven fixed view shape justifies specializing a bound gate.
        if (fn.code !== undefined) {
          const argument = shape(sample, state);
          const known = abstractValue(fn.node.body,
            new Map([...fn.abstractEnvironment, [fn.node.parameter, argument]]));
          if (valueTemplate(known) === undefined) {
            // Retain source-proven shape for later calls (for example a
            // constant attribute produced by an ordinary helper).
            return { ...emit(`apply(${fn.code}, ${force(sample, state)})`, state), known };
          }
        }
        const { work, serial } = state.budget;
        const result = evaluate(fn.node.body, fn.environment.bind(fn.node.parameter, sample), state);
        // Keep original memoization for opaque element holes, while allowing
        // projections to remove fixed wrappers. Identity/projection returns
        // predate this call and must never acquire an origin pointing to self.
        if (fn.code !== undefined && state.budget.work === work
          && (result.kind === 'cell' || result.kind === 'seal') && result.id >= serial) {
          result.origin = { code: fn.code, sample };
        }
        return result;
      }
      if (fn.kind === 'native' && fn.name === 'raw-seal') {
        return { kind: 'seal', id: state.budget.serial++, value: sample };
      }
      const target = force(fn, state);
      const argument = force(sample, state);
      return emit(`apply(${target}, ${argument})`, state);
    }
    case 'if': {
      const condition = evaluate(node.condition, environment, state);
      if (condition.kind === 'atom' && condition.value <= 1n) {
        return evaluate(condition.value === 0n ? node.then : node.else, environment, state);
      }
      const test = force(condition, state);
      const yes = branch(node.then, environment, state);
      const no = branch(node.else, environment, state);
      return emit(`(requireLoobean(${test}) ? ${yes} : ${no})`, state);
    }
    case 'edit': {
      const target = evaluate(node.target, environment, state);
      const value = evaluate(node.value, environment, state);
      const left = force(target, state);
      const right = force(value, state);
      return emit(`edit(${node.axis}n, ${left}, ${right})`, state);
    }
    case 'cell': return emit(`isCell(${force(evaluate(node.value, environment, state), state)})`, state);
    case 'eq': {
      const left = evaluate(node.left, environment, state);
      const right = evaluate(node.right, environment, state);
      const first = force(left, state);
      const second = force(right, state);
      return emit(`same(${first}, ${second})`, state);
    }
    case 'trace': {
      const message = force(evaluate(node.message, environment, state), state);
      state.budget.work++;
      state.lines.push(`traceLazy(${message}, () => 0n);`);
      return evaluate(node.body, environment, state);
    }
    case 'crash': return emit('crash("explicit Core crash")', state);
    default: throw unsupported;
  }
}

/** Optional private JS evaluator returning the original plan's hole vector. */
export function directHoles(node, environment, axes, sites = []) {
  const state = { budget: { left: LIMIT, next: 0, serial: 0, work: 0, sites }, lines: [], cache: new Map() };
  try {
    const captured = new Environment(null, new Map(), environment);
    const result = evaluate(node.body, captured.bind(node.parameter, actual('$model')), state);
    const holes = axes.map(axis => force(project(result, BigInt(axis), state), state));
    return `(($model) => {\n${body(state, `[${holes.join(', ')}]`)}})`;
  } catch (error) {
    if (error !== unsupported) throw error;
    return undefined;
  }
}
