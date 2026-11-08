import test from 'node:test';
import assert from 'node:assert/strict';
import { createNativeRegistry, defineNative } from '../natives/registry.mjs';
import { isRawSeal, validateRawSeal } from '../natives/index.mjs';
import { cord, listToArray } from '../natives/helpers.mjs';

test('native registries contain exactly the requested authenticated identities', () => {
  const add = ([left, right]) => left + right;
  const sub = ([left, right]) => left - right;
  defineNative('test/add', add);
  defineNative('test/sub', sub);
  defineNative('test/raw-add.core', add);
  const registry = createNativeRegistry(['test/add', 'test/raw-add.core']);
  assert.strictEqual(registry['test/add'], add);
  assert.strictEqual(registry['test/raw-add.core'], add);
  assert.deepEqual(Object.keys(registry), ['test/add', 'test/raw-add.core']);
  assert.equal(Object.getPrototypeOf(registry), null);
  assert.equal(registry['test/add']([40n, 2n]), 42n);
  assert.throws(() => createNativeRegistry(['test/sub', 'test/missing']), /test\/missing/);
  assert.throws(() => defineNative('test/add', add), /duplicate/);
  assert.throws(() => Object.assign(registry, { 'test/add': sub }), TypeError);
});

test('checked raw primitive identities use their exact ABIs', () => {
  const registry = createNativeRegistry([
    'raw-add.core',
    'raw-trip.core',
    'raw-tuba.core',
    'raw-crip.core',
    'raw-tufa.core',
    'raw-format-knot.core',
  ]);
  assert.equal(registry['raw-add.core']([40n, 2n]), 42n);
  const utf8 = listToArray(registry['raw-trip.core'](registry['raw-crip.core']([65n, 0n])));
  assert.deepEqual(utf8, [65n]);
  const points = listToArray(registry['raw-tuba.core']([206n, [187n, 0n]]));
  assert.deepEqual(points, [955n]);
  assert.deepEqual(listToArray(registry['raw-tufa.core']([955n, 0n])), [206n, 187n]);
  assert.equal(registry['raw-format-knot.core']([cord('ud'), 42n]), cord('42'));
});

test('raw map wrappers preserve checked samples and unit results', () => {
  const registry = createNativeRegistry(['raw-map-get.core', 'raw-map-put.core']);
  const key = cord('answer');
  const map = registry['raw-map-put.core']([0n, [key, 42n]]);
  assert.deepEqual(registry['raw-map-get.core']([map, key]), [0n, 42n]);
  assert.equal(registry['raw-map-get.core']([map, cord('missing')]), 0n);
});

test('calendar, parsing, bit, and sealing identities are registered', () => {
  const registry = createNativeRegistry([
    'raw-date-pack.core',
    'raw-date-unpack.core',
    'raw-parse-atom.core',
    'raw-bit-not.core',
    'raw-seal.core',
  ]);
  assert.equal(registry['raw-date-pack.core'](registry['raw-date-unpack.core'](0n)), 0n);
  assert.deepEqual(registry['raw-parse-atom.core']([cord('ud'), cord('42')]), [0n, 42n]);
  assert.equal(registry['raw-bit-not.core']([0n, [4n, 42n]]), 37n);
  const sealed = registry['raw-seal.core'](42n);
  assert.equal(isRawSeal(sealed), true);
  assert.equal(validateRawSeal(sealed), 42n);
});

test('registered noun codecs preserve their value ABI', () => {
  const registry = createNativeRegistry(['jam', 'cue']);
  const noun = [42n, [1n, 2n]];
  assert.deepEqual(registry.cue(registry.jam(noun)), noun);
});
