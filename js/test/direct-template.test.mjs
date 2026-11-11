import test from 'node:test';
import assert from 'node:assert/strict';
import * as runtime from '../core/runtime.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { cord } from '../natives/helpers.mjs';
import { toVnode } from '../browser/vdom.mjs';
import {
  allocationCases, domSnapshot, instantiate, layoutCore, measureAllocations, mount, sealCore,
} from '../bench/template-allocations.mjs';

const text = payload => sealCore('text', payload);
const column = (...children) => layoutCore('column', '~', ...children);
const errorOf = operation => {
  try { operation(); } catch (error) { return { name: error.name, message: error.message }; }
  assert.fail('expected an exception');
};

for (const fixture of allocationCases) {
  test(`direct holes reduce generated noun cells: ${fixture.name}`, async () => {
    await measureAllocations(fixture);
  });
}

test('allocation counters leave public gate nouns and native provenance unchanged', async () => {
  for (const fixture of allocationCases) {
    const ordinary = await instantiate(fixture.source, { optimized: false });
    const direct = await instantiate(fixture.source);
    for (const model of [fixture.initial, ...fixture.models]) {
      const before = ordinary.value(model);
      const after = direct.value(model);
      assert.equal(runtime.same(after, before), 0n, fixture.name);
      assert.deepEqual(toVnode(after), toVnode(before), fixture.name);
    }
  }
});

test('direct holes evaluate shared native work once and retain its result in both holes', async () => {
  const source = `(lam model (let words (app (native scot) (cons %ud model))
    ${column(text('words'), text('words'))}))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
  const a = mount(direct.value, 0n);
  const b = mount(ordinary.value, 0n);
  for (const model of [1n, 2n, 3n]) {
    direct.reset();
    ordinary.reset();
    a.island.send(model);
    b.island.send(model);
    assert.deepEqual(a.errors, []);
    assert.deepEqual(b.errors, []);
    assert.equal(direct.calls.filter(name => name === 'scot').length, 1);
    assert.equal(ordinary.calls.filter(name => name === 'scot').length, 1);
    assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    assert.equal(a.island.node.childNodes[0].nodeValue, a.island.node.childNodes[1].nodeValue);
  }
});

test('traces and discarded work keep their ordinary order through direct holes or fallback', async () => {
  const source = `(lam model
    (let ignored (trace "before" ~)
      (let words (trace "shared" model)
        (let shown ${column(text('words'), text('words'))}
          (let finished (trace "after" ~) shown)))))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  for (const model of [cord('next'), cord('again')]) {
    direct.reset();
    ordinary.reset();
    a.island.send(model);
    b.island.send(model);
    assert.deepEqual(a.errors, []);
    assert.deepEqual(b.errors, []);
    assert.deepEqual(direct.traces, ordinary.traces);
    assert.equal(direct.traces.length, 3);
    assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  }
});

test('discarded crashes and native failures retain diagnostics and leave the previous view intact', async () => {
  for (const failure of ['(crash)', '(app (native dec) 0)']) {
    for (const later of [false, true]) {
      const body = later
        ? `(let shown ${column(text('model'))} (let ignored (if (eq model 0) ~ ${failure}) shown))`
        : `(let ignored (if (eq model 0) ~ ${failure}) ${column(text('model'))})`;
      const source = `(lam model ${body})`;
      const direct = await instantiate(source);
      const ordinary = await instantiate(source, { optimized: false });
      const a = mount(direct.value, 0n);
      const b = mount(ordinary.value, 0n);
      const old = domSnapshot(a.island.node);
      a.island.send(1n);
      b.island.send(1n);
      assert.equal(a.errors.length, 1);
      assert.equal(b.errors.length, 1);
      assert.deepEqual(errorOf(() => { throw a.errors[0]; }), errorOf(() => { throw b.errors[0]; }));
      assert.equal(a.island.model, 0n);
      assert.equal(b.island.model, 0n);
      assert.deepEqual(domSnapshot(a.island.node), old);
      assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    }
  }
});

test('erased cons cells keep their exact shallow validation failures', async () => {
  const instance = await instantiate(`(lam model ${column(text('model'))})`);
  const holes = instance.plans.get(instance.value)?.holesGate;
  assert.equal(typeof holes, 'function');
  for (const bad of [-1n, [0n, 'not a Core value'], [0n], null]) {
    const expected = errorOf(() => instance.value(bad));
    assert.match(expected.message, /^cons (head|tail):/);
    assert.deepEqual(errorOf(() => holes(bad)), expected);
  }
});

