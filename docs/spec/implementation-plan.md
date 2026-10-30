# Implementation plan

Oct 29, 2026 · @iko

Build Jibb in eight milestones, each ending in something that runs on a fake ship. The first release, static pages served by the shared host, comes at milestone 4. The spec is in the other tabs: the language in Jibb — an Elm-architecture UI language for Urbit, its syntax in Grammar, the core language in Core language, and every choice in Decisions.

## Milestones

Each milestone ends with its checks passing on a fake ship. No dates yet: agree them after milestone 1, once it shows how fast the Hoon work goes.

1. **Parser and mark**
   - Builds: the `%jibb` mark as the first tab gives it; the layout pass, emitting INDENT, DEDENT and NEWLINE; a parser for the Grammar tab's EBNF that returns a syntax tree with source positions; errors with file, line, column and an excerpt.
   - Done when: every Jibb code block in the doc parses; each lexical rule has a test input that breaks it; `|commit` stores `.jibb` files on a fake ship.
2. **Types and prelude**
   - Builds: Hindley–Milner inference with aura variables; tag and literal resolution with deferred constraints; the union disjointness check; exhaustive `?-` with dead-arm errors; `/-`, `/%` and `/=`, with the table for importing Hoon types; API files and their derived gates; the prelude's types.
   - Done when: the doc's examples typecheck, except those written as errors; each error the Grammar tab describes has a test with its message, such as "msg has no case %submitt"; a `/sur` file with `$%`, `$@`, maps and a recursive mold imports as the table says.
3. **Core language**
   - Builds: lowering from the checked syntax tree; the text form's printer and reader; the reference interpreter, in Hoon; the Nock backend, with gates shaped like Hoon's and natives calling the standard library.
   - Done when: the Core language tab's example lowers to the program shown there; the interpreter and the Nock backend agree on a corpus of test programs, crashes included.
4. **Host and static pages: the first release**
   - Builds: the shared host on the `%jibb` desk, which finds app desks by docket's `site+`, binds their paths, rebuilds on commit one module per Behn timer wake, and serves pages only to the owner; the compiler's `build` and `render` entry points; the renderer written in Jibb, with HTML serialized on the ship; the theme's stylesheet; routing and application paths; static files at hashed URLs in Eyre's cache; the per-module compile cache; `-jibb!clear`.
   - Done when: worked example 1 is served at its URL; a logged-out request is sent to the login page; a commit that changes one module recompiles only it and its dependents; a missing static file is a compile error; suspending the desk clears its cache entries.
5. **Published pages**
   - Builds: `load`, the per-request scry, route parameters parsed by aura, validators on scried data, and the 404 and 500 pages.
   - Done when: worked example 2 and a `_slug` route render from a fresh scry on every request; an unparseable parameter gives a 404 and a crashing render a 500, neither cached.
6. **Islands**
   - Builds, in order: the benchmark, a minimal JavaScript backend against a Nock interpreter in the browser on the same programs, with the result recorded in Decisions; then the chosen backend and the runtime library: the noun codec with `jam`, `cue` and `@uw`, natives, the channel client over `fetch`, the keyed DOM differ, `cmd` and `sub`, stores, the crash notice, URL subscriptions, and the loop rules under Browser runtime.
   - Done when: worked example 3 and the Grammar tab's store example run end to end in a browser; the browser code agrees with the reference interpreter on the test corpus; a keystroke in the benchmark's list island meets the bar agreed under Open questions.
7. **Tooling**
   - Builds: `-jibb!test` for `test-` arms; the Node harness that runs each test module's Nock, with nockjs, beside its JavaScript; the formatter; the tree-sitter grammar.
   - Done when: CI runs both test suites on every commit, and the formatter leaves every example in the doc unchanged.
8. **Polish**
   - Builds: island modules shared across pages, holes, and size work.
   - Done when: the shared library stays under 20 KB.

## Setup and ground rules

- **Code**: one repo with three folders: `jibb-dev`, which app desks vendor (the compiler, prelude, browser library and marks); `jibb`, the desk for the shared host and its threads; and an example app desk built from the doc's worked examples. The Node harness lives beside them.
- **Running**: a fake ship, with each folder synced into its desk and `|commit` after changes. App desks also need base-dev's `txt`, `txt-diff`, `js`, `bill` and `kelvin` marks, docket's `docket-0` and a `sys.kelvin`.
- **Tests**: from milestone 1 on, every Jibb code block in the doc is a golden test, and each stage's output is printed and compared, the core language in its text form.
- **The doc wins**: where code and doc disagree, the doc stands until it changes. A change to the language is agreed first and recorded in Decisions.
- **Questions** go as comments on the doc, on the words they're about.

