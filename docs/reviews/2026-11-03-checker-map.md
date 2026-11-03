# The checker on 2026-11-03, and what a general core replaces

A map of the type checker in `jibb-dev/lib/jibb.hoon`, written for whoever builds the general checker core that [review question 5](2026-11-02-questions.md) chose. It was written by the thread that fixed the [2026-11-02 review](2026-11-02-repo-review.md)'s findings, by reading the code; nothing in it was run. Claims about which tests would fail come from the tests' fixtures, their direct `name:jibb` references, and the code paths.

Line numbers without a file are `jibb-dev/lib/jibb.hoon` at commit [`f84a29e`](https://github.com/iko-soy/jibb/blob/f84a29e/jibb-dev/lib/jibb.hoon) (15,838 lines). The syntax changes of 2026-11-03 (`f22d19d` and before: `unface`, S2, S4 to S7) moved them by up to about 800 lines and added `+itype-unface`, `+reserved-name`, `+unfaced-gate` and named type variables kept in the bits of a variable's ID (`+named-var`, `+var-name`), which this map doesn't cover. Find an arm by its name, not its number. Review finding numbers (A1 to A137) come from [the review](2026-11-02-repo-review.md), whose own line numbers are pinned to `4bf477e`.

Review Q5 (`docs/reviews/2026-11-02-questions.md:43-49`) was answered (a): *"Build the general core
first: union-find bindings with levels, a deferred-constraint queue and Maranget's usefulness check,
with `main = (program …)` checked as an ordinary application."* Q6 (l.51-56, one golden pipeline),
Q11 (l.88, one branch-join rule) and Q12 (l.95, dependency-order pass) were also chosen.

## 0. Numbers

| Thing | Value |
| --- | --- |
| `%type-inference` chapter | 4601-10901 (325 arms) |
| `%union-analysis` chapter | 10902-15838 (224 arms). Despite its name it holds union analysis (10902-11302), the module checker, API derivation, program/store recovery, the report and the dg-* transaction (A131) |
| Arms and types from 4601 on | 549 `++` arms, 91 `+$` types |
| `itype` | 22 cases (4663-4686), six of them variable kinds plus `%tag` |
| `istate` | 27 positional fields (5996); built as a positional literal at 10 sites (10699, 10752, 11986, 12001, 12057, 12735, 12769, 14759, 14924, 15107) and bunted at 5 (14497, 14550, 14566, 15610, 15652) |
| Program/store/page/static recovery and kind code | 13146-14648 (1,503 lines) |
| dg-* deferred transaction | 15147-15719 (573 lines) |
| Direct gate-layout evidence | 9002-9228 (227 lines) |
| Lines saying "unsupported" or "not supported" | 283 |
| Golden cases | 690 in `tests/golden`; 304 have `types.txt`, every one of which starts `partial inference; module not checked`; 177 of those also have `modules.txt` (module-check mode, prepared prelude); 127 of the 304 contain an "unsupported"/"not supported" line |
| Suites | 58 files in `tests/lib` (the 57 checker-related suites of the brief plus `jibb-check-spans`/`jibb-hoon-reference`, which are not checker tests); they reference 125 distinct `jibb.hoon` arms and 55 types by `name:jibb` |
| Call sites | `itype-fit` 59 (22 in 13311-14648), `itype-unify` 43, `itype-normalize` 95 (20 in program/store, 7 in dg), `instantiate-scheme` 17 (12 in program/store), `itype-merge-faces` 13 (12 in program/store), `direct-invariant` 19 (16 in program/store), `template-apply` 22 (15 in program/store), `add-supported-result` 7 (6 in program/store) |

## 1. The checker as it is

### 1.1 Data types

| Type | Line | Shape | Role and quirks |
| --- | --- | --- | --- |
| `itype` | 4663 | `%var %fvar %avar %rvar %nvar %rnvar` (one id space), `%atom aura`, `%any-atom` (bare `@`), `%flag`, `%noun`, `%empty`, `%tag [id literal constructor=?]`, `%const literal`, `%collection [name args]`, `%recursive [module name label]`, `%jrec [at name label head aura tail]`, `%grec [at name label proof=shape args]`, `%union [cases origin label args]`, `%face [name body]`, `%fn [sample product]`, `%cell [hed tal]` | The whole type language. `%var` unconstrained; `%fvar` gate-free; `%avar` any atom incl. `?` and `@`; `%rvar` atom other than `?` (arithmetic); `%nvar` decimal literal, defaults to `@ud`; `%rnvar` both. `%tag` is a pending literal resolved by binding its id. Faces and display labels live inside the type, so relabelling changes equality (A11). `%collection` is opaque except list/unit (A13). Three recursive representations (`%recursive` imported, `%jrec` qath-shaped, `%grec` test tree) |
| `ibinding`, `isub` | 4687-4688 | `(list [id val])` | Substitution as an association list; first entry wins; entries only prepended; no path compression. Kind refinement is encoded as a self-binding (`[n -> %fvar n]`, `[n -> %rvar n]`, `[n -> %rnvar n]`) |
| `ipending` | 4689 | `[id literal at]` | One per `%term`/`%null` literal or `%ctor` tag (created 8780, 8781, 8848) in `istate.tags` |
| `igf-form(s)` | 4942-4943 | `[typ sub left]` | Gate-free conversion result with fuel |
| `ifit` | 5019 | `%ok [sub next]` / `%bad` / `%unknown` | Three-valued directional fit. `%unknown` is the universal fail-closed answer |
| `ischeme`, `ienv`, `imold-types` | 5804-5806 | `[typ vars=(list @ud)]`; `(list [name scheme])`; `(list [name template])` | Schemes with raw (not canonical) quantified ids; environment is newest-first, linear `ienv-lookup` (6001) |
| `iderived`, `iwidth-definition`, `iwidth-dependency` | 5807-5809 | | Derived poke constructors; `proj` elaboration evidence (carries the raw `sub`, 10687) |
| `irequest-evidence`, `istore-request-evidence`, `irequest-graph` | 5812, 5816, 5820 | | Source-bound API/store request certificates and the trusted closure inputs |
| `ifile` | 5822 | `[values molds at derived elaborations dependencies source graph]` | Checked module interface; `graph ~` = detached legacy/prelude file |
| `ijimports`, `icap(s)`, `iparams`, `imolds`, `iexternals`, `imark-externals`, `ihole` | 5823-5834 | | Imports in scope; written capitals with their var ids; generic params; local mold shapes; raw importer nouns; type holes (created 7103) |
| `iwfield(s)`, `iwstep`, `iwidth-result`, `iwprojection` | 5839-5843 | | Record-spine scan and `proj` plan |
| `igf-segment`, `igate-free` | 5931, 5938 | `[verdict=?(%yes %no %unknown) inhabited left path]` | Gate-free proof with witness path |
| `igate-prelude-evidence` | 5994 | `[iface gates=(map term def)]` | Re-parsed prelude gate defs for direct-gate recovery |
| `dgo` | 5995 | `[left right at context]` | Deferred fit obligation (dg-* only) |
| `istate` | 5996 | `next sub caps binders molds globals externals surs mark-externals marks jimports reserved-molds params active tags in-mold at top-molds prelude holes jrec-fuel projections gate-defs head-evidence grec-index defer obligations` | Threaded functional state. `next` restarts at 0 per top-level definition. Recovery-only fields: `jrec-fuel`, `gate-defs`, `head-evidence`, `grec-index`, `defer`, `obligations` |
| `idiag`, `iresult`, `isample-result` | 5997-5999 | `[msg sites]`; `(each [typ state] idiag)`; `(each [typ env state] tape)` | A diag with no sites is "unsupported"/retryable (`definite-diag` 7521) |
| `irec-pattern` | 6416 | `[pat=upat has=?]` | Imported recursive fork proof |
| `ilocal-result` | 7306 | `(each [env state] idiag)` | Locals and groups |
| `icap-site` | 7377 | `[name at]` | Written capital occurrence |
| `imatch`, `ifinite` | 8106, 8170 | `?(%full %none %unknown)`; `[origin base part]` | Pattern-vs-case classifier; finite loobean refinement row |
| `itag-presence` | 8661 | `?(%yes %no %maybe)` | Missing-tag diagnosis |
| `iwidth-elaboration` | 8994 | | Dead (only the dead `infer-width-elaboration`) |
| `igate-entry`, `igate-seeds` | 10433-10434 | | Recursive-group seeds |
| `iresolved` | 10552 | `[env grouped artifacts]` | Resolver output threaded by the recovery chain |
| `iadj ivisited iwork iwresult icresult icomponents` | 10553-10558 | | Kosaraju state |
| `iadded-definition` | 10668 | `[env checked artifacts]` | `add-supported-result` output |
| `icyclesite`, `icycle` | 10788-10789 | | Value-cycle proof |
| `upat`, `urelation`, `upair` | 10909, 10919, 10920 | `%unknown %all %empty [%atom (unit @)] %flag [%cell] [%or]`; `?(%disjoint %overlap %unknown)`; `[first second relation]` | Noun-shape projection for disjointness/overlap (also used by the importer at 6463, 6645) |
| `uow-case` | 11191 | | Source overlap witness case |
| `jsource jbundle jcache jfile-result jfile-overlap jfile-failure jfile-detailed-result jimports(-detailed)-result` | 11507-11518 | | Module sources, per-invocation cache, results with structured overlap evidence |
| `written-fields` | 11521 | `(map term span)` | Duplicate-field scope |
| `imold-failure` | 11777 | `[message overlap=(unit [name upair])]` | First failing mold |
| `iprelude` | 12090 | `[iface values molds]` | Prepared prelude; values/molds reserve every declared name |
| `iapi-*` | 12328-12706 | | API path/request/support evidence |
| `ione-request-interface`, `imulti-request-gates` | 12780, 13043 | | API constructors |
| `istore-declaration` | 13242 | `[action=term defs]` | Store declaration (action always `%poke`) |
| `iview-site` | 13608 | `[xs mapper]` | Keyed `each (turn xs mapper)` site |
| `igate-free-mold` | 14885 | | `gate-free-mold-source` result |
| `dgscan`, `dgcommit`, `dg-step`, `dgparse` | 15149, 15243, 15444, 15581 | | dg-* transaction |
| `grec-collected` | 15782 | `[molds proofs]` | grec index input |

### 1.2 Pipelines

#### (a) The partial golden-types report (all 304 typed goldens)

Entry chain:
- No prelude (127 typed goldens): `golden-types` 11486 → `golden-types-imports` 11497 → `golden-types-with-marks` 15016 → `golden-types-in-context` 15021 → `golden-types-in-context-core` 15025. `tools/golden:248-253` picks the arm by whether the case has `/sur` or mark fixtures.
- Module-check mode (177 typed goldens with `modules.txt`): `tools/golden:254-260` calls `golden-types-with-prepared-prelude` 14975 with a prelude prepared once under `mule` by `prepare-prelude-with-internal` 12103 (`tools/golden:291`), falling back to `golden-types-with-prelude-and-internal` 14969. 14975 parses, runs `duplicate-defs`, `module-scope-valid` 14986, and **resolves Jibb imports with the full checker** (`resolve-jibb-imports` 14989 → `infer-jibb-file-detailed` per imported module), then calls the core.

`golden-types-in-context-core` 15025-15146:
1. Parse (15029), `duplicate-defs` 15031 (→ `duplicate-fields-report`), reserved `proj` 15033 (bare `'module has reserved proj name'`, no header, A43).
2. `resolve-groups` 15040: the same resolver as the full check (10662 → `resolve-groups-core` 10736) but **with no grec index**, so `%grec` never arises here; no program/store recovery, no kind checks.
3. `definite-value-cycles` 15041.
4. dg-* transaction if eligible (15044-15075): import-free, not API/store, no `main`, incomplete, ≤65,536 bytes, ≤64 defs, and either no prelude + `dg-source-candidate`, or the exact prepared prelude + `dg-prepared-candidate`. Names it adds are "recovered" only if the transaction env is complete and `dg-interface-safe`.
5. Per definition in source order (15079-15146): molds → `show-partial-mold` 11431 (never infers the mold; hole report, union disjointness verdict or `not checked`); duplicate name → `name already in scope`; cycle → `non-gate value depends on itself through a cycle`; recovered/grouped → print the scheme from env; otherwise **re-infer the definition afresh** (state literal 15107, `gate-defs`/`head-evidence` 15108-15109, `reserve-def-caps` 15110; gates through `infer-recursive-gate` 15113, others `infer-fragment` 15114) and finalize with its own copy of the finalization (15117-15143, table in 2.8), then `canonical-itype` 15144 + `show-itype` + `show-atom-constraint`.

So a report line is not the scheme the resolver published; it is a second inference against the resolved env. The report never runs recovery, kind checks or grec; its messages are the raw per-definition failures.

#### (b) The full module check

`infer-jibb-file` 14650 (text adapter) → `infer-jibb-file-detailed` 14658-14879:
1. Parse 14661 (`module source does not parse: /p`), `duplicate-defs` 14664, API module with `main` rejected 14666.
2. `/ui/api/...` branch 14668-14725: `api-poke-interface-result` 12979 first; else `api-derived-clash` 14678, scope with mark rules 14684-14698, prelude required 14699, `resolve-jibb-imports-detailed` 14705, `+$ paths` required 14708, then the "narrow" `one-request-interface-graph` 14711-14721 or `multi-request-interface-graph` 14722-14725. No value inference beyond `api-support-analysis-*` (12708, 12742), which calls `resolve-groups`.
3. Other modules: `program-main-def` 14726 and the syntactic recognisers `program-main-parts` 14728, `page-main-parts` 14730, `store-main-parts` 14732; `store-declaration` 14734 (definite clash 14736; `module kind or scope needs unsupported inference` 14740); a `/ui/stores` main that is not a store is rejected 14741.
4. `module-scope-valid` 14745, `resolve-jibb-imports-detailed` 14748 (mutual recursion with this arm; cycle check before cache, cache reuse rules 12275).
5. Molds: `grec-collect-molds` 15825 only for import-free modules (14750-14752); istate literal 14759; grec index only for import-free prelude-backed modules whose prelude list is exactly `[[%collection %list ~[[%var 0]]] ~[0]]` and that have no local `list` (14762-14772); `module-mold-types-detail` 11799 (first failure aborts; overlap evidence rendered 14774-14780).
6. Values: `resolve-groups` or, with an index, `resolve-groups-core` (14781-14784). `resolve-groups-core` 10736-10756: compute names, graph, Kosaraju components, `direct-prelude-evidence` (prelude re-parse) and `dependency-order` 10768 once, then loop: `add-supported-defs-core` 10690 over the ordered defs (fresh positional state per def with `next=0`, `jrec-fuel=256`, `gate-defs` = `direct-checked-gates` of the current env, `head-evidence`; `reserve-def-caps`; `infer-fragment`, then `infer-recursive-gate` if that failed; `add-supported-result` 10670, which **silently drops** any failure or pending tag), then `add-groups` 10645 (cyclic components through `infer-gate-group` 10509), until env stops changing.
7. Program recovery chain 14786-14804, only for a direct `(program i u v s)` main: `program-update-context` 13346 → `program-subs-context` 13508 → `program-view-context` 13938 (keyed) → `program-plain-view-context` 13858 (only if keyed declined) → `program-plain-init-context` 14238 → `program-main-context` 14472. Single pass, fixed order, each arm a no-op unless its component (and `main`) is still missing.
8. dg fallback 14807-14816: only if incomplete, not a store, no imports **and no prelude** (14809), so it can never affect a prelude-backed check (A47).
9. Completeness 14817-14832 (store modules exclude `main`): `module-pending-tag` 10715 (re-infers ≤64 missing defs to find `nothing fixes the union of %x`), then `module-sample-shadow` 12171, then `module definitions need unsupported inference: /p[: ++ name]` with `module-missing-value` 12132 choosing the name.
10. `request-graph-merge` 14834; static main swap 14836-14843 (`static-main-specialized` 14487); store main swap 14844-14849 (`store-main-closed` 14599); kind boundary 14850-14857 (`program-main-closed` 14555, `page-main-closed` 14540, store/static results) → `module kind needs unsupported inference: /p`; store-derived exports 14858-14875; `request-graph-bounded` 14876; `ifile` 14878.

#### Where the two pipelines differ (A46, A122)

| | Report (a) | Full check (b) |
| --- | --- | --- |
| Resolver | `resolve-groups`, grec index `~` | `resolve-groups-core` with index when import-free |
| After resolving | re-infers each definition and prints its own failure | keeps resolver env; failures are silent |
| Recovery | none | program chain, static/store main swaps |
| Kind checks | none | `program-main-closed`, `page-main-closed`, store, static |
| dg-* | eligible with or without prepared prelude (15053-15061) | only without prelude (14809) |
| Finalization | 15117-15143 (adds `pending-null`, hidden recursive/generic, merged-capitals messages) | `add-supported-result` 10675-10689 (no `pending-null`, no hidden-name check, merged capitals caught only as `constrained-capitals`) |
| Mold check | `show-partial-mold` (projection only) | `module-mold-types-detail` (real templates) |

### 1.3 Families, by layer

"Category": G general inference, U union analysis, M module and imports, A API and paths, R recovery slice, P reporting/printing, O other. "Tests" lists suites (without the `jibb-` prefix) and goldens; `[call]` marks suites that name the family's arms directly.

#### A. Substrate (4601-6400)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Chapter contract, `itype`, `isub` | 4601-4689 | G | Contract comment 4603-4661 (assoc-list sub, occurs check, per-definition generalization, monomorphic binders, capitals shared per definition, `@` one-way, unions keep origin/args; `proj` limits 1,024/4,096; "The unchanged todo API fits this fragment" 4643-4644; closed gate sample may omit one outer face 4653-4655) | every `types-*`; 32 suites build `itype:jibb` |
| Lookup, walk, occurs, normalize | 4691-4732, 4817-4843, 6012-6026 | G | Linear `itype-lookup`; `itype-walk` follows chains for the six var kinds and `%tag`, stopping only at a self-binding to `%fvar`/`%rvar`/`%rnvar` (six copied arms, A16); `itype-occurs` (opaque `%recursive`/`%jrec`; same-id `%tag` counts); `itype-normalize` full zonk, leaves `%tag`/`%recursive`/`%jrec` | typecheck, hole-guards [call], arithmetic-guards [call], deferred [call], generic-construction [call]; `types-partial-occurs`, `types-partial-dependency-chain`, `types-partial-shared-tvar` |
| Emptiness and inhabitation | 4734-4815 | U | Budgeted; `itype-empty-proof` proves only emptiness; `itype-inhabited-proof` three-valued (`%var` yes only via written capital; only list/unit collections decided, A13; `%grec` via `grec-tree-proof` 4801); `itype-live-cases` drops proven-empty cases, any unknown → `~` | empty [call]; `types-list-patterns`, `types-partial-union-edges`, `types-union-finite-limit`, `types-tuple-context` |
| Unification | 4851-4940, 5005-5012 | G | `(unit isub)`, no reason. Walk both, equal → ok; grec by at+name then args; jrec by 5 fields; recursive by module+name; union by origin, then raw `cases` equality when argless (A11) else args; collection by name then args; `%var` binds anything after occurs; `%fvar` via `itype-bind-gate-free`; atom-kind lattice 4884-4925 (nvar~rvar → rnvar with self-binding 4887-4889); const by value; atoms of different aura fail (no widening); face~face same name; fn/cell pointwise | typecheck, arithmetic-guards, gate-free-guards, generic-recursion [call]; `types-arithmetic-*`, `types-partial-atom-*`, `types-union-phantom-generic` |
| Gate-free propagation | 4942-5003, 6320-6343 | G | `itype-gate-free-form` (budget; unbound `%var` → self-binding to `%fvar`; fails on fn/noun/tag/recursive/grec); `itype-bind-gate-free` 256 (exhaustion reads as mismatch); `itype-collection-keys` for set/map/mop/jar/jug keys; `itype-var-is-gate-free-fuel` fails open at fuel 0 | gate-free-guards [call], gate-free-source; `types-prelude-unit-helpers` |
| Directional fit | 5014-5019, 5451-5711 | G | `itype-fit` = `itype-fit-inner` + empty-source rescue (256). About 45 ordered guards: width (spine ≥1,024 or wider source → unknown); empty/flag-vs-`@f`; `*` accepts anything incl. gates (A23) and binds bare tags to `*` (A22); actual `*` only to a var; grec/jrec/recursive by identity; unions by origin; known union to var by unify; non-var vs union → `itype-fit-cases` (unique %ok wins, two → unknown); tags: ctor only vs fn via `itype-fit-ctor-cases`, term vs `@tas`/`@ta` with no aura check (A20), vs `?` if 0/1, vs `@`; zero vs list → unknown; var vs face unifies with the body (5652); `@` turns a var into a fresh `%avar` (only allocation, 5666); atom by `aura-prefix`; cells head then tail; faces same name; closed gates by `itype-closed-gates-match`; last resort unify, with failures turned to `%unknown` when unions, recursion or related auras are involved. **Gates (fn vs fn) only unify: no variance** | closed-gate-guards, constructor-fit-guards, empty, qath-fuel, generic-construction, arithmetic-guards, generic-recursion, deferred [call]; 32 golden lines `call constraint…`, 37 `cast constraint…` |
| Aura families | 5049-5092 | G | `aura-prefix` textual prefix (`@` above all); `itype-family-related` only to turn failures into unknown | `types-partial-aura*`, `types-partial-atom-widening`, `types-partial-branch-widening` |
| Branch joins | 5094-5097, 5125-5210 | G | Unify, else `itype-concrete-join` (prefix parent or `@`, never touches sub); n-ary: unify all, else first `@` or common prefix parent present among arms | `types-partial-branch-widening`, `types-list-branch`, `types-union-branch-*`, `types-recursive-branch`, cell-branch, deferred |
| Face guards | 5212-5227, 5265-5349 | G | `itype-face-asym` (face on one side vs non-var); `itype-merge-faces` (cast result, 1 + 12 recovery calls); positional rules `itype-positional-face-asym`/`-slot-face-asym` (added with `like`, 640a442); `itype-output-may-be-cell` | positional-face-guards [call], direct-gate-guards [call], deferred [call]; `types-positional-faces`, `types-prelude-like`, `types-generic-face-inference`; 4 golden lines `call result face propagation` |
| Closed gate sample matching | 5229-5263 | R | See 3, R12 | closed-gate-guards (via `itype-fit`), todo-api |
| Fail-closed structure guards | 5020-5046, 5098-5123, 5372-5449 | G | `itype-has-any-atom/-tag/-union/-recursive/-hidden-generic/-hidden-recursive`; `itype-has-fixed-atom` (5098) is dead | `types-union-unresolved*`, `types-generic-union-escaping`, `types-qath-module-identity` |
| Pending tags | 5351-5370 | G | `pending-tags`, `pending-null`, `pending-tag-diagnostic` (`nothing fixes the union of ` + `show-lit`, 5363); checked only at definition end | buttons (`tests/type-buttons/error.txt`), program-init, program-update, deferred [call]; 80 golden lines `tag needs context`, 24 `` `~` needs context `` |
| Self-test | 5713-5798 | O | `itype-unify-test`, compared by `jibb-typecheck` with `tests/checker/unification.txt` (the old `tools/hoon` check is gone) | typecheck [call] |
| State, env, results | 5800-5806, 5824-5827, 5832-5834, 5995-6006 | G | see 1.1 | 13 suites build `istate:jibb` |
| Interface/evidence types | 5807-5823, 5828-5831 | M | see 1.1 | module-*, api-evidence, store, program-watch |
| Record width and `proj` | 5835-5923 | O | `width-scan` (closed uniquely faced spine), `width-known-shape`, `width-shape` (wider source → `record width constraint needs unsupported inference`), `width-proj-shape`/`width-project` (source-order planner, 4,096) | proj-guards; `types-proj-*`, `types-partial-projection` |
| Gate-free proof with witness | 5925-5992 | O | `gate-free-type` on normalized types; budgeted; list/unit only (A13) | gate-free-guards, gate-free-source, empty, generic-recursion [call]; program-main |
| Defaulting, promotion, holes | 6028-6181 | G | `promote-restricted-numbers` (only with written caps), `default-hole-numbers` (only when the type has no gate), `unresolved-hole`, `default-decimals` (`itype-has-gate` treats `%grec` as gate-bearing, ignores union args), `uncertain-hole-msg` | hole-guards [call], generic-recursion [call]; `types-hole-*`, `types-partial-decimal-default` |
| Vars, rename, canonical, instantiate | 6183-6318, 6345-6368 | G | `itype-vars` order (fn sample before product, head before tail, union args before cases); `unique-type-vars` O(n²); `itype-rename` single pass, no sub; `canonical-itype` kind precedence rvar > avar (nvar/rnvar → avar) > fvar > var; `instantiate-scheme` pushes fresh fvar/avar/rvar ids onto `binders` | gate-free-guards [call]; `types-partial-generalization`, `types-partial-atom-alias`, `types-many-variables`, `module-import-atom-scheme` |
| Local capital and mold lookup | 6370-6395 | M | `icap-lookup`, `find-simple-mold` (unique only), `collect-simple-molds` | 5 suites [call] |

#### B. Import bridge and mold elaboration (6397-7253)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Imported Hoon validation and bridge | 6397-6728 | M | `jibb-face-name`, `rec-pattern(s)` (self-recursive disjoint fork → opaque `%recursive`), `imported-faces-valid` (repeated face on a spine fails), `import-to-itype(-standard)` (aura whitelist u ud ux uv t ta tas p da dr tD, duplicated at 6432, 6557, 12666, A14; `%f` pair → `?`; `%unit` → prelude unit union only with the standard template, A10; other forks → originless `%union` after pairwise `union-relate`), `find-imported-mold(-prelude)`, `find-imported-mark(-prelude)`, `collect-sur-imports`, `collect-mark-imports`. 6682-6683 dead (A18). All failures `~` | bridge, api-evidence [call], import*, mark-bridge, tlon-bridge, poke-bridge; `types-import-*`, `module-import-api-*` |
| Interface lookup and relabelling | 6730-6841 | M | `find-jibb-interface`, `find-jibb-mold` (~40 callers), `itype-in-import` relabels unions/jrec/grec (display only), `prelude-union-alias`, `identity-union-parameters` | generic-alias, ask-guards, store, page-main, program-watch, todo-full, theme [call]; `module-import-*`, `types-union-print-*` |
| Mold elaboration and templates | 6843-6919, 6970-7000, 7099-7253 | G | `infer-simple-shape` (shape→itype; holes allocate a var + `ihole`; unions need `union-pairs` without overlap, else the source slice; local mold expansion guarded by `active`; generic local mold re-elaborated with params bound; generic local unions refused 7216-7217); `template-apply(-sub)` renames scheme vars to args (`template-apply` drops the sub); `infer-mold-template` builds +$ schemes, generalizing exactly the params; `label-direct-union` gives a top-level union its origin | union-source [call], gate-free-guards [call]; `types-generic-*`, `types-hole-*`, `types-union-alias` |
| Source-recursive recognisers | 6921-6967 | R | `simple-source-recursive` (`%jrec`), `simple-source-generic-recursive` (`%grec`). See R17, R18 | qath-*, generic-recursion [call] |
| Import-invalid replay | 7002-7097 | M | Replays a failed shape to recover the importer's `[%invalid …]` message with site note `invalid imported mold` | import, import-diagnostic, import-overlap, import-structural |
| Gate samples | 7255-7300 | G | `infer-sample`: binders fresh `%var`, monomorphic, pushed onto `binders`; shadow → tape `sample shadows a name` | `types-partial-shadow-global`, `module-import-*-shadow` |
| Local definitions | 7302-7373, 7514-7702 | G | See 2.7; generalization subtracts `free-env-vars` and `free-cap-vars`; order-independence machinery `shared-types`/`shared-moved`/`closed-local` | `types-local-*`, `types-partial-locals`, `types-local-scc*` |
| Capital scope walker | 7375-7512 | G | `scope-*` syntactic walk; `reserve-def-caps` allocates one `%var` per written capital per `++` | `types-local-capitals`, `types-capital-distinct` |
| Record field access | 7704-7747 | G | `record-fields-named` on a known faced spine; no deferred has-field constraint | program-init/main/update/watch [call]; `types-record-faces` |

#### C. Expression checker (7749-10032)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Contextual branches and list literals | 7749-7921 | G | `infer-union-context` (two loobean arms or unit arms with the same expected type, no join), `infer-list-context` (exact prelude list scheme; cons only under list context), `infer-open-list-items`/`infer-list-items` (drifted copies, A17), each with the `element` fallback hook (R7) | `types-list-*`, `types-flag-branch-context`, `types-union-branch-context`, deferred-context, todo-partial |
| Unit and list two-arm branches | 7923-8075 | U | Hand-coded two-arm exhaustiveness (`~` + `[~ x]`, `~` + `[h t]`); unit recognised structurally (no origin check); inhabitation 256 | empty [call]; `types-unit-patterns`, `types-list-patterns` |
| String interpolation | 8077-8101 | G | Accepts atoms, `@`, leftover decimals, `(list @tD)`; generic atom from a capital → `a generic atom in interpolation needs an aura`; cell → `a cell in interpolation needs a printer` | `types-string-interpolation` |
| Union coverage, three copies | 8103-8390 | U | `union-pattern` %full/%none/%unknown; `infer-known-union-whole` 8208, `-context-whole` 8246, `-finite` 8292 (loobean expansion ≤64 rows); `single-structured-pattern`/`infer-single-case-branch` 8351-8390 | generic-pattern, cell-branch, nested-union-guards, empty; `types-union-patterns*`, `types-union-finite*`, `types-single-case-pattern` |
| jrec/grec match views | 8392-8475 | R | R17, R18 | qath-fuel, generic-pattern [call] |
| Branch routing | 8477-8549 + 8878-8930 | G | Order in `infer-fragment %branch`: dg → one arm (empty-list, empty-union, grec, structured, cell) → ≥3 arms known-union → two arms: speculative `known-union-subject`, unit, non-literal → known-union, loobeans (unify subject with `?`, infer arms, `itype-branch-join`, failure classified 8921-8929) | `types-union-*`, `types-loobean-*`, `doc-grammar-04-step` |
| Empty list / empty union | 8555-8608 | U | `empty-list-null-branch` (exact prelude list; element proven empty), `known-empty-union-wing` | empty [call] |
| Record change | 8612-8656 | G | `infer-change-edits` on a known faced spine; `standard-unit-template` 8646 | `types-record-change*` |
| Missing-tag diagnostics | 8658-8744 | P | `missing-union-tag` (`{label} has no case %x`), `nested-missing-tag` replay | `types-missing-tag-*`, `types-nested-missing-tag` |
| `infer-fragment` | 8749-8980 | G | Synthesis by node kind (literals: `%ud` → `%nvar`, `%loobean` → `%flag`, term/null → `%tag` + `ipending`; ctor → `%tag … &`; `%unit`/`%list`/`%qath` require the exact prelude templates; `%wing` instantiates; `%cast` = shape + check-mode + width check + fit + merge faces; `%gate` monomorphic sample; `%call` → `infer-call-with-head`) | every typed golden; cell-branch, deferred, generic-pattern, qath-source [call] |
| Dead code | 8988-9000, 9058-9063, 10780-10783 | O | `width-has-projections`, `infer-width-elaboration`, `direct-find-gate`, `resolve-supported-defs` | none |
| Direct gate-layout evidence | 9002-9228 | R | R11 | direct-gate-guards [call] |
| Call checking | 9230-9294, 9296-9314 | G | Head first; known `%fn`: context args, width, fit (`itype-fit-inner … skip-width` for multi-arg), else `direct-gate-call-fit`; `%unknown` → `call constraint…` (or a `dgo` in defer mode); `%bad` → missing tag → nested tag → `call's sample and argument types do not unify` (`call-error-site` blame); face-propagation guard 9283-9288. Unknown head: unify with `[%fn arg fresh]` | 116 golden lines `call's sample…` in 53 goldens; positional-face-guards |
| Contextual call and singleton/unit/tagged-case | 9316-9562 | R/G | `infer-unit-context` 9321, `infer-contextual-call` 9355 (pre-unify product with expected; `element` exception), `explicit-singleton-in-union` 9480, `contextual-*` 9501-9562 (R15), `grec-direct-context` 9527 | nested-union-guards, constructor-fit-guards [call]; `types-nested-union-context`, `types-unit-context` |
| `proj` intrinsic | 9396-9475 | O | `explicit-proj-call`, `infer-proj-context` (check mode only), literal fields by name | proj-guards; `types-proj-*` |
| Closed-cell branch retry | 9564-9662 | R | R14 | cell-branch [call]; `types-cell-branch-context` |
| Check-mode dispatcher | 9664-9783 | G | `infer-call-context-arg`, ~19 ordered steps (9667-9783): defer → unwrap pair/group/body/trace → peel faces → `proj` → grec ctor → jrec `~`/tuple → call → empty list → structured/cell patterns → loobean singleton → known-union branch → unit → closed-cell → flag/union/list branch → list literal → tagged case → cell tuple → synth. Reads the raw `expected` at 9732, 9743, 9756 to keep provenance (A36). Callers do the final fit | generic-construction, qath-fuel [call] |
| Positional items, cell binders | 9785-9928 | G | `infer-call-context-items/-args`, `projection-field-target` (peels one slot face), `infer-simple-items`, `infer-cell-branch` | `types-cell-pattern-*`, `types-multi-call` |
| Printers | 9930-10032 | P | `show-itype` (A-Z then T26…; six identical variable arms 9936-9951, A35), `show-itype-cases`, `site-type-note` (bare label for vars, nvar, tags, unions, hidden recursion) | every typed golden; 11 suites [call] |

#### D. Definition boundary and module resolver (10034-10900)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Capital and atom-var guards | 10034-10169 | G | `merged-capitals` 10072, `constrained-capitals` 10089 (capital bound to non-var or shared → "explicit capital constraints are not supported"), `atom-var-from-cap`, `atom-var-from-binder`, `unsupported-atom-vars` 10159 (atom vars generalize only from caps or `binders`) | deferred [call]; `types-capital-distinct`, `types-partial-explicit-capital`, `types-partial-aura-*` |
| Constraint printing | 10171-10191 | P | `show-atom-constraint`: ` where A is an atom other than ?` / ` is an atom` / ` contains no gates` | all typed goldens with constrained vars |
| Names, dependencies | 10193-10214, 10327-10428 | M | `global-value-names`, `unique-value-name`, `dependency-expr` (syntactic, ignores binders, errs closed) | `types-partial-forward`, `types-scope-*` |
| Single recursion | 10216-10325 | G | `infer-recursive-gate` 10285: monomorphic `[%fn sam seed-or-fresh]`, body, unify product; `recursive-branch-seed` 10254 (closed base arm of a one-self-call loobean branch); refuses in defer mode; clears `gate-defs` | `types-recursive-*`, `types-local-recursive` |
| Mutual recursion groups | 10430-10533 | G | `seed-gate-group`, `infer-gate-group-bodies`, `group-schemes` (short merged-capital text 10495), `infer-gate-group` 10509 (rejects projections, holes, pending tags) | `types-recursion-scc-*`, `types-local-scc*` |
| Projection finalization | 10535-10549 | O | `width-finalize` | `types-proj-*` |
| Kosaraju SCC | 10552-10643 | M | Work-list DFS; components dependencies-first; duplicates → no components | `types-recursion-scc-order`, `types-value-cycles` |
| Resolver fixpoint and finalization | 10645-10778 | M | `add-groups`, `resolve-groups`, `add-supported-result`, `add-supported-defs-core`, `resolve-groups-core`, `dependency-order` (see 1.2(b) step 6, 2.7, 2.8) | all full-check suites; `module-import-*` |
| Failure diagnostics, value cycles | 10711-10734, 10785-10900 | P | `module-pending-tag` 10715; `definite-value-cycles` 10885 (report only) | buttons, program-init, program-update; `types-value-cycle*` |

#### E. Union analysis and module checker (10902-12600)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Union projection and relation | 10904-11022, 11275-11286 | U | `project-union-mold` (local refs only, `seen` list), `union-relate` (`?` = {0,1}), `union-pairs` O(n²) in (i, j) order | full-overlap-*, import-overlap; 73 goldens print `cases proven disjoint`, 12 `overlapping cases` |
| Source disjointness slice + state screen | 11024-11187 | R | R19 | union-source [call] |
| Overlap witness | 11189-11273, 11288-11302 | U | `mold-overlap-witness` 11296: first projected overlap, else (only if some pair unknown) `union-source-overlap` 256 | union-alias-overlap, full-overlap-basic [call] |
| Hole detection | 11304-11430 | G | `simple-mold-hole` (unit unit span), syntactic `*-has-hole` | hole-guards [call]; `types-hole-*` |
| Report printers and entry wrappers | 11431-11500 | P | `show-partial-mold`, `show-inference-diagnostic`, `show-duplicate-fields`, `duplicate-fields-report`, `golden-types`, `golden-types-imports` | all typed goldens |
| Duplicate fields | 11520-11693 | O | Pre-inference syntax pass; nested cell opens a new scope (A30); message `record field `x` is repeated` | `types-record-field-*` |
| Scope validity, reserved `proj` | 11694-11773 | M | `import-binding-names` (includes `/%` marks, A25), `reserved-proj-*`, `module-scope-valid` | proj-guards, deferred-resolver [call]; `types-proj-reserved-*` |
| Module mold elaboration | 11775-11824 | G | `module-mold-types(-detail)`: each mold from the same base state (ids may repeat across templates); first failure aborts; overlap evidence for a union | full-overlap-basic [call]; `module-cache-incomplete` |
| Prelude bootstrap | 11826-12024 | R | R21 | `prelude-*`, `types-prelude-*` |
| Partial prelude interface | 11913-11926, 12026-12112 | M | `partial-prelude-molds` drops failing molds silently; `prepare-prelude(-with-internal)` re-parse | 33 suites call `prepare-prelude-with-internal`; `tools/golden:291` |
| Completeness and failure naming | 12114-12188 | P | `module-values-complete`, `module-missing-value`, `module-sample-shadow` | `module-missing-value-*` |
| Import resolver and cache | 12190-12200, 12219-12228, 12275-12324 | M | Cycle check before cache; legacy entries rebuilt; reuse needs identical inputs | `module-import-*`, `module-cache-*`; full-overlap-graph, request-guards |
| Request-graph merge | 12202-12218, 12229-12274 | A | Set union of paths; dedup requests/stores; 256/256 bound (A27) | store [call], request-guards |
| API path extraction, derived names, typing | 12326-12615 | A | `+$ paths`/`+$ poke` declarations, `api-derived-clash`, `api-path-analysis(-source)`, `api-path-evidence-source` | api-paths, api-evidence, hole-guards, proj-guards [call]; `module-import-api-*` |

#### F. API interfaces (12596-13144)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Path evidence | 12596-12652 | A | `api-path-evidence-source/-graph` (copies, A31), `api-path-watchability` | api-evidence [call] |
| Request components | 12654-12698 | A | `api-request-parameter-types`, `api-request-fold-type`, `api-request-parts` (argument order not fixed) | api-evidence [call], todo-api |
| Supporting definitions | 12700-12774 | A | `api-support-analysis-source/-graph` (copies): ordinary `resolve-groups` with a positional state | api-evidence [call] |
| Prelude shape certificates | 12776-12845 | A | `compatible-raw-poke`, `request-compatible-ask`: structural `=` on hard-coded itype nouns | store [call], ask-guards, sub-guards |
| Request interface constructors | 12847-12956, 13020-13075, 13099-13144 | A | `one-request-interface-source` (dead) and `-graph` (narrow branch, A44), `api-sur-covered`, `api-request-gates` (fuel 256), `multi-request-interface-graph`; hand-built `∀0` schemes | request-guards, todo-api, page-main, todo-full; `types-request-normal`, `module-import-api-request-reason` |
| Poke-only interface | 12958-13018, 13077-13097 | A | `api-poke-interface(-result)`, `api-poke-from-checked`, `api-mark-exports` | hole-guards, api-paths, proj-guards [call]; `module-import-api-poke-*` |

#### G. Kind recognition and program/store recovery (13146-14648)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Main-call recognisers | 13146-13240 | M | `program-main-def`, `program-main-wing`, `program-main-args/-parts`, `page-main-parts`, `store-main-parts`: syntax, heads matched by name (four copies of one walk, A48) | program-main, program-watch, store, page-main [call] |
| Store declaration, derived-name clash | 13242-13309 | M/P | `store-declaration`, `derived-name-clash` (precedence: definition, import face, another derived name, prelude name) | store; `module-import-store-*`, `module-import-api-*-clash` |
| Transparency helpers | 13311-13340 | R | `program-empty-null`, `program-subs-empty`, `program-transparent` | program-main, page-main |
| Update, subs recovery | 13342-13606 | R | R1, R2 | via `infer-jibb-file(-detailed)` |
| Slot and relation helpers | 13452-13503 | R | `program-inferred-slot`, `program-two-slot-names`, `program-update-relation` | via recovery |
| Keyed view-site walker | 13608-13749 | R | R3 | todo-full |
| Element message fits | 13751-13853 | R | R7 | todo-full, store, buttons; `types-prelude-ui` |
| View recovery | 13855-14155 | R | R3, R4 | todo-full, store |
| Initializer | 14157-14312 | R | R5 | program-init |
| Derived request/store evidence | 14314-14470 | A | `derived-poke-command-scheme`, `store-derived-schemes`, `program-subs-watch` 14367, `derived-request-member` 14405-14441, `derived-store-request-member` 14443-14470: provenance certificates compared by `=` | store [call], program-watch, page-main |
| Program main completion, kind boundary | 14472-14582 | R/M | `program-main-context` (R6), `static-main-specialized` (R9), `page-load-derived`, `page-main-closed` (R10), `program-main-closed` (R6) | program-main, program-watch, store, page-main [call] |
| Store kind | 14584-14648 | R | R8 | store |

#### H. Driver, report, dg, fresh ids, grec (14650-15838)

| Family | Lines | Cat | How it works | Tests |
| --- | --- | --- | --- | --- |
| Module driver | 14650-14879 | M | 1.2(b) | 23 suites call `infer-jibb-file`, 12 `infer-jibb-file-detailed` |
| Mold analysis entry | 14881-14933 | O | `gate-free-mold-source` | gate-free-source [call] |
| Report adapters | 14935-15024 | P | `golden-types-with-modules` (dead, A42), `-with-prelude`, `-with-prelude-and-internal`, `-with-prepared-prelude`, `reader-result-for-checker`, `-with-reader-diagnostics`, `-with-marks`, `-in-context` | tools/golden, tools/ship; 24 suites |
| Report core | 15025-15146 | P | 1.2(a) | all 304 typed goldens; deferred-prepared [call] |
| dg-* | 15147-15656, 15704-15719 | R/G | R20 | deferred, deferred-context, deferred-prepared, deferred-resolver [call] |
| Fresh ids | 15658-15702 | G | `ienv-fresh-id` = one above the max id in env (declines on a pending `%tag`); stands in for a global fresh supply | deferred [call]; program recovery suites |
| grec trees | 15721-15835 | R | R18 | generic-*, union-source [call] |

## 2. Inference today

### 2.1 Unification and type comparison: one unifier, one fit, many special comparators

| # | Comparator | Lines | Direction | What differs |
| --- | --- | --- | --- | --- |
| 1 | `itype-unify` | 4851-4940 | symmetric | The only structural unifier. Returns `(unit isub)` with no reason. Nominal rules: grec/jrec/recursive identity; union by origin then (argless) raw case equality or args; face names must match. Atom-kind lattice by pairwise cases 4884-4925. Never widens |
| 2 | `itype-fit` / `itype-fit-inner` | 5516-5711 | actual → expected | Widening (aura prefix, `@`, `*`, empty source), tag binding, ctor case selection; three-valued; calls unify for vars and as last resort. Gate types are compared by unify (invariant) except `itype-closed-gates-match` |
| 3 | `itype-fit-cases`, `itype-fit-ctor-cases` | 5451-5514 | actual → union cases | Each case tried from the original sub; unique `%ok` wins, two → `%unknown` |
| 4 | `itype-closed-gates-match` | 5229-5263 | symmetric, closed only | Gate equality modulo one omitted outer sample-slot face; all unifies from empty sub |
| 5 | `direct-invariant` | 9097 | both ways | Fit forward and backward plus a face-asymmetry test; 19 call sites, 16 in program/store recovery |
| 6 | `direct-function-fit`, `direct-positional-fit` | 9107, 9142 | both ways per slot | Two-slot gate samples matched with binder-face stripping, then replay must leave `sub`/`next` unchanged |
| 7 | `program-union-tag-case`, `program-single-case-fit`, `program-single-generic-fit`, `program-keyed-product-fit` | 13751-13853 | element messages | Select the one literal-tagged case, fit head and tail; element covariance only for a single case |
| 8 | `contextual-tagged-case` | 9545 | expected union | Unique const-headed case by head noun |
| 9 | Structural `=` on itype | 12782, 12805, 14314-14349, 14408-14470, 14599-14648; `infer-closed-cell-branch` 9616; `dg-stable-fit` 15427; `dg-stage-one` 22-field state equality 15458-15479; `program-init-model` replay 14163-14213 | exact | Prelude certificates and "stability" checks substitute for constraint solving |
| 10 | `union-relate` | 10994 | pattern overlap | Not a type relation; noun-shape projection used for disjointness |

### 2.2 Substitution

- Representation: `isub` assoc list (4688), prepended, never compressed; `itype-lookup` 4691 linear.
- Head walk: `itype-walk` 4698-4732, six identical arms (`%var|%fvar`, `%avar`, `%rvar`, `%nvar`, `%rnvar`, `%tag`) that stop at a self-binding to `%fvar`/`%rvar`/`%rnvar` (A16). Self-bindings are created at 4887-4889 (nvar~rvar), 4962 (gate-free form) and in `promote-restricted-numbers` (6119-6131). Any other self-binding loops forever (no fuel).
- Second walker: `dg-scan` 15150-15178 follows the sub with fuel; recognises only `%rvar`/`%rnvar` self-bindings, so an `%fvar` self-binding burns fuel and declines.
- Full application: `itype-normalize` 6012 (95 call sites); leaves `%tag`, `%recursive`, `%jrec` unexpanded.
- Whole-sub scans used as provenance screens: `contextual-simple-sub` 9519 (unbounded), `closed-cell-sub-safe` 9592 (512), `grec-direct-context` 9527 (4,096), `union-state-sub-budget` 11147 (256). Each declines if *any* entry binds a structural type, so behaviour depends on inference order.
- Mold-level substitutions (not the type substitution): `bind-params` 6873 (param name → arg type, by re-elaboration), `template-apply-sub` 6882 (rename scheme vars to args), `union-overlap-case` 11206 (tvar → arg pattern).
- Rollback is implicit: speculative attempts drop their returned state (`known-union-subject` 8541, closed-cell retry, tagged-case retry 9768-9774, direct-gate replay, `infer-recursive-gate` retry, failed locals).

### 2.3 Generalization: six sites, four rules

| Site | Lines | Rule |
| --- | --- | --- |
| Top level (`add-supported-result`) | 10682 | Quantify **every** variable of the normalized type. Sound only because each definition starts at `next=0` (10699) and the env holds closed schemes |
| Report (`golden-types-in-context-core`) | 15141 | Same, copied |
| Locals (`infer-local-defs`) | 7677-7681 | Type vars minus `free-env-vars(env)` (7307: normalizes every non-quantified var of every env scheme) minus `free-cap-vars(enclosing caps)` (7320) |
| Groups (`group-schemes`) | 10502-10504 | Same rule with the outer state's caps |
| dg (`dg-generalize`) | 15222 (called 15482) | Vars of the normalized type minus "blocked" = env-free (`dg-env` 15187, whole env scan) + obligation vars + tag-reachable vars (`dg-tags` 15209) + captured; bounded scan 32,768; ≤64 edges |
| Molds (`infer-mold-template`) | 6970-7000 | Exactly the fresh param ids; a nongeneric mold must be closed |
| Hand-built schemes | 12889, 12943, 13068, 14349, `store-derived-schemes` 14351 | `[… ~[0]]` literals |
| Recovery publication | via `add-supported-result` in 13444, 13600, 13927, 14107, 14149, 14306 | Then require `vars ~` and no `itype-vars` (closed-only) |

Instantiation is one arm, `instantiate-scheme` 6355 (fresh ids from `next`, kind precedence, fresh atom/gate-free ids pushed onto `binders`, which is what lets `types-partial-atom-alias` re-generalize), plus `template-apply(-sub)` for molds and `itype-rename` 6219. Fresh ids for env-mixing code come from `ienv-fresh-id` 15666 (program recovery 13381, 13543, 13894, 14008, 14271; dg roots 15607, 15649).

### 2.4 Branch joins: one join, several non-joins

- Join rule (Q11, A133 fixed in 38c711c): `itype-branch-join` 5138 (two arms) and `itype-branch-join-list` 5202 (n arms), falling back to `itype-concrete-join` 5125. Callers: 8029 (list), 8073 (unit), 8226 and 8314 (union folds), 8919 (loobean; failures classified into five messages 8921-8929), 15333 (dg boolean).
- Checking-mode branches do not join; each arm is fitted to the expected type and the result is `expected`: `infer-union-context` 7763, `infer-known-union-context-whole` 8246, `infer-known-union-finite` with expected 8292, `infer-single-case-branch` 8361, `infer-cell-branch` 9894, `infer-unit-branch`/`infer-list-branch` with expected (A133 note).
- Other "joins": open list literal items are fitted to one element var (`infer-open-list-items` 7879, messages `list item widening is not supported` / `list items do not have compatible types`); `infer-closed-cell-branch` 9616 requires the two arm results to be equal and closed; `dg-boolean-branch` 15316 falls back to a fresh result var with two `dgo` edges.

### 2.5 Pending constraints (no queue)

| Constraint | Where held | Created | Checked | Outcome when unresolved |
| --- | --- | --- | --- | --- |
| Tag/`~` literal, ctor | `istate.tags` (`ipending`) + `%tag` pseudo-var | 8780, 8781, 8848 | end of each definition: `pending-tags`/`pending-null` 5351-5370 | locals wait (7673); top level dropped (10680); report prints `tag needs context` / `` `~` needs context `` (15131-15134); groups fail (10529); dg fails (15503); full check explains with `module-pending-tag` 10715 |
| Type hole | `istate.holes` (`ihole`) | 7103 | `default-hole-numbers` 6133, `unresolved-hole` 6168 | error (locals, report) or drop (top level); groups reject any new hole (10527) |
| Decimal literal | `%nvar`/`%rnvar` | 8773 | `default-decimals` 6062 at top level (10679), report (15130), `width-finalize` | locals do **not** default before generalizing; groups/dg reject `%nvar` (10499, 15481) |
| Atom-kind var | `%avar`/`%rvar` + `binders` | 5666, 4887, `instantiate-scheme` | `unsupported-atom-vars` 10159 | locals wait; top level drop; report `unresolved aura-variable inference` |
| Written capitals | `istate.caps` | `reserve-def-caps` 7509 | `merged-capitals` 10072, `constrained-capitals` 10089 | definite error (locals, report) or drop |
| `proj` | `istate.projections` | 9461 | `width-finalize` 10535 | drop / report message; groups reject |
| Call/cast fit `%unknown` | nowhere |: | immediately | `call/cast constraint is not supported…`; in defer mode a `dgo` |
| Deferred fit edges | `istate.obligations` (`dgo`) | 9262-9265, 15316, 15355 | `dg-replay-edges` 15252 at transaction close | whole transaction declines; outside dg any obligation is an error (7661) |

Nothing carries a constraint from one definition to the next except the dg transaction. A later definition (e.g. `main`) can never fix an earlier definition's tag; that is why the program recovery arms exist.

### 2.6 Order of solving

Synthesis is left-to-right and eager: every fit is decided when it is met, with `%unknown` meaning "give up". Expected types flow only through `infer-call-context-arg` 9664 and its ~19-step ladder; casts and known call samples are the only sources of context.

### 2.7 Fixpoints and retries

| Loop | Lines | Bound | Notes |
| --- | --- | --- | --- |
| Module resolver | 10749-10756 | env stops changing | One productive pass in dependency order (839f6b0) plus a confirming pass; fixpoint kept as fallback (A135) |
| `add-supported-defs-core` | 10690-10709 | one pass | Retries `infer-recursive-gate` after every failed `infer-fragment` (10705), gate or not (A33) |
| `add-groups` | 10645-10660 | one pass per resolver iteration | Errors discarded |
| Locals | 7624-7639 | progress | Pass loop; then `graph-components` + `try-local-group` 7686; then the order-independence rules decide definite vs `local definitions need unsupported inference` (7637) |
| dg-stage | 15496-15522 | ≤64 defs, fuel² = 4,096 attempts | Retry `(flop waiting)`; close: replay edges twice and require unchanged `sub`/`next` (15501-15510) |
| Program recovery | 14786-14804 | single pass | No fixpoint; order matters |
| Report | 15079-15146 | one pass | Re-infers every non-group definition after resolution |
| `module-pending-tag` | 10715-10734 | fuel 64 | Failure-path re-inference only |
| Replay "stability" checks | 9142/9191 (direct gate), 9616 (closed cell), 14163-14213 (init model), 15501-15510 (dg) |: | Stand-ins for "the constraints are solved" |

### 2.8 Definition finalization: five copies

| Step | `add-supported-result` 10670 | report 15117 | locals 7659 | groups 10488/10509 | `dg-stage-one` 15445 |
| --- | --- | --- | --- | --- | --- |
| obligations unchanged |: |: | 7661 | refuses defer 10512 | collects them |
| `promote-restricted-numbers` | 10675 | 15117 | 7662 |: |: |
| `default-hole-numbers` | 10676 | 15118 | 7663 | holes must not change 10527 | holes unchanged 15477 |
| `unresolved-hole` | 10677 drop | 15119 message | 7664 fail |: |: |
| `merged-capitals` |: (only via constrained) | 15122 long text | 7666-7669 long text | 10493-10495 short text | any written capital declines 15452 |
| `constrained-capitals` | 10678 | 15128 | 7670 | 10496 |: |
| `default-decimals` | 10679 | 15130 | **none** | nvar → fail 10499 | nvar → decline 15481 |
| `pending-null` |: | 15131 |: |: |: |
| pending tags / tag in type | 10680 drop | 15133 | 7673 wait | 10529, 10500 | blocks generalization; 15503 at close |
| hidden recursive/generic name |: | 15135-15138 |: | 10500 | `dg-interface-safe` 15573 at publish |
| `unsupported-atom-vars` | 10681 drop | 15139 | 7675 wait | 10500 | 15480 |
| quantify | all vars 10682 | all vars 15141 | minus env/caps 7677-7680 | minus env/outer caps 10502-10504 | `dg-generalize` 15482 |
| `width-finalize` | 10683 | 15142 | (left to the enclosing definition) | projections must not change 10525 | projections unchanged 15479 |

## 3. Recovery slices

"Would fail if removed today": `[call]` suites name the slice's arms and stop compiling if the arms go; `[out]` suites or goldens whose expected output depends on the path (from fixtures; not executed). **No typed golden reaches R1-R10, R18 or the full-check side of R20**, because the report (15025) runs no recovery, no kind check and no grec index, and the only goldens whose case-local modules have a `main` (`module-import-api-import-error`, `module-import-store-derived-clash`, `module-import-store-face-clash`, all importing a cart store) stop at the derived-name clash before inference. Those slices are pinned only by `tests/lib`.

### 3.1 Example-fitted slices

| # | Slice | Lines | Serves | Does instead of ordinary inference | Would fail if removed |
| --- | --- | --- | --- | --- | --- |
| R1 | Update recovery `program-update-context` | 13342-13450 | Todo island `update` (`my-app/ui/todo-list.jibb:16-25`) and basket `update`: bodies end in `[m ~]` and `\|=%acked`, whose tags have no context inside the definition, so `add-supported-result` drops them (10680) | Reads message/model from the written two-slot sample (binder faces stripped), builds `[model (list (cmd message))]` from prelude templates, proves it against program's instantiated slot with `direct-invariant`, checks the body in context, casts, merges faces, publishes only a closed scheme | [out] program-update (all `tests/type-program-update/*`), todo-full, store (basket), page-main (`index.jibb` imports `todo-list`), program-init (needs the update relation) |
| R2 | Subs recovery `program-subs-context` | 13505-13606 | Todo `subs ~[[%watch (todos.todo \|=%got)]]`, basket `(state.cart \|=%got)` | Same pattern with `(list (sub message))` and program slot 4 | [out] todo-full, store, page-main, program-init (`initializer-subs`) |
| R3 | Keyed view recovery `program-view-context` + view-site walker | 13608-13749, 13938-14155 | Todo `view` with exactly one `each (turn todos.m row-of)` and the mapper `row-of` | Finds the site syntactically, instantiates `each`/`turn`, infers the mapper and the view against hand-built `element message` types, publishes both mapper and view | [out] todo-full (`expected`, `alias`, `ambiguous-mapper`, `open-key`, `non-gate-view`, `wrong-*`), page-main, program-init (`initializer-open-view`) |
| R4 | Plain view `program-plain-view-context` | 13855-13936 | Basket `view` (no keyed site, 4bf477e) | Checks the body against `(element message)`; does not check program slot 3 (A48 drift) | [out] store (basket) |
| R5 | Initializer `program-init-model`, `program-init-ordinary`, `program-plain-init-context` | 14157-14312 | Todo `init \|= ts=(list item.todo) [ts "" ~]` (`~` needs context), basket `init \|= ~` | Model from the update relation or from a tentative positional fit of main's args (`direct-positional-fit` + replay stability), then context check of the body; ordinary fallback in a separate state | [out] program-init (17 `initializer*` fixtures), todo-full (`cast-init` guards ordering), store, page-main |
| R6 | Main completion and program kind check `program-main-context`, `program-main-closed`, `program-subs-watch`, `program-subs-empty` | 13311-13340, 14367-14403, 14472-14482, 14555-14582 | Any direct `(program i u v s)` main | Re-infers `main` after recovery (only agreement check); kind check instantiates program from `*istate`, requires closed invariant main, gate-free init data and model (256 shared budget), and one syntactic watch shape | [call] program-main, program-watch, store (`program-main-closed`); [out] program-main, program-watch, todo-full, store, page-main, program-update/init |
| R7 | Element message fits and the list-item hook | 7887-7891, 7909-7913, 9355-9394 (element exception in `infer-contextual-call`), 13751-13853 | Todo union controls (`button "Add" %submit`, `field … \|=%typed`), raw constructors (docs/compiler.md:153) | When an ordinary list-item fit to a prelude `element` union fails, prove the message argument invariantly or pick the single literal case; pre-unify recursive `element` results | [out] todo-full, store, buttons; goldens `types-prelude-ui` (`bad-child` and element lines), probably `doc-grammar-02-buttons` (`labelled`) |
| R8 | Store kind and main recovery `store-update-unfaced`, `store-main-closed` | 14584-14648, swap 14844-14849, completeness exception 14817-14819 | Cart store `my-app/ui/stores/cart.jibb` ("The builder erases the action from main", 14597) | Checks prelude `store` value and mold by `=`, checks init/update against local `state`/`poke` invariantly, publishes `[canonical ~]` as `main` even if `main` never inferred | [out] store (cart, basket); compiler.md:143 |
| R9 | Static main `static-main-specialized` | 14484-14508, swap 14836-14843 | `about.jibb` `++ main view` | Instantiates main from `*istate`, fits into `(element !!)`, publishes the canonical closed scheme | [out] page-main (about, `wrong-static`) |
| R10 | Page kind `page-load-derived`, `page-main-closed` | 14510-14553 | `index.jibb`, `blog/index.jibb` | One syntactic load shape `case.face reply`, provenance via `derived-request-member` | [call] page-main |
| R11 | Direct gate-layout evidence `direct-*`, `istate.gate-defs/head-evidence` | 9002-9228; set at 10701-10702, 15108-15109, recovery arms | `(program init update view subs)` with a faced `update \|= [=msg m=model]` against prelude `update=$-([M X] …)` (`prelude.jibb:534`) | After an ordinary call fit is not `%ok`, re-parse the prelude (A132), match written gate samples slot by slot, both ways, then replay | [call] direct-gate-guards; [out] direct-gate-source (`tests/type-direct-gate`), program-main, program-update, todo-full; golden probably `types-prelude-ui` `++ concrete-program` (line 72 of its source) since the report sets `gate-defs` |
| R12 | Closed gate sample matching | 5229-5263 (called 5701, 5316) | Todo API named closed fold gates (a1c5f35; contract 4643-4644, 4653-4655) | Gate equality ignoring one outer slot face | [out] closed-gate-guards (through `itype-fit`), todo-api, todo-full, program-watch, page-main |
| R13 | Positional face rule | 5313-5349, 9285 | `like` result mapping (640a442) | Ignore one sample-slot face per written argument | [call] positional-face-guards, direct-gate-guards; goldens `types-positional-faces`, `types-prelude-like` |
| R14 | Closed-cell branch retry | 9564-9662, dispatch 9743 | Todo `update` inner `?- (gth …)` returning `[m(...) ~]` (22f3788) | Re-check a two-loobean branch against a cell target from the original state; results must be equal, closed, tag-free; replay | [call] cell-branch; golden `types-cell-branch-context`; [out] todo-full |
| R15 | Contextual tagged case | 9477-9562 (`contextual-tagged-case` 9545), dispatch 9753-9780 | Todo `subs` body `~[[%watch (todos.todo \|=%got)]]` (72acdb3) | Try ordinary inference; else select the union case by literal head and check the payload in context | [call] nested-union-guards; goldens `types-nested-union-context`, `types-nested-shallow-preserve`; [out] todo-full |
| R16 | `infer-contextual-call` element exception | 9355-9394 | Todo controls, `\|=%got` callbacks | Pre-unify a same-origin generic union result with the expected type; recursive only for prelude `element` | goldens `types-generic-result-context`, `types-prelude-ui` (likely); [out] todo-full |
| R17 | `%jrec` / qath | 4680, 6925-6952, 8392-8420, 8757-8763, 8807-8821, 9699-9714 | Internal prelude `qath` (`internal.jibb:15-17`, 0ea700d); theme `font=` qath literal; `image`/`link` | Recognise `~ / [h=@aura t=self]`, unfold one layer per fuel (256 per definition) for matching, construction and static path literals | [call] qath-fuel; qath-source, theme; goldens `types-qath-*`, `types-arithmetic-proj-qath`, `types-prelude-ui` (`image-scheme`, `link-scheme` print `qath`) |
| R18 | `%grec` generic tree | 4681, 6954-6968, 8422-8475, 9527-9539, 9684-9698, 15721-15835, 4801 | Test-only node tree (`tests/type-generic-recursion`, c96597d) | Fixed two-case shape proof; one-layer view for patterns/construction; index only for import-free prelude-backed modules (14762-14772) | [call] generic-recursion, generic-construction, generic-pattern, union-source; golden `types-generic-recursive-union` only as an unsupported control |
| R19 | Union source disjointness, state screen, source overlap witness | 11024-11187, 11189-11273 | One-hop local generic alias with a literal head (b93a94b) | Bounded syntactic proof of distinct heads / positive overlap when projection is unknown | [call] union-source, union-alias-overlap, full-overlap-basic; goldens `types-union-source-alias`, `types-prelude-succ` |
| R20 | dg-* deferred transaction | 15147-15656, 15704-15719; hooks 8854, 8879, 8951, 9261-9265, 9281, 9667-9669, 10288, 10512 | Import-free modules without a prelude (full check, 14807-14816); prepared-prelude reports whose fixture is the todo initializer `[xs "" ~]` closed by a later cast (`tests/type-deferred-prepared/good.txt`) | Re-infer definitions with obligation edges for literal branch arms, tuple items and ctor args, retry to a fixpoint, replay edges twice | [call] deferred, deferred-context, deferred-prepared, deferred-resolver; goldens `types-constructor-context`, `types-union-singleton` reach the screens but the transaction declines (report unchanged) |
| R21 | Prelude bootstrap | 11826-12024 | `prelude.jibb`, `internal.jibb` | `standard-prelude-list` pattern-matches `\|$ [A] $@(~ [i=A t=(list A)])` and publishes `%collection`; six hard-coded primitive schemes (11930); `infer-private-internal` proof retry; `prelude-label*` | all module-check goldens and 33 suites that prepare the prelude |
| R22 | API narrow branch `one-request-interface-graph` | 12904-12956, 14711-14721 | Blog API (one mark import, non-union paths) | Hand-built one-request interface; redundant with multi-request (A44); `one-request-interface-source` 12850 is dead | [out] page-main (blog API), request-guards |

### 3.2 Ad hoc slices of general inference (not fitted to one example, but replaced by the core)

| Slice | Lines | Replaced by |
| --- | --- | --- |
| Two-arm unit/list branches | 7923-8075 | usefulness over `~`/cell constructors |
| Three coverage loops + 64-row loobean expansion | 8103-8350 | usefulness |
| One-arm structured / cell-binder / empty-list / empty-union | 8351-8390, 8555-8608, 9852-9928 | one-row usefulness, empty types have no constructors |
| Speculative subject screens | 8477-8549 | infer subject once |
| `recursive-branch-seed`, blanket `infer-recursive-gate` retry | 10216-10325, 10705, 10729, 7646 | SCC let-rec with levels |
| `known-union-subject` double inference | 8541 |: |
| Loobean join failure classification | 8920-8929 | one join + deferred widen |
| Import-invalid replay | 7002-7097 | elaboration returning reasons |
| `module-pending-tag`, `module-missing-value`, `module-sample-shadow` | 10715, 12132, 12171 | per-definition errors from the core |
| Order-independence rules for locals | 7521-7584, 7633-7637 | SCC order + deferral |

## 4. What the core replaces, what it must keep, and the hazards

### 4.1 Replaced

| Core piece | Replaces |
| --- | --- |
| Union-find store over a map, path compression, one global fresh counter | `isub`/`ibinding` 4687-4688, `itype-lookup` 4691, `itype-walk` 4698-4732, `dg-scan` 15150, `ienv-fresh-id` 15666-15702, per-definition `next=0` (10699, 10752, 14759, 15107) |
| Kind on the root (any ⊐ gate-free ⊐ atom ⊐ atom-other-than-? / defaultable number) | `%fvar %avar %rvar %nvar %rnvar` (4666-4670), the pairwise lattice 4884-4925, self-binding refinement (4887-4889, 4962, 6119-6131), `itype-bind-gate-free` 4998 and its 256 budget, `itype-var-is-*` 6267-6343, `binders` bookkeeping for `unsupported-atom-vars` 10159 |
| Levels | `free-env-vars` 7307, `free-cap-vars` 7320, `shared-types`/`shared-moved`/`closed-local` 7534-7584, `dg-env` 15187, `dg-generalize` 15222, all-var quantification 10682/15141 |
| Deferred-constraint queue (woken on binding, reported at module end) | `%tag` + `ipending` + `pending-tags`/`pending-null` 5351-5370 + drop at 10680 + `module-pending-tag` 10715; holes 6133-6181 (as level-exit obligations); decimal defaulting 6062 and promotion 6119 (as level-exit defaulting); fit `%unknown` (5527-5711) as "enqueue"; `itype-fit-ctor-cases` 5474; field access 7720, change 8622, interpolation 8081, `proj` 9461, cell/cons literals 7834; the whole dg-* transaction 15147-15719 and its hooks |
| Bidirectional check mode (synthesize then unify/subsume with expected; push expected into arms and items) | most of `infer-call-context-arg` 9664-9783: contextual branches 7749-7921, unit context 9321, singleton 9480, tagged case 9477-9562, closed-cell retry 9564-9662, `infer-contextual-call` pre-unify 9355 |
| Maranget usefulness over a constructor signature taken from the subject type | 7923-8075, 8103-8390, 8395, 8425-8475, 8477-8608, 9852-9928, `dg-boolean-patterns` 15292; branch routing 8878-8930 |
| One nominal recursive mold `(module, name, args)` unfolded on demand | `%recursive`/`%jrec`/`%grec` 4679-4681, `simple-source-recursive` 6925, `simple-source-generic-recursive` 6954, `jrec-match-view`, `qath-static-fuel`, grec 15721-15835, `jrec-fuel` |
| SCC driver, one pass, scheme-or-error per definition | `resolve-groups-core` fixpoint 10736-10756, `add-supported-defs-core` retries, `add-groups`, locals' pass loop 7611-7681, `try-local-group` 7686, `dg-stage` 15487 |
| `main` as an ordinary application, sample-slot faces as labels | program chain 13342-14482, `direct-*` 9002-9228, `itype-closed-gates-match` 5229-5263, positional face rules 5313-5349, element fits 13751-13853 and hooks 7887-7891/7909-7913, `static-main-specialized` 14487, store component recovery 14599-14648 |
| One pipeline (Q6) | report re-inference 15079-15146; its separate finalization 15117-15143 |
| Five finalization copies (2.8) | one generalization step at level exit |

### 4.2 Kept (retargeted to the new representation, behaviour preserved)

- **Printers**: `show-itype` 9930-9995 (A-Z then T26…, `(label args)`, space-separated unnamed unions, parenthesised in context), `site-type-note` 10024, `show-atom-constraint` 10171, `canonical-itype` 6345 with `itype-vars` order 6183 (fn sample before product, head before tail, union args before cases) and kind precedence rvar > avar > fvar > var, `show-partial-mold` 11431 (until Q6 changes the report), `show-inference-diagnostic` 11458, `show-duplicate-fields` 11470, `prelude-label*` 11870-11911, `itype-in-import` labels 6806 (display separate from identity).
- **Error wording and site notes** (golden-pinned; full list in 4.3).
- **API path analysis and derived interfaces**: 12326-13144 and 14314-14470, `derived-name-clash` 13289, request-graph 12202-12274, watchability; they synthesize schemes into interfaces before consumers are checked. The hand-built schemes should become instantiations of declared templates.
- **Hoon importer bridge**: 6397-6728 plus `jibb-dev/lib/jibb-import.hoon`; the import-invalid wording (`invalid imported mold` + importer message).
- **Overlap witness and disjointness**: `upat`/`union-relate`/`union-pairs` 10904-11022/11275, `mold-overlap-witness` 11296, `module-mold-overlap` 11786, `jfile-overlap` 11513 evidence. `union-relate` is also the importer's disjointness relation (6477, 6665), so either keep `upat` as the importer projection or give itype a pattern view.
- **Pre-inference passes**: duplicate fields 11520-11693, scope and reserved `proj` 11694-11773, dependency extraction 10327-10428, Kosaraju 10552-10643, value-cycle diagnosis 10785-10900 (wording), module graph and cache 12190-12324.
- **Elaboration**: `infer-simple-shape` 7099 / `infer-mold-template` 6970 / `label-direct-union` 6843 (mold → type, origin assignment), `proj` planning 5835-5923, 9396-9475, `width-finalize` 10535 (artifacts), `gate-free-type` 5925-5992 as a post-solve check with witness path.
- **Kind boundary** as post-solve matching of `main`'s closed type against prelude molds; watch/load provenance checks; store-derived exports.

### 4.3 Hazards

1. **Golden output moves.** All 304 `types.txt` come from the report path. Pinned fail-closed lines: 80 `tag needs context in partial inference`, 24 `` `~` needs context ``, 32 `call constraint is not supported…`, 37 `cast constraint…`, 5 `record width constraint…`, 5 `proj constraint…`, 6 `type hole needs unsupported inference`, 6 `unresolved aura-variable inference`, 4 `call result face propagation`, 31 `local definitions need unsupported inference`, 47 `name is not available to partial inference`; 127 goldens contain some unsupported text. Mold lines: 171 `+$ X: not checked`, 171 `cases proven disjoint; mold not checked`, 6 `case disjointness unresolved`, 22 `overlapping cases`. A stronger core changes these; each stage must either keep the exact `%unknown` sites or budget a deliberate golden update (Q6 predicts ~283 outputs change once).
2. **Definite wording to keep byte-exact**: `call's sample and argument types do not unify` + `called gate`/`argument` (116 golden lines, 53 goldens); `branch arms have incompatible types` + `first arm`/`second arm`; `cast mold and expression type do not unify` + `cast mold`/`expression`; `{label} has no case `%x`` + `expected union`/`tag` (8706); `record has no field `x`` + `unknown field`; `change field and replacement do not unify`; `a change takes at least one field` + `empty change`; `missing union case X` (no sites, first remaining case); `branch arm is covered by earlier arms` + `covered arm`; `branch does not cover both loobeans`; `nothing fixes the union of %x` (5363; `tests/type-buttons/error.txt`, program-init, program-update; not in any golden); `non-gate value depends on itself through a cycle` + `value in cycle`/`dependency in cycle`; the long capitals message (7669, 15126) vs the short one (10495); `type hole needs a determined type` + `unresolved type hole`; `a generic atom in interpolation needs an aura`, `a cell in interpolation needs a printer`; `record field `x` is repeated` + `first field`/`repeated field`; derived-name clash texts; module/API texts in 1.2(b).
3. **Sites decide definiteness.** `definite-diag` 7521 treats site-less diags as retryable; several definite-sounding errors have no sites (`missing union case`, `pattern binder shadows a name`, `unit present pattern is unreachable`, `sample shadows a name`). Adding sites changes local-definition outcomes (they stop ending as `local definitions need unsupported inference`).
4. **Message precedence is order-dependent**: report checks 15117-15143 in fixed order; loobean join classification 8921-8929; missing tag → nested tag → generic after every `%bad`; union coverage checks `%unknown` before coverage and `covered` before `not supported` (A15); locals report the earliest failing local (`rear sure`, 7636); finite expansion prints `%.n` rows before `%.y`; the full check reports pending tag, then shadowing sample, then missing value (14821-14832); API precedence poke-only → clash → scope → import error → constructor reason.
5. **Unification semantics goldens rely on**: unequal atoms never unify; argful named unions unify by args only, argless by raw case equality (A11); `%var` binds faces, unions, tags; a `%tag` vs non-var fails in unify; faces must match by name; fit is invariant for gates; `*` accepts gates (A23, pending Q18) and binds bare tags (A22); term literal fits `@tas`/`@ta` with no aura check (A20); `?` vs `@f` is unknown; zero vs list unknown; only `@` allocates in fit.
6. **Self-binding invariant**: any self-binding other than `%fvar`/`%rvar`/`%rnvar` loops `itype-walk`. A staged migration that keeps `isub` alongside a union-find store must keep this invariant or convert at the boundary.
7. **Ids**: ids restart at 0 per top-level definition, `itype-rename` is single-pass, so scheme ids may coincide with fresh ids by design (6008-6010); `module-mold-types` reuses one base state per mold, so template ids repeat. A union-find store must never assume scheme ids are globally unique; instantiate always.
8. **Rollback**: speculative attempts drop state; tests assert that failed retries return the original result and replays leave `sub`/`next` byte-identical (cell-branch, direct-gate-guards, deferred). A mutable store needs a trail/snapshot or a persistent map.
9. **Provenance screens**: grec, tagged-case and closed-cell screens decline if any substitution entry is structural; `infer-call-context-arg` reads raw `expected` at 9732, 9743, 9756. Behaviour of these slices depends on inference order; a new store changes when they fire.
10. **Budgets pinned by tests**: `jrec-fuel` 256 (qath-fuel uses 0/1/2); grec arms 128; closed-cell screens 512 (cell-branch tests the limits); `union-source-distinct-tags` 18 ok / 17 declines; `union-source-overlap` 20/19; `module-mold-params-valid` 256/257; `union-source-state-safe` 256/257 caps; `dg-direct-source` 63/64 wrappers, `dg-source-candidate` 64/65 defs; `ienv-fresh-id` results `2.000.002`, `1`, `10`; `dg-generalize` results `~[43]`, `~[81]`, `~[722]`, `~[713]`. Other literals: empty proof 256 in fit, live cases 4,096, inhabitation 256, finite 64, width 1,024/4,096, gate-free 256, obligations 62/63/64, `module-pending-tag` 64, request graph 256/256, `api-request-gates` 256.
11. **`istate` shape**: 27 positional fields at 10 literal sites, 5 bunts, `dg-stage-one` compares 22 fields (15458-15479), 13 suites build `istate:jibb` (some positionally). Adding union-find, level or queue fields touches all of them; a constructor arm (A28/A125) should come first.
12. **Interfaces are hashed nouns**: `iwidth-definition` carries the raw `sub` (10687) into `ifile.elaborations`; cache reuse compares inputs by equality (12219, 12275). Changing the representation changes interface nouns, cache keys and anything comparing `ifile`s (`request-graph-merge` dedup, `derived-request-member` evidence equality).
13. **Structural `=` certificates**: `compatible-raw-poke`, `request-compatible-ask`, `derived-poke-command-scheme` (five `cmd` cases in order `poke go wait now who`, label `raw-poke`), `store-main-closed`, `derived-request-member` (`∀m. $-($-(full m) (ask m))`), `derived-store-request-member`. A new var representation must keep these equal or replace them with template comparisons; any edit to `prelude.jibb`/`internal.jibb` silently disables them.
14. **Printer stability**: variable letters depend on `itype-vars` order and kind precedence; `site-type-note` suppression rules; nvar/rnvar print as atom constraints; `(unit qath)` and other public labels rely on `prelude-label-nested` (A134; jibb-theme).
15. **Prelude identity checks**: exact list scheme compared at 7844, 7996, 8572, 8800, 14767 (and built at 11920, 11979, 12013, 12064); unit via `standard-unit-template` 8646; `element` by origin `[at.prelude %element]`; qath must be `%jrec` at `/lib/jibb/internal/jibb` (8816). The core must expose the same identities or these paths all fail closed.
16. **Two pipelines**: changing the resolver or finalization in one pipeline without the other moves goldens or suites (A46, A122). The golden report also runs the full check on imported case-local modules (14989), so module-check goldens see both.
17. **Recovery adapters**: until R1-R10 are retired, they call `itype-fit` (22×), `itype-merge-faces` (12×), `instantiate-scheme` (12×), `direct-invariant` (16×), `template-apply` (15×), `infer-sample`, `reserve-def-caps`, `record-fields-named`, `itype-in-import`, `add-supported-result` (6×), `infer-call-context-arg` (6×), `ienv-fresh-id`; and they mix substitutions on purpose (body inferred from the sample's own sub with the gate-fit's `next`, 13418-13421; mapper from `initial`). A core that threads one store changes their edge behaviour.
18. **Negative fixtures that encode recovery limits, not spec errors**: `tests/type-todo-full/ambiguous-mapper.txt`, `alias.txt`, probably `open-key.txt`; generic strings `module definitions need unsupported inference: /p: ++ name` and `module kind needs unsupported inference: /p` asserted by program-update/init/main. An ordinary-application core will accept or reject these differently; decide per fixture.
19. **`program-single-generic-fit` is in ordinary inference** (7890, 7912) for any prelude `element` target, so removing the program recovery does not remove it; `types-prelude-ui` and `doc-grammar-02-buttons` depend on the path that reaches it.
20. **Performance**: assoc-list lookups and 95 `itype-normalize` calls; `unique-type-vars` O(n²); `free-env-vars`/`dg-env` rescans per generalization; `itype-fit-cases` re-fits every case; subjects inferred twice; whole-to-finite re-inference; prelude re-parsed per `direct-prelude-evidence` call (A132); report re-infers every definition; compiler.md:67-69 reports 38-72 s CPU for 2,000 gates. Brief l.141 asks for seconds.
21. **Deviations from the spec the core should not copy unknowingly**: gates fit `*` (Q18 pending), tag fits `@tas`/`@ta` without aura check (Q16/Q17), faces handled by asymmetric guards instead of "unnamed acquires the face" (S1 pending), argless union identity by raw cases (A11), only list/unit in inhabitation/gate-free (A13), arms matching no case reported as unsupported (Q22), decimal defaulting skipped in locals and gate types (compiler.md:59 notes defaulting in gate types is incomplete).
22. **Dead code not to port**: `itype-has-fixed-atom` 5098, `width-has-projections` 8988, `infer-width-elaboration` 8995 and `iwidth-elaboration` 8994, `direct-find-gate` 9058, `resolve-supported-defs` 10780, `golden-types-with-modules` 14939, `one-request-interface-source` 12850, unreachable `!!` at 14258 and 14525, the last `[%& …]` of `dg-boolean-branch` (15351), the always-`~` `captured` argument of `dg-generalize`, misplaced headers (5014-5018, 6008-6010, 6320-6321, 6397-6403, 5835-5837), the stale comment at 11502-11505.

### 4.4 Seams a staged plan can use (observations, not a plan)

- `golden-types-in-context-core` re-infers each definition independently (15107-15114), so a new core can be swapped in per definition behind the same printer and finalization, leaving `resolve-groups` in place, before the full check changes.
- The full check's recovery chain only runs for components still missing after `resolve-groups-core` (`?^ (ienv-lookup …) ~` at the top of each arm). A core that resolves a component ordinarily turns its recovery arm into a no-op without deleting it; the `cast-init` regression already guards that ordering.
- `itype-fit`'s three-valued API can be preserved over a new store as long as `%unknown` stays the answer for "would need a queued constraint" in the old callers; R1-R10 are its heaviest users.
- The dg-* transaction is reachable from the full check only without a prelude (14809) and from the report only on eligible sources; its tests are self-contained (four suites), so it can be retired as a unit once the queue exists.

## 5. Entry points that must stay stable during a staged migration

### 5.1 Tools (signatures are checked)

| Arm | Line | Caller |
| --- | --- | --- |
| `golden` | (%api chapter) | `tools/golden` (parser outputs), module trees |
| `golden-types` `[file=path src=@t] -> @t` | 11486 | `tools/golden:251-253` (signature enforced at `tools/golden:407-408`), `tools/ship:1234` |
| `golden-types-imports` | 11497 | `tools/golden:252`, `tools/ship:1257` |
| `golden-types-with-marks` | 15016 | `tools/golden:248`, `tools/ship:1288` |
| `golden-types-with-prelude-and-internal` | 14969 | `tools/golden:259`, `tools/ship:1345` |
| `golden-types-with-prepared-prelude` | 14975 | `tools/golden:260`, `tools/ship:1346` |
| `prepare-prelude-with-internal` | 12103 | `tools/golden:291` (under `mule`), `tools/ship:1222` |

### 5.2 Module-check API (suites, and itself recursively)

`infer-jibb-file` 14650 (23 suites; also builds the internal prelude, 11956), `infer-jibb-file-detailed` 14658 (12 suites; `resolve-jibb-imports-detailed` 12316/12320), `resolve-jibb-imports` 12286 (deferred-resolver, generic-recursion), `prepare-prelude` 12092 (api-evidence, poke-bridge), `prepare-prelude-with-internal` (33 suites), `golden-types-with-prelude` 14955 (bridge, list-alias-guards, module-scope), `golden-types-with-reader-diagnostics` 15007 (bridge, import-*), `golden-types-in-context` 15021 (empty, union-alias-overlap, union-source), `golden-types-in-context-core` 15025 (deferred-prepared), `gate-free-mold-source` 14887, the API evidence arms (`api-path-analysis(-source)`, `api-path-evidence-source`, `api-path-parameters`, `api-path-watchability`, `api-request-parts`, `api-support-analysis-source`, `api-poke-interface`), `find-jibb-cache`, `request-graph-bounded`, `request-graph-reusable`, `module-scope-valid`, `module-mold-params-valid`, `program-main-def`, `program-main-parts`, `page-main-parts`, `parse`, `show-error`, `show-itype` (11 suites), `canonical-itype` (buttons, deferred-resolver, doc-examples), `record-fields-named` (program-init/main/update/watch), `itype-in-import` (5 suites), `itype-vars` (page-main, program-watch, store, theme), `ienv-lookup` (17 suites), `find-jibb-mold` (13 suites), `find-jibb-interface`, `find-simple-mold`, `collect-simple-molds`, `find-imported-mold`, `find-imported-mark`, `import-to-itype`, `template-apply`, `identity-union-parameters`, `prelude-union-alias`, `compatible-raw-poke`, `request-compatible-ask`, `derived-poke-command-scheme`.

### 5.3 Substrate arms called by suites (keep or migrate the suites in the same stage)

`itype-fit` (8 suites: arithmetic-guards, closed-gate-guards, constructor-fit-guards, deferred, empty, generic-construction, generic-recursion, qath-fuel), `itype-unify` (arithmetic-guards, gate-free-guards, generic-recursion), `itype-unify-test` (typecheck), `itype-walk` (arithmetic-guards, deferred), `itype-lookup` (hole-guards), `itype-normalize` (deferred, generic-construction), `itype-empty-proof`/`itype-inhabited-proof`/`itype-live-cases`/`empty-list-null-branch` (empty), `itype-gate-free-form`/`itype-collection-keys`/`itype-var-is-gate-free`/`instantiate-scheme`/`template-apply-sub` (gate-free-guards), `gate-free-type` (empty, gate-free-guards, generic-recursion), `itype-has-face` (deferred, empty), `itype-face-asym`/`itype-output-may-be-cell`/`pending-tags`/`unsupported-atom-vars` (deferred), `itype-positional-face-asym` (positional-face-guards), `itype-positional-slot-face-asym` (direct-gate-guards), `itype-fit-ctor-cases` (constructor-fit-guards), `itype-has-gate`/`default-decimals` (generic-recursion), `default-hole-numbers`/`simple-mold-hole` (hole-guards), `infer-fragment` (cell-branch, deferred, generic-pattern, qath-source), `infer-call-context-arg` (generic-construction, qath-fuel), `infer-simple-shape` (union-source).

### 5.4 Recovery and dg arms called by suites (retire with their suites)

direct-gate-guards: `direct-checked-gates`, `direct-gate-call-fit`, `direct-gate-sample`, `direct-positional-fit`, `direct-prelude-evidence`. cell-branch: `closed-cell-branch-eligible`, `closed-cell-retry-safe`, `closed-cell-sub-safe`, `infer-closed-cell-branch`. nested-union-guards: `contextual-direct-union`, `contextual-simple-sub`, `contextual-tagged-case`. constructor-fit-guards: `explicit-singleton-in-union`. qath-fuel: `jrec-match-view`, `qath-static-fuel`. generic-*: `simple-source-generic-recursive`, `grec-direct-context`, `grec-match-view`, `grec-patterns-eligible`, `grec-single-wing-subject`, `grec-unfold-view`. union-source: `grec-collect-molds`, `union-source-distinct-tags`, `union-source-state-safe`. union-alias-overlap and full-overlap-basic: `union-source-overlap`. program-main/-watch/store: `program-main-closed`; page-main: `page-main-closed`. deferred*: `dg-close-env`, `dg-direct-source`, `dg-generalize`, `dg-obligations`, `dg-replay-edges`, `dg-root-detail`, `dg-root-prepared`, `dg-root-source`, `dg-scan`, `dg-source-candidate`, `dg-stable-call-fit`, `dg-stage`, `ienv-fresh-id`.

### 5.5 Types constructed by suites

`itype` (32 suites), `iprelude` (32), `ifile` (25), `ischeme` (24), `istate` (13: cell-branch, deferred-context, deferred, direct-gate-guards, empty, gate-free-guards, generic-construction, generic-pattern, generic-recursion, hole-guards, qath-fuel, qath-source, union-source), `ienv` (11), `isub` (10), `iresult` (6), `ifit` (6), `upair` (3), `irequest-graph`/`irequest-evidence` (3), `dgo`/`ipending`/`igate-free`/`iwprojection`/`iwidth-definition` (2), `istore-request-evidence`, `igate-prelude-evidence`, `igf-form`, `igf-segment`, `ibinding`, `dgscan`, `dgparse`, `dgcommit`, `grec-collected` (1 each). Q37 decided tests keep calling internal arms (A126) until the core lands; a facade or same-stage suite edits are required for every renamed arm or reshaped type.

## 6. Spec rules the core must meet, and open rulings

Repository spec wins over the design doc (review Q42); several type-system rows in `decisions.md` are still marked unsynced.

### 6.1 Rules

| Topic | Rule (short) | Where | Core requirement | Today |
| --- | --- | --- | --- | --- |
| Inference basis | HM with aura variables; principal types; no general subtyping except listed one-way widenings and explicit `proj` | grammar.md l.121; decisions.md l.35; implementation-plan.md l.15; milestone-2.md l.39, l.62, l.141 | Union-find + levels; widening as directional constraints outside unify | assoc list, env scans, fit mixes widening and unification |
| Atoms and auras | `@` any atom per occurrence; specific auras distinct; aura fits `@` and Hoon-family ancestor; reverse needs a check | grammar.md l.124; decisions.md l.59, l.35, Q15 l.134, Q19 l.142 | `fit(actual, expected)` constraint that waits while actual is unbound; unify never widens | `aura-prefix` 5052, fit 5663-5680, `itype-concrete-join` 5125 |
| Noun | `*` is the noun type, top of fit only; arbitrary noun does not fit narrower | grammar.md l.121, l.132; decisions.md l.49, Q9 l.122 | unify(`*`, T) fails unless T is `*` | 5549-5557 accepts gates (Q18) |
| Empty and crash | `!!` expression has any type; mold `!!` empty; empty-position cells empty, disjoint from all | grammar.md l.62, l.127, l.132; decisions.md l.48, Q17 l.138 | crash = fresh var; usefulness drops uninhabited constructors | `%empty`, 4744, 5521-5525 |
| Loobeans | `?` = {0,1}; disjoint from cells, overlaps 0 and 1; arithmetic rejects, comparison accepts | grammar.md l.124, l.127, l.59; decisions.md l.52, l.60, Q16, Q28 | finite constructor set; "atom other than ?" kind | `?` vs `@f` unresolved (5546-5548) |
| Constants | singletons compared by noun (`%$` = `%.y` = `~` = 0) | grammar.md l.29-31, l.125, l.144; decisions.md l.29, Q34 | key singletons by noun in unify, fit, ctor, patterns, disjointness | `%const` by value 4926, 5617 |
| Literals | decimal `@ud` or any aura by context; prefixed numbers, ships, dates, knots, cords; `` `x ``, `~[…]`, `a+b`, paths, qath read as Hoon | grammar.md l.19-39; decisions.md l.14, l.58 | literal → type or var + literal constraint; prelude unit/list/path/qath templates available | 8770-8821 |
| Faces | faces are part of types; unnamed position unifies with faced and takes its face; different faces don't unify; duplicate fields error (also imported); `[a]` is `a`; `[]` error; theme `dark=[tones=…]` must check | grammar.md l.126, l.33; decisions.md l.15, l.42, l.35, Q5, Q8, Q21, Q27 | label slot that may be unknown, bound by unification | `%face` wrapper + asymmetry guards 5212-5349 |
| `proj` | explicit, type-directed; expected type selects fields; evaluated once; never inserted implicitly; reserved name | grammar.md l.126; decisions.md l.43; core-language.md l.85; Q32 | deferred `proj(S) : T` with recorded axes | 5835-5923, 9461, 10535, 11706-11760 |
| Capitals | generalized per `++`; local `++` shares an enclosing capital it also uses; cannot force two capitals equal; cannot become more specific | grammar.md l.129; decisions.md l.50, Q4, Q23; milestone-2.md l.66 | rigid (skolem) vars scoped before inference; violations name both sites | `merged-capitals` 10072; forcing concrete is "unsupported" (10089) |
| Atom/arith constraints | atom constraint and "atom other than ?" retained through generalization and instantiation; printed as where-clauses separated by commas | grammar.md l.124, l.137; decisions.md l.31, l.60, Q28, Q29 | kind lattice on roots | six var kinds, A16 |
| Gate-free | `eq` args and map/set keys contain no gates; inferred and generalized; printed `where A contains no gates` | grammar.md l.137; decisions.md l.33, l.106; core-language.md l.39 | gate-free kind, structural propagation, binding a gate fails with sites | `%fvar`, 4998, 5951 |
| Holes | `_` wherever a mold may; resolves to a concrete type or written capital; unconstrained is an error; a definition determines its own holes | grammar.md l.123, l.130; decisions.md l.51, Q30, Q31 | hole var with span checked at its level exit | 6133-6181 |
| Order, recursion, value cycles | any order; gates self/mutually recursive; non-gate value depending on itself is an error; infer in dependency order, groups together | grammar.md l.56, l.101; decisions.md l.23; core-language.md l.145; milestone-2.md l.66, l.141 | one SCC pass; value cycles reported from the graph | fixpoint fallback 10749-10756; cycle proof needs a cast |
| Locals | `++` at the start of any body; mutually visible; generalize locally, captured outer vars shared | grammar.md l.56; decisions.md l.22; milestone-2.md l.97 | levels + same SCC machinery | 7611-7681 |
| No shadowing | samples, locals, pattern binders, imports, prelude | grammar.md l.101; decisions.md l.13; core-language.md l.37; milestone-2.md l.95 | scope pass with sites | several site-less messages (8018, 8240…) |
| Namespaces | molds and values separate, by position | grammar.md l.102; overview.md l.305 | two tables per scope/interface | `ifile` 5822 |
| Tag resolution | tag/`~` = fresh var + pending constraint; non-union = one-case union; checked by shape and shared tag positions, field positions against fields; `@tas`/`@ta`/`@`/`*` make it that constant; no match → `msg has no case %submitt` | grammar.md l.141-143; decisions.md l.29; milestone-2.md l.77 | the deferred queue, woken on binding | `%tag` 4676, 5451, 8693, 8711 |
| Non-generalization, module end | tag-constrained vars (and what they mention) do not generalize; an island's `main` fixes its messages; open at module end → error asking for `^-`, never guess | grammar.md l.145-146, l.150-158; milestone-2.md l.79 | keep such vars at module level; module-end pass reports `nothing fixes the union of %add` | dropped at 10680; recovery R1-R5; `module-pending-tag` |
| `\|=%tag` | case constructor typed by the expected gate; any case whose head noun equals the tag; no such case is an error | grammar.md l.48, l.141, l.144; decisions.md l.47, Q34; milestone-2.md l.78, l.124 | deferred ctor constraint on the product's root | 5474 |
| Numbers by context | wait for context; default `@ud` at the `++` only if unfixed and not generic over it | grammar.md l.162-167; decisions.md l.35; milestone-2.md l.81 | defaultable kind, defaulted at level exit unless linked to a quantified/rigid var | 6062, 6119; incomplete in gate types (compiler.md:59) |
| Cell literals | tuple, record or cons (under list); default tuple | grammar.md l.33, l.168, l.172 | deferred cell constraint | cons only under known list context (7834) |
| Null | `~` is the `~` case of any union that has one | grammar.md l.31, l.141 | same queue keyed on noun 0 | 5365, 5613-5616 |
| Waiting | wing access, changes and `?-` on unknown types wait; patterns don't; `m()` error | grammar.md l.147-148, l.45, l.47; decisions.md l.13, Q6 | deferred has-field / edit / match constraints | 7720, 8622 need a known spine |
| Samples, inline gates | every bare name in a sample binds; `\|=(p title.p)` works when the call fixes the type | grammar.md l.48, l.58; decisions.md l.21, l.47; milestone-2.md l.69 | relies on deferred wing access |: |
| Calls | right-nested sample; parentheses only group | grammar.md l.43; core-language.md l.29, l.88 | apply = unify/fit with `$-(sample result)` | several call paths |
| Named unions | every Jibb union is named; imports may be unnamed; identity = origin + args, display separate | grammar.md l.57, l.127; decisions.md l.29; overview.md l.77 | nominal identity | raw-case equality (A11) |
| Disjointness | cases must differ as nouns (for all generic args); `*`, vars and `(list A)` overlap; `!!` disjoint; imported `$% $? $^` too; unverifiable imports fail closed; error suggests leaving `[` open | grammar.md l.127, l.94; decisions.md l.29, l.41, Q16, Q17, Q22; overview.md l.66-68; milestone-2.md l.86, l.125; jibb.hoon 4620 | noun-shape signature shared with usefulness; overlap witness naming both sites | 10909-11302 |
| Generic molds | `\|$ [V E]` right after `+$` name; prelude `cmd`/`sub` use `\|$ [M]` | grammar.md l.64, l.131; milestone-2.md l.70 | templates instantiated at exact arity; unions keep origin/args | 6970, 6355; recursive generics only via grec |
| Recursive molds | allowed; identity by name and module; imported (e.g. `json`) matched by name | grammar.md l.57, l.135; decisions.md l.56; overview.md l.74 | one nominal recursive type unfolded on demand | three forms |
| Containers | list, unit, set, map, mop, qeu, jar, jug; imported maps/sets checked with `apt`; keys gate-free | grammar.md l.128; overview.md l.70-71, l.88, l.102 | inhabitation and gate-free over all containers | list/unit only (A13) |
| `?-` | exhaustive, ordered; missing case error naming it; covered arm error; nested patterns allowed; last position binds the rest | grammar.md l.59, l.184-219, l.276-277; decisions.md l.32, l.57; milestone-2.md l.89-92, l.142 | Maranget usefulness with witnesses; one matrix also for milestone-3 lowering | three loops + slices; nested mostly unsupported |
| Pattern typing | patterns checked against the subject; binders take position types | grammar.md l.148, l.184; core-language.md l.92-93 | binder types from specialized matrix columns | `union-pattern-bind` 8156 |
| Branch join | unify, else widen only to an explicitly present parent aura or `@`; with an expected type each arm fits it | questions.md Q11; A133; grammar.md l.121 | unify + deferred widen; check mode with expected | 5138, 5202 |
| Interpolation | atoms print by aura (`@` as `@ud`); text auras and tapes splice; other cells error; generic aura error here and in qath segments; `~&` printer from type | grammar.md l.49, l.170-171; decisions.md l.58; core-language.md l.79, l.95; milestone-2.md l.82 | deferred printable constraint decided at level exit; record the printer | 8081 rejects late-known types |
| Paths | constant, empty, typed by aura (`_` allowed); qath with printable segments; route check is milestone 4 | grammar.md l.130, l.36-37, l.173; overview.md l.337 | path mold kind; same printable constraint | jrec qath |
| Imports, module values | `/-`, `/%` (no face), `/=` under a face; records read with `.`; module as a value is a cell of definitions in name order; APIs re-export `/%` types; import cycles are errors | grammar.md l.86-94, l.104, l.47; core-language.md l.146; overview.md l.305; milestone-2.md l.98-99 | interface noun; faces as record access with per-use instantiation | `ifile`, 12293, cycle 12304 |
| Hoon import table | `$% $? $^` unions if disjoint; `$@`; `$~` dropped; containers by name; tags `%0 %& %\|`; recursive by name; errors where used for duplicates, cores, gates, vases, signed/float auras | overview.md l.60-77; grammar.md l.94; decisions.md l.41, Q21, Q22; milestone-2.md l.102-104, l.134-140, l.153 | imported molds become the same core types; unsupported molds poisoned at use | 6527-6728; whitelist triplicated (A14) |
| Module kinds | main's type decides: `(element !!)` page, `(page R D)`, `(program D X M)`, `(store S)`, none = library; built by builders; stages never inferred | grammar.md l.103, l.107-117; overview.md l.106-115; decisions.md l.55, l.66, Q11; milestone-2.md l.100, l.107 | post-solve match of main's closed type; main ordinary (Q5) | syntactic recognisers 13146-13240 |
| Islands | `main` record of exactly init/update/view/subs; `island` checks data against init's sample; update/subs/init types from the prelude | overview.md l.112, l.115-121, l.155, l.166; grammar.md l.293-343; decisions.md l.70-71 | follows from prelude types once tags defer across `++` | R1-R6 |
| Gate-free island data/model | no gates in data and models; name the field | overview.md l.121; decisions.md l.73; core-language.md l.39; milestone-2.md l.109, l.124 | post-solve gate-free check with witness path | `program-main-closed` 14555 + 5951 (256) |
| Effects | `cmd`/`sub` prelude unions with `\|$ [M]`; `raw-poke`, `ask`, `qath` transparent internal types re-exported | overview.md l.140-160; grammar.md l.133-134; decisions.md l.36-37, Q24, Q25 | generic unions with gate payloads; public names in printing | `prelude-label-nested` 11878 |
| Stores | `state`, local `+$ poke`, `++ main (store init update)`; builder `\|= [init=S update=$-([A S] S)] ^- (store S)`; kind check verifies A against poke; derived poke helper and state request; one store per page | overview.md l.168-169; grammar.md l.105, l.293-306, l.343; decisions.md l.77-78, Q11 | record A's instantiation at main's application, or check update against `$-([poke state] state)` | R8 |
| APIs | `/ui/api/<agent>.jibb` declares `+$ poke` and `+$ paths` (declarations); `(facts full diff …)` with fold `$-([[%mark diff] full] full)`; optional `scry=`; derived poke helper and one request per case; clashes are errors | overview.md l.283-307, l.157-158; grammar.md l.105, l.134; decisions.md l.38-40; milestone-2.md l.111-114 | declaration elaboration into interface schemes | 12329-13148 |
| Watchability | islands read agents only by watching; first fact full state; a `scry=` case cannot be watched; unproven watchability is a type error; store state is watchable | overview.md l.159; grammar.md l.105; decisions.md l.38, l.79, Q33 | type-level marker or provenance analysis over the elaborated tree | one syntactic watch shape (14367) |
| Pages with data | `load` maps route parameters to one `ask`/`pure`; `view` takes D, returns `(element !!)` | overview.md l.125-130, l.334; grammar.md l.103; decisions.md l.67; milestone-2.md l.161 | ordinary application of `page` | one load shape (14512) |
| Elements, attributes | elements are ordinary gates; duplicate attribute in a literal list is an error; `~[text "hi"]` gets a suggestion | overview.md l.174-204; grammar.md l.44; milestone-2.md l.121, l.124 | type-directed post-solve checks | absent |
| Theme | `++ theme ^- theme`, backtick units | overview.md l.211-222; decisions.md l.83, Q5 | plain record check | works (uses R17 for the qath font) |
| Prelude | Hoon stdlib regrouped in Jibb with a complete inventory; private internal module | overview.md l.81-102; decisions.md l.87-88; open-questions Q3; milestone-2.md l.116-121 | prelude checked by the same core and exported as an interface | partial interface (compiler.md:159) |
| No built-ins | type-directed rules only if listed in the Grammar; special cases for one gate are language changes | decisions.md l.34; milestone-2.md l.28 | `program`, `page`, `store`, `each`, `turn`, `element` as ordinary gates | R3, R7 are gate-specific |
| Printing | Jibb mold syntax; unnamed unions as space-separated cases; where-clauses; no private names | grammar.md l.137; overview.md l.77; decisions.md l.30-31; milestone-2.md l.143, l.148 | keep origin/name through solving; canonical names past 26 | 9930, 6345, 10171 |
| Errors | each error names both sites with excerpts; messages are golden tests; catalogue (aura mismatch, faces, missing case, open constraint, ctor, overlap, missing `?-` case, covered arm, self-dependent value, shadowing, interpolation, capitals, `~[text "hi"]`, clashing derived names, import cycle, `(facts …)` misuse, gate in island data, repeated attribute) | implementation-plan.md Risks; milestone-2.md l.48, l.123-127 | every constraint carries spans; union-find keeps a reason per binding | `idiag` 5997; 283 unsupported lines |
| Elaborated output | types/faces/casts leave nothing; lowering needs field axes, edits, decision tree, `proj` plans, printers, path validators | core-language.md l.74-98, l.33-41 | apply the final substitution to a typed tree | only width artifacts (5808) |
| Checker as function | caller passes Clay inputs; interface is its own noun; cache with interface and body hashed separately; modules one at a time in dependency order | milestone-2.md l.133; implementation-plan.md (pipeline, cache row); compiler.md:19 | interfaces store generalized schemes with constraints and mold templates | `ifile`, `prepare-prelude` |
| Speed | a 2,000-line module checks in seconds | milestone-2.md l.141, l.155; implementation-plan.md Risks | near-constant find, level generalization, one SCC pass | 38-72 s CPU for 2,000 gates (compiler.md:67-69) |
| Golden types | third golden output: each definition's type and the module kind, or the rendered error | milestone-2.md l.148; questions.md Q6 | one pipeline returning scheme-or-error per definition | all 304 from the report path (A122) |

### 6.2 Open rulings that affect the core

| Ruling | State | Effect on the core |
| --- | --- | --- |
| open-questions.md Q3 (prelude inventory and signatures) | open | Fixes the environment the core checks against; the prepared prelude is partial today |
| open-questions.md Q32 (`proj` reordering) | partly settled | How `proj` constraints discharge (jibb.hoon 4625 treats reordering as a doc question) |
| Review Q16 (A20): follow Hoon, `%1.000` is `@ud`, `%&` is `?` | proposed, awaiting @iko | How tag constraints discharge against atoms (today 5617-5626, 5636-5648) |
| Review Q17 (A20): a name term fits `@t` | proposed | Same discharge rule |
| Review Q18 (A23): `*` may hold gates | proposed "yes" | Fit to `*`, gate-free proofs, element's child erasure to `*` (prelude.jibb l.447-466), core-language.md l.33 |
| Review Q19 (A6, A100): reject `[]` and `m()` in the parser | proposed | Otherwise the core must reject them |
| Review Q20 (A30): `[a=@ud [a=@t b=?]]` is one record, duplicate `a` is an error | proposed | Record and field-access semantics (today nested tails get their own scope, 11556) |
| Review Q21 (A25): `/% %foo` beside `++ foo` | proposed | Scope check (11760) |
| Review Q22 (A15): an arm matching no remaining case is definite (`arm matches no case`) | proposed | Usefulness reports a useless row; today `union pattern is not supported` (8236, 8273, 8324) |
| Review Q23 (A55): `(mop K V)` without comparator | proposed | No comparator in the type |
| Review Q24 (A64): Hoon's `each` mold beside the `each` gate | proposed | Relies on separate namespaces |
| Review Q26 (A50): importer learns `$%` with `%& %\| %0` tags, then `each` and `json` | proposed | Which imported unions reach the core |
| Review Q28 (A136): printer flattens `[a [b c]]`, prints named molds by name | proposed | Core must keep mold names through solving |
| Review Q6 (A122): render the report from the full checker | decided, not done | ~283 `types.txt` change once |
| Review Q37 (A126): tests keep calling ~137 internal arms | decided; revisit after the core | Keep arms or move suites behind a facade per stage |
| Syntax review S1: capitals bind only the type under a face; gate sample names ignored when gate types unify | question for @iko | Decides the face rules; reopens decisions.md l.33 and settled Q8; directly decides whether R11-R13 become unnecessary |
| Syntax review S3: samples/binders/locals may reuse prelude value names | question for @iko | Shadowing pass; todo-list's `[%typed text]` fails today |
| Syntax review S4: bare decimal fits only `@ud @u @ *` | question for @iko | Number-literal constraint (grammar.md l.21 says any aura) |
| Syntax review S5: a pattern name spelling a case tag at a union position is an error | question for @iko | Usefulness-time check |
| Syntax review S7: multi-letter type variables | question for @iko | Printer and capital scoping |
| Syntax review S12: nested cell patterns shown in the spec | question for @iko | The EBNF allows them; the prelude uses nested `?-` because the checker lacks them, so the core must handle nesting |
| Derived request argument order | unresolved in code (`api-request-parts` 12683) | Overview's `(post.api slug same)` suggests segments first |
| Application paths vs routes | milestone 4 | Core types `%/…` as qath with printable segments only |
| Spec sync | repository copy wins (Q42) | Unsynced decisions.md rows (Unions, Printed type constraints, Partial type annotations, Record fields, Record projection, Store builder, Agent APIs, Effects) may still differ from the design doc |
