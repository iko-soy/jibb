// The Core names a node uses that it does not bind.
export function freeNames(node, bound, out) {
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