## Compiler architecture

The compiler is a Hoon library, `/lib/jibb.hoon` in jibb-dev, which Clay builds once per release. The shared host checks it against two entry points, fixed across releases, and calls them: `build` on each commit, which also renders pages without data, and `render` for each request to a page with data. Until a new build links, the last one keeps serving.

```
/ui source
  → layout pass → parser → a syntax tree per module
  → module graph: imports resolved, Hoon types read from Clay
  → type checker, one module at a time, in dependency order
  → core language
      → Nock: pages, islands' init and first view, and the libraries they use
      → JavaScript: islands' update, view and subs, stores, and the libraries they use
```

| Decision | Choice | Why |
| --- | --- | --- |
| Nock code | Emitted directly from the core language, not through generated Hoon | Types are already checked, Hindley–Milner polymorphism has no direct Hoon form, and `mint` is slow on a ship |
| Browser code | JavaScript from the core language, unless milestone 6's benchmark favours a Nock interpreter | Both run the same programs, so the benchmark measures only the generated code |
| HTML renderer | One, written in Jibb: elements to virtual nodes, then HTML text on the ship and DOM in the browser | The server's HTML and the browser's first view agree by construction, which resuming relies on |
| Long compiles | One module per Behn timer wake | An event runs to completion, and moves inside it, self-pokes included, don't yield |
| Compile cache | Per module, with its interface and body hashed separately | A body change re-emits the module without re-checking its dependents |

Anything that crosses between ship and browser is the same noun on both sides: records are right-nested cells in field order, `%.y` and `~` are 0, cords have their first byte lowest, and maps are treaps ordered by `mug`. Gates never cross, so each backend represents them its own way.

## Browser runtime

For milestone 6. An island is one loop over one model: events become messages, `update` turns each message into a new model and commands, and only `view` decides what the island shows.

- **Start**: run `view` on the jammed model, bind the result to the server's nodes by key, and replace the subtree if they differ. `subs` then opens its watches, and each watch's first fact, full state, arrives as a message.
- **Messages** come from controls, command replies, facts, timers and `%url`. *Proposed*: an island handles them one at a time, in arrival order.
- **Rendering**: a message changes the model when `update` returns a different noun; `view` then re-runs and a keyed diff patches the DOM. An unchanged model renders nothing. *Proposed*: the patch lands before the next message, so a crash in `view` belongs to one message.
- **Controls**: after every event, the control that fired is reset to the latest view, even when the model didn't change. A field's text is rewritten only when it differs from the screen, which keeps the caret and any IME composition.
- **Commands**: each reply arrives later as a new message, never inside the `update` that sent it. *Proposed*: commands run in list order, after the patch.

| Control | Sends | When |
| --- | --- | --- |
| `button label msg` | `msg` | On click, or Enter or Space while focused |
| `toggle on label msg` | `msg` | When the reader flips it; `msg` carries no new value |
| `field label value reply` | `(reply text)` | On every `input` event, and once per IME composition, when it ends |
| `form msg kids` | `msg` | On Enter in any field inside it, without reloading the page |

*Proposed*: no overlays in v1, so no dialogs, menus, popovers or tooltips.

## Risks

- **Importing Hoon types.** Hoon's types form a graph with lazy `%hold` nodes, so the importer needs Hoon's own type engine to expand them, and it must recognise maps, sets and recursive molds by name. Start it early in milestone 2, on real `/sur` files such as Tlon's.
- **The compiler's speed in Hoon.** A parser and checker written in Hoon run far slower than native code. The cache keeps commits fast, but the first build after an install or upgrade is slow; time the example desk's first build in milestone 4.
- **Stack depth in JavaScript.** Most browsers have no tail calls, so self tail calls compile to loops, and list gates need native versions in JavaScript.
- **Atoms in JavaScript.** BigInt for every atom is slow. Keep small atoms as numbers and the rest as bytes, with cords caching their decoded string.
- **Type errors.** Hindley–Milner is known for confusing errors. Each error names both conflicting sites, with excerpts, and the messages are golden tests.

## Open questions

| Question | Needed by |
| --- | --- |
| What is the typography scale for heading levels and the `role` values? | Milestone 4 |
| Does the Eyre channel CSRF test reproduce on a fake ship? @iko has the write-up; if it does, it goes to Urbit privately. | Milestone 4 |
| What is the benchmark's bar? Proposed: a keystroke in a 500-row list island renders within one 16 ms frame on a mid-range phone. | Milestone 6 |
| Are the proposed loop rules adopted, along with no overlays in v1? | Milestone 6 |
| What do controls look like by default: buttons, toggles and fields, with their focus and disabled states? | Milestone 6 |
