import { murmur32 } from '../core/hash.mjs';
import { CoreCrash, atomToBytes, equalNouns as equalValid, validateValue } from '../core/runtime.mjs';
import { arrayToList, call, cell, loob, pair, unit } from './helpers.mjs';

function fail(message) {
  throw new CoreCrash(message);
}

function assertNoun(value, operation) {
  return validateValue(value, operation);
}

function assertMapValue(value, operation) {
  return validateValue(value, operation, true);
}

function mum(seed, fallback, key) {
  const bytes = atomToBytes(key);
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const hashed = murmur32(seed + attempt, bytes);
    const result = (hashed >>> 31) ^ (hashed & 0x7fffffff);
    if (result !== 0) return BigInt(result);
  }
  return fallback;
}

function mugValid(value) {
  const memo = new Map();
  const results = [];
  const stack = [{ value, exit: false }];

  while (stack.length !== 0) {
    const frame = stack.pop();
    const current = frame.value;
    if (typeof current === 'bigint') {
      results.push(mum(0xcafebabe, 0x7fffn, current));
      continue;
    }
    if (frame.exit) {
      const tail = results.pop();
      const head = results.pop();
      const combined = (tail << 32n) | head;
      const hashed = mum(0xdeadbeef, 0xfffen, combined);
      memo.set(current, hashed);
      results.push(hashed);
      continue;
    }
    if (memo.has(current)) {
      results.push(memo.get(current));
      continue;
    }
    stack.push(
      { value: current, exit: true },
      { value: current[1], exit: false },
      { value: current[0], exit: false },
    );
  }
  return results[0];
}

/** Hoon +mug: a nonzero 31-bit noun hash. */
export function mug(value) {
  assertNoun(value, 'mug');
  return mugValid(value);
}

// Depth order is the collision fallback for both gor and mor.
function dorValid(left, right) {
  const pending = [[left, right]];
  while (pending.length !== 0) {
    const [a, b] = pending.pop();
    if (equalValid(a, b)) continue;
    if (typeof a === 'bigint') {
      if (typeof b !== 'bigint') return true;
      return a < b;
    }
    if (typeof b === 'bigint') return false;
    pending.push(equalValid(a[0], b[0]) ? [a[1], b[1]] : [a[0], b[0]]);
  }
  return true;
}

function gorValid(left, right) {
  const a = mugValid(left);
  const b = mugValid(right);
  return a === b ? dorValid(left, right) : a < b;
}

function morValid(left, right) {
  const a = mugValid(mugValid(left));
  const b = mugValid(mugValid(right));
  return a === b ? dorValid(left, right) : a < b;
}

/** Hoon +gor, returned as a Jibb loobean. */
export function gor(left, right) {
  assertNoun(left, 'gor left');
  assertNoun(right, 'gor right');
  return loob(gorValid(left, right));
}

/** Hoon +mor, returned as a Jibb loobean. */
export function mor(left, right) {
  assertNoun(left, 'mor left');
  assertNoun(right, 'mor right');
  return loob(morValid(left, right));
}

function readNode(tree, operation) {
  const [value, children] = cell(tree, operation);
  const [left, right] = cell(children, operation);
  return { value, left, right };
}

function makeNode(value, left, right) {
  return [value, [left, right]];
}

function mapKey(node) {
  return node.value[0];
}

function setKey(node) {
  return node.value;
}

function validateTree(tree, isMap, operation) {
  if (tree === 0n) return tree;
  const active = new Set();
  const keyOf = isMap ? mapKey : setKey;
  const stack = [{ tree, lower: null, upper: null, exit: false }];

  while (stack.length !== 0) {
    const frame = stack.pop();
    const current = frame.tree;
    if (current === 0n) continue;
    if (typeof current === 'bigint') fail(`${operation}: nonempty tree node must be a cell`);
    if (frame.exit) {
      active.delete(current);
      const node = readNode(current, operation);
      const key = keyOf(node);
      for (const child of [node.left, node.right]) {
        if (child === 0n) continue;
        const childKey = keyOf(readNode(child, operation));
        if (!morValid(key, childKey) || equalValid(key, childKey)) {
          fail(`${operation}: parent key must have strict mor priority over its children`);
        }
      }
      continue;
    }
    if (active.has(current)) fail(`${operation}: cyclic treap`);

    const node = readNode(current, operation);
    if (isMap) {
      pair(node.value, `${operation} entry`);
      assertMapValue(node.value[1], `${operation} value`);
    }
    const key = keyOf(node);
    assertNoun(key, `${operation} key`);

    if (frame.lower !== null && (!gorValid(frame.lower, key) || equalValid(key, frame.lower))) {
      fail(`${operation}: key is not strictly greater than its lower gor bound`);
    }
    if (frame.upper !== null && (!gorValid(key, frame.upper) || equalValid(key, frame.upper))) {
      fail(`${operation}: key is not strictly less than its upper gor bound`);
    }

    active.add(current);
    stack.push(
      { tree: current, lower: null, upper: null, exit: true },
      { tree: node.right, lower: key, upper: frame.upper, exit: false },
      { tree: node.left, lower: frame.lower, upper: key, exit: false },
    );
  }
  return tree;
}

