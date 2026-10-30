# Drop the `$?` rune

A brief for the developer who removes the union rune `$?` from Jibb, as @iko decided on 2026-10-30. Paste it as the first message of a session, or hand it to a person; it assumes a fresh start in the repo `iko-soy/jibb`. Written 2026-10-30, at commit 5cc44b4. Do it before milestone 2, whose brief, [milestone-2.md](milestone-2.md), it updates.

---

You are making one language change to Jibb, a UI language for Urbit: a Hoon dialect with an indentation layout. Its spec is @iko's design doc, [Jibb — an Elm-architecture UI language for Urbit](https://claude.ai/artifact/DMBr48qzi5z8hcwn2ccPBv), copied into `docs/spec/`. Milestone 1 built the layout pass and the parser in Hoon, in `jibb-dev/lib/jibb.hoon`; milestone 2, the type checker, hasn't started. The change: Jibb drops `$?` in both its forms, and a `+$` takes a union's cases on the lines below its name.

## The decision

@iko asked whether Jibb needs `$?` at all, since it is the only way to define a union, and a `+$` without it means what a `$?` of one case means. There were three options: keep `$?`; drop its tall form but keep `$?(%a %b)` for unions inside other molds; or drop it entirely. @iko chose the last, with its costs: "Every union needs its own +$ name. Messages need a print-only notation for unnamed unions from Hoon, and the prelude must name space, role, tone and the like."

What Jibb becomes:

1. **A union is a `+$` with its cases below.** A `+$` takes one mold on its line, or its cases on the lines below it, one per line. Several cases make a union; one case is just that mold, as if it were on the `+$` line.

   ```
   +$ msg
     [%noted text=@t]
     %add
   ```

2. **Every union written in Jibb has a name.** A union used in a field, a sample, a cast, a gate's mold or an argument gets its own `+$`, at the top of the module or among an enclosing body's local definitions. A gate's sample can't use a `+$` from that gate's own body, which only the body sees.
3. **`|$` comes right after a `+$`'s name**, then the mold on its line or the cases below: `+$ cmd |$ [M]` above its cases. `|$` anywhere else is an error. Today the parser takes `|$` wherever a mold goes, as in `++ f ^- |$ [A] A 5`.
4. **A mold that isn't a union counts as a union of one case**, for tag resolution and `|=%tag`: `[%go "x"]` fits `+$ go [%go url=@t]`, and `|=%typed` works against `$-(@t M)` when `M` is `[%typed text=@t]`. Tag resolution today asks for "a union with a matching case", so without this rule a `+$` of one case would not mean what a `$?` of one case meant.
5. **Only `|=` and `$-` keep wide forms.** `$?`, `$?(…)` and `$%` are left out, with messages saying how to write a union.
6. **Unchanged**: cases must differ as nouns; tags take their union from context; `?-` is exhaustive; a record still leaves its `[` open on the `+$` line to put one field on each line below; recursive molds go by name and module; and `poke` and `paths` in an API file stay "declarations, not molds", whose lines below list poke types and path cases, as their `$?` cases did.

Unions without a name don't go away. Hoon `/sur` files nest them inside other molds, as `c-ask=?(%approve %deny)` and `[?(%watch %unwatch) ~]` (16 of the 40 files in `tloncorp/tlon-apps`, `desk/sur`, have a `?(…)` inside another mold), and `$@` and `$^` import as unions. Jibb can import them but no longer write them, so milestone 2's messages need a notation for them. That is a question for @iko, which step 4 records; it isn't yours to settle here.

## Read first

1. `docs/README.md` and `docs/development.md`: the ground rules, how to set up a machine, the checks, and how golden cases work.
2. In `docs/spec/grammar.md`: Lexical rules, Runes, Modules, Molds, Tag resolution, the EBNF and the examples. In `docs/spec/overview.md`: Importing Hoon types, Effects, Agent APIs and worked example 3. In `docs/spec/decisions.md`: the Syntax and Unions rows.
3. In `jibb-dev/lib/jibb.hoon`: design notes 2 and 3; the parser's `+read-def`, `+read-mold`, `+read-union`, `+read-union-wide`, `+read-molds` and `+read-generic`; and the layout pass's `$` and `|` glyphs in `+lexer`. `grep -n '\$?' jibb-dev/lib/jibb.hoon` finds the rest.

