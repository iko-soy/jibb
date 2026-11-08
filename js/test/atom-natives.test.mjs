import assert from 'node:assert/strict';
import test from 'node:test';

import { readLiteral } from '../core/literal.mjs';
import { CoreCrash, atomToBytes, bytesToAtom } from '../core/runtime.mjs';
import {
  add,
  sub,
  mul,
  inc,
  dec,
  gth,
  gte,
  lth,
  lte,
  eq,
  not,
  max,
  min,
  trip,
  tuba,
  join,
  formatUd,
  formatUx,
  formatUv,
  formatTas,
  formatT,
  formatTa,
  formatP,
  formatDa,
  formatDr,
  scot,
  scow,
} from '../natives/atom.mjs';
import {
  arrayToList,
  cord,
  listToArray,
  text,
} from '../natives/helpers.mjs';

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

function byteCord(bytes) {
  return bytesToAtom(new Uint8Array(bytes));
}

function rendered(formatter, value) {
  return text(formatter(value));
}

test('atom arithmetic uses unsigned BigInts without precision loss', () => {
  const huge = 2n ** 4096n + 123_456_789n;
  assert.equal(add([huge, 77n]), huge + 77n);
  assert.equal(add([0n, 0n]), 0n);
  assert.equal(sub([huge, 123_456_789n]), 2n ** 4096n);
  assert.equal(sub([9n, 9n]), 0n);
  assert.equal(mul([huge, 17n]), huge * 17n);
  assert.equal(mul([0n, huge]), 0n);
  assert.equal(inc(huge), huge + 1n);
  assert.equal(dec(huge), huge - 1n);
  assert.equal(dec(1n), 0n);
  assert.equal(max([4n, 9n]), 9n);
  assert.equal(max([9n, 4n]), 9n);
  assert.equal(max([9n, 9n]), 9n);
  assert.equal(min([4n, 9n]), 4n);
  assert.equal(min([9n, 4n]), 4n);
  assert.equal(min([9n, 9n]), 9n);
});

test('arithmetic crashes on underflow, malformed samples, and non-atoms', () => {
  throwsCore(() => sub([0n, 1n]), /underflow/);
  throwsCore(() => sub([2n ** 100n, 2n ** 100n + 1n]), /underflow/);
  throwsCore(() => dec(0n), /underflow/);

  const binary = [add, sub, mul, gth, gte, lth, lte, max, min];
  for (const gate of binary) {
    for (const sample of [0n, [0n], [0n, 1n, 2n], [0n, 0], [0, 0n], [-1n, 0n], [[0n, 0n], 0n]]) {
      throwsCore(() => gate(sample));
    }
  }
  for (const gate of [inc, dec]) {
    for (const value of [-1n, 0, 1, '1', null, undefined, [], [0n, 0n]]) {
      throwsCore(() => gate(value));
    }
  }
});

test('comparisons return canonical Jibb loobeans for the full truth table', () => {
  for (const left of [0n, 1n, 2n, 2n ** 256n]) {
    for (const right of [0n, 1n, 2n, 2n ** 256n]) {
      assert.equal(gth([left, right]), left > right ? 0n : 1n);
      assert.equal(gte([left, right]), left >= right ? 0n : 1n);
      assert.equal(lth([left, right]), left < right ? 0n : 1n);
      assert.equal(lte([left, right]), left <= right ? 0n : 1n);
    }
  }
});

test('eq performs deep noun equality and not accepts only loobeans', () => {
  assert.equal(eq([0n, 0n]), 0n);
  assert.equal(eq([0n, 1n]), 1n);
  assert.equal(eq([[1n, [2n, 3n]], [1n, [2n, 3n]]]), 0n);
  assert.equal(eq([[1n, [2n, 3n]], [1n, [2n, 4n]]]), 1n);
  assert.equal(eq([0n, [0n, 0n]]), 1n);

  let left = 0n;
  let right = 0n;
  for (let index = 0n; index < 5_000n; index += 1n) {
    left = [index, left];
    right = [index, right];
  }
  assert.equal(eq([left, right]), 0n);
  throwsCore(() => eq([[0n, () => 0n], [0n, 0n]]), /functions/);
  throwsCore(() => eq(0n), /cell/);

  assert.equal(not(0n), 1n);
  assert.equal(not(1n), 0n);
  for (const value of [2n, -1n, 0, false, null, [0n, 0n], () => 0n]) {
    throwsCore(() => not(value), /loobean/);
  }
});

