# Milestone 3: core language

Architecture and implementation brief, written 2026-11-07 after milestone 2 completed at `bc25d08`. This is an implementation plan, not a new language decision. The normative sources are [Core language](../spec/core-language.md), [Grammar](../spec/grammar.md), [Decisions](../spec/decisions.md), and the [implementation plan](../spec/implementation-plan.md#milestones).

## Scope and done criteria

Build:

1. Lowering from the successfully checked Jibb syntax tree to the specified 15-node Core language.
2. The Core S-expression printer and reader.
3. The reference interpreter in Hoon.
4. The Nock backend, with Hoon-shaped gates and authenticated native calls.

Done when:

- The Core tab's `update` example lowers to the exact program shown there.
- The reference interpreter and Nock backend agree on a reviewed corpus of hand-written Core and lowered Jibb programs, comparing returned nouns and crash/no-crash, including deliberate crashes.
- Every Core node and every lowering rule has focused tests, including malformed runtime nouns where crashes are required.
- The complete eval and fake-ship checks pass, including the new Core goldens and differential suites.

Out of scope: the JavaScript backend, browser runtime, host, rendering, route handling, scry validation, incoming-fact validator integration, and per-request behavior. The validator lowering rule in the Core tab does not expand milestone 3's stated acceptance criteria; scry validators belong to milestone 5 and fact validation to the later runtime work.

## Current architecture and reusable assets

Milestone 2 provides a general full checker, source AST, dependency SCCs, nominal recursive types, match usefulness analysis, checked imports, projection plans, and source-backed prelude interfaces. The native Rust CLI is a separate surface-AST parser/checker/evaluator. It is not the Core implementation or Nock backend.

Reusable Hoon assets:

- Full checking enters through `infer-jibb-file-detailed` in `jibb-dev/lib/jibb.hoon`.
- `iresolved` and `icore-check` reach the successful final substitution, defaulting, coverage, and publication boundary.
- `iwprojection` already retains projection source/target types, selected field steps, and quantified variables.
- The dependency graph already computes lexical SCCs for top-level and local definitions.
- The coverage domain, ordered pattern matrices, witnesses, binder refinements, and recursive domain graphs already implement the required static match analysis.
- The import resolver already checks or reuses every dependency in a cache.
- Literal values and print auras survive in the source AST.

Reusable Rust assets are secondary only: arbitrary-precision nouns, structural noun equality, literal codecs, and independently generated test vectors. The Hoon Core interpreter is the semantic reference. Rust surface evaluation is not a strictness, crash-order, native-ABI, or Core oracle. In particular, its lazy definitions and its current `raw-tuba` behavior differ from the specified/Hoon behavior and must not become shared goldens.

## Decisions and contracts before the affected stages

### Owner language questions

| Question | Current state | What it blocks |
| --- | --- | --- |
| May `proj` reorder source fields? | The expected result type selects fields and layout; reordering remains open in question 32 | Only `proj` lowering and its goldens. Do not implement a guessed reorder rule |
| May a gate fit `*`? | Core distinguishes functions from nouns; review answer 18 is an unconfirmed proposal, not a decision | Gate-erasing UI representations. It does not block ordinary Core, the interpreter, Nock, or first-order lowering |

Do not turn other unconfirmed review proposals into implementation rules. The Decisions row saying that three Core rules are proposed is stale: the Core tab currently marks none proposed. Correct that documentation without inventing new rulings.

### Implementation contracts to write down with the code

These are deterministic implementation contracts, not owner language changes unless tests reveal observable semantic disagreement:

- Within a module, preserve source order where dependencies permit. Within `rec`, use source arm order. Across modules, use a deterministic path-and-name tie-break. Linker reachability must not depend on map iteration order.
- Reject Core axis 0 despite the permissive digit production, which the prose defines as at least 1.
- Reject interpolated strings as Core atom literals; interpolation lowers to native printing and `join` before the Core text form.
- The Core reader validates structure, arity, names, axes, duplicate bindings/definitions, and native names. Hand-written Core's function/noun invariants remain preconditions; milestone 3 does not add a second Core type system.
- Differential outcomes are a canonical noun or crash. Apply returned functions to noun arguments rather than comparing backend closure representations. Traces have separate smoke tests and are not cross-backend equality requirements.
- Native resolution uses authenticated definition identity established once during prelude preparation. Unknown or lookalike definitions fail closed; spelling alone is never evidence.

## Target architecture

```text
hand-written Core text ───────────────┐
                                      ├→ Core reader → Core AST → reference interpreter
                                      │               │          → Nock emitter → execution
Jibb source → parser → full checker   │               │
                           │          │               │
                           └→ checked-module artifact │
                                  → lowering → Core AST
                                  → entry reachability/linking
```

Use separate libraries so hand-written Core and backend work do not depend on surface inference:

- `jibb-dev/lib/jibb-core.hoon`: Core AST, reader/printer, reference interpreter, canonical outcome handling, and Nock emission.
- `jibb-dev/lib/jibb.hoon`: capture checked lowering artifacts during the existing successful check.
- `jibb-dev/lib/jibb-lower.hoon`: checked-tree lowering and entry linking, using the surface and Core libraries.

Keep existing `ifile` and full-check result shapes stable for current callers. Add a separate lowering result/cache rather than changing positional public types.

## Checked-module artifact

The full checker currently publishes definition schemes and selected evidence but discards most per-occurrence information. Add a `checked-module` captured once, inside the existing recursive full check. Lowering must not parse again, rerun `infer-fragment`, repeat coverage, or guess from source spelling.

The artifact should contain:

- Module path, source AST in source order, checked kind, exported interface, and direct import face-to-path mappings.
- Final normalized types for expression, sample, pattern, and binder occurrences, with stable occurrence IDs and lexical owners.
- Resolved value references: local binder, own definition, prelude definition, or imported definition, with canonical definition identity.
- Wing field-axis chains and record-edit axes.
- Sample and pattern binder axes and definition identities.
- Explicit top-level/local dependency SCCs, not only a flattened list of names.
- Checked match artifacts: subject type, final domain graph, ordered matrix rows, arm occurrences, and binder refinements. A deterministic decision DAG may be retained or built from these data without re-inference.
- Projection plans joined to the same occurrence IDs used by the typed tree.
- Final types for interpolation, application-path, and trace values so their printers can be selected.
- Authenticated native IDs on resolved prelude/private-primitive references.
- An enriched dependency cache containing each imported module's lowering artifact or already lowered Core module.

A suitable public boundary is `check-jibb-file-for-lowering` returning the root artifact, enriched cache, and kind, followed by pure `lower-checked-module`. A combined `lower-jibb-file-detailed` may wrap both for tools. Do not expose raw `istate` or substitution internals.

## Core interpreter and Nock contracts

Implement all 15 nodes directly: literals, names, `cons`, `slot`, `edit`, `cell?`, `eq`, `if`, `let`, `rec`, `lam`, `app`, `native`, `crash`, and `trace`.

The interpreter tests must establish:

- Strict samples and strict unused `let` expressions.
- Text-order evaluation except lazy `if` branches.
- Closures, higher-order calls, and mutually recursive lambdas.
- Crashes for invalid axes, invalid loobean tests, explicit crash, and native failure.
- Trace output followed by the body's result.
- No comparison of functions as nouns.

The Nock backend must preserve the specified formulas and Hoon gate ABI: sample at axis 6, direct application with `[9 2 10 [6 e] f]`, Hoon-shaped cores for `rec`, and Nock 11 `%slog` hints for traces. Native Hoon gates and Jibb gates use the same call convention, including higher-order natives calling back into Jibb gates.

Apply only the bounded local simplifications and one entry-reachability pass described in [optimizations.md](../optimizations.md). Do not add fixed-point optimization, general inlining, partial evaluation, or unbounded decision-tree search. Measure compilation and generated-code execution separately on a fake ship.

## Staged implementation

### Stage 1: Core AST and text form

- Define the independent Core AST and native registry types.
- Implement canonical printing and structural reading for every node and module form.
- Add round trips for own, qualified, and generated names; comments and whitespace; arbitrary-precision atoms and print auras.
- Add negative goldens for axis 0, bad arity, malformed names/modules, duplicate bindings/definitions, unknown natives, and interpolated atom literals.

### Stage 2: Hoon reference interpreter

- Implement direct evaluation of every node and canonical noun/crash outcomes.
- Cover strictness, recursion, higher-order calls, invalid runtime nouns, crashes, and traces.
- Keep hand-written Core tests independent of the Jibb checker so backend semantics have a small oracle.

### Stage 3: Nock backend for hand-written Core

- Emit and execute every node, comparing interpreter and Nock results/crash-ness.
- Test the Hoon gate ABI in both directions, including a native calling a Jibb gate.
- Add cheap local rewrites only with positive and crash-preservation controls.

### Stage 4: Capture checked artifacts

- Extend the successful full-check path and dependency cache without changing existing report callers.
- Test occurrence identity, final substitutions, local scopes, imported references, SCC boundaries, wing/edit axes, match artifacts, and native identity.
- Negative controls must show that lowering receives no artifact from a failed or provisional module.

### Stage 5: Lowering and linking

Implement every Core-tab rule: erased types/faces/casts/`unface`; literals and interpolation; cells/lists/units/pairs; paths; wings; changes computed from the original record; gates/samples; constructors/calls; local and top-level `let`/`rec`; pattern decision trees; traces/crashes; derived gates; and `proj` after its field-order ruling.

- Match the Core tab's `update` example exactly.
- Evaluate subjects and projection sources once.
- Prune unreachable definitions per entry while retaining whole-module uses.
- Preserve deterministic ordering and single computation of non-gate values.
- Keep runtime validators out of this stage.

### Stage 6: Native and end-to-end differential acceptance

- Map trusted prelude/private definitions to their Hoon implementations by identity.
- Compare Jibb and native Hoon behavior for arithmetic, text, literal codecs, equality, recursion, argument layout, higher-order calls, and crashes.
- Add lookalike/user-definition and malformed-sample controls.
- Run the combined hand-written Core and lowered-Jibb corpus under the reference interpreter and Nock on eval and a fake ship.
- Optionally execute the same canonical Core text in a Rust Core reader/interpreter as a secondary check; do not substitute the existing Rust surface evaluator for either required backend.

## Test integration

Extend both golden runners from the same case data so eval and ship cannot drift:

- `core.txt`: canonical lowered Core, where applicable.
- `core-tree.txt` or a structured parse result only if needed for reader diagnostics; avoid serialized source positions in canonical Core.
- Differential suite arms for execution rather than storing backend-specific closure or trace output.

Reuse `tests/lib/jibb-useful.hoon`, coverage/tail-binder suites, projection suites, `jibb-hoon-reference`, and the real `doc-core-02-update` context. Seed source-level runtime cases from Rust tests only after the Hoon full checker accepts them and expected nouns are independently confirmed. Include success and crash cases, unused crashing `let`, malformed runtime nouns, deep equality, big atoms, empty text, Unicode/codepoints, recursion, and higher-order natives.

Register new standalone checks in `tools/check`; new suites under `tests/lib` join the existing shards. Keep each commit's eval and ship checks green and review generated Core goldens rather than updating them blindly.

## Final acceptance matrix

| Area | Required evidence |
| --- | --- |
| Core text | All 15 nodes and modules round-trip; malformed inputs reject deterministically |
| Reference interpreter | Direct semantics, strictness, recursion, traces, native behavior, and crashes |
| Checked artifacts | Complete resolved occurrence data, failed-check nonpublication, dependency retention |
| Lowering | Exact Core-tab `update` golden plus every lowering rule and source-once controls |
| Linking | Reachability, SCCs, deterministic order, whole-module values, shared dependencies |
| Nock | Every node, Hoon gate ABI, native/higher-order calls, result/crash agreement |
| Optimizations | Local positive/negative controls and separate compile/execution measurements |
| Repository acceptance | All golden cases and test arms pass under eval and on the fake ship; `nix flake check` passes |

## First implementation slice

Start with Stage 1 and Stage 2 using hand-written Core programs. They require no typed-tree changes and none of the open owner rulings. Add `jibb-core.hoon`, its reader/printer and interpreter suites, and the canonical noun/crash harness. Once those are green, implement the Nock emitter for the same programs before integrating the full-checker artifact capture.
