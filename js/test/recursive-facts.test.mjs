// This Core comes from real Hoon mark sources, the full Jibb checker and
// its derived-request lowering. tests/lib/jibb-recursive-facts.hoon pins
// the exact linked expression and runs the same inputs in Hoon/Core/Nock.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { readCore } from '../core/reader.mjs';
import { evaluateCore } from '../core/node.mjs';
import { CoreCrash } from '../core/runtime.mjs';
import { emitCore } from '../nock/emitter.mjs';
import { applyNock, runNock } from '../nock/interpreter.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';

const linked = readFileSync(new URL('../../tests/type-recursive-facts/core.txt', import.meta.url), 'utf8');
assert.equal(
  readFileSync(new URL('../../tests/js-emit/extra-checked-recursive-facts/core.txt', import.meta.url), 'utf8'),
  linked,
  'the browser emitter fixture must use the exact checked receiver Core',
);
const leaf = (flag, value) => [cord('leaf'), [flag, value]];
const branch = (...children) => [cord('branch'), arrayToList(children)];
const unit = value => [0n, value];
const tagged = (tag, value) => [cord(tag), value];
const roots = (items, stamp = 0n) => [arrayToList(items), stamp];
const nested = branch(leaf(0n, 7n), branch(leaf(1n, 9n)));
const tree = roots([nested], 42n);
function deepTree(value) {
  for (let depth = 0; depth < 192; depth += 1) value = branch(value);
  return value;
}
const cases = [
  ['tree leaf', 'tree-state', 0n, roots([leaf(0n, 7n)], 1n), true],
  ['tree nested full', 'tree-state', 0n, tree, true],
  ['tree nested diff', 'tree-diff', unit(roots([leaf(0n, 1n)])), [tree, 7n], true],
  ['tree empty children', 'tree-diff', unit(tree), [roots([branch()], 2n), 8n], true],
  ['tree empty roots', 'tree-state', 0n, roots([], 3n), true],
  ['tree unknown root tag', 'tree-state', 0n, roots([tagged('unknown', 0n)]), false],
  ['tree root atom', 'tree-state', 0n, cord('leaf'), false],
  ['tree nested unknown tag', 'tree-state', 0n, roots([branch([cord('wrong'), [0n, 1n]])]), false],
  ['tree nested boolean', 'tree-state', 0n, roots([branch(leaf(2n, 1n))]), false],
  ['tree nested atom field', 'tree-state', 0n, roots([branch(leaf(0n, [1n, 2n]))]), false],
  ['tree improper children', 'tree-state', 0n, roots([tagged('branch', [leaf(0n, 1n), 42n])]), false],
  ['tree malformed diff', 'tree-diff', unit(tree), [roots([branch(leaf(2n, 1n))]), 7n], false],
  ['tree unknown diff mark', 'unknown', unit(tree), [tree, 7n], false],
  ['tree improper roots', 'tree-state', 0n, [[nested, 42n], 0n], false],
  ['tree invalid stamp', 'tree-state', 0n, roots([nested], [1n, 2n]), false],
  ['tree valid sibling then invalid', 'tree-state', 0n, roots([nested, leaf(2n, 1n)]), false],
  ['tree full shape is not a diff', 'tree-diff', unit(tree), tree, false],
  ['tree diff shape is not full state', 'tree-state', 0n, [tree, 7n], false],
  ['tree invalid diff nonce', 'tree-diff', unit(tree), [tree, [1n, 2n]], false],
  ['tree deep full state', 'tree-state', 0n, roots([deepTree(leaf(0n, 7n))]), true],
  ['tree deep malformed leaf', 'tree-state', 0n, roots([deepTree(leaf(2n, 7n))]), false],
  ['tree valid after malformed', 'tree-diff', unit(tree), [roots([leaf(1n, 8n)], 99n), 9n], true],
];