test('trip decodes UTF-8 to codepoints and tuba reconstructs the exact cord', () => {
  assert.equal(trip(0n), 0n);
  assert.deepEqual(listToArray(trip(cord('Aλ🙂雪'))), [65n, 0x3bbn, 0x1f642n, 0x96ean]);
  assert.deepEqual(listToArray(trip(byteCord([0x61, 0, 0x62]))), [97n, 0n, 98n]);
  assert.equal(tuba(list(65n, 0x3bbn, 0x1f642n, 0x96ean)), cord('Aλ🙂雪'));
  assert.equal(tuba(0n), 0n);
  assert.equal(tuba(trip(cord('Jibb λ 🌍\n\0'))), cord('Jibb λ 🌍\n\0'));

  const long = 'λ🙂abc'.repeat(2_000);
  assert.equal(tuba(trip(cord(long))), cord(long));
  assert.equal(BigInt(listToArray(trip(cord(long))).length), 10_000n);

  for (const invalid of [[0xc0, 0x80], [0xed, 0xa0, 0x80], [0xf4, 0x90, 0x80, 0x80], [0xff]]) {
    throwsCore(() => trip(byteCord(invalid)), /UTF-8/);
  }
  for (const codepoint of [0xd800n, 0xdfffn, 0x110000n, 2n ** 80n, -1n]) {
    throwsCore(() => tuba(list(codepoint)), codepoint < 0n ? /atom/ : /Unicode scalar/);
  }
  throwsCore(() => tuba(list(65n, 0)), /atom/);
  throwsCore(() => tuba([65n, 1n]), /cell/);
  throwsCore(() => trip([0n, 0n]), /atom/);
});

test('join concatenates raw cord bytes with no convenience decoding', () => {
  assert.equal(join([cord(', '), 0n]), 0n);
  assert.equal(join([cord(', '), list(cord('one'))]), cord('one'));
  assert.equal(join([cord(', '), list(cord('one'), cord('two'), 0n)]), cord('one, two, '));
  assert.equal(join([0n, list(cord('ab'), cord('cd'))]), cord('abcd'));
  assert.equal(
    join([byteCord([0xff]), list(byteCord([0x80]), byteCord([0x00, 0x81]))]),
    byteCord([0x80, 0xff, 0x00, 0x81]),
  );

  const items = Array.from({ length: 5_000 }, (_, index) => cord(`item-${index}`));
  const expected = items.map(text).join('|');
  assert.equal(text(join([cord('|'), arrayToList(items)])), expected);
  throwsCore(() => join([0n, list(cord('ok'), 1)]), /atom/);
  throwsCore(() => join([0n, [cord('ok'), 1n]]), /cell/);
});

test('decimal, hexadecimal, and base32 printers group arbitrary-precision digits', () => {
  assert.equal(rendered(formatUd, 0n), '0');
  assert.equal(rendered(formatUd, 999n), '999');
  assert.equal(rendered(formatUd, 1_000n), '1.000');
  assert.equal(rendered(formatUd, 123456789012345678901234567890n), '123.456.789.012.345.678.901.234.567.890');
  assert.equal(rendered(formatUx, 0n), '0x0');
  assert.equal(rendered(formatUx, 0xdeadbeefn), '0xdead.beef');
  assert.equal(rendered(formatUx, 16n ** 100n), `0x1.${Array(25).fill('0000').join('.')}`);
  assert.equal(rendered(formatUv, 0n), '0v0');
  assert.equal(rendered(formatUv, 31n), '0vv');
  assert.equal(rendered(formatUv, 32n), '0v10');
  assert.equal(rendered(formatUv, 32n ** 100n), `0v1.${Array(20).fill('00000').join('.')}`);

  for (const [literal, formatter] of [
    ['12.345.678', formatUd],
    ['0xdead.BEEF', formatUx],
    ['0v5.fdf99', formatUv],
  ]) {
    const printed = rendered(formatter, readLiteral(literal).value);
    assert.equal(readLiteral(printed).value, readLiteral(literal).value);
  }
  for (const formatter of [formatUd, formatUx, formatUv]) {
    throwsCore(() => formatter(-1n));
    throwsCore(() => formatter(1));
    throwsCore(() => formatter([1n, 2n]));
  }
});

test('textual aura printers retain Hoon scot escaping and prefixes', () => {
  assert.equal(formatTas(cord('foo-bar9')), cord('foo-bar9'));
  assert.equal(rendered(formatTa, cord('my-post_2~')), '~.my-post_2~');
  assert.equal(rendered(formatTa, 0n), '~.');
  assert.equal(rendered(formatT, cord('hello world')), '~~hello.world');
  assert.equal(rendered(formatT, cord('A')), '~~~41.');
  assert.equal(rendered(formatT, cord('.')), '~~~.');
  assert.equal(rendered(formatT, cord('~')), '~~~~');
  assert.equal(rendered(formatT, cord('λ')), '~~~3bb.');
  assert.equal(rendered(formatT, 0n), '~~');
  throwsCore(() => formatT(byteCord([0xff])), /UTF-8/);
  throwsCore(() => formatTa(-1n));
  throwsCore(() => formatTas(1));
});

