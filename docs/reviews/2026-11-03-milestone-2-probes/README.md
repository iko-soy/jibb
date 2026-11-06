# Probes for the milestone 2 review

The Jibb sources the [milestone 2 review](../2026-11-03-milestone-2-review.md) ran through the full module checker, `infer-jibb-file-detailed`, at `f84a29e`, with what the checker printed then. They are evidence for the review and a regression corpus for [finishing milestone 2](../../prompts/milestone-2-finish.md). Several saved outputs record what was wrong then, not expected results.

`tools/probe-regression` runs all 317 Jibb sections and the import probe's 21 module checks and 10 raw reader checks as a strict regression, with `--backend eval` (the default) or `--backend ship` on a running fake ship. Name groups to run just those, as `tools/probe-regression p2 errors-p1 imports`; `-j 3` runs three eval groups at a time. It requires every valid case to check and checks each invalid case's reason, source sites and excerpts against [the annotated expectations](../../../tests/type-probe/diagnostics.txt), or an exact message for the fixed-message cases. Unsupported valid cases and generic or misplaced errors fail; they are not counted as passes. The Core-language fragment is checked inside the todo island. The `p6` hand-built-load section has been repaired to parse; its saved review output predates that correction. Its typed-load positive now passes `same` so the reply matches the view’s record sample; the original `%one`/record mismatch is retained as the `typed-mismatch` negative in `jibb-page-main`. The `p5` explicit casts inside calls now use the required rune parentheses; these still test a valid null-list comparison and a rejected specialization of a written capital. In `p2`, the unused helper mold was renamed from `flag` to `switch-flag` after `flag` was added to the prelude; its saved output also predates this correction. The original spelling remains a separate prelude-shadowing negative in `jibb-prelude-flag-shadow`. The `drop-each` variant now casts its unused `row-of` result so its `%toggled` constructor has a union context; the original is retained as an unresolved-tag negative in `jibb-todo-full`. The import probe's generated [ship suite](../../../tests/probes/jibb-probe-import.hoon) is checked against its review source before running. Both strict backends are enrolled in `tools/check`. Remaining failures keep the repository check red until the full corpus passes.

The diagnostic annotations distinguish the conflicting expressions from their declarations. A call points to its callee and argument and prints both types; a cast points to its mold and expression. A missing match case points to `?-` and its subject, as the finishing brief requires. A missing union tag points to the union's declaration and the offending tag. When the message type is unresolved, this is the checked container's declaration; the checker does not guess a nearby local message mold. A capital error points to the capital itself and the expression forcing its type; interpolation points to its expression and printing context. These sites retain two excerpts without requiring an unrelated occurrence of the same type name. The face-mismatch probes require both complete incompatible layouts in the message.

Two original error probes stop in parsing: `T3-hole-path` uses a typed segment in an expression path, whose grammar permits only knots, and `X3-pt-faced-cases` writes fields without a record opener. Their annotations require the unexpected `[` or `=` and the parser's explanation. The original source is preserved; a separate full-check mold-path regression uses the typed-segment syntax.

Each `.jibb` file holds sections, each starting with a line `#### <label>`; each section is checked as a module on its own. A `.out` file is the output of its `.jibb`: per section, `CHECKED` and the exported molds and values with their types, or `REJECTED:` and the message.

| Files | What they hold | Run with |
| --- | --- | --- |
| `variants/p1.jibb` to `p10.jibb` | The `my-app` modules and the doc blocks as written (`p1`), then about 90 spec-valid one-edit variants of them (`p2` to `p8`: reordered, renamed, extra helpers, a second watch, `\|=(m ~)` subscriptions, aliases, typed and `pure` loads) and wrong variants that must fail with their own error (`p9`, `p10`, labels starting `BAD-`). A label is the module's path, then a name | `run app` |
| `errors/p1.jibb` to `p5.jibb` | One or more probes for each error the spec describes, labelled as in the review's error table (`E01` an aura mismatch, `S2` the Grammar's `[%move * *]`, `C1` `%submitt` in an island, `W1` to `W4` island initializers) | `run plain` |
| `errors/import-check.hoon` | Invalid Hoon imports (`I1` to `I9`), module-graph errors (`M1` to `M5`) and the raw reader results | `run imports` |

`variants/p1.jibb` has no saved output; every section in it checks, except `buttons`, which fails with "nothing fixes the union of %add".

From the repo root, with `urbit` on `PATH` (`nix develop`):

```
docs/reviews/2026-11-03-milestone-2-probes/run app   docs/reviews/2026-11-03-milestone-2-probes/variants/p9.jibb
docs/reviews/2026-11-03-milestone-2-probes/run plain docs/reviews/2026-11-03-milestone-2-probes/errors/p1.jibb
docs/reviews/2026-11-03-milestone-2-probes/run imports
```

`run plain` checks each section as `/ui/probe/jibb` against the real prelude (`check.hoon`). `run app` checks each section at the path its label names, with `my-app`'s todo and blog `/sur` files and marks compiled by `ride` (marks without their `/-` lines, as the `tests/lib` suites do) and a bundle of `api/todo`, `todo-list`, `api/blog`, `card` and `cart`, the section's own path left out (`app-check.hoon`). A label of the form `<path> module <name>` adds that section to the bundle instead. Each run takes 30 to 80 s, most of it building the libraries.
