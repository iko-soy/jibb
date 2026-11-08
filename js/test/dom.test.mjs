import assert from 'node:assert/strict';
import test from 'node:test';

import { createDom, patchDom, syncControls } from '../browser/dom.mjs';
import { toVnode } from '../browser/vdom.mjs';
import { CoreCrash } from '../core/runtime.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { createFakeDocument, FakeEvent } from './fake-dom.mjs';

const list = (...values) => arrayToList(values);
const textNode = text => ({ kind: 'text', text });
const seal = (tag, payload) => rawSeal([cord(tag), payload]);
const textElement = value => seal('text', cord(value));

function element(tag, attrs = {}, children = [], extra = {}) {
  return { kind: 'element', tag, attrs, children, ...extra };
}

function button(key, message, label = String(message)) {
  return element('button', { type: 'button', 'data-name': label }, [textNode(label)], {
    key,
    control: { type: 'button', message },
  });
}

function field(key, value, label = String(key)) {
  return element('input', {
    type: 'text', value, 'aria-label': label,
  }, [], { key, control: { type: 'field', reply: valueAtom => [cord('reply'), valueAtom] } });
}

function render(vnode) {
  const document = createFakeDocument();
  const node = createDom(vnode, { document, dispatch() {} });
  document.body.appendChild(node);
  return { document, node };
}

function childElements(node) {
  return node.childNodes.filter(child => child.nodeType === 1);
}

test('toVnode decodes layouts, text, attributes, headings, and authenticates seals', () => {
  const attrs = list(
    [cord('pad'), cord('s2')],
    [cord('gap'), cord('s3')],
    [cord('width'), [cord('fill'), 0n]],
    [cord('align'), cord('center')],
    [cord('role'), cord('body')],
    [cord('tone'), cord('danger')],
  );
  const row = toVnode(seal('row', [attrs, list(textElement('hello'))]));
  assert.equal(row.kind, 'element');
  assert.equal(row.tag, 'div');
  assert.deepEqual(row.children, [{ kind: 'text', text: 'hello' }]);
  assert.equal(row.attrs.style.display, 'flex');
  assert.equal(row.attrs.style.flexDirection, 'row');
  assert.equal(row.attrs.style.padding, '8px');
  assert.equal(row.attrs.style.gap, '16px');
  assert.equal(row.attrs.style.flex, '1 1 0%');
  assert.equal(row.attrs.style.justifyContent, 'center');
  assert.equal(row.attrs['data-role'], 'body');
  assert.equal(row.attrs['data-tone'], 'danger');

  assert.equal(toVnode(seal('column', [0n, 0n])).attrs.style.flexDirection, 'column');
  assert.equal(toVnode(seal('wrap', [0n, 0n])).attrs.style.flexWrap, 'wrap');
  assert.equal(toVnode(seal('stack', [0n, 0n])).attrs['data-layout'], 'stack');
  assert.equal(toVnode(seal('el', [0n, textElement('x')])).children[0].text, 'x');
  assert.equal(toVnode(seal('para', list(textElement('p')))).tag, 'p');
  assert.equal(toVnode(seal('heading', [1n, cord('title')])).tag, 'h1');
  assert.equal(toVnode(seal('heading', [99n, cord('title')])).tag, 'h6');
  assert.throws(() => toVnode([cord('not-a-seal'), textElement('x')]), CoreCrash);
  assert.throws(() => toVnode(seal('unknown', 0n)), /unsupported element/);
});

test('toVnode decodes keyed collections and table rows without dropping duplicates', () => {
  const compoundKey = [cord('key'), [1n, 2n]];
  const each = toVnode(seal('each', list(
    [7n, textElement('first')],
    [7n, textElement('second')],
    [compoundKey, textElement('third')],
  )));
  assert.equal(each.children.length, 3);
  assert.equal(each.children[0].key, 7n);
  assert.equal(each.children[1].key, 7n);
  assert.deepEqual(each.children[2].key, compoundKey);
  assert.deepEqual(each.children.map(child => child.text), ['first', 'second', 'third']);

  const table = toVnode(seal('table', [
    list([cord('Name'), [[cord('chars'), 12n], cord('end')]]),
    list(
      [3n, list(textElement('a'))],
      [3n, list(textElement('b'))],
    ),
  ]));
  assert.equal(table.tag, 'table');
  assert.equal(table.children[0].tag, 'thead');
  assert.equal(table.children[0].children[0].children[0].tag, 'th');
  assert.equal(table.children[0].children[0].children[0].children[0].text, 'Name');
  assert.equal(table.children[0].children[0].children[0].attrs.style.textAlign, 'end');
  const rows = table.children[1].children;
  assert.equal(table.children[1].tag, 'tbody');
  assert.deepEqual(rows.map(row => row.key), [3n, 3n]);
  assert.deepEqual(rows.map(row => row.children[0].children[0].text), ['a', 'b']);
});

