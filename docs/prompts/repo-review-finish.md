# Finishing the 2026-11-02 repository review

A brief for the developer who finishes what the [2026-11-02 repository review](../reviews/2026-11-02-repo-review.md) started. Paste it as the first message of a session, or hand it to a person; it assumes the repo `iko-soy/jibb`. Written 2026-11-03, at commit `e208bcb`, by the thread that fixed the review's findings, from a check of every question and finding against `master` that day.

---

You are finishing the follow-up to a review of the whole Jibb repository. Jibb is a UI language for Urbit, a Hoon dialect with an indentation layout; its compiler is a Hoon library, `jibb-dev/lib/jibb.hoon`, with a Hoon type importer in `jibb-dev/lib/jibb-import.hoon`. The review, at commit `4bf477e`, found 137 problems (A1 to A137) and raised 45 questions, which Montelot, the project's owner, answered: each answer is marked *(chosen)* in [the questions](../reviews/2026-11-02-questions.md). Most answers have landed. What is left is small fixes, simplifications and docs that no other brief covers, twelve language rulings and one more question (A62) that wait for @iko, and the review's advice for the checker core, which milestone-2-finish.md builds.

Three briefs share the remaining work. Don't do one brief's work under another:

- **[milestone-2-finish.md](milestone-2-finish.md)** owns the general checker core (review question 5), the diagnostics the full checker still drops (its step 1), the usefulness check for `?-`, one types pipeline (question 6), kinds, APIs, the import table, tests and speed. Its import table step lists two known gaps from this review, A14 and A50; they are fixed here, in step 1 and under question 26.
- **[syntax-review-follow-up.md](syntax-review-follow-up.md)** owns the syntax changes S1 to S15, including `unface` and the gaps in S2, S4 to S7.
- **This brief** owns the rest of the repository review: the open findings below, the rulings for @iko, and the review's input to the core.

## What landed

| Questions | What | Commits |
| --- | --- | --- |
| 1 to 4 | The review on `master`, fixes as commits straight to `master`, a fake ship in cloud containers | `c7cd17d`, `f583172` |
| 7 to 15 and the eight "fix first" bugs | Ordinary inference before recovery, the narrow initializer recovery deleted, imported `(unit T)` as the prelude's unit, `ask` and `qath` printed without `.internal`, one branch-join rule, dependency-order resolution, kept diagnostics, no 26-variable gate, a fresh-ID high-water mark, lexer, `tools/ship` and `tools/golden` fixes | `a211c34`, `38c711c` and `ec7c6d4` (@iko), `93d6b23`, `839f6b0`, `f0411ad`, `ce69a3b`, `447a592`, `2b9666c`, `96d1784`, `c0a0b85`, `941c486`, `452f64c`, `68d9b76` |
| 25 | `eq` and the gate-free constraint | `0858191` (@iko) |
| 29 to 35 | `tools/test-arms` instead of 52 scripts, `tools/check`, `my-app` read on the test desk, the generated `tests/lib/jibb.hoon` no longer committed, importer fixtures in their suite, a `jibb-fixtures` desk, span and Hoon-reference checks as test arms | `d74b5e2`, `0a86d7c`, `8125287`, `ba67080`, `933bc83`, `d43c99b`, `32f4b78` |
| 30 (CI) | A GitHub Actions job ran the eval checks; Montelot had it removed on 2026-11-03. There is no CI; don't add one back without asking | `84b8527`, `f84a29e` |
| 36, 37, 39, 43 | Decided to keep things as they are | `bf65f8f` |
| 40 to 42, 44, 45 | `tools/hoon --no-debug`, `status.md` as a capability table, the repository spec wins until synced, `open-questions.md` only open questions, the MIT licence | `cdf53c8`, `e97aebe`, `7bc7d54`, `116178b` |

## Read first