Then set up the machine as `docs/development.md` says and run its checks. All 344 golden cases should pass before you change anything.

## Ground rules

- **The doc wins.** The doc changes first (step 1), and the code follows its words. Where this brief and the doc differ, follow the doc and tell @iko.
- **Don't decide more of the language than this.** A question goes to @iko, as a comment on the doc's words or in the project's chat, and into `docs/open-questions.md`.
- **Everything is a golden test**, and every check passes on the fake ship as well as under `urbit eval`.
- **Push straight to `master`**, in commits that each leave every check passing. No pull requests.
- **Keep `docs/` current**, as step 4 says.

## Step 1: change the doc

Make these edits in the doc itself, replacing the quoted words. Check each against the doc before you change it: `docs/spec/` is a snapshot from 2026-10-30, and the doc may have moved since. If you can't edit the doc, send @iko this list and wait until it lands. The quotes are the doc's own words; in `docs/spec/`, a `|` inside a table row is written `\|`.

**Decisions tab.** The tab's rule is that "a later date marks a revision", so both rows become "Decided 2026-10-30".

- Syntax: "wide forms only for `|=`, `$?` and `$-`" becomes "wide forms only for `|=` and `$-`".
- Unions: "`$?` only; tags anywhere" becomes "No `$?`: a `+$` with its cases on the lines below is a union, so every union written in Jibb has a name; one case is just that mold; a mold that isn't a union counts as a union of one case for tags and `|=%tag`; a generic's `|$` comes right after the `+$`'s name; tags anywhere".

**Grammar tab.**

- Lexical rules, Tight forms: "the openers `~[`, `|=(`, `$?(`, `$-(` take no spaces" becomes "the openers `~[`, `|=(`, `$-(` take no spaces".
- Runes: "`+$` **lusbuc**: defines a mold, likewise; molds may be recursive." becomes "`+$` **lusbuc**: defines a mold, likewise: on its line, or as cases on the lines below, one per line, where several cases make a union and one is just that mold. Molds may be recursive."
- Runes: delete the entry "`$?` **bucwut**: a union, one case per line or `$?(%a %b)`; cases must differ as nouns."
- Runes: "`|$` **barbuc**: a generic mold, `|$ [A] mold`." becomes "`|$` **barbuc**: a generic mold, right after a `+$`'s name: `+$ result |$ [V E]`, then the mold on its line or the cases below."
- Runes: "Only `|=`, `$?` and `$-` have wide forms: `|=(sample expr)`, `$?(case case)`, `$-(mold mold)`." becomes "Only `|=` and `$-` have wide forms: `|=(sample expr)` and `$-(mold mold)`."
- Left out on purpose: "`$%`: `$?` covers unions." becomes "`$?`, `$%`: a union is a `+$` with its cases below."
- Molds, Unions: "`$?`; tags take their union from context" becomes "a `+$` with several cases below it. Every union written in Jibb has a name, so one used in a field, a sample, a cast, a gate's mold or an argument gets its own `+$`; only imports bring in unions without one. Tags take their union from context".
- Molds, Generic molds: "`+$ result |$ [V E] $?` with cases below." becomes "`+$ result |$ [V E]` with cases below; `|$` goes only right after a `+$`'s name."
- Tag resolution: after "the variable must become a union with a matching case, or an atom type the term fits.", add "A mold that isn't a union counts as a union of one case, for tags and for `|=%tag`: `[%go "x"]` fits `+$ go [%go url=@t]`, and `|=%typed` works against `$-(@t M)` when `M` is `[%typed text=@t]`."
- The examples: `+$ step $?`, `+$ cart-action $?` and `+$ msg $?` lose their ` $?`.
- The EBNF: `definition` becomes the first block below, and `mold` the second, which drops its `$?` and `$?(` lines and its `|$` line.

  ```
  definition = "+$" name [ generic ] ( mold | cases )
             | "++" name ( expr | body ) ;
  generic    = "|$" "[" typevar { typevar } "]" ;
  cases      = INDENT mold { NEWLINE mold } DEDENT ;  (* one case is that mold; more make a union *)
  ```

  ```
  mold       = aura | "*" | "!!" | "?" | "~" | term | loobean | ref | typevar
             | pathmold
             | "(" ref mold { mold } ")" | "(" ref { mold } mlines
             | "[" field { field } "]" | "[" { field } flines
             | "$-(" mold mold ")" ;
  ```

