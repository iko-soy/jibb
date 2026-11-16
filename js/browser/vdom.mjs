import { CoreCrash, requireLoobean } from '../core/runtime.mjs';
import { cell, listToArray, text } from '../natives/helpers.mjs';
import { validateRawSeal } from '../natives/legacy.mjs';
import { safeUrl } from './safe-url.mjs';

// Style attributes are the theme stylesheet's atomic classes, as the server
// renders them, so the browser needs no theme tokens of its own. Every
// element's tags, attributes, attribute order and classes are the server's
// (lib/jibb/renderer.jibb and jibb-build.hoon), so hydration finds the
// server's DOM equal to the browser's: classes first, then the other
// attributes, then the style, whose keys are CSS property names.
const SPACES = new Set(['s0', 's1', 's2', 's3']);
const TONES = new Set(['normal', 'muted', 'accent', 'danger']);
// What a <p> may hold; the HTML parser closes a <p> at anything else.
const PHRASING = new Set([
  'text', 'link', 'link-unsafe', 'image', 'image-unsafe', 'button', 'toggle', 'field',
]);

function fail(message) {
  throw new CoreCrash(`toVnode: ${message}`);
}

export function atomText(value, operation) {
  try {
    return text(value);
  } catch (error) {
    fail(`${operation}: ${error.message}`);
  }
}

function pair(value, operation) {
  try {
    return cell(value, operation);
  } catch (error) {
    fail(error.message);
  }
}

function items(value, operation) {
  try {
    return listToArray(value, operation);
  } catch (error) {
    fail(error.message);
  }
}

function element(tag, attrs = {}, children = [], control, key) {
  const vnode = { kind: 'element', tag, attrs, children };
  if (control !== undefined) vnode.control = control;
  if (key !== undefined) vnode.key = key;
  return vnode;
}

function words(value) {
  return { kind: 'text', text: atomText(value, 'text') };
}

// A keyed child of a given vnode is made once per key, so a view that
// keeps its parts keeps its keyed vnodes too.
const KEYED = Symbol('jibb.keyed');
function keyed(key, vnode) {
  if (typeof key !== 'bigint') return { ...vnode, key };
  const byKey = vnode[KEYED] ?? (vnode[KEYED] = new Map());
  let made = byKey.get(key);
  if (made === undefined) {
    made = { ...vnode, key };
    byKey.set(key, made);
  }
  return made;
}

// A width's kind, as the renderer's fill-weight floors a fill below 1.
function lengthOf(value) {
  if (typeof value === 'bigint') {
    if (atomText(value, 'width') !== 'shrink') fail('unknown width');
    return { kind: 'shrink' };
  }
  const [tag, payload] = pair(value, 'width');
  const kind = atomText(tag, 'width');
  if (typeof payload !== 'bigint') fail(`malformed width %${kind}`);
  if (kind === 'chars') return { kind, n: payload };
  if (kind === 'fill') return { kind, n: payload < 1n ? 1n : payload };
  fail(`unknown width %${kind}`);
}

// A width is a class; chars and fill carry their number inline, as the
// custom property the stylesheet reads along the axis the width is on.
function lengthParts(length) {
  if (length.kind === 'shrink') return { class: 'j-shrink', style: {} };
  if (length.kind === 'chars') return { class: 'j-chars', style: { '--j-chars': `${length.n}ch` } };
  return { class: 'j-fill', style: { '--j-fill': String(length.n) } };
}

function attributeParts(entry) {
  const [tag, payload] = pair(entry, 'attribute');
  const name = atomText(tag, 'attribute');
  if (name === 'pad' || name === 'gap') {
    const space = atomText(payload, name);
    if (!SPACES.has(space)) fail(`unknown ${name} %${space}`);
    return { name, class: `j-${name}-${space}` };
  }
  if (name === 'width') return { name, ...lengthParts(lengthOf(payload)) };
  if (name === 'align') {
    const align = atomText(payload, 'align');
    if (!['start', 'center', 'end'].includes(align)) fail(`unknown align %${align}`);
    return { name, class: `j-align-${align}` };
  }
  if (name === 'role') {
    const role = atomText(payload, 'role');
    if (!['body', 'caption', 'label'].includes(role)) fail(`unknown role %${role}`);
    return { name, class: `j-role-${role}` };
  }
  if (name === 'tone') {
    const tone = atomText(payload, 'tone');
    if (!TONES.has(tone)) fail(`unknown tone %${tone}`);
    return {
      name, class: `j-tone-${tone}`, plain: tone === 'danger' ? { 'aria-live': 'polite' } : {},
    };
  }
  fail(`unknown attribute %${name}`);
}

