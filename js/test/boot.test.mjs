import test from 'node:test';
import assert from 'node:assert/strict';
import { compileCore } from '../core/compiler.mjs';
import { boot, CRASH_NOTICE } from '../browser/boot.mjs';
import { encodeUw, jam } from '../natives/codec.mjs';
import { cord } from '../natives/helpers.mjs';
import { nativeNames } from '../natives/index.mjs';
import { createFakeDocument, FakeEvent } from './fake-dom.mjs';

const natives = nativeNames();
const module = core => compileCore(core, { nativeNames: natives });

// A button whose label is the model; a click, message 7, adds one.
const COUNTER = module(`
  (cons (lam d d)
  (cons (lam s (cons (app (native add) (cons (slot 3 s) 1)) 0))
  (cons (lam m (app (native raw-seal) (cons %button (cons (app (native scot) (cons %ud m)) 7))))
  (lam m 0))))`);

// A store whose state adds each %add's payload.
const CART = module(`
  (cons 0 (lam a (app (native add) (cons (slot 3 a) (slot 3 (slot 2 a))))))`);

// An island watching the cart store: a click pokes it with [%add 1], and
// each fact, [%got state], becomes the model.
const BASKET = module(`
  (cons (lam d 0)
  (cons (lam s
    (if (cell? (slot 2 s))
      (cons (slot 3 (slot 2 s)) 0)
      (if (eq (slot 2 s) 7)
        (cons (slot 3 s)
          (cons (cons %poke (cons (cons %store (cons "ui/stores/cart" (cons %add 1))) (lam e %acked))) 0))
        (cons (slot 3 s) 0))))
  (cons (lam m (app (native raw-seal) (cons %button (cons (app (native scot) (cons %ud m)) 7))))
  (lam m (cons (cons %watch (cons %store (cons "ui/stores/cart" (cons %state
    (lam r (cons (slot 3 r) (cons %got (slot 3 r)))))))) 0)))))`);

// An island whose view crashes.
const BROKEN = module(`
  (cons (lam d d) (cons (lam s (cons (slot 3 s) 0)) (cons (lam m (crash)) (lam m 0))))`);

function fakeWindow(pathname = '/apps/test') {
  const navigations = [];
  const window = {
    navigations,
    pushed: [],
    addEventListener() {},
    removeEventListener() {},
    location: {
      origin: 'https://ship.example',
      pathname,
      get href() { return `https://ship.example${this.pathname}`; },
      assign: url => navigations.push(url),
    },
    history: {
      pushState(state, title, url) {
        window.pushed.push(url);
        window.location.pathname = new URL(url, window.location.href).pathname;
      },
    },
  };
  return window;
}

function page({ islands, stores = {}, sources, section }) {
  const document = createFakeDocument();
  const config = document.createElement('script');
  config.setAttribute('type', 'application/x-jibb-client');
  config.appendChild(document.createTextNode(JSON.stringify({
    base: '/apps/test', ship: '~zod', stores, assets: {}, section,
  })));
  document.body.appendChild(config);
  const containers = islands.map(({ hash, model }) => {
    const container = document.createElement('div');
    container.setAttribute('data-jibb-island', hash);
    const first = document.createElement('p');
    first.appendChild(document.createTextNode('server view'));
    container.appendChild(first);
    const state = document.createElement('script');
    state.setAttribute('type', 'application/x-jibb-state');
    state.appendChild(document.createTextNode(encodeUw(jam(model))));
    container.appendChild(state);
    document.body.appendChild(container);
    return container;
  });
  const loaded = [];
  const load = async (url) => {
    loaded.push(url);
    const hash = /\/~jibb\/m\/([^/]+)\.js$/.exec(url)?.[1];
    if (!Object.hasOwn(sources, hash)) throw new Error(`no module at ${url}`);
    return import(`data:text/javascript;base64,${Buffer.from(sources[hash]).toString('base64')}`);
  };
  return { document, containers, load, loaded };
}

const noFetch = async () => {
  throw new Error('unexpected request');
};

test('boot starts each island from the model the server rendered with', async () => {
  const { document, containers, load, loaded } = page({
    islands: [{ hash: '0vcounter', model: 41n }],
    sources: { '0vcounter': COUNTER },
  });
  const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: noFetch, uid: 'u' });
  assert.deepEqual(loaded, ['/apps/test/~jibb/m/0vcounter.js']);
  const [container] = containers;
  // The island's own view replaced the server's, state script included.
  assert.equal(container.childNodes.length, 1);
  const button = container.childNodes[0];
  assert.equal(button.localName, 'button');
  assert.equal(button.textContent, '41');
  button.dispatchEvent(new FakeEvent('click', { bubbles: true }));
  assert.equal(island.model, 42n);
  assert.equal(container.childNodes[0].textContent, '42');
});

test('a page has one store, which its islands share', async () => {
  const { document, containers, load } = page({
    islands: [{ hash: '0vbasket', model: 0n }, { hash: '0vbasket', model: 0n }],
    stores: { 'ui/stores/cart': '0vcart' },
    sources: { '0vbasket': BASKET, '0vcart': CART },
  });
  const { loaded } = { loaded: [] };
  const counting = url => { loaded.push(url); return load(url); };
  const [first, second] = await boot({ document, window: fakeWindow(), load: counting, fetchImpl: noFetch, uid: 'u' });
  // One store module and one island module, each loaded once.
  assert.deepEqual(loaded.sort(), ['/apps/test/~jibb/m/0vbasket.js', '/apps/test/~jibb/m/0vcart.js']);
  await Promise.resolve();
  assert.equal(first.model, 0n);
  containers[0].childNodes[0].dispatchEvent(new FakeEvent('click', { bubbles: true }));
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(first.model, 1n);
  assert.equal(second.model, 1n);
  assert.equal(containers[1].childNodes[0].textContent, '1');
});

