import test from 'node:test';
import assert from 'node:assert/strict';
import { compiledViewTemplate as viewTemplate } from '../browser/template.mjs';
import { viewTemplate as publicViewTemplate } from '../core/runtime.mjs';
import { startIsland } from '../browser/island.mjs';
import { toVnode } from '../browser/vdom.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { arrayToList, cord, listToArray } from '../natives/helpers.mjs';
import { createFakeDocument, FakeEvent } from './fake-dom.mjs';

const seal = (tag, payload) => rawSeal([cord(tag), payload]);
const text = value => seal('text', value);
const column = children => seal('column', [0n, arrayToList(children)]);
const attrs = { style: {}, class: 'j-column' };
const plan = ['div', attrs, [['h1', { tabIndex: '-1' }, ['Title']], 0]];
const draw = model => column([seal('heading', [1n, cord('Title')]), text(model)]);

function mount(view, initial = cord('first'), onCrash = error => { throw error; }, options = {}) {
  const document = createFakeDocument();
  const island = startIsland({
    ...options, document, container: document.body, model: initial, onCrash,
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

test('fixed layout attributes decode at mount and are not revisited by hole updates', () => {
  const fixed = arrayToList([
    [cord('pad'), cord('s1')], [cord('width'), [cord('chars'), 12n]],
    [cord('pad'), cord('s3')], [cord('width'), cord('shrink')],
    [cord('tone'), cord('danger')],
  ]);
  const draw = model => seal('column', [fixed, arrayToList([text(model)])]);
  const view = viewTemplate(draw, ['column', 14, [0]], [123], loweredNatives);
  const { document, island } = mount(view);
  assert.deepEqual(island.vnode, toVnode(draw(island.model)));
  const root = island.node;
  assert.equal(root.localName, 'div');
  assert.equal(root.getAttribute('class'), 'j-column j-pad-s3 j-shrink j-tone-danger');
  assert.equal(root.style.flex, '0 0 12ch');
  assert.equal(root.getAttribute('aria-live'), 'polite');
  const keptAttrs = island.vnode.attrs;
  island.vnode.attrs = new Proxy(keptAttrs, {
    ownKeys() { throw new Error('fixed attributes were revisited'); },
  });
  island.send(cord('next'));
  assert.equal(document.body.firstChild, root);
  assert.equal(root.textContent, 'next');
  island.vnode.attrs = keptAttrs;
  assert.deepEqual(island.vnode, toVnode(draw(island.model)));
});

test('invalid fixed attributes fail before mounting any DOM', () => {
  const errors = [];
  const view = viewTemplate(model => seal('column', [
    arrayToList([[cord('pad'), cord('invalid')]]), arrayToList([text(model)]),
  ]), ['column', 14, [0]], [123], loweredNatives);
  const { document, island } = mount(view, cord('first'), error => errors.push(error));
  assert.equal(island.active, false);
  assert.equal(document.body.childNodes.length, 0);
  assert.match(errors[0].message, /unknown pad %invalid/);
});

test('template mounting preserves ordinary attribute and child error precedence, including nested layouts', () => {
  const invalid = kind => arrayToList([[cord(kind), cord('invalid')]]);
  const layout = (tag, attrs, child) => seal(tag, [
    attrs, tag === 'el' ? child : arrayToList([child]),
  ]);
  const cases = ['row', 'column', 'wrap', 'stack', 'el'].map(tag => ({
    draw: model => layout(tag, invalid('pad'), model),
    tree: [tag, 14, [-1]], axes: [tag === 'el' ? 15 : 30],
    error: tag === 'el' ? 'toVnode: unknown pad %invalid'
      : 'validateRawSeal: expected a value produced by rawSeal',
  }));
  cases.push({
    draw: model => layout('column', invalid('pad'), layout('el', invalid('role'), model)),
    tree: ['column', 14, [['el', 246, [-1]]]], axes: [247],
    error: 'toVnode: unknown role %invalid',
  }, {
    draw: model => layout('el', invalid('pad'), layout('column', invalid('role'), model)),
    tree: ['el', 14, [['column', 126, [-1]]]], axes: [254],
    error: 'toVnode: unknown pad %invalid',
  });
  for (const { draw, tree, axes, error } of cases) {
    const view = viewTemplate(draw, tree, axes, loweredNatives);
    assert.throws(() => toVnode(view(0n)), { message: error });
    const errors = [];
    const { document, island } = mount(view, 0n, failure => errors.push(failure));
    assert.equal(island.active, false);
    assert.equal(document.body.childNodes.length, 0);
    assert.deepEqual(errors.map(failure => failure.message), [error]);
  }
});

test('subtree controls retain focus and caret and reset rejected input from the current vnode', () => {
  const reply = value => value;
  const field = model => seal('field', [cord('Label'), [model, reply]]);
  const view = viewTemplate(model => column([field(model)]),
    ['div', attrs, [-1]], [30], loweredNatives);
  const { document, island } = mount(view, cord('a'));
  island.program.update = ([message, model]) => [message === cord('reject') ? model : message, 0n];
  const input = island.node.firstChild;
  input.focus();
  input.value = 'ab';
  input.setSelectionRange(2, 2);
  input.dispatchEvent(new FakeEvent('input'));
  assert.equal(island.model, cord('ab'));
  assert.equal(island.node.firstChild, input);
  assert.equal(document.activeElement, input);
  assert.equal(input.selectionStart, 2);
  assert.equal(input.selectionEnd, 2);
  assert.equal(island.vnode.children[0], input.__jibb.vnode);
  input.value = 'reject';
  input.dispatchEvent(new FakeEvent('input'));
  assert.equal(island.model, cord('ab'));
  assert.equal(input.value, 'ab');
  assert.equal(document.activeElement, input);
});

test('subtree replacements keep their parent vnode current for later ordinary rendering', () => {
  const child = model => model[0] === 0n ? text(model[1])
    : seal('heading', [2n, model[1]]);
  const draw = model => column([child(model)]);
  const view = viewTemplate(draw, ['div', attrs, [-1]], [30], loweredNatives);
  const { island } = mount(view, [0n, cord('text')]);
  const root = island.node;
  const old = root.firstChild;
  island.send([1n, cord('heading')]);
  const heading = root.firstChild;
  assert.notEqual(heading, old);
  assert.equal(heading.localName, 'h2');
  assert.equal(island.vnode.children[0], heading.__jibb.vnode);
  island.send([1n, cord('updated')]);
  assert.equal(root.firstChild, heading);
  assert.deepEqual(island.vnode, toVnode(draw(island.model)));
  island.program.view = model => draw(model);
  island.send([1n, cord('ordinary')]);
  assert.equal(island.template, null);
  assert.equal(island.node, root);
  assert.equal(root.firstChild, heading);
  assert.equal(heading.textContent, 'ordinary');
  assert.deepEqual(island.vnode, toVnode(draw(island.model)));
});

test('keyed subtree reorders retain controls before and after falling back to ordinary rendering', () => {
  const reply = value => value;
  const draw = order => column([seal('each', arrayToList(listToArray(order).map(key => [
    key, seal('field', [cord(String(key)), [cord(`value ${key}`), reply]]),
  ])))]);
  const view = viewTemplate(draw, ['div', attrs, [-1]], [30], loweredNatives);
  const { document, island } = mount(view, arrayToList([1n, 2n, 3n]));
  const each = island.node.firstChild;
  const [one, two, three] = each.childNodes;
  two.focus();
  two.setSelectionRange(2, 2);
  island.send(arrayToList([3n, 1n, 2n]));
  assert.deepEqual(each.childNodes, [three, one, two]);
  assert.equal(document.activeElement, two);
  assert.equal(two.selectionStart, 2);
  assert.equal(island.vnode.children[0], each.__jibb.vnode);
  assert.deepEqual(island.vnode.children[0].children.map(child => child.key), [3n, 1n, 2n]);
  island.send(arrayToList([2n, 4n, 3n]));
  assert.equal(each.firstChild, two);
  assert.equal(each.lastChild, three);
  assert.equal(one.parentNode, null);
  island.program.view = model => draw(model);
  island.send(arrayToList([3n, 2n]));
  assert.equal(island.template, null);
  assert.equal(island.node.firstChild, each);
  assert.deepEqual(each.childNodes, [three, two]);
  assert.equal(document.activeElement, two);
});

test('subtree links and shared images use each island’s page paths on mount and update', () => {
  const asset = seal('image', [arrayToList([cord('static'), cord('dot.png')]), cord('Dot')]);
  const draw = model => column([seal('link', [arrayToList([model]), model]), asset]);
  const view = viewTemplate(draw, ['div', attrs, [-1, -2]], [30, 62], loweredNatives);
  const paths = base => ({
    base, assets: new Map([['/static/dot.png', { url: `${base}/static/hash/dot.png`, width: 3, height: 4 }]]),
  });
  const a = mount(view, cord('start'), undefined, { paths: paths('/apps/a') });
  const b = mount(view, cord('start'), undefined, { paths: paths('/apps/b') });
  for (const [base, { island }] of [['/apps/a', a], ['/apps/b', b]]) {
    assert.equal(island.node.firstChild.getAttribute('href'), `${base}/start`);
    assert.equal(island.node.lastChild.getAttribute('src'), `${base}/static/hash/dot.png`);
    assert.equal(island.node.lastChild.getAttribute('width'), '3');
    island.send(cord('next page'));
    assert.equal(island.node.firstChild.getAttribute('href'), `${base}/next%20page`);
    assert.equal(island.node.lastChild.getAttribute('src'), `${base}/static/hash/dot.png`);
  }
});

test('a failing later subtree leaves earlier text and element holes and the model intact', () => {
  const draw = model => column([
    text(model[0]), seal('button', [model[1][0], 7n]), model[1][1],
  ]);
  const view = viewTemplate(draw, ['div', attrs, [0, -2, -3]], [123, 62, 126], loweredNatives);
  const old = [cord('one'), [cord('button'), text(cord('last'))]];
  const errors = [];
  const { document, island } = mount(view, old, error => errors.push(error));
  const children = [...island.node.childNodes];
  const vnodes = [...island.vnode.children];
  const bad = [cord('changed'), [cord('changed button'), [cord('forged'), 0n]]];
  island.send(bad);
  assert.equal(errors.length, 1);
  assert.match(errors[0].message, /expected a value produced by rawSeal/);
  assert.equal(island.model, old);
  assert.equal(document.body.textContent, 'onebuttonlast');
  assert.deepEqual(island.node.childNodes, children);
  assert.deepEqual(island.vnode.children, vnodes);
  island.send([cord('two'), [cord('new button'), seal('heading', [2n, cord('end')])]]);
  assert.equal(document.body.textContent, 'twonew buttonend');
  assert.equal(island.node.childNodes[1], children[1]);
  assert.equal(island.node.lastChild.localName, 'h2');
});

test('negative-looking static text stays a template and an element-only hole falls back', () => {
  const literal = viewTemplate(() => text(cord('-1')), '-1', [], loweredNatives);
  const a = mount(literal);
  assert.ok(a.island.template);
  assert.equal(a.document.body.textContent, '-1');
  const subtree = viewTemplate(model => text(model), -1, [1], loweredNatives);
  const b = mount(subtree);
  assert.equal(b.island.template, null);
  assert.equal(b.document.body.textContent, 'first');
});

test('direct holes run only after ordinary mount and retain generic calls and changed-view fallback', () => {
  let ordinary = 0;
  const samples = [];
  const view = viewTemplate(model => { ordinary++; return draw(model); }, plan, [251], loweredNatives,
    model => { samples.push(model); return [model]; });
  const errors = [];
  const { document, island } = mount(view, cord('first'), error => errors.push(error));
  const root = island.node;
  assert.equal(ordinary, 1);
  assert.deepEqual(samples, []);
  island.send(cord('second'));
  island.send(cord('second'));
  assert.equal(ordinary, 1);
  assert.deepEqual(samples, [cord('second')]);
  assert.equal(document.body.textContent, 'Titlesecond');
  assert.equal(toVnode(view(cord('generic'))).children[1].text, 'generic');
  assert.equal(ordinary, 2);
  const template = island.template;
  island.program.view = () => { throw new Error('replacement failed'); };
  island.send(cord('discarded'));
  assert.equal(errors[0].message, 'replacement failed');
  assert.equal(island.model, cord('second'));
  assert.equal(island.template, template);
  island.program.view = model => draw(model);
  island.send(cord('ordinary'));
  assert.equal(island.template, null);
  assert.equal(island.node, root);
  assert.equal(document.body.textContent, 'Titleordinary');
  assert.deepEqual(samples, [cord('second')]);
});

test('direct evaluation cannot bypass ordinary first-mount errors', () => {
  let direct = 0;
  const holeGate = () => { direct++; return [cord('incorrect success')]; };
  for (const normal of [
    () => { throw new Error('ordinary view failed'); },
    () => [cord('forged'), 0n],
  ]) {
    const errors = [];
    const view = viewTemplate(normal, 0, [7], loweredNatives, holeGate);
    const { document, island } = mount(view, 0n, error => errors.push(error));
    assert.equal(island.active, false);
    assert.equal(document.body.childNodes.length, 0);
    assert.equal(errors.length, 1);
    assert.match(errors[0].message, /ordinary view failed|expected a value produced by rawSeal/);
  }
  assert.equal(direct, 0);
});

test('direct holes require both the private decorator and the canonical native registry', () => {
  let direct = 0;
  const holeGate = () => { direct++; return [cord('untrusted')]; };
  for (const [decorate, natives] of [
    [publicViewTemplate, loweredNatives],
    [viewTemplate, { ...loweredNatives }],
    [viewTemplate, Object.freeze({ ...loweredNatives })],
  ]) {
    const view = decorate(model => text(model), 0, [7], natives, holeGate);
    const { document, island } = mount(view);
    assert.equal(island.template, null);
    island.send(cord('ordinary'));
    assert.equal(document.body.textContent, 'ordinary');
  }
  assert.equal(direct, 0);
});

test('direct vectors and every hole are validated before any patch, and later evaluation errors win', () => {
  let ordinary = 0;
  const button = label => seal('button', [label, 7n]);
  const view = viewTemplate(model => {
    ordinary++;
    return column([text(model), button(model)]);
  }, ['div', attrs, [0, -2]], [123, 62], loweredNatives, model => {
    if (model === cord('short')) return [cord('changed')];
    if (model === cord('long')) return [cord('changed'), button(model), 0n];
    if (model === cord('atom')) return 0n;
    if (model === cord('sparse')) return new Array(2);
    if (model === cord('bad child')) return [cord('changed'), [cord('forged'), 0n]];
    if (model === cord('later failure')) return [[1n, 2n], (() => { throw new Error('later evaluation failed'); })()];
    return [model, button(model)];
  });
  const errors = [];
  const { document, island } = mount(view, cord('kept'), error => errors.push(error));
  const children = [...island.node.childNodes];
  for (const model of ['short', 'long', 'atom', 'sparse', 'bad child', 'later failure']) {
    island.send(cord(model));
    assert.equal(island.model, cord('kept'));
    assert.equal(document.body.textContent, 'keptkept');
    assert.deepEqual(island.node.childNodes, children);
    assert.equal(island.vnode.children[0].text, 'kept');
    assert.equal(island.vnode.children[1].children[0].text, 'kept');
  }
  assert.deepEqual(errors.slice(0, 3).map(error => error.message),
    Array(3).fill('view template: invalid hole vector'));
  assert.match(errors[3].message, /text: expected an unsigned atom/);
  assert.match(errors[4].message, /expected a value produced by rawSeal/);
  assert.equal(errors[5].message, 'later evaluation failed');
  island.send(cord('recovered'));
  assert.equal(document.body.textContent, 'recoveredrecovered');
  assert.deepEqual(island.node.childNodes, children);
  assert.equal(ordinary, 1);
});

test('a direct gate with no holes still runs strict work on changed models', () => {
  const calls = [];
  const view = viewTemplate(() => text(cord('fixed')), 'fixed', [], loweredNatives, model => {
    calls.push(model);
    if (model === 1n) throw new Error('discarded work failed');
    return [];
  });
  const errors = [];
  const { document, island } = mount(view, 0n, error => errors.push(error));
  island.send(1n);
  assert.equal(island.model, 0n);
  assert.equal(errors[0].message, 'discarded work failed');
  island.send(2n);
  island.send(2n);
  assert.deepEqual(calls, [1n, 2n]);
  assert.equal(island.model, 2n);
  assert.equal(document.body.textContent, 'fixed');
});

test('direct subtree holes preserve control state, keyed identity, and page paths', () => {
  let ordinary = 0;
  let direct = 0;
  const pieces = model => [
    seal('field', [cord('Draft'), [model[0], value => [value, model[1]]]]),
    seal('each', arrayToList(listToArray(model[1]).map(key => [key, text(cord(String(key)))]))),
    seal('link', [arrayToList([model[0]]), model[0]]),
  ];
  const view = viewTemplate(model => { ordinary++; return column(pieces(model)); },
    ['div', attrs, [-1, -2, -3]], [30, 62, 126], loweredNatives,
    model => { direct++; return pieces(model); });
  const { document, island } = mount(view, [cord('a'), arrayToList([1n, 2n])], undefined,
    { paths: { base: '/apps/example' } });
  island.program.update = ([message, model]) => [message[0] === cord('reject') ? model : message, 0n];
  const [input, each, link] = island.node.childNodes;
  const [one, two] = each.childNodes;
  input.focus();
  input.value = 'ab';
  input.setSelectionRange(2, 2);
  input.dispatchEvent(new FakeEvent('input'));
  assert.equal(input.value, 'ab');
  assert.equal(input.selectionStart, 2);
  assert.equal(document.activeElement, input);
  assert.equal(link.getAttribute('href'), '/apps/example/ab');
  input.value = 'reject';
  input.dispatchEvent(new FakeEvent('input'));
  assert.equal(input.value, 'ab');
  assert.equal(direct, 1);
  island.send([cord('next page'), arrayToList([2n, 1n])]);
  assert.deepEqual(each.childNodes, [two, one]);
  assert.equal(island.node.firstChild, input);
  assert.equal(document.activeElement, input);
  assert.equal(link.getAttribute('href'), '/apps/example/next%20page');
  assert.equal(island.vnode.children[1], each.__jibb.vnode);
  assert.equal(ordinary, 1);
  assert.equal(direct, 2);
});
