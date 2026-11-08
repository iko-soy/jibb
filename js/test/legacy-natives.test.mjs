import assert from 'node:assert/strict';
import test from 'node:test';

import { readLiteral } from '../core/literal.mjs';
import { CoreCrash, atomToBytes, bytesToAtom } from '../core/runtime.mjs';
import { scot } from '../natives/atom.mjs';
import {
  arrayToList,
  cord,
  listToArray,
  text,
} from '../natives/helpers.mjs';
import {
  isRawSeal,
  rawBitNot,
  rawDatePack,
  rawDateUnpack,
  rawParseAtom,
  rawSeal,
  validateRawSeal,
} from '../natives/legacy.mjs';

function list(...items) {
  return arrayToList(items);
}

function date(flag, year, month, day, hours = 0n, minutes = 0n, seconds = 0n, fractions = 0n) {
  return [[flag, year], [month, [day, [hours, [minutes, [seconds, fractions]]]]]];
}

function throwsCore(fn, message) {
  assert.throws(fn, error => {
    assert.ok(error instanceof CoreCrash);
    assert.equal(error.name, 'CoreCrash');
    if (message !== undefined) assert.match(error.message, message);
    return true;
  });
}

function parsed(aura, source) {
  return rawParseAtom([cord(aura), cord(source)]);
}

function valid(aura, source, expected) {
  assert.deepEqual(parsed(aura, source), [0n, expected], `${aura} ${source}`);
}

function invalid(aura, source) {
  assert.deepEqual(parsed(aura, source), [1n, 0n], `${aura} ${source}`);
}

test('date pack matches Hoon year for AD, BC, leap years, and normalization', () => {
  const cases = [
    [date(0n, 2_026n, 1n, 1n), '~2026.1.1'],
    [date(0n, 2_026n, 1n, 1n, 14n, 30n, 0n, list(0xbeefn)), '~2026.1.1..14.30.00..beef.0000.0000.0000'],
    [date(1n, 1n, 1n, 1n), '~1-.1.1'],
    [date(1n, 292_277_024_401n, 1n, 1n), '~292277024401-.1.1'],
    [date(0n, 2_000n, 2n, 29n), '~2000.2.29'],
    [date(0n, 1_900n, 2n, 29n), '~1900.3.1'],
    [date(0n, 2_026n, 2n, 31n), '~2026.3.3'],
    [date(0n, 0n, 1n, 1n), '~1-.1.1'],
  ];
  for (const [value, literal] of cases) {
    assert.equal(rawDatePack(value), readLiteral(literal).value, literal);
  }
  assert.equal(rawDatePack(date(1n, 292_277_024_401n, 1n, 1n)), 0n);
  assert.equal(
    rawDatePack(date(1n, 292_277_024_401n, 1n, 1n, 0n, 0n, 0n, list(0x1_0000n))),
    1n << 64n,
    'out-of-range fraction words retain Hoon yule bitwise-OR behavior',
  );
  assert.equal(
    rawDatePack(date(1n, 292_277_024_401n, 1n, 1n, 0n, 0n, 0n, list(1n, 0x1_0000n))),
    1n << 49n,
    'overlapping fraction words are added before the final bitwise OR',
  );
});

test('date unpack matches Hoon yore including epoch and significant fraction groups', () => {
  assert.deepEqual(rawDateUnpack(0n), date(1n, 292_277_024_401n, 1n, 1n));
  assert.deepEqual(
    rawDateUnpack(1n),
    date(1n, 292_277_024_401n, 1n, 1n, 0n, 0n, 0n, list(0n, 0n, 0n, 1n)),
  );
  assert.deepEqual(
    rawDateUnpack(0x1_0000n),
    date(1n, 292_277_024_401n, 1n, 1n, 0n, 0n, 0n, list(0n, 0n, 1n)),
  );
  assert.deepEqual(
    rawDateUnpack(0x1_0000_0000_0000n),
    date(1n, 292_277_024_401n, 1n, 1n, 0n, 0n, 0n, list(1n)),
  );
  assert.deepEqual(
    rawDateUnpack(readLiteral('~2026.10.23..14.30.00..0001.0002.0003.0004').value),
    date(0n, 2_026n, 10n, 23n, 14n, 30n, 0n, list(1n, 2n, 3n, 4n)),
  );

  for (const literal of [
    '~1-.1.1',
    '~292277024401-.1.1',
    '~2026.10.23',
    '~2000.2.29',
    '~1900.3.1',
    '~2026.1.1..14.30.00..0000.0000.0000.beef',
  ]) {
    const value = readLiteral(literal).value;
    assert.equal(rawDatePack(rawDateUnpack(value)), value, literal);
  }
});

