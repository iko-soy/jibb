import { readLiteral } from '../core/literal.mjs';

// runNock uses this non-enumerable metadata to add the explicit native-gate
// environment expected by formulas emitted below. The formula itself remains
// an ordinary two-element Nock noun.
export const NOCK_NATIVES = Symbol('jibb.nock.natives');

const ZERO = 0n;
const ONE = 1n;
const SLOG = readLiteral('%slog').value;
const LEAF = readLiteral('%leaf').value;

function fail(message) {
  throw new Error(`Nock emitter: ${message}`);
}

function cell(head, tail) {
  return [head, tail];
}

function slot(axis) {
  return [ZERO, axis];
}

function literal(value) {
  return [ONE, value];
}

// Put a subject formerly at axis 1 at parentAxis, preserving all of its axes.
function nestAxis(parentAxis, axis) {
  return BigInt(`0b${parentAxis.toString(2)}${axis.toString(2).slice(1)}`);
}

function shiftEntries(entries, parentAxis) {
  return new Map([...entries].map(([name, entry]) => [
    name,
    { ...entry, axis: nestAxis(parentAxis, entry.axis) },
  ]));
}

function environment(context) {
  return { lexical: new Map(), natives: context.initialNatives };
}

function nativeAxes(names) {
  const axes = new Map();
  // The registry is a nil-terminated list at axis 2 of the wrapped subject.
  let listCell = ONE;
  for (const name of names) {
    axes.set(name, { kind: 'axis', axis: nestAxis(2n, nestAxis(listCell, 2n)) });
    listCell = nestAxis(listCell, 3n);
  }
  return axes;
}

function declaredNatives(nativeNames) {
  if (nativeNames === undefined) return [];
  if (!Array.isArray(nativeNames) && !(nativeNames instanceof Set)) {
    throw new TypeError('Nock emitter: nativeNames must be a Set or an array');
  }
  const names = [...nativeNames];
  if (names.some(name => typeof name !== 'string')) {
    throw new TypeError('Nock emitter: native names must be strings');
  }
  return new Set(names);
}

function collectNatives(node, declared, required) {
  const pending = [node];
  while (pending.length !== 0) {
    const current = pending.pop();
    if (current.type === 'native') {
      if (!declared.has(current.name)) fail(`unknown native ${current.name}`);
      required.add(current.name);
      continue;
    }
    switch (current.type) {
      case 'literal':
      case 'name':
      case 'crash':
        break;
      case 'cons':
        pending.push(current.head, current.tail);
        break;
      case 'slot':
      case 'cell':
        pending.push(current.value);
        break;
      case 'edit':
        pending.push(current.target, current.value);
        break;
      case 'eq':
        pending.push(current.left, current.right);
        break;
      case 'if':
        pending.push(current.condition, current.then, current.else);
        break;
      case 'let':
        pending.push(current.value, current.body);
        break;
      case 'rec':
        for (const binding of current.bindings) pending.push(binding.lambda);
        pending.push(current.body);
        break;
      case 'lam':
        pending.push(current.body);
        break;
      case 'app':
        pending.push(current.fn, current.argument);
        break;
      case 'trace':
        pending.push(current.message, current.body);
        break;
      default:
        fail(`unsupported Core node ${current.type}`);
    }
  }
}

function lookup(entries, name, kind) {
  const entry = entries.get(name);
  if (entry === undefined) fail(`unbound Core ${kind} ${name}`);
  return entry;
}

function variable(entry) {
  if (entry.kind === 'axis') return slot(entry.axis);
  // A recursive name evaluates its arm in the captured rec core, producing a
  // gate. The application rule then invokes that gate like any other.
  return [9n, [entry.arm, slot(entry.axis)]];
}

function define(entries, name, entry) {
  if (entries.has(name)) fail(`duplicate binding ${name}`);
  entries.set(name, entry);
}

function withBinding(env, name, entry, parentAxis) {
  const lexical = shiftEntries(env.lexical, parentAxis);
  define(lexical, name, entry);
  return { lexical, natives: shiftEntries(env.natives, parentAxis) };
}

function shifted(env, parentAxis) {
  return {
    lexical: shiftEntries(env.lexical, parentAxis),
    natives: shiftEntries(env.natives, parentAxis),
  };
}

function recursiveEnvironment(env, bindings, coreAxis, outerAxis, parameter = null) {
  const inner = {
    lexical: shiftEntries(env.lexical, outerAxis),
    natives: shiftEntries(env.natives, outerAxis),
  };
  const axes = armAxes(bindings.length);
  for (let index = 0; index < bindings.length; index += 1) {
    define(inner.lexical, bindings[index].name, {
      kind: 'arm',
      arm: axes[index],
      axis: coreAxis,
    });
  }
  if (parameter !== null) define(inner.lexical, parameter, { kind: 'axis', axis: 6n });
  return inner;
}

