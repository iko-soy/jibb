# The compiler

A map of `jibb-dev/lib/jibb.hoon`, the compiler as milestone 1 left it: the layout pass, the parser, and the printers the golden tests compare. The file explains itself in design notes at its top, numbered 1 to 4; this page says where things are and points there for the reasoning.

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

## Constraints

- **One core, no Ford runes.** `urbit eval` runs the library as `=>  <this file>  <expression>`, and a ship builds it as `/lib/jibb.hoon`. So it can't import with `/-` or `/+`, and under `urbit eval` it can't scry. Anything from Clay, such as an imported module's text or a `/sur` file's type, is best passed in by the caller, which keeps every stage testable under eval.
- **The standard library is the subject.** Under `urbit eval`, as on a ship, the library is built against `..zuse`: `hoon.hoon`, lull and zuse. It reads literals with Hoon's own parser, `nuck:so`. Hoon's type engine, `ut`, is there for milestone 2, and under eval `ride` compiles Hoon source, such as a `/sur` file without Ford runes, into a type, which tests can use in place of Clay's builds.
- **The spec wins.** Where the file and the spec disagree, the spec is right, and the file's notes quote its words for each rule they implement. The repository spec records the decision to drop `$?`, pending synchronization to the Claude document.

## API

From the header of the file:

| Arm | Takes | Gives |
| --- | --- | --- |
| `+layout` | `[file=path src=@t]` | `(list token)`: never fails; an error is the last token |
| `+layout-error` | `[file=path toks=(list token)]` | `(unit error)`: the error token's error, if any |
| `+parse` | `[file=path src=@t]` | `(each module error)` |
| `+parse-tokens` | `[file=path toks=(list token)]` | `(each module error)` |
| `+golden` | `[file=path src=@t]` | `[tokens=@t tree=@t]`: both stages printed, or the rendered error |
| `+golden-types` | `[file=path src=@t]` | A partial inference report; explicitly says the module has not been checked |
| `+golden-types-imports` | `[file=path src=@t externals=iexternals]` | The same partial report, with selected caller-supplied Hoon mold results |
| `+show-tokens` | `(list token)` | `@t` |
| `+show-module` | `module` | `@t` |
| `+show-error` | `[src=@t error]` | `@t` |

A file is a Clay path whose last segment is the extension, as `/ui/basket/jibb`.

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
| `%type-inference` | The initial inference fragment and its unification helpers; not yet a module type checker |

The inference fragment supports fixed auras, unrestricted `@`, one-way widening into it and toward aura-family ancestors, generic variables and gates, faced and unfaced cells, cell sample binders, known record field reads, a two-binder cell pattern, a complete two-arm loobean branch, a complete two-arm unit-shaped branch, closed local mold aliases and acyclic forward value references. It instantiates generalized top-level definitions when they are used. Acyclic local value definitions can refer forward and generalize variables that are free of their enclosing environment; captured variables and explicit capitals remain shared. Acyclic simple local mold aliases can also refer forward, and are scoped to the body, not its gate's sample. Nonrecursive generic aliases of supported molds can be applied at exact arity, including locally and through library interfaces; their parameters are lexical. Closed, provably disjoint nonrecursive unions and tagged single-case molds support contextual term values, `~` and `|=%tag` constructors. A null-headed cell can match a union case but does not supply a `|=%$` constructor; unresolved tags and nulls remain pending, with distinct partial-inference diagnostics. Nonrecursive top-level generic union molds with provably disjoint cases also support contextual tags and constructors at exact arity; their arguments are retained through generalization and supported library interfaces. Nonrecursive generic aliases can reorder, repeat or omit parameters while preserving a supported union’s origin, including through local scopes and library interfaces. A generic union declared directly inside a body remains unsupported, as do recursive local groups and recursive molds. A value with type variable `A` can fit a field whose type is that same `A`, including in generic union payloads and nested or repeated record fields. A differing-variable face constraint remains unsupported. It can infer and generalize atom constraints arising from explicit capitals or bare sample binders, preserve those constraints through aliases, instantiate them independently, and print multiple constraints. Unresolved decimal variables default to `@ud` for inferred types without gates; defaulting inside gate types and other constraint cases remain incomplete. It does not yet check a module, complete imports, general patterns, general deferred constraints, recursive molds, dependency cycles or most errors with both conflicting excerpts. Definite cast and call mismatches, incompatible branches and overlapping union cases report both sites and excerpts. Concrete branch results can join at an explicitly present parent aura or `@`. Some known tuple and record positions acquire matching faces; other variable-dependent face merges, general branch tag context and ambiguous call-result propagation remain unsupported; function compatibility involving nested `@` and variable-dependent joins remain unsupported except for equal types. The current dependency pass can take quadratic time on long forward chains; the milestone's speed target remains unverified. A separate conservative pass reports unions whose cases are provably disjoint or overlapping and leaves other cases unresolved; it does not claim the mold is checked. Unsupported forms are reported as such, and the partial output says the module has not been checked.

