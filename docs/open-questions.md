# Open questions

Questions the doc doesn't settle yet, as of 2026-10-30. Language questions belong to the doc's author, @iko: the plan says they go "as comments on the doc, on the words they're about", and a change to the language is "agreed first and recorded in Decisions". When one is settled, record it there, change the code if needed, and remove it here.

## The plan's open questions

From [spec/implementation-plan.md](spec/implementation-plan.md), Open questions:

| Question | Needed by |
| --- | --- |
| What is the typography scale for heading levels and the `role` values? | Milestone 4 |
| Does the Eyre channel CSRF test reproduce on a fake ship? @iko has the write-up; if it does, it goes to Urbit privately. | Milestone 4 |
| What is the benchmark's bar? Proposed: a keystroke in a 500-row list island renders within one 16 ms frame on a mid-range phone. | Milestone 6 |
| Are the proposed loop rules adopted, along with no overlays in v1? | Milestone 6 |
| What do controls look like by default: buttons, toggles and fields, with their focus and disabled states? | Milestone 6 |

On 2026-10-30, @iko adopted gate-free `eq` arguments and map and set keys, treating gates as opaque when distinguishing union cases, and rejecting a non-gate value that depends on itself even through a gate. The checker infers and generalizes the gate-free constraint. @iko also said jetted prelude functions may take gates.

## Questions milestone 2 raises

Found while writing [prompts/milestone-2.md](prompts/milestone-2.md), checking it against the doc's examples, and building the checker. The numbering is retained so existing references stay valid. Questions 3 and 18 remain open; the field-order detail in question 32 is being clarified. The other questions are settled.

