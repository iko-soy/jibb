import test from 'node:test';
import assert from 'node:assert/strict';

import { readCore } from '../core/reader.mjs';
import { readLiteral } from '../core/literal.mjs';
import { CoreCrash } from '../core/runtime.mjs';
import { emitCore } from '../nock/emitter.mjs';
import { applyNock, runNock } from '../nock/interpreter.mjs';

const add = ([left, right]) => left + right;
const dec = value => value - 1n;

function compile(source, natives = {}) {
  const nativeNames = Object.keys(natives);
  return emitCore(readCore(source, { nativeNames }), { nativeNames });
}

function evaluate(source, { natives = {}, subject = 0n, logger } = {}) {
  return runNock(subject, compile(source, natives), natives, { logger });
}

function throwsCore(fn, message) {
  assert.throws(fn, error => {
    assert.ok(error instanceof CoreCrash);
    if (message !== undefined) assert.match(error.message, message);
    return true;
  });
}

function cord(text) {
  return readLiteral(JSON.stringify(text)).value;
}

test('Nock 0 and 1 address subjects and preserve arbitrary-precision constants', () => {
  const tree = [[1n, 2n], [3n, 4n]];
  assert.strictEqual(runNock(tree, [0n, 1n]), tree);
  assert.strictEqual(runNock(tree, [0n, 2n]), tree[0]);
  assert.equal(runNock(tree, [0n, 6n]), 3n);
  assert.equal(runNock(tree, [0n, 7n]), 4n);
  const huge = 1234567890123456789012345678901234567890n;
  assert.equal(runNock(0n, [1n, huge]), huge);
  throwsCore(() => runNock(tree, [0n, 0n]));
  throwsCore(() => runNock(1n, [0n, 2n]));
});

test('Nock 2 computes a subject and formula and Nock 3 and 4 test nouns', () => {
  assert.equal(runNock(0n, [2n, [[1n, 42n], [1n, [0n, 1n]]]]), 42n);
  assert.deepEqual(
    runNock(0n, [2n, [[1n, [8n, 9n]], [1n, [0n, 3n]]]]),
    9n,
  );
  assert.equal(runNock(0n, [3n, [1n, 1n]]), 1n);
  assert.equal(runNock(0n, [3n, [1n, [1n, 2n]]]), 0n);
  assert.equal(runNock(0n, [4n, [1n, 41n]]), 42n);
  assert.equal(runNock(0n, [4n, [1n, 2n ** 2048n]]), 2n ** 2048n + 1n);
  throwsCore(() => runNock(0n, [4n, [1n, [1n, 2n]]]), /atom/);
});

test('Nock 5 compares complete nouns and Nock 6 is lazy and loobean-checked', () => {
  assert.equal(runNock(0n, [5n, [[1n, [1n, 2n]], [1n, [1n, 2n]]]]), 0n);
  assert.equal(runNock(0n, [5n, [[1n, [1n, 2n]], [1n, [1n, 3n]]]]), 1n);
  assert.equal(runNock(0n, [6n, [[1n, 0n], [[1n, 42n], [0n, 0n]]]]), 42n);
  assert.equal(runNock(0n, [6n, [[1n, 1n], [[0n, 0n], [1n, 43n]]]]), 43n);
  throwsCore(() => runNock(0n, [6n, [[1n, 2n], [[1n, 42n], [1n, 43n]]]]), /loobean/);
});

test('Nock 7, 8, 9, and 10 compose, push, kick, and edit', () => {
  assert.equal(runNock(0n, [7n, [[1n, [10n, 20n]], [0n, 2n]]]), 10n);
  assert.deepEqual(runNock(9n, [8n, [[1n, 42n], [0n, 1n]]]), [42n, 9n]);
  assert.equal(runNock(9n, [8n, [[1n, 42n], [0n, 2n]]]), 42n);
  assert.equal(runNock(9n, [8n, [[1n, 42n], [0n, 3n]]]), 9n);

  const gate = [[0n, 6n], [42n, 0n]];
  assert.equal(runNock(0n, [9n, [2n, [1n, gate]]]), 42n);
  assert.deepEqual(
    runNock(0n, [10n, [[6n, [1n, 99n]], [1n, [1n, [2n, 3n]]]]]),
    [1n, [99n, 3n]],
  );
  assert.equal(runNock(0n, [10n, [[1n, [1n, 99n]], [1n, [2n, 3n]]]]), 99n);
  throwsCore(() => runNock(0n, [10n, [[6n, [1n, 99n]], [1n, 1n]]]));
});

