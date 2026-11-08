import { apply, same } from '../core/runtime.mjs';
import { cue } from '../natives/codec.mjs';
import { pair, listToArray } from '../natives/helpers.mjs';
import { createDom, patchDom, syncControls } from './dom.mjs';
import { toVnode } from './vdom.mjs';

export class Island {
  constructor({
    program,
    data = 0n,
    model,
    packedModel,
    container,
    document,
    dispatchCommand,
    onUpdate = () => {},
    onCrash = () => {},
  }) {
    if (!program || typeof program.init !== 'function'
      || typeof program.update !== 'function' || typeof program.view !== 'function') {
      throw new TypeError('an island needs init, update, and view gates');
    }
    if (!container || !document) throw new TypeError('an island needs a container and document');
    this.program = program;
    this.data = data;
    this.model = model;
    this.packedModel = packedModel;
    this.container = container;
    this.document = document;
    this.dispatchCommand = dispatchCommand;
    this.onUpdate = onUpdate;
    this.onCrash = onCrash;
    this.queue = [];
    this.processing = false;
    this.active = false;
    this.node = null;
    this.vnode = null;
  }

  start() {
    if (this.active) return this;
    try {
      if (this.model === undefined) {
        this.model = this.packedModel === undefined
          ? apply(this.program.init, this.data)
          : cue(this.packedModel);
      }
      this.vnode = toVnode(apply(this.program.view, this.model));
      this.node = createDom(this.vnode, {
        document: this.document,
        dispatch: (message) => this.send(message),
      });
      this.container.appendChild(this.node);
      this.active = true;
      syncControls(this.node, this.vnode);
      this.onUpdate(this);
      return this;
    } catch (error) {
      this.fail(error);
      return this;
    }
  }

  send(message) {
    if (!this.active) throw new Error('cannot send to a stopped island');
    this.queue.push(message);
    if (this.processing) return;
    this.processing = true;
    try {
      while (this.queue.length !== 0) {
        const current = this.queue.shift();
        try {
          this.update(current);
        } catch (error) {
          this.fail(error, current);
        }
      }
    } finally {
      this.processing = false;
    }
  }

  update(message) {
    const previous = this.model;
    const result = apply(this.program.update, [message, previous]);
    const [next, commands] = pair(result, 'island update result');
    if (same(previous, next) === 0n) {
      this.model = next;
      syncControls(this.node, this.vnode);
      this.runCommands(commands);
      this.onUpdate(this);
      return;
    }

    const vnode = toVnode(apply(this.program.view, next));
    const node = patchDom(this.container, this.node, vnode, {
      document: this.document,
      dispatch: (reply) => this.send(reply),
    });
    this.model = next;
    this.vnode = vnode;
    this.node = node;
    this.runCommands(commands);
    this.onUpdate(this);
  }

  runCommands(commands) {
    const items = listToArray(commands, 'island commands');
    if (items.length !== 0 && typeof this.dispatchCommand !== 'function') {
      throw new Error('island commands need a dispatchCommand transport');
    }
    for (const command of items) this.dispatchCommand(command, this);
  }

  fail(error, message) {
    this.onCrash(error, message, this);
  }

  stop() {
    if (!this.active) return;
    this.active = false;
    this.queue.length = 0;
    if (this.node.parentNode) this.node.parentNode.removeChild(this.node);
    this.node = null;
    this.vnode = null;
  }
}

export function startIsland(options) {
  return new Island(options).start();
}
