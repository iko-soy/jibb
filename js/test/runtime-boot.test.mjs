import test from 'node:test';
import assert from 'node:assert/strict';
import { boot, CRASH_NOTICE } from '../browser/boot.mjs';
import { cord } from '../natives/helpers.mjs';
import { fakeEyre, fakeWindow, module, page, settle } from './runtime-page.mjs';

// An island watching AGENT's /state: its model is [fact acks], the last
// fact and how many pokes were acked; a click pokes AGENT.
const watcher = agent => module(`
  (cons (lam d d)
  (cons (lam s
    (if (cell? (slot 2 s))
      (if (eq (slot 2 (slot 2 s)) %got)
        (cons (cons (slot 3 (slot 2 s)) (slot 7 s)) 0)
        (cons (cons (slot 6 s) (app (native add) (cons (slot 7 s) 1))) 0))
      (cons (slot 3 s) (cons (cons %poke (cons (cons %agent (cons %${agent} (cons %mark 1))) (lam e (cons %acked e)))) 0))))
  (cons (lam m (app (native raw-seal) (cons %button (cons (app (native scot) (cons %ud (slot 2 m))) 7))))
  (lam m (cons (cons %watch (cons %agent (cons %api (cons %state (cons %${agent} (cons (cons %state 0) (cons 0
    (lam r (cons (slot 7 r) (cons %got (slot 7 r))))))))))) 0)))))`);

// A button whose label is the model; a click adds one.
const COUNTER = module(`
  (cons (lam d d)
  (cons (lam s (cons (app (native add) (cons (slot 3 s) 1)) 0))
  (cons (lam m (app (native raw-seal) (cons %button (cons (app (native scot) (cons %ud m)) 7))))
  (lam m 0))))`);

const quiet = { wait: async () => {} };

test('islands on one page take request ids from its channel and get only their own events', async () => {
  const { document, containers, load } = page({
    islands: [{ hash: '0va', model: [0n, 0n] }, { hash: '0vb', model: [0n, 0n] }],
    sources: { '0va': watcher('alpha'), '0vb': watcher('beta') },
  });
  const eyre = fakeEyre();
  const [a, b] = await boot({ document, window: fakeWindow(), load, fetchImpl: eyre.fetchImpl, uid: 'u', ...quiet });
  await settle();
  const subscriptions = eyre.requests('subscribe');
  assert.deepEqual(subscriptions.map(([, [, [agent]]]) => agent), [cord('alpha'), cord('beta')]);
  const [alpha, beta] = subscriptions.map(([id]) => id);
  assert.notEqual(alpha, beta);

  eyre.fact(1, alpha, 'state', 11n);
  eyre.fact(2, beta, 'state', 22n);
  await settle();
  assert.deepEqual([a.model, b.model], [[11n, 0n], [22n, 0n]]);
  assert.deepEqual(containers.map(container => container.textContent), ['11', '22']);

  // Each poke has an id of its own, and its ack goes to the island that sent it.
  containers[1].firstChild.click();
  containers[0].firstChild.click();
  await settle();
  const pokes = eyre.requests('poke');
  assert.deepEqual(pokes.map(([, [, [app]]]) => app), [cord('beta'), cord('alpha')]);
  const ids = [alpha, beta, ...pokes.map(([id]) => id)];
  assert.equal(new Set(ids).size, ids.length);
  eyre.pokeAck(3, pokes[1][0]);
  await settle();
  assert.deepEqual([a.model, b.model], [[11n, 1n], [22n, 0n]]);
  eyre.pokeAck(4, pokes[0][0]);
  eyre.fact(5, alpha, 'state', 12n);
  await settle();
  assert.deepEqual([a.model, b.model], [[12n, 1n], [22n, 1n]]);
});

test('one island\'s failure to start, its first subs crashing or its store missing, leaves the others running', async () => {
  // Subs crashes on the first model, as a (snag 0 ~) in it would.
  const FRAGILE = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) 0))
    (cons (lam m (app (native raw-seal) (cons %text "fragile")))
    (lam m (crash)))))`);
  // Watches a store whose module doesn't load.
  const STORED = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) 0))
    (cons (lam m (app (native raw-seal) (cons %text "stored")))
    (lam m (cons (cons %watch (cons %store (cons "ui/stores/gone" (cons %state (lam r (cons (slot 3 r) 0)))))) 0)))))`);
  const { document, containers, load } = page({
    islands: [{ hash: '0vfragile', model: 0n }, { hash: '0vstored', model: 0n }, { hash: '0vcounter', model: 41n }],
    stores: { 'ui/stores/gone': '0vgone' },
    sources: { '0vfragile': FRAGILE, '0vstored': STORED, '0vcounter': COUNTER },
  });
  const started = await boot({ document, window: fakeWindow(), load, fetchImpl: fakeEyre().fetchImpl, uid: 'u' });
  assert.equal(started.length, 3);
  for (const container of containers.slice(0, 2)) {
    assert.equal(container.firstChild.textContent, CRASH_NOTICE);
  }
  const counter = containers[2];
  assert.equal(counter.querySelector('[data-jibb-notice]'), null);
  assert.equal(counter.querySelector('script[type="application/x-jibb-state"]'), null);
  counter.firstChild.click();
  assert.equal(started[2].model, 42n);
  assert.equal(counter.textContent, '42');
});