// An attribute's family is its tag. The last attribute of a family
// replaces all an earlier one gave, in the family's first place, as the
// server's build facade does.
export function decodeAttrs(raw, layoutClass) {
  const families = new Map();
  for (const entry of items(raw, 'attributes')) {
    const parts = attributeParts(entry);
    families.set(parts.name, parts);
  }
  const classes = layoutClass === undefined ? [] : [layoutClass];
  const attrs = { class: '' };
  const style = {};
  for (const parts of families.values()) {
    classes.push(parts.class);
    Object.assign(attrs, parts.plain);
    Object.assign(style, parts.style);
  }
  attrs.class = classes.join(' ');
  attrs.style = style;
  return attrs;
}

function layout(tag, rawAttrs, kids) {
  return element('div', decodeAttrs(rawAttrs, `j-${tag}`), kids);
}

// Without a page's paths, application paths stay bare, as in tests.
const BARE_PATHS = Object.freeze({ base: '', assets: undefined });

function pathParts(raw) {
  return items(raw, 'path').map(part => atomText(part, 'path'));
}

// An application path under the page's base, or a static file's hashed URL,
// as the server's links are.
function decodePath(raw, paths) {
  const parts = pathParts(raw);
  if (parts[0] === 'static' && paths.assets !== undefined) {
    const asset = paths.assets.get(`/${parts.join('/')}`);
    if (asset !== undefined) return asset.url;
  }
  if (parts.length === 0) return paths.base === '' ? '/' : paths.base;
  return `${paths.base}/${parts.map(part => encodeURIComponent(part)).join('/')}`;
}

// A table with a fill column spans its container, the fill columns sharing
// it by weight, and a shrink column's cells keep their content's width, as
// the renderer's table frame says.
function decodeTable(raw, paths) {
  const [rawColumns, rawRows] = pair(raw, 'table');
  const columns = items(rawColumns, 'table columns').map(column => {
    const [header, rest] = pair(column, 'table column');
    const [width, align] = pair(rest, 'table column');
    const alignment = atomText(align, 'table column align');
    if (!['start', 'center', 'end'].includes(alignment)) fail(`unknown align %${alignment}`);
    return { header: atomText(header, 'table header'), width: lengthOf(width), alignment };
  });
  const headings = columns.map(({ header, width, alignment }) => {
    const parts = lengthParts(width);
    return element('th', {
      class: parts.class,
      scope: 'col',
      style: { ...parts.style, 'text-align': alignment },
    }, [wordsFromString(header)]);
  });
  const shrinks = columns.map(({ width }) => width.kind === 'shrink');
  const head = element('thead', {}, [element('tr', {}, headings)]);
  const rows = items(rawRows, 'table rows').map(rawRow => {
    const [key, rawCells] = pair(rawRow, 'table row');
    const cells = items(rawCells, 'table cells').map((rawCell, index) => (
      element('td', shrinks[index] ? { class: 'j-shrink' } : {}, [toVnode(rawCell, paths)])
    ));
    return keyed(key, element('tr', {}, cells));
  });
  const fills = columns.reduce((total, { width }) => total + (width.kind === 'fill' ? width.n : 0n), 0n);
  const style = { 'border-collapse': 'collapse', 'max-width': '100%' };
  if (fills > 0n) Object.assign(style, { width: '100%', '--j-fills': String(fills) });
  return element('table', { style }, [head, element('tbody', {}, rows)]);
}

function wordsFromString(value) {
  return { kind: 'text', text: value };
}

// An element's tag, from its authenticated seal.
function elementTag(sealed) {
  const [rawTag] = pair(validateRawSeal(sealed), 'element');
  return atomText(rawTag, 'element tag');
}

/**
 * Decode one authentic sealed internal element into renderer-independent
 * vnodes. paths gives the page's base and its static files, by path.
 */
// Each element's vnode is made once for a page's paths, and kept on the
// element: a view that returns the same parts, as memoized gates do,
// returns the same vnodes, which the DOM patch passes over.
const VNODE = Symbol('jibb.vnode');

export function toVnode(sealed, paths = BARE_PATHS) {
  if (!Array.isArray(sealed)) return decode(sealed, paths);
  const kept = sealed[VNODE];
  if (kept !== undefined && kept.paths === paths) return kept.vnode;
  const vnode = decode(sealed, paths);
  if (Object.isExtensible(sealed)) sealed[VNODE] = { paths, vnode };
  return vnode;
}

