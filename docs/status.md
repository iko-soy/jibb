# Status

As of 2026-11-14. This is the current capability and acceptance table. History and dated review findings are in git and [reviews/](reviews/). The plan is [spec/implementation-plan.md](spec/implementation-plan.md); every milestone requires its checks to pass on a fake ship as well as under eval.

## Milestones

| # | Milestone | Status |
| --- | --- | --- |
| 1 | Parser and mark | Done |
| 2 | Types and prelude | Done: the general full checker, checked prelude and Hoon importer meet the milestone acceptance criteria under eval, on the fake ship and in the integrated Nix checks |
| 3 | Core language | Done: checked-artifact capture, lowering/linking, the Core reader/interpreter, Nock backend and authenticated natives pass the exact Core golden, focused suites, and the final integrated Nix eval and fake-ship checks. Provenance-checked Nock execution adds 13 focused eval arms for function-as-noun and trace controls |
| 4 | Host and static pages: the first release | Done: the shared host builds each desk with its own vendored compiler at one Clay revision, one compiler step per Behn wake, caches every result under a hash of its inputs, and serves static pages only to the owner. Static files and each desk's theme stylesheet are public, immutable files in Eyre's cache at hashed URLs; links and images are checked against routes and static files; suspending a desk clears its files and `-jibb!clear` every desk's. The acceptance criteria pass on the fake ship and in `nix flake check` |
| 5 | Published pages | Done: a page with data is prepared at build time and rendered per request from a fresh scry, run in a thread so that a path its agent rejects is the page's 404; route parameters bind `load`'s sample by name and parse by aura, with catch-alls; derived receivers check what agents answer against its type; failures get Jibb's error page; nothing is cached. The acceptance criteria pass on the fake ship |
| 6 | Islands | Done except the benchmark's bar, which waits for @iko: islands render their `init`'s first view on the ship with their jammed model, and the host compiles island and store modules to JavaScript with a Hoon port of the Core compiler, publishing them and the browser library at hashed URLs. In headless Chromium, worked example 3 adds and toggles todos through the `%todo` agent, the Grammar tab's store example shares one cart between two baskets, a crashing island shows the notice, and an app follows its in-section links without loading a page. The browser code agrees with the reference interpreter, and the Hoon emitter with the JavaScript compiler. The benchmark's measurements are below |
| 7 | Tooling | Done: `-jibb!test` runs each `test-` arm under `/ui/tests` in Nock; the Node harness runs every test as JavaScript and as Nock and requires them to agree with `-jibb!test`; the formatter leaves every example in the doc unchanged, the examples now in its canonical form; the tree-sitter grammar is `jibb-cli`'s. `.github/workflows/check.yml` runs `nix flake check` on every commit and pull request; the extended run for `633e0c9` passed |
| 8 | Polish | Done: island and store modules are shared across pages and evaluated once per page. Templates include constant layout attributes and dynamic element holes; eligible updates evaluate holes directly without allocating fixed layout nouns, retaining shared cell and callback identity across branches. The library is 55,729 minified bytes and 19,826 under `gzip -9n`, below the owner's strict 20,000-byte limit. The complete incremental Nix eval and fresh-ship checks passed |

JavaScript integration evidence on 2026-11-08: all 11 shared outcomes matched the integrated Hoon Core interpreter, and all JavaScript tests passed. Checked lowering, authenticated natives, derived API/store calls, and entry linking are now integrated; 58 focused lowering arms and the exact Core golden pass under eval and on the fake ship. These checks complement, rather than replace, the later browser-runtime milestones.

The repository [specification](spec/) and its [decisions](spec/decisions.md) are authoritative. Later-milestone native CLI work is integrated independently; it does not replace the Hoon compiler acceptance checks below.

## Milestone 2 acceptance

