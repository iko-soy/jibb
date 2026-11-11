import { apply, slot } from '../core/runtime.mjs';
import { validateRawSeal } from '../natives/legacy.mjs';
import { loweredNatives } from '../natives/lowered.mjs';
import { createDom, patchDom } from './dom.mjs';
import { atomText, decodeAttrs, toVnode } from './vdom.mjs';

const viewTemplates = new WeakMap();

// Boot supplies this decorator only to checked host modules. Arbitrary JS
// callers use the public runtime's identity decorator: foreign callbacks or
// mutable captured cells cannot establish the compiler's immutable view proof.
export function compiledViewTemplate(gate, tree, axes, natives, holesGate) {
  viewTemplates.set(gate, { tree, axes, natives, holesGate });
  return gate;
}

// The ordinary view establishes the fixed structure and attributes at mount.
// A proven residual gate can compute only its holes on subsequent renders.
// A same-named native supplied by a caller cannot establish that proof;
// custom natives may mutate cells or the registry behind an ordinary gate.
export function createViewTemplate(view, value, options) {
  const plan = viewTemplates.get(view);
  if (!plan || plan.natives !== loweredNatives
    || (typeof plan.tree === 'number' && plan.tree < 0)) return null;
  const read = (tree, value, direct) => {
    const index = tree < 0 ? -tree - 1 : tree;
    const raw = direct ? value[index] : slot(plan.axes[index], value);
    return tree < 0 ? toVnode(raw, options.paths) : atomText(raw, 'text');
  };
  validateRawSeal(value);
  const make = tree => {
    if (typeof tree === 'number') {
      const decoded = read(tree, value);
      return tree < 0 ? decoded : { kind: 'text', text: decoded };
    }
    if (!Array.isArray(tree)) {
      return { kind: 'text', text: tree };
    }
    const fixedAttrs = typeof tree[1] === 'number';
    // Ordinary list layouts decode children before their attributes; el
    // validates attributes first. Preserve which error a failed mount reports.
    const children = fixedAttrs && tree[0] === 'el' ? undefined : tree[2].map(make);
    return {
      kind: 'element', tag: fixedAttrs ? 'div' : tree[0],
      attrs: fixedAttrs ? decodeAttrs(slot(tree[1], value), `j-${tree[0]}`) : tree[1],
      children: children ?? tree[2].map(make),
    };
  };
  const vnode = make(plan.tree);
  const node = createDom(vnode, options);
  const holes = [];
  const bind = (tree, vnode, node, parent, index) => {
    if (typeof tree === 'number') {
      holes[tree < 0 ? -tree - 1 : tree] = { tree, vnode, node, parent, index };
    } else if (Array.isArray(tree)) {
      tree[2].forEach((child, index) => bind(child, vnode.children[index], node.childNodes[index], vnode, index));
    }
  };
  bind(plan.tree, vnode, node);
  return {
    view, vnode, node,
    update(model) {
      // Validate every hole before changing any DOM, so a failed render
      // leaves both the previous model and its complete view in place.
      const direct = plan.holesGate;
      const value = apply(direct ?? view, model);
      if (direct) {
        if (!Array.isArray(value) || value.length !== plan.axes.length) {
          throw new TypeError('view template: invalid hole vector');
        }
      } else validateRawSeal(value);
      holes.map(hole => read(hole.tree, value, direct)).forEach((decoded, index) => {
        const hole = holes[index];
        if (hole.tree < 0) {
          hole.node = patchDom(hole.node.parentNode, hole.node, decoded, options);
          hole.parent.children[hole.index] = decoded;
          hole.vnode = decoded;
        } else {
          if (hole.node.nodeValue !== decoded) hole.node.nodeValue = decoded;
          hole.vnode.text = decoded;
        }
      });
    },
  };
}
