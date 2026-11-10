import { slot } from '../core/runtime.mjs';
import { validateRawSeal } from '../natives/legacy.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { createDom } from './dom.mjs';
import { atomText } from './vdom.mjs';

const viewTemplates = new WeakMap();

// Boot supplies this decorator only to checked host modules. Arbitrary JS
// callers use the public runtime's identity decorator: foreign callbacks or
// mutable captured cells cannot establish the compiler's immutable view proof.
export function compiledViewTemplate(gate, tree, axes, natives) {
  viewTemplates.set(gate, { tree, axes, natives });
  return gate;
}

// The compiler proves the fixed structure; the original gate still runs on
// every render. Only model-dependent text is decoded and patched afterward.
// A same-named native supplied by a caller cannot establish that proof;
// custom natives may mutate cells or the registry behind an ordinary gate.
export function createViewTemplate(view, value, options) {
  const plan = viewTemplates.get(view);
  if (!plan || plan.natives !== loweredNatives) return null;
  const read = value => {
    validateRawSeal(value);
    return plan.axes.map(axis => atomText(slot(axis, value), 'text'));
  };
  const texts = read(value);
  const make = tree => {
    if (!Array.isArray(tree)) {
      return { kind: 'text', text: typeof tree === 'number' ? texts[tree] : tree };
    }
    return { kind: 'element', tag: tree[0], attrs: tree[1], children: tree[2].map(make) };
  };
  const vnode = make(plan.tree);
  const node = createDom(vnode, options);
  const holes = [];
  const bind = (tree, vnode, node) => {
    if (typeof tree === 'number') holes[tree] = { vnode, node };
    else if (Array.isArray(tree)) {
      tree[2].forEach((child, index) => bind(child, vnode.children[index], node.childNodes[index]));
    }
  };
  bind(plan.tree, vnode, node);
  return {
    view, vnode, node,
    update(value) {
      // Validate every hole before changing any DOM, so a failed render
      // leaves both the previous model and its complete view in place.
      read(value).forEach((text, index) => {
        const hole = holes[index];
        if (hole.node.nodeValue !== text) hole.node.nodeValue = text;
        hole.vnode.text = text;
      });
    },
  };
}
