import test from 'node:test';
import assert from 'node:assert/strict';
import { Channel, installPagehide } from '../browser/channel.mjs';
import { Effects } from '../browser/effects.mjs';
import { startIsland } from '../browser/island.mjs';
import { StoreRegistry } from '../browser/stores.mjs';
import { CoreCrash } from '../core/runtime.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { createFakeDocument } from './fake-dom.mjs';
import { fakeEyre, MockChannel, settle } from './runtime-page.mjs';

const textElement = value => rawSeal([cord('text'), cord(String(value))]);
const agentWatch = (agent, receive) => [cord('watch'), [cord('agent'), [cord('api'), [cord('state'),
  [cord(agent), [arrayToList([cord('state')]), [0n, receive]]]]]]];
const agentPoke = (agent, reply) => [cord('poke'), [[cord('agent'), [cord(agent), [cord('mark'), 1n]]], reply]];

function mount(program, options = {}) {
  const document = options.document ?? createFakeDocument();
  const container = document.createElement('div');
  document.body.appendChild(container);
  const crashes = [];
  const island = startIsland({
    document, container, onCrash: error => crashes.push(error), ...options.island,
    program: { init: () => 0n, view: model => textElement(model), subs: () => 0n, ...program },
  });
  const effects = new Effects({ island, channel: options.channel ?? new MockChannel(), ...options.effects });
  return { document, container, island, effects, crashes };
}

test('two islands\' watches on one channel unsubscribe only their own subscriptions', async () => {
  const eyre = fakeEyre();
  const channel = new Channel('page', { fetchImpl: eyre.fetchImpl });
  const document = createFakeDocument();
  const make = (agent) => {
    let watching = true;
    const view = mount({
      update: ([message, model]) => [message, 0n],
      subs: () => (watching ? arrayToList([agentWatch(agent, ([, [, fact]]) => [fact, fact])]) : 0n),
    }, { document, channel });
    return { ...view, stop: () => { watching = false; view.island.send(1n); } };
  };
  const alpha = make('alpha');
  const beta = make('beta');
  await settle();
  const [[alphaId], [betaId]] = eyre.requests('subscribe');
  assert.notEqual(alphaId, betaId);
  beta.stop();
  await settle();
  const [[unsubscribeId, ended]] = eyre.requests('unsubscribe');
  assert.equal(ended, betaId);
  assert.ok(![alphaId, betaId].includes(unsubscribeId), 'the unsubscribe has an id of its own');
  // alpha still gets its facts; beta's id goes nowhere.
  channel.dispatchEvent(alphaId, [cord('fact'), [cord('desk'), [cord('state'), 5n]]]);
  channel.dispatchEvent(betaId, [cord('fact'), [cord('desk'), [cord('state'), 6n]]]);
  assert.equal(alpha.island.model, 5n);
  assert.equal(beta.island.model, 1n);
  alpha.stop();
  await settle();
  assert.deepEqual(eyre.requests('unsubscribe').map(([, id]) => id), [betaId, alphaId]);
});

test('a crash in subs drops the message and keeps the model, DOM and commands unsent', () => {
  const channel = new MockChannel();
  const { container, island, crashes } = mount({
    // Each message becomes the model and pokes %ledger.
    update: ([message]) => [message, arrayToList([agentPoke('ledger', () => 0n)])],
    subs: model => {
      if (model === 5n) throw new CoreCrash('subs crashed');
      return arrayToList([agentWatch(`feed${model}`, ([, [, fact]]) => [fact, fact])]);
    },
  }, { channel });
  island.send(3n);
  assert.equal(island.model, 3n);
  assert.equal(channel.pokes.length, 1);
  island.send(5n);
  assert.deepEqual(crashes.map(error => error.message), ['subs crashed']);
  assert.equal(island.model, 3n);
  assert.equal(container.textContent, '3');
  assert.equal(channel.pokes.length, 1);
  // The watch the last good subs declared is still on.
  assert.equal(channel.subscriptions.length, 2);
  assert.equal(channel.unsubscriptions.length, 1);
  assert.equal(channel.subscriptions.at(-1)[2], cord('feed3'));
});

