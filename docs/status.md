# Status

As of 2026-11-11. This is the current capability and acceptance table. History and dated review findings are in git and [reviews/](reviews/). The plan is [spec/implementation-plan.md](spec/implementation-plan.md); every milestone requires its checks to pass on a fake ship as well as under eval.

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
| 8 | Polish | In part: island and store modules are shared across pages and evaluated once per page. Templates now include constant layout attributes and dynamic element holes, whose controls and keyed lists use ordinary rendering within the static layout. The library is 55,279 minified bytes and 19,664 bytes under `gzip -9n`; `tools/bundle-js` enforces the owner's limit of fewer than 20,000 gzipped bytes. The extension passed integrated Nix eval and fresh-ship checks. Intermediate element-noun allocation remains unfinished |

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
| The browser code agrees with the reference interpreter | `test-js-differential` runs the shared corpus through the JavaScript backend and the Hoon Core interpreter; `jibb-js` checks that the Hoon emitter the host compiles islands with gives the JavaScript compiler's text on `tests/js-emit`'s 26 cases, including template bounds and descriptor branches; the Node harness runs each test arm in JavaScript and Nock |
| A keystroke in the benchmark's list island meets the bar | Waits for the bar, which is still an open question. In headless Chromium at a 4x CPU slowdown, in the Nix sandbox on a fresh fake ship on 2026-11-11, a keystroke in the host fixture's 500-row list island took a median of 16.5 ms and a p95 of 20.1 ms, the island's own update, view and patch a median of 11.6 ms and the rest Chromium's style and layout; on the shared test ship, a median of 14.4 to 15.5 ms and a p95 of 23.5 to 25.6 ms; under heavier load, at a load average of about 20, medians were 15 to 46 ms. Views now reuse their unchanged parts: before that a keystroke took a median of 58 ms at 4x, and before the runtime stopped checking whole nouns on every operation, 7.5 s. In Node, without the browser's layout, the island's work takes a median of 0.5 ms. `tools/check-browser --bar=16` fails a p95 over 16 ms |

