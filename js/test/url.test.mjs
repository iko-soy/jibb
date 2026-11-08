import test from 'node:test';
import assert from 'node:assert/strict';
import { pathToNoun, UrlRuntime } from '../browser/url.mjs';
import { cord, listToArray } from '../natives/helpers.mjs';

function fakeWindow(pathname = '/initial') {
  const listeners = new Map();
  const window = {
    location: { pathname },
    listeners,
    addEventListener(type, listener) {
      const entries = listeners.get(type) ?? [];
      entries.push(listener);
      listeners.set(type, entries);
    },
    removeEventListener(type, listener) {
      listeners.set(type, (listeners.get(type) ?? []).filter(entry => entry !== listener));
    },
  };
  window.history = {
    calls: [],
    pushState(_state, _title, url) {
      this.calls.push(url);
      const parsed = new URL(url, 'https://ship.example');
      window.location.pathname = parsed.pathname;
    },
  };
  return window;
}

test('paths become noun lists with decoded segments', () => {
  assert.deepEqual(pathToNoun('/blog/hello%20world'), [cord('blog'), [cord('hello world'), 0n]]);
  assert.deepEqual(pathToNoun('/'), 0n);
});

test('watch delivers initial path, go updates history, and popstate notifies', () => {
  const window = fakeWindow();
  const focused = [];
  const document = { querySelector: () => ({ focus: () => focused.push('h1') }) };
  const runtime = new UrlRuntime({ window, document, defer: (fn) => fn() });
  const paths = [];
  const id = runtime.watch((path) => paths.push(path));
  assert.deepEqual(paths, [[cord('initial'), 0n]]);
  runtime.go('/next/page');
  assert.deepEqual(window.history.calls, ['/next/page']);
  assert.deepEqual(paths.at(-1), [cord('next'), [cord('page'), 0n]]);
  assert.deepEqual(focused, ['h1']);
  window.location.pathname = '/back';
  window.listeners.get('popstate')[0]();
  assert.deepEqual(paths.at(-1), [cord('back'), 0n]);
  runtime.unwatch(id);
  runtime.go('/ignored');
  assert.deepEqual(paths.at(-1), [cord('back'), 0n]);
  runtime.stop();
  assert.equal(window.listeners.get('popstate').length, 0);
});
