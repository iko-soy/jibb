import assert from 'node:assert/strict';
import test from 'node:test';

import { CoreCrash } from '../core/runtime.mjs';
import { arrayToList, listToArray } from '../natives/helpers.mjs';
import {
  lent,
  turn,
  flop,
  snag,
  scag,
  slag,
  gulf,
  oust,
  swag,
  snap,
  into,
  skid,
  fand,
  find,
  spin,
  sqt,
  roll,
  zing,
  lead,
  late,
  succ,
  fall,
  flit,
  biff,
  bind,
  bond,
  both,
  clap,
  clef,
  drop,
  mate,
  need,
  some,
} from '../natives/list.mjs';

function throwsCore(fn, message) {
  assert.throws(fn, error => {
    assert.ok(error instanceof CoreCrash);
    assert.equal(error.name, 'CoreCrash');
    if (message !== undefined) assert.match(error.message, message);
    return true;
  });
}

function list(...items) {
  return arrayToList(items);
}

function items(value) {
  return listToArray(value);
}

function range(length) {
  return Array.from({ length }, (_, index) => BigInt(index));
}

function sample3(first, second, third) {
  return [first, [second, third]];
}

const absent = 0n;
const present = value => [0n, value];

test('lent, turn, and flop handle empty, improper, and long lists iteratively', () => {
  assert.equal(lent(absent), 0n);
  assert.equal(lent(list(1n, 2n, 3n)), 3n);
  assert.deepEqual(items(flop(list(1n, 2n, 3n))), [3n, 2n, 1n]);
  assert.equal(flop(absent), absent);
  assert.deepEqual(items(turn([list(1n, 2n, 3n), item => item * 3n])), [3n, 6n, 9n]);
  assert.equal(turn([absent, () => { throw new Error('not called'); }]), absent);

  const calls = [];
  turn([list(4n, 5n), item => { calls.push(item); return item; }]);
  assert.deepEqual(calls, [4n, 5n]);
  throwsCore(() => turn([list(1n), 0n]), /callable/);
  for (const gate of [lent, flop]) throwsCore(() => gate([1n, 2n]), /cell/);
  throwsCore(() => turn([[1n, 2n], item => item]), /cell/);

  const long = arrayToList(range(20_000));
  assert.equal(lent(long), 20_000n);
  const mapped = turn([long, item => item + 1n]);
  assert.equal(lent(mapped), 20_000n);
  assert.equal(snag([0n, mapped]), 1n);
  assert.equal(snag([19_999n, mapped]), 20_000n);
  assert.deepEqual(items(flop(mapped)), range(20_000).map(item => 20_000n - item));
});

test('snag is zero-based and crashes at every past-end position', () => {
  const values = list('a', 'b', 'c');
  assert.equal(snag([0n, values]), 'a');
  assert.equal(snag([2n, values]), 'c');
  for (const index of [3n, 4n, 2n ** 100n]) throwsCore(() => snag([index, values]), /past end/);
  throwsCore(() => snag([0n, absent]), /past end/);
  for (const index of [-1n, 0, '0', null, [0n, 0n]]) throwsCore(() => snag([index, values]));
  throwsCore(() => snag([0n, [1n, 2n]]), /cell/);
});

test('scag and slag clamp counts exactly, including huge atoms', () => {
  const values = list(0n, 1n, 2n, 3n);
  for (const [count, prefix, suffix] of [
    [0n, [], [0n, 1n, 2n, 3n]],
    [1n, [0n], [1n, 2n, 3n]],
    [4n, [0n, 1n, 2n, 3n], []],
    [9n, [0n, 1n, 2n, 3n], []],
    [2n ** 100n, [0n, 1n, 2n, 3n], []],
  ]) {
    assert.deepEqual(items(scag([count, values])), prefix);
    assert.deepEqual(items(slag([count, values])), suffix);
  }
  assert.equal(scag([2n, absent]), absent);
  assert.equal(slag([2n, absent]), absent);
  for (const gate of [scag, slag]) {
    throwsCore(() => gate([-1n, values]));
    throwsCore(() => gate([1n, [0n, 1n]]), /cell/);
  }

  const long = arrayToList(range(15_000));
  assert.equal(lent(scag([14_999n, long])), 14_999n);
  assert.equal(lent(slag([14_999n, long])), 1n);
  assert.equal(snag([0n, slag([14_999n, long])]), 14_999n);
});

