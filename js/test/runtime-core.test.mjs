import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { compileCore } from '../core/compiler.mjs';
import { compileLinkedCore, linkCore } from '../core/linker.mjs';
import * as runtime from '../core/runtime.mjs';

// Runs a compiled program with a time limit, so a loop that never ends
// fails the test rather than hanging it.
function run(source, natives = {}) {
  const script = `${source.replace('export function evaluate', 'function evaluate')}\nevaluate(runtime, natives);`;
  return vm.runInNewContext(script, { runtime, natives }, { timeout: 2000 });
}

test('a binder that repeats a function\'s qualified name hides it from the self-tail loop', () => {
  // Linking qualifies the module's f as m:f, which these binders repeat.
  const programs = {
    let: '(def f (lam x (if (eq x 0) (app f 1) (let m:f (lam y (cons y y)) (app m:f x)))))',
    rec: '(def f (lam x (if (eq x 0) (app f 1) (rec ((m:f (lam y (cons y y)))) (app m:f x)))))',
  };
  for (const [binder, definition] of Object.entries(programs)) {
    const linked = compileLinkedCore([`(module m ${definition} (def main (app f 5)))`], 'm:main');
    assert.deepEqual(run(linked.source), [5n, 5n], binder);
    // A call by the name that isn't hidden is still a loop.
    assert.match(linked.source, /continue;/, binder);
  }
  // A parameter of that name is the gate it was given, not the function.
  const parameter = compileLinkedCore([
    '(module m (def f (lam m:f (app m:f 1))) (def main (app f (lam z (cons z z)))))',
  ], 'm:main');
  assert.deepEqual(run(parameter.source), [1n, 1n]);
  // Unhidden self calls still run in constant stack.
  const loop = compileCore('(rec ((f (lam n (if (eq n 0) 7 (app f (app (native dec) n)))))) (app f 100.000))',
    { nativeNames: ['dec'] });
  assert.equal(run(loop, { dec: n => n - 1n }), 7n);
});

test('a module value that uses a later definition, or itself, is a Core error', () => {
  for (const [source, message] of [
    ['(module a (def x y) (def y 1))', /Core value x uses y before its definition/],
    ['(module a (def x x))', /Core value x depends on itself/],
    ['(module a (def x (cons 1 x)))', /Core value x depends on itself/],
    // Through a gate: f's body uses y, which isn't defined when x runs f.
    ['(module a (def f (lam z y)) (def x (app f 0)) (def y 1))', /Core value x uses y before its definition/],
    ['(module a (def f (lam z x)) (def x (cons 1 (app f 0))))', /Core value x depends on itself/],
  ]) {
    assert.throws(() => compileCore(source), message, source);
  }
  // Gates may use what comes later; values what comes before.
  for (const source of [
    '(module a (def f (lam x (app g x))) (def g (lam y y)))',
    '(module a (def y 1) (def x (cons y y)))',
    '(module a (def f (lam z y)) (def y 1) (def x (app f 0)))',
  ]) {
    assert.doesNotThrow(() => compileCore(source), source);
  }
  const values = run(compileCore('(module a (def f (lam z y)) (def y 1) (def x (app f 0)))'));
  assert.equal(values.x, 1n);
});

test('linking orders modules and a whole module\'s value by code point, as Hoon does', () => {
  // Thai collation ignores punctuation, so a-c sorts after ab there, but
  // Hoon's +tape-before puts - (45) before b (98) whatever the locale.
  const original = String.prototype.localeCompare;
  String.prototype.localeCompare = function localeCompare(other) {
    return original.call(this, other, 'th');
  };
  try {
    assert.ok('a-c'.localeCompare('ab') > 0, 'the stand-in collation ignores the hyphen');
    const whole = linkCore(['(module m (def ab 1) (def a-c 2))'], { module: 'm', wholeModule: true });
    assert.deepEqual(whole.ast.body.body, {
      type: 'cons', head: { type: 'name', name: 'm:a-c' }, tail: { type: 'name', name: 'm:ab' },
    });
    const value = run(compileLinkedCore(['(module m (def ab 1) (def a-c 2))'], { module: 'm', wholeModule: true }).source);
    assert.deepEqual(value, [2n, 1n]);
    // Module paths too: the definitions of a/b-c's module come before ab's.
    const linked = linkCore([
      '(module ab (def x 1))',
      '(module a-c (def y 2))',
      '(module main (def z (cons ab:x a-c:y)))',
    ], 'main:z');
    assert.deepEqual(linked.definitions, ['a-c:y', 'ab:x', 'main:z']);
  } finally {
    String.prototype.localeCompare = original;
  }
});
