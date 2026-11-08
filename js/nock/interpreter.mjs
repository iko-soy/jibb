import {
  CoreCrash,
  slot,
  edit,
  isCell,
  same,
  atomToText,
} from '../core/runtime.mjs';
import { readLiteral } from '../core/literal.mjs';
import { NOCK_NATIVES } from './emitter.mjs';

const SLOG = readLiteral('%slog').value;
const LEAF = readLiteral('%leaf').value;

function fail(message) {
  throw new CoreCrash(`Nock: ${message}`);
}

function formulaCell(value, description = 'formula') {
  if (!Array.isArray(value) || value.length !== 2) {
    fail(`expected a two-element ${description}`);
  }
  return value;
}

function isAdapter(value) {
  return typeof value === 'function'
    || (value !== null && typeof value === 'object' && typeof value.apply === 'function');
}

class AppliedNative {
  constructor(adapter, sample) {
    this.adapter = adapter;
    this.sample = sample;
  }
}

function isGateNoun(value) {
  return Array.isArray(value) && value.length === 2
    && Array.isArray(value[0]) && value[0].length === 2
    && Array.isArray(value[1]) && value[1].length === 2;
}

function registryValue(natives, name) {
  let value;
  if (natives instanceof Map) {
    if (!natives.has(name)) throw new TypeError(`missing native ${name}`);
    value = natives.get(name);
  } else {
    if (natives === null || typeof natives !== 'object' || !Object.hasOwn(natives, name)) {
      throw new TypeError(`missing native ${name}`);
    }
    value = natives[name];
  }
  if (!isGateNoun(value) && !isAdapter(value)) {
    throw new TypeError(`native ${name} must be a Hoon-shaped gate noun or adapter`);
  }
  return value;
}

function nativeSubject(subject, formula, natives) {
  const names = formula[NOCK_NATIVES] ?? [];
  if (names.length === 0) return subject;
  let registry = 0n;
  for (let index = names.length - 1; index >= 0; index -= 1) {
    registry = [registryValue(natives, names[index]), registry];
  }
  return [registry, subject];
}

function callAdapter(applied, options) {
  const applyGate = (gate, sample) => applyNock(gate, sample, {}, options);
  if (typeof applied.adapter === 'function') {
    return applied.adapter(applied.sample, applyGate);
  }
  return applied.adapter.apply(applied.sample, applyGate);
}

function handleHint(tag, clue, logger) {
  if (tag !== SLOG) return;
  const outer = formulaCell(clue, '%slog clue');
  const priority = outer[0];
  const tank = formulaCell(outer[1], '%slog tank');
  if (typeof priority !== 'bigint' || tank[0] !== LEAF || typeof tank[1] !== 'bigint') {
    fail('%slog expects [priority [%leaf cord]]');
  }
  logger(atomToText(tank[1]));
}

/**
 * Evaluate standard Nock 0-10 and dynamic/static Nock 11 hints.
 *
 * Emitted formulas carry a private native layout. When present, runNock wraps
 * the subject as [native-gate-list subject]; ordinary hand-written formulas
 * run against the supplied subject unchanged. The optional fourth argument is
 * {logger}, used only for %slog hints.
 */
