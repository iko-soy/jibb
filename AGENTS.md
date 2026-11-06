# Working on Jibb

Jibb is a UI language for Urbit: a Hoon dialect with indentation layout. Its compiler is a Hoon library, `jibb-dev/lib/jibb.hoon`. Use the repository's actual source, specifications, and test results to establish behavior.

## Current assignment

Finish milestone 2: types and prelude. The owner has requested complete implementation and verification, followed by commits and a push to `master`. Do not treat an intermediate patch or a focused passing suite as milestone completion. Follow later user instructions when the task changes.

The other developer/coordinator is unavailable. Continue independently; do not make progress depend on contacting them. Permission to commit and push this milestone to `master` has already been given. Keep every commit passing the required checks, and inspect the remote state before pushing.

## Read first

1. [Finishing milestone 2](docs/prompts/milestone-2-finish.md): scope, remaining work, and completion criteria.
2. [Milestone 2 review](docs/reviews/2026-11-03-milestone-2-review.md): findings and the table of 33 specified errors.
3. [Original milestone brief](docs/prompts/milestone-2.md).
4. [Implementation plan](docs/spec/implementation-plan.md), [Grammar](docs/spec/grammar.md), and [Decisions](docs/spec/decisions.md).
5. [Owner's answers](docs/reviews/2026-11-02-questions.md): distinguish chosen answers from proposals.
6. [Development guide](docs/development.md): setup, test tools, conventions, and checks before pushing.

For the existing workspace, also read these local checkpoints, newest first:

- `/tmp/jibb-root-0211-state.txt`
- `/tmp/jibb-root-0206-state.txt`
- `/tmp/jibb-root-continuation-state.txt`

They record scratch candidates, selective patches, validation evidence, and unfinished work. These temporary files may not exist on another machine; their absence does not replace the repository's specifications or justify stopping work.

## Implementation rules

- The spec wins. Record new language decisions in `docs/spec/decisions.md` before implementing them. Do not treat unchosen review proposals as decisions.
- No spelling-based built-ins. Derive prelude behavior and constraints from checked source and authenticated imported interfaces.
- Fail closed when a construct is unsupported, with a diagnostic naming the construct and its source site. Preserve definite diagnostics through the full checker.
- Use the general inference core: union-find variables with levels, deferred constraints, dependency SCCs, and reusable match usefulness analysis. Avoid adding example-specific recovery paths.
- Infer `main` as an ordinary expression and classify the module from its type. A directory or a particular source spelling does not establish the kind.
- Watchability belongs to the actual request occurrence. Types, casts, cached source, or unrelated interfaces must not manufacture that evidence.
- Delete recovery paths when the general core replaces them. Preserve their behavioral tests, including negative provenance controls, and migrate tests that directly call deleted helpers.
- Render type reports from the full checker. Invalid cases must assert the actual message and source locations, with excerpts; merely asserting rejection is insufficient.
- Review generated golden changes. Do not weaken expectations or turn valid programs into expected rejections to make a suite pass.
- Keep `docs/` consistent with verified behavior. Do not mark milestone 2 complete while required work remains.

## Owner decision from 2026-11-04

`each` and `table` keys must contain no gates, including gates nested in a key. Infer and generalize this constraint through their prelude signatures. The restriction applies to keys; an element's message may contain a gate. This decision is recorded in Decisions and Grammar.

## Workspace and collaboration

- Preserve all existing changes. At the handoff there were approximately 1,257 modified or untracked paths, containing ongoing implementation and tests. Do not reset, clean, or replace the checkout.
- Inspect `git status`, the current compiler hash, and active jobs before applying a patch. Scratch candidates may predate changes already integrated by another agent.
- Coordinate edits to `jibb-dev/lib/jibb.hoon` and the public/internal prelude. Prefer a reviewed selective patch over copying an entire older candidate onto shared files.
- Parallelize independent work. The previous team divided responsibility among `desk`, `imports`, and `inference`; resume available agents before creating duplicate assignments.
- Existing eval and ship jobs can survive a turn interruption or an agent capacity error. Read their logs and check their processes before starting replacements.
- The desk agent owns both existing fake-ship piers. Coordinate access; do not run overlapping syncs or tests against the same pier.
- On this workspace, keep the root agent to at most two simultaneous eval processes and coordinate total load with the other agents.
- Give concise progress updates during sustained work. Report what passed, what failed, and what remains uncertain without claiming unverified success.

## Tools and verification

Use `nix develop` for the pinned development environment. Consult the development guide and each tool's help for current options.

```sh
tools/test-arms <suite>             # selected Hoon test arms under eval
tools/golden --case '<glob>'        # selected golden cases under eval
tools/golden --update --case <name> # generate outputs, then review them
tools/probe-regression             # strict review-probe regression
tools/check --group eval           # all eval checks
tools/check                       # all registered checks
nix flake check                   # full checks with a fresh fake ship
tools/check-my-app                 # real desk types read through Clay
```

`tools/hoon -f FILE` reads an expression from a file. Use `tools/hoon --no-debug` for the required timings. `tools/golden` does not have a `--no-debug` option. Review `tools/bench-check` for generated-module benchmarks.

Register a new standalone check in `tools/check`. Suites in `tests/lib` are collected by the existing test-arm shards. Keep golden behavior consistent between eval and the fake ship.

Never promote scratch tracing such as `field-trace*.hoon` or deliberate `~| ... !!` instrumentation. Some scratch report suites intentionally mismatch expected strings to capture diagnostics; they are not passing tests.

## Milestone completion criteria

- The doc examples and all valid review variants check. Invalid probes report their own errors at their own sites. The current corpus comprises 317 source probes and 31 import probes; verify the inventory if it changes.
- Every row of the review's 33-error table is Met through full-checker golden cases.
- The Hoon import-table test includes unions, atoms/cells, maps, and recursive molds, printed and used through the full checker under eval and on the ship.
- Every golden case and test arm passes; `nix flake check` passes.
- The `my-app` desk builds its `/sur` files and marks through Clay and checks all 11 UI modules in dependency order, with exactly one expected failure: `buttons.jibb` at 3:16.
- Replaced recovery paths are deleted.
- Measure 2,000-line generated modules in both source orders and the desk with debug disabled. Record counts and timings in `docs/status.md`.
- Update the capability table, compiler/design documentation, Decisions, and open questions. Mark milestone 2 done only after its criteria hold.
- Commit and push the completed work to `master`. If project chat is available, send the brief's requested completion report; do not claim to have sent one without actually doing so.

Lowering, backends, the host, routes, runtime, formatter, and later-milestone features remain outside this assignment.

## Handoff snapshot: 2026-11-04 02:13 UTC

This section is a dated snapshot, not a statement that the listed processes are still running. Recheck it before acting and update it when the continuation state changes.

The branch was `master`, HEAD `9e4bb53`. No commit or push was made during the latest continuation. The shared compiler SHA256 was:

```text
5e6595e9d267e1b533ddf41d3ed96c0609238231e052e0aaae91549c6285bbe7
```

General context inference, W source/provenance diagnostics, calendar/prelude diagnostics, and guarded recursive empty-domain certification had been integrated locally. The recursive empty-domain change passed 17 eval and 17 Clay checks. Milestone 2 remained incomplete.

### Immediate root continuation

The composed scratch checker is `/tmp/jibb-root-watch/current-watch-70e7.hoon`, SHA256 `f460e70cd6f2b3d6325898482801f5fd4484e2f4d4e38b02d624539094d5f045`. Its checkout is `/tmp/jibb-root-watch/current-watch-checkout`; its runner is `/tmp/jibb-root-watch/current-watch-safe-test-arms`.

The latest 12-suite batch failed to compile with `-find.program-main-closed`; see `/tmp/jibb-root-watch/current-watch-controls.log`. The cause is confirmed: a shared-tests overlay replaced two migrated suites with older tests calling deliberately deleted recovery helpers.

Restore `jibb-program-watch.hoon` and `jibb-program-products.hoon` from `/tmp/jibb-root-watch/combined-v23-checkout/tests/lib/` into the current scratch checkout. Inspect remaining obsolete-helper references and preserve the forged-capability controls. Do not restore the obsolete compiler helpers just to satisfy those old tests. Rerun the focused checks after correcting the fixtures.

This scratch composition contains the watch/kind replacement, recursive-data precision fix, precise watch-tag sites, union declaration sites, field diagnostics, and negative atom/recursive fitting. It predates the latest shared recursive-empty patch and still needs composition with the other agents' final changes.

The recursive-analysis fix passed the closure regression and discarded-island controls, and all 12 p7 probes passed. A separate valid delayed-subscription inference case remains unresolved. Four theme diagnostics were generated and reviewed with precise field/declaration sites. A fifth local-mold/decoy golden is staged but had not been generated. None of this root stage had been promoted to the shared compiler.

### Agent work and logs

| Area | State and location |
| --- | --- |
| Desk | List/bit/calendar ship run last reported 35/38 arms: `/tmp/jibb-desk-test/list-bit-calendar-fixed-ship.log`. UI-key ship run: `/tmp/jibb-desk-test/ui-keys-ship.log`. Combined map/list/bit/context/W eval: `/tmp/jibb-map-bit-w-work/combined-eval.log`. |
| Map integration | Reader and multiple-generator source proofs passed focused Clay tests. Reader patch: `/tmp/jibb-map-reader.patch`; compiler delta: `/tmp/jibb-map-over-list-bit-w.patch`. The 101 caller migrations and tool adapters are staged in `/tmp/jibb-map-migration-run`; review before copying. |
| Inference | Combined W/context/list/bit eval: `/tmp/jibb-list-bit-w-combined.log`, session 87659. UI-key source patch: `/tmp/jibb-ui-keys-source.patch`; five reviewed goldens: `/tmp/jibb-ui-key-goldens`. UI-key behavior passed seven eval arms; ship validation was running. |
| Local inference gaps | Nonrecursive capture candidate: `/tmp/jibb-local-capture-w.hoon`. Recursive-capture failing fixture: `/tmp/jibb-local-capture-recursive-suite`. Valid delayed subscription fixtures: `/tmp/jibb-stream-small-suite/jibb-stream-small.hoon`. Projection/value-face inference remains unfinished. |
| Imports/diagnostics | Failed-gate diagnostic continuation: `/tmp/jibb-failed-gate-context.patch`, scratch checkout `/tmp/jibb-p9-diagnostic-run`. Eight focused controls passed; actual p9/p10 probes were running in session 73698, log `/tmp/jibb-p9-seed-all.log`. The original error must remain mandatory; provisional diagnostic types must never publish successfully. |
| Other pending patches | Missing qualified mold: `/tmp/jibb-missing-qualified-mold.patch`, awaiting ship validation/rebase. Negative atom/recursive fit: `/tmp/jibb-atom-recursive-negative.patch`, included in root scratch but awaiting final integration/ship checks. |
| Legacy reports | Twenty-eight reviewed golden migrations are staged at `/tmp/jibb-legacy-reviewed-cases`; broader report migration remains incomplete. |

Finish the pending diagnostic, local-inference, API, import, and source-origin work; integrate the map/list/bit/UI-key/root changes; then run the complete acceptance checks. Focused green results do not replace that final validation.