test('gulf builds inclusive ranges and rejects reversed endpoints', () => {
  assert.deepEqual(items(gulf([0n, 0n])), [0n]);
  assert.deepEqual(items(gulf([3n, 7n])), [3n, 4n, 5n, 6n, 7n]);
  const start = 2n ** 100n;
  assert.deepEqual(items(gulf([start, start + 2n])), [start, start + 1n, start + 2n]);
  assert.equal(lent(gulf([0n, 9_999n])), 10_000n);
  throwsCore(() => gulf([1n, 0n]), /greater/);
  throwsCore(() => gulf([0n, -1n]));
  throwsCore(() => gulf([[0n, 0n], 1n]));
});

test('oust and swag implement removal and slicing at all boundaries', () => {
  const values = list(0n, 1n, 2n, 3n, 4n);
  assert.deepEqual(items(oust([[1n, 2n], values])), [0n, 3n, 4n]);
  assert.deepEqual(items(oust([[0n, 0n], values])), [0n, 1n, 2n, 3n, 4n]);
  assert.deepEqual(items(oust([[4n, 9n], values])), [0n, 1n, 2n, 3n]);
  assert.deepEqual(items(oust([[9n, 2n], values])), [0n, 1n, 2n, 3n, 4n]);
  assert.deepEqual(items(oust([[1n, 2n ** 100n], values])), [0n]);
  assert.deepEqual(items(oust([[2n ** 100n, 2n ** 100n], values])), [0n, 1n, 2n, 3n, 4n]);

  assert.deepEqual(items(swag([[1n, 2n], values])), [1n, 2n]);
  assert.deepEqual(items(swag([[0n, 0n], values])), []);
  assert.deepEqual(items(swag([[4n, 9n], values])), [4n]);
  assert.deepEqual(items(swag([[9n, 2n], values])), []);
  assert.deepEqual(items(swag([[1n, 2n ** 100n], values])), [1n, 2n, 3n, 4n]);
  assert.deepEqual(items(swag([[2n ** 100n, 1n], values])), []);

  for (const gate of [oust, swag]) {
    throwsCore(() => gate([[-1n, 1n], values]));
    throwsCore(() => gate([[1n, -1n], values]));
    throwsCore(() => gate([[1n, 1n], [0n, 1n]]), /cell/);
  }
});

test('snap replaces and into inserts, both appending beyond the end', () => {
  const values = list(0n, 1n, 2n);
  assert.deepEqual(items(snap(sample3(values, 1n, 9n))), [0n, 9n, 2n]);
  assert.deepEqual(items(snap(sample3(values, 3n, 9n))), [0n, 1n, 2n, 9n]);
  assert.deepEqual(items(snap(sample3(values, 99n, 9n))), [0n, 1n, 2n, 9n]);
  assert.deepEqual(items(snap(sample3(values, 2n ** 100n, 9n))), [0n, 1n, 2n, 9n]);
  assert.deepEqual(items(snap(sample3(absent, 0n, 9n))), [9n]);
  assert.deepEqual(items(values), [0n, 1n, 2n]);

  assert.deepEqual(items(into(sample3(values, 0n, 9n))), [9n, 0n, 1n, 2n]);
  assert.deepEqual(items(into(sample3(values, 1n, 9n))), [0n, 9n, 1n, 2n]);
  assert.deepEqual(items(into(sample3(values, 3n, 9n))), [0n, 1n, 2n, 9n]);
  assert.deepEqual(items(into(sample3(values, 99n, 9n))), [0n, 1n, 2n, 9n]);
  assert.deepEqual(items(into(sample3(absent, 2n ** 100n, 9n))), [9n]);
  for (const gate of [snap, into]) {
    throwsCore(() => gate(sample3(values, -1n, 9n)));
    throwsCore(() => gate(sample3([0n, 1n], 0n, 9n)), /cell/);
    throwsCore(() => gate([values, 0n, 9n]), /cell/);
  }
});

