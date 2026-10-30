# Development

How to work on Jibb: the rules the plan sets, how to set up a machine, and what to run before pushing. The repo's [README](../README.md) describes each tool in full.

## Ground rules

From the plan's Setup and ground rules, and from @iko:

- **The doc wins.** Where code and doc disagree, the doc stands until it changes. [spec/](spec/) is a snapshot; the doc itself is the authority.
- **Language changes are agreed first** and recorded in the Decisions tab, before the code changes.
- **Questions go to @iko**, as comments on the doc, on the words they're about. While one is open, follow the most likely reading, mark it "(doc question)" in the library's notes, and list it in [open-questions.md](open-questions.md). Where an error points is not a doc question: the library's section 2.0 settles it.
- **Every Jibb code block in the doc is a golden test**, and each stage's output is printed and compared. The doc labels its Jibb blocks `jibb`; `tools/doc-blocks` checks that each has its case.
- **Each milestone ends with its checks passing on a fake ship**, not only under `urbit eval`.
- **Push straight to `master`.** @iko reviews work in the project's chat, not in pull requests, so there are none. Run the checks below first.
- **Keep docs/ current**: [status.md](status.md) when a milestone moves, [open-questions.md](open-questions.md) when a question is settled or found.

## Setting up a machine

The tools need Python 3 and `urbit` (vere) on `PATH`; the ship tools also need a fake `~zod` and click. Everything so far ran with vere 4.6 on Linux.

On a usual machine:

1. Install vere as [docs.urbit.org](https://docs.urbit.org) says, and get a brass pill.
2. Boot a fake ship where `tools/ship` expects it, or point `--pier` or `$JIBB_PIER` elsewhere. Booting takes a few minutes:
   ```
   mkdir -p /root/urbit && cd /root/urbit
   urbit -F zod -B brass.pill -t -x -c zod
   ```
3. Get click, the command-line client for a ship's `conn.sock`, from [urbit/tools](https://github.com/urbit/tools), at `/root/src/tools/pkg/click/click` or wherever `--click` or `$JIBB_CLICK` says.
4. Optionally, clone [urbit/urbit](https://github.com/urbit/urbit) to read Arvo's source. `vendor/SOURCES.txt` names the commit the vendored files come from.

In a Claude cloud container, the network blocks urbit.org, bootstrap.urbit.org, nixos.org's installer and GitHub's release downloads. This worked on 2026-10-29, and has to be redone in each new container:

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
| `tools/golden` | Runs the golden cases under `urbit eval`: every case, or those matching `--case`; `--update` rewrites the expected outputs; `--show` prints them |
| `tools/importer-test` | Compares the partial Hoon importer's diagnostic trees and errors with `tests/importer/tree.txt` under `urbit eval` |
| `tools/type-import-test` | Composes the Hoon importer with the partial checker and compares `tests/type-import/expected.txt` under eval |
| `tools/clay-fixtures` | Syncs `my-app` and checks that its example `/sur` files and marks build through Clay on the fake ship |
| `tools/hoon` | Evaluates Hoon with the library in scope, as `tools/hoon '(golden /a/b/jibb (crip "++ main view"))'`; `--cord name=file` binds a file's text, `-f` reads the expression from a file |
| `tools/doc-blocks` | Checks the doc's `jibb` blocks against the `doc-*` golden cases: `tools/doc-blocks docs/spec` |
| `tools/ship` | Runs the fake ship: `start`, `stop`, `status`, `log`, `sync <desk>`, `test`, `gen-tests`, `check-commit`, `scry`, `hoon`, `run`, `poke`, `commit`, `mount`, `unmount` |
| `tools/testdata/selftest` | Tests `tools/golden` and `tools/hoon` against a stub library, and `tools/doc-blocks` against Markdown it writes |
| `tools/testdata/ship-selftest` | Tests `tools/ship`'s test generator and runner against a stub library on the ship |

`tools/golden` starts `urbit eval` once and builds the library, which takes about 8 s, then runs every case under `mule`, so a crash fails only its own case.

## Before pushing

```
tools/golden                       # all cases pass
tools/importer-test                # Hoon importer fixture projections match
tools/type-import-test             # importer/checker bridge golden report matches
tools/hoon check-spans-test        # prints <<>>
tools/testdata/selftest            # 19 checks, 0 failed
tools/doc-blocks docs/spec         # every jibb block has its case
tools/ship gen-tests --check       # tests/lib/jibb.hoon is up to date
tools/ship test                    # the cases pass as -test arms on the ship
tools/testdata/ship-selftest       # when tools/ship changed
tools/ship check-commit            # when the mark or the desks changed
tools/clay-fixtures                # when the my-app Hoon fixtures changed
```

`tools/ship test` regenerates `tests/lib/jibb.hoon` and syncs the `jibb-dev` desk before it runs, so commit the regenerated file. A run with `--stub`, `--lib`, or a custom `--golden` isolates its generated golden tests from the repository's other test programs; run the default command afterward to restore and test those programs. It also runs the independent `tests/lib/jibb-import.hoon` test against the same importer fixtures and expected diagnostic projection as `tools/importer-test`. The projection is an internal tree, not the Jibb type printer. `tests/lib/jibb-bridge.hoon` also runs the importer/checker bridge fixture on the ship; `tools/type-import-test` runs the same report under eval.

## Golden cases

A case is a folder `tests/golden/<name>/` holding:

- `source.jibb`, the input, ending in one newline;
- `about.txt`: a `source:` line with the doc's words or block it comes from, a `tests:` line saying what it exercises, and an `expect:` line, either `parses` or `error at <line>:<col>` and why (one case, `inline-leftout-signed-float-auras`, says `unclear`: see grammar question 13 in [open-questions.md](open-questions.md));
- the expected outputs, `tokens.txt` and `tree.txt`, each the output plus one newline.
- optionally, `path.txt`, the logical `/ui/.../*.jibb` path to pass to the compiler; the source remains `source.jibb`.
- optionally, an `expect-types:` line in `about.txt` opts the case into `+golden-types`; `types.txt` holds its output plus one newline and `--update` creates it. A `types.txt` also opts in when the line is absent. This interface is provisional while the checker is under construction.
- optionally, `imports.txt` selects Hoon `/sur` molds, one `module mold` pair per line. Each module's source goes in `sur/<module>.txt` and is compiled against zuse by both runners. The selected reader results go to the partial checker; a type output is required. This currently handles only sources without Ford imports, not marks or Jibb module fixtures.

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
