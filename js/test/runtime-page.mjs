// A page for browser-runtime tests: islands from Core modules, a fake
// window, and a fake Eyre that decodes channel PUTs and streams events.
import { compileCore } from '../core/compiler.mjs';
import { cue, decodeUw, encodeUw, jam } from '../natives/codec.mjs';
import { cord, listToArray, text } from '../natives/helpers.mjs';
import { nativeNames } from '../natives/index.mjs';
import { createFakeDocument } from './fake-dom.mjs';

const natives = nativeNames();
export const module = core => compileCore(core, { nativeNames: natives });
export const tick = () => new Promise(resolve => setTimeout(resolve, 0));
export async function settle(times = 6) {
  for (let index = 0; index < times; index += 1) await tick();
}

export function fakeWindow(pathname = '/apps/test') {
  const window = {
    navigations: [],
    pushed: [],
    listeners: {},
    addEventListener(type, fn) { (this.listeners[type] ??= []).push(fn); },
    removeEventListener(type, fn) { this.listeners[type] = (this.listeners[type] ?? []).filter(other => other !== fn); },
    dispatch(type, event = {}) { for (const fn of this.listeners[type] ?? []) fn(event); },
    location: {
      origin: 'https://ship.example',
      pathname,
      get href() { return `https://ship.example${this.pathname}`; },
      assign: url => window.navigations.push(url),
    },
    history: {
      pushState(state, title, url) {
        window.pushed.push(url);
        window.location.pathname = new URL(url, window.location.href).pathname;
      },
    },
  };
  return window;
}

// islands: [{ hash, model, server(document) → the server's nodes }]
export function page({ islands, stores = {}, sources, section }) {
  const document = createFakeDocument();
  const config = document.createElement('script');
  config.setAttribute('type', 'application/x-jibb-client');
  config.appendChild(document.createTextNode(JSON.stringify({
    base: '/apps/test', ship: '~zod', stores, assets: {}, section,
  })));
  document.body.appendChild(config);
  const containers = islands.map(({ hash, model, server }) => {
    const container = document.createElement('div');
    container.setAttribute('data-jibb-island', hash);
    let nodes = server?.(document);
    if (!nodes) {
      const first = document.createElement('p');
      first.appendChild(document.createTextNode('server view'));
      nodes = [first];
    }
    for (const node of nodes) container.appendChild(node);
    const state = document.createElement('script');
    state.setAttribute('type', 'application/x-jibb-state');
    state.appendChild(document.createTextNode(encodeUw(jam(model))));
    container.appendChild(state);
    document.body.appendChild(container);
    return container;
  });
  const load = async (url) => {
    const hash = /\/~jibb\/m\/([^/]+)\.js$/.exec(url)?.[1];
    if (!Object.hasOwn(sources, hash)) throw new Error(`no module at ${url}`);
    return import(`data:text/javascript;base64,${Buffer.from(sources[hash]).toString('base64')}`);
  };
  return { document, containers, load };
}

// A channel request as text, as [%poke 1 ...] reads: terms by name.
export function show(noun) {
  if (typeof noun === 'bigint') {
    try {
      const value = text(noun);
      if (/^[a-z][a-z0-9-]*$/.test(value)) return `%${value}`;
    } catch { /* Not text. */ }
    return String(noun);
  }
  return `[${show(noun[0])} ${show(noun[1])}]`;
}

// put(requests, url) answers a PUT's status; get(url) a GET's: a status, or
// undefined for a stream the test drives with event(), fact() and end().
export function fakeEyre({ put = () => 204, get = () => undefined } = {}) {
  const puts = [];
  const gets = [];
  const streams = [];
  const fetchImpl = async (url, init) => {
    if (init.method === 'PUT') {
      const requests = listToArray(cue(decodeUw(init.body)));
      puts.push({ url, requests, shown: requests.map(show), keepalive: init.keepalive });
      const status = put(requests, url);
      return { ok: status >= 200 && status < 300, status, statusText: status === 403 ? 'Forbidden' : '' };
    }
    gets.push({ url, headers: init.headers });
    const status = get(url);
    if (status !== undefined) {
      if (typeof status === 'object') return status;
      return { ok: status >= 200 && status < 300, status, statusText: status === 404 ? 'Not Found' : '' };
    }
    const queue = [];
    let wake;
    const stream = {
      push(chunk) { queue.push(chunk); wake?.(); },
    };
    streams.push(stream);
    init.signal?.addEventListener('abort', () => stream.push(null));
    const body = {
      async *[Symbol.asyncIterator]() {
        for (;;) {
          while (queue.length) {
            const chunk = queue.shift();
            if (chunk === null) return;
            yield chunk;
          }
          await new Promise(resolve => { wake = resolve; });
          wake = undefined;
        }
      },
    };
    return { ok: true, status: 200, body };
  };
  const frame = (id, requestId, event) => `id: ${id}\ndata: ${encodeUw(jam([requestId, event]))}\n\n`;
  const send = chunk => streams.at(-1).push(chunk);
  return {
    fetchImpl, puts, gets, streams, frame, send,
    event: (id, requestId, event) => send(frame(id, requestId, event)),
    fact: (id, requestId, mark, noun) => send(frame(id, requestId, [cord('fact'), [cord('desk'), [cord(mark), noun]]])),
    factFrame: (id, requestId, mark, noun) => frame(id, requestId, [cord('fact'), [cord('desk'), [cord(mark), noun]]]),
    pokeAck: (id, requestId) => send(frame(id, requestId, [cord('poke-ack'), 0n])),
    kick: (id, requestId) => send(frame(id, requestId, [cord('kick'), 0n])),
    end: () => streams.at(-1).push(null),
    // The requests of every PUT so far, of one kind, as [request-id rest].
    requests: kind => puts.flatMap(put => put.requests)
      .filter(request => request[0] === cord(kind))
      .map(request => request[1]),
  };
}

// The page's channel: request ids, and each request's events for the
// owner that took its id, as Channel routes Eyre's.
export class MockChannel {
  constructor() {
    this.subscriptions = [];
    this.unsubscriptions = [];
    this.pokes = [];
    this.acks = [];
    this.nextId = 1n;
    this.owners = new Map();
  }
  take(owner) {
    const id = this.nextId++;
    if (owner) this.owners.set(id, owner);
    return id;
  }
  drop(id) { this.owners.delete(id); }
  subscribe(...args) { this.subscriptions.push(args); }
  unsubscribe(...args) { this.unsubscriptions.push(args); }
  poke(...args) { this.pokes.push(args); }
  ack(id) { this.acks.push(id); }
  onFact(id, ...rest) { this.owners.get(id)?.onFact(id, ...rest); }
  onPokeAck(id, ...rest) { this.owners.get(id)?.onPokeAck(id, ...rest); }
  onWatchAck(id, ...rest) { this.owners.get(id)?.onWatchAck(id, ...rest); }
  onKick(id, ...rest) { this.owners.get(id)?.onKick(id, ...rest); }
}
