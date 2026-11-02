# Jibb decisions

Oct 29, 2026 · @iko

The choices behind the Language tab, made on 2026-10-23; a later date marks a revision.

## Decisions

| Decision | Choice | Status |
| --- | --- | --- |
| Syntax | Hoon's runes as keywords, and its literals; wide forms only for `\|=` and `$-`; changes take one or more record items, as `m(draft="x")`, so `m()` is an error; `.` reads fields, imports and prelude groups; no name may shadow another | Decided 2026-10-30 |
| Literals | Exactly Hoon's, including `%$` as a term literal and pattern: `1000` is an error, `~2026.2.31` is `~2026.3.3`, and years BC and sub-second groups are dates; `print-date`'s minute form is not a literal | Decided 2026-10-30 |
| Cells | A single-item cell `[a]` is `a`; an empty `[]` is an error, in expressions and molds | Decided 2026-10-30 |
| Numeric terms | `%` and a decimal as Hoon writes it: `%1.000`; `%1000` and `%007` are errors | Decided 2026-10-30 |
| Strings | Hoon's escapes: `\\`, `\"`, `\{`, and `\` with two lowercase hex digits; a string and each `{…}` close on the line they open; `::` in a string is text | Decided 2026-10-30 |
| Spacing | Style, kept by the formatter: one or more spaces between items, and spaces allowed after an opener, before a closer and at the end of a line; faces, puns and typed path segments take no spaces; a rune is followed by one | Decided 2026-10-30 |
| Path literals | `/posts/~zod` is an expression: `pathlit` is an operand | Decided 2026-10-30 |
| Crash | `!!` is an operand, so `f !!` and `~[!!]` need no parentheses | Decided 2026-10-30 |
| Sample names | Every bare name in a sample binds, at any depth: `\|= [a=@ b]` binds `a` and `b` | Decided 2026-10-30 |
| Local definitions | At the start of any body: a gate's, an arm's, a `^-`'s, a `~&`'s or a `++`'s | Decided 2026-10-30 |
| Value cycles | A non-gate value that depends on itself, even through a gate, is an error; mutually recursive gates are allowed | Decided 2026-10-30 |
| Open molds | A mold's `[` and `(` may be left open at line end, one field or mold per deeper line; a `(` keeps the mold's name on its first line | Decided 2026-10-30 |
| Open groups | A `(` alone at line end puts the call's head on the first deeper line | Decided 2026-10-30 |
| Several open brackets | The deeper lines go to the last bracket, or the last rune's body, left open on a line, and the brackets before it close with it: `(column ~ ~[` needs no `)` | Decided 2026-10-30 |
| Jibb code blocks | Labelled `jibb` in this doc; each is a golden test | Decided 2026-10-30 |
| Definitions | `++` for values, `+$` for molds; no `=/` | Decided |
| Unions | No `$?`: a `+$` with its cases on the lines below is a union, so every union written in Jibb has a name; one case is just that mold; a mold that isn't a union counts as a union of one case for tags and `\|=%tag`; a generic's `\|$` comes right after the `+$`'s name; tags anywhere; constructor heads and case disjointness compare literal noun values regardless of spelling, so `%$`, `%.y` and `~` are equal and overlapping cases are errors; cases differ as nouns, with `?` treated as the two atoms `%.y` and `%.n`, disjoint from cells and overlapping constants 0 and 1, and `!!` or any cell with an empty position disjoint from every case; a tag literal or `~` waits for its union, and an unresolved one is an error | Decided 2026-10-31 |
| Printed unnamed unions | Print the cases separated by spaces, as `%approve %deny`; this is print-only, not Jibb syntax | Decided 2026-10-30 |
| Printed type constraints | Print an atom constraint as `$-([A A] A) where A is an atom`, an arithmetic atom constraint as `where A is an atom other than ?`, and a gate-free constraint as `$-([A A] ?) where A contains no gates`; separate multiple clauses with commas, as `where A is an atom, B contains no gates` | Decided 2026-10-31 |
| Branching | `?-` only, loobeans included; exhaustive, with explicit catch-alls; covered arms are errors; failures say `!!` | Decided 2026-10-29 |
| Equality and negation | The gates `eq` and `not`, with Hoon's bitwise `not` exposed as `not.bit`; `eq`'s arguments and map and set keys contain no gates, even nested; the checker infers and generalizes that constraint; union matching never inspects a gate to distinguish cases | Decided 2026-10-30 |
| Special rules | No built-ins; type-directed rules are welcome, each listed in the Grammar tab | Decided 2026-10-29 |
| Inference | Hindley–Milner with aura variables; `@` is any atom, a specific atom fits `@` and a more specific aura fits an ancestor in its Hoon aura family, but each reverse needs a check, and repeated atom-constrained capitals give the same type; a number takes `@ud` only where its `++` isn't generic over its aura; distinct specific auras remain distinct; faces are part of record types, and an unnamed position can take a face but two different faces don't unify; principal types | Decided 2026-10-30 |
| Effects | The library unions `cmd` and `sub`; `poke`, `ask` and `qath` are transparent types defined in the internal prelude and re-exported normally; derived gates and `pure` also construct requests; islands read agents only by watching; replies get full state, and diffs take a fold; timers carry the time; `%who` gives the owner's `@p`; nacks reach replies as text | Decided 2026-10-31 |
| Poke representation | The source-backed private internal prelude module defines `poke`, and the public prelude re-exports it as an ordinary transparent type. Ordinary modules can construct and inspect its values | Decided 2026-10-31 |
| Agent APIs | `/ui/api/<agent>.jibb` with `+$ poke` and `+$ paths`, over the agent's mark types; a case is a name, a path and a type, with `(facts full diff …)` for diffs, told apart by mark; an optional scry path, for pages; an island may watch a request only when the checker proves it is watchable, so a separate scry path or unknown watchability is an error; typed segments by aura | Decided 2026-10-31 |
| Mark names | Any name: `/%` names types after marks, and constructors poke with their type's mark; no alias marks | Decided 2026-10-26 |
| Derived gates | API files and stores give a constructor per poke type and a checked request per path or store state; clashing names are errors, including a derived name that clashes with an import face | Decided 2026-10-30 |
| Hoon types | A fixed translation table; `map`, `set`, `qeu`, `jar`, `jug` by name; `mop` as `(mop K V)`, read with `on`; imported `$%`, `$?` and `$^` cases must differ as nouns, and records with duplicate field names are errors where used; unused molds skipped | Decided 2026-10-30 |
| Record fields | Duplicate field names in a Jibb-written record are an error, as they are in an imported Hoon record | Decided 2026-10-31 |
| Record projection | The explicit type-directed operation `proj` takes a record and uses its expected result type to select its fields; no projection is inserted automatically. `proj` is reserved and cannot be defined or imported under that name. The result has exactly the fields declared by its type | Decided 2026-10-31 |
| Layout | Indentation; juxtaposed calls; a bracket open at line end takes one item per line, with no closer | Decided |
| Elements | Ordinary gates; containers take attribute lists; `stack` switches at `wide`; `el` adds attributes and wins; headings 1 to 6; `form` sends on Enter, the innermost when nested; `image` from an application path, sized from the file, or a sized URL; no focus control for now | Decided 2026-10-29 |
| Long calls | One argument per line inside parentheses | Decided |
| Inline gates | Hoon's wide form; the mold may be inferred; a bare sample name binds; `\|=%got` is a case's constructor, typed by the gate expected; a bare tag is always a value | Decided 2026-10-29 |
| Empty mold | `!!`, with no values; the expression has any type; pages are `(element !!)`, which keeps islands out of islands | Decided 2026-10-29 |
| Noun mold | `*` is the noun type, not a type variable; use a capital for a generic type; a value of a more specific noun type can be used where `*` is expected | Decided 2026-10-30 |
| Type variables | Capitals, generalized per `++`; a capital in a local `++` shares the enclosing `++`'s variable of that name if the enclosing `++` also uses it; otherwise it is introduced and generalized locally; a different type takes a different capital; a body cannot force distinct capitals to be equal, so a shared type uses the same capital; one used where an atom is required gains an inferred atom constraint, and cannot be fixed to a more specific type in its body | Decided 2026-10-30 |
| Partial type annotations | `_` may appear wherever a mold may appear and marks that part of the type for inference; a hole inferred as a named type variable is resolved; an unconstrained hole is an error, and a named mold or value definition must determine its own holes without constraints from later uses | Decided 2026-10-31 |
| Loobean mold | `?`, switched with `?-` | Decided 2026-10-26 |
| Defaults | None | Decided |
| Modules | Records, not cores | Decided |
| Kinds | The type of `main`: `(element !!)`, `(page R D)`, `(program D X M)` or `(store S)`; other names by file kind, in the Grammar tab | Decided 2026-10-29 |
| Type identity | Recursive molds by name and module | Decided 2026-10-29 |
| Binding patterns | In `?-` arms; the last position binds the rest | Decided 2026-10-29 |
| Text | Strings are written only as `"…"` and are always cords; tapes come from `trip`; `{…}` prints by aura, a bare `@` as `@ud`, and an atom whose aura its `++` is generic over is an error; `print-date` prints Urbit-style to the minute in the theme's zone, from jibb-dev's zone table; numbers keep Hoon's form | Decided 2026-10-30 |
| Auras | Specific auras stay distinct; `@` is any atom, a more specific aura fits an ancestor in its Hoon aura family one way, with the reverse requiring a check, and shared atom-constrained type variables preserve the same aura | Decided 2026-10-30 |
| Loobean arithmetic | Arithmetic rejects loobean operands; comparison may accept them and returns `?` | Decided 2026-10-31 |
| Crashes | As in Hoon; an island keeps its model and shows the standard notice; a failing page, or one rendering a control outside an island, gets Jibb's error page; no render limit, so an endless render stalls the ship | Decided 2026-10-29 |
| Refinement types | None | Decided |
| Imports | `/-`, `/%` (a mark's type, with no face) and `/=`; no `/+`; cycles are errors | Decided 2026-10-29 |
| Hoon marks for Jibb types | None: wire types are the agent's marks, and Jibb's own types never cross | Decided 2026-10-26 |
| Core language | A small untyped core language between the checker and both backends: Nock's operations on nouns plus a lambda calculus with names; one sample per call; s-expressions as its text form; a reference interpreter in Hoon; three rules in its tab still proposed | Decided |
| Stages | By kind: pages without data at commit, with data in the host, islands and stores in the browser; never inferred | Decided 2026-10-29 |
| Page loading | `load` maps route parameters, `~` for none, to one `ask` or `pure`; pages render per request from a fresh scry of the path, or of its case's scry path; nothing is watched or kept | Decided 2026-10-29 |
| Compile targets | Nock on the ship, JavaScript in the browser | Decided |
| Optimizer | Basic lowering; holes later | Decided 2026-10-29 |
| Island `update` | In the browser | Decided |
| Island `init` | Takes the page's data, returns the model | Decided 2026-10-29 |
| Island rendering | `view` re-runs on model changes; a keyed diff patches the DOM; holes later | Decided 2026-10-29 |
| Data crossing to the browser | No gates in island data or models | Decided 2026-10-29 |
| Inputs | A message per input event, none mid-composition; controls reset to the latest view after every event; fields read-only until the island starts | Decided 2026-10-29 |
| Transactions | None; one poke per command | Decided |
| Reloads | Restart from the model the page is served with | Decided 2026-10-29 |
| Shared state | Stores: browser agents written like API files, with `state`, `+$ poke` and `(store init update)`; the store's `+$ poke` is a declaration, not a mold; derived gates provide poke constructors and state requests; one per page | Decided 2026-10-31 |
| Subscriptions | By agent and path, shared per page; the first fact is full state, so no paths that need a scry path | Decided 2026-10-29 |
| Apps | One island under a catch-all route, given the path by `pure`; `%url` delivers the path on every change; in-section links act as `go`; focus moves to the first heading | Decided 2026-10-29 |
| Layout vocabulary | Jibb's elements and theme tokens; the stylesheet comes from the theme alone; chars and fill are inline; `[%fill n]` below 1 counts as 1 | Decided 2026-10-29 |
| Responsive layout | `stack` switches at the theme's `wide` | Decided 2026-10-29 |
| Theme | A prelude mold with every token required: spaces, five tones with `normal` and `background`, language, zone, `wide`, and an optional static font; optional values such as dark tones use explicit backtick unit syntax; 4.5:1 contrast enforced | Decided 2026-11-01 |
| Dark mode | Hand-written dark tones under `dark`, used when the reader prefers dark | Decided 2026-10-27 |
| Links | All text escaped; in-app links are application paths, as `%/blog/(slug)`, with no query or fragment, checked at compile time against routes and static files; paths and unchecked `https`, `mailto` and `tel` URLs and root-relative cords such as `"/apps/groups"` have separate declarations; `link-unsafe`, `image-unsafe` and `go-unsafe` are the unchecked forms; both navigation declarations produce `[%go url=@t]`, with `go` converting the path to a cord including the app's base path; other cords render as text; a CSP on every page | Decided 2026-10-30 |
| Data layer | Hoon's nouns: units, treaps, loobeans | Decided |
| Prelude | Hoon's standard library regrouped: all names from the listed sections except explicitly excluded groups, including all of 3g, with Hoon's `tone` exposed as `tone.hoon` and Hoon's 1c `step` as `step.hoon`; arithmetic over aura variables, units, lists, maps, sets, queues, ordered maps, function helpers, text, atom printing, a zoned date printer, time and data molds; folds take a start; jetted functions have working Jibb implementations, whose shapes the compiler recognizes to use the Hoon versions, and may take gates; private helpers and low-level primitives live in a separate internal module imported without exposing them, with public foundational gates implemented in Jibb on those primitives; `clap` takes two units of the same type and a combining gate over that type; no signed or float gates, or parser gates outside 3g except `slav` and `slaw`; signed or float auras are errors | Decided 2026-10-30 |
| `like` | The `(like A)` mold remains available; the value gate `like` maps the product of an existing `(like A)` with a gate `$-(A B)`, preserving the position and remaining input, and returns `(like B)` | Decided 2026-10-31 |
| Wire format | Noun channels; Jibb's own noun codec in the browser | Decided 2026-10-29 |
| Hosting | One thin host agent on `%jibb` binds, caches and serves every Jibb desk; each desk vendors jibb-dev, names its base path in docket's `site+`, and builds and renders with its own copy through fixed entry points; install `%jibb` first; app agents stay plain Hoon; pokes only from the ship | Decided 2026-10-29 |
| Private pages | Served by the host per request and never cached; non-owners go to the login page | Decided 2026-10-29 |
| Cache | Eyre holds only the hashed assets, all public; the host serves every page; a desk's entries are cleared on suspend or uninstall, and all by `-jibb!clear` | Decided 2026-10-29 |
| Static files | Under `/ui/static/`, committed, at hashed immutable URLs; referenced by application path, so a missing file fails to compile, and images are sized from the file; no large media, since Clay keeps every version and the cache ignores `Range` | Decided 2026-10-29 |
| Routing | A literal beats a parameter, which beats a catch-all; parameters bind to `load`'s sample by name; `@ta` and `@tas` raw, other auras as Hoon prints them | Decided 2026-10-29 |
| Linking | Folder convention; the mark stores text; the host runs each desk's own compiler; modules cached by their own and their imports' hashes | Decided 2026-10-29 |
| Access | Every page is private to the owner; public pages come in a later version | Decided 2026-10-29 |
| Tests | `test-…` arms under `/ui/tests`, run by `-jibb!test`; the JavaScript side and differential tests under Node from jibb-dev | Decided 2026-10-29 |
| Editor support | Tree-sitter grammar | Decided |
| Formatter | One canonical layout | Decided |
| Name | Jibb | Decided |

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