function receiverSource() {
  return `(lam input (let request-gate ${linked}
    (let request (app request-gate
      (cons (lam answer (trace "reply" (cons %got answer)))
        (lam change (trace "fold"
          (if (eq (slot 3 change) (slot 3 (slot 6 input))) (slot 10 change) (crash))))))
      (app (slot 127 request) input))))`;
}

const source = receiverSource();
const jsTraces = [];
const nockTraces = [];
const receiver = {
  js: await evaluateCore(source, { logger: message => jsTraces.push(message) }),
  nock: runNock(0n, emitCore(readCore(source))),
  jsTraces, nockTraces,
};

for (const [name, mark, state, fact, valid] of cases) {
  test(`checked recursive fact: ${name}`, () => {
    const input = [cord(mark), [state, fact]];
    receiver.jsTraces.length = 0;
    receiver.nockTraces.length = 0;
    const javascript = () => receiver.js(input);
    const nock = () => applyNock(receiver.nock, input, {}, {
      logger: message => receiver.nockTraces.push(message),
    });
    if (valid) {
      const next = state === 0n ? fact : fact[0];
      const expected = [next, tagged('got', next)];
      assert.deepEqual(javascript(), expected);
      assert.deepEqual(nock(), expected);
      assert.deepEqual(receiver.jsTraces, state === 0n ? ['reply'] : ['fold', 'reply']);
      assert.deepEqual(receiver.nockTraces, receiver.jsTraces);
    } else {
      assert.throws(javascript, CoreCrash);
      assert.throws(nock, CoreCrash);
      // An outcome-only crash comparison would miss a callback executed
      // before a late validation error. Observe the actual callback traces.
      assert.deepEqual(receiver.jsTraces, []);
      assert.deepEqual(receiver.nockTraces, []);
    }
  });
}

const flatCount = 20_000;
const flatStamp = 123n;
function flatRoots(malformedLast = false) {
  let items = 0n;
  for (let index = flatCount - 1; index >= 0; index -= 1) {
    const flag = malformedLast && index === flatCount - 1 ? 2n : BigInt(index % 2);
    items = [leaf(flag, BigInt(index)), items];
  }
  return [items, flatStamp];
}

function assertCell(value) {
  assert.ok(Array.isArray(value));
  assert.equal(value.length, 2);
}

function assertFlatRoots(state) {
  assertCell(state);
  assert.equal(state[1], flatStamp);
  let items = state[0];
  const leafTag = cord('leaf');
  // Traverse the output iteratively: a recursive assertion could itself
  // overflow and conceal whether the receiver handled a long list.
  for (let index = 0; index < flatCount; index += 1) {
    assertCell(items);
    const item = items[0];
    assertCell(item);
    assert.equal(item[0], leafTag);
    assertCell(item[1]);
    assert.equal(item[1][0], BigInt(index % 2));
    assert.equal(item[1][1], BigInt(index));
    items = items[1];
  }
  assert.equal(items, 0n);
}

for (const malformed of [false, true]) {
  test(`checked recursive fact: long flat list ${malformed ? 'rejects a late malformed leaf' : 'accepts every leaf'}`, () => {
    const replacement = flatRoots(malformed);
    for (const diff of [false, true]) {
      const input = [cord(diff ? 'tree-diff' : 'tree-state'), [
        diff ? unit(roots([])) : 0n,
        diff ? [replacement, 7n] : replacement,
      ]];
      for (const backend of ['js', 'nock']) {
        const traces = backend === 'js' ? receiver.jsTraces : receiver.nockTraces;
        traces.length = 0;
        const run = backend === 'js' ? () => receiver.js(input) : () => applyNock(receiver.nock, input, {}, {
          logger: message => traces.push(message),
        });
        if (malformed) {
          assert.throws(run, CoreCrash);
          assert.deepEqual(traces, []);
        } else {
          const out = run();
          assertCell(out);
          assertFlatRoots(out[0]);
          assertCell(out[1]);
          assert.equal(out[1][0], cord('got'));
          assertFlatRoots(out[1][1]);
          assert.deepEqual(traces, diff ? ['fold', 'reply'] : ['reply']);
        }
      }
    }
  });
}
