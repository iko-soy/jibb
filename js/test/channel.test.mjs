import assert from 'node:assert/strict';
import test from 'node:test';

import { Channel, installPagehide } from '../browser/channel.mjs';
import { cue, decodeUw, encodeUw, jam } from '../natives/codec.mjs';
import { arrayToList, cord, listToArray } from '../natives/helpers.mjs';

const okResponse = () => ({ ok: true, status: 200, statusText: 'OK', body: null });
const list = (...items) => arrayToList(items);
const okSign = () => [cord('ok'), 0n];
const packet = (requestId, event) => encodeUw(jam([requestId, event]));

function recordingFetch(responses = []) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    const response = responses.length === 0 ? okResponse() : responses.shift();
    if (typeof response === 'function') return response(url, init);
    return response;
  };
  return { calls, fetchImpl };
}

function putRequests(call) {
  return listToArray(cue(decodeUw(call.init.body)), 'test PUT requests');
}

function byteStream(value, width = 3) {
  const bytes = new TextEncoder().encode(value);
  return new ReadableStream({
    start(controller) {
      for (let offset = 0; offset < bytes.length; offset += width) {
        controller.enqueue(bytes.slice(offset, offset + width));
      }
      controller.close();
    },
  });
}

test('PUT methods emit exact channel-request nouns, headers, credentials, and @uw bodies', async () => {
  const { calls, fetchImpl } = recordingFetch();
  const channel = new Channel('test uid', { origin: 'https://ship.example/', fetchImpl });
  const ship = cord('~zod');
  const app = cord('jibb');
  const mark = cord('json');
  const noun = [cord('value'), 9007199254740993n];

  await channel.poke(9007199254740994n, ship, app, mark, noun);
  await channel.subscribe(2n, ship, app, '/one/two');
  await channel.subscribe(3n, ship, app, list(cord('three'), cord('four')));
  await channel.unsubscribe(4n, 2n);
  await channel.delete();

  assert.equal(calls.length, 5);
  const expected = [
    [cord('poke'), [9007199254740994n, [ship, [app, [mark, noun]]]]],
    [cord('subscribe'), [2n, [ship, [app, list(cord('one'), cord('two'))]]]],
    [cord('subscribe'), [3n, [ship, [app, list(cord('three'), cord('four'))]]]],
    [cord('unsubscribe'), [4n, 2n]],
    [cord('delete'), 0n],
  ];
  calls.forEach((call, index) => {
    assert.equal(call.url, 'https://ship.example/~/channel/test%20uid');
    assert.equal(call.init.method, 'PUT');
    assert.equal(call.init.credentials, 'include');
    assert.deepEqual(call.init.headers, { 'content-type': 'application/x-urb-jam' });
    assert.equal(typeof call.init.body, 'string');
    assert.deepEqual(putRequests(call), [expected[index]]);
  });

  assert.throws(() => channel.poke(1, ship, app, mark, noun), /expected an unsigned atom/);
});

test('request accepts a batch and ack accumulates synchronous calls into one PUT', async () => {
  const { calls, fetchImpl } = recordingFetch();
  const channel = new Channel({ uid: 'acks', fetchImpl });
  const poke = [cord('poke'), [8n, [cord('~zod'), [cord('app'), [cord('mark'), 0n]]]]];

  await channel.request([poke, [cord('delete'), 0n]]);
  assert.deepEqual(putRequests(calls[0]), [poke, [cord('delete'), 0n]]);

  const first = channel.ack(10n);
  const second = channel.ack(11n);
  await Promise.all([first, second]);
  assert.equal(calls.length, 2);
  assert.deepEqual(putRequests(calls[1]), [
    [cord('ack'), 10n],
    [cord('ack'), 11n],
  ]);

  await channel.ack(12n);
  assert.deepEqual(putRequests(calls[2]), [[cord('ack'), 12n]]);
});

