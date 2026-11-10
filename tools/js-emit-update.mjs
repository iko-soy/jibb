// Regenerate tests/js-emit: each case's Core source, its natives and the
// JavaScript js/core/compiler.mjs emits for it, which the Hoon port in
// jibb-dev/lib/jibb-js.hoon must reproduce exactly (tests/lib/jibb-js.hoon).
// Cases are the shared hand-written fixtures and a few closed expressions
// more.
//
//     node tools/js-emit-update.mjs
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readCore } from '../js/core/reader.mjs';
import { compileCore } from '../js/core/compiler.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'tests', 'js-emit');

function slug(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function nativeNames(node, names = new Set()) {
  if (node && typeof node === 'object') {
    if (node.type === 'native') names.add(node.name);
    for (const value of Object.values(node)) {
      if (Array.isArray(value)) value.forEach((item) => nativeNames(item, names));
      else if (value && typeof value === 'object') nativeNames(value, names);
    }
  }
  return names;
}

const cases = [];
const fixture = JSON.parse(readFileSync(join(root, 'js', 'test', 'fixtures', 'hand-written.json'), 'utf8'));
for (const entry of fixture.cases) {
  const ast = readCore(entry.source, { nativeNames: entry.natives });
  cases.push({ name: `fixture-${slug(entry.name)}`, source: entry.source, ast });
}
// Compact constructors for additional template coverage. These build Core
// source only; the checker-linked fixture below remains the source proof.
const sealed = (tag, payload) => `(app (native raw-seal) (cons %${tag} ${payload}))`;
const coreList = (...items) => items.reduceRight((tail, head) => `(cons ${head} ${tail})`, '~');
const layout = (tag, ...children) => sealed(tag, `(cons ~ ${coreList(...children)})`);
const templateBranches = `(lam words ${layout('row', layout('wrap',
  sealed('heading', '(cons 0 "low")'),
  layout('stack', sealed('heading', '(cons 9 "high")'),
    sealed('el', `(cons ~ ${sealed('para', coreList(
      sealed('text', String.raw`"quote \" and slash \\"`),
      sealed('text', '"λ"'), sealed('text', 'words'),
    ))})`)),
))})`;
let deepTemplate = sealed('text', 'words');
for (let i = 0; i < 20; i++) deepTemplate = `(app wrap ${deepTemplate})`;
let wideTemplate = sealed('text', 'words');
for (let i = 0; i < 6; i++) wideTemplate = `(app pair ${wideTemplate})`;
// This projection is valid Core, but its 54-bit axis is outside analysis.
let projectedTemplate = sealed('text', 'words');
for (let i = 0; i < 53; i++) projectedTemplate = `(cons ${projectedTemplate} ~)`;
projectedTemplate = `(slot 9007199254740992 ${projectedTemplate})`;
const templateLimits = `(let wrap (lam child ${sealed('el', '(cons ~ child)')})
  (let pair (lam child ${sealed('para', coreList('child', 'child'))})
    (cons (lam words ${deepTemplate})
      (cons (lam words ${wideTemplate}) (lam words ${projectedTemplate})))))`;

// Closed expressions the shared fixtures leave out: a self tail call, which
// compiles to a loop, a recursive arm in tail position, nested lets, a trace
// and closed lambdas inside a gate, which are made once.
const extra = [
  ['checked-view-template', readFileSync(join(root, 'tests', 'view-template', 'core.txt'), 'utf8').trim(), ['raw-seal']],
  ['view-template-trace', '(lam words (let seen (trace "render" ~) (app (native raw-seal) (cons %text words))))', ['raw-seal']],
  ['view-template-recursive', '(rec ((view (lam words (app (native raw-seal) (cons %text words))))) view)', ['raw-seal']],
  ['view-template-inner', '(lam captured (lam ignored (app (native raw-seal) (cons %text captured))))', ['raw-seal']],
  ['view-template-closed-inner', '(lam ignored (lam words (app (native raw-seal) (cons %text words))))', ['raw-seal']],
  ['view-template-branches', templateBranches, ['raw-seal']],
  ['view-template-limits', templateLimits, ['raw-seal']],
  ['self-tail-loop', '(rec ((count (lam n (if (eq n 0) %done (app count (app (native dec) n)))))) (app count 5))', ['dec']],
  ['tail-rec-arm', '(rec ((walk (lam p (if (cell? p) (app walk (slot 3 p)) p)))) (let start (cons 1 (cons 2 3)) (app walk start)))', []],
  ['nested-lets', '(let x 1 (let y (cons x 2) (let z (edit 2 y 7) (cons (slot 2 z) (slot 3 y)))))', []],
  ['trace', '(trace "checked" (if (eq 1 1) 42 (crash)))', []],
  // Inside a module-level gate, a lambda using only module-level names is
  // made once; one using the gate's sample is made each call.
  ['closed-inner-lambda', '(let f (lam x (cons x x)) (let g (lam y (cons (lam z (app f z)) (lam w (cons y w)))) (app (slot 2 (app g 1)) 2)))', []],
];
for (const [name, source, natives] of extra) {
  cases.push({ name: `extra-${name}`, source, ast: readCore(source, { nativeNames: natives }) });
}

if (existsSync(out)) rmSync(out, { recursive: true });
mkdirSync(out, { recursive: true });
const index = [];
for (const { name, source, ast } of cases) {
  const natives = [...nativeNames(ast)].sort();
  const js = compileCore(ast, { nativeNames: natives });
  const dir = join(out, name);
  mkdirSync(dir);
  writeFileSync(join(dir, 'core.txt'), source + '\n');
  writeFileSync(join(dir, 'natives.txt'), natives.join('\n') + '\n');
  writeFileSync(join(dir, 'js.txt'), js);
  index.push(name);
}
writeFileSync(join(out, 'cases.txt'), index.join('\n') + '\n');
console.log(`wrote ${index.length} cases to tests/js-emit`);
