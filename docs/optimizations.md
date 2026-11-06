# Cheap optimizations

Jibb compiles on Urbit, so compiler time is a first-order constraint. The optimizer must not become another expensive whole-program analysis phase. The initial goal is to emit good Nock during type-directed lowering, with at most one reachability pass, rather than to run a general optimizer to a fixed point.

The Core language and its evaluation rules are specified in [the Core language](spec/core-language.md). Every optimization must preserve results, crashes, and the behavior of native calls. Compilation and execution need separate measurements on a fake ship.

## Initial pipeline

```text
check
  → one type-directed lowering pass
      (static axes, direct natives, simple decision trees, local simplification)
  → one entry-reachability pass
  → Nock emission
```

Nock-specific formula construction remains in the Nock backend: autocons, formula composition, final subject-axis assignment, formula deduplication, and Nock 11 hints.

## Static axes and direct references

Resolve names and type-directed operations while the checked type information is available:

- Resolve local variables, samples, module definitions, and imports to their final references.
- Turn each record wing into a constant noun axis.
- Combine nested record wings into one axis instead of emitting a chain of projections.
- Lower sample destructuring directly to constant-axis slots and bindings.
- Give closures a statically determined subject layout.
- Resolve known function references directly where the gate ABI permits it; do not perform runtime name lookup.

This is part of lowering, not a separate analysis. It removes work from the generated Nock and simplifies the emitter.

## Direct native references

Resolve recognized prelude definitions to their Hoon implementations by definition identity. This lets Vere's jets fire and avoids compiling Jibb wrapper bodies into generic Nock. Higher-order natives must retain the Hoon-compatible Jibb gate ABI so Hoon implementations can call Jibb samples.

Native recognition must not repeatedly compare function bodies or search for matching implementation shapes after each rewrite. Establish the identity of trusted prelude definitions once, retain it through name resolution, and emit the corresponding native reference during lowering.

Differential tests must establish the native and Jibb implementations' agreement, including argument layout, recursion, higher-order calls, and crashes.

## Local simplification during Core construction

Apply cheap rewrites as their enclosing Core node is constructed. Do not repeatedly traverse the module looking for new opportunities.

Initial rewrites:

```text
slot 1 e           → e
slot m (slot n e)  → slot (composed axis) e
if %.y t f         → t
if %.n t f         → f
app (lam x b) a    → let x a b
```

The beta rewrite preserves strict sample evaluation: `a` is still evaluated before `b`. It avoids constructing and invoking a closure without introducing a general inliner.

Fold a primitive only when its arguments are already constants and the result is immediately known to succeed. A failing operation must remain a runtime crash unless the whole program is rejected statically. Do not add a compile-time evaluator for arbitrary definitions as part of this pass.

After replacing a node, use the simplified child in the enclosing construction. Do not revisit siblings or restart a module traversal.

## Straightforward pattern decision trees

Lower `?-` directly to a decision tree that:

- Evaluates the subject once.
- Shares tag and head tests already needed by several arms.
- Projects each payload at a constant axis.
- Introduces binders only on the path where their pattern matches.
- Uses checker coverage information to omit type-redundant tests.

Use a deterministic, bounded construction algorithm. Do not search for an optimal decision tree or use an unbounded pattern-matrix expansion. The simple patterns in the language should produce a tree close to linear in the size of the source and generated tests.

Static coverage is not permission to accept malformed external nouns. Where Core requires a check to crash on invalid runtime data, the emitted Nock must retain that behavior.

## Entry reachability

Build one program per entry and retain only definitions reachable from that entry. Reuse the dependency graph and recursive-group information needed by checking and lowering. A reachability traversal should visit each reachable definition and reference once per program, without repeatedly recomputing dependency groups.

If a module is used as a whole value, all of its definitions remain live, as required by the Core specification.

Reachability reduces emitted Nock as well as runtime dependencies. It should not be followed by general inlining or another optimization cycle. If later work adds transformations that can make definitions unreachable, measure whether a second reachability traversal pays for its compilation cost before adding it.

## Optimizations to defer

Do not include these in the initial compiler:

- General or recursive inlining.
- Iterative optimization to a fixed point.
- Global common-subexpression elimination.
- Global constant propagation or partial evaluation.
- Compile-time execution of arbitrary non-gate definitions.
- Monomorphization or representation specialization.
- Strictness analysis; Core is already strict.
- List-pipeline fusion.
- Searches for optimal pattern decision trees.
- Repeated structural recognition of native implementations.

These may be reconsidered individually after measurements show a significant execution problem and a bounded implementation with acceptable compilation cost.

## Correctness limits

Cheap does not mean semantics-free:

- Core is strict, so an unused `let` cannot generally be deleted: its bound expression may crash, diverge, or trace.
- Purity alone does not permit hoisting, duplication, or deletion. Termination and crashes are observable.
- Constant folding must preserve native failure behavior.
- Type-proven checks must still reject malformed nouns where the Core contract requires a crash.
- Traces must not be accidentally duplicated or introduced. Differential tests currently compare results and crashes rather than trace output, but that is not a license for arbitrary trace movement.
- Generated Nock must preserve the Hoon gate layout used for calls between Jibb and native Hoon gates.

## Tests and measurements

For each rewrite, test the smallest positive and negative cases, then compare unoptimized and optimized Core and Nock for:

- Returned noun or function behavior.
- Successful results and crashes.
- Malformed runtime nouns and failed primitive operations.
- Pattern order, coverage, and binder values.
- Strict evaluation and unused crashing expressions.
- Native and higher-order-native calls.

Benchmark compilation and execution separately on a fake ship, with compiler-debug tracing disabled for representative production timings. Include small modules, many independent definitions, recursive groups, deep records, large matches, and several entries sharing dependencies. Report both costs; a faster generated program is not sufficient justification for an optimization that makes ordinary compilation substantially slower.
