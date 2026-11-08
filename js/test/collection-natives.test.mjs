import test from 'node:test';
import assert from 'node:assert/strict';

import { CoreCrash } from '../core/runtime.mjs';
import { listToArray } from '../natives/helpers.mjs';
import {
  collectionNatives,
  emptyMap,
  emptySet,
  gor,
  mapDelete,
  mapEntries,
  mapFromEntries,
  mapGet,
  mapHas,
  mapKeys,
  mapPut,
  mapRep,
  mapValues,
  mor,
  mug,
  rawMapGet,
  rawMapPut,
  setDelete,
  setFromValues,
  setHas,
  setPut,
  setRep,
  setValues,
  validateMap,
  validateSet,
} from '../natives/collections.mjs';

function throwsCore(fn, message) {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof CoreCrash);
    assert.equal(error.name, 'CoreCrash');
    if (message !== undefined) assert.match(error.message, message);
    return true;
  });
}

function mapLeaf(key, value) {
  return [[key, value], [0n, 0n]];
}

function setLeaf(value) {
  return [value, [0n, 0n]];
}

// Produced by Hoon 135 ~(gas by ...) over ~[[1 10] ... [5 50]].
function referenceMap() {
  return [
    [5n, 50n],
    [0n, [
      [4n, 40n],
      [
        [[2n, 20n], [mapLeaf(1n, 10n), mapLeaf(3n, 30n)]],
        0n,
      ],
    ]],
  ];
}

// Produced by Hoon 135 (silt ~[1 2 3 4 5]).
function referenceSet() {
  return [
    5n,
    [0n, [
      4n,
      [
        [2n, [setLeaf(1n), setLeaf(3n)]],
        0n,
      ],
    ]],
  ];
}

test('mug matches known Hoon 135 atoms and cells exactly', () => {
  const examples = new Map([
    [0n, 2046756072n],
    [1n, 1901865568n],
    [42n, 1681410502n],
    [255n, 937744505n],
    [256n, 1197277890n],
    [65535n, 1913531461n],
    [65536n, 100493749n],
    [0xffffffn, 2095306694n],
    [0x1000000n, 486012269n],
    [0x12345678n, 3566001n],
    [1681410502n, 1763956467n],
  ]);
  for (const [input, expected] of examples) assert.equal(mug(input), expected);

  assert.equal(mug([1n, 2n]), 1781973465n);
  assert.equal(mug([[1n, 2n], 3n]), 797794207n);
  assert.equal(mug([0n, 0n]), 422532488n);
  assert.equal(mug([1n, 0n]), 1155845783n);
  assert.equal(mug([0n, 1n]), 379659067n);
  assert.equal(mug(mug(42n)), 1763956467n);
});

test('mug handles deep and shared nouns without recursion or mutation', () => {
  let deep = 0n;
  for (let index = 0n; index < 3000n; index += 1n) deep = [deep, index & 1n];
  const hashed = mug(deep);
  assert.ok(hashed > 0n && hashed <= 0x7fffffffn);

  const shared = [7n, [8n, 9n]];
  assert.equal(mug([shared, shared]), mug([[7n, [8n, 9n]], [7n, [8n, 9n]]]));
  assert.deepEqual(shared, [7n, [8n, 9n]]);
});

test('gor and mor use Hoon mug and double-mug ordering with loobean results', () => {
  assert.equal(gor([1n, 2n], [1n, 3n]), 1n);
  assert.equal(gor([1n, 2n], [1n, 2n]), 0n);
  assert.equal(mor(1n, 2n), 1n);
  assert.equal(mor(2n, 1n), 0n);
  assert.equal(mor([1n, 2n], [1n, 2n]), 0n);

  for (const key of [0n, 1n, 42n, [1n, [2n, 3n]], 2n ** 300n]) {
    assert.equal(gor(key, key), 0n);
    assert.equal(mor(key, key), 0n);
  }
});

test('map construction reproduces the exact Hoon treap, tap, key, and val nouns', () => {
  const entries = [[1n, 10n], [2n, 20n], [3n, 30n], [4n, 40n], [5n, 50n]];
  const map = mapFromEntries(entries);
  assert.deepEqual(map, referenceMap());
  assert.strictEqual(validateMap(map), map);

  assert.deepEqual(listToArray(mapEntries(map)), [
    [4n, 40n], [3n, 30n], [2n, 20n], [1n, 10n], [5n, 50n],
  ]);
  assert.deepEqual(listToArray(mapValues(map)), [40n, 30n, 20n, 10n, 50n]);
  const keys = mapKeys(map);
  assert.deepEqual(keys, referenceSet());
  assert.strictEqual(validateSet(keys), keys);
});