test('the server\'s whole view is replaced when the HTML parser split it', async () => {
  // <p>Status: <div …>offline</div></p> parses as <p>Status: </p><div>offline</div><p></p>.
  const VIEW = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) 0))
    (cons (lam m (app (native raw-seal) (cons %para (cons (app (native raw-seal) (cons %text "Status: "))
      (cons (app (native raw-seal) (cons %el (cons (cons (cons %tone %danger) 0) (app (native raw-seal) (cons %text "offline"))))) 0)))))
    (lam m 0))))`);
  const split = (document) => {
    const before = document.createElement('p');
    before.appendChild(document.createTextNode('Status: '));
    const hoisted = document.createElement('div');
    hoisted.setAttribute('class', 'j-el j-tone-danger');
    hoisted.setAttribute('aria-live', 'polite');
    hoisted.appendChild(document.createTextNode('offline'));
    return [before, hoisted, document.createElement('p')];
  };
  const { document, containers, load } = page({
    islands: [{ hash: '0vview', model: 0n, server: split }],
    sources: { '0vview': VIEW },
  });
  const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: fakeEyre().fetchImpl, uid: 'u' });
  const [container] = containers;
  assert.equal(island.active, true);
  assert.equal(container.childNodes.length, 1);
  assert.strictEqual(container.firstChild, island.node);
  assert.equal(container.textContent, 'Status: offline');
});

test('go follows only the targets the server would link, in and out of an app\'s section', async () => {
  const GO = url => module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) (cons (cons %go ${JSON.stringify(url)}) 0)))
    (cons (lam m (app (native raw-seal) (cons %button (cons "go" 7))))
    (lam m 0))))`);
  for (const section of [undefined, '/app']) {
    for (const [url, followed] of [
      ['javascript:alert(document.cookie)', false], ['//evil.example/login', false],
      ['/\\evil.example', false], ['http://plain.example', false], ['data:text/html,x', false],
      [' /apps/test/app/x', false], ['/apps/test/app/next', true], ['https://docs.example', true],
    ]) {
      const { document, containers, load } = page({ islands: [{ hash: '0vg', model: 0n }], sources: { '0vg': GO(url) }, section });
      const window = fakeWindow(section ? '/apps/test/app' : '/apps/test');
      await boot({ document, window, load, fetchImpl: fakeEyre().fetchImpl, uid: 'u' });
      containers[0].firstChild.click();
      const went = [...window.navigations, ...window.pushed];
      assert.deepEqual(went, followed ? [url] : [], `${section} ${url}`);
    }
  }
});