test('skid partitions in order with the checked two-pass callback behavior', () => {
  const calls = [];
  const result = skid([list(1n, 2n, 3n, 4n), item => {
    calls.push(item);
    return item % 2n === 0n ? 0n : 1n;
  }]);
  assert.deepEqual(result.map(items), [[2n, 4n], [1n, 3n]]);
  assert.deepEqual(calls, [1n, 2n, 3n, 4n, 1n, 2n, 3n, 4n]);
  assert.deepEqual(skid([absent, () => 0n]).map(items), [[], []]);
  throwsCore(() => skid([list(1n), () => 2n]), /loobean/);
  throwsCore(() => skid([list(1n), null]), /callable/);

  const long = arrayToList(range(10_000));
  const [even, odd] = skid([long, item => item % 2n === 0n ? 0n : 1n]);
  assert.equal(lent(even), 5_000n);
  assert.equal(lent(odd), 5_000n);
});

test('fand and find support overlaps, deep equality, absence, and empty needles', () => {
  const haystack = list(1n, 1n, 1n, 2n, 1n, 1n);
  assert.deepEqual(items(fand([list(1n, 1n), haystack])), [0n, 1n, 4n]);
  assert.deepEqual(items(fand([list(1n, 2n), haystack])), [2n]);
  assert.equal(fand([list(9n), haystack]), absent);
  assert.equal(fand([absent, haystack]), absent);
  assert.equal(fand([list(1n), absent]), absent);

  assert.deepEqual(find([list(1n, 1n), haystack]), present(0n));
  assert.deepEqual(find([list(1n, 2n), haystack]), present(2n));
  assert.equal(find([list(9n), haystack]), absent);
  assert.equal(find([absent, haystack]), absent);
  assert.equal(find([list(1n), absent]), absent);

  const left = [1n, [2n, 3n]];
  const equal = [1n, [2n, 3n]];
  const different = [1n, [2n, 4n]];
  assert.deepEqual(items(fand([list(left), list(0n, equal, different)])), [1n]);
  assert.deepEqual(find([list(left), list(0n, equal, different)]), present(1n));

  const longNeedle = list(9n, 9n);
  const longHaystack = arrayToList([...range(8_000), 9n, 9n]);
  assert.deepEqual(items(fand([longNeedle, longHaystack])), [8_000n]);
  assert.deepEqual(find([longNeedle, longHaystack]), present(8_000n));
  for (const gate of [fand, find]) {
    throwsCore(() => gate([[1n, 2n], haystack]), /cell/);
    throwsCore(() => gate([list(1n), [1n, 2n]]), /cell/);
  }
});

test('spin threads state through right-nested samples and callback products', () => {
  const calls = [];
  const result = spin(sample3(list(1n, 2n, 3n), 10n, ([item, state]) => {
    calls.push([item, state]);
    return [item * 2n, state + item];
  }));
  assert.deepEqual(result.map((value, index) => index === 0 ? items(value) : value), [[2n, 4n, 6n], 16n]);
  assert.deepEqual(calls, [[1n, 10n], [2n, 11n], [3n, 13n]]);
  assert.deepEqual(spin(sample3(absent, 7n, () => { throw new Error('not called'); })), [0n, 7n]);
  throwsCore(() => spin(sample3(list(1n), 0n, () => 0n)), /cell/);
  throwsCore(() => spin(sample3(list(1n), 0n, null)), /callable/);
  throwsCore(() => spin([list(1n), [0n, () => 0n]]), /cell/);

  const long = spin(sample3(arrayToList(range(10_000)), 0n, ([item, state]) => [item + 1n, state + 1n]));
  assert.equal(lent(long[0]), 10_000n);
  assert.equal(long[1], 10_000n);
  assert.equal(snag([9_999n, long[0]]), 10_000n);
});

