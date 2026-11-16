// The browser's decoder against the server's markup. tests/markup-parity/
// expected.txt holds, for each case, the HTML the ship's renderer writes for
// an element (tests/lib/markup-parity.hoon renders the same nouns through
// lib/jibb/renderer.jibb and jibb-build.hoon and compares them with the same
// file). Hydration keeps the server's DOM only when the browser's DOM for
// the same view serializes the same, so every case must match exactly: the
// tags, the attributes in order, the classes and the style.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { createDom } from '../browser/dom.mjs';
import { toVnode } from '../browser/vdom.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';
import { rawSeal } from '../natives/legacy.mjs';

const list = (...values) => arrayToList(values);
const seal = (tag, payload) => rawSeal([cord(tag), payload]);
const text = words => seal('text', cord(words));
const path = (...parts) => list(...parts.map(cord));
const attr = (name, value) => [cord(name), typeof value === 'string' ? cord(value) : value];
const chars = n => [cord('chars'), n];
const fill = n => [cord('fill'), n];
const shrink = cord('shrink');
const column = (header, width, align) => [cord(header), [width, cord(align)]];
const yes = 0n;
const no = 1n;

// The server's page context: its base, and a 4 by 5 static image.
const paths = {
  base: '/apps/my-app',
  assets: new Map([
    ['/static/img/dot.png', { url: '/apps/my-app/static/0v1.abcde/img/dot.png', width: 4, height: 5 }],
  ]),
};