For supported closed unions, the type printer keeps the union’s origin separate from its displayed name. It prints an in-scope name such as `msg` or `msg.lib`, including in records and gates; an accessible imported nongeneric alias may name a transitive union. A nongeneric body-local union that escapes its scope, or an origin without an accessible name, prints its cases separated by spaces, parenthesized when nested. That case-list form is print-only. A supported generic union prints its name and all arguments, including unused arguments; when its name is unavailable, the partial printer reports that limitation instead of dropping its arguments. Two faces for the same imported origin remain compatible; compatibility between distinct union origins, including in gate types, remains unsupported. Some comparisons of generic union arguments also remain unsupported rather than deciding equality or mismatch. The Hoon bridge also translates some imported unnamed unions into this representation; unsupported cases remain errors.

A known union of `~` and a null-headed cell can be matched by `~` and `[~ value]` arms in either order. The payload binder is checked for shadowing. Unknown subjects, missing or duplicate arms, and unresolved branch results remain unsupported; this fragment infers the prelude’s `fall` and `need` signatures.

A known closed union can also provide context to each arm of a complete loobean or unit-shaped branch in a cast or a call with a known union sample. Nested branches and transparent groups work; a mismatch reports the expected union and the offending arm. General patterns and context through bodies with local definitions remain unsupported, and unrelated unresolved tags stay pending.

The separate `jibb-dev/lib/jibb-import.hoon` is an unfinished reader for selected Hoon type graphs. It handles named recursion, nested map, set, queue, list, unit, jar and jug arguments, direct ordered maps, and direct `$^` unions whose source branches can be proved disjoint. It also reads ordered map fields in records when the map arguments are syntactically fixed atom molds and other fields are fixed atom molds or standard collections of static atom molds. Collection names must not be shadowed. The reader can also import a mark door sample, removing its outer sample face and validating its build subject. The reader checks explicit Hoon `$%`, `$?` and `$^` unions against the Grammar’s disjointness rule (doc question 22). It re-evaluates statically recognizable source branches before Hoon can collapse them, checks materialized fork cases, and rejects shapes it cannot prove disjoint. Static records may also have verified standard-collection and `path` siblings. One direct explicit union argument in a standard list, set, map or unit is accepted when its call wrapper and collection provenance are verified and its static cases are pairwise disjoint. A synthetic regression checks that forged wrapper subjects, samples and tails are rejected. Other collection-union forms, nested ordered maps, general source-level disjointness and complete integration with the checker remain unfinished. `+golden-types-imports` can consume fixed-aura atoms, valid term singletons, nested faced or unfaced cells, unions of supported, pairwise-disjoint cases, and opaque standard collections with supported arguments from caller-supplied reader results for declared `/-` imports; `+golden-types-with-marks` accepts the same shapes for declared marks. The caller must pass unchanged results from the source-aware reader: the bridge validates the supplied graph but cannot detect source cases Hoon collapsed before that graph was built. The opaque collection types retain their names and arguments for identity, unification and printing; Jibb-written collection molds and their prelude operations are not yet connected. Other forms remain unsupported. Its disjointness proof is conservative and can reject a valid union it cannot prove disjoint. Collection recognition requires the originating `/sur` core. The reader validates direct zuse subjects and Ford subjects consisting of faced imported cores and a validated tail, checking imported cores transitively; it rejects shadowed names, inconsistent core subjects and other subject shapes. For a recursive reference, the reader matches the exact Hoon hold against named arms in validated cores, including transitive Ford imports; it rejects missing, unlabelled or ambiguous origins. Its fixtures include three real Tlon files; `tools/importer-test` compares the internal projection under eval, and the ship test compares the same golden output. `tools/type-import-test` and `tools/type-mark-test` compare bridge reports under eval and on the ship. `tools/clay-fixtures` also passes Clay-built `/sur` molds and mark samples through the Clay-built importer and partial checker.

