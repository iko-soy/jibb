import { CoreCrash } from './runtime.mjs';
import { nuck } from './aura.mjs';

const TERM = /^%(?:[a-z][a-z0-9-]*|[&|$])$/;
// The auras a Core literal may have, as jibb-core.hoon's +literal-aura.
const AURAS = new Map([
  ['ud', '@ud'], ['ux', '@ux'], ['uv', '@uv'], ['p', '@p'], ['da', '@da'], ['dr', '@dr'], ['ta', 'knot'], ['n', 'null'],
]);

function fail(text, reason = 'invalid literal') {
  throw new SyntaxError(`${reason}: ${JSON.stringify(text)}`);
}

function result(text, value, aura) {
  return { value, aura, text };
}

function cord(bytes) {
  let value = 0n;
  for (let index = bytes.length - 1; index >= 0; index -= 1) {
    value = (value << 8n) | BigInt(bytes[index]);
  }
  return value;
}

function asciiCord(text) {
  return cord(Array.from(text, character => character.charCodeAt(0)));
}

function wellFormed(text) {
  for (let index = 0; index < text.length; index += 1) {
    const code = text.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = text.charCodeAt(index + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) return false;
      index += 1;
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return false;
    }
  }
  return true;
}

function readString(text) {
  if (text.length < 2 || !text.startsWith('"') || !text.endsWith('"') || !wellFormed(text)) {
    fail(text, 'invalid string literal');
  }

  const inner = text.slice(1, -1);
  const bytes = [];
  let raw = '';
  const flush = () => {
    if (raw !== '') {
      for (const byte of new TextEncoder().encode(raw)) bytes.push(byte);
    }
    raw = '';
  };

  for (let index = 0; index < inner.length;) {
    const character = inner[index];
    const code = inner.charCodeAt(index);
    if (character === '{') fail(text, 'interpolated strings are not literals');
    if (character === '"') fail(text, 'unescaped quote in string literal');
    if (code <= 31 || code === 127) fail(text, 'unescaped control character in string literal');

    if (character !== '\\') {
      raw += character;
      index += 1;
      continue;
    }

    flush();
    const escaped = inner[index + 1];
    if (escaped === '"' || escaped === '{' || escaped === '\\') {
      bytes.push(escaped.charCodeAt(0));
      index += 2;
      continue;
    }
    const hexadecimal = inner.slice(index + 1, index + 3);
    if (!/^[0-9a-f]{2}$/.test(hexadecimal)) {
      fail(text, 'invalid string escape (expected \", \\{, \\\\, or two lowercase hex digits)');
    }
    bytes.push(Number.parseInt(hexadecimal, 16));
    index += 3;
  }
  flush();
  return result(text, cord(bytes), '@t');
}

function readTerm(text) {
  if (text === '%.y' || text === '%.n') {
    return result(text, text === '%.y' ? 0n : 1n, '?');
  }
  if (text === '%&' || text === '%$' || text === '%0') return result(text, 0n, '@tas');
  if (text === '%|') return result(text, 1n, '@tas');

  // A numeric term is % and a decimal, as Hoon reads it.
  const body = text.slice(1);
  if (/^[0-9]/.test(body)) {
    const number = body[0] === '0' ? undefined : read(body);
    if (number?.aura !== 'ud') fail(text, 'invalid term literal');
    return result(text, number.value, '@tas');
  }
  if (!TERM.test(text)) fail(text, 'invalid term literal');
  return result(text, asciiCord(body), '@tas');
}

// Hoon's ++nuck of the whole text, as jibb-core.hoon's +read-literal reads
// it: a literal Hoon can't read, or reads only by crashing, is invalid.
function read(text) {
  try {
    return nuck(text);
  } catch (error) {
    if (error instanceof CoreCrash) return undefined;
    throw error;
  }
}

// A ship's name, read as Hoon's ++fed:ag reads it.
export function readShip(text) {
  const parsed = read(text);
  if (parsed?.aura !== 'p') fail(text, 'invalid ship');
  return result(text, parsed.value, '@p');
}

export function readLiteral(text) {
  if (typeof text !== 'string') throw new SyntaxError(`literal must be a string, received ${typeof text}`);
  if (text.startsWith('"')) return readString(text);
  if (text.startsWith('%')) return readTerm(text);
  const parsed = /^[0-9~]/.test(text) ? read(text) : undefined;
  if (parsed === undefined) fail(text);
  if (!AURAS.has(parsed.aura)) fail(text, `unsupported literal aura @${parsed.aura}`);
  return result(text, parsed.value, AURAS.get(parsed.aura));
}
