import { readCore } from './reader.mjs';
import { readLiteral } from './literal.mjs';

export function compileCore(input, { nativeNames = [] } = {}) {
  const ast = typeof input === 'string'
    ? readCore(input, { nativeNames })
    : input;
  const natives = new Set(nativeNames);
  const requiredNatives = new Set();
  const context = {
    natives,
    requiredNatives,
    scopes: [],
    nextVariable: 0,
    // A program with a trace remembers no products, so every trace prints.
    memoize: !containsTrace(ast),
    hoisted: [],
  };
  let body;
  if (ast.type === 'module') {
    const names = new Scope(context, null);
    context.scopes.push(names);
    const declarations = ast.definitions.map((definition) => {
      const variable = names.define(definition.name);
      return { definition, variable };
    });
    const statements = declarations.map(({ definition, variable }) =>
      `const ${variable} = ${expression(definition.expression, context, names)};`
    );
    const entries = declarations.map(({ definition, variable }) =>
      `${JSON.stringify(definition.name)}: ${variable}`
    );
    body = `${statements.join('\n')}\nreturn {${entries.join(', ')}};`;
    context.scopes.pop();
  } else {
    body = `return ${expression(ast, context, null)};`;
  }
  const nativeChecks = [...requiredNatives].sort().map((name) =>
    `requireNative(natives, ${JSON.stringify(name)});`
  );
  const slots = context.hoisted.length === 0 ? '' : `let ${context.hoisted.join(', ')};\n`;
  return `// Generated from Jibb Core. Do not edit.\nexport function evaluate(runtime, natives) {\nconst {apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy, memo} = runtime;\nconst requireNative = (registry, name) => {\n  if (registry === null || typeof registry !== 'object' || !Object.hasOwn(registry, name) || typeof registry[name] !== 'function') {\n    throw new TypeError(\`missing native \${name}\`);\n  }\n};\n${nativeChecks.join('\n')}\n${slots}${body}\n}\n`;
}

function containsTrace(node) {
  if (node === null || typeof node !== 'object') return false;
  if (node.type === 'trace') return true;
  return Object.values(node).some(value => (Array.isArray(value)
    ? value.some(containsTrace)
    : containsTrace(value)));
}

// The Core names a node uses that it does not bind.
function freeNames(node, bound, out) {
  switch (node.type) {
    case 'name':
      if (!bound.has(node.name)) out.add(node.name);
      return out;
    case 'literal':
    case 'native':
    case 'crash':
      return out;
    case 'cons':
      freeNames(node.head, bound, out);
      return freeNames(node.tail, bound, out);
    case 'slot':
    case 'cell':
      return freeNames(node.value, bound, out);
    case 'edit':
      freeNames(node.target, bound, out);
      return freeNames(node.value, bound, out);
    case 'eq':
      freeNames(node.left, bound, out);
      return freeNames(node.right, bound, out);
    case 'if':
      freeNames(node.condition, bound, out);
      freeNames(node.then, bound, out);
      return freeNames(node.else, bound, out);
    case 'let':
      freeNames(node.value, bound, out);
      return freeNames(node.body, new Set([...bound, node.name]), out);
    case 'rec': {
      const inner = new Set([...bound, ...node.bindings.map(binding => binding.name)]);
      for (const binding of node.bindings) freeNames(binding.lambda, inner, out);
      return freeNames(node.body, inner, out);
    }
    case 'lam':
      return freeNames(node.body, new Set([...bound, node.parameter]), out);
    case 'app':
      freeNames(node.fn, bound, out);
      return freeNames(node.argument, bound, out);
    case 'trace':
      freeNames(node.message, bound, out);
      return freeNames(node.body, bound, out);
    default:
      throw new Error(`unsupported Core node ${node.type}`);
  }
}

// A lambda inside another whose every free name is bound outside all
// lambdas is the same closure each time, so it is made once.
function closed(node, scope) {
  for (const name of freeNames(node, new Set(), new Set())) {
    if (scope.depthOf(name) !== 0) return false;
  }
  return true;
}

function depthOf(scope) {
  return scope === null ? 0 : scope.depth;
}

// depth counts the lambdas around a scope: 0 is the module's own level.
class Scope {
  constructor(context, parent, depth = parent === null ? 0 : parent.depth) {
    this.context = context;
    this.parent = parent;
    this.depth = depth;
    this.names = new Map();
  }

  fresh() {
    return `$${this.context.nextVariable++}`;
  }

  define(name) {
    if (this.names.has(name)) {
      throw new Error(`duplicate JavaScript binding for ${name}`);
    }
    const variable = this.fresh();
    this.names.set(name, variable);
    return variable;
  }

  lookup(name) {
    const variable = this.names.get(name) ?? this.parent?.lookup(name);
    if (variable === undefined) {
      throw new Error(`unbound Core name ${name}`);
    }
    return variable;
  }

  depthOf(name) {
    if (this.names.has(name)) return this.depth;
    if (this.parent === null) throw new Error(`unbound Core name ${name}`);
    return this.parent.depthOf(name);
  }
}