**Overview tab.**

- Importing Hoon types: in the table, the `$%`, `$?` row's "`$?`" becomes "A union"; "`$?` with an atom case" becomes "A union with an atom case"; and "`$?` if its cases differ as nouns, else an error where used" becomes "A union if its cases differ as nouns, else an error where used". After "Unused molds are skipped, so unsupported constructs elsewhere in a `/sur` file are fine.", add "A union without a name, as a field's `?(%approve %deny)`, imports too, though Jibb can't write one."
- Effects: `+$ cmd |$ [M] $?` and `+$ sub |$ [M] $?` lose their ` $?`.
- Agent APIs: `+$ paths $?` loses its ` $?`.
- Worked example 3: `+$ msg $?` loses its ` $?`.

The Core language and Implementation plan tabs don't mention `$?`. Then export the five tabs as Markdown into `docs/spec/`, as `docs/README.md` says, and check that `git diff docs/spec` holds only these edits. `tools/doc-blocks docs/spec` will then find six blocks without a case and six cases without a block, the six whose unions changed, until step 3 updates them.

## Step 2: change the parser

The layout pass:

- `$?` and `$?(` become left-out runes, an error at the `?`, as `$%` is today. Say, "`$?` is left out: a union is a `+$` with its cases below", which states the rule broken and quotes the Left out list, as the other left-out messages do. `$%` gets the same reason, and `$` alone becomes "`$` begins `$-(`".
- `%'$?'` and `%'$?('` leave `+glyph`. The token printer names no glyph, so it doesn't change.

The parser:

