# Development

How to work on Jibb: the rules the plan sets, how to set up a machine, and what to run before pushing. The repo's [README](../README.md) describes each tool in full.

## Ground rules

From the plan's Setup and ground rules, and from @iko:

- **The spec wins.** Where code and spec disagree, the spec stands until it changes. The spec is the copy in [spec/](spec/); the Synced column in [spec/decisions.md](spec/decisions.md) shows which rows the doc has.
- **Language changes are agreed first** and recorded in the Decisions tab, before the code changes.
- **Questions go to @iko**, as comments on the doc, on the words they're about. While one is open, follow the most likely reading, mark it "(doc question)" in the library's notes, and list it in [open-questions.md](open-questions.md). Where an error points is not a doc question: the library's section 2.0 settles it.
- **Every Jibb code block in the doc is a golden test**, and each stage's output is printed and compared. The doc labels its Jibb blocks `jibb`; `tools/doc-blocks` checks that each has its case.
- **Each milestone ends with its checks passing on a fake ship**, not only under `urbit eval`.
- **Push straight to `master`.** @iko reviews work in the project's chat, not in pull requests, so there are none. Run the checks below first.
- **Keep docs/ current**: [status.md](status.md) when a milestone moves, [open-questions.md](open-questions.md) when a question is found, and [spec/decisions.md](spec/decisions.md) when one is settled: it moves there.

The source-backed generic-union guard is the suite `tests/lib/jibb-union-source.hoon`: `tools/test-arms jibb-union-source` runs its `test-union-source` arm under eval, and the same arm is assembled for the fake ship. It retains bounded source-proof controls and now checks its reports through the full-module checker. Its valid recursive-mold/alias combination is a required positive regression; the general core must cover it before the milestone is complete. `tests/lib/jibb-union-alias-overlap.hoon` exercises the separate positive overlap witness, with one test arm shared by eval and the ship. `tests/lib/jibb-full-overlap-basic.hoon` and `tests/lib/jibb-full-overlap-graph.hoon` check structured full-module overlap evidence and the legacy error text; `tools/test-arms 'jibb-full-overlap-*'` runs both of their test arms under eval, and both are assembled for the fake ship.

## Setting up a machine

The ship tools need Python 3 and `urbit` (vere) on `PATH`, plus a fake `~zod` and click. The native CLI needs a Rust toolchain and Cargo; regenerating its parser also needs Node and the tree-sitter CLI. Everything so far ran with vere 4.6 on Linux.

With Nix (and flakes), `nix develop` gives a shell with vere 4.6, Python 3, click, Rust and tree-sitter, as the flake pins them, and sets `$JIBB_CLICK`. `nix build .#fakezod` boots a fake `~zod` from the pinned brass pill in about half a minute; copy it to where `tools/ship` expects it:

```
mkdir -p /root/urbit
cp -r "$(nix build .#fakezod --no-link --print-out-paths)" /root/urbit/zod
chmod -R u+w /root/urbit/zod
```