test('toVnode decodes media, links, and all control payloads', () => {
  const image = toVnode(seal('image', [list(cord('static'), cord('a.png')), cord('description')]));
  assert.equal(image.tag, 'img');
  assert.equal(image.attrs.src, '/static/a.png');
  assert.equal(image.attrs.alt, 'description');

  const unsafeImage = toVnode(seal('image-unsafe', [
    [cord('https://example.com/a.png'), [20n, 10n]], cord('remote'),
  ]));
  assert.equal(unsafeImage.attrs.width, '20');
  assert.equal(unsafeImage.attrs.height, '10');
  assert.equal(unsafeImage.attrs.style.aspectRatio, '20 / 10');

  assert.equal(toVnode(seal('link', [list(cord('blog')), cord('Blog')])).attrs.href, '/blog');
  assert.equal(toVnode(seal('link-unsafe', [cord('/elsewhere'), cord('Away')])).attrs.href, '/elsewhere');

  const message = [cord('message'), 42n];
  const buttonVnode = toVnode(seal('button', [cord('Push'), message]));
  assert.equal(buttonVnode.tag, 'button');
  assert.deepEqual(buttonVnode.control, { type: 'button', message });

  const toggle = toVnode(seal('toggle', [0n, [cord('Done'), message]]));
  assert.equal(toggle.attrs.checked, true);
  assert.equal(toggle.attrs['aria-label'], 'Done');
  assert.deepEqual(toggle.control, { type: 'toggle', message });

  const reply = value => [message, value];
  const input = toVnode(seal('field', [cord('Draft'), [cord('text'), reply]]));
  assert.equal(input.attrs.value, 'text');
  assert.equal(input.control.reply, reply);

  const form = toVnode(seal('form', [message, list(textElement('body'))]));
  assert.equal(form.tag, 'form');
  assert.deepEqual(form.control, { type: 'form', message });
});

test('createDom creates text and element nodes without HTML interpretation', () => {
  const vnode = element('div', { id: 'root', class: 'safe' }, [
    textNode('<img src=x onerror=alert(1)>'),
    element('span', { title: 'a"b' }, [textNode('child')]),
  ]);
  const { node } = render(vnode);
  assert.equal(node.localName, 'div');
  assert.equal(node.getAttribute('id'), 'root');
  assert.equal(node.firstChild.nodeType, 3);
  assert.equal(node.firstChild.nodeValue, '<img src=x onerror=alert(1)>');
  assert.equal(node.children[0].localName, 'span');
  assert.equal(node.textContent, '<img src=x onerror=alert(1)>child');
  assert.equal(node.__jibb.vnode, vnode);
});

test('patchDom updates text and attrs, replaces incompatible nodes, and refreshes listeners', () => {
  const document = createFakeDocument();
  const sent = [];
  const options = { document, dispatch: message => sent.push(message) };
  const original = button(1n, cord('old'), 'old');
  const node = createDom(original, options);
  document.body.appendChild(node);

  const next = button(1n, cord('new'), 'new');
  next.attrs.title = 'updated';
  const patched = patchDom(document.body, node, next, options);
  assert.equal(patched, node);
  assert.equal(node.textContent, 'new');
  assert.equal(node.getAttribute('title'), 'updated');
  node.click();
  assert.deepEqual(sent, [cord('new')]);

  const withoutTitle = { ...next, attrs: { type: 'button' } };
  patchDom(document.body, node, withoutTitle, options);
  assert.equal(node.hasAttribute('title'), false);
  assert.equal(node.hasAttribute('data-name'), false);

  const replacement = patchDom(document.body, node, element('p', {}, [textNode('paragraph')]), options);
  assert.notEqual(replacement, node);
  assert.equal(replacement.localName, 'p');
  assert.equal(document.body.firstChild, replacement);

  const currentText = patchDom(document.body, replacement, textNode('plain'), options);
  assert.equal(currentText.nodeType, 3);
  const sameText = patchDom(document.body, currentText, textNode('changed'), options);
  assert.equal(sameText, currentText);
  assert.equal(currentText.nodeValue, 'changed');
});

