// The Node harness: runs each test- arm of a desk's test modules as the
// JavaScript the browser would run and as the Nock the ship would, with
// the same natives, and reports both outcomes. tools/check-node-tests gives
// it the host's test programs, one jammed file per desk, and checks the
// outcomes agree with each other and with -jibb!test's.
//
// The Nock names each native by a placeholder, [[0 0] 0 %jibb-native name];
// js/nock/interpreter.mjs runs it with the JavaScript native in its place,
// as a jet. Prints one JSON object a test.

import { readFileSync } from 'node:fs';
import * as runtime from '../js/core/runtime.mjs';
import { bytesToAtom } from '../js/core/runtime.mjs';
import { cue } from '../js/natives/codec.mjs';
import { cord, listToArray, text } from '../js/natives/helpers.mjs';
import { createNativeRegistry, nativeNames } from '../js/natives/index.mjs';
import { runNock } from '../js/nock/interpreter.mjs';

const natives = createNativeRegistry(nativeNames());
const PLACEHOLDER = cord('jibb-native');

function placeholderName(value) {
  if (!Array.isArray(value)) return undefined;
  const [battery, rest] = value;
  if (!Array.isArray(battery) || battery[0] !== 0n || battery[1] !== 0n) return undefined;
  if (!Array.isArray(rest) || rest[0] !== 0n || !Array.isArray(rest[1])) return undefined;
  if (rest[1][0] !== PLACEHOLDER || typeof rest[1][1] !== 'bigint') return undefined;
  return text(rest[1][1]);
}

// The formula with each placeholder replaced by its native.
function withNatives(formula) {
  const name = placeholderName(formula);
  if (name !== undefined) {
    if (!Object.hasOwn(natives, name)) throw new Error(`no JavaScript native ${name}`);
    return natives[name];
  }
  if (!Array.isArray(formula)) return formula;
  return [withNatives(formula[0]), withNatives(formula[1])];
}

function outcome(run) {
  try {
    const value = run();
    if (value === 0n) return 'yes';
    if (value === 1n) return 'no';
    return 'other';
  } catch (error) {
    if (error instanceof runtime.CoreCrash) return 'crash';
    return `error: ${error.message}`;
  }
}

for (const file of process.argv.slice(2)) {
  const modules = cue(bytesToAtom(new Uint8Array(readFileSync(file))));
  for (const [at, programs] of listToArray(modules, 'test modules')) {
    const where = `/${listToArray(at, 'module path').map(text).join('/')}`;
    for (const [arm, [js, nock]] of listToArray(programs, 'test programs')) {
      const source = text(js);
      const module = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
      const viaJs = outcome(() => module.evaluate(runtime, natives));
      const viaNock = outcome(() => runNock(0n, withNatives(nock)));
      console.log(JSON.stringify({ at: where, arm: text(arm), js: viaJs, nock: viaNock }));
    }
  }
}
