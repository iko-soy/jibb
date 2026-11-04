# Jibb interpreter implementation plan

## Goal

Add a native implementation of the pure fragment of Jibb. It will parse a module into a public semantic AST, statically check it according to the specification, and evaluate a selected entry point without Urbit, Hoon, a ship, or `urbit eval`.

The first version checks and interprets ordinary values and computation. It does not render UI, execute effects, or implement the Nock backend. Static type checking is required before evaluation; an unchecked AST is never executed.

## Status

Implemented on 2026-11-04: the public semantic AST, diagnostics, complete CST lowering, and structural tests are complete. The implementation includes arbitrary-precision numbers, terms and constructors, decoded strings, source spans, and recursive span-erased normalization.

All 62 tests pass, including 512 valid golden lowerings with normalized AST equality before and after formatting, 250 invalid-case rejections, Clippy, the native repository check, the Nix package build, and the complete eval and fake-ship checks. Ships, dates, and durations retain source spelling until their runtime representations are implemented.

Direction corrected on 2026-11-04: static type checking is a required milestone before runtime evaluation. `docs/spec/grammar.md` and `docs/spec/decisions.md` are the normative semantic references. The Hoon implementation and its `types.txt` output explicitly describe partial inference; their implementation limitations must not become Rust language semantics.

Static-checker foundation implemented: the AST retains numeric and term forms needed for aura checking; static types and deterministic type printing, related-span diagnostics, scope validation, named/generic mold resolution, runtime-noun union overlap checks, directional literal fitting, and basic cast/record checking are available through `check`.

Inference implemented: union-find unification with occurs checks and rigid capitals, directional fitting, principal-type generalization and instantiation, higher-order gates and calls, forward references, recursive gate groups, local polymorphic definitions, and local capital sharing. Generalized atom, arithmetic-atom, and gate-free constraints propagate through bindings and nested types, survive schemes, and preserve generic aura fitting. Remaining contextual expressions still fail closed. All 84 Rust tests pass in debug and release modes, Clippy passes with warnings denied, and the native repository check passes.

## Architecture

Keep parsing, semantic syntax, formatting, and evaluation separate:

```text
source text
  → tree-sitter CST
  → hand-written lowering
  → public semantic AST
  → static checker
  → checked module and principal type schemes
  → evaluator
  → runtime values
```

Use these modules:

```text
src/
  lib.rs          public parse, AST, and evaluation entry points
  ast.rs          owned semantic syntax types
  lower.rs        CST to AST normalization and validation
  types.rs        static types, schemes, constraints, and type printing
  infer.rs        union-find unification, generalization, and instantiation
  check.rs        mold resolution, inference, and exhaustive pattern checking
  formatter.rs    existing CST/trivia formatter, unchanged
  value.rs        runtime nouns, gates, natives, and environments
  eval.rs         evaluation, pattern matching, and diagnostics
  native.rs       initial pure native functions
  main.rs         the new `jibb run` command
```

The formatter continues to consume the CST because it needs comments and concrete layout. The checker and interpreter consume the semantic AST and do not depend on formatter documents or trivia. The evaluator accepts only a successfully checked module.

## 1. Public semantic AST

Define owned Rust types independent of tree-sitter lifetimes. Every expression, definition, pattern, mold, and arm retains a byte span and source identity for diagnostics.

Core shape:

```rust
pub struct Module {
    pub imports: Vec<Import>,
    pub definitions: Vec<Definition>,
}

pub struct Definition {
    pub name: String,
    pub kind: DefinitionKind,
    pub span: Span,
}

pub enum DefinitionKind {
    Value(Expr),
    Mold(MoldDefinition),
}

pub struct Expr {
    pub kind: ExprKind,
    pub span: Span,
}

pub enum ExprKind {
    Literal(Literal),
    String(Vec<StringPart>),
    Path(Vec<PathSegment>),
    ApplicationPath(Vec<ApplicationSegment>),
    Reference(Vec<String>),
    Call { head: Box<Expr>, arguments: Vec<Expr> },
    Gate { sample: Sample, body: Box<Expr> },
    Cast { mold: Mold, value: Box<Expr> },
    Trace { value: Box<Expr>, body: Box<Expr> },
    Branch { subject: Box<Expr>, arms: Vec<Arm> },
    Body { definitions: Vec<Definition>, result: Box<Expr> },
    List(Vec<Expr>),
    Tuple(Vec<Item>),
    Change { target: Vec<String>, edits: Vec<Edit> },
    Pair { tag: String, value: Box<Expr> },
    Unit(Box<Expr>),
    Crash,
}
```

Keep `Mold`, `Sample`, `Pattern`, `Item`, `Edit`, and `Arm` as separate types. Do not model molds or patterns as expressions.

Normalize away presentation distinctions:

- Merge open and closed containers.
- Remove redundant grouping.
- Normalize wide and tall gates into one gate form.
- Merge ordinary bodies and rest-of-body forms.
- Represent every call with a head and an argument vector.
- Preserve original literal spelling only when useful for diagnostics; also decode its runtime value.

Expose:

```rust
pub fn parse_ast(source: &str) -> Result<ast::Module, Diagnostic>;
pub fn check(module: &ast::Module) -> Result<check::CheckedModule, Diagnostic>;
pub fn evaluate(module: &ast::Module, entry: &str) -> Result<Value, Diagnostic>;
```

Start with owned `String` values. Add string interning or node IDs only if profiling shows a need.

## 2. Hand-written CST lowering

Implement lowering as total, checked functions returning `Result<T, Diagnostic>`. Do not use string slicing to infer structure.

The lowering pass must:

- Reject `ERROR` and missing CST nodes before lowering.
- Cover every syntax node currently accepted by the grammar.
- Normalize open/closed and wide/tall forms.
- Distinguish operands, runes, molds, samples, and patterns by context.
- Decode supported literals without changing their meaning.
- Preserve spans through normalized nodes.
- Return an explicit unsupported-syntax error rather than panicking or guessing.

Add normalized-AST snapshots for every golden case. Include assertions that open and closed forms lower identically, groups disappear where redundant, and both gate spellings produce the same gate AST.

Add a structural formatting invariant: formatting and then lowering must produce the same normalized AST as lowering the original, except for spans. This closes the current reparse-and-idempotence-only coverage gap.

## 3. Static type checking

Implement the type system specified in `docs/spec/grammar.md` and `docs/spec/decisions.md`. Do not infer language rules from the current Hoon checker's partial-inference fallbacks. A program that the partial Hoon fragment cannot infer is not automatically invalid; classify it from the spec and add a focused test.

### 3.1 Checked modules and diagnostics

`check` returns a checked module containing each value definition's principal type scheme, each mold's resolved definition, and the expression types needed by type-directed lowering and evaluation. It rejects the whole module on the first deterministic diagnostic; it never returns a partially checked module as executable.

Extend diagnostics with related source notes while retaining the primary message and span. Type errors should identify conflicting sites, such as an expected mold and the actual expression, both capitals that must not be forced equal, or a branch arm covered by an earlier arm. Keep rendering deterministic and independent of hash-map iteration order.

### 3.2 Static types and mold resolution

Use an internal representation along these lines:

```rust
pub enum Type {
    Var(TypeVar),
    Atom(Aura),
    AnyAtom,
    Noun,
    Void,
    Flag,
    Constant(NounLiteral),
    Cell(Vec<TypeField>),
    Gate { sample: Box<Type>, product: Box<Type> },
    Named { module: ModuleId, name: String, arguments: Vec<Type> },
}

pub struct TypeScheme {
    pub variables: Vec<QuantifiedVariable>,
    pub constraints: Vec<Constraint>,
    pub typ: Type,
}
```

