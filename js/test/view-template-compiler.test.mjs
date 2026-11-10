import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { compileCore } from '../core/compiler.mjs';
import { evaluateCore } from '../core/node.mjs';
import * as runtime from '../core/runtime.mjs';
import { cord } from '../natives/helpers.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { toVnode } from '../browser/vdom.mjs';
import { startIsland } from '../browser/island.mjs';
import { compiledViewTemplate } from '../browser/template.mjs';
import { createFakeDocument } from './fake-dom.mjs';

async function compiled(source, natives = loweredNatives, logger = () => {}) {
  const plans = new WeakMap();
  const js = compileCore(source, { nativeNames: Object.keys(natives) });
  const module = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
  const value = module.evaluate({
    ...runtime,
    traceLazy: (message, body) => runtime.traceLazy(message, body, logger),
    viewTemplate: (gate, tree, axes, selectedNatives) => {
      plans.set(gate, { tree, axes, natives: selectedNatives });
      return gate;
    },
  }, natives);
  return { value, plans, js };
}

async function compiledForBrowser(source, natives = loweredNatives) {
  const js = compileCore(source, { nativeNames: Object.keys(natives) });
  const module = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
  return module.evaluate({ ...runtime, viewTemplate: compiledViewTemplate }, natives);
}

test('a checked view compiles to a static layout and model-dependent text hole', async () => {
  // The Hoon suite checks source.jibb and pins this actual linked Core.
  const source = readFileSync(new URL('../../tests/view-template/core.txt', import.meta.url), 'utf8');
  const { value: view, plans } = await compiled(source);
  const plan = plans.get(view);
  assert.deepEqual(plan, {
    tree: ['div', { class: 'j-column' }, [['h1', { tabIndex: '-1' }, ['Title']], 0]],
    axes: [251],
    natives: loweredNatives,
  });
  for (const words of ['first', 'second', 'λ', '<script>no markup</script>']) {
    const noun = view(cord(words));
    assert.equal(runtime.slot(plan.axes[0], noun), cord(words));
    const vnode = toVnode(noun);
    assert.equal(vnode.children[0].children[0].text, 'Title');
    assert.equal(vnode.children[1].text, words);
  }
});

test('the checked compiled fixture mounts a template and updates without visiting static attributes', async () => {
  const source = readFileSync(new URL('../../tests/view-template/core.txt', import.meta.url), 'utf8');
  const view = await compiledForBrowser(source);
  const document = createFakeDocument();
  const island = startIsland({
    document, container: document.body, model: cord('first'),
    program: { init: () => 0n, update: ([message]) => [message, 0n], view },
    onCrash: error => { throw error; },
  });
  assert.ok(island.template);
  const root = island.node;
  const [heading, words] = root.childNodes;
  const unreachable = attrs => new Proxy(attrs, {
    ownKeys() { throw new Error('static attributes were visited on update'); },
  });
  island.vnode.attrs = unreachable(island.vnode.attrs);
  island.vnode.children[0].attrs = unreachable(island.vnode.children[0].attrs);
  island.send(cord('second'));
  assert.strictEqual(island.node, root);
  assert.strictEqual(root.firstChild, heading);
  assert.strictEqual(root.lastChild, words);
  assert.equal(heading.textContent, 'Title');
  assert.equal(words.nodeValue, 'second');
});

test('lexical aliases preserve the authenticated constructor through ordinary bindings', async () => {
  const { value: view, plans } = await compiled(`
    (let seal (native raw-seal)
      (let constructor (lam value (app seal (cons %text value)))
        (let alias constructor
          (lam words (app alias words)))))`);
  assert.deepEqual(plans.get(view).tree, 0);
  assert.deepEqual(plans.get(view).axes, [7]);
  assert.equal(toVnode(view(cord('captured'))).text, 'captured');
});

test('local captured gates get their own templates and preserve closure values', async () => {
  const { value: outer, plans } = await compiled(`
    (lam captured (lam ignored (app (native raw-seal) (cons %text captured))))`);
  assert.equal(plans.has(outer), false);
  const first = outer(cord('one'));
  const second = outer(cord('two'));
  assert.notStrictEqual(first, second);
  assert.deepEqual(plans.get(first).axes, [7]);
  assert.equal(toVnode(first(0n)).text, 'one');
  assert.equal(toVnode(second(0n)).text, 'two');
});

test('static ASCII text is compiled, while Unicode and invalid UTF-8 retain the decoder', async () => {
  const staticView = await compiled('(lam x (app (native raw-seal) (cons %text "static")))');
  assert.deepEqual(staticView.plans.get(staticView.value).tree, 'static');
  assert.deepEqual(staticView.plans.get(staticView.value).axes, []);
  for (const source of ['"λ"', '255', '10']) {
    const { value: view, plans } = await compiled(`(lam x (app (native raw-seal) (cons %text ${source})))`);
    assert.deepEqual(plans.get(view).tree, 0);
    assert.deepEqual(plans.get(view).axes, [7]);
    if (source === '255') assert.equal(toVnode(view(0n)).text, '\uFFFD');
  }
});

