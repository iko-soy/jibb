# Probes for the milestone 2 review

The Jibb sources the [milestone 2 review](../2026-11-03-milestone-2-review.md) ran through the full module checker, `infer-jibb-file-detailed`, at `f84a29e`, with what the checker printed then. They are evidence for the review and a ready regression corpus for [finishing milestone 2](../../prompts/milestone-2-finish.md). No check runs them: they are not tests, and several outputs record what is wrong today.

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