Store named union cases and generic mold parameters in resolved mold definitions rather than creating cyclic Rust types. Recursive mold identity is its name and module. Constant comparison uses structural noun values and arbitrary-precision atoms, so different spellings of the same noun cannot create distinct cases.

Resolve molds and values in separate namespaces. Reject duplicate record faces, invalid generic arity, unknown molds, empty cells, unresolved holes, and overlapping union cases. Union disjointness follows runtime noun shape: loobeans overlap constants 0 and 1, `!!` is empty, a cell containing an empty position is empty, and gates are opaque.

### 3.3 Unification, fitting, and inference variables

Implement Hindley–Milner inference with identity-based union-find variables, path compression, ranks, levels, occurs checks, and deterministic instantiation. Track whether a variable is explicit, rigid, generalized, or constrained.

Keep two operations distinct:

- **Unify** requires equal type structure, subject to the spec's face and explicit-capital rules.
- **Fit** is directional and additionally permits only the specified one-way widenings: a specific noun to `*`, a specific atom to `@`, and an aura to an ancestor in its Hoon aura family.

There is no general subtyping. Distinct specific auras do not unify merely because they share an ancestor. Reverse widening requires the check specified by the language; it is not silently accepted by ordinary fitting.

Represent atom, arithmetic-atom, and gate-free obligations on variables. Propagate them through cells, gates, named generic arguments, and containers; preserve them through generalization and instantiation. Arithmetic excludes loobeans, while equality and map/set keys reject gates even when nested.

### 3.4 Definitions, scopes, and generalization

Build lexical scopes before expression inference. All definitions in a scope are visible independently of source order. Enforce the no-shadowing rule across values, molds, samples, binders, imports, and the prelude as applicable, and reserve `proj` and `unface`.

Build the value dependency graph and its strongly connected components. Infer recursive gate groups with monomorphic in-group references, then generalize completed definitions. Mutually recursive gates are allowed; a non-gate value that depends on itself, including through a gate, is a static error.

Generalize per `++`, not at arbitrary local expressions. A capital in a local definition shares the enclosing definition's capital when the enclosing definition uses it; otherwise it is introduced and generalized locally. Distinct explicit capitals cannot be forced equal. Preserve source names when printing principal types and assign deterministic names to anonymous variables.

A named mold or value definition must resolve its own `_` holes without help from later uses. An unresolved hole, open tag constraint, or insufficiently determined definition is an error at that definition.

### 3.5 Bidirectional checking and deferred constraints

Use expected types for molds, casts, gate samples and products, call arguments, list items, cells, constructors, record projection, branch results, and other context-sensitive forms. Expected-type propagation must not bypass ordinary inference or principal-type generalization.

Maintain a deterministic work queue for constraints that cannot yet be resolved:

- Tag, null, number, and cell literal resolution.
- Constructor shape and payload resolution.
- Wing access, record changes, `proj`, and `unface` on unknown types.
- Branch subjects and results whose types are not yet known.
- Atom, arithmetic, gate-free, interpolation, and typed-path-segment obligations.

Wake constraints when their variables become sufficiently known. Default unresolved decimal literals to `@ud` only at the definition boundary allowed by the spec and only when the definition is not generic over their aura. Cell literals default to tuples where permitted. Tags and unresolved null constraints never receive a guessed default: report the required context, normally a `^-` cast.

### 3.6 Expression rules

Check every pure AST expression, not only annotated expressions:

- Literals use their exact aura or constant type; strings are cords, and interpolation checks that each expression has a statically selectable printer.
- References instantiate value schemes; multi-segment wings traverse statically known record or module fields.
- Gates bind every sample name with its checked type and produce `$-(sample product)`.
- Calls fit one right-nested argument sample against the gate sample; multiple arguments are not currying.
- Casts resolve their mold and statically validate the expression against it, including contextual resolution of tags, numbers, cells, constructors, and holes.
- Lists, units, pairs, tuples, and records resolve against context where required.
- Changes validate every field wing against the original record, reject duplicate or nested edits, and check every replacement against its original field type.
- `proj` uses the expected result type to select exactly those fields; `unface` recursively removes faces only where the spec permits.
- Traces return their body type. Crashes have the empty type and fit any expected type.

