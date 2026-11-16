import { apply, CoreCrash } from '../core/runtime.mjs';
import { cord } from '../natives/helpers.mjs';

function crashCord(error) {
  if (error instanceof CoreCrash || error instanceof Error) {
    return cord(error.message || 'store update crashed');
  }
  return cord(String(error));
}

export class StoreRegistry {
  constructor({ defer = callback => queueMicrotask(callback) } = {}) {
    if (typeof defer !== 'function') throw new TypeError('StoreRegistry requires a defer function');
    this.defer = defer;
    this.stores = new Map();
    this.watches = new Map();
    this.nextWatch = 1n;
    // States wait here for their watchers, in the order the pokes made
    // them, so a watcher that pokes the store from its own update can't
    // leave the others with an older state.
    this.queue = [];
    this.delivering = false;
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
    this.defer(() => this.deliver([[watch, store.state]]));
    return id;
  }

  deliver(facts) {
    this.queue.push(...facts);
    if (this.delivering) return;
    this.delivering = true;
    try {
      while (this.queue.length !== 0) {
        const [watch, noun] = this.queue.shift();
        if (this.watches.get(watch.id) !== watch) continue;
        watch.notify({ requestId: watch.id, mark: watch.store.name, noun });
      }
    } finally {
      this.delivering = false;
    }
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
    this.deliver([...this.watches.values()]
      .filter(watch => watch.store === store)
      .map(watch => [watch, next]));
    return 0n;
  }
}
