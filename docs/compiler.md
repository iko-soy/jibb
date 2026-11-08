# The compiler

A map of `jibb-dev/lib/jibb.hoon`: the layout pass, parser, module graph and type checker. The library's design notes explain the syntax rules and the shared inference core. Milestone 2's general full checker has replaced the specialized recovery paths, and all report expectations use the full-check pipeline. [Status](status.md) records final acceptance validation, validated capabilities, and remaining gaps.

The plan's Compiler architecture section gives the whole pipeline. Here it is shortened, with the milestone that builds each step; milestone 1 built the first line:

```
/ui source
  → layout pass → parser → a syntax tree per module            milestone 1
  → module graph: imports resolved, Hoon types read from Clay   milestone 2
  → type checker, one module at a time, in dependency order     milestone 2
  → core language                                               milestone 3
      → Nock                                                    milestone 3
      → JavaScript                                              milestone 6
```

The common checker retains `proj` actions alongside each checked definition. Each action keeps the original expression, selected field axes and resolved source and result types. Local generic definitions quantify their own proof variables when they generalize; final module substitutions cannot capture those variables. The enclosing definition owns each action once, including actions in mutually recursive local gates. The focused projection and compatibility suites passed 38 arms under eval and on the fake ship. Lowering and execution remain milestone 3 work.

## Core language and lowering

`jibb-core.hoon` defines the independent 15-node Core tree, its canonical S-expression reader and printer, and the strict Hoon reference interpreter. `jibb-nock.hoon` emits Nock for that tree with Hoon-shaped gates and explicit native registries. The two executors compare canonical nouns and crash/no-crash outcomes; functions are applied to noun samples rather than compared as backend closures.

The successful full check can retain a `checked-module` containing resolved references, final occurrence types, field axes, dependency SCCs, match evidence, projections, derived plans, and authenticated native identities. `check-jibb-file-for-lowering` and its prepared-prelude variant return that artifact and its enriched dependency cache without changing the existing full-report result. Failed or provisional checks publish no artifact.

`jibb-lower.hoon` consumes only those checked artifacts: it does not parse, infer, or repeat coverage. It lowers modules, links reachable definitions per entry, and expands derived API and store calls. Runtime module identifiers omit the display-leading slash, while Core module names retain their logical paths. Unsupported projection reordering and unavailable type-directed printers fail closed.

## JavaScript backend

`js/core/` implements the milestone 6 track that can proceed without surface lowering: a hand-written-Core reader, Jibb literal decoder, noun runtime, and Core-to-JavaScript code generator. `linkCore` resolves module-qualified definition identities, prunes by entry reachability, orders dependency SCCs, rejects recursive non-gates, and emits one linked Core program per definition entry or whole-module value. `compileLinkedCore` combines that program with the generator. Native evidence is preserved from lowered `(native …)` nodes rather than inferred from definition spelling. `compileCore` produces an ES module whose `evaluate` function receives an explicit runtime and native registry. Native names must be declared at compilation and validated again at instantiation; spelling alone does not authenticate a prelude definition. The initial representation uses BigInt atoms and two-element arrays for cells, leaving small-atom and tail-call optimizations for measured milestone 6 work. `js/core/node.mjs` evaluates generated modules for Node tests; it is not the browser runtime. `tools/test-js` covers all Core nodes, strictness and crashes, arbitrary-precision values, closures and mutual recursion, higher-order natives, and malformed reader inputs. `js/test/fixtures/hand-written.json` is a language-neutral seed corpus of source text, required test natives, and canonical noun/crash outcomes for the later Hoon differential harness. `tools/test-js-differential` runs the shared corpus through both JavaScript and the Hoon Core interpreter in `master`, translating the JavaScript AST directly to Hoon `expr`; `--core-lib PATH` selects another interpreter. All 11 shared outcomes matched. Separate probes lowered checked Jibb literal and authenticated-`add` modules and executed them through `linkCore`, both returning 42. Those candidate libraries are not promoted by this JavaScript work. Full checked-artifact integration waits for their merge, and the browser-backend benchmark decision remains open.

