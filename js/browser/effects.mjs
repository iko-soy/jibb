import { apply, atomToText, bytesToAtom } from '../core/runtime.mjs';
import { cell, cord, listToArray, pair, text } from '../natives/helpers.mjs';
import { UrlRuntime } from './url.mjs';

const UNIX_EPOCH_SECONDS = 62_167_219_200n;

export function dateFromMilliseconds(milliseconds) {
  if (!Number.isSafeInteger(milliseconds) || milliseconds < 0) {
    throw new TypeError('milliseconds must be a nonnegative safe integer');
  }
  const unix = BigInt(milliseconds);
  const seconds = UNIX_EPOCH_SECONDS + unix / 1_000n;
  const fraction = (unix % 1_000n) * ((1n << 64n) / 1_000n);
  return (seconds << 64n) | fraction;
}

function durationMilliseconds(value) {
  return Number((value >> 64n) * 1_000n + ((value & 0xffff_ffff_ffff_ffffn) * 1_000n) / (1n << 64n));
}

function tag(value, operation) {
  const [head, tail] = cell(value, operation);
  return [text(head), tail];
}

function renderTank(tank) {
  if (typeof tank === 'bigint') return text(tank);
  const [kind, payload] = tag(tank, 'error tank');
  if (kind === 'leaf') {
    return atomToText(bytesToAtom(new Uint8Array(listToArray(payload, 'error leaf').map(value => Number(value)))));
  }
  return kind;
}

function signError(sign) {
  const [kind, payload] = tag(sign, 'channel sign');
  if (kind === 'ok') return undefined;
  if (kind === 'err') return payload;
  throw new Error(`unknown channel sign %${kind}`);
}

function renderError(error) {
  if (error === undefined || error === null) return cord('request failed');
  if (typeof error === 'bigint') return error;
  try {
    const lines = listToArray(error, 'error tang').map(renderTank);
    return cord(lines.join('\n'));
  } catch {
    return cord('request failed');
  }
}

export class Effects {
  constructor({
    island,
    channel,
    owner = 0n,
    now = () => dateFromMilliseconds(Date.now()),
    setTimer = globalThis.setTimeout,
    clearTimer = globalThis.clearTimeout,
    setInterval = globalThis.setInterval,
    clearInterval = globalThis.clearInterval,
    navigate,
    stores,
    urlRuntime,
    window,
    document,
    defer = queueMicrotask,
  }) {
    if (!island || !channel) throw new TypeError('effects need an island and channel');
    this.island = island;
    this.channel = channel;
    this.owner = owner;
    this.now = now;
    this.setTimer = setTimer;
    this.clearTimer = clearTimer;
    this.setInterval = setInterval;
    this.clearInterval = clearInterval;
    this.navigate = navigate;
    this.stores = stores;
    this.urlRuntime = urlRuntime;
    this.window = window;
    this.document = document;
    this.defer = defer;
    this.urlWatches = new Set();
    this.nextRequest = 1n;
    this.watches = new Map();
    this.intervals = new Map();
    this.pokes = new Map();
    this.active = true;
    this.channel.onPokeAck = (requestId, sign) => this.pokeAck({ requestId, error: signError(sign) });
    this.channel.onWatchAck = (requestId, sign) => this.watchAck({ requestId, error: signError(sign) });
    this.channel.onFact = (requestId, mark, noun, eventId) => this.fact({ requestId, eventId, mark, noun, kind: 'agent' });
    this.channel.onKick = (requestId) => this.kick({ requestId });
    this.island.dispatchCommand = (command) => this.command(command);
    this.island.onUpdate = () => this.sync();
    this.sync();
  }

  id() {
    const id = this.nextRequest;
    this.nextRequest += 1n;
    return id;
  }

