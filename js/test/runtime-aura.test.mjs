import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { readLiteral } from '../core/literal.mjs';
import { CoreCrash, atomToBytes } from '../core/runtime.mjs';
import { scot } from '../natives/atom.mjs';
import { cord } from '../natives/helpers.mjs';
import { rawParseAtom } from '../natives/legacy.mjs';

// What the pinned ship's Hoon (%135, the brass pill the flake boots its
// fake ship from) printed with +scot, read with +slaw (under mule, as
// parse-atom-native runs it) and read with jibb-core.hoon's +read-literal,
// for each case, through tools/ship hoon. urbit eval runs Hoon %137, which
// differs only in dates: it prints month and day unpadded and reads no
// leading zero in them.
const fixture = JSON.parse(readFileSync(new URL('./fixtures/runtime-hoon-atoms.json', import.meta.url), 'utf8'));
const latin1 = value => Buffer.from(atomToBytes(value)).toString('latin1');
const valueOf = text => (text.startsWith('~') ? readLiteral(text).value : BigInt(text));

test('scot prints every aura as Hoon\'s +rend does', () => {
  assert.equal(fixture.hoon, '%135');
  const wrong = [];
  for (const [aura, value, expected] of fixture.scot) {
    let printed;
    try {
      printed = latin1(scot([cord(aura), valueOf(value)]));
    } catch (error) {
      if (!(error instanceof CoreCrash)) throw error;
      printed = '!CRASH';
    }
    if (printed !== Buffer.from(expected, 'utf8').toString('latin1')) wrong.push([aura, value, expected, printed]);
  }
  assert.deepEqual(wrong, []);
  assert.ok(fixture.scot.length >= 200);
});

test('parse-atom reads every aura as Hoon\'s +slaw does', () => {
  const wrong = [];
  for (const [aura, text, expected] of fixture.slaw) {
    const [invalid, value] = rawParseAtom([cord(aura), cord(text)]);
    // A crash and no parse are both invalid text to parse-atom.
    const want = expected.startsWith('!') ? [1n, 0n] : [0n, BigInt(expected.slice(2))];
    if (invalid !== want[0] || value !== want[1]) wrong.push([aura, text, expected, [invalid, value]]);
  }
  assert.deepEqual(wrong, []);
  assert.ok(fixture.slaw.length >= 200);
});

test('Core literals read as jibb-core.hoon\'s +read-literal reads them', () => {
  const AURAS = { ud: '@ud', ux: '@ux', uv: '@uv', p: '@p', da: '@da', dr: '@dr', ta: 'knot', n: 'null' };
  const wrong = [];
  for (const [text, expected] of fixture.literal) {
    let read;
    try {
      const { value, aura } = readLiteral(text);
      read = { value, aura };
    } catch (error) {
      if (!(error instanceof SyntaxError)) throw error;
      read = undefined;
    }
    if (expected.startsWith('!')) {
      if (read !== undefined) wrong.push([text, expected, read]);
      continue;
    }
    const [aura, value] = expected.split(' ');
    // Terms and strings keep the JavaScript reader's own aura names.
    const sameAura = text.startsWith('%') || text.startsWith('"') || read?.aura === AURAS[aura];
    if (read?.value !== BigInt(value.slice(2)) || !sameAura) wrong.push([text, expected, read]);
  }
  assert.deepEqual(wrong, []);
});

test('a float printed as Hoon prints it reads back as the same float, in every format', () => {
  let seed = 7n;
  const random = (bits) => {
    let value = 0n;
    for (let done = 0; done < bits; done += 62) {
      seed = (seed * 6_364_136_223_846_793_005n + 1_442_695_040_888_963_407n) % 2n ** 64n;
      value = (value << 62n) | (seed >> 2n);
    }
    return value & ((1n << BigInt(bits)) - 1n);
  };
  const view = new DataView(new ArrayBuffer(8));
  for (const [aura, bits] of [['rh', 16], ['rs', 32], ['rd', 64], ['rq', 128]]) {
    for (let index = 0; index < 1_000; index += 1) {
      const value = random(bits);
      const printed = latin1(scot([cord(aura), value]));
      const [invalid, read] = rawParseAtom([cord(aura), cord(printed)]);
      assert.equal(invalid, 0n, printed);
      // Every NaN reads back as Hoon's one NaN.
      if (!printed.endsWith('nan')) assert.equal(read, value, `${aura} ${printed}`);
      if (aura === 'rd' && !/inf|nan/.test(printed)) {
        view.setBigUint64(0, value);
        assert.ok(Object.is(Number(printed.slice(2)), view.getFloat64(0)), printed);
      }
    }
  }
});