// A one-arm battery is the formula itself. Larger batteries are right-nested
// pairs of arm formulas, with no trailing atom.
function armAxes(count) {
  const axes = [];
  let remaining = 2n; // battery's axis in its core
  for (let index = 0; index < count; index += 1) {
    if (index === count - 1) {
      axes.push(remaining);
    } else {
      axes.push(nestAxis(remaining, 2n));
      remaining = nestAxis(remaining, 3n);
    }
  }
  return axes;
}

function battery(armFormulas) {
  if (armFormulas.length === 1) return armFormulas[0];
  let result = armFormulas[armFormulas.length - 1];
  for (let index = armFormulas.length - 2; index >= 0; index -= 1) {
    result = cell(armFormulas[index], result);
  }
  return result;
}

function gateFormula(bodyFormula, contextFormula) {
  // [body [0 context]]: battery at 2, sample at 6, closure at 7.
  return cell(literal(bodyFormula), cell(literal(ZERO), contextFormula));
}

function expression(node, env) {
  switch (node.type) {
    case 'literal':
      return literal(readLiteral(node.text).value);
    case 'name':
      return variable(lookup(env.lexical, node.name, 'name'));
    case 'cons':
      // Nock autocons: a formula whose head is itself a formula.
      return cell(expression(node.head, env), expression(node.tail, env));
    case 'slot':
      return [7n, [expression(node.value, env), slot(node.axis)]];
    case 'edit':
      return [10n, [[node.axis, expression(node.value, env)], expression(node.target, env)]];
    case 'cell':
      return [3n, expression(node.value, env)];
    case 'eq':
      return [5n, [expression(node.left, env), expression(node.right, env)]];
    case 'if':
      return [6n, [expression(node.condition, env), [
        expression(node.then, env),
        expression(node.else, env),
      ]]];
    case 'let': {
      const inner = withBinding(env, node.name, { kind: 'axis', axis: 2n }, 3n);
      return [8n, [expression(node.value, env), expression(node.body, inner)]];
    }
    case 'rec': {
      if (node.bindings.length === 0) return expression(node.body, env);
      for (const binding of node.bindings) {
        if (binding.lambda.type !== 'lam') fail(`recursive binding ${binding.name} is not a lambda`);
      }

      // Each arm runs with rec core C as its subject and constructs a gate
      // [body [0 C]]. The outer subject is C's payload at axis 3. Within a
      // recursive gate C is at 7, so the outer subject is at 15.
      const armFormulas = node.bindings.map(binding => {
        const inner = recursiveEnvironment(
          env,
          node.bindings,
          7n,
          15n,
          binding.lambda.parameter,
        );
        const body = expression(binding.lambda.body, inner);
        return gateFormula(body, slot(ONE));
      });
      const core = cell(literal(battery(armFormulas)), slot(ONE));

      // Evaluate the rec body with [C old-subject] as its subject.
      const inner = recursiveEnvironment(env, node.bindings, 2n, 3n);
      return [8n, [core, expression(node.body, inner)]];
    }
    case 'lam': {
      const inner = shifted(env, 7n);
      define(inner.lexical, node.parameter, { kind: 'axis', axis: 6n });
      return gateFormula(expression(node.body, inner), slot(ONE));
    }
    case 'app':
      return [9n, [2n, [10n, [[6n, expression(node.argument, env)], expression(node.fn, env)]]]];
    case 'native':
      return variable(lookup(env.natives, node.name, 'native'));
    case 'crash':
      return slot(ZERO);
    case 'trace': {
      // %slog's dynamic clue evaluates to [0 [%leaf message]].
      const clue = cell(literal(ZERO), cell(literal(LEAF), expression(node.message, env)));
      return [11n, [[SLOG, clue], expression(node.body, env)]];
    }
    default:
      fail(`unsupported Core node ${node.type}`);
  }
}

/** Emit a Core expression as a standard Nock formula using BigInt atoms. */
export function emitCore(ast, { nativeNames } = {}) {
  const declared = declaredNatives(nativeNames);
  const required = new Set();
  collectNatives(ast, declared, required);
  const names = [...required].sort();
  const context = { initialNatives: nativeAxes(names) };
  const formula = expression(ast, environment(context));
  Object.defineProperty(formula, NOCK_NATIVES, {
    value: Object.freeze(names),
    enumerable: false,
  });
  return formula;
}