test('the newest reply of a watch, a timer and %url is the one used', () => {
  const received = [];
  let tick;
  let path;
  const urlRuntime = {
    watch: (reply) => { path = reply; return 1n; },
    unwatch() {},
  };
  const channel = new MockChannel();
  const { island } = mount({
    init: () => 1n,
    update: ([message, model]) => {
      if (message[0] === cord('page')) return [message[1], 0n];
      received.push(message);
      return [model, 0n];
    },
    // Each reply captures the page it was made on.
    subs: model => arrayToList([
      [cord('every'), [1n << 64n, () => [cord('tick'), model]]],
      [cord('url'), () => [cord('url'), model]],
      agentWatch('feed', ([, [, fact]]) => [fact, [cord('got'), model]]),
    ]),
  }, { channel, effects: { setInterval: fn => { tick = fn; return 1; }, clearInterval() {}, urlRuntime } });
  island.send([cord('page'), 2n]);
  island.send([cord('page'), 3n]);
  tick();
  path(0n);
  channel.onFact(channel.subscriptions[0][0], cord('state'), 9n, 1n);
  assert.deepEqual(received.map(([kind, page]) => [kind, page]), [[cord('tick'), 3n], [cord('url'), 3n], [cord('got'), 3n]]);
});

test('a store watcher\'s crash is its own: the others get the state, the poker its reply', async () => {
  const stores = new StoreRegistry({ defer: callback => callback() });
  const CART = cord('ui/stores/cart');
  stores.register({ name: CART, init: 0n, update: ([[, amount], state]) => state + amount });
  const document = createFakeDocument();
  const watcher = crashOn => mount({
    update: ([message, model]) => [message === cord('replied') ? model : message, 0n],
    subs: () => arrayToList([[cord('watch'), [cord('store'), [CART, [cord('state'), ([, fact]) => {
      if (fact === crashOn) throw new CoreCrash('watcher crashed');
      return [fact, fact];
    }]]]]]),
  }, { document, effects: { stores, defer: callback => callback() } });
  const b = watcher(2n);
  const c = watcher(-1n);
  let replies = 0;
  const a = mount({
    update: ([message, model]) => (message === 1n
      ? [model, arrayToList([[cord('poke'), [[cord('store'), [CART, [cord('add'), 2n]]], () => { replies += 1; return 9n; }]]])]
      : [model, 0n]),
  }, { document, effects: { stores, defer: callback => callback() } });
  a.island.send(1n);
  assert.deepEqual(b.crashes.map(error => error.message), ['watcher crashed']);
  assert.equal(c.island.model, 2n);
  assert.deepEqual(a.crashes, []);
  assert.equal(replies, 1);
});

test('a watcher that pokes its store from its update leaves no one with an older state', () => {
  const stores = new StoreRegistry({ defer: callback => callback() });
  const CART = cord('ui/stores/cart');
  stores.register({ name: CART, init: 0n, update: ([[, amount], state]) => state + amount });
  const document = createFakeDocument();
  const poke = amount => [cord('poke'), [[cord('store'), [CART, [cord('add'), amount]]], () => cord('replied')]];
  const watching = react => mount({
    update: ([message, model]) => (Array.isArray(message) ? [message[1], react(message[1])] : [model, 0n]),
    subs: () => arrayToList([[cord('watch'), [cord('store'), [CART, [cord('state'), ([, fact]) => [fact, [cord('got'), fact]]]]]]]),
  }, { document, effects: { stores, defer: callback => callback() } });
  // The first tops the cart up by ten when it sees one item.
  const first = watching(state => (state === 1n ? arrayToList([poke(10n)]) : 0n));
  const second = watching(() => 0n);
  const poker = mount({ update: ([message, model]) => [model, message === 1n ? arrayToList([poke(1n)]) : 0n] },
    { document, effects: { stores, defer: callback => callback() } });
  poker.island.send(1n);
  assert.equal(stores.stores.get(CART).state, 11n);
  assert.equal(first.island.model, 11n);
  assert.equal(second.island.model, 11n);
});