test('set construction reproduces the exact Hoon treap and tap noun', () => {
  const set = setFromValues([1n, 2n, 3n, 4n, 5n]);
  assert.deepEqual(set, referenceSet());
  assert.strictEqual(validateSet(set), set);
  assert.deepEqual(listToArray(setValues(set)), [4n, 3n, 2n, 1n, 5n]);
  assert.deepEqual(emptyMap, 0n);
  assert.deepEqual(emptySet, 0n);
  assert.deepEqual(mapFromEntries([]), 0n);
  assert.deepEqual(setFromValues([]), 0n);
});

test('map delete and reinsert match the known Hoon nouns', () => {
  const map = referenceMap();
  const deleted = mapDelete(map, 3n);
  const expectedDeleted = [
    [5n, 50n],
    [0n, [
      [4n, 40n],
      [
        [[2n, 20n], [mapLeaf(1n, 10n), 0n]],
        0n,
      ],
    ]],
  ];
  assert.deepEqual(deleted, expectedDeleted);

  const reinserted = mapPut(deleted, 3n, 99n);
  const expected = referenceMap();
  expected[1][1][1][0][1][1] = mapLeaf(3n, 99n);
  assert.deepEqual(reinserted, expected);
  assert.deepEqual(map, referenceMap());
  assert.strictEqual(mapDelete(map, 999n), map);
});

test('map get and has return units and loobeans for arbitrary noun keys', () => {
  const keys = [
    0n,
    2n ** 4096n + 77n,
    [1n, 2n],
    [[1n, 0n], [2n, [3n, 4n]]],
    [0n, [0n, 0n]],
  ];
  const map = mapFromEntries(keys.map((key, index) => [key, BigInt(index + 10)]));
  for (const [index, key] of keys.entries()) {
    assert.deepEqual(mapGet(map, key), [0n, BigInt(index + 10)]);
    assert.equal(mapHas(map, key), 0n);
  }
  assert.deepEqual(mapGet(map, [999n, 0n]), 0n);
  assert.equal(mapHas(map, [999n, 0n]), 1n);
  assert.deepEqual(mapGet(0n, 0n), 0n);
  assert.equal(mapHas(0n, 0n), 1n);
});

test('map updates are persistent, share untouched paths, and replace values', () => {
  const original = referenceMap();
  const snapshot = structuredClone(original);
  const updated = mapPut(original, 1n, 11n);

  assert.deepEqual(original, snapshot);
  assert.notStrictEqual(updated, original);
  assert.notStrictEqual(updated[1][1], original[1][1]);
  assert.strictEqual(updated[1][1][0], original[1][1][0]);
  const originalTwo = original[1][1][1][0];
  const updatedTwo = updated[1][1][1][0];
  assert.notStrictEqual(updatedTwo, originalTwo);
  assert.strictEqual(updatedTwo[1][1], originalTwo[1][1]);
  assert.deepEqual(mapGet(updated, 1n), [0n, 11n]);
  assert.deepEqual(mapGet(original, 1n), [0n, 10n]);
  assert.strictEqual(mapPut(original, 1n, 10n), original);

  const added = mapPut(original, 99n, [7n, 8n]);
  assert.deepEqual(original, snapshot);
  assert.deepEqual(mapGet(added, 99n), [0n, [7n, 8n]]);
  assert.deepEqual(mapGet(original, 99n), 0n);
});

test('set insertion and deletion are persistent and preserve unrelated versions', () => {
  const original = referenceSet();
  const snapshot = structuredClone(original);
  const added = setPut(original, 99n);
  const removed = setDelete(original, 3n);

  assert.deepEqual(original, snapshot);
  assert.equal(setHas(added, 99n), 0n);
  assert.equal(setHas(original, 99n), 1n);
  assert.equal(setHas(removed, 3n), 1n);
  assert.equal(setHas(original, 3n), 0n);
  assert.strictEqual(setPut(original, 3n), original);
  assert.strictEqual(setDelete(original, 999n), original);
  validateSet(added);
  validateSet(removed);
});