test('date operations crash on malformed samples and Hoon year failures', () => {
  for (const sample of [
    0n,
    [0n, 0n],
    date(2n, 1n, 1n, 1n),
    date(1n, 0n, 1n, 1n),
    date(1n, 292_277_024_402n, 1n, 1n),
    date(0n, 1n, 0n, 1n),
    date(0n, 1n, 13n, 1n),
    date(0n, 1n, 1n, 0n),
    date(0n, 1n, 1n, 1n, 0n, 0n, 0n, list(1n, 2n, 3n, 4n, 5n)),
    date(0n, 1n, 1n, 1n, 0n, 0n, 0n, [1n, 1n]),
    date(0n, -1n, 1n, 1n),
  ]) {
    throwsCore(() => rawDatePack(sample));
  }
  for (const sample of [-1n, 0, '0', null, [0n, 0n]]) {
    throwsCore(() => rawDateUnpack(sample));
  }
});

test('parse-atom accepts every checked numeric, term, knot, and ship printer', () => {
  valid('ud', '0', 0n);
  valid('ud', '12.345.678', 12_345_678n);
  valid('ux', '0x0', 0n);
  valid('ux', '0xdead.BEEF', 0xdead_beefn);
  valid('uv', '0v0', 0n);
  valid('uv', '0vv', 31n);
  valid('uv', '0v5.fdf99', readLiteral('0v5.fdf99').value);
  valid('tas', 'foo-bar9', cord('foo-bar9'));
  valid('ta', '~.my-post_2~', cord('my-post_2~'));
  valid('ta', '~.', 0n);

  for (const literal of [
    '~zod',
    '~nec',
    '~sampel-palnet',
    '~mastyr-midwyt-sampel-palnet',
    '~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem',
  ]) {
    valid('p', literal, readLiteral(literal).value);
  }

  for (const [aura, value] of [
    ['ud', 123_456_789_012_345_678_901n],
    ['ux', 0xdead_beef_1234n],
    ['uv', 32n ** 30n + 31n],
    ['tas', cord('valid-term9')],
    ['ta', cord('my-post_2~')],
    ['p', 1_624_961_343n],
  ]) {
    const printed = text(scot([cord(aura), value]));
    valid(aura, printed, value);
  }
});

test('parse-atom matches date and duration printers, fractions, BC, and repeated units', () => {
  for (const literal of [
    '~1-.1.1',
    '~292277024401-.1.1',
    '~2026.10.23',
    '~2026.10.23..14.30.00..0001.0002.0003.0004',
    '~2026.2.31',
  ]) {
    valid('da', literal, readLiteral(literal).value);
  }
  for (const literal of [
    '~s0',
    '~h1.m30',
    '~d1000.h5.m30.s12..0000.0000.0000.beef',
  ]) {
    valid('dr', literal, readLiteral(literal).value);
  }

  valid('dr', '~m1.s2.d3.h4', ((3n * 86_400n + 4n * 3_600n + 60n + 2n) << 64n));
  valid('dr', '~s1.s2.h1.h2', (10_803n << 64n));
  valid('dr', '~s1..0000.0000.0000.0001', (1n << 64n) | 1n);
  valid('dr', '~s1..beef', 32_204_959_460_349_706_240n);
  valid('da', '~2026.1.1..000.000.000', readLiteral('~2026.1.1').value);
  valid(
    'da',
    '~2026.1.1..14.30.00..beef',
    170_141_184_507_752_689_255_009_738_751_081_447_424n,
  );
});

test('parse-atom decodes Hoon cord escapes to UTF-8 atoms', () => {
  valid('t', '~~', 0n);
  valid('t', '~~hello.world', cord('hello world'));
  valid('t', '~~~41.', cord('A'));
  valid('t', '~~~3bb.', cord('λ'));
  valid('t', '~~~1f642.', cord('🙂'));
  valid('t', '~~~~', cord('~'));
  valid('t', '~~~.', cord('.'));
  valid('t', '~~a.b~~c~.d', cord('a b~c.d'));
  valid('t', '~~a~0.b', bytesToAtom(new Uint8Array([97, 0, 98])));
  valid('t', '~~a~01.b', bytesToAtom(new Uint8Array([97, 1, 98])));

  const original = cord('hello world.λ🙂~_-');
  valid('t', text(scot([cord('t'), original])), original);
});

