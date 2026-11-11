// Drives headless Chromium through the DevTools protocol against a fake ship
// serving the host, my-app and the host fixture: worked example 3, the
// Grammar tab's store example, shared modules across pages, the crash notice,
// and the benchmark's list island under a 4x CPU slowdown. tools/check-browser runs it once the
// desks have built. Prints one line per result; exits 1 on any failure.

import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).map(arg => {
  const [name, ...rest] = arg.replace(/^--/, '').split('=');
  return [name, rest.join('=')];
}));
const origin = args.origin;
const password = args.password;
const chromium = args.chromium || process.env.JIBB_CHROMIUM || 'chromium';
// The proposed bar (Open questions) is a keystroke in a 500-row list island
// within one 16 ms frame on a mid-range phone, which a 4x slowdown stands
// for. Until a bar is agreed the benchmark reports its times; --bar=16
// makes them pass or fail.
const BAR_MS = args.bar ? Number(args.bar) : undefined;
const KEYSTROKES = Number(args.keystrokes || 40);
const NOTICE = 'This part of the page stopped working. Reloading the page may fix it.';

if (!origin || !password) {
  console.error('usage: browser-check.mjs --origin=http://127.0.0.1:PORT --password=CODE');
  process.exit(2);
}

const failures = [];
function expect(condition, message) {
  if (!condition) {
    failures.push(message);
    console.log(`FAIL ${message}`);
  }
  return condition;
}

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function launch() {
  const profile = mkdtempSync(join(tmpdir(), 'jibb-chromium-'));
  // The Nix sandbox's HOME is not writable, and its /dev/shm may be small.
  const child = spawn(chromium, [
    '--headless=new', '--no-sandbox', '--disable-gpu', '--no-first-run',
    '--no-default-browser-check', '--disable-extensions', '--disable-dev-shm-usage',
    '--disable-crash-reporter', '--disable-breakpad', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'], env: { ...process.env, HOME: profile } });
  // Chromium's own output, kept to show when a step fails.
  let output = '';
  const endpoint = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Chromium did not start: ${output}`)), 60_000);
    child.stderr.on('data', chunk => {
      output = (output + chunk).slice(-20_000);
      const match = /DevTools listening on (ws:\/\/\S+)/.exec(output);
      if (match) {
        clearTimeout(timer);
        resolve(match[1]);
      }
    });
    child.on('error', error => reject(new Error(`Chromium did not start: ${error.message}`)));
    child.on('exit', code => reject(new Error(`Chromium exited with ${code}: ${output}`)));
  });
  return {
    endpoint,
    output: () => output,
    close() {
      child.kill('SIGKILL');
      try { rmSync(profile, { recursive: true, force: true }); } catch { /* best effort */ }
    },
  };
}

// A failed load outside the desks under test and Eyre's channel, as of
// the ship's default app on a fresh fake ship, is no fault of theirs.
const TESTED = ['/apps/my-app', '/apps/jibb-host-fixture', '/~/channel'];
function tested(entry) {
  if (entry.source !== 'network' || !entry.url) return true;
  const { pathname } = new URL(entry.url);
  return TESTED.some(base => pathname === base || pathname.startsWith(`${base}/`));
}

// One flattened DevTools session over the browser's WebSocket.
class Session {
  static async open(endpoint) {
    const socket = new WebSocket(endpoint);
    await new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve, { once: true });
      socket.addEventListener('error', reject, { once: true });
    });
    const session = new Session(socket);
    const { targetId } = await session.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await session.send('Target.attachToTarget', { targetId, flatten: true });
    session.sessionId = sessionId;
    await session.send('Page.enable');
    await session.send('Runtime.enable');
    await session.send('Log.enable');
    return session;
  }

  constructor(socket) {
    this.socket = socket;
    this.next = 1;
    this.pending = new Map();
    this.sessionId = undefined;
    this.problems = [];
    this.waiters = [];
    socket.addEventListener('message', event => this.receive(JSON.parse(event.data)));
  }

  receive(message) {
    if (message.id !== undefined) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(`${pending.method}: ${message.error.message}`));
      else pending.resolve(message.result);
      return;
    }
    const { method, params } = message;
    if (method === 'Runtime.exceptionThrown') {
      this.problems.push(`uncaught: ${params.exceptionDetails.exception?.description ?? params.exceptionDetails.text}`);
    } else if (method === 'Runtime.consoleAPICalled' && params.type === 'error') {
      this.problems.push(`console error: ${params.args.map(a => a.value ?? a.description).join(' ')}`);
    } else if (method === 'Log.entryAdded' && params.entry.level === 'error' && tested(params.entry)) {
      this.problems.push(`log: ${params.entry.text}${params.entry.url ? ` (${params.entry.url})` : ''}`);
    }
    this.waiters = this.waiters.filter(waiter => !waiter(method, params));
  }

  // Every call has an answer within a minute, or fails; a hung browser
  // fails the check rather than leaving it waiting.
  send(method, params = {}) {
    const id = this.next++;
    const message = { id, method, params };
    if (this.sessionId !== undefined && !method.startsWith('Target.')) message.sessionId = this.sessionId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} had no answer in 60 s`));
      }, 60_000);
      this.pending.set(id, {
        resolve: value => { clearTimeout(timer); resolve(value); },
        reject: error => { clearTimeout(timer); reject(error); },
        method,
      });
      this.socket.send(JSON.stringify(message));
    });
  }

  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {
      expression, awaitPromise: true, returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(`evaluate: ${result.exceptionDetails.exception?.description ?? result.exceptionDetails.text}`);
    }
    return result.result.value;
  }

  async navigate(url) {
    let timer;
    const loaded = new Promise((resolve, reject) => {
      timer = setTimeout(() => reject(new Error(`${url} did not load in 120 s`)), 120_000);
      this.waiters.push(method => {
        if (method !== 'Page.loadEventFired') return false;
        clearTimeout(timer);
        resolve();
        return true;
      });
    });
    const { errorText } = await this.send('Page.navigate', { url });
    if (errorText) {
      clearTimeout(timer);
      throw new Error(`${url} did not load: ${errorText}`);
    }
    await loaded;
  }

  async until(what, expression, timeout = 60_000) {
    const deadline = Date.now() + timeout;
    let last;
    while (Date.now() < deadline) {
      try {
        last = await this.evaluate(expression);
        if (last) return last;
      } catch (error) {
        last = error.message;
      }
      await sleep(100);
    }
    throw new Error(`timed out waiting for ${what}: ${JSON.stringify(last)}`);
  }

  // A real click at the element's centre.
  async click(selector) {
    const box = await this.evaluate(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return null;
      el.scrollIntoView({ block: 'center' });
      const r = el.getBoundingClientRect();
      return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    })()`);
    if (!box) throw new Error(`nothing to click at ${selector}`);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await this.send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: 'left', clickCount: 1 });
    }
  }

  async focus(selector) {
    await this.evaluate(`document.querySelector(${JSON.stringify(selector)}).focus()`);
  }

  async type(text) {
    await this.send('Input.insertText', { text });
  }

  takeProblems() {
    const problems = this.problems;
    this.problems = [];
    return problems;
  }
}

// The text of a page's islands, and whether each has started: a started
// island has no server state script and no read-only field.
const ISLANDS = `[...document.querySelectorAll('[data-jibb-island]')].map(island => ({
  text: island.textContent,
  started: !island.querySelector('script[type="application/x-jibb-state"]')
    && !island.querySelector('input[readonly]'),
  notice: island.querySelector('[data-jibb-notice]')?.textContent ?? null,
}))`;

// Every island on the page has started, and there is one.
const STARTED = `(() => { const islands = ${ISLANDS}; return islands.length > 0 && islands.every(i => i.started); })()`;

// Protect the known static layout, while controls and keyed lists remain free
// to use ordinary patching inside element holes. A changed view rendered by
// the ordinary whole-tree diff would enumerate one of these attribute bags.
// Inspecting the emitted JavaScript for a particular source name would not
// prove that the browser actually used its template.
async function guardStaticLayout(session, selectors) {
  await session.evaluate(`(() => {
    const container = document.querySelector('[data-jibb-island]');
    const visits = [];
    const nodes = Object.fromEntries(Object.entries(${JSON.stringify(selectors)}).map(([name, selector]) => {
      const node = container.querySelector(selector);
      if (!node?.__jibb?.vnode?.attrs) throw new Error('missing managed static node: ' + name);
      const attributes = [...node.attributes].map(({ name, value }) => [name, value]);
      node.__jibb.vnode.attrs = new Proxy(node.__jibb.vnode.attrs, {
        ownKeys() {
          visits.push(name);
          throw new Error('template update revisited static attributes: ' + name);
        },
      });
      return [name, { node, selector, attributes }];
    }));
    window.jibbTemplateGuard = { container, nodes, visits };
  })()`);
}

async function checkStaticLayout(session, label) {
  const state = await session.evaluate(`(() => {
    const { container, nodes, visits } = window.jibbTemplateGuard;
    return {
      visits,
      notice: container.querySelector('[data-jibb-notice]')?.textContent ?? null,
      changed: Object.entries(nodes).filter(([, { node, selector, attributes }]) =>
        !node.isConnected || node !== container.querySelector(selector)
        || node.attributes.length !== attributes.length
        || attributes.some(([name, value]) => node.getAttribute(name) !== value)
      ).map(([name]) => name),
    };
  })()`);
  expect(state.visits.length === 0, `${label} revisited static attributes: ${state.visits.join(', ')}`);
  expect(state.changed.length === 0, `${label} changed static DOM or attributes: ${state.changed.join(', ')}`);
  expect(state.notice === null, `${label} showed a crash notice: ${state.notice}`);
}

async function login(session) {
  await session.navigate(`${origin}/~/login`);
  const status = await session.evaluate(`fetch('/~/login', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: 'password=${password}',
    redirect: 'manual',
  }).then(response => response.status)`);
  expect([200, 204, 303, 0].includes(status), `owner login answered ${status}`);
  session.takeProblems();
}

async function exampleThree(session) {
  const page = `${origin}/apps/my-app`;
  await session.navigate(page);
  const server = await session.evaluate('document.documentElement.outerHTML');
  expect(server.includes('>My ship</h1>'), 'worked example 3 lost its heading');
  expect(/<input type="text" value="" aria-label="New todo" readonly="">/.test(
    await session.evaluate(`fetch(location.href).then(r => r.text())`)),
  'the server rendered the todo field writable before its island started');
  await session.until('the todo island to start', STARTED);
  const field = '[data-jibb-island] input[type="text"]';
  const add = '[data-jibb-island] button';
  await guardStaticLayout(session, {
    column: ':scope > .j-column',
    heading: ':scope > .j-column > h2',
    row: ':scope > .j-column > .j-row',
    fieldFrame: ':scope > .j-column > .j-row > .j-el',
    error: ':scope > .j-column > .j-tone-danger',
  });
  const styled = await session.evaluate(`(() => {
    const { container, nodes } = window.jibbTemplateGuard;
    const each = container.querySelector('[data-each]');
    window.jibbTodoNodes = {
      field: container.querySelector('input[type="text"]'),
      button: container.querySelector('button'),
      each,
      rows: [...each.children].map(node => [node.__jibb.vnode.key, node]),
    };
    return nodes.column.node.classList.contains('j-gap-s2')
      && nodes.row.node.classList.contains('j-gap-s1')
      && nodes.fieldFrame.node.style.flex === '1 1 0%'
      && parseFloat(nodes.fieldFrame.node.style.minWidth) === 0
      && nodes.error.node.getAttribute('aria-live') === 'polite';
  })()`);
  expect(styled, 'the todo template lost its constant gap, width or danger-tone attributes');
  const stamp = Date.now();
  const item = `Buy milk ${stamp}`;
  await session.focus(field);
  await session.type(`Buy ${stamp}`);
  await session.evaluate('window.jibbTodoNodes.field.setSelectionRange(4, 4)');
  await session.type('milk ');
  expect(await session.evaluate(`(() => {
    const { field } = window.jibbTodoNodes;
    return field === document.querySelector(${JSON.stringify(field)})
      && field === document.activeElement && field.value === ${JSON.stringify(item)}
      && field.selectionStart === 9 && field.selectionEnd === 9;
  })()`), 'the todo template replaced its field or moved the caret during a middle insertion');
  await session.click(add);
  await session.until('the new todo from the agent',
    `!!document.querySelector('[data-jibb-island] input[type="checkbox"][aria-label=${JSON.stringify(item)}]')`);
  expect(await session.evaluate(`document.querySelector(${JSON.stringify(field)}).value`) === '',
    'the todo field was not cleared after Add');
  const toggle = `[data-jibb-island] input[type="checkbox"][aria-label=${JSON.stringify(item)}]`;
  expect(await session.evaluate(`(() => {
    const { each, rows, button } = window.jibbTodoNodes;
    const current = new Map([...each.children].map(node => [node.__jibb.vnode.key, node]));
    window.jibbTodoNodes.toggle = document.querySelector(${JSON.stringify(toggle)});
    return each === document.querySelector('[data-jibb-island] [data-each]')
      && button === document.querySelector(${JSON.stringify(add)})
      && rows.every(([key, node]) => current.get(key) === node);
  })()`), 'adding a todo replaced the keyed list, an existing row or the Add control');
  expect(!(await session.evaluate(`document.querySelector(${JSON.stringify(toggle)}).checked`)),
    'a new todo started done');
  await session.click(toggle);
  await session.until('the toggled todo from the agent',
    `document.querySelector(${JSON.stringify(toggle)}).checked`);
  expect(await session.evaluate(`window.jibbTodoNodes.toggle === document.querySelector(${JSON.stringify(toggle)})
    && document.activeElement === window.jibbTodoNodes.toggle`),
  'the todo fact replaced its toggle or lost its focus');
  // update's validation: more than 80 characters shows an error at once.
  await session.focus(field);
  await session.type('x'.repeat(81));
  await session.until('the length error', `document.querySelector('[data-jibb-island]').textContent.includes('Too long')`);
  await session.evaluate('window.jibbTodoNodes.field.setSelectionRange(0, 81)');
  await session.type('ok');
  await session.until('the length error to clear',
    `window.jibbTemplateGuard.nodes.error.node.textContent === ''`);
  expect(await session.evaluate(`(() => {
    const { field } = window.jibbTodoNodes;
    return field === document.querySelector(${JSON.stringify(field)})
      && document.activeElement === field && field.value === 'ok'
      && field.selectionStart === 2 && field.selectionEnd === 2;
  })()`), 'the todo template lost field identity, focus or selection while clearing validation');
  await checkStaticLayout(session, 'the todo template');
  // A fresh scry renders the new todo on the server too.
  await session.navigate(page);
  const fresh = await session.evaluate(`fetch(location.href).then(r => r.text())`);
  expect(fresh.includes(`aria-label="${item}" checked=""`),
    'the page did not render the toggled todo from a fresh scry');
  await session.until('the todo island to start again', STARTED);
  const problems = session.takeProblems();
  expect(problems.length === 0, `worked example 3 logged: ${problems.join('; ')}`);
  console.log('ok   worked example 3: compiled layout keeps controls and keyed rows while adding and toggling a todo through the %todo agent');
}

async function storeExample(session) {
  await session.navigate(`${origin}/apps/my-app/shop`);
  await session.until('both baskets to start', `(() => { const i = ${ISLANDS}; return i.length === 2 && i.every(x => x.started); })()`);
  const islands = await session.evaluate(ISLANDS);
  expect(islands.every(island => island.text.includes('0 items')), `the baskets did not start empty: ${JSON.stringify(islands)}`);
  // The first basket adds an item; the second shows it too.
  await session.focus('[data-jibb-island] input');
  await session.type('apple');
  await session.click('[data-jibb-island] button');
  await session.until('the shared cart in both baskets',
    `(${ISLANDS}).every(i => i.text.includes('1 items'))`);
  const problems = session.takeProblems();
  expect(problems.length === 0, `the store example logged: ${problems.join('; ')}`);
  console.log('ok   the store example: one cart, shared by both baskets on the page');
}

async function crashNotice(session) {
  await session.navigate(`${origin}/apps/jibb-host-fixture/fragile`);
  await session.until('the fragile island to start', STARTED);
  await session.click('[data-jibb-island] button');
  await session.until('the crash notice', `(${ISLANDS})[0].notice !== null`);
  const [island] = await session.evaluate(ISLANDS);
  expect(island.notice === NOTICE, `the crash notice read ${JSON.stringify(island.notice)}`);
  expect(island.text.includes('Pressed 0 times'), 'the crashed island lost its model');
  const role = await session.evaluate(`document.querySelector('[data-jibb-notice]').getAttribute('role')`);
  expect(role === 'alert', 'the crash notice is not an alert');
  session.takeProblems();
  console.log('ok   the crash notice: shown once, with the model kept');
}

async function sharedModules(session) {
  let sharedHash;
  for (const [route, count] of [['bench-small', 3], ['bench', 500], ['bench-small', 3]]) {
    await session.navigate(`${origin}/apps/jibb-host-fixture/${route}`);
    await session.until('the shared rows island to start', STARTED);
    const state = await session.evaluate(`(() => {
      const island = document.querySelector('[data-jibb-island]');
      return {
        hash: island.getAttribute('data-jibb-island'),
        rows: island.querySelectorAll('[data-each] > *').length,
        value: island.querySelector('input').value,
      };
    })()`);
    sharedHash ??= state.hash;
    expect(state.hash === sharedHash, 'the rows module URL changed between pages');
    expect(state.rows === count, `${route} rendered ${state.rows} rows, not ${count}`);
    expect(state.value === '', `${route} retained another page's input`);
    await session.focus('[data-jibb-island] input');
    await session.type('page-local');
    await session.until('the page-local model to update',
      `document.querySelector('[data-jibb-island]').textContent.includes('Typed: page-local')`);
  }
  const problems = session.takeProblems();
  expect(problems.length === 0, `shared modules logged: ${problems.join('; ')}`);
  console.log('ok   shared island module across pages: one URL, independent models');
}