test('map values may contain Core functions without weakening key checks', () => {
  const fn = (value) => value;
  const value = [fn, [0n, fn]];
  const map = mapPut(0n, [1n, 2n], value);
  validateMap(map);
  const found = mapGet(map, [1n, 2n]);
  assert.strictEqual(found[1], value);
  assert.strictEqual(mapRep(map, 0n, ([entry, count]) => {
    assert.strictEqual(entry[1], value);
    return count + 1n;
  }), 1n);
  assert.strictEqual(listToArray(mapValues(map))[0], value);
  assert.strictEqual(mapPut(map, [1n, 2n], value), map);
});

test('keys and compared nouns reject functions recursively', () => {
  const fn = () => 0n;
  const badKeys = [fn, [0n, fn], [[0n, 0n], [1n, [fn, 2n]]]];
  for (const key of badKeys) {
    throwsCore(() => mug(key), /functions/);
    throwsCore(() => gor(key, 0n), /functions/);
    throwsCore(() => mor(0n, key), /functions/);
    throwsCore(() => mapFromEntries([[key, 0n]]), /functions/);
    throwsCore(() => setFromValues([key]), /functions/);
    throwsCore(() => mapPut(0n, key, 0n), /functions/);
    throwsCore(() => mapGet(0n, key), /functions/);
    throwsCore(() => mapHas(0n, key), /functions/);
    throwsCore(() => mapDelete(0n, key), /functions/);
    throwsCore(() => setPut(0n, key), /functions/);
    throwsCore(() => setHas(0n, key), /functions/);
    throwsCore(() => setDelete(0n, key), /functions/);
  }

  throwsCore(() => validateMap([[fn, 0n], [0n, 0n]]), /functions/);
  throwsCore(() => validateMap([[[0n, fn], 0n], [0n, 0n]]), /functions/);
  throwsCore(() => validateSet([[0n, fn], [0n, 0n]]), /functions/);
});

test('malformed nouns and cyclic data crash instead of being coerced', () => {
  const malformed = [undefined, null, true, 0, 1.5, '0', -1n, {}, [], [0n], [0n, 0n, 0n]];
  for (const value of malformed) {
    throwsCore(() => mug(value));
    throwsCore(() => mapPut(0n, value, 0n));
    throwsCore(() => mapPut(0n, 0n, value));
    throwsCore(() => setPut(0n, value));
  }

  const cyclicKey = [0n, 0n];
  cyclicKey[1] = cyclicKey;
  throwsCore(() => mug(cyclicKey), /cyclic/);
  throwsCore(() => mapPut(0n, cyclicKey, 0n), /cyclic/);

  const cyclicValue = [0n, 0n];
  cyclicValue[0] = cyclicValue;
  throwsCore(() => mapPut(0n, 0n, cyclicValue), /cyclic/);

  const cyclicTree = [0n, [0n, 0n]];
  cyclicTree[1][0] = cyclicTree;
  throwsCore(() => validateSet(cyclicTree), /cyclic/);
  throwsCore(() => setHas(cyclicTree, 0n), /cyclic/);
});

test('map and set validators reject malformed tree and entry shapes', () => {
  const badMaps = [
    1n,
    [],
    [0n],
    [[0n, 0n]],
    [[0n, 0n], 0n],
    [[0n, 0n], [0n]],
    [0n, [0n, 0n]],
    [[0n], [0n, 0n]],
    [[0n, 0n, 0n], [0n, 0n]],
    [[0n, undefined], [0n, 0n]],
  ];
  for (const tree of badMaps) {
    throwsCore(() => validateMap(tree));
    throwsCore(() => mapEntries(tree));
  }

  const badSets = [1n, [], [0n], [0n, 0n], [0n, [0n]], [[0n], [0n, 0n]]];
  for (const tree of badSets) {
    throwsCore(() => validateSet(tree));
    throwsCore(() => setValues(tree));
  }
});

test('validators reject duplicate keys, wrong gor bounds, and wrong mor priority', () => {
  const duplicate = [[1n, 10n], [mapLeaf(1n, 11n), 0n]];
  throwsCore(() => validateMap(duplicate), /bound|priority/);
  throwsCore(() => validateSet([1n, [setLeaf(1n), 0n]]), /bound|priority/);

  const wrongBound = [[5n, 50n], [0n, mapLeaf(6n, 60n)]];
  throwsCore(() => validateMap(wrongBound), /bound|priority/);

  let child = 1n;
  while (!(gor(0n, child) === 0n && mor(0n, child) === 1n)) child += 1n;
  const wrongPriority = [0n, [0n, setLeaf(child)]];
  throwsCore(() => validateSet(wrongPriority), /priority/);
});