test('connect parses split SSE frames, CRLF, comments, multiline data, and every event callback', async () => {
  const tang = list(cord('first trace'), [cord('second'), 42n]);
  const errorSign = [cord('err'), tang];
  const factNoun = [cord('answer'), 9007199254740993n];
  // As Eyre sends them: acks with a (unit tang), facts with their desk.
  const pokePayload = packet(21n, [cord('poke-ack'), 0n]);
  const splitAt = Math.floor(pokePayload.length / 2);
  const frames = [
    ': keepalive\r\n',
    'id: 100\r\n',
    `data: ${pokePayload.slice(0, splitAt)}\r\n`,
    `data: ${pokePayload.slice(splitAt)}\r\n\r\n`,
    'id: 101\n',
    `data: ${packet(22n, [cord('watch-ack'), [0n, tang]])}\n\n`,
    ': another comment\n',
    'id: 102\n',
    `data: ${packet(23n, [cord('fact'), [cord('my-app'), [cord('json'), factNoun]]])}\n\n`,
    'id: 103\n',
    `data: ${packet(24n, [cord('kick'), 0n])}\n\n`,
  ].join('');
  const { calls, fetchImpl } = recordingFetch([
    { ok: true, status: 200, body: byteStream(frames) },
  ]);
  const events = { poke: [], watch: [], fact: [], kick: [] };
  const channel = new Channel('events', {
    fetchImpl,
    onPokeAck: (...args) => events.poke.push(args),
    onWatchAck: (...args) => events.watch.push(args),
    onFact: (...args) => events.fact.push(args),
    onKick: (...args) => events.kick.push(args),
  });

  await channel.connect(99n);

  assert.equal(calls.length, 1);
  assert.equal(calls[0].init.method, 'GET');
  assert.equal(calls[0].init.credentials, 'include');
  assert.deepEqual(calls[0].init.headers, {
    'x-channel-format': 'application/x-urb-jam',
    'Last-Event-ID': '99',
  });
  assert.ok(calls[0].init.signal instanceof AbortSignal);
  assert.deepEqual(events.poke, [[21n, okSign(), 100n]]);
  assert.deepEqual(events.watch, [[22n, errorSign, 101n]]);
  assert.deepEqual(events.watch[0][1][1], tang);
  assert.deepEqual(events.fact, [[23n, cord('json'), factNoun, 102n]]);
  assert.deepEqual(events.kick, [[24n, okSign(), 103n]]);
  assert.equal(channel.lastEventId, 103n);
});

test('connect resumes from the last received SSE id when no explicit id is supplied', async () => {
  const frame = `id: 51\ndata: ${packet(1n, [cord('poke-ack'), 0n])}\n\n`;
  const { calls, fetchImpl } = recordingFetch([
    { ok: true, status: 200, body: byteStream(frame) },
    { ok: true, status: 200, body: byteStream('') },
  ]);
  const channel = new Channel('resume', { fetchImpl });

  await channel.connect();
  assert.equal(calls[0].init.headers['Last-Event-ID'], undefined);
  await channel.connect();
  assert.equal(calls[1].init.headers['Last-Event-ID'], '51');
});

test('reconnect replaces a missing channel and drops the stale resume id', async () => {
  const { calls, fetchImpl } = recordingFetch([
    { ok: false, status: 404, statusText: 'Not Found' },
    { ok: true, status: 200, body: byteStream(`id: 9\ndata: ${packet(1n, [cord('poke-ack'), 0n])}\n\n`) },
  ]);
  const events = [];
  const channel = new Channel('expired', {
    fetchImpl,
    freshUid: () => 'fresh',
    onPokeAck: (...args) => events.push(args),
  });
  await channel.reconnect();
  assert.equal(calls.length, 2);
  assert.match(calls[0].url, /expired$/);
  assert.match(calls[1].url, /fresh$/);
  assert.equal(calls[1].init.headers['Last-Event-ID'], undefined);
  assert.deepEqual(events, [[1n, okSign(), 9n]]);
});

test('non-2xx PUT and GET responses reject with their HTTP status', async () => {
  const put = recordingFetch([{ ok: false, status: 403, statusText: 'Forbidden' }]);
  const channel = new Channel('errors', { fetchImpl: put.fetchImpl });
  await assert.rejects(channel.delete(), error => {
    assert.equal(error.status, 403);
    assert.match(error.message, /403 Forbidden/);
    return true;
  });

  const errors = [];
  const get = recordingFetch([{ ok: false, status: 504, statusText: 'Gateway Timeout' }]);
  const streaming = new Channel('errors', {
    fetchImpl: get.fetchImpl,
    onError: error => errors.push(error),
  });
  await assert.rejects(streaming.connect(), /504 Gateway Timeout/);
  assert.equal(errors.length, 1);
  assert.equal(errors[0].status, 504);
});

test('close aborts an active connection without reporting an error', async () => {
  let observedSignal;
  const fetchImpl = async (url, init) => {
    observedSignal = init.signal;
    return new Promise((resolve, reject) => {
      init.signal.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
    });
  };
  const errors = [];
  const channel = new Channel('abort', { fetchImpl, onError: error => errors.push(error) });
  const connection = channel.connect();

  channel.close();
  await connection;
  assert.equal(observedSignal.aborted, true);
  assert.deepEqual(errors, []);
  assert.equal(channel.connection, null);
});

test('installPagehide sends delete, closes, and can be uninstalled', async () => {
  const { calls, fetchImpl } = recordingFetch();
  const listeners = new Map();
  const target = {
    addEventListener: (name, fn) => listeners.set(name, fn),
    removeEventListener: name => listeners.delete(name),
  };
  const channel = new Channel('pagehide', { fetchImpl });
  let closes = 0;
  channel.close = () => { closes += 1; };
  const uninstall = installPagehide(channel, target);

  listeners.get('pagehide')();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(closes, 1);
  assert.deepEqual(putRequests(calls[0]), [[cord('delete'), 0n]]);
  uninstall();
  assert.equal(listeners.has('pagehide'), false);
});
