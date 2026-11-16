import { apply, atomToText, bytesToAtom } from '../core/runtime.mjs';
import { atom, cell, cord, listToArray, pair, text } from '../natives/helpers.mjs';
import { safeUrl } from './safe-url.mjs';
import { UrlRuntime } from './url.mjs';

const UNIX_EPOCH_SECONDS = 62_167_219_200n;
// A browser timer fires at once for a delay of 2^31 ms or more, so a longer
// one is a chain of shorter ones.
const LONGEST_TIMER = 2 ** 31 - 1;

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

// The text a failed request gives its reply: its HTTP status, if it got one.
const failure = error => cord(error?.message || 'request failed');

// What an island's subs declares, one entry per subscription. Watches
// match by agent and path, timers by gap; an entry's reply is the newest.
function declared(declaration) {
  const [kind, payload] = tag(declaration, 'subscription');
  if (kind === 'every') {
    const [gap, reply] = pair(payload, 'every subscription');
    return { kind, key: `every:${atom(gap, 'every gap')}`, gap, reply };
  }
  if (kind === 'url') return { kind, key: kind, reply: payload };
  if (kind !== 'watch') throw new Error(`unsupported subscription %${kind}`);
  const [requestKind, request] = tag(payload, 'watch request');
  if (requestKind === 'pure') return { kind: requestKind, message: request };
  if (requestKind === 'store') {
    const [module, rest] = pair(request, 'store request');
    const [name, receive] = pair(rest, 'store request');
    return { kind: requestKind, key: `store:${text(module)}:${text(name)}`, module, receive };
  }
  if (requestKind !== 'agent') throw new Error(`unsupported watch request %${requestKind}`);
  const [, rest] = pair(request, 'agent request');
  const [, agentRest] = pair(rest, 'agent request');
  const [agent, pathRest] = pair(agentRest, 'agent request');
  const [path, scryRest] = pair(pathRest, 'agent request');
  const [, receive] = pair(scryRest, 'agent request');
  const key = `${text(agent)}:${listToArray(path, 'watch path').map(text).join('/')}`;
  return { kind: requestKind, key, agent, path, receive };
}

export class Effects {
  constructor({
    island,
    channel,
    owner = 0n,
    now = () => dateFromMilliseconds(Date.now()),
    // A browser's own timers throw when called as another object's methods.
    setTimer = (callback, ms) => globalThis.setTimeout(callback, ms),
    clearTimer = handle => globalThis.clearTimeout(handle),
    setInterval = (callback, ms) => globalThis.setInterval(callback, ms),
    clearInterval = handle => globalThis.clearInterval(handle),
    navigate,
    stores,
    urlRuntime,
    window,
    document,
    defer = callback => queueMicrotask(callback),
  }) {
    if (!island || !channel) throw new TypeError('effects need an island and channel');
    Object.assign(this, {
      island, channel, owner, now, setTimer, clearTimer, setInterval, clearInterval,
      navigate, stores, urlRuntime, window, document, defer,
    });
    this.watches = new Map();
    this.timers = new Map();
    this.url = undefined;
    this.pokes = new Map();
    this.active = true;
    island.dispatchCommand = command => this.command(command);
    island.plan = model => this.plan(model);
    island.onUpdate = (_, plan) => plan && this.sync(plan);
    // A crash in the first subs is the island's, which goes on without them.
    if (island.active) {
      try {
        this.sync(this.plan(island.model));
      } catch (error) {
        island.fail(error);
      }
    }
  }

  plan(model) {
    const { subs } = this.island.program;
    return typeof subs === 'function'
      ? listToArray(apply(subs, model), 'island subscriptions').map(declared)
      : [];
  }