Self-recursive `/sur` molds can cross the bridge as opaque module-and-name identities when their supported source-aware graph passes validation. Aliases, foreign references, recursive marks, unfolding, construction and field access remain unsupported; the partial printer declines recursive names that are not in scope.

Callers that have a `/sur` core and a name can use `+read-named`: it checks for a locally declared arm before asking Hoon to evaluate the mold, and reports evaluation failures with the final Hoon trace line. `+read-mold-in` remains available when the caller already has the selected type. The checker currently treats a failed import as unsupported rather than rendering the importer's error.

`+golden-types-with-prelude` accepts case-local Jibb module sources alongside `/sur` and mark results and the vendored prelude source. It resolves reachable ordinary library modules in dependency order, caching completed interfaces per invocation and exporting supported closed value schemes, direct generic unions, and simple or nonrecursive generic mold aliases whose bodies the fragment supports. It reserves names from the supplied prelude, detects missing sources and cycles, and rejects a dependency if its interface cannot be inferred by the fragment. API files, modules with `main`, unsupported definitions and many other features remain outside this subset; the prelude inventory itself is incomplete. The older `+golden-types-with-modules` entry point fails closed for imports because it has no prelude scope. Neither entry point claims the module has been checked.

And the design notes:

| Note | Says |
| --- | --- |
| 1. Positions | Lines and columns count from 1, columns in characters; every token and node has a span, start and end, and the rules a node's span follows |
| 2. The layout pass | 2.0 where errors point, then lines, characters, blank lines, levels (INDENT, NEWLINE, DEDENT), the end of the file, tokens and tightness, paths, literals (read with `nuck:so`), strings, and what fails here |
| 3. The parser | Why recursive descent (the grammar is LL(2) after the layout pass), the EBNF rule by rule with the node each gives, what the EBNF leaves out and how it's filled in, spacing, and where each error points, with its message |
| 4. Printed formats | The token, tree and error formats the golden files hold |

## The tree

Every node is `[%tag at=span …]`, so `+span-of` finds its span in one place; the few that aren't say so in the `%tree` chapter. The kinds of node:

- **Module**: imports (`%sur` for `/-`, `%mark` for `/%`, `%jibb` for `/=`), then definitions (`%mold` for `+$`, `%value` for `++`).
- **Expressions** (`expr`): `%lit`, `%str`, `%path`, `%qath`, `%wing`, `%change`, `%pair`, `%unit`, `%group`, `%list`, `%tuple`, `%gate-wide`, `%ctor`, `%call`, `%gate`, `%cast`, `%trace`, `%branch`, `%crash`, and `%body` for an indented body, with its local definitions if it has any.
- **Molds as written** (`shape`): `%aura`, `%noun`, `%void`, `%flag`, `%const`, `%ref`, `%tvar`, `%path`, `%apply`, `%cell`, `%union`, `%fn`, `%generic`. A `%union` spans its first through last case and has no lead token; a single case is its own mold. `%generic` spans from the `|$` after a `+$` name through its body.
- **Samples, fields and patterns**: a sample is `%bind`, `%face`, `%pun`, `%cell` or `%bare`, since a bare name binds anywhere in a sample; a pattern is `%lit`, `%str`, `%any`, `%bind` or `%cell`.
- **Literals** (`lit`) keep the form they matched, their aura and value, and their text as written, which the printers show.

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

`tools/golden` runs `+golden` under `urbit eval` on every case and compares `tokens.txt` and `tree.txt`; opted-in cases also compare `+golden-types` with `types.txt`. `tools/ship gen-tests` writes a `-test` arm per case that does the same on the ship. The type output is provisional until the checker can check complete modules and imports.

## Speed

Starting `urbit eval` and building the library takes about 8 s. A 2,000-line module of 400 definitions then parses in about a second. Loops over definitions, arms, lines and items are tail calls, so a long module grows no stack; nesting costs a few stack frames a level, and 100,000 nested brackets still parse (note 3).
