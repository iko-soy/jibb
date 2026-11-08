import { CoreCrash, requireLoobean, same } from '../core/runtime.mjs';
import {
  arrayToList,
  atom,
  call,
  listToArray,
  pair,
  unitValue,
} from './helpers.mjs';

function crash(operation, message) {
  throw new CoreCrash(`${operation}: ${message}`);
}

function boundedIndex(value, length, operation) {
  const index = atom(value, operation);
  return index > BigInt(length) ? length : Number(index);
}

function triple(sample, operation) {
  const [first, rest] = pair(sample, operation);
  const [second, third] = pair(rest, operation);
  return [first, second, third];
}

function matches(needle, needleLength, haystack, offset) {
  const candidate = arrayToList(haystack.slice(offset, offset + needleLength));
  return same(needle, candidate) === 0n;
}

export function lent(values) {
  return BigInt(listToArray(values, 'lent').length);
}

export function turn(sample) {
  const [values, gate] = pair(sample, 'turn');
  return arrayToList(listToArray(values, 'turn').map(item => call(gate, item)));
}

export function flop(values) {
  return arrayToList(listToArray(values, 'flop').reverse());
}

export function snag(sample) {
  const [indexValue, values] = pair(sample, 'snag');
  const items = listToArray(values, 'snag');
  const index = atom(indexValue, 'snag');
  if (index >= BigInt(items.length)) crash('snag', 'index past end of list');
  return items[Number(index)];
}

export function scag(sample) {
  const [count, values] = pair(sample, 'scag');
  const items = listToArray(values, 'scag');
  return arrayToList(items.slice(0, boundedIndex(count, items.length, 'scag')));
}

export function slag(sample) {
  const [count, values] = pair(sample, 'slag');
  const items = listToArray(values, 'slag');
  return arrayToList(items.slice(boundedIndex(count, items.length, 'slag')));
}

export function gulf(sample) {
  const [start, finish] = pair(sample, 'gulf');
  const first = atom(start, 'gulf');
  const last = atom(finish, 'gulf');
  if (first > last) crash('gulf', 'start is greater than finish');
  const items = [];
  for (let current = first; current <= last; current += 1n) items.push(current);
  return arrayToList(items);
}

export function oust(sample) {
  const [slice, values] = pair(sample, 'oust');
  const [startValue, countValue] = pair(slice, 'oust');
  const items = listToArray(values, 'oust');
  const start = atom(startValue, 'oust');
  const count = atom(countValue, 'oust');
  const prefix = start > BigInt(items.length) ? items.length : Number(start);
  const end = start + count > BigInt(items.length) ? items.length : Number(start + count);
  return arrayToList([...items.slice(0, prefix), ...items.slice(end)]);
}

export function swag(sample) {
  const [slice, values] = pair(sample, 'swag');
  const [startValue, countValue] = pair(slice, 'swag');
  const items = listToArray(values, 'swag');
  const start = boundedIndex(startValue, items.length, 'swag');
  const available = items.length - start;
  const count = boundedIndex(countValue, available, 'swag');
  return arrayToList(items.slice(start, start + count));
}

export function snap(sample) {
  const [values, indexValue, item] = triple(sample, 'snap');
  const items = listToArray(values, 'snap');
  const index = boundedIndex(indexValue, items.length, 'snap');
  const result = items.slice(0, index);
  result.push(item);
  if (index < items.length) {
    for (let position = index + 1; position < items.length; position += 1) {
      result.push(items[position]);
    }
  }
  return arrayToList(result);
}

export function into(sample) {
  const [values, indexValue, item] = triple(sample, 'into');
  const items = listToArray(values, 'into');
  const index = boundedIndex(indexValue, items.length, 'into');
  return arrayToList([...items.slice(0, index), item, ...items.slice(index)]);
}

export function skid(sample) {
  const [values, predicate] = pair(sample, 'skid');
  const items = listToArray(values, 'skid');
  // The checked Jibb definition is [skim(xs, p), skip(xs, p)]: retain its
  // two complete predicate passes and their observable callback order.
  const yes = [];
  const no = [];
  for (const item of items) {
    if (requireLoobean(call(predicate, item))) yes.push(item);
  }
  for (const item of items) {
    if (!requireLoobean(call(predicate, item))) no.push(item);
  }
  return [arrayToList(yes), arrayToList(no)];
}

