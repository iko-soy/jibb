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
  return `// Generated from Jibb Core. Do not edit.\nexport function evaluate(runtime, natives) {\nconst {apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy} = runtime;\nconst requireNative = (registry, name) => {\n  if (registry === null || typeof registry !== 'object' || !Object.hasOwn(registry, name) || typeof registry[name] !== 'function') {\n    throw new TypeError(\`missing native \${name}\`);\n  }\n};\n${nativeChecks.join('\n')}\n${body}\n}\n`;
}

class Scope {
  constructor(context, parent) {
    this.context = context;
    this.parent = parent;
    this.names = new Map();
  }

  define(name) {
    if (this.names.has(name)) {
      throw new Error(`duplicate JavaScript binding for ${name}`);
    }
    const variable = `$${this.context.nextVariable++}`;
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
      const inner = new Scope(context, scope);
      const value = expression(node.value, context, scope);
      const variable = inner.define(node.name);
      return `(() => { const ${variable} = ${value}; return ${expression(node.body, context, inner)}; })()`;
    }
    case 'rec': {
      const inner = new Scope(context, scope);
      const bindings = node.bindings.map((binding) => ({
        binding,
        variable: inner.define(binding.name),
      }));
      const declarations = bindings.map(({ binding, variable }) => {
        if (binding.lambda.type !== 'lam') {
          throw new Error(`recursive binding ${binding.name} is not a lambda`);
        }
        return lambda(binding.lambda, context, inner, variable, true);
      });
      return `(() => {\n${declarations.join('\n')}\nreturn ${expression(node.body, context, inner)};\n})()`;
    }
    case 'lam':
      return lambda(node, context, scope, null, false);
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

function lambda(node, context, scope, variable, declaration) {
  if (node.type !== 'lam') {
    throw new Error('expected lambda');
  }
  const inner = new Scope(context, scope);
  const parameter = inner.define(node.parameter);
  const body = expression(node.body, context, inner);
  return declaration
    ? `function ${variable}(${parameter}) { return ${body}; }`
    : `((${parameter}) => ${body})`;
}
