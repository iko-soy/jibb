import test from 'node:test';
import assert from 'node:assert/strict';
import { createFakeDocument } from './fake-dom.mjs';
import { startIsland } from '../browser/island.mjs';
import { Effects } from '../browser/effects.mjs';
import { UrlRuntime } from '../browser/url.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { cord } from '../natives/helpers.mjs';

function navigationWindow() {
  const listeners = new Map();
  const window = {
    location: { pathname: '/start' },
    listeners,
    addEventListener: (type, fn) => listeners.set(type, [...(listeners.get(type) ?? []), fn]),
    removeEventListener: (type, fn) => listeners.set(type, (listeners.get(type) ?? []).filter(entry => entry !== fn)),
  };
  window.history = {
    calls: [],
    pushState(_state, _title, url) {
      this.calls.push(url);
      window.location.pathname = new URL(url, 'https://ship.example').pathname;
    },
  };
  return window;
}

test('Effects delivers initial and subsequent URL messages and focuses after go', async () => {
  const document = createFakeDocument();
  const window = navigationWindow();
  const focused = [];
  document.querySelector = () => ({ focus: () => focused.push('h1') });
  const messages = [];
  const program = {
    init: () => 0n,
    update: ([message, model]) => {
      messages.push(message);
      return [model, 0n];
    },
    view: (model) => rawSeal([cord('text'), cord(String(model))]),
    subs: () => [ [cord('url'), (path) => [cord('url'), path]], 0n],
  };
  const island = startIsland({ program, document, container: document.body });
  const urlRuntime = new UrlRuntime({ window, document, defer: (fn) => fn() });
  const effects = new Effects({ island, channel: {}, urlRuntime });
  assert.deepEqual(messages[0], [cord('url'), [cord('start'), 0n]]);
  island.dispatchCommand([cord('go'), cord('/next')]);
  assert.deepEqual(window.history.calls, ['/next']);
  assert.deepEqual(messages.at(-1), [cord('url'), [cord('next'), 0n]]);
  assert.deepEqual(focused, ['h1']);
  effects.stop();
  assert.equal(urlRuntime.watchers.size, 0);
});
