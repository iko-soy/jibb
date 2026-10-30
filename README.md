# Jibb

Jibb is a UI language for Urbit: a Hoon dialect with an indentation layout. Its design doc is the spec, and where this code and the doc disagree, the doc wins.

## Layout

- `jibb-dev/`: what app desks vendor: the `%jibb` mark (`mar/jibb.hoon`) and the compiler (`lib/jibb.hoon`, one Hoon core without Ford runes); later the prelude and browser library.
- `jibb/`: the `%jibb` desk, for the shared host (milestone 4).
- `my-app/`: an example app desk built from the doc's worked examples.
- `vendor/`: pinned copies of the base-dev and landscape files the desks need.
- `tests/`: golden cases in `golden/<case>/`, and on-ship tests for the `-test` thread in `lib/jibb.hoon`.
- `tools/`: dev tooling: `golden`, `hoon` and `doc-blocks`, with their self-test in `testdata/`, and `ship`.

## Golden tests

Each case, `tests/golden/<case>/`, holds `source.jibb`, `about.txt` (where it comes from, what it tests, the expected outcome), and the expected outputs: `tokens.txt` from the layout pass and `tree.txt` from the parser. A file holds the output plus one trailing newline.

Run them without a ship. This needs `urbit` on PATH and Python 3.

```
tools/golden                      # every case: PASS or FAIL, a diff per failure, a summary
tools/golden --case 'grammar-*'   # only the cases matching a glob
tools/golden --show --case foo    # print the outputs, don't compare
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

`tools/testdata/selftest` tests both tools against a stub library, and `tools/doc-blocks` against Markdown it writes.

### The doc's examples

Every code block the design doc labels `jibb` is a golden case, `doc-<tab>-<n>-<what>`, where `<n>` counts the tab's code blocks, labelled or not. To check that none is missing or stale, export the doc's tabs as Markdown and pass the files, or a folder of them:

```
tools/doc-blocks Grammar.md Overview.md Core-language.md
```

It matches each labelled block to the case whose `source.jibb` is the block's text plus a newline, and lists the blocks no case holds, each with a diff against the closest unmatched case, and the `doc-*` cases no block holds. Pass every tab with Jibb blocks, or the other tabs' cases count as stale. The exit status is 0 when every block has a case and every case a block, 1 when one doesn't, and 2 when the check can't run, for example because no block is labelled `jibb`.

## Fake ship

`tools/ship` runs the desks on a fake `~zod` at `/root/urbit/zod` (`--pier` or `$JIBB_PIER`). It needs Python 3 and click (`/root/src/tools/pkg/click/click`, or `--click`). The ship runs in the background, logging to `/root/urbit/zod.log`.

```
tools/ship start                # start it and wait until it's live
tools/ship status               # running or not; desks, revisions, mounts
tools/ship log                  # the end of its log
tools/ship stop
```

`tools/ship sync <desk>` assembles a desk from the repo's folders, creates it if it's missing (as `|new-desk` does), mounts it, makes the mount hold exactly those files, runs `|commit` and waits until the desk matches the repo, checking every file. If Clay rejects the commit, it prints Clay's error, which the log doesn't show.

| Desk | Assembled from |
| --- | --- |
| `my-app` | `vendor/*`, then `jibb-dev` without `tests/`, then `my-app` |
| `jibb` | `vendor/*`, then `jibb` |
| `jibb-dev` | `vendor/*`, then `jibb-dev`, then `tests/`, with `tests/lib/jibb.hoon` generated, and `jibb/sys.kelvin` |

The `jibb-dev` desk runs the golden cases on the ship, as `-test` arms. `tools/ship gen-tests` writes `tests/lib/jibb.hoon` from `tests/golden`: for each case it imports `source.jibb`, `tokens.txt` and `tree.txt` with `/*`, and its `test-` arm compares `golden:jibb` with them. Don't edit that file; `--check` says whether it's up to date. `tools/ship test` regenerates it, syncs the desk and runs `-test /=jibb-dev=/tests`, printing each case's OK, FAILED or CRASHED and the reason. It exits 0 only when every case passes.

```
tools/ship test                                   # the library and tests/golden
tools/ship test --stub --golden tools/testdata/ship-golden
tools/ship test --lib some/other/jibb.hoon
```

A sync with nothing to commit takes about 2 s. A commit adds 3 to 10 s, and 300 cases (900 files) sync in about 10 s. `-test` takes 1 to 3 s with the stub library. `--stub` swaps in `tools/testdata/ship-stub.hoon`, and `tools/testdata/ship-selftest` checks the generator and the runner against it with the cases in `tools/testdata/ship-golden`.

`tools/ship check-commit` proves that `|commit` stores `.jibb` files. It syncs `my-app`, reads every `/ui` file back with `%cx`, byte for byte, and converts `%jibb` to `%mime` and `%txt` and back. It commits half-written files, then deletes them. It merges a file that two desks changed on different lines, and checks that changes to the same line conflict. It can be rerun, and it leaves the two scratch desks it merges with (`%jibb-check-ours` and `%jibb-check-theirs`) holding only what `|new-desk` gives, unmounted.

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
- conn.sock closes the connection as soon as it has written a reply, so a reply bigger than the socket buffer, about 200 KB, is cut off. `tools/ship` keeps its replies small and reads big files in parts.
