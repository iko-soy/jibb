import {
  BASE58, FLOATS, UW, checkPad, check58, fein, fromFloat, taft, tuft,
} from '../core/aura.mjs';
import { rawDateUnpack } from './legacy.mjs';
import {
  CoreCrash,
  atomToBytes,
  bytesToAtom,
  requireLoobean,
  same,
} from '../core/runtime.mjs';
import {
  arrayToList,
  atom,
  cord,
  listToArray,
  loob,
  pair,
} from './helpers.mjs';
import { PREFIXES, SUFFIXES } from '../core/syllables.mjs';

const MAX_CODEPOINT = 0x10ffffn;
const MAX_U64 = 0xffff_ffff_ffff_ffffn;

function crash(operation, message) {
  throw new CoreCrash(`${operation}: ${message}`);
}

function atomPair(sample, operation) {
  const [left, right] = pair(sample, operation);
  return [atom(left, operation), atom(right, operation)];
}

function decodeUtf8(value, operation) {
  const bytes = atomToBytes(atom(value, operation));
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    crash(operation, 'invalid UTF-8 cord');
  }
}

function encodeCodepoints(codepoints) {
  let result = '';
  for (let offset = 0; offset < codepoints.length; offset += 1024) {
    result += String.fromCodePoint(...codepoints.slice(offset, offset + 1024));
  }
  return result;
}

function prefixedAtom(prefix, value, operation) {
  const first = new TextEncoder().encode(prefix);
  const rest = atomToBytes(atom(value, operation));
  const bytes = new Uint8Array(first.length + rest.length);
  bytes.set(first);
  bytes.set(rest, first.length);
  return bytesToAtom(bytes);
}

export function add(sample) {
  const [left, right] = atomPair(sample, 'add');
  return left + right;
}

export function sub(sample) {
  const [left, right] = atomPair(sample, 'sub');
  if (left < right) crash('sub', 'subtract underflow');
  return left - right;
}

export function mul(sample) {
  const [left, right] = atomPair(sample, 'mul');
  return left * right;
}

// [quotient remainder], crashing on a zero divisor as Hoon's +dvr does.
function divide(sample, label) {
  const [left, right] = atomPair(sample, label);
  if (right === 0n) crash(label, 'divide by zero');
  return [left / right, left % right];
}

export function dvr(sample) {
  return divide(sample, 'dvr');
}

export function div(sample) {
  return divide(sample, 'div')[0];
}

export function mod(sample) {
  return divide(sample, 'mod')[1];
}

export function pow(sample) {
  const [base, exponent] = atomPair(sample, 'pow');
  try {
    return base ** exponent;
  } catch {
    return crash('pow', 'power too large');
  }
}

export function inc(value) {
  return atom(value, 'inc') + 1n;
}

export function dec(value) {
  const current = atom(value, 'dec');
  if (current === 0n) crash('dec', 'decrement underflow');
  return current - 1n;
}

export function gth(sample) {
  const [left, right] = atomPair(sample, 'gth');
  return loob(left > right);
}

export function gte(sample) {
  const [left, right] = atomPair(sample, 'gte');
  return loob(left >= right);
}

export function lth(sample) {
  const [left, right] = atomPair(sample, 'lth');
  return loob(left < right);
}

export function lte(sample) {
  const [left, right] = atomPair(sample, 'lte');
  return loob(left <= right);
}

export function eq(sample) {
  const [left, right] = pair(sample, 'eq');
  return same(left, right);
}

export function not(value) {
  return requireLoobean(value) ? 1n : 0n;
}

export function max(sample) {
  const [left, right] = atomPair(sample, 'max');
  return left > right ? left : right;
}

export function min(sample) {
  const [left, right] = atomPair(sample, 'min');
  return left < right ? left : right;
}

// This is the composed Unicode codec: Hoon's tuba(trip value), rather than
// the prelude's separate byte-tape-to-codepoint-list arm named tuba.
export function trip(value) {
  const decoded = decodeUtf8(value, 'trip');
  return arrayToList(Array.from(decoded, character => BigInt(character.codePointAt(0))));
}

export function tuba(values) {
  const items = listToArray(values, 'tuba');
  const codepoints = items.map(item => {
    const codepoint = atom(item, 'tuba');
    if (codepoint > MAX_CODEPOINT || (codepoint >= 0xd800n && codepoint <= 0xdfffn)) {
      crash('tuba', `invalid Unicode scalar value ${codepoint}`);
    }
    return Number(codepoint);
  });
  return cord(encodeCodepoints(codepoints));
}

export function tripBytes(value) {
  return arrayToList([...atomToBytes(atom(value, 'trip'))].map(BigInt));
}

// Hoon's +crip is +rap 3: each element's bytes, as many as it has, so a
// zero has none and 256 has two.
function rap(values, operation) {
  const bytes = [];
  for (const value of listToArray(values, operation)) bytes.push(...atomToBytes(atom(value, operation)));
  return bytes;
}

