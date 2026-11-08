import { compileCore } from './compiler.mjs';
import { readCore } from './reader.mjs';

export function linkCore(inputs, entry, { nativeNames = [] } = {}) {
  const allowedNatives = new Set(nativeNames);
  const modules = inputs.map((input) => {
    const module = typeof input === 'string' ? readCore(input) : input;
    if (module.type !== 'module') throw new Error('linker inputs must be Core modules');
    return module;
  }).sort((left, right) => pathOf(left).localeCompare(pathOf(right)));

  const definitions = new Map();
  const paths = new Set();
  for (const module of modules) {
    const path = pathOf(module);
    if (paths.has(path)) throw new Error(`duplicate module ${path}`);
    paths.add(path);
    for (const definition of module.definitions) {
      const id = `${path}:${definition.name}`;
      if (definitions.has(id)) throw new Error(`duplicate definition ${id}`);
      definitions.set(id, {
        id,
        expression: qualify(definition.expression, path),
        order: definitions.size,
      });
    }
  }

  const selected = selectEntry(entry);
  const selectedModule = modules.find((module) => pathOf(module) === selected.module);
  const roots = selected.wholeModule
    ? selectedModule?.definitions.map((definition) => `${selected.module}:${definition.name}`)
    : [selected.name];
  if (!roots || roots.some((id) => !definitions.has(id))) {
    throw new Error(`unknown link entry ${selected.name ?? selected.module}`);
  }

  const reachable = new Set();
  function visit(id) {
    if (reachable.has(id)) return;
    const definition = definitions.get(id);
    if (!definition) throw new Error(`unbound linked definition ${id}`);
    reachable.add(id);
    for (const reference of references(definition.expression)) visit(reference);
  }
  roots.forEach(visit);

  const ordered = [...definitions.values()]
    .filter((definition) => reachable.has(definition.id))
    .sort((left, right) => left.order - right.order);
  const groups = components(ordered);
  let body = selected.wholeModule ? wholeValue(roots, definitions) : {
    type: 'name',
    name: selected.name,
  };
  for (const component of groups.toReversed()) {
    const recursive = component.length > 1
      || references(component[0].expression).has(component[0].id);
    if (recursive) {
      for (const definition of component) {
        if (definition.expression.type !== 'lam') {
          throw new Error(`recursive non-gate definition ${definition.id}`);
        }
      }
      body = {
        type: 'rec',
        bindings: component.map((definition) => ({
          name: definition.id,
          lambda: definition.expression,
        })),
        body,
      };
    } else {
      body = {
        type: 'let',
        name: component[0].id,
        value: component[0].expression,
        body,
      };
    }
  }

  const requiredNatives = references(body, true);
  for (const name of requiredNatives) {
    if (!allowedNatives.has(name)) throw new Error(`unknown native ${name}`);
  }
  return {
    ast: body,
    nativeNames: [...requiredNatives].sort(),
    definitions: groups.flatMap((component) => component.map((definition) => definition.id)),
    entry: selected,
  };
}

export function compileLinkedCore(inputs, entry, options = {}) {
  const linked = linkCore(inputs, entry, options);
  return {
    ...linked,
    source: compileCore(linked.ast, { nativeNames: options.nativeNames ?? [] }),
  };
}

function pathOf(module) {
  return module.path.join('/');
}

function selectEntry(entry) {
  if (typeof entry === 'string') {
    const separator = entry.lastIndexOf(':');
    if (separator < 1 || separator === entry.length - 1) {
      throw new Error('entry must be module/name or path:name');
    }
    return { module: entry.slice(0, separator), name: entry, wholeModule: false };
  }
  if (entry && typeof entry === 'object' && typeof entry.module === 'string') {
    if (entry.wholeModule) return { module: entry.module, wholeModule: true };
    if (typeof entry.name === 'string' && entry.name !== '') {
      return { module: entry.module, name: `${entry.module}:${entry.name}`, wholeModule: false };
    }
  }
  throw new Error('entry must select a module definition or whole module');
}

