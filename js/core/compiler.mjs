import { readCore } from './reader.mjs';
import { readLiteral } from './literal.mjs';
import { abstractValue, boundValue, UNKNOWN, viewTemplate as templatePlan } from './view-template.mjs';
import { directHoles } from './direct-template.mjs';
import { freeNames } from './free-names.mjs';

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
    hoistSites: [],
  };
  let body;
  if (ast.type === 'module') {
    const names = new Scope(context, null);
    context.scopes.push(names);
    const declarations = ast.definitions.map((definition) => {
      const variable = names.define(definition.name);
      return { definition, variable };
    });
    const statements = declarations.map(({ definition, variable }) => {
      const value = abstractValue(definition.expression, names.abstractEnvironment());
      const made = expression(definition.expression, context, names);
      names.abstracts.set(definition.name, boundValue(value, variable));
      return `const ${variable} = ${made};`;
    });
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
  return `// Generated from Jibb Core. Do not edit.\nexport function evaluate(runtime, natives) {\nconst {apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy, memo, viewTemplate, checkValue} = runtime;\nconst requireNative = (registry, name) => {\n  if (registry === null || typeof registry !== 'object' || !Object.hasOwn(registry, name) || typeof registry[name] !== 'function') {\n    throw new TypeError(\`missing native \${name}\`);\n  }\n};\n${nativeChecks.join('\n')}\n${slots}${body}\n}\n`;
}

function containsTrace(node) {
  if (node === null || typeof node !== 'object') return false;
  if (node.type === 'trace') return true;
  return Object.values(node).some(value => (Array.isArray(value)
    ? value.some(containsTrace)
    : containsTrace(value)));
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
    this.abstracts = new Map();
  }

  fresh() {
    return `$${this.context.nextVariable++}`;
  }

  define(name, value = UNKNOWN) {
    if (this.names.has(name)) {
      throw new Error(`duplicate JavaScript binding for ${name}`);
    }
    const variable = this.fresh();
    this.names.set(name, variable);
    this.abstracts.set(name, boundValue(value, variable));
    return variable;
  }

  // One independent lexical snapshot per call, with outer bindings first.
  abstractEnvironment(environment = new Map()) {
    this.parent?.abstractEnvironment(environment);
    for (const [name, value] of this.abstracts) environment.set(name, value);
    return environment;
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

function decorateTemplate(node, made, scope, context) {
  const environment = scope?.abstractEnvironment();
  const plan = templatePlan(node, environment);
  if (plan === undefined) return made;
  const direct = directHoles(node, environment, plan.axes, context.hoistSites);
  return `viewTemplate(${made}, ${JSON.stringify(plan.tree)}, [${plan.axes.join(', ')}], natives${direct === undefined ? '' : `, ${direct}`})`;
}

function recursiveDeclaration(binding, variable, context, scope, memoize) {
  const declaration = lambda(binding.lambda, context, scope, variable, true, binding.name);
  const made = memoize ? `memo(${declaration})` : declaration;
  const decorated = decorateTemplate(binding.lambda, made, scope, context);
  return memoize || decorated !== declaration ? `const ${variable} = ${decorated};` : declaration;
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
      const variable = inner.define(node.name, abstractValue(node.value, scope?.abstractEnvironment()));
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
        // A module-level arm remembers its last product; inside, its name is
        // the bare function, so its own recursion does not.
        return recursiveDeclaration(binding, variable, context, inner, depthOf(scope) === 0 && context.memoize);
      });
      return `(() => {\n${declarations.join('\n')}\nreturn ${expression(node.body, context, inner)};\n})()`;
    }
    case 'lam': {
      let made = lambda(node, context, scope, null, false);
      if (depthOf(scope) === 0) {
        return decorateTemplate(node, context.memoize ? `memo(${made})` : made, scope, context);
      }
      made = decorateTemplate(node, made, scope, context);
      if (!closed(node, scope)) return made;
      const slot = `$h${context.hoisted.length}`;
      context.hoisted.push(slot);
      const code = `(${slot} ??= ${made})`;
      const references = new Map([...freeNames(node, new Set(), new Set())]
        .map(name => [name, scope.lookup(name)]));
      context.hoistSites.push({ node, references, code });
      return code;
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
    inner.abstracts.set(node.parameter, boundValue(UNKNOWN, current));
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
      const variable = inner.define(node.name, abstractValue(node.value, scope?.abstractEnvironment()));
      return `const ${variable} = ${value};\n${tailExpression(node.body, context, inner, self)}`;
    }
    case 'rec': {
      const inner = new Scope(context, scope ?? null);
      const bindings = node.bindings.map((binding) => ({
        binding,
        variable: inner.define(binding.name),
      }));
      const declarations = bindings.map(({ binding, variable }) =>
        recursiveDeclaration(binding, variable, context, inner, false)
      );
      return `${declarations.join('\n')}\n${tailExpression(node.body, context, inner, self)}`;
    }
  }
  return `return ${expression(node, context, scope)};`;
}