1. [The review](../reviews/2026-11-02-repo-review.md): its summary, and the appendix rows for the findings below. Its line numbers are pinned to `4bf477e` and have drifted; find code by arm name.
2. [The questions](../reviews/2026-11-02-questions.md), and in [open-questions.md](../open-questions.md) the section "Review rulings waiting for @iko".
3. The two other briefs, so you know what they own.
4. [The checker map](../reviews/2026-11-03-checker-map.md), before you touch the type checker: what each family of arms does, which tests pin it, the 22 recovery slices, the five copies of definition finalization, and 22 hazards for anyone changing the checker.
5. [development.md](../development.md): setting up (`nix develop`), the tools, the test suites, and the checks to run before pushing (`tools/check`, or `nix flake check`).
6. `git log origin/master`. @iko and other threads work in `jibb.hoon` in parallel; rebase often.

Then run `tools/check`. Every check should pass before you change anything.

## Ground rules

- **Push straight to `master`**, rebased on `origin/master`, in commits that each leave every check passing, the ship group included. Never force-push. Before a change to `tools/ship`, the desks or the `%jibb` mark, run the ship checks on a fake ship.
- **Every fix is a golden case or a test arm.** A finding that changes behaviour gets a case that fails before the fix.
- **Don't decide the language.** Questions 16 to 24 and 26 to 28 are Montelot's proposals, and each waits for @iko to confirm it before it goes in `decisions.md` and the code changes. Ask @iko in the project chat; don't build them on the proposal alone.
- **Don't patch what the core replaces.** The findings listed at the end of step 6 are fixed by building the core, not by repairing the old code. Before you change `+itype-unify`, `+itype-fit`, branch joins, `?-` coverage, the program, page and store recovery, or the `dg-*` transaction, ask in the project chat who is building the core and what has landed.
- **Keep docs current.** `status.md` is a table of capabilities: change the row a fix affects, don't add history. `compiler.md` follows the code.

## Step 1: fixes that don't wait for anything

A19 and the inhabitation half of A13 touch `+itype-fit-inner` and `+itype-inhabited-proof`, which the core replaces, so follow the ground rule: ask in the project chat first, and leave them to the core if it has replaced that code. A13's `+gate-free-type` half and A14's bridge are code the core keeps (the checker map, 4.2), so they don't wait.

Checker and importer:

- **A19.** `+width-scan` counts each faced entry on a spine, so a flat faced tuple has more entries than a record whose last field is a faced nested record. The flat tuple is then refused, as unknown by the `too-wide` guard in `+itype-fit-inner`, and as "record width constraint needs unsupported inference" by `+width-shape` in the cast and call checks. When the target's last field is a faced cell, match the source against it structurally instead of by count, and check the `lth` guards in `+width-proj-shape` and `+width-infer-literal` with the same case.
- **A13.** `+itype-inhabited-proof` and `+gate-free-type` know only the list and unit collections. Treat set, map, qeu, mop, jar and jug as inhabited by `~`, and check gate-freedom over all their arguments. Add a union match on a case that holds an imported map.
- **A14.** One whitelist of auras, `?(%u %ud %ux %uv %t %ta %tas %p %da %dr)`, is copied in `+rec-pattern`, `+import-to-itype-standard` and the API parameter check, and rejects bare `@` and other unsigned auras. Write one predicate for `@` and every unsigned, non-float aura and use it at all three; teach `+rec-pattern` `*` and `?` fields. Add bridge cases. Milestone-2-finish step 7 lists this gap for its import test; fix it here, and that test then covers it.
- **A56.** The importer's `+overlap-source-witness` proves a definite overlap only for a top-level `$?` of tagged cells. Accept `$%` bodies and `?(...)` leaves, so duplicate `$%` tags and `?(%a %a)` give the definite overlap, with cases in `tests/importer/tree.txt`.
- **A43.** Without a prelude the partial report says a bare "module has a reserved proj or unface name", with no "partial inference; module not checked" header, while the prepared path says "module has conflicting names". Give both paths one message under the header: the prepared path's, or, if milestone-2-finish step 1 has given `proj` its own wording by then, that wording. `inline-unface-reserved-no-prelude` already covers the no-prelude branch for a mold named `unface`; add a case for `++ proj 1`, and update that case's output.
- **A22.** The comment on the noun fit says a bare tag is "fixed as a constant", but the code binds it to the expected type. Fix the comment.

