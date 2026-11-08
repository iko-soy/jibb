import { cue, decodeUw, encodeUw, jam } from '../natives/codec.mjs';
import { arrayToList, atom, cell, cord, listToArray, text } from '../natives/helpers.mjs';

const CHANNEL_FORMAT = 'application/x-urb-jam';

function httpError(response) {
  const status = response.status;
  const suffix = response.statusText ? ` ${response.statusText}` : '';
  const error = new Error(`Eyre channel HTTP ${status}${suffix}`);
  error.status = status;
  error.response = response;
  return error;
}

function requireOk(response) {
  const ok = typeof response.ok === 'boolean'
    ? response.ok
    : response.status >= 200 && response.status < 300;
  if (!ok) throw httpError(response);
  return response;
}

function normalizeRequests(first, rest) {
  if (rest.length !== 0) return [first, ...rest];
  if (first === undefined) return [];
  if (Array.isArray(first) && (first.length === 0 || Array.isArray(first[0]))) {
    return first;
  }
  return [first];
}

function normalizePath(path) {
  if (typeof path === 'string') {
    return arrayToList(path.split('/').filter(Boolean).map(cord));
  }

  // Prefer the noun interpretation when a two-atom cell is a proper one-knot
  // list. Otherwise, also accept a JavaScript array of knot atoms.
  if (Array.isArray(path)) {
    try {
      const knots = listToArray(path, 'channel path');
      for (const knot of knots) atom(knot, 'channel path knot');
      return path;
    } catch {
      if (path.every(knot => typeof knot === 'bigint' && knot >= 0n)) {
        return arrayToList(path);
      }
      throw new TypeError('channel path must be a slash string or a list of knot atoms');
    }
  }

  const knots = listToArray(path, 'channel path');
  for (const knot of knots) atom(knot, 'channel path knot');
  return path;
}

function decodeSign(value) {
  const [tag, payload] = cell(value, 'channel sign');
  switch (text(tag)) {
    case 'ok':
      if (payload !== 0n) throw new Error('channel %ok sign must have a ~ tail');
      break;
    case 'err':
      // The payload is the application-supplied tang noun, left uninterpreted.
      break;
    default:
      throw new Error(`unknown channel sign %${text(tag)}`);
  }
  return value;
}

function eventId(value) {
  try {
    return BigInt(value);
  } catch {
    throw new Error(`invalid SSE event id ${JSON.stringify(value)}`);
  }
}

class EventStreamParser {
  constructor(dispatch, initialEventId) {
    this.dispatch = dispatch;
    this.buffer = '';
    this.data = [];
    this.id = initialEventId === null ? null : String(initialEventId);
  }

  push(chunk) {
    this.buffer += chunk;
    while (true) {
      const match = /[\r\n]/.exec(this.buffer);
      if (match === null) return;
      const index = match.index;
      if (this.buffer[index] === '\r' && index + 1 === this.buffer.length) return;
      const line = this.buffer.slice(0, index);
      const width = this.buffer[index] === '\r' && this.buffer[index + 1] === '\n' ? 2 : 1;
      this.buffer = this.buffer.slice(index + width);
      this.line(line);
    }
  }

  finish() {
    if (this.buffer !== '') {
      const line = this.buffer.endsWith('\r') ? this.buffer.slice(0, -1) : this.buffer;
      this.buffer = '';
      this.line(line);
    }
    this.dispatchEvent();
  }

  line(line) {
    if (line === '') {
      this.dispatchEvent();
      return;
    }
    if (line.startsWith(':')) return;

    const colon = line.indexOf(':');
    const field = colon === -1 ? line : line.slice(0, colon);
    let value = colon === -1 ? '' : line.slice(colon + 1);
    if (value.startsWith(' ')) value = value.slice(1);

    if (field === 'data') {
      this.data.push(value);
    } else if (field === 'id' && !value.includes('\0')) {
      this.id = value === '' ? null : value;
    }
  }

  dispatchEvent() {
    if (this.data.length === 0) {
      this.id = null;
      return;
    }
    // A channel payload is one @uw token. Concatenation also accepts a token
    // split across SSE data lines without introducing insignificant newlines.
    const encoded = this.data.join('').trim();
    const id = this.id;
    this.data = [];
    this.id = null;
    this.dispatch(encoded, id === null ? null : eventId(id));
  }
}

async function *chunks(body) {
  if (typeof body.getReader === 'function') {
    const reader = body.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) return;
        yield value;
      }
    } finally {
      reader.releaseLock?.();
    }
  } else if (body[Symbol.asyncIterator] !== undefined) {
    yield * body;
  } else {
    throw new Error('Eyre channel response has no readable body');
  }
}

