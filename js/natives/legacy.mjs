import { civilFromDays, monthLengths } from '../core/calendar.mjs';
import { readShip } from '../core/literal.mjs';
import {
  CoreCrash,
  atomToBytes,
  bytesToAtom,
  requireLoobean,
} from '../core/runtime.mjs';
import {
  arrayToList,
  atom,
  cord,
  listToArray,
  pair,
} from './helpers.mjs';

const DATE_OFFSET = 292_277_024_400n;
const MAX_U64 = 0xffff_ffff_ffff_ffffn;
const SEAL_TAG = cord('jibb.private.seal.v1');
// A seal's provenance is a module-private symbol on its own cell, cheaper to
// set than a WeakSet entry; a copied cell, or one cued from a server, has none.
const SEALED = Symbol('jibb.sealed');

function crash(operation, message) {
  throw new CoreCrash(`${operation}: ${message}`);
}

// Hoon +yawn. Years are absolute proleptic-Gregorian years, with year zero
// preceding AD 1 at DATE_OFFSET. Days and months are one-based; an excessive
// day deliberately carries into later months, just as it does in Hoon.
function daysFromCivil(year, month, day, operation) {
  if (month === 0n || day === 0n) crash(operation, 'month and day are one-based');
  if (month > 12n) crash(operation, 'month is greater than 12');

  let days = year === 0n
    ? 0n
    : year * 365n + (year - 1n) / 4n + 1n - ((year - 1n) / 100n + 1n)
      + ((year - 1n) / 400n + 1n);
  const lengths = monthLengths(year);
  for (let index = 1n; index < month; index += 1n) {
    days += lengths[Number(index - 1n)];
  }
  return days + day - 1n;
}

function packFraction(items, operation) {
  if (items.length > 4) crash(operation, 'more than four fractional groups');
  let result = 0n;
  for (let index = 0; index < items.length; index += 1) {
    const shift = 16n * BigInt(3 - index);
    result += atom(items[index], operation) << shift;
  }
  return result;
}

export function rawDatePack(value) {
  const operation = 'rawDatePack';
  const [era, dateRest] = pair(value, operation);
  const [flag, yearValue] = pair(era, operation);
  const [monthValue, tarp] = pair(dateRest, operation);
  const [dayValue, dayRest] = pair(tarp, operation);
  const [hourValue, hourRest] = pair(dayRest, operation);
  const [minuteValue, minuteRest] = pair(hourRest, operation);
  const [secondValue, fractionValue] = pair(minuteRest, operation);

  const ad = requireLoobean(flag);
  const displayYear = atom(yearValue, operation);
  if (!ad && displayYear === 0n) crash(operation, 'BC year zero');
  const year = ad ? DATE_OFFSET + displayYear : DATE_OFFSET - (displayYear - 1n);
  if (year < 0n) crash(operation, 'BC year precedes the atom epoch');

  const month = atom(monthValue, operation);
  const day = atom(dayValue, operation);
  const days = daysFromCivil(year, month, day, operation);
  const seconds = days * 86_400n
    + atom(hourValue, operation) * 3_600n
    + atom(minuteValue, operation) * 60n
    + atom(secondValue, operation);
  const fractions = packFraction(listToArray(fractionValue, operation), operation);
  // Hoon +yule adds fraction words, then uses con with the shifted seconds.
  // Both distinctions are observable for out-of-range fraction words.
  return (seconds << 64n) | fractions;
}

export function rawDateUnpack(value) {
  const operation = 'rawDateUnpack';
  const current = atom(value, operation);
  let rawFraction = current & MAX_U64;
  let seconds = current >> 64n;
  const days = seconds / 86_400n;
  seconds %= 86_400n;
  const hours = seconds / 3_600n;
  const minutes = seconds % 3_600n / 60n;
  const remainder = seconds % 60n;
  const [year, month, day] = civilFromDays(days);
  const ad = year > DATE_OFFSET;
  const displayYear = ad ? year - DATE_OFFSET : DATE_OFFSET + 1n - year;

  // Hoon +yell emits the most-significant nonzero group first, retaining any
  // zero groups below it. Four 16-bit groups cover the complete low 64 bits.
  const fractions = [];
  for (let muc = 4n; rawFraction !== 0n && muc !== 0n;) {
    muc -= 1n;
    fractions.push((rawFraction >> (16n * muc)) & 0xffffn);
    rawFraction &= (1n << (16n * muc)) - 1n;
  }

  return [
    [ad ? 0n : 1n, displayYear],
    [month, [day, [hours, [minutes, [remainder, arrayToList(fractions)]]]]],
  ];
}