// The same elements as the Hoon suite's cases, by name. The server's
// render-only lowering wraps elements in their source origins, which the
// browser never sees, so the origins cases are the same elements unwrapped.
const cases = {
  text: text('Fish & <ships> "quoted" \'single\''),
  heading: seal('heading', [2n, cord('Title')]),
  'heading-clamped': seal('column', [0n, list(
    seal('heading', [0n, cord('Low')]), seal('heading', [9n, cord('High')]),
  )]),
  'para-phrasing': seal('para', list(
    text('Read '),
    seal('link', [path('blog', 'first-post'), cord('the post')]),
    text(', '),
    seal('link-unsafe', [cord('https://urbit.org'), cord('Urbit')]),
    seal('image', [path('static', 'img', 'dot.png'), cord('A dot')]),
    seal('image-unsafe', [[cord('https://urbit.org/a.png'), [10n, 20n]], cord('Away')]),
  )),
  'para-block': seal('para', list(
    text('Status: '), seal('el', [list(attr('tone', 'danger')), text('offline')]),
  )),
  'para-heading': seal('para', list(text('Intro'), seal('heading', [2n, cord('Title')]))),
  'para-empty': seal('para', 0n),
  'para-each': seal('para', list(text('See '), seal('each', list([1n, text('a')])))),
  'para-in-para': seal('para', list(seal('para', list(text('inner'))))),
  'para-origins': seal('para', list(text('a '), seal('link', [path('blog', 'first-post'), cord('b')]))),
  'para-origins-block': seal('para', list(seal('el', [0n, text('b')]))),
  'row-attributes': seal('row', [list(
    attr('pad', 's2'), attr('gap', 's3'), attr('width', fill(0n)),
    attr('align', 'center'), attr('role', 'body'), attr('tone', 'danger'),
  ), list(text('all'))]),
  'column-chars': seal('column', [list(
    attr('width', chars(20n)), attr('align', 'end'), attr('role', 'caption'),
  ), list(text('narrow'))]),
  'wrap-shrink': seal('wrap', [list(
    attr('width', shrink), attr('gap', 's1'), attr('tone', 'muted'),
  ), list(text('a'), text('b'))]),
  'stack-fill': seal('stack', [list(
    attr('width', fill(3n)), attr('pad', 's0'), attr('role', 'label'), attr('tone', 'accent'),
  ), list(text('stacked'))]),
  'el-last-wins': seal('el', [list(
    attr('width', chars(5n)), attr('tone', 'danger'), attr('pad', 's1'),
    attr('width', shrink), attr('tone', 'normal'), attr('pad', 's3'),
  ), text('last')]),
  'el-back-to-chars': seal('el', [list(
    attr('width', shrink), attr('width', fill(2n)), attr('width', chars(7n)),
  ), text('seven')]),
  // Every value of every attribute, one el each.
  'every-attribute': seal('column', [0n, list(...[
    attr('pad', 's0'), attr('pad', 's1'), attr('pad', 's2'), attr('pad', 's3'),
    attr('gap', 's0'), attr('gap', 's1'), attr('gap', 's2'), attr('gap', 's3'),
    attr('align', 'start'), attr('align', 'center'), attr('align', 'end'),
    attr('role', 'body'), attr('role', 'caption'), attr('role', 'label'),
    attr('tone', 'normal'), attr('tone', 'muted'), attr('tone', 'accent'), attr('tone', 'danger'),
    attr('width', shrink), attr('width', chars(1n)), attr('width', fill(1n)),
  ].map(entry => seal('el', [list(entry), text('x')])))]),
  link: seal('link', [path('blog', 'first-post'), cord('First & best')]),
  'link-static': seal('link', [path('static', 'img', 'dot.png'), cord('Dot file')]),
  'link-home': seal('link', [0n, cord('Home')]),
  'link-unsafe-https': seal('link-unsafe', [cord('https://urbit.org/?a=1&b=2'), cord('Urbit')]),
  'link-unsafe-root': seal('link-unsafe', [cord('/apps/groups'), cord('Groups')]),
  'link-unsafe-mailto': seal('link-unsafe', [cord('mailto:a@b.c'), cord('Mail')]),
  'link-unsafe-tel': seal('link-unsafe', [cord('tel:+1555'), cord('Call')]),
  'link-unsafe-javascript': seal('link-unsafe', [cord('javascript:alert(1)'), cord('Run <me>')]),
  'link-unsafe-protocol-relative': seal('link-unsafe', [cord('//evil.example'), cord('Elsewhere')]),
  'link-unsafe-backslash': seal('link-unsafe', [cord('/\\evil.example'), cord('Back')]),
  'link-unsafe-tab': seal('link-unsafe', [cord('/\t/tabbed.example'), cord('Tabbed')]),
  'link-unsafe-http': seal('link-unsafe', [cord('http://plain.example'), cord('Plain')]),
  image: seal('image', [path('static', 'img', 'dot.png'), cord('A dot')]),
  'image-decorative': seal('image', [path('static', 'img', 'dot.png'), 0n]),
  'image-unsafe-https': seal('image-unsafe', [[cord('https://urbit.org/a.png'), [10n, 20n]], cord('Away')]),
  'image-unsafe-root': seal('image-unsafe', [[cord('/apps/x/a.png'), [3n, 4n]], cord('Root')]),
  'image-unsafe-data': seal('image-unsafe', [
    [cord('data:image/png;base64,AAAA'), [1n, 1n]], cord('Not "fetched"'),
  ]),
  each: seal('each', list([1n, text('one')], [[cord('k'), 2n], seal('el', [0n, text('two')])])),
  table: seal('table', [
    list(
      column('Qty', shrink, 'end'), column('Name', fill(1n), 'start'),
      column('Notes', fill(2n), 'center'), column('Code', chars(10n), 'end'),
    ),
    list(
      [1n, list(text('12'), text('Ann'), text('x'), text('A1'), text('extra'))],
      [2n, list(text('3'))],
    ),
  ]),
  'table-plain': seal('table', [list(column('A', chars(0n), 'start'), column('B', shrink, 'start')), 0n]),
  'table-fill-zero': seal('table', [list(column('Z', fill(0n), 'start')), 0n]),
  button: seal('button', [cord('Go & stop'), 0n]),
  'toggle-on': seal('toggle', [yes, [cord('On'), 0n]]),
  'toggle-off': seal('toggle', [no, [cord('Off'), 0n]]),
  field: seal('field', [cord('Name'), [cord('Ann & "Bo"'), 0n]]),
  form: seal('form', [0n, list(seal('field', [cord('Inner'), [0n, 0n]]), seal('button', [cord('Send'), 0n]))]),
  'form-nested': seal('form', [0n, list(
    text('before'),
    seal('form', [0n, list(text('inside'), seal('field', [cord('Nested'), [0n, 0n]]))]),
    text('after'),
  )]),
  'para-controls': seal('para', list(
    text('Pick '), seal('button', [cord('b'), 0n]),
    seal('toggle', [yes, [cord('t'), 0n]]), seal('field', [cord('f'), [cord('v'), 0n]]),
  )),
  'para-form': seal('para', list(seal('form', [0n, list(text('in form'))]))),
};