test('ship printer matches phonetic vectors and round-trips every address width', () => {
  const vectors = new Map([
    [0n, '~zod'],
    [1n, '~nec'],
    [255n, '~fes'],
    [256n, '~marzod'],
    [512n, '~binzod'],
    [1_624_961_343n, '~sampel-palnet'],
    [14_598_768_375_314_968_895n, '~mastyr-midwyt-sampel-palnet'],
    [177292234920987225829036013324996224552n, '~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem'],
  ]);
  for (const [value, expected] of vectors) assert.equal(rendered(formatP, value), expected);

  for (const value of [
    ...vectors.keys(),
    65_535n,
    65_536n,
    65_537n,
    0xffff_ffffn,
    0x1_0000_0000n,
    0xffff_ffff_ffff_ffffn,
    2n ** 128n - 1n,
  ]) {
    const printed = rendered(formatP, value);
    assert.equal(readLiteral(printed).value, value, printed);
  }
  throwsCore(() => formatP(-1n));
  throwsCore(() => formatP('0'));
});

test('date printer implements Hoon 135 epochs, padding, and fractional groups', () => {
  const cases = new Map([
    ['~292277024401-.1.1', '~292277024401-.01.01'],
    ['~1-.1.1', '~1-.01.01'],
    ['~2026.1.1', '~2026.01.01'],
    ['~2026.2.31', '~2026.03.03'],
    ['~2026.1.1..14.30.00..beef', '~2026.01.01..14.30.00..0000.0000.0000.beef'],
    ['~2026.1.1..0.0.0..0001.0002.0003.0004', '~2026.01.01..00.00.00..0001.0002.0003.0004'],
    ['~999999999999999999999.1.1', '~999999999999999999999.01.01'],
  ]);
  for (const [literal, expected] of cases) {
    const value = readLiteral(literal).value;
    const printed = rendered(formatDa, value);
    assert.equal(printed, expected);
    assert.equal(readLiteral(printed).value, value);
  }
  assert.equal(rendered(formatDa, 1n), '~292277024401-.01.01..00.00.00..0000.0000.0000.0001');
  assert.equal(rendered(formatDa, 0x1_0000n), '~292277024401-.01.01..00.00.00..0000.0000.0001');
  assert.equal(rendered(formatDa, 0x1_0000_0000_0000n), '~292277024401-.01.01..00.00.00..0001');
  throwsCore(() => formatDa(-1n));
});

test('duration printer omits zero components but preserves significant fractions', () => {
  const cases = new Map([
    ['~s0', '~s0'],
    ['~s30', '~s30'],
    ['~h1.m30', '~h1.m30'],
    ['~m0.s0', '~s0'],
    ['~d1000.h5.m30.s12..beef', '~d1000.h5.m30.s12..0000.0000.0000.beef'],
    ['~s1..0001.0002.0003.0004', '~s1..0001.0002.0003.0004'],
    ['~d999999999999999999999', '~d999999999999999999999'],
  ]);
  for (const [literal, expected] of cases) {
    const value = readLiteral(literal).value;
    const printed = rendered(formatDr, value);
    assert.equal(printed, expected);
    assert.equal(readLiteral(printed).value, value);
  }
  assert.equal(rendered(formatDr, 1n), '~s0..0000.0000.0000.0001');
  assert.equal(rendered(formatDr, 0x1_0000n), '~s0..0000.0000.0001');
  assert.equal(rendered(formatDr, 0x1_0000_0000_0000n), '~s0..0001');
  throwsCore(() => formatDr(-1n));
});

test('scot dispatches all supported auras and scow returns a byte tape', () => {
  const expectations = [
    ['ud', 12_345n, '12.345'],
    ['ux', 0xbeefn, '0xbeef'],
    ['uv', 31n, '0vv'],
    ['tas', cord('foo'), 'foo'],
    ['t', cord('a b'), '~~a.b'],
    ['ta', cord('foo'), '~.foo'],
    ['p', 0n, '~zod'],
    ['da', 0n, '~292277024401-.01.01'],
    ['dr', 0n, '~s0'],
  ];
  for (const [aura, value, expected] of expectations) {
    const sample = [cord(aura), value];
    assert.equal(text(scot(sample)), expected);
    assert.deepEqual(
      listToArray(scow(sample)),
      [...atomToBytes(cord(expected))].map(BigInt),
    );
  }
  throwsCore(() => scot([cord('nope'), 0n]), /unsupported aura/);
  throwsCore(() => scot([0n, 0n]), /unsupported aura/);
  throwsCore(() => scot(cord('ud')), /cell/);
});
