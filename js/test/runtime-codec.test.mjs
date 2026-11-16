import test from 'node:test';
import assert from 'node:assert/strict';
import { cue, decodeUw, encodeUw, jam } from '../natives/codec.mjs';
import { same } from '../core/runtime.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';

// Boot models and channel facts decode through @uw and cue; a page's fact
// may be hundreds of kilobytes. Before, decoding 141 KiB took 2.6 s and
// grew with the square of the size.
test('@uw decoding and cue take time linear in a large noun\'s size, as do jam\'s long atoms', () => {
  const rows = arrayToList(Array.from({ length: 6_000 }, (_, index) => [BigInt(index), cord(`row ${index} `.padEnd(40, 'x'))]));
  const huge = 2n ** 2_400_000n - 12_345n;
  for (const noun of [rows, [huge, [huge, 7n]]]) {
    const token = encodeUw(jam(noun));
    assert.ok(token.length > 400_000, `a large token (${token.length} bytes)`);
    // About 0.2 s here; it was 2.6 s for a third of this, and quadratic.
    const started = performance.now();
    const decoded = cue(decodeUw(token));
    const elapsed = performance.now() - started;
    assert.ok(elapsed < 1_500, `${token.length} bytes decoded in ${elapsed.toFixed(0)} ms`);
    assert.equal(same(decoded, noun), 0n);
  }
  const started = performance.now();
  jam([huge, huge + 1n]);
  assert.ok(performance.now() - started < 1_500, 'jam writes a long atom by its bytes');
});

test('@uw and jam round-trip atoms of every width and group boundary', () => {
  let seed = 1n;
  const next = () => (seed = (seed * 6_364_136_223_846_793_005n + 1_442_695_040_888_963_407n) % 2n ** 64n);
  for (let width = 0; width < 400; width += 1) {
    let value = 0n;
    for (let bits = 0; bits < width; bits += 64) value = (value << 64n) | next();
    value &= (1n << BigInt(width)) - 1n;
    for (const atom of [value, value | 1n, (1n << BigInt(width)) - 1n]) {
      assert.equal(decodeUw(encodeUw(atom)), atom);
      assert.deepEqual(cue(jam([atom, [next(), atom]])), [atom, [seed, atom]]);
    }
  }
  assert.equal(decodeUw('0w0'), 0n);
  assert.equal(decodeUw('0w10'), 64n);
  assert.equal(decodeUw('0w1.00000'), 2n ** 30n);
  assert.equal(decodeUw('0w~~~~~'), 2n ** 30n - 1n);
  assert.throws(() => decodeUw('0w1.0000!'), /invalid digit "!"/);
  assert.throws(() => decodeUw('0w!'), /invalid digit "!"/);
});
