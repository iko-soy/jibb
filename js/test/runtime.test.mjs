import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CoreCrash,
  cons,
  isCell,
  same,
  slot,
  edit,
  requireLoobean,
  apply,
  crash,
  trace,
  traceLazy,
  atomToBytes,
  bytesToAtom,
  atomToText,
} from '../core/runtime.mjs';

function throwsCore(fn, message) {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof CoreCrash);
    assert.ok(error instanceof Error);
    assert.equal(error.name, 'CoreCrash');
    if (message !== undefined) {
      assert.match(error.message, message);
    }
    return true;
  });
}

function cord(text) {
  return bytesToAtom(new TextEncoder().encode(text));
}

test('CoreCrash is distinct and crash preserves its diagnostic', () => {
  throwsCore(() => crash('boom'), /^boom$/);
  throwsCore(() => crash(), /Core crash/);
  throwsCore(() => crash(42), /string/);
  assert.notEqual(CoreCrash, Error);
});

test('cons constructs cells and isCell returns Jibb loobeans', () => {
  const cell = cons(1n, cons(2n, 3n));
  assert.deepEqual(cell, [1n, [2n, 3n]]);
  assert.equal(isCell(cell), 0n);
  assert.equal(isCell(0n), 1n);
  assert.equal(isCell(2n ** 4096n + 123n), 1n);
  assert.notStrictEqual(cons(1n, 2n), cons(1n, 2n));
});

test('cons and isCell reject malformed values and direct function inspection', () => {
  const fn = () => 0n;
  const malformed = [
    undefined,
    null,
    true,
    0,
    1.5,
    '0',
    -1n,
    {},
    [],
    [1n],
    [1n, 2n, 3n],
    new Array(2),
    [1n, '2'],
    [1n, -2n],
  ];

  for (const value of malformed) {
    throwsCore(() => isCell(value));
  }
  throwsCore(() => isCell(fn), /functions/);
  throwsCore(() => cons(0, 0n), /atom/);
  throwsCore(() => cons(0n, [0n]), /two-element/);

  const cyclic = [0n, 0n];
  cyclic[0] = cyclic;
  throwsCore(() => isCell(cyclic), /cyclic/);
});

test('cells can carry functions without making them noun data', () => {
  const fn = () => 0n;
  const cell = cons(fn, cons(0n, fn));
  assert.strictEqual(cell[0], fn);
  assert.strictEqual(cell[1][1], fn);
  assert.equal(isCell(cell), 0n);
  assert.strictEqual(slot(2, cell), fn);
  assert.strictEqual(slot(7, cell), fn);
  const changed = edit(7, cell, fn);
  assert.strictEqual(slot(7, changed), fn);
  assert.strictEqual(edit(1, cell, fn), fn);
});

test('same compares atoms, cells, shapes, and very large atoms', () => {
  assert.equal(same(0n, 0n), 0n);
  assert.equal(same(0n, 1n), 1n);
  assert.equal(same(2n ** 8192n + 77n, 2n ** 8192n + 77n), 0n);
  assert.equal(same(2n ** 8192n + 77n, 2n ** 8192n + 78n), 1n);
  assert.equal(same([1n, [2n, 3n]], [1n, [2n, 3n]]), 0n);
  assert.equal(same([1n, [2n, 3n]], [1n, [2n, 4n]]), 1n);
  assert.equal(same([[1n, 2n], 3n], [1n, [2n, 3n]]), 1n);
  assert.equal(same(0n, [0n, 0n]), 1n);
});

test('same supports deep nouns and shared acyclic substructure', () => {
  let left = 0n;
  let right = 0n;
  for (let index = 0n; index < 10000n; index += 1n) {
    left = [left, index % 3n];
    right = [right, index % 3n];
  }
  assert.equal(same(left, right), 0n);
  right[1] = 9n;
  assert.equal(same(left, right), 1n);

  const shared = [7n, 8n];
  assert.equal(same([shared, shared], [[7n, 8n], [7n, 8n]]), 0n);
});

test('same rejects functions anywhere, cycles, and malformed values', () => {
  const fn = () => 0n;
  throwsCore(() => same(fn, fn), /functions/);
  throwsCore(() => same(0n, fn), /functions/);
  throwsCore(() => same([0n, [0n, fn]], [0n, 0n]), /functions/);
  throwsCore(() => same([0n, 0n], [0n, [fn, 0n]]), /functions/);
  throwsCore(() => same([0n], [0n]), /two-element/);
  throwsCore(() => same(-1n, -1n), /negative/);

  const left = [0n, 0n];
  left[1] = left;
  throwsCore(() => same(left, left), /cyclic/);
});

