import assert from 'node:assert/strict';
import test from 'node:test';

import { StoreRegistry } from '../browser/stores.mjs';
import { CoreCrash } from '../core/runtime.mjs';
import { cord } from '../natives/helpers.mjs';

function manualDefer() {
  const queue = [];
  return {
    defer: (callback) => queue.push(callback),
    flush() {
      while (queue.length !== 0) queue.shift()();
    },
  };
}

const add = ([[action, amount], state]) => {
  assert.equal(action, cord('add'));
  return state + amount;
};

test('watch defers its initial full-state fact and unwatch cancels delivery', () => {
  const deferred = manualDefer();
  const registry = new StoreRegistry(deferred);
  const initial = [cord('items'), 0n];
  registry.register({ name: 'cart', init: initial, update: add });
  const facts = [];
  const canceled = [];

  const id = registry.watch('cart', fact => facts.push(fact));
  const canceledId = registry.watch('cart', fact => canceled.push(fact));
  assert.equal(id, 1n);
  assert.equal(canceledId, 2n);
  assert.deepEqual(facts, []);

  registry.unwatch(canceledId);
  deferred.flush();
  assert.deepEqual(facts, [{ requestId: 1n, mark: 'cart', noun: initial }]);
  assert.deepEqual(canceled, []);
  assert.throws(() => registry.unwatch(canceledId), /unknown store watch: 2/);

  registry.unwatch(id);
  assert.throws(() => registry.unwatch(id), /unknown store watch: 1/);
});

test('queueMicrotask supplies the default deferred initial notification', async () => {
  const registry = new StoreRegistry();
  registry.register({ name: 'counter', init: 41n, update: add });
  const facts = [];
  const id = registry.watch('counter', fact => facts.push(fact));
  assert.deepEqual(facts, []);
  await new Promise(resolve => queueMicrotask(resolve));
  assert.deepEqual(facts, [{ requestId: id, mark: 'counter', noun: 41n }]);
});

test('multiple watchers share state and receive every successful update', () => {
  const deferred = manualDefer();
  const registry = new StoreRegistry(deferred);
  const samples = [];
  registry.register({
    name: 'counter',
    init: 10n,
    update(sample) {
      samples.push(sample);
      return add(sample);
    },
  });
  const first = [];
  const second = [];
  const firstId = registry.watch('counter', fact => first.push(fact));
  const secondId = registry.watch('counter', fact => second.push(fact));
  deferred.flush();

  assert.equal(registry.poke('counter', cord('add'), 5n), 0n);
  assert.deepEqual(samples, [[[cord('add'), 5n], 10n]]);
  assert.deepEqual(first.at(-1), { requestId: firstId, mark: 'counter', noun: 15n });
  assert.deepEqual(second.at(-1), { requestId: secondId, mark: 'counter', noun: 15n });

  registry.unwatch(firstId);
  assert.equal(registry.poke('counter', cord('add'), 0n), 0n);
  assert.equal(first.length, 2);
  assert.equal(second.length, 3);
  assert.equal(second.at(-1).noun, 15n);

  const late = [];
  const lateId = registry.watch('counter', fact => late.push(fact));
  assert.deepEqual(late, []);
  deferred.flush();
  assert.deepEqual(late, [{ requestId: lateId, mark: 'counter', noun: 15n }]);
});

test('poke replies report update crashes without changing state or notifying watchers', () => {
  const deferred = manualDefer();
  const registry = new StoreRegistry(deferred);
  registry.register({
    name: 'counter',
    init: 7n,
    update([[action, amount], state]) {
      if (action === cord('crash')) throw new CoreCrash('bad update');
      if (action === cord('error')) throw new Error('host failure');
      return state + amount;
    },
  });
  const facts = [];
  registry.watch('counter', fact => facts.push(fact));
  deferred.flush();

  assert.deepEqual(registry.poke('counter', cord('crash'), 100n), [0n, cord('bad update')]);
  assert.deepEqual(registry.poke('counter', cord('error'), 100n), [0n, cord('host failure')]);
  assert.equal(facts.length, 1);
  assert.equal(facts[0].noun, 7n);

  assert.equal(registry.poke('counter', cord('add'), 2n), 0n);
  assert.equal(facts.length, 2);
  assert.equal(facts.at(-1).noun, 9n);
});

test('unknown stores and duplicate registrations fail clearly', () => {
  const registry = new StoreRegistry({ defer: () => {} });
  assert.throws(() => registry.watch('missing', () => {}), /unknown store: missing/);
  assert.throws(() => registry.poke('missing', cord('add'), 1n), /unknown store: missing/);

  registry.register({ name: 'counter', init: 3n, update: add });
  assert.throws(
    () => registry.register({ name: 'counter', init: 99n, update: add }),
    /store already registered: counter/,
  );
  assert.equal(registry.poke('counter', cord('add'), 1n), 0n);
  assert.throws(() => registry.register({ name: 'bad', init: 0n, update: 0n }), /update must be callable/);
});

test('registries keep independent state and watch ids', () => {
  const firstQueue = manualDefer();
  const secondQueue = manualDefer();
  const first = new StoreRegistry(firstQueue);
  const second = new StoreRegistry(secondQueue);
  first.register({ name: 'counter', init: 1n, update: add });
  second.register({ name: 'counter', init: 100n, update: add });
  const firstFacts = [];
  const secondFacts = [];
  const firstId = first.watch('counter', fact => firstFacts.push(fact));
  const secondId = second.watch('counter', fact => secondFacts.push(fact));
  firstQueue.flush();
  secondQueue.flush();

  assert.equal(firstId, 1n);
  assert.equal(secondId, 1n);
  first.poke('counter', cord('add'), 4n);
  second.poke('counter', cord('add'), 7n);
  assert.deepEqual(firstFacts.map(fact => fact.noun), [1n, 5n]);
  assert.deepEqual(secondFacts.map(fact => fact.noun), [100n, 107n]);
});