function decodeCord(value) {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(atomToBytes(value));
  } catch {
    return undefined;
  }
}

function parseGroupedDigits(source, radix, firstWidth, laterWidth, digits) {
  const groups = source.split('.');
  if (groups.length === 0 || groups[0].length < 1 || groups[0].length > firstWidth) {
    return undefined;
  }
  if (!/^[1-9a-f]/.test(groups[0]) && radix === 16) return undefined;
  if (!/^[1-9a-v]/.test(groups[0]) && radix === 32) return undefined;
  if (radix === 10 && !/^[1-9]/.test(groups[0])) return undefined;
  if (groups.slice(1).some(group => group.length !== laterWidth)) return undefined;

  const expression = new RegExp(`^[${digits}]+$`);
  if (groups.some(group => !expression.test(group))) return undefined;
  let result = 0n;
  for (const group of groups) {
    for (const character of group) {
      const digit = Number.parseInt(character, radix);
      result = result * BigInt(radix) + BigInt(digit);
    }
  }
  return result;
}

function parseDecimal(source) {
  if (source === '0') return 0n;
  return parseGroupedDigits(source, 10, 3, 3, '0-9');
}

function parseHexadecimal(source) {
  if (source === '0') return 0n;
  return parseGroupedDigits(source, 16, 4, 4, '0-9a-fA-F');
}

function parseBase32(source) {
  if (source === '0') return 0n;
  return parseGroupedDigits(source, 32, 5, 5, '0-9a-v');
}

function parseFractionGroups(source) {
  const groups = source.split('.');
  if (groups.length > 4 || groups.some(group => !/^[0-9a-f]{4}$/.test(group))) {
    return undefined;
  }
  return groups.map(group => BigInt(`0x${group}`));
}

function parseDate(source) {
  const match = /^~([0-9]+)(-?)\.([0-9]+)\.([0-9]+)(?:\.\.([0-9]+)\.([0-9]+)\.([0-9]+)(?:\.\.([0-9a-f]{4}(?:\.[0-9a-f]{4})*))?)?$/.exec(source);
  if (!match) return undefined;
  const [, yearText, bc, monthText, dayText, hour = '0', minute = '0', second = '0', fractionText] = match;
  if (!/^(?:0|[1-9][0-9]*)$/.test(yearText)) return undefined;
  if (!/^(?:0?[1-9]|1[0-2])$/.test(monthText)) return undefined;
  if (!/^(?:0?[1-9]|[1-9][0-9]*)$/.test(dayText)) return undefined;
  const fractions = fractionText === undefined ? [] : parseFractionGroups(fractionText);
  if (fractions === undefined) return undefined;

  return rawDatePack([
    [bc === '-' ? 1n : 0n, BigInt(yearText)],
    [BigInt(monthText), [BigInt(dayText), [BigInt(hour), [BigInt(minute), [BigInt(second), arrayToList(fractions)]]]]],
  ]);
}

function parseDuration(source) {
  if (!source.startsWith('~')) return undefined;
  const sections = source.slice(1).split('..');
  if (sections.length < 1 || sections.length > 2) return undefined;
  const components = sections[0].split('.');
  const units = { d: 86_400n, h: 3_600n, m: 60n, s: 1n };
  let seconds = 0n;
  for (const component of components) {
    const match = /^([dhms])(0|[1-9][0-9]*)$/.exec(component);
    if (!match) return undefined;
    seconds += BigInt(match[2]) * units[match[1]];
  }
  const fractions = sections.length === 1 ? [] : parseFractionGroups(sections[1]);
  if (fractions === undefined) return undefined;
  return (seconds << 64n) | packFraction(fractions, 'rawParseAtom');
}