test('Nock 11 evaluates dynamic clues, ignores other hints, and logs %slog leaves', () => {
  assert.equal(runNock(0n, [11n, [123456n, [1n, 42n]]]), 42n);
  assert.equal(runNock(0n, [11n, [[123456n, [1n, 99n]], [1n, 42n]]]), 42n);
  throwsCore(() => runNock(0n, [11n, [[123456n, [0n, 0n]], [1n, 42n]]]));

  const slog = readLiteral('%slog').value;
  const leaf = readLiteral('%leaf').value;
  const clue = [[1n, 0n], [[1n, leaf], [1n, cord('hint')]]];
  const lines = [];
  assert.equal(
    runNock(0n, [11n, [[slog, clue], [1n, 42n]]], {}, { logger: line => lines.push(line) }),
    42n,
  );
  assert.deepEqual(lines, ['hint']);
});

test('emitter preserves the specified noun-operation formulas', () => {
  assert.deepEqual(compile('42'), [1n, 42n]);
  assert.deepEqual(compile('(cons 1 2)'), [[1n, 1n], [1n, 2n]]);
  assert.deepEqual(compile('(slot 2 42)'), [7n, [[1n, 42n], [0n, 2n]]]);
  assert.deepEqual(compile('(edit 2 1 42)'), [10n, [[2n, [1n, 42n]], [1n, 1n]]]);
  assert.deepEqual(compile('(cell? 1)'), [3n, [1n, 1n]]);
  assert.deepEqual(compile('(eq 1 2)'), [5n, [[1n, 1n], [1n, 2n]]]);
  assert.deepEqual(
    compile('(if %.y 1 2)'),
    [6n, [[1n, 0n], [[1n, 1n], [1n, 2n]]]],
  );
  assert.deepEqual(compile('(let x 1 x)'), [8n, [[1n, 1n], [0n, 2n]]]);
  assert.deepEqual(compile('(crash)'), [0n, 0n]);
  assert.deepEqual(
    compile('(app (native identity) 42)', { identity: [[0n, 6n], [0n, 0n]] })[1][1],
    [10n, [[6n, [1n, 42n]], [0n, 4n]]],
  );
});

test('all Core noun nodes evaluate with BigInt atoms and autocons', () => {
  const huge = 1234567890123456789012345678901234567890n;
  assert.equal(evaluate('1.234.567.890.123.456.789.012.345.678.901.234.567.890'), huge);
  assert.deepEqual(evaluate('(cons 1 "milk")'), [1n, readLiteral('"milk"').value]);
  assert.equal(evaluate('(slot 6 (cons 1 (cons 2 3)))'), 2n);
  assert.deepEqual(evaluate('(edit 6 (cons 1 (cons 2 3)) 42)'), [1n, [42n, 3n]]);
  assert.equal(evaluate('(cell? (cons 1 2))'), 0n);
  assert.equal(evaluate('(cell? 1)'), 1n);
  assert.equal(evaluate('(eq (cons 1 2) (cons 1 2))'), 0n);
  assert.equal(evaluate('(eq 12.345.678.901.234.567.890 12.345.678.901.234.567.891)'), 1n);
});

test('Core if and let preserve laziness, strictness, and lexical subject axes', () => {
  assert.equal(evaluate('(if %.y 42 (crash))'), 42n);
  assert.equal(evaluate('(if %.n (crash) 43)'), 43n);
  throwsCore(() => evaluate('(if 2 42 43)'), /loobean/);
  assert.equal(evaluate('(let x 40 (let y 2 x))'), 40n);
  assert.equal(
    evaluate('(let x 40 (let y 2 (app (native add) (cons x y))))', { natives: { add } }),
    42n,
  );
  throwsCore(() => evaluate('(let x (crash) 42)'));
});

test('lambda gates have battery at 2, sample at 6, closure at 7, and use direct application', () => {
  const gate = evaluate('(let x 40 (lam y (cons x y)))');
  assert.ok(Array.isArray(gate));
  assert.equal(gate[1][0], 0n); // untouched sample
  assert.equal(gate[1][1][0], 40n); // captured let value in context
  assert.deepEqual(applyNock(gate, 2n), [40n, 2n]);
  assert.equal(
    evaluate('(app (let x 40 (lam y (app (native add) (cons x y)))) 2)', { natives: { add } }),
    42n,
  );
  const identity = evaluate('(lam x x)');
  assert.equal(applyNock(identity, 2n ** 1024n), 2n ** 1024n);
});

