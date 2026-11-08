const BUBBLING_EVENTS = new Set([
  'click', 'input', 'change', 'keydown', 'submit',
  'compositionstart', 'compositionend',
]);

export class FakeEvent {
  constructor(type, init = {}) {
    this.type = type;
    this.bubbles = init.bubbles ?? BUBBLING_EVENTS.has(type);
    this.cancelable = init.cancelable ?? true;
    this.key = init.key;
    this.isComposing = init.isComposing ?? false;
    this.inputType = init.inputType;
    this.defaultPrevented = false;
    this.target = null;
    this.currentTarget = null;
  }

  preventDefault() {
    if (this.cancelable) this.defaultPrevented = true;
  }

  stopPropagation() {
    this.propagationStopped = true;
  }
}

class FakeStyle {
  constructor() {
    this.cssText = '';
  }

  setProperty(name, value) {
    this[name] = String(value);
  }

  removeProperty(name) {
    const previous = this[name] ?? '';
    this[name] = '';
    return previous;
  }
}

class FakeNode {
  constructor(document, nodeType, nodeName) {
    this.ownerDocument = document;
    this.nodeType = nodeType;
    this.nodeName = nodeName;
    this.parentNode = null;
    this.childNodes = [];
  }

  get firstChild() {
    return this.childNodes[0] ?? null;
  }

  get lastChild() {
    return this.childNodes[this.childNodes.length - 1] ?? null;
  }

  get children() {
    return this.childNodes.filter(node => node.nodeType === 1);
  }

  get nextSibling() {
    if (!this.parentNode) return null;
    const index = this.parentNode.childNodes.indexOf(this);
    return this.parentNode.childNodes[index + 1] ?? null;
  }

  get textContent() {
    if (this.nodeType === 3) return this.nodeValue;
    return this.childNodes.map(node => node.textContent).join('');
  }

  set textContent(value) {
    if (this.nodeType === 3) {
      this.nodeValue = String(value);
      return;
    }
    for (const child of this.childNodes) child.parentNode = null;
    this.childNodes = [];
    if (value !== '') this.appendChild(this.ownerDocument.createTextNode(String(value)));
  }

  appendChild(node) {
    return this.insertBefore(node, null);
  }

  insertBefore(node, reference) {
    if (reference !== null && reference.parentNode !== this) {
      throw new Error('insertBefore reference is not a child');
    }
    if (node === reference) return node;
    if (node.parentNode) node.parentNode.removeChild(node);
    const index = reference === null ? this.childNodes.length : this.childNodes.indexOf(reference);
    this.childNodes.splice(index, 0, node);
    node.parentNode = this;
    return node;
  }

  removeChild(node) {
    const index = this.childNodes.indexOf(node);
    if (index < 0) throw new Error('removeChild target is not a child');
    this.childNodes.splice(index, 1);
    node.parentNode = null;
    return node;
  }

  replaceChild(replacement, node) {
    const index = this.childNodes.indexOf(node);
    if (index < 0) throw new Error('replaceChild target is not a child');
    if (replacement === node) return node;
    if (replacement.parentNode) replacement.parentNode.removeChild(replacement);
    this.childNodes[index] = replacement;
    replacement.parentNode = this;
    node.parentNode = null;
    return node;
  }

  contains(node) {
    for (let current = node; current; current = current.parentNode) {
      if (current === this) return true;
    }
    return false;
  }
}

class FakeText extends FakeNode {
  constructor(document, value) {
    super(document, 3, '#text');
    this.nodeValue = String(value);
  }

  get data() {
    return this.nodeValue;
  }

  set data(value) {
    this.nodeValue = String(value);
  }
}

class FakeElement extends FakeNode {
  constructor(document, tag) {
    const upper = tag.toUpperCase();
    super(document, 1, upper);
    this.tagName = upper;
    this.localName = tag.toLowerCase();
    this.attributes = new Map();
    this.style = new FakeStyle();
    this.listeners = new Map();
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.selectionStart = 0;
    this.selectionEnd = 0;
    this.selectionDirection = 'none';
  }

  setAttribute(name, value) {
    const text = String(value);
    this.attributes.set(name, text);
    if (name === 'style') this.style.cssText = text;
    if (name === 'type') this.type = text;
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  hasAttribute(name) {
    return this.attributes.has(name);
  }

  removeAttribute(name) {
    this.attributes.delete(name);
    if (name === 'style') {
      this.style = new FakeStyle();
    }
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    if (!listeners.includes(listener)) listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  removeEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    this.listeners.set(type, listeners.filter(candidate => candidate !== listener));
  }

  dispatchEvent(event) {
    if (!event.target) event.target = this;
    const path = [this];
    if (event.bubbles) {
      for (let parent = this.parentNode; parent; parent = parent.parentNode) path.push(parent);
    }
    for (const current of path) {
      event.currentTarget = current;
      for (const listener of [...(current.listeners.get(event.type) ?? [])]) {
        listener.call(current, event);
      }
      if (event.propagationStopped) break;
    }
    event.currentTarget = null;
    return !event.defaultPrevented;
  }

  focus() {
    if (!this.disabled) this.ownerDocument.activeElement = this;
  }

  blur() {
    if (this.ownerDocument.activeElement === this) {
      this.ownerDocument.activeElement = this.ownerDocument.body;
    }
  }

  click() {
    if (this.disabled) return;
    if (this.localName === 'input' && this.getAttribute('type') === 'checkbox') {
      this.checked = !this.checked;
    }
    this.dispatchEvent(new FakeEvent('click'));
  }

  setSelectionRange(start, end, direction = 'none') {
    this.selectionStart = start;
    this.selectionEnd = end;
    this.selectionDirection = direction;
  }

  querySelectorAll(selector) {
    const matches = [];
    const matchesSelector = node => {
      if (selector.startsWith('#')) return node.getAttribute('id') === selector.slice(1);
      if (selector.startsWith('.')) {
        return (node.getAttribute('class') ?? '').split(/\s+/).includes(selector.slice(1));
      }
      return node.localName === selector.toLowerCase();
    };
    for (const child of this.children) {
      if (matchesSelector(child)) matches.push(child);
      matches.push(...child.querySelectorAll(selector));
    }
    return matches;
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] ?? null;
  }
}

class FakeDocument extends FakeNode {
  constructor() {
    super(null, 9, '#document');
    this.ownerDocument = this;
    this.listeners = new Map();
    this.body = this.createElement('body');
    this.appendChild(this.body);
    this.activeElement = this.body;
  }

  createElement(tag) {
    return new FakeElement(this, tag);
  }

  createTextNode(value) {
    return new FakeText(this, value);
  }
}

export function createFakeDocument() {
  return new FakeDocument();
}
