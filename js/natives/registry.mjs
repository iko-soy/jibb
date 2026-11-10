const implementations = new Map();

export function defineNative(name, implementation) {
  if (typeof name !== 'string' || name === '' || typeof implementation !== 'function') {
    throw new TypeError('a native needs a name and function implementation');
  }
  if (implementations.has(name)) {
    throw new Error(`duplicate native implementation ${name}`);
  }
  implementations.set(name, implementation);
}

export function createNativeRegistry(identities) {
  const registry = Object.create(null);
  for (const identity of identities) {
    if (!implementations.has(identity)) {
      throw new Error(`no JavaScript implementation for native ${identity}`);
    }
    Object.defineProperty(registry, identity, {
      value: implementations.get(identity),
      enumerable: true,
      configurable: false,
      writable: false,
    });
  }
  return registry;
}

// Every native defined so far, as a browser page's islands may use any.
export function nativeNames() {
  return [...implementations.keys()];
}
