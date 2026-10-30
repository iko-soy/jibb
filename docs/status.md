# Status

As of 2026-10-30. The plan is [spec/implementation-plan.md](spec/implementation-plan.md); each milestone ends with its checks passing on a fake ship.

| # | Milestone | Status |
| --- | --- | --- |
| 1 | Parser and mark | Done (7c739b7; the doc's grammar decisions of 2026-10-30 in ab797a9) |
| 2 | Types and prelude | In progress. [prompts/milestone-2.md](prompts/milestone-2.md) briefs the developer; the checker and importer are partial |
| 3 | Core language | Not started |
| 4 | Host and static pages: the first release | Not started |
| 5 | Published pages | Not started |
| 6 | Islands | Not started |
| 7 | Tooling | Not started |
| 8 | Polish | Not started |

The plan sets no dates: "agree them after milestone 1, once it shows how fast the Hoon work goes". They haven't been agreed yet. Milestone 1's commits run from 2026-10-29 18:13 UTC to 2026-10-30 11:50 UTC.

On 2026-10-30, @iko decided that Jibb drops `$?`, so a `+$` takes a union's cases on the lines below its name. [prompts/drop-union-rune.md](prompts/drop-union-rune.md) records the change before milestone 2. The repository spec records the decision; the Claude document still needs to be synchronized.

## Milestone 2: in progress

The repository spec records the subsequent type-system and prelude decisions; those changes also need synchronization to the Claude document. An initial inference fragment and a standalone Hoon type reader are being tested. The fragment explicitly reports that it does not check a module; a partial bridge passes selected Hoon atoms and unfaced cells into inference, while the reader and bridge do not cover every supported Hoon type. It reads named recursion, several collections, jar and jug in record fields, and direct `$^` unions whose cases can be proved disjoint. Nested `$^`, nested collection arguments, ordered maps, marks and general union disjointness remain unfinished. Collection recognition checks the originating core and fails closed on local shadows or unresolved Ford subjects; its golden fixtures include three real Tlon files. The prelude currently has only a few functions, and [prelude-inventory.md](prelude-inventory.md) is a source audit, not the complete inventory or signatures. The milestone remains unfinished.

## Milestone 1: parser and mark

What the plan asks for, and where it is:

| The plan | Where |
| --- | --- |
| The `%jibb` mark as the first tab gives it | `jibb-dev/mar/jibb.hoon`, as the doc writes it |
| The layout pass, emitting INDENT, DEDENT and NEWLINE | `+layout` in `jibb-dev/lib/jibb.hoon`, designed in its section 2 |
| A parser for the Grammar tab's EBNF that returns a syntax tree with source positions | `+parse` and `+parse-tokens`, section 3. Every node has a span, its start and end, and `+check-spans` tests the spans of every tree the golden tests print |
| Errors with file, line, column and an excerpt | `+show-error`, section 4.3. Each error points at the first character where the text stops being the start of any valid module (section 2.0) |
| Done when every Jibb code block in the doc parses | The doc labels its 14 Jibb blocks `jibb`. Each is a golden case, `tests/golden/doc-*`, and `tools/doc-blocks docs/spec` checks that they match. All parse; the one block written as an error, the Grammar's buttons example, has a type error for milestone 2 |
| Done when each lexical rule has a test input that breaks it | The `lex-*` golden cases: for each lexical rule, inputs that break it (`-bad-`), each with the error's expected place, and inputs that keep it (`-ok-`), except for the forms Jibb leaves out (the closers, blob and `@c` literals) |
| Done when `\|commit` stores `.jibb` files on a fake ship | `tools/ship check-commit`: 7 checks, from reading every file back byte for byte to three-way merges |

Besides the plan's list:

- 393 golden cases: 177 that parse and 216 that fail, each failure at a stated line and column. One failing case has an unclear expectation (corpus question 3). The newer type-output cases exercise only the partial inference fragment. Each case's `about.txt` quotes the doc's words it tests.
- The 393-case corpus passed under `urbit eval` in 20.0 s. The fake ship passed all 396 tests, including the importer, importer/checker bridge and unification checks, with 18.9 s for sync and 8.9 s for tests. The importer golden compares 35 projections; `tools/clay-fixtures` also built all seven example Hoon fixtures through Clay.
- `tools/testdata/selftest` (19 checks) and `tools/testdata/ship-selftest` test the tools themselves.
- Two independent audits before 7c739b7, one of which compared the library with a reference parser written in Python from the doc over about 19,000 generated programs. Before ab797a9, a second Python parser, written from the decisions, agreed with the library on 8,000 generated programs and 900 hand-written probes.
- Speed: starting `urbit eval` and building the library takes about 8 s. After that, a 2,000-line module of 400 definitions parses in about a second. Loops over definitions, arms, lines and items grow no stack; nesting costs a few stack frames a level, and 100,000 nested brackets still parse (library section 3).

### History

| Commit | Date | What |
| --- | --- | --- |
| 1cb51df | 2026-10-29 | Foundation: the parser's design, the tools, the desks, the vendored base-dev and landscape files, the golden corpus |
| 15a5545 | 2026-10-29 | The layout pass |
| 3c5f50a | 2026-10-29 | The parser |
| 7c739b7 | 2026-10-30 | Fixes from two independent audits; milestone 1 done |
| 5a4aa73 | 2026-10-30 | `tools/doc-blocks`, after the doc labelled its Jibb blocks |
| ab797a9 | 2026-10-30 | The 12 grammar decisions of 2026-10-30: four changed the parser, eight confirmed it |
| aad6ddb | 2026-10-30 | Drop `$?`; `+$` takes union cases below its name |
| 1dd92a6 | 2026-10-30 | Begin type inference and Hoon imports |
| This change | 2026-10-30 | Extend partial inference and importer, record type and prelude decisions |

## Checking it

On a machine set up as [development.md](development.md) says:

```
tools/golden                      # 393 cases under urbit eval
tools/importer-test               # the Hoon importer fixture projection
tools/type-import-test            # the importer/checker bridge fixture
tools/hoon check-spans-test       # prints <<>> when the span checker works
tools/testdata/selftest           # the tools themselves
tools/doc-blocks docs/spec        # the doc's examples are golden cases
tools/ship start
tools/ship gen-tests --check      # tests/lib/jibb.hoon is up to date
tools/ship test                   # the same 393 cases as -test arms on the ship
tools/testdata/ship-selftest
tools/ship check-commit           # |commit stores .jibb files
tools/clay-fixtures               # example /sur files and marks build through Clay
```

## What milestone 1 leaves to later milestones

- Errors carry a start only. Spans keep each node's end so that milestone 2's type errors can underline both conflicting sites with excerpts (library section 1).
- The parser accepts forms for the checker to judge: `[]`, `[a]`, `m()`, `!! a`, and the module kinds. `[]` and `m()` have since been decided to be errors, and `[a]` is `a`; the parser has not changed. The Grammar's buttons example parses, though the doc marks it as a type error.
- Grammar questions the doc's author hasn't been asked follow the readings in [open-questions.md](open-questions.md).