test('a bad fact crashes its receiver, which counts as a crashed update, and the stream goes on', async () => {
  // The receiver crashes on 13, as a generated validator does on a bad fact.
  const WATCHER = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 2 s) 0))
    (cons (lam m (app (native raw-seal) (cons %text (app (native scot) (cons %ud m)))))
    (lam m (cons (cons %watch (cons %agent (cons %api (cons %state (cons %alpha (cons (cons %state 0) (cons 0
      (lam r (if (eq (slot 7 r) 13) (crash) (cons (slot 7 r) (slot 7 r))))))))))) 0)))))`);
  const { document, containers, load } = page({ islands: [{ hash: '0va', model: 0n }], sources: { '0va': WATCHER } });
  const eyre = fakeEyre();
  const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: eyre.fetchImpl, uid: 'u', ...quiet });
  await settle();
  const [[id]] = eyre.requests('subscribe');
  eyre.send(eyre.factFrame(1, id, 'state', 13n) + eyre.factFrame(2, id, 'state', 21n));
  await settle();
  assert.equal(containers[0].firstChild.textContent, CRASH_NOTICE);
  assert.equal(island.model, 21n);
  assert.equal(eyre.gets.length, 1, 'the event stream stays open');
  assert.deepEqual(eyre.requests('ack'), [1n, 2n]);
});

test('a channel Eyre no longer has stops the islands and their timers', async () => {
  // A clock: every second it pokes %clock.
  const CLOCK = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) (cons (cons %poke (cons (cons %agent (cons %clock (cons %tick 1))) (lam e 0))) 0)))
    (cons (lam m (app (native raw-seal) (cons %button (cons "clock" 7))))
    (lam m (cons (cons %every (cons ~s1 (lam t 1))) 0)))))`);
  const { document, containers, load } = page({ islands: [{ hash: '0vclock', model: 0n }], sources: { '0vclock': CLOCK } });
  const saved = { setInterval: globalThis.setInterval, clearInterval: globalThis.clearInterval };
  const intervals = new Map();
  globalThis.setInterval = (fn, ms) => { intervals.set(intervals.size + 1, fn); return intervals.size; };
  globalThis.clearInterval = handle => intervals.delete(handle);
  try {
    const eyre = fakeEyre({ get: () => 404 });
    const [island] = await boot({ document, window: fakeWindow(), load, fetchImpl: eyre.fetchImpl, uid: 'u', ...quiet });
    assert.equal(intervals.size, 1);
    [...intervals.values()][0]();
    await settle();
    assert.equal(eyre.gets.length, 1);
    assert.equal(island.active, false);
    assert.equal(containers[0].firstChild.textContent, CRASH_NOTICE);
    assert.equal(intervals.size, 0, 'the island\'s interval is cleared');
    assert.equal(eyre.requests('unsubscribe').length, 0);
  } finally {
    Object.assign(globalThis, saved);
  }
});

test('the event stream reopens after a delay that starts over once a stream opened', async () => {
  const POKER = module(`
    (cons (lam d d)
    (cons (lam s (cons (slot 3 s) (cons (cons %poke (cons (cons %agent (cons %app (cons %mark 1))) (lam e 0))) 0)))
    (cons (lam m (app (native raw-seal) (cons %button (cons "go" 7))))
    (lam m 0))))`);
  // Each GET fails (a 502), opens and then breaks, or opens and ends at
  // once, in this order; then the channel is gone.
  const answers = [502, 502, 'broken', 'empty', 'empty'];
  const streams = {
    empty: { ok: true, status: 200, body: { async *[Symbol.asyncIterator]() {} } },
    broken: { ok: true, status: 200, body: { async *[Symbol.asyncIterator]() { throw new Error('reset'); } } },
  };
  const eyre = fakeEyre({ get: () => { const next = answers.shift(); return streams[next] ?? next ?? 404; } });
  const delays = [];
  const wait = async (ms) => { delays.push(ms); };
  const { document, containers, load } = page({ islands: [{ hash: '0vp', model: 0n }], sources: { '0vp': POKER } });
  await boot({ document, window: fakeWindow(), load, fetchImpl: eyre.fetchImpl, uid: 'u', wait });
  containers[0].firstChild.click();
  await settle(20);
  assert.equal(eyre.gets.length, 6);
  assert.deepEqual(delays, [1000, 2000, 1000, 1000, 1000]);
});

test('a page shown again from the back/forward cache gets a fresh channel and watches again', async () => {
  const { document, containers, load } = page({
    islands: [{ hash: '0va', model: [0n, 0n] }],
    sources: { '0va': watcher('alpha') },
  });
  const eyre = fakeEyre();
  const window = fakeWindow();
  const [island] = await boot({ document, window, load, fetchImpl: eyre.fetchImpl, uid: 'first', ...quiet });
  await settle();
  containers[0].firstChild.click();
  await settle();
  window.dispatch('pagehide', { persisted: true });
  await settle();
  const hidden = eyre.puts.at(-1);
  assert.deepEqual(hidden.shown, ['[%delete 0]']);
  assert.equal(hidden.keepalive, true);
  assert.match(hidden.url, /\/first$/);

  window.dispatch('pageshow', { persisted: true });
  await settle();
  // The unacknowledged poke gets an error; the watch starts on the new channel.
  assert.deepEqual(island.model, [0n, 1n]);
  const again = eyre.puts.at(-1);
  assert.doesNotMatch(again.url, /\/first$/);
  assert.equal(again.shown.length, 1);
  assert.match(again.shown[0], /^\[%subscribe /);
  assert.equal(eyre.gets.length, 2);
  assert.equal(eyre.gets[1].url, again.url);
  const [, [id]] = again.requests[0];
  eyre.fact(1, id, 'state', 5n);
  await settle();
  assert.deepEqual(island.model, [5n, 1n]);
});