/** Validate a Hoon map noun and return it unchanged. */
export function validateMap(tree) {
  return validateTree(tree, true, 'map validation');
}

/** Validate a Hoon set noun and return it unchanged. */
export function validateSet(tree) {
  return validateTree(tree, false, 'set validation');
}

function getValid(tree, key, isMap) {
  let current = tree;
  while (current !== 0n) {
    const node = readNode(current, 'collection lookup');
    const nodeKey = isMap ? mapKey(node) : setKey(node);
    if (equalValid(key, nodeKey)) return node;
    current = gorValid(key, nodeKey) ? node.left : node.right;
  }
  return null;
}

function putValid(tree, key, value, isMap) {
  if (tree === 0n) return makeNode(isMap ? [key, value] : key, 0n, 0n);
  const node = readNode(tree, 'collection put');
  const nodeKey = isMap ? mapKey(node) : setKey(node);

  if (equalValid(key, nodeKey)) {
    if (!isMap || value === node.value[1]) return tree;
    return makeNode([key, value], node.left, node.right);
  }

  if (gorValid(key, nodeKey)) {
    const inserted = putValid(node.left, key, value, isMap);
    if (inserted === node.left) return tree;
    const child = readNode(inserted, 'collection put');
    const childKey = isMap ? mapKey(child) : setKey(child);
    if (morValid(nodeKey, childKey)) return makeNode(node.value, inserted, node.right);
    return makeNode(child.value, child.left, makeNode(node.value, child.right, node.right));
  }

  const inserted = putValid(node.right, key, value, isMap);
  if (inserted === node.right) return tree;
  const child = readNode(inserted, 'collection put');
  const childKey = isMap ? mapKey(child) : setKey(child);
  if (morValid(nodeKey, childKey)) return makeNode(node.value, node.left, inserted);
  return makeNode(child.value, makeNode(node.value, node.left, child.left), child.right);
}

function joinValid(left, right, isMap) {
  if (left === 0n) return right;
  if (right === 0n) return left;
  const a = readNode(left, 'collection delete');
  const b = readNode(right, 'collection delete');
  const aKey = isMap ? mapKey(a) : setKey(a);
  const bKey = isMap ? mapKey(b) : setKey(b);
  if (morValid(aKey, bKey)) {
    return makeNode(a.value, a.left, joinValid(a.right, right, isMap));
  }
  return makeNode(b.value, joinValid(left, b.left, isMap), b.right);
}

function deleteValid(tree, key, isMap) {
  if (tree === 0n) return tree;
  const node = readNode(tree, 'collection delete');
  const nodeKey = isMap ? mapKey(node) : setKey(node);
  if (equalValid(key, nodeKey)) return joinValid(node.left, node.right, isMap);

  if (gorValid(key, nodeKey)) {
    const deleted = deleteValid(node.left, key, isMap);
    return deleted === node.left ? tree : makeNode(node.value, deleted, node.right);
  }
  const deleted = deleteValid(node.right, key, isMap);
  return deleted === node.right ? tree : makeNode(node.value, node.left, deleted);
}

export const emptyMap = 0n;
export const emptySet = 0n;

/** Construct a map by Hoon +gas order from a JavaScript array of [key, value]. */
export function mapFromEntries(entries) {
  if (!Array.isArray(entries)) fail('map constructor: expected an array of entries');
  let tree = emptyMap;
  for (const entry of entries) {
    pair(entry, 'map constructor entry');
    assertNoun(entry[0], 'map constructor key');
    assertMapValue(entry[1], 'map constructor value');
    tree = putValid(tree, entry[0], entry[1], true);
  }
  return validateMap(tree);
}

/** Construct a set by Hoon +gas order from a JavaScript array of values. */
export function setFromValues(values) {
  if (!Array.isArray(values)) fail('set constructor: expected an array of values');
  let tree = emptySet;
  for (const value of values) {
    assertNoun(value, 'set constructor item');
    tree = putValid(tree, value, undefined, false);
  }
  return validateSet(tree);
}

/** Hoon +get.by: ~ or [~ value]. */
export function mapGet(tree, key) {
  validateMap(tree);
  assertNoun(key, 'map get key');
  const found = getValid(tree, key, true);
  return found === null ? unit(undefined) : unit(found.value[1]);
}

