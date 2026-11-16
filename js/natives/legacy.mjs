import { civilFromDays } from '../core/calendar.mjs';
import { DATE_OFFSET, slaw, year as packDate } from '../core/aura.mjs';
import {
  CoreCrash,
  atomToBytes,
  requireLoobean,
} from '../core/runtime.mjs';
import {
  arrayToList,
  atom,
  cord,
  listToArray,
  pair,
} from './helpers.mjs';

const MAX_U64 = 0xffff_ffff_ffff_ffffn;
const SEAL_TAG = cord('jibb.private.seal.v1');
// A seal's provenance is a module-private symbol on its own cell, cheaper to
// set than a WeakSet entry; a copied cell, or one cued from a server, has none.
const SEALED = Symbol('jibb.sealed');

function crash(operation, message) {
  throw new CoreCrash(`${operation}: ${message}`);
}

// Hoon's +year: day and month past their ends carry on, month 13 into the
// next year, and it crashes where Hoon's does (month 0 or past 13, day 0,
// a BC year 0, a fifth sub-second group).
export function rawDatePack(value) {
  const operation = 'rawDatePack';
  const [era, dateRest] = pair(value, operation);
  const [flag, yearValue] = pair(era, operation);
  const [monthValue, tarp] = pair(dateRest, operation);
  const [dayValue, dayRest] = pair(tarp, operation);
  const [hourValue, hourRest] = pair(dayRest, operation);
  const [minuteValue, minuteRest] = pair(hourRest, operation);
  const [secondValue, fractionValue] = pair(minuteRest, operation);
  return packDate(
    requireLoobean(flag),
    atom(yearValue, operation),
    atom(monthValue, operation),
    atom(dayValue, operation),
    atom(hourValue, operation),
    atom(minuteValue, operation),
    atom(secondValue, operation),
    listToArray(fractionValue, operation).map(group => atom(group, operation)),
  );
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

// Hoon's +slaw under mule, as the ship runs it: [%.y value], or [%.n 0]
// for text that doesn't parse or whose parse crashes.
export function rawParseAtom(sample) {
  const operation = 'rawParseAtom';
  const [auraValue, textValue] = pair(sample, operation);
  const aura = decodeCord(atom(auraValue, operation));
  const source = decodeCord(atom(textValue, operation));
  if (aura === undefined || source === undefined) return [1n, 0n];
  try {
    const value = slaw(aura, source);
    return value === undefined ? [1n, 0n] : [0n, value];
  } catch (error) {
    if (error instanceof CoreCrash) return [1n, 0n];
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

export function restoreSealedModel(value) {
  const seen = new Set();
  const pending = [value];
  while (pending.length !== 0) {
    const current = pending.pop();
    if (!Array.isArray(current) || seen.has(current)) continue;
    seen.add(current);
    if (current.length === 2 && current[0] === SEAL_TAG) current[SEALED] = true;
    pending.push(current[0], current[1]);
  }
  return value;
}

export function isRawSeal(value) {
  return Array.isArray(value) && value.length === 2 && value[0] === SEAL_TAG
    && value[SEALED] === true;
}

export function validateRawSeal(value) {
  if (!isRawSeal(value)) crash('validateRawSeal', 'expected a value produced by rawSeal');
  return value[1];
}
