# Docs

Jibb's spec is a design doc by @iko, [Jibb — an Elm-architecture UI language for Urbit](https://claude.ai/artifact/DMBr48qzi5z8hcwn2ccPBv), and its repository copy in `spec/`. The repository copy records decisions made on 2026-10-30, including dropping `$?`, adding `%$` as a term literal and pattern, making `@` an unrestricted atom, treating `?` as two atoms for union disjointness, and the milestone 2 type and prelude decisions; the Claude document still needs to be synchronized. This folder also holds where the build stands, what is still open, and how to work on the code.

The current full-module checker also has a narrow static/data-page slice, documented in [compiler.md](compiler.md) and [status.md](status.md). Its shared eval/ship fixture checks the real about, blog index and todo index sources without claiming rendering or request execution. The shared theme fixture likewise full-checks the byte-identical real theme and its exact type without implementing theme behavior.

| File | What it holds |
| --- | --- |
| [spec/](spec/) | The doc's tabs, as Markdown, with decisions the doc doesn't have yet; until the doc is synced, this copy is the spec |
| [status.md](status.md) | The eight milestones, what Jibb does now with the test that proves each part, and the known gaps |
| [open-questions.md](open-questions.md) | Questions still open: the plan's, the grammar's, and those milestone 2 raises |
| [development.md](development.md) | Setting up a machine, the ground rules, the checks to run before pushing |
| [compiler.md](compiler.md) | A map of `jibb-dev/lib/jibb.hoon`: its API, data, errors and printed formats |
| [prelude-inventory.md](prelude-inventory.md) | Working source audit for the prelude's exported inventory |
| [prompts/milestone-2.md](prompts/milestone-2.md) | A brief for the developer who builds milestone 2, types and prelude |
| [prompts/drop-union-rune.md](prompts/drop-union-rune.md) | The completed brief for dropping `$?`, as decided on 2026-10-30, before milestone 2 |
| [reviews/2026-11-02-repo-review.md](reviews/2026-11-02-repo-review.md) | A review of the whole repository on 2026-11-02: bugs, gaps and simplifications, each checked by a second reviewer |
| [reviews/2026-11-02-questions.md](reviews/2026-11-02-questions.md) | The 45 decisions that review raises, with options and recommendations |
| [reviews/2026-11-02-syntax-review.md](reviews/2026-11-02-syntax-review.md) | A review of Jibb's syntax on 2026-11-02: 15 verified proposals with before and after examples, what to keep, and questions for @iko |
| [reviews/2026-11-03-milestone-2-review.md](reviews/2026-11-03-milestone-2-review.md) | A review of milestone 2 against the plan on 2026-11-03: the done-criteria, the errors the spec describes, findings M1 to M17, with its [probes](reviews/2026-11-03-milestone-2-probes/) |
| [prompts/milestone-2-finish.md](prompts/milestone-2-finish.md) | A brief for finishing milestone 2: the general checker core, diagnostics, patterns, kinds, imports, tests and docs that the milestone 2 review found missing |

## The spec

`spec/` began as a snapshot of the doc taken on 2026-10-30, after @iko's answers to the 12 grammar questions that day. It has since been edited to record decisions including dropping `$?`, local type-variable scope, cells and changes, record faces, and the noun type `*`; the Claude document still needs those edits. It also has the doc's rules of the same day for gates generic over auras. Each file corresponds to one tab:

| File | Tab |
| --- | --- |
| [spec/overview.md](spec/overview.md) | Jibb — an Elm-architecture UI language for Urbit: the language, the stages, the mark, the host, worked examples |
| [spec/grammar.md](spec/grammar.md) | Grammar: lexical rules, literals, runes, imports, modules, molds, tag resolution, patterns, the EBNF |
| [spec/core-language.md](spec/core-language.md) | Core language: the untyped language between the checker and both backends |
| [spec/decisions.md](spec/decisions.md) | Decisions: every choice, with the date it was made and whether the doc has it yet, and the settled milestone 2 questions |
| [spec/implementation-plan.md](spec/implementation-plan.md) | Implementation plan: the eight milestones, ground rules, architecture, risks, open questions |

The doc has a sixth tab, "Loom on Urbit", which is empty, so it has no file.

The overview's pipeline diagram, "Jibb pipeline · source to browser in three stages", is embedded content, so the export holds only a placeholder line for it under Architecture. The doc shows it.

The two copies can diverge, and until they are synced, this copy wins (review question 42). Sync the repository decisions to the Claude document before refreshing this copy: the rows that decisions.md's Synced column marks No or Check, and its settled milestone 2 questions. Then export each tab as Markdown again (in a Claude session, the Claude Docs connector's `export` gives each tab's Markdown), replace the files, and run:

```
git diff docs/spec          # what changed in the doc
tools/doc-blocks docs/spec  # every code block labelled jibb has its golden case
```

A `jibb` block that changed or is new needs its golden case, `tests/golden/doc-<tab>-<n>-<what>/`, where `<n>` counts every code block of the tab, labelled or not ([development.md](development.md)).
