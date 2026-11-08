import test from 'node:test';
import assert from 'node:assert/strict';
import { createFakeDocument, FakeEvent } from './fake-dom.mjs';
import { startIsland } from '../browser/island.mjs';
import { rawSeal } from '../natives/legacy.mjs';
import { jam } from '../natives/codec.mjs';
import { arrayToList, cord } from '../natives/helpers.mjs';

const textElement = (value) => rawSeal([cord('text'), cord(String(value))]);

function counterProgram(overrides = {}) {
  return {
    init: () => 0n,
    update: ([_message, model]) => [model + 1n, 0n],
    view: (model) => textElement(`Count: ${model}`),
    ...overrides,
  };
}

function setup(program = counterProgram(), options = {}) {
  const document = createFakeDocument();
  const island = startIsland({ program, document, container: document.body, ...options });
  return { document, island };
}

test('start initializes and mounts, then update patches the model and view', () => {
  const { document, island } = setup();
  assert.equal(document.body.textContent, 'Count: 0');
  island.send(cord('increment'));
  assert.equal(document.body.textContent, 'Count: 1');
  island.send(cord('increment'));
  assert.equal(document.body.textContent, 'Count: 2');
  assert.equal(island.model, 2n);
});

test('commands run in list order after the DOM patch, including unchanged models', () => {
  const calls = [];
  const program = counterProgram({
    update: ([message, model]) => [message === cord('same') ? model : model + 1n,
      arrayToList([cord('first'), cord('second')])],
  });
  const { document, island } = setup(program, {
    dispatchCommand: (command) => calls.push([command, document.body.textContent]),
  });
  island.send(cord('next'));
  assert.deepEqual(calls, [[cord('first'), 'Count: 1'], [cord('second'), 'Count: 1']]);
  island.send(cord('same'));
  assert.equal(island.model, 1n);
  assert.deepEqual(calls.slice(2), [[cord('first'), 'Count: 1'], [cord('second'), 'Count: 1']]);
});

test('update and view failures keep the previous model and report the crash', () => {
  const errors = [];
  const program = counterProgram({
    update: ([message, model]) => {
      if (message === cord('bad')) throw new Error('bad update');
      return [model + 1n, 0n];
    },
  });
  const { document, island } = setup(program, {
    onCrash: (error, message) => errors.push([error.message, message]),
  });
  island.send(cord('good'));
  island.send(cord('bad'));
  assert.equal(island.model, 1n);
  assert.equal(document.body.textContent, 'Count: 1');
  assert.deepEqual(errors, [['bad update', cord('bad')]]);
  island.send(cord('good'));
  assert.equal(island.model, 2n);
});

test('packed model resumption does not rerun init', () => {
  const program = counterProgram({
    init: () => { throw new Error('init must not run'); },
  });
  const { document, island } = setup(program, { packedModel: jam(41n) });
  assert.equal(island.model, 41n);
  assert.equal(document.body.textContent, 'Count: 41');
  island.send(cord('next'));
  assert.equal(island.model, 42n);
});

test('reentrant messages queue until the current update completes', () => {
  const log = [];
  let island;
  const program = counterProgram({
    update: ([message, model]) => {
      log.push(`${message}-start`);
      if (message === cord('outer')) island.send(cord('inner'));
      log.push(`${message}-end`);
      return [model + 1n, 0n];
    },
  });
  ({ island } = setup(program));
  island.send(cord('outer'));
  assert.deepEqual(log, [
    `${cord('outer')}-start`,
    `${cord('outer')}-end`,
    `${cord('inner')}-start`,
    `${cord('inner')}-end`,
  ]);
  assert.equal(island.model, 2n);
});

test('commands without a transport fail clearly after a successful patch', () => {
  const errors = [];
  const program = counterProgram({
    update: ([_message, model]) => [model + 1n, arrayToList([cord('command')])],
  });
  const { document, island } = setup(program, {
    onCrash: (error) => errors.push(error.message),
  });
  island.send(cord('next'));
  assert.equal(island.model, 1n);
  assert.equal(document.body.textContent, 'Count: 1');
  assert.deepEqual(errors, ['island commands need a dispatchCommand transport']);
});

test('field updates preserve the caret when the model already matches the screen', () => {
  const reply = (value) => [cord('typed'), value];
  const program = {
    init: () => cord('a'),
    update: ([message, _model]) => [message[1], 0n],
    view: (model) => rawSeal([cord('field'), [cord('Label'), [model, reply]]]),
  };
  const { document } = setup(program);
  const field = document.body.querySelector('input');
  field.focus();
  field.value = 'ab';
  field.setSelectionRange(2, 2);
  field.dispatchEvent(new FakeEvent('input', { target: field }));
  assert.equal(field.value, 'ab');
  assert.equal(field.selectionStart, 2);
  assert.equal(field.selectionEnd, 2);
  assert.equal(document.activeElement, field);
});

test('stop detaches the island and rejects later messages', () => {
  const { document, island } = setup();
  island.stop();
  assert.equal(document.body.childNodes.length, 0);
  assert.throws(() => island.send(cord('next')), /stopped island/);
});