  // Start what the plan declares that isn't running, stop what it doesn't.
  sync(plan) {
    if (!this.active) return;
    const wanted = new Set();
    let pure = 0;
    for (const entry of plan) {
      if (entry.kind === 'pure') entry.key = `:pure:${pure++}`;
      wanted.add(entry.key);
      const running = entry.kind === 'every' ? this.timers.get(entry.key)
        : entry.kind === 'url' ? this.url : this.watches.get(entry.key);
      if (running) {
        running.reply = entry.reply;
        running.receive = entry.receive;
      } else if (entry.kind === 'every') {
        this.timers.set(entry.key, this.every(entry));
      } else if (entry.kind === 'url') {
        this.watchUrl(entry);
      } else {
        this.watches.set(entry.key, entry);
        if (entry.kind === 'pure') {
          this.island.send(entry.message);
          continue;
        }
        entry.state = 0n;
        if (entry.kind === 'store') {
          if (!this.stores) throw new Error('store watches require a store registry');
          entry.id = this.stores.watch(entry.module, event => this.receive(entry, [entry.state, event.noun]));
        } else {
          this.subscribe(entry);
        }
      }
    }
    for (const [key, watch] of this.watches) {
      if (!wanted.has(key)) {
        this.unwatch(watch);
        this.watches.delete(key);
      }
    }
    for (const [key, timer] of this.timers) {
      if (!wanted.has(key)) {
        timer.stop();
        this.timers.delete(key);
      }
    }
    if (this.url && !wanted.has('url')) {
      this.urlRuntime.unwatch(this.url.id);
      this.url = undefined;
    }
  }

  // A reply's message for the island, or the island's crash if the reply
  // crashes, as a crashed update would.
  deliver(reply, sample) {
    if (!this.active || !this.island.active) return;
    let message;
    try {
      message = apply(reply, sample);
    } catch (error) {
      this.island.fail(error);
      return;
    }
    this.island.send(message);
  }

  // Run callback after ms, through as many timers as that takes.
  after(ms, callback) {
    if (ms <= LONGEST_TIMER) {
      this.setTimer(callback, ms);
      return;
    }
    this.setTimer(() => {
      if (this.active) this.after(ms - LONGEST_TIMER, callback);
    }, LONGEST_TIMER);
  }

  every(entry) {
    const ms = durationMilliseconds(entry.gap);
    const tick = () => this.deliver(entry.reply, this.now());
    if (ms <= LONGEST_TIMER) {
      const handle = this.setInterval(tick, ms);
      entry.stop = () => this.clearInterval(handle);
    } else {
      const next = () => this.after(ms, () => {
        if (entry.stop === stop) {
          tick();
          next();
        }
      });
      const stop = () => { entry.stop = undefined; };
      entry.stop = stop;
      next();
    }
    return entry;
  }

  watchUrl(entry) {
    if (!this.urlRuntime) {
      this.urlRuntime = new UrlRuntime({ window: this.window, document: this.document, defer: this.defer });
    }
    this.url = entry;
    entry.id = this.urlRuntime.watch(path => this.deliver(entry.reply, path));
  }

  // An agent watch, under a fresh request id of the page's channel. A
  // subscription that can't be sent counts as refused, but for one a
  // closed channel didn't send, which a renewed channel sends again.
  subscribe(watch) {
    watch.id = this.channel.take(this);
    watch.state = 0n;
    const id = watch.id;
    Promise.resolve(this.channel.subscribe(id, this.owner, watch.agent, watch.path))
      .catch(error => this.channel.closed || this.refuse(id, failure(error)));
  }

  agentWatch(id) {
    for (const watch of this.watches.values()) {
      if (watch.kind === 'agent' && watch.id === id) return watch;
    }
  }

  // A refused watch shows the crash notice and stays refused, rather than
  // being tried again on every update, until subs stops declaring it.
  refuse(id, error) {
    const watch = this.agentWatch(id);
    if (!watch || !this.active) return;
    this.channel.drop(id);
    watch.id = undefined;
    watch.refused = true;
    this.island.fail(error, watch);
  }

  unwatch(watch) {
    if (watch.id === undefined) return;
    if (watch.kind === 'store') {
      this.stores.unwatch(watch.id);
    } else {
      this.channel.drop(watch.id);
      if (!this.channel.closed) {
        Promise.resolve(this.channel.unsubscribe(this.channel.take(), watch.id)).catch(() => {});
      }
    }
  }