async function viewTemplates(session) {
  await session.navigate(`${origin}/apps/jibb-host-fixture/template-demo`);
  await session.until('the template island to start', STARTED);
  await session.evaluate(`(() => {
    const root = document.querySelector('[data-jibb-island]').firstChild;
    window.templateNodes = { root, heading: root.firstChild, text: root.lastChild };
    window.templateCount = Number(root.lastChild.nodeValue.slice('Count: '.length));
    // Ordinary vnode diffing would enumerate these attributes on each tick.
    // A compiled text-hole update must leave the static structure alone.
    root.__jibb.vnode.attrs = new Proxy(root.__jibb.vnode.attrs, {
      ownKeys() { throw new Error('template update revisited static attributes'); },
    });
  })()`);
  await session.until('the timer to update the template text',
    `Number(window.templateNodes.text.nodeValue.slice('Count: '.length)) > window.templateCount`);
  const kept = await session.evaluate(`(() => {
    const { root, heading, text } = window.templateNodes;
    return root === document.querySelector('[data-jibb-island]').firstChild
      && root.firstChild === heading && heading.textContent === 'Compiled template'
      && root.lastChild === text;
  })()`);
  expect(kept, 'the template update replaced its static DOM or text hole');
  const problems = session.takeProblems();
  expect(problems.length === 0, `view templates logged: ${problems.join('; ')}`);
  console.log('ok   compiled view template: timer updates text and retains static DOM');
}