test('keyed reconciliation preserves identity, focus, and caret through moves', () => {
  const initial = element('div', {}, [field(1n, 'one'), field(2n, 'two'), field(3n, 'three')]);
  const { document, node } = render(initial);
  const [one, two, three] = childElements(node);
  two.focus();
  two.setSelectionRange(1, 2, 'forward');

  const reordered = element('div', {}, [
    field(3n, 'three', 'THREE'),
    field(1n, 'one', 'ONE'),
    field(2n, 'two', 'TWO'),
  ]);
  patchDom(document.body, node, reordered, { document });
  assert.deepEqual(childElements(node), [three, one, two]);
  assert.equal(document.activeElement, two);
  assert.equal(two.selectionStart, 1);
  assert.equal(two.selectionEnd, 2);
  assert.equal(two.selectionDirection, 'forward');
  assert.equal(two.value, 'two');
  assert.equal(two.getAttribute('aria-label'), 'TWO');
});

test('duplicate keys match in occurrence order and compound keys use noun equality', () => {
  const compound = [cord('id'), 9n];
  const initial = element('div', {}, [
    field(7n, 'first'),
    field(7n, 'second'),
    field(compound, 'compound'),
  ]);
  const { document, node } = render(initial);
  const [first, second, third] = childElements(node);

  const next = element('div', {}, [
    field([cord('id'), 9n], 'compound'),
    field(7n, 'FIRST'),
    field(7n, 'SECOND'),
  ]);
  patchDom(document.body, node, next, { document });
  assert.deepEqual(childElements(node), [third, first, second]);
  assert.equal(first.value, 'FIRST');
  assert.equal(second.value, 'SECOND');

  const oneDuplicate = element('div', {}, [field(7n, 'only')]);
  patchDom(document.body, node, oneDuplicate, { document });
  assert.deepEqual(childElements(node), [first]);
  assert.equal(first.value, 'only');
  assert.equal(second.parentNode, null);
  assert.equal(third.parentNode, null);
});

test('keyed removals and insertions leave unrelated unkeyed nodes stable', () => {
  const initial = element('div', {}, [
    element('span', { id: 'unkeyed' }, [textNode('before')]),
    button(1n, 1n, 'one'),
    button(2n, 2n, 'two'),
  ]);
  const { document, node } = render(initial);
  const [unkeyed, one, two] = childElements(node);
  const next = element('div', {}, [
    element('span', { id: 'unkeyed' }, [textNode('after')]),
    button(3n, 3n, 'three'),
    button(2n, 2n, 'TWO'),
  ]);
  patchDom(document.body, node, next, { document });
  const current = childElements(node);
  assert.equal(current[0], unkeyed);
  assert.equal(current[0].textContent, 'after');
  assert.notEqual(current[1], one);
  assert.equal(current[2], two);
  assert.equal(two.textContent, 'TWO');
  assert.equal(one.parentNode, null);
});

test('button and toggle dispatch synchronously and controls reset to the latest view', () => {
  const document = createFakeDocument();
  const sent = [];
  const dispatch = message => sent.push(message);
  const buttonNode = createDom(toVnode(seal('button', [cord('Push'), cord('clicked')])), {
    document, dispatch,
  });
  buttonNode.click();
  assert.deepEqual(sent, [cord('clicked')]);

  const toggleNode = createDom(toVnode(seal('toggle', [1n, [cord('Done'), cord('toggled')]])), {
    document, dispatch,
  });
  assert.equal(toggleNode.checked, false);
  toggleNode.checked = true;
  toggleNode.dispatchEvent(new FakeEvent('change'));
  assert.deepEqual(sent, [cord('clicked'), cord('toggled')]);
  assert.equal(toggleNode.checked, false, 'unchanged view resets a toggle after its event');
});

