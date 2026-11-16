import test from 'node:test';
import assert from 'node:assert/strict';
import { bytesToAtom, CoreCrash } from '../core/runtime.mjs';
import { cripBytes, tripBytes, tubaBytes, tufaCodepoints } from '../natives/atom.mjs';
import { arrayToList, cord, listToArray } from '../natives/helpers.mjs';

const bytes = (values) => arrayToList(values.map(BigInt));
const text = 'Aλ🙂';

test('raw trip and crip preserve UTF-8 bytes without Unicode interpretation', () => {
  const packed = cord(text);
  const raw = listToArray(tripBytes(packed));
  assert.deepEqual(raw, [...new TextEncoder().encode(text)].map(BigInt));
  assert.equal(cripBytes(bytes(raw)), packed);
  assert.deepEqual(listToArray(tripBytes(bytesToAtom(new Uint8Array([0xff])))), [0xffn]);
});

test('raw tuba decodes bytes to scalar values and tufa encodes them back', () => {
  const utf8 = [...new TextEncoder().encode(text)];
  const codepoints = Array.from(text, character => BigInt(character.codePointAt(0)));
  assert.deepEqual(listToArray(tubaBytes(bytes(utf8))), codepoints);
  assert.deepEqual(listToArray(tufaCodepoints(arrayToList(codepoints))), utf8.map(BigInt));
});

// Each expectation is what the pinned ship's Hoon (%135), and urbit
// eval's (%137), gave for the same
// call: crip is +rap 3, tuba +taft of it, tufa +tuft of each point.
test('crip takes each element\'s bytes, so a NUL vanishes and 256 is two bytes', () => {
  assert.equal(cripBytes(bytes([0x6e, 0x75, 0x6c, 0, 0x65, 0x6e, 0x64])), cord('nulend'));
  assert.equal(cripBytes(bytes([256])), 256n);
  assert.equal(cripBytes(bytes([97, 0, 98, 0, 0])), cord('ab'));
  assert.equal(cripBytes(bytes([0x1_0061, 98])), 0x6201_0061n);
  // trip keeps a NUL inside a cord.
  assert.deepEqual(listToArray(tripBytes(bytesToAtom(new Uint8Array([97, 0, 98])))), [97n, 0n, 98n]);
});

test('tuba reads bytes as Hoon\'s +taft does', () => {
  const points = values => listToArray(tubaBytes(bytes(values))).map(Number);
  assert.deepEqual(points([97, 10, 98]), [97, 10, 98]);
  assert.deepEqual(points([97, 127, 98]), [97, 127, 98]);
  assert.deepEqual(points([0xed, 0xa0, 0x80]), [0xd800]);
  assert.deepEqual(points([0xf4, 0x90, 0x80, 0x80]), [0x11_0000]);
  assert.deepEqual(points([0xf7, 0xbf, 0xbf, 0xbf]), [0x1f_ffff]);
  assert.deepEqual(points([97, 0, 98]), [97, 98]);
  assert.deepEqual(points([0xe2, 0x82, 0xac, 0xf0, 0x9f, 0x99, 0x82]), [0x20ac, 0x1_f642]);
  // A tab, an overlong or a cut-off sequence, and a NUL inside crash.
  for (const values of [[97, 9, 98], [0xc0, 0xaf], [0xc0, 0x80], [0x61, 0xc3], [0xf0, 0x9f], [97, 256, 98]]) {
    assert.throws(() => tubaBytes(bytes(values)), CoreCrash, JSON.stringify(values));
  }
});

test('tufa encodes each 32-bit word as Hoon\'s +tuft does, a zero as nothing', () => {
  const utf8 = values => listToArray(tufaCodepoints(arrayToList(values))).map(Number);
  assert.deepEqual(utf8([65n, 0n]), [65]);
  assert.deepEqual(utf8([0n]), []);
  assert.deepEqual(utf8([0xd800n]), [237, 160, 128]);
  assert.deepEqual(utf8([0x11_0000n]), [244, 144, 128, 128]);
  assert.deepEqual(utf8([0x20_0041n]), [240, 128, 129, 129]);
  assert.deepEqual(utf8([0x1_0000_0041n]), [65, 1]);
  assert.deepEqual(utf8([0x20acn, 0x1_f642n, 0x7ffn, 0x80n]), [226, 130, 172, 240, 159, 153, 130, 223, 191, 194, 128]);
});