Lexer and parser:

- **A4.** `+read-string` calls `+doomed` for "the `}` of an interpolation", a case that never happens. Delete the call, fall through to `+bad`, and drop the clause from the notes and `+doomed`'s comment.
- **A5.** In the lexer's glyph dispatch, the second-character messages ("`|` begins `|=`…", "`^` begins `^-`") win over the 2.2 character errors, so a tab or control character after a glyph gets the wrong message, and only some left-out runes get the doc's reason. Run `+bad-char` first and give every left-out rune of the doc's kinds its reason. The syntax review's S9 (undecided) would rewrite nearby messages; keep to the review's fix.
- **A3, what is left.** About a dozen lexer hints have no golden case, among them "this `}` closes no `{`", "`|` begins …", "`^` begins `^-`", a comment inside `{…}`, interpolation outside a string, a wing's `.`, the `@u` and `@t` literal errors, the date bounds, "Jibb writes no such literal" and "Jibb can't read this literal". Several parser hints have none either, as "`+` begins `++` or `+$`", "patterns take no units: write [~ x]", "`?` alone is the loobean mold" and "the wide gate's body is one operand". Add a `lex-*-bad-*` case for each lexical one and an `inline-*` case for each parser one.

## Step 2: tools and tests

- **A68.** `tools/golden` splices `jibb-import.hoon` into the "(harness)" segment, so its compile errors and crash frames are blamed on the harness. Add the reader as its own segment, so spots map to `jibb-import.hoon` lines.
- **A69.** `tools/ship test`, `sync` and `gen-tests` accept a `--golden` folder that doesn't exist and pass with no tests. Fail when the folder is missing or a named folder has no cases, as `tools/golden` does.
- **A70, A84.** `tools/testdata/ship-selftest` hard-codes 45 `tests/lib` names, which miss 14 of the 58 suites, and dozens of fixture names in the checks after them. Replace them with one check: every file under `tests/` except `golden/` and `clay-fixtures/desk/` is in `assemble('jibb-dev')`, and so is the generated `tests/lib/jibb.hoon`. Keep the `--lib` and `--golden` isolation checks. That list is the last place a new suite must be registered by hand, so this also closes A84.
- **A74.** An `about.txt` that isn't UTF-8 crashes `tools/golden` and `tools/ship gen-tests` with a traceback, because `wants_types` in `tools/golden_case.py` is called outside the `except ValueError` handlers. Have it raise a `ValueError` that names the file, as `source_path` does, and move its calls inside the handlers: in `Case.__init__` in `tools/golden`, and in `generate_tests`' per-case loop and types-helper test in `tools/ship`. Both then exit 2 with a report.
- **A75.** `tools/golden` fills the harness's `{…}` placeholders after splicing in the cases' sources, the reader and the preludes, so any of them that contains a placeholder is rewritten. Substitute every placeholder in one pass.
- **A76.** The ship's plain `+check-types` isn't under `mule`, unlike `+check-import-types` and its other siblings, so a crash in it shows only as CRASHED, without the case's tokens and tree results or the label its siblings give. Wrap it. The eval and ship runners also keep separate copies of their Hoon helpers and their walk over a case's metadata; share them.
- **A72, A77, A73, A79.** Smaller tool copies: `tools/golden` renders the two preludes twice and repeats its read-to-`rap` code three times; `tools/ship` keeps its own `KNOT`/`TERM`, noun decoding and cord escaping beside `golden_case.py`, `noun.py` and `urbit_eval.py`; `delete_batches` keeps an empty-list case only a selftest uses; `tools/ship`'s `find_urbit` ignores `$URBIT`.
- **A71.** `check_fixture_crash_isolated` in `tools/testdata/selftest` runs the real compiler and pins checker output, though the file says the selftest runs against the stub. Give it a stub fixture, or say so.
- **Test-only code in the shipped library (A93, A127).** Move `+itype-unify-test` and `+check-spans-test` from `jibb.hoon` into the `jibb-typecheck` and `jibb-check-spans` suites, and have `test-unification` return the unifier's failures as its tang, so the one-line `tests/checker/unification.txt` can go (A85).
- **A86.** 38 suites repeat a lines-to-cord helper. Put one in a shared test library bound with `/+`.
- **A87, A88.** `development.md`'s golden naming table lists only `lex-`, `inline-` and `doc-`; add `types-`, `module-`, `prelude-`, `parser-` and `fixture-`, fix the ten `about.txt` files that lack a required line, and have `tools/golden` or the selftest reject them. Say in the suites section which `tests/type-*` folder belongs to which suite, or rename the folders after their suites.
- **A89.** The importer's fixtures are bound one by one in `tests/lib/jibb-import.hoon`; bind them as one list and derive the report and the missing-file checks from it. `tools/clay-fixtures` prints hand-written counts, "7 passed" and "4 projections passed"; compute them from the expected files.
- **A90, A102.** Nothing tests the claims that 100,000 nested brackets and a 20,000-line module parse. Add a suite or selftest step that generates them; milestone-2-finish step 9 then records the timings. Then re-measure design note 3's figures with `tools/hoon --no-debug` and say which mode they use: its "8 s" for starting urbit and building the library is now about 27 s.
- **A114.** The Clay fixture `tests/clay-fixtures/desk/sur/import-fixture.hoon` writes `$^(@ud [a=@ud b=@t])`, which accepts only atom-headed cells. Write the intended `$@(@ud [a=@ud b=@t])` and update the `ford-nested-union` expected files.
- **A111, A117.** `tools/ship`'s `DESKS` skips a `jibb-dev/tests` folder that doesn't exist, for `my-app` and `jibb-fixtures`; drop the skip and the README's "without tests/", and make the README's desk table match `DESKS`: add the `jibb-fixtures` row, and on `jibb-dev` name `my-app` under `/my-app` and the skipped `tests/clay-fixtures/desk`. Make `tools/ship assemble` fail when `my-app/sys.kelvin` and `jibb/sys.kelvin` differ.
- **A118.** `vendor/SOURCES.txt` records the machine-local path `/root/src/urbit` it was copied from, and credits the docket files to urbit/urbit's legacy `pkg/landscape`. Drop the local path, and say where the docket files are maintained now.
- **A110.** The Clay fixtures build `my-app`'s marks only as Hoon cores. Add a `%cb` build and a `vale` of one sample noun for each, with milestone-2-finish step 8's `my-app` ship check if that lands first.

