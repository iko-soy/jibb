# Questions from the 2026-11-02 review

Every decision that [the review](2026-11-02-repo-review.md) raises, with options. Each **Answer** was prefilled with the recommended option. An answer marked *(chosen)* is the one Montelot picked; the rest are still the recommendation. A-numbers point into the review's appendix.

Questions 16 to 28 are language or spec rulings. Under the ground rules they are @iko's to make and are recorded in decisions.md before the code changes.

## Scope and process

**1. Where should the review land?** It is on `claude/project-thread-7prdcx` now.

- a) Push it to `master`, as development.md's "push straight to master" rule says.
- b) Open a pull request.
- c) Leave it on the branch.

**Answer:** a *(chosen)*

**2. What should be done first?**

- a) The eight "fix first" bugs.
- b) The simplifications, starting with the test runner.
- c) The docs cleanup.
- d) Nothing more for now.

**Answer:** a *(chosen)*

**3. How should fixes land?**

- a) Commits straight to `master` once every check passes, as development.md says.
- b) One pull request per theme.
- c) A branch you merge yourself.

**Answer:** a *(chosen)*

**4. Should a fake ship be set up in the cloud container**, so the ship checks run too? That needs the brass pill from GitHub LFS and a few minutes to boot.

- a) Yes, before any fix that touches tools/ship, the desks or the mark.
- b) No, eval checks are enough.

**Answer:** a *(chosen)*

## Direction

**5. How should the checker grow from here?** (A121)

- a) Build the general core first: union-find bindings with levels, a deferred-constraint queue and Maranget's usefulness check, with `main = (program …)` checked as an ordinary application.
- b) Keep adding recovery paths until milestone 2's examples pass, and refactor after.
- c) Both: make today's recovery fall back to ordinary inference now, and plan the core as the next milestone-2 task.

**Answer:** a *(chosen)*

**6. Should the partial `golden-types` report be rendered from the full checker's per-definition results**, so there is one pipeline? (A122) About 283 `types.txt` outputs would change once.

- a) Yes.
- b) No, keep the two pipelines.

**Answer:** a *(chosen)*

## Checker fixes

**7. How should the keyed-view screen be fixed?** (A119, A38)

- a) Run ordinary inference first, and recovery only for components it leaves unresolved. Some todo diagnostics may change.
- b) Keep recovery first, and fall back to ordinary inference when it declines.

**Answer:** a *(chosen)*

**8. Should the narrow initializer recovery go?** Deleting the null-sample gate and `program-init-context` (about 140 lines) lets the general path handle reordered models, and the seven negative init fixtures still fail. (A39)

- a) Yes, once the todo, store and program tests pass.
- b) No.

**Answer:** a *(chosen)*

**9. How should an imported Hoon `(unit T)` be handled?** (A10)

- a) Translate it to the prelude's `unit` union, passing the prelude template into the import bridge.
- b) For now, make it fit as unknown, so it fails closed instead of giving a false error.

**Answer:** a *(chosen)*

**10. Should printed types say `ask` and `qath` instead of `ask.internal` and `qath.internal`?** Two expected outputs change. (A134)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**11. Should every `?-` branch kind join its arm results by one rule:** unify, and if that fails, widen to an explicitly present parent aura or `@`? Then `?- b  %.y n  %.n 0` with `n=@ud` checks. (A133)

- a) Yes.
- b) No, keep the per-kind rules.

**Answer:** a *(chosen)*

**12. Should top-level resolution make one pass in dependency order**, keeping the fixpoint as a fallback, with a 400-definition timing check added to the suite? (A135)

- a) Yes.
- b) Only the fix.
- c) No.

**Answer:** b *(chosen)*

**13. Should the checker keep the errors it already finds?** That means the real error inside a local `++`, the name of the failing definition, the API reasons, and a definite error for a derived-name clash. Boundary strings that tests lock in would change. (A12, A40, A24)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**14. Should the 26-variable printer limit stop gating which modules check?** The printer would print `T27` and on, as it already can. (A124)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**15. Should the 32,768-node freshness scan be replaced** by a fresh-ID high-water mark computed once, with `%recursive` treated as a leaf? (A37)

- a) Yes.
- b) Keep the scan and document its budget.

**Answer:** a *(chosen)*

## Language and spec rulings

**16. Which auras may a term literal fit?** Today `^- @tas %1.000` and `^- @tas %&` are accepted and `^- @ud %1.000` is rejected, the opposite of Hoon. grammar.md:141 supports the code; grammar.md:29 and "Literals: exactly Hoon's" don't. (A20)

- a) Follow Hoon: a term literal fits its own aura family, so `%1.000` is `@ud` and `%&` is `?`.
- b) Keep grammar.md:141 as written.

**Answer:** a *(chosen)*

**17. May a name term fit `@t`, as `@tas` nests in `@t` in Hoon?** grammar.md:141 lists only `@tas`, `@ta`, `@` and `*`. (A20)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**18. May a gate fit `*`?** core-language.md says a function isn't a noun, but the prelude's `element` erases gates into `*`. (A23)

- a) Yes: say in the spec that `*` may hold gates.
- b) No: design a typed erasure first.

**Answer:** a *(chosen)*

**19. Where should `[]` and `m()` be rejected?** Both are decided errors. Today the parser accepts them, and the checker calls `[]` "not supported". (A6, A100)

- a) In the parser, at the closer, with new golden cases.
- b) In the checker, as definite errors.

**Answer:** a *(chosen)*

**20. Is `[a=@ud [a=@t b=?]]` one record or two scopes?** Hoon treats it as flat, and field access already does. Today the duplicate `a` is accepted and `a.x` is "ambiguous". (A30)