`nix flake check` needs neither step, since it boots a ship of its own; see the [README](../README.md#building-and-checking-with-nix).

Without Nix, on a usual machine:

1. Install vere as [docs.urbit.org](https://docs.urbit.org) says, and get a brass pill.
2. Boot a fake ship where `tools/ship` expects it, or point `--pier` or `$JIBB_PIER` elsewhere. Booting takes a few minutes:
   ```
   mkdir -p /root/urbit && cd /root/urbit
   urbit -F zod -B brass.pill -t -x -c zod
   ```
3. Get click, the command-line client for a ship's `conn.sock`, from [urbit/tools](https://github.com/urbit/tools), at `/root/src/tools/pkg/click/click` or wherever `--click` or `$JIBB_CLICK` says.
4. Optionally, clone [urbit/urbit](https://github.com/urbit/urbit) to read Arvo's source. `vendor/SOURCES.txt` names the commit the vendored files come from.

In a restricted cloud container, the network blocks urbit.org, bootstrap.urbit.org, nixos.org's installer and GitHub's release downloads. When Nix is already installed, as it was on 2026-11-02, the flake does all of the below: it fetches nixpkgs from channels.nixos.org, click with git and the pill from media.githubusercontent.com, which the network allows. Otherwise, this worked on 2026-10-29, and has to be redone in each new container:

```
# Nix, single-user
curl -sSfL -o install https://releases.nixos.org/nix/nix-2.32.4/install
mkdir -p /etc/nix && printf 'build-users-group =\nsandbox = false\n' > /etc/nix/nix.conf
sh ./install --no-daemon --no-channel-add --yes
. /root/.nix-profile/etc/profile.d/nix.sh

# vere, from nixpkgs
nix build -I nixpkgs=https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz \
  --impure --expr 'with import <nixpkgs> {}; urbit'
# then put result/bin/urbit on PATH

# the brass pill, from Git LFS
mkdir -p /root/urbit && cd /root/urbit
curl -sSfL -o brass.pill https://media.githubusercontent.com/media/urbit/urbit/master/bin/brass.pill
urbit -F zod -B brass.pill -t -x -c zod

# click
git clone https://github.com/urbit/tools /root/src/tools
```

`echo '(add 2 2)' | urbit eval` checks that vere works without a ship.

## The tools

| Tool | What it does |
| --- | --- |
| `tools/check` | Runs every check in this table, or a group (`--group eval`, `native` or `ship`), or some by name: see [Before pushing](#before-pushing) |
| `jibb-cli` | `cargo test --manifest-path jibb-cli/Cargo.toml` tests the native executable, parser, formatter and golden corpus; `cargo run --manifest-path jibb-cli/Cargo.toml -- fmt` runs the formatter |
| `tools/golden` | Runs the golden cases under `urbit eval`: every case, or those matching `--case`; `--update` rewrites the expected outputs; `--show` prints them. `expect-core:` opts into checked lowering and canonical `core.txt` output |
| `tools/test-arms` | Runs the `test-` arms of the `tests/lib` suites under `urbit eval`, each with the subject Ford would give it on the `jibb-dev` desk: every suite, or those named or matched by a glob, as `tools/test-arms jibb-store 'jibb-program-*'`; `--shard I/N` runs the I-th of N balanced shards; `--list` prints the suites and their arms; `--report` and `--update` print or rewrite a golden-report suite's report. Nix's narrow batches use `--desk-map` with explicit suite names instead of assembling the full desk. See [The test suites](#the-test-suites) |
| `tools/eval-manifest` | Generates `nix/eval-manifest.json` with `--write`; `--check` verifies freshness, complete disjoint coverage and byte-identical full/narrow arm programs. Regenerate after changing golden or suite membership, dependencies or shard assignments |
| `tools/clay-fixtures` | Syncs `my-app` and `jibb-fixtures`, builds their example `/sur` files and marks through Clay, checks selected mold and mark projections and the full checker, and records Ford and mark subject shapes on the fake ship |
| `tools/check-my-app` | Syncs `my-app`, builds its `/sur` files and marks through Clay, and runs the full checker over every UI module in dependency order; asserts the one expected buttons error and prints the checking time |
| `tools/check-host` | Builds the fixture and `my-app` with their own vendored compilers, timing `my-app`'s first build, then verifies real Clay imports, generic and misspelled `/sur` molds, default and custom themes, checked page-kind routes, static HTML over HTTP with its CSP, login redirects, `HEAD`, 404/405/501 responses, and desk suspend/revive behavior on the fake ship. Static files, the stylesheets and `my-app`'s font must come from Eyre's cache, public and immutable, with no private page there. Worked example 2 and `my-app`'s `_slug` page must render from a fresh scry of its `%blog` agent, a post added by a poke appearing at once; a path the agent rejects, a segment that does not parse and an answer that does not fit its type give the desk's 404, 404 and 500, and a page whose view crashes a 500 on every request. It commits a change to one of the fixture's libraries and checks, through the host's `/build` and `/modules` scries, that only that library and the page importing it check again and that the rebuilt page is served; changes the notes page's image, which gets a new URL while the old one stays, then deletes it, which is that page's error; runs `-jibb!clear`; and restores every file it changed. Clearing leaves `my-app` without its files, so it suspends and revives `my-app` at the end, which builds it again in the background; `-jibb!test` must give each test of the fixture and `my-app` its expected outcome |
| `tools/check-browser` | Runs worked example 3, the Grammar tab's store example, the crash notice and the benchmark's 500-row list island in headless Chromium against the host on the fake ship, through `tools/browser-check.mjs` and the DevTools protocol: it adds and toggles a todo through the `%todo` agent, checks compiled templates retaining static attributes, control focus/caret and keyed rows, shares one cart between two baskets, follows an app's in-section links without loading a page, and times keystrokes at a 4x CPU slowdown, script and layout apart; `--bar=16` fails a p95 over 16 ms, which waits for the bar to be agreed. Needs `chromium` on `PATH` or `$JIBB_CHROMIUM` |
| `tools/check-node-tests` | The Node harness: syncs the host and both desks, reads each test module's `test-` arms from the host as JavaScript and as Nock, runs both in Node with `tools/node-tests.mjs`, and requires them to agree with each other and with `-jibb!test` |
| `tools/probe-regression` | Strict full-check regression for the classified review probes, registered as `probes-eval` and `probes-ship` in `tools/check`. Valid probes must check and invalid probes must give their specified diagnostic and sites |
| `tools/hoon` | Evaluates Hoon with the library in scope, as `tools/hoon '(golden /a/b/jibb (crip "++ main view"))'`; `--cord name=file` binds a file's text, `-f` reads the expression from a file; `--no-debug` leaves out `!:`, which gives errors their positions but makes the checker 2.2 to 2.6 times slower than on a ship, for timings |
| `tools/bench-check` | Measures full checking of a generated 2,000-definition chain in both source orders with `tools/hoon --no-debug`, plus startup; `--lines` changes its size. It snapshots the library for the run. |
| `tools/doc-blocks` | Checks the doc's `jibb` blocks against the `doc-*` golden cases: `tools/doc-blocks docs/spec` |
| `tools/split-goldens` | Checks that isolated type-error cases retain their original source lines and import fixtures |
| `tools/ship` | Runs the fake ship: `dev` (boot, create, mount and sync an application directory), `start`, `stop`, `status`, `log`, `sync <desk>`, `assemble --out <dir>` (no ship needed), `test`, `gen-tests`, `check-commit`, `scry`, `hoon`, `run`, `poke`, `commit`, `mount`, `unmount`. Don't stop a command while the ship is still working on its request: vere 4.6's king process crashes when it writes the reply to a closed socket, with `newt: write failed broken pipe` and a loom fault in the log; `tools/ship start` brings the ship back |
| `tools/test-js` | Runs the JavaScript Core reader, literal, runtime, code-generation, and entry-linker tests under Node |
| `tools/bundle-js` | Bundles the browser library, `js/browser/entry.mjs` and what it imports, into `jibb-dev/lib/jibb/runtime.js` with pinned esbuild and Terser; compression preserves property names and uses no unsafe transformations. Every build must be smaller than 20,000 bytes under `gzip -9n`, and an oversized build leaves the vendored file untouched. `--check` also fails if that file is stale, and is registered as the `bundle-js` check |
| `tools/doc-format` | Checks that the formatter leaves every Jibb example in `docs/spec` unchanged, through the `doc-*` golden cases `tools/doc-blocks` keeps them as; uses `jibb` on `PATH` or builds the CLI |
| `tools/test-js-differential` | Runs the shared hand-written corpus in JavaScript and the Hoon Core interpreter, comparing canonical nouns and crashes. The JavaScript reader supplies the AST, which the harness translates directly to Hoon `expr`; `--core-lib PATH` selects another interpreter |
| `tools/bench-js` | Compares generated JavaScript with the iterative Nock interpreter on identical Core, checking nouns before reporting separate emission and execution timings. Supports `--case`, `--warmups`, `--iterations`, and `--json` |
| `tools/testdata/selftest` | Tests `tools/golden` and `tools/hoon` against a stub library, `tools/test-arms` against the stub library with suites it writes, and `tools/doc-blocks` against Markdown it writes |
| `tools/testdata/ship-selftest` | Tests `tools/ship`'s test generator and runner against a stub library on the ship |

`tools/golden` starts `urbit eval` once and builds the library, which takes about 27 s, then runs every case under `mule`, so a crash fails only its own case. A golden case with `expect-core:` in `about.txt`, or an existing `core.txt`, lowers its successfully checked tree and compares `print-module:jibb-core` with `core.txt`. The marker remains mandatory after an expected file is deleted, so `--update` cannot silently disable the stage. Cases without `about.txt` need no Core metadata.

## The test suites

Each file in `tests/lib` is a suite: a core of `test-` arms, with the libraries and files it reads bound by `/+` and `/*`. On the fake ship, `tools/ship test` runs each suite's test file in its own `-test` event; under eval, `tools/test-arms` runs the same arms, so every suite below runs in both places. `tools/test-arms` gives each suite the subject Ford would give it on the `jibb-dev` desk: each `/+` library and each `/*` file, found where `tools/ship assemble` puts them. Before a suite's `|%` it takes only comments, `/+` lines and `/*` lines, and binds only `%txt` and `%jibb` files. The suites it runs share one eval, so the library is built once for all of them, in about 17 s with `!:`, and so is the importer library `jibb-import`, in about 20 s more, when any of them uses it. Each arm runs under `mule` and prints `OK`, `FAILED` or `CRASHED`, as `-test` does; a crashed arm's trace is mapped to lines in the suite and the library, with an excerpt of the innermost spot. When a suite doesn't build, `tools/test-arms` runs the suites again one at a time and reports it as `FAILED <suite> (build)`, with its error placed in the suite file. `tools/test-arms <suite>` runs one suite, and names or globs pick several, as `tools/test-arms jibb-store 'jibb-program-*'`; `tools/test-arms --list` prints the suites and their arms. `tools/check` runs them all in eight shards, `arms-1` to `arms-8`, each `tools/test-arms --shard I/8` in an eval of its own, balanced by the measured costs in `COSTS` and `LIB_COSTS` in `tools/test-arms`. `tests/lib/jibb.hoon`, which `tools/ship gen-tests` writes from `tests/golden`, is left out under eval, since `tools/golden` runs those cases.

A golden-report suite has a `report` arm and a golden file bound to the face `expected`; its test arm compares the report with that file, and `tools/test-arms --list` marks it `, report`. `tools/test-arms --report <suite>` prints the report, and `tools/test-arms --update <suite>` writes it to the file; with no suite named, `--update` writes every golden-report suite's. When such a suite's arm fails, `tools/test-arms` prints a unified diff between the file and the report. `jibb-buttons` and `jibb-deferred-prepared` have golden files too, but compare them inside helpers over several cases and have no `report` arm. Every golden file, a `/*` `%txt` file bound to a face containing `expected`, must end in exactly one newline (a suite compares `wain`s, which can't show a missing one) and hold no line that starts `BAD ` or ends `: BAD`; `tools/test-arms` checks that before any eval, and `--update` won't write a report that breaks it.

`tools/doc-fragments` guards examples checked in a larger context: the Core language's `update` and its containing type-check source match the todo island, the valid buttons fixture matches the Grammar's buttons block without `add-button`, and the documented `cmd` and `sub` molds match the prelude. It also compares copied module and `/sur` fixtures with `my-app` and checks that standalone mark fixtures embed their real `/sur` source. It runs as part of `tools/check` alongside `tools/doc-blocks`.

`tools/split-goldens` checks the provenance of isolated type-error cases. Each `split-source.txt` names an original golden, a target definition and the retained definitions; the checker verifies the original source with all other definitions blanked in place and compares the copied import fixtures. This keeps line numbers and columns stable while the full checker reports each independent error separately.

`probes-eval` and `probes-ship` run the review's entire regression corpus with `tools/probe-regression`, through the full checker under eval and on the fake ship. A valid probe must check; a negative must have its specified reason, source sites, excerpts and carets. Generic unsupported messages fail these checks. The corpus has 317 Jibb sections and 31 separate importer probes. Run selected groups with `tools/probe-regression p1 errors-p1`, or add `--backend ship`; the ship backend shares the test desk, so run it sequentially with other ship checks. Both backends passed milestone 2 acceptance and remain required regression checks.

The pattern matrix suites exercise one shared match analysis. `jibb-useful` checks whether an arm can match a value that earlier arms miss, produces witnesses for missing cases, and checks analysis limits. The coverage, nested-pattern, recursive-pattern and empty-type suites use that analysis through ordinary expression inference. `jibb-body-context`, `jibb-result-unsound` and `jibb-local-group-diagnostics` check that expected types, result faces and errors survive nested bodies and recursive definition groups. The same suite arms run under eval and on the fake ship.

The `jibb-dev` desk holds `my-app`'s `ui/`, `sur/` and `mar/` under `/my-app` (review question 31), so the suites that check `my-app` files bind them there, as `/*  sur  %txt  /my-app/sur/todo/hoon`, and keep no copies. A mark's `/-` line is Ford's, which `ride` can't parse, so the suites that ride a mark drop it with their `+mark-text` arm. Where the table below calls a `my-app` file byte-identical or unchanged, the suite reads that file itself. Files that only the importer's tests need are kept off `my-app` (review question 34): the Clay fixtures' `/sur` with a Ford import, their mark and the real Tlon notes `/sur` are in `tests/clay-fixtures/desk/`, which the `jibb-fixtures` desk adds to `my-app` and the `jibb-dev` desk leaves out, and the golden cases and `tests/type-poke/mark.txt` that use the mark link to `tests/clay-fixtures/desk/mar/label.hoon`.

| Suite | What it checks | Golden files |
| --- | --- | --- |
| `jibb-api-evidence` | Source, scope, reader-result and declaration-watchability evidence guards for path declarations, in two arms, over synthetic and real todo inputs | |
| `jibb-api-general` | General API modules with ordinary definitions and derived request gates, downstream use, watchability and failure ownership | |
| `jibb-api-paths` | Partial API path analysis with real todo mark samples; it does not generate request interfaces | `tests/type-api-paths/expected.txt` |
| `jibb-arithmetic-guards` | Restricted atom-variable, unification and projection guards | |
| `jibb-ask-guards` | Ask origin and canonical list/unit bootstrap guards | |
| `jibb-bridge` | The importer/checker bridge: the Hoon importer composed with the full checker | `tests/type-import/expected.txt` |
| `jibb-buttons` | The documented valid button helpers and the unchanged unresolved-`%add` module, through detailed and legacy inference | `tests/type-buttons/expected.txt` |
| `jibb-cell-branch` | Cell patterns through the common match checker, contextual results and substitution rollback | |
| `jibb-check-spans` | `+check-spans`, which `+golden` runs on every tree: its own test, `+check-spans-test`, moves the spans of parsed nodes as a parser bug would and checks that it says so | |
| `jibb-closed-gate-guards` | Closed gate sample labels and face uncertainty | |
| `jibb-constructor-fit-guards` | Constructor-case uncertainty and known mismatches | |
| `jibb-deferred` | The common deferred queue, final source diagnostics, level-based generalization, occurs checks and 100 deferred gates | `tests/type-deferred/expected.txt` |
| `jibb-deferred-context` | Deferred source order and literal branch contexts | `tests/type-deferred-context/report.txt` |
| `jibb-deferred-prepared` | Prepared-prelude definitions through the common full checker, exact reports and consistency with source-taking entry points | `tests/type-deferred-prepared/expected.txt`, `expected-control.txt` and `expected-tuple-only.txt` |
| `jibb-deferred-resolver` | Deferred resolution, report consistency and atomic failure | `tests/type-deferred-resolver/expected.txt` |
| `jibb-direct-gate-guards` | Ordinary direct and aliased callback inference, later binding and exact face/aura/capital errors | |
| `jibb-direct-gate-source` | Each original gate-layout definition through the full checker with its dependencies, retaining original source lines | `tests/type-direct-gate/expected.txt` |
| `jibb-doc-examples` | Full checking of the import-only, view-day, step and cmd/sub doc fragments in their intended contexts, through detailed and legacy inference | |
| `jibb-empty` | Empty molds, inhabitedness and match coverage through the common pattern matrix | `tests/type-empty/expected.txt` |
| `jibb-full-overlap-basic` | Structured full-module overlap evidence: source-bound overlap witnesses, generic parameter limits, precedence and rejection controls, and the legacy full-module error text | `tests/type-full-overlap/expected-basic.txt` |
| `jibb-full-overlap-graph` | Imported-source attribution of overlap evidence across parent and child modules: cache rebuilds and source binding, and private, cyclic, duplicate, missing and transitive imports | `tests/type-full-overlap/expected-graph.txt` |
| `jibb-gate-free-guards` | Bounded gate-free verdicts, persistent constraints, substitution safeguards, collection keys and witness paths | |
| `jibb-gate-free-source` | Source-backed todo mold analysis through the real readers | `tests/type-gate-free/expected.txt` |
| `jibb-generic-alias`, `jibb-visible-alias` | Public and imported union aliases, including reversed, repeated, fixed and specialized arguments; rendering cannot specialize actual parameters or confuse nominal origins | |
| `jibb-generic-construction` | Recursive construction, nominal provenance, retries and fuel | `tests/type-generic-construction/` |
| `jibb-generic-pattern` | Recursive pattern inference, diagnostics, coverage and bounded retry | `tests/type-generic-pattern/` |
| `jibb-generic-recursion` | Source-backed generic recursive identity and provenance | `tests/type-generic-recursion/expected.txt` |
| `jibb-hole-guards` | Hole-defaulting and API interface guards | |
| `jibb-hoon-reference` | Hoon translations of the Jibb-written `zing`, `lead`, `late` and `succ` against Hoon's own arms, on selected inputs; this does not execute Jibb, test lowering or prove jet recognition | |
| `jibb-core` | Independent Core reader/printer round trips, malformed inputs, strict reference interpretation, recursion, native registries, traces and crash behavior | |
| `jibb-nock` | Every Core node's Nock emission, local rewrites, closures, recursive cores, Hoon gate ABI, higher-order natives and differential crash behavior | |
| `jibb-js` | Exact Hoon/JavaScript emitter parity on 41 fixtures, including direct holes, captures, memo reuse and bounded fallback | `tests/js-emit/` |
| `jibb-js-direct` | Strict direct-hole specialization, removed cell checks and local-recursion fallback | |
| `jibb-view-template`, `jibb-view-template-source` | Authenticated template shapes and bounds, plus full checking and linking of text and realistic element-hole source views | `tests/view-template/` |
| `jibb-lowering-artifacts` | Final occurrence/reference/axis/SCC/match/projection capture, prepared dependencies, and failed/provisional nonpublication | |
| `jibb-lower` | Checked-tree lowering, exact documented `update`, linking, source-once controls, derived API calls, authenticated printers, and fail-closed projection reordering | |
| `jibb-store-lower` | Derived store state/poke shapes, runtime envelopes, full-state delivery and reply execution under the reference interpreter and Nock | |
| `jibb-lower-differential` | Lowered Jibb programs executed through the Hoon reference interpreter and Nock with independently specified noun/crash outcomes | |
| `jibb-import` | The partial Hoon importer's diagnostic trees and errors over the importer fixtures, and the structured values behind them; the projection is an internal tree, not the Jibb type printer | `tests/importer/tree.txt` |
| `jibb-import-default` | Default-wrapped union source proofs over a real Tlon mold, and adversarial cases | `tests/type-import-default/expected.txt` |
| `jibb-import-general` | A `/sur` containing `$%`, `$@`, a map and a recursive mold through the full checker; `tools/clay-fixtures` also builds these molds through Clay and prints their types | `tests/clay-fixtures/full-import-expected.txt` |
| `jibb-import-mark-source` | Source-aware mark origin authentication, declaration sites, stale/ambiguous/decoy controls and unchanged semantic bodies and errors | |
| `jibb-import-tag-auras` | Non-term tagged union heads, noun-equal head overlap, disjoint payloads and reader vase diagnostics | |
| `jibb-import-vase` | A used Hoon vase reports its error at the Jibb use site | |
| `jibb-import-diagnostic` | The structured reader diagnostic bridge report: definite and unsupported reader diagnostics through the checker | `tests/type-import-diagnostic/expected.txt` |
| `jibb-import-overlap` | Source-aware Hoon union overlap, provenance and proof-budget controls | `tests/type-import-overlap/expected.txt` |
| `jibb-import-structural` | Multi-case and nested Hoon union overlap witnesses | `tests/type-import-structural/expected.txt` |
| `jibb-recursive-diagnostics` | Full recursive-group errors, actual value-cycle chains, scoped references, dependency-order priority and rollback of failed group constraints | `tests/type-recursive-diagnostics/expected.txt` |
| `jibb-recursive-watch-data` | Recursive data abstraction around embedded islands, discarded-watch diagnostics, finite subscriptions and evidence and growth controls | |
| `jibb-local-island-watch` | Occurrence-based watch checking for local and embedded islands, including generic helpers and discarded or overwritten values | |
| `jibb-local-mold-capture` | Lexical capital capture by local generic and non-generic molds, deferred matches and scope-leak controls | |
| `jibb-local-mold-recursive-capture` | Captured capitals through nested local recursive mold graphs and deferred matches, with scope-leak controls | |
| `jibb-local-mold-scope` | Full-check local mold collisions with both sites; nested reserved binders; permitted same-spelled fields and tags | `tests/type-local-mold-scope/expected.txt` |
| `jibb-import-cycle` | Full-check import cycles with each edge's file, excerpt and caret; root and self cycles, with an acyclic shared-import control | `tests/type-import-cycle/expected.txt` |
| `jibb-full-report` | Exact full-check reports for values, module kinds, imported molds, API helpers and the buttons error | Full result returned by public `golden-types*` |
| `jibb-list-alias-guards` | Prelude list-alias and provenance guards | `tests/type-list-alias/expected.txt` |
| `jibb-mark-bridge` | The full checker's mark import boundary | `tests/type-mark/expected.txt` |
| `jibb-map-private-bit` | `map` identity types composed with the private bit group and `not.bit` | |
| `jibb-module-scope` | The full checker's prelude boundary and duplicate-source rejection | `tests/type-module-scope/expected.txt`, and the golden case's `tests/golden/types-prelude-interface/types.txt` |
| `jibb-nested-union-guards` | Nested tagged-union case selection and uncertainty | |
| `jibb-page-main` | Full checking of byte-identical static and direct data pages through real readers, exact main types, downstream imports and rejection guards | |
| `jibb-poke-bridge` | Source-backed prelude and poke-only API reports | `tests/type-poke/expected.txt` |
| `jibb-positional-face-guards` | Positional-call and nested-face guards | |
| `jibb-prelude-list-edit` | Full checking of source-written `gulf`, `oust`, `swag`, `snap`, `into` and `skid`, preserving auras and element/field types | `tests/golden/types-prelude-list-edit/` |
| `jibb-prelude-lists` | Full checking of `snag`, `scag`, `slag`, `reap` and `sort` calls with exact numeric and text result types | `tests/golden/types-prelude-list-index-sort/` |
| `jibb-prelude-arithmetic` | Full checking of `min`, recursive `sub` and `mul`, with independent auras, a generic arithmetic constraint and the exact loobean error | `tests/golden/types-prelude-recursive-arithmetic/`, `tests/type-prelude-arithmetic/loobean-expected.txt` |
| `jibb-prelude-bit` | `not.bit` type and call behavior, private bit-group boundaries and source and diagnostic guards | |
| `jibb-prelude-helpers` | Checked `homo`, `fand`, `find`, `spin`, `test` and `sqt` signatures and inferred call results | |
| `jibb-prelude-max` | Source-backed `max` and the Grammar's generic `clamp` body through the full checker | |
| `jibb-program-init` | Initializers through the common constraint queue, exact exported/imported types and rejection boundaries | |
| `jibb-program-main` | The narrow closed subscription-free program-main interface, downstream import and rejection guards | |
| `jibb-program-update` | Update results through the common constraint queue, union/boolean context and exact exported/imported types | |
| `jibb-program-watch` | Direct singleton request-value watchability against merged real-todo evidence, exact types/imports and rejection boundaries | |
| `jibb-proj-guards` | Projection evidence, name-scope and dependency guards | |
| `jibb-qath-fuel` | Recursive qath unfolding and face guards: unfolding uses bounded fuel and keeps uncertain faces | |
| `jibb-qath-source` | Qath source-provenance guards: source-backed qath accepts only the proven public and internal interfaces | |
| `jibb-request-guards` | Request evidence, source consistency and cache provenance guards | |
| `jibb-store` | The unchanged cart/basket through detailed and legacy inference, exact store/derived schemes, malformed-prelude guards, structural imports, source-bound state watch evidence and rejection guards | |
| `jibb-stream-small` | Delayed subscription event context through direct, `identity` and `flop` lists, with wrong-event diagnostics | |
| `jibb-sub-guards` | Source-backed subscription mold dependencies | |
| `jibb-theme` | Full checking of the byte-identical real theme, its exact exported type, structural downstream import, dark absent/present forms and rejection guards | |
| `jibb-tlon-bridge` | The real, unmodified Tlon presence source through the importer and full checker | `tests/type-tlon/expected.txt` |
| `jibb-todo-api` | The actual todo API through the real Hoon readers and full checker | `tests/type-todo-api/expected.txt` and `negative-expected.txt` |
| `jibb-todo-full` | Full checking of the byte-identical todo island and an ordinary call-bodied annotated-initializer variant through real readers, exact main types, structural downstream import and rejection controls | `tests/type-todo-full/expected.txt` |
| `jibb-todo-partial` | Full-check reports for the todo island through the real API and readers, plus negative import controls; the suite retains its historical name | `tests/type-todo-partial/expected.txt` |
| `jibb-typecheck` | The partial inference unifier, through the library's own `+itype-unify-test` cases | `tests/checker/unification.txt` |
| `jibb-ui-keys` | `each` and `table` gate-free keys through aliases and generic wrappers, nested-gate rejection and gate-bearing element messages | |
| `jibb-union-alias-overlap` | Source-backed generic-alias overlap witnesses | `tests/type-union-alias-overlap/expected.txt` |
| `jibb-union-source` | Bounded local generic-alias disjointness and state guards | `tests/type-union-source/expected.txt` |

`jibb-deferred`, `jibb-deferred-resolver` and `jibb-deferred-prepared` exercise the common constraint queue and full checker: delayed constructors, fresh variables, source order, rollback, prepared preludes, exact reports and diagnostic ownership. The former constructor transactions, separate prepared-tuple route and partial report have been removed. Kind and watchability checks have their own suites.

## Before pushing

```
tools/check                  # every check; it exits 0 only when all pass
tools/check --group eval     # only the checks that need just urbit and Python
tools/check --group native   # only the Rust CLI's checks
nix flake check -j 2         # incremental checks in the Nix sandbox, on fresh fake ships
```

`tools/check` runs every check the repo has. Their one list is `CHECKS` in the script, so a new check goes there, as well as in the table above; `tools/check --list` prints it with each check's command. A new suite in `tests/lib` needs no new check: `arms-1` to `arms-8` run every suite's arms, in shards of about equal time, and a slow suite's cost belongs in `COSTS` in `tools/test-arms`, which balances them. The eval and native groups run several checks at a time (`-j`, by default one per CPU), the slowest first. The ship group runs `ship-selftest`, `ship-test-goldens`, `ship-test-suites`, `check-commit`, `clay-fixtures`, `check-my-app`, `check-host`, `check-browser`, `check-node-tests` and `probes-ship` one at a time on the ship `tools/ship` talks to; `tools/check` starts it if it isn't running and stops it again afterwards. Name checks, or globs, to run only those: `tools/check golden 'arms-*'`. To run one suite under eval, use `tools/test-arms <suite>`, as `tools/test-arms jibb-todo-full`. A failing check's output follows its FAIL line; `-v` prints every check's output, and `--logs DIR` keeps it all.

`.github/workflows/check.yml` runs `nix flake check -j 2` on every pushed commit and pull request; run `tools/check` or `nix flake check -j 2` before pushing too, since a first run takes hours. Nix needs nothing but Nix, since it builds the desks and CLI and runs all three groups in the sandbox. Its eval aggregate splits the goldens into 14 batches and keeps the eight arm shards, each with its recorded source closure; probes and the tooling selftest have separate derivations, leaving a smaller residual group. Unchanged batches are reused. The manifest itself is an input only to the freshness check, so a membership edit cannot invalidate every batch. On Linux, eight ordinary-suite groups, ship goldens, base integration, ship probes, and the host/browser/Node chain run in independent fresh piers. See the [README](../README.md#building-and-checking-with-nix).

The registered arm checks allow 3,600 seconds per eval; standalone `tools/test-arms` defaults to 1,800. The outer `tools/check` timeout also applies and defaults to 2,400 seconds per check. For long runs on shared builders, use `tools/check --timeout 10800`; Nix uses that outer limit. Use `nix flake check -j 2` as well: its derivations bypass `tools/check`'s process cap, so an unbounded Nix job count could start too many Vere processes.

`ship-selftest` matters most when `tools/ship` changed, and `check-commit` when the mark or the desks changed, but `tools/check` runs both every time. The self-test leaves fixture files on the `jibb-dev` desk, and `ship-test-goldens`, which runs after it, puts the real ones back. `ship-test-suites` runs every ordinary suite separately from the generated golden batches.

`tools/ship test` regenerates the golden test suites and syncs the `jibb-dev` desk before it runs. `--only suites` selects ordinary suites without regenerating goldens; `--only goldens` selects generated golden tests. With `--only suites`, repeat `--suite NAME` to run a specific subset; generated golden names, duplicates, unknown names and the other modes are errors. Option and selection errors are checked before syncing. All forms perform the full sync by default and reject an empty selection. Desk assembly splits them into deterministic batches of at most 100 cases; generated files are ignored by git. Running each test file in its own event bounds the memory that made one whole-corpus event fail. Sync preflights and splits large deletion lists into bounded click requests, waiting for each Clay revision; a failure stops later batches. The ship self-test exercises this when switching from the full desk to a smaller fixture desk. A run with `--stub`, `--lib`, or a custom `--golden` isolates its generated golden tests from the repository's other test programs; run the default command afterward to restore and test those programs. `tools/ship test` also runs every other suite in `tests/lib`, and `tools/test-arms` runs the same suites under eval, so each compares the same fixtures and golden files in both places. `tests/lib/jibb-import.hoon` runs the importer fixtures against their expected diagnostic projection, an internal tree, not the Jibb type printer, and checks the structured values behind it. The probes it runs live in the suite, not in `jibb-dev/lib/jibb-import.hoon`, which app desks vendor. `tests/lib/jibb-bridge.hoon` runs the importer/checker bridge fixture, and `tests/lib/jibb-tlon-bridge.hoon` the real Tlon presence reader/checker fixture. `tests/lib/jibb-import-diagnostic.hoon` covers the structured reader diagnostics, and `tests/lib/jibb-mark-bridge.hoon` compares the mark bridge's fixture report. `tests/lib/jibb-poke-bridge.hoon` holds the source-backed prelude and poke-only API fixture. `tests/lib/jibb-api-paths.hoon` runs partial path analysis over the real todo marks; this does not generate request interfaces. `tests/lib/jibb-module-scope.hoon` compares the prelude scope report.

## Golden cases

A case is a folder `tests/golden/<name>/` holding:

- `source.jibb`, the input, ending in one newline. A case whose input is a `my-app` file, such as a doc block that `my-app` holds, makes it a symlink to that file; desk assembly leaves the link out, and `tools/ship gen-tests` reads the file from `/my-app`. A file under `modules/` may link to `my-app` the same way;
- `about.txt`: a `source:` line with the doc's words or block it comes from, a `tests:` line saying what it exercises, and an `expect:` line, either `parses` or `error at <line>:<col>` and why (one case, `inline-leftout-signed-float-auras`, says `unclear`: see grammar question 13 in [open-questions.md](open-questions.md));
- the expected outputs, `tokens.txt` and `tree.txt`, each the output plus one newline.
- optionally, `path.txt`, the logical `/ui/.../*.jibb` path to pass to the compiler; the source remains `source.jibb`.
- optionally, an `expect-types:` line in `about.txt` opts the case into `+golden-types`; `types.txt` holds its output plus one newline and `--update` creates it. A `types.txt` also opts in when the line is absent. This interface is provisional while the checker is under construction.
- optionally, `imports.txt` selects Hoon `/sur` molds, one `module mold` pair per line. Each module's source goes in `sur/<module>.txt` and is compiled against zuse by both runners. `marks.txt` selects marks, one name per line, with source in `mar/<name>.txt`; both kinds may be supplied together. The reader results go to the full checker, and a type output is required. Source-aware mark reading also uses the supplied `/sur` source to authenticate declaration-origin evidence when available; absent, stale or ambiguous metadata does not replace semantic import checking. Both runners reconstruct fixture text from `%txt` lines and identify the fixture if its compilation crashes; a crash fails the case without discarding its successful parse output. These fixtures cannot use Ford imports directly; the documented mark fixtures embed their actual `/sur` core instead.
- optionally, `modules.txt` lists logical `/ui/.../*.jibb` paths, one per line. The corresponding sources live below the case's `modules/ui/` directory. Both runners parse each source at its logical path and compare the combined `module-trees.txt`; `--update` writes that output. A case with type output also supplies these sources and the vendored prelude to the full checker. The file opts in even when it lists no sources; use a comment such as `# no module fixtures` for an empty bundle. Blank lines and comment lines are ignored. Cases without `modules.txt` keep their existing no-prelude type interface.
- optionally, `type-source.jibb` supplies the containing module to type-check while `source.jibb` remains the source parsed for tokens and tree. `type-path.txt` overrides the logical path used only for type checking. A prelude fragment can list the molds it defines in `type-exclude-molds.txt`: the runners remove those molds from the prepared prelude before fully checking the fragment. The doc fragment guard checks the containing module and prelude definitions against their originals.
- optionally, `type-contract.txt` sets additional requirements on the full diagnostic, one per line: `site <path>:<line>:<column>`, `typed-site <path>:<line>:<column>`, `unresolved-site <path>:<line>:<column>`, `min-sites <count>`, or `message <text>`. A typed site must include a type note; an unresolved site must identify an unresolved tag or constructor; the message text must occur in the diagnostic's first line. Both runners enforce the contract in addition to the exact `types.txt` comparison, and `--update` refuses to replace a golden when the contract fails.

The runners prepare the trusted vendored public and internal prelude sources once for their generated test core and share its interface. Preparation reserves all names present in the public source; an unsupported declaration remains reserved but unavailable. Type goldens render the full checker result, including module kind and diagnostics. `+golden-types-with-prelude-and-internal` accepts both sources directly; callers using `+golden-types-with-prepared-prelude` pass the result of `+prepare-prelude-with-internal`. The older source-only entry points remain available for preludes without imports. Missing or malformed sources fail closed.

Names say what a case is for:

| Name | For |
| --- | --- |
| `lex-<rule>-ok-<n>`, `lex-<rule>-bad-<n>` | A lexical rule, kept or broken |
| `inline-<topic>` | Any other rule, often from one sentence of the Grammar tab |
| `doc-<tab>-<n>-<what>` | The doc's `<n>`th code block of the tab, counting every block, labelled or not |

Write `source.jibb` and `about.txt` by hand, run `tools/golden --update --case <name>`, and read the outputs against `about.txt` before committing. A changed output on purpose is reviewed with `git diff tests/golden`.

## Code conventions

`jibb-dev/lib/jibb.hoon` is one core with no Ford runes, so `urbit eval` can run it and Clay can build it. Its design notes open the file in numbered sections; keep them true when the code changes, since they are where the reasoning lives. [compiler.md](compiler.md) maps the file.

- An arm's comment is `::  +name: what it is`, then details indented by four spaces.
- Types avoid the standard library's names (`mold`, `wing`, `gate`), hence `+shape` for a mold as written. Every type in a recursive cycle has a `$~` default that is a leaf, or Hoon can't build its default.
- Two arms do shadow the standard library: `+in`, a bit test, hides the set door `in`, and `+fail` hides Hoon's parser rule `fail`. Inside the library, and under `tools/hoon`, write `~(has in:..zuse s)`, or rename `+in` before code there uses sets.
- The parser's errors read "expected <what>, found <token>", with an optional "; <hint>"; the layout pass's state the rule broken, as "a tab: Jibb uses spaces only". No final period, lowercase except for names, and the code the error is about in backticks; example code in a hint, as m(done=%.y), isn't quoted so far. Their wording is fixed by the golden tests once written.
- Loops over many items are tail calls, so long inputs grow no stack; check new passes on a long module.

## Commits

A short subject in the imperative, then a body that says what changed and why, wrapped at 72 columns, as in `git log`. Each commit leaves every check passing.
