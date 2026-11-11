import { CoreCrash, requireLoobean } from '../core/runtime.mjs';
import { cell, listToArray, text } from '../natives/helpers.mjs';
import { validateRawSeal } from '../natives/legacy.mjs';

// Style attributes are the theme stylesheet's atomic classes, as the server
// renders them, so the browser needs no theme tokens of its own.
const SPACES = new Set(['s0', 's1', 's2', 's3']);
const TONES = new Set(['normal', 'muted', 'accent', 'danger']);

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

function lengthStyle(value) {
  if (typeof value === 'bigint') {
    if (atomText(value, 'width') !== 'shrink') fail('unknown width');
    return { flex: '0 0 auto', width: 'auto' };
  }
  const [tag, payload] = pair(value, 'width');
  const name = atomText(tag, 'width');
  if (name === 'chars') return { flex: `0 0 ${payload}ch` };
  if (name === 'fill') {
    const weight = payload < 1n ? 1n : payload;
    return { flex: `${weight} 1 0%`, minWidth: '0' };
  }
  fail(`unknown width %${name}`);
}

// A width is a class, except chars and fill, which stay inline.
function lengthAttrs(value, classes, style) {
  if (typeof value === 'bigint') {
    if (atomText(value, 'width') !== 'shrink') fail('unknown width');
    classes.set('width', 'j-shrink');
    return;
  }
  Object.assign(style, lengthStyle(value));
}

// One class per family, the last of each winning in the family's first
// place, as the server's serializer does.
export function decodeAttrs(raw, layoutClass) {
  const classes = new Map();
  if (layoutClass !== undefined) classes.set('layout', layoutClass);
  const style = {};
  const attrs = { style };
  for (const entry of items(raw, 'attributes')) {
    const [tag, payload] = pair(entry, 'attribute');
    const name = atomText(tag, 'attribute');
    if (name === 'pad' || name === 'gap') {
      const space = atomText(payload, name);
      if (!SPACES.has(space)) fail(`unknown ${name} %${space}`);
      classes.set(name, `j-${name}-${space}`);
    } else if (name === 'width') {
      lengthAttrs(payload, classes, style);
    } else if (name === 'align') {
      const align = atomText(payload, 'align');
      if (!['start', 'center', 'end'].includes(align)) fail(`unknown align %${align}`);
      classes.set('align', `j-align-${align}`);
    } else if (name === 'role') {
      const role = atomText(payload, 'role');
      if (!['body', 'caption', 'label'].includes(role)) fail(`unknown role %${role}`);
      classes.set('role', `j-role-${role}`);
    } else if (name === 'tone') {
      const tone = atomText(payload, 'tone');
      if (!TONES.has(tone)) fail(`unknown tone %${tone}`);
      classes.set('tone', `j-tone-${tone}`);
      if (tone === 'danger') attrs['aria-live'] = 'polite';
    } else {
      fail(`unknown attribute %${name}`);
    }
  }
  if (classes.size) attrs.class = [...classes.values()].join(' ');
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

function decodeLengthAttribute(raw) {
  return lengthStyle(raw);
}

function decodeTable(raw, paths) {
  const [rawColumns, rawRows] = pair(raw, 'table');
  const columns = items(rawColumns, 'table columns').map(column => {
    const [header, rest] = pair(column, 'table column');
    const [width, align] = pair(rest, 'table column');
    const alignment = atomText(align, 'table column align');
    if (!['start', 'center', 'end'].includes(alignment)) fail(`unknown align %${alignment}`);
    return {
      header: atomText(header, 'table header'),
      style: {
        ...decodeLengthAttribute(width),
        textAlign: alignment,
      },
    };
  });
  const headings = columns.map(column => element('th', {
    scope: 'col',
    style: column.style,
  }, [wordsFromString(column.header)]));
  const head = element('thead', {}, [element('tr', {}, headings)]);
  const rows = items(rawRows, 'table rows').map(rawRow => {
    const [key, rawCells] = pair(rawRow, 'table row');
    const cells = items(rawCells, 'table cells').map(rawCell => (
      element('td', {}, [toVnode(rawCell, paths)])
    ));
    return keyed(key, element('tr', {}, cells));
  });
  return element('table', {
    style: { borderCollapse: 'collapse', maxWidth: '100%' },
  }, [head, element('tbody', {}, rows)]);
}

function wordsFromString(value) {
  return { kind: 'text', text: value };
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
    case 'para':
      return element('p', {}, items(payload, 'para children').map(child));
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
        return element('img', { src: decodePath(source, paths), alt, style: { maxWidth: '100%' } });
      }
      // A page's image is one of its desk's static files, as on the server.
      const at = `/${pathParts(source).join('/')}`;
      const asset = paths.assets.get(at);
      if (asset === undefined) fail(`missing static file ${at}`);
      const attrs = { src: asset.url, alt, style: { maxWidth: '100%' } };
      if (asset.width !== undefined) {
        attrs.width = String(asset.width);
        attrs.height = String(asset.height);
      }
      return element('img', attrs);
    }
    case 'image-unsafe': {
      const [source, description] = pair(payload, 'image-unsafe');
      const [url, size] = pair(source, 'image-unsafe source');
      const [width, height] = pair(size, 'image-unsafe source');
      return element('img', {
        src: atomText(url, 'image URL'),
        alt: atomText(description, 'image description'),
        width: String(width),
        height: String(height),
        style: {
          maxWidth: '100%',
          aspectRatio: `${width} / ${height}`,
        },
      });
    }
    case 'link':
    case 'link-unsafe': {
      const [target, label] = pair(payload, tag);
      return element('a', {
        href: tag === 'link' ? decodePath(target, paths) : atomText(target, 'link target'),
      }, [words(label)]);
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
      return element('input', {
        type: 'checkbox',
        checked: requireLoobean(on),
        'aria-label': atomText(label, 'toggle label'),
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
      return element('form', {}, items(children, 'form children').map(child), {
        type: 'form', message,
      });
    }
    default:
      fail(`unsupported element %${tag}`);
  }
}