export function runNock(subject, formula, natives = {}, { logger = console.log } = {}) {
  if (typeof logger !== 'function') throw new TypeError('Nock logger must be callable');

  let currentSubject = nativeSubject(subject, formula, natives);
  let currentFormula = formula;
  let value;
  let hasValue = false;
  const stack = [];
  const options = { logger };

  for (;;) {
    if (hasValue) {
      if (stack.length === 0) return value;
      const frame = stack.pop();
      hasValue = false;
      switch (frame.type) {
        case 'cons-head':
          stack.push({ type: 'cons-tail', head: value });
          currentFormula = frame.tail;
          currentSubject = frame.subject;
          continue;
        case 'cons-tail':
          value = [frame.head, value];
          hasValue = true;
          continue;
        case 'two-second':
          stack.push({ type: 'two-eval', first: value });
          currentFormula = frame.second;
          currentSubject = frame.subject;
          continue;
        case 'two-eval':
          currentSubject = frame.first;
          currentFormula = formulaCell(value, 'computed formula');
          continue;
        case 'cell':
          value = isCell(value);
          hasValue = true;
          continue;
        case 'increment':
          if (typeof value !== 'bigint' || value < 0n) fail('increment expects an atom');
          value += 1n;
          hasValue = true;
          continue;
        case 'equal-left':
          stack.push({ type: 'equal-right', left: value });
          currentFormula = frame.right;
          currentSubject = frame.subject;
          continue;
        case 'equal-right':
          value = same(frame.left, value);
          hasValue = true;
          continue;
        case 'if':
          if (value === 0n) currentFormula = frame.then;
          else if (value === 1n) currentFormula = frame.else;
          else fail('if expects loobean 0n or 1n');
          currentSubject = frame.subject;
          continue;
        case 'compose':
          currentSubject = value;
          currentFormula = frame.next;
          continue;
        case 'push':
          currentSubject = [value, frame.subject];
          currentFormula = frame.body;
          continue;
        case 'kick':
          if (value instanceof AppliedNative) {
            if (frame.axis !== 2n) fail('a native adapter only has an arm at axis 2');
            value = callAdapter(value, options);
            hasValue = true;
          } else {
            currentSubject = value;
            currentFormula = slot(frame.axis, value);
          }
          continue;
        case 'edit-target':
          stack.push({ type: 'edit-value', axis: frame.axis, target: value });
          currentFormula = frame.replacement;
          currentSubject = frame.subject;
          continue;
        case 'edit-value':
          if (isAdapter(frame.target)) {
            if (frame.axis === 1n) value = value;
            else if (frame.axis === 6n) value = new AppliedNative(frame.target, value);
            else fail('a native adapter only supports replacement at axis 6');
          } else {
            value = edit(frame.axis, frame.target, value);
          }
          hasValue = true;
          continue;
        case 'hint':
          handleHint(frame.tag, value, logger);
          currentSubject = frame.subject;
          currentFormula = frame.body;
          continue;
        default:
          throw new Error(`unknown Nock continuation ${frame.type}`);
      }
    }

    const current = formulaCell(currentFormula);
    const [head, tail] = current;

    // Any formula with a cell in its head is autocons, including formulas
    // which would look like an opcode after removing their first layer.
    if (Array.isArray(head)) {
      stack.push({ type: 'cons-head', subject: currentSubject, tail });
      currentFormula = head;
      continue;
    }
    if (typeof head !== 'bigint') fail('formula opcode must be an atom');

    switch (head) {
      case 0n:
        if (typeof tail !== 'bigint') fail('slot axis must be an atom');
        value = slot(tail, currentSubject);
        hasValue = true;
        break;
      case 1n:
        value = tail;
        hasValue = true;
        break;
      case 2n: {
        const [first, second] = formulaCell(tail, 'Nock 2 tail');
        stack.push({ type: 'two-second', subject: currentSubject, second });
        currentFormula = first;
        break;
      }
      case 3n:
        stack.push({ type: 'cell' });
        currentFormula = tail;
        break;
      case 4n:
        stack.push({ type: 'increment' });
        currentFormula = tail;
        break;
      case 5n: {
        const [left, right] = formulaCell(tail, 'Nock 5 tail');
        stack.push({ type: 'equal-left', subject: currentSubject, right });
        currentFormula = left;
        break;
      }
      case 6n: {
        const [condition, branches] = formulaCell(tail, 'Nock 6 tail');
        const [then, otherwise] = formulaCell(branches, 'Nock 6 branches');
        stack.push({
          type: 'if',
          subject: currentSubject,
          then,
          else: otherwise,
        });
        currentFormula = condition;
        break;
      }
      case 7n: {
        const [first, next] = formulaCell(tail, 'Nock 7 tail');
        stack.push({ type: 'compose', next });
        currentFormula = first;
        break;
      }
      case 8n: {
        const [first, body] = formulaCell(tail, 'Nock 8 tail');
        stack.push({ type: 'push', subject: currentSubject, body });
        currentFormula = first;
        break;
      }
      case 9n: {
        const [axis, core] = formulaCell(tail, 'Nock 9 tail');
        if (typeof axis !== 'bigint') fail('Nock 9 arm axis must be an atom');
        stack.push({ type: 'kick', axis });
        currentFormula = core;
        break;
      }
      case 10n: {
        const [replacementSpec, target] = formulaCell(tail, 'Nock 10 tail');
        const [axis, replacement] = formulaCell(replacementSpec, 'Nock 10 replacement');
        if (typeof axis !== 'bigint') fail('Nock 10 axis must be an atom');
        stack.push({
          type: 'edit-target',
          subject: currentSubject,
          axis,
          replacement,
        });
        currentFormula = target;
        break;
      }
      case 11n: {
        const [hint, body] = formulaCell(tail, 'Nock 11 tail');
        if (Array.isArray(hint)) {
          const [tag, clue] = formulaCell(hint, 'Nock 11 dynamic hint');
          if (typeof tag !== 'bigint') fail('Nock 11 hint tag must be an atom');
          stack.push({ type: 'hint', subject: currentSubject, tag, body });
          currentFormula = clue;
        } else {
          if (typeof hint !== 'bigint') fail('Nock 11 hint tag must be an atom');
          // Static hints have no clue to evaluate and do not alter the result.
          currentFormula = body;
        }
        break;
      }
      default:
        fail(`unsupported opcode ${head}`);
    }
  }
}

/** Apply a Hoon-shaped gate or native adapter with the Core application ABI. */
export function applyNock(gate, argument, natives = {}, options = {}) {
  const formula = [9n, [2n, [10n, [[6n, [1n, argument]], [1n, gate]]]]];
  return runNock(0n, formula, natives, options);
}
