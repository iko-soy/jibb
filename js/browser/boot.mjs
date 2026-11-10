import * as runtime from '../core/runtime.mjs';
import { readShip } from '../core/literal.mjs';
import { decodeUw } from '../natives/codec.mjs';
import { cell, cord } from '../natives/helpers.mjs';
import { createNativeRegistry, nativeNames } from '../natives/registry.mjs';
import '../natives/lowered.mjs';
import { Channel, installPagehide } from './channel.mjs';
import { Effects } from './effects.mjs';
import { Island } from './island.mjs';
import { StoreRegistry } from './stores.mjs';
import { UrlRuntime } from './url.mjs';

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

// The event stream reopens when it ends, with its last event id; a channel
// Eyre no longer has took its watches with it, so the islands stop.
async function keepConnected(channel, onLost, wait) {
  let delay = 1000;
  for (;;) {
    try {
      await channel.connect();
      delay = 1000;
    } catch (error) {
      if (channel.closed) return;
      if (error.status === 404) {
        onLost(error);
        return;
      }
      await wait(delay);
      delay = Math.min(delay * 2, 30_000);
    }
    if (channel.closed) return;
  }
}

/**
 * Start every island on the page: one store registry and one channel for
 * the page, each island from the model the server rendered its first view
 * with. Resolves to the started islands.
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
  const natives = createNativeRegistry(nativeNames());
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

  // One store per page, shared by its islands (Decisions: Shared state).
  const stores = new StoreRegistry();
  for (const [module, hash] of Object.entries(config.stores)) {
    const [init, update] = cell(await evaluate(hash), 'store');
    stores.register({ name: cord(module), init, update });
  }

  const started = [];
  let streaming = false;
  const channel = new Channel(uid, {
    fetchImpl,
    onSent: () => {
      if (streaming) return;
      streaming = true;
      keepConnected(channel, () => {
        for (const { island, container } of started) {
          island.stop();
          showNotice(document, container);
        }
      }, wait);
    },
  });
  installPagehide(channel, window);
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
    if (loaded.error !== undefined) {
      showNotice(document, container);
      return;
    }
    const state = container.querySelector('script[type="application/x-jibb-state"]');
    if (state === null) {
      showNotice(document, container);
      return;
    }
    const server = [...container.childNodes];
    const island = new Island({
      program: programOf(loaded.main),
      packedModel: decodeUw(state.textContent.trim()),
      container,
      document,
      paths,
      // An island that crashes keeps its model and shows the notice
      // (Decisions: Crashes).
      onCrash: () => showNotice(document, container),
    });
    island.start();
    if (!island.active) return;
    // The island's own view replaces the server's.
    for (const node of server) {
      if (node.parentNode === container) container.removeChild(node);
    }
    new Effects({
      island,
      channel,
      owner,
      stores,
      window,
      document,
      urlRuntime,
      navigate,
    });
    started.push({ island, container });
  });
  return started.map(({ island }) => island);
}