export function fand(sample) {
  const [needleValues, haystackValues] = pair(sample, 'fand');
  const needleItems = listToArray(needleValues, 'fand');
  const haystack = listToArray(haystackValues, 'fand');
  if (needleItems.length === 0) return 0n;
  const needle = arrayToList(needleItems);
  const offsets = [];
  for (let offset = 0; offset + needleItems.length <= haystack.length; offset += 1) {
    if (matches(needle, needleItems.length, haystack, offset)) offsets.push(BigInt(offset));
  }
  return arrayToList(offsets);
}

export function find(sample) {
  const [needleValues, haystackValues] = pair(sample, 'find');
  const needleItems = listToArray(needleValues, 'find');
  const haystack = listToArray(haystackValues, 'find');
  if (needleItems.length === 0) return 0n;
  const needle = arrayToList(needleItems);
  for (let offset = 0; offset + needleItems.length <= haystack.length; offset += 1) {
    if (matches(needle, needleItems.length, haystack, offset)) return [0n, BigInt(offset)];
  }
  return 0n;
}

export function spin(sample) {
  const [values, initial, gate] = triple(sample, 'spin');
  const items = listToArray(values, 'spin');
  const mapped = [];
  let state = initial;
  for (const item of items) {
    const [value, next] = pair(call(gate, [item, state]), 'spin callback');
    mapped.push(value);
    state = next;
  }
  return [arrayToList(mapped), state];
}

export function sqt(value) {
  const target = atom(value, 'sqt');
  let low = 0n;
  let high = target + 1n;
  while (low + 1n < high) {
    const middle = (low + high) / 2n;
    if (middle * middle <= target) low = middle;
    else high = middle;
  }
  return [low, target - low * low];
}

export function roll(sample) {
  const [values, initial, combine] = triple(sample, 'roll');
  let state = initial;
  for (const item of listToArray(values, 'roll')) {
    state = call(combine, [item, state]);
  }
  return state;
}

export function zing(values) {
  const lists = listToArray(values, 'zing');
  const items = [];
  for (const list of lists) {
    for (const item of listToArray(list, 'zing')) items.push(item);
  }
  return arrayToList(items);
}

export function lead(first) {
  return second => [first, second];
}

export function late(second) {
  return first => [first, second];
}

export function succ(value) {
  return atom(value, 'succ') + 1n;
}

export function fall(sample) {
  const [maybe, fallback] = pair(sample, 'fall');
  const value = unitValue(maybe, 'fall');
  return value === undefined ? fallback : value;
}

export function flit(predicate) {
  return value => requireLoobean(call(predicate, value)) ? [0n, value] : 0n;
}

export function biff(sample) {
  const [maybe, gate] = pair(sample, 'biff');
  const value = unitValue(maybe, 'biff');
  return value === undefined ? 0n : call(gate, value);
}

export function bind(sample) {
  const [maybe, gate] = pair(sample, 'bind');
  const value = unitValue(maybe, 'bind');
  return value === undefined ? 0n : [0n, call(gate, value)];
}

export function bond(fallback) {
  return maybe => {
    const value = unitValue(maybe, 'bond');
    return value === undefined ? call(fallback, 0n) : value;
  };
}

export function both(sample) {
  const [first, second] = pair(sample, 'both');
  const left = unitValue(first, 'both');
  if (left === undefined) return 0n;
  const right = unitValue(second, 'both');
  return right === undefined ? 0n : [0n, [left, right]];
}

export function clap(sample) {
  const [first, second, combine] = triple(sample, 'clap');
  const left = unitValue(first, 'clap');
  if (left === undefined) return second;
  const right = unitValue(second, 'clap');
  if (right === undefined) return first;
  return [0n, call(combine, [left, right])];
}

export function clef(sample) {
  const [first, second, combine] = triple(sample, 'clef');
  const left = unitValue(first, 'clef');
  if (left === undefined) return 0n;
  const right = unitValue(second, 'clef');
  if (right === undefined) return 0n;
  return call(combine, [left, right]);
}

export function drop(maybe) {
  const value = unitValue(maybe, 'drop');
  return value === undefined ? 0n : [value, 0n];
}

export function mate(sample) {
  const [first, second] = pair(sample, 'mate');
  const right = unitValue(second, 'mate');
  if (right === undefined) return first;
  const left = unitValue(first, 'mate');
  if (left === undefined) return second;
  if (same(left, right) !== 0n) crash('mate', 'present values differ');
  return first;
}

export function need(maybe) {
  const value = unitValue(maybe, 'need');
  if (value === undefined) crash('need', 'absent unit');
  return value;
}

export function some(value) {
  return [0n, value];
}