test('rec cores support self recursion, mutual recursion, and gates returned as values', () => {
  const self = '(rec ((f (lam x (if (eq x 0) 42 (app f 0))))) (app f 9))';
  assert.equal(evaluate(self), 42n);
  const mutual = `
    (rec ((even (lam x (if (eq x 0) %.y (app odd (app (native dec) x)))))
          (odd (lam x (if (eq x 0) %.n (app even (app (native dec) x))))))
      (app even 10))
  `;
  assert.equal(evaluate(mutual, { natives: { dec } }), 0n);
  const returned = evaluate('(rec ((f (lam x (cons x x)))) f)');
  assert.deepEqual(applyNock(returned, 7n), [7n, 7n]);
});

test('deep recursive calls use the explicit evaluator stack', () => {
  const countdown = `
    (rec ((f (lam x (if (eq x 0) 0 (app f (app (native dec) x))))))
      (app f 5.000))
  `;
  assert.equal(evaluate(countdown, { natives: { dec } }), 0n);
});

test('native adapters and actual Hoon gates share the sample-at-axis-6 ABI', () => {
  const hoonIdentity = [[0n, 6n], [0n, 0n]];
  assert.equal(
    evaluate('(app (native identity) 42)', { natives: { identity: hoonIdentity } }),
    42n,
  );
  assert.equal(applyNock(hoonIdentity, 43n), 43n);
  assert.equal(applyNock(add, [40n, 2n]), 42n);
  assert.equal(
    evaluate('(app (native add) (cons 40 2))', { natives: { add } }),
    42n,
  );
});

test('a Hoon native gate and a JavaScript adapter can both call Jibb gates', () => {
  // The native sample is [callback value]. Its battery invokes callback with
  // value through precisely the same [9 2 10 [6 ...] ...] application rule.
  const callbackAt = [0n, 12n];
  const valueAt = [0n, 13n];
  const hoonCall = [[9n, [2n, [10n, [[6n, valueAt], callbackAt]]]], [0n, 0n]];
  assert.equal(
    evaluate('(app (native call) (cons (lam x (app (native add) (cons x 1))) 41))', {
      natives: { call: hoonCall, add },
    }),
    42n,
  );

  const applyTwice = (sample, applyGate) => {
    const [gate, value] = sample;
    return applyGate(gate, applyGate(gate, value));
  };
  assert.equal(
    evaluate('(app (native apply-twice) (cons (lam x (app (native add) (cons x 1))) 40))', {
      natives: { 'apply-twice': applyTwice, add },
    }),
    42n,
  );
});

test('native lookup is closed-world and never infers an implementation from spelling', () => {
  assert.throws(() => compile('(native add)'), /unknown native.*add/i);
  assert.throws(
    () => runNock(0n, compile('(native add)', { add }), {}),
    /missing native add/,
  );
  assert.throws(
    () => runNock(0n, compile('(native add)', { add }), { add: 42n }),
    /Hoon-shaped gate noun or adapter/,
  );
  assert.equal(
    evaluate('(app (native lookalike) 1)', { natives: { lookalike: value => value } }),
    1n,
  );
});

test('Core crash and invalid runtime operations remain CoreCrash failures', () => {
  throwsCore(() => evaluate('(crash)'));
  throwsCore(() => evaluate('(slot 2 1)'));
  throwsCore(() => evaluate('(edit 6 1 42)'));
  const nativeFailure = new Error('native failed');
  assert.throws(
    () => evaluate('(app (native fail) 0)', { natives: { fail: () => { throw nativeFailure; } } }),
    error => error === nativeFailure,
  );
  throwsCore(() => runNock(0n, [99n, 0n]), /unsupported opcode/);
});

test('Core traces emit ordered %slog leaf hints before their bodies', () => {
  const lines = [];
  const logger = line => lines.push(line);
  assert.equal(evaluate('(trace "outer" (trace "inner" 42))', { logger }), 42n);
  assert.deepEqual(lines, ['outer', 'inner']);
  lines.length = 0;
  assert.deepEqual(
    evaluate('(cons (trace "head" 1) (trace "tail" 2))', { logger }),
    [1n, 2n],
  );
  assert.deepEqual(lines, ['head', 'tail']);
  lines.length = 0;
  throwsCore(() => evaluate('(trace "before" (crash))', { logger }));
  assert.deepEqual(lines, ['before']);
});
