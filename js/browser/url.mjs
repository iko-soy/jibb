import { arrayToList, cord } from '../natives/helpers.mjs';

export function pathToNoun(pathname) {
  return arrayToList(String(pathname).split('/').filter(Boolean).map((segment) => {
    try {
      return cord(decodeURIComponent(segment));
    } catch {
      return cord(segment);
    }
  }));
}

// prefix is the page's base path and, for an app under a catch-all route,
// the section that route covers: %url gives the path within it.
export class UrlRuntime {
  constructor({ window, document, defer = callback => queueMicrotask(callback), prefix = '' }) {
    if (!window?.history || !window.location) throw new TypeError('URL runtime needs a window with history and location');
    this.window = window;
    this.document = document;
    this.defer = defer;
    this.prefix = prefix;
    this.prefixParts = prefix.split('/');
    this.parameterized = this.prefixParts.some(part => part.startsWith('_') && !part.startsWith('__'));
    this.nextId = 1n;
    this.watchers = new Map();
    this.onPopstate = () => this.notify();
    window.addEventListener('popstate', this.onPopstate);
  }

  matchPrefix(pathname) {
    if (this.prefix === '') return 0;
    if (!this.parameterized) {
      return pathname === this.prefix || pathname.startsWith(`${this.prefix}/`)
        ? this.prefix.length
        : -1;
    }
    const parts = pathname.split('/');
    if (parts.length < this.prefixParts.length) return -1;
    for (let index = 0; index < this.prefixParts.length; index++) {
      const pattern = this.prefixParts[index];
      if (pattern.startsWith('_') && !pattern.startsWith('__')) {
        if (parts[index] === '') return -1;
      } else if (parts[index] !== pattern) {
        return -1;
      }
    }
    return parts.slice(0, this.prefixParts.length).join('/').length;
  }

  contains(pathname) {
    return this.matchPrefix(pathname) !== -1;
  }

  currentPath() {
    const pathname = this.window.location.pathname;
    const prefixLength = this.matchPrefix(pathname);
    return pathToNoun(prefixLength === -1 ? pathname : pathname.slice(prefixLength));
  }

  watch(reply) {
    const id = this.nextId++;
    this.watchers.set(id, reply);
    this.defer(() => {
      if (this.watchers.has(id)) this.watchers.get(id)(this.currentPath());
    });
    return id;
  }

  unwatch(id) {
    this.watchers.delete(id);
  }

  go(url) {
    this.window.history.pushState({}, '', url);
    this.notify();
    this.defer(() => {
      const heading = this.document?.querySelector('h1');
      if (heading && typeof heading.focus === 'function') heading.focus();
    });
  }

  notify() {
    const path = this.currentPath();
    for (const reply of this.watchers.values()) reply(path);
  }

  stop() {
    this.window.removeEventListener('popstate', this.onPopstate);
    this.watchers.clear();
  }
}
