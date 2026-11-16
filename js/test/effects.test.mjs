import test from 'node:test';
import assert from 'node:assert/strict';
import { createFakeDocument } from './fake-dom.mjs';
import { startIsland } from '../browser/island.mjs';
import { dateFromMilliseconds, Effects } from '../browser/effects.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';
import { MockChannel } from './runtime-page.mjs';

const textElement = (value) => rawSeal([cord('text'), cord(String(value))]);

function agentRequest(receive) {
  return [
    cord('agent'),
    [cord('api'),
      [cord('state'),
        [cord('counter'),
          [arrayToList([cord('state')]),
            [0n, receive]]]]],
  ];
}

function setup({ subs, receive, now = () => 42n, navigate, ...options } = {}) {
  const document = createFakeDocument();
  const program = {
    init: () => 0n,
    update: ([message, model]) => [message, 0n],
    view: (model) => textElement(model),
    subs: subs ?? (() => 0n),
  };
  const island = startIsland({ program, document, container: document.body });
  const channel = new MockChannel();
  const effects = new Effects({ island, channel, now, navigate, ...options });
  return { document, island, channel, effects };
}

test('watch facts apply stateful folds, acknowledge, and preserve request ids', () => {
  const states = [];
  const receive = ([mark, [state, fact]]) => {
    states.push(state);
    return [(state === 0n ? 0n : state[1]) + fact, fact];
  };
  const watch = [cord('watch'), agentRequest(receive)];
  const { channel, island, effects } = setup({ subs: () => arrayToList([watch]) });
  const id = channel.subscriptions[0][0];
  assert.equal(channel.subscriptions[0][2], cord('counter'));
  channel.onFact(id, cord('state'), 40n, 7n);
  assert.equal(island.model, 40n);
  channel.onFact(id, cord('state'), 2n, 8n);
  assert.equal(island.model, 2n);
  assert.deepEqual(channel.acks, [7n, 8n]);
  // The receiver gets ~ first, then the state it returned, as a unit.
  assert.deepEqual(states, [0n, [0n, 40n]]);
  effects.stop();
});

test('watch removal unsubscribes and kicks reseed from first state', () => {
  const receive = ([mark, [state, fact]]) => {
    const previous = state === 0n ? 0n : state[1];
    return [previous + fact, previous + fact];
  };
  const watch = [cord('watch'), agentRequest(receive)];
  let enabled = true;
  const timers = [];
  const { channel, island } = setup({
    subs: () => enabled ? arrayToList([watch]) : 0n,
    setTimer: (fn, ms) => timers.push([fn, ms]),
  });
  const id = channel.subscriptions[0][0];
  channel.onFact(id, cord('state'), 40n, 1n);
  channel.onFact(id, cord('state'), 2n, 2n);
  assert.equal(island.model, 42n);
  channel.onKick(id, [cord('ok'), 0n]);
  // The watch starts again a second later, under a fresh request id, and
  // its receiver starts again from ~.
  assert.equal(channel.subscriptions.length, 1);
  assert.deepEqual(timers.map(([, ms]) => ms), [1000]);
  timers.shift()[0]();
  const again = channel.subscriptions.at(-1)[0];
  assert.notEqual(again, id);
  channel.onFact(id, cord('state'), 7n, 3n);
  assert.equal(island.model, 42n, 'the kicked subscription has no more facts');
  channel.onFact(again, cord('state'), 5n, 4n);
  assert.equal(island.model, 5n);
  enabled = false;
  island.send(9n);
  assert.deepEqual(channel.unsubscriptions.map(request => request[1]), [again]);
});

