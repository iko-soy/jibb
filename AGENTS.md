# Working on Jibb

Jibb is a UI language for Urbit: a Hoon dialect with indentation layout. Its compiler is a Hoon library, `jibb-dev/lib/jibb.hoon`. Use the repository's actual source, specifications, and test results to establish behavior.

## Current assignment

Continue milestone 8: polish, including shared island modules, view templates with holes, and browser library size. The owner chose this scope on 2026-11-10. Follow later user instructions when the task changes.

The continuation started at `633e0c9`, with a clean checkout and implementation through the browser runtime and tooling. Milestone 2 was implemented in `184cac2` and marked complete after integrated validation in `bc25d08`. Its old `/tmp` checkpoints and scratch patches are historical; compare any candidate with current source before applying it. Read [status.md](docs/status.md) for current capabilities, remaining work, and validation evidence. Milestone 8 is not yet complete.

Continue independently; do not make progress depend on contacting another developer. Commit passing work directly to `master`, as the development guide requires, and inspect the remote state before pushing. A focused passing suite is not milestone acceptance.

## Read first

1. [Status](docs/status.md): current capabilities, acceptance evidence, and remaining work.
2. [Implementation plan](docs/spec/implementation-plan.md), [Overview](docs/spec/overview.md), and [Decisions](docs/spec/decisions.md): scope, runtime behavior, and chosen decisions.
3. [Development guide](docs/development.md): setup, test tools, conventions, and checks before pushing.
4. [Compiler map](docs/compiler.md), [Core language](docs/spec/core-language.md), and [Grammar](docs/spec/grammar.md), as relevant to the change.
5. [Open questions](docs/open-questions.md): distinguish proposals from decisions, including the unsettled browser benchmark bar.

## Implementation rules

- The spec wins. Agree language changes first and record them in `docs/spec/decisions.md` before implementing them. Do not treat unchosen review proposals as decisions.
- No spelling-based built-ins. Derive prelude behavior and constraints from checked source and authenticated imported interfaces.
- Fail closed when a construct is unsupported, with a diagnostic naming the construct and its source site. Preserve definite diagnostics through the full checker.
- Use the general inference core: union-find variables with levels, deferred constraints, dependency SCCs, and reusable match usefulness analysis. Avoid adding example-specific recovery paths.
- Infer `main` as an ordinary expression and classify the module from its type. A directory or a particular source spelling does not establish the kind.
- Watchability belongs to the actual request occurrence. Types, casts, cached source, or unrelated interfaces must not manufacture that evidence.
- Delete recovery paths when the general core replaces them. Preserve their behavioral tests, including negative provenance controls, and migrate tests that directly call deleted helpers.
- Render type reports from the full checker. Invalid cases must assert the actual message and source locations, with excerpts; merely asserting rejection is insufficient.
- Review generated golden changes. Do not weaken expectations or turn valid programs into expected rejections to make a suite pass.
- Preserve the shared noun representation and backend agreement. Optimizations must retain observable results, crashes, and traces.
- `each` and `table` keys contain no gates, including nested gates; an element's message may contain a gate. Infer and generalize the constraint through their prelude signatures.
- Keep `docs/` consistent with verified behavior. Do not mark a milestone complete while required work remains.

## Workspace and collaboration

- Preserve existing changes. Do not reset, clean, or replace the checkout.
- Inspect `git status`, relevant source hashes, and active jobs before applying a patch. Scratch candidates may predate integrated changes.
- Coordinate edits to shared compiler, prelude, and runtime files. Prefer a reviewed selective patch over copying an older candidate onto shared files.
- Parallelize independent work; check available agents before creating duplicate assignments.
- Existing eval and ship jobs can survive interruptions. Read their logs and check their processes before starting replacements.
- Coordinate fake-ship access; do not run overlapping syncs or tests against the same pier.
- Keep the root agent to at most two simultaneous eval processes and coordinate total load with other agents.
- Give concise progress updates during sustained work. Report what passed, what failed, and what remains uncertain without claiming unverified success.

## Tools and verification

Use `nix develop` for the pinned development environment. Consult the development guide and each tool's help for current options.

```sh
tools/test-js                      # JavaScript compiler and runtime tests
tools/bundle-js                    # regenerate the vendored browser library
tools/bundle-js --check            # verify the vendored bundle
tools/check-browser                # browser acceptance and measurements on a fake ship
tools/test-arms <suite>             # selected Hoon test arms under eval
tools/golden --case '<glob>'        # selected golden cases under eval
tools/golden --update --case <name> # generate outputs, then review them
tools/check                        # all registered eval, native, and ship checks
nix flake check                    # full checks with a fresh fake ship
```

Register a new standalone check in `tools/check`. Suites in `tests/lib` join the existing test-arm shards. Keep golden behavior consistent between eval and the fake ship. Use the current runners to obtain corpus counts rather than carrying old counts into acceptance claims.

`tools/hoon -f FILE` reads an expression from a file; `--no-debug` disables debug instrumentation for timings. `tools/golden` has no `--no-debug` option. Use `tools/bench-check` for generated-module benchmarks and `tools/check-browser` for browser measurements; do not treat an unagreed benchmark bar as accepted.

Never promote scratch tracing or deliberately failing diagnostic-capture suites. Before pushing, pass the required checks in [the development guide](docs/development.md#before-pushing). Record measured sizes, counts, timings, and material limitations in `docs/status.md`, and update compiler/design documentation and Decisions when behavior changes. Milestone acceptance requires the integrated checks under eval and on a fake ship, not only focused tests.