  // A fact goes to its watch's receiver with the state it returned last;
  // a bad fact crashes the receiver, which counts as a crashed update.
  receive(watch, input) {
    if (!this.active || !this.island.active || this.watches.get(watch.key) !== watch) return;
    let state;
    let message;
    try {
      [state, message] = pair(apply(watch.receive, input), 'watch reply');
    } catch (error) {
      this.island.fail(error, watch);
      return;
    }
    watch.state = [0n, state];
    watch.kicks = 0;
    this.island.send(message);
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
        this.defer(() => this.deliver(reply, result));
        return;
      }
      if (agent !== 'agent') throw new Error(`unsupported poke %${agent}`);
      const [app, rest] = pair(markPayload, 'agent poke');
      const [mark, value] = pair(rest, 'agent poke');
      const id = this.channel.take(this);
      this.pokes.set(id, reply);
      Promise.resolve(this.channel.poke(id, this.owner, app, mark, value))
        .catch(error => this.answer(id, [0n, failure(error)]));
      return;
    }
    if (kind === 'go') {
      // Only where the server's links may go: anything else is ignored.
      const url = text(payload);
      if (!safeUrl(url)) return;
      if (typeof this.navigate === 'function') this.navigate(url);
      else if (this.urlRuntime) this.urlRuntime.go(url);
      else throw new Error('go needs a navigation transport');
      return;
    }
    if (kind === 'wait') {
      const [gap, message] = pair(payload, 'wait command');
      this.after(durationMilliseconds(gap), () => {
        if (this.active && this.island.active) this.island.send(message);
      });
      return;
    }
    if (kind === 'now') {
      this.deliver(payload, this.now());
      return;
    }
    if (kind === 'who') {
      this.deliver(payload, this.owner);
      return;
    }
    throw new Error(`unsupported command %${kind}`);
  }

  answer(id, result) {
    const reply = this.pokes.get(id);
    if (!reply) return;
    this.pokes.delete(id);
    this.channel.drop(id);
    this.deliver(reply, result);
  }

  // The channel's events for this island's requests.
  onPokeAck(id, sign) {
    const error = signError(sign);
    this.answer(id, error === undefined ? 0n : [0n, renderError(error)]);
  }

  onWatchAck(id, sign) {
    const error = signError(sign);
    if (error !== undefined) this.refuse(id, renderError(error));
  }

  onFact(id, mark, noun, eventId) {
    const watch = this.agentWatch(id);
    if (watch) this.receive(watch, [mark, [watch.state, noun]]);
    if (eventId !== undefined && eventId !== null) {
      Promise.resolve(this.channel.ack(eventId)).catch(() => {});
    }
  }

  // A kicked watch watches again from its first fact, after a delay that
  // doubles, from a second up to half a minute, while kicks come without
  // facts between them.
  onKick(id) {
    const watch = this.agentWatch(id);
    if (!watch) return;
    this.channel.drop(id);
    watch.id = undefined;
    watch.kicks = (watch.kicks ?? 0) + 1;
    this.after(Math.min(500 * 2 ** watch.kicks, 30_000), () => {
      if (this.active && this.watches.get(watch.key) === watch && watch.id === undefined && !watch.refused) {
        this.subscribe(watch);
      }
    });
  }

  // After the page comes back from the back/forward cache on a fresh
  // channel: pokes the old one carried get no ack, and agent watches start
  // again.
  resume() {
    if (!this.active) return;
    for (const id of [...this.pokes.keys()]) {
      this.answer(id, [0n, cord('the page was hidden before the poke was acknowledged')]);
    }
    for (const watch of this.watches.values()) {
      if (watch.kind === 'agent' && !watch.refused) {
        if (watch.id !== undefined) this.channel.drop(watch.id);
        this.subscribe(watch);
      }
    }
  }

  stop() {
    if (!this.active) return;
    this.active = false;
    for (const watch of this.watches.values()) this.unwatch(watch);
    this.watches.clear();
    for (const timer of this.timers.values()) timer.stop();
    this.timers.clear();
    if (this.url) this.urlRuntime.unwatch(this.url.id);
    this.url = undefined;
    for (const id of this.pokes.keys()) this.channel.drop(id);
    this.pokes.clear();
  }
}
