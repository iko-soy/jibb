import { CoreCrash, apply, atomToText, bytesToAtom } from '../core/runtime.mjs';

export function atom(value, operation = 'native') {
  if (typeof value !== 'bigint' || value < 0n) {
    throw new CoreCrash(`${operation}: expected an unsigned atom`);
  }
  return value;
}

export function cell(value, operation = 'native') {
  if (!Array.isArray(value) || value.length !== 2) {
    throw new CoreCrash(`${operation}: expected a cell`);
  }
  return value;
}

export function pair(sample, operation = 'native') {
  return cell(sample, operation);
}

export function listToArray(value, operation = 'native') {
  const items = [];
  let current = value;
  while (current !== 0n) {
    const [head, tail] = cell(current, operation);
    items.push(head);
    current = tail;
  }
  return items;
}

export function arrayToList(items) {
  return items.reduceRight((tail, item) => [item, tail], 0n);
}

export function cord(text) {
  return bytesToAtom(new TextEncoder().encode(text));
}

export function text(value) {
  return atomToText(atom(value, 'text'));
}

export function loob(value) {
  return value ? 0n : 1n;
}

export function call(fn, argument) {
  return apply(fn, argument);
}

export function unit(value) {
  return value === undefined ? 0n : [0n, value];
}

export function unitValue(value, operation = 'native unit') {
  if (value === 0n) return undefined;
  const [head, tail] = cell(value, operation);
  if (head !== 0n) throw new CoreCrash(`${operation}: expected ~ or [~ value]`);
  return tail;
}
