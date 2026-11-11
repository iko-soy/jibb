// Deterministic allocation accounting at the generated Core boundary. This
// counts successful cons/edit cells and canonical raw-seal wrapper cells. It
// does not count native internals, JS hole vectors/closures, DOM or heap bytes.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { compileCore } from '../core/compiler.mjs';
import * as runtime from '../core/runtime.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { cord } from '../natives/helpers.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { compiledViewTemplate } from '../browser/template.mjs';
import { startIsland } from '../browser/island.mjs';
import { createFakeDocument } from '../test/fake-dom.mjs';

export const sealCore = (tag, payload) => `(app (native raw-seal) (cons %${tag} ${payload}))`;
export const listCore = (...values) => values.reduceRight((tail, head) => `(cons ${head} ${tail})`, '~');
export const layoutCore = (tag, attrs, ...children) => sealCore(tag,
  `(cons ${attrs} ${tag === 'el' ? children[0] : listCore(...children)})`);

export async function instantiate(source, { optimized = true, natives = loweredNatives } = {}) {
  let counts = { cons: 0, edit: 0, seals: 0 };
  const traces = [];
  const calls = [];
  const names = new Map(Object.entries(natives).map(([name, fn]) => [fn, name]));
  const plans = new WeakMap();
  const js = compileCore(source, { nativeNames: Object.keys(natives) });
  const module = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
  const value = module.evaluate({
    ...runtime,
    cons(head, tail) {
      const value = runtime.cons(head, tail);
      counts.cons++;
      return value;
    },
    edit(axis, target, replacement) {
      const value = runtime.edit(axis, target, replacement);
      counts.edit += BigInt(axis).toString(2).length - 1;
      return value;
    },
    apply(fn, argument) {
      if (names.has(fn)) calls.push(names.get(fn));
      const value = runtime.apply(fn, argument);
      if (fn === loweredNatives['raw-seal']) counts.seals++;
      return value;
    },
    traceLazy(message, body) {
      return runtime.traceLazy(message, body, text => traces.push(text));
    },
    viewTemplate(gate, tree, axes, selectedNatives, holesGate) {
      plans.set(gate, { tree, axes, natives: selectedNatives, holesGate });
      return optimized
        ? compiledViewTemplate(gate, tree, axes, selectedNatives, holesGate)
        : gate;
    },
  }, natives);
  return {
    value, plans, traces, calls,
    reset() {
      counts = { cons: 0, edit: 0, seals: 0 };
      traces.length = calls.length = 0;
    },
    counts: () => ({ ...counts, total: counts.cons + counts.edit + counts.seals }),
  };
}

export function mount(view, model) {
  const document = createFakeDocument();
  const errors = [];
  const messages = [];
  const island = startIsland({
    document, container: document.body, model,
    program: {
      init: () => model,
      update: ([message]) => { messages.push(message); return [message, 0n]; },
      view,
    },
    onCrash: error => errors.push(error),
  });
  return { document, island, errors, messages };
}

// Compare observable DOM without depending on empty vnode style bags or
// unrelated renderer metadata. Control values are DOM properties as well.
export function domSnapshot(node) {
  if (node.nodeType === 3) return node.nodeValue;
  return {
    tag: node.localName,
    attrs: [...node.attributes].sort(([a], [b]) => a.localeCompare(b)),
    style: Object.entries(node.style).filter(([, value]) => value !== '')
      .sort(([a], [b]) => a.localeCompare(b)),
    value: node.value, checked: node.checked, disabled: node.disabled,
    children: node.childNodes.map(domSnapshot),
  };
}

const gap = listCore('(cons %gap %s2)');
const width = listCore('(cons %width (cons %fill 1))');
const tone = listCore('(cons %tone %danger)');
// Model construction is outside the measured compiled gate. Reusing this
// keyed list isolates the fixed view work from changes to the row collection.
const stableItems = [[1n, rawSeal([cord('text'), cord('one')])],
  [[2n, rawSeal([cord('text'), cord('two')])], 0n]];
const stableNumbers = [1n, [2n, [3n, 0n]]];