const tree = [
  [[1n, 2n], [3n, 4n]],
  [[5n, 6n], [7n, 8n]],
];

const slots = new Map([
  [1, tree],
  [2, tree[0]],
  [3, tree[1]],
  [4, tree[0][0]],
  [5, tree[0][1]],
  [6, tree[1][0]],
  [7, tree[1][1]],
  [8, 1n],
  [9, 2n],
  [10, 3n],
  [11, 4n],
  [12, 5n],
  [13, 6n],
  [14, 7n],
  [15, 8n],
]);

test('slot implements every Nock axis through a complete binary tree', () => {
  for (const [axis, expected] of slots) {
    assert.strictEqual(slot(axis, tree), expected);
    assert.strictEqual(slot(BigInt(axis), tree), expected);
  }
});

test('slot handles deep safe axes without recursion', () => {
  let noun = 42n;
  for (let index = 0; index < 52; index += 1) {
    noun = [noun, BigInt(index)];
  }
  assert.equal(slot(2n ** 52n, noun), 42n);
});

test('slot rejects invalid axes, missing axes, and non-nouns', () => {
  const invalidAxes = [
    0,
    0n,
    -1,
    -1n,
    1.5,
    Number.NaN,
    Number.POSITIVE_INFINITY,
    Number.MAX_SAFE_INTEGER + 1,
    2n ** 53n,
    '1',
    null,
    undefined,
    true,
    [],
  ];
  for (const axis of invalidAxes) {
    throwsCore(() => slot(axis, tree), /Axis/);
  }

  throwsCore(() => slot(2, 0n), /does not exist/);
  throwsCore(() => slot(9, tree[0]), /does not exist/);
  throwsCore(() => slot(1, () => 0n), /functions/);
  throwsCore(() => slot(2, [0n, [0n]]), /two-element/);
});

test('edit replaces the root and all positions in a complete tree', () => {
  const root = edit(1, tree, 99n);
  assert.equal(root, 99n);
  assert.equal(slot(1, tree), tree);

  for (const axis of slots.keys()) {
    if (axis === 1) continue;
    const changed = edit(BigInt(axis), tree, 99n);
    assert.equal(slot(axis, changed), 99n);
    assert.equal(slot(axis, tree), slots.get(axis));
  }
});

test('edit copies only the edited path and never mutates its input', () => {
  const original = [
    [[1n, 2n], [3n, 4n]],
    [[5n, 6n], [7n, 8n]],
  ];
  const changed = edit(10, original, 99n);

  assert.deepEqual(changed, [
    [[1n, 2n], [99n, 4n]],
    [[5n, 6n], [7n, 8n]],
  ]);
  assert.deepEqual(original, tree);
  assert.notStrictEqual(changed, original);
  assert.notStrictEqual(changed[0], original[0]);
  assert.notStrictEqual(changed[0][1], original[0][1]);
  assert.strictEqual(changed[0][0], original[0][0]);
  assert.strictEqual(changed[1], original[1]);

  const first = edit(2, original, 10n);
  const second = edit(3, original, 20n);
  assert.deepEqual(first, [10n, original[1]]);
  assert.deepEqual(second, [original[0], 20n]);
  assert.deepEqual(original, tree);
});

test('edit accepts frozen cells, cell replacements, and deep axes', () => {
  const frozen = Object.freeze([
    Object.freeze([0n, 1n]),
    Object.freeze([2n, 3n]),
  ]);
  assert.deepEqual(edit(4, frozen, [8n, 9n]), [[[8n, 9n], 1n], [2n, 3n]]);

  let noun = 42n;
  for (let index = 0; index < 52; index += 1) {
    noun = [noun, BigInt(index)];
  }
  const changed = edit(2n ** 52n, noun, 43n);
  assert.equal(slot(2n ** 52n, changed), 43n);
  assert.equal(slot(2n ** 52n, noun), 42n);
});

test('edit rejects invalid axes, missing axes, functions, and malformed nouns', () => {
  for (const axis of [0, 0n, -1n, 1.5, 2n ** 53n, '2', null]) {
    throwsCore(() => edit(axis, tree, 0n), /Axis/);
  }
  throwsCore(() => edit(2, 0n, 1n), /does not exist/);
  throwsCore(() => edit(16, tree, 1n), /does not exist/);
  throwsCore(() => edit(1, () => 0n, 0n), /functions/);
  throwsCore(() => edit(2, [0n], 0n), /two-element/);
  throwsCore(() => edit(2, tree, -1n), /negative/);
});