test('waits and timers of 2^31 ms or more run through a chain of shorter timers', () => {
  const timers = [];
  const intervals = [];
  const DAY = 86_400n << 64n;
  const { island, effects } = mount({
    update: ([message, model]) => [message, 0n],
    subs: () => arrayToList([[cord('every'), [30n * DAY, () => cord('month')]]]),
  }, {
    effects: {
      setTimer: (fn, ms) => timers.push([fn, ms]),
      setInterval: (fn, ms) => intervals.push([fn, ms]),
      now: () => 0n,
    },
  });
  effects.command([cord('wait'), [30n * DAY, cord('reminder')]]);
  const longest = 2 ** 31 - 1;
  const thirty = 30 * 86_400_000;
  assert.deepEqual(intervals, [], 'no interval: its delay would overflow');
  assert.deepEqual(timers.map(([, ms]) => ms), [longest, longest]);
  // The every's chain and the wait's each take two timers to come due.
  timers.shift()[0]();
  timers.shift()[0]();
  assert.deepEqual(timers.map(([, ms]) => ms), [thirty - longest, thirty - longest]);
  assert.equal(island.model, 0n);
  timers.shift()[0]();
  assert.equal(island.model, cord('month'));
  timers.shift()[0]();
  assert.equal(island.model, cord('reminder'));
  // The every starts its next period.
  assert.deepEqual(timers.map(([, ms]) => ms), [longest]);
  effects.stop();
  timers.shift()[0]();
  assert.deepEqual(timers, []);
});

test('a poke whose PUT fails gets an error reply, and a failed subscribe counts as refused', async () => {
  const rejections = [];
  const onRejection = error => rejections.push(error);
  process.on('unhandledRejection', onRejection);
  try {
    const eyre = fakeEyre({ put: () => 403 });
    const channel = new Channel('u', { fetchImpl: eyre.fetchImpl });
    const replies = [];
    const { island, effects, crashes } = mount({
      update: ([message, model]) => {
        if (message === 1n) return [model, arrayToList([agentPoke('ledger', error => [cord('reply'), error])])];
        if (Array.isArray(message)) replies.push(message[1]);
        return [model, 0n];
      },
      subs: () => arrayToList([agentWatch('private', ([, [, fact]]) => [fact, fact])]),
    }, { channel });
    await settle();
    assert.equal(crashes.length, 1, 'the refused watch shows the notice');
    assert.equal([...effects.watches.values()][0].refused, true);
    island.send(1n);
    await settle();
    assert.deepEqual(replies, [[0n, cord('Eyre channel HTTP 403 Forbidden')]]);
    assert.equal(effects.pokes.size, 0);
    island.send(2n);
    await settle();
    assert.equal(eyre.requests('subscribe').length, 1, 'not tried again on the next update');
    // Acks that fail are dropped too.
    effects.onFact(99n, cord('state'), 0n, 7n);
    await settle();
    assert.deepEqual(rejections, []);
  } finally {
    process.off('unhandledRejection', onRejection);
  }
});

test('a hidden page\'s DELETE goes at once, with keepalive, and PUTs still queued then never go', async () => {
  const sent = [];
  let release;
  const fetchImpl = (url, init) => {
    sent.push([url, init.keepalive === true]);
    // The first PUT is slow, so the second waits behind it.
    return sent.length === 1 ? new Promise(resolve => { release = () => resolve({ ok: true, status: 204 }); })
      : Promise.resolve({ ok: true, status: 204 });
  };
  const listeners = {};
  const target = { addEventListener: (type, fn) => { listeners[type] = fn; }, removeEventListener() {} };
  const channel = new Channel('page', { fetchImpl });
  let restored = 0;
  installPagehide(channel, target, () => { restored += 1; });
  const first = channel.poke(1n, 0n, cord('app'), cord('mark'), 1n);
  const queued = channel.poke(2n, 0n, cord('app'), cord('mark'), 2n);
  await Promise.resolve();
  listeners.pagehide({ persisted: true });
  assert.deepEqual(sent.map(([, keepalive]) => keepalive), [false, true]);
  release();
  await first;
  await assert.rejects(queued, /closed/);
  assert.equal(sent.length, 2, 'the queued poke never went');
  // Shown again, it is a fresh channel that sends again.
  listeners.pageshow({ persisted: false });
  assert.equal(restored, 0);
  listeners.pageshow({ persisted: true });
  assert.equal(restored, 1);
  assert.equal(channel.closed, false);
  await channel.poke(3n, 0n, cord('app'), cord('mark'), 3n);
  assert.equal(sent.length, 3);
  assert.notEqual(sent[2][0], sent[0][0]);
});