## Step 3: simplifications in code the core keeps

Most are in the parser, the importer, and the module and API code, which the core keeps. A few are dead lines in checker arms that the core replaces, as the fuel of `+itype-closed-sample-match` and the last unify of `+itype-closed-gates-match`; deleting them changes nothing, so they don't wait for the core. Each must leave every golden output unchanged.

- **Dead code (A26, A31, A42, A44, A130, A18, part of A45).** Delete `+width-has-projections`, `+infer-width-elaboration` and its type `+$ iwidth-elaboration`, `+direct-find-gate`, `+resolve-supported-defs`, the newly dead `+import-to-itypes`, `+one-request-interface-source` and `+golden-types-with-modules` (and its sentence in `compiler.md`), and the orphan comments above unrelated arms. Drop the narrow API branch, `+one-request-interface-graph`, so every API with `+$ paths` goes through `+multi-request-interface-graph`, after checking that `blog.jibb`'s interface and the `type-api` outputs don't change. Remove the never-decremented fuel of `+itype-closed-sample-match`, the always-true unify at the end of `+itype-closed-gates-match`, `+width-scan`'s unused `sub`, and two dead lines in `+find-imported-mold-prelude`. Of A45, fix only what is outside the recovery and `dg-*` arms: the double negation and the `?~ index` branch in the module driver, and the fake `ifile`s in the store code.
- **The `?(` check (A7).** `+hoon-union` walks back over tokens at twelve call sites to report a tight `?(`. Have the lexer's `?` branch report it, with the same column and message, and delete `+hoon-union`.
- **Names that shadow the standard library (A8).** Rename `+in`, move the `+fail*` helpers into `+parser` so `file` is in scope, and delete the `file` forwarders and the sixteen `in:..zuse` workarounds. Then drop the Code conventions bullet in `development.md` that says `+in` and `+fail` shadow the standard library, and move the `+fail*` helpers from the `%parser-helpers` row of `compiler.md`'s chapter table to the `%parser` row.
- **Copies in the parser (A9).** The path-segment loops of `+read-pathlit`, `+read-qath` and `+read-pathmold`, the open-mold-line loops, and the item and line name branches are near copies. Merge them where the result is clearly simpler; the review found some merges are not.
- **`%gate` and `%gate-wide` (A34, A123).** The two nodes carry the same fields, and 39 lines in the checker chapters test both or repeat an identical body for each (A34). Make one `%gate` node with a `wide=?` flag that only the printers read. That merges the checker's copies too and changes note 3's tree forms, but no golden output. Ask first if the core is being built; if its builder wants the old node kept for now, use `?(%gate %gate-wide)` in the parser, the printers and the syntax walkers only, and leave A34 to the core.
- **Syntax walkers (A32, A129).** The `scope-*`, `dependency-*`, `duplicate-*`, `*-has-hole` and reserved-name walker families each repeat the per-node dispatch. Add one enumeration of an expression's children and a fold, and rewrite these families on it. The type walkers (A21, A35) wait for the core.
- **API and module copies (A27, A29, A31).** `+request-graph-merge` should reuse `+request-graph-inputs-match` and `+request-graph-bounded`, drop its fuel arguments, and make the bound agree with its comment. `+prepare-prelude` and `+prepare-prelude-with-internal`, and `+module-mold-types` and its `-detail` form, should each share one core. `+api-path-evidence-source` and `+api-support-analysis-source` should call their `-graph` forms.
- **Importer copies (A57, A58, A59).** A provenance-error helper for the repeated preamble, `+local-arm-source` in `+tagged-union-fallback`, one list of standard collections, one unwrap gate parameterised by the wrapper's tag, one case lister for `$%` and `$?` with the budget as a parameter. A59, a reader that walks once for both the plain and diagnostic results, is low priority.
- **Budgets (A124).** The checker's literal budgets (256, 64, 4,096 and others) are scattered. Name the ones in code the core keeps in one arm; the `dg-*` ones go with the core.

