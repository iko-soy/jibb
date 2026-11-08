import test from 'node:test';
import assert from 'node:assert/strict';
import { compileCore } from '../core/compiler.mjs';
import { evaluateCore } from '../core/node.mjs';
import { apply } from '../core/runtime.mjs';

const dec = (value) => {
  if (value === 0n) throw new Error('decrement underflow');
  return value - 1n;
};

test('direct self-tail-calls run 200,000 iterations without stack growth', async () => {
  const source = `
    (rec ((loop (lam n
      (if (eq n 0)
        42
        (app loop (app (native dec) n))))))
      (app loop 200.000))
  `;
  const generated = compileCore(source, { nativeNames: ['dec'] });
  assert.match(generated, /for \(;;\)/);
  assert.match(generated, /continue;/);
  assert.equal(await evaluateCore(source, { natives: { dec } }), 42n);
});

test('tail positions include let bodies and both if branches', async () => {
  const source = `
    (rec ((loop (lam n
      (let next (app (native dec) n)
        (if (eq next 0)
          42
          (app loop next))))))
      (app loop 100.000))
  `;
  assert.equal(await evaluateCore(source, { natives: { dec } }), 42n);
});

test('each iteration has a fresh parameter binding for captured closures', async () => {
  const source = '(rec ((loop (lam state (let n (slot 2 state) (let acc (slot 3 state) (if (eq n 0) acc (app loop (cons (app (native dec) n) (cons (lam x n) acc))))))))) (app loop (cons 3 ~)))';
  const captured = await evaluateCore(source, { natives: { dec } });
  const values = [];
  for (let current = captured; current !== 0n; current = current[1]) {
    values.push(apply(current[0], 99n));
  }
  assert.deepEqual(values, [1n, 2n, 3n]);
});

test('tail arguments are evaluated exactly once before iteration', async () => {
  const lines = [];
  const source = `
    (rec ((loop (lam n
      (if (eq n 0)
        42
        (app loop (trace "tick" (app (native dec) n)))))))
      (app loop 3))
  `;
  assert.equal(await evaluateCore(source, {
    natives: { dec },
    logger: (line) => lines.push(line),
  }), 42n);
  assert.deepEqual(lines, ['tick', 'tick', 'tick']);
});

test('non-tail and trace-wrapped recursion retain ordinary call semantics', async () => {
  const nonTail = '(rec ((f (lam n (if (eq n 0) 0 (cons 1 (app f (app (native dec) n))))))) (app f 3))';
  assert.doesNotMatch(compileCore(nonTail, { nativeNames: ['dec'] }), /for \(;;\)/);
  assert.deepEqual(await evaluateCore(nonTail, { natives: { dec } }), [1n, [1n, [1n, 0n]]]);

  const traced = '(rec ((f (lam n (if (eq n 0) 42 (trace "next" (app f (app (native dec) n))))))) (app f 2))';
  assert.doesNotMatch(compileCore(traced, { nativeNames: ['dec'] }), /for \(;;\)/);
  const lines = [];
  assert.equal(await evaluateCore(traced, {
    natives: { dec },
    logger: (line) => lines.push(line),
  }), 42n);
  assert.deepEqual(lines, ['next', 'next']);
});
