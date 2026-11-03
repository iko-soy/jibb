# Development

How to work on Jibb: the rules the plan sets, how to set up a machine, and what to run before pushing. The repo's [README](../README.md) describes each tool in full.

## Ground rules

From the plan's Setup and ground rules, and from @iko:

- **The spec wins.** Where code and spec disagree, the spec stands until it changes. Until the Claude doc is synced with the repository's decisions, the spec is the copy in [spec/](spec/); the Synced column in [spec/decisions.md](spec/decisions.md) shows which rows the doc has.
- **Language changes are agreed first** and recorded in the Decisions tab, before the code changes.
- **Questions go to @iko**, as comments on the doc, on the words they're about. While one is open, follow the most likely reading, mark it "(doc question)" in the library's notes, and list it in [open-questions.md](open-questions.md). Where an error points is not a doc question: the library's section 2.0 settles it.
- **Every Jibb code block in the doc is a golden test**, and each stage's output is printed and compared. The doc labels its Jibb blocks `jibb`; `tools/doc-blocks` checks that each has its case.
- **Each milestone ends with its checks passing on a fake ship**, not only under `urbit eval`.
- **Push straight to `master`.** @iko reviews work in the project's chat, not in pull requests, so there are none. Run the checks below first.
- **Keep docs/ current**: [status.md](status.md) when a milestone moves, [open-questions.md](open-questions.md) when a question is found, and [spec/decisions.md](spec/decisions.md) when one is settled: it moves there.

The source-backed generic-union guard is the suite `tests/lib/jibb-union-source.hoon`: `tools/test-arms jibb-union-source` runs its `test-union-source` arm under eval, and the same arm is assembled for the fake ship. It checks a bounded partial inference slice, not general union completeness. `tests/lib/jibb-union-alias-overlap.hoon` exercises the separate positive overlap witness, with one test arm shared by eval and the ship. `tests/lib/jibb-full-overlap-basic.hoon` and `tests/lib/jibb-full-overlap-graph.hoon` check structured full-module overlap evidence and the legacy error text; `tools/test-arms 'jibb-full-overlap-*'` runs both of their test arms under eval, and both are assembled for the fake ship.

## Setting up a machine

The tools need Python 3 and `urbit` (vere) on `PATH`; the ship tools also need a fake `~zod` and click. Everything so far ran with vere 4.6 on Linux.

With Nix (and flakes), `nix develop` gives a shell with vere 4.6, Python 3 and click, as the flake pins them, and sets `$JIBB_CLICK`. `nix build .#fakezod` boots a fake `~zod` from the pinned brass pill in about half a minute; copy it to where `tools/ship` expects it:

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