// A document whose elements keep their attributes in order and write their
// style as browsers do, "name: value;" joined by spaces, the style attribute
// taking its place when its first property is set.
function createParityDocument() {
  const kebab = name => (name.startsWith('--') ? name : name.replace(/[A-Z]/g, c => `-${c.toLowerCase()}`));
  class Style {
    constructor(owner) {
      this.owner = owner;
      this.entries = new Map();
    }

    get cssText() {
      return [...this.entries].map(([name, value]) => `${name}: ${value};`).join(' ');
    }

    setProperty(name, value) {
      if (value === '') return this.removeProperty(name);
      this.entries.set(kebab(name), String(value));
      this.owner.reflectStyle();
    }

    removeProperty(name) {
      this.entries.delete(kebab(name));
      this.owner.reflectStyle();
    }
  }
  const styleProxy = owner => new Proxy(new Style(owner), {
    set(target, name, value) {
      if (name in target || typeof name !== 'string') target[name] = value;
      else target.setProperty(name, value);
      return true;
    },
  });
  class Text {
    constructor(value) {
      this.nodeType = 3;
      this.nodeValue = String(value);
    }
  }
  class Element {
    constructor(document, tag) {
      this.ownerDocument = document;
      this.nodeType = 1;
      this.localName = tag.toLowerCase();
      this.attributes = new Map();
      this.childNodes = [];
      this.style = styleProxy(this);
      this.value = '';
      this.checked = false;
      this.disabled = false;
    }

    // An HTML document lowercases attribute names, so tabIndex is tabindex.
    setAttribute(name, value) {
      this.attributes.set(name.toLowerCase(), String(value));
    }

    removeAttribute(name) {
      this.attributes.delete(name.toLowerCase());
    }

    getAttribute(name) {
      return this.attributes.get(name.toLowerCase()) ?? null;
    }

    reflectStyle() {
      const text = this.style.cssText;
      if (text === '') this.attributes.delete('style');
      else this.attributes.set('style', text);
    }

    appendChild(node) {
      this.childNodes.push(node);
      return node;
    }

    addEventListener() {}
    removeEventListener() {}
  }
  const document = {
    createElement: tag => new Element(document, tag),
    createTextNode: value => new Text(value),
  };
  return document;
}

// HTML as the server writes it: every &, <, >, " and ' escaped, in text and
// in attributes alike, and no end tag for a void element.
const escapeHtml = value => value.replace(/[&<>"']/g, c => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;',
}[c]));
const VOID = new Set(['img', 'input']);
function serialize(node) {
  if (node.nodeType === 3) return escapeHtml(node.nodeValue);
  const attrs = [...node.attributes].map(([name, value]) => ` ${name}="${escapeHtml(value)}"`).join('');
  if (VOID.has(node.localName)) return `<${node.localName}${attrs}>`;
  return `<${node.localName}${attrs}>${node.childNodes.map(serialize).join('')}</${node.localName}>`;
}

function expectedCases() {
  const lines = readFileSync(new URL('../../tests/markup-parity/expected.txt', import.meta.url), 'utf8')
    .split('\n');
  assert.equal(lines.pop(), '', 'expected.txt ends in one newline');
  return new Map(lines.map(line => {
    const space = line.indexOf(' ');
    return [line.slice(0, space), line.slice(space + 1)];
  }));
}

test('the server and browser cases are the same', () => {
  assert.deepEqual([...expectedCases().keys()], Object.keys(cases));
});

test('the decoder draws every element kind and attribute as the server does', () => {
  const document = createParityDocument();
  const differences = [];
  for (const [name, server] of expectedCases()) {
    const node = createDom(toVnode(cases[name], paths), { document, dispatch() {} });
    // A field is read-only until its island starts: the server marks it so,
    // and hydration takes the attribute off before it compares the DOM.
    const browser = serialize(node);
    if (browser !== server.replaceAll(' readonly=""', '')) differences.push({ name, browser, server });
  }
  assert.deepEqual(differences, []);
});

test('the parity document writes style attributes as browsers do', () => {
  const document = createParityDocument();
  const node = document.createElement('div');
  node.setAttribute('class', 'x');
  node.style.setProperty('--j-chars', '5ch');
  node.style.width = '100%';
  node.style.setProperty('text-align', 'start');
  node.setAttribute('tabIndex', '-1');
  // As Chromium wrote it for the same calls.
  assert.equal(serialize(node), '<div class="x" style="--j-chars: 5ch; width: 100%; text-align: start;" tabindex="-1"></div>');
});
