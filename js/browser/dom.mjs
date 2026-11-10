import { cord } from '../natives/helpers.mjs';

const METADATA = '__jibb';

function contextFor(node, parent, options) {
  const previous = node?.[METADATA] ?? parent?.[METADATA];
  const document = options.document ?? previous?.document ?? parent?.ownerDocument ?? globalThis.document;
  if (!document) throw new TypeError('createDom/patchDom requires a document');
  return {
    document,
    dispatch: options.dispatch ?? previous?.dispatch ?? (() => {}),
  };
}

function setStyle(node, name, value) {
  if (name.startsWith('--') || name.includes('-')) {
    node.style.setProperty(name, String(value));
  } else {
    node.style[name] = String(value);
  }
}

function updateStyle(node, previous, next) {
  if (typeof next === 'string') {
    if (previous !== next) node.setAttribute('style', next);
    return;
  }
  if (typeof previous === 'string') node.removeAttribute('style');
  const before = previous && typeof previous === 'object' ? previous : {};
  const after = next && typeof next === 'object' ? next : {};
  for (const name of Object.keys(before)) {
    if (after[name] === undefined || after[name] === null) {
      if (name.startsWith('--') || name.includes('-')) node.style.removeProperty(name);
      else node.style[name] = '';
    }
  }
  for (const [name, value] of Object.entries(after)) {
    if (before[name] !== value && value !== undefined && value !== null) {
      setStyle(node, name, value);
    }
  }
}

function setAttribute(node, name, value) {
  if (name === 'style') return;
  if (value === false || value === undefined || value === null) {
    node.removeAttribute(name);
  } else {
    node.setAttribute(name, value === true ? '' : String(value));
  }
}

function updateAttributes(node, previous = {}, next = {}) {
  for (const name of Object.keys(previous)) {
    if (!(name in next)) {
      if (name === 'style') updateStyle(node, previous[name], {});
      else node.removeAttribute(name);
    }
  }
  for (const [name, value] of Object.entries(next)) {
    if (name === 'style') updateStyle(node, previous[name], value ?? {});
    else if (previous[name] !== value) setAttribute(node, name, value);
  }
}

function controlType(vnode) {
  return vnode.control?.type ?? vnode.control?.kind;
}

function currentMessage(node) {
  const metadata = node[METADATA];
  const control = metadata.vnode.control;
  if (controlType(metadata.vnode) === 'field') {
    return control.reply(cord(node.value));
  }
  return control.message;
}

function dispatchControl(node) {
  const metadata = node[METADATA];
  if (!metadata?.vnode.control || node.disabled) return;
  try {
    // A direct call is intentional: update/view dispatch has no asynchronous gap.
    metadata.dispatch(currentMessage(node));
  } finally {
    const current = node[METADATA];
    if (current) syncControls(node, current.vnode);
  }
}

function addListener(node, metadata, type, listener) {
  node.addEventListener(type, listener);
  metadata.listeners.push({ type, listener });
}

function installListeners(node, metadata) {
  for (const { type, listener } of metadata.listeners) {
    node.removeEventListener(type, listener);
  }
  metadata.listeners = [];
  metadata.controlType = controlType(metadata.vnode);

  switch (metadata.controlType) {
    case 'button':
      addListener(node, metadata, 'click', () => dispatchControl(node));
      break;
    case 'toggle':
      addListener(node, metadata, 'change', () => dispatchControl(node));
      break;
    case 'field':
      addListener(node, metadata, 'compositionstart', () => {
        metadata.composing = true;
      });
      addListener(node, metadata, 'input', event => {
        if (metadata.composing || event.isComposing) return;
        dispatchControl(node);
      });
      addListener(node, metadata, 'compositionend', event => {
        metadata.composing = false;
        dispatchControl(node);
      });
      break;
    case 'form':
      addListener(node, metadata, 'keydown', event => {
        if (event.key !== 'Enter' || event.isComposing || event.defaultPrevented) return;
        const target = event.target;
        if (!target?.[METADATA] || controlType(target[METADATA].vnode) !== 'field') return;
        event.preventDefault();
        dispatchControl(node);
      });
      addListener(node, metadata, 'submit', event => {
        event.preventDefault();
        dispatchControl(node);
      });
      break;
  }
}

function updateMetadata(node, vnode, context) {
  const previous = node[METADATA];
  const metadata = previous ?? {
    document: context.document,
    dispatch: context.dispatch,
    listeners: [],
    composing: false,
  };
  metadata.document = context.document;
  metadata.dispatch = context.dispatch;
  metadata.vnode = vnode;
  node[METADATA] = metadata;
  if (!previous || metadata.controlType !== controlType(vnode)) {
    installListeners(node, metadata);
  }
  return metadata;
}