async function rowTemplates(session) {
  await session.navigate(`${origin}/apps/jibb-host-fixture/bench`);
  await session.until('the rows template to start', STARTED);
  await guardStaticLayout(session, { column: ':scope > .j-column' });
  const count = await session.evaluate(`(() => {
    const { container, nodes } = window.jibbTemplateGuard;
    const root = nodes.column.node;
    const each = root.querySelector('[data-each]');
    window.jibbRowNodes = {
      field: root.querySelector('input'),
      echo: root.childNodes[1],
      each,
      rows: [...each.children].map(node => [node.__jibb.vnode.key, node]),
    };
    if (!root.classList.contains('j-gap-s1')) throw new Error('the rows template lost its gap');
    return each.children.length;
  })()`);
  expect(count === 500, `the rows template started with ${count} rows, not 500`);
  await session.focus('[data-jibb-island] input');
  await session.type('ac');
  await session.evaluate('window.jibbRowNodes.field.setSelectionRange(1, 1)');
  await session.type('b');
  await session.until('the rows template to echo the middle insertion',
    `document.querySelector('[data-jibb-island]').textContent.includes('Typed: abc')`);
  expect(await session.evaluate(`(() => {
    const { container, nodes } = window.jibbTemplateGuard;
    const { field, echo, each, rows } = window.jibbRowNodes;
    const current = [...each.children];
    return field === container.querySelector('input') && field === document.activeElement
      && field.value === 'abc' && field.selectionStart === 2 && field.selectionEnd === 2
      && echo === nodes.column.node.childNodes[1] && echo.nodeValue === 'Typed: abc'
      && each === container.querySelector('[data-each]') && current.length === rows.length
      && rows.every(([key, node], index) => current[index] === node && node.__jibb.vnode.key === key);
  })()`), 'the rows template replaced its field, echo or keyed rows, or moved focus or the caret');
  await checkStaticLayout(session, 'the rows template');
  const problems = session.takeProblems();
  expect(problems.length === 0, `the rows template logged: ${problems.join('; ')}`);
  console.log('ok   compiled rows template: static gap, control focus and caret, text and 500 keyed rows survive updates');
}

