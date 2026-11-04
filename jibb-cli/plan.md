# Jibb interpreter implementation plan

## Goal

Add a small, native interpreter for the pure fragment of Jibb. It will parse a module into a public semantic AST and evaluate a selected entry point without Urbit, Hoon, a ship, or `urbit eval`.

The first version is an interpreter for ordinary values and computation. It does not render UI, execute effects, perform static type checking, or implement the Nock backend.

## Status

Implemented on 2026-11-04: the public semantic AST, diagnostics, complete CST lowering, and structural tests are complete. The implementation includes arbitrary-precision numbers, terms and constructors, decoded strings, source spans, and recursive span-erased normalization.

All 62 tests pass, including 512 valid golden lowerings with normalized AST equality before and after formatting, 250 invalid-case rejections, Clippy, the native repository check, and the Nix package build. Ships, dates, and durations retain source spelling until their runtime representations are implemented.

## Architecture

Keep parsing, semantic syntax, formatting, and evaluation separate:

```text
source text
  → tree-sitter CST
  → hand-written lowering
  → public semantic AST
  → evaluator
  → runtime values
```

Use these modules:

```text
src/
  lib.rs          public parse, AST, and evaluation entry points
  ast.rs          owned semantic syntax types
  lower.rs        CST to AST normalization and validation
  formatter.rs    existing CST/trivia formatter, unchanged
  value.rs        runtime nouns, gates, natives, and environments
  eval.rs         evaluation, pattern matching, and diagnostics
  native.rs       initial pure native functions
  main.rs         the new `jibb run` command
```

The formatter continues to consume the CST because it needs comments and concrete layout. The interpreter consumes the semantic AST and does not depend on formatter documents or trivia.

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

## 3. Runtime values

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

## 4. Environments and definitions

Give each module and body a lexical scope. Definitions are visible independently of source order, subject to Jibb's cycle rules.

Use memoized lazy slots for definition values:

```text
unevaluated → evaluating → evaluated
```

A gate captures its defining scope. Evaluating a reference forces its slot. An `evaluating` revisit reports a dependency cycle with the definition chain. This supports forward value references and mutually recursive gates while rejecting invalid non-gate cycles.

Do not create a fresh environment for each sibling definition. Local definitions follow the same scope model as module definitions.

Runtime failures include source spans and a short Jibb call stack. They do not expose Rust panics as ordinary language errors.

## 5. Evaluator

Implement evaluation in stages:

1. Literals, references, cells, lists, units, pairs, and groups already normalized by lowering.
2. Gate construction, closure capture, calls, and native calls.
3. Local definitions and lazy forward references.
4. Branches and pattern matching.
5. Changes and record-wing access.
6. Traces and crashes.
7. Casts as evaluation-transparent operations in this untyped interpreter.

Pattern matching tries arms in source order. Literal patterns compare nouns, binders capture values, wildcards match anything, and cell patterns decompose right-nested cells. A nonmatch proceeds to the next arm; no matching arm is a runtime exhaustiveness error.

Molds remain in the AST but are not evaluated. Static checking is a separate future pass.

The initial interpreter rejects UI effects, requests, subscriptions, stores as effectful builders, and JavaScript/Nock-specific behavior with explicit unsupported-feature diagnostics.

## 6. Initial native functions

Implement a deliberately small pure native set needed by evaluator examples:

- `eq`, `not`
- `add`, `dec`
- `lth`, `lth2` when their calling conventions are needed
- `lent`, `weld`, `snoc`, `flop`
- `trip`
- `same`

Natives receive ordinary Jibb samples and return ordinary values or Jibb diagnostics. Add further prelude functions only with tests; do not expose untested approximations of the whole prelude.

Paths, application paths, dates, durations, and other literal families are added only after their runtime representations are defined by tests.

## 7. CLI

Add:

```text
jibb run FILE
jibb run FILE --entry NAME
```

`run` parses and lowers the file, evaluates `main` by default, and prints the resulting value in a documented Jibb-oriented noun format. A gate requiring arguments is an error until command-line noun arguments are implemented.

Use exit status 0 for a returned value, 1 for a Jibb syntax/runtime error, and 2 for CLI or I/O failures. Write values to stdout and diagnostics to stderr.

Imports initially produce an unsupported-import diagnostic. A later module loader resolves `/=` paths relative to explicit source roots, caches lowered modules, and reports missing modules and cycles. `/-` and `/%` remain outside the pure standalone subset until their host inputs are supplied.

## 8. Testing

Add three layers:

### Lowering tests

- AST snapshots for all golden cases.
- Equivalent surface forms produce equivalent ASTs.
- Span-erased AST equality before and after formatting.
- Every accepted syntax node lowers without a panic.

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

### End-to-end tests

Run small modules through `jibb run`, checking stdout, stderr, and exit status. Include an entry-point selection test, invalid source, unsupported features, and a nontrivial recursive program.

Keep runtime tests independent of the formatter. Run debug and release Cargo tests, Clippy with warnings denied, and the complete Nix eval and ship checks before pushing.

## 9. Delivery sequence

1. [x] Public AST, diagnostics, and complete CST lowering.
2. [x] Structural AST and formatter-equivalence tests.
3. [ ] Runtime nouns, scopes, literals, and references.
4. [ ] Gates, lazy definitions, calls, and recursion.
5. [ ] Branches, patterns, data construction, changes, traces, and crashes.
6. [ ] Initial natives and `jibb run`.
7. [ ] End-to-end goldens, documentation, Nix wiring, and full checks.
8. [ ] Imports and additional literal/prelude coverage as separate follow-ups.

Each step remains compilable and tested. Unsupported syntax or evaluation fails explicitly rather than silently changing semantics.
