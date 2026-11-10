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
    this.nextId = 1n;
    this.watchers = new Map();
    this.onPopstate = () => this.notify();
    window.addEventListener('popstate', this.onPopstate);
  }

  contains(pathname) {
    return this.prefix === '' || pathname === this.prefix || pathname.startsWith(`${this.prefix}/`);
  }

  currentPath() {
    const pathname = this.window.location.pathname;
    return pathToNoun(this.prefix !== '' && this.contains(pathname)
      ? pathname.slice(this.prefix.length)
      : pathname);
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
