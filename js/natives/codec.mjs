import { CoreCrash, atomToBytes, bytesToAtom } from '../core/runtime.mjs';
import { atom, cell } from './helpers.mjs';

const UW_ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-~';
const UW_DIGITS = new Map([...UW_ALPHABET].map((digit, index) => [digit, index]));

function fail(message) {
  throw new CoreCrash(message);
}

function bitWidth(value) {
  return value === 0n ? 0 : value.toString(2).length;
}

// Intern by noun structure, not JavaScript identity. This gives structurally
// equal cells the same canonical jam backreferences. The explicit enter/exit
// stack accepts deep nouns while distinguishing sharing from cycles.
function internNoun(root, operation) {
  const nodes = [];
  const atomIds = new Map();
  const cellIds = new Map();
  const active = new Set();
  const complete = new Map();
  let rootId;
  const stack = [{ value: root, exit: false, assign: (id) => { rootId = id; } }];

  while (stack.length !== 0) {
    const frame = stack.pop();
    const current = frame.value;

    if (typeof current === 'bigint') {
      atom(current, operation);
      let id = atomIds.get(current);
      if (id === undefined) {
        id = nodes.length;
        nodes.push({ atom: current });
        atomIds.set(current, id);
      }
      frame.assign(id);
      continue;
    }

    if (typeof current === 'function') {
      fail(`${operation}: functions are not nouns`);
    }
    cell(current, operation);

    if (frame.exit) {
      let tails = cellIds.get(frame.headId);
      if (tails === undefined) {
        tails = new Map();
        cellIds.set(frame.headId, tails);
      }
      let id = tails.get(frame.tailId);
      if (id === undefined) {
        id = nodes.length;
        nodes.push({ head: frame.headId, tail: frame.tailId });
        tails.set(frame.tailId, id);
      }
      active.delete(current);
      complete.set(current, id);
      frame.assign(id);
      continue;
    }

    const known = complete.get(current);
    if (known !== undefined) {
      frame.assign(known);
      continue;
    }
    if (active.has(current)) {
      fail(`${operation}: cyclic cells are not nouns`);
    }

    active.add(current);
    const exit = { value: current, exit: true, assign: frame.assign };
    stack.push(
      exit,
      { value: current[1], exit: false, assign: (id) => { exit.tailId = id; } },
      { value: current[0], exit: false, assign: (id) => { exit.headId = id; } },
    );
  }

  return { nodes, rootId };
}

export function validateNoun(value, operation = 'noun') {
  internNoun(value, operation);
  return value;
}

class BitWriter {
  constructor() {
    this.bytes = new Uint8Array(64);
    this.position = 0;
  }

  ensure(width) {
    const required = Math.ceil((this.position + width) / 8);
    if (required <= this.bytes.length) return;
    let size = this.bytes.length;
    while (size < required) size *= 2;
    const grown = new Uint8Array(size);
    grown.set(this.bytes);
    this.bytes = grown;
  }

  writeBits(value, width) {
    if (width === 0) return;
    this.ensure(width);
    let remaining = width;
    let source = value;
    while (remaining !== 0) {
      const offset = this.position & 7;
      const count = Math.min(remaining, 8 - offset);
      const mask = (1n << BigInt(count)) - 1n;
      const bits = Number(source & mask);
      this.bytes[this.position >> 3] |= bits << offset;
      this.position += count;
      source >>= BigInt(count);
      remaining -= count;
    }
  }

  writeMat(value) {
    if (value === 0n) {
      this.writeBits(1n, 1);
      return;
    }
    const width = bitWidth(value);
    const lengthWidth = bitWidth(BigInt(width));
    this.writeBits(0n, lengthWidth);
    this.writeBits(1n, 1);
    this.writeBits(BigInt(width), lengthWidth - 1);
    this.writeBits(value, width);
  }

  finish() {
    return this.bytes.slice(0, Math.ceil(this.position / 8));
  }
}

// Hoon +jam: atom tag 0, cell tag 01, and backreference tag 11. All bit
// strings are least-significant-bit first, as in Hoon +mat and Vere serial.c.
export function jam(value) {
  const { nodes, rootId } = internNoun(value, 'jam');
  const writer = new BitWriter();
  const references = new Map();
  const pending = [rootId];

  while (pending.length !== 0) {
    const id = pending.pop();
    const node = nodes[id];
    const isAtom = Object.hasOwn(node, 'atom');
    const reference = references.get(id);

    if (reference !== undefined) {
      if (!isAtom || bitWidth(node.atom) > bitWidth(reference)) {
        writer.writeBits(3n, 2);
        writer.writeMat(reference);
        continue;
      }
    } else {
      references.set(id, BigInt(writer.position));
    }

    if (isAtom) {
      writer.writeBits(0n, 1);
      writer.writeMat(node.atom);
    } else {
      writer.writeBits(1n, 2);
      pending.push(node.tail, node.head);
    }
  }

  return bytesToAtom(writer.finish());
}