- `+read-def` reads, after a `+$`'s name, an optional `|$ [vars]` (today's `+read-generic`, moved here), then one mold on its line, or INDENT, cases one per line, and DEDENT (the loop of today's `+read-union`, moved here too). One case gives that mold's own node; several give `[%union at cases]`, whose span runs from its first case's start to its last case's end, since it has no token of its own. `|$` wraps either in `%generic`, from the `|$` to the end of its body. Local `+$`s go through `+read-def`, so they get the same.
- `+read-mold` no longer takes `$?`, `$?(` or `|$`. `|$` there is an error at it: say, "expected a mold, found `|$`; `|$` goes right after a `+$`'s name, as in +$ result |$ [V E]".
- `|` no longer begins a mold, except right after a `+$`'s name. Take it out of `mold-mask` and out of the table above it, which becomes "a mold  a-z A-Z @ * ! ? ~ % / ( [ $", and read the place after a `+$`'s name with `mold-mask` and `|`. An error is placed just past the part of a token that could begin the place (`+prefix`), so otherwise `|$` or `|=` in a field, a sample, a cast or an application would fail at its second character. With the change, `+$ x [a=|=]` fails at 1:9, its `|`, not 1:10, while `+$ x |%` still fails at the `%`, where `|$` could have begun.
- `+read-union`, `+read-union-wide` and the union half of `+read-molds` go, and so does `+read-def`'s hint "a `+$` takes one mold; a union is `$?` with its cases below", with the branch it ends. `$?(` leaves the lists of openers in `+stray` and `+index-tokens`.
- Where each new error points follows note 2.0: the first character where the text stops being the start of any valid module. So `+$ x |$ [A]` with nothing below now fails at the next line, as `+$ x` does (`lex-layout-bad-10`), not at the end of its own line.
- Hints for the slips the change makes likely:
  - A mold on the `+$` line, or after `|$ [vars]`, with deeper lines below. Today that is "expected the end of the line, found a deeper line; only a bracket open at the end of a line, or a rune's body, takes deeper lines", at the deeper line. Say instead "a `+$` takes one mold on its line or its cases below, not both".
  - A case line that starts `name=`, as when a record's fields go under a bare `+$` without their `[`. Today that is "expected the end of the line, found `=`", at the `=`. Add "a `+$`'s lines below are its cases; a record's fields go in a [ left open on the `+$` line".
  - Two molds on one case line keep today's "a union takes one case per line".
  - Hoon's `?(%a %b)` in a mold. Today, at the `(`, that is "expected the end of the line, found `(`" after a `+$`'s name; "expected a space between items, found `(`" in a field, an application or a `$-(`; "expected a space after the sample, found `(`" in a gate's sample, as `|= s=?(%a %b)`; and "expected a space after the mold, found `(`" in a cast. Add "a union is a `+$` with its cases below" to each.
- `+check-spans`: a union's outline has no lead token now (`~`, so it starts with its first case) and ends with its last case (`%kid`). `+check-spans-test`'s entry for `+$ x $?(%a %b)` needs another source, such as a `+$` with two cases below.
- The notes: section 1's "$?'s cases end with their last line's code"; design notes 2 and 3, including note 3's list of the parts a rune needs on its own line, where `|$`'s mold no longer belongs, and its Errors example "`$?(]`"; section 4.2's printed cart store, whose `(union 3:16` becomes `(union 4:3`, as a union now starts at its first case; the comments on `+glyph`, `+shape` and `+stop`; and every arm comment that mentions `$?`, `$?(` or `|$` as a mold. Say in note 3 that @iko decided the change on 2026-10-30, quoting the Decisions row, as the notes do for the other decisions.

Error wording is yours within the doc's rules and the conventions in `docs/development.md`; the golden tests fix it once written.

## Step 3: tests

`tools/golden --update --case <name>` rewrites a case's outputs. Read every diff against the case's `about.txt` before committing, as `docs/development.md` says under Golden cases.

**Cases that change.** These 25 cases' sources use `$?`, `$?(` or `$%`, or a `|$` whose meaning changes:

| Cases | What to do |
| --- | --- |
| `doc-grammar-04-step`, `doc-grammar-06-cart-store`, `doc-grammar-07-basket`, `doc-overview-01-cmd-sub`, `doc-overview-04-todo-api`, `doc-overview-10-todo-list` | Copy the doc's new block into `source.jibb` and update `about.txt`'s quotes, so `tools/doc-blocks docs/spec` matches them again |
| `inline-mold-generic`, `inline-scry-case`, `lex-indent-ok-3`, `lex-open-mold-ok-4` | Drop ` $?` from the `+$` line. `inline-scry-case`'s one case is now the mold itself, so its tree loses the `(union …)` |
| `lex-rune-layout-ok-1` | Its `+$ h` has `$?` alone on the line below it, with the cases deeper still. Delete that line and indent `%a` and `%b` two spaces, right below `+$ h`. In `about.txt`, "a `$?` whose cases" become "a `+$` whose cases" |
| `inline-term-numeric` | `+$ code` with its three constants on the lines below |
| `inline-pattern-crash-arm`, `inline-pattern-crash-bad` | Name the sample's union with a top-level `+$`; the error's line moves |
| `inline-wide-forms`, `lex-tight-opener-ok-1` | Drop the `$?(` line, and quote the doc's new sentence on wide forms or openers |
| `lex-open-bracket-ok-5` | Drop the definition of `w`, `$?(%a [`; the other three still test brackets left open together |
| `lex-rune-layout-bad-10` | `+$ x \|$ [A]` above `(list A)` now parses: the line below is the generic's one case. Give it the next free `lex-rune-layout-ok-` name and say why |
| `inline-leftout-buccen` | The new message for `$%` |
| `lex-rune-layout-bad-13`, `lex-tight-opener-bad-3`, `lex-open-mold-bad-6`, `inline-union-wide` | Their subject is gone. Make each a case of `$?` or `$?(` left out, or delete it; `lex-layout-bad-10` already covers a `+$` with no mold |
| `lex-open-bracket-ok-9` | A `(` before a `$?` with its cases below is gone, and the same lines now read as `(map %a %b)`. Delete it, or keep it saying so |
| `inline-wide-union-call` | Its subject, an application without parentheses where a case goes, lives on as `+$ x` above `%a` and `list @t`, which fails at `@t`, "a union takes one case per line" |

Other `about.txt` files quote words the doc changes, such as the `lex-tight-*` cases quoting Tight forms. Update those quotes too. `grep -l '\$?\|\$%\||\$' tests/golden/*/about.txt` finds most of them, and `grep -l 'INDENT mold DEDENT' tests/golden/*/about.txt` finds six more that quote the old `definition` rule: `lex-layout-bad-5`, `lex-layout-bad-6`, `lex-layout-bad-10`, `lex-name-bad-6`, `lex-open-mold-ok-5` and `lex-term-bad-13`.

**New cases**, at least:

- a `+$` with one case below, whose tree is the same as with the case on its line;
- a local `+$` with cases, at the start of a gate's body;
- a generic with cases below (`inline-mold-generic` will be one) and with one mold below (the renamed `lex-rune-layout-bad-10`);
- `$?` with its cases below, `$?(%a %b)`, and `$?(…)` in a field, as `[dir=$?(%l %r)]`, each left out at the `?`; and `$` alone where a mold goes, as `+$ x $`, "`$` begins `$-(`" at 1:7;
- `|$` in a field, in a cast, in an application, and on the line under a bare `+$`, each an error at its `|`; and `|=` where a mold goes, as `+$ x [a=|=]`, at its `|` now;
- a mold on the `+$` line with cases below it, and the same after `|$ [A]`;
- a record's fields under a bare `+$`, without the `[`;
- Hoon's `?(%a %b)` after a `+$`'s name, in a field, in a gate's sample and in a cast.

Each new `about.txt` quotes the doc's new words.

**`my-app` and `tools/ship`.** `my-app/ui/` holds nine of the doc's blocks, byte for byte. Four of them change: `stores/cart.jibb`, `basket.jibb`, `api/todo.jibb` and `todo-list.jibb`. `tools/ship`'s `MERGE_BASE`, the start of worked example 3, which `check-commit` merges, loses its ` $?` too.

**Run** every check in `docs/development.md`: `tools/golden`, `tools/hoon check-spans-test`, `tools/testdata/selftest` and `tools/doc-blocks docs/spec`; then, on the ship, `tools/ship gen-tests` (commit the regenerated `tests/lib/jibb.hoon`), `tools/ship test`, `tools/testdata/ship-selftest`, and `tools/ship check-commit`, since the `my-app` desk changed.

## Step 4: docs

- `docs/spec/`: the fresh export from step 1.
- `docs/status.md`: the change in the history table, the new case counts, and no longer listed as waiting.
- `docs/open-questions.md`:
  - In question 10, "a `$?` of a `qath` and a cord" becomes "a union of a `qath` and a cord".
  - Add question 12 under "Questions milestone 2 raises": how messages and `types.txt` print a union without a name, now that Jibb has no syntax for one. Hoon imports bring them in (a field's `?(%approve %deny)`, `$@` and `$^`), and so does the fold of a `(facts full d1 d2)` request. @iko's decision calls for "a print-only notation".
  - Add to question 3 that the prelude must name every union its elements and attributes take, such as the spaces, roles and tones, and that no module may then use those names, since no name may shadow the prelude's.
- `docs/prompts/milestone-2.md`:
  - the bullets on generic molds and on the import table;
  - the Unions group: every union is a named `+$`, and a mold that isn't a union is one case;
  - the type printer, which has no Jibb syntax for a union without a name (question 12);
  - the number of open questions and their list;
  - in the Errors list, a hint for a `+$` whose cases overlap or don't fit: a record or tuple leaves its `[` open on the `+$` line. `+$ pt` above `@t` and `[@ud @ud]` is now a valid union, where it used to be a parse error;
  - the note at its top that this change comes first.
- `docs/compiler.md`: the tree's lines on `%union` and `%generic`, if they changed.
- `docs/README.md` and `docs/status.md`: this brief, as done.

## When you're done

- The doc says what step 1 lists, `docs/spec/` matches it, and `tools/doc-blocks docs/spec` finds every block's case.
- No `$?`, `$?(` or `$%` is left in the Jibb the library reads or describes (its parser, messages, notes and examples), nor in the golden sources, `my-app` or `tools/ship`, except where a message or note names it as left out. The library's own Hoon keeps its `$?`, `$%` and `|$`.
- Every check in `docs/development.md` passes under eval and on the ship.
- Everything is pushed to `master`.
- Tell @iko in the project's chat, in a few lines: what changed, the case counts, and anything you had to decide or ask.
