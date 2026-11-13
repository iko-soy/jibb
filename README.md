# Jibb

Jibb is a UI language for Urbit: a Hoon dialect with an indentation layout. Its specification is [Jibb — an Elm-architecture UI language for Urbit](docs/spec/overview.md), with the remaining specification documents in [docs/spec/](docs/spec/). Where this code and the spec disagree, the spec wins.

Milestones 1 through 5 of the doc's eight are done, and the builds of milestones 6 to 8 are in place: islands, stores and the browser runtime; `-jibb!test`, the Node harness and the formatter; shared island modules, views that reuse their unchanged parts, and a library of 19,938 gzipped bytes, checked against its 20,000-byte limit. What remains is in [docs/status.md](docs/status.md): the benchmark's bar, which waits for @iko, CI's first run, and compiling views with holes. [docs/](docs/) holds a copy of the doc's tabs, the status of each milestone, the open questions, a development guide, a map of the compiler, and milestone briefs.

## Layout

- `jibb-dev/`: what app desks vendor: the `%jibb` mark, compiler, Hoon type reader, checked prelude, lowering and backends, renderer, and browser library.
- `jibb-cli/`: the native Rust `jibb` executable and its tree-sitter grammar, for earth-side utilities.
- `jibb/`: the `%jibb` desk, for the shared host and its threads, `-jibb!clear` and `-jibb!test`.
- `js/`: the browser library, bundled into `jibb-dev/lib/jibb/runtime.js` by `tools/bundle-js`: the Core-to-JavaScript backend, native runtime, virtual DOM and island loop, Eyre channel and effects, shared stores, URL runtime and the boot script that starts a page's islands; with the entry linker, the Nock comparison backend, and Node and differential tests.
- `my-app/`: an example app desk built from the doc's worked examples.
- `vendor/`: pinned copies of the base-dev and landscape files the desks need.
- `tests/`: golden cases in `golden/<case>/`, test suites in `lib/` and their fixtures, for `tools/test-arms` and the ship's `-test` thread, and in `clay-fixtures/`, the threads `tools/clay-fixtures` runs and, in `clay-fixtures/desk/`, the Hoon files the `jibb-fixtures` desk adds to `my-app`. `lib/jibb.hoon`, which runs the golden cases on the ship, is generated.
- `tools/`: dev tooling: `golden`, `test-arms`, `hoon` and `doc-blocks`, with their self-test in `testdata/`, `ship`, and `check`, which runs every check.
- `docs/`: the doc's tabs as Markdown in `spec/`, the status, the open questions, the development guide, the compiler's map, and briefs for milestones in `prompts/`.

## Building and checking with Nix

The flake (`flake.nix`, pinned by `flake.lock`) builds the desks and runs every check, with vere 4.6, Python 3, click and the brass pill pinned:

```
nix build              # result/{my-app,jibb,jibb-dev,jibb-fixtures,jibb-host-fixture}: the desks
nix build .#jibb       # result/bin/jibb: the native earth-side executable
nix flake check        # every check: the CLI, eval group and, on Linux, the ship group on a fresh fake ~zod
nix develop            # a shell with urbit, Python, click, Rust and tree-sitter
nix build .#fakezod    # a freshly booted fake ~zod pier (Linux)
```

The default `nix build` writes the five desks exactly as `tools/ship sync` would commit them (it runs `tools/ship assemble`), and compiles `jibb.hoon` and `jibb-import.hoon` under `urbit eval` to check that they build. `jibb-cli-unwrapped` builds and tests the native CLI without Urbit; `jibb` packages a copy of that executable with its runtime helpers and vendored desks. Changing those files repackages the CLI without recompiling Rust.

