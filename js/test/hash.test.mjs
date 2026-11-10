import test from 'node:test';
import assert from 'node:assert/strict';
import { murmur32 } from '../core/hash.mjs';
import { mug } from '../natives/collections.mjs';

// Fixed outputs of the previous Hoon +muk port, which used BigInt for
// every uint32 operation. Cover each tail width and unsigned boundaries.
test('shared Murmur32 preserves empty, tail, block and high-bit results', () => {
  const vectors = [
    [0x0, '', 0x0],
    [0xffffffff, '', 0x81f16f39],
    [0x80000000, 'ff', 0x4bff1c8a],
    [0xdeadbeef, '1234', 0xae36c9c1],
    [0xcafebabe, '123456', 0xf6c66723],
    [0xcafebabe, '12345678', 0x2004ba54],
    [0xdeadbeef, '123456789a', 0xe1c41a6e],
    [0xdeadbeef, '123456789abc', 0xdac061b6],
    [0xdeadbeef, '123456789abcde', 0x2d0a7fcb],
    [0xffffffff, 'ffffffff', 0xa5fe21d3],
    [0x80000000, 'ffffffffffffffff', 0xd07e717e],
    [0xcafebabe, '000000000000000001', 0xa6a7107e],
  ];
  for (const [seed, hex, expected] of vectors) {
    assert.equal(murmur32(seed, Buffer.from(hex, 'hex')), expected, `${seed}: ${hex}`);
  }
});

test('mug preserves large atom hashes across block boundaries', () => {
  const vectors = [
    [31, 1076864541n], [32, 501731201n],
    [63, 324972947n], [64, 648482943n],
    [127, 1025590334n], [128, 98393738n],
    [255, 1280967580n], [256, 1415649449n],
    [511, 1378440689n], [512, 1175087545n],
  ];
  for (const [bits, expected] of vectors) assert.equal(mug(1n << BigInt(bits)), expected);
});
