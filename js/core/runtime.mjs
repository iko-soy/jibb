// Runtime primitives for Jibb Core. Atoms are unsigned BigInts and cells are
// two-element arrays. Functions are Core values, but are never valid nouns.

export class CoreCrash extends Error {
  constructor(message = 'Core crash') {
    super(message);
    this.name = 'CoreCrash';
  }
}

export function crash(message = 'Core crash') {
  if (typeof message !== 'string') {
    throw new CoreCrash('Crash message must be a string');
  }
  throw new CoreCrash(message);
}

function fail(message) {
  throw new CoreCrash(message);
}

function assertAtom(value, operation) {
  if (typeof value !== 'bigint') {
    fail(`${operation}: expected an atom (BigInt)`);
  }
  if (value < 0n) {
    fail(`${operation}: atoms cannot be negative`);
  }
  return value;
}

// Each operation checks its operands one level deep: an atom is a
// nonnegative BigInt, and a cell a two-element array whose head and tail are
// each an atom, a function or another two-element array. Every cell a Core
// program makes comes from cons or edit, so cells stay well formed
// throughout, and no operation costs more than the part of a noun it reads.
// same and collection boundaries read whole values. Keys and compared nouns
// disallow functions; map values permit them. The explicit stack handles deep
// nouns; the two sets distinguish shared structure (valid) from cycles.
export function validateValue(value, operation, allowFunctions = false) {
  const active = new Set();
  const complete = new Set();
  const stack = [{ value, exit: false }];

  while (stack.length !== 0) {
    const frame = stack.pop();
    const current = frame.value;

    if (typeof current === 'bigint') {
      assertAtom(current, operation);
      continue;
    }

    if (typeof current === 'function') {
      if (allowFunctions) continue;
      fail(`${operation}: functions are not nouns`);
    }

    if (!Array.isArray(current) || current.length !== 2) {
      fail(`${operation}: expected an atom or a two-element cell`);
    }

    if (complete.has(current)) {
      continue;
    }

    if (frame.exit) {
      active.delete(current);
      complete.add(current);
      continue;
    }

    if (active.has(current)) {
      fail(`${operation}: cyclic cells are not nouns`);
    }

    active.add(current);
    stack.push(
      { value: current, exit: true },
      { value: current[1], exit: false },
      { value: current[0], exit: false },
    );
  }

  return value;
}

function assertPart(part, operation) {
  if (typeof part === 'bigint') {
    assertAtom(part, operation);
  } else if (typeof part !== 'function' && (!Array.isArray(part) || part.length !== 2)) {
    fail(`${operation}: expected an atom or a two-element cell`);
  }
}

function assertValue(value, operation) {
  if (typeof value === 'bigint') return assertAtom(value, operation);
  if (typeof value === 'function') return value;
  if (!Array.isArray(value) || value.length !== 2) {
    fail(`${operation}: expected an atom or a two-element cell`);
  }
  assertPart(value[0], operation);
  assertPart(value[1], operation);
  return value;
}

export function cons(head, tail) {
  assertValue(head, 'cons head');
  assertValue(tail, 'cons tail');
  return [head, tail];
}

export function isCell(value) {
  if (typeof value === 'function') {
    fail('cell?: functions are not nouns');
  }
  assertValue(value, 'cell?');
  return Array.isArray(value) ? 0n : 1n;
}

export function same(left, right) {
  validateValue(left, 'eq left');
  validateValue(right, 'eq right');
  return equalNouns(left, right) ? 0n : 1n;
}

// Both operands have passed validateValue with functions disallowed.
export function equalNouns(left, right) {
  const pending = [[left, right]];
  while (pending.length !== 0) {
    const [a, b] = pending.pop();

    if (a === b) {
      continue;
    }
    if (typeof a === 'bigint' || typeof b === 'bigint') {
      return false;
    }

    pending.push([a[0], b[0]], [a[1], b[1]]);
  }

  return true;
}

function normalizeAxis(axis) {
  if (typeof axis === 'bigint') {
    if (axis < 1n || axis > MAX_SAFE) {
      fail('Axis must be a safe integer greater than or equal to 1');
    }
    return Number(axis);
  }

  if (typeof axis !== 'number' || !Number.isSafeInteger(axis) || axis < 1) {
    fail('Axis must be a safe integer greater than or equal to 1');
  }
  return axis;
}

// Everything after the leading binary digit is a path: 0 selects the head and
// 1 selects the tail. This avoids recursively dividing large axes.
function axisPath(axis) {
  return normalizeAxis(axis).toString(2).slice(1);
}

export function slot(axis, value) {
  const number = normalizeAxis(axis);
  if (typeof value === 'function') {
    fail('slot: functions are not nouns');
  }
  assertValue(value, 'slot');

  let current = value;
  if (number < 0x80000000) {
    // The bits below the leading one, most significant first.
    for (let bit = 30 - Math.clz32(number); bit >= 0; bit -= 1) {
      if (!Array.isArray(current)) {
        fail(`slot: axis ${String(axis)} does not exist`);
      }
      current = current[(number >>> bit) & 1];
    }
    return current;
  }
  for (const direction of number.toString(2).slice(1)) {
    if (!Array.isArray(current)) {
      fail(`slot: axis ${String(axis)} does not exist`);
    }
    current = current[direction === '0' ? 0 : 1];
  }
  return current;
}