| Check | Corpus and required result | Current evidence |
| --- | --- | --- |
| Golden cases | 1,376 cases; exact tokens, trees, and full-checker type reports | Final integrated Nix eval run passed in 572 seconds |
| Test arms | 518 `test-` arms in 256 `tests/lib` suites, in eight eval shards | Final eval run passed all eight shards |
| Strict review regression | 317 source probes and 31 import probes; valid inputs check and invalid inputs produce their own specified messages, sites, excerpts, and carets | Final integrated Nix runs passed eval in 2,915 seconds and ship in 1,144 seconds |
| Fake-ship corpus | The 1,376 golden arms plus 518 suite arms: 1,894 arms total | Final integrated Nix run passed 1,894/1,894 in 6,238 seconds, with no failures or crashes |
| Error table | All 33 specified errors and the source-site summary row | Met with full-checker goldens in the [review appendix](reviews/2026-11-03-milestone-2-review.md#appendix-the-errors-the-spec-describes), including 17 `review-*` cases |
| Hoon import table | `$%`, `$@`, atoms/cells, maps, and recursive molds, printed and used through the full checker under eval and on the ship | [jibb-import-general](../tests/lib/jibb-import-general.hoon), [Clay full-import](../tests/clay-fixtures/full-import.txt); final eval and Clay/ship runs passed |
| `my-app` through Clay | Build `/sur` files and marks, then check all 11 UI modules in dependency order with exactly one expected failure: `buttons.jibb` at 3:16 | Final source-aware run passed in 63.5 seconds |
| Debug-disabled performance | Generated 2,000-line modules in both declaration orders and the desk | Recorded below |
| Complete registered checks | `tools/check` and `nix flake check` on the final integrated tree | Integrated serialized Nix run passed: 14/14 eval checks in 5,604 seconds and 6/6 ship checks in 7,622 seconds, plus desks and native CLI |

The public `golden-types*` reporters render only the full-module result: checked definitions and module kind, or the actual diagnostic with source excerpts. The old partial-report and source-shaped recovery pipelines are deleted; their behavioral suites remain as regressions. Final validation uses compiler SHA-256 `d369b012ae312f0d4dfc6930c789e2f143e8baa33f9f99e799632365b6806731` and importer SHA-256 `d7fc1f8f1a62415c2b3ffdaae1c93060c8f38639da6ec2f7689dd68eb9fca4f0`.

## Milestone 3 acceptance

| Check | Corpus and required result | Current evidence |
| --- | --- | --- |
| Focused Core and lowering suites | 84 merged Core/Nock/lowering arms, including checked artifacts, linking, derived APIs/stores and differential execution | All passed under eval; the complete pre-merge tree also passed all 58 focused lowering arms on the fake ship |
| Exact Core example | `doc-core-02-update` lowers to the documented `update`, with canonical `core.txt` on both runners | Passed under eval and on the fake ship |
| Complete eval | All 15 registered checks, including 1,376 goldens, 576 test arms in 262 suites and strict probes | Passed in 6,046 seconds on the pre-merge tree |
| Complete fake ship | All 6 registered checks; 1,952 golden/suite arms plus Clay, `my-app`, commit and strict probes | Passed in 8,728 seconds on the pre-merge tree; all 1,952 arms passed with no failures or crashes |
| Native checks | Rust parser/checker/evaluator/formatter/CLI corpus and JavaScript compatibility | All 127 Rust tests and clippy passed on the merged tree; all 230 JavaScript tests passed; all 11 shared Hoon outcomes matched |
| Integrated merge and Nix | New Core/Nock work from `master` merged with checked lowering; 611 test arms in 265 suites and 1,987 golden/suite arms on the ship | `nix flake check` passed: desks, eval, native CLI and fresh fake ship |

## Milestone 4 acceptance

| Criterion | Evidence |
| --- | --- |
| Worked example 1 is served at its URL | `tools/check-host`: `my-app`'s About page at `/apps/my-app/about` answers the owner with its Content-Security-Policy, its theme stylesheet and the Inter font that stylesheet loads; both files were fetched logged out from Eyre's cache, public and immutable |
| A logged-out request is sent to the login page | `tools/check-host`: a 307 to `/~/login?redirect=` with the exact original target, query included |
| A commit that changes one module recompiles only it and its dependents | `tools/check-host`: a commit to the fixture's note library checked exactly it and the page importing it again, 2 of the fixture's 8 modules, and rendered 1 of its 4 static pages |
| A missing static file is a compile error | `tools/check-host`: deleting the notes page's image made that page answer 500 with `missing static asset: /static/img/dot.png` while About kept serving. The build suites cover missing images, fonts and link targets |
| Suspending the desk clears its cache entries | `tools/check-host`: after a suspend the host lists no files for the desk, and its stylesheet and image are no longer in Eyre's cache. `-jibb!clear` removed every desk's files, and the next build published them again |

| Area | Current evidence |
| --- | --- |
| Static build and render | The checked build facade resolves the renderer and theme, executes linked Nock, checks the page's links and images against the desk's routes and static files, and serializes HTML with a Content-Security-Policy allowing scripts only from the ship; `+theme-css` checks the theme's values and contrast and makes its stylesheet. `jibb-build` (9 arms), `jibb-build-probe`, `jibb-host` (16 arms) and `jibb-cache-scope` pass under eval, and the 235 JavaScript tests pass with the browser decoder emitting the same classes |
| Static files and stylesheets | Files under `/ui/static/` and each desk's stylesheet are public, immutable entries in Eyre's cache at URLs naming a hash of their bytes. `tools/check-host` fetched the fixture's image, sized 3 by 2 from its PNG, and both desks' stylesheets logged out; a changed image got a new URL while the old one kept answering, retired with an expiry a day later, and restoring it brought its first URL back. Eyre's cache held exactly the published files and no page. A build whose compiler does not build kept serving the last pages and files, and the build after it checked nothing again |
| Real-Clay host | Each desk's `%ca`-built compiler and importer prepare, check, and render its sources at one Clay revision; the agent caches rendered pages by desk and route and serves them without adding private pages to Eyre's cache. It calls each entry point with `+slam`, typing every argument with the desk's own copy of its mold |
| Application interfaces and kinds | Authenticated `/sur` declaration enumeration and `/mar` readers feed checking; dynamic pages return 501, and libraries, islands, and stores return 404; a missing theme uses the checked default. On the fake ship a page using a generic `/sur` mold, `\|$  [key value]  (map key value)`, checks, and a misspelled mold gets the importer's own ``Hoon mold `tabel` is not declared`` at `/ui/misspelled.jibb:8:15`. `my-app`'s build report prints the expected `buttons.jibb` error at 3:16 |
| Incremental rebuilds | A commit to a published desk starts a build of that Clay revision, run as one compiler step per Behn wake while the last completed build keeps serving; until a desk's first build completes, its pages answer 503. Parsed imports, the prelude, `/sur` and mark reader results, module checks, the stylesheet and renders are cached under hashes of their inputs, and a compiler certificate binds only its module's import closure. Because certificates bind the sources of that closure rather than its interfaces, a change to a module's body still checks its dependents again; the plan's separate interface and body hashes are not used yet. Hoon files are built through Clay requests rather than scries, which Gall cannot recover from. A changed static file renders every static page again, since each render is keyed on all of the desk's file URLs, but checks no module again |
| HTTP and lifecycle | `tools/check-host` passed on a fake ship: owner `GET` and `HEAD`, the root, missing pages, unbuilt static files and libraries as 404s, logged out too for static files, 405 with `Allow`, a page importing an unbuildable `/sur` file answering with that build error while the others kept serving, and routes and files removed and rebuilt across suspend and revive |
| Regression validation | `nix flake check` on the working tree, with a fresh fake ship: the native CLI's 127 tests and all 16 eval checks passed, including every golden case, the eight test-arm shards and the strict probes. The ship group passed on its fresh ship too: `ship-selftest`, `ship-test` (every suite on the ship), `check-commit`, `clay-fixtures`, `check-my-app` with its one expected `buttons.jibb` error, `check-host` and `probes-ship` |

## Milestone 5 acceptance

| Criterion | Evidence |
| --- | --- |
| Worked example 2 renders from a fresh scry on every request | `tools/check-host`: `my-app`'s `/ui/blog/index.jibb` lists the posts its new `%blog` fixture agent answers at `/posts`, and a post added by a poke appears on the next request, with no commit |
| A `_slug` route renders from a fresh scry | `tools/check-host`: `/ui/blog/_slug.jibb`, `++ load |= slug=@ta (post.api slug same)`, renders a post and a newly added one; `HEAD` has no body and a logged-out reader is sent to the login page |
| An unparseable parameter gives a 404 | `tools/check-host`: `/blog/Not%20a%20knot` and the fixture's `/numbered/twelve`, a `@ud` route parameter, answer 404 with Jibb's error page; a path the agent rejects is a 404 too |
| A crashing render gives a 500 | `tools/check-host`: the fixture's `/crash` answers 500 on every request, and an agent answer that does not fit its type, `/blog/malformed`, is a 500 rather than a page |
| Neither is cached | `tools/check-host`: Eyre's cache holds only the desks' static files after these requests; the host keeps no rendered page with data |

| Area | Current evidence |
| --- | --- |
| Routes and `load` | The checker requires that a page under `/ui` takes exactly its route's parameters, each an atom of a path aura, a catch-all page the path itself, and a page with none `~`, reporting a mismatch at `main` with its sample's type. `jibb-build` (12 arms) binds and parses them, and its suite renders, rejects and scries through `+page-request`. The host routes a literal before a parameter before a catch-all, and reports conflicting routes as each file's error (`jibb-host`, 19 arms) |
| Checked facts | A derived request's receiver checks a fact against its full or diff type before the typed reply or fold, and the fold now receives each diff tagged with its mark, as its checked type says; `doc-core-02-update`'s Core shows both. Recursive molds in facts fail closed at lowering |
| Interpolation | `@ta`, `@tas` and the rest of the `@t` family splice as text and tapes through `crip`, as the Grammar says; before, a knot printed as `~.1` and a tape failed to lower (`jibb-lower`) |

## Milestone 6 acceptance

| Criterion | Evidence |
| --- | --- |
| Worked example 3 runs end to end in a browser | `tools/check-browser`: in headless Chromium, `my-app`'s index renders "My ship" and the todo island's first view from a fresh scry of the `%todo` agent, with its field read-only until the island starts; typing a todo and pressing Add pokes the agent, whose fact on `/todos` brings the new todo into the list; its toggle is checked by the next fact; 81 characters show "Too long" at once; and the page renders the toggled todo from a fresh scry |
| The Grammar tab's store example runs end to end | `tools/check-browser`: `my-app`'s `/shop` has two baskets on the `cart` store; adding an item in one shows "1 items" in both |
| The browser code agrees with the reference interpreter | `test-js-differential` runs the shared corpus through the JavaScript backend and the Hoon Core interpreter; `jibb-js` checks that the Hoon emitter the host compiles islands with gives the JavaScript compiler's text on `tests/js-emit`'s 38 cases, including template bounds and descriptor branches; the Node harness runs each test arm in JavaScript and Nock |
| A keystroke in the benchmark's list island meets the bar | Waits for the bar, which is still an open question. In headless Chromium at a 4x CPU slowdown, in the Nix sandbox on a fresh fake ship on 2026-11-11, a keystroke in the host fixture's 500-row list island took a median of 16.5 ms and a p95 of 20.1 ms, the island's own update, view and patch a median of 11.6 ms and the rest Chromium's style and layout; on the shared test ship, a median of 14.4 to 15.5 ms and a p95 of 23.5 to 25.6 ms; under heavier load, at a load average of about 20, medians were 15 to 46 ms. Views now reuse their unchanged parts: before that a keystroke took a median of 58 ms at 4x, and before the runtime stopped checking whole nouns on every operation, 7.5 s. In Node, without the browser's layout, the island's work takes a median of 0.5 ms. `tools/check-browser --bar=16` fails a p95 over 16 ms |

| Area | Current evidence |
| --- | --- |
| Islands on the ship | `jibb-build` (18 arms) renders an island's first view with its model and the page's client configuration, compiles it for the browser, and refuses a page; render failures name their original element call's source site. the host's build compiles each island and store module after the checks and publishes their files and the library, which `tools/check-host` fetches logged out |
| Browser runtime | 283 JavaScript tests: the boot script, stores shared within a page and isolated between pages, the crash notice, app sections and links, Eyre's noun events as Eyre sends them, timers and `fetch` called as browsers require, memoized gates and kept vnodes, hash boundaries, trailing-NUL text encoding, and compiled templates with ordinary fallback for foreign JavaScript callbacks and bounded analysis. Element-hole tests cover paths, controls, keyed reordering, later ordinary rendering and failures before patching |

## Milestone 7 acceptance

| Criterion | Evidence |
| --- | --- |
| CI runs both test suites on every commit | `.github/workflows/check.yml` runs `nix flake check`, whose ship group includes `check-host`, which runs `-jibb!test` on both desks, and `check-node-tests`, the Node harness. The [extended run for `633e0c9`](https://github.com/iko-soy/jibb/actions/runs/42856605769) passed on 2026-11-10 at 19:26 UTC. The later [run for `fc71705`](https://github.com/iko-soy/jibb/actions/runs/42863756570) also passed |
| The formatter leaves every example in the doc unchanged | `tools/doc-format` and the CLI's `doc_examples_are_canonical` format each of the doc's 14 examples to itself. The examples, and the `my-app` modules and prelude definitions they mirror, were rewritten in the formatter's canonical form; their parse trees are unchanged but for layout, and the goldens that quote them were regenerated |

## Milestone 8 progress

| Area | Evidence and limits |
| --- | --- |
| Shared modules | The host publishes one module URL for the rows island used on `/bench` and `/bench-small`; boot evaluates each imported module once per page. Node tests check separate page stores and models. The fresh-ship Nix browser run passed the shared-URL and independent-model checks |
| Compiled templates | Descriptors and text/element-hole axes come from authenticated linked Core. The original checked-source fixture pins a fixed column, heading and dynamic text; a second covers constant attributes, fields, buttons, keyed lists and a changing child. Fresh-ship browser checks passed for the real todo and 500-row islands as well as the timer fixture: updates did not revisit static attributes or replace retained DOM, and controls kept focus/caret and keyed rows kept identity; the integrated Nix eval and fresh-ship checks passed |
| Preserved behavior | First mount uses the original view. Eligible updates compute holes directly while retaining strict discarded work, crashes, traces and shallow cell validation. All holes decode before any patch. Tests cover Unicode and invalid UTF-8 decoding, failed renders, independent instances, replacement views, custom native registries and foreign JavaScript callbacks. Element holes retain the ordinary decoder's page paths and the DOM patcher's controls and keyed reconciliation. Only checked browser modules with the frozen canonical native table activate templates |
| Direct allocation evidence | Separately instantiated ordinary and optimized views produce the same DOM across five distinct updates. Generated noun cells per update fall from 9 to 0 for the checked column/text source, 24 to 0 for nested layouts with fixed attributes, and 13 to 3 for a button inside a fixed layout. Stable keyed-element cases, including an ordinary validation call, fall from 7 to 0. A closed row callback passed to an opaque recursive mapper retains its memo hit, falling from 8 to 1. First mounts retain identical allocations. Counts include generated `cons`, `edit` path cells and canonical seal wrappers; they exclude native internals, JavaScript vectors/closures, DOM allocations and heap bytes. Reproduce with `nix develop --command node js/bench/template-allocations.mjs` |
| Scope | Fixed `row`, `column`, `wrap`, `stack` and `el` with constant attributes, `para`, known heading levels and text. Dynamic attributes, controls, routes, unknown shapes and dynamic child lists use whole-element holes within a fixed layout; a wholly dynamic root keeps ordinary rendering. Attribute and list analysis have independent bounds, and exhaustion declines the complete plan. Direct evaluation has its own 2,000-step bound; unknown captures and local recursive expressions retain ordinary evaluation. Element holes and opaque operations still construct the nouns they need |
| Browser library | 55,729 minified bytes; 19,826 under `gzip -9n`, 174 below the strict 20,000-byte limit. Pinned esbuild and Terser use standard compression without unsafe transforms or property mangling. The bundle check enforces both size and freshness |

## Parser and mark

| Area | Status | Evidence |
| --- | --- | --- |
| `%jibb` mark and `|commit` | Done: MIME, noun, and text conversions, commit/readback, merges, and conflicts | [jibb-dev/mar/jibb.hoon](../jibb-dev/mar/jibb.hoon), `tools/ship check-commit` |
| Layout, lexical rules, and spans | Done: indentation tokens, source spans, exact parse errors with excerpts and carets | `lex-*`, `inline-*`, [jibb-check-spans](../tests/lib/jibb-check-spans.hoon) |
| Parser | Done for the specified grammar, including the settled syntax-review rulings | Every golden `tree.txt`, [grammar decisions](spec/decisions.md) |
| Documentation examples | All 14 labelled Jibb blocks parse and check in their intended contexts | `doc-*`, `tools/doc-blocks docs/spec`, `tools/doc-fragments` |
| Long and deeply nested input | Partial stress evidence, not a universal resource guarantee | Library design notes and bounded parser cases |

## General checker

| Area | Status | Evidence |
| --- | --- | --- |
| Inference core | Union-find variables with levels, occurs checks, atom/numeric/gate-free restrictions, deferred constraints, dependency SCCs, and level-based generalization | [compiler map](compiler.md), `types-*`, [jibb-deferred](../tests/lib/jibb-deferred.hoon), [jibb-union-find](../tests/lib/jibb-union-find.hoon) |
| Names and faces | Lexical capital scope, no-shadowing diagnostics, face-preserving joins, positional calls, `proj`, and `unface`; a capital beneath a face binds only the underlying type | `types-local-*`, `types-record-*`, `types-proj-*`, `inline-unface-*`, [jibb-positional-face-guards](../tests/lib/jibb-positional-face-guards.hoon) |
| Recursion and molds | Ordinary recursive gate groups, non-gate cycle diagnostics, local mold captures, and nominal recursive graphs with checked origin and arguments | `types-recursion-*`, `types-local-*`, [jibb-recursive-diagnostics](../tests/lib/jibb-recursive-diagnostics.hoon), [jibb-recursive-import](../tests/lib/jibb-recursive-import.hoon) |
| Literals and holes | Contextual atoms, decimals, strings, application paths, and definition-local hole resolution with definite diagnostics | `inline-decimal-*`, `types-hole-*`, `types-interpolation-*`, `types-qath-*` |
| Unions and constructors | Nominal identity, generic aliases, contextual constructors, disjointness, and precise missing-tag diagnostics | `types-union-*`, `types-generic-*`, `types-missing-tag-*` |
| Patterns | One reusable usefulness analysis over noun constants and cells, including lists, units, loobeans, nested patterns, missing-case witnesses, and covered-arm errors | `types-union-patterns*`, `types-cell-pattern-*`, [jibb-useful](../tests/lib/jibb-useful.hoon), [review-nested-covered](../tests/golden/review-nested-covered/) |
| Diagnostics | Actual messages and relevant declaration, context, and expression sites with excerpts; failed definitions cannot publish provisional interfaces | [jibb-full-report](../tests/lib/jibb-full-report.hoon), the 33-error appendix, strict probes |
| Implementation limits | Unsupported or unproved constructs fail closed and name the construct and source site; resource bounds are not treated as evidence | Strict negative controls and [compiler diagnostics](compiler.md#diagnostics) |

## Module kinds, APIs, and elements

| Area | Status | Evidence |
| --- | --- | --- |
| Kind classification | `main` is inferred as an ordinary expression; its checked type classifies a program, page, store, or static page. Directory and source spelling do not establish the kind | [jibb-program-main](../tests/lib/jibb-program-main.hoon), [jibb-page-kind-type](../tests/lib/jibb-page-kind-type.hoon), [jibb-store-kind](../tests/lib/jibb-store-kind.hoon) |
| Programs and islands | General component inference, initializer/model gate-freedom, update/view checking, and multiple or delayed subscriptions | [jibb-program-valid-inference](../tests/lib/jibb-program-valid-inference.hoon), [jibb-stream-small](../tests/lib/jibb-stream-small.hoon), [jibb-todo-full](../tests/lib/jibb-todo-full.hoon) |
| Watchability | Proven at the actual request occurrence through local, embedded, recursive, imported, and cached data; changed, discarded, unknown, and `scry=` requests reject | [jibb-program-watch](../tests/lib/jibb-program-watch.hoon), [jibb-local-island-watch](../tests/lib/jibb-local-island-watch.hoon), [jibb-recursive-watch-data](../tests/lib/jibb-recursive-watch-data.hoon) |
| Pages and loads | Static and data pages, typed route parameters, indirect and `pure` loads, aliases, and downstream imports | [jibb-page-main](../tests/lib/jibb-page-main.hoon), page review probes |
| Stores | Ordinary inferred and hand-built mains, aliases, multi-case actions, derived state/poke interfaces, and watch evidence | [jibb-store](../tests/lib/jibb-store.hoon), [jibb-store-kind](../tests/lib/jibb-store-kind.hoon), store review probes |
| APIs | General path declarations, typed parameters, multiple diffs and folds, scry paths, ordinary definitions, derived gates, and provenance through imports | [jibb-api-general](../tests/lib/jibb-api-general.hoon), [jibb-todo-api-positive](../tests/lib/jibb-todo-api-positive.hoon), [jibb-request-guards](../tests/lib/jibb-request-guards.hoon) |
| Elements | Private sealing prevents hand-built elements; public constructors retain type arguments; repeated literal attributes are exact errors | [jibb-element-forgery](../tests/lib/jibb-element-forgery.hoon), [jibb-element-positive](../tests/lib/jibb-element-positive.hoon), [review-repeated-attribute](../tests/golden/review-repeated-attribute/) |
| UI keys | `each` and `table` keys contain no gates, including nested gates, through aliases and generic wrappers; element messages may contain gates | [jibb-ui-keys](../tests/lib/jibb-ui-keys.hoon), `types-ui-key-*` |
| Static checking boundary | These rows establish types and compile-time evidence only, not lowering, decoding, rendering, or runtime execution | Later milestones below |

## Prelude

The public and private preludes are checked Jibb source. Their values and molds use the same inference core as ordinary modules; names do not bypass unification. The [prelude inventory](prelude-inventory.md) is the authoritative list of checked interfaces and deliberate omissions.

| Area | Status | Evidence |
| --- | --- | --- |
| Source preparation and groups | Public, internal, `hoon`, and `bit` sources compose with checked boundaries and no private-name leakage | [jibb-prelude-groups](../tests/lib/jibb-prelude-groups.hoon), [jibb-group-bootstrap](../tests/lib/jibb-group-bootstrap.hoon), [jibb-prelude-bit](../tests/lib/jibb-prelude-bit.hoon) |
| Units, lists, and functions | Checked source implementations and generic signatures for the selected inventory, including `hunt`, folds, indexing, editing, sorting, composition, and currying | `types-prelude-*`, [jibb-prelude-helpers](../tests/lib/jibb-prelude-helpers.hoon), [jibb-prelude-list-edit](../tests/lib/jibb-prelude-list-edit.hoon) |
| Arithmetic, text, time, and data molds | Checked aura constraints and representative calls; arithmetic rejects loobeans | [jibb-prelude-arithmetic](../tests/lib/jibb-prelude-arithmetic.hoon), `types-prelude-text*`, `types-prelude-time-print-*`, `types-prelude-data-molds` |
| Collections and equality | `eq`, `mate`, `map`, and the other checked collection interfaces preserve gate-free key constraints and independent instantiations | [jibb-generic-constraints](../tests/lib/jibb-generic-constraints.hoon), [jibb-recursive-map](../tests/lib/jibb-recursive-map.hoon), [jibb-map-private-bit](../tests/lib/jibb-map-private-bit.hoon) |
| UI and request types | `cmd`, `sub`, `ask`, `qath`, `raw-poke`, `program`, `page`, `store`, `theme`, and checked UI constructors | `types-prelude-ui`, [jibb-qath-source](../tests/lib/jibb-qath-source.hoon), [jibb-poke-bridge](../tests/lib/jibb-poke-bridge.hoon) |
| Deliberate omissions | Explicitly listed rather than silently given substitute signatures; execution and jet recognition are milestone 3 | [Deliberately left out](prelude-inventory.md#deliberately-left-out-of-the-checked-prelude) |

## Hoon importer and Clay

| Area | Status | Evidence |
| --- | --- | --- |
| Selected Hoon types | Fixed translation for used atoms, cells, unions, collections, and recursive molds, with source-backed overlap and provenance checks | [jibb-import](../tests/lib/jibb-import.hoon), [jibb-import-general](../tests/lib/jibb-import-general.hoon), `types-import-*` |
| Import diagnostics | Signed/float auras, cores, gates, vases, overlapping unions, repeated fields, missing molds, and invalid readers report definite errors at Jibb use sites | `review-import-*`, [jibb-import-diagnostic](../tests/lib/jibb-import-diagnostic.hoon), strict import probes |
| Source-aware mark origins | Done: a unique declaration is rebuilt from the supplied `/sur` source; selected and raw dependency types must have the same canonical `read-mold` representation. The checker accepts origin only from a unique direct result for that mark. Missing, stale, wrong-path, duplicate, or same-shaped-decoy evidence publishes no origin and never hides the semantic result | [jibb-import-mark-source](../tests/lib/jibb-import-mark-source.hoon), [jibb-external-origin](../tests/lib/jibb-external-origin.hoon) |
| Clay fixtures | `/sur` files and marks build through Clay; imported types feed the full checker, including the required union/atom/map/recursive fixture | `tools/clay-fixtures`, [full-import](../tests/clay-fixtures/full-import.txt) |
| `my-app` | All its modules, 14 now, check in dependency order through real Clay types, with exactly the expected `buttons.jibb` error at 3:16 | `tools/check-my-app` |

## Performance

Measured on 2026-11-06 with final compiler SHA-256 prefix `d369b012` and debug disabled. The generated-module timings include the 52.920-second startup measurement.

| Measurement | Time |
| --- | ---: |
| `tools/hoon --no-debug` startup | 52.920 s |
| 2,000-line module, bottom-up definitions | 75.262 s |
| 2,000-line module, top-down definitions | 76.627 s |
| `my-app`, 11 modules through Clay with source-aware origins | 63.5 s |

`my-app`'s first build through the host, from an empty compile cache, took 53 s on 2026-11-10 in `tools/check-host`, on a fake ship sharing 8 CPUs with other builds at a load average of about 30; at a load average of about 50 it took 107 s. That covers checking its 11 UI modules and the renderer, making its stylesheet and rendering its one static page, one compiler step per Behn wake.

With its pages with data, islands, store and tests, 14 UI modules in all, `my-app`'s first build took 140 s in the flake's ship check on 2026-11-11, and 170 to 491 s in `tools/check-host` on the shared test ship while other builds loaded the machine; island and store modules are compiled to JavaScript in the same build.

Milestone-3 Nock measurements on 2026-11-08 used a temporary focused suite on the fake ship, after all acceptance checks passed. Emission and execution were separate arms; the suite was removed and the accepted desk was restored.

| Case | Nock emission | Nock execution |
| --- | ---: | ---: |
| 200 independent strict bindings | 39.842 ms | 324 µs |
| 128-field right-nested record projection | 1.999 ms | 271 µs |
| 128-branch decision tree | 4.459 ms | 1.303 ms |
| Recursive core | 877 µs | 119 µs |

Use `tools/bench-check` to reproduce the generated-module measurements. The desk number is checking time reported by `tools/check-my-app`, not desk synchronization time.

## Remaining work and open questions

- Milestone 3 is complete. `proj` field reordering still fails closed pending its owner ruling. The additional provenance-checked backend preserves function identity through ordinary data, recursion, and explicit native adapters, with trace-preserving differential controls under eval.
- Milestone 4's acceptance criteria hold on the fake ship. The plan's question of whether the Eyre channel CSRF test reproduces on a fake ship waits for @iko's write-up. The typography scale and the reading of failed builds are [Decisions](spec/decisions.md) rows of 2026-11-09 that @iko may revise. Known host gaps: a generic `/sur` mold in a file with `/-` or `/+` imports is still reported unsupported, since only a Ford-free file is rebuilt for the importer; link and image errors now carry the original element call's source site through imports and nesting; a `chars` or `fill` number of 1,000 or more prints with Hoon's dots, as `1.000`, which CSS reads as 1; and a changed static file renders every static page of its desk again.
- Milestone 5 is complete. Render failures now report the original element call's file, line, column, excerpt and caret, including data pages and island first views; absent or ambiguous provenance retains the unlocated message. Remaining gaps: a fact whose type is a recursive mold fails closed when its request is lowered; and the `%blog` agent is a fixture of the documented examples.
- Milestone 6 is done but for the benchmark's bar, which @iko has yet to agree; the measurements above are from a loaded machine. Known gaps: an island starts by replacing the server's view, not by binding to its nodes; an app's section must be a literal prefix, so a catch-all after a parameter has none; and JavaScript `slot`/`edit` currently reject axes above `Number.MAX_SAFE_INTEGER`, while Core permits arbitrary positive axes. Template analysis preserves that existing runtime diagnostic.
- Milestone 7 is complete: the extended CI run for `633e0c9` passed. The Node harness runs its Nock in the repo's own interpreter rather than nockjs, whose published package has no interpreter.
- Milestone 8 is complete: shared modules, direct view holes and the library size budget passed integrated eval and fresh-ship acceptance. Dynamic attributes and child-list tails deliberately retain whole-element rendering. [compiler.md](compiler.md#browser-dom-and-island-loop) records the boundary and fallback behavior.
- The checked prelude's deliberate omissions are documented in [prelude-inventory.md](prelude-inventory.md); they are not silently implemented with different signatures.
- Open language questions remain in [open-questions.md](open-questions.md), including `proj` field reordering and unconfirmed review proposals. Current checker diagnostics do not settle those proposals.

## Checking it

Strict eval probe batches now share immutable compiler/importer, reader evidence and prepared prelude across at most five adjacent app/plain groups, including at most three app groups. App groups also share mark setup. Each app group retains its own module overrides; plain groups retain `/ui/probe/jibb` with empty external, mark and module inputs. Every case keeps its original `mule` road, fresh inference state and empty module cache. Import-only probes remain separate. The four manifest batches start five eval processes instead of ten before fallback. Their original 348 cases remain, with three added plain-context controls: 351 cases in 16 groups, including 149 expected negatives.

On 2026-11-14, a frozen comparison against `77872bc` measured the complete first manifest batch (`p1`, `p2`, `p3`, `errors-p1`), using pinned Vere 4.6 and Python on x86_64-linux. All 133 inputs, ordered outcomes, full diagnostics, source excerpts and positive type reports matched exactly: all 58,293 returned report bytes. The comparison removed only the one transport newline appended by `tools/hoon --raw` per process; raw outputs were retained. The added controls belong to the fourth batch and do not change this measured corpus.

| First probe batch | Separate plain setup | Shared app/plain setup |
| --- | ---: | ---: |
| Complete batch wall time | 356.37 s | 206.30 s |
| Complete batch child user CPU | 349.75 s | 202.85 s |
| Eval processes | 2 | 1 |

This saves 150.07 seconds (42.1%) wall and 146.90 seconds (42.0%) child user CPU for this batch. CPU includes subprocess Python tools. This is one paired sample on a shared host, with at most two evals active, and does not measure the complete Nix check's critical path. Neither successful run needed resource fallback or diagnostic replay.

A separate real-Hoon control checks the same module, mark and `/sur` mold successfully in app mode and rejects each in plain mode, while a plain positive still checks. Separate and mixed runs returned identical 756-byte reports: four typed successes and three rejections with their exact messages, fixed plain source sites, excerpts and carets. The three negative cases are now permanent `errors-p5` probes with full exact expectations; the generic guard against unrelated unsupported-inference errors is unchanged. Mutating acceptance, message, site, excerpt or caret fails each new expectation. Standalone plain and all-plain generation controls prohibit application fixture and template reads.

The existing batch selftests now cover mixed order and the five-total/three-app limits, original modes through both group and case resource fallback, and app/plain debug replay that cannot clear the initial failure. Manifest validation compares mixed as well as individual programs between full and narrowed source closures. The final Nix graph changes 13 of 50 leaves and preserves 37; the added exact-expectation fixture also changes desk assembly. All 49 source-bearing store closures match their tracked paths, bytes, modes and symlinks. All 348 existing probe inputs and their regenerated ship programs remain identical; both backends select the three added cases. Ship scheduling and the import-only suite are unchanged.

Full `nix flake check -L -j 2 --keep-going` passed on x86_64-linux with all 50 leaves valid: 37 unchanged results were reused and all 13 affected leaves passed. All 351 probe outcomes passed under eval and on fresh ships without resource fallback or diagnostic replay. The tooling selftest passed all 32 checks in 501 seconds, the eight residual checks passed in seven seconds, and the fresh-ship selftest completed in 62 seconds. The browser library remains 55,729 bytes, 19,826 under `gzip -9n`. The full command took 679.17 seconds while reusing the separately completed tooling selftest and sharing work with a fresh-ship build and one separately started eval batch; this is acceptance evidence, not a standalone cold benchmark.

The preceding app-only optimization in `77872bc` shared immutable compiler/importer, reader evidence, prelude and mark setup across at most three adjacent app groups. Plain and import-only programs remained byte-identical and separate. It reduced the four manifest batches from sixteen eval processes to ten before fallback, preserving all then-existing 348 cases and ship-generated programs and scheduling.

On 2026-11-14, a frozen before/after comparison against `8652c2b` used pinned Vere 4.6 and Python on x86_64-linux. The complete first manifest batch includes `p1`, `p2`, `p3` and `errors-p1`: 133 cases. All inputs, ordered outcomes, full diagnostics, source excerpts and positive type reports matched exactly. All 58,293 returned report bytes matched; the audit removed only the one transport newline that `tools/hoon --raw` appends per process, retaining the original raw output files.

| First probe batch | Separate app groups | Shared app setup |
| --- | ---: | ---: |
| Complete batch wall time | 686.30 s | 372.65 s |
| Complete batch child user CPU | 669.00 s | 361.34 s |
| App groups only, wall time | 523.44 s | 213.57 s |
| Separate plain-group control, wall time | 162.86 s | 159.08 s |
| Eval processes | 4 | 2 |

This saves 313.65 seconds (45.7%) wall and 307.67 seconds (46.0%) child user CPU for this batch. CPU includes the subprocess Python tools. This is one paired sample on a shared host, with at most two evals active; it measures complete compilation, setup and checking for the batch, not the full Nix check's critical path. Neither run needed resource fallback or diagnostic replay.

An additional real-Hoon isolation control defines the same module path with an `@ud` value in one group and an `@t` value in another, then imports that path from a third group where it is absent. Separate baseline runs and one combined run return identical 410-byte reports: four typed successes and the expected missing-module rejection, including its exact source site and excerpt. This detects module leakage or accidental concatenation of group sources.

Three new tooling selftests cover group and source ordering, repeated labels across groups, missing/extra/reordered results, whole-group resource fallback in both debug modes, and retention of fast failures after successful debug replay. Existing fast-failure and resource-isolation controls still pass. Manifest validation now compares combined app programs as well as the individual eval inputs and ship programs against their narrowed sources. The Nix graph changes 12 of 50 leaves and preserves 38; actual Git-flake inputs match the clean tracked snapshot, and all 49 source-bearing store closures retain their projected files, bytes, executable modes and symlink targets.

Full `nix flake check -L -j 2 --keep-going` passed on x86_64-linux with all 50 leaves valid: 38 unchanged results were reused and all 12 affected leaves passed. All 348 probe outcomes passed under eval and on fresh ships, without resource fallback or diagnostic replay. The tooling selftest passed all 32 checks in 495 seconds, retaining the original 29 checks in order; all eight residual checks passed in seven seconds, and the ship runner selftest passed in 62 seconds. The full command reused separately completed checks, including fresh-ship work shared with a concurrent Nix build, so its elapsed time is not a standalone cold benchmark.

Library smoke compilation is now cached separately from desk assembly. Its source contains exactly five files: `jibb.hoon`, `jibb-import.hoon`, `tools/hoon`, `tools/urbit_eval.py` and `tools/noun.py`, with pinned Python and Urbit dependencies. Both libraries still compile sequentially with debug instrumentation and the existing timeout. The smoke output contains the exact compiled sources, and `desks` compares both assembled libraries against them. The eval aggregate retains this output through CI cache cleanup.

On 2026-11-14, full `nix flake check -L -j 2 --keep-going` passed on x86_64-linux with all 50 leaves valid. Compared with `7bedfd2`, 48 existing leaves were unchanged and reused; desks changed and the smoke leaf was added. The smoke build phase took 151 seconds, and the incremental full check took 165.72 seconds. These are individual shared-machine measurements with previously cached eval, native and ship results, not a cold full-check benchmark.

All 9,588 files across the five assembled desks have identical bytes and modes to the previous output; all 11,464 filesystem entries match. Two actual Nix controls deliberately changed one assembled library at a time, and both builds failed at the byte comparison while reusing compilation. Mock runs of the evaluated smoke build phase additionally verify that failure of either compiler invocation prevents both certified copies from being saved, and that success logs both results before copying the inputs.

Ten isolated derivation controls passed: ordinary-suite, golden-source, ship-tool and prelude edits reuse compilation; either library, any of the three evaluator helpers, or a pinned-runtime identity change invalidates it. An ordinary-suite edit still changes six check leaves, with 44 of 50 reused, but desk rebuilding now skips the expensive compilation phase. An actual `nix build .#desks` from that edited snapshot rebuilt and validated all five desks in 14.60 seconds without either compilation. The actual Git-flake graph matches the tracked snapshot used for these controls, and the realized eval aggregate links the smoke output. This avoids 151 seconds of compilation work in the measured sample; the complete check's elapsed saving depends on scheduling.

The eval tooling selftest now lists its test scripts and fixtures explicitly. It retains the real compiler/importer/prelude/readers and existing desk support, its own script and stub, the tooling golden cases, `types-import-mark` and its linked Clay mark, and both probe diagnostic data files. Its 29 checks and assertions are unchanged. Ordinary-suite files, the ship selftest and its fixtures no longer invalidate this check.

On 2026-11-14, an audit of the actual Nix sources against `58f7858` found all 139 retained files byte-identical, down from 9,421 files. The assembled desk used by temporary arm suites shrank from 9,296 files to 89. Both retained symlinks preserve their link text and target bytes and resolve within the narrowed source. Fresh Python processes generated 12 representative programs with identical Hoon bytes and source-map segments: debug and fast variants for the tooling golden corpus, logical paths, module fixtures, empty-module/prelude preparation, real fixture-crash cases and synthetic arm suites. Trace parsing, fast-failure preservation and resource-isolation controls also passed without Hoon execution. Scratch fixture copies were made writable to match Nix's unpacked build tree; the store sources and their bytes were unchanged.

Fifteen isolated derivation controls passed. Ordinary-suite edits now change six of 49 check leaves rather than seven, and ship-selftest edits change three rather than four; both preserve the eval-selftest derivation and source path. Changes to the real fixture source or expected output, linked mark, either probe data file, stub, tooling golden fixture, shared helper, compiler, prelude or reader still invalidate it. Compiler, prelude and reader controls invalidate all 49 leaves; the raw Rust build remains unchanged in every control.

Full `nix flake check -L -j 2 --keep-going` passed on 2026-11-14 on x86_64-linux with all 49 leaves valid: 48 were unchanged and reused, and only the tooling selftest rebuilt. All 29 runtime checks passed in their original order in 526 seconds; the full incremental check took 534.57 seconds. Subsequent builds of the selftest leaf from snapshots with an ordinary suite edit or a `ship-selftest` edit reused the identical output in 1.30 and 1.37 seconds, respectively, with no build steps. These are individual shared-machine measurements. The saving comes from avoiding unrelated reruns; uncached runs retain all 29 checks.

The ship golden corpus and ship runner selftest now have separate Nix derivations and fresh piers. The golden source includes the union of the existing eval golden batches' recorded paths, including symlink targets, alongside the desk support sources. The selftest retains the previous full source set and every ordinary-suite, fixture-desk and custom-library/corpus assembly assertion. It now also reruns the valid logical-path stub case immediately after the deliberately broken compiler, requiring exactly one passing arm on the same desk. This preserves failure-to-success recovery coverage that the following real golden run previously provided. `tools/check` still registers and runs both checks.

On 2026-11-13, a comparison of the actual Nix golden source with the complete `d3fa6c7` checkout found all 14 generated ship programs and 1,376 arms identical, with the same 5,471 bound source paths. All 8,488 files in the narrowed assembled desk have the same bytes and provenance as the full desk; 808 unrelated files were removed from its 9,296 files. All 29 golden symlinks retain their link text and target bytes, and all 30 symlinks in the complete narrowed source resolve within it. The tool/helper sources used by this audit are byte-identical.

Isolated Nix derivation controls confirm that an ordinary `jibb-ui-keys` edit now preserves both the `ship-goldens` derivation and source path; the old combined check invalidated. Golden source, expected output, a linked Clay mark fixture, compiler, prelude and Hoon reader edits each still invalidate the golden check. The ordinary-suite control changes seven of 49 leaves and reuses 42: the new broad ship selftest replaces the old golden run among the affected leaves. Compiler, prelude and reader controls invalidate all 49 leaves; the raw Rust build remains unchanged in every control.

The narrowed golden check passed all 1,376 arms on a fresh ship, with zero failures or crashes, in 829 seconds: 164.2 seconds syncing and 664.5 seconds testing. The separate ship selftest passed in 55 seconds, including the explicit recovery assertion. An actual `nix build` from the isolated ordinary-suite-edited snapshot then returned the identical realized golden output in 2.40 seconds, with no build steps.

Full `nix flake check -L -j 2 --keep-going` passed on the final x86_64-linux tree with all 49 leaves valid. Against `d3fa6c7`, 44 existing leaves were unchanged and reused; manifest validation, the residual checks, the tooling selftest and ship goldens changed, and ship selftest was added. All eight residual checks passed in seven seconds and the tooling selftest in 557 seconds. The full check reused separately completed leaves, including the fresh golden run whose inputs were unchanged by the recovery-test addition; its elapsed time is not a standalone cold benchmark.

This targets incremental work: the preceding suite edit reran the golden check for 871 seconds despite unchanged golden inputs. Avoiding that work does not promise an equal wall-time saving under parallel builds. A fully uncached check now starts one additional fresh pier for the separated selftest. At that point, the tooling selftest still used a broad source closure.

The five rejection cases in `jibb-ui-keys` now share one prepared prelude, including its authenticated Hoon-reader evidence. The suite still has three test arms, each preparing independently; preparation calls fall from seven to three. Every case retains fresh inference state and its original empty module cache. All positive and negative Jibb source bytes are unchanged. The negative cases additionally compare the complete diagnostic text, including both source sites, excerpts and carets. A scratch comparison found all five complete detailed results identical before and after reuse; existing missing, stale and forged evidence controls remain unchanged.

Measurements on 2026-11-13 compare `a66cf9f` with this suite change, using pinned Vere 4.6 on x86_64-linux. The complete `arms-6` eval batch contains 85 arms in 32 suites; `tools/bench-eval --batch arms-6 --stage full` returned byte-identical output and all expected results in order. Only the suite source changed among its inputs.

| Complete eval batch | Before | Shared preparation |
| --- | ---: | ---: |
| Wall time | 838.35 s | 754.68 s |
| Evaluator user CPU | 815.25 s | 735.34 s |

That is about 10% less wall and user CPU time for this batch, including the stronger diagnostic assertions. A separate matched-harness prototype of the rejection arm, before adding those assertions, took 228.31 to 170.64 seconds wall and 223.11 to 161.28 seconds user CPU, including common startup and compilation. Preparation-stage controls were not additive and did not establish a separate evidence-construction cost; the setup control briefly overlapped an interrupted duplicate process. These are single observations on a shared machine, not a measurement of the complete Nix check's critical path.

The same 85-arm batch passed on two fresh ships with no failures or crashes. The baseline used a name-only derivation override to force execution despite an existing Nix result; its source, builder, command, desk map and dependencies were unchanged, with only its name and resulting output paths changed. The candidate used the ordinary acceptance derivation.

| Fresh-ship measurement | Before | Shared preparation |
| --- | ---: | ---: |
| Rejection arm | 122.47 s | 25.41 s |
| Complete three-arm UI-key suite | 171.84 s | 76.38 s |
| Complete 85-arm test phase | 1,029.7 s | 974.2 s |
| Build client wall time, including setup | 1,043.42 s | 987.78 s |

The two independently prepared UI-key controls took 24.42 and 24.96 seconds before, and 24.93 and 26.04 seconds after. Sharing saved 95.46 seconds in the suite (55.6%); the complete ship test phase saved 55.5 seconds (5.4%). Unrelated arms took 705.68 seconds before and 743.44 seconds after. The ships overlapped other work at different times, so these single samples do not isolate background-load effects or establish an overall Nix speedup.

Full `nix flake check -L -j 2 --keep-going` passed on x86_64-linux. Compared with `a66cf9f`, 41 of 48 check leaves were unchanged and reused; all seven changed leaves passed: desks, eval batch 6, manifest validation, the eight residual checks, the tooling selftest, ship batch 6 and ship goldens. The official eval batch passed in 788 seconds and the tooling selftest in 546 seconds. The fresh golden pier passed its selftest in 43 seconds and all 1,376 goldens in 871 seconds, including 210.1 seconds syncing and 660.5 seconds testing. Current runner discovery still counts 274 suites with 681 ordinary arms, 1,376 goldens and 348 probes per backend. Required leaves were prebuilt separately and reused by the full check; this validation is not a cold timing of the complete check.

Eval profiling on 2026-11-13 used the unchanged programs from `f843494`, pinned Vere 4.6 on x86_64-linux, and compiler SHA-256 `b6a9f82b5b13bdd52cfc3bc0b2d9757d9e7818fc6c2cfa0b5516a9d3042ae38f`. `arms-2` contains 87 arms in 33 suites; `arms-builder` contains 21 arms in two suites. Both unchanged and trap-wrapped executions returned every expected arm result in order. Fresh-process startup took 0.40–0.47 seconds wall and 0.33–0.39 seconds user CPU; compiling only the root compiler took 75.38–75.77 seconds wall and 73.09–73.18 seconds user CPU.

| Eval stage | Regular wall | Regular user CPU | Builder wall | Builder user CPU |
| --- | ---: | ---: | ---: | ---: |
| Shared libraries and bound inputs | 155.5 s | 150.9 s | 157.8 s | 153.6 s |
| Compile complete batch without executing arms | 165.5 s | 160.5 s | 167.2 s | 159.7 s |
| Execute through the profiling trap | 1,014.5 s | 988.1 s | 664.7 s | 642.2 s |
| Unchanged complete batch | 999.2 s | 975.7 s | 638.5 s | 626.9 s |

These are individual runs on a shared machine, with at most two eval processes active. Stage subtraction estimates that test execution accounts for roughly 75–84% of these two batches' user CPU time; it is not an additive accounting of compiler work, memoization and garbage collection. The trap changes the subject, so its successful execution and its timing relative to the original program are necessary controls. `tools/bench-eval` reproduces the measured programs, freezes source/runtime hashes and expected results before starting, and retains raw output, diagnostics and wall/user/system timings in a new evidence directory. Its Python regression controls cover exact program generation, evidence preservation, ordered results, exit-zero crashes and timeouts; a real startup smoke passed under `nix develop`.

A compiler-artifact prototype remains experimental. It saved a 967,186-byte typed constructor formula, executing construction afresh on each load; a small crash/trace control verified repeated construction. Producing the artifact took 90.33 seconds wall and 87.69 seconds user CPU, including Python work. A loader smoke took 21.41 seconds wall and 20.60 seconds evaluator user CPU. Complete cached runs returned all 87 and 21 expected results: 961.80 seconds wall / 934.51 seconds user CPU for the regular batch, and 611.62 / 599.49 seconds for the builder batch, including loader generation, validation and output handling.

| Sum of the two measured batches | Wall time | User CPU |
| --- | ---: | ---: |
| Original programs | 1,637.6 s | 1,602.6 s |
| Compiler artifact already available | 1,573.4 s | 1,534.0 s |
| Create the artifact and run both batches | 1,663.8 s | 1,621.7 s |

The warm saving is about 4%; including creation makes this first pair about 1–2% slower. These sums describe the two sampled batches, not the critical path of all nine batches or the complete Nix check. Baseline CPU figures measure Vere alone; cached totals also include approximately 0.2 seconds of Python user CPU per batch. A separate cached regular-prefix control preserved the subject hash and took 129.68 seconds wall / 125.50 seconds user CPU, saving only about 25 CPU seconds over the original prefix; compiler-only and loader-smoke times cannot predict the complete saving. This sample does not justify adding the artifact format and loading path to production, so normal checks retain source compilation. Test execution is the larger remaining target.

Parser equivalence was checked separately from passing test output. The initial builder prototype used `rain` with a custom base path, changing the meaning of the existing `%/nowhere` in `jibb-build` despite all 21 tests passing; that measurement is excluded above. The corrected builder run uses `ream`, with a separate default-path control. The compiler source and regular suffix produced identical ASTs under both parsers, so their earlier measurements remain usable. Any future cache must preserve the default parser, constructor effects, crash/trace behavior, exact input identities and full-source diagnostic replay.

The profiling tool and its regression coverage passed `nix flake check -L -j 2 --keep-going` on x86_64-linux. Derivation comparison with `f843494` confirmed 44 of 48 leaves unchanged; the four changed leaves passed: manifest validation, all eight residual checks, the tooling selftest in 622 seconds, and ship goldens on a fresh pier. The latter passed its selftest in 41 seconds and all 1,376 goldens in 837 seconds, with no failures or crashes. The full check reused those prebuilds and completed both aggregate outputs. No compiler artifact is enabled in Nix or the normal test runners.

Builder-dependent test suites now have a separate `arms-builder` batch under eval and on a fresh ship. Membership follows the actual library and bound-file source closure, including indirect imports; it is extracted after the existing eight-way assignment, so all 272 other suites keep their original positions. The current dedicated batch contains `jibb-build` and `jibb-build-probe`: 21 arms in two suites. Previously, a builder edit reran 197 arms in 66 suites per backend, including 176 unrelated arms. All 681 ordinary arms in 274 suites remain covered exactly once, and full, narrow and ship-map programs agree. Synthetic dependency and CLI controls pass; all nine batches' debug and fast programs are byte-identical to programs produced by the previous runner for the same suite selections.

Isolated Nix derivation comparisons show a builder-only edit invalidating 10 of 48 check leaves, versus 12 of 46 before the split. All eight regular eval and ship arm batches stay cached; the new builder batches and other builder-dependent integration checks still rebuild. A new test with an indirect builder dependency joins the dedicated batch, and a compiler edit still invalidates all 48 leaves. The raw Rust build is reused in every control. These comparisons establish invalidation behavior, not execution timings. A fully uncached suite pass now starts nine eval processes and nine fresh suite piers instead of eight of each; the saved work above applies when the unrelated batches are already cached.

Local timings on 2026-11-13 compare the affected batches with the previous runner, using identical Hoon sources. The new eval batches took 689 seconds (regular 5), 872 seconds (regular 6), and 708 seconds (builder). The corresponding ship test phases took 1,006.8, 1,519.3, and 1,037.6 seconds.

| Affected arm work | Previous | After split |
| --- | ---: | ---: |
| Eval after a builder-only edit | 2,224 s (197 arms) | 708 s (21 arms) |
| Eval with every affected batch uncached | 2,224 s (2 batches) | 2,269 s (3 batches) |
| Ship test phases after a builder-only edit | 2,974.7 s (197 arms) | 1,037.6 s (21 arms) |
| Ship test phases with every affected batch uncached | 2,974.7 s (2 batches) | 3,563.7 s (3 batches) |

These are sums of batch durations, not elapsed times for the complete check. Both cold cohorts execute the same 197 arms, and both became slower in this sample. Including setup, the summed cold ship build phases rose from 2,994 to 3,595 seconds. Historical and current runs shared the machine with different work. An unchanged eval batch, with identical command and all 44 Hoon inputs, took 1,398 seconds versus 929 previously. That variation prevents attributing the cold increases either to the extra batch alone or to contention alone; these runs do not establish a cold-run speedup. The incremental rows assume the unrelated batches are cached and leave out the other builder-dependent integration checks.

Full `nix flake check -L -j 2` passed on x86_64-linux with all 48 check leaves valid: 30 were unchanged and reused, and all 18 new or changed leaves passed. Acceptance covers all 681 ordinary arms in 274 suites and 1,376 goldens on both backends, 348 probe outcomes per backend, 128 Rust tests and 322 JavaScript tests. The tooling selftest passed in 552 seconds, all eight residual checks passed, and the fresh host/browser/Node chain passed in 1,010.7 seconds. The browser library remains 55,729 bytes, 19,826 under `gzip -9n`. The selftest and dedicated ship batch were prebuilt separately, and additional ship builds shared results with the full check; its 5,811.5-second wall time is not a standalone cold benchmark. A final cached rerun passed in 7.4 seconds with `running 0 flake checks`.

Render preparation now memoizes page linking, renderer/theme linking with authenticated native selection, and Nock emission. It retains page-owned diagnostic sources and keys emission by the actual native gates. Execution, reference validation and serialization still use the current render context; facade signatures, prepared data-page layout and host state are unchanged. The runtime's persistent memo cache is shared and limited by entry count, not bytes; eviction only causes recomputation.

Fresh-ship Nix host/browser/Node acceptance passed on the production source. Against `2c39dd6`, the complete chain fell from 2,454.9 to 1,014.9 seconds, saving 1,440.0 seconds (58.7%). All existing assertions remained in place:

| Measurement | Before | After |
| --- | ---: | ---: |
| Fresh fixture build | 240.5 s | 302.8 s |
| Fresh `my-app` build | 141.6 s | 152.2 s |
| Static asset change, deletion and restoration | 564.5 s | 26.9 s |
| Render diagnostics and recovery | 755.9 s | 134.8 s |
| Broken-import recovery | 380.5 s | 19.8 s |
| Browser acceptance | 20.4 s | 20.8 s |
| Node agreement | 14.3 s | 13.7 s |

Both cold builds regressed in this sample. These single runs shared the machine with other jobs; they cannot separate cache setup, key hashing and compilation overhead from load effects. The browser run measured 40 keystrokes in the 500-row island at 4× CPU slowdown: median 11.9 ms, p95 17.5 ms and maximum 20.0 ms. No unagreed performance bar was imposed. Six current test results agreed across JavaScript, Nock and `-jibb!test`, and the pier stopped cleanly.

A focused fresh-ship run on 2026-11-13 exercised three static pages and one data page, with seven checked modules. The first build made four page-link calls, four kit-link calls and 85 emission calls, with 4, 4 and 25 misses respectively. Five asset-only commits each reused all 93 computations with zero misses and unchanged checked-module revisions. They passed current image URL, byte and dimension checks, exact missing-image diagnostics and restoration, unchanged unrelated HTML/CSP, and distinct data responses for parameters 41, 42 and 41. Persistent memo storage grew from 4,394,720 to 5,378,592 bytes on the initial build and stayed exactly flat across those commits. The rebuilds took 15.7, 15.6, 4.9, 4.7 and 4.7 seconds; these focused timings are not a baseline comparison.

A separate real-ship probe called the desk's Ford-built `+execute-linked` in four events. Both repeated successes returned 42 and emitted their trace; both repeated crashes retained their exact diagnostic and emitted their trace. Each pair's second call hit the emission cache. Scratch counters and probes are absent from the production sources. The current runner discovers 681 ordinary arms in 274 suites, plus 1,376 golden cases.

Render-stage profiling on 2026-11-13 compares `2c39dd6` with `57d41eb` using the checked host fixture's About page, default theme and vendored renderer under pinned, debug-disabled eval. Each fresh process compiled and checked the same inputs and prepared the stage inputs once before repeating one operation. Marginal times subtract a no-loop control's user CPU time: baseline controls were 186.85 and 208.11 seconds; candidate controls were 194.35 and 196.75 seconds. The ranges below subtract each observed control; they are not statistical confidence intervals.

| Repeated operation | Repetitions | Marginal CPU time per operation |
| --- | ---: | ---: |
| Baseline page linking | 10 | 0.54–2.67 s |
| Baseline support linking: theme, 18 renderer entries and attribute decoder | 10 bundles | 6.08–8.20 s |
| Baseline complete kit preparation | 6 | 5.27–8.81 s |
| Baseline element-to-vnode conversion | 50,000 | 0.15–0.58 ms |
| Baseline HTML serialization: 609 bytes per document | 20,000 | 0.41–1.47 ms |
| Baseline complete render | 6 | 4.76–8.30 s |
| Candidate complete render | 1,000 | 4.08–6.48 ms |

Additional baseline runs covered native discovery (500 bundles), Nock emission (100 bundles), execution of already-emitted programs (50,000 bundles), and reference validation (100,000 trees). Each program bundle contains the page, theme, attribute decoder and 18 renderer entries: 21 programs. Their smaller marginal costs were not resolved against the baseline control spread. The stage scopes overlap, and separate process measurements do not form an exact additive breakdown. Some component estimates exceed the separately measured complete render; these runs locate expensive stages without establishing their proportions.

The candidate's common setup warmed kit and emission caches; its complete-render loop still included one initial page-link cache miss. Every render executed the programs, checked references and serialized HTML again. These timings describe this fixture; the complete host measurements establish the effect on the acceptance workload.

For the render-cache change at `57d41eb`, full `nix flake check -L -j 1` passed on x86_64-linux, reusing unchanged checks and completing all 46 check leaves. The changed eval shards passed 111 and 86 arms in 1,152 and 1,072 seconds; their fresh-ship counterparts passed with no failures or crashes. The complete check set covers all 681 ordinary arms and 1,376 goldens on both backends, all 348 probe outcomes on each backend, 128 Rust tests and 322 JavaScript tests. The tooling selftest passed in 562 seconds, all eight residual checks passed, and the browser library remained 55,729 bytes, 19,826 under `gzip -9n`. A final `nix flake check -L -j 2` rerun passed in 7.5 seconds with `running 0 flake checks`.

GitHub Actions [run 43415210856](https://github.com/iko-soy/jibb/actions/runs/43415210856) passed for `57d41eb`. It restored the `2c39dd6` Nix cache, reused 34 of 46 check leaves and rebuilt the 12 affected leaves: eval and ship arm shards 5/6, eval manifest/residual/selftests, ship base/goldens/host, desks and the CLI wrapper. The raw Rust CLI was reused. The Nix check step took 24 minutes 9 seconds; host/browser/Node acceptance took 360.7 seconds within it. Rooting and cache garbage collection succeeded, and the commit's new cache was saved at 1,204,521,045 bytes (1.12 GiB). These CI timings are separate observations from the local comparison.

Host-chain profiling on 2026-11-13 removed redundant builds from acceptance setup and cleanup. Applications remain suspended until the host is installed, and each first build asserts that no earlier result, checked module or published file exists. After `-jibb!clear`, an unrelated Clay commit republishes `my-app` assets while retaining its checked modules; the runner restores the temporary file in both the filesystem and Clay and verifies every asset's public, immutable response. Nix runs browser and Node acceptance before the final fixture suspension, then stops its disposable pier. Standalone runs still revive the fixture, and failures retain restoration cleanup. All 98 original host assertion sites remain; 14 mocked republish cases, 19 lifecycle cases and six pinned Nix exit-hook cases passed.

The timing-only baseline and optimized full `nix flake check -L -j 2` both passed on x86_64-linux. Unchanged check results were reused; host acceptance ran on a fresh pier in each run. Phase records are retained in `shipHost/timings.jsonl` with the aggregate log. This is one before/after pair on a shared machine, not a general throughput guarantee:

| Measurement | Baseline | Optimized |
| --- | ---: | ---: |
| Complete host/browser/Node tools, excluding pier startup/shutdown | 3,005.4 s | 2,454.9 s |
| Fresh fixture build | 408.7 s | 240.5 s |
| Fresh `my-app` build | 136.4 s | 141.6 s |
| Browser runner, including setup | 357.6 s | 20.4 s |
| Browser execution and measurement itself | 6.0 s | 6.0 s |
| Node runner | 14.7 s | 14.3 s |
| Complete incremental Nix command | 3,028.9 s | 2,466.7 s |

The tool chain saved 550.5 seconds (18.3%). The cached `my-app` republish took 20.3 seconds; browser waits for applications fell from 307.8 to 3.4 seconds. The unchanged expensive phases remain static-asset mutation/restoration (564.5 seconds), render diagnostics (755.9 seconds) and broken-import recovery (380.5 seconds). Browser acceptance and JavaScript/Nock agreement passed, and the ship stopped cleanly. An unchanged rerun passed in 5.2 seconds with `running 0 flake checks`. The browser measurement was median 17.4 ms, p95 27.8 ms and maximum 28.6 ms for 40 keystrokes at 4× CPU slowdown; no unagreed benchmark bar was imposed. Compiler, runtime and vendored browser bytes are unchanged.

Cross-commit CI caching is verified by two successful push runs. The [initial run for `39c1c76`](https://github.com/iko-soy/jibb/actions/runs/43374787405) missed the cache, checked in 9,272 seconds, and saved 1,173,476,278 bytes (1.09 GiB) in a 20-second cache post step. The [following run for `f3c6952`](https://github.com/iko-soy/jibb/actions/runs/43393927942) restored that exact cache key in 31 seconds and checked in 1,347 seconds. Only three of 46 check leaves rebuilt: `eval-manifest`, `eval-residual` and `ship-host`, plus their two aggregate link farms. The other 43 leaves, raw Rust build and clean fake-ship seed were reused. The host/browser/Node chain took 1,307.7 seconds, including browser in 9.4 and Node in 6.0; rooting took five seconds, and the 18-second cache post step saved 1,182,233,733 bytes (1.10 GiB). These CI totals combine cache reuse, changed host orchestration and different build loads; use the local pair above for the narrower host comparison.

Nix check optimization on 2026-11-13 adds recorded ship/probe input closures, separate Rust compilation and CLI packaging, GitHub Actions result caching, and fast eval with instrumented failure replay. Isolated derivation comparisons show a runtime-bundle-only edit invalidating 8 of 46 check leaves instead of 24, and a browser-driver-only edit invalidating 3 instead of 5. A suite-only edit changes its matching eval/ship shards; a compiler edit still invalidates all 46 checks. The raw Rust derivation is reused in all four controls. Manifest validation compares full and narrow arm programs, probe inputs and desk sources; mapped-input negative tests and fast-runner failure/replay tests pass.

Before implementation, an unchanged cached check passed in 7.8 seconds. On the same source, one two-suite, three-arm timing sample took 286 seconds with debug and 201 without it; compiler-only startup took 107 and 70 seconds. These include startup and are single samples on a shared machine, not an estimate of whole-suite speedup. CI now roots successful check outputs, the separate Rust executable and the clean fake-ship seed before saving its cache; the two-run transfer and reuse evidence is above.

Final `nix flake check -L -j 2` on x86_64-linux passed all 46 check leaves: desk compilation, CLI packaging and its installed-helper smoke check, 128 Rust tests, 322 JavaScript tests, all 1,376 golden cases and 679 ordinary arms in 274 suites under both eval and fresh ships, and all 348 probe outcomes on each backend. The tooling selftest passed all 29 checks in 536 seconds, and the eight residual checks passed in 7 seconds. Eval arm batches took 344–1,078 seconds; the host/browser/Node chain took 3,340 seconds (2,936 / 384 / 17). Independent ship builds ran alongside eval on a shared machine, so these are acceptance measurements rather than a controlled whole-run speedup comparison. An unchanged rerun passed in 0.7 seconds with `running 0 flake checks`. The CI root-creation command and workflow lint passed; the browser library remained 55,729 bytes, 19,826 gzipped.

Direct-hole evaluation passed all 319 JavaScript tests, 41 exact Hoon/JavaScript emitter fixtures, three direct semantic arms and eight checked-source/template arms on 2026-11-11. Conditional-branch regressions retain shared cell and callback identity, and nested probes consume the same residual fuel bound. The bundle check passed at 55,463 minified bytes and 19,740 under `gzip -9n`; desk compilation also passed. Complete incremental eval and fresh-ship acceptance passed.

The initial incremental Nix split used 14 dependency-aware golden batches, eight narrow arm shards and three fresh-pier ship groups. `tools/eval-manifest --check` verifies all 1,376 cases and 274 suites and requires identical full and narrow arm programs. The filtered-ship no-ship selftest passed. Golden batch 14 passed all 76 cases in 188.3 seconds and its second realization reused the result without rebuilding. Arm shard 1 passed 87 arms in 35 suites in 854 seconds, including the exact JavaScript emitter corpus. The full `nix flake check -L -j 2` run passed desk compilation, all 128 native CLI tests, all 14 golden batches (1,376 cases), all eight arm shards (676 arms in 274 suites) and the nine residual eval checks. Its slowest eval groups were the residual checks at 3,610 seconds and arm shard 7 at 1,364 seconds. All three fresh-pier groups passed: 676 ordinary suite arms in 7,048 seconds (group 7,051), 1,376 golden arms in 775 seconds (group 821), and seven integration checks in 3,674 seconds, including host in 1,717 seconds and browser in 343 seconds. The ship corpora passed all 2,052 arms with no failures or crashes. An immediate rerun reported every check previously built and `running 0 flake checks`.

The next acceptance graph split separated eval probes and the tooling selftest, partitioned ordinary ship suites into the manifest's eight fresh-pier groups, and split ship integration into base, probe and host/browser/Node groups. Explicit `--suite` selection rejects generated goldens, duplicates, unknown names and incompatible modes before syncing. The no-ship selftest and Nix graph evaluation pass. Representative ship shard 2 passed all 87 arms in 1,210.5 seconds with only 142 files in its narrow desk and stopped its pier cleanly. The complete partitioned run passed all 1,376 golden cases and 676 ordinary suite arms in 274 suites, with no failures or crashes. Its longest groups were eval probes at 3,118 seconds, the host/browser/Node chain at 2,225 seconds, ship probes at 1,390 seconds and ship arm shard 7 at 1,398.9 seconds; the tooling selftest took 482 seconds and base integration 327 seconds. An immediate rerun reported every check previously built and `running 0 flake checks`.

Strict probes now use four manifest-checked batches covering `p1`–`p10`, `errors-p1`–`errors-p5` and `imports` exactly once on both backends. Eval batch 1 passed all 133 probes in 795 seconds; ship batch 4 passed `p10` 11/11, `errors-p5` 4/4 and all 31 importer probes in 263 seconds, with a clean independent pier. The complete run passed all 348 source and importer probe outcomes on both backends. The other eval batches took 910, 777 and 565 seconds; the other ship batches took 465, 425 and 375 seconds. In that run, the host/browser/Node chain was the longest group at 2,195 seconds. An immediate rerun reported every check previously built and `running 0 flake checks`.

Source-located render diagnostics passed all 18 `jibb-build` arms and 39 lowering/template/emitter arms, plus 322 JavaScript tests and the exact Core golden. Static and data-page failures now show the original element call's source location, including imported and nested ownership; renderer-provided provenance cannot overwrite it, and island decode failures keep their crash notice. The HTTP fixture checks exact messages, source excerpts and carets for direct, imported, data-page, island and unreadable-image failures. On 2026-11-13 the complete incremental run passed every eval and fresh-ship check: 1,376 golden cases and 679 ordinary suite arms in 274 suites, 2,055 golden/suite arms on ships, all 348 probe outcomes on both backends, host in 2,629 seconds and browser in 352 seconds. An immediate rerun reported `running 0 flake checks`.

Sealed-model resumption passed all 322 JavaScript tests. Boot restores seals only for the host-produced result of checked `init`, preserving nested sharing and later DOM identity; generic `cue` and non-boot packed-model callers still reject copied wrappers. The regression uses the real boot path with a model-retained element and a second render after an update. The current checker still rejects element-bearing island model types at its gate-free boundary, so no checked-Jibb fixture is claimed. The regenerated library is 55,729 minified bytes and 19,826 under `gzip -9n`, 174 below the strict limit. On 2026-11-12 the corrected full incremental run passed all eval and fresh-ship checks: residual eval in 3,576 seconds, host in 1,693 seconds, browser in 345 seconds, ship goldens in 758 seconds and ordinary ship suites in 7,065 seconds.

The isolated browser run passed all eight checks. Precise V8 coverage verified direct evaluator calls in the real todo, timer and rows modules; draft typing retained the unchanged keyed subtree's vnode as well as its DOM. Coverage was disabled before the separate 40-keystroke benchmark at 4× CPU slowdown: median 12.7 ms, p95 19.7 ms, maximum 22.1 ms, and script median 8.9 ms. No unagreed performance bar was imposed.

The constant-attribute and element-hole extension on 2026-11-11 passed `nix flake check`: desk compilation (160 seconds), all 128 native CLI tests, all 18 eval checks in 6,685 seconds, and all nine fresh-ship checks in 11,775 seconds. Eval covered 1,376 goldens and 673 Hoon arms in 273 suites; the ship passed all 2,049 golden/suite arms in 8,081 seconds, with no failures or crashes. All 283 JavaScript tests, 26 exact Hoon/JavaScript emitter fixtures, 11 differential outcomes, strict probes and documentation checks passed.

`check-host` passed in 1,761 seconds, with my-app's first build measured at 140 seconds. `check-browser` passed all eight checks in 367 seconds, including retained static attributes, focus/caret and keyed rows in the real todo and 500-row islands. The benchmark measured 40 keystrokes at 4× CPU slowdown: median 16.5 ms, p95 20.1 ms, maximum 22.0 ms, and script median 11.6 ms. The library is 55,279 minified bytes and 19,664 bytes under `gzip -9n`, below the strict 20,000-byte limit. Intermediate element-noun allocation remains unfinished.

An initial integrated run reached the 1,800-second eval limit in shard 5 without an assertion diagnostic and was stopped before completion. Registered shards now allow 3,600 seconds per eval, and golden isolation stays within the runner's job cap. The retry's unchanged assertions passed, with shard 5 completing in 1,673 seconds. The golden runner split its 1,376- and 688-case batches after `%oops` bailouts; every case passed after isolation.

An earlier isolated browser run passed all eight steps in 677 seconds with unchanged compiler/runtime inputs. It ran alongside full eval checks and measured a median of 28.2 ms, p95 of 69.0 ms, maximum of 81.9 ms, and script median of 20.7 ms. Both browser runs were on a shared machine; no agreed acceptance bar was imposed.

Milestone-8 template work on 2026-11-10 passed `nix flake check` on the final source: the native CLI, desk compilation (136 seconds), all 18 eval checks (6,662 seconds), and all nine fresh-ship checks (10,940 seconds). Eval covered 1,376 goldens and 667 Hoon arms in 272 suites; the ship passed all 2,043 golden/suite arms in 7,482 seconds, with no failures or crashes. All 270 JavaScript tests, 23 exact Hoon/JavaScript emitter fixtures, strict probes and documentation checks passed. An initial ship attempt stopped when the build filesystem filled; the retry reused the passing eval result and ran the unchanged ship group on a fresh pier after space recovered.

`check-host` passed in 1,623 seconds, with my-app's first build measured at 130 seconds. `check-browser` passed all seven checks in 343 seconds, including shared modules and the real timer island's compiled template. The 500-row benchmark measured 40 keystrokes at 4× CPU slowdown: median 13.4 ms, p95 21.6 ms, maximum 23.0 ms; the island's own work had a median of 9.6 ms. These are measurements on a shared machine, with no acceptance bar imposed. The library was 54,868 minified bytes and 19,518 bytes under `gzip -9n`. This validated the first template slice; other hole kinds and removing intermediate element nouns were unfinished.

The preceding size/sharing commit, `fc71705`, passed all 251 JavaScript tests, the deterministic bundle check and tooling selftests. Its bundle was 19,938 bytes under `gzip -9n`, down from 20,618 with the same measurement. Its full Nix run had passed the native CLI, desk compilation and ship selftest when the owner requested the push; remaining eval and ship checks were still running then. Its GitHub Actions run subsequently passed the full checks.

An earlier `nix flake check` run on 2026-11-10 passed every eval check, among them all 1,376 golden cases, the eight test-arm shards, the strict probes, `doc-format` and `bundle-js`, and every ship check but one: `ship-test`, `check-commit`, `clay-fixtures`, `check-my-app`, `check-host`, `check-node-tests` and `probes-ship`. `check-browser` hung there, because the sandbox has no fonts and Chromium's renderer hangs laying out text without them. The ship check now gives Chromium a fontconfig with DejaVu fonts, and the browser driver fails a call with no answer rather than waiting; in the same sandbox, on a fresh fake ship, `check-browser` and `check-node-tests` then passed.

[Before pushing](development.md#before-pushing) documents `tools/check`, its eval/native/ship groups, and `nix flake check`. Individual suites and goldens can be selected with `tools/test-arms`, `tools/golden --case`, and `tools/probe-regression`. Milestone acceptance requires the full integrated eval and ship checks, as well as that milestone's specific criteria.