export class Channel {
  constructor(uid, options = {}) {
    if (typeof uid === 'object' && uid !== null) {
      options = uid;
      uid = options.uid;
    }
    if ((typeof uid !== 'string' && typeof uid !== 'number') || String(uid) === '') {
      throw new TypeError('Channel requires a channel uid');
    }

    const base = options.origin ?? options.baseUrl ?? '';
    this.base = base.replace(/\/+$/, '');
    this.freshUid = options.freshUid ?? (() => globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-jibb`);
    this.uid = String(uid);
    this.url = `${this.base}/~/channel/${encodeURIComponent(this.uid)}`;
    this.fetchImpl = options.fetchImpl ?? globalThis.fetch;
    if (typeof this.fetchImpl !== 'function') throw new TypeError('Channel requires fetchImpl');

    this.onPokeAck = options.onPokeAck ?? (() => {});
    this.onWatchAck = options.onWatchAck ?? (() => {});
    this.onFact = options.onFact ?? (() => {});
    this.onKick = options.onKick ?? (() => {});
    this.onError = options.onError ?? (() => {});

    this.lastEventId = null;
    this.abortController = null;
    this.connection = null;
    this.pendingAcks = [];
    this.ackScheduled = false;
  }

  async request(requests, ...rest) {
    const batch = normalizeRequests(requests, rest);
    const body = encodeUw(jam(arrayToList(batch)));
    const response = await this.fetchImpl(this.url, {
      method: 'PUT',
      credentials: 'include',
      headers: { 'content-type': CHANNEL_FORMAT },
      body,
    });
    requireOk(response);
  }

  poke(requestId, ship, app, mark, noun) {
    atom(requestId, 'channel poke request-id');
    return this.request([cord('poke'), [requestId, [ship, [app, [mark, noun]]]]]);
  }

  subscribe(requestId, ship, app, path) {
    atom(requestId, 'channel subscribe request-id');
    return this.request([cord('subscribe'), [requestId, [ship, [app, normalizePath(path)]]]]);
  }

  unsubscribe(requestId, subscriptionId) {
    atom(requestId, 'channel unsubscribe request-id');
    atom(subscriptionId, 'channel unsubscribe subscription-id');
    return this.request([cord('unsubscribe'), [requestId, subscriptionId]]);
  }

  ack(eventId) {
    atom(eventId, 'channel ack event-id');
    return new Promise((resolve, reject) => {
      this.pendingAcks.push({ eventId, resolve, reject });
      if (!this.ackScheduled) {
        this.ackScheduled = true;
        queueMicrotask(() => { this.flushAcks(); });
      }
    });
  }

  async flushAcks() {
    const pending = this.pendingAcks;
    this.pendingAcks = [];
    this.ackScheduled = false;
    try {
      await this.request(pending.map(({ eventId }) => [cord('ack'), eventId]));
      for (const { resolve } of pending) resolve();
    } catch (error) {
      for (const { reject } of pending) reject(error);
    }
  }

  delete() {
    return this.request([cord('delete'), 0n]);
  }

  connect(lastEventId) {
    if (this.connection !== null) return this.connection;
    if (lastEventId !== undefined) atom(lastEventId, 'channel Last-Event-ID');
    const resumeId = lastEventId === undefined ? this.lastEventId : lastEventId;
    const controller = new AbortController();
    this.abortController = controller;

    const connection = this.runEventStream(resumeId, controller.signal)
      .catch(error => {
        if (controller.signal.aborted) return;
        try { this.onError(error); } catch { /* Error callbacks cannot break cleanup. */ }
        throw error;
      })
      .finally(() => {
        if (this.connection === connection) this.connection = null;
        if (this.abortController === controller) this.abortController = null;
      });
    this.connection = connection;
    return connection;
  }

  async runEventStream(resumeId, signal) {
    const headers = { 'x-channel-format': CHANNEL_FORMAT };
    if (resumeId !== null) headers['Last-Event-ID'] = String(resumeId);
    const response = await this.fetchImpl(this.url, {
      method: 'GET',
      credentials: 'include',
      headers,
      signal,
    });
    requireOk(response);
    if (response.body === null || response.body === undefined) {
      throw new Error('Eyre channel response has no readable body');
    }

    const decoder = new TextDecoder();
    const parser = new EventStreamParser((encoded, id) => {
      const decoded = cue(decodeUw(encoded));
      const [requestId, event] = cell(decoded, 'channel SSE packet');
      atom(requestId, 'channel SSE request-id');
      if (id !== null) this.lastEventId = id;
      this.dispatchEvent(requestId, event, id);
    }, resumeId);

    for await (const chunk of chunks(response.body)) {
      if (signal.aborted) return;
      parser.push(typeof chunk === 'string' ? chunk : decoder.decode(chunk, { stream: true }));
    }
    parser.push(decoder.decode());
    if (!signal.aborted) parser.finish();
  }

  dispatchEvent(requestId, event, eventId = null) {
    const [tag, payload] = cell(event, 'channel event');
    switch (text(tag)) {
      case 'poke-ack':
        this.onPokeAck(requestId, decodeSign(payload), eventId);
        return;
      case 'watch-ack':
        this.onWatchAck(requestId, decodeSign(payload), eventId);
        return;
      case 'kick':
        this.onKick(requestId, decodeSign(payload), eventId);
        return;
      case 'fact': {
        const [mark, noun] = cell(payload, 'channel fact');
        this.onFact(requestId, mark, noun, eventId);
        return;
      }
      default:
        throw new Error(`unknown channel event %${text(tag)}`);
    }
  }

  async reconnect() {
    try {
      return await this.connect();
    } catch (error) {
      if (error.status !== 404) throw error;
      this.uid = this.freshUid();
      this.url = `${this.base}/~/channel/${encodeURIComponent(this.uid)}`;
      this.lastEventId = null;
      return this.connect();
    }
  }

  close() {
    this.abortController?.abort();
  }
}

export function installPagehide(channel, target = globalThis) {
  if (typeof target.addEventListener !== 'function') {
    throw new TypeError('installPagehide requires an event target');
  }
  const onPagehide = () => {
    try {
      Promise.resolve(channel.delete()).catch(error => {
        try { channel.onError?.(error); } catch { /* Pagehide cannot recover. */ }
      });
    } catch (error) {
      try { channel.onError?.(error); } catch { /* Pagehide cannot recover. */ }
    } finally {
      channel.close();
    }
  };
  target.addEventListener('pagehide', onPagehide);
  return () => target.removeEventListener('pagehide', onPagehide);
}
