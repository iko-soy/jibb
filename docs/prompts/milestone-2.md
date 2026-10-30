# Milestone 2: types and prelude

A brief for the developer who builds milestone 2 of Jibb. Paste it as the first message of a session, or hand it to a person; it assumes a fresh start in the repo `iko-soy/jibb`. Written 2026-10-30, at commit ab797a9, when milestone 1 was done.

---

You are building milestone 2 of Jibb, a UI language for Urbit: a Hoon dialect with an indentation layout. Its spec is @iko's design doc, [Jibb — an Elm-architecture UI language for Urbit](https://claude.ai/artifact/DMBr48qzi5z8hcwn2ccPBv), with its repository copy in `docs/spec/`; the repository records the decision to drop `$?` pending synchronization to the Claude document. Milestone 1 built the layout pass and the parser in Hoon, in `jibb-dev/lib/jibb.hoon`. Milestone 2 adds the type checker, the imports, and the prelude.

Before milestone 2, @iko decided on 2026-10-30 to drop `$?`. The change is described in [drop-union-rune.md](drop-union-rune.md); check `docs/status.md` for its completion.

## Read first

1. `docs/README.md`, `docs/status.md` and `docs/development.md`: where things stand, the ground rules, how to set up a machine.
2. `docs/spec/implementation-plan.md`: milestone 2, the Compiler architecture section, Risks and Open questions.
3. `docs/spec/grammar.md`, all of it, and closely: Literals, Molds, Tag resolution, Literals by context, Patterns, Modules, Imports, Runes, Expressions. This is most of your spec.
4. `docs/spec/overview.md`: Importing Hoon types, Prelude, The Elm architecture on Urbit (kinds, islands, effects), Layout and styling with Links and URLs, Agent APIs, Desk layout, the worked examples.
5. `docs/spec/decisions.md`: every row, and closely Special rules, Inference, Unions, Branching, Hoon types, Derived gates, Type identity, Kinds, Type variables, Empty mold, Inline gates, Sample names, Binding patterns, Text, Auras, Imports and Data crossing to the browser.
6. `docs/spec/core-language.md`, Values and invariants: what the front end guarantees the backends. The checker's share includes "No shadowing" and island data without gates.
7. `docs/compiler.md`, then the design notes at the top of `jibb-dev/lib/jibb.hoon` and its `%tree` chapter: the syntax tree you will check.
8. `docs/open-questions.md`.

Then set up the machine as `docs/development.md` says and run its checks. All golden cases should pass before you change anything.

## Ground rules

- **The spec wins.** Where code and spec disagree, the spec stands until it changes. `docs/spec/` records the decision to drop `$?`, which still needs synchronization to the Claude document; consult the document for other details as described in `docs/README.md`.
- **Don't decide the language.** A question about what Jibb means goes to @iko: as a comment on the doc, on the words it's about, if you can comment there, or else in the project's chat, where @iko reviews work. List it in `docs/open-questions.md` too. Meanwhile follow the most likely reading, mark it "(doc question)" in the library's notes, and keep going. A language change is agreed first and recorded in the Decisions tab.
- **No built-ins.** The Decisions tab's Special rules row: "No built-ins; type-directed rules are welcome, each listed in the Grammar tab". A typing rule the Grammar doesn't list, such as a special case for one gate, is a language change.
- **Implementation choices are yours**: data structures, algorithms, error wording within the doc's rules, test layout. Record the reasoning in the library's design notes, as milestone 1 did.
- **Everything is a golden test**, and every check passes on the fake ship as well as under `urbit eval`.
- **Push straight to `master`**, in commits that each leave every check passing. No pull requests.
- **Keep `docs/` current**: `status.md`, `open-questions.md`, `compiler.md` and `development.md` change with the code.

## The milestone

From the plan, word for word:

> **Types and prelude**
> - Builds: Hindley–Milner inference with aura variables; tag and literal resolution with deferred constraints; the union disjointness check; exhaustive `?-` with dead-arm errors; `/-`, `/%` and `/=`, with the table for importing Hoon types; API files and their derived gates; the prelude's types.
> - Done when: the doc's examples typecheck, except those written as errors; each error the Grammar tab describes has a test with its message, such as "msg has no case %submitt"; a `/sur` file with `$%`, `$@`, maps and a recursive mold imports as the table says.