In a Claude cloud container, the network blocks urbit.org, bootstrap.urbit.org, nixos.org's installer and GitHub's release downloads. When Nix is already installed, as it was on 2026-11-02, the flake does all of the below: it fetches nixpkgs from channels.nixos.org, click with git and the pill from media.githubusercontent.com, which the network allows. Otherwise, this worked on 2026-10-29, and has to be redone in each new container:

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
| `tools/check` | Runs every check in this table, or a group (`--group eval` or `ship`), or some by name: see [Before pushing](#before-pushing) |
| `tools/golden` | Runs the golden cases under `urbit eval`: every case, or those matching `--case`; `--update` rewrites the expected outputs; `--show` prints them |
| `tools/test-arms` | Runs the `test-` arms of the `tests/lib` suites under `urbit eval`, each with the subject Ford would give it on the `jibb-dev` desk: every suite, or those named or matched by a glob, as `tools/test-arms jibb-store 'jibb-program-*'`; `--shard I/N` runs the I-th of N balanced shards; `--list` prints the suites and their arms; `--report` and `--update` print or rewrite a golden-report suite's report. See [The test suites](#the-test-suites) |
| `tools/clay-fixtures` | Syncs `my-app` and `jibb-fixtures`, builds their example `/sur` files and marks through Clay, checks selected mold and mark projections and the partial checker, and records Ford and mark subject shapes on the fake ship |
| `tools/hoon` | Evaluates Hoon with the library in scope, as `tools/hoon '(golden /a/b/jibb (crip "++ main view"))'`; `--cord name=file` binds a file's text, `-f` reads the expression from a file; `--no-debug` leaves out `!:`, which gives errors their positions but makes the checker 2.2 to 2.6 times slower than on a ship, for timings |
| `tools/doc-blocks` | Checks the doc's `jibb` blocks against the `doc-*` golden cases: `tools/doc-blocks docs/spec` |
| `tools/ship` | Runs the fake ship: `start`, `stop`, `status`, `log`, `sync <desk>`, `assemble --out <dir>` (no ship needed), `test`, `gen-tests`, `check-commit`, `scry`, `hoon`, `run`, `poke`, `commit`, `mount`, `unmount` |
| `tools/testdata/selftest` | Tests `tools/golden` and `tools/hoon` against a stub library, `tools/test-arms` against the stub library with suites it writes, and `tools/doc-blocks` against Markdown it writes |
| `tools/testdata/ship-selftest` | Tests `tools/ship`'s test generator and runner against a stub library on the ship |

`tools/golden` starts `urbit eval` once and builds the library, which takes about 27 s, then runs every case under `mule`, so a crash fails only its own case.

## The test suites

Each file in `tests/lib` is a suite: a core of `test-` arms, with the libraries and files it reads bound by `/+` and `/*`. On the fake ship, `tools/ship test` runs every suite's arms with `-test /=jibb-dev=/tests`; under eval, `tools/test-arms` runs the same arms, so every suite below runs in both places. `tools/test-arms` gives each suite the subject Ford would give it on the `jibb-dev` desk: each `/+` library and each `/*` file, found where `tools/ship assemble` puts them. Before a suite's `|%` it takes only comments, `/+` lines and `/*` lines, and binds only `%txt` and `%jibb` files. The suites it runs share one eval, so the library is built once for all of them, in about 17 s with `!:`, and so is the importer library `jibb-import`, in about 20 s more, when any of them uses it. Each arm runs under `mule` and prints `OK`, `FAILED` or `CRASHED`, as `-test` does; a crashed arm's trace is mapped to lines in the suite and the library, with an excerpt of the innermost spot. When a suite doesn't build, `tools/test-arms` runs the suites again one at a time and reports it as `FAILED <suite> (build)`, with its error placed in the suite file. `tools/test-arms <suite>` runs one suite, and names or globs pick several, as `tools/test-arms jibb-store 'jibb-program-*'`; `tools/test-arms --list` prints the suites and their arms. `tools/check` runs them all in four shards, `arms-1` to `arms-4`, each `tools/test-arms --shard I/4` in an eval of its own, balanced by the measured costs in `COSTS` and `LIB_COSTS` in `tools/test-arms`. `tests/lib/jibb.hoon`, which `tools/ship gen-tests` writes from `tests/golden`, is left out under eval, since `tools/golden` runs those cases.

A golden-report suite has a `report` arm and a golden file bound to the face `expected`; its test arm compares the report with that file, and `tools/test-arms --list` marks it `, report`. `tools/test-arms --report <suite>` prints the report, and `tools/test-arms --update <suite>` writes it to the file; with no suite named, `--update` writes every golden-report suite's. When such a suite's arm fails, `tools/test-arms` prints a unified diff between the file and the report. `jibb-buttons` and `jibb-deferred-prepared` have golden files too, but compare them inside helpers over several cases and have no `report` arm. Every golden file, a `/*` `%txt` file bound to a face containing `expected`, must end in exactly one newline (a suite compares `wain`s, which can't show a missing one) and hold no line that starts `BAD ` or ends `: BAD`; `tools/test-arms` checks that before any eval, and `--update` won't write a report that breaks it.

The `jibb-dev` desk holds `my-app`'s `ui/`, `sur/` and `mar/` under `/my-app` (review question 31), so the suites that check `my-app` files bind them there, as `/*  sur  %txt  /my-app/sur/todo/hoon`, and keep no copies. A mark's `/-` line is Ford's, which `ride` can't parse, so the suites that ride a mark drop it with their `+mark-text` arm. Where the table below calls a `my-app` file byte-identical or unchanged, the suite reads that file itself. Files that only the importer's tests need are kept off `my-app` (review question 34): the Clay fixtures' `/sur` with a Ford import, their mark and the real Tlon notes `/sur` are in `tests/clay-fixtures/desk/`, which the `jibb-fixtures` desk adds to `my-app` and the `jibb-dev` desk leaves out, and the golden cases and `tests/type-poke/mark.txt` that use the mark link to `tests/clay-fixtures/desk/mar/label.hoon`.

| Suite | What it checks | Golden files |
| --- | --- | --- |
| `jibb-api-evidence` | Source, scope, reader-result and declaration-watchability evidence guards for path declarations, in two arms, over synthetic and real todo inputs | |
| `jibb-api-paths` | Partial API path analysis with real todo mark samples; it does not generate request interfaces | `tests/type-api-paths/expected.txt` |
| `jibb-arithmetic-guards` | Restricted atom-variable, unification and projection guards | |
| `jibb-ask-guards` | Ask origin and canonical list/unit bootstrap guards | |
| `jibb-bridge` | The importer/checker bridge: the Hoon importer composed with the partial checker | `tests/type-import/expected.txt` |
| `jibb-buttons` | The documented valid button helpers and the unchanged unresolved-`%add` module, through detailed and legacy inference | `tests/type-buttons/expected.txt` |
| `jibb-cell-branch` | Closed-cell branch context, rollback and bounded retry screens | |
| `jibb-check-spans` | `+check-spans`, which `+golden` runs on every tree: its own test, `+check-spans-test`, moves the spans of parsed nodes as a parser bug would and checks that it says so | |
| `jibb-closed-gate-guards` | Closed gate sample labels and face uncertainty | |
| `jibb-constructor-fit-guards` | Constructor-case uncertainty and known mismatches | |
| `jibb-deferred` | The bounded source-owned deferred inference transaction | `tests/type-deferred/expected.txt` |
| `jibb-deferred-context` | Deferred source order and literal branch contexts | `tests/type-deferred-context/report.txt` |
| `jibb-deferred-prepared` | Prepared-prelude tuple initializer recovery, exact partial reports and fail-closed guards | `tests/type-deferred-prepared/expected.txt`, `expected-control.txt` and `expected-tuple-only.txt` |
| `jibb-deferred-resolver` | Deferred resolution, report consistency and atomic failure | `tests/type-deferred-resolver/expected.txt` |
| `jibb-direct-gate-guards` | Direct gate provenance: direct layout evidence keeps its provenance and final face constraints | |
| `jibb-direct-gate-source` | A synthetic source-backed program report: direct-source gate layouts through a synthetic program scaffold | `tests/type-direct-gate/expected.txt` |
| `jibb-doc-examples` | Full checking of the import-only, view-day, step and cmd/sub doc fragments in their intended contexts, through detailed and legacy inference | |
| `jibb-empty` | Source-backed empty molds, inhabitedness, coverage and proof budgets | `tests/type-empty/expected.txt` |
| `jibb-full-overlap-basic` | Structured full-module overlap evidence: source-bound overlap witnesses, generic parameter limits, precedence and rejection controls, and the legacy full-module error text | `tests/type-full-overlap/expected-basic.txt` |
| `jibb-full-overlap-graph` | Imported-source attribution of overlap evidence across parent and child modules: cache rebuilds and source binding, and private, cyclic, duplicate, missing and transitive imports | `tests/type-full-overlap/expected-graph.txt` |
| `jibb-gate-free-guards` | Bounded gate-free verdicts, persistent constraints, substitution safeguards, collection keys and witness paths | |
| `jibb-gate-free-source` | Source-backed todo mold analysis through the real readers | `tests/type-gate-free/expected.txt` |
| `jibb-generic-alias` | Public/private generic union alias and provenance guards | |
| `jibb-generic-construction` | Source-backed one-layer recursive construction, provenance and fuel | `tests/type-generic-construction/expected.txt` |
| `jibb-generic-pattern` | Source-backed recursive patterns, catch-all coverage, state and per-attempt fuel/arm limits | `tests/type-generic-pattern/expected.txt` |
| `jibb-generic-recursion` | Source-backed generic recursive identity and provenance | `tests/type-generic-recursion/expected.txt` |
| `jibb-hole-guards` | Hole-defaulting and API interface guards | |
| `jibb-hoon-reference` | Hoon translations of the Jibb-written `zing`, `lead`, `late` and `succ` against Hoon's own arms, on selected inputs; this does not execute Jibb, test lowering or prove jet recognition | |
| `jibb-import` | The partial Hoon importer's diagnostic trees and errors over the importer fixtures, and the structured values behind them; the projection is an internal tree, not the Jibb type printer | `tests/importer/tree.txt` |
| `jibb-import-default` | Default-wrapped union source proofs over a real Tlon mold, and adversarial cases | `tests/type-import-default/expected.txt` |
| `jibb-import-diagnostic` | The structured reader diagnostic bridge report: definite and unsupported reader diagnostics through the checker | `tests/type-import-diagnostic/expected.txt` |
| `jibb-import-overlap` | Source-aware Hoon union overlap, provenance and proof-budget controls | `tests/type-import-overlap/expected.txt` |
| `jibb-import-structural` | Multi-case and nested Hoon union overlap witnesses | `tests/type-import-structural/expected.txt` |
| `jibb-list-alias-guards` | Prelude list-alias and provenance guards | `tests/type-list-alias/expected.txt` |
| `jibb-mark-bridge` | The partial checker's mark import boundary | `tests/type-mark/expected.txt` |
| `jibb-module-scope` | The partial module checker's prelude boundary and duplicate-source rejection | `tests/type-module-scope/expected.txt`, and the golden case's `tests/golden/types-prelude-interface/types.txt` |
| `jibb-nested-union-guards` | Nested tagged-union case selection and uncertainty | |
| `jibb-page-main` | Full checking of byte-identical static and direct data pages through real readers, exact main types, downstream imports and rejection guards | |
| `jibb-poke-bridge` | Source-backed prelude and poke-only API reports | `tests/type-poke/expected.txt` |
| `jibb-positional-face-guards` | Positional-call and nested-face guards | |
| `jibb-program-init` | Transactional direct-program initializer recovery, exact exported/imported types and fail-closed boundaries | |
| `jibb-program-main` | The narrow closed subscription-free program-main interface, downstream import and rejection guards | |
| `jibb-program-update` | Transactional direct-program update result recovery, union/boolean context, exact exported/imported types and fail-closed boundaries | |
| `jibb-program-watch` | Direct singleton request-value watchability against merged real-todo evidence, exact types/imports and rejection boundaries | |
| `jibb-proj-guards` | Projection evidence, name-scope and dependency guards | |
| `jibb-qath-fuel` | Recursive qath unfolding and face guards: unfolding uses bounded fuel and keeps uncertain faces | |
| `jibb-qath-source` | Qath source-provenance guards: source-backed qath accepts only the proven public and internal interfaces | |
| `jibb-request-guards` | Request evidence, source consistency and cache provenance guards | |
| `jibb-store` | The unchanged cart/basket through detailed and legacy inference, exact store/derived schemes, malformed-prelude guards, structural imports, source-bound state watch evidence and rejection guards | |
| `jibb-sub-guards` | Source-backed subscription mold dependencies | |
| `jibb-theme` | Full checking of the byte-identical real theme, its exact exported type, structural downstream import, dark absent/present forms and rejection guards | |
| `jibb-tlon-bridge` | The real, unmodified Tlon presence source through the importer and partial checker | `tests/type-tlon/expected.txt` |
| `jibb-todo-api` | The actual todo API through the real Hoon readers and partial checker | `tests/type-todo-api/expected.txt` and `negative-expected.txt` |
| `jibb-todo-full` | Full checking of the byte-identical todo island and an ordinary call-bodied annotated-initializer variant through real readers, exact main types, structural downstream import and rejection controls | `tests/type-todo-full/expected.txt` |
| `jibb-todo-partial` | Partial inference reports for the unchanged todo island through the real API and readers | `tests/type-todo-partial/expected.txt` |
| `jibb-typecheck` | The partial inference unifier, through the library's own `+itype-unify-test` cases | `tests/checker/unification.txt` |
| `jibb-union-alias-overlap` | Source-backed generic-alias overlap witnesses | `tests/type-union-alias-overlap/expected.txt` |
| `jibb-union-source` | Bounded local generic-alias disjointness and state guards | `tests/type-union-source/expected.txt` |

`jibb-deferred` exercises the bounded, source-owned constructor transaction and low-level freshness/replay guards. `jibb-deferred-resolver` checks the experimental import-free library resolver, report consistency, atomic failure, and that both source orders of a late face constraint decline. `jibb-deferred-prepared` checks the separate partial-report-only prepared-prelude route, direct tuple-literal obligations, exact report types and its wrong-field, unrelated-tag, mold-collision and no-final-cast controls. These suites do not establish island-kind or watchability support.

## Before pushing

```
tools/check                  # every check; it exits 0 only when all pass
tools/check --group eval     # only the checks that need no ship
nix flake check              # the same checks in the Nix sandbox, on a fresh fake ~zod
```

`tools/check` runs every check the repo has. Their one list is `CHECKS` in the script, so a new check goes there, as well as in the table above; `tools/check --list` prints it with each check's command. A new suite in `tests/lib` needs no new check: `arms-1` to `arms-4` run every suite's arms, in shards of about equal time, and a slow suite's cost belongs in `COSTS` in `tools/test-arms`, which balances them. The eval group, the 7 checks that need only `urbit` and Python, runs several at a time (`-j`, by default one per CPU), the slowest first. The ship group, `ship-selftest`, `ship-test`, `check-commit` and `clay-fixtures`, then runs one check at a time on the ship `tools/ship` talks to; `tools/check` starts it if it isn't running and stops it again afterwards. Name checks, or globs, to run only those: `tools/check golden 'arms-*'`. To run one suite under eval, use `tools/test-arms <suite>`, as `tools/test-arms jibb-todo-full`. A failing check's output follows its FAIL line; `-v` prints every check's output, and `--logs DIR` keeps it all.

There is no CI, so nothing runs these checks for you: run `tools/check` or `nix flake check` before every push. `nix flake check` needs nothing but Nix, since it builds the desks and runs both groups in the Nix sandbox, the ship group (Linux only) on a fake ~zod it boots itself; see the [README](../README.md#building-and-checking-with-nix).

`ship-selftest` matters most when `tools/ship` changed, and `check-commit` when the mark or the desks changed, but `tools/check` runs both every time. The self-test leaves fixture files on the `jibb-dev` desk, and `ship-test`, which runs after it, puts the real ones back.

`tools/ship test` regenerates `tests/lib/jibb.hoon` and syncs the `jibb-dev` desk before it runs. The file is ignored by git, since desk assembly always regenerates it. Sync preflights and splits large deletion lists into bounded click requests, waiting for each Clay revision; a failure stops later batches. The ship self-test exercises this when switching from the full desk to a smaller fixture desk. A run with `--stub`, `--lib`, or a custom `--golden` isolates its generated golden tests from the repository's other test programs; run the default command afterward to restore and test those programs. `tools/ship test` also runs every other suite in `tests/lib`, and `tools/test-arms` runs the same suites under eval, so each compares the same fixtures and golden files in both places. `tests/lib/jibb-import.hoon` runs the importer fixtures against their expected diagnostic projection, an internal tree, not the Jibb type printer, and checks the structured values behind it. The probes it runs live in the suite, not in `jibb-dev/lib/jibb-import.hoon`, which app desks vendor. `tests/lib/jibb-bridge.hoon` runs the importer/checker bridge fixture, and `tests/lib/jibb-tlon-bridge.hoon` the real Tlon presence reader/checker fixture. `tests/lib/jibb-import-diagnostic.hoon` covers the structured reader diagnostics, and `tests/lib/jibb-mark-bridge.hoon` compares the mark bridge's fixture report. `tests/lib/jibb-poke-bridge.hoon` holds the source-backed prelude and poke-only API fixture. `tests/lib/jibb-api-paths.hoon` runs partial path analysis over the real todo marks; this does not generate request interfaces. `tests/lib/jibb-module-scope.hoon` compares the prelude scope report.

## Golden cases

A case is a folder `tests/golden/<name>/` holding:

- `source.jibb`, the input, ending in one newline. A case whose input is a `my-app` file, such as a doc block that `my-app` holds, makes it a symlink to that file; desk assembly leaves the link out, and `tools/ship gen-tests` reads the file from `/my-app`. A file under `modules/` may link to `my-app` the same way;
- `about.txt`: a `source:` line with the doc's words or block it comes from, a `tests:` line saying what it exercises, and an `expect:` line, either `parses` or `error at <line>:<col>` and why (one case, `inline-leftout-signed-float-auras`, says `unclear`: see grammar question 13 in [open-questions.md](open-questions.md));
- the expected outputs, `tokens.txt` and `tree.txt`, each the output plus one newline.
- optionally, `path.txt`, the logical `/ui/.../*.jibb` path to pass to the compiler; the source remains `source.jibb`.
- optionally, an `expect-types:` line in `about.txt` opts the case into `+golden-types`; `types.txt` holds its output plus one newline and `--update` creates it. A `types.txt` also opts in when the line is absent. This interface is provisional while the checker is under construction.
- optionally, `imports.txt` selects Hoon `/sur` molds, one `module mold` pair per line. Each module's source goes in `sur/<module>.txt` and is compiled against zuse by both runners. `marks.txt` selects marks, one name per line, with source in `mar/<name>.txt`; both kinds may be supplied together. The reader results go to the partial checker, and a type output is required. Both runners reconstruct fixture text from `%txt` lines and identify the fixture if its compilation crashes; a crash fails the case without discarding its successful parse output. These fixtures currently handle only sources without Ford imports.
- optionally, `modules.txt` lists logical `/ui/.../*.jibb` paths, one per line. The corresponding sources live below the case's `modules/ui/` directory. Both runners parse each source at its logical path and compare the combined `module-trees.txt`; `--update` writes that output. A case with type output also supplies these sources and the vendored prelude to the partial module checker. The file opts in even when it lists no sources; use a comment such as `# no module fixtures` for an empty bundle. Blank lines and comment lines are ignored. Cases without `modules.txt` keep their existing no-prelude type interface.

The runners prepare the trusted vendored public and internal prelude sources once for their generated test core and share the partial interface. Preparation reserves all names present in the public source and supplies the molds and values the fragment can infer; an unsupported declaration remains reserved but unavailable. The source and checker are incomplete, so the output still says the module has not been checked and does not claim complete shadowing coverage. `+golden-types-with-prelude-and-internal` accepts both sources directly; callers using `+golden-types-with-prepared-prelude` pass the unchanged result of `+prepare-prelude-with-internal`. The older source-only entry points remain available for preludes without imports. Missing or malformed sources fail closed.

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