## Step 4: docs

- **The library's header and `compiler.md` (A2, A60, A101, A131).** `jibb.hoon`'s first line says milestone 1, and its API list lacks `infer-jibb-file`, `infer-jibb-file-detailed` and the `golden-types-with-*` entry points. Its API list also lacks `+layout-error`, `+golden-types-imports`, `+prepare-prelude` and `+prepare-prelude-with-internal`, which hosts and `tools/golden` call. Add them all, make `compiler.md`'s API table list the same arms, fix its `%api` row, and add `%union-analysis` to its chapter table with an accurate `%type-inference` row; that chapter also holds the module checker, the API code and the recovery, so say so or split it. The header also still says the doc wins, where question 42 made the copy in `docs/spec/` win, and its Status paragraph calls the checker a partial inference fragment; fix both, as `development.md` words the first, and fix `compiler.md`'s first paragraph, which says "as milestone 1 left it". Milestone-2-finish step 10 rewrites these again for the core; this fix is for the code as it is now.
- **Design notes 2.6, 3 and 4.2 (A2).** They don't mention the `_` type hole (its token, where a mold may be `_`, its tree form) or the `?(` hint ("a union is a `+$` with its cases below"). Add them, writing the hint where A7 leaves the check: once the lexer reports it, in note 2.6's table of left-out forms, beside `$?` and `$%`.
- **The recovery chain (A41).** Neither `compiler.md` nor `status.md` mentions the plain-view recovery, `+program-plain-view-context`, which runs only when the keyed-view proof declines. Add it to `compiler.md`'s recovery paragraph and to `status.md`'s component-local recovery row, or leave it if the core has deleted it by then.
- **The importer's header (A53).** It opens with `+read-mold`, which only tests use; the callers use `+read-named` and `+read-mark` and their `-diagnostic` forms. Rewrite the header's API paragraph around them, and fix the two `jibb.hoon` comments that name `+read-mold`.
- **The prelude docs (A54, A105, A63, A99).** `prelude-inventory.md` lists the nine 3g shapes as future work though all exist, and its 2a rows contradict the paragraph above them. `decisions.md`'s Core language row still says three rules in its tab are proposed, but `core-language.md` marks none, and the review found each decided in its own row; drop the clause and set the row's Synced column to No, and ask @iko only about a rule that has no decided row. `internal.jibb` should say in a comment that the compiler adds the public prelude's validated list and unit to `core`, to avoid an import cycle, and `tuba-text` should take `values=(list @tD)`.
- **Question 38 (A112).** Montelot chose to keep `my-app`'s deliberately failing buttons example and the theme's static font, and to list them as a milestone 4 question. Add it to `open-questions.md` under "Questions milestone 2 raises", or in the plan's table with "review question 38" in the row, so the table doesn't credit the plan with it.
- **A106.** A paragraph about the tools sits under `development.md`'s ground rules, and `docs/README.md` carries status prose. Move the first into "The test suites". Delete the second, after adding to a `status.md` row anything it says that no row does.
- **A103, what is left.** `open-questions.md` still lists grammar questions 4 and 11, which the syntax review settled (S6, S7). `decisions.md`'s Syntax and Type variables rows already record the answers, so delete the two rows, keep the other rows' numbers, and update the page's "as of" date.
- **A115, A116.** `my-app/mar/todo-action.hoon` says it is "not supplied by the design doc", but it is the overview's `todo-action` block; fix the line. Say in the README's desk table that `my-app`'s `desk.bill` is `~` until fixture agents arrive. List the missing `%todo` and `%blog` fixture agents, and a page that embeds the basket, as gaps in `status.md` for milestones 5 and 6, and ask @iko before adding them to `implementation-plan.md`, which is @iko's tab.