One Grammar error waits: checking an application path "against routes and static files" needs routing, which the plan builds in milestone 4. Say so in your report.

And from the plan's Risks:

> **Importing Hoon types.** Hoon's types form a graph with lazy `%hold` nodes, so the importer needs Hoon's own type engine to expand them, and it must recognise maps, sets and recursive molds by name. Start it early in milestone 2, on real `/sur` files such as Tlon's.

> **Type errors.** Hindley–Milner is known for confusing errors. Each error names both conflicting sites, with excerpts, and the messages are golden tests.

## First steps

1. **Settle the open questions.** The checker needs answers the doc doesn't give yet. `docs/open-questions.md` lists twelve under "Questions milestone 2 raises", found by walking the doc's examples through its rules:
   1. how the prelude declares natives;
   2. how it marks private names;
   3. what the prelude holds, and whether milestone 2 writes "the prelude's types", as the plan says, or "the core prelude gates", as the Decisions tab's Build order says;
   4. whether a capital in a local `++` is the enclosing `++`'s (the rest of that question was settled on 2026-10-30);
   5. `[]` and `[a]`;
   6. `m()`;
   7. how to check the doc's blocks that aren't whole modules;
   8. whether a tuple can meet a record, which worked example 3 needs;
   9. how a typed value meets `*`, as `each`'s `key=*` does;
   10. what `link`, `image` and `go` take;
   11. stores' `+$ poke`, derived-name clashes, and watching a `scry=` case;
   12. the print-only notation for unions without a name.

   The plan's first open question matters too: whether `eq`'s arguments and map and set keys must be free of gates, and a gate may never tell a union's cases apart, which changes the disjointness check; whether natives may take gates, which decides whether `turn`, `sort` and `skim` are natives; and whether a value that depends on itself through a gate is an error. Put each to @iko in your first days with a proposed answer and the reason for it, and build on the proposal until you hear back.
2. **Start the importer early**, as the plan's Risks ask: first on a small `/sur` file, then on Tlon's. "Suggested design" below has a way in.

## What the doc asks of the checker

The rules are scattered across the tabs. This is a map of them, not a replacement: read each in place, and where this summary and the doc differ, the doc is right.