async function appRoutes(session) {
  const heading = `document.querySelector('[data-jibb-island] h1')?.textContent`;
  await session.navigate(`${origin}/apps/jibb-host-fixture/app/one`);
  await session.until('the app island to start', STARTED);
  expect(await session.evaluate(heading) === 'At one', 'the app did not start at its path');
  // A marker on the window survives only while no page loads.
  await session.evaluate('window.jibbMarker = 1');
  await session.click('[data-jibb-island] a[href$="/app/two"]');
  await session.until('the app to follow its link', `${heading} === 'At two'`);
  expect(await session.evaluate('location.pathname') === '/apps/jibb-host-fixture/app/two',
    'following an in-section link left the address unchanged');
  expect(await session.evaluate('window.jibbMarker') === 1, 'following an in-section link loaded a page');
  expect(await session.evaluate('document.activeElement?.tagName') === 'H1',
    'focus did not move to the first heading');
  await session.evaluate('history.back()');
  await session.until('the app to follow the back button', `${heading} === 'At one'`);
  // A link out of the section loads its page.
  await session.click('[data-jibb-island] a[href$="/about"]');
  await session.until('the About page',
    `location.pathname === '/apps/jibb-host-fixture/about' && document.readyState === 'complete'`);
  const problems = session.takeProblems();
  expect(problems.length === 0, `the app logged: ${problems.join('; ')}`);
  console.log('ok   an app: in-section links and the back button move it without loading a page');
}

