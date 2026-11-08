import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { measureSync } from '../bench/timing.mjs';

test('benchmark validates every case and emits machine-readable timings', () => {
  const output = execFileSync(
    process.execPath,
    ['js/bench/compare.mjs', '--iterations', '1', '--warmups', '1', '--json'],
    { cwd: new URL('../..', import.meta.url), encoding: 'utf8' },
  );
  const result = JSON.parse(output);
  assert.equal(result.warmup, 1);
  assert.deepEqual(result.cases.map((entry) => entry.name), [
    'tail-countdown',
    'tail-sum',
    'record-edit',
  ]);
  for (const entry of result.cases) {
    for (const stage of ['emission', 'execution']) {
      for (const backend of ['javascript', 'nock']) {
        assert.equal(entry[stage][backend].iterations, 1);
        assert.ok(entry[stage][backend].medianMs >= 0);
      }
    }
  }
});

test('benchmark timing rejects invalid iteration counts', () => {
  for (const value of [0, -1, 1.5, Number.NaN]) {
    assert.throws(() => measureSync(value, () => {}), /positive integer/);
  }
  assert.throws(
    () => execFileSync(process.execPath, ['js/bench/compare.mjs', '--case', 'missing'], {
      cwd: new URL('../..', import.meta.url),
      stdio: 'pipe',
    }),
    /no benchmark matches/,
  );
});