**Types and inference** (Grammar: Molds, Modules, Runes, Expressions; Decisions: Inference, Type variables, Sample names, Inline gates)
- Hindley–Milner with aura variables: "every expression has a principal type, and there is no subtyping".
- "`@` is an atom whose aura isn't known yet, fixed by what it meets": `add` takes `[@ @]` and returns `@`, all one aura. "Different auras never unify." "A bare `@` in a `+$` is one aura variable per module, `@ud` if unfixed." Elsewhere, "as in a gate's sample or a cast, each bare `@` is its own aura variable, generalized per `++` if nothing fixes it; atoms that must share an aura take one capital".
- Faces are part of record types: `[a=@ b=@]` and `[x=@ y=@]` don't unify. Whether a tuple meets a record is open question 8.
- Type variables are capitals, "generalized per `++`". "A type variable that meets an atom becomes an aura variable", so `++ clamp |= [lo=A hi=A n=A]`, calling `gth` and `max`, works on any one aura; "It can become nothing more specific: a body that makes `A` a `@ud` or a list is an error." Whether a capital in a local `++` is the enclosing one's is open question 4. Names "may refer to each other in any order", so infer `++` definitions in dependency order, a group of mutually recursive ones together.
- "Gates may call themselves and their siblings; other values can't refer to themselves, so `++ title (trim title)` is an error." Molds may be recursive, and "recursive molds go by name and module".
- A sample's mold may be left out: every bare name in a sample binds, at any depth, as in `|=(p title.p)` "when the call fixes the type", `|= [a=@ b]` and `|=(m ~)`.
- Generic molds: `+$ result |$ [V E]` with cases below, applied as `(result V E)`; `|$` goes right after a `+$`'s name, and the prelude's `cmd` and `sub` use `|$ [M]`.
- `!!` is the empty mold, and as an expression it has any type. `*` is any noun; how other types meet it is open question 9.
- `poke`, `ask` and `qath` are opaque, built only by derived gates, `pure` and application-path literals.
- The Literals table gives every other literal its type: `0x1f` a `@ux`, ships `@p`, dates `@da`, durations `@dr`, `~.knot` a `@ta`, strings `@t`, `` `x `` a `(unit A)`, `~[…]` a `(list A)`, `gap+%s2` the pair `[%gap %s2]`, `/posts/~zod` a `path`, `%/blog` a `qath`.

**Tags, `~`, numbers and cells wait for their context** (Grammar: Tag resolution, Literals by context)
- A tag or `~` gets a fresh variable and a pending constraint, checked once unification fixes the variable: against a union's cases, by shape and shared tag positions, or as a constant atom for `@tas`, `@ta`, `@` or `*`. A literal that matches nothing is "an error naming the union, such as "msg has no case %submitt"".
- `|=%typed` is a case's constructor: "against `$-(@t M)` it is `|=(t [%typed t])`, requiring `M` to have a case `[%typed @t]`. It works for cases tagged at their head; a bare tag is always a value."
- "A constrained variable, and any it mentions, doesn't generalize; it stays open until something in the module fixes it. An island's `main` fixes its messages." A constraint still open when the module is checked "is an error asking for a `^-`; the checker never guesses".
- "Wing access, changes and `?-` on a type not yet known wait the same way." Patterns don't: they're checked against the subject's type.
- Number and cell literals each "takes a default when its `++` is checked": a number `@ud`, a cell a tuple. But "A number takes `@ud` only if nothing fixes its aura and its `++` isn't generic over it", so `++ inc |= n=A (add n 1)` stays generic: unlike a tag's, a number's variable doesn't stop its `++` from generalizing. A cell can also become a record or, where a list is expected, a cons.
- In `{…}`, atoms print by aura, a bare `@` as `@ud`; `@t`, `@ta`, `@tas` and tapes splice as text; "any other cell is an error asking for a printer". "Printers are picked when compiling", so an atom whose aura its `++` is generic over "is an error asking for an aura", in `{…}` and in a `(…)` segment of an application path. String literals are always cords.

**Unions** (Grammar: Molds, Runes; Decisions: Unions)
- Every union written in Jibb is a named `+$` with its cases below. One case is just that mold; a mold that isn't a union counts as a union of one case for tags and `|=%tag`. Imported types can contain unnamed unions.
- Cases "must differ as nouns: at some position of their right-nested cells, one is an atom and the other a cell, or both are different constants. `*`, type variables and molds that can be either, such as `(list A)` or `?`, overlap both. A union whose cases don't all differ is rejected."

**Patterns and `?-`** (Grammar: Patterns; Decisions: Branching, Binding patterns)
- Exhaustive: "Every case needs an arm or a catch-all, `*` or a bare name." Leaving one out is an error naming it.
- "An arm that earlier arms cover, such as a second `%add` or anything after `[%move * *]`, is an error."
- `?-` on a loobean switches on `%.y` and `%.n`. A name in a pattern always binds anew; the last position of a cell pattern binds the rest.
- The Core language tab lowers `?-` "by the usual pattern-matrix algorithm", so one matrix can serve exhaustiveness, dead arms and, in milestone 3, lowering.

**Names and modules** (Grammar: Modules, Imports, Runes, Expressions; Core language: Programs and linking)
- "No name may shadow one already in scope, imports and the prelude included": samples, local `++`s and pattern binders too. The backends rely on it (Core language, "No shadowing").
- Molds and values have separate namespaces, "told apart by position": `todo-action.todo` is a mold and its constructor.
- Local definitions may start any body, "visible to each other and the final expression".
- `/-  todo` gives the molds of `/sur/todo.hoon` the module uses; `/%  %todo-action` gives a mark's type, named after the mark, with no face; `/=  card  /ui/components/card` gives a Jibb module. API modules re-export their `/%` types, "not `/-` faces or `/=` modules". Import cycles are errors.
- Imports and prelude groups are records, read with `.`: `card.card`, `space.theme.theme`, `get.by`. "A module used as a whole value is a cell of its definitions, in name order."
- `main`'s type decides a module's kind: `(element !!)` a page, `(page R D)` a page with data, `(program D X M)` an island, `(store S)` a store; no `main`, a library.

**Importing Hoon types** (overview: Importing Hoon types; Decisions: Hoon types)
- The table: `$%` and `$?` become a union; `$@` a union with an atom case; `$^` a union if its cases differ as nouns, else an error where used; `$~` dropped; `map`, `set`, `qeu`, `jar`, `jug` the same, by name; `mop` as `(mop K V)`, read with `on`; other `$|` their base type; `%0`, `%&` and `%|` tags; recursive molds recursive, matched by name; cores, gates, vases, signed and float auras an error where used.
- "Unused molds are skipped, so unsupported constructs elsewhere in a `/sur` file are fine." A field's unnamed union imports too, although Jibb cannot write one.

**Islands, pages and stores** (overview: The Elm architecture on Urbit; Grammar: Modules and the store example)
- `(page load view)`, `(program init update view subs)` and `(store init update)` build the kinds. The worked examples show their gates' shapes: `update` takes `[msg model]` and gives a model and a list of `cmd`s, `subs` gives a list of `sub`s, a store's `update` takes a poke and the state.
- `main.todo-list` "is a record of exactly `init`, `update`, `view` and `subs`"; in `island main.todo-list ts`, `ts` is "the island's data, checked against `init`'s sample"; `island` gives an `(element !!)`, which keeps islands out of islands.
- "Island data and models can't hold gates; the checker names the field."

**API files, stores and derived gates** (overview: Agent APIs, Effects; Grammar: Modules)
- `/ui/api/<agent>.jibb` declares `+$ poke` and `+$ paths`; "`poke` and `paths` are declarations, not molds." "A path case is a request name, a path and a type", and "A case can name another scry path, as in `[%changes /updates (facts todos todo-update) scry=/todos]`, used only by pages." Islands "can't watch paths that need a separate scry path".
- Each poke type gives a constructor, as `todo-action.todo`, and each path case a request, as `(todos.todo |=%got)`. A path with typed segments takes them too: the overview's `(post.api slug same)` suggests they come first. A `(facts full diff …)` case's request also takes a fold, as `$-([[%todo-update todo-update] todos] todos)`.
- A store exports a constructor per poke type and a `state` request. "Clashing derived names are errors." Open question 11 asks the rest.

**The prelude** (overview: Prelude, Layout and styling, Links and URLs, Effects)
- Hoon's standard library regrouped, "written in Jibb and vendored as `/lib/jibb/prelude`", plus `eq`, `not`, `page`, `program`, `store`, `pure`, `island`, the layout elements and molds, `attr`, `theme`, and `cmd` and `sub` as the overview's Effects block writes them.
- Signatures change where the Prelude table says: maps and sets are plain gates over Hoon's trees, as `(get.by m k)`; folds take a start, as `(roll xs init f)`, `rep.by` and `rep.in`; ordered maps go through lull's `on`, as `(get.on lte m k)`.
- Left out: signed and float gates, parsers, and the table's "The rest" (1b, 2p, 3d, 3f, 4c, 4n, 4o, 5a–5f); "`jam`, `cue` and `fein` run inside the runtime".
- Write the prelude in Jibb, enough to give every name its type: Jibb-written gates as code the checker checks, natives as declarations, in whatever form open question 1 settles. The Hoon gates behind natives come with the Nock backend in milestone 3.
- Element signatures are in the Layout and styling table; what `link`, `image` and `go` take is open question 10. "The same attribute twice in a literal list is an error."

**Errors**
- Each one the Grammar tab describes needs a golden case with its message. A start on the list: an aura mismatch; mismatched faces; "msg has no case %submitt"; an unresolved tag, as the Grammar's `add-button` ("nothing fixes the union of %add"); an open constraint at the end of a module; a `|=%tag` whose union has no such case tagged at its head; a union whose cases overlap; a missing `?-` case, named; an arm that earlier arms cover; a value that refers to itself; a shadowed name, including a prelude or imported one; a cell in `{…}` with no printer; an atom of a generic aura in `{…}` or a path's `(…)`; a capital that a body makes a `@ud` or a list; `~[text "hi"]`, where the checker suggests `~[(text "hi")]`; clashing derived names; an import cycle; from an import, a signed or float aura, a core, gate or vase, or a `$^` whose cases don't differ as nouns, each where used; a `(facts …)` outside an API file's `paths`; a gate in island data or a model, naming the field; a repeated attribute in a literal list. Read the Grammar tab, and the other tabs' mentions of "error" and "the checker", and make the list complete.
- For a `+$` whose cases overlap or do not fit, suggest that a record or tuple leaves its `[` open on the `+$` line. `+$ pt` above `@t` and `[@ud @ud]` is a valid union.
- "Each error names both conflicting sites, with excerpts." Today's `error` is `[file line col msg]`, a start only; spans keep each node's end so that a type error can underline both sites.
- Messages name things in the doc's words and quote the code they're about in backticks, as milestone 1's do. Their wording is fixed by the golden tests once written.

## Suggested design

Suggestions, not rules; change them where you find better.

- **Keep the checker a function.** `urbit eval` can't scry, so let the caller pass in what comes from Clay: the source of each imported module, or its checked interface, each imported Hoon type, and the prelude, which jibb-dev vendors beside the library as `/lib/jibb/prelude` (overview, Desk layout). On a ship the host (milestone 4) reads them; in tests the harness does, loading the prelude once per run. The plan caches "per module, with its interface and body hashed separately", so make a module's interface, its exported names, molds and types, a noun of its own.
- **A way into the importer.** Under `urbit eval`, this compiles a `/sur` file and reads a mold's type (checked on 2026-10-30, vere 4.6):
  ```hoon
  =/  cor=type  -:(ride -:!>(..zuse) src)        ::  src: the /sur file's text, with no Ford runes
  =/  t=type  (~(play ut cor) (ream '*action'))  ::  the type of an action
  ~(repo ut t)                                   ::  expands one %hold
  ```
  `..zuse` is the subject a ship builds `/sur` files against, so molds from lull and zuse, such as `json` and `mark`, resolve. Each `+$` arm's type comes as a `%hold` whose expansion is a `%hint` with a `%made` note naming the arm, then the mold: a `$%` is a `%fork` of cells headed by `%tas` constants. A `(map id item)` field is named only in its arm's own `%hold`, whose Hoon calls `map` by name. Once the arm is expanded, the field is a `%hold` whose Hoon is the body of `map`, `(tree (pair key value))` with its `apt` check, which expands to a second `%hold`, `tree`'s body, and only then to a treap's `%fork`. So recognising maps, sets and the rest by name means reading an arm's Hoon before expanding it, or comparing a `%hold`'s Hoon with the standard library molds' own bodies. On a ship, `.^(vase %ca /=my-app=/sur/todo/hoon)` builds a `/sur` file, and a mark's type is its door's sample. Most of Tlon's `/sur` files begin with `/-` or `/+` (25 of the 40 in `tloncorp/tlon-apps`, `desk/sur`, on 2026-10-30), so under eval their imports must be resolved by hand; on the ship Clay does it.
- **Inference**: union-find over a map of variables, levels for generalization rather than scanning the environment, and a queue of deferred constraints, retried as variables are bound and reported when the module ends. Infer `++`s in strongly connected groups. Measure early: Hoon is slow, and a 2,000-line module should check in seconds, not minutes.
- **Exhaustiveness**: Maranget's "Warnings for pattern matching" (Journal of Functional Programming, 2007) fits nouns: constructors are constants and cells.
- **A type printer** for golden output and messages. Use Jibb's mold syntax where possible; Jibb has no syntax for an unnamed union. Open question 12 asks for a print-only notation.
- **Mind two names.** The library's `+in`, a bit test, hides the standard library's set door `in`, and `+fail` hides Hoon's parser rule `fail`. Write `in:..zuse`, or rename `+in` before the checker uses sets.

## Tests

- **A third golden output.** Add the checker's output to `+golden`, say `types.txt`: each definition's type (using the print-only notation for unnamed unions once question 12 is settled) and the module's kind, or the rendered error. Teach `tools/golden`, `tools/ship gen-tests`, the stubs and self-tests in `tools/testdata`, README.md and `docs/development.md` about it, with an `expect:` form for the checker, then add it to the existing cases and review every one.
- **Cases with imports.** Six of the doc's fourteen `jibb` blocks import other modules, three of them `/sur` files or marks, and the Core language tab's `update` needs the todo API without importing it. Give a case a way to carry the files it imports, under eval and on the ship alike. A case also needs its own path under `/ui`: both runners pass the file as `/tests/golden/<case>/source/jibb`, but an API file is known by its path, `/ui/api/<agent>.jibb`, whose name is the agent its constructors poke.
- **Hoon files on the ship.** `tools/ship test` runs `-test` on the `jibb-dev` desk's `/tests`, which builds every `.hoon` file there as a test file. A fixture mark that starts `/-  todo`, or one of Tlon's files, fails that build, and with it the run. Keep such files where `-test` won't build them, as `.txt` read with `/*`, or in a desk of their own, and keep them out of `jibb-dev/`, which app desks vendor, and `vendor/`, which goes into every desk.
- **Fixtures for the doc's examples.** `my-app/ui/` holds nine of the doc's blocks as modules. Add what they import that the doc doesn't show: `/sur/todo.hoon` and the marks `todo-action`, `todos`, `todo-update` and `todo-item` (the overview shows `/mar/todo-action.hoon`; `row-of` reads `id`, `done` and `text` from an item); `/sur/blog.hoon`, a mark for the posts, of type `(list post:blog)`, and `/ui/api/blog.jibb`, whose `posts` case names that type through `/%`; and `/ui/components/card.jibb`, with a `card` gate from a post to an element. Keep them as small as the examples allow, say in a comment at the top of each that it is a fixture and not from the doc, and don't change the doc's blocks.
- **Every doc example typechecks**, except the Grammar's buttons example, whose `add-button` is written as an error and must fail with it. The same block marks `labelled` and `wide` as fine, so show them checking too, by printing the definitions that check beside the error or in a case without `add-button`. Open question 7 proposes how to check the three blocks that aren't whole modules.
- **The `/sur` import.** A test `/sur` file with `$%`, `$@`, a map and a recursive mold, imported and printed, using the print-only notation for unnamed unions when needed, under eval and on the ship. Then Tlon's real files, as the risk asks: they need not import fully, but every mold a test uses must, and any error must be the table's.
- **On the ship**: the golden cases as `-test` arms, and the `my-app` desk checked with its Hoon types read through Clay: every module checks except `ui/components/buttons.jibb`, which gives `add-button`'s error.
- **Speed**: time the corpus and the `my-app` desk, and record both in `docs/status.md`.

## Out of scope

- Lowering, the core language, its interpreter and the Nock backend: milestone 3.
- Checking application paths against routes and static files, routing, the theme's contrast check and the host: milestone 4. Type `%/blog/(slug)` as a `qath` and its segments as printable atoms, no more.
- `load`'s per-request behaviour and binding route parameters: milestone 5. `page`'s type and `load`'s signature are in scope.
- The JavaScript backend and the runtime: milestone 6. The formatter and the tree-sitter grammar: milestone 7.

## When you're done

- The plan's three "Done when" items hold, but for the route check, and every check in `docs/development.md` passes under eval and on the ship.
- `docs/status.md` shows milestone 2 done, with counts and timings; `docs/open-questions.md` lists what's still open; `docs/compiler.md`, `docs/development.md` and the library's notes describe the checker.
- Everything is pushed to `master`.
- Report to @iko in the project's chat, in a few lines: what was built, the test counts and timings, the decisions you needed and got, and what's still open.
