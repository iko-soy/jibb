# Finishing milestone 2

A brief for the developer who finishes milestone 2 of Jibb, types and prelude. Paste it as the first message of a session, or hand it to a person; it assumes the repo `iko-soy/jibb`. Written 2026-11-03, at commit `f84a29e`, from the [milestone 2 review](../reviews/2026-11-03-milestone-2-review.md) of the same day. That review was still running in seven of its nine areas when this was written; where a section below depends on them it says so, and both files will be updated when they finish.

---

You are finishing milestone 2 of Jibb, a UI language for Urbit: a Hoon dialect with an indentation layout, whose compiler is a Hoon library, `jibb-dev/lib/jibb.hoon`. Milestone 1 built the layout pass and the parser. Milestone 2 has built a large partial type checker, a Hoon type importer and most of the prelude; every check passes, under `urbit eval` and on a fake ship, and the doc's 14 `jibb` blocks check as written. What is missing is a checker that is general rather than fitted to those examples, and that tells the user what is wrong.

## Read first

1. [docs/reviews/2026-11-03-milestone-2-review.md](../reviews/2026-11-03-milestone-2-review.md): the verdict, findings M1 to M17, and the table of the 33 errors the spec describes. This brief is its to-do list.
2. [docs/prompts/milestone-2.md](milestone-2.md): the original brief. Its "What the doc asks of the checker", "Suggested design" and "Tests" sections still hold, and this brief doesn't repeat them.
3. [docs/spec/implementation-plan.md](../spec/implementation-plan.md), milestone 2, and the spec tabs it points at, closely Grammar's Tag resolution, Literals by context, Patterns, Modules and Imports.
4. [docs/reviews/2026-11-02-questions.md](../reviews/2026-11-02-questions.md): the owner's answers, marked *(chosen)*. Q5 and Q6 set the direction below. Q16 to Q28 are proposals waiting for @iko, not spec.
5. [docs/development.md](../development.md): setting up (`nix develop`), the tools, the test suites, and the checks before pushing (`tools/check` or `nix flake check`).
6. `git log origin/master`: @iko works in `jibb.hoon` in parallel, and another thread is implementing syntax-review proposals S1, S2, S4 to S7, S11 to S13 and S15 ([syntax review](../reviews/2026-11-02-syntax-review.md)). Rebase often and keep your changes out of theirs where you can. The thread that fixes the 2026-11-02 review's findings planned this same core on 2026-11-03, in stages that keep every check green; ask in the project chat who is building it before you start step 2.

## Ground rules

The original brief's rules hold: the spec wins, language questions go to @iko and are recorded in Decisions first, no built-ins, everything is a golden test that passes under eval and on the fake ship, push straight to `master` in commits that each leave every check passing, and keep `docs/` current. Two more:

- **Fail closed, but say why.** A program the checker can't yet handle must be rejected, never accepted, and its message must name the construct and its site. "module definitions need unsupported inference: <path>: ++ x" is not an acceptable message for an error the spec describes.
- **Delete what the core replaces.** When the general core covers a recovery path or a "source-proven" slice, delete the slice and keep its tests. The milestone is done when the slices are gone, not when they are joined by a core.

## What is left

In order. Steps 1 and 2 can start at once; the rest build on step 2.

### 1. Keep the diagnostics the checker already finds (M1, M12, M17)

The full checker, `infer-jibb-file-detailed`, drops every per-definition reason in `add-supported-result` (`jibb.hoon` 10670-10689), so almost every error reaches the user as the generic message. The partial report already computes most of them. Thread a diagnostic, an `idiag` with its sites, through `add-supported-defs-core` for each unresolved definition, mold and kind check, and render the first in dependency order where the generic text is built today (14820-14857). Keep the generic text only for real checker limits, and make those name the construct. Make `module-scope-valid` return the shadowed name and both sites, with its own wording for `proj`. This plumbing carries over to the core of step 2.

### 2. The general checker core (Q5)