test('parse-atom rejects bad aura text canonically without throwing', () => {
  for (const [aura, source] of [
    ['nope', '0'],
    ['ud', '01'],
    ['ud', '1000'],
    ['ud', '1.00'],
    ['ud', '0.000'],
    ['ux', '0x01'],
    ['ux', '0x0.0001'],
    ['ux', '0x0000.0001'],
    ['ux', '0xA'],
    ['uv', '0v0000v'],
    ['uv', '0vw'],
    ['tas', ''],
    ['tas', '%foo'],
    ['tas', 'Foo'],
    ['ta', 'foo'],
    ['ta', '~.Foo'],
    ['p', '~not-a-ship'],
    ['p', '~zod-zod'],
    ['p', '0'],
    ['da', '~0-.1.1'],
    ['da', '~2026.0.1'],
    ['da', '~2026.13.1'],
    ['da', '~2026.1.0'],
    ['da', '~02026.1.1'],
    ['da', '~2026.1.1..0.0'],
    ['da', '~2026.1.1..0.0.0..BEEF'],
    ['da', '~2026.1.1..0.0.0..0000.0000.0000.0000.0000'],
    ['dr', '~'],
    ['dr', '~s01'],
    ['dr', '~x1'],
    ['dr', '~s1..0000.0000.0000.0000.0000'],
    ['t', 'hello'],
    ['t', '~~A'],
    ['t', '~~a~'],
    ['t', '~~~110000.'],
    ['t', '~~~d800.'],
  ]) {
    invalid(aura, source);
  }
  assert.deepEqual(
    rawParseAtom([cord('ud'), bytesToAtom(new Uint8Array([0xff]))]),
    [1n, 0n],
  );
});

test('parse-atom retains CoreCrash for malformed ABI samples', () => {
  for (const sample of [
    0n,
    [cord('ud')],
    [cord('ud'), cord('1'), 0n],
    [[cord('ud'), 0n], cord('1')],
    [cord('ud'), [cord('1'), 0n]],
    [-1n, cord('1')],
    [cord('ud'), -1n],
    [0, cord('1')],
  ]) {
    throwsCore(() => rawParseAtom(sample));
  }
});

test('bit-not uses Hoon bloq times count width and preserves high bits', () => {
  const vectors = [
    [[0n, [4n, 42n]], 37n],
    [[1n, [4n, 42n]], 213n],
    [[3n, [4n, 42n]], 4_294_967_253n],
    [[0n, [0n, 42n]], 42n],
    [[0n, [4n, 0n]], 15n],
    [[4n, [2n, 0xdead_beefn]], 559_038_736n],
    [[0n, [8n, 0x1234_5678n]], 0x1234_5687n],
    [[2n, [2n, 0x1_0000_0000n]], 0x1_0000_00ffn],
  ];
  for (const [sample, expected] of vectors) assert.equal(rawBitNot(sample), expected);

  for (const sample of [0n, [0n, 1n], [0n, [1n]], [[0n, 0n], 1n, 2n], [-1n, 1n, 0n], [0n, -1n, 0n], [0n, 1n, -1n]]) {
    throwsCore(() => rawBitNot(sample));
  }
});

test('seal preserves the value ABI and validation rejects raw and forged wrappers', () => {
  const gate = value => value;
  for (const value of [0n, 42n, [1n, [2n, 3n]], gate]) {
    const sealed = rawSeal(value);
    assert.ok(Array.isArray(sealed));
    assert.equal(sealed.length, 2);
    assert.strictEqual(sealed[1], value);
    assert.equal(isRawSeal(sealed), true);
    assert.strictEqual(validateRawSeal(sealed), value);
    assert.equal(isRawSeal(value), false);
    assert.equal(isRawSeal([sealed[0], value]), false, 'copied wrapper must not gain provenance');
    throwsCore(() => validateRawSeal(value));
    throwsCore(() => validateRawSeal([sealed[0], value]));
  }

  const first = rawSeal(42n);
  const second = rawSeal(42n);
  assert.notStrictEqual(first, second);
  assert.equal(isRawSeal(first), true);
  assert.equal(isRawSeal(second), true);
  first[1] = 43n;
  assert.equal(validateRawSeal(first), 43n, 'the payload remains an ordinary mutable Core value');
  first[0] = 0n;
  assert.equal(isRawSeal(first), false);
  throwsCore(() => validateRawSeal(first));
});

test('sealed nouns retain their byte-level atom/list representation', () => {
  const sealed = rawSeal([cord('element'), list(1n, 2n)]);
  assert.deepEqual(listToArray(sealed[1][1]), [1n, 2n]);
  assert.deepEqual([...atomToBytes(sealed[1][0])], [...atomToBytes(cord('element'))]);
});