test('rep folds entries and items in Hoon root-left-right order', () => {
  const map = referenceMap();
  const mapOrder = [];
  const sum = mapRep(map, 0n, ([[key, value], accumulator]) => {
    mapOrder.push(key);
    return accumulator + key + value;
  });
  assert.deepEqual(mapOrder, [5n, 4n, 2n, 1n, 3n]);
  assert.equal(sum, 165n);
  assert.equal(mapRep(0n, 42n, () => 0n), 42n);

  const setOrder = [];
  const setSum = setRep(referenceSet(), 0n, ([value, accumulator]) => {
    setOrder.push(value);
    return accumulator + value;
  });
  assert.deepEqual(setOrder, [5n, 4n, 2n, 1n, 3n]);
  assert.equal(setSum, 15n);
  throwsCore(() => mapRep(map, 0n, null), /callable/);
  throwsCore(() => setRep(referenceSet(), 0n, 0n), /callable/);
});

test('raw Core wrappers use the checked map get and put sample shapes', () => {
  const empty = rawMapPut([0n, [1n, 10n]]);
  const map = collectionNatives['raw-map-put']([empty, [[1n, 2n], 20n]]);
  assert.deepEqual(collectionNatives['raw-map-get']([map, [1n, 2n]]), [0n, 20n]);
  assert.deepEqual(rawMapGet([map, 1n]), [0n, 10n]);
  assert.deepEqual(rawMapGet([map, 3n]), 0n);

  throwsCore(() => rawMapGet(0n));
  throwsCore(() => rawMapPut([0n, 0n]));
  throwsCore(() => rawMapPut([0n, [() => 0n, 0n]]), /functions/);
  throwsCore(() => rawMapGet([1n, 0n]));
});

test('constructors reject malformed JavaScript inputs with CoreCrash', () => {
  for (const input of [null, undefined, 'abc', 0n, {}, () => 0n]) {
    throwsCore(() => mapFromEntries(input));
    throwsCore(() => setFromValues(input));
  }
  throwsCore(() => mapFromEntries([0n]));
  throwsCore(() => mapFromEntries([[0n]]));
  throwsCore(() => mapFromEntries([[[0n], 0n]]));
});

test('frozen treaps and arbitrary large atoms remain immutable and valid', () => {
  const freezeDeep = (value) => {
    if (Array.isArray(value)) {
      freezeDeep(value[0]);
      freezeDeep(value[1]);
      Object.freeze(value);
    }
    return value;
  };
  const original = freezeDeep(mapFromEntries([
    [2n ** 1024n, 1n],
    [[2n ** 512n, [0n, 9n]], 2n],
  ]));
  const snapshot = structuredClone(original);
  const updated = mapPut(original, [2n ** 512n, [0n, 9n]], 3n);
  const deleted = mapDelete(original, 2n ** 1024n);
  assert.deepEqual(original, snapshot);
  validateMap(updated);
  validateMap(deleted);
  assert.deepEqual(mapGet(updated, [2n ** 512n, [0n, 9n]]), [0n, 3n]);
});

test('deterministic mixed updates preserve every older map and set version', () => {
  let seed = 0x12345678;
  const random = (limit) => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed % limit;
  };

  let map = 0n;
  let set = 0n;
  const mapModel = new globalThis.Map();
  const setModel = new globalThis.Set();
  const versions = [];

  for (let step = 0; step < 80; step += 1) {
    const key = BigInt(random(24));
    if (random(3) === 0) {
      map = mapDelete(map, key);
      set = setDelete(set, key);
      mapModel.delete(key);
      setModel.delete(key);
    } else {
      const value = BigInt(step);
      map = mapPut(map, key, [value, key]);
      set = setPut(set, key);
      mapModel.set(key, [value, key]);
      setModel.add(key);
    }
    validateMap(map);
    validateSet(set);
    versions.push([map, set, structuredClone(mapModel), new globalThis.Set(setModel)]);
  }

  for (const [oldMap, oldSet, oldMapModel, oldSetModel] of versions) {
    for (let key = 0n; key < 24n; key += 1n) {
      assert.deepEqual(mapGet(oldMap, key), oldMapModel.has(key) ? [0n, oldMapModel.get(key)] : 0n);
      assert.equal(mapHas(oldMap, key), oldMapModel.has(key) ? 0n : 1n);
      assert.equal(setHas(oldSet, key), oldSetModel.has(key) ? 0n : 1n);
    }
  }
});
