import assert from 'node:assert/strict';
import test from 'node:test';

import { readLiteral } from '../core/literal.mjs';

function check(text, value, aura) {
  assert.deepEqual(readLiteral(text), { value, aura, text });
}

function invalid(text, message) {
  assert.throws(() => readLiteral(text), error => {
    assert.ok(error instanceof SyntaxError, `expected SyntaxError for ${String(text)}`);
    if (message) assert.match(error.message, message);
    return true;
  });
}

function byteCord(bytes) {
  let value = 0n;
  for (let index = 0; index < bytes.length; index += 1) {
    value |= BigInt(bytes[index]) << BigInt(index * 8);
  }
  return value;
}

function textCord(text) {
  return byteCord(new TextEncoder().encode(text));
}

function base32(digits) {
  let value = 0n;
  for (const digit of digits) {
    value = value * 32n + BigInt(Number.parseInt(digit, 32));
  }
  return value;
}

test('decimal literals enforce Hoon grouping and preserve arbitrary precision', () => {
  check('0', 0n, '@ud');
  check('1', 1n, '@ud');
  check('999', 999n, '@ud');
  check('1.000', 1_000n, '@ud');
  check('12.345.678', 12_345_678n, '@ud');
  check(
    '123.456.789.012.345.678.901.234.567.890',
    123456789012345678901234567890n,
    '@ud',
  );

  for (const text of [
    '', '00', '01', '000.000', '1000', '1.00', '1.0000', '1.', '.1',
    '1..000', '1.000.00', '-1', '+1', ' 1', '1 ', '1_000',
  ]) invalid(text);
});

test('hexadecimal and base32 literals accept arbitrary nonempty groups', () => {
  check('0x0', 0n, '@ux');
  check('0x00.0000', 0n, '@ux');
  check('0x1f', 31n, '@ux');
  check('0xdead.BEEF', 0xdeadbeefn, '@ux');
  check('0x1.0000', 65_536n, '@ux');
  check(`0x1.${'0'.repeat(100)}`, 16n ** 100n, '@ux');

  check('0v0', 0n, '@uv');
  check('0v00.000', 0n, '@uv');
  check('0v10', 32n, '@uv');
  check('0vv', 31n, '@uv');
  check('0v5.fdf99', base32('5fdf99'), '@uv');
  check(`0v1.${'0'.repeat(100)}`, 32n ** 100n, '@uv');

  for (const text of [
    '0x', '0x.', '0x.0', '0x0.', '0x0..0', '0X1', '0xg', '0x-1',
    '0v', '0v.', '0v.0', '0v0.', '0v0..0', '0V1', '0vw', '0vA', '0v-1',
  ]) invalid(text);
});

test('strings are UTF-8 cords in Hoon little-endian byte order', () => {
  check('""', 0n, '@t');
  check('"a"', 97n, '@t');
  check('"abc"', 0x636261n, '@t');
  check('"hello"', textCord('hello'), '@t');
  check('"λ🙂"', textCord('λ🙂'), '@t');
  check('"雪 and ŝ"', textCord('雪 and ŝ'), '@t');
  check('"}"', textCord('}'), '@t');
  check(String.raw`"\00"`, 0n, '@t');
  check(String.raw`"\00\01"`, 256n, '@t');
  check(String.raw`"\ff"`, 255n, '@t');
  check(String.raw`"\7b"`, 123n, '@t');
  check(String.raw`"\22"`, 34n, '@t');
  check(String.raw`"\5c"`, 92n, '@t');
  check(String.raw`"a\"b\{c\\d"`, textCord('a"b{c\\d'), '@t');
  check(String.raw`"\{name}"`, textCord('{name}'), '@t');

  const mixed = String.raw`"λ\00🙂\ff"`;
  const expected = byteCord([
    ...new TextEncoder().encode('λ'), 0,
    ...new TextEncoder().encode('🙂'), 255,
  ]);
  check(mixed, expected, '@t');
});

test('interpolated and malformed strings fail closed', () => {
  invalid(String.raw`"hello {name}"`, /interpolated/);
  invalid(String.raw`"{x}"`, /interpolated/);

  const malformed = [
    '"', '"abc', 'abc"', '"a"b"', String.raw`"\}"`, String.raw`"\n"`,
    String.raw`"\a"`, String.raw`"\0g"`, String.raw`"\AF"`, String.raw`"\"`,
    '"line\nfeed"', '"tab\tcharacter"', '"nul\0character"', '"del\x7fcharacter"',
    `"${String.fromCharCode(0xd800)}"`,
  ];
  for (const text of malformed) invalid(text);
});

