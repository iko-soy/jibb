import test from 'node:test';
import assert from 'node:assert/strict';
import { compileLinkedCore, linkCore } from '../core/linker.mjs';
import { evaluateCore } from '../core/node.mjs';
import { apply } from '../core/runtime.mjs';
import { readCore } from '../core/reader.mjs';

const add = ([left, right]) => left + right;
const sub = ([left, right]) => left - right;

const utility = `
  (module util
    (def base 40)
    (def add-base (lam x (app (native add) (cons base x))))
    (def unused (crash)))
`;
const island = `
  (module island
    (def update (lam x (app util:add-base x))))
`;

test('links only definitions reachable from an entry', async () => {
  const linked = linkCore([utility, island], 'island:update', { nativeNames: ['add'] });
  assert.deepEqual(linked.definitions, [
    'util:base',
    'util:add-base',
    'island:update',
  ]);
  assert.deepEqual(linked.nativeNames, ['add']);
  const update = await evaluateCore(linked.ast, { natives: { add } });
  assert.equal(apply(update, 2n), 42n);
});

test('module input order does not change deterministic linked output', () => {
  const first = compileLinkedCore([utility, island], 'island:update', { nativeNames: ['add'] });
  const second = compileLinkedCore([island, utility], 'island:update', { nativeNames: ['add'] });
  assert.equal(first.source, second.source);
  assert.deepEqual(first.definitions, second.definitions);
});

test('non-gate dependencies are computed once per linked program', async () => {
  const lines = [];
  const source = `
    (module app
      (def base (trace "compute" 40))
      (def update (lam x (app (native add) (cons base x)))))
  `;
  const linked = linkCore([source], 'app:update', { nativeNames: ['add'] });
  const update = await evaluateCore(linked.ast, {
    natives: { add },
    logger: (line) => lines.push(line),
  });
  assert.deepEqual(lines, ['compute']);
  assert.equal(apply(update, 1n), 41n);
  assert.equal(apply(update, 2n), 42n);
  assert.deepEqual(lines, ['compute']);
});

test('mutually recursive definitions become one rec group', async () => {
  const source = `
    (module math
      (def even (lam x (if (eq x 0) %.y (app odd (app (native sub) (cons x 1))))))
      (def odd (lam x (if (eq x 0) %.n (app even (app (native sub) (cons x 1)))))))
  `;
  const linked = linkCore([source], 'math:even', { nativeNames: ['sub'] });
  assert.equal(linked.ast.type, 'rec');
  assert.deepEqual(linked.ast.bindings.map((binding) => binding.name), ['math:even', 'math:odd']);
  const even = await evaluateCore(linked.ast, { natives: { sub } });
  assert.equal(apply(even, 10n), 0n);
  assert.equal(apply(even, 11n), 1n);
});

test('recursive non-gate definitions fail closed', () => {
  assert.throws(
    () => linkCore(['(module bad (def x (cons x 1)))'], 'bad:x'),
    /recursive non-gate definition bad:x/,
  );
});

test('unreachable unknown natives are pruned; reachable ones reject', () => {
  const source = `
    (module app
      (def good 42)
      (def bad (native lookalike)))
  `;
  assert.equal(linkCore([source], 'app:good').nativeNames.length, 0);
  assert.throws(() => linkCore([source], 'app:bad'), /unknown native lookalike/);
});

test('native evidence is preserved rather than inferred from definition spelling', async () => {
  const source = `
    (module app
      (def add (lam x x))
      (def explicit (native add)))
  `;
  const ordinary = await evaluateCore(linkCore([source], 'app:add').ast, {
    natives: { add },
  });
  assert.equal(apply(ordinary, 42n), 42n);
  const explicit = await evaluateCore(linkCore([source], 'app:explicit', { nativeNames: ['add'] }).ast, {
    natives: { add },
  });
  assert.strictEqual(explicit, add);
});

test('whole-module linking retains all definitions in name order', async () => {
  const source = `
    (module util
      (def z 1)
      (def a 2)
      (def hidden 3))
  `;
  const linked = linkCore([source], { module: 'util', wholeModule: true });
  assert.deepEqual(linked.definitions, ['util:z', 'util:a', 'util:hidden']);
  assert.deepEqual(await evaluateCore(linked.ast), [2n, [3n, 1n]]);
});

test('whole-module linking keeps external dependencies', async () => {
  const result = await evaluateCore(linkCore(
    [utility, '(module whole (def answer util:base))'],
    { module: 'whole', wholeModule: true },
  ).ast);
  assert.equal(result, 40n);
});

test('empty whole modules and missing references fail closed', () => {
  assert.throws(
    () => linkCore(['(module empty)'], { module: 'empty', wholeModule: true }),
    /empty module/,
  );
  assert.throws(
    () => linkCore(['(module app (def x missing))'], 'app:x'),
    /unbound linked definition app:missing/,
  );
  assert.throws(() => linkCore([utility], 'island:update'), /unknown link entry/);
  assert.throws(
    () => linkCore(['(module empty)', '(module empty)'], { module: 'empty', wholeModule: true }),
    /duplicate module empty/,
  );
});

test('linking does not mutate source ASTs', () => {
  const module = readCore(utility);
  const before = structuredClone(module);
  linkCore([module], { module: 'util', wholeModule: true }, { nativeNames: ['add'] });
  assert.deepEqual(module, before);
});