test('intervals, one-shot waits, now, who, and go use their transports', () => {
  const timers = [];
  const intervals = [];
  const cleared = [];
  const navigations = [];
  const messages = [];
  const every = [cord('every'), [1n << 64n, (time) => [cord('tick'), time]]];
  const { island, effects } = setup({
    subs: () => arrayToList([every]),
    now: () => 42n,
    setTimer: (fn, ms) => { timers.push([fn, ms]); return timers.length; },
    clearTimer: (id) => cleared.push(id),
    setInterval: (fn, ms) => { intervals.push([fn, ms]); return intervals.length; },
    clearInterval: (id) => cleared.push(id),
    navigate: (url) => navigations.push(url),
  });
  island.program.update = ([message, model]) => {
    messages.push(message);
    return [model, 0n];
  };
  intervals[0][0]();
  effects.command([cord('wait'), [1n << 64n, cord('later')]]);
  timers[0][0]();
  effects.command([cord('now'), (time) => [cord('now'), time]]);
  effects.command([cord('who'), (ship) => [cord('who'), ship]]);
  effects.command([cord('go'), cord('/next')]);
  assert.equal(messages.length, 4);
  assert.equal(messages[0][0], cord('tick'));
  assert.equal(messages[0][1], 42n);
  assert.equal(messages[1], cord('later'));
  assert.equal(messages[2][0], cord('now'));
  assert.equal(messages[3][0], cord('who'));
  assert.deepEqual(navigations, ['/next']);
  effects.stop();
  assert.deepEqual(cleared, [1]);
});

test('poke replies arrive as later messages with nack text', () => {
  const replies = [];
  const { channel, island, effects } = setup();
  island.program.update = ([message, model]) => {
    replies.push(message);
    return [model, 0n];
  };
  const reply = (error) => [cord('reply'), error];
  island.dispatchCommand([
    cord('poke'),
    [[cord('agent'), [cord('counter'), [cord('action'), 42n]]], reply],
  ]);
  assert.equal(replies.length, 0);
  assert.equal(channel.pokes.length, 1);
  channel.onPokeAck(channel.pokes[0][0], [cord('ok'), 0n]);
  channel.onPokeAck(channel.pokes[0][0], [cord('ok'), 0n]);
  assert.equal(replies.length, 1);
  assert.deepEqual(replies[0][1], 0n);
  assert.equal(channel.pokes[0][4], 42n);
});

test('stop unsubscribes watches and clears intervals', () => {
  const receive = ([mark, [state, fact]]) => [state, fact];
  const watch = [cord('watch'), agentRequest(receive)];
  const every = [cord('every'), [1n << 64n, (time) => time]];
  const cleared = [];
  const { channel, effects } = setup({
    subs: () => arrayToList([watch, every]),
    setInterval: () => 99,
    clearInterval: (id) => cleared.push(id),
  });
  effects.stop();
  assert.equal(channel.unsubscriptions.length, 1);
  assert.deepEqual(cleared, [99]);
  assert.throws(() => effects.command([cord('who'), (ship) => ship]), /unsupported|stopped/);
});

test('watch refusal reports its tang and is not tried again while declared', () => {
  const receive = ([mark, [state, fact]]) => [state, fact];
  const watch = [cord('watch'), agentRequest(receive)];
  let enabled = true;
  const errors = [];
  const { channel, island, effects } = setup({ subs: () => enabled ? arrayToList([watch]) : 0n });
  island.onCrash = (error, failed) => errors.push([error, failed]);
  const id = channel.subscriptions[0][0];
  const tang = arrayToList([[cord('leaf'), arrayToList([...'refused'].map(character => BigInt(character.charCodeAt(0))))]]);
  channel.onWatchAck(id, [cord('err'), tang]);
  assert.equal(errors.length, 1);
  assert.deepEqual(errors[0][0], cord('refused'));
  assert.equal([...effects.watches.values()][0].refused, true);
  // Typing in a field, say: every update declares the watch again.
  for (let keystroke = 1n; keystroke <= 5n; keystroke += 1n) island.send(keystroke);
  assert.equal(channel.subscriptions.length, 1);
  // Stopping a refused watch sends nothing; declaring it anew tries again.
  enabled = false;
  island.send(6n);
  assert.equal(effects.watches.size, 0);
  assert.deepEqual(channel.unsubscriptions, []);
  enabled = true;
  island.send(7n);
  assert.equal(channel.subscriptions.length, 2);
});

test('dates use the Urbit epoch and binary fractional seconds', () => {
  assert.equal(dateFromMilliseconds(0), 62_167_219_200n << 64n);
  assert.equal(dateFromMilliseconds(1_000), (62_167_219_200n + 1n) << 64n);
  assert.equal(dateFromMilliseconds(1), (62_167_219_200n << 64n) | 18_446_744_073_709_551n);
});