test('direct gates retain lexical captures and aliases across independent instances', async () => {
  const source = `(lam captured-value (let captured captured-value
    (lam words (let alias words (let fixed "fixed"
      ${column(text('captured'), text('alias'), text('fixed'))})))))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  const first = direct.value(cord('first'));
  const other = direct.value(cord('other'));
  assert.equal(typeof direct.plans.get(first)?.holesGate, 'function');
  assert.equal(typeof direct.plans.get(other)?.holesGate, 'function');
  const a = mount(first, cord('initial'));
  const b = mount(ordinary.value(cord('first')), cord('initial'));
  const separate = mount(other, cord('untouched'));
  a.island.send(cord('changed'));
  b.island.send(cord('changed'));
  assert.deepEqual(a.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.equal(a.island.node.textContent, 'firstchangedfixed');
  assert.equal(separate.island.node.textContent, 'otheruntouchedfixed');
});

test('closed callbacks reuse the ordinary hoist while captured callbacks follow the current model', async () => {
  for (const captured of [false, true]) {
    const callback = `(lam words (cons ${captured ? 'model' : '%typed'} words))`;
    const source = `(lam model ${column(sealCore('field', `(cons "Draft" (cons model ${callback}))`))})`;
    const direct = await instantiate(source);
    const ordinary = await instantiate(source, { optimized: false });
    assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
    const a = mount(direct.value, cord('first'));
    const b = mount(ordinary.value, cord('first'));
    let previous = a.island.vnode.children[0].control.reply;
    let originalPrevious = b.island.vnode.children[0].control.reply;
    for (const model of [cord('second'), cord('third')]) {
      a.island.send(model);
      b.island.send(model);
      assert.deepEqual(a.errors, []);
      assert.deepEqual(b.errors, []);
      assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
      const reply = a.island.vnode.children[0].control.reply;
      const original = b.island.vnode.children[0].control.reply;
      assert.equal(reply === previous, !captured, 'callback identity differs from its lexical lifetime');
      assert.equal(original === originalPrevious, !captured);
      assert.deepEqual(reply(cord('input')), [captured ? model : cord('typed'), cord('input')]);
      previous = reply;
      originalPrevious = original;
    }
  }
});

test('identical closed callbacks at different lexical sites retain the ordinary fallback', async () => {
  const callback = '(lam words (cons %typed words))';
  const field = label => sealCore('field', `(cons "${label}" (cons model ${callback}))`);
  const source = `(lam model ${column(field('First'), field('Second'))})`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  const replies = a.island.vnode.children.map(child => child.control.reply);
  assert.notStrictEqual(replies[0], replies[1], 'separate ordinary hoist slots were conflated');
  for (const model of [cord('second'), cord('third')]) {
    direct.reset();
    ordinary.reset();
    a.island.send(model);
    b.island.send(model);
    assert.deepEqual(a.errors, []);
    assert.deepEqual(b.errors, []);
    assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    assert.deepEqual(direct.counts(), ordinary.counts());
    a.island.vnode.children.forEach((child, index) => assert.strictEqual(child.control.reply, replies[index]));
  }
});

test('an unavailable hoisted capture keeps its ordinary fallback and module value', async () => {
  const source = `(let render (let saved (app (native scot) (cons %ud 1))
    (lam words ${text('saved')})) (lam model (app render model)))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  direct.reset();
  ordinary.reset();
  a.island.send(cord('second'));
  b.island.send(cord('second'));
  assert.deepEqual(a.errors, []);
  assert.deepEqual(b.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.equal(a.island.node.textContent, '1');
  assert.deepEqual(direct.counts(), ordinary.counts());
  assert.deepEqual(direct.calls, ordinary.calls);
  assert.equal(direct.calls.filter(name => name === 'scot').length, 0, 'the module capture was recomputed');
});

test('bound constructors keep their memoized element hole identity and skip cached validation', async () => {
  for (const name of ['stable-keyed-element-hole', 'validated-keyed-element-hole']) {
    const fixture = allocationCases.find(item => item.name === name);
    const direct = await instantiate(fixture.source);
    const plan = direct.plans.get(direct.value);
    assert.equal(typeof plan.holesGate, 'function');
    const mounted = mount(direct.value, fixture.initial);
    const original = runtime.slot(BigInt(plan.axes[1]), direct.value(fixture.initial));
    const node = mounted.island.node.childNodes[1];
    for (const model of fixture.models) {
      direct.reset();
      const holes = plan.holesGate(model);
      assert.strictEqual(holes[1], original, 'the opaque each wrapper was rebuilt');
      assert.equal(direct.counts().total, 0);
      assert.deepEqual(direct.calls, [], 'cached constructor validation ran again');
      mounted.island.send(model);
      assert.deepEqual(mounted.errors, []);
      assert.strictEqual(mounted.island.node.childNodes[1], node);
      assert.equal(direct.counts().total, 0);
      assert.deepEqual(direct.calls, []);
    }
    const changedItems = [[9n, rawSeal([cord('text'), cord('new')])], 0n];
    const model = [cord('last'), changedItems];
    direct.reset();
    mounted.island.send(model);
    assert.deepEqual(mounted.errors, []);
    assert.equal(mounted.island.node.textContent, 'lastnew');
    assert.notStrictEqual(plan.holesGate(model)[1], original, 'changed constructor samples kept a stale element');
    assert.equal(direct.calls.filter(native => native === 'lent').length,
      name === 'validated-keyed-element-hole' ? 1 : 0);
    assert.deepEqual(direct.counts(), { cons: 1, edit: 0, seals: 1, total: 2 });
  }
});

test('identity and projection helpers do not turn returned arguments into cyclic constructor origins', async () => {
  const first = `(app identity ${sealCore('button', '(cons "Identity" (slot 3 model))')})`;
  const second = `(app head (cons ${sealCore('button', '(cons "Projection" (slot 3 model))')} ~))`;
  const source = `(let identity (lam value value) (let head (lam pair (slot 2 pair))
    (lam model ${column(text('(slot 2 model)'), first, second)})))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  const plan = direct.plans.get(direct.value);
  assert.equal(typeof plan.holesGate, 'function');
  const a = mount(direct.value, [cord('first'), 0n]);
  const b = mount(ordinary.value, [cord('first'), 0n]);
  for (const model of [[cord('second'), 1n], [cord('third'), 2n]]) {
    direct.reset();
    a.island.send(model);
    b.island.send(model);
    assert.deepEqual(a.errors, []);
    assert.deepEqual(b.errors, []);
    assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    // The opaque projection keeps its ordinary argument cell as well as the
    // two button payloads; forcing either result must not recurse into itself.
    assert.deepEqual(direct.counts(), { cons: 5, edit: 0, seals: 2, total: 7 });
    const expected = ordinary.value(model);
    plan.holesGate(model).forEach((hole, index) => {
      assert.equal(runtime.same(hole, runtime.slot(BigInt(plan.axes[index]), expected)), 0n);
    });
  }
});

test('discarded traces and native calls inside a constructor run once when its element is forced', async () => {
  for (const effect of ['(trace "constructor" ~)', '(app (native scot) (cons %ud message))']) {
    const source = `(let item (lam message (let ignored ${effect}
      ${sealCore('button', '(cons "Press" message)')}))
      (lam model ${column(text('"fixed"'), '(app item model)')}))`;
    const direct = await instantiate(source);
    const ordinary = await instantiate(source, { optimized: false });
    assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
    const a = mount(direct.value, 0n);
    const b = mount(ordinary.value, 0n);
    for (const model of [1n, 2n, 3n]) {
      direct.reset();
      ordinary.reset();
      a.island.send(model);
      b.island.send(model);
      assert.deepEqual(a.errors, []);
      assert.deepEqual(b.errors, []);
      assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
      assert.deepEqual(direct.traces, ordinary.traces);
      assert.equal(direct.traces.length, effect.startsWith('(trace') ? 1 : 0);
      assert.equal(direct.calls.filter(name => name === 'scot').length, effect.startsWith('(app') ? 1 : 0);
      assert.equal(ordinary.calls.filter(name => name === 'scot').length, effect.startsWith('(app') ? 1 : 0);
      const nativeSample = effect.startsWith('(app') ? 1 : 0;
      assert.deepEqual(direct.counts(), { cons: 2 + nativeSample, edit: 0, seals: 1, total: 3 + nativeSample });
    }
  }
});

test('direct analysis does not bypass the Core reader ban on shadowed bindings', async () => {
  const source = `(lam words (lam words ${text('words')}))`;
  for (const optimized of [false, true]) {
    await assert.rejects(instantiate(source, { optimized }), /Binding 'words' shadows an enclosing binding/);
  }
});

test('selected branches preserve traces and escaping closures materialize their captures once', async () => {
  const reply = `(if (eq model "first")
    (let selected (trace "first branch" (cons model 1)) (lam ignored selected))
    (let alternate (trace "other branch" (cons model 2)) (lam input alternate)))`;
  const source = `(lam model (let reply ${reply}
    ${column(sealCore('field', '(cons "Captured" (cons model reply))'))}))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  for (const model of [cord('other'), cord('first')]) {
    direct.reset();
    ordinary.reset();
    a.island.send(model);
    b.island.send(model);
    assert.deepEqual(a.errors, []);
    assert.deepEqual(b.errors, []);
    assert.deepEqual(direct.traces, ordinary.traces);
    assert.equal(direct.traces.length, 1, 'the unselected branch must not trace');
    assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    const callback = a.island.vnode.children[0].control.reply;
    const original = b.island.vnode.children[0].control.reply;
    direct.reset();
    ordinary.reset();
    const captured = callback(cord('ignored'));
    assert.strictEqual(callback(cord('again')), captured, 'the capture was rebuilt on callback invocation');
    assert.equal(runtime.same(captured, original(cord('ignored'))), 0n);
    assert.deepEqual(captured, [model, model === cord('first') ? 1n : 2n]);
    assert.equal(direct.counts().total, 0, 'closure calls allocate no copies of their captured noun');
    assert.equal(ordinary.counts().total, 0);
  }
});

test('dynamic branches retain shared callback identity for local and imported captures', async () => {
  const local = `(lam model (let first (lam words (cons (cons "first" model) words))
    (let second (lam words (cons (cons "second" model) words))
      (let selected (if (eq model 0) first second)
        ${column(
          sealCore('field', '(cons "Selected" (cons model selected))'),
          sealCore('field', '(cons "First" (cons model first))'),
        )}))))`;
  const imported = `(let saved "first"
    (let first (lam words (cons saved words))
      (let second (lam words (cons "second" words))
        (lam model (let selected (if (eq model 0) first second)
        ${column(
          sealCore('field', '(cons "Selected" (cons model selected))'),
          sealCore('field', '(cons "First" (cons model first))'),
        )})))))`;
  for (const source of [local, imported]) {
    const direct = await instantiate(source);
    const ordinary = await instantiate(source, { optimized: false });
    assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
    const a = mount(direct.value, 1n);
    const b = mount(ordinary.value, 1n);
    for (const model of [0n, 1n, 0n]) {
      a.island.send(model);
      b.island.send(model);
      assert.deepEqual(a.errors, []);
      assert.deepEqual(b.errors, []);
      const replies = a.island.vnode.children.map(child => child.control.reply);
      const expected = b.island.vnode.children.map(child => child.control.reply);
      assert.strictEqual(replies[0] === replies[1], model === 0n);
      assert.strictEqual(expected[0] === expected[1], model === 0n);
      assert.deepEqual(replies[0](cord('input')), expected[0](cord('input')));
      assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
    }
  }
});

test('dynamic branches retain shared cell identity as well as noun equality', async () => {
  const source = `(lam model (let saved (cons model ~)
    (let selected (if (eq model 0) saved saved)
      ${column(
        sealCore('button', '(cons "Selected" (cons selected ~))'),
        sealCore('button', '(cons "Saved" (cons saved ~))'),
      )})))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  const plan = direct.plans.get(direct.value);
  assert.equal(typeof plan.holesGate, 'function');
  const holes = plan.holesGate(0n);
  const expected = ordinary.value(0n);
  assert.strictEqual(holes[0][1][1][1][0], holes[1][1][1][1][0]);
  assert.strictEqual(runtime.slot(BigInt(plan.axes[0]), expected)[1][1][1][0],
    runtime.slot(BigInt(plan.axes[1]), expected)[1][1][1][0]);
});

test('nested branch probes share the residual fuel bound and retain ordinary rendering', async () => {
  let child = text('"leaf"');
  for (let depth = 0; depth < 12; depth++) {
    child = `(if (eq model ${depth}) ${child} ${text('"other"')})`;
  }
  const source = `(lam model ${column(child)})`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, 0n);
  const b = mount(ordinary.value, 0n);
  a.island.send(11n);
  b.island.send(11n);
  assert.deepEqual(a.errors, []);
  assert.deepEqual(b.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.deepEqual(direct.counts(), ordinary.counts());
});

test('residual fuel exhaustion retains ordinary rendering and strict discarded work', async () => {
  // The shape analysis stops at the unknown branch; specialization must also
  // examine its bodies, whose balanced tree exceeds the residual node budget.
  let large = '0';
  for (let depth = 0; depth < 10; depth++) large = `(cons ${large} ${large})`;
  const child = `(if (eq model 0) ${text('"first"')}
    (let discarded ${large} ${text('"later"')}))`;
  const source = `(lam model ${column(child)})`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, 0n);
  const b = mount(ordinary.value, 0n);
  direct.reset();
  ordinary.reset();
  a.island.send(1n);
  b.island.send(1n);
  assert.deepEqual(a.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.equal(a.island.node.textContent, 'later');
  assert.deepEqual(direct.counts(), ordinary.counts());
  assert.ok(direct.counts().cons >= 1023, 'fallback dropped discarded tree construction');
});

test('abstracting a shared virtual DAG exhausts the shared budget and keeps ordinary evaluation', async () => {
  let body = `(let ignored (app ignore part11) ${column(text('model'))})`;
  for (let index = 11; index >= 0; index--) {
    const previous = index === 0 ? 'model' : `part${index - 1}`;
    body = `(let part${index} (cons ${previous} ${previous}) ${body})`;
  }
  const source = `(let ignore (lam input 0) (lam model ${body}))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  direct.reset();
  ordinary.reset();
  a.island.send(cord('next'));
  b.island.send(cord('next'));
  assert.deepEqual(a.errors, []);
  assert.deepEqual(b.errors, []);
  assert.equal(a.island.node.textContent, 'next');
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.deepEqual(direct.counts(), ordinary.counts());
  assert.ok(direct.counts().cons >= 12, 'fallback dropped the strict shared DAG');
});

test('a local recursive group keeps the ordinary view fallback', async () => {
  const recursion = `(rec ((walk (lam n (if (eq n 0) 42 (app walk (app (native dec) n))))))
    (app walk model))`;
  const source = `(lam model (let ignored ${recursion} ${column(text('"kept"'))}))`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.ok(direct.plans.has(direct.value));
  assert.equal(direct.plans.get(direct.value).holesGate, undefined);
  const a = mount(direct.value, 0n);
  const b = mount(ordinary.value, 0n);
  direct.reset();
  ordinary.reset();
  a.island.send(3n);
  b.island.send(3n);
  assert.deepEqual(a.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.equal(direct.calls.filter(name => name === 'dec').length, 3);
  assert.deepEqual(direct.calls, ordinary.calls);
  assert.deepEqual(direct.counts(), ordinary.counts());
});

test('a late invalid direct hole preserves every DOM hole and the previous model', async () => {
  const source = `(lam model ${column(text('(slot 2 model)'), text('(slot 3 model)'))})`;
  const direct = await instantiate(source);
  const ordinary = await instantiate(source, { optimized: false });
  assert.equal(typeof direct.plans.get(direct.value)?.holesGate, 'function');
  const initial = [cord('one'), cord('two')];
  const a = mount(direct.value, initial);
  const b = mount(ordinary.value, initial);
  const before = domSnapshot(a.island.node);
  const bad = [cord('would change'), [0n, 0n]];
  a.island.send(bad);
  b.island.send(bad);
  assert.equal(a.errors.length, 1);
  assert.equal(b.errors.length, 1);
  assert.equal(a.errors[0].message, b.errors[0].message);
  assert.strictEqual(a.island.model, initial);
  assert.deepEqual(domSnapshot(a.island.node), before);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  const next = [cord('three'), cord('four')];
  a.island.send(next);
  b.island.send(next);
  assert.equal(a.errors.length, 1);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.equal(a.island.node.textContent, 'threefour');
});

test('the public decorator cannot opt foreign JavaScript callbacks into direct evaluation', () => {
  let calls = 0;
  let directCalls = 0;
  const gate = model => { calls++; return rawSeal([cord('text'), model]); };
  const view = runtime.viewTemplate(gate, 0, [7], loweredNatives, () => {
    directCalls++;
    return [cord('forged')];
  });
  assert.strictEqual(view, gate);
  const instance = mount(view, cord('first'));
  instance.island.send(cord('second'));
  assert.equal(instance.island.template, null);
  assert.equal(calls, 2);
  assert.equal(directCalls, 0);
  assert.equal(instance.island.node.textContent, 'second');
});

test('custom native registries keep ordinary allocation and rendering behavior', async () => {
  const source = allocationCases[0].source;
  const natives = { ...loweredNatives };
  const direct = await instantiate(source, { natives });
  const ordinary = await instantiate(source, { natives, optimized: false });
  const a = mount(direct.value, cord('first'));
  const b = mount(ordinary.value, cord('first'));
  assert.equal(a.island.template, null);
  direct.reset();
  ordinary.reset();
  a.island.send(cord('changed'));
  b.island.send(cord('changed'));
  assert.deepEqual(a.errors, []);
  assert.deepEqual(domSnapshot(a.island.node), domSnapshot(b.island.node));
  assert.deepEqual(direct.counts(), ordinary.counts());
  assert.ok(direct.counts().total > 0);
});
