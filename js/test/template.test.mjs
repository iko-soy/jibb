import test from 'node:test';
import assert from 'node:assert/strict';
import { compiledViewTemplate as viewTemplate } from '../browser/template.mjs';
import { startIsland } from '../browser/island.mjs';
import { toVnode } from '../browser/vdom.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';
import { createFakeDocument } from './fake-dom.mjs';

const seal = (tag, payload) => rawSeal([cord(tag), payload]);
const text = value => seal('text', value);
const column = children => seal('column', [0n, arrayToList(children)]);
const attrs = { style: {}, class: 'j-column' };
const plan = ['div', attrs, [['h1', { tabIndex: '-1' }, ['Title']], 0]];
const draw = model => column([seal('heading', [1n, cord('Title')]), text(model)]);

function mount(view, initial = cord('first'), onCrash = error => { throw error; }) {
  const document = createFakeDocument();
  const island = startIsland({
    document, container: document.body, model: initial, onCrash,
    program: { init: () => initial, update: ([message]) => [message, 0n], view },
  });
  return { document, island };
}

test('compiled template keeps static DOM and patches text without interpreting markup', () => {
  let calls = 0;
  const view = viewTemplate(model => { calls += 1; return draw(model); }, plan, [251], loweredNatives);
  const { document, island } = mount(view);
  assert.ok(island.template);
  assert.deepEqual(island.vnode, toVnode(draw(cord('first'))));
  const root = document.body.firstChild;
  const [heading, dynamic] = root.childNodes;
  island.send(cord('<img src=x onerror=bad()>'));
  assert.equal(calls, 2);
  assert.equal(document.body.firstChild, root);
  assert.equal(root.firstChild, heading);
  assert.equal(root.lastChild, dynamic);
  assert.equal(dynamic.nodeType, 3);
  assert.equal(dynamic.nodeValue, '<img src=x onerror=bad()>');
  assert.equal(root.children.length, 1);
  assert.deepEqual(island.vnode, toVnode(draw(island.model)));
});

test('template instances share a descriptor but no DOM or model state', () => {
  const view = viewTemplate(draw, plan, [251], loweredNatives);
  const a = mount(view);
  const b = mount(view, cord('other'));
  a.island.send(cord('changed'));
  assert.equal(a.document.body.textContent, 'Titlechanged');
  assert.equal(b.document.body.textContent, 'Titleother');
  assert.notEqual(a.island.node, b.island.node);
  assert.notEqual(a.island.vnode.children[1], b.island.vnode.children[1]);
});

test('a failing text hole leaves every DOM hole and the previous model intact', () => {
  const view = viewTemplate(model => column([text(model[0]), text(model[1])]),
    ['div', attrs, [0, 1]], [123, 251], loweredNatives);
  const errors = [];
  const old = [cord('one'), cord('two')];
  const { document, island } = mount(view, old, error => errors.push(error));
  const bad = [cord('changed'), [1n, 2n]];
  island.send(bad);
  assert.equal(errors.length, 1);
  assert.equal(errors[0].message, 'toVnode: text: text: expected an unsigned atom');
  assert.throws(() => toVnode(view(bad)), { message: errors[0].message });
  assert.equal(document.body.textContent, 'onetwo');
  assert.equal(island.model, old);
  island.send([cord('three'), cord('four')]);
  assert.equal(document.body.textContent, 'threefour');
});

test('a custom same-named seal uses ordinary rendering instead of a trusted template', () => {
  const replacementSeal = payload => rawSeal(payload);
  const view = viewTemplate(model => replacementSeal([cord('text'), model]),
    'incorrect static text', [], { ...loweredNatives, 'raw-seal': replacementSeal });
  const { document, island } = mount(view);
  assert.equal(island.template, null);
  assert.equal(document.body.textContent, 'first');
  island.send(cord('second'));
  assert.equal(document.body.textContent, 'second');
});

test('a mutable copy of the native registry cannot authorize a template', () => {
  const natives = { ...loweredNatives };
  const view = viewTemplate(model => natives['raw-seal']([cord('text'), model]),
    'incorrect static text', [], natives);
  const { document, island } = mount(view);
  assert.equal(island.template, null);
  natives['raw-seal'] = () => text(cord('replacement'));
  island.send(cord('next'));
  assert.equal(document.body.textContent, 'replacement');
});

test('templates retain view crashes and validate the returned seal', () => {
  const errors = [];
  const view = viewTemplate(model => {
    if (model === 1n) throw new Error('view failed');
    if (model === 2n) return [cord('forged'), cord('text')];
    return text(model);
  }, 0, [7], loweredNatives);
  const { document, island } = mount(view, cord('kept'), error => errors.push(error));
  island.send(1n);
  island.send(2n);
  assert.equal(island.model, cord('kept'));
  assert.equal(document.body.textContent, 'kept');
  assert.equal(errors[0].message, 'view failed');
  assert.match(errors[1].message, /expected a value produced by rawSeal/);
});

test('replacing a view preserves the old template on failure and falls back on success', () => {
  const errors = [];
  const view = viewTemplate(draw, plan, [251], loweredNatives);
  const { document, island } = mount(view, cord('kept'), error => errors.push(error));
  const original = island.template;
  island.program.view = () => { throw new Error('replacement failed'); };
  island.send(cord('discarded'));
  assert.equal(island.model, cord('kept'));
  assert.equal(document.body.textContent, 'Titlekept');
  assert.equal(island.template, original);
  assert.equal(errors[0].message, 'replacement failed');
  island.program.view = model => text(model);
  island.send(cord('replacement'));
  assert.equal(island.template, null);
  assert.equal(document.body.textContent, 'replacement');
});