### Browser DOM and island loop

`js/browser/` decodes authenticated sealed element nodes into renderer-independent virtual nodes, creates and patches DOM, and reconciles keyed `each` children and table rows in occurrence order. Compatible nodes retain identity, focus, selection, and caret; control properties are rewritten only when they differ. Button, toggle, field, form, and composition events dispatch synchronously. `startIsland` initializes or resumes a jammed model, mounts the first view, queues reentrant messages, patches before ordered commands, resynchronizes controls on unchanged models, and retains the previous model after update/view failures. Commands require an explicit transport. `Channel` implements Eyre noun channels with `application/x-urb-jam` request batches and streamed SSE decoding, cumulative acknowledgement batching, resume IDs, fresh-UID reconnect on 404, and pagehide deletion. `Effects` installs command dispatch and subscription diffs: agent watches retain fold state, reseed after kicks, acknowledge after handling, unsubscribe on removal, and reject refused watches. Poke replies, one-shot and interval timers, `now`, `who`, and `go` are supported. `StoreRegistry` shares per-page stores, defers initial full-state watches, notifies every island after successful pokes, preserves state on update crashes, and returns deferred error text. `UrlRuntime` delivers initial and subsequent paths, handles `go` with `pushState`/`popstate`, and focuses the first heading after navigation.

### Nock comparison and tail calls