/** Hoon +has.by, returned as a Jibb loobean. */
export function mapHas(tree, key) {
  validateMap(tree);
  assertNoun(key, 'map has key');
  return loob(getValid(tree, key, true) !== null);
}

/** Hoon +put.by, with persistent path copying and rotations. */
export function mapPut(tree, key, value) {
  validateMap(tree);
  assertNoun(key, 'map put key');
  assertMapValue(value, 'map put value');
  return putValid(tree, key, value, true);
}

/** Hoon +del.by, with persistent path copying and heap joins. */
export function mapDelete(tree, key) {
  validateMap(tree);
  assertNoun(key, 'map delete key');
  return deleteValid(tree, key, true);
}

/** Hoon +has.in, returned as a Jibb loobean. */
export function setHas(tree, value) {
  validateSet(tree);
  assertNoun(value, 'set has item');
  return loob(getValid(tree, value, false) !== null);
}

/** Hoon +put.in, with persistent path copying and rotations. */
export function setPut(tree, value) {
  validateSet(tree);
  assertNoun(value, 'set put item');
  return putValid(tree, value, undefined, false);
}

/** Hoon +del.in, with persistent path copying and heap joins. */
export function setDelete(tree, value) {
  validateSet(tree);
  assertNoun(value, 'set delete item');
  return deleteValid(tree, value, false);
}

function preorder(tree, visit) {
  const stack = [tree];
  while (stack.length !== 0) {
    const current = stack.pop();
    if (current === 0n) continue;
    const node = readNode(current, 'collection traversal');
    visit(node);
    stack.push(node.right, node.left);
  }
}

function reverseInorder(tree, visit) {
  const stack = [{ tree, exit: false }];
  while (stack.length !== 0) {
    const frame = stack.pop();
    if (frame.tree === 0n) continue;
    const node = readNode(frame.tree, 'collection traversal');
    if (frame.exit) {
      visit(node);
      continue;
    }
    stack.push(
      { tree: node.left, exit: false },
      { tree: frame.tree, exit: true },
      { tree: node.right, exit: false },
    );
  }
}

/** Hoon +tap.by: entries in descending gor key order, as a Hoon list. */
export function mapEntries(tree) {
  validateMap(tree);
  const entries = [];
  reverseInorder(tree, (node) => entries.push(node.value));
  return arrayToList(entries);
}

/** Hoon +val.by: values in descending gor key order, as a Hoon list. */
export function mapValues(tree) {
  validateMap(tree);
  const values = [];
  reverseInorder(tree, (node) => values.push(node.value[1]));
  return arrayToList(values);
}

/** Hoon +key.by, including its root/left/right insertion order. */
export function mapKeys(tree) {
  validateMap(tree);
  let result = emptySet;
  preorder(tree, (node) => {
    result = putValid(result, mapKey(node), undefined, false);
  });
  return result;
}

/** Hoon +tap.in: items in descending gor order, as a Hoon list. */
export function setValues(tree) {
  validateSet(tree);
  const values = [];
  reverseInorder(tree, (node) => values.push(node.value));
  return arrayToList(values);
}

/** Hoon +rep.by: call fn([entry, accumulator]) root/left/right. */
export function mapRep(tree, initial, fn) {
  validateMap(tree);
  let accumulator = initial;
  preorder(tree, (node) => {
    accumulator = call(fn, [node.value, accumulator]);
  });
  return accumulator;
}

/** Hoon +rep.in: call fn([item, accumulator]) root/left/right. */
export function setRep(tree, initial, fn) {
  validateSet(tree);
  let accumulator = initial;
  preorder(tree, (node) => {
    accumulator = call(fn, [node.value, accumulator]);
  });
  return accumulator;
}

/** Core native wrapper for raw-map-get.core, sample [map key]. */
export function rawMapGet(argument) {
  const [tree, key] = pair(argument, 'raw-map-get');
  return mapGet(tree, key);
}

/** Core native wrapper for raw-map-put.core, sample [map [key value]]. */
export function rawMapPut(argument) {
  const [tree, rest] = pair(argument, 'raw-map-put');
  const [key, value] = pair(rest, 'raw-map-put');
  return mapPut(tree, key, value);
}

export const collectionNatives = /* @__PURE__ */ Object.freeze({
  'raw-map-get': rawMapGet,
  'raw-map-put': rawMapPut,
});

// Familiar aliases retain the exact Hoon door-arm names as well.
export {
  mapDelete as mapDel,
  mapEntries as mapTap,
  mapKeys as mapKey,
  mapRep as mapFold,
  mapValues as mapVal,
  setDelete as setDel,
  setRep as setFold,
  setValues as setTap,
};