  sync() {
    if (!this.active) return;
    const declarations = typeof this.island.program.subs === 'function'
      ? listToArray(apply(this.island.program.subs, this.island.model), 'island subscriptions')
      : [];
    const wanted = new Set();
    for (const declaration of declarations) {
      const [kind, payload] = tag(declaration, 'subscription');
      if (kind === 'watch') {
        const [requestKind, request] = tag(payload, 'watch request');
        if (requestKind === 'pure') {
          this.island.send(request);
          continue;
        }
        if (requestKind === 'store') {
          if (!this.stores) throw new Error('store watches require a store registry');
          const [module, rest] = pair(request, 'store request');
          const [name, receive] = pair(rest, 'store request');
          const key = `store:${text(module)}:${text(name)}`;
          wanted.add(key);
          if (!this.watches.has(key)) {
            const id = this.stores.watch(module, (event) => this.fact({ ...event, eventId: undefined, kind: 'store' }));
            this.watches.set(key, { id, key, kind: 'store', receive, state: 0n });
          }
          continue;
        }
        if (requestKind !== 'agent') throw new Error(`unsupported watch request %${requestKind}`);
        const [api, rest] = pair(request, 'agent request');
        const [caseName, agentRest] = pair(rest, 'agent request');
        const [agent, pathRest] = pair(agentRest, 'agent request');
        const [path, scryRest] = pair(pathRest, 'agent request');
        const [_scry, receive] = pair(scryRest, 'agent request');
        const key = `${text(agent)}:${listToArray(path, 'watch path').map(text).join('/')}`;
        wanted.add(key);
        if (!this.watches.has(key)) {
          const id = this.id();
          this.watches.set(key, {
            id, key, kind: 'agent', api, caseName, agent, path, receive,
            state: 0n,
            first: true,
          });
          this.channel.subscribe(id, this.owner, agent, path);
        }
      } else if (kind === 'every') {
        const [gap, reply] = pair(payload, 'every subscription');
        const key = gap.toString();
        wanted.add(key);
        if (!this.intervals.has(key)) {
          const handle = this.setInterval(() => {
            if (this.active) this.island.send(apply(reply, this.now()));
          }, durationMilliseconds(gap));
          this.intervals.set(key, handle);
        }
      } else if (kind === 'url') {
        wanted.add('url');
        if (this.urlWatches.size === 0) {
          if (!this.urlRuntime) {
            this.urlRuntime = new UrlRuntime({
              window: this.window,
              document: this.document,
              defer: this.defer,
            });
          }
          const id = this.urlRuntime.watch((path) => this.island.send(apply(payload, path)));
          this.urlWatches.add(id);
        }
      } else {
        throw new Error(`unsupported subscription %${kind}`);
      }
    }
    for (const [key, watch] of this.watches) {
      if (!wanted.has(key)) {
        if (watch.kind === 'store') this.stores.unwatch(watch.id);
        else this.channel.unsubscribe(this.id(), watch.id);
        this.watches.delete(key);
      }
    }
    for (const [key, handle] of this.intervals) {
      if (!wanted.has(key)) {
        this.clearInterval(handle);
        this.intervals.delete(key);
      }
    }
    if (!wanted.has('url')) {
      for (const id of this.urlWatches) this.urlRuntime.unwatch(id);
      this.urlWatches.clear();
    }
  }

  command(command) {
    if (!this.active) throw new Error('effects are stopped');
    const [kind, payload] = tag(command, 'command');
    if (kind === 'poke') {
      const [raw, reply] = pair(payload, 'poke command');
      const [agent, markPayload] = tag(raw, 'agent poke');
      if (agent === 'store') {
        if (!this.stores) throw new Error('store pokes require a store registry');
        const [module, rest] = pair(markPayload, 'store poke');
        const [action, value] = pair(rest, 'store poke');
        const result = this.stores.poke(module, action, value);
        this.defer(() => this.island.send(apply(reply, result)));
        return;
      }
      if (agent !== 'agent') throw new Error(`unsupported poke %${agent}`);
      const [app, rest] = pair(markPayload, 'agent poke');
      const [mark, value] = pair(rest, 'agent poke');
      const id = this.id();
      this.pokes.set(id, reply);
      this.channel.poke(id, this.owner, app, mark, value);
      return;
    }
    if (kind === 'go') {
      if (typeof this.navigate === 'function') this.navigate(text(payload));
      else if (this.urlRuntime) this.urlRuntime.go(text(payload));
      else throw new Error('go needs a navigation transport');
      return;
    }
    if (kind === 'wait') {
      const [gap, message] = pair(payload, 'wait command');
      this.setTimer(() => {
        if (this.active) this.island.send(message);
      }, durationMilliseconds(gap));
      return;
    }
    if (kind === 'now') {
      this.island.send(apply(payload, this.now()));
      return;
    }
    if (kind === 'who') {
      this.island.send(apply(payload, this.owner));
      return;
    }
    throw new Error(`unsupported command %${kind}`);
  }

  pokeAck({ requestId, error }) {
    const reply = this.pokes.get(requestId);
    if (!reply) return;
    this.pokes.delete(requestId);
    this.island.send(apply(reply, error === undefined ? 0n : [0n, renderError(error)]));
  }

  watchAck({ requestId, error }) {
    if (error === undefined) return;
    for (const watch of this.watches.values()) {
      if (watch.kind === 'agent' && watch.id === requestId) {
        this.watches.delete(watch.key);
        this.island.fail(renderError(error), watch);
        return;
      }
    }
  }

  fact({ requestId, eventId, mark, noun, kind = 'agent' }) {
    for (const watch of this.watches.values()) {
      if (watch.id !== requestId || watch.kind !== kind) continue;
      try {
        const [state, message] = pair(apply(watch.receive, [mark, [watch.state, noun]]), 'watch reply');
        watch.state = state;
        watch.first = false;
        this.island.send(message);
      } finally {
        if (eventId !== undefined) this.channel.ack(eventId);
      }
      return;
    }
  }

  kick({ requestId }) {
    for (const watch of this.watches.values()) {
      if (watch.kind === 'agent' && watch.id === requestId) {
        watch.state = 0n;
        watch.first = true;
        this.channel.subscribe(watch.id, this.owner, watch.agent, watch.path);
        return;
      }
    }
  }

  stop() {
    if (!this.active) return;
    this.active = false;
    for (const watch of this.watches.values()) {
      if (watch.kind === 'store') this.stores.unwatch(watch.id);
      else this.channel.unsubscribe(this.id(), watch.id);
    }
    this.watches.clear();
    for (const id of this.urlWatches) this.urlRuntime.unwatch(id);
    this.urlWatches.clear();
    for (const handle of this.intervals.values()) this.clearInterval(handle);
    this.intervals.clear();
    this.pokes.clear();
  }
}