export function edit(axis, target, value) {
  const path = axisPath(axis);
  if (typeof target === 'function') {
    fail('edit: functions are not nouns');
  }
  assertValue(target, 'edit target');
  assertValue(value, 'edit replacement');

  if (path.length === 0) {
    return value;
  }

  const parents = [];
  let current = target;
  for (const direction of path) {
    if (!Array.isArray(current)) {
      fail(`edit: axis ${String(axis)} does not exist`);
    }
    parents.push(current);
    current = current[direction === '0' ? 0 : 1];
  }

  let replacement = value;
  for (let index = path.length - 1; index >= 0; index -= 1) {
    const parent = parents[index];
    replacement = path[index] === '0'
      ? [replacement, parent[1]]
      : [parent[0], replacement];
  }
  return replacement;
}

export function requireLoobean(value) {
  if (value === 0n) {
    return true;
  }
  if (value === 1n) {
    return false;
  }
  fail('Expected loobean 0n (%.y) or 1n (%.n)');
}

export function apply(fn, argument) {
  if (typeof fn !== 'function') {
    fail('Application target must be callable');
  }
  return fn(argument);
}

// A module-level function remembers its last few samples and products:
// called again with one of those samples, or a cell of the same two parts,
// it gives the same product, so the parts of a view whose inputs did not
// change are the same nouns as before, which the browser need not render
// again. A few, since one render may call a gate from several places.
const REMEMBERED = 4;

function sameSample(left, right) {
  return left === right || (Array.isArray(left) && Array.isArray(right)
    && left[0] === right[0] && left[1] === right[1]);
}

export function memo(fn) {
  const samples = [];
  const products = [];
  return (argument) => {
    for (let index = 0; index < samples.length; index += 1) {
      if (sameSample(samples[index], argument)) return products[index];
    }
    const result = fn(argument);
    if (samples.length === REMEMBERED) {
      samples.pop();
      products.pop();
    }
    samples.unshift(argument);
    products.unshift(result);
    return result;
  };
}

const MAX_SAFE = BigInt(Number.MAX_SAFE_INTEGER);
const HEX_BYTES = Array.from({ length: 256 }, (_, byte) => byte.toString(16).padStart(2, '0'));
const HEX_VALUES = new Uint8Array(128);
for (let digit = 0; digit < 16; digit += 1) {
  HEX_VALUES['0123456789abcdef'.charCodeAt(digit)] = digit;
}

export function atomToBytes(atom) {
  assertAtom(atom, 'atomToBytes');
  if (atom === 0n) {
    return new Uint8Array(0);
  }

  // Urbit atoms store the least-significant byte first.
  if (atom <= MAX_SAFE) {
    let rest = Number(atom);
    let length = 0;
    for (let probe = rest; probe > 0; probe = Math.floor(probe / 256)) length += 1;
    const bytes = new Uint8Array(length);
    for (let index = 0; index < length; index += 1) {
      bytes[index] = rest % 256;
      rest = Math.floor(rest / 256);
    }
    return bytes;
  }

  const hexadecimal = atom.toString(16);
  const odd = hexadecimal.length % 2;
  const bytes = new Uint8Array((hexadecimal.length + odd) / 2);
  let offset = hexadecimal.length;
  for (let index = 0; index < bytes.length; index += 1) {
    const low = HEX_VALUES[hexadecimal.charCodeAt(offset - 1)];
    const high = offset >= 2 ? HEX_VALUES[hexadecimal.charCodeAt(offset - 2)] : 0;
    bytes[index] = high * 16 + low;
    offset -= 2;
  }
  return bytes;
}

export function bytesToAtom(bytes) {
  if (!(bytes instanceof Uint8Array)) {
    fail('bytesToAtom: expected a Uint8Array');
  }

  if (bytes.length <= 6) {
    let small = 0;
    for (let index = bytes.length - 1; index >= 0; index -= 1) {
      small = small * 256 + bytes[index];
    }
    return BigInt(small);
  }
  let hexadecimal = '0x';
  for (let index = bytes.length - 1; index >= 0; index -= 1) {
    hexadecimal += HEX_BYTES[bytes[index]];
  }
  return BigInt(hexadecimal);
}

// Views decode the same cords again on every render, so recent decodings
// are kept, a bounded number of them.
const decoder = new TextDecoder('utf-8');
const decoded = new Map();
const DECODED_LIMIT = 8192;

export function atomToText(atom) {
  const known = decoded.get(atom);
  if (known !== undefined) return known;
  const bytes = atomToBytes(atom);
  let text;
  if (bytes.length <= 1024 && bytes.every(byte => byte < 0x80)) {
    text = String.fromCharCode(...bytes);
  } else {
    text = decoder.decode(bytes);
  }
  if (decoded.size >= DECODED_LIMIT) decoded.clear();
  decoded.set(atom, text);
  return text;
}

function logTrace(message, logger) {
  assertAtom(message, 'trace message');
  if (typeof logger !== 'function') {
    fail('trace: logger must be callable');
  }
  logger(atomToText(message));
}

export function trace(message, body, logger = console.log) {
  logTrace(message, logger);
  return body;
}

export function traceLazy(message, body, logger = console.log) {
  if (typeof body !== 'function') {
    fail('trace: lazy body must be callable');
  }
  logTrace(message, logger);
  return body();
}