Imports, effect types, application-path validation, and module-kind checks fail closed until their specified static environments are available. They must produce explicit unsupported-feature diagnostics rather than being skipped or treated as nouns.

### 3.7 Patterns and exhaustiveness

Check patterns against the subject type, bind names anew without shadowing, and give every arm a compatible result type. The last cell-pattern position takes the rest. Literal patterns require compatible literal types.

Perform static coverage analysis over union cases, loobeans, units, lists, cells, catch-alls, and nested patterns. Reject nonexhaustive branches with the missing case and reject arms covered by earlier arms. A binder that spells a tag at a position where the matched case has that tag is an error rather than a catch-all. If coverage cannot be established because a constraint remains unresolved, defer it and ultimately reject it; never assume exhaustiveness.

## 4. Runtime values

Use immutable, shared nouns and separate computational values:

```rust
pub enum Noun {
    Atom(BigUint),
    Cell(Rc<Noun>, Rc<Noun>),
}

pub enum Value {
    Noun(Rc<Noun>),
    Gate {
        sample: Sample,
        body: Expr,
        environment: Rc<Scope>,
    },
    Native(NativeFunction),
}
```

Use arbitrary-precision atoms from the start. Runtime equality compares noun structure and numeric atom value, not literal spelling or aura. Faces are not runtime data.

Represent data canonically:

- `[a b c]` as the right-nested cell `[a [b c]]`.
- A one-item cell as its item.
- `~[a b c]` as the list `[a [b [c ~]]]`.
- `` `x `` as `[~ x]`.
- `tag+value` as `[%tag value]`.
- Records and changes as their underlying cells, with faces erased.

Gate application constructs one right-nested sample from all arguments; multiple arguments do not mean Rust-style variadic application or currying.

## 5. Environments and definitions

Give each module and body a lexical scope. Definitions are visible independently of source order, subject to Jibb's cycle rules.

Use memoized lazy slots for definition values:

```text
unevaluated → evaluating → evaluated
```

A gate captures its defining scope. Evaluating a reference forces its slot. An `evaluating` revisit reports a dependency cycle with the definition chain. This supports forward value references and mutually recursive gates while rejecting invalid non-gate cycles.

Do not create a fresh environment for each sibling definition. Local definitions follow the same scope model as module definitions.

Runtime failures include source spans and a short Jibb call stack. They do not expose Rust panics as ordinary language errors.

## 6. Evaluator

Implement evaluation in stages:

1. Literals, references, cells, lists, units, pairs, and groups already normalized by lowering.
2. Gate construction, closure capture, calls, and native calls.
3. Local definitions and lazy forward references.
4. Branches and pattern matching.
5. Changes and record-wing access.
6. Traces and crashes.
7. Casts after successful static checking; the evaluator must not perform or omit a cast in a way that changes the checked semantics.

Pattern matching tries arms in source order. Literal patterns compare nouns, binders capture values, wildcards match anything, and cell patterns decompose right-nested cells. A nonmatch proceeds to the next arm; no matching arm is a runtime exhaustiveness error.

Molds are resolved and checked statically before evaluation. Runtime nouns do not carry static types or faces.

The initial interpreter rejects UI effects, requests, subscriptions, stores as effectful builders, and JavaScript/Nock-specific behavior with explicit unsupported-feature diagnostics.

## 7. Initial native functions

Implement a deliberately small pure native set needed by evaluator examples:

- `eq`, `not`
- `add`, `dec`
- `lth`, `lth2` when their calling conventions are needed
- `lent`, `weld`, `snoc`, `flop`
- `trip`
- `same`

Natives receive ordinary Jibb samples and return ordinary values or Jibb diagnostics. Add further prelude functions only with tests; do not expose untested approximations of the whole prelude.

Paths, application paths, dates, durations, and other literal families are added only after their runtime representations are defined by tests.

## 8. CLI

Add:

```text
jibb run FILE
jibb run FILE --entry NAME
```

`run` parses and lowers the file, evaluates `main` by default, and prints the resulting value in a documented Jibb-oriented noun format. A gate requiring arguments is an error until command-line noun arguments are implemented.

Use exit status 0 for a returned value, 1 for a Jibb syntax/runtime error, and 2 for CLI or I/O failures. Write values to stdout and diagnostics to stderr.

Imports initially produce an unsupported-import diagnostic. A later module loader resolves `/=` paths relative to explicit source roots, caches lowered modules, and reports missing modules and cycles. `/-` and `/%` remain outside the pure standalone subset until their host inputs are supplied.

## 9. Testing

Add three layers:

### Lowering tests

- AST snapshots for all golden cases.
- Equivalent surface forms produce equivalent ASTs.
- Span-erased AST equality before and after formatting.
- Every accepted syntax node lowers without a panic.

### Typechecker unit tests

- Aura families, one-way fitting, rejected reverse widening, and distinct specific auras.
- Unification, occurs checks, principal types, instantiation, and explicit-capital rigidity.
- Local capital sharing, definition holes, atom/arithmetic/gate-free constraints, and deterministic type printing.
- Forward definitions, recursive gate groups, local definitions, no-shadowing, and invalid value cycles.
- Named recursive molds, generic arity, record faces, union disjointness, and equal noun constants.
- Contextual tags, constructors, decimals, cells, lists, casts, interpolation, `proj`, and `unface`.
- Gate calls, record wings and changes, pattern binding, exhaustiveness, and covered arms.
- Every unresolved or unsupported static feature fails closed with a source diagnostic.

### Evaluator unit tests

- Atom and cell construction.
- Lists, units, pairs, records, and changes.
- Closure capture and lexical scope.
- Forward definitions and sibling gate recursion.
- Invalid cycle diagnostics.
- Multiple-argument sample construction.
- Pattern order, binders, nested cells, and exhaustiveness errors.
- Native-function results and failures.
- Trace and crash behavior.

### Type golden corpus

Classify every `tests/golden/types-*` source case by the spec and run it through the Rust checker. Retain valid expected types and diagnostics where they express specified behavior. Where `types.txt` says `partial inference; module not checked` or reports a partial-inference limitation, derive the intended checked result from the spec instead of blessing that limitation as a language rule.

### End-to-end tests

Run small modules through `jibb run`, checking stdout, stderr, and exit status. Include an entry-point selection test, invalid source, unsupported features, and a nontrivial recursive program.

Keep runtime tests independent of the formatter. Run debug and release Cargo tests, Clippy with warnings denied, and the complete Nix eval and ship checks before pushing.

## 10. Delivery sequence

1. [x] Public AST, diagnostics, and complete CST lowering.
2. [x] Structural AST and formatter-equivalence tests.
3. [x] Static type representation, mold resolution, scopes, and related-span diagnostics.
4. [x] Unification, directional fitting, recursive definitions, and generalization.
5. [x] Generalized atom, arithmetic-atom, and gate-free constraints.
6. [ ] Complete pure-expression checking, contextual resolution, and principal type schemes.
7. [ ] Pattern coverage, union validation, type goldens, and static-checker regression tests.
8. [ ] Runtime nouns, scopes, literals, and references over checked modules only.
9. [ ] Gates, lazy definitions, calls, recursion, patterns, changes, traces, and crashes.
10. [ ] Initial natives and `jibb run`, which always checks before evaluating.
11. [ ] End-to-end goldens, documentation, Nix wiring, and full checks.
12. [ ] Imports and additional literal/prelude coverage as separate spec-checked follow-ups.

Each step remains compilable and tested. Unsupported syntax or evaluation fails explicitly rather than silently changing semantics.
