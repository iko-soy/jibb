# Finish the 2026-11-02 syntax review's changes

A brief for the developer who finishes what the [2026-11-02 syntax review](../reviews/2026-11-02-syntax-review.md) started. Paste it as the first message of a session, or hand it to a person; it assumes a fresh start in the repo `iko-soy/jibb`. Written 2026-11-03, when S1, S2, S4 to S7, S11 to S13 and S15 landed on `master`.

---

You are finishing a set of syntax changes to Jibb, a UI language for Urbit: a Hoon dialect with an indentation layout. Its spec is in `docs/spec/`; the parser, checker and printer are `jibb-dev/lib/jibb.hoon`; the prelude is `jibb-dev/lib/jibb/prelude.jibb`. On 2026-11-03 Montelot decided ten of the review's fifteen proposals, and they were built the same day, each on its own branch with its own golden cases, then merged. What is left is the gaps those builds reported, four adversarial reviews that didn't finish, and work that waits on the new checker core.

## What landed

Each proposal is a section of the review, numbered S1 to S15, and a row of `docs/spec/decisions.md` dated 2026-11-03.

| # | What it does now | Where to look |
| --- | --- | --- |
| S1 | `(unface e)` removes every face from `e`'s type, through cells, a gate's sample and product, containers' arguments and the unit's payload; unions and recursive molds go by name and are kept whole. It is reserved with `proj`, is not a value, and `++ f (unface \|= …)` is still a gate | grammar.md "Unface", `+itype-unface`, `+reserved-name`, `inline-unface-*` |
| S1 step 1 | Decided, not built: a capital that meets a faced position binds only the type under the face | decisions.md Inference row, `inline-unface-labelled-slot` |
| S2 | A body's final line hands the lines after it at its depth to a tall `\|=`, `^-` or `~&` that ends it; a `?-` that begins a body's final line may take its arms at its own depth | grammar.md "The rest of a body", `lex-body-rest-*` |
| S4 | A bare decimal is a `@ud`: it fits `@u`, `@` and `*`, and no other aura, unless its `++` is generic over its aura | grammar.md Literals, `inline-decimal-*` |
| S5 | A bare pattern name is an error where a case the pattern can match has a tag there that the name spells | grammar.md Patterns, `inline-pattern-tag-name-*` |
| S6 | A change's item may name a wing through record fields, `m(open.cart=x)`; overlapping items are an error | grammar.md Expressions, `inline-change-wing`, `types-change-*` |
| S7 | Type variables may be words, `Msg`, `T2`, and print by their written names; `program` is `\|$ [Data Model Msg]` | grammar.md Type variables and Printed types, `lex-typevar-*`, `types-typevar-*` |
| S11, S12, S15 | Spec wording for deeper lines and nested patterns; the examples build their models with faced cells | grammar.md Lexical rules and Patterns |
| S13 | A cast whose expression takes the deeper lines ends its owner line; the prelude, my-app and the spec's examples use the canonical layout, with flat `?-` arms | grammar.md Spacing, prelude.jibb |

## Read first

1. `docs/README.md` and `docs/development.md`: the ground rules, the checks, and how golden cases work.
2. The review's sections for S1, S2, S4, S5, S6, S7 and S12, and decisions.md's rows dated 2026-11-03.
3. `docs/status.md`, the rows that name S1 to S7: each says what is partial.

Then run `tools/check`. Everything should pass before you change anything.

## Ground rules

- **The spec wins**, and a language question is Montelot's to decide, as the 2026-11-03 rows were. Where this brief would decide more of the language, it says so, and you ask instead.
- **Another thread is building the checker core** that review question 5 asks for: union-find with levels, deferred constraints and a usefulness check for `?-`. It will replace `+itype-unify`, branch joins, `?-` exhaustiveness and pattern binding. Don't patch those for S1 step 1 or face joins; that thread owns them. Ask in the project chat what has landed before you touch the checker.
- **Every change is a golden case or a test arm**, and every check passes, the ship group included (`nix flake check` runs it on a fresh fake ship, or see `docs/development.md`).
- **Push straight to `master`**, rebased, in commits that each leave every check passing.
- **Keep docs current**: the status.md row for each capability, decisions.md when something is settled.

## Step 1: finish the adversarial reviews

The reviews of S2, S4, S6 and S7 didn't finish before the merge. For each, try to break it: probe edge cases the golden cases don't cover, check that the spec says exactly what the code does, and check every golden output the change touched. Fix what you find, with a golden case for each fix. The probe recipe is at the end of the review.

Known already:

- **S2.** A body of 40,000 same-depth `~& x` lines runs out of memory under eval, where 40,000 nested parentheses don't: each rest is a level of recursion in the parser. Make the rest loop iterative, if that stays small. Some new ok cases have no `types.txt` because the partial checker can't type them (`lex-body-rest-ok-3`, `-5` and `-6`).
- **S4.** Number patterns are checked against the subject only on known-union and atom subjects. The unit, list, loobean, single-case and deferred `?-` paths don't check them, so `[~ 0]` against a `(unit @dr)` falls through to older messages. A constructor applied directly, `(|=%wait 30)`, and a call whose head is still a variable keep the generic "call's sample and argument types do not unify".
- **S6.** A wing through a union field's site note reads just "field `data`", with no type. The inference-level "repeated change fields" check is now unreachable from the module entry points, because the duplicate pass reports overlaps first; keep it as a safety net or remove it.
- **S7.** A few messages still say "capital", as "use the same capital for a shared type". Names live in the bits of a variable's ID (`+named-var`, `+var-name`), so any test that compares a prelude scheme's IDs exactly must use the named IDs.

## Step 2: close S1's and S5's gaps

- `unface` on an argument whose type isn't known yet, as `|= f (unface f)` or `|=(g (unface g))` passed where the call fixes `g`, says "not supported by partial inference". The spec says it waits, as wing access does. Make it wait when the deferred path can, and fail closed otherwise. The check also looks only at the top of the type: a faced variable passes and a bare one is refused.
- Islands, pages and stores that find `init`, `update`, `load` or `view` by a literal `|=` (around the program, page and store recognisers) don't see through `unface`. `++ update (unface |= …)` should be a gate there, as it is for recursion (`+unfaced-gate`).
- Golden cases for `unface` over a set, a map and a jug, which the code handles but no case shows. `inline-unface-unknown`'s about.txt cites the wrong spec sentence. `(unface)` gets a different error in a `++` body and as a call argument; make it one.
- S5's exemption for a union's generic arguments works by type equality, so a concretely typed position whose type happens to equal an argument is skipped. Make it follow where the mold puts the type variable. The full module check reports an S5 error only as "module definitions need unsupported inference"; give it the partial report's message and sites.

## Step 3: after the checker core lands

These wait on the core from review question 5. Coordinate with that thread first.

1. **S1 step 1** is the core's job, with a golden case each for `(hunt lt-a `1 `2)`, `(roll ~[1 2] 0 add-f)` and `[A A]` against `[x=@ y=@]`. The same thread makes joins keep a face once a position has taken one, so `~[lt-u lt-a lt-c]` and `~[lt-a lt-u lt-c]` are errors alike (today the first checks and the second doesn't). Update `inline-unface-labelled-slot` and `inline-unface-lambda` when it lands.
2. **The prelude's `args=` gates.** Thirty prelude gates take an unfaced `args=[…]` and open a one-arm `?-` to name its parts, only so that they fit slots with any labels. With step 1, write them with labelled samples, `++ weld |= [xs=(list A) ys=(list A)] ^- (list A)`. Use `(unface |=(…))` only for small gates mostly passed as values, as `lth`, `gte` and `lte`. Each rewrite must keep the gate's type report.
3. **S12, later part.** Flatten the eight prelude gates that nest a `?-` inside another's arm to look at two values (`both`, `clap`, `hunt`, `mate`, `clef`, `join`, `snip`, `rear`) into nested cell patterns, as the review shows for `hunt`. The partial checker says "branch is not supported" for those today, so wait until the core types nested patterns.

## Step 4: lowering, at milestone 3

When the lowering to the core language is built, `(unface e)` lowers to `e`, a `++` whose body is `(unface |= …)` joins its group's `rec` as a gate, and a wing item in a change lowers to an edit at the wing's axis (core-language.md says how).

## Questions to ask, not decide

Put these to Montelot in the project chat, each with a recommendation, and record the answers in decisions.md:

1. **What faces does a cast's result keep?** `^- $-([@ud @ud] ?) lt-a` drops the gate's labels today (the fall-through at the end of `+itype-merge-faces`), while `^- [@t @ud] r` keeps a record's. The critique recommends that a cast never removes faces, so `unface` is the one place labels go.
2. **May a flat arm's bare-name pattern hide a prelude name?** With flat arms, Hoon's habit of writing `?:`'s else branch back at the rune's column, as `dec a`, parses as a catch-all arm binding `dec`. Today "pattern binder shadows a name" catches it. If S3 ever lands, it wouldn't.
3. **Is a `|=` or `~&` that ends a body's final line written flat or with a deeper body by the formatter?** The prelude keeps deeper bodies for `flit` and `bond`.
4. **When named type variables merge, which name prints?** Today a capital written in the `++` wins, otherwise the one made first, so `(cork fk fv)` prints `cork`'s `A`, not `fk`'s `Key`.

The review's other proposals (S3, S8, S9, S10 and S14) weren't decided. Leave them unless Montelot asks.