The owner chose this on 2026-11-02: union-find bindings with levels, a queue of deferred constraints, and a usefulness check for matches, built before more recovery paths. It is a long piece of work, so first write its design as a new section of the library's design notes, and share it in the project chat for @iko before replacing code.

- **Unification**: union-find over type variables, with levels for generalization instead of environment scans; an occurs check; aura variables and the "is an atom" and "contains no gates" constraints carried on the variable, as `0858191` already does for gate-freedom.
- **Deferred constraints**: tags, `~`, numbers and cells, wing access, changes and `?-` on a type not yet known each wait in one queue, retried as variables are bound, as the Grammar's Tag resolution says. A tag-constrained variable does not generalize and stays open until something in the module fixes it. At the end of the module, each still-open constraint is an error at its source: "nothing fixes the union of %add; add a `^-`".
- **Order**: infer `++`s by the strongly connected components `839f6b0` already computes, a group of mutually recursive gates together; reject a non-gate value that depends on itself, naming the cycle.
- **Kinds by type**: check `main` as an ordinary expression. `(program init update view subs)`, `(page load view)` and `(store init update)` are calls whose unification fixes their components' types, messages included, so a tag in `view` is resolved by `main`. Then read the kind from `main`'s type, as the Grammar says, and run each kind's own checks after inference: gate-free island data and models, naming the field; for islands, a walk of the `(list (sub M))` that asks for a watchability proof only for `%watch`; for pages, a load that is any gate to `(ask D)`, `pure` and typed paths included.
- **Rulings it must build in**, chosen by Montelot on 2026-11-03 from the syntax review: a capital that meets a faced position binds only the type under the face, never the face, so `[A A]` fits `[x=@ y=@]`, `(hunt lt-a `1 `2)` checks, and `(roll ~[1 2] 0 add-f)` checks with `++ add-f |= [a=@ud b=@ud] (add a b)`; a join keeps a face once a position takes one, so reordering a list's items never changes whether it checks; and, as the syntax thread lands them, the explicit `unface` (S1), bare decimals fitting only `@ud`, `@u`, `@` and `*` (S4), and a bare-name pattern that spells a union tag being an error (S5). Take their final wording from `decisions.md`, and add each ruling's examples as golden cases in the stage that builds it.
- **Then delete** the program, page and store recovery chain, the deferred transactions, the prepared-tuple route and the other example-shaped slices as the core covers their tests (the earlier review counts about 1,180 lines of program recovery alone).

When this is done, M2 to M5 are gone: every valid variant in the review's [probe corpus](../reviews/2026-11-03-milestone-2-probes/) checks, and each error in an island is reported where it is, as `button "Add" %submitt` giving "msg has no case `%submitt`" at the tag, with the union's site.

### 3. Patterns by a usefulness check (M10)

Replace the per-case coverage loops with Maranget's usefulness check over nouns: constants and cells, a loobean as its two constants, lists and units as their unions, nested patterns, literal patterns, `*` and bare names. It gives the missing-case error with a witness, at the `?-` and its subject, and the dead-arm error naming the arm that covers it, for the Grammar's `[%move * *]` example too. Keep the matrix reusable: milestone 3 lowers `?-` with it.

### 4. One types pipeline (Q6, M14, M15)

Render `types.txt` from the full checker: each definition's type, the module's kind, or the error with its excerpts. Retire the partial report, or make it a view of the full result. Give every `doc-*` case a `types.txt`, with the buttons error for `doc-grammar-02-buttons`.

### 5. Every error the spec describes (done-criterion 2)

Work down the review's [error table](../reviews/2026-11-03-milestone-2-review.md#appendix-the-errors-the-spec-describes) until every row says Met: a golden case with the spec's message, from the full checker, naming both conflicting sites with excerpts. The rows with no message anywhere today: a capital made `@ud` or a list, `~[text "hi"]` with its suggestion, `(facts …)` outside an API's `paths`, a gate in island data or a model with the field named, `[]`, a generic aura in `{…}` or a path's `(…)`, an imported vase or repeated record face, and a repeated attribute in a literal list, which today is accepted (M9).

