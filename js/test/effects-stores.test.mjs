import test from 'node:test';
import assert from 'node:assert/strict';
import { createFakeDocument } from './fake-dom.mjs';
import { startIsland } from '../browser/island.mjs';
import { Effects } from '../browser/effects.mjs';
import { StoreRegistry } from '../browser/stores.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';

const textElement = (value) => rawSeal([cord('text'), cord(String(value))]);
const storeRequest = (receive) => [
  cord('store'),
  [cord('cart'), [cord('state'), receive]],
];

function islandWithStore(registry, state = { messages: [] }) {
  const receive = ([mark, [previous, fact]]) => [fact, fact];
  const program = {
    init: () => 0n,
    update: ([message, model]) => {
      state.messages.push(message);
      return [message, 0n];
    },
    view: (model) => textElement(model),
    subs: () => arrayToList([[cord('watch'), storeRequest(receive)]]),
  };
  const document = createFakeDocument();
  const island = startIsland({ program, document, container: document.body });
  const effects = new Effects({ island, channel: {}, stores: registry });
  return { island, effects, messages: state.messages };
}

function storePoke(reply) {
  return [
    cord('poke'),
    [[cord('store'), [cord('cart'), [cord('increment'), 1n]]], reply],
  ];
}

test('two islands share a store and receive initial and subsequent full states', async () => {
  const registry = new StoreRegistry();
  registry.register({
    name: cord('cart'),
    init: 0n,
    update: ([[action, payload], state]) => state + payload,
  });
  const first = islandWithStore(registry);
  const second = islandWithStore(registry);
  await Promise.resolve();
  assert.equal(first.island.model, 0n);
  assert.equal(second.island.model, 0n);

  const replies = [];
  first.island.dispatchCommand(storePoke((error) => {
    replies.push(error);
    return 0n;
  }));
  await Promise.resolve();
  assert.equal(registry.stores.get(cord('cart')).state, 1n);
  assert.equal(second.island.model, 1n);
  assert.deepEqual(replies, [0n]);
  first.effects.stop();
  second.island.dispatchCommand(storePoke((error) => error));
  await Promise.resolve();
  assert.equal(registry.stores.get(cord('cart')).state, 2n);
  second.effects.stop();
});

test('store update crashes preserve state and return error text', async () => {
  const registry = new StoreRegistry();
  registry.register({
    name: cord('cart'),
    init: 42n,
    update: () => { throw new Error('bad action'); },
  });
  const { island, effects } = islandWithStore(registry);
  await Promise.resolve();
  assert.equal(island.model, 42n);
  const replies = [];
  island.dispatchCommand(storePoke((error) => {
    replies.push(error);
    return 0n;
  }));
  await Promise.resolve();
  assert.equal(registry.stores.get(cord('cart')).state, 42n);
  assert.equal(replies.length, 1);
  assert.deepEqual(replies[0], [0n, cord('bad action')]);
  effects.stop();
});