test('fields reply with cord text on input, but not during IME composition', () => {
  const document = createFakeDocument();
  const sent = [];
  const reply = value => [cord('typed'), value];
  const vnode = toVnode(seal('field', [cord('Name'), [cord('before'), reply]]));
  const node = createDom(vnode, { document, dispatch: message => sent.push(message) });

  node.value = 'hello';
  node.dispatchEvent(new FakeEvent('input'));
  assert.deepEqual(sent, [[cord('typed'), cord('hello')]]);
  assert.equal(node.value, 'before', 'the current view is synchronized after dispatch');

  node.value = 'に';
  node.dispatchEvent(new FakeEvent('compositionstart'));
  node.dispatchEvent(new FakeEvent('input', { isComposing: true }));
  node.value = 'にほ';
  node.dispatchEvent(new FakeEvent('input', { isComposing: true }));
  assert.equal(sent.length, 1, 'composition input does not dispatch intermediate text');

  node.value = '日本';
  node.dispatchEvent(new FakeEvent('compositionend'));
  assert.deepEqual(sent[1], [cord('typed'), cord('日本')]);
  assert.equal(sent.length, 2);
  assert.equal(node.value, 'before');
});

test('form Enter dispatches only the nearest message and prevents reload', () => {
  const document = createFakeDocument();
  const sent = [];
  const options = { document, dispatch: message => sent.push(message) };
  const inner = toVnode(seal('form', [cord('inner'), list(
    seal('field', [cord('Draft'), [cord(''), value => [cord('ignored'), value]]]),
  )]));
  const outer = toVnode(seal('form', [cord('outer'), list(rawSeal([
    cord('form'), [cord('outer-unused'), 0n],
  ]))]));
  // Build the nested forms directly so the test can exercise bubbling and nearest-form behavior.
  outer.children = [inner];
  const node = createDom(outer, options);
  const input = node.querySelector('input');
  const enter = new FakeEvent('keydown', { key: 'Enter' });
  input.dispatchEvent(enter);
  assert.equal(enter.defaultPrevented, true);
  assert.deepEqual(sent, [cord('inner')]);

  const submit = new FakeEvent('submit');
  node.dispatchEvent(submit);
  assert.equal(submit.defaultPrevented, true);
  assert.deepEqual(sent, [cord('inner'), cord('outer')]);
});

test('syncControls writes only changed value, checked, and disabled properties', () => {
  const document = createFakeDocument();
  const vnode = element('input', {
    type: 'text', value: 'stable', checked: false, disabled: false,
  }, [], { control: { type: 'field', reply: value => value } });
  const node = createDom(vnode, { document });
  node.focus();
  node.setSelectionRange(2, 4);

  let valueWrites = 0;
  let checkedWrites = 0;
  let disabledWrites = 0;
  let value = node.value;
  let checked = node.checked;
  let disabled = node.disabled;
  Object.defineProperties(node, {
    value: { get: () => value, set: next => { valueWrites += 1; value = next; } },
    checked: { get: () => checked, set: next => { checkedWrites += 1; checked = next; } },
    disabled: { get: () => disabled, set: next => { disabledWrites += 1; disabled = next; } },
  });

  syncControls(node, vnode);
  patchDom(document.body, node, { ...vnode }, { document });
  assert.equal(valueWrites, 0, 'unchanged field values are never rewritten');
  assert.equal(checkedWrites, 0);
  assert.equal(disabledWrites, 0);
  assert.equal(document.activeElement, node);
  assert.equal(node.selectionStart, 2);
  assert.equal(node.selectionEnd, 4);

  syncControls(node, {
    ...vnode,
    attrs: { ...vnode.attrs, value: 'changed', checked: true, disabled: true },
  });
  assert.equal(valueWrites, 1);
  assert.equal(checkedWrites, 1);
  assert.equal(disabledWrites, 1);
  assert.equal(node.value, 'changed');
  assert.equal(node.checked, true);
  assert.equal(node.disabled, true);
});