test('requireLoobean accepts only canonical Jibb loobeans', () => {
  assert.equal(requireLoobean(0n), true);
  assert.equal(requireLoobean(1n), false);
  for (const value of [2n, -1n, 0, 1, true, false, '0', null, [0n, 0n], () => 0n]) {
    throwsCore(() => requireLoobean(value), /loobean/);
  }
});

test('apply validates callability and passes exactly one argument', () => {
  let received;
  let count;
  const fn = function (...args) {
    received = args[0];
    count = args.length;
    return [args[0], this];
  };
  const argument = [1n, 2n];
  const result = apply(fn, argument);
  assert.strictEqual(received, argument);
  assert.equal(count, 1);
  assert.strictEqual(result[0], argument);
  assert.equal(result[1], undefined);

  const callableArgument = () => 0n;
  assert.strictEqual(apply((value) => value, callableArgument), callableArgument);
  for (const value of [0n, 0, null, undefined, {}, [], 'fn']) {
    throwsCore(() => apply(value, 0n), /callable/);
  }

  const expected = new CoreCrash('from function');
  assert.throws(() => apply(() => { throw expected; }, 0n), (error) => error === expected);
});

test('atom byte conversion is little-endian and exact', () => {
  assert.deepEqual(atomToBytes(0n), new Uint8Array());
  assert.deepEqual(atomToBytes(1n), new Uint8Array([1]));
  assert.deepEqual(atomToBytes(0xffn), new Uint8Array([255]));
  assert.deepEqual(atomToBytes(0x100n), new Uint8Array([0, 1]));
  assert.deepEqual(atomToBytes(0x1234n), new Uint8Array([0x34, 0x12]));
  assert.equal(bytesToAtom(new Uint8Array()), 0n);
  assert.equal(bytesToAtom(new Uint8Array([0x34, 0x12])), 0x1234n);
  assert.equal(bytesToAtom(new Uint8Array([1, 0, 2])), 0x20001n);

  for (const atom of [1n, 255n, 256n, 2n ** 4096n + 0x123456789abcdefn]) {
    assert.equal(bytesToAtom(atomToBytes(atom)), atom);
  }
});

test('atom byte conversion rejects coercion and negative atoms', () => {
  for (const value of [-1n, 0, 1, '1', null, undefined, [], [0n, 0n], () => 0n]) {
    throwsCore(() => atomToBytes(value));
  }
  for (const value of [[], [1, 2], 'abc', null, undefined, new ArrayBuffer(2), new DataView(new ArrayBuffer(2))]) {
    throwsCore(() => bytesToAtom(value), /Uint8Array/);
  }
});

test('atomToText decodes UTF-8 cords, empty cords, and malformed sequences', () => {
  assert.equal(atomToText(0n), '');
  assert.equal(atomToText(cord('milk')), 'milk');
  assert.equal(atomToText(cord('Jibb λ 🌍\n')), 'Jibb λ 🌍\n');
  assert.equal(atomToText(bytesToAtom(new Uint8Array([0xff]))), '�');
  assert.equal(atomToText(bytesToAtom(new Uint8Array([0x61, 0x00, 0x62]))), 'a\0b');
});

test('trace logs decoded UTF-8 once and returns its body', () => {
  const body = [1n, 2n];
  const calls = [];
  const logger = (...args) => calls.push(args);
  assert.strictEqual(trace(cord('hello λ 🌍'), body, logger), body);
  assert.deepEqual(calls, [['hello λ 🌍']]);

  calls.length = 0;
  assert.equal(trace(0n, 42n, logger), 42n);
  assert.deepEqual(calls, [['']]);
});

test('traceLazy logs before evaluating its body', () => {
  const calls = [];
  const result = traceLazy(cord('first'), () => {
    calls.push('body');
    return 42n;
  }, (line) => calls.push(line));
  assert.equal(result, 42n);
  assert.deepEqual(calls, ['first', 'body']);
  throwsCore(() => traceLazy(cord('bad'), 42n, () => {}), /callable/);
});

test('trace uses console.log by default', () => {
  const original = console.log;
  const calls = [];
  console.log = (...args) => calls.push(args);
  try {
    assert.equal(trace(cord('default logger'), 7n), 7n);
  } finally {
    console.log = original;
  }
  assert.deepEqual(calls, [['default logger']]);
});

test('trace validates its cord and logger before printing', () => {
  let calls = 0;
  const logger = () => { calls += 1; };
  for (const message of [-1n, 0, 'hello', null, [0n, 0n], () => 0n]) {
    throwsCore(() => trace(message, 0n, logger));
  }
  throwsCore(() => trace(cord('hello'), 0n, null), /callable/);
  throwsCore(() => trace(cord('hello'), 0n, 'log'), /callable/);
  assert.equal(calls, 0);
});
