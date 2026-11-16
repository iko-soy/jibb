import { apply, same } from '../core/runtime.mjs';
import { cue } from '../natives/codec.mjs';
import { pair, listToArray } from '../natives/helpers.mjs';
import { restoreSealedModel } from '../natives/legacy.mjs';
import { createDom, hydrateDom, patchDom, syncControls } from './dom.mjs';
import { toVnode } from './vdom.mjs';
import { createViewTemplate } from './template.mjs';

export class Island {
  constructor({
    program,
    data = 0n,
    model,
    packedModel,
    checkedInit = false,
    container,
    s,
    document,
    dispatchCommand,
    onUpdate = () => {},
    onCrash = () => {},
    paths,
  }) {
    if (!program || typeof program.init !== 'function'
      || typeof program.update !== 'function' || typeof program.view !== 'function') {
      throw new TypeError('an island needs init, update, and view gates');
    }
    if (!container || !document) throw new TypeError('an island needs a container and document');
    this.program = program;
    this.d = data;
    this.model = model;
    this.p = packedModel;
    this.c = checkedInit;
    this.container = container;
    this.s = s;
    this.document = document;
    this.dispatchCommand = dispatchCommand;
    this.onUpdate = onUpdate;
    this.onCrash = onCrash;
    this.r = paths;
    this.q = [];
    this.b = false;
    this.active = false;
    this.node = null;
    this.vnode = null;
    this.template = null;
  }

  start() {
    if (this.active) return this;
    try {
      if (this.model === undefined) {
        if (this.p === undefined) {
          this.model = apply(this.program.init, this.d);
        } else {
          const resumed = cue(this.p);
          this.model = this.c ? restoreSealedModel(resumed) : resumed;
        }
      }
      const value = apply(this.program.view, this.model);
      const options = {
        document: this.document,
        dispatch: (message) => this.send(message),
        paths: this.r,
      };
      // s holds the server's nodes for the first view, which adopts them
      // or replaces them all.
      const server = this.s?.length ? this.s : 0;
      options.s = server;
      this.template = createViewTemplate(this.program.view, value, options);
      this.vnode = this.template?.vnode ?? toVnode(value, this.r);
      this.node = this.template?.node ?? (server
        ? hydrateDom(server, this.vnode, options)
        : createDom(this.vnode, options));
      if (!server) this.container.appendChild(this.node);
      this.s = 0;
      this.active = true;
      this.onUpdate(this);
      return this;
    } catch (error) {
      this.fail(error);
      return this;
    }
  }

  send(message) {
    if (!this.active) throw new Error('cannot send to a stopped island');
    this.q.push(message);
    if (this.b) return;
    this.b = true;
    try {
      while (this.q.length !== 0) {
        const current = this.q.shift();
        try {
          this.update(current);
        } catch (error) {
          this.fail(error, current);
        }
      }
    } finally {
      this.b = false;
    }
  }

  // The message's model, view and subscriptions are all computed before
  // anything changes, so a crash in update, view or subs drops the message
  // and keeps the model, DOM and watches (overview: Errors). Commands then
  // run in list order.
  update(message) {
    const previous = this.model;
    const result = apply(this.program.update, [message, previous]);
    const [next, commands] = pair(result, 'island update result');
    const items = listToArray(commands, 'island commands');
    const render = same(previous, next) === 0n ? 0 : this.render(next);
    const plan = this.plan?.(next);
    this.model = next;
    if (render) render();
    else syncControls(this.node, this.vnode);
    this.onUpdate(this, plan);
    if (items.length !== 0 && typeof this.dispatchCommand !== 'function') {
      throw new Error('island commands need a dispatchCommand transport');
    }
    for (const command of items) this.dispatchCommand(command, this);
  }

  // A function that shows next's view, made without touching the DOM.
  render(next) {
    if (this.template?.view === this.program.view) return this.template.update(next);
    const vnode = toVnode(apply(this.program.view, next), this.r);
    return () => {
      this.node = patchDom(this.container, this.node, vnode, {
        document: this.document,
        dispatch: (reply) => this.send(reply),
      });
      this.vnode = vnode;
      this.template = null;
    };
  }

  fail(error, message) {
    this.onCrash(error, message, this);
  }

  stop() {
    if (!this.active) return;
    this.active = false;
    this.q.length = 0;
    if (this.node.parentNode) this.node.parentNode.removeChild(this.node);
    this.node = null;
    this.vnode = null;
    this.template = null;
  }
}

export function startIsland(options) {
  return new Island(options).start();
}