## Step 5: the rulings, when @iko confirms them

Ask @iko about each in the project chat, with the proposal from `open-questions.md`. When one is confirmed, record it in `decisions.md`, move it out of `open-questions.md`, then change the code with golden cases. Until then, change nothing.

| Question | Proposal | Then |
| --- | --- | --- |
| 16, 17 (A20) | A term literal fits its own aura family, `%1.000` a `@ud` and `%&` a `?`; a name term also fits `@t` | Change the two term-literal branches of `+itype-fit-inner`, the `%atom` row of `+tag-presence`, and the sentence in `grammar.md`'s Tag resolution that lists `@tas`, `@ta`, `@` and `*`; the syntax review's S4 already did this for bare decimals |
| 18 (A23) | A gate may fit `*` | No code change; say in `core-language.md` that `*` may hold gates |
| 19 (A6, A100) | `[]` and `m()` are rejected in the parser, at the closer | Parser errors at the closer, with golden cases; make the EBNF's `tuple` rule take at least one item; delete the three "empty cell is not supported by partial inference" strings, and the checker's "a change takes at least one field" once the parser reports `m()` |
| 20 (A30) | `[a=@ud [a=@t b=?]]` is one record, so the duplicate `a` is an error | `+duplicate-fields` carries seen fields through unfaced tails; fix the comment above `+$ written-fields` in `jibb.hoon`, which says each written record has its own scope |
| 21 (A25) | `/%  %foo` and `++ foo 1` may share a name | `+module-scope-valid` checks marks only against marks and molds, as the API scope check has done since `ce69a3b`; add golden cases for `/%  %foo` beside `++ foo 1` and beside a prelude value in an ordinary module. Tell @iko that API modules already allow it |
| 22 (A15) | A `?-` arm that matches no remaining case is a definite error, "arm matches no case" | The core's usefulness check gives it; until then it reads "union pattern is not supported" |
| 23 (A55), 24 (A64), 27 (A61) | Match Hoon: no comparator in `(mop K V)`; keep both `each`s; the mark keeps dropping the final newline | No code change; record each in `decisions.md` |
| 26 (A50) | The importer reads `$%` with `%&`, `%\|` and `%0` tags, then `each` and `json` | `jibb-import.hoon`'s tag checks, then catalogue entries, with importer fixtures |
| 28 (A136) | The printer flattens `[a [b c]]` and prints named molds by name | `+show-itype`, and the missing-tag message, which lists an imported union's cases (`union %no %yes has no case %other` in `types-missing-tag-imported`) instead of naming it, `choice.fixture`; many `types.txt` change, so do it with or after the core's one pipeline |

