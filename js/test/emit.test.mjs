// tests/js-emit is the corpus the Hoon emitter, jibb-dev/lib/jibb-js.hoon,
// must reproduce: each expected module is what this compiler emits for its
// Core, or, for a case with an entry.txt, for its module linked at that
// entry.  `node tools/js-emit-update.mjs` regenerates the corpus.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readCore } from '../core/reader.mjs';
import { compileCore } from '../core/compiler.mjs';
import { linkCore } from '../core/linker.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'tests', 'js-emit');
const cases = readFileSync(join(root, 'cases.txt'), 'utf8').split('\n').filter(Boolean);

test('the emitter corpus is what the JavaScript compiler emits', () => {
  assert.ok(cases.length > 0);
  for (const name of cases) {
    const core = readFileSync(join(root, name, 'core.txt'), 'utf8').trim();
    const natives = readFileSync(join(root, name, 'natives.txt'), 'utf8').split('\n').filter(Boolean);
    const expected = readFileSync(join(root, name, 'js.txt'), 'utf8');
    const entry = join(root, name, 'entry.txt');
    const ast = existsSync(entry)
      ? linkCore([core], readFileSync(entry, 'utf8').trim(), { nativeNames: natives }).ast
      : readCore(core, { nativeNames: natives });
    assert.equal(compileCore(ast, { nativeNames: natives }), expected, name);
  }
});
