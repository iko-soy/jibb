# Status

As of 2026-10-31. The plan is [spec/implementation-plan.md](spec/implementation-plan.md); each milestone ends with its checks passing on a fake ship.

| # | Milestone | Status |
| --- | --- | --- |
| 1 | Parser and mark | Done (7c739b7; the doc's grammar decisions of 2026-10-30 in ab797a9) |
| 2 | Types and prelude | In progress. [prompts/milestone-2.md](prompts/milestone-2.md) briefs the developer; the checker and importer are partial |
| 3 | Core language | Not started |
| 4 | Host and static pages: the first release | Not started |
| 5 | Published pages | Not started |
| 6 | Islands | Not started |
| 7 | Tooling | Not started |
| 8 | Polish | Not started |

The plan sets no dates: "agree them after milestone 1, once it shows how fast the Hoon work goes". They haven't been agreed yet. Milestone 1's commits run from 2026-10-29 18:13 UTC to 2026-10-30 11:50 UTC.

On 2026-10-30, @iko decided that Jibb drops `$?`, so a `+$` takes a union's cases on the lines below its name. [prompts/drop-union-rune.md](prompts/drop-union-rune.md) records the change before milestone 2. The repository spec records the decision; the Claude document still needs to be synchronized.

## Milestone 2: in progress

The parser accepts `_` in mold positions and typed path segments, retaining each hole’s span. The partial checker tracks ordinary annotation holes through inference and requires each value or local definition to resolve its own holes before generalization. A hole can resolve to a concrete type or an explicitly written in-scope type variable; later uses cannot fix an unresolved definition. Independent decimal holes can default, but captured variables are not defaulted prematurely. Structural named molds with an unresolved hole report its site. Complex mold forms, inferred path segments, mutual recursive groups and other unsupported constraints still fail closed, and the fragment does not claim the module is checked. A syntax-tree pass rejects duplicate field names within each written record and reports both sites. The repository spec now records that `ask` and `qath` are transparent; complete request checking remains outstanding.

On 2026-10-31, @iko chose explicit, result-directed `(proj record)` to construct a record with exactly the expected fields, and reserved `proj` against definitions and imports. The partial checker handles selected explicit calls with known, closed record types, records field-selection evidence for later lowering, and reserves the name across source bindings. Reordered fields, some nested contexts and several open or recursive cases remain unsupported; lowering and execution are not implemented yet. The field-order question remains open.

The internal prelude also defines `qath` as a transparent recursive knot sequence, re-exported by the public prelude. The partial checker recognizes its source identity, supports selected null/cell construction and matching, and types static application-path literals. Construction and matching for other recursive shapes, broader patterns and dynamic application-path segments remain unsupported. A 256-step limit applies per inference attempt, not to parsing or retries; checking routes and static files remains milestone 4.

The checker also recognizes a limited source-proven generic recursive tree in an import-free defining module. Its opaque identity retains the defining path, mold name and type arguments, including across supported imports and aliases. Construction, pattern matching, unfolding and gate-free proof for this shape remain unsupported; this is not yet the prelude's `element` implementation or island checking. The source index uses fixed-shape checks during mold collection. A single startup-inclusive comparison of 1,000 ordinary gates produced identical reports and used 29.12 seconds of user CPU before the shared-resolver refactor and 28.55 seconds after it, with other work running; it is not a general performance bound.

The internal prelude defines a transparent generic `ask` with pure, agent and store cases, re-exported alongside the Jibb-written `pure` gate. The partial checker infers supported constructors and exhaustive matches. Agent and store receivers operate on raw nouns; their fields do not prove schema validity or watchability. The public prelude now defines the documented source-backed `sub` union; supported `%watch` payloads retain the public `(ask M)` type. Constructing a `sub` does not prove that its request is watchable. Request lowering, checked decoding, runtime validation and island watch checking remain unimplemented.

Known same-origin generic-union result context can now constrain a call before its arguments are inferred. An unresolved or opaque constructor target stays unsupported rather than producing a definite mismatch; proven missing tags still report errors. A todo request with explicit `(ask msg)` context can infer `|=%got`; its uncontextualized form remains unsupported. A two-item literal-headed tuple can receive payload context from a known union of uniquely headed literal cells when its payload is a shallow wing-headed call with literal, wing or constructor arguments. Existing inference takes precedence when it fits; otherwise the checker tries the contextual path once. It conservatively declines that path when any substitution has a structural root, as well as for duplicate or opaque competitors. The guard scans substitutions per eligible tuple and may add one shallow inference; no global linear-time bound is claimed. This allows an explicitly typed todo subscription body to infer, but does not check the island or prove request watchability.

A separate source-backed analysis can prove one named mold gate-free, report a definite gate with a field path, or return unknown. It retains the prepared prelude, source bundle, reader results and resolved imports; the actual todo model proves gate-free, while a callback field reports its path and `*` remains unknown. Its classifier is capped at 256 nodes, not the surrounding parse and import work. API, store and private roots are unsupported, and the artifact does not check a module or island, infer generalized constraints, or prove watchability.

The partial checker can also match a directly named, checked root gate against a generic gate sample in a direct, unshadowed source-backed prelude call. It uses the written two-slot sample layouts to preserve nested record faces, then requires the complete call samples to be closed and tag-free and repeats the fit under the final substitution. The proof falls back to existing inference for unavailable or ambiguous source layouts, local or dynamic gates, aliases, recursive placeholders and open generic caller types. It preserves written-capital checks and projection evidence; it does not add `program`, check islands or prove request watchability. Prepared prelude source and interface remain a trusted pair.

The API path analyzer can retain its source, complete prepared prelude, reader results and resolved dependencies as evidence, and classify a unique declaration as watchable, not watchable or unknown. It does not yet prove the provenance of request values or check island subscriptions. Prepared artifacts and reader results remain trusted host inputs.

For a unique supported path declaration, the request-parts analysis derives ordered typed path parameters, a full-state reply sample and a fold type for one diff mark. Multiple diffs and unsupported or ambiguous evidence fail closed. By itself it does not create request gates or establish watchability of values.

A separate supporting-definition analysis infers supported ordinary API molds and values and resolves all declared marks, retaining their source and dependency evidence. It fails closed on unsupported helpers or marks; unused `/-` cores are not independently validated, and definitions depending on derived gates remain unsupported. This does not check or export the whole API.

Ordinary imports can infer derived request-gate types for multiple supported API paths. A case may take one typed segment before the reply or one diff fold after it; the unchanged todo API's plain, typed and diff requests infer, including a named closed fold. Checked ordinary API definitions, mark molds and a supported poke constructor are exported. Each `/sur` core must have a directly used, successfully read mold; unselected bindings are not independently validated. Jibb module imports, scry paths, multiple parameters or diffs and a parameter together with a fold remain unsupported. Source-qualified request evidence and exact trusted graph inputs survive transitive imports and cached interfaces, while stale or ambiguous evidence fails closed. This is a type-only interface: request execution, schema validation and proof that a request value is watchable remain unimplemented. In one loaded-machine run, the real-todo eval took 195.83 s wall and 67.83 s user CPU; the prior prototype took 111.81 s wall and 64.60 s user. Both include Hoon compilation and reader setup and overlapped other work, so they are not isolated checker benchmarks.

The Hoon reader's tagged-union source proof also handles `$~` default wrappers. A shared eval and ship golden exercises the unmodified Tlon `epic.saga` mold as a named payload in a labeled downstream extension, alongside overlap, recursive, shadow and malformed-wrapper controls. The tagged-source helper peels at most four consecutive defaults; defaults inside dependency proofs spend the existing semantic-node budget. Other unverified nested unions and dependencies remain unsupported.

The repository spec records the subsequent type-system and prelude decisions, including the chosen `like` result-mapping gate; those changes also need synchronization to the Claude document. An initial inference fragment and a standalone Hoon type reader are being tested. The fragment explicitly reports that it does not check a module; partial bridges pass Hoon `*` in supported nonrecursive molds, selected Hoon atoms, term singletons, the null singleton, the two loobean singletons and their exact fork, nested faced or unfaced cells, supported disjoint unions and opaque standard collections from `/sur` molds and marks into inference. Collections retain their names and supported arguments for printing and unification; nested supported union arguments are retained too. The bridge trusts unchanged results from the source-aware reader; a materialized type graph alone cannot reveal cases Hoon already collapsed. The source-validated standard prelude `list` mold shares this representation with imported lists; other Jibb-written collection molds and most prelude collection operations remain unsupported; malformed names and arities fail closed. Selected self-recursive `/sur` molds, including Tlon `notes.import-node` with list-wrapped self references, cross as opaque module-and-name identities; aliases, foreign references, recursive marks, unfolding and construction remain unsupported. The reader handles mark samples, including a source-proved nonrecursive union from a single Ford-imported `/sur` core, recursive molds whose origins can be verified through Ford imports, nested collections, direct ordered maps, including source-validated named operands such as Tlon `notes.log`, certain ordered-map fields, direct `$^` unions whose cases can be proved disjoint, and one verified explicit union argument in a list, set, map or unit. Tagged `$%` cases can additionally use restricted local named payload molds, bare `~` fields and one level of local named tagged unions, as in real Tlon `notes`, with bounded source proof; unsupported or ambiguous dependencies fail closed. Ambiguous recursive origins fail closed; recognizable explicit unions are checked from source before Hoon can collapse their cases, as @iko confirmed for imported `$%`, `$?` and `$^`, while other nested unions, nested ordered maps, general union disjointness and complete import integration remain unfinished. Opt-in structured reader APIs preserve successful graphs and distinguish definite unsupported-aura and core evidence from failures the reader cannot prove; unverified union disjointness and name-only vase recognition remain unsupported. They revalidate and re-walk failed types. An opt-in partial checker entry point consumes unchanged reader results and reports definite aura or core errors at imported mold use sites when their inputs are unique. Ordered replay covers nested cell samples, record and function casts, and non-generic same-module aliases; unsupported prefixes, cycles and shadowing stop it. Union molds, generic applications, transitive modules and unsupported reader outcomes remain generic. Replay repeats inference and may add work. The partial checker resolves a subset of ordinary library imports in dependency order using supplied Jibb sources and a source-derived partial prelude interface, caches completed interfaces per run, detects missing sources and cycles, and resolves nested fields of imported values with independent scheme instantiation. The source-backed internal prelude defines `poke` and the public prelude re-exports it as a transparent type. A dedicated trusted preparation path supplies private comparison and arithmetic schemes to the Jibb-written `gth`, `add` and `dec` wrappers; ordinary imports cannot access them. The public `add` and `dec` wrappers use private arithmetic interfaces; supported inference preserves the shared atom constraint that excludes loobeans. Primitive execution, jet recognition and length remain unfinished. The partial checker resolves its supported source shape and rejects ordinary imports of the private path. An imported API with one mark and a matching direct `+$ poke` declaration can export a constructor and retain agent/mark metadata when the representation has the supported agent case. A separate partial analysis resolves supported API path declarations and their full and diff mark types, including the todo paths; it does not by itself create requests or check an API module. Ordinary imports additionally infer the supported multi-path request-gate types described above. Complete private module checking, other API shapes, request lowering, root API and kind checking, stores, complete `ask` and `pure` checking and runtime effects remain unfinished. A possible store or root API with `+$ poke` reports unsupported kind or scope, while definite duplicates and unrelated shadowing still report conflicts. The prelude includes the doc-exact generic `cmd` union; the prelude inventory is incomplete. The inference fragment supports unrestricted `@`, selected one-way widenings including aura-family ancestors, generalized atom constraints arising from explicit capitals or bare sample binders, acyclic local value definitions with captures, selected single self-recursive top-level and local gates, simple and nonrecursive generic mold aliases, selected faced record casts and field reads, and contextual tags, `~` and constructors for closed disjoint unions, including direct nonrecursive generic unions and propagation through complete loobean and unit-shaped branches in casts and known union-sample calls, including nested branches. Known loobean result context also propagates through supported complete branches and binder-only cell arms; binder-only arms over union subjects remain unsupported. A directly known named union can instantiate an unconstrained generic gate sample with its origin, generic arguments and faces preserved; unnamed, pending, recursive and variable-bound cases remain unsupported. A known gate with an unresolved result variable can receive a known enclosing result type before its arguments are inferred; unknown calls and unresolved targets remain conservative. Multi-argument calls form a right-nested sample, retain known faces and shared type variables, and can use known sample positions to contextualize list and union arguments. A definite mismatch points to the failing argument when the fragment can establish it, otherwise to the combined sample; unsupported contextual forms still fail closed. For a supported recursive gate, the checker infers the sample first and uses its exact type, including field faces, for one monomorphic self reference. It generalizes after the body is checked; subsequent uses instantiate it independently. Incompatible recursive arguments can report the gate and argument sites. For a complete loobean branch with one direct self-call arm, a separately inferred closed base type can seed the recursive result before the whole body is checked. Open or pending base types do not seed it; other branch shapes remain subject to the fragment’s existing limits. A supported single local recursive gate also uses a monomorphic self reference and generalizes variables free of the enclosing environment after checking its body; captured variables remain shared. The checker collects written capitals per `++` before inference, excluding nested definitions: a capital used in an enclosing definition is shared with its locals even when written later, while a capital introduced only in a local definition is generalized there. Sibling locals can introduce independent capitals with the same spelling; generic mold parameters keep their own scope. Top-level groups of syntactic gates are inferred together with monomorphic placeholders and shared substitutions, then generalized only after the whole group checks; downstream uses and library interfaces instantiate those schemes independently. A dependency graph identifies groups with two iterative depth-first passes; its conservative local-reference edges can reject otherwise valid programs. Supported local mutually recursive gate groups also use shared monomorphic placeholders and generalize only after the group checks, preserving captured outer variables. A bounded dependency proof reports certain non-gate cycles through values and gates when an explicit atom or loobean result cast and simple unshadowed expressions establish the cycle. Other mixed gate/value cycles, polymorphic recursion, unresolved literal constraints and unresolved branch joins remain unsupported. Reporting repeats inference for a single recursive gate outside a group; grouped reports use the stored schemes. Its performance cost remains unmeasured. A single-arm cell pattern accepts two or more binders, the last capturing the remaining tail; duplicate and shadowed binders are rejected. A structured single-arm pattern also works for a known non-union cell when coverage is proven, including nested literal and wildcard positions. Intermediate union or collection tails, nested patterns, wildcards and faced records remain unsupported. String interpolation accepts known atom auras, unrestricted `@`, tapes and isolated decimal literals; a known cell asks for a printer, and an explicitly generic atom asks for an aura. Loobeans, term singletons, non-tape collections, open types and a type fixed only later remain unsupported. A known closed union with two or more arms supports patterns that provably cover or exclude each remaining case, including payload binders, imported and generic cases, and binder-free catch-alls. Partial boolean patterns can split known `?` positions into their two noun values, up to 64 alternatives across the union; binders retain their original case type. Missing alternatives and covered arms are reported. Other partial patterns, expansions above the limit, binders spanning distinct cases, differing arm result types and some complex two-arm subjects remain unsupported. A cast or known call sample can supply result context through whole-case arms and supported finite loobean refinements for a known union accessed by a wing, a grouped wing or a supported shallow call, including nested cell and list positions; other partial-pattern contexts and subject forms remain unsupported. The Grammar’s `step` block infers in this fragment, but its module is not yet checked. A bare tag proved absent from a known union reports the union and tag sites in casts, single-argument calls, unit payloads, list items and supported branch arms; imported unnamed unions print their cases. Ordered fit replay can identify a missing tag nested in a syntactic tuple, stopping at an earlier mismatch or uncertainty. Known faced records support uniquely named field changes, including nested wings, with field context passed to replacements and the original record type retained. Missing fields, empty changes and definite mismatches report sites; the expected-type site is the edit because the original field declaration location is not retained. Unknown or partly unfaced spines, ambiguous fields and repeated edits remain unsupported. A known record cast supplies field context to its tuple or record initializer, including nested list and union fields; mismatch diagnostics use the cast mold because the original field declaration location is not retained. Isolated cart-style `init` and `update` expressions infer, while the complete cart-store fails closed because its kind and declaration scope remain unchecked. Uncontextualized list literals infer a fresh element type, including empty and nested lists, with independently generalized uses. Unresolved item tags and uncertain widening remain unsupported. Backtick unit construction uses the validated standard prelude unit template, infers its payload without losing pending constraints, and makes the prelude’s `some` available. Ordinary result annotations also let its `bind`, `biff`, `both`, `clap`, `clef` and `flit` infer. A known unit in a cast, call, list item or record field supplies context to its payload, including nested units and lists; mismatches identify the payload and context. Unrelated union identities, some variable-dependent fits, and missing or altered prelude unit templates remain unsupported. Literal singleton heads compare by runtime noun, so `|=%$` also matches explicit null- and loobean-zero-headed cases. When equal heads have disjoint payloads, the constructor selects a uniquely proven compatible payload; unknown and ambiguous candidates remain unsupported. Unresolved nulls remain pending and are reported separately from tags. A known union of `~` and a null-headed cell supports a complete `~` / `[~ value]` branch in either order, including shadow checks; unknown subjects, missing or duplicate arms, and unresolved branch results remain unsupported. This fragment infers the prelude’s `fall` and `need` signatures. With the validated prelude list and a known cast or gate sample, empty, nonempty and nested list literals infer their element types, including contextual union tags; a mismatched element names both sites. In that context `~` and zero-valued terms fit an empty list, and two-item unfaced cells form cons lists, including nested cons and imported-list contexts; invalid heads or tails name both sites. A known gate sample also supplies context to matching positions in a single tuple or record argument, including nested cells; zero literals can fit list positions. A bound zero constant remains unsupported rather than a definite mismatch, and an unknown callee does not supply context. Faced or longer cells and a missing or altered prelude list fail closed. A known list result also supplies context through complete loobean, unit-shaped and list-shaped branches, including recursive and nested branches. For a known standard list with a supported element type, a complete `~` / `[item rest]` branch infers the element and tail types in either arm order and checks binders for shadowing. Unknown subjects, unsupported element types and other or incomplete list patterns remain unsupported. A value with type variable `A` can fit a field whose type is that same `A`, including in generic union payloads and nested or repeated record fields. Other variable-dependent face merges remain unsupported. Forced equality of distinct written capitals now reports both source sites, following @iko’s decision; forcing one to a concrete type remains unsupported. Imported record spines with repeated faces fail closed where used, but only with a generic unsupported diagnostic. Hoon may erase unfaced nested-cell boundaries, so the check can conservatively reject valid names in distinct erased scopes. Supported closed unions print using an in-scope name or imported alias; an unnamed nongeneric union prints its cases, parenthesized when nested. The latter is print-only. Generic union types retain all arguments in their printed name; if that name is unavailable, the partial printer reports the limitation. Different import faces for the same origin remain compatible; compatibility across distinct union origins and some generic-argument comparisons remain unsupported. Nonrecursive generic aliases can reorder, repeat or omit parameters while retaining a union’s origin, including through local scopes and library interfaces. A generic union declared directly inside a body remains unsupported, as do differing-variable face constraints in a union payload. A transitive generic union whose name is unavailable is reported as unsupported instead of hiding its arguments. Unfixed decimal literals default to `@ud` in gate-free inferred types; recursive molds, general branch tag context, other constraint cases and defaulting inside gate types still need work. Collection recognition checks the originating core and fails closed on shadows or unsupported Ford subject shapes; a wrapper regression also rejects forged subjects, samples and tails. Its golden fixtures include three real Tlon files. A Clay test passes a Ford-built nested union through the reader into partial inference. The partial prelude includes `murn`, `join`, `snip`, `rear` and the agreed shared-type `clap`; supported calls infer, while backend validation remains outstanding, and [prelude-inventory.md](prelude-inventory.md) is a source audit, not the complete inventory or signatures. The milestone remains unfinished.

The shared prelude interface reserves every name present in the supplied vendored source and makes only supported inferred entries available, including `list`, `unit`, `same`, `fall`, `need`, `bond`, `lure`, `weld`, `snoc`, `turn` and `lent`. The validated standard `list` mold is injected when the prelude’s own gates are inferred; `weld` and `turn` have ordinary explicit result casts. An absent or altered `list` is not injected, and an altered declaration cannot leak through direct or transitive mold aliases. The same validated template is available when prelude mold aliases are prepared, so supported direct and transitive aliases can use it. Unsupported entries such as most list helpers remain reserved but unavailable; backend validation of the helpers remains outstanding. All callers use the same prelude origin, so a library can export a type containing unqualified `(unit A)` to another module. The source-only `+prepare-prelude` rejects empty, malformed, conflicting or import-bearing source; `+prepare-prelude-with-internal` also accepts the supported private internal import. Prepared values are trusted and must come unchanged from the matching preparation arm. When canonical public list or unit templates are missing or altered, independently inferred private molds remain available, while molds that depend on those templates do not. The module-scope fixture compares the prepared and source-taking paths against the real prelude and a two-module golden under eval and on the ship. The source and checker remain incomplete, so this does not establish complete shadowing coverage or a checked module.

The prelude also has a Jibb-written `zing` that concatenates homogeneous lists via `weld`. Its focused golden infers empty, nested text, ship, generic and gate-element lists and reports a non-list error; the same golden passes on the ship. A Hoon translation agrees with Hoon `zing` on selected finite inputs, not on Jibb execution. Hoon’s raw helper additionally accepts heterogeneous noun lists, which the Jibb signature does not express. Backend lowering and jet recognition remain unverified.

An eval and ship fixture now reports partial inference for the unchanged todo island with its real API and Hoon readers. It verifies that the source fixtures match `my-app` and exercises missing or duplicate imports; the report does not claim the module or island has been checked. The prelude also has a Jibb-written recursive `lent` whose supported generic calls infer `@ud`. Execution and shape-based jet recognition remain future backend work. Nested union tests check equal runtime nouns, different nested tags, empty fields and unknown inhabitation.

The prelude now writes `lth`, `gte` and `lte` in Jibb using `gth` and `not`. Supported generic and concrete calls infer, including loobeans; mismatched explicit auras fail. Execution, jet recognition and complete import checking remain unfinished.

The Hoon reader can prove overlaps among supported original `$?` source cases, including nested cells and unions with more than two cases, and report them at a Jibb use site. It evaluates each case independently and compares runtime noun values. Other overlaps, Hoon case locations and mark-reader overlap diagnostics remain unfinished. The source screen allows at most 128 cases and 4,096 source noun nodes; dependency checking and pairwise witness analysis each have a separate 4,096-node budget. These budgets do not bound chapter lookup, Hoon evaluation or graph walks.

Restricted-number promotion now skips an environment scan when a definition has no written capitals. In a single startup-inclusive pair on 2,000 independent gates, output was identical and user CPU fell from 71.67 to 38.26 seconds; wall time was 72.80 versus 51.66 seconds with other checks running. This is a partial-inference measurement, not a complete checker or a bound on dependent modules.

## Milestone 1: parser and mark

What the plan asks for, and where it is:

| The plan | Where |
| --- | --- |
| The `%jibb` mark as the first tab gives it | `jibb-dev/mar/jibb.hoon`, as the doc writes it |
| The layout pass, emitting INDENT, DEDENT and NEWLINE | `+layout` in `jibb-dev/lib/jibb.hoon`, designed in its section 2 |
| A parser for the Grammar tab's EBNF that returns a syntax tree with source positions | `+parse` and `+parse-tokens`, section 3. Every node has a span, its start and end, and `+check-spans` tests the spans of every tree the golden tests print |
| Errors with file, line, column and an excerpt | `+show-error`, section 4.3. Each error points at the first character where the text stops being the start of any valid module (section 2.0) |
| Done when every Jibb code block in the doc parses | The doc labels its 14 Jibb blocks `jibb`. Each is a golden case, `tests/golden/doc-*`, and `tools/doc-blocks docs/spec` checks that they match. All parse; the one block written as an error, the Grammar's buttons example, has a type error for milestone 2 |
| Done when each lexical rule has a test input that breaks it | The `lex-*` golden cases: for each lexical rule, inputs that break it (`-bad-`), each with the error's expected place, and inputs that keep it (`-ok-`), except for the forms Jibb leaves out (the closers, blob and `@c` literals) |
| Done when `\|commit` stores `.jibb` files on a fake ship | `tools/ship check-commit`: 7 checks, from reading every file back byte for byte to three-way merges |

Besides the plan's list:

- 653 golden cases: 433 that parse and 220 that fail, each failure at a stated line and column. One failing case has an unclear expectation (corpus question 3). The newer type-output cases exercise only the partial inference fragment. Each case's `about.txt` quotes the doc's words it tests.
- The 653-case corpus passed under `urbit eval` in 107.5 s while other checks were running. The fake ship passed all 688 tests, including the source-overlap, structural-overlap and generic-recursion fixtures, importer, importer/checker and mark/checker bridges, module scope, unification, hole, qath, ask, default-wrapper importer, projection, arithmetic, generic-alias, positional-face, API-evidence, request, closed-gate, todo API, constructor, sub, nested-union, gate-free and direct-gate guards and the unchanged todo report. Desk sync took 94.5 s while other checks were running. The importer golden compares 221 projections; `tools/clay-fixtures` builds the example Hoon fixtures through Clay, checks a recursive Ford import's origin, and passes Clay-built types through the Clay-built importer and partial checker.
- `tools/testdata/selftest` (22 checks), `tools/testdata/ship-selftest` and `tools/testdata/clay-fixtures-selftest` test the tools themselves; the last checks temporary Clay fixture cleanup and signal handling without a ship.
- Two independent audits before 7c739b7, one of which compared the library with a reference parser written in Python from the doc over about 19,000 generated programs. Before ab797a9, a second Python parser, written from the decisions, agreed with the library on 8,000 generated programs and 900 hand-written probes.
- Speed: starting `urbit eval` and building the library takes about 8 s. After that, a 2,000-line module of 400 definitions parses in about a second. Loops over definitions, arms, lines and items grow no stack; nesting costs a few stack frames a level, and 100,000 nested brackets still parse (library section 3).

### History

| Commit | Date | What |
| --- | --- | --- |
| 1cb51df | 2026-10-29 | Foundation: the parser's design, the tools, the desks, the vendored base-dev and landscape files, the golden corpus |
| 15a5545 | 2026-10-29 | The layout pass |
| 3c5f50a | 2026-10-29 | The parser |
| 7c739b7 | 2026-10-30 | Fixes from two independent audits; milestone 1 done |
| 5a4aa73 | 2026-10-30 | `tools/doc-blocks`, after the doc labelled its Jibb blocks |
| ab797a9 | 2026-10-30 | The 12 grammar decisions of 2026-10-30: four changed the parser, eight confirmed it |
| aad6ddb | 2026-10-30 | Drop `$?`; `+$` takes union cases below its name |
| 1dd92a6 | 2026-10-30 | Begin type inference and Hoon imports |
| 51ce4d9 | 2026-10-30 | Extend partial inference and importer, record type and prelude decisions |
| be6d2a5 | 2026-10-30 | Add atom widening, nested collections and case-local Hoon import fixtures |
| 26554ac | 2026-10-30 | Infer an atom constraint, extend the prelude and read example molds through Clay |
| fbeaa83 | 2026-10-30 | Extend atom constraints and nested ordered-map imports; connect Clay types to partial inference |
| 47a1f49 | 2026-10-30 | Read validated Ford imports, widen aura families, and show both sites of selected errors |
| bd37989 | 2026-10-30 | Read mark samples and test partial mark imports; reject unproven nested `$^`; preserve atom constraints through aliases |
| 2d5deb2 | 2026-10-30 | Default gate-free decimal types, validate named Hoon mold lookup, and isolate fixture failures |
| 1b7dbae | 2026-10-30 | Infer acyclic local definitions and parse case-local Jibb module fixtures |
| 8b9c9ac | 2026-10-30 | Preserve recursive import origins, infer simple local molds, and supply Jibb module sources to the partial checker |
| 529736a | 2026-10-30 | Infer supported library import graphs and guard nested Hoon `$^` in collections |
| 8bf1b12 | 2026-10-30 | Infer selected record faces and check nested `$^` in static Hoon records |
| d8ac47d | 2026-10-30 | Cache library interfaces, preserve imported Hoon record faces, and check nested tagged unions |
| edd9277 | 2026-10-30 | Infer nonrecursive generic mold aliases with lexical parameters |
| 4406f6f | 2026-10-30 | Resolve selected contextual tags and check explicit imported unions |
| 5c73614 | 2026-10-30 | Print supported named and escaping union types |
| 0070584 | 2026-10-30 | Propagate union context through loobean branches, read selected unions in Hoon collections, and add `flit` |
| 250564c | 2026-10-30 | Infer selected named generic unions, test Hoon collection wrappers, and add list helpers |
| e95ef8f | 2026-10-30 | Bridge selected Hoon unions into partial inference and support generic union aliases |
| 56a899f | 2026-10-30 | Infer matching variable types in faced fields and bridge opaque Hoon collections |
| 4d45d2f | 2026-10-30 | Resolve selected contextual null literals |
| e878edc | 2026-10-30 | Infer complete unit-shaped branches and bridge selected recursive Hoon molds |
| 743dfd8 | 2026-10-30 | Propagate union context through unit-shaped branches |
| 3f90fa8 | 2026-10-30 | Share a partial prelude interface across module inference |
| 29bd39f | 2026-10-30 | Infer contextual list literals and validate prelude parity |
| a2a6ef5 | 2026-10-30 | Infer complete list-shaped branches |
| 671fe72 | 2026-10-30 | Infer contextual list nulls and cons cells |
| 7e69436 | 2026-10-30 | Infer selected self-recursive gates |
| 9ab52e8 | 2026-10-30 | Infer recursive branches with closed base types |
| d782b45 | 2026-10-30 | Propagate list context and apply settled type decisions |
| c7082e0 | 2026-10-30 | Infer multi-argument calls |
| 918acbd | 2026-10-30 | Infer recursive gates from their samples first |
| 1470d18 | 2026-10-30 | Infer selected prelude list helpers |
| 10cbf9c | 2026-10-30 | Infer selected local recursive gates and distinguish reader diagnostics |
| 45afb13 | 2026-10-30 | Infer local capital scopes and report direct reader diagnostics |
| 054e651 | 2026-10-30 | Report nested reader diagnostics |
| 98c19cd | 2026-10-30 | Infer known-aura string interpolation |
| ddba633 | 2026-10-30 | Infer top-level mutually recursive gates |
| 9f1517e | 2026-10-30 | Infer whole-case union patterns and prelude `turn` |
| 9dd35c8 | 2026-10-31 | Match finite boolean refinements of union cases |
| 54852d4 | 2026-10-31 | Contextualize tuple calls and infer known record changes |
| 0bc5113 | 2026-10-31 | Contextualize record initializers and infer unit construction |
| 264a436 | 2026-10-31 | Contextualize unit payloads in casts, calls and nested values |
| a140383 | 2026-10-31 | Report missing union tags and infer prelude unit helpers |
| d69cc52 | 2026-10-31 | Infer longer cell binder patterns and prelude unit helpers |
| ae35005 | 2026-10-31 | Import source-verified tagged Hoon unions |
| c8f894a | 2026-10-31 | Report nested missing tags and contextualize union branch results |
| ef2ea71 | 2026-10-31 | Import Hoon null singleton cases |
| 67f900e | 2026-10-31 | Infer local mutual gates and uncontextualized lists |
| 7ff15f1 | 2026-10-31 | Contextualize finite union patterns and record the initial poke decision |
| c790a9f | 2026-10-31 | Expose transparent `poke` from the internal prelude |
| ef4772a | 2026-10-31 | Bridge imported loobeans and loobean singletons |
| ad46655 | 2026-10-31 | Bridge selected imported any-noun molds |
| beada10 | 2026-10-31 | Import source-proved Ford mark unions, analyze API paths and infer list helpers |
| e28f7be | 2026-10-31 | Diagnose proven non-gate cycles and import Tlon null-payload union cases |
| fd2f288 | 2026-10-31 | Infer qualified fields of imported values |
| ed9291e | 2026-10-31 | Infer term-headed pairs and function helpers, and import nested named unions |
| ad0265e | 2026-10-31 | Infer proven single-case patterns and the prelude command union |
| 413b12b | 2026-10-31 | Propagate known result context into generic calls and batch ship deletions |
| c690076 | 2026-10-31 | Propagate loobean context, infer predicate helpers, and import named ordered-map operands |
| 0bf6178 | 2026-10-31 | Bridge recursive Tlon lists and prepare a private comparison interface |
| 4e472b5 | 2026-10-31 | Pass known named unions through polymorphic gates |
| e3e184f | 2026-10-31 | Parse type holes, reject duplicate written record fields, and extend partial union inference and imports |
| 80e221a | 2026-10-31 | Infer supported annotation holes and prelude list aliases |
| ba1fec4 | 2026-10-31 | Add the curried `bond` prelude gate |
| 0ea700d | 2026-10-31 | Infer a source-defined recursive `qath` subset and record the explicit `proj` decision |
| 75f5952 | 2026-10-31 | Check a subset of explicit `proj` calls and retain their lowering evidence |
| cf17925 | 2026-10-31 | Infer supported single-field projections |
| 1a891e2 | 2026-10-31 | Infer source-backed addition and decrement without loobean operands; record the watchability decision |
| 81af5fd | 2026-10-31 | Preserve public names of identity-generic union aliases and record the `like` decision |
| 640a442 | 2026-10-31 | Add the source-backed `like` result mapper and infer supported positional calls |
| 445a0a1 | 2026-10-31 | Retain source-backed API path evidence and classify declarations |
| f69493d | 2026-10-31 | Derive supported request components from API declarations |
| f0f6954 | 2026-10-31 | Analyze supported API helper definitions and declared marks |
| 3f55af7 | 2026-10-31 | Define source-backed transparent ask and pure |
| ae1ec26 | 2026-10-31 | Prove selected default-wrapped Hoon unions from source |
| dde791c | 2026-10-31 | Infer a source-backed request-gate type through ordinary imports |
| a1c5f35 | 2026-10-31 | Infer supported multi-path requests and named closed folds |
| 911ca0c | 2026-10-31 | Propagate union context, define subscriptions and match literal nouns |
| 72acdb3 | 2026-10-31 | Infer selected nested union payloads from context |
| 706035c | 2026-10-31 | Analyze gate-free source molds with field witnesses |
| 651b8ec | 2026-10-31 | Match source-proven gate samples in direct calls |
| cc8e389 | 2026-10-31 | Add source-backed list length and real todo regression |
| 4da6891 | 2026-10-31 | Add source-backed comparisons and nested Hoon union controls |
| 09db390 | 2026-10-31 | Skip unnecessary inference environment scans |
| 179d717 | 2026-10-31 | Diagnose source-proven Hoon union overlaps |
| 142f2e2 | 2026-10-31 | Prove structural overlaps across Hoon union cases |
| c96597d | 2026-10-31 | Track source-proven generic recursive identities |
| This change | 2026-10-31 | Add source-backed list flattening |

## Checking it

On a machine set up as [development.md](development.md) says:

```
tools/golden                      # 653 cases under urbit eval
tools/importer-test               # the Hoon importer fixture projection
tools/type-import-default-test    # default-wrapped source proof golden
tools/type-import-test            # the importer/checker bridge fixture
tools/type-import-overlap-test    # source-aware Hoon overlap and provenance fixture
tools/type-import-structural-test # structural overlap and multi-case source fixture
tools/type-tlon-test              # the real Tlon reader/checker fixture
tools/type-mark-test              # the mark/checker bridge fixture
tools/type-poke-test              # the source-backed poke/API fixture
tools/type-api-evidence-test      # API declaration evidence guards
tools/type-api-paths-test         # partial API path metadata fixture
tools/type-hole-guards-test       # hole defaulting and API interface guards
tools/type-list-alias-test        # prelude list-alias guards
tools/type-generic-alias-test     # generic union alias guards
tools/type-generic-recursion-test # source-proven generic recursion guards
tools/type-positional-face-guards-test # positional sample face guards
tools/type-qath-guards-test       # qath source and unfolding guards
tools/type-ask-guards-test        # ask source and bootstrap guards
tools/type-proj-guards-test       # projection evidence and scope guards
tools/type-module-scope-test      # module and prelude scope fixture
tools/hoon check-spans-test       # prints <<>> when the span checker works
tools/testdata/selftest           # the tools themselves
tools/doc-blocks docs/spec        # the doc's examples are golden cases
tools/ship start
tools/ship gen-tests --check      # tests/lib/jibb.hoon is up to date
tools/ship test                   # the same 653 cases as -test arms on the ship
tools/testdata/ship-selftest
tools/testdata/clay-fixtures-selftest # scratch fixture cleanup without a ship
tools/ship check-commit           # |commit stores .jibb files
tools/clay-fixtures               # example /sur files and marks build through Clay
```

## What milestone 1 leaves to later milestones

- Errors carry a start only. Spans keep each node's end so that milestone 2's type errors can underline both conflicting sites with excerpts (library section 1).
- The parser accepts forms for the checker to judge: `[]`, `[a]`, `m()`, `!! a`, and the module kinds. `[]` and `m()` have since been decided to be errors, and `[a]` is `a`; the parser has not changed. The Grammar's buttons example parses, though the doc marks it as a type error.
- Grammar questions the doc's author hasn't been asked follow the readings in [open-questions.md](open-questions.md).