function expression(node, context, scope) {
  switch (node.type) {
    case 'literal':
      return `BigInt(${JSON.stringify(readLiteral(node.text).value.toString())})`;
    case 'name':
      return scope.lookup(node.name);
    case 'cons':
      return `cons(${expression(node.head, context, scope)}, ${expression(node.tail, context, scope)})`;
    case 'slot':
      return `slot(${node.axis}n, ${expression(node.value, context, scope)})`;
    case 'edit':
      return `edit(${node.axis}n, ${expression(node.target, context, scope)}, ${expression(node.value, context, scope)})`;
    case 'cell':
      return `isCell(${expression(node.value, context, scope)})`;
    case 'eq':
      return `same(${expression(node.left, context, scope)}, ${expression(node.right, context, scope)})`;
    case 'if':
      return `(requireLoobean(${expression(node.condition, context, scope)}) ? ${expression(node.then, context, scope)} : ${expression(node.else, context, scope)})`;
    case 'let': {
      const inner = new Scope(context, scope ?? null);
      const value = expression(node.value, context, scope);
      const variable = inner.define(node.name);
      return `(() => { const ${variable} = ${value}; return ${expression(node.body, context, inner)}; })()`;
    }
    case 'rec': {
      const inner = new Scope(context, scope ?? null);
      const bindings = node.bindings.map((binding) => ({
        binding,
        variable: inner.define(binding.name),
      }));
      const declarations = bindings.map(({ binding, variable }) => {
        if (binding.lambda.type !== 'lam') {
          throw new Error(`recursive binding ${binding.name} is not a lambda`);
        }
        const declaration = lambda(binding.lambda, context, inner, variable, true, binding.name);
        // A module-level arm remembers its last product; inside, its name is
        // the bare function, so its own recursion does not.
        return depthOf(scope) === 0 && context.memoize
          ? `const ${variable} = memo(${declaration});`
          : declaration;
      });
      return `(() => {\n${declarations.join('\n')}\nreturn ${expression(node.body, context, inner)};\n})()`;
    }
    case 'lam': {
      const made = lambda(node, context, scope, null, false);
      if (depthOf(scope) === 0) return context.memoize ? `memo(${made})` : made;
      if (!closed(node, scope)) return made;
      const slot = `$h${context.hoisted.length}`;
      context.hoisted.push(slot);
      return `(${slot} ??= ${made})`;
    }
    case 'app':
      return `apply(${expression(node.fn, context, scope)}, ${expression(node.argument, context, scope)})`;
    case 'native':
      if (!context.natives.has(node.name)) {
        throw new Error(`unknown native ${node.name}`);
      }
      context.requiredNatives.add(node.name);
      return `natives[${JSON.stringify(node.name)}]`;
    case 'crash':
      return 'crash("explicit Core crash")';
    case 'trace':
      return `traceLazy(${expression(node.message, context, scope)}, () => ${expression(node.body, context, scope)})`;
    default:
      throw new Error(`unsupported Core node ${node.type}`);
  }
}

function lambda(node, context, scope, variable, declaration, recursiveName = null) {
  if (node.type !== 'lam') {
    throw new Error('expected lambda');
  }
  const inner = new Scope(context, scope ?? null, depthOf(scope) + 1);
  const parameter = inner.define(node.parameter);
  if (declaration && containsSelfTail(node.body, recursiveName)) {
    const state = inner.fresh();
    const current = inner.fresh();
    inner.names.set(node.parameter, current);
    const body = tailExpression(node.body, context, inner, { name: recursiveName, state });
    return `function ${variable}(${parameter}) {\nlet ${state} = ${parameter};\nfor (;;) {\nconst ${current} = ${state};\n${body}\n}\n}`;
  }
  const body = expression(node.body, context, inner);
  return declaration
    ? `function ${variable}(${parameter}) { return ${body}; }`
    : `((${parameter}) => ${body})`;
}

function containsSelfTail(node, name) {
  if (name === null) return false;
  switch (node.type) {
    case 'app':
      return node.fn.type === 'name' && node.fn.name === name;
    case 'if':
      return containsSelfTail(node.then, name) || containsSelfTail(node.else, name);
    case 'let':
      return containsSelfTail(node.body, name);
    case 'rec':
      return containsSelfTail(node.body, name);
    default:
      return false;
  }
}

function tailExpression(node, context, scope, self) {
  switch (node.type) {
    case 'app':
      if (node.fn.type === 'name' && node.fn.name === self.name) {
        return `${self.state} = ${expression(node.argument, context, scope)};\ncontinue;`;
      }
      break;
    case 'if':
      return `if (requireLoobean(${expression(node.condition, context, scope)})) {\n${tailExpression(node.then, context, scope, self)}\n} else {\n${tailExpression(node.else, context, scope, self)}\n}`;
    case 'let': {
      const inner = new Scope(context, scope ?? null);
      const value = expression(node.value, context, scope);
      const variable = inner.define(node.name);
      return `const ${variable} = ${value};\n${tailExpression(node.body, context, inner, self)}`;
    }
    case 'rec': {
      const inner = new Scope(context, scope ?? null);
      const bindings = node.bindings.map((binding) => ({
        binding,
        variable: inner.define(binding.name),
      }));
      const declarations = bindings.map(({ binding, variable }) =>
        lambda(binding.lambda, context, inner, variable, true, binding.name)
      );
      return `${declarations.join('\n')}\n${tailExpression(node.body, context, inner, self)}`;
    }
  }
  return `return ${expression(node, context, scope)};`;
}
