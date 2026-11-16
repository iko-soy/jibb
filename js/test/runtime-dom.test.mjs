import test from 'node:test';
import assert from 'node:assert/strict';
import { createDom, hydrateDom, patchDom } from '../browser/dom.mjs';
import { createFakeDocument } from './fake-dom.mjs';

// The fake DOM, as a browser, takes focus from a field that leaves the
// document, even to be inserted again elsewhere.
const row = key => ({
  kind: 'element', tag: 'div', attrs: { 'data-row': String(key) }, key: BigInt(key), children: [{
    kind: 'element', tag: 'input', attrs: { type: 'text', value: `row ${key}`, 'aria-label': `row ${key}` },
    children: [], control: { type: 'field', reply: value => value },
  }],
});
const list = keys => ({ kind: 'element', tag: 'div', attrs: {}, children: keys.map(row) });

function rendered(keys) {
  const document = createFakeDocument();
  const root = createDom(list(keys), { document, dispatch() {} });
  document.body.appendChild(root);
  // Count moves: insertions of rows already in the list.
  let moves = 0;
  const insertBefore = root.insertBefore.bind(root);
  root.insertBefore = (node, reference) => {
    if (node.parentNode === root) moves += 1;
    return insertBefore(node, reference);
  };
  return { document, root, moves: () => moves };
}

test('deleting a keyed row moves no other row, so a field in one keeps focus and caret', () => {
  const { document, root, moves } = rendered([1, 2, 3, 4, 5]);
  const field = root.querySelector('[aria-label="row 4"]');
  field.focus();
  field.setSelectionRange(2, 4, 'forward');
  patchDom(document.body, root, list([2, 3, 4, 5]), { document, dispatch() {} });
  assert.deepEqual(root.children.map(node => node.getAttribute('data-row')), ['2', '3', '4', '5']);
  assert.equal(moves(), 0);
  assert.strictEqual(root.querySelector('[aria-label="row 4"]'), field);
  assert.strictEqual(document.activeElement, field);
  assert.deepEqual([field.selectionStart, field.selectionEnd, field.selectionDirection], [2, 4, 'forward']);
});

test('keyed reorders move the fewest rows, and a moved field gets its focus back', () => {
  for (const [before, after, fewest] of [
    [[1, 2, 3, 4, 5], [5, 1, 2, 3, 4], 1],
    [[1, 2, 3, 4, 5], [2, 3, 4, 5, 1], 1],
    [[1, 2, 3, 4, 5], [1, 2, 6, 3, 4, 5], 0],
    [[1, 2, 3, 4, 5], [5, 4, 3, 2, 1], 4],
    [[1, 2, 3, 4, 5], [2, 1, 4, 3, 5], 2],
    [[1, 2, 3], [3, 7, 1], 1],
  ]) {
    const { document, root, moves } = rendered(before);
    const field = root.querySelector('[aria-label="row 1"]');
    field.focus();
    field.setSelectionRange(1, 3, 'backward');
    patchDom(document.body, root, list(after), { document, dispatch() {} });
    assert.deepEqual(root.children.map(node => Number(node.getAttribute('data-row'))), after);
    assert.equal(moves(), fewest, `${before} to ${after}`);
    assert.strictEqual(document.activeElement, field, `${before} to ${after}`);
    assert.deepEqual([field.selectionStart, field.selectionEnd, field.selectionDirection], [1, 3, 'backward']);
  }
});

test('hydration adopts a lone matching server node and replaces a split one whole', () => {
  const document = createFakeDocument();
  const vnode = { kind: 'element', tag: 'p', attrs: {}, children: [{ kind: 'text', text: 'hi' }] };
  const container = document.createElement('div');
  const server = createDom(vnode, { document });
  container.appendChild(server);
  delete server.__jibb;
  assert.strictEqual(hydrateDom([server], vnode, { document }), server);
  // Two server nodes for one view: neither stays.
  const first = createDom(vnode, { document });
  const second = document.createElement('div');
  container.replaceChild(first, server);
  container.appendChild(second);
  const fresh = hydrateDom([first, second], vnode, { document });
  assert.notStrictEqual(fresh, first);
  assert.deepEqual(container.childNodes, [fresh]);
});
