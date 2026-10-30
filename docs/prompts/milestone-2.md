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

1. **Specify the prelude inventory.** The checker needs the prelude's complete exported inventory and signatures; include all names from the listed Hoon library sections except explicitly excluded groups, as `docs/open-questions.md` question 3 records. The prelude imports private helpers and low-level primitives from a separate internal module without exposing them; its public foundational gates are implemented in Jibb on those primitives.

   The plan's three core-language rules were adopted: gate-free `eq` arguments and map and set keys, with gates opaque for union matching; jetted prelude functions taking gates; and rejection of a non-gate value that depends on itself even through a gate.
2. **Start the importer early**, as the plan's Risks ask: first on a small `/sur` file, then on Tlon's. "Suggested design" below has a way in.

## What the doc asks of the checker

The rules are scattered across the tabs. This is a map of them, not a replacement: read each in place, and where this summary and the doc differ, the doc is right.

**Types and inference** (Grammar: Molds, Modules, Runes, Expressions; Decisions: Inference, Type variables, Sample names, Inline gates)
- Hindley–Milner with aura variables: "every expression has a principal type, and there is no general subtyping". A specific atom fits `@`, a specific noun fits `*`, and a more specific aura fits an ancestor in its Hoon aura family, each only in that direction; the reverse needs a check.
- `@` means any atom, independently at each occurrence. A specific atom such as `@ud` fits where `@` is expected; an `@` value needs a check to fit `@ud`. `@ud` and `@ux` also fit `@u`, and `@tD` fits `@t`, following Hoon aura families; the reverse needs a check. Distinct specific auras remain distinct. `add` takes `[A A]` and returns `A`, with an atom constraint inferred for the shared type variable.
- Faces are part of record types: `[a=@ b=@]` and `[x=@ y=@]` don't unify. An unnamed position can unify with a faced one and take its face, so `[0 0]` fits `[x=@ud y=@ud]`. A single-item cell `[a]` is `a`; an empty `[]` is an error.
- Type variables are capitals, "generalized per `++`". A capital in a local `++` shares the enclosing `++`'s variable of that name; a different type takes a different capital. "A type variable used where an atom is required gains an atom constraint", so `++ clamp |= [lo=A hi=A n=A]`, calling `gth` and `max`, works on any one aura; "It can become nothing more specific: a body that makes `A` a `@ud` or a list is an error." Names "may refer to each other in any order", so infer `++` definitions in dependency order, a group of mutually recursive ones together.
- The checker infers a gate-free constraint for `eq` arguments and map and set keys and retains it when a type variable is generalized. The requirement applies recursively to nested values; union-case matching treats gates as opaque. Print a gate-free constraint as `$-([A A] ?) where A contains no gates` and an atom constraint as `$-([A A] A) where A is an atom`; separate multiple clauses with commas, as `where A is an atom, B contains no gates`.
- Gates may call themselves and their siblings; a non-gate value that depends on itself, even through a gate, is an error. Molds may be recursive, and "recursive molds go by name and module".
- A sample's mold may be left out: every bare name in a sample binds, at any depth, as in `|=(p title.p)` "when the call fixes the type", `|= [a=@ b]` and `|=(m ~)`.
- Generic molds: `+$ result |$ [V E]` with cases below, applied as `(result V E)`; `|$` goes right after a `+$`'s name, and the prelude's `cmd` and `sub` use `|$ [M]`.
- `!!` is the empty mold, and as an expression it has any type. `*` is the noun type, not a type variable; generic positions such as the keys in `each` and `table` use a capital. A value of a more specific noun type can be used where `*` is expected.
- `poke`, `ask` and `qath` are opaque, built only by derived gates, `pure` and application-path literals.
- The Literals table gives every other literal its type: `0x1f` a `@ux`, ships `@p`, dates `@da`, durations `@dr`, `~.knot` a `@ta`, strings `@t`, `` `x `` a `(unit A)`, `~[…]` a `(list A)`, `gap+%s2` the pair `[%gap %s2]`, `/posts/~zod` a `path`, `%/blog` a `qath`.

**Tags, `~`, numbers and cells wait for their context** (Grammar: Tag resolution, Literals by context)
- A tag or `~` gets a fresh variable and a pending constraint, checked once unification fixes the variable: against a union's cases, by shape and shared tag positions, or as a constant atom for `@tas`, `@ta`, `@` or `*`. A literal that matches nothing is "an error naming the union, such as "msg has no case %submitt"".
- `|=%typed` is a case's constructor: "against `$-(@t M)` it is `|=(t [%typed t])`, requiring `M` to have a case `[%typed @t]`. It works for cases tagged at their head; a bare tag is always a value."
- A variable constrained by tag resolution, and any it mentions, doesn't generalize; it stays open until something in the module fixes it. An island's `main` fixes its messages. A tag constraint still open when the module is checked is an error asking for a `^-`; the checker never guesses. Gate-free constraints are retained when generalized.
- "Wing access, changes and `?-` on a type not yet known wait the same way." A change with no items, `m()`, is an error; the parser still accepts it. Patterns don't wait: they're checked against the subject's type.
- Number and cell literals each "takes a default when its `++` is checked": a number `@ud`, a cell a tuple. But "A number takes `@ud` only if nothing fixes its aura and its `++` isn't generic over it", so `++ inc |= n=A (add n 1)` stays generic: unlike a tag's, a number's variable doesn't stop its `++` from generalizing. A cell can also become a record or, where a list is expected, a cons.
- In `{…}`, atoms print by aura, a bare `@` as `@ud`; `@t`, `@ta`, `@tas` and tapes splice as text; "any other cell is an error asking for a printer". "Printers are picked when compiling", so an atom whose aura its `++` is generic over "is an error asking for an aura", in `{…}` and in a `(…)` segment of an application path. String literals are always cords.

**Unions** (Grammar: Molds, Runes; Decisions: Unions)
- Every union written in Jibb is a named `+$` with its cases below. One case is just that mold; a mold that isn't a union counts as a union of one case for tags and `|=%tag`. Imported types can contain unnamed unions.
- Cases "must differ as nouns: inhabited cases must differ at some position of their right-nested cells, where one is an atom and the other a cell, or both are different constants. `*`, type variables and molds that can be either, such as `(list A)`, can overlap atoms and cells. `?` counts as the two atoms `%.y` and `%.n`: it is disjoint from cells and overlaps the constants 0 and 1. The empty mold `!!` is disjoint from every case; a cell with an empty position at any depth is itself empty and is also disjoint from every case. A union whose cases don't all differ is rejected."

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
- `/ui/api/<agent>.jibb` declares `+$ poke` and `+$ paths`; "`poke` and `paths` are declarations, not molds." "A path case is a request name, a path and a type", and "A case can name another scry path, as in `[%changes /updates (facts todos todo-update) scry=/todos]`, used only by pages." An island watching a request whose case has `scry=` has a type error.
- Each poke type gives a constructor, as `todo-action.todo`, and each path case a request, as `(todos.todo |=%got)`. A path with typed segments takes them too: the overview's `(post.api slug same)` suggests they come first. A `(facts full diff …)` case's request also takes a fold, as `$-([[%todo-update todo-update] todos] todos)`.
- A store's `+$ poke` is a declaration, not a mold. A store exports a constructor per poke type and a `state` request. Clashing derived names are errors, including clashes with an import face. The checker must account for the fact that the type of `main` determines whether a module is a store.

**The prelude** (overview: Prelude, Layout and styling, Links and URLs, Effects)
- Hoon's standard library regrouped, "written in Jibb and vendored as `/lib/jibb/prelude`", plus `eq`, `not`, `page`, `program`, `store`, `pure`, `island`, the layout elements and molds, `attr`, `theme`, and `cmd` and `sub` as the overview's Effects block writes them.
- Signatures change where the Prelude table says: maps and sets are plain gates over Hoon's trees, as `(get.by m k)`; folds take a start, as `(roll xs init f)`, `rep.by` and `rep.in`; ordered maps go through lull's `on`, as `(get.on lte m k)`.
- Left out: signed and float gates, parser helpers outside 3g other than the explicitly listed `slav` and `slaw`, and the table's "The rest" (1b, 2p, 3d, 3f, 4c, 4n, 4o, 5a–5f); "`jam`, `cue` and `fein` run inside the runtime".
- Write the prelude in Jibb, enough to give every name its type. Foundational gates use private low-level primitives from the internal prelude module. Jetted functions have working Jibb implementations; the compiler recognizes their shapes and uses the Hoon versions so jets can fire. They may take gates as arguments; the Nock backend comes in milestone 3.
- Element signatures are in the Layout and styling table. Paths and unchecked cords have separate declarations, with `link-unsafe`, `image-unsafe` and `go-unsafe` for the unchecked forms. Both navigation declarations produce `[%go url=@t]`; `go` converts its application path to a cord including the app's base path. "The same attribute twice in a literal list is an error."

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
- **A type printer** for golden output and messages. Use Jibb's mold syntax where possible; Jibb has no syntax for an unnamed union, which prints its cases separated by spaces, as `%approve %deny`.
- **Mind two names.** The library's `+in`, a bit test, hides the standard library's set door `in`, and `+fail` hides Hoon's parser rule `fail`. Write `in:..zuse`, or rename `+in` before the checker uses sets.

## Tests

- **A third golden output.** Add the checker's output to `+golden`, say `types.txt`: each definition's type (printing an unnamed union's cases separated by spaces) and the module's kind, or the rendered error. Teach `tools/golden`, `tools/ship gen-tests`, the stubs and self-tests in `tools/testdata`, README.md and `docs/development.md` about it, with an `expect:` form for the checker, then add it to the existing cases and review every one.
- **Cases with imports.** Six of the doc's fourteen `jibb` blocks import other modules, three of them `/sur` files or marks, and the Core language tab's `update` needs the todo API without importing it. Give a case a way to carry the files it imports, under eval and on the ship alike. A case also needs its own path under `/ui`: both runners pass the file as `/tests/golden/<case>/source/jibb`, but an API file is known by its path, `/ui/api/<agent>.jibb`, whose name is the agent its constructors poke.
- **Hoon files on the ship.** `tools/ship test` runs `-test` on the `jibb-dev` desk's `/tests`, which builds every `.hoon` file there as a test file. A fixture mark that starts `/-  todo`, or one of Tlon's files, fails that build, and with it the run. Keep such files where `-test` won't build them, as `.txt` read with `/*`, or in a desk of their own, and keep them out of `jibb-dev/`, which app desks vendor, and `vendor/`, which goes into every desk.
- **Fixtures for the doc's examples.** `my-app/ui/` holds nine of the doc's blocks as modules. Add what they import that the doc doesn't show: `/sur/todo.hoon` and the marks `todo-action`, `todos`, `todo-update` and `todo-item` (the overview shows `/mar/todo-action.hoon`; `row-of` reads `id`, `done` and `text` from an item); `/sur/blog.hoon`, a mark for the posts, of type `(list post:blog)`, and `/ui/api/blog.jibb`, whose `posts` case names that type through `/%`; and `/ui/components/card.jibb`, with a `card` gate from a post to an element. Keep them as small as the examples allow, say in a comment at the top of each that it is a fixture and not from the doc, and don't change the doc's blocks.
- **Every doc example typechecks**, except the Grammar's buttons example, whose `add-button` is written as an error and must fail with it. The same block marks `labelled` and `wide` as fine, so show them checking too, by printing the definitions that check beside the error or in a case without `add-button`. Check the three blocks that aren't whole modules in their intended contexts: `cmd` and `sub` as prelude source, the Core language tab's `update` inside the todo island, and the imports example against fixtures.
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