function decode(sealed, paths) {
  const child = value => toVnode(value, paths);
  const raw = validateRawSeal(sealed);
  const [rawTag, payload] = pair(raw, 'element');
  const tag = atomText(rawTag, 'element tag');

  switch (tag) {
    case 'row':
    case 'column':
    case 'wrap':
    case 'stack': {
      const [attrs, children] = pair(payload, tag);
      return layout(tag, attrs, items(children, `${tag} children`).map(child));
    }
    case 'el': {
      const [attrs, inner] = pair(payload, 'el');
      return element('div', decodeAttrs(attrs, 'j-el'), [child(inner)]);
    }
    case 'para': {
      // A <p> holds only phrasing content; with any other child the server
      // renders the paragraph as a div styled as one.
      const kids = items(payload, 'para children');
      const children = kids.map(child);
      return kids.every(kid => PHRASING.has(elementTag(kid)))
        ? element('p', {}, children)
        : element('div', { class: 'j-para' }, children);
    }
    case 'text':
      return words(payload);
    case 'heading': {
      const [rawLevel, rawWords] = pair(payload, 'heading');
      const level = rawLevel < 1n ? 1 : rawLevel > 6n ? 6 : Number(rawLevel);
      return element(`h${level}`, { tabIndex: '-1' }, [words(rawWords)]);
    }
    case 'each': {
      const children = items(payload, 'each items').map(entry => {
        const [key, value] = pair(entry, 'each item');
        return keyed(key, child(value));
      });
      return element('div', {
        'data-each': '',
        style: { display: 'contents' },
      }, children);
    }
    case 'table':
      return decodeTable(payload, paths);
    case 'image': {
      const [source, description] = pair(payload, 'image');
      const alt = atomText(description, 'image description');
      if (paths.assets === undefined) {
        return element('img', { src: decodePath(source, paths), alt });
      }
      // A page's image is one of its desk's static files, as on the server,
      // where the stylesheet keeps it within its container.
      const at = `/${pathParts(source).join('/')}`;
      const asset = paths.assets.get(at);
      if (asset === undefined) fail(`missing static file ${at}`);
      const attrs = { src: asset.url, alt };
      if (asset.width !== undefined) {
        attrs.width = String(asset.width);
        attrs.height = String(asset.height);
      }
      return element('img', attrs);
    }
    case 'image-unsafe': {
      // The server's rule for unchecked URLs: anything else is drawn as its
      // description, never fetched.
      const [source, description] = pair(payload, 'image-unsafe');
      const [url, size] = pair(source, 'image-unsafe source');
      const [width, height] = pair(size, 'image-unsafe source');
      const src = atomText(url, 'image URL');
      const alt = atomText(description, 'image description');
      if (!safeUrl(src)) return wordsFromString(alt);
      return element('img', {
        src, alt, width: String(width), height: String(height),
      });
    }
    case 'link': {
      const [target, label] = pair(payload, tag);
      return element('a', { href: decodePath(target, paths) }, [words(label)]);
    }
    case 'link-unsafe': {
      // An unsafe link is drawn as its label, never followed; an https one
      // opens in a new tab without its opener, as on the server.
      const [target, label] = pair(payload, tag);
      const href = atomText(target, 'link target');
      if (!safeUrl(href)) return words(label);
      const attrs = { href };
      if (href.startsWith('https:')) Object.assign(attrs, { target: '_blank', rel: 'noopener' });
      return element('a', attrs, [words(label)]);
    }
    case 'button': {
      const [label, message] = pair(payload, 'button');
      return element('button', { type: 'button' }, [words(label)], {
        type: 'button', message,
      });
    }
    case 'toggle': {
      const [on, rest] = pair(payload, 'toggle');
      const [label, message] = pair(rest, 'toggle');
      const checked = requireLoobean(on);
      return element('input', {
        type: 'checkbox',
        'aria-label': atomText(label, 'toggle label'),
        checked,
      }, [], { type: 'toggle', message });
    }
    case 'field': {
      const [label, rest] = pair(payload, 'field');
      const [value, reply] = pair(rest, 'field');
      return element('input', {
        type: 'text',
        value: atomText(value, 'field value'),
        'aria-label': atomText(label, 'field label'),
      }, [], { type: 'field', reply });
    }
    case 'form': {
      const [message, children] = pair(payload, 'form');
      return element('div', {}, items(children, 'form children').map(child), {
        type: 'form', message,
      });
    }
    default:
      fail(`unsupported element %${tag}`);
  }
}