export function cripBytes(values) {
  return bytesToAtom(new Uint8Array(rap(values, 'crip')));
}

// Hoon's +tuba, +taft of those bytes: surrogates and points past U+10FFFF
// read as Hoon reads them, and a control other than a line feed crashes.
export function tubaBytes(values) {
  return arrayToList(taft(rap(values, 'tuba')).map(BigInt));
}

// Hoon's +tufa, +tuft of each point: any 32-bit word encodes, and a zero
// encodes as nothing.
export function tufaCodepoints(values) {
  return arrayToList(listToArray(values, 'tufa').flatMap(value => tuft(atom(value, 'tufa'))).map(BigInt));
}

export function join(sample) {
  const [separator, values] = pair(sample, 'join');
  const between = atomToBytes(atom(separator, 'join'));
  const items = [];
  let length = 0;
  for (let rest = values; rest !== 0n;) {
    const [head, tail] = pair(rest, 'join');
    const bytes = atomToBytes(atom(head, 'join'));
    if (items.length !== 0) length += between.length;
    length += bytes.length;
    items.push(bytes);
    rest = tail;
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (let index = 0; index < items.length; index += 1) {
    if (index !== 0) {
      output.set(between, offset);
      offset += between.length;
    }
    output.set(items[index], offset);
    offset += items[index].length;
  }
  return bytesToAtom(output);
}

// ++co's printing, for the auras Jibb shows: Hoon's +rend picks the form
// by an aura's first two letters, and anything else is hexadecimal.

// ++ox-co: digits in groups of width, the first unpadded.
function grouped(value, radix, width) {
  const digits = radix === 64 ? base64(value) : value.toString(radix);
  let text = digits.slice(0, digits.length % width || width);
  for (let index = text.length; index < digits.length; index += width) text += `.${digits.slice(index, index + width)}`;
  return text;
}

function base64(value) {
  const bits = value.toString(2);
  const padded = bits.padStart(Math.ceil(bits.length / 6) * 6, '0');
  let text = '';
  for (let index = 0; index < padded.length; index += 6) text += UW[Number.parseInt(padded.slice(index, index + 6), 2)];
  return text;
}

function base58(value) {
  let text = '';
  for (let rest = value; text === '' || rest > 0n; rest /= 58n) text = BASE58[Number(rest % 58n)] + text;
  return text;
}

const two = value => String(value).padStart(2, '0');

// ++s-co: sub-second groups, from the most significant to the last nonzero.
function fraction(groups) {
  return groups.map(group => `.${group.toString(16).padStart(4, '0')}`).join('');
}

function words(value) {
  return value.toString(16).padStart(Math.ceil(value.toString(16).length / 4) * 4, '0');
}

// %p: a ship by +fein, words from the top, -- between groups of four
// counted from the bottom.
function ship(value) {
  const scrambled = fein(value);
  if (scrambled <= 0xffn) return `~${SUFFIXES[Number(scrambled)]}`;
  const hex = words(scrambled);
  let text = '';
  for (let imp = 0; imp < hex.length / 4; imp += 1) {
    const word = Number.parseInt(hex.slice(hex.length - 4 * imp - 4, hex.length - 4 * imp), 16);
    text = PREFIXES[word >> 8] + SUFFIXES[word & 0xff] + (imp === 0 ? '' : imp % 4 === 0 ? '--' : '-') + text;
  }
  return `~${text}`;
}

// %q: bytes from the bottom, a suffix then a prefix, words joined by -.
function phonemic(value) {
  const bytes = value === 0n ? [0] : [...atomToBytes(value)];
  let text = '';
  let suffix = true;
  for (const byte of bytes) {
    text = (suffix ? SUFFIXES[byte] : PREFIXES[byte]) + (suffix && text !== '' ? `-${text}` : text);
    suffix = !suffix;
  }
  return `.~${text}`;
}

// +wood: a cord as a knot, escaping by code point, +taft's way.
function wood(bytes) {
  return taft(bytes).map((point) => {
    if ((point >= 97 && point <= 122) || (point >= 48 && point <= 57) || point === 45) return String.fromCharCode(point);
    if (point === 32) return '.';
    if (point === 46) return '~.';
    if (point === 126) return '~~';
    return `~${point.toString(16)}.`;
  }).join('');
}

// %rd %rh %rq %rs: the shortest decimal, as ++r-co writes it.
function float(format, bits) {
  const number = fromFloat(format, bits);
  if (number.nan) return 'nan';
  if (number.infinite) return number.sign ? 'inf' : '-inf';
  const digits = String(number.digits);
  const scientific = number.exponent + digits.length - 1;
  let point;
  let exponent = 0;
  if (number.exponent >= 3 || scientific < -2) {
    point = 1;
    exponent = scientific;
  } else {
    point = scientific + 1;
  }
  let text;
  if (point <= 0) text = `0.${'0'.repeat(-point)}${digits}`;
  else if (point < digits.length) text = `${digits.slice(0, point)}.${digits.slice(point)}`;
  else text = digits + '0'.repeat(point - digits.length);
  return (number.sign ? '' : '-') + text + (exponent ? `e${exponent}` : '');
}

const IPV = { f: [8, 10, 4], s: [16, 16, 8] };

// +rend's text of an aura's atom; yed and hay are the aura's first letters.
function rend(yed, hay, value) {
  switch (yed) {
    case 'c':
      return `~-${wood(tuft(value))}`;
    case 'd':
      if (hay === 'a') return date(value);
      if (hay === 'r') return span(value);
      break;
    case 'f':
      if (value === 0n) return '.y';
      if (value === 1n) return '.n';
      break;
    case 'n':
      return '~';
    case 'i':
      if (IPV[hay]) {
        const [bits, radix, count] = IPV[hay];
        let text = '';
        for (let index = count - 1; index >= 0; index -= 1) {
          text += `.${((value >> BigInt(bits * index)) & ((1n << BigInt(bits)) - 1n)).toString(radix)}`;
        }
        return text;
      }
      break;
    case 'p':
      return ship(value);
    case 'q':
      return phonemic(value);
    case 'r': {
      const format = FLOATS[hay];
      if (format) return `.${'~'.repeat({ s: 0, d: 1, h: 2, q: 3 }[hay])}${float(format, value)}`;
      break;
    }
    case 'u':
      if (hay === 'c') return `0c${'1'.repeat(checkPad(value))}${base58((value << 32n) | check58(value))}`;
      if (value === 0n) return { b: '0b0', i: '0i0', x: '0x0', v: '0v0', w: '0w0' }[hay] ?? '0';
      switch (hay) {
        case 'b': return `0b${grouped(value, 2, 4)}`;
        case 'i': return `0i${value}`;
        case 'x': return `0x${grouped(value, 16, 4)}`;
        case 'v': return `0v${grouped(value, 32, 5)}`;
        case 'w': return `0w${grouped(value, 64, 5)}`;
        default: return grouped(value, 10, 3);
      }
    case 's':
      // @s is zigzag: even is positive.
      return (value & 1n ? '-' : '--') + rend('u', hay, (value + (value & 1n)) / 2n);
    case 't':
      return `~~${wood([...atomToBytes(value)])}`;
    default:
  }
  return `0x${value.toString(16)}`;
}

// %da: +yore's date, the month, day and time's parts in two digits, as
// the pinned ship's Hoon (%135) prints them (y-co), and its sub-second
// groups.
function date(value) {
  const [[ad, year], [month, [day, [hours, [minutes, [seconds, groups]]]]]] = rawDateUnpack(value);
  const sub = listToArray(groups);
  let text = `~${year}${ad === 1n ? '-' : ''}.${two(month)}.${two(day)}`;
  if (sub.length !== 0 || hours !== 0n || minutes !== 0n || seconds !== 0n) {
    text += `..${two(hours)}.${two(minutes)}.${two(seconds)}${sub.length ? `.${fraction(sub)}` : ''}`;
  }
  return text;
}

// %dr: days, hours, minutes and seconds that aren't zero, or s0.
function span(value) {
  const groups = [];
  for (let low = value & MAX_U64, shift = 48n; low !== 0n; shift -= 16n) {
    groups.push((low >> shift) & 0xffffn);
    low &= (1n << shift) - 1n;
  }
  let seconds = value >> 64n;
  const parts = [];
  for (const [unit, size] of [['d', 86_400n], ['h', 3_600n], ['m', 60n], ['s', 1n]]) {
    const count = seconds / size;
    seconds %= size;
    if (count !== 0n) parts.push(`${unit}${count}`);
  }
  return `~${parts.length ? parts.join('.') : 's0'}${groups.length ? `.${fraction(groups)}` : ''}`;
}

export function formatUd(value) {
  return scot([cord('ud'), value]);
}

export function formatUx(value) {
  return scot([cord('ux'), value]);
}

export function formatUv(value) {
  return scot([cord('uv'), value]);
}

export function formatTas(value) {
  return atom(value, 'formatTas');
}

export function formatT(value) {
  return scot([cord('t'), value]);
}

export function formatTa(value) {
  return prefixedAtom('~.', value, 'formatTa');
}

export function formatP(value) {
  return cord(ship(atom(value, 'formatP')));
}

export function formatDa(value) {
  return cord(date(atom(value, 'formatDa')));
}

export function formatDr(value) {
  return cord(span(atom(value, 'formatDr')));
}

// Hoon's +scot of any aura. A knot, %ta, and a term, %tas, keep their
// bytes as they are.
export function scot(sample) {
  const [aura, value] = pair(sample, 'scot');
  const [yed, hay, third] = [...atomToBytes(atom(aura, 'scot'))].map(code => String.fromCharCode(code));
  atom(value, 'scot');
  if (yed === 't' && hay === 'a') return third === 's' ? value : prefixedAtom('~.', value, 'scot');
  return cord(rend(yed, hay, value));
}

export function scow(sample) {
  return tripBytes(scot(sample));
}
