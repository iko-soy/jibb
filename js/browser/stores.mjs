import { apply, CoreCrash } from '../core/runtime.mjs';
import { cord } from '../natives/helpers.mjs';

function crashCord(error) {
  if (error instanceof CoreCrash || error instanceof Error) {
    return cord(error.message || 'store update crashed');
  }
  return cord(String(error));
}

export class StoreRegistry {
  constructor({ defer = globalThis.queueMicrotask } = {}) {
    if (typeof defer !== 'function') throw new TypeError('StoreRegistry requires a defer function');
    this.defer = defer;
    this.stores = new Map();
    this.watches = new Map();
    this.nextWatch = 1n;
  }

  register({ name, init, update }) {
    if (this.stores.has(name)) throw new Error(`store already registered: ${String(name)}`);
    if (typeof update !== 'function') throw new TypeError(`store update must be callable: ${String(name)}`);
    this.stores.set(name, { name, state: init, update });
  }

  watch(name, notify) {
    const store = this.stores.get(name);
    if (!store) throw new Error(`unknown store: ${String(name)}`);
    if (typeof notify !== 'function') throw new TypeError(`store watch notify must be callable: ${String(name)}`);

    const id = this.nextWatch;
    this.nextWatch += 1n;
    const watch = { id, store, notify };
    this.watches.set(id, watch);
    this.defer(() => {
      if (this.watches.get(id) !== watch) return;
      notify({ requestId: id, mark: name, noun: store.state });
    });
    return id;
  }

  unwatch(id) {
    if (!this.watches.delete(id)) throw new Error(`unknown store watch: ${String(id)}`);
  }

  poke(name, action, payload) {
    const store = this.stores.get(name);
    if (!store) throw new Error(`unknown store: ${String(name)}`);

    let next;
    try {
      next = apply(store.update, [[action, payload], store.state]);
    } catch (error) {
      return [0n, crashCord(error)];
    }

    store.state = next;
    const watches = [...this.watches.values()];
    for (const watch of watches) {
      if (watch.store !== store || this.watches.get(watch.id) !== watch) continue;
      watch.notify({ requestId: watch.id, mark: name, noun: next });
    }
    return 0n;
  }
}