test('shape uncertainty, dynamic attributes and same-spelled ordinary gates stay generic', async () => {
  const cases = [
    '(let raw-seal (lam x (cons %fake x)) (lam x (app raw-seal (cons %text x))))',
    '(lam x (app (native raw-seal) x))',
    '(lam x (app (native raw-seal) (cons %heading (cons x "Title"))))',
    '(lam x (app (native raw-seal) (cons %column (cons x ~))))',
    '(lam x (if (eq x 0) (app (native raw-seal) (cons %text "one")) (app (native raw-seal) (cons %para ~))))',
    '(rec ((again (lam x (app again x)))) (lam x (app again x)))',
  ];
  for (const source of cases) {
    const { value, plans } = await compiled(source);
    assert.equal(plans.has(value), false, source);
  }
  const noNative = await compiled('(lam x (cons %text x))', {});
  assert.equal(noNative.js.includes('requireNative(natives, "raw-seal")'), false);
  assert.equal(noNative.plans.has(noNative.value), false);
});

test('decoration preserves strict discarded work and every trace at equal samples', async () => {
  const seen = [];
  const { value: view, plans } = await compiled(`
    (lam words (let ignored (trace "render" ~)
      (app (native raw-seal) (cons %text words))))`, loweredNatives, text => seen.push(text));
  assert.deepEqual(plans.get(view).axes, [7]);
  view(cord('same'));
  view(cord('same'));
  assert.equal(seen.length, 2);

  const crashed = await compiled(`
    (lam words (let ignored (crash) (app (native raw-seal) (cons %text words))))`);
  assert.equal(crashed.plans.has(crashed.value), true);
  assert.throws(() => crashed.value(cord('unused')), /explicit Core crash/);
});

test('the descriptor retains the exact native capability for the browser to authenticate', async () => {
  const customSeal = value => rawSeal([cord('text'), cord('different')]);
  const custom = { 'raw-seal': customSeal };
  const { value: view, plans } = await compiled('(lam words (app (native raw-seal) (cons %text words)))', custom);
  assert.strictEqual(plans.get(view).natives, custom);
  assert.notStrictEqual(plans.get(view).natives, loweredNatives);
  assert.equal(toVnode(view(cord('original'))).text, 'different');
});

test('an arbitrary native that mutates known cells forces ordinary island rendering', async () => {
  const source = `(lam words (let raw (cons %text "before")
    (let ignored (app (native mutate) (cons raw words))
      (app (native raw-seal) raw))))`;
  let calls = 0;
  const natives = {
    ...loweredNatives,
    mutate: ([raw, words]) => { calls++; raw[1] = words; return 0n; },
  };
  const view = await compiledForBrowser(source, natives);
  const document = createFakeDocument();
  const island = startIsland({
    document, container: document.body, model: cord('first'),
    program: { init: () => 0n, update: ([message]) => [message, 0n], view },
    onCrash: error => { throw error; },
  });
  assert.equal(island.template, null);
  assert.equal(document.body.textContent, 'first');
  island.send(cord('second'));
  assert.equal(document.body.textContent, 'second');
  assert.equal(calls, 2);
});

test('the public runtime preserves foreign callback mutations through ordinary rendering', async () => {
  const factory = await evaluateCore(`
    (lam callback (lam words (let raw (cons %text "before")
      (let ignored (app callback raw) (app (native raw-seal) raw)))))`,
  { natives: loweredNatives });
  let calls = 0;
  const view = factory(raw => { raw[1] = cord(`after ${++calls}`); return 0n; });
  const document = createFakeDocument();
  const island = startIsland({
    document, container: document.body, model: 0n,
    program: { init: () => 0n, update: ([message]) => [message, 0n], view },
    onCrash: error => { throw error; },
  });
  assert.equal(island.template, null);
  assert.equal(document.body.textContent, 'after 1');
  island.send(1n);
  assert.equal(document.body.textContent, 'after 2');
  assert.equal(calls, 2);
});

test('fixed nested elements give exact axes and oversized templates fall back', async () => {
  const { value: view, plans } = await compiled(`
    (lam words (app (native raw-seal) (cons %el (cons ~
      (app (native raw-seal) (cons %para (cons
        (app (native raw-seal) (cons %text words)) ~)))))))`);
  const noun = view(cord('nested'));
  assert.deepEqual(plans.get(view).tree, ['div', { class: 'j-el' }, [['p', {}, [0]]]]);
  assert.equal(runtime.slot(plans.get(view).axes[0], noun), cord('nested'));
  let nested = '(app (native raw-seal) (cons %text words))';
  for (let i = 0; i < 20; i++) nested = `(app (native raw-seal) (cons %el (cons ~ ${nested})))`;
  const large = await compiled(`(lam words ${nested})`);
  assert.equal(large.plans.has(large.value), false, 'an unsafe numeric axis declines optimization');
  assert.doesNotThrow(() => large.value(cord('ordinary Core still runs')));
});

test('analysis limits preserve ordinary execution and projection diagnostics', async () => {
  const source = readFileSync(new URL('../../tests/js-emit/extra-view-template-limits/core.txt', import.meta.url), 'utf8');
  const { value: [deep, [wide, projected]], plans } = await compiled(source);
  for (const gate of [deep, wide, projected]) assert.equal(plans.has(gate), false);
  for (const gate of [deep, wide]) {
    assert.doesNotThrow(() => gate(cord('ordinary Core still runs')));
  }
  const words = cord('projected text');
  let ordinary = rawSeal([cord('text'), words]);
  for (let i = 0; i < 53; i++) ordinary = [ordinary, 0n];
  const outcome = run => {
    try { return { value: run() }; }
    catch (error) { return { error: error.constructor.name, message: error.message }; }
  };
  // The existing runtime rejects axes above MAX_SAFE. Analysis must neither
  // execute that projection early nor hide its ordinary runtime diagnostic.
  assert.deepEqual(outcome(() => projected(words)), outcome(() => runtime.slot(2n ** 53n, ordinary)));
});
