import { apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy, memo, checkValue } from '../core/runtime.mjs';
import { readShip } from '../core/literal.mjs';
import { decodeUw } from '../natives/codec.mjs';
import { cell, cord } from '../natives/helpers.mjs';
import { loweredNatives as natives } from '../natives/lowered.mjs';
import { Channel, installPagehide } from './channel.mjs';
import { Effects } from './effects.mjs';
import { Island } from './island.mjs';
import { StoreRegistry } from './stores.mjs';
import { compiledViewTemplate } from './template.mjs';
import { UrlRuntime } from './url.mjs';

// Only the primitives both Core emitters put in evaluate(runtime, natives).
// Other runtime exports are helpers for the library, not the module ABI.
const runtime = { apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy, memo, checkValue, viewTemplate: compiledViewTemplate };

// The server's notice for a crashed island, which the browser shows too.
export const CRASH_NOTICE = 'This part of the page stopped working. Reloading the page may fix it.';

// A page with islands carries its client configuration as JSON: its base
// path, its ship, its stores' module hashes and its static files.
export function readConfig(document) {
  const element = document.querySelector('script[type="application/x-jibb-client"]');
  if (element === null) throw new Error('the page has no Jibb client configuration');
  const config = JSON.parse(element.textContent);
  return {
    base: config.base ?? '',
    ship: config.ship,
    stores: config.stores ?? {},
    assets: new Map(Object.entries(config.assets ?? {})),
    section: config.section,
  };
}

export function moduleUrl(base, hash) {
  return `${base}/~jibb/m/${hash}.js`;
}

// An island module's main is [init update view subs].
function programOf(main) {
  const [init, rest] = cell(main, 'island program');
  const [update, more] = cell(rest, 'island program');
  const [view, subs] = cell(more, 'island program');
  return { init, update, view, subs };
}

function showNotice(document, container) {
  if (container.querySelector('[data-jibb-notice]') !== null) return;
  const notice = document.createElement('p');
  notice.setAttribute('role', 'alert');
  notice.setAttribute('class', 'j-tone-danger');
  notice.setAttribute('data-jibb-notice', '');
  notice.appendChild(document.createTextNode(CRASH_NOTICE));
  container.insertBefore(notice, container.firstChild);
}

// The event stream reopens when it ends, with its last event id, after a
// delay that doubles while it can't be opened and starts over once it has
// been; a channel Eyre no longer has took its watches with it, so the
// islands stop (Decisions: Crash notice). A closing ends the loop.
async function keepConnected(channel, onLost, wait) {
  const generation = channel.generation;
  const live = () => channel.generation === generation;
  let delay = 1000;
  while (live()) {
    const opened = channel.opened;
    try {
      await channel.connect();
    } catch (error) {
      if (live() && error.status === 404) return onLost(error);
    }
    if (!live()) return;
    if (channel.opened !== opened) delay = 1000;
    await wait(delay);
    delay = Math.min(delay * 2, 30_000);
  }
}

/**
 * Start every island on the page: one store registry and one channel for
 * the page, each island from the model the server rendered its first view
 * with. Resolves to the started islands. One island's failure, or a store's,
 * leaves the others running.
 */
export async function boot({
  document = globalThis.document,
  window = globalThis,
  load = url => import(url),
  fetchImpl = globalThis.fetch?.bind(globalThis),
  uid = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  wait = ms => new Promise(resolve => setTimeout(resolve, ms)),
} = {}) {
  const config = readConfig(document);
  // Islands of one module share its evaluation, as stores and islands
  // share a module's file across pages.
  const evaluated = new Map();
  const evaluate = hash => {
    if (!evaluated.has(hash)) {
      evaluated.set(hash, load(moduleUrl(config.base, hash))
        .then(module => module.evaluate(runtime, natives)));
    }
    return evaluated.get(hash);
  };
  const paths = { base: config.base, assets: config.assets };

  // One store per page, shared by its islands (Decisions: Shared state). A
  // store that can't load is left out, so only the islands using it crash.
  const stores = new StoreRegistry();
  await Promise.all(Object.entries(config.stores).map(([module, hash]) => evaluate(hash).then(
    (main) => {
      const [init, update] = cell(main, 'store');
      stores.register({ name: cord(module), init, update });
    },
    () => {},
  )));

  const started = [];
  // The channel whose event stream is kept open, by generation.
  let streaming;
  const channel = new Channel(uid, {
    fetchImpl,
    onSent: () => {
      if (streaming === channel.generation) return;
      streaming = channel.generation;
      keepConnected(channel, () => {
        channel.close();
        for (const { island, container, effects } of started) {
          effects.stop();
          island.stop();
          showNotice(document, container);
        }
      }, wait);
    },
  });
  // A page shown again from the back/forward cache has a fresh channel, on
  // which each island watches again what it watched.
  installPagehide(channel, window, () => {
    for (const { effects } of started) effects.resume();
  });
  const owner = readShip(config.ship).value;

  // A page under a catch-all route is an app: its links and go commands
  // within the section the route covers change the address without loading
  // a page, and %url gives its islands the path within the section
  // (Decisions: Apps). Elsewhere %url gives the application path.
  const { section } = config;
  const urlRuntime = new UrlRuntime({
    window, document, prefix: section === undefined ? config.base : `${config.base}${section}`,
  });
  const inSection = (href) => {
    if (section === undefined) return false;
    const target = new URL(href, window.location.href);
    return target.origin === window.location.origin && urlRuntime.contains(target.pathname);
  };
  const navigate = url => (inSection(url) ? urlRuntime.go(url) : window.location.assign(url));
  if (section !== undefined) {
    document.addEventListener('click', (event) => {
      if (event.defaultPrevented || (event.button ?? 0) !== 0
        || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      let link = event.target;
      while (link && !(link.localName === 'a' && link.getAttribute('href') !== null)) link = link.parentNode;
      if (!link || link.getAttribute('target') !== null || link.getAttribute('download') !== null) return;
      const href = link.getAttribute('href');
      if (!inSection(href)) return;
      event.preventDefault();
      urlRuntime.go(href);
    });
  }

  const containers = [...document.querySelectorAll('[data-jibb-island]')];
  const mains = await Promise.all(containers.map(container => (
    evaluate(container.getAttribute('data-jibb-island')).then(
      main => ({ main }),
      error => ({ error }),
    )
  )));
  containers.forEach((container, index) => {
    const loaded = mains[index];
    const state = container.querySelector('script[type="application/x-jibb-state"]');
    if (loaded.error !== undefined || state === null) {
      showNotice(document, container);
      return;
    }
    try {
      const island = new Island({
        program: programOf(loaded.main),
        packedModel: decodeUw(state.textContent.trim()),
        checkedInit: true,
        container,
        // The server's view, all of it: the HTML parser may have split it.
        s: [...container.childNodes].filter(node => node !== state),
        document,
        paths,
        // An island that crashes keeps its model and shows the notice
        // (Decisions: Crashes).
        onCrash: () => showNotice(document, container),
      });
      island.start();
      if (!island.active) return;
      state.remove();
      const effects = new Effects({
        island,
        channel,
        owner,
        stores,
        window,
        document,
        urlRuntime,
        navigate,
      });
      started.push({ island, container, effects });
    } catch {
      showNotice(document, container);
    }
  });
  return started.map(({ island }) => island);
}
