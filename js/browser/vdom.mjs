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

function atomText(value, operation) {
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

function keyed(key, vnode) {
  return { ...vnode, key };
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
  const [tag, payload] = pair(value, 'width');
  const name = atomText(tag, 'width');
  if (name === 'chars') {
    style.flex = `0 0 ${payload}ch`;
    return;
  }
  if (name === 'fill') {
    const weight = payload < 1n ? 1n : payload;
    style.flex = `${weight} 1 0%`;
    style.minWidth = '0';
    return;
  }
  fail(`unknown width %${name}`);
}

// One class per family, the last of each winning in the family's first
// place, as the server's serializer does.
function decodeAttrs(raw, layoutClass) {
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

function decodePath(raw) {
  const path = items(raw, 'path').map(part => encodeURIComponent(atomText(part, 'path')));
  return `/${path.join('/')}`;
}

function decodeLengthAttribute(raw) {
  return lengthStyle(raw);
}

function decodeTable(raw) {
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
      element('td', {}, [toVnode(rawCell)])
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

/** Decode one authentic sealed internal element into renderer-independent vnodes. */
export function toVnode(sealed) {
  const raw = validateRawSeal(sealed);
  const [rawTag, payload] = pair(raw, 'element');
  const tag = atomText(rawTag, 'element tag');

  switch (tag) {
    case 'row':
    case 'column':
    case 'wrap':
    case 'stack': {
      const [attrs, children] = pair(payload, tag);
      return layout(tag, attrs, items(children, `${tag} children`).map(toVnode));
    }
    case 'el': {
      const [attrs, child] = pair(payload, 'el');
      return element('div', decodeAttrs(attrs, 'j-el'), [toVnode(child)]);
    }
    case 'para':
      return element('p', {}, items(payload, 'para children').map(toVnode));
    case 'text':
      return words(payload);
    case 'heading': {
      const [rawLevel, rawWords] = pair(payload, 'heading');
      const level = rawLevel < 1n ? 1 : rawLevel > 6n ? 6 : Number(rawLevel);
      return element(`h${level}`, { tabIndex: '-1' }, [words(rawWords)]);
    }
    case 'each': {
      const children = items(payload, 'each items').map(entry => {
        const [key, child] = pair(entry, 'each item');
        return keyed(key, toVnode(child));
      });
      return element('div', {
        'data-each': '',
        style: { display: 'contents' },
      }, children);
    }
    case 'table':
      return decodeTable(payload);
    case 'image': {
      const [source, description] = pair(payload, 'image');
      return element('img', {
        src: decodePath(source),
        alt: atomText(description, 'image description'),
        style: { maxWidth: '100%' },
      });
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
        href: tag === 'link' ? decodePath(target) : atomText(target, 'link target'),
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
      return element('form', {}, items(children, 'form children').map(toVnode), {
        type: 'form', message,
      });
    }
    default:
      fail(`unsupported element %${tag}`);
  }
}