- a) One record: the duplicate is an error.
- b) Two scopes, as compiler.md says now.

**Answer:** a *(chosen)*

**21. Should `/%  %foo` together with `++ foo 1` be allowed?** `/%` binds only a mold, and molds and values have separate namespaces (grammar.md:94 and :102), but the scope check rejects it. (A25)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**22. Should a `?-` arm that matches no remaining case be a definite error** ("arm matches no case"), as grammar.md:184 implies, instead of "not supported"? (A15)

- a) Yes.
- b) No.

**Answer:** a *(chosen)*

**23. Should `(mop K V)` carry its comparator,** so that `get.on gth` on an `lte` mop is an error? Neither Hoon nor decisions.md:39 does this. (A55)

- a) No, match Hoon.
- b) Yes.

**Answer:** a *(chosen)*

**24. Should Hoon's `each` mold be renamed to `each.hoon`**, since the prelude also has the element gate `each`? They live in separate namespaces. (A64)

- a) No, keep both.
- b) Yes.

**Answer:** a

**25. When should `eq` and the gate-free type-variable constraint be built?** Both are decided, neither exists, and no doc tracks them. (A98)

- a) In milestone 2.
- b) Later, and list them as outstanding.

**Answer:** a

**26. Which Hoon unions should the importer learn?** Today `$%` with `%&`, `%|` or `%0` tags, `(each a b)` and `json` all fail, though the spec's import table lists them. (A50)

- a) The non-`%tas` tags now, then `each` and `json` as catalog entries.
- b) Only the tags.
- c) Later.

**Answer:** a

**27. Should the `%jibb` mark keep dropping the final newline on a `%txt` round trip**, as `%hoon` does? (A61)

- a) Keep it, like `%hoon`.
- b) Preserve the newline, and change tools/ship's assertion.

**Answer:** a

**28. Should the printer flatten `[a [b c]]` to `[a b c]` and print named molds by name**, such as `theme` and `item.todo`? (A136)

- a) Yes.
- b) No.

**Answer:** a

## Tests and tooling

**29. Should one runner over the `tests/lib` test arms replace the 49 `tools/type-*-test` scripts and `importer-test`?** A prototype ran them in 681 s instead of 2,591 s. The `my-app` byte guards would move to a manifest. (A82, A120)

- a) Yes.
- b) No.

**Answer:** a

**30. Should there be one `tools/check` command, and CI?** (A92, A96)

- a) `tools/check` now, and a CI job for the eval checks now.
- b) `tools/check` now, CI at milestone 7 as planned.
- c) Neither.

**Answer:** b

**31. How should the 28 copies of `my-app` files under `tests/` be handled?** (A108, A109)

- a) Map `my-app` into the `jibb-dev` desk outside `/tests` and read it directly, removing the copies.
- b) Keep the copies, and guard them all from one manifest.

**Answer:** a

**32. Should the generated `tests/lib/jibb.hoon` (3,949 lines) stop being committed?** Assembly drops it and regenerates it anyway. (A83)

- a) Yes, and add it to .gitignore.
- b) No.

**Answer:** a

**33. Should the importer's test fixtures (about 550 lines) move out of `jibb-import.hoon`**, which app desks vendor, into `tests/lib/jibb-import.hoon`? (A52)

- a) Yes.
- b) No.

**Answer:** a

**34. Should the import-only fixtures move off `my-app`** (`sur/import-fixture.hoon`, `mar/label.hoon`, the Tlon probe) to a fixtures desk? (A113)

- a) Yes.
- b) No.

**Answer:** a

**35. Should the five `tools/hoon` checks that exit 0 whatever they print become test arms?** (A91)

- a) Yes.
- b) No.

**Answer:** a

**36. Should type-checker golden cases keep their full token and tree outputs?** They are 73% of all parser golden lines. (A94)

- a) Keep them: each stage's output is compared.
- b) Let type cases opt out.

**Answer:** a

**37. Should the tests keep calling internal library arms (137 of them)?** (A126)

- a) Keep them for now, and revisit after the checker core changes.
- b) Move them behind a small public facade.

**Answer:** a

**38. Should `my-app` keep the failing buttons example and the doc theme's static font?** Milestone 4 will treat both as errors. (A112)

- a) Keep them through milestone 2, and list it as a milestone-4 open question.
- b) Move the error example out now.

**Answer:** a

**39. Should every vendored package keep going into every desk?** (A117)

- a) Yes, as designed.
- b) Make it per desk.

**Answer:** a

**40. Should `tools/hoon` get a `--no-debug` mode** for timings, with the docs' figures re-measured? Every eval runs with `!:`, which makes checker work 2.2 to 2.6 times slower. (A137)

- a) Yes.
- b) No.

**Answer:** a

## Docs and repository

**41. Should status.md become a capability table** (area, status, the test that proves it) plus a short list of gaps, with the history table replaced by `git log`? (A97, A95)

- a) Yes.
- b) Only fix the contradictions.

**Answer:** a

**42. Until the Claude design doc is synced, which spec wins?** (A104)

- a) The repository copy, with a "synced" column in decisions.md.
- b) The Claude doc, as development.md says now.

**Answer:** a

**43. Who syncs the Claude design doc with the repository's decisions?**

- a) Me, if you give me edit access to it.
- b) @iko.
- c) Leave it for now.

**Answer:** b

**44. Should open-questions.md hold only open questions**, with settled ones moved to decisions.md? (A103)

- a) Yes.
- b) No.

**Answer:** a

**45. Which licence should the repository have?** It has none, and doesn't state the licences of `vendor/` or the Tlon fixtures. (A107)

- a) MIT, like urbit/urbit.
- b) Another licence.
- c) None: keep it private.

**Answer:** a