function wholeValue(roots, definitions) {
  const values = roots
    .map((id) => definitions.get(id))
    .sort((left, right) => left.id.localeCompare(right.id))
    .map((definition) => ({ type: 'name', name: definition.id }));
  if (values.length === 0) throw new Error('cannot use an empty module as a value');
  return values.length === 1
    ? values[0]
    : values.reduceRight((tail, value) => ({ type: 'cons', head: value, tail }));
}

function qualify(node, path, bound = new Set()) {
  switch (node.type) {
    case 'literal':
    case 'native':
    case 'crash':
      return { ...node };
    case 'name':
      return bound.has(node.name) || node.name.includes(':')
        ? { ...node }
        : { type: 'name', name: `${path}:${node.name}` };
    case 'let':
      return {
        type: 'let',
        name: node.name,
        value: qualify(node.value, path, bound),
        body: qualify(node.body, path, new Set([...bound, node.name])),
      };
    case 'lam':
      return {
        type: 'lam',
        parameter: node.parameter,
        body: qualify(node.body, path, new Set([...bound, node.parameter])),
      };
    case 'rec': {
      const inner = new Set([...bound, ...node.bindings.map((binding) => binding.name)]);
      return {
        type: 'rec',
        bindings: node.bindings.map((binding) => ({
          name: binding.name,
          lambda: qualify(binding.lambda, path, inner),
        })),
        body: qualify(node.body, path, inner),
      };
    }
    default:
      return mapChildren(node, (child) => qualify(child, path, bound));
  }
}

function mapChildren(node, convert) {
  return Object.fromEntries(Object.entries(node).map(([key, value]) => {
    if (Array.isArray(value)) {
      return [key, value.map((item) => item && typeof item === 'object' ? convert(item) : item)];
    }
    return [key, value && typeof value === 'object' ? convert(value) : value];
  }));
}

function references(node, natives = false, bound = new Set(), found = new Set()) {
  switch (node.type) {
    case 'name':
      if (!natives && !bound.has(node.name)) found.add(node.name);
      break;
    case 'native':
      if (natives) found.add(node.name);
      break;
    case 'let':
      references(node.value, natives, bound, found);
      references(node.body, natives, new Set([...bound, node.name]), found);
      return found;
    case 'lam':
      references(node.body, natives, new Set([...bound, node.parameter]), found);
      return found;
    case 'rec': {
      const inner = new Set([...bound, ...node.bindings.map((binding) => binding.name)]);
      for (const binding of node.bindings) references(binding.lambda, natives, inner, found);
      references(node.body, natives, inner, found);
      return found;
    }
    default:
      for (const value of Object.values(node)) collectReferences(value, natives, bound, found);
  }
  return found;
}

function collectReferences(value, natives, bound, found) {
  if (Array.isArray(value)) {
    for (const item of value) collectReferences(item, natives, bound, found);
  } else if (value && typeof value === 'object') {
    if (typeof value.type === 'string') {
      references(value, natives, bound, found);
    } else {
      for (const item of Object.values(value)) collectReferences(item, natives, bound, found);
    }
  }
}

function components(definitions) {
  const byId = new Map(definitions.map((definition) => [definition.id, definition]));
  const indices = new Map();
  const lowlinks = new Map();
  const stack = [];
  const onStack = new Set();
  const result = [];
  let next = 0;

  function connect(definition) {
    const id = definition.id;
    indices.set(id, next);
    lowlinks.set(id, next);
    next += 1;
    stack.push(definition);
    onStack.add(id);
    for (const reference of references(definition.expression)) {
      if (!byId.has(reference)) continue;
      if (!indices.has(reference)) {
        connect(byId.get(reference));
        lowlinks.set(id, Math.min(lowlinks.get(id), lowlinks.get(reference)));
      } else if (onStack.has(reference)) {
        lowlinks.set(id, Math.min(lowlinks.get(id), indices.get(reference)));
      }
    }
    if (lowlinks.get(id) === indices.get(id)) {
      const component = [];
      let member;
      do {
        member = stack.pop();
        onStack.delete(member.id);
        component.push(member);
      } while (member.id !== id);
      component.sort((left, right) => left.order - right.order);
      result.push(component);
    }
  }

  for (const definition of definitions) {
    if (!indices.has(definition.id)) connect(definition);
  }
  return result;
}
