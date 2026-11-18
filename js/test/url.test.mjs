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

test('literal section prefixes keep their boundary and current path behavior', () => {
  const window = fakeWindow('/apps/test/app/one');
  const runtime = new UrlRuntime({ window, prefix: '/apps/test/app', defer: (fn) => fn() });
  assert.equal(runtime.contains('/apps/test/app'), true);
  assert.equal(runtime.contains('/apps/test/app/two'), true);
  assert.equal(runtime.contains('/apps/test/application'), false);
  assert.deepEqual(runtime.currentPath(), [cord('one'), 0n]);
  window.location.pathname = '/apps/test/app';
  assert.deepEqual(runtime.currentPath(), 0n);
  runtime.stop();
});

test('parameterized sections navigate and strip the complete matched prefix', () => {
  const window = fakeWindow('/apps/test/user/alice/inbox');
  const runtime = new UrlRuntime({ window, prefix: '/apps/test/user/_id', defer: (fn) => fn() });
  const paths = [];
  runtime.watch(path => paths.push(path));
  assert.deepEqual(paths, [[cord('inbox'), 0n]]);
  assert.equal(runtime.contains('/apps/test/user/alice'), true);
  assert.equal(runtime.contains('/apps/test/user/alice/inbox'), true);
  runtime.go('/apps/test/user/bob/hello%20world?tab=all#details');
  assert.deepEqual(window.history.calls, ['/apps/test/user/bob/hello%20world?tab=all#details']);
  assert.deepEqual(paths.at(-1), [cord('hello world'), 0n]);
  window.location.pathname = '/apps/test/user/bob';
  assert.deepEqual(runtime.currentPath(), 0n);
  runtime.stop();
});

test('parameterized sections reject missing parameters and nonmatching literals', () => {
  const window = fakeWindow('/apps/test/user/alice/inbox');
  const runtime = new UrlRuntime({ window, prefix: '/apps/test/user/_id' });
  assert.equal(runtime.contains('/apps/test/user'), false);
  assert.equal(runtime.contains('/apps/test/user/'), false);
  assert.equal(runtime.contains('/apps/test/user//inbox'), false);
  assert.equal(runtime.contains('/apps/test/users/alice/inbox'), false);
  assert.equal(runtime.contains('/apps/test/user/alice'), true);
  runtime.stop();
});

test('multiple parameters match one segment each and popstate uses new values', () => {
  const window = fakeWindow('/apps/test/org/acme/member/u1/drafts');
  const runtime = new UrlRuntime({
    window,
    prefix: '/apps/test/org/_org/member/_member',
    defer: (fn) => fn(),
  });
  const paths = [];
  runtime.watch(path => paths.push(path));
  assert.deepEqual(paths, [[cord('drafts'), 0n]]);
  runtime.go('/apps/test/org/example/member/u2/edit');
  assert.deepEqual(paths.at(-1), [cord('edit'), 0n]);
  window.location.pathname = '/apps/test/org/other/member/u3/notes/today';
  window.listeners.get('popstate')[0]();
  assert.deepEqual(paths.at(-1), [cord('notes'), [cord('today'), 0n]]);
  assert.equal(runtime.contains('/apps/test/org/acme/member'), false);
  assert.equal(runtime.contains('/apps/test/org/acme/member/'), false);
  assert.equal(runtime.contains('/apps/test/org/acme/members/u1'), false);
  runtime.stop();
});

test('double underscore prefix segments remain literal', () => {
  const window = fakeWindow('/apps/test/__archive/a1');
  const runtime = new UrlRuntime({ window, prefix: '/apps/test/__archive/_id' });
  assert.equal(runtime.contains('/apps/test/__archive/a1'), true);
  assert.equal(runtime.contains('/apps/test/other/a1'), false);
  assert.deepEqual(runtime.currentPath(), 0n);
  runtime.stop();
});