1. **Settled: how the prelude identifies jetted functions.** On 2026-10-30, @iko said the prelude functions have working Jibb implementations, and the compiler recognizes their shapes and uses the Hoon versions so jets can fire.
2. **Settled: how the prelude keeps helpers private.** On 2026-10-30, @iko chose a separate internal prelude module imported by the prelude, without exposing the imported helpers.
3. **The prelude's inventory.** On 2026-10-30, @iko chose to include all names from the listed Hoon library sections, excluding groups the spec explicitly leaves out. All of 3g is included; its Hoon `tone` is exposed as `tone.hoon`, distinct from the styling type. Hoon 1c `step` is exposed as `step.hoon`, leaving the Grammar example's `step` name available. On 2026-10-30, @iko also approved `%$` as a term literal and pattern, so Jibb can write the `%$` case of Hoon `coin`. For parsing sections 4j and 4l, only the explicitly listed `slav` and `slaw` are included; other parser helpers are left out. Jibb's `not` negates a loobean, and Hoon's bitwise `not` is exposed as `not.bit`. @iko also agreed to specifying the complete exported inventory in the doc, building its types and gates needed by the examples in milestone 2, and doing native implementations in milestone 3. Prelude unions such as spaces, roles and tones need names that other modules cannot shadow. The actual inventory and signatures still need to be specified.
4. **Settled: a capital in a local `++`.** On 2026-10-30, @iko said it shares the enclosing `++`'s variable of that name if the enclosing `++` also uses it; otherwise the local `++` introduces and generalizes its own variable. For example, `++ inner |= y=A y` shares `A` with an enclosing gate whose sample is `x=A`, but generalizes its own `A` if the enclosing `++` does not use `A`. A different type uses a different capital. The Grammar and Decisions record this alongside the earlier aura rules.
5. **Settled: cells of no items or one.** On 2026-10-30, @iko said a single-item cell is the value and `[]` is an error. The theme's `dark=[tones=[…]]`, a record of one field, must still check.
6. **Settled: a change with no items.** On 2026-10-30, @iko said `m()` is an error. The parser still accepts it; the checker needs to reject it and add a golden case.
7. **Settled: the doc's blocks that aren't whole modules.** On 2026-10-30, @iko agreed to check each in its intended context: the `cmd` and `sub` definitions as prelude source, the Core language tab's `update` inside the todo island, and the Grammar's imports example against fixture files.
8. **Settled: tuples and records.** On 2026-10-30, @iko agreed that an unnamed position can unify with a faced position and take its face; two different explicit faces still conflict. The Grammar and Decisions record this rule.
9. **Settled: values where `*` is expected.** On 2026-10-30, @iko said `*` is the noun type, not a type variable; generic positions use proper type variables. A value already known to be `@ud` can be passed where `*` is expected. The `each` and `table` signatures use `key=K`.
10. **Settled: navigation commands.** On 2026-10-30, @iko chose separate declarations for application paths and unchecked cords, with `link-unsafe`, `image-unsafe` and `go-unsafe` for the unchecked forms. `image-unsafe` takes a sized URL record. Both navigation declarations produce `[%go url=@t]`; `go` converts the application path to a cord including the app's base path.
11. **Settled: stores and derived gates.** On 2026-10-30, @iko said a store's `+$ poke` is a declaration, like an API file's, not a mold; a derived name clashes with an import face; and an island watching a request whose case has a separate `scry=` path has a type error. The todo API's request is renamed `todo-by-id` so it does not clash with `/- todo`. The checker must account for the fact that a store's kind is determined by the type of `main`.
12. **Settled: how to print a union without a name.** On 2026-10-30, @iko said to print its cases separated by spaces, as `%approve %deny`. This is print-only, not Jibb syntax.
13. **Settled: how to print type constraints.** On 2026-10-30, @iko chose `$-([A A] A) where A is an atom` for an atom constraint and `$-([A A] ?) where A contains no gates` for a gate-free constraint. Multiple clauses are comma-separated, as `where A is an atom, B contains no gates`.
14. **Settled: how the prelude implements foundational operations.** On 2026-10-30, @iko chose private low-level primitives in the internal prelude module, with the public foundational gates implemented in Jibb on top of them.
15. **Settled: unrestricted atoms and shared auras.** On 2026-10-30, @iko said `@` means any atom, independently at each occurrence, so Hoon `dime` and `pint` keep their bare-`@` fields. A specific atom such as `@ud` fits where `@` is expected; an `@` value needs a check to fit `@ud`. Shared atom types use one capital, with the atom constraint inferred from its body, as for `add` taking `[A A]` and returning `A`.
16. **Settled: loobeans in union disjointness.** On 2026-10-30, @iko said `?` counts as its two atoms, `%.y` and `%.n`: it is disjoint from any cell and overlaps the constants 0 and 1.
17. **Settled: empty cases in union disjointness.** On 2026-10-30, @iko said `!!` is disjoint from every case. A cell containing an empty position at any depth is itself empty and is also disjoint from every case.
18. **The two uses of Hoon `like`.** Hoon `+like` is a wet mold builder, but the gate it returns is callable and applies its supplied gate to the product. In a verified Hoon 135 example, applying `(like f)` to `[[1 2] [7 8 ~]]` produces an edge whose product is `8` when `f` is identity and `42` when `f` returns `42`; the resulting nail is the original input. Jibb molds are types, not callable values. The prelude now declares a generic `(like A)` mold and a `wonk` extractor; both parse, but their full type and backend validation remain outstanding. Should it also expose a value gate under `like`? If so, should the value preserve Hoon's input shape and behavior, or instead map the product of an already constructed edge? @iko is reviewing these alternatives; the exact public signature is not yet decided.
19. **Settled: Hoon aura families and `step.hoon`.** On 2026-10-30, @iko chose `step.hoon` for Hoon 1c `step`, avoiding a clash with the Grammar example's `step`, and chose one-way widening across Hoon aura families: for example, `@ud` and `@ux` fit `@u`, and `@tD` fits `@t`. The reverse needs a check. The `step.hoon` group representation is not implemented yet.
20. **Settled: the type of `clap`.** On 2026-10-30, @iko chose one shared value type for both units and the combining gate. If either unit is absent, `clap` returns the other; if both are present, it applies the gate to their values and wraps the result.
21. **Settled: duplicate faces in imported Hoon records.** On 2026-10-30, @iko chose to reject an imported Hoon record with duplicate field names where its type is used. Hoon permits `[a=@ud a=@t]` and picks the first `a`; Jibb rejects it.
22. **Settled: overlapping imported `$%` and `$?` cases.** On 2026-10-30, @iko confirmed that the general union disjointness rule rejects imported `$%` and `$?` cases that overlap as nouns where the type is used, as it does for `$^`. The importer rejects recognizable overlaps and fails closed when it cannot verify them.
23. **Settled: converging explicit capitals.** On 2026-10-30, @iko chose that a body cannot force two separately written capitals to be equal. For `++ repeated |= x=(choice A A) x`, `++ f |= x=(choice A B) (repeated x)` is an error; use `A` in both positions when the type must be shared. This also applies across local captures and within generic mold applications.

24. **Settled: how the internal prelude provides `poke`.** On 2026-10-31, @iko chose to define `poke` in the source-backed private internal prelude module and re-export it through the public prelude as an ordinary transparent type. Ordinary modules can construct and inspect its values. This settles `poke`; it does not decide the representation of `ask` or `qath`.

25. **Settled: how the prelude provides `ask` and `qath`.** On 2026-10-31, @iko chose ordinary transparent types defined in the internal prelude and re-exported normally, as for `poke`. Callers may construct and inspect their values.

26. **Settled: the `step` example's `at` binder.** On 2026-10-31, @iko chose to rename the `describe` pattern binder to `sent-at`, keeping Hoon's `at` in the prelude and the no-shadowing rule.

27. **Settled: duplicate fields in a Jibb-written record.** On 2026-10-31, @iko chose to reject duplicate field names, as for imported Hoon records.

28. **Settled: arithmetic on loobeans.** On 2026-10-31, @iko chose to reject loobean operands for arithmetic. Comparison may still accept loobeans and returns `?`. The checker needs to retain this constraint through inference, generalization and instantiation before it exports `add` or `dec`.

29. **Settled: printing the arithmetic atom constraint.** On 2026-10-31, @iko chose `where A is an atom other than ?` for a generic arithmetic type whose atom variable excludes loobeans.