export const allocationCases = [
  {
    name: 'checked-column-text',
    source: readFileSync(new URL('../../tests/view-template/core.txt', import.meta.url), 'utf8'),
    initial: cord('first'), models: ['second', 'third', 'fourth', 'fifth', 'sixth'].map(cord),
    expected: { cons: 0, edit: 0, seals: 0, total: 0 },
  },
  {
    name: 'fixed-attributes-and-nested-layout',
    source: `(lam model ${layoutCore('column', gap,
      layoutCore('el', width, layoutCore('row', tone,
        sealCore('heading', '(cons 2 "Title")'), sealCore('text', 'model'))))})`,
    initial: cord('first'), models: ['second', 'third', 'fourth', 'fifth', 'sixth'].map(cord),
    expected: { cons: 0, edit: 0, seals: 0, total: 0 },
  },
  {
    name: 'opaque-button-hole',
    source: `(lam model ${layoutCore('column', gap,
      sealCore('heading', '(cons 2 "Title")'), sealCore('button', '(cons "Press" model)'))})`,
    initial: 0n, models: [1n, 2n, 3n, 4n, 5n],
    expected: { cons: 2, edit: 0, seals: 1, total: 3 },
  },
  {
    name: 'stable-keyed-element-hole',
    source: `(let each (lam items ${sealCore('each', 'items')})
      (lam model ${layoutCore('column', '~', sealCore('text', '(slot 2 model)'),
        '(app each (slot 3 model))')}))`,
    initial: [cord('first'), stableItems],
    models: ['second', 'third', 'fourth', 'fifth', 'sixth'].map(words => [cord(words), stableItems]),
    expected: { cons: 0, edit: 0, seals: 0, total: 0 },
  },
  {
    name: 'validated-keyed-element-hole',
    source: `(let each (lam items (let checked (app (native lent) items) ${sealCore('each', 'items')}))
      (lam model ${layoutCore('column', '~', sealCore('text', '(slot 2 model)'),
        '(app each (slot 3 model))')}))`,
    initial: [cord('first'), stableItems],
    models: ['second', 'third', 'fourth', 'fifth', 'sixth'].map(words => [cord(words), stableItems]),
    expected: { cons: 0, edit: 0, seals: 0, total: 0 },
  },
  {
    name: 'hoisted-row-callback-and-opaque-mapper',
    source: `(let each (lam items ${sealCore('each', 'items')})
      (rec ((map (lam pair (if (cell? (slot 2 pair))
        (cons (app (slot 3 pair) (slot 4 pair))
          (app map (cons (slot 5 pair) (slot 3 pair)))) ~))))
        (lam model ${layoutCore('column', '~', sealCore('text', '(slot 2 model)'),
          `(app each (app map (cons (slot 3 model) (lam n
            (cons n ${sealCore('text', '(app (native scot) (cons %ud n))')})))))`)})))`,
    initial: [cord('first'), stableNumbers],
    models: ['second', 'third', 'fourth', 'fifth', 'sixth'].map(words => [cord(words), stableNumbers]),
    expected: { cons: 1, edit: 0, seals: 0, total: 1 },
  },
];

export async function measureAllocations(test) {
  // Evaluation creates independent memo caches even when Node reuses the
  // imported module namespace. Module setup and the first mount are separate.
  const ordinary = await instantiate(test.source, { optimized: false });
  const direct = await instantiate(test.source);
  const plan = direct.plans.get(direct.value);
  assert.equal(typeof plan?.holesGate, 'function', `${test.name}: no direct hole gate`);
  assert.strictEqual(plan.natives, loweredNatives);
  ordinary.reset();
  direct.reset();
  const before = mount(ordinary.value, test.initial);
  const after = mount(direct.value, test.initial);
  assert.equal(before.errors.length, 0);
  assert.equal(after.errors.length, 0);
  assert.ok(after.island.template, `${test.name}: browser did not select a template`);
  assert.equal(before.island.template, null);
  assert.deepEqual(domSnapshot(after.island.node), domSnapshot(before.island.node));
  const mountCounts = { ordinary: ordinary.counts(), direct: direct.counts() };
  assert.deepEqual(mountCounts.direct, mountCounts.ordinary, 'first mount must evaluate the ordinary view once');
  const updates = [];
  for (const model of test.models) {
    ordinary.reset();
    direct.reset();
    before.island.send(model);
    after.island.send(model);
    assert.equal(before.errors.length, 0);
    assert.equal(after.errors.length, 0);
    assert.deepEqual(domSnapshot(after.island.node), domSnapshot(before.island.node));
    const counts = { ordinary: ordinary.counts(), direct: direct.counts() };
    assert.deepEqual(counts.direct, test.expected, `${test.name}: unexpected update noun cells`);
    assert.ok(counts.direct.total < counts.ordinary.total, `${test.name}: no noun-cell reduction`);
    updates.push(counts);
  }
  return { name: test.name, mount: mountCounts, updates };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const results = [];
  for (const test of allocationCases) results.push(await measureAllocations(test));
  console.log(JSON.stringify({
    metric: 'generated noun cells: cons + edit path cells + canonical raw-seal wrappers',
    excludes: 'native internals, JavaScript hole vectors/closures, DOM and heap bytes',
    cases: results,
  }, null, 2));
}