`nix flake check -j 2` builds those and the CLI, runs the CLI's Rust tests, and runs the eval and Linux ship checks in the Nix sandbox without network. The eval aggregate has 14 golden batches, nine arm batches (eight regular shards and `arms-builder`), four strict-probe batches, a separate tooling selftest, a residual group and a manifest-freshness check. The ship aggregate uses the same nine ordinary-suite batches plus golden, base integration, four ship-probe groups, and the host/browser/Node chain, each with an independent fresh pier copied from the pinned pill. Nix reuses a batch whose complete source closure is unchanged. `nix/eval-manifest.json` records eval and ship closures, including the selected probes. Its checker compares full and narrowed Hoon programs, probe inputs and recorded desk files. Run `tools/eval-manifest --write` after changing case or suite membership, dependencies or shard assignments, and `tools/eval-manifest --check` to verify it. Eval tests use `--fast`, retaining debug replay on failure; the tooling selftest remains instrumented. A first full run still takes hours, but an unrelated change need not repeat every Hoon expression. Each aggregate keeps links to its batches' logs. To run a single check, use `nix develop -c tools/check <name>` (see [docs/development.md](docs/development.md#before-pushing)).

Limits: the ship checks need Linux, since `tools/ship` finds the ship's processes in `/proc`, so on macOS `nix flake check` runs only the CLI and eval group. Only `x86_64-linux` has been tried; the flake also declares `aarch64-linux` and `aarch64-darwin`, the other platforms nixpkgs builds vere for.

CI restores Nix results from prior commits and saves successful push results in GitHub Actions' cache. Check outputs, the raw Rust executable and the clean fake-ship seed are rooted before cache garbage collection so the individual batch results, compiled CLI and ship setup survive. Pull requests restore caches without uploading them. The cache targets a 4 GiB store after collecting unreferenced paths; live results can exceed that target, and GitHub's repository cache quota controls retention. No separate cache credentials are needed.

## Earth-side CLI

The source utilities need neither a ship nor `urbit`; `dev` is the exception. Build the executable with `nix build .#jibb`, or run it from a Rust toolchain with `cargo run --manifest-path jibb-cli/Cargo.toml -- <arguments>`. The Nix package includes the ship helper, its Python/Urbit/click runtime dependencies, and the Jibb desk dependencies.

```
jibb init DIRECTORY        # create a Hoon agent and Jibb frontend project
jibb dev DIRECTORY --pill PILL  # boot a fake ship, create/mount/sync the desk
jibb dev DIRECTORY         # start its existing pier and sync the desk again
jibb fmt FILE...          # format files in place
jibb fmt                  # read standard input and write standard output
jibb fmt --check FILE...  # report files that would change; exit 1
jibb fmt --diff FILE...   # print unified diffs without writing
jibb check FILE...        # statically check files without evaluating them
jibb check -              # read standard input and check it
jibb check FILE --source-root DIR
jibb check FILE --prelude FILE
jibb run FILE             # statically check and evaluate main
jibb run FILE --entry NAME  # evaluate another entry definition
jibb run FILE --source-root DIR  # resolve `/=` module imports under DIR
jibb run FILE --prelude FILE   # include a source prelude module
jibb docs PATH...             # write module documentation under docs/api
jibb docs PATH... -o DIR      # write module documentation and readme.md under DIR
```

`init` creates a counter application in a new or empty directory. The desk name comes from the directory's final component and must be a lowercase Hoon term. The template includes a Gall agent, shared `/sur` types and `/mar` marks, an agent API module, a Jibb island, and desk metadata. It refuses to overwrite a nonempty directory.

`dev` performs the complete local setup in one command: it boots a fake `~zod` when the pier is absent (or starts an existing pier), creates the desk if needed, mounts it, mirrors the application over the standard Jibb/vendor dependencies, commits it, and verifies the result. Its default pier is `DIRECTORY/.jibb/zod`; `--pier` selects another, and `--desk` overrides the directory-derived desk name. A new pier needs `--pill`; subsequent runs do not. The ship remains running. `--urbit`, `--click`, and `--timeout` customize the runtime, while `--ship-tool` or `$JIBB_SHIP_TOOL` selects a ship helper outside the normal repository or installed-package locations. A root `README.md` and dotfiles such as `.jibb/` stay earth-side.

File commands select the source language from the filename extension; there are no language-selection flags. `.jibb` is currently the supported source extension, and file inputs with another or no extension are rejected. Standard input is Jibb.

Formatting follows the canonical style in `docs/spec/grammar.md`. Invalid source is not written. `check` parses, links and statically checks source without evaluating it, reporting all requested files' errors and producing no output on success. `run` evaluates the supported pure fragment only after static checking; unsupported language features report errors rather than executing unchecked code. Both commands resolve `/=` imports from `--source-root` directories, and `--prelude` links an optional source prelude. `cargo test --manifest-path jibb-cli/Cargo.toml` runs the CLI, parser, formatter, static-checker and runtime tests, including the repository's golden corpus when run from a checkout.

`docs` accepts Jibb files and directories, recursively includes their `/=` imports, and statically checks each module. It writes one Markdown file per module, preserving relative paths, with a table of contents, leading `::` documentation comments, mold definitions, and inferred value types. The output directory's `readme.md` links to every generated module. Its default output directory is `docs/api`; `--source-root` and `--prelude` have the same meaning as for `check` and `run`.

### Runtime packaging

Urbit is deliberately a runtime dependency, not embedded in the Rust executable. The Nix package supplies a pinned runtime closure with Urbit, click, Python, and the ship helper, so `dev` needs no separate installation of those tools. Embedding only Urbit would not make the CLI standalone: click and the ship helper would remain external, and the executable would need OS/architecture-specific builds, larger releases, and a new update process for Vere compatibility and security fixes. Urbit also docks binaries into a pier at runtime.

For a single-download distribution, use a self-extracting, platform-specific bundle containing the CLI and its complete runtime rather than embedding Urbit with `include_bytes!`. The startup pill is a separate input: `dev` requires `--pill` for a new pier and never downloads one implicitly. The flake's reproducible `.#fakezod` package uses the separately pinned brass pill from `flake.nix`.

## Golden tests

Each case, `tests/golden/<case>/`, holds `source.jibb` and the expected outputs: `tokens.txt` from the layout pass and `tree.txt` from the parser. Optional `about.txt` records where it comes from, what it tests, and the expected outcome. A file holds the output plus one trailing newline. A case may also have a `path.txt` specifying its logical `/ui/.../*.jibb` path. An `expect-types:` line in `about.txt` opts it into full-checker output in `types.txt`; `expect-core:` opts into checked lowering and canonical Core output in `core.txt`. `--update` creates opted-in outputs. A case can select Hoon molds in `imports.txt` and provide each module in `sur/<module>.txt`, or select marks in `marks.txt` and provide their source in `mar/<name>.txt`. `modules.txt` selects Jibb source fixtures; their trees go in `module-trees.txt`, and the partial checker can resolve a subset of library imports. See [docs/development.md](docs/development.md).

Run them without a ship. This needs `urbit` on PATH and Python 3.

```
tools/golden                         # every case: PASS or FAIL, a diff per failure, a summary
tools/golden --fast                  # omit Hoon instrumentation; replay failures with debug
tools/golden --case 'doc-grammar-*'  # only the cases matching a glob
tools/golden --show --case foo       # print the outputs, don't compare
```

When outputs change on purpose, regenerate them, then review the diff before committing:

```
tools/golden --update
git diff tests/golden
```

`tools/golden` compiles `jibb-dev/lib/jibb.hoon` once under `urbit eval` and calls its `golden` arm on each case under `mule`, so a crash fails only its own case. `--update` never writes a crash. Errors and crash traces point at lines of the library. The exit status is 0 when every case passes, 1 when a case fails, and 2 when the tests can't run, for example because the library doesn't compile.

To try the library by hand:

```
tools/hoon '(golden /a/b/jibb (crip "++ main view"))'
tools/hoon --raw --cord src=tests/golden/foo/source.jibb 'tree:(golden /a/b/jibb src)'
```

`tools/testdata/selftest` tests `tools/golden` and `tools/hoon` against a stub library, `tools/test-arms` against the same library with suites it writes, and `tools/doc-blocks` against Markdown it writes.

### The doc's examples

Every code block the design doc labels `jibb` is a golden case, `doc-<tab>-<n>-<what>`, where `<n>` counts the tab's code blocks, labelled or not. To check that none is missing or stale, export the doc's tabs as Markdown and pass the files, or a folder of them:

```
tools/doc-blocks docs/spec                                 # the snapshot in docs/spec
tools/doc-blocks Grammar.md Overview.md Core-language.md  # fresh exports
```

It matches each labelled block to the case whose `source.jibb` is the block's text plus a newline, and lists the blocks no case holds, each with a diff against the closest unmatched case, and the `doc-*` cases no block holds. Pass every tab with Jibb blocks, or the other tabs' cases count as stale. The exit status is 0 when every block has a case and every case a block, 1 when one doesn't, and 2 when the check can't run, for example because no block is labelled `jibb`.

## Test suites

Each `tests/lib/<suite>.hoon` file is a test suite: a core whose `test-` arms return a `tang`, empty when the arm passes. `tools/ship test` runs every suite on the fake ship with the `-test` thread. `tools/test-arms` runs the same arms under `urbit eval`, without a ship, for every suite but the generated `jibb.hoon`, whose golden cases `tools/golden` runs. It gives each suite the subject Ford would give it on the `jibb-dev` desk: its `/+` libraries and its `/*` files, which must be `%txt`, `%jibb` or `%hoon` files, from where `tools/ship assemble` puts them. Like `tools/golden`, it needs `urbit` on PATH and Python 3.

```
tools/test-arms                              # every suite
tools/test-arms --fast jibb-store             # fast execution, diagnostic replay on failure
tools/test-arms jibb-store 'jibb-program-*'  # suites by name or glob
tools/test-arms --shard 2/4                  # the second of four shards, balanced by measured cost
tools/test-arms --include-library jibb-build # suites that read the builder, directly or indirectly
tools/test-arms --shard 2/8 --exclude-library jibb-build # the same suite selection as arms-2
tools/test-arms --list                       # the suites and their arms; ", report" marks a golden report
tools/test-arms --report jibb-import         # print a golden-report suite's report
tools/test-arms --update jibb-import         # write it to the suite's expected file
tools/check arms-builder                    # the named builder eval batch, with --fast
```

Many suites share one eval, so the library is built once per eval, not once per suite. Each arm runs under `mule` and prints OK, FAILED or CRASHED, as `-test` does, with what it returned or, for a crash, its trace mapped to lines of the suite and the library. When an eval fails, it is run again one suite at a time, and each suite that doesn't build is reported as `FAILED <suite> (build)`, with its error placed in the suite file. An eval that runs past `--timeout`, 1800 s by default, fails each of its suites as `(timeout)`. The exit status is 0 when every arm passes, 1 when an arm or a golden file fails, and 2 when the suites can't run, for example on a usage error or a suite header it can't read. `tools/check` runs nine batches, `arms-1` to `arms-8` and `arms-builder`, using `--fast`. Standalone runs retain debug instrumentation unless `--fast` is requested. A fast failure stays a failure even when its diagnostic replay passes.

Registered batches first balance all suites into eight shards, then extract suites that read `jibb-build` into `arms-builder`, currently `jibb-build` and `jibb-build-probe`. The dependency selector follows libraries and bound files, including indirect library dependencies. Extracting after balancing preserves the other suites' shard assignments; Nix records each resulting batch's eval and ship source closure. Plain `tools/test-arms` still runs every suite, and plain `--shard I/N` retains the complete balanced shard. `--include-library NAME` and `--exclude-library NAME` apply their filter after sharding; they can also be used with `--list`.

`tools/bench-eval --batch arms-2 --output /tmp/jibb-eval-profile` measures startup, compiler preparation, batch preparation, compilation and execution in fresh eval processes. It freezes every selected program and its input hashes before timing, preserves raw logs, and requires both execution variants to return every expected arm result in order. The output directory must be new. Use `--dry-run` to inspect the generated inputs without starting Hoon, or repeat `--stage` to select stages. This is a manual benchmark; stage differences are estimates because compilation and runtime caches interact. See [the development guide](docs/development.md#the-tools).

A golden-report suite has a `report` arm and a `/*` file bound to the face `expected`; when one of its arms fails, the runner prints a diff between that file and the report. Before any eval, the runner checks the golden files of the suites it runs, the `%txt` files bound to a face containing `expected`: each must end in exactly one newline, which an arm can't see in the file's wain, and hold no line that starts `BAD ` or ends `: BAD`. `--update` won't write a report that breaks either rule.

The `jibb-dev` desk holds `my-app`'s sources under `/my-app`, without its desk files, so the suites below that check `my-app` files read them there, and a golden case that uses one links to it: `tests/golden/doc-overview-02-theme/source.jibb` is a symlink to `my-app/ui/theme.jibb`.

`tools/test-arms --list` lists every suite, and [The test suites](docs/development.md#the-test-suites) in the development guide says what each one checks. Each suite it lists runs under eval and on the fake ship, with the same fixtures. The `jibb-import` suite compares the partial Hoon importer's fixture projections against their golden file. The suites `jibb-bridge`, `jibb-import-overlap`, `jibb-import-structural`, `jibb-union-source`, `jibb-union-alias-overlap`, `jibb-full-overlap-basic`, `jibb-full-overlap-graph`, `jibb-generic-recursion`, `jibb-generic-construction`, `jibb-generic-pattern`, `jibb-deferred`, `jibb-deferred-prepared`, `jibb-deferred-resolver`, `jibb-deferred-context`, `jibb-empty`, `jibb-cell-branch`, `jibb-tlon-bridge`, `jibb-mark-bridge`, `jibb-poke-bridge` and `jibb-api-paths` check importer/checker, prelude and partial API path analysis boundaries.

`tests/lib/jibb-page-main.hoon` fully checks the byte-identical static about page and direct blog/todo data pages through the real readers, with exact main types, downstream imports and fail-closed syntax/evidence controls. It does not render pages or execute requests.

`tests/lib/jibb-buttons.hoon` fully checks the documented `labelled` and `wide` definitions and the unchanged module's exact source-located unresolved-`%add` error through detailed and legacy inference, with the valid source, schemes and error fixtures in `tests/type-buttons/`. It does not render or execute UI.

`tests/lib/jibb-doc-examples.hoon` fully checks the import-only example with real Hoon readers and the card module, the `view-day` and `step` modules, and the `cmd`/`sub` molds at their prelude path through detailed and legacy inference.

`tests/lib/jibb-theme.hoon` fully checks the byte-identical real theme against the exact prelude mold, including its exported type, structural downstream import, dark absent/present forms and malformed-field negatives. It does not check contrast, render themes or route fonts.

`tests/lib/jibb-store.hoon` checks the byte-identical cart store and basket through detailed and legacy inference, exact main and derived schemes, structural imports, direct store watch evidence and rejection controls. It does not lower or execute stores, support multi-action declarations, or permit store requests in page loads.

`tests/lib/jibb-program-main.hoon` checks the narrow closed, subscription-free `main` slice. `tests/lib/jibb-program-init.hoon` checks transactional initializer recovery for a synthetic direct program, including exact exported and imported types and rejection boundaries. `tests/lib/jibb-program-update.hoon` checks derived result context for an unannotated two-slot update, including a union/boolean branch, downstream types and fail-closed controls. `tests/lib/jibb-program-watch.hoon` uses the real todo readers with synthetic program components to check one direct request value against merged API-source evidence and reject hand-built, indirect, parameterized, diff and ambiguous subscriptions. These are static checks only: they do not run an island or establish runtime watching. `tests/lib/jibb-todo-full.hoon` additionally checks the byte-identical todo island through both full-module APIs, verifies its exact closed `main` type and structural downstream import, and runs rejection controls.

## Licence

Jibb is under the MIT licence, in [LICENSE](LICENSE). Two kinds of files in it are other people's, under their own MIT licences: the files in `vendor/` are copies from urbit/urbit, whose licence is in [vendor/LICENSE-urbit.txt](vendor/LICENSE-urbit.txt), and the Tlon `/sur` files that `tests/` uses as importer fixtures come from tloncorp/tlon-apps, whose licence is in [tests/importer/tlon-license.txt](tests/importer/tlon-license.txt).

## Fake ship

For an application directory, `jibb dev DIRECTORY --pill brass.pill` performs the whole initial setup and leaves the fake ship running. Run `jibb dev DIRECTORY` after later source changes.

`tools/ship` runs the desks on a fake `~zod` at `/root/urbit/zod` (`--pier` or `$JIBB_PIER`). It needs Python 3 and click (`/root/src/tools/pkg/click/click`, or `--click`). The ship runs in the background, logging to `/root/urbit/zod.log`.

```
tools/ship dev . --pill brass.pill  # the same complete workflow for the current app
tools/ship start                # start an existing pier and wait until it's live
tools/ship status               # running or not; desks, revisions, mounts
tools/ship log                  # the end of its log
tools/ship stop
```

`tools/ship assemble --out <dir> [<desk> ...]` writes the desks' files to `<dir>/<desk>` as sync assembles them, without a ship; `nix build` uses it. `tools/ship sync <desk>` assembles a desk from the repo's folders, creates it if it's missing (as `|new-desk` does), mounts it, deletes from the desk through Clay the files the repo doesn't have, makes the mount hold exactly the repo's files, runs `|commit` and waits until the desk matches the repo, checking every file. If Clay rejects the commit, it prints Clay's error, which the log doesn't show.

| Desk | Assembled from |
| --- | --- |
| `my-app` | `vendor/*`, then `jibb-dev` without `tests/`, then `my-app` |
| `jibb` | `vendor/*`, then `jibb-dev` without `tests/`, then `jibb` |
| `jibb-host-fixture` | `vendor/*`, then `jibb-dev` without `tests/`, then `tests/host-fixture/desk` |
| `jibb-dev` | `vendor/*`, then `jibb-dev`, then `tests/`, with `tests/lib/jibb.hoon` generated, and `jibb/sys.kelvin` |

The `jibb-dev` desk runs the golden cases on the ship, as `-test` arms. `tools/ship gen-tests` writes `tests/lib/jibb.hoon` from `tests/golden`: for each case it imports `source.jibb`, `tokens.txt` and `tree.txt` with `/*`, reading a `source.jibb` that links to a `my-app` file from `/my-app`, and its `test-` arm compares `golden:jibb` with them. Cases opted into `types.txt` also compare the full-checker report; cases opted into `core.txt` also compare canonical lowered Core. The file is generated, not committed (review question 32): desk assembly writes it afresh, and `.gitignore` lists it. `tools/ship test` regenerates it, syncs the desk and runs `-test /=jibb-dev=/tests`, printing each case's OK, FAILED or CRASHED and the reason. It exits 0 only when every case passes.

```
tools/ship test                                   # the library and tests/golden
tools/ship test --stub --golden tools/testdata/ship-golden
tools/ship test --lib some/other/jibb.hoon
```

A sync with nothing to commit takes about 2 s. A commit adds 3 to 10 s, and 300 cases (900 files) sync in about 10 s. `-test` takes 1 to 3 s with the stub library. `--stub` swaps in `tools/testdata/ship-stub.hoon`, and `tools/testdata/ship-selftest` checks the generator and the runner against it with the cases in `tools/testdata/ship-golden`. Runs with `--stub`, `--lib`, or a custom `--golden` include only the generated golden test program: the repository's other test programs run with the default library and corpus. A subsequent default `tools/ship test` restores them.

`tools/ship check-commit` proves that `|commit` stores `.jibb` files. It syncs `my-app`, reads every `/ui` file back with `%cx`, byte for byte, and converts `%jibb` to `%mime` and `%txt` and back. It commits half-written files, then deletes them. It merges a file that two desks changed on different lines, and checks that changes to the same line conflict. It can be rerun, and it leaves the two scratch desks it merges with (`%jibb-check-ours` and `%jibb-check-theirs`) holding only what `|new-desk` gives, unmounted.

`tools/clay-fixtures` syncs `my-app` and `jibb-fixtures`, builds their example `/sur` files and marks through Clay, and checks selected types read from the compiled graphs and passed to the partial checker. It compares the results with golden files under `tests/clay-fixtures/`.

For anything else:

```
tools/ship scry /cx/=my-app=/ui/about/jibb --raw     # a file's bytes
tools/ship scry /ct/=jibb=/ --type '(list path)'
tools/ship hoon '(add 2 2)'                          # as dojo, with our, now, eny
tools/ship run thread.hoon                           # a strand
tools/ship poke hood kiln-commit '[%my-app |]'
tools/ship commit|mount|unmount <desk>
```

What the ship does that you might not expect:

- `|merge` with kiln's default strategy, `%auto`, stops at "auto merge failed on strategy %fine" whenever a fast-forward isn't possible: kiln moves on to `%meet` only on a `%bad-fine-merge` error, and this Clay reports `%merge-failed`. Pass `=gem %mate`.
- `%txt` keeps no final newline: vere's `+to-wain` jet ends the last line there, where the Hoon in zuse gives an empty line after it. So a `.jibb` file that a three-way merge changes, which goes through `%txt` (`grad %txt`, as `%hoon` does), loses its final newline. Likewise the ship can't tell a golden `tokens.txt` or `tree.txt` that lacks its final newline; `tools/golden` and `tools/ship test` catch it.
- `|commit` deletes from the desk only the files vere has seen in the mount since the ship started: the ones it wrote there and the ones an earlier `|commit` found. So after a restart, a file deleted from the mount before the next `|commit` stays on the desk. That is why `tools/ship sync` deletes such files through Clay, with a `%info` task.
- conn.sock closes the connection as soon as it has written a reply, so a reply bigger than the socket buffer, about 200 KB, is cut off. `tools/ship` keeps its replies small and reads big files in parts.