test('an island that cannot start keeps the server view and shows the notice', async () => {
  const { document, containers, load } = page({
    islands: [{ hash: '0vbroken', model: 1n }, { hash: '0vmissing', model: 1n }],
    sources: { '0vbroken': BROKEN },
  });
  const started = await boot({ document, window: fakeWindow(), load, fetchImpl: noFetch, uid: 'u' });
  assert.equal(started.length, 0);
  for (const container of containers) {
    const notice = container.childNodes[0];
    assert.equal(notice.getAttribute('role'), 'alert');
    assert.equal(notice.getAttribute('data-jibb-notice'), '');
    assert.equal(notice.textContent, CRASH_NOTICE);
    assert.equal(container.childNodes[1].textContent, 'server view');
  }
});

test('an island that crashes later keeps its model and shows the notice once', async () => {
  // A click crashes update: its message is not a cell, so slot 3 fails.
  const crashing = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 (slot 2 s)) 0))
    (cons (lam m (app (native raw-seal) (cons %button (cons (app (native scot) (cons %ud m)) 7))))
    (lam m 0))))`);
  const { document, containers, load } = page({
    islands: [{ hash: '0vcrash', model: 5n }],
    sources: { '0vcrash': crashing },
  });
  const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: noFetch, uid: 'u' });
  const [container] = containers;
  const button = container.childNodes[0];
  button.dispatchEvent(new FakeEvent('click', { bubbles: true }));
  button.dispatchEvent(new FakeEvent('click', { bubbles: true }));
  assert.equal(island.model, 5n);
  assert.equal(container.childNodes.length, 2);
  assert.equal(container.childNodes[0].textContent, CRASH_NOTICE);
  assert.equal(container.childNodes[1].textContent, '5');
});

test('the page configuration names the ship and the store modules', async () => {
  const { document, load } = page({
    islands: [{ hash: '0vcounter', model: 0n }],
    sources: { '0vcounter': COUNTER },
  });
  const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: noFetch, uid: 'u' });
  // %who replies with the owner's @p: ~zod is 0.
  let who;
  island.dispatchCommand([cord('who'), (ship) => { who = ship; return 0n; }]);
  assert.equal(who, 0n);
});

test('the runtime calls timers, microtasks and fetch as browsers require', async () => {
  // A browser's own functions throw "Illegal invocation" when called as
  // another object's methods; Node's do not, so these stand in for them.
  const names = ['queueMicrotask', 'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval', 'fetch'];
  const saved = Object.fromEntries(names.map(name => [name, globalThis[name]]));
  for (const name of names) {
    const original = saved[name];
    globalThis[name] = function strict(...args) {
      if (this !== undefined && this !== globalThis) throw new TypeError(`Illegal invocation of ${name}`);
      return original === undefined ? undefined : original.apply(globalThis, args);
    };
  }
  try {
    const { document, containers, load } = page({
      islands: [{ hash: '0vbasket', model: 0n }],
      stores: { 'ui/stores/cart': '0vcart' },
      sources: { '0vbasket': BASKET, '0vcart': CART },
    });
    const [island] = await boot({ document, window: fakeWindow(), load, uid: 'u' });
    await new Promise(resolve => saved.setTimeout(resolve, 0));
    containers[0].childNodes[0].dispatchEvent(new FakeEvent('click', { bubbles: true }));
    await new Promise(resolve => saved.setTimeout(resolve, 0));
    assert.equal(island.model, 1n);
  } finally {
    Object.assign(globalThis, saved);
  }
});

// An app: its model is the path within its section, which %url gives it,
// and its view links within the section and out of it.
const ROUTER = module(`
  (cons (lam d d)
  (cons (lam s (cons (slot 3 (slot 2 s)) 0))
  (cons (lam m (app (native raw-seal) (cons %column (cons 0
    (cons (app (native raw-seal) (cons %link (cons (cons ~.app (cons ~.two 0)) "Two")))
    (cons (app (native raw-seal) (cons %link (cons (cons ~.about 0) "Away"))) 0))))))
  (lam m (cons (cons %url (lam p (cons %moved p))) 0)))))`);

test('an app\'s links within its section change the address, and %url the path', async () => {
  const window = fakeWindow('/apps/test/app/one');
  const { document, containers, load } = page({
    islands: [{ hash: '0vrouter', model: [cord('one'), 0n] }],
    sources: { '0vrouter': ROUTER },
    section: '/app',
  });
  const [island] = await boot({ document, window, load, fetchImpl: noFetch, uid: 'u' });
  await Promise.resolve();
  // %url gives the path within the section: /app/one is /one.
  assert.deepEqual(island.model, [cord('one'), 0n]);
  const [inside, outside] = containers[0].childNodes[0].childNodes;
  assert.equal(inside.getAttribute('href'), '/apps/test/app/two');
  const click = new FakeEvent('click', { bubbles: true });
  inside.dispatchEvent(click);
  assert.equal(click.defaultPrevented, true);
  assert.deepEqual(window.pushed, ['/apps/test/app/two']);
  assert.deepEqual(island.model, [cord('two'), 0n]);
  // A link out of the section is the browser's to follow.
  const away = new FakeEvent('click', { bubbles: true });
  outside.dispatchEvent(away);
  assert.equal(away.defaultPrevented, false);
  assert.deepEqual(window.pushed, ['/apps/test/app/two']);
});