test('sqt returns integer roots and remainders for small and huge atoms', () => {
  const cases = [
    [0n, 0n, 0n], [1n, 1n, 0n], [2n, 1n, 1n], [3n, 1n, 2n],
    [4n, 2n, 0n], [15n, 3n, 6n], [16n, 4n, 0n], [17n, 4n, 1n],
    [2n ** 4096n, 2n ** 2048n, 0n],
  ];
  for (const [value, root, remainder] of cases) assert.deepEqual(sqt(value), [root, remainder]);
  const root = 2n ** 2048n + 123_456_789n;
  assert.deepEqual(sqt(root * root + 77n), [root, 77n]);
  for (const value of [-1n, 0, 1, '1', null, [0n, 0n]]) throwsCore(() => sqt(value));
});

test('roll is a left fold and zing concatenates without recursive stack use', () => {
  const calls = [];
  const result = roll(sample3(list(1n, 2n, 3n), 0n, ([item, state]) => {
    calls.push([item, state]);
    return state * 10n + item;
  }));
  assert.equal(result, 123n);
  assert.deepEqual(calls, [[1n, 0n], [2n, 1n], [3n, 12n]]);
  assert.equal(roll(sample3(absent, 9n, () => { throw new Error('not called'); })), 9n);
  throwsCore(() => roll(sample3(list(1n), 0n, null)), /callable/);

  assert.equal(zing(absent), absent);
  assert.deepEqual(items(zing(list(absent, list(1n, 2n), absent, list(3n)))), [1n, 2n, 3n]);
  throwsCore(() => zing(list(list(1n), [2n, 3n])), /cell/);
  throwsCore(() => zing([list(1n), 2n]), /cell/);

  const long = arrayToList(range(20_000));
  assert.equal(roll(sample3(long, 0n, ([item, state]) => state + item)), 199_990_000n);
  const nested = arrayToList(Array.from({ length: 2_000 }, () => list(1n, 2n, 3n, 4n, 5n)));
  assert.equal(lent(zing(nested)), 10_000n);
});

test('lead, late, and succ retain their curried and atom semantics', () => {
  const first = [1n, 2n];
  const second = [3n, 4n];
  assert.deepEqual(lead(first)(second), [first, second]);
  assert.deepEqual(late(second)(first), [first, second]);
  assert.equal(succ(0n), 1n);
  assert.equal(succ(2n ** 4096n), 2n ** 4096n + 1n);
  for (const value of [-1n, 0, '1', null, [0n, 0n]]) throwsCore(() => succ(value));
});

test('fall, need, some, and drop implement unit extraction and construction', () => {
  const payload = [1n, 2n];
  assert.strictEqual(fall([present(payload), 9n]), payload);
  assert.equal(fall([absent, 9n]), 9n);
  assert.strictEqual(need(present(payload)), payload);
  throwsCore(() => need(absent), /absent/);
  assert.deepEqual(some(payload), [0n, payload]);
  assert.deepEqual(drop(present(payload)), [payload, 0n]);
  assert.equal(drop(absent), absent);
  for (const gate of [need, drop]) {
    for (const malformed of [1n, [1n, 0n], [0n], 0, null]) throwsCore(() => gate(malformed));
  }
});

test('flit and bond are curried and invoke callbacks only when required', () => {
  const calls = [];
  const positive = flit(value => {
    calls.push(value);
    return value > 0n ? 0n : 1n;
  });
  assert.deepEqual(positive(2n), present(2n));
  assert.equal(positive(0n), absent);
  assert.deepEqual(calls, [2n, 0n]);
  throwsCore(() => flit(() => 2n)(1n), /loobean/);
  throwsCore(() => flit(null)(1n), /callable/);

  let fallbackCalls = 0;
  const fallback = argument => {
    fallbackCalls += 1;
    assert.equal(argument, 0n);
    return 42n;
  };
  const replace = bond(fallback);
  assert.equal(replace(absent), 42n);
  assert.equal(replace(present(7n)), 7n);
  assert.equal(fallbackCalls, 1);
  throwsCore(() => bond(null)(absent), /callable/);
});

