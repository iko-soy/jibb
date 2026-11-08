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

export class UrlRuntime {
  constructor({ window, document, defer = queueMicrotask }) {
    if (!window?.history || !window.location) throw new TypeError('URL runtime needs a window with history and location');
    this.window = window;
    this.document = document;
    this.defer = defer;
    this.nextId = 1n;
    this.watchers = new Map();
    this.onPopstate = () => this.notify();
    window.addEventListener('popstate', this.onPopstate);
  }

  currentPath() {
    return pathToNoun(this.window.location.pathname);
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
