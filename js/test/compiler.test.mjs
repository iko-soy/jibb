import test from 'node:test';
import assert from 'node:assert/strict';
import { compileCore } from '../core/compiler.mjs';
import { evaluateCore } from '../core/node.mjs';
import { apply, CoreCrash } from '../core/runtime.mjs';
import { readLiteral } from '../core/literal.mjs';

const add = (sample) => {
  const [left, right] = sample;
  return left + right;
};
const sub = (sample) => {
  const [left, right] = sample;
  return left - right;
};

test('compiles every noun operation with arbitrary-precision atoms', async () => {
  const huge = 1234567890123456789012345678901234567890n;
  assert.equal(await evaluateCore('1.234.567.890.123.456.789.012.345.678.901.234.567.890'), huge);
  assert.deepEqual(await evaluateCore('(cons 1 "milk")'), [1n, readLiteral('"milk"').value]);
  assert.equal(await evaluateCore('(slot 6 (cons 1 (cons 2 3)))'), 2n);
  assert.deepEqual(
    await evaluateCore('(edit 6 (cons 1 (cons 2 3)) 42)'),
    [1n, [42n, 3n]],
  );
  assert.equal(await evaluateCore('(cell? (cons 1 2))'), 0n);
  assert.equal(await evaluateCore('(cell? 1)'), 1n);
  assert.equal(await evaluateCore('(eq (cons 1 2) (cons 1 2))'), 0n);
  assert.equal(await evaluateCore('(eq 12.345.678.901.234.567.890 12.345.678.901.234.567.891)'), 1n);
});

test('if evaluates only the selected branch and validates its test', async () => {
  assert.equal(await evaluateCore('(if %.y 42 (crash))'), 42n);
  assert.equal(await evaluateCore('(if %.n (crash) 43)'), 43n);
  await assert.rejects(evaluateCore('(if 2 42 43)'), CoreCrash);
});

test('let is strict even when its value is unused', async () => {
  assert.equal(await evaluateCore('(let x 40 (let y 2 x))'), 40n);
  await assert.rejects(evaluateCore('(let x (crash) 42)'), CoreCrash);
});

test('closures and native calls preserve sample layout and lexical capture', async () => {
  const result = await evaluateCore(
    '(app (let x 40 (lam y (app (native add) (cons x y)))) 2)',
    { natives: { add } },
  );
  assert.equal(result, 42n);
  const fn = await evaluateCore('(lam x (cons x x))');
  assert.deepEqual(apply(fn, 7n), [7n, 7n]);
  const carried = await evaluateCore('(slot 2 (cons (lam x x) 0))');
  assert.equal(apply(carried, 8n), 8n);
});

test('recursive function declarations support self and mutual recursion', async () => {
  const self = '(rec ((f (lam x (if (eq x 0) 42 (app f 0))))) (app f 9))';
  assert.equal(await evaluateCore(self), 42n);
  const mutual = `
    (rec ((even (lam x (if (eq x 0) %.y (app odd (app (native sub) (cons x 1))))))
          (odd (lam x (if (eq x 0) %.n (app even (app (native sub) (cons x 1)))))))
      (app even 10))
  `;
  assert.equal(await evaluateCore(mutual, { natives: { sub } }), 0n);
});

test('higher-order natives can call generated closures', async () => {
  const applyTwice = (sample) => {
    const [fn, value] = sample;
    return apply(fn, apply(fn, value));
  };
  const result = await evaluateCore(
    '(app (native apply-twice) (cons (lam x (app (native add) (cons x 1))) 40))',
    { natives: { add, 'apply-twice': applyTwice } },
  );
  assert.equal(result, 42n);
});

test('traces print in evaluation order before their bodies', async () => {
  const lines = [];
  const logger = (line) => lines.push(line);
  assert.equal(
    await evaluateCore('(trace "outer" (trace "inner" 42))', { logger }),
    42n,
  );
  assert.deepEqual(lines, ['outer', 'inner']);
  lines.length = 0;
  assert.deepEqual(
    await evaluateCore('(cons (trace "head" 1) (trace "tail" 2))', { logger }),
    [1n, 2n],
  );
  assert.deepEqual(lines, ['head', 'tail']);
  lines.length = 0;
  await assert.rejects(evaluateCore('(trace "before" (crash))', { logger }), CoreCrash);
  assert.deepEqual(lines, ['before']);
});

test('explicit crashes and malformed runtime nouns remain crashes', async () => {
  await assert.rejects(evaluateCore('(crash)'), CoreCrash);
  await assert.rejects(evaluateCore('(slot 0 1)'));
  await assert.rejects(evaluateCore('(slot 2 1)'), CoreCrash);
  await assert.rejects(evaluateCore('(eq (lam x x) (lam x x))'), CoreCrash);
});

test('native names fail closed at compilation and instantiation', async () => {
  assert.throws(() => compileCore('(native lookalike)'), /unknown native/i);
  const source = compileCore('(native add)', { nativeNames: ['add'] });
  const generated = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
  const runtime = await import('../core/runtime.mjs');
  assert.throws(() => generated.evaluate(runtime, {}), /missing native add/);
});

test('module evaluation returns definitions in source order', async () => {
  const result = await evaluateCore(`
    (module example
      (def answer 42)
      (def call-later (lam x (app identity x)))
      (def identity (lam x x)))
  `);
  assert.deepEqual(Object.keys(result), ['answer', 'call-later', 'identity']);
  assert.equal(result.answer, 42n);
  assert.equal(apply(result.identity, 9n), 9n);
  assert.equal(apply(result['call-later'], 10n), 10n);
});

test('compiler output is deterministic JavaScript', () => {
  const input = '(let x 1 (cons x (native add)))';
  assert.equal(
    compileCore(input, { nativeNames: ['add'] }),
    compileCore(input, { nativeNames: ['add'] }),
  );
  assert.match(compileCore('42'), /export function evaluate/);
});
