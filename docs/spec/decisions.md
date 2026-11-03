# Jibb decisions

Oct 29, 2026 · @iko

The choices behind the Language tab, made on 2026-10-23; a later date marks a revision.

## Decisions

Until the Claude doc is synced with this copy, this copy is the spec (review question 42). Synced says whether the doc's Decisions tab has the row as written here. A row decided by 2026-10-29 or undated was in the doc when `spec/` was copied from it on 2026-10-30, and is unchanged. A row decided on or after 2026-10-31 is only here. A row of 2026-10-30 says Check: the copy had that day's answers to the 12 grammar questions, but other rows of that day were added or edited here afterwards ([docs/README.md](../README.md#the-spec)), and nobody has compared them with the doc yet.

Rows dated 2026-11-03 are Montelot's decisions on the [syntax review](../reviews/2026-11-02-syntax-review.md): S1 with its step 1, S2, S4 to S7, S11 to S13 and S15. S1 step 1 is decided but not built yet; the checker core that review question 5 asks for will build it.

| Decision | Choice | Status | Synced |
| --- | --- | --- | --- |
| Syntax | Hoon's runes as keywords, and its literals; wide forms only for `\|=` and `$-`; changes take one or more record items, as `m(draft="x")`, so `m()` is an error; an item may name a wing through record fields, as `m(open.cart=x)`, every value is computed from the original record, and two items that name the same field, or one inside the other, are an error; `.` reads fields, imports and prelude groups; no name may shadow another | Decided 2026-11-03 | No |
| Literals | Exactly Hoon's, including `%$` as a term literal and pattern: a bare decimal is a `@ud`, so `^- @dr 30` is an error and a duration is written `~s30`; `1000` is an error, `~2026.2.31` is `~2026.3.3`, and years BC and sub-second groups are dates; `print-date`'s minute form is not a literal | Decided 2026-11-03 | No |
| Cells | A single-item cell `[a]` is `a`; an empty `[]` is an error, in expressions and molds | Decided 2026-10-30 | Check |
| Numeric terms | `%` and a decimal as Hoon writes it: `%1.000`; `%1000` and `%007` are errors | Decided 2026-10-30 | Check |
| Strings | Hoon's escapes: `\\`, `\"`, `\{`, and `\` with two lowercase hex digits; a string and each `{…}` close on the line they open; `::` in a string is text | Decided 2026-10-30 | Check |
| Spacing | Style, kept by the formatter: one or more spaces between items, and spaces allowed after an opener, before a closer and at the end of a line; faces, puns and typed path segments take no spaces; a rune is followed by one | Decided 2026-10-30 | Check |
| Path literals | `/posts/~zod` is an expression: `pathlit` is an operand | Decided 2026-10-30 | Check |
| Crash | `!!` is an operand, so `f !!` and `~[!!]` need no parentheses | Decided 2026-10-30 | Check |
| Sample names | Every bare name in a sample binds, at any depth: `\|= [a=@ b]` binds `a` and `b` | Decided 2026-10-30 | Check |
| Local definitions | At the start of any body: a gate's, an arm's, a `^-`'s, a `~&`'s or a `++`'s | Decided 2026-10-30 | Check |
| Value cycles | A non-gate value that depends on itself, even through a gate, is an error; mutually recursive gates are allowed | Decided 2026-10-30 | Check |
| Open molds | A mold's `[` and `(` may be left open at line end, one field or mold per deeper line; a `(` keeps the mold's name on its first line | Decided 2026-10-30 | Check |
| Open groups | A `(` alone at line end puts the call's head on the first deeper line | Decided 2026-10-30 | Check |
| Several open brackets | The deeper lines go to the last bracket, or the last rune's body, left open on a line, and the brackets before it close with it: `(column ~ ~[` needs no `)` | Decided 2026-10-30 | Check |
| Jibb code blocks | Labelled `jibb` in this doc; each is a golden test | Decided 2026-10-30 | Check |
| Definitions | `++` for values, `+$` for molds; no `=/` | Decided | Yes |
| Unions | No `$?`: a `+$` with its cases on the lines below is a union, so every union written in Jibb has a name; one case is just that mold; a mold that isn't a union counts as a union of one case for tags and `\|=%tag`; a generic's `\|$` comes right after the `+$`'s name; tags anywhere; constructor heads and case disjointness compare literal noun values regardless of spelling, so `%$`, `%.y` and `~` are equal and overlapping cases are errors; cases differ as nouns, with `?` treated as the two atoms `%.y` and `%.n`, disjoint from cells and overlapping constants 0 and 1, and `!!` or any cell with an empty position disjoint from every case; a tag literal or `~` waits for its union, and an unresolved one is an error | Decided 2026-10-31 | No |
| Printed unnamed unions | Print the cases separated by spaces, as `%approve %deny`; this is print-only, not Jibb syntax | Decided 2026-10-30 | Check |
| Printed type constraints | Print an atom constraint as `$-([A A] A) where A is an atom`, an arithmetic atom constraint as `where A is an atom other than ?`, and a gate-free constraint as `$-([A A] ?) where A contains no gates`; separate multiple clauses with commas, as `where A is an atom, B contains no gates` | Decided 2026-10-31 | No |
| Branching | `?-` only, loobeans included; exhaustive, with explicit catch-alls; covered arms are errors; failures say `!!` | Decided 2026-10-29 | Yes |
| Equality and negation | The gates `eq` and `not`, with Hoon's bitwise `not` exposed as `not.bit`; `eq`'s arguments and map and set keys contain no gates, even nested; the checker infers and generalizes that constraint; union matching never inspects a gate to distinguish cases | Decided 2026-10-30 | Check |
| Special rules | No built-ins; type-directed rules are welcome, each listed in the Grammar tab | Decided 2026-10-29 | Yes |
| Inference | Hindley–Milner with aura variables; `@` is any atom, a specific atom fits `@` and a more specific aura fits an ancestor in its Hoon aura family, but each reverse needs a check, and repeated atom-constrained capitals give the same type; a decimal is a `@ud`, which fits `@u`, `@` and `*` but no other aura, except where its `++` is generic over its aura; distinct specific auras remain distinct; faces are part of record types, and an unnamed position can take a face but two different faces don't unify; a capital that meets a faced position binds only the type under the face, so `$-([A A] ?)` takes a gate with named parameters (not built yet); principal types | Decided 2026-11-03 | No |
| Effects | The library unions `cmd` and `sub`; `raw-poke`, `ask` and `qath` are transparent types defined in the internal prelude and re-exported normally; derived gates and `pure` also construct requests; islands read agents only by watching; replies get full state, and diffs take a fold; timers carry the time; `%who` gives the owner's `@p`; nacks reach replies as text | Decided 2026-11-01 | No |
| Poke representation | The source-backed private internal prelude module defines `raw-poke`, and the public prelude re-exports it as an ordinary transparent type. A store's local `poke` action remains an ordinary mold; derived helpers produce the runtime envelope | Decided 2026-11-01 | No |
| Agent APIs | `/ui/api/<agent>.jibb` with `+$ poke` and `+$ paths`, over the agent's mark types; a case is a name, a path and a type, with `(facts full diff …)` for diffs, told apart by mark; an optional scry path, for pages; an island may watch a request only when the checker proves it is watchable, so a separate scry path or unknown watchability is an error; typed segments by aura | Decided 2026-10-31 | No |
| Mark names | Any name: `/%` names types after marks, and constructors poke with their type's mark; no alias marks | Decided 2026-10-26 | Yes |
| Derived gates | API files and stores give a generic `poke` command helper taking an action and reply, and a checked request per path or store state; clashing names are errors, including a derived name that clashes with an import face | Decided 2026-11-01 | No |
| Hoon types | A fixed translation table; `map`, `set`, `qeu`, `jar`, `jug` by name; `mop` as `(mop K V)`, read with `on`; imported `$%`, `$?` and `$^` cases must differ as nouns, and records with duplicate field names are errors where used; unused molds skipped | Decided 2026-10-30 | Check |
| Record fields | Duplicate field names in a Jibb-written record are an error, as they are in an imported Hoon record | Decided 2026-10-31 | No |
| Unface | The explicit type-directed operation `unface` removes every face from its argument's type, through cells, a gate's sample and product, and containers' arguments; unions and recursive molds go by name and are kept whole; like `proj`, it is reserved and not a value; it leaves nothing behind at run time | Decided 2026-11-03 | No |
| Record projection | The explicit type-directed operation `proj` takes a record and uses its expected result type to select its fields; no projection is inserted automatically. `proj` is reserved and cannot be defined or imported under that name. The result has exactly the fields declared by its type | Decided 2026-10-31 | No |
| Layout | Indentation; juxtaposed calls; a bracket open at line end takes one item per line, with no closer; a block of deeper lines belongs to the line above, so a call never continues onto a deeper line; a body's final line may hand the rest of the body, at its depth, to a tall `\|=`, `^-` or `~&` that ends it, and a `?-` that begins it may take its arms at its depth | Decided 2026-11-03 | No |
| Elements | Ordinary gates; containers take attribute lists; `stack` switches at `wide`; `el` adds attributes and wins; headings 1 to 6; `form` sends on Enter, the innermost when nested; `image` from an application path, sized from the file, or a sized URL; no focus control for now | Decided 2026-10-29 | Yes |
| Long calls | One argument per line inside parentheses | Decided | Yes |
| Inline gates | Hoon's wide form; the mold may be inferred; a bare sample name binds; `\|=%got` is a case's constructor, typed by the gate expected; a bare tag is always a value | Decided 2026-10-29 | Yes |
| Empty mold | `!!`, with no values; the expression has any type; pages are `(element !!)`, which keeps islands out of islands | Decided 2026-10-29 | Yes |
| Noun mold | `*` is the noun type, not a type variable; use a capital for a generic type; a value of a more specific noun type can be used where `*` is expected | Decided 2026-10-30 | Check |
| Type variables | A capital, then lowercase letters and digits, as `A` or `Msg`, printed by the name they were written with; generalized per `++`; a capital in a local `++` shares the enclosing `++`'s variable of that name if the enclosing `++` also uses it; otherwise it is introduced and generalized locally; a different type takes a different capital; a body cannot force distinct capitals to be equal, so a shared type uses the same capital; one used where an atom is required gains an inferred atom constraint, and cannot be fixed to a more specific type in its body | Decided 2026-11-03 | No |
| Partial type annotations | `_` may appear wherever a mold may appear and marks that part of the type for inference; a hole inferred as a named type variable is resolved; an unconstrained hole is an error, and a named mold or value definition must determine its own holes without constraints from later uses | Decided 2026-10-31 | No |
| Loobean mold | `?`, switched with `?-` | Decided 2026-10-26 | Yes |
| Defaults | None | Decided | Yes |
| Modules | Records, not cores | Decided | Yes |
| Kinds | The type of `main`: `(element !!)`, `(page Params Data)`, `(program Data Model Msg)` or `(store S)`; other names by file kind, in the Grammar tab | Decided 2026-11-03 | No |
| Type identity | Recursive molds by name and module | Decided 2026-10-29 | Yes |
| Binding patterns | In `?-` arms; the last position binds the rest; cells of patterns nest; a bare name is an error where a case the pattern can match has there a tag the name spells, as `stop` for `%stop` | Decided 2026-11-03 | No |
| Text | Strings are written only as `"…"` and are always cords; tapes come from `trip`; `{…}` prints by aura, a bare `@` as `@ud`, and an atom whose aura its `++` is generic over is an error; `print-date` prints Urbit-style to the minute in the theme's zone, from jibb-dev's zone table; numbers keep Hoon's form | Decided 2026-10-30 | Check |
| Auras | Specific auras stay distinct; `@` is any atom, a more specific aura fits an ancestor in its Hoon aura family one way, with the reverse requiring a check, and shared atom-constrained type variables preserve the same aura | Decided 2026-10-30 | Check |
| Loobean arithmetic | Arithmetic rejects loobean operands; comparison may accept them and returns `?` | Decided 2026-10-31 | No |
| Crashes | As in Hoon; an island keeps its model and shows the standard notice; a failing page, or one rendering a control outside an island, gets Jibb's error page; no render limit, so an endless render stalls the ship | Decided 2026-10-29 | Yes |
| Refinement types | None | Decided | Yes |
| Imports | `/-`, `/%` (a mark's type, with no face) and `/=`; no `/+`; cycles are errors | Decided 2026-10-29 | Yes |
| Hoon marks for Jibb types | None: wire types are the agent's marks, and Jibb's own types never cross | Decided 2026-10-26 | Yes |
| Core language | A small untyped core language between the checker and both backends: Nock's operations on nouns plus a lambda calculus with names; one sample per call; s-expressions as its text form; a reference interpreter in Hoon; three rules in its tab still proposed | Decided | Yes |
| Stages | By kind: pages without data at commit, with data in the host, islands and stores in the browser; never inferred | Decided 2026-10-29 | Yes |
| Page loading | `load` maps route parameters, `~` for none, to one `ask` or `pure`; pages render per request from a fresh scry of the path, or of its case's scry path; nothing is watched or kept | Decided 2026-10-29 | Yes |
| Compile targets | Nock on the ship, JavaScript in the browser | Decided | Yes |
| Optimizer | Basic lowering; holes later | Decided 2026-10-29 | Yes |
| Island `update` | In the browser; returns the model and a list of commands, which the runtime processes one at a time in list order | Decided 2026-11-02 | No |
| Island `init` | Takes the page's data, returns the model | Decided 2026-10-29 | Yes |
| Island rendering | `view` re-runs on model changes; a keyed diff patches the DOM; holes later | Decided 2026-10-29 | Yes |
| Data crossing to the browser | No gates in island data or models | Decided 2026-10-29 | Yes |
| Inputs | A message per input event, none mid-composition; controls reset to the latest view after every event; fields read-only until the island starts | Decided 2026-10-29 | Yes |
| Transactions | None; one poke per command | Decided | Yes |
| Reloads | Restart from the model the page is served with | Decided 2026-10-29 | Yes |
| Shared state | Stores: browser agents written like API files, with `state`, a local `+$ poke` action mold and `(store init update)`; derived gates provide the generic `poke` command helper and state requests; one per page | Decided 2026-11-01 | No |
| Store builder | `+$ store |$ [S] [init=S update=*]`, with `++ store |= [init=S update=$-([A S] S)] ^- (store S) [init update]`: the builder checks action `A`, while `main` exposes only state `S`; the store kind check verifies `A` against the poke declaration | Decided 2026-11-01 | No |
| Subscriptions | By agent and path, shared per page; the first fact is full state, so no paths that need a scry path | Decided 2026-10-29 | Yes |
| Apps | One island under a catch-all route, given the path by `pure`; `%url` delivers the path on every change; in-section links act as `go`; focus moves to the first heading | Decided 2026-10-29 | Yes |
| Layout vocabulary | Jibb's elements and theme tokens; the stylesheet comes from the theme alone; chars and fill are inline; `[%fill n]` below 1 counts as 1 | Decided 2026-10-29 | Yes |
| Responsive layout | `stack` switches at the theme's `wide` | Decided 2026-10-29 | Yes |
| Theme | A prelude mold with every token required: spaces, five tones with `normal` and `background`, language, zone, `wide`, and an optional static font; optional values such as dark tones use explicit backtick unit syntax; 4.5:1 contrast enforced | Decided 2026-11-01 | No |
| Dark mode | Hand-written dark tones under `dark`, used when the reader prefers dark | Decided 2026-10-27 | Yes |
| Links | All text escaped; in-app links are application paths, as `%/blog/(slug)`, with no query or fragment, checked at compile time against routes and static files; paths and unchecked `https`, `mailto` and `tel` URLs and root-relative cords such as `"/apps/groups"` have separate declarations; `link-unsafe`, `image-unsafe` and `go-unsafe` are the unchecked forms; both navigation declarations produce `[%go url=@t]`, with `go` converting the path to a cord including the app's base path; other cords render as text; a CSP on every page | Decided 2026-10-30 | Check |
| Data layer | Hoon's nouns: units, treaps, loobeans | Decided | Yes |
| Prelude | Hoon's standard library regrouped: all names from the listed sections except explicitly excluded groups, including all of 3g, with Hoon's `tone` exposed as `tone.hoon` and Hoon's 1c `step` as `step.hoon`; arithmetic over aura variables, units, lists, maps, sets, queues, ordered maps, function helpers, text, atom printing, a zoned date printer, time and data molds; folds take a start; jetted functions have working Jibb implementations, whose shapes the compiler recognizes to use the Hoon versions, and may take gates; private helpers and low-level primitives live in a separate internal module imported without exposing them, with public foundational gates implemented in Jibb on those primitives; `clap` takes two units of the same type and a combining gate over that type; no signed or float gates, or parser gates outside 3g except `slav` and `slaw`; signed or float auras are errors | Decided 2026-10-30 | Check |
| `like` | The `(like A)` mold remains available; the value gate `like` maps the product of an existing `(like A)` with a gate `$-(A B)`, preserving the position and remaining input, and returns `(like B)` | Decided 2026-10-31 | No |
| Wire format | Noun channels; Jibb's own noun codec in the browser | Decided 2026-10-29 | Yes |
| Hosting | One thin host agent on `%jibb` binds, caches and serves every Jibb desk; each desk vendors jibb-dev, names its base path in docket's `site+`, and builds and renders with its own copy through fixed entry points; install `%jibb` first; app agents stay plain Hoon; pokes only from the ship | Decided 2026-10-29 | Yes |
| Private pages | Served by the host per request and never cached; non-owners go to the login page | Decided 2026-10-29 | Yes |
| Cache | Eyre holds only the hashed assets, all public; the host serves every page; a desk's entries are cleared on suspend or uninstall, and all by `-jibb!clear` | Decided 2026-10-29 | Yes |
| Static files | Under `/ui/static/`, committed, at hashed immutable URLs; referenced by application path, so a missing file fails to compile, and images are sized from the file; no large media, since Clay keeps every version and the cache ignores `Range` | Decided 2026-10-29 | Yes |
| Routing | A literal beats a parameter, which beats a catch-all; parameters bind to `load`'s sample by name; `@ta` and `@tas` raw, other auras as Hoon prints them | Decided 2026-10-29 | Yes |
| Linking | Folder convention; the mark stores text; the host runs each desk's own compiler; modules cached by their own and their imports' hashes | Decided 2026-10-29 | Yes |
| Access | Every page is private to the owner; public pages come in a later version | Decided 2026-10-29 | Yes |
| Tests | `test-…` arms under `/ui/tests`, run by `-jibb!test`; the JavaScript side and differential tests under Node from jibb-dev | Decided 2026-10-29 | Yes |
| Editor support | Tree-sitter grammar | Decided | Yes |
| Formatter | One canonical layout: a cast whose expression takes the deeper lines ends the line it belongs to; every `?-` begins its own line, with its arms at its depth where the rest of a body allows that | Decided 2026-11-03 | No |
| Name | Jibb | Decided | Yes |

## Settled milestone 2 questions

Kept only in this copy. These were open questions in [open-questions.md](../open-questions.md) until @iko settled them; the rows above record each choice, and the questions keep their numbers there, so references to them stay valid. Questions 3 and 32 are still open there.

On 2026-10-30, @iko adopted gate-free `eq` arguments and map and set keys, treating gates as opaque when distinguishing union cases, and rejecting a non-gate value that depends on itself even through a gate. The checker infers and generalizes the gate-free constraint. @iko also said jetted prelude functions may take gates.

**1. Settled: how the prelude identifies jetted functions.** On 2026-10-30, @iko said the prelude functions have working Jibb implementations, and the compiler recognizes their shapes and uses the Hoon versions so jets can fire.

**2. Settled: how the prelude keeps helpers private.** On 2026-10-30, @iko chose a separate internal prelude module imported by the prelude, without exposing the imported helpers.

**4. Settled: a capital in a local `++`.** On 2026-10-30, @iko said it shares the enclosing `++`'s variable of that name if the enclosing `++` also uses it; otherwise the local `++` introduces and generalizes its own variable. For example, `++ inner |= y=A y` shares `A` with an enclosing gate whose sample is `x=A`, but generalizes its own `A` if the enclosing `++` does not use `A`. A different type uses a different capital. The Grammar and Decisions record this alongside the earlier aura rules.

**5. Settled: cells of no items or one.** On 2026-10-30, @iko said a single-item cell is the value and `[]` is an error. The theme's `dark=[tones=[…]]`, a record of one field, must still check.

**6. Settled: a change with no items.** On 2026-10-30, @iko said `m()` is an error. The parser still accepts it; the checker needs to reject it and add a golden case.

**7. Settled: the doc's blocks that aren't whole modules.** On 2026-10-30, @iko agreed to check each in its intended context: the `cmd` and `sub` definitions as prelude source, the Core language tab's `update` inside the todo island, and the Grammar's imports example against fixture files.

**8. Settled: tuples and records.** On 2026-10-30, @iko agreed that an unnamed position can unify with a faced position and take its face; two different explicit faces still conflict. The Grammar and Decisions record this rule.

**9. Settled: values where `*` is expected.** On 2026-10-30, @iko said `*` is the noun type, not a type variable; generic positions use proper type variables. A value already known to be `@ud` can be passed where `*` is expected. The `each` and `table` signatures use `key=K`.

**10. Settled: navigation commands.** On 2026-10-30, @iko chose separate declarations for application paths and unchecked cords, with `link-unsafe`, `image-unsafe` and `go-unsafe` for the unchecked forms. `image-unsafe` takes a sized URL record. Both navigation declarations produce `[%go url=@t]`; `go` converts the application path to a cord including the app's base path.

**11. Settled: stores and derived gates.** On 2026-11-01, @iko said a store's local `+$ poke` is an ordinary action mold and the runtime envelope is `raw-poke`; a derived name clashes with an import face; and an island watching a request whose case has a separate `scry=` path has a type error. The todo API's request is renamed `todo-by-id` so it does not clash with `/- todo`. The checker must account for the fact that a store's kind is determined by the type of `main`.

**12. Settled: how to print a union without a name.** On 2026-10-30, @iko said to print its cases separated by spaces, as `%approve %deny`. This is print-only, not Jibb syntax.

**13. Settled: how to print type constraints.** On 2026-10-30, @iko chose `$-([A A] A) where A is an atom` for an atom constraint and `$-([A A] ?) where A contains no gates` for a gate-free constraint. Multiple clauses are comma-separated, as `where A is an atom, B contains no gates`.

**14. Settled: how the prelude implements foundational operations.** On 2026-10-30, @iko chose private low-level primitives in the internal prelude module, with the public foundational gates implemented in Jibb on top of them.

**15. Settled: unrestricted atoms and shared auras.** On 2026-10-30, @iko said `@` means any atom, independently at each occurrence, so Hoon `dime` and `pint` keep their bare-`@` fields. A specific atom such as `@ud` fits where `@` is expected; an `@` value needs a check to fit `@ud`. Shared atom types use one capital, with the atom constraint inferred from its body, as for `add` taking `[A A]` and returning `A`.

**16. Settled: loobeans in union disjointness.** On 2026-10-30, @iko said `?` counts as its two atoms, `%.y` and `%.n`: it is disjoint from any cell and overlaps the constants 0 and 1.

**17. Settled: empty cases in union disjointness.** On 2026-10-30, @iko said `!!` is disjoint from every case. A cell containing an empty position at any depth is itself empty and is also disjoint from every case.

**18. Settled: the value gate `like`.** On 2026-10-31, @iko chose a gate `(like convert result)` that maps the product of an existing `(like A)` result with `convert=$-(A B)`, yielding `(like B)` while preserving its position and remaining input. An absent result stays absent. The `(like A)` mold remains available in the separate mold namespace. Hoon's wet `+like` instead builds a gate that constructs a result from an input noun; the chosen Jibb value gate is an adaptation of that behavior.

**19. Settled: Hoon aura families and `step.hoon`.** On 2026-10-30, @iko chose `step.hoon` for Hoon 1c `step`, avoiding a clash with the Grammar example's `step`, and chose one-way widening across Hoon aura families: for example, `@ud` and `@ux` fit `@u`, and `@tD` fits `@t`. The reverse needs a check. The `step.hoon` group representation is not implemented yet.

**20. Settled: the type of `clap`.** On 2026-10-30, @iko chose one shared value type for both units and the combining gate. If either unit is absent, `clap` returns the other; if both are present, it applies the gate to their values and wraps the result.

**21. Settled: duplicate faces in imported Hoon records.** On 2026-10-30, @iko chose to reject an imported Hoon record with duplicate field names where its type is used. Hoon permits `[a=@ud a=@t]` and picks the first `a`; Jibb rejects it.

**22. Settled: overlapping imported `$%` and `$?` cases.** On 2026-10-30, @iko confirmed that the general union disjointness rule rejects imported `$%` and `$?` cases that overlap as nouns where the type is used, as it does for `$^`. The importer rejects recognizable overlaps and fails closed when it cannot verify them.

**23. Settled: converging explicit capitals.** On 2026-10-30, @iko chose that a body cannot force two separately written capitals to be equal. For `++ repeated |= x=(choice A A) x`, `++ f |= x=(choice A B) (repeated x)` is an error; use `A` in both positions when the type must be shared. This also applies across local captures and within generic mold applications.

**24. Settled: how the internal prelude provides `raw-poke`.** On 2026-11-01, @iko chose to define `raw-poke` in the source-backed private internal prelude module and re-export it through the public prelude as an ordinary transparent type. Ordinary modules can construct and inspect its values, while derived API/store `poke` helpers return commands. This settles `raw-poke`; it does not decide the representation of `ask` or `qath`.

**25. Settled: how the prelude provides `ask` and `qath`.** On 2026-10-31, @iko chose ordinary transparent types defined in the internal prelude and re-exported normally, as for `raw-poke`. Callers may construct and inspect their values.

**26. Settled: the `step` example's `at` binder.** On 2026-10-31, @iko chose to rename the `describe` pattern binder to `sent-at`, keeping Hoon's `at` in the prelude and the no-shadowing rule.

**27. Settled: duplicate fields in a Jibb-written record.** On 2026-10-31, @iko chose to reject duplicate field names, as for imported Hoon records.

**28. Settled: arithmetic on loobeans.** On 2026-10-31, @iko chose to reject loobean operands for arithmetic. Comparison may still accept loobeans and returns `?`. The checker needs to retain this constraint through inference, generalization and instantiation before it exports `add` or `dec`.

**29. Settled: printing the arithmetic atom constraint.** On 2026-10-31, @iko chose `where A is an atom other than ?` for a generic arithmetic type whose atom variable excludes loobeans.

**30. Settled: a hole inferred as a generic variable.** On 2026-10-31, @iko said a hole resolved to an explicitly written type variable counts as inferred: in `++ id |= x=A ^- _ x`, the result hole is `A`. Named molds must determine their own holes without constraints from later uses; an unconstrained hole is an error.

**31. Settled: uses of a value with a hole.** On 2026-10-31, @iko said a value definition must determine its own holes; another definition's use cannot fix an otherwise unresolved hole. For example, `++ id |= x=_ x` remains an error even if a later definition calls `id` with a cord.

**33. Settled: watching a request with unknown provenance.** On 2026-10-31, @iko said an island may watch a request only if the checker proves it watchable at compile time. An unknown request, including one built or passed through a gate without sufficient evidence, is rejected rather than deferred to a runtime check.

**34. Settled: constructors and equal noun literals.** On 2026-10-31, @iko said expressions with the same runtime representation count as equal, and cases that cannot be distinguished at runtime are rejected at compile time. Thus `|=%$` matches a case headed by `%$`, `%.y` or `~`: each is the noun 0. Cases with equal heads and overlapping payloads cannot coexist in a union.

Review question 25, when to build `eq` and the gate-free constraint, is settled: @iko's commit 0858191 adds `eq` and infers the constraint.

## Checked against the kernel

- **Eyre's cache** is keyed by the exact request target, query included, one entry per URL, and counts against the ship's memory ([eyre.hoon](https://github.com/urbit/urbit/blob/50c7f5239610fc72263df7aa99b4d171cfe9d408/pkg/arvo/sys/vane/eyre.hoon#L922-L927), [vere #626](https://github.com/urbit/vere/issues/626)). An auth-flagged entry gives anyone but the owner a bare 403 before any agent sees the request ([vere http.c](https://github.com/urbit/vere/blob/510d5b7fe4ea81343f2364db081ce61f1d2c72d3/pkg/vere/io/http.c#L1141-L1146)), and entries outlive their agent ([gall.hoon](https://github.com/urbit/urbit/blob/50c7f5239610fc72263df7aa99b4d171cfe9d408/pkg/arvo/sys/vane/gall.hoon#L1382-L1409)).

## Build order

Each step ends in something usable.

1. **Parser and mark**: the layout pass, runes, literals and patterns; the `%jibb` mark.
2. **Types and prelude**: inference with aura variables and tag resolution; `/-`, `/%` and `/=`; the Hoon type table; the core prelude gates.
3. **Core language**: lowering from the checked tree, the text form, the reference interpreter in Hoon, and the Nock backend.
4. **Host and static pages**: the shared host running vendored compilers, routing and application paths, layout and theme, static files, the Eyre asset cache and the owner check. First release.
5. **Published pages**: `load`, requests and per-request rendering.
6. **Islands**: first a benchmark that runs the same programs as JavaScript and in a Nock interpreter, to pick the browser backend; then that backend, `cmd` and `sub`, keyed diffing, the shared library, stores, the crash notice and URL subscriptions.
7. **Tooling**: tests, formatter, tree-sitter grammar and differential tests.
8. **Polish**: shared island modules across pages, holes, size.
