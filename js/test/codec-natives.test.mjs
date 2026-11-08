import test from 'node:test';
import assert from 'node:assert/strict';

import { CoreCrash, atomToBytes } from '../core/runtime.mjs';
import {
  jam,
  cue,
  encodeUw,
  decodeUw,
  enUw,
  deUw,
  validateNoun,
} from '../natives/codec.mjs';

function throwsCore(fn, message) {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof CoreCrash);
    assert.equal(error.name, 'CoreCrash');
    if (message !== undefined) assert.match(error.message, message);
    return true;
  });
}

function bytesHex(value) {
  return [...atomToBytes(value)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

test('jam and cue match independent Hoon/Rust serialization vectors', () => {
  // The first five values and bit layouts are documented in Hoon +jam and
  // the urbit/noun Rust serdes implementation, respectively.
  const vectors = [
    { noun: 0n, packed: 2n, bytes: '02' },
    { noun: 1n, packed: 12n, bytes: '0c' },
    { noun: 19n, packed: 2480n, bytes: 'b009' },
    { noun: [0n, 19n], packed: 39689n, bytes: '099b' },
    { noun: [10000n, 10000n], packed: 4952983169n, bytes: '8186382701' },
  ];

  for (const { noun, packed, bytes } of vectors) {
    assert.equal(jam(noun), packed);
    assert.equal(bytesHex(packed), bytes);
    assert.deepEqual(cue(packed), noun);
  }
});

test('@uw matches Hoon numeric base-64 spelling and grouping', () => {
  // These are Hoon aura examples, not RFC base64/base64url encodings.
  const vectors = [
    [0n, '0w0'],
    [62n, '0w-'],
    [63n, '0w~'],
    [64n, '0w10'],
    [100n, '0w1A'],
    [1000000n, '0w3Q90'],
    [1000000000n, '0wXCIE0'],
    [1000000000000n, '0wez.kFh00'],
    [0xdeadbeefn, '0w3.uHrXL'],
  ];

  for (const [value, encoded] of vectors) {
    assert.equal(encodeUw(value), encoded);
    assert.equal(decodeUw(encoded), value);
    assert.equal(enUw(value), encoded);
    assert.equal(deUw(encoded), value);
  }
  assert.equal(decodeUw('0w1.00000'), 64n ** 5n);
});

test('roundtrips preserve arbitrary-precision atoms and nested nouns', () => {
  const huge = (2n ** 4096n) + (2n ** 2048n) + 9007199254740993n;
  const nouns = [
    9007199254740993n,
    huge,
    [huge, 0n],
    [1n, [2n, [3n, [4n, 0n]]]],
    [[huge, 19n], [10000n, [huge, 1n]]],
  ];

  for (const noun of nouns) {
    const packed = jam(noun);
    assert.deepEqual(cue(packed), noun);
    assert.equal(jam(cue(packed)), packed);
    assert.equal(decodeUw(encodeUw(packed)), packed);
  }
  assert.equal(decodeUw(encodeUw(huge)), huge);
});

test('canonical jam uses structural sharing and cue preserves it', () => {
  const shared = [(2n ** 300n) + 7n, 19n];
  const withSharedCell = [shared, shared];
  const withEqualCells = [
    [(2n ** 300n) + 7n, 19n],
    [(2n ** 300n) + 7n, 19n],
  ];

  const packed = jam(withSharedCell);
  assert.equal(packed, jam(withEqualCells));
  const decoded = cue(packed);
  assert.deepEqual(decoded, withSharedCell);
  assert.strictEqual(decoded[0], decoded[1]);
  assert.equal(jam(decoded), packed);
});

test('deep nouns do not use the JavaScript call stack', () => {
  let noun = 0n;
  const depth = 5000;
  for (let index = 0; index < depth; index += 1) {
    noun = [BigInt(index % 7), noun];
  }

  const packed = jam(noun);
  const decoded = cue(packed);
  let current = decoded;
  for (let index = depth - 1; index >= 0; index -= 1) {
    assert.ok(Array.isArray(current));
    assert.equal(current[0], BigInt(index % 7));
    current = current[1];
  }
  assert.equal(current, 0n);
  assert.equal(jam(decoded), packed);

  const sharedDeep = cue(jam([decoded, decoded]));
  assert.strictEqual(sharedDeep[0], sharedDeep[1]);
});

test('jam and validateNoun reject every non-noun and cycles', () => {
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
    () => 0n,
    [0n, () => 0n],
  ];
  const cyclic = [0n, 0n];
  cyclic[0] = cyclic;
  const indirect = [0n, [0n, 0n]];
  indirect[1][0] = indirect;
  malformed.push(cyclic, indirect);

  for (const value of malformed) {
    throwsCore(() => jam(value));
    throwsCore(() => validateNoun(value));
  }
  assert.deepEqual(validateNoun([1n, [2n, 3n]]), [1n, [2n, 3n]]);
});

test('cue rejects truncation, trailing data, and invalid backreferences', () => {
  for (const packed of [0n, 1n, 4n]) {
    throwsCore(() => cue(packed), /truncated/);
  }

  const nineteen = jam(19n);
  const withoutLastBit = nineteen ^ (1n << BigInt(nineteen.toString(2).length - 1));
  throwsCore(() => cue(withoutLastBit), /truncated/);

  for (const noun of [0n, 19n, [0n, 19n]]) {
    const packed = jam(noun);
    const withTrailingBit = packed | (1n << BigInt(packed.toString(2).length));
    throwsCore(() => cue(withTrailingBit), /trailing data/);
  }

  // 7 = backreference tag + mat(0); 27 refers to unoccupied bit 1.
  throwsCore(() => cue(7n), /invalid backreference/);
  throwsCore(() => cue(27n), /invalid backreference/);
  // A cell cannot backreference itself before its head and tail complete.
  throwsCore(() => cue(29n), /invalid backreference/);

  for (const packed of [-1n, 0, 1.5, '2', null, undefined]) {
    throwsCore(() => cue(packed));
  }
});

test('@uw decoding rejects non-Hoon padding, alphabets, and groups', () => {
  const malformed = [
    '',
    '0',
    'uw0',
    '0x0',
    '0w',
    '0w00',
    '0w01',
    '0w0.00000',
    '0w123456',
    '0w.12345',
    '0w12345.',
    '0w1..00000',
    '0w1.0000',
    '0w12345.0000',
    '0w1+000',
    '0w1/000',
    '0w1_000',
    '0w1=000',
    '0w1 000',
    ' 0w1',
    '0w1\n',
  ];
  for (const encoded of malformed) {
    throwsCore(() => decodeUw(encoded));
  }
  for (const encoded of [null, undefined, 0, 0n, {}]) {
    throwsCore(() => decodeUw(encoded));
  }
  for (const value of [-1n, 0, 1.5, '0', null, undefined]) {
    throwsCore(() => encodeUw(value));
  }

  const canonical = '0w1.00000.00000';
  assert.equal(encodeUw(decodeUw(canonical)), canonical);
});