30. **Settled: a hole inferred as a generic variable.** On 2026-10-31, @iko said a hole resolved to an explicitly written type variable counts as inferred: in `++ id |= x=A ^- _ x`, the result hole is `A`. Named molds must determine their own holes without constraints from later uses; an unconstrained hole is an error.

31. **Settled: uses of a value with a hole.** On 2026-10-31, @iko said a value definition must determine its own holes; another definition's use cannot fix an otherwise unresolved hole. For example, `++ id |= x=_ x` remains an error even if a later definition calls `id` with a cord.

32. **Partly settled: type-directed record projection.** On 2026-10-31, @iko chose an explicit `(proj record)` whose expected result type selects the fields. There is no automatic projection, and `proj` is reserved against definitions and imports. The result contains exactly the fields of its expected type. Whether the result may reorder fields from the source remains open.

## Grammar questions never put to the doc's author

In milestone 1 the parser met about thirty places where the doc could be read more than one way. Twelve went to @iko on 2026-10-30 and are rows of the Decisions tab. These were not asked. For each, the parser follows the reading below, and some are marked "(doc question)" in the library's notes. None changes what a valid program means, except where a reading makes something an error.

| # | Question | What the parser does now |
| --- | --- | --- |
| 1 | `knot` may be empty, so the EBNF admits `//`, `/a//b` and a trailing `/`. Which are paths? | A segment has at least one character, as in Hoon. `/` alone is the empty path, in expressions and molds; `%/` alone is the root application path. `//` fails at the second `/`, and a trailing `/` just past it. `inline-mold-paths` has `/` alone as a mold |
| 2 | Is `/` alone a valid path for a `/=` import? | No: `/=` names a module's file, so its path has a segment. `/=  card  /` fails just past the `/` (`inline-import-root-bad`) |
| 3 | The EBNF's `line = [ name "=" ] expr` lets every open bracket's lines take `name=`. What would it mean on a line of an open `(` or `~[`? | An error: `name=` lines belong to tuples and changes. "expected a space between items, found `=`; `name=value` goes in a cell, as [a=1], or a change, as m(a=1)" |
| 4 | Does "items named" make every item of a change need `name=`? | Yes: `m(x)` fails just past `x`, "a change's items are named, as in m(done=%.y)" (`lex-tight-change-bad-3` to `-7`; `-8` and `-9` test what follows a name there). The parser still accepts `m()`, though question 6 settled it as an error |
| 5 | `term` includes `%0`, `%&` and `%\|`, which no mark is called. What does `/%` take? | `%` and a name only: `/%  %0` is "expected a mark's term, as `%todo-action`, found `%0`" |
| 6 | What does an indented first line mean? | An error: "the first line is indented: top-level lines start at column 1" (`lex-indent-bad-3`) |
| 7 | With levels open at columns 1 and 5, what does a line at column 3 mean? | An error naming the open columns: "this line's indentation matches no enclosing line: indent it to column 1 or 5". `lex-indent-bad-2`, with levels at 1, 5 and 7, gives "column 1, 5 or 7" |
| 8 | Tabs, carriage returns, other control characters, and non-ASCII text outside strings and comments? | Errors everywhere, strings and comments included, except that UTF-8 is allowed in strings and comments; a tab in a string is written `\09`. `lex-indent-bad-1` and `lex-spacing-bad-2` test tabs |
| 9 | Must a file be valid UTF-8? | Not checked yet: any byte from 128 up passes in strings and comments, and columns assume UTF-8. The proposed reading makes a byte that can't continue a UTF-8 sequence an error. An escape such as `\ff` still writes any byte, as in Hoon |
| 10 | Inside `{…}`, may `::` start a comment, which would swallow the `}` and the `"`? Is a lone `}` in a string text? May a comment follow code with no space, as in `5::note`? | A `:` inside `{…}` is "a comment can't start inside `{…}`". A lone `}` is text, as in Hoon. `5::note` is `5` and a comment |
| 11 | Is a type variable exactly one capital letter, as `typevar = upper` says? | Yes: `Msg` is "a type variable is one capital letter" |
| 12 | Hoon has more runes of the left-out kinds than the list names: `?~ ?= ?. ?@ ?^`, `:- :+ :^ :_`, `%- %+ %^ %~`, `=+ =? =.`, `;:` and `~&(…)`. Are they all left out? | Yes, with the list's reasons, as "`:-` is left out: indentation covers it; write a cell as [a b]". Naming them in the doc, or saying "Hoon's other runes", would make the messages the doc's words (`inline-leftout-*`) |
| 13 | `@s…` and `@r…` auras are "errors wherever used". Is that the parser's error in Jibb source, or the checker's? | An error before the checker. Where a mold goes, the layout pass's, at the `s` or `r`: "signed and floating-point auras are left out of Jibb". Where an expression goes, the parser's, at the `@`: "expected an expression, found `@`; signed and floating-point auras are left out of Jibb". Imported ones are milestone 2's importer's. The case `inline-leftout-signed-float-auras` still says "expect: unclear" |

Where an error points is not a doc question: the doc asks only for "errors with file, line, column and an excerpt". The library puts each error at the first character where the text stops being the start of any valid module, as Hoon's parser does (its section 2.0).