`js/nock/` contains an independent Core-to-Nock emitter and iterative Nock 0–11 interpreter used for correctness tests and backend comparison. Native adapters and Hoon-shaped gate nouns share the sample-at-axis-6 ABI. `tools/bench-js` checks expected nouns before measuring source emission and execution separately. Direct self-tail-calls in generated JavaScript become loops, including through `if`, `let`, and `rec` bodies, with fresh parameter bindings per iteration to preserve captured closures. Trace-wrapped recursion retains ordinary call semantics. The 2026-11-08 comparison selected generated JavaScript for the browser backend; see [optimizations.md](optimizations.md#measured-javascript-and-nock-comparison) for measurements and remaining performance limits.

### Native runtime

`js/natives/` implements arithmetic and comparison, strict UTF-8 byte/codepoint conversion, cord joining, aura formatting, list and unit gates, persistent Hoon treaps with `mug`/`gor`/`mor`, `jam`/`cue`, exact `@uw`, and deep noun validation. `createNativeRegistry` installs only explicitly requested identities with immutable function properties. The checked raw mappings cover arithmetic, comparison, text, formatting, calendar pack/unpack, aura-directed parsing, bit complement, sealing, and map get/put; deliberately omitted collection-door APIs are not manufactured from names. Composed Unicode convenience functions remain separate from the exact `trip`/`tuba`/`crip`/`tufa` primitive steps. Native and registry tests include arbitrary-precision values, higher-order callbacks, malformed inputs, persistent map/set versions, independent Hoon vectors, and canonical codec round trips.

## Constraints

- **One core, no Ford runes.** `urbit eval` runs the library as `=>  <this file>  <expression>`, and a ship builds it as `/lib/jibb.hoon`. So it can't import with `/-` or `/+`, and under `urbit eval` it can't scry. Anything from Clay, such as an imported module's text or a `/sur` file's type, is best passed in by the caller, which keeps every stage testable under eval.
- **The standard library is the subject.** Under `urbit eval`, as on a ship, the library is built against `..zuse`: `hoon.hoon`, lull and zuse. It reads literals with Hoon's own parser, `nuck:so`. Hoon's type engine, `ut`, is there for milestone 2, and under eval `ride` compiles Hoon source, such as a `/sur` file without Ford runes, into a type, which tests can use in place of Clay's builds.
- **The spec wins.** Where the file and the spec disagree, the spec is right, and the file's notes quote its words for each rule they implement. The repository spec records the decision to drop `$?`.

## API

From the header of the file:

| Arm | Takes | Gives |
| --- | --- | --- |
| `+layout` | `[file=path src=@t]` | `(list token)`: never fails; an error is the last token |
| `+layout-error` | `[file=path toks=(list token)]` | `(unit error)`: the error token's error, if any |
| `+parse` | `[file=path src=@t]` | `(each module error)` |
| `+parse-tokens` | `[file=path toks=(list token)]` | `(each module error)` |
| `+golden` | `[file=path src=@t]` | `[tokens=@t tree=@t]`: both stages printed, or the rendered error |
| `+golden-types` | `[file=path src=@t]` | The full checker’s definition types and module kind, or its diagnostic with excerpts |
| `+golden-types-imports` | `[file=path src=@t externals=iexternals]` | The full result with caller-supplied Hoon mold results |
| `+show-tokens` | `(list token)` | `@t` |
| `+show-module` | `module` | `@t` |
| `+show-error` | `[src=@t error]` | `@t` |

A file is a Clay path whose last segment is the extension, as `/ui/basket/jibb`. The `golden-types-with-*` entry points add prepared prelude, mark and module inputs to the same full checker. An unsupported construct remains an error; reporting does not publish a partial interface as a checked module. The renderer preserves nominal identities and all generic arguments. It first uses visible mold aliases; when a value exposes a type from a transitive Jibb import, it adds a report-only import such as `/= types-1 /ui/base` and prints `(phantom.types-1 @t)`. These aliases do not change source scope or the checked interface. They avoid existing names, and distinct origin modules keep distinct aliases. A nominal identity with no available checked origin still reports its limitation at the definition’s source site. Diagnostics retain the known structure of incomplete types: an unresolved tag prints as a type variable with its literal constraint, rather than hiding the surrounding record or pretending the union is fixed. Constructor mismatches use the known union’s payload type; calls retain the successful argument-prefix substitution so both concrete conflicting auras are shown. At the module boundary, a failed branch join recovers the original arm expression to keep the decimal/aura suggestion and both source excerpts. The old `golden-types-in-context*` partial-report implementations and their unused printers have been deleted. All report tests use the full checker; remaining old golden expectations are still being reviewed, and unsupported valid programs remain failing regressions.

Inference diagnostics can carry sites from more than one source file. For a missing case in an imported Jibb union, the checker reports the union declaration from its checked source and the tag from the current module. It uses the checked import graph and the exact module bundle to establish the origin, including through transitive imports; if that source is unavailable or ambiguous, it does not invent an excerpt. Local diagnostics keep their existing spans and excerpts.

## Where things are

The core is split into chapters, `+|  %name`, in this order:

| Chapter | Holds |
| --- | --- |
| `%positions` | `loc`, `span` and `error` |
| `%tokens` | `token`, `lexeme`, `glyph` and `lit`: what the layout pass emits |
| `%tree` | The syntax tree: `module`, `import`, `def`, `expr`, `piece`, `qseg`, `item`, `edit`, `arm`, `sample`, `field`, `pattern`, `shape` and `pseg` |
| `%api` | The arms above that aren't printers |
| `%lexer` | The layout pass's door, `+lexer`, and its helpers |
| `%printers` | `+show-tokens`, `+show-module`, `+show-error` |
| `%parser-helpers` | Error building (`+fail`, `+fail-in`, `+fail-space`, `+fail-line`, `+moved`, …) and the `+then` combinator |
| `%parser` | The parser's door, `+parser`: one arm per EBNF rule, as `+read-module`, `+read-expr`, `+read-mold` |
| `%span-check` | `+check-spans`, which `+golden` runs on every tree, and `+check-spans-test` |
| `%type-inference` | The common module checker, constraint queue, type graphs, imports and kind checks |

## Type checking

`infer-jibb-file-detailed` resolves imports, checks mold declarations and infers the module through `icore-check`. The public text-result adapter and every `golden-types*` reporter read that same result. A failed definition prevents publication of the interface. There is no second resolver that accepts a source-shaped recovery case after the common checker declines it.

The dependency graph uses a lexical traversal: samples, patterns and local definitions bind names, while references to outer values remain edges. Two depth-first passes find strongly connected components. Dependencies are inferred before their users. A recursive group shares monomorphic placeholders while its bodies are checked and generalizes only after the group succeeds. A non-gate dependency cycle reports the actual declaration and reference chain. A failed group rolls back its substitutions; independent later definitions can still resolve earlier constraints, without making the failed module publishable.

Type variables carry binding levels and restrictions for atoms, numeric literals and gate freedom. Unification checks occurrence before binding a variable and lowers reachable levels when a value captures an outer variable. Generalization uses these levels and the pending constraints; it preserves captured variables and independently instantiates quantified variables, including restrictions nested in lists, records and recursive types. Written capitals have lexical scope and cannot be forced to a concrete type or merged with another distinct written capital. A type hole must be resolved by its own definition before generalization; later uses cannot repair it.

Local mold capitals have lexical scope through local recursive mold graphs, including nested graphs. Their capture relationships survive deferred generalization, while independent mold parameters still generalize and unbound or out-of-scope captures are rejected.

One queue carries unresolved literal, constructor, cell, call, cast, field, change, match, face, printable-aura and attribute constraints. Its wake index tracks the variables reachable from each edge, including aliases and structural bindings, so unrelated substitutions need not retry every edge. The full solver remains a reference implementation for the indexed solver. Pending tag variables remain monomorphic until module context determines their union. Finalization reports a remaining edge at its own source instead of publishing an open type. The queue retains argument positions, called-gate types, written capitals and definition ownership as compound constraints are decomposed.

Expected subscription event context reaches delayed expressions through direct lists and lists transformed by `identity` or `flop`. Valid streams infer their event type through the ordinary constraints; a wrong event produces a type error rather than merely leaving inference unresolved.

A capital meeting a faced position binds the type beneath that face. Structural joins retain a face once the position has one and reject incompatible face names. Sample binder faces and value faces therefore do not require a source-layout exception for a directly named gate: aliases and inferred callbacks use the same constraints. Module-kind template matching preserves raw `%slot` markers until gate-sample pairing, so written binders are not mistaken for value faces. `unface` explicitly removes value faces. A `proj` keeps checked field axes as an elaboration attached to its owning definition; generalized local proof variables remain independent of later module substitutions.

A monomorphic gate result can retain a module-owned structural root until later uses supply its faces. That root is allocated before scheme-local renaming and only when its product has no variables that will generalize and no private occurrence evidence. Tag-constrained variables remain module-owned. Independent polymorphic calls keep distinct product variables; collection, union and recursive arguments receive their own structural face joins.

Recursive Jibb and imported molds use one nominal graph representation, `%mrec`, with checked source identities and explicit arguments. Traversals use graph nodes and guarded unfolding rather than separate example-specific recursive wrappers. A structurally guarded recursive mold may have no finite inhabitants; certification preserves its identity without asserting that it contains a value. Saved schemes retain their reachable roots and restrictions. They instantiate with fresh variables and do not expose private mold names or change a nominal origin to make a fit succeed.

Private occurrence evidence supports proofs such as “this broad noun contains no gate.” It is attached to the value that established it. When values join, structural evidence is intersected field by field; evidence available in only one alternative cannot justify the result. Face-only queue updates preserve the target's evidence or its absence. Binding a capital beneath a face does not copy that occurrence's proof into every use of the capital. This keeps equality, collection-key and island-data checks sound under aliases, casts and repeated generic parameters.

Watch checking follows actual request occurrences through local and embedded islands, including generic embedding helpers and islands discarded by surrounding data flow. A data-only absence proof does not manufacture request evidence, and an unproved subscription reports its own watch site.

The checked `each` and `table` signatures constrain keys to contain no gates, including gates nested inside a key. The constraint survives aliases and generic wrappers; an element's message may still contain a gate.

The match checker specializes a pattern matrix over noun constants and cells. Loobeans, lists, units and named recursive unions supply their possible constructors. Usefulness identifies an unreachable arm; exhaustiveness produces a missing-case witness. Patterns retain source spans and the refined types of their binders, including a final binder that captures a cell tail. The matrix is reusable by milestone 3's lowering pass. The old per-case, collection and closed-cell branch recovery paths have been deleted. The integration passed 65 suite arms and six exact diagnostic goldens under eval and on the fake ship, including local body contexts and recursive result faces.

`main` is inferred with the other definitions. The kind check then examines its checked type and applies the kind's additional constraints, including gate-free data and models and evidence for each watched request. Kind checks are type-directed, and watchability follows actual request occurrences and their checked provenance. Lowering, runtime behavior and route checking are later milestones.

## Imports and prelude

The host supplies imported module sources and Hoon reader results. Under eval, tests can build Hoon fixture types with `ride`; on a ship, the desk check uses types built through Clay. `jibb-import.hoon` reads those Hoon types, and the Jibb checker preserves their auras, record faces, union cases and recursive identities. An unsupported or invalid imported type is reported where it is used, with source evidence when available. Checked import graphs bind interfaces to the sources, declarations and dependencies that established their evidence; a changed source cannot reuse a stale proof.

Source-aware mark reading authenticates origin evidence against a unique declaration rebuilt from the supplied source and matched to the mark's faced dependency. The checker reads origin only from a unique direct result for that mark; another mark's declaration cannot supply it. The selected declaration and the raw dependency must have the same canonical `read-mold` representation, which avoids Ford-versus-eval raw-type representation differences without accepting equal-shaped decoys. Missing, stale, wrong-path or ambiguous origin metadata produces no origin rather than a guessed site. Source evidence does not change the imported semantic body or hide a semantic import error.

The prelude is Jibb source, prepared through the checker. Its private internal module can use a small validated primitive interface. Public helpers and module constructors are ordinary values with checked signatures; their names do not bypass unification. Standard list and unit recognition is tied to their validated source templates. The [prelude inventory](prelude-inventory.md) records available names, their source groups and deliberate omissions.

The element type uses a compiler-owned private seal. The source-backed internal prelude defines the unsealed element node and the public prelude builds nodes through its ordinary typed constructors before sealing them. The seal's checked private origin and type arguments survive imports and instantiation; the display name is not its identity. Ordinary modules cannot import the sealing primitive, inspect an element's representation or cast a raw noun into an element. This is private implementation metadata for element opacity, not a public type operator. In particular, an island constructor still checks its program and initial data through their source-defined types before sealing the result.

## Diagnostics

An inference diagnostic is a message and a list of source sites. The common checker retains the owning definition and the original argument, declaration or constraint spans until rendering. Errors are selected in dependency order. An earlier independent unresolved tag can precede a later failure; a tag whose context comes from the failing definition does not hide that definition's actual error.

Conflicting types, fields, capitals and bindings show the relevant sites with excerpts and carets. Imported union and scope diagnostics use the checked origin source. A genuine implementation limit still rejects the program and names the unresolved construct and its location. The public reporter never substitutes a partial list of successful definitions for a failed module.


## The tree

Every node is `[%tag at=span …]`, so `+span-of` finds its span in one place; the few that aren't say so in the `%tree` chapter. The kinds of node:

- **Module**: imports (`%sur` for `/-`, `%mark` for `/%`, `%jibb` for `/=`), then definitions (`%mold` for `+$`, `%value` for `++`).
- **Expressions** (`expr`): `%lit`, `%str`, `%path`, `%qath`, `%wing`, `%change`, `%pair`, `%unit`, `%group`, `%list`, `%tuple`, `%gate-wide`, `%ctor`, `%call`, `%gate`, `%cast`, `%trace`, `%branch`, `%crash`, and `%body` for an indented body, with its local definitions if it has any.
- **Molds as written** (`shape`): `%aura`, `%hole`, `%noun`, `%void`, `%flag`, `%const`, `%ref`, `%tvar`, `%path`, `%apply`, `%cell`, `%union`, `%fn`, `%generic`. A `%hole` retains the span of `_`; an inferred typed path segment retains that span separately from its enclosing segment. A `%union` spans its first through last case and has no lead token; a single case is its own mold. `%generic` spans from the `|$` after a `+$` name through its body.
- **Samples, fields and patterns**: a sample is `%bind`, `%face`, `%pun`, `%cell` or `%bare`, since a bare name binds anywhere in a sample; a pattern is `%lit`, `%str`, `%any`, `%bind` or `%cell`.
- **Literals** (`lit`) keep the form they matched, their aura and value, and their text as written, which the printers show.

The parser accepts type holes and retains each hole's span. The checker diagnoses an unresolved hole before its definition can generalize. A separate syntax-tree pass reports repeated record fields at both written sites, including in unused definitions; nested and separate records have independent scopes.

The tree keeps everything the checker needs to report an error at the code as written: open and closed brackets give the same node, but every node keeps its span.

## Positions and errors

- A span runs from a node's first character to just past its last. A node ends where its last token ends, never at a layout token, and holds its children's spans in order. `+check-spans` tests both rules on every tree the golden tests print.
- An error is `[file=path line=@ud col=@ud msg=tape]`: a start, no end yet. Milestone 2's type errors need more, since the plan asks that "each error names both conflicting sites, with excerpts". Spans keep their ends for that.
- Every error points at the first character where the text stops being the start of any valid module (note 2.0). The layout pass never fails: it ends its tokens with an error token, and the parser reports whichever error comes first, its own or that one.
- The parser's messages read "expected <what>, found <token>", with an optional "; <hint>". The layout pass's state the rule broken, as "a tab: Jibb uses spaces only" or "`|%` is left out: modules are records". None ends with a period, and all start lowercase unless they open with a name, as "Jibb writes no @c literals". `+show-error` prints `<file>:<line>:<col>: <message>`, the line, and a caret under the column.

## Printed formats

Note 4 has examples of each.

- **Tokens**: one per line, `<line>:<col>`, then `tight` if the token follows the previous one on its line with no space between, then its kind and text.
- **Trees**: S-expressions, `(kind line:col fields kids)`, with each node's start; a node whose kids are all leaves prints on one line. Past 64 levels the indent stops growing, so the printed tree stays linear in the text's size.
- **Errors**: as above. Control characters print as spaces in the excerpt, so the caret stays under its column.

## Tests

`tools/golden` runs `+golden` under `urbit eval` on every case and compares `tokens.txt` and `tree.txt`; opted-in cases also compare `+golden-types` with `types.txt`. `tools/ship gen-tests` writes a `-test` arm per case that does the same on the ship. The type output comes from the full checker: checked definition types and module kind, or its diagnostic with source excerpts. Rendering selects visible mold aliases from the module, its direct imports and the prepared prelude. A separate print view reconstructs alias arguments without changing the checked scheme, including aliases that reverse, repeat or fix parameters. A nongeneric specialization prints without spurious type arguments; an inaccessible nominal type is reported rather than losing its identity.

## Speed

`tools/bench-check` measures startup and a full 2,000-line module in both dependency orders with `tools/hoon --no-debug`. `tools/check-my-app` measures checking the desk after its Clay types have built. Current verified timings and the exact tested snapshot belong in [status](status.md); historical recovery-path microbenchmarks are retained in git.
