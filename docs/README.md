# Docs

Jibb's spec is a design doc by @iko, [Jibb — an Elm-architecture UI language for Urbit](https://claude.ai/artifact/DMBr48qzi5z8hcwn2ccPBv), and its repository copy in `spec/`. The repository copy records decisions made on 2026-10-30, including dropping `$?`, adding `%$` as a term literal and pattern, making `@` an unrestricted atom, treating `?` as two atoms for union disjointness, and the milestone 2 type and prelude decisions; the Claude document still needs to be synchronized. This folder also holds where the build stands, what is still open, and how to work on the code.

| File | What it holds |
| --- | --- |
| [spec/](spec/) | The doc's tabs, as Markdown |
| [status.md](status.md) | The eight milestones, what milestone 1 built, and how to check it |
| [open-questions.md](open-questions.md) | Questions still open: the plan's, the grammar's, and those milestone 2 raises |
| [development.md](development.md) | Setting up a machine, the ground rules, the checks to run before pushing |
| [compiler.md](compiler.md) | A map of `jibb-dev/lib/jibb.hoon`: its API, data, errors and printed formats |
| [prelude-inventory.md](prelude-inventory.md) | Working source audit for the prelude's exported inventory |
| [prompts/milestone-2.md](prompts/milestone-2.md) | A brief for the developer who builds milestone 2, types and prelude |
| [prompts/drop-union-rune.md](prompts/drop-union-rune.md) | The completed brief for dropping `$?`, as decided on 2026-10-30, before milestone 2 |

## The spec

`spec/` began as a snapshot of the doc taken on 2026-10-30, after @iko's answers to the 12 grammar questions that day. It has since been edited to record decisions including dropping `$?`, local type-variable scope, cells and changes, record faces, and the noun type `*`; the Claude document still needs those edits. It also has the doc's rules of the same day for gates generic over auras. Each file corresponds to one tab:

| File | Tab |
| --- | --- |
| [spec/overview.md](spec/overview.md) | Jibb — an Elm-architecture UI language for Urbit: the language, the stages, the mark, the host, worked examples |
| [spec/grammar.md](spec/grammar.md) | Grammar: lexical rules, literals, runes, imports, modules, molds, tag resolution, patterns, the EBNF |
| [spec/core-language.md](spec/core-language.md) | Core language: the untyped language between the checker and both backends |
| [spec/decisions.md](spec/decisions.md) | Decisions: every choice, with the date it was made |
| [spec/implementation-plan.md](spec/implementation-plan.md) | Implementation plan: the eight milestones, ground rules, architecture, risks, open questions |

The doc has a sixth tab, "Loom on Urbit", which is empty, so it has no file.

The overview's pipeline diagram, "Jibb pipeline · source to browser in three stages", is embedded content, so the export holds only a placeholder line for it under Architecture. The doc shows it.

The two copies can diverge. Sync the repository decisions to the Claude document before refreshing this copy, then export each tab as Markdown again (in a Claude session, the Claude Docs connector's `export` gives each tab's Markdown), replace the files, and run:

```
git diff docs/spec          # what changed in the doc
tools/doc-blocks docs/spec  # every code block labelled jibb has its golden case
```

A `jibb` block that changed or is new needs its golden case, `tests/golden/doc-<tab>-<n>-<what>/`, where `<n>` counts every code block of the tab, labelled or not ([development.md](development.md)).
