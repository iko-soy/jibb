# Status

As of 2026-11-08. This is the current capability and acceptance table. History and dated review findings are in git and [reviews/](reviews/). The plan is [spec/implementation-plan.md](spec/implementation-plan.md); every milestone requires its checks to pass on a fake ship as well as under eval.

## Milestones

| # | Milestone | Status |
| --- | --- | --- |
| 1 | Parser and mark | Done |
| 2 | Types and prelude | Done: the general full checker, checked prelude and Hoon importer meet the milestone acceptance criteria under eval, on the fake ship and in the integrated Nix checks |
| 3 | Core language | Done: checked-artifact capture, lowering/linking, the Core reader/interpreter, Nock backend and authenticated natives pass the exact Core golden, focused suites, and the final integrated Nix eval and fake-ship checks. Provenance-checked Nock execution adds 13 focused eval arms for function-as-noun and trace controls |
| 4 | Host and static pages: the first release | In progress: real-Clay static checking, Nock rendering, agent-side HTML caching, owner-only HTTP responses, and desk lifecycle handling pass focused eval and fake-ship HTTP checks; incremental rebuilds, full application imports, hashed Eyre assets, and the remaining acceptance criteria are unfinished |
| 5 | Published pages | Not started |
| 6 | Islands | In progress: the independent JavaScript reader, backend, entry linker, and native runtime are implemented with Node semantic tests and shared Hoon differential outcomes; full integration awaits checked lowering; the initial benchmark selected generated JavaScript, and the virtual DOM/island loop is implemented with focus-preserving tests. Channel, subscriptions, timers, and poke replies are implemented with mocked transport tests. Store and URL transports are implemented with lifecycle tests. Full browser integration and performance work remain outstanding |
| 7 | Tooling | Not started |
| 8 | Polish | Not started |

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

## Milestone 4 progress

| Area | Current evidence |
| --- | --- |
| Static build and render | The checked build facade resolves the renderer and theme, executes linked Nock, serializes HTML, and rejects missing theme assets; focused build suites pass under eval |
| Real-Clay host | The agent reads the app desk's Jibb sources, prelude, renderer, theme, and collection interfaces through Clay, caches rendered pages by desk and route, and serves them without adding private pages to Eyre's cache |
| HTTP and lifecycle | `tools/check-host` passed on a fake ship: exact logged-out login redirect, owner `GET` and `HEAD`, `/about` plus root/missing/asset 404 behavior, 405, no private Eyre cache entries, and route/cache removal and rebuilding across suspend and revive |
| Regression validation | `nix flake check` passed with the real-Clay host and fixture: desks, native CLI, all eval checks, and the complete fresh-ship group |
| Remaining acceptance work | Executing each desk's own vendored compiler, commit-driven incremental compilation, application `/-` and `/%` interfaces, excluding non-page module kinds from public routes, default themes, content-hashed public assets in Eyre, route/link validation, theme stylesheet and contrast work, and `-jibb!clear` remain incomplete; milestone 4 is not done |

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
| `my-app` | All 11 modules check in dependency order through real Clay types, with exactly the expected `buttons.jibb` error at 3:16 | `tools/check-my-app` |

## Performance

Measured on 2026-11-06 with final compiler SHA-256 prefix `d369b012` and debug disabled. The generated-module timings include the 52.920-second startup measurement.

| Measurement | Time |
| --- | ---: |
| `tools/hoon --no-debug` startup | 52.920 s |
| 2,000-line module, bottom-up definitions | 75.262 s |
| 2,000-line module, top-down definitions | 76.627 s |
| `my-app`, 11 modules through Clay with source-aware origins | 63.5 s |

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
- Milestone 4 is in progress. The real-Clay static HTML/HTTP slice above is verified; commit-driven incremental builds, full application imports, static files in Eyre, routing/application-path validation, the theme stylesheet and contrast checks, and `-jibb!clear` remain.
- Milestone 5: per-request host behavior. Static `load` checking is already part of milestone 2.
- Milestone 6: checked-lowering integration is present; full browser/phone performance validation and runtime request handling remain. Store and URL transports are implemented with lifecycle tests. Eyre channels, subscriptions, timers, and poke replies are implemented with mocked transport tests. The initial Core benchmark selected generated JavaScript; virtual DOM and the island loop are implemented.
- Milestone 7: formatter and later tooling.
- The checked prelude's deliberate omissions are documented in [prelude-inventory.md](prelude-inventory.md); they are not silently implemented with different signatures.
- Open language questions remain in [open-questions.md](open-questions.md), including `proj` field reordering and unconfirmed review proposals. Current checker diagnostics do not settle those proposals.

## Checking it

[Before pushing](development.md#before-pushing) documents `tools/check`, its eval/native/ship groups, and `nix flake check`. Individual suites and goldens can be selected with `tools/test-arms`, `tools/golden --case`, and `tools/probe-regression`. Every final count above must pass on the integrated commit before milestone 2 is marked Done.