class BitReader {
  constructor(packed) {
    this.bytes = atomToBytes(packed);
    this.length = bitWidth(packed);
    this.position = 0;
  }

  readBits(width) {
    if (width > this.length - this.position) {
      fail(`cue: truncated jam at bit ${this.position}`);
    }
    let remaining = width;
    let result = 0n;
    let shift = 0n;
    while (remaining !== 0) {
      const offset = this.position & 7;
      const count = Math.min(remaining, 8 - offset);
      const mask = (1 << count) - 1;
      const bits = (this.bytes[this.position >> 3] >> offset) & mask;
      result |= BigInt(bits) << shift;
      shift += BigInt(count);
      this.position += count;
      remaining -= count;
    }
    return result;
  }

  readRub() {
    let lengthWidth = 0;
    while (this.readBits(1) === 0n) lengthWidth += 1;
    if (lengthWidth === 0) return 0n;

    const low = this.readBits(lengthWidth - 1);
    const width = (1n << BigInt(lengthWidth - 1)) + low;
    if (width > BigInt(this.length - this.position)) {
      fail(`cue: truncated atom payload at bit ${this.position}`);
    }
    return this.readBits(Number(width));
  }
}

// Cue is deliberately stricter than Hoon's permissive bit slicing: a jam atom
// must contain exactly one complete noun and every backreference must name a
// previously completed atom or cell.
export function cue(packed) {
  atom(packed, 'cue');
  const reader = new BitReader(packed);
  const references = new Map();
  let result;
  const pending = [{ kind: 'decode', assign: (value) => { result = value; } }];

  while (pending.length !== 0) {
    const frame = pending.pop();
    if (frame.kind === 'finish') {
      references.set(BigInt(frame.start), frame.value);
      frame.assign(frame.value);
      continue;
    }

    const start = reader.position;
    if (reader.readBits(1) === 0n) {
      const value = reader.readRub();
      references.set(BigInt(start), value);
      frame.assign(value);
      continue;
    }

    if (reader.readBits(1) === 1n) {
      const reference = reader.readRub();
      if (!references.has(reference)) {
        fail(`cue: invalid backreference to bit ${reference}`);
      }
      frame.assign(references.get(reference));
      continue;
    }

    const value = [0n, 0n];
    pending.push(
      { kind: 'finish', start, value, assign: frame.assign },
      { kind: 'decode', assign: (tail) => { value[1] = tail; } },
      { kind: 'decode', assign: (head) => { value[0] = head; } },
    );
  }

  if (reader.position !== reader.length) {
    fail(`cue: trailing data after bit ${reader.position} of ${reader.length}`);
  }
  return result;
}

// Hoon @uw is numeric base 64, not byte-oriented RFC base64url. Digits are
// most-significant first, with dots before each non-leading five-digit group.
export function encodeUw(value) {
  atom(value, '@uw encode');
  if (value === 0n) return '0w0';

  const binary = value.toString(2);
  const digits = [];
  let offset = binary.length % 6 || 6;
  digits.push(UW_ALPHABET[Number.parseInt(binary.slice(0, offset), 2)]);
  while (offset < binary.length) {
    digits.push(UW_ALPHABET[Number.parseInt(binary.slice(offset, offset + 6), 2)]);
    offset += 6;
  }

  let encoded = '0w';
  for (let index = 0; index < digits.length; index += 1) {
    if (index !== 0 && (digits.length - index) % 5 === 0) encoded += '.';
    encoded += digits[index];
  }
  return encoded;
}

export function decodeUw(encoded) {
  if (typeof encoded !== 'string') {
    fail('@uw decode: expected a string');
  }
  if (!encoded.startsWith('0w')) {
    fail('@uw decode: expected the 0w prefix');
  }

  const body = encoded.slice(2);
  if (body === '0') return 0n;
  if (body.length === 0) fail('@uw decode: missing digits');

  const groups = body.split('.');
  if (groups[0].length < 1 || groups[0].length > 5 || groups[0][0] === '0') {
    fail('@uw decode: invalid leading digit group');
  }
  if (groups.slice(1).some((group) => group.length !== 5)) {
    fail('@uw decode: non-leading groups must contain five digits');
  }

  let value = 0n;
  for (const group of groups) {
    for (const digit of group) {
      const parsed = UW_DIGITS.get(digit);
      if (parsed === undefined) fail(`@uw decode: invalid digit ${JSON.stringify(digit)}`);
      value = (value << 6n) | BigInt(parsed);
    }
  }
  return value;
}

export { encodeUw as enUw, decodeUw as deUw };
