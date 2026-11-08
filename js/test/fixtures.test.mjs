import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { evaluateCore } from '../core/node.mjs';
import { apply, CoreCrash } from '../core/runtime.mjs';

const fixture = JSON.parse(
  await readFile(new URL('./fixtures/hand-written.json', import.meta.url), 'utf8'),
);

function expectedNoun(json) {
  if (typeof json.atom === 'string') {
    return BigInt(json.atom);
  }
  if (Array.isArray(json.cell) && json.cell.length === 2) {
    return json.cell.map(expectedNoun);
  }
  throw new Error(`invalid expected noun ${JSON.stringify(json)}`);
}

const natives = {
  add: ([left, right]) => left + right,
  sub: ([left, right]) => left - right,
  'apply-twice': ([fn, value]) => apply(fn, apply(fn, value)),
};

for (const { name, source, natives: names, outcome } of fixture.cases) {
  test(`shared hand-written Core: ${name}`, async () => {
    const registry = Object.fromEntries(names.map((name) => [name, natives[name]]));
    if (outcome.crash) {
      await assert.rejects(evaluateCore(source, { natives: registry }), CoreCrash);
    } else {
      assert.deepEqual(
        await evaluateCore(source, { natives: registry }),
        expectedNoun(outcome),
      );
    }
  });
}
