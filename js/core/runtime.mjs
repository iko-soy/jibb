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

// Validate the complete noun, rather than only the portion an operation reads.
// The explicit stack handles deep nouns; the two sets distinguish shared
// substructure (valid) from cycles (invalid).
function assertNoun(value, operation) {
  return assertValue(value, operation, false);
}

function assertValue(value, operation, allowFunctions = true) {
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
      if (allowFunctions) {
        continue;
      }
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
  assertNoun(left, 'eq left');
  assertNoun(right, 'eq right');

  const pending = [[left, right]];
  while (pending.length !== 0) {
    const [a, b] = pending.pop();

    if (a === b) {
      continue;
    }
    if (typeof a === 'bigint' || typeof b === 'bigint') {
      return 1n;
    }
    if (!Array.isArray(a) || !Array.isArray(b)) {
      return 1n;
    }

    pending.push([a[0], b[0]], [a[1], b[1]]);
  }

  return 0n;
}

function normalizeAxis(axis) {
  if (typeof axis === 'bigint') {
    if (axis < 1n || axis > BigInt(Number.MAX_SAFE_INTEGER)) {
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
  const path = axisPath(axis);
  if (typeof value === 'function') {
    fail('slot: functions are not nouns');
  }
  assertValue(value, 'slot');

  let current = value;
  for (const direction of path) {
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

export function atomToBytes(atom) {
  assertAtom(atom, 'atomToBytes');
  if (atom === 0n) {
    return new Uint8Array(0);
  }

  let hexadecimal = atom.toString(16);
  if (hexadecimal.length % 2 !== 0) {
    hexadecimal = `0${hexadecimal}`;
  }

  const bytes = new Uint8Array(hexadecimal.length / 2);
  // Urbit atoms store the least-significant byte first.
  for (let index = 0; index < bytes.length; index += 1) {
    const offset = hexadecimal.length - 2 * (index + 1);
    bytes[index] = Number.parseInt(hexadecimal.slice(offset, offset + 2), 16);
  }
  return bytes;
}

export function bytesToAtom(bytes) {
  if (!(bytes instanceof Uint8Array)) {
    fail('bytesToAtom: expected a Uint8Array');
  }

  let atom = 0n;
  for (let index = bytes.length - 1; index >= 0; index -= 1) {
    atom = (atom << 8n) | BigInt(bytes[index]);
  }
  return atom;
}

export function atomToText(atom) {
  return new TextDecoder('utf-8').decode(atomToBytes(atom));
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