function parseCord(source) {
  if (!source.startsWith('~~')) return undefined;
  const bytes = [];
  const body = source.slice(2);
  for (let index = 0; index < body.length;) {
    const character = body[index];
    if (/^[a-z0-9_-]$/.test(character)) {
      bytes.push(character.charCodeAt(0));
      index += 1;
      continue;
    }
    if (character === '.') {
      bytes.push(32);
      index += 1;
      continue;
    }
    if (character !== '~') return undefined;
    if (body[index + 1] === '~' || body[index + 1] === '.') {
      bytes.push(body.charCodeAt(index + 1));
      index += 2;
      continue;
    }

    // +urx uses the plain 4i hex rule here, not the grouped @ux rule:
    // leading zeroes and arbitrary widths are accepted, and the first dot
    // terminates the escape.
    const escape = /^~([0-9a-fA-F]+)\./.exec(body.slice(index));
    if (!escape) return undefined;
    const codepoint = BigInt(`0x${escape[1]}`);
    if (codepoint === undefined || codepoint > 0x10ffffn
      || (codepoint >= 0xd800n && codepoint <= 0xdfffn)) return undefined;
    bytes.push(...new TextEncoder().encode(String.fromCodePoint(Number(codepoint))));
    index += escape[0].length;
  }
  return bytesToAtom(new Uint8Array(bytes));
}

function parseAura(aura, source) {
  switch (aura) {
    case 'ud': return parseDecimal(source);
    case 'ux': return source.startsWith('0x') ? parseHexadecimal(source.slice(2)) : undefined;
    case 'uv': return source.startsWith('0v') ? parseBase32(source.slice(2)) : undefined;
    case 'tas':
      return /^[a-z][a-z0-9-]*$/.test(source) ? cord(source) : undefined;
    case 'ta':
      return source.startsWith('~.') && /^[a-z0-9._~-]*$/.test(source.slice(2))
        ? cord(source.slice(2)) : undefined;
    case 'p': {
      if (!source.startsWith('~')) return undefined;
      return readShip(source).value;
    }
    case 'da': return parseDate(source);
    case 'dr': return parseDuration(source);
    case 't': return parseCord(source);
    default: return undefined;
  }
}

export function rawParseAtom(sample) {
  const operation = 'rawParseAtom';
  const [auraValue, textValue] = pair(sample, operation);
  const aura = decodeCord(atom(auraValue, operation));
  const source = decodeCord(atom(textValue, operation));
  if (aura === undefined || source === undefined) return [1n, 0n];

  try {
    const value = parseAura(aura, source);
    return value === undefined ? [1n, 0n] : [0n, value];
  } catch (error) {
    // Text is a total boundary even where Hoon's +year would crash on a
    // parse-shaped BC year zero or a fifth fractional group. ABI failures
    // above remain CoreCrash exceptions and are never converted to invalid text.
    if (error instanceof CoreCrash || error instanceof SyntaxError) return [1n, 0n];
    throw error;
  }
}

export function rawBitNot(sample) {
  const operation = 'rawBitNot';
  const [bloqValue, rest] = pair(sample, operation);
  const [countValue, atomValue] = pair(rest, operation);
  const bloq = atom(bloqValue, operation);
  const count = atom(countValue, operation);
  const value = atom(atomValue, operation);
  // Hoon +not is xor with count * 2^bloq low one-bits. In particular, count
  // zero leaves the atom unchanged; bloq zero counts bits, not bytes.
  const width = count * (1n << bloq);
  return value ^ ((1n << width) - 1n);
}

// Opaque Jibb values still use the ordinary Core noun/cell ABI. The wrapper is
// only a representation: compile-time privacy is the language boundary. Local
// provenance additionally lets JS consumers reject raw and copied lookalikes.
export function rawSeal(value) {
  const sealed = [SEAL_TAG, value];
  sealed[SEALED] = true;
  return sealed;
}

export function isRawSeal(value) {
  return Array.isArray(value) && value.length === 2 && value[0] === SEAL_TAG
    && value[SEALED] === true;
}

export function validateRawSeal(value) {
  if (!isRawSeal(value)) crash('validateRawSeal', 'expected a value produced by rawSeal');
  return value[1];
}