test('terms, loobeans, null, and knots have their Hoon atom values', () => {
  check('%a', 97n, '@tas');
  check('%add', 0x646461n, '@tas');
  check('%foo-bar9', textCord('foo-bar9'), '@tas');
  check('%0', 0n, '@tas');
  check('%1.000', 1_000n, '@tas');
  check('%123.456.789.012.345.678.901', 123456789012345678901n, '@tas');
  check('%&', 0n, '@tas');
  check('%|', 1n, '@tas');
  check('%$', 0n, '@tas');
  check('%.y', 0n, '?');
  check('%.n', 1n, '?');
  check('~', 0n, 'null');

  check('~.', 0n, 'knot');
  check('~..', textCord('.'), 'knot');
  check('~.my-post_2~', textCord('my-post_2~'), 'knot');
  check('~.0.x-y_z~', textCord('0.x-y_z~'), 'knot');

  for (const text of [
    '%', '%A', '%a_b', '%a.b', '%1000', '%01', '%1.00', '%.x', '%.Y', '%/',
    '~.Upper', '~.has/slash', '~.has space', '~.has{brace',
  ]) invalid(text);
});

test('durations match Rust vectors and place fractions in the low 64 bits', () => {
  check('~s0', 0n, '@dr');
  check('~s30', 30n << 64n, '@dr');
  check('~h1.m30', 5_400n << 64n, '@dr');
  check('~m0.s0', 0n, '@dr');

  const seconds = 1_000n * 86_400n + 5n * 3_600n + 30n * 60n + 12n;
  check('~d1000.h5.m30.s12..beef', (seconds << 64n) | 0xbeefn, '@dr');
  check('~s1..0001.0002.0003.0004', (1n << 64n) | 0x0001000200030004n, '@dr');
  check('~d999999999999999999999', (999999999999999999999n * 86_400n) << 64n, '@dr');

  for (const text of [
    '~s', '~1s', '~x1', '~s1.', '~s1..', '~s1...beef', '~s1..be', '~s1..BEEF',
    '~s1..00001', '~s1..0001.0002.0003.0004.0005', '~s1.m2', '~h1.d2',
    '~m1.m2', '~d1.s2.h3', '~d1..h2', '~s-1', '~s 1',
  ]) invalid(text);
});

test('dates match Rust arithmetic, normalization, BC epoch, and fractions', () => {
  check('~292277024401-.1.1', 0n, '@da');
  check('~292277024401-.1.1..0.0.0..0001', 1n, '@da');
  check('~292277024401-.1.1..1.2.3..0001', (3_723n << 64n) | 1n, '@da');
  check(
    '~292277024401-.1.1..0.0.0..0001.0002.0003.0004',
    0x0001000200030004n,
    '@da',
  );

  const day = readLiteral('~2026.1.1').value;
  assert.ok(day > 0n);
  assert.equal(readLiteral('~2026.2.31').value, readLiteral('~2026.3.3').value);
  assert.equal(
    readLiteral('~2026.1.1..14.30.00..beef').value,
    day + (52_200n << 64n) + 0xbeefn,
  );
  assert.ok(readLiteral('~1-.1.1').value > 0n);

  for (const text of [
    '~2026', '~2026.1', '~2026.1.1.', '~2026.001.1', '~2026.1.001',
    '~2026.1.1..14.30', '~2026.1.1..14.30.00.', '~2026.1.1..beef',
    '~2026.1.1..14.30.00..be', '~2026.1.1..14.30.00..BEEF',
    '~2026.1.1..14.30.00..0001.0002.0003.0004.0005',
    '~2026.14.1', '~292277024402-.1.1',
  ]) invalid(text);
});

test('ships decode all address widths with urbit-ob deobfuscation', () => {
  check('~zod', 0n, '@p');
  check('~fes', 255n, '@p');
  check('~doznec', 1n, '@p');
  check('~marzod', 256n, '@p');
  check('~binzod', 512n, '@p');
  check('~dozzod', 0n, '@p');
  check('~sampel-palnet', 1_624_961_343n, '@p');
  check('~dozzod-sampel-palnet', 1_624_961_343n, '@p');
  check('~mastyr-midwyt-sampel-palnet', 14_598_768_375_314_968_895n, '@p');
  check(
    '~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem',
    177292234920987225829036013324996224552n,
    '@p',
  );
});

test('malformed ship syllables, zero padding, and separators are rejected', () => {
  for (const text of [
    'sampel-palnet', '.~sampel-palnet', '~xxx', '~Zod', '~zod-',
    '~sampel-palxxx', '~sampel-xxxnet', '~sampel-word-palnet',
    '~dev-sampel-palnet', '~zod-nec', '~sampel--palnet', '~-sampel-palnet',
    '~rolruc-midwyl-hathes-palsym-fotnul-pagpur-nopful-lomtem',
    '~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful--lomtem',
  ]) invalid(text);
});

test('non-string and non-literal inputs throw clear SyntaxErrors', () => {
  for (const value of [undefined, null, 1, 1n, {}, ['1']]) invalid(value);
  for (const text of ['!!', '/path', 'name', ' ', '-0x1', '0b1']) invalid(text);
  assert.throws(() => readLiteral('not-a-literal'), /not-a-literal/);
});