### 6. Kinds, APIs and the prelude in general (M4, M7, M9)

- Pages: the overview's route-parameter page, `(post.api slug same)`, and its catch-all page, `(pure p)`, check.
- Islands: `|=(m ~)` for no subscriptions, several watches, `%every`, and a watch with a fold, `(changes.todo |=%got apply)`, check.
- Stores: a `poke` with several cases checks.
- APIs: an API other than the todo one checks as a module, with typed segments, several parameters, `scry=` paths and folds; `(facts …)` outside `paths` is an error.
- `element` can't be built by hand: `^- (element !!) [%island 5]` is rejected, so island data is always checked against `init`.
- The prelude: every name in the overview's Prelude and Layout tables is usable with its signature, or listed as deliberately left out. `max` is missing today, so the Grammar's `clamp` example fails. The inventory and its gaps are still being reviewed.
- The inline Grammar examples in M7 check: `|=(p title.p)`, `"{(add 1 2)}"`, path and unit literals, and every row of the Patterns table.

### 7. The Hoon import table (done-criterion 3)

A test `/sur` file with `$%`, `$@`, a map and a recursive mold, imported, printed in Jibb's notation and used from a Jibb module through the full checker, under eval and on the ship. Each row of the overview's import table works or gives the table's error where used. Known gaps from the earlier review: only `%tas` head tags (`%&`, `%|`, `%0` and `(each a b)` fail, A50) and no bare `@` or `@uw` (A14). The review's import area is still running and will add to this list.

### 8. Tests (M6, M8, M16)

- A ship check of the `my-app` desk as the original brief asks: build each `/sur` and mark through Clay, run the full checker over every `/ui/**.jibb` in dependency order, expect exactly one failure, `buttons.jibb` at 3:16, and record the time in `status.md`.
- Turn the spec-valid negatives (two `each` sites, a mapper alias, a page alias, an indirect or `pure` load, a store alias, a hand-built main) into positive cases. Fix `tests/type-page-main/hand-built-load.txt`, which doesn't parse. Make every negative assert its message and place, not only "rejected".
- Turn the review's [probe corpus](../reviews/2026-11-03-milestone-2-probes/) into a regression suite: its about 90 valid one-edit variants of the doc modules check, and its wrong variants and error probes fail with their own error at their own site.
- Guard the copies: the Core language block as a slice of `todo-list.jibb`, and `tests/type-buttons/valid.txt` as the buttons block without `add-button`.

### 9. Speed

The original brief asks that "a 2,000-line module should check in seconds, not minutes". Measure the full check of generated modules, written bottom-up and top-down, and of the `my-app` desk, with `tools/hoon --no-debug`, and record the numbers in `status.md`. The review's speed area is still running and will add its measurements here.

### 10. Docs

`status.md` becomes the capability table that Q41 asked for, then shows milestone 2 done with counts and timings. `compiler.md` and the library's header stop saying milestone 1, and describe the core. `open-questions.md` lists what is still open, and `decisions.md` records any new decision.

## Out of scope

As in the original brief: lowering and the backends (milestone 3), routes, static files, the theme's contrast check and the host (milestone 4), `load`'s per-request behaviour (milestone 5), the JavaScript runtime (milestone 6) and the formatter (milestone 7). Also the syntax-review changes another thread is making.

## When you're done

- The plan's three "Done when" items hold, but for the route check: the doc's examples and the review's valid variants check; every row of the error table is Met; the `/sur` import test passes.
- Every check passes, under eval and on the ship (`nix flake check`), and the `my-app` desk checks on the ship with its types read through Clay.
- The recovery paths and slices the core replaced are deleted.
- `docs/status.md` shows milestone 2 done, with counts and timings, and the other docs describe the checker as it is.
- Everything is pushed to `master`, and a few lines go to @iko in the project chat: what changed, the counts and timings, the decisions needed, and what is still open.
