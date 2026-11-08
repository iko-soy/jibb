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

test('byte and Unicode primitives reject malformed input', () => {
  assert.throws(() => cripBytes(bytes([256])), CoreCrash);
  assert.throws(() => tubaBytes(bytes([0xc0, 0x80])), CoreCrash);
  assert.throws(() => tubaBytes(bytes([0xed, 0xa0, 0x80])), CoreCrash);
  assert.throws(() => tubaBytes(bytes([0xf0, 0x9f])), CoreCrash);
  assert.throws(() => tufaCodepoints(arrayToList([0xd800n])), CoreCrash);
  assert.throws(() => tufaCodepoints(arrayToList([0x110000n])), CoreCrash);
});