One more was never asked: **A62**, whether the prelude's `+$ attr` should spell `pad` and `gap` with a `+$ space %s0 %s1 %s2 %s3` instead of eight constant cases. It adds a public prelude name, which is @iko's call. Ask with the others.

Milestone-2-finish step 7 lists the same import gaps (A50, and A14 from step 1). Build A50 here once @iko confirms question 26, and say in the project chat when it lands, so that brief's builder doesn't build it again.

## Step 6: the checker core

[milestone-2-finish.md](milestone-2-finish.md), steps 2 to 4, describes the core and owns it. Whoever builds it should start from [the checker map](../reviews/2026-11-03-checker-map.md). The review's own advice for staging it:

- Give `istate` a constructor first (A28, A125): it has 27 positional fields, built as literals at 10 places in `jibb.hoon`, so every field the core adds touches all of them. The 13 suites that use it bunt `*istate:jibb` and set fields by name, so they don't need to change.
- The partial report re-infers each definition on its own, so a new core can sit behind the report one definition at a time, before the full check changes (map, section 4.4).
- The program, page and store recovery arms run only for definitions still missing after ordinary resolution, so when the core resolves one ordinarily, its recovery arm stops firing and can be deleted with its tests kept.
- Keep `+itype-fit`'s three answers while old callers remain: `%unknown` should still mean "would need a deferred constraint".
- Budget the golden changes: question 6 moves every `types.txt` once, 347 on `master` today (283 when the review counted). Do that in one commit, with every changed output read.

These findings close when the core lands, and nobody should patch them before: A11 (same-origin unions compared by their raw cases), A15 with question 22, A16 (variable kinds kept by self-bindings in six copied `+itype-walk` arms), A17 (three union-coverage loops), A21 and A35 (the type walkers and variable-kind disjunctions), A33 (`+infer-recursive-gate` retried after every failure), A36 (the call-argument copies in the check-mode dispatcher), A46 (the report's own resolver), A47 (the `dg-*` transaction), A48 (the program recovery arms), A49 (the generic tree proof), A132 (the prelude parsed again for each direct gate-layout proof), the rest of A42 and A130 (the report's entry chain, which parses and duplicate-checks the source again in `+golden-types-in-context` and repeats its eligibility guards, and the ten `+golden-types*` wrappers, which the one pipeline should reduce to the entry points hosts need), the rest of A45, and A121 and A122, the review's direction items on example-fitted slices and two pipelines.

## When you're done

- Every finding in steps 1 to 4 is fixed, each with its case, or written up in `open-questions.md` with the reason it was left.
- Every ruling @iko has confirmed is in `decisions.md` and built; the rest are still listed as waiting.
- Every check passes, under eval and on the ship.
- `status.md`, `compiler.md` and `open-questions.md` describe the code as it is.
- Everything is pushed to `master`, and a few lines go to Montelot in the project chat: what landed, what was left and why, and what waits on @iko or the core.