| Area | Current evidence |
| --- | --- |
| Islands on the ship | `jibb-build` (15 arms) renders an island's first view with its model and the page's client configuration, compiles it for the browser, and refuses a page; the host's build compiles each island and store module after the checks and publishes their files and the library, which `tools/check-host` fetches logged out |
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
| Preserved behavior | The original view still evaluates once per render, including strict discarded work, crashes and traces. All holes decode before any patch. Tests cover Unicode and invalid UTF-8 decoding, failed renders, independent instances, replacement views, custom native registries and foreign JavaScript callbacks. Element holes retain the ordinary decoder's page paths and the DOM patcher's controls and keyed reconciliation. Only checked browser modules with the frozen canonical native table activate templates |
| Scope | Fixed `row`, `column`, `wrap`, `stack` and `el` with constant attributes, `para`, known heading levels and text. Dynamic attributes, controls, routes, unknown shapes and dynamic child lists use whole-element holes within a fixed layout; a wholly dynamic root keeps ordinary rendering. Attribute and list analysis have independent bounds, and exhaustion declines the complete plan. Intermediate element nouns are still allocated |
| Browser library | 55,279 minified bytes; 19,664 under `gzip -9n`, 336 below the strict 20,000-byte limit. Pinned esbuild and Terser use standard compression without unsafe transforms or property mangling. The bundle check enforces both size and freshness |

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
- Milestone 4's acceptance criteria hold on the fake ship. The plan's question of whether the Eyre channel CSRF test reproduces on a fake ship waits for @iko's write-up. The typography scale and the reading of failed builds are [Decisions](spec/decisions.md) rows of 2026-11-09 that @iko may revise. Known host gaps: a generic `/sur` mold in a file with `/-` or `/+` imports is still reported unsupported, since only a Ford-free file is rebuilt for the importer; link and image errors name the path but not its source site, because they are checked on the rendered page; a `chars` or `fill` number of 1,000 or more prints with Hoon's dots, as `1.000`, which CSS reads as 1; and a changed static file renders every static page of its desk again.
- Milestone 5 is complete. Known gaps: a fact whose type is a recursive mold fails closed when its request is lowered; a page's error messages name no source site for failures found while it renders; and the `%blog` agent is a fixture of the documented examples.
- Milestone 6 is done but for the benchmark's bar, which @iko has yet to agree; the measurements above are from a loaded machine. Known gaps: an island starts by replacing the server's view, not by binding to its nodes; a model containing a sealed element cannot be shown again after it crosses to the browser; an app's section must be a literal prefix, so a catch-all after a parameter has none; and JavaScript `slot`/`edit` currently reject axes above `Number.MAX_SAFE_INTEGER`, while Core permits arbitrary positive axes. Template analysis preserves that existing runtime diagnostic.
- Milestone 7 is complete: the extended CI run for `633e0c9` passed. The Node harness runs its Nock in the repo's own interpreter rather than nockjs, whose published package has no interpreter.
- Milestone 8: the library meets its size budget; fixed layouts now include constant attributes and dynamic element holes. The extension passed the integrated eval and fresh-ship checks. Removing intermediate element-noun allocation remains; dynamic attributes and child-list tails still use whole-element rendering. [compiler.md](compiler.md#browser-dom-and-island-loop) records the current boundary and fallback behavior.
- The checked prelude's deliberate omissions are documented in [prelude-inventory.md](prelude-inventory.md); they are not silently implemented with different signatures.
- Open language questions remain in [open-questions.md](open-questions.md), including `proj` field reordering and unconfirmed review proposals. Current checker diagnostics do not settle those proposals.

## Checking it

The constant-attribute and element-hole extension on 2026-11-11 passed `nix flake check`: desk compilation (160 seconds), all 128 native CLI tests, all 18 eval checks in 6,685 seconds, and all nine fresh-ship checks in 11,775 seconds. Eval covered 1,376 goldens and 673 Hoon arms in 273 suites; the ship passed all 2,049 golden/suite arms in 8,081 seconds, with no failures or crashes. All 283 JavaScript tests, 26 exact Hoon/JavaScript emitter fixtures, 11 differential outcomes, strict probes and documentation checks passed.

`check-host` passed in 1,761 seconds, with my-app's first build measured at 140 seconds. `check-browser` passed all eight checks in 367 seconds, including retained static attributes, focus/caret and keyed rows in the real todo and 500-row islands. The benchmark measured 40 keystrokes at 4× CPU slowdown: median 16.5 ms, p95 20.1 ms, maximum 22.0 ms, and script median 11.6 ms. The library is 55,279 minified bytes and 19,664 bytes under `gzip -9n`, below the strict 20,000-byte limit. Intermediate element-noun allocation remains unfinished.

An initial integrated run reached the 1,800-second eval limit in shard 5 without an assertion diagnostic and was stopped before completion. Registered shards now allow 3,600 seconds per eval, and golden isolation stays within the runner's job cap. The retry's unchanged assertions passed, with shard 5 completing in 1,673 seconds. The golden runner split its 1,376- and 688-case batches after `%oops` bailouts; every case passed after isolation.

An earlier isolated browser run passed all eight steps in 677 seconds with unchanged compiler/runtime inputs. It ran alongside full eval checks and measured a median of 28.2 ms, p95 of 69.0 ms, maximum of 81.9 ms, and script median of 20.7 ms. Both browser runs were on a shared machine; no agreed acceptance bar was imposed.

Milestone-8 template work on 2026-11-10 passed `nix flake check` on the final source: the native CLI, desk compilation (136 seconds), all 18 eval checks (6,662 seconds), and all nine fresh-ship checks (10,940 seconds). Eval covered 1,376 goldens and 667 Hoon arms in 272 suites; the ship passed all 2,043 golden/suite arms in 7,482 seconds, with no failures or crashes. All 270 JavaScript tests, 23 exact Hoon/JavaScript emitter fixtures, strict probes and documentation checks passed. An initial ship attempt stopped when the build filesystem filled; the retry reused the passing eval result and ran the unchanged ship group on a fresh pier after space recovered.

`check-host` passed in 1,623 seconds, with my-app's first build measured at 130 seconds. `check-browser` passed all seven checks in 343 seconds, including shared modules and the real timer island's compiled template. The 500-row benchmark measured 40 keystrokes at 4× CPU slowdown: median 13.4 ms, p95 21.6 ms, maximum 23.0 ms; the island's own work had a median of 9.6 ms. These are measurements on a shared machine, with no acceptance bar imposed. The library was 54,868 minified bytes and 19,518 bytes under `gzip -9n`. This validated the first template slice; other hole kinds and removing intermediate element nouns were unfinished.

The preceding size/sharing commit, `fc71705`, passed all 251 JavaScript tests, the deterministic bundle check and tooling selftests. Its bundle was 19,938 bytes under `gzip -9n`, down from 20,618 with the same measurement. Its full Nix run had passed the native CLI, desk compilation and ship selftest when the owner requested the push; remaining eval and ship checks were still running then. Its GitHub Actions run subsequently passed the full checks.

An earlier `nix flake check` run on 2026-11-10 passed every eval check, among them all 1,376 golden cases, the eight test-arm shards, the strict probes, `doc-format` and `bundle-js`, and every ship check but one: `ship-test`, `check-commit`, `clay-fixtures`, `check-my-app`, `check-host`, `check-node-tests` and `probes-ship`. `check-browser` hung there, because the sandbox has no fonts and Chromium's renderer hangs laying out text without them. The ship check now gives Chromium a fontconfig with DejaVu fonts, and the browser driver fails a call with no answer rather than waiting; in the same sandbox, on a fresh fake ship, `check-browser` and `check-node-tests` then passed.

[Before pushing](development.md#before-pushing) documents `tools/check`, its eval/native/ship groups, and `nix flake check`. Individual suites and goldens can be selected with `tools/test-arms`, `tools/golden --case`, and `tools/probe-regression`. Milestone acceptance requires the full integrated eval and ship checks, as well as that milestone's specific criteria.