test('biff and bind preserve absence and apply present callbacks correctly', () => {
  let biffCalls = 0;
  const biffResult = biff([present(4n), value => {
    biffCalls += 1;
    return present(value * 2n);
  }]);
  assert.deepEqual(biffResult, present(8n));
  assert.equal(biff([absent, () => { throw new Error('not called'); }]), absent);
  assert.equal(biffCalls, 1);
  const returned = present(9n);
  assert.strictEqual(biff([present(1n), () => returned]), returned);

  let bindCalls = 0;
  assert.deepEqual(bind([present(4n), value => {
    bindCalls += 1;
    return value * 3n;
  }]), present(12n));
  assert.equal(bind([absent, () => { throw new Error('not called'); }]), absent);
  assert.equal(bindCalls, 1);
  for (const gate of [biff, bind]) {
    throwsCore(() => gate([present(1n), null]), /callable/);
    throwsCore(() => gate([[1n, 0n], () => 0n]));
  }
});

test('both combines only two present units in sample order', () => {
  assert.equal(both([absent, absent]), absent);
  assert.equal(both([present(1n), absent]), absent);
  assert.equal(both([absent, present(2n)]), absent);
  assert.deepEqual(both([present(1n), present(2n)]), present([1n, 2n]));
  const left = [1n, 2n];
  const right = [3n, 4n];
  const result = both([present(left), present(right)]);
  assert.strictEqual(result[1][0], left);
  assert.strictEqual(result[1][1], right);
});

test('clap selects a present unit or combines both with a pair sample', () => {
  const first = present(3n);
  const second = present(4n);
  assert.strictEqual(clap(sample3(absent, second, () => { throw new Error('not called'); })), second);
  assert.strictEqual(clap(sample3(first, absent, () => { throw new Error('not called'); })), first);
  assert.equal(clap(sample3(absent, absent, () => 0n)), absent);
  let sample;
  assert.deepEqual(clap(sample3(first, second, argument => {
    sample = argument;
    return argument[0] + argument[1];
  })), present(7n));
  assert.deepEqual(sample, [3n, 4n]);
  throwsCore(() => clap(sample3(first, second, null)), /callable/);
});

test('clef returns absence unless both units and its callback produce a result', () => {
  const first = present(3n);
  const second = present(4n);
  assert.equal(clef(sample3(absent, second, () => { throw new Error('not called'); })), absent);
  assert.equal(clef(sample3(first, absent, () => { throw new Error('not called'); })), absent);
  assert.equal(clef(sample3(absent, absent, () => 0n)), absent);
  let sample;
  assert.deepEqual(clef(sample3(first, second, argument => {
    sample = argument;
    return present(argument[0] * argument[1]);
  })), present(12n));
  assert.deepEqual(sample, [3n, 4n]);
  const returned = present(0n);
  assert.strictEqual(clef(sample3(first, second, () => returned)), returned);
  throwsCore(() => clef(sample3(first, second, null)), /callable/);
});

test('mate chooses present units, compares deep payloads, and crashes on conflict', () => {
  const first = present([1n, [2n, 3n]]);
  const equal = present([1n, [2n, 3n]]);
  const other = present([1n, [2n, 4n]]);
  assert.strictEqual(mate([first, absent]), first);
  assert.strictEqual(mate([absent, first]), first);
  assert.equal(mate([absent, absent]), absent);
  assert.strictEqual(mate([first, equal]), first);
  throwsCore(() => mate([first, other]), /differ/);
  throwsCore(() => mate([[1n, 0n], first]));
});