async function benchmark(session) {
  await session.navigate(`${origin}/apps/jibb-host-fixture/bench`);
  await session.until('the list island to start', STARTED);
  const rows = await session.evaluate(`document.querySelectorAll('[data-jibb-island] [data-each] > *').length`);
  expect(rows === 500, `the list island has ${rows} rows, not 500`);
  // Each keystroke's time from its input event to the patched page laid
  // out: the island's update, view and patch, then style and layout, timed
  // apart too.
  await session.evaluate(`(() => {
    window.jibbTimes = [];
    let start = 0;
    addEventListener('beforeinput', () => { start = performance.now(); }, true);
    addEventListener('input', () => {
      const patched = performance.now();
      document.body.getBoundingClientRect();
      void document.body.offsetHeight;
      const laid = performance.now();
      window.jibbTimes.push([laid - start, patched - start]);
    });
  })()`);
  await session.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await session.focus('[data-jibb-island] input');
  if (args.profile) {
    await session.send('Profiler.enable');
    await session.send('Profiler.start');
  }
  for (let i = 0; i < KEYSTROKES + 5; i += 1) {
    await session.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'a', code: 'KeyA', text: 'a', windowsVirtualKeyCode: 65 });
    await session.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'a', code: 'KeyA', windowsVirtualKeyCode: 65 });
  }
  if (args.profile) {
    const { profile } = await session.send('Profiler.stop');
    writeFileSync(args.profile, JSON.stringify(profile));
  }
  await session.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  const measured = (await session.evaluate('window.jibbTimes')).slice(5);
  const times = measured.map(([total]) => total).sort((a, b) => a - b);
  const scripts = measured.map(([, script]) => script).sort((a, b) => a - b);
  const typed = await session.evaluate(`document.querySelector('[data-jibb-island]').textContent`);
  expect(typed.includes(`Typed: ${'a'.repeat(KEYSTROKES + 5)}`), 'the list island did not echo every keystroke');
  expect(times.length === KEYSTROKES, `measured ${times.length} keystrokes, not ${KEYSTROKES}`);
  const at = q => times[Math.min(times.length - 1, Math.floor(q * times.length))];
  const median = list => list[Math.floor(list.length / 2)];
  const summary = `median ${at(0.5).toFixed(1)} ms, p95 ${at(0.95).toFixed(1)} ms, max ${times.at(-1).toFixed(1)} ms; `
    + `the island's own update, view and patch, median ${median(scripts).toFixed(1)} ms, the rest style and layout`;
  const problems = session.takeProblems();
  expect(problems.length === 0, `the benchmark logged: ${problems.join('; ')}`);
  if (BAR_MS === undefined) {
    console.log(`ok   the benchmark, measured: ${KEYSTROKES} keystrokes in a 500-row list island at 4x CPU slowdown: ${summary}`);
  } else if (expect(at(0.95) <= BAR_MS, `a keystroke in the 500-row list island took ${summary} at 4x CPU slowdown, over the ${BAR_MS} ms bar`)) {
    console.log(`ok   the benchmark: ${KEYSTROKES} keystrokes in a 500-row list island at 4x CPU slowdown: ${summary}, within the ${BAR_MS} ms bar`);
  }
}

const browser = await launch();
try {
  const session = await Session.open(browser.endpoint);
  try {
    await login(session);
  } catch (error) {
    expect(false, `login: ${error.message}`);
    console.log(`Chromium's output:\n${browser.output()}`);
    throw error;
  }
  const steps = [exampleThree, storeExample, crashNotice, sharedModules, viewTemplates, rowTemplates, appRoutes, benchmark]
    .filter(step => !args.only || args.only.split(',').includes(step.name));
  for (const step of steps) {
    try {
      await step(session);
    } catch (error) {
      const problems = session.takeProblems();
      expect(false, `${step.name}: ${error.message}${problems.length ? `; the page logged: ${problems.join('; ')}` : ''}`);
    }
  }
} finally {
  browser.close();
}
if (failures.length !== 0) {
  console.log(`browser-check: ${failures.length} failed`);
  process.exit(1);
}
console.log('browser-check: all selected browser checks passed in Chromium');
process.exit(0);