/** Synchronize mutable control properties without touching unchanged values. */
export function syncControls(node, vnode) {
  if (!vnode || vnode.kind !== 'element') return;
  const attrs = vnode.attrs ?? {};
  const control = vnode.control ?? {};
  const type = controlType(vnode);

  const hasValue = Object.hasOwn(attrs, 'value') || Object.hasOwn(control, 'value') || type === 'field';
  if (hasValue) {
    const value = String(attrs.value ?? control.value ?? '');
    if (node.value !== value) node.value = value;
  }

  const hasChecked = Object.hasOwn(attrs, 'checked') || Object.hasOwn(control, 'checked') || type === 'toggle';
  if (hasChecked) {
    const checked = Boolean(attrs.checked ?? control.checked ?? false);
    if (node.checked !== checked) node.checked = checked;
  }

  if (vnode.control || Object.hasOwn(attrs, 'disabled') || Object.hasOwn(control, 'disabled')) {
    const disabled = Boolean(attrs.disabled ?? control.disabled ?? false);
    if (node.disabled !== disabled) node.disabled = disabled;
  }
}

/** Create a DOM node and attach current-vnode metadata plus stable listeners. */
export function createDom(vnode, options = {}) {
  const context = contextFor(null, null, options);
  let node;
  if (vnode.kind === 'text') {
    node = context.document.createTextNode(vnode.text);
  } else if (vnode.kind === 'element') {
    node = context.document.createElement(vnode.tag);
    updateMetadata(node, vnode, context);
    updateAttributes(node, {}, vnode.attrs);
    for (const child of vnode.children) {
      node.appendChild(createDom(child, context));
    }
    syncControls(node, vnode);
  } else {
    throw new TypeError(`Unknown vnode kind ${vnode.kind}`);
  }
  if (vnode.kind === 'text') updateMetadata(node, vnode, context);
  return node;
}

function sameKey(left, right) {
  if (left === right) return true;
  if (typeof left === 'bigint' || typeof right === 'bigint') return false;
  if (!Array.isArray(left) || !Array.isArray(right)) return false;
  return left.length === right.length && left.every((part, index) => sameKey(part, right[index]));
}

// An atom key is its own token: a Map compares BigInts by value.
function keyToken(key) {
  if (typeof key === 'bigint') return key;
  if (Array.isArray(key)) return `c:${key.length}:${key.map(keyToken).join('|')}`;
  return `j:${typeof key}:${String(key)}`;
}

function oldKey(node) {
  return node[METADATA]?.vnode?.key;
}

// The children keep their keys in order, as after most messages: each
// patches its own node.
function inOrder(oldNodes, children) {
  if (oldNodes.length !== children.length) return false;
  for (let index = 0; index < children.length; index += 1) {
    const before = oldKey(oldNodes[index]);
    const after = children[index].key;
    if (before === undefined || after === undefined) {
      if (before !== after) return false;
    } else if (!sameKey(before, after)) {
      return false;
    }
  }
  return true;
}

function patchChildren(parent, children, context) {
  const oldNodes = Array.from(parent.childNodes);
  if (inOrder(oldNodes, children)) {
    for (let index = 0; index < children.length; index += 1) {
      patchDom(parent, oldNodes[index], children[index], context);
    }
    return;
  }
  const keyed = new Map();
  const unkeyed = [];
  for (const node of oldNodes) {
    const key = oldKey(node);
    if (key === undefined) {
      unkeyed.push(node);
    } else {
      const token = keyToken(key);
      const bucket = keyed.get(token);
      if (bucket) bucket.push(node);
      else keyed.set(token, [node]);
    }
  }

  const used = new Set();
  const current = children.map(vnode => {
    let old;
    if (vnode.key !== undefined) {
      const bucket = keyed.get(keyToken(vnode.key)) ?? [];
      // A queue, rather than a key-to-node map, gives repeated keys ordered matching.
      while (bucket.length && used.has(bucket[0])) bucket.shift();
      old = bucket.shift();
      if (old && !sameKey(oldKey(old), vnode.key)) old = undefined;
    } else {
      while (unkeyed.length && used.has(unkeyed[0])) unkeyed.shift();
      old = unkeyed.shift();
    }

    let node;
    if (old) {
      used.add(old);
      node = patchDom(parent, old, vnode, context);
    } else {
      node = createDom(vnode, context);
    }
    return node;
  });

  current.forEach((node, index) => {
    const atIndex = parent.childNodes[index] ?? null;
    if (atIndex !== node) parent.insertBefore(node, atIndex);
  });
  for (const node of oldNodes) {
    if (!used.has(node)) parent.removeChild(node);
  }
}

/** Patch a managed node in place, replacing it only when its kind or tag changes. */
export function patchDom(parent, node, vnode, options = {}) {
  const context = contextFor(node, parent, options);
  if (!node) {
    const created = createDom(vnode, context);
    parent.appendChild(created);
    return created;
  }

  const previous = node[METADATA]?.vnode;
  // The same vnode shows the same DOM. A control the reader changed is
  // reset by the dispatch that reported it.
  if (previous === vnode) return node;
  const compatible = previous && previous.kind === vnode.kind
    && (vnode.kind === 'text' || previous.tag === vnode.tag);
  if (!compatible) {
    const replacement = createDom(vnode, context);
    parent.replaceChild(replacement, node);
    return replacement;
  }

  if (vnode.kind === 'text') {
    if (node.nodeValue !== vnode.text) node.nodeValue = vnode.text;
    updateMetadata(node, vnode, context);
    return node;
  }

  updateMetadata(node, vnode, context);
  updateAttributes(node, previous.attrs, vnode.attrs);
  patchChildren(node, vnode.children, context);
  syncControls(node, vnode);
  return node;
}
