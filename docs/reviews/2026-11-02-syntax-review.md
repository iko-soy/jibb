# Syntax review, 2026-11-02

A review of Jibb's syntax at [`0858191`](https://github.com/iko-soy/jibb/commit/0858191ab08738c4da5c6d84f00492e629564e73), asked for in the project chat: how can the syntax be improved for readability, consistency, ambiguity and ergonomics? Every proposal here is a proposal. Under the ground rules, a language change is agreed by @iko and recorded in [decisions.md](../spec/decisions.md) before the code changes, and the spec text is @iko's too. Nothing in the implementation was changed.

How it was done: five reviewers each read the spec, the prelude, the example desk and the parser's design notes through one lens (readability, consistency, ambiguity, ergonomics for Hoon and Elm programmers, and growth). Their 28 proposals, and 11 of my own, were merged into 22. Three verifiers then tried to refute each one, mostly by running the snippet through the real parser and partial checker (`tools/golden --dir <folder> --show` under urbit eval, vere 4.6), and by checking Hoon's behaviour with `urbit eval`. 15 survived, most of them revised; 7 were dropped. [How to rerun a probe](#how-to-rerun-a-probe) is at the end.

This review does not restate the language rulings that [the repository review](2026-11-02-questions.md) raised (questions 16 to 28, now listed in [open-questions.md](../open-questions.md) under "Review rulings waiting for @iko"). Where a proposal extends one of them, it says so. Proposals here are numbered S1 to S15 so they don't collide with those numbers. "Review question N" means a question in that file, and "open question N" means item N of [open-questions.md](../open-questions.md).

## Outcome, 2026-11-03

Montelot decided ten of the proposals on 2026-11-03, and they were built the same day. [decisions.md](../spec/decisions.md) has a row for each, dated 2026-11-03, and [prompts/syntax-review-follow-up.md](../prompts/syntax-review-follow-up.md) lists what is left.

| # | Decision | Built |
| --- | --- | --- |
| S1 | Not as proposed: an explicit `unface` that strips every face from a type, reserved like `proj`, instead of ignoring sample names when gates unify. Step 1 too: a capital binds only the type under a face | `unface` yes; step 1 waits for the checker core of review question 5 |
| S2 | Yes, and a `?-` that begins a body's final line may also take its arms at its own depth, without indenting them | Yes |
| S4, S5, S6, S7 | Yes | Yes, with gaps listed in the follow-up prompt |
| S11, S12, S13, S15 | Yes; S12's prelude rewrite waits for a checker that types nested patterns | Yes |
| S3, S8, S9, S10, S14 | Not decided | No |

The sections below are the review as written on 2026-11-02, before these decisions.

## Summary

- **The syntax is in good shape.** Open brackets without closers, tightness as the one disambiguator, one exhaustive `?-`, named unions, `|=%tag` constructors and named changes all read well, and nearly every slip the reviewers tried gets an error at the right character. The [keep list](#what-to-keep) says what not to change.
- **Three changes would help most, and each needs @iko.** Gates whose parameters are named differently can't fit each other today, which is why the prelude writes 27 gates as `|= args=[…]` followed by a one-arm `?-` ([S1](#s1-let-gates-with-differently-named-parameters-fit-each-other)). A cast or trace can't be followed by its expression at the same depth, as Hoon's tall form does, so every one adds an indentation level ([S2](#s2-let-a-bodys-last---or--take-the-rest-of-the-body-at-the-same-depth)). And no binder may reuse a prelude name, so `text`, `head`, `row`, `max` and soon about 110 more everyday words can't name a local ([S3](#s3-let-local-binders-reuse-prelude-value-names)).
- **Two literal and pattern rules accept code that is almost certainly wrong.** A bare decimal fits any aura, so `[%every 1 |=%tick]` is a timer of 1/2^64 s and `(text 5)` renders a control byte ([S4](#s4-let-a-bare-decimal-fit-only-ud-and-its-ancestors)). A tag written without its `%` in the last arm silently becomes a catch-all ([S5](#s5-reject-a-pattern-name-that-spells-one-of-the-subjects-tags)).
- **Much can be done without changing the language.** Better messages for Hoon and Elm habits ([S9](#s9-name-the-hoon-or-elm-habit-behind-each-likely-slip)), an EBNF that says what the parser accepts ([S10](#s10-make-the-ebnf-say-what-the-parser-accepts)), and a canonical layout for casts ([S13](#s13-put-a-cast-whose-expression-takes-deeper-lines-at-the-end-of-its-line)).

## The proposals at a glance

Links in the "Today" column go to the code at `0858191`.

| # | Proposal | Today | Proposed | Language change? | Touches | Benefit |
| --- | --- | --- | --- | --- | --- | --- |
| [S1](#s1-let-gates-with-differently-named-parameters-fit-each-other) | Gates with differently named parameters fit each other | `~[lth2 lte2]` and `(turn pairs \|=([k v] k))` are type errors; the prelude uses unfaced `args=` ([prelude.jibb:52](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L52-L58)) | Sample names label a gate but are ignored when two gate types unify | Yes, a typing rule | [decisions.md:33](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L33), [open question 8](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L30) | High |
| [S2](#s2-let-a-bodys-last---or--take-the-rest-of-the-body-at-the-same-depth) | Hoon's backstep for a body's last `^-`, `~&` or `\|=` | `^- @ud` above `n` at the same depth is an error ([grammar.md:54](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L54)) | The rest of the body at the same depth is the rune's last child | Yes, layout | [grammar.md:54, :61](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L54-L61) | High |
| [S3](#s3-let-local-binders-reuse-prelude-value-names) | Local binders may reuse prelude value names | `[%typed text]` is "pattern binder shadows a name" ([todo-list.jibb:18](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/todo-list.jibb#L18)) | Samples, pattern binders and local `++` may hide a prelude value | Yes, scope | [decisions.md:11](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L11), [open question 26](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L51) | High |
| [S4](#s4-let-a-bare-decimal-fit-only-ud-and-its-ancestors) | A bare decimal fits only `@ud`, `@u`, `@` and `*` | `^- @dr 30`, `^- @p 0`, `(text 5)` check ([grammar.md:167](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L167)) | Other auras take their own literals: `~s30`, `~zod`, `"5"` | Yes, literals | [grammar.md:21](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L21); extends review question 16 | Medium |
| [S5](#s5-reject-a-pattern-name-that-spells-one-of-the-subjects-tags) | A pattern name that spells a case's tag is an error | `stop` for `%stop` in the last arm checks as a catch-all | "`stop` binds a name, but s can be the case %stop here" | Yes, a checker rule | [grammar.md:184](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L184) | Medium |
| [S6](#s6-let-a-changes-item-name-a-wing) | A change's item may name a wing | `m(open.cart=x)` is "expected a named item" | `m(open.cart=x)`, as Hoon's `m(open.cart x)` | Yes, small | [decisions.md:11](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L11) | Low |
| [S7](#s7-allow-type-variables-longer-than-one-letter) | Type variables longer than one letter | `(program D X M)`; `Msg` is a lexer error ([grammar.md:286](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L286)) | `(program Data Model Msg)`, printed as written | Yes, lexer and printer | [parser reading 11](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L85) | Low |
| [S8](#s8-catch-a-route-segment-that-should-have-been-a-value) | Catch a route segment that should have been a value | `%/blog/slug.p` is the literal text "slug.p" | An error at milestone 4's route check, for two narrow cases | Yes, milestone 4 | [decisions.md:83](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L83) | Low |
| [S9](#s9-name-the-hoon-or-elm-habit-behind-each-likely-slip) | Messages that name the Hoon or Elm habit | `(a == b)` is blamed on the closer `==`; `True` is "found `T`" | "Jibb has no operators: write (eq a b)" and so on | No, messages | [grammar.md:68](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L68-L82) | High |
| [S10](#s10-make-the-ebnf-say-what-the-parser-accepts) | The EBNF says what the parser accepts | No `sample` rule; `change` allows unnamed items; `knot` may be empty ([grammar.md:221](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L221-L289)) | Productions for samples, edits, line kinds, knots and imports | No, spec text | [parser readings 1-5](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L75-L79) | High |
| [S11](#s11-say-which-deeper-lines-are-allowed) | Say which deeper lines are allowed | "a deeper line continues the line above" ([grammar.md:9](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L9)), though a call never continues | List what takes deeper lines; say an opener's line splits on spaces | No, spec text | [decisions.md:42](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L42) | Medium |
| [S12](#s12-say-that-cell-patterns-nest-and-flatten-the-prelude-later) | Say that cell patterns nest; flatten the prelude later | "not lists or pairs" reads as "no nesting"; `hunt` uses four `?-`s ([prelude.jibb:203](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L203-L214)) | Pattern rows such as `[[~ a] [~ b]]`; one `?-` once the checker can | No | [grammar.md:184](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L184) | Medium |
| [S13](#s13-put-a-cast-whose-expression-takes-deeper-lines-at-the-end-of-its-line) | Canonical place for a cast | `^- @ud` alone below `\|=` pushes the body right ([prelude.jibb:376](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L376-L380)) | `++ lent \|= xs=(list A) ^- @ud`, body below | No, layout convention | [decisions.md:97](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L97) | Medium |
| [S14](#s14-pin-down-the-spellings-the-formatter-writes) | Spellings the formatter writes | `(text …)` beside `field …` on open-list lines; `align=align` beside `=msg` | One spelling each; alignment stays the writer's | No, layout convention | [decisions.md:16, :97](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L16) | Low |
| [S15](#s15-name-the-fields-when-the-examples-build-a-model) | Name the fields when the examples build a model | `[[~ %.n] ""]` ([basket.jibb:15](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/basket.jibb#L15)) | `[cart=[items=~ open=%.n] note=""]` | No, examples | none | Low |

Seven proposals were dropped after verification; [the dropped table](#considered-and-dropped) gives each reason.

## Language changes

Each of these needs @iko's agreement before any code changes.

### S1. Let gates with differently named parameters fit each other

**Problem.** A cell sample's names become faces of the gate's type: `|= [a=A b=B]` and `|= [a b]` both give `$-([a=A b=B] …)`. Faces are part of record types, and two different faces don't unify ([decisions.md:33](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L33), [settled open question 8](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L30)). So a gate's parameter names are part of its interface. Two comparators named differently can't share a list, a lambda over Hoon's `[p= q=]` pairs can't be passed to `turn`, and renaming a parameter is a breaking type change. Hoon ignores faces when it nests types, so Hoon programmers don't expect this.

The prelude works around it. 30 of its gates take an unfaced `args=[…]` or `gates=[…]` sample, and 27 then open a one-arm `?-` whose only job is to name the parts ([prelude.jibb:33, 45, 53 and 24 more](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L52-L58)). That costs two lines and two indentation levels per gate, and reads as a branch where nothing branches. Meanwhile the element constructors and the spec's examples face their samples (`|= [=msg m=model]`), so the prelude and the spec teach two styles, and about 110 inventory gates are still to be written.

There are two separate causes, and they need separate fixes:

1. A capital takes a face. `(hunt lth2 `1 `2)` fails because `lth2`'s type `$-([x=A y=A] ?)` meets `hunt`'s slot `$-([A A] ?)`, and the capital `A` takes `x=` from one position and `y=` from the other. [Open question 8](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L30) says only that an unnamed position takes a face; it doesn't say whether a capital does.
2. The decided rule itself. `~[lth2 lte2]` and `(turn pairs |=([k v] k))` fail because two explicit faces meet.

**Evidence** (probes with the prelude loaded):

```
++ lth2 |= [x=A y=A] (gth y x)
++ lte2 |= [a=A b=A] (not (gth a b))
++ pickers ~[lth2 lte2]          ::  list items do not have compatible types
++ use-hunt (hunt lth2 `1 `2)    ::  argument has type $-([x=A y=A] ?)
++ c2 ^- $-([A A] ?) lth2        ::  cast mold and expression type do not unify
++ pairs ^- (list [p=@t q=@ud]) ~[["a" 1]]
++ keys (turn pairs |=([k v] k)) ::  argument has type $-([k=A v=B] A)
```

In Hoon, `^-  $-([x=@ y=@] @)  |=([a=@ b=@] a)` and `(turn ~(tap by m) |=([k=@t v=@ud] k))` both compile. A faced gate already fits a concrete unfaced slot in Jibb, as `^- $-([@ud @ud] @ud) sum` does, so the failures are confined to the two causes above.

**Before**, [prelude.jibb:52-58](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L52-L58):

```
++ turn |= args=[(list A) $-(A B)]
  ?- args
    [xs f]
      ^- (list B)
        ?- xs
          ~ ~
          [item rest] [(f item) (turn rest f)]
```

**After.** Step 1 settles a reading and reopens nothing: a face belongs to its position, and a capital binds only the type under it, so `[A A]` fits `[x=@ y=@]`. Step 2 is the ruling: the names a cell sample binds, faced or bare, are the gate's labels. They bind in the body, print in its type, check a direct call's argument and feed `proj` and route binding, which reads `load`'s own labels. They are ignored when the gate's type unifies with another type and never flow into a capital, and labels that differ where two gate types meet are dropped.

```
++ pickers ~[lth2 lte2]              ::  (list $-([A A] ?))
++ use-hunt (hunt lth2 `1 `2)        ::  (unit @ud), step 1
++ keys (turn pairs |=([k v] k))     ::  (list @t), step 2
(sum [p=1 q=2])                      ::  still an error: a direct call checks labels

::  after step 2, the prelude can name its parameters (with S13's cast placement):
++ turn |= [xs=(list A) f=$-(A B)] ^- (list B)
  ?- xs
    ~            ~
    [item rest]  [(f item) (turn rest f)]
```

**Compatibility.** Only errors become meaning, except that step 1 changes some printed types: `(diff-slot lth2)` prints `$-([A A] ?)` where it printed `$-([x=A y=A] ?)`. Data records keep today's rule: `[hi=10 lo=0]` where `[lo=@ud hi=@ud]` is expected stays an error. A scratch rewrite of the whole prelude with S1, S12 and S13, in syntax that parses today, went from 431 to 347 code lines and from a deepest indent of 16 to 8; S1 accounts for about 54 of the 84 lines.

**Parser.** None. `+read-sample` already tells binders, faces and molds apart ([jibb.hoon:3772](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb.hoon#L3772-L3800)). The checker records faces per position (step 1) and keeps a gate's labels apart from its sample type (step 2).

**Touches.** Step 2 reopens [decisions.md:33](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L33) and settled open question 8 (both 2026-10-30) for gate samples only. It stays consistent with Sample names (:19), `proj` (:41) and Routing (:92).

**Alternatives.** (b) Make a cell sample's names pure binders, out of the type altogether, as `n` in `|= n=@ud` already is. It is simpler, but it breaks `(f (proj wider))` into a faced sample, which checks today, and loses parameter names in printed types such as `button`'s. (c) Keep the rule and the `args=` idiom, and only make the error say that just the faces differ.

### S2. Let a body's last `^-`, `~&` or `|=` take the rest of the body at the same depth

**Problem.** A tall rune's last child sits on its line or deeper ([grammar.md:54](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L54), and `~&` "runs the body below", [:61](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L61)). So every cast or trace whose expression goes below adds an indentation level. Adding one `~& msg` while debugging, with the one debugging rune Jibb keeps, re-indents every line below it, and removing it re-indents them again. Hoon programmers write `|=  a=@`, `^-  @ud` and `~&  x` each on its own line with what follows at the same column. In Jibb that is an error.

**Evidence.** `++ f |= n=@ud` above `^- @ud` and `n` at the same depth gives "expected an expression, or a body on deeper lines, found a line at the same depth"; the `~&` version gives "expected `~&`'s body on deeper lines". Ten of the prelude's casts sit alone on their line ([prelude.jibb:47, 55, 108, 158, 260, 271, 297, 323, 377, 395](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L157-L161)). Eleven more sit on a `?-` arm's line, where the next same-depth line must stay the next arm, so this rule doesn't change them.

**Before**, [todo-list.jibb:16-25](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/todo-list.jibb#L16-L25) with a trace added, and [prelude.jibb:163-167](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L163-L167):

```
++ update |= [=msg m=model]
  ~& msg
    ?- msg
      [%typed t]
        …

++ bond |= fallback=$-(~ A)
  |= maybe=(unit A)
    ?- maybe
      ~ (fallback ~)
      [~ value] value
```

**After:**

```
++ update |= [=msg m=model]
  ~& msg                 ::  insert or delete this one line; nothing else moves
  ?- msg
    [%typed t]
      …

++ bond |= fallback=$-(~ A)
  |= maybe=(unit A)
  ?- maybe
    ~ (fallback ~)
    [~ value] value
```

The rule, for grammar.md's Runes: a body's final line may be a tall `^-`, `~&` or `|=`, or a chain of them such as `^- @ud ~& x`. When that line ends where the innermost rune's last child goes, the rest of the body at the same depth is that child: first its local `++` and `+$`, then its expression. It does not apply on a `?-` arm's line, on a line of an open bracket, after a bracket opened earlier on the line, at the top level, or to a definition's own expression: `++ inner |= y=@ud` above `(inner x)` stays an error.

**Compatibility.** Only errors become meaning: a NEWLINE right after a body's final expression is always an error today. Of the golden corpus, only `lex-rune-layout-bad-3` flips, and its about.txt already calls the form "as Hoon's tall form would put it". The other cases that fail on "a line at the same depth" are at the top level, on arms, on definitions or in brackets, and keep their errors.

**Parser.** Small, with no backtracking. The body loop already knows it has reached the final expression when the next token isn't `++` or `+$`. After a rune's head the next token is an expression start, INDENT (today's body) or NEWLINE (the new case). A "final line of a body, nothing open before" flag passes down the chain of runes on that line.

**Touches.** grammar.md:54 and :61 and the EBNF's `rune`, for a body's final line only. No decisions row requires a deeper body. The formatter's one canonical layout ([decisions.md:97](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L97)) has to make this flat form canonical, or the "nothing else moves" benefit is lost.

**Alternatives.** `^-` and `~&` only, leaving `|=`. Or no language change at all: [S13](#s13-put-a-cast-whose-expression-takes-deeper-lines-at-the-end-of-its-line) puts a cast on its `|=` line, which removes most of the cast drift today but does nothing for `~&`.

### S3. Let local binders reuse prelude value names

**Problem.** No name may shadow one in scope, "imports and the prelude included" ([grammar.md:101](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L101)). The prelude has 75 top-level values, and the inventory decision adds about 110 more, many of them everyday words: `at`, `end`, `cut`, `min`, `max`, `find`, `sort`, `trim`, `test`, `year`, `head`, `tail`, `in`, `by`, `to`. The element gates take `text`, `row`, `field`, `link`, `form` and `table`. So the natural name for a binder is often forbidden: the field `text=@t` is bound as `t` ([todo-list.jibb:18](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/todo-list.jibb#L18)), 13 golden sources name a value `text-value`, and [settled open question 26](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L51) renamed the grammar example's `at` to `sent-at`. Every name the prelude adds later can break code that bound it. The messages don't say which name clashed with what.

**Evidence** (prelude loaded): `[%typed text] text` gives "pattern binder shadows a name"; `|= row=@ud row` gives "sample shadows a name"; a local `++ head 1` gives "local definitions shadow a name"; golden case [module-import-prelude-sample-shadow](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden/module-import-prelude-sample-shadow/source.jibb) rejects `|=(same same)`.

**Before** and **after**:

```
::  today
  ?- msg
    [%typed t]
      ?- (gth (lent (tuba (trip t))) 80)
        %.y  [m(draft=t error=`"Too long") ~]

::  proposed
  ?- msg
    [%typed text]
      ?- (gth (lent (tuba (trip text))) 80)
        %.y  [m(draft=text error=`"Too long") ~]

++ text "hi"                ::  still an error, now naming both sides:
                            ::  "`text` is the prelude gate text; a top-level name can't reuse it"
```

The rule, for grammar.md:101: "No name may shadow one already in scope, with one exception: a sample, a pattern binder or a local `++` may reuse the name of a prelude value, which that scope then can't name. Top-level names, import faces and molds never shadow the prelude, and nothing shadows an import face or a name the module defines. `proj` stays reserved."

**Compatibility.** Only errors become meaning; no valid program binds a prelude name today. Inside a scope that hides a prelude gate, using that gate is an error, and the message should name the hidden gate.

**Parser.** None. The lowering renames such binders, since [core-language.md](../spec/core-language.md) assumes prelude names are never hidden; it already generates `_` names.

**Touches.** The Syntax row ([decisions.md:11](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L11)) for local binders, and settled open question 26, which @iko decided on 2026-10-31 with the inventory decision already made. The new evidence is the size of that inventory. Decide it together with [S5](#s5-reject-a-pattern-name-that-spells-one-of-the-subjects-tags): today `add` written for `%add` happens to be caught as a shadowing error, and under S3 it would need S5 to be caught.

**Not affected by S3.** The prelude's own `toggle |= [on=? …]` ([prelude.jibb:513](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L513)) will collide if `on` is ever defined in the prelude, because a module can't shadow its own names; rename the face then.

**Alternatives.** Let a module's top-level names shadow the prelude too: rejected, since a top-level `++ text` would hide the element gate in the whole module and Jibb has no qualifier to reach it. Or keep the rule and only improve the message.

### S4. Let a bare decimal fit only `@ud` and its ancestors

**Problem.** A bare decimal takes "any aura by context" ([grammar.md:21](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L21), [:167](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L167)). So a number written where a duration, date, ship or cord is expected compiles with a meaning nobody intends: `[%every 1 |=%tick]` fires every 1/2^64 s, `[%wait 30 %done]` waits about nothing, `(text 5)` renders the byte 0x05 and `^- @p 0` is `~zod`. Hoon rejects all of these (`mint-nice -need.@dr -have.@ud`), and "Literals: exactly Hoon's" ([decisions.md:12](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L12)) points the same way. Once review question 16 lands, `%1.000` fits only its own aura family, and `1.000` would be the looser of the two.

**Evidence.** `^- @dr 30`, `^- @p 0`, `^- @t 5` and `^- (element !!) (text 5)` all check today. No source in my-app, jibb-dev or the docs relies on it.

**After:**

```
++ subs |= m=model
  ~[[%every ~s1 |=%tick]]        ::  [%every 1 |=%tick]: "1 is a @ud; a duration is written ~s1"
++ note (text "5")              ::  (text 5): "5 is a @ud; text is written \"5\""
++ bump |= x=A (add x 1)        ::  unchanged: generic over its aura, so (bump ~s1) checks
```

The rule, for grammar.md:21 and :167: a decimal is `@ud`, and also fits `@u`, `@` and `*`, as in Hoon. Where its `++` is generic over its aura it stays generic, as decisions.md:33 already says. Other auras take their own literals: `~s30`, `~2026.1.1`, `~zod`, `"5"`, `0x1`.

**Compatibility.** Some programs that check today become errors. In the corpus only [types-partial-aura](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden/types-partial-aura/source.jibb#L2) flips: `^- @ux 1`, which Hoon also rejects, becomes `0x1`. If @iko would rather keep `^- @ux 1`, allowing `@ux` and `@uv` is a stated deviation from Hoon.

**Parser.** None. In the checker, the decimal constraint against a concrete atom ([jibb.hoon:4909-4914](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb.hoon#L4909-L4914)) accepts only `ud`, `u` and the empty aura.

**Touches.** grammar.md:21, :162 and :167. It extends review question 16 (a) to bare decimals without restating it.

### S5. Reject a pattern name that spells one of the subject's tags

**Problem.** A bare name in a pattern always binds ([grammar.md:184](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L184)), so a tag written without its `%` becomes a catch-all. In any arm but the last, review question 22's dead-arm error catches it. In the last arm it checks, and from then on it silently takes every case later added to the union, which switches off the exhaustiveness check that [decisions.md:30](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L30) relies on. In Hoon a bare `stop` in a `?-` arm is not a binder, so Hoon programmers expect an error.

**Evidence.** grammar.md's own `step` example with `stop` for `%stop` as its last arm checks as `$-(step @t)`. `[typed t]` for `[%typed t]` checks too.

**Before** and **after**, [grammar.md:210-216](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L210-L216) with one `%` dropped:

```
++ describe |= s=step
  ?- s
    [%move %left n]   "left {n}"
    [%move %right n]  "right {n}"
    [t %draft]        t
    [t %sent sent-at] t
    stop              "stop"
::  today: accepted; binds stop and catches everything left
::  proposed: "`stop` binds a name, but s can be the case %stop here; write %stop, or * for a catch-all"
```

The rule, a new sentence in Patterns: "A bare name in a pattern is an error where the subject's type at that position is a union, or a one-case mold, with a case whose constant there is the term that name spells. Positions typed by an aura, `*`, a type variable or a container's element are unaffected, so `[t %draft] t` still binds `t`, and `x` is still a catch-all on a `@tas` subject." The limit to union positions matters: under review questions 16 and 17 every name spells a constant that a `@tas` or `@t` position can hold.

**Compatibility.** Only adds errors, and no golden, prelude, my-app or doc arm is affected. **Parser.** None; the exhaustiveness check already computes the remaining cases' constants. **Touches.** A type-directed rule, which [decisions.md:32](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L32) welcomes if the Grammar tab lists it.

### S6. Let a change's item name a wing

**Problem.** A change's items are single names, so updating a field of a nested record repeats the path, and a Hoon programmer's `m(open.cart x)` gets "expected a named item, found `open.cart`", which is wrong in spirit since the item is named. Hoon's `%=` takes wings: `=/  m  [a=[b=1 c=2] d=3]  m(b.a 5)` gives `[a=[b=5 c=2] d=3]`.

```
::  today, synthetic: nothing in the repository writes a nested change yet
++ toggle-open |= m=model
  m(cart=cart.m(open=(not open.cart.m)))

::  proposed
++ toggle-open |= m=model
  m(open.cart=(not open.cart.m))
```

The rule: a change's item, inline or on a line of an open change, is `name=value` or `wing=value`, read through record fields only. Every value is computed from the original record, and two items that name the same field, or one inside the other, are an error. Tuples, samples and patterns keep plain names.

**Compatibility.** Only errors become meaning: a wing followed tight by `=` parses nowhere today. [lex-tight-change-bad-5](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden/lex-tight-change-bad-5/source.jibb) flips. **Parser.** Still LL(2); the lexer already emits the wing token. **Touches.** The Syntax row ("changes take one or more record items") and parser reading 4. The benefit is low: Elm has no nested update either, and no code here needs one yet. Whatever is decided, the message for `m(a.b 1)` should say "expected `=` right after `a.b`" (part of [S9](#s9-name-the-hoon-or-elm-habit-behind-each-likely-slip)).

### S7. Allow type variables longer than one letter

**Problem.** A type variable is one capital ([grammar.md:286](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L286)), so the architecture's molds read `(program D X M)`, with `X` for the model because `M` is taken, and the prose has to decode them. Hoon names `|$` parameters with words. The one-letter rule is the parser's own [reading 11](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L85), never put to @iko.

```
::  today, prelude.jibb:531-532; ++ id |= x=Msg x is "a type variable is one capital letter"
+$ program |$ [D X M]
  [init=$-(D X) update=$-([M X] [X (list (cmd M))]) view=$-(X (element M)) subs=$-(X (list (sub M)))]

::  proposed
+$ program |$ [Data Model Msg]
  [ init=$-(Data Model)
    update=$-([Msg Model] [Model (list (cmd Msg))])
    view=$-(Model (element Msg))
    subs=$-(Model (list (sub Msg)))
```

`typevar = upper { lower | digit }`, so `Msg` and `T2` are variables and `AB` stays an error. Only a lexer error becomes meaning ([jibb.hoon:1357-1361](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb.hoon#L1357-L1361)), and single capitals stay valid.

Two conditions. The printer must print written names: today `program`'s `D X M` print as `A B C` ([types-prelude-ui/types.txt:22](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden/types-prelude-ui/types.txt#L22)), so without that the names never reach an error message. And the spec should say plainly that capitalized names are variables and lowercase names are molds, the reverse of Elm, where `Msg` is a concrete type. The benefit is low: my-app writes one type variable in all.

### S8. Catch a route segment that should have been a value

**Problem.** A value goes into an application path in parentheses, `%/blog/(slug.p)`. A bare segment is a knot, and knots may hold dots, so `%/blog/slug.p` is the literal text "slug.p" and types as `qath` with no complaint. With `/ui/blog/_slug.jibb` present, milestone 4's route check as designed would accept it, and every card would link to one post. `%/blog/{slug}` is caught, but the message doesn't say how to put a value in a path.

**After**, at milestone 4's route check and for a `@ta` or `@tas` parameter only: `%/blog/slug.p` is an error when it reads as a wing of a local binding ("write (slug.p) for its value, or (~.slug.p) for the text"), and `%/blog/slug` when it is the parameter's own name. Ordinary words stay literal links, since the prelude makes nearly every word a name in scope. The `{` message can improve now: "a segment's value goes in parentheses, as %/blog/(slug)".

**Touches.** Refines [decisions.md:83](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L83) and :92. Low value until milestone 4.

## No language change

These change messages, spec text, examples or the formatter's choices. The spec text is still @iko's, but none of them changes what a program means.

### S9. Name the Hoon or Elm habit behind each likely slip

**Problem.** Jibb's messages for the Hoon forms grammar.md names as left out are good. The next most likely slips get messages that blame another construct, or say nothing useful. Each new message is chosen where the parser or lexer already fails, using tokens it already holds, so LL(2) and the no-backtracking rule are untouched.

| Written | Today | Proposed message |
| --- | --- | --- |
| `(a == b)` | "the closer `==` is left out: indentation covers it" | "Jibb has no operators: write (eq a b)"; likewise `+`, `-`, `<`, `>`, `\|>`, `&&` |
| `?- -.a` | "a name starts with a letter, and Jibb has no operators" | "`-.a` is left out: write (head a), or switch on a itself with arms such as [%add n]"; `+.a` gets `(tail a)` |
| `(~(get by m) "a")` | "expected a space between items, found `(`" | "`~(arm door …)` is left out: call the group's gate, as (get.by m \"a\")" |
| `True` | "expected an expression, found `T`" | "names are lowercase: the loobeans are %.y and %.n, null is ~" |
| `[x :: xs]` | an error two lines later about a shallower line | "the `::` at 2:6 begins a comment: a list's head and tail are [x xs]" |
| `b=2 c=3` on a line of an open `[` | "`name=value` goes in a cell", though it is in one | "a bracket open at the end of its line takes one item per line" |
| `-- note` | "the closer `--` is left out" | "comments start with `::`" |
| `+(n)`, `$:`, `$@`, `$~`, `=\|`, `^+`, `` `@ud`x `` | generic messages | `(succ n)`; a record; a `+$` with cases; no defaults; `^-` with a mold or `_`; `^- @ud x` |
| `\x -> …`, `{ m \| … }`, `f(x)`, `_` in a pattern | generic messages | `\|=(x …)`; `m(note="x")`; `(f x)`; `*` |
| `(lent "abc")`; a shadowing binder | a type mismatch; "pattern binder shadows a name" | "a string is a cord; (trip \"abc\") is its tape"; "binder `text` shadows the prelude's `text`" |

**Compatibility.** Error text only, plus a one-bit layout flag on a token followed by a comment, used only for the `[x :: xs]` message. The golden `tree.txt` files of the affected `lex-*`, `inline-leftout-*` and types cases change.

### S10. Make the EBNF say what the parser accepts

**Problem.** The tree-sitter grammar and the formatter ([decisions.md:96-97](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L96-L97)) will be written from the EBNF, and grammar.md calls itself "the syntax the compiler accepts". In several places the EBNF and the parser disagree, and every mismatch below was reproduced:

- Samples: `rune = "|=" field …` reuses `field`, so a bare name in a sample reads as a mold reference, but it binds ([decisions.md:19](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L19)), at any depth, while inside a faced mold such as `p=[a b]` the same names are molds. A cell sample's `[` closes on its line.
- `change` uses `item`, whose name is optional, though every item and every line of an open change must be named.
- `group` and `list` share `line = [ name "=" ] expr`, but their lines take no `name=`.
- `knot` may be empty, so the EBNF admits `//` and a trailing `/`; `/` alone is the empty path, which `pathlit` doesn't admit.
- `/%` takes any `term`, but only `%name` works; a `/=` path needs a segment.

**After** ([grammar.md:221-289](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L221-L289)):

```
import     = "/-" name | "/%" "%" name | "/=" name "/" knot { "/" knot } ;
change     = wing "(" edit { edit } ")" | wing "(" { edit } elines ;  (* "(" tight after the wing; m() is an error, review question 19 *)
edit       = name "=" operand ;
elines     = INDENT name "=" expr { NEWLINE name "=" expr } DEDENT ;
group      = "(" expr ")" | "(" { operand } xlines ;
list       = "~[" { operand } "]" | "~[" { operand } xlines ;
tuple      = "[" item { item } "]" | "[" { item } ilines ;          (* [] is an error, review question 19 *)
item       = [ name "=" ] operand ;
xlines     = INDENT expr { NEWLINE expr } DEDENT ;                    (* lines take no name= *)
ilines     = INDENT [ name "=" ] expr { NEWLINE [ name "=" ] expr } DEDENT ;
sample     = name                        (* one name, no ".": binds, at any depth *)
           | name "=" mold | "=" name    (* a name inside the mold is a mold *)
           | "[" sample { sample } "]"   (* a cell of samples; closes on its line *)
           | mold ;                      (* any other mold, never a lone name or "[":
                                            binds nothing, as |= ~ or |= post.blog *)
gate       = "|=(" sample operand ")" ;
rune       = "|=" sample ( expr | body ) | … ;
pathlit    = "/" | "/" knot { "/" knot } ;
pathmold   = "/" | "/" segment { "/" segment } ;
knot       = kchar { kchar } ;
kchar      = lower | digit | "-" | "." | "~" | "_" ;
```

The prose changes with it: grammar.md:58 adds that a sample may be a bare name, which binds, or another mold, which binds nothing, as `|= ~`; :66 says `|=(sample operand)`. `[]` and `m()` follow review question 19's answer; the parser still accepts both until that lands. `~[]` stays valid (see [the dropped table](#considered-and-dropped)).

**Touches.** No decided row. It writes [parser readings 1 to 5](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/open-questions.md?plain=1#L75-L79) into the spec, which @iko should confirm. If S6 lands, `edit` becomes `( name | wing ) "=" operand`.

### S11. Say which deeper lines are allowed

**Problem.** [grammar.md:9](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L9) says "a deeper line continues the line above", which suggests a call can continue onto a deeper line. It can't: `f a` above a deeper `b` is "expected the end of the line, found a deeper line". Separately, the same text reads differently on an opener's line and on a deeper line. `~[heading 2 "Todos"` holds three items, while `text "a"` on a deeper line is one call; `[label=trim " x " n=1]` has three items, while `label=trim " x "` on a deeper line means `label=(trim " x ")`. grammar.md:44 explains this for lists only.

**After**, grammar.md:9: "**Indentation is structure**: a block of deeper lines belongs to the line above it: to the last bracket that line leaves open at its end, to the body of the last rune or `++` on it, to `?-`'s arms, to an arm's body, or to a `+$`'s cases. A deeper line that nothing on the line above takes is an error, so a call never continues onto a deeper line. Returning to an earlier indentation closes every block since."

And to Open brackets (grammar.md:11): "On the opener's line, spaces separate items, so `~[text "a"` holds two items. In an expression's open bracket each deeper line is one whole item: `text "a"` there is `(text "a")`, `label=trim " x "` is `label=(trim " x ")`, and under a `(` alone the first deeper line is the head. A mold's open bracket takes exactly one field or mold per deeper line." Also rename [lex-call-open-bad-1](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden/lex-call-open-bad-1/about.txt), which parses, as its about.txt says.

### S12. Say that cell patterns nest, and flatten the prelude later

**Problem.** Eight prelude gates nest a `?-` inside another `?-`'s arm, to look at two values or one list cell ahead: `both`, `clap`, `hunt`, `mate`, `clef`, `join`, `snip` and `rear`. `hunt` needs four `?-`s for one decision. The EBNF already allows nested cell patterns, but the spec shows none, and "not lists or pairs" ([grammar.md:184](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/grammar.md?plain=1#L184)) reads as if cells don't nest. The partial checker doesn't support nested or list-refining patterns yet, which is why the prelude was written this way.

**Now**, in grammar.md's Patterns: "… ships, loobeans and `~`, and cells of patterns, which nest; not `~[…]` lists or `a+b` pairs." Add the rows `[[~ a] [~ b]]` (a pair of present units) and `[x ~]` (a list of one item), and a note: over `[(unit A) (unit A)]`, `[~ b]` means "the first is null", not "a present unit", so keep every position visible, as `[* ~ b]`.

**Later**, once the checker supports nested patterns along with review questions 5 and 22 ([prelude.jibb:203-214](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L203-L214) and [:331-337](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L331-L337)):

```
::  today
++ hunt |= args=[$-([A A] ?) (unit A) (unit A)]
  ?- args
    [choose first second] ^- (unit A)
      ?- first
        ~ second
        [~ a]
          ?- second
            ~ first
            [~ b]
              ?- (choose a b)
                %.y first
                %.n second

::  later
++ hunt |= args=[$-([A A] ?) (unit A) (unit A)] ^- (unit A)
  ?- args
    [* ~ second]  second
    [* first ~]   first
    [choose [~ a] [~ b]]
      ?- (choose a b)
        %.y  `a
        %.n  `b
```

Both versions parse today; the flat one gets "branch is not supported by partial inference", so the prelude must wait or it stops checking.

### S13. Put a cast whose expression takes deeper lines at the end of its line

**Problem.** Eight prelude gates put `^- T` alone on the line below `|=`, and two arms do the same, so each pushes its body one level right. The spec's examples already write casts on the line they belong to (`++ theme  ^- theme`, `++ id |= x=A ^- _ x`), and Hoon programmers read `|=  a=@  ^-  @` as one header. The formatter's "one canonical layout" doesn't say where a cast goes.

```
::  today, prelude.jibb:376-380
++ lent |= xs=(list A)
  ^- @ud
    ?- xs
      ~ 0
      [item rest] (add 1 (lent rest))

::  proposed
++ lent |= xs=(list A) ^- @ud
  ?- xs
    ~            0
    [item rest]  (add 1 (lent rest))

::  unchanged: a cast and its expression that fit on one line stay below the |=
++ row |= [attrs=(list attr) kids=(list (element M))]
  ^- (element M) [%row attrs kids]
```

For grammar.md:60: "A cast whose expression takes the deeper lines goes at the end of the line it belongs to, the `|=`, `++` or arm line; a cast whose expression fits on its own line goes on the line below with it." Both layouts parse to the same meaning today. If [S2](#s2-let-a-bodys-last---or--take-the-rest-of-the-body-at-the-same-depth) lands, the formatter must pick between this and the flat form; S13 can be adopted in the prelude now.

### S14. Pin down the spellings the formatter writes

**Problem.** The spec's code mixes equivalent spellings side by side, which suggests they differ: `(text …)` lines beside unparenthesized `field …` lines in one open list ([basket.jibb:29-32](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/basket.jibb#L29-L32)); `align=align` ([prelude.jibb:443-445](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb/prelude.jibb#L443-L445)) where the spec teaches `=msg`; a cast's body indented 2 deeper in some places and 4 in others. Each pair parses to the same thing.

**After**, for grammar.md's Spacing: "The formatter writes one layout, except for runs of spaces. It drops parentheses around an unfaced whole line of an open list or group, writes `name=name` as `=name` in molds and samples, and indents a body two spaces deeper than the line it continues. Spaces for alignment and import gaps stay as written." Dropping alignment was considered and not proposed: it would reopen [decisions.md:16](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L16) on diff-noise grounds alone. Whether a null-sample `load` is written wide, `|=(~ …)`, or tall is left to @iko; the spec uses both.

### S15. Name the fields when the examples build a model

**Problem.** The examples build models and state as bare tuples that take their faces from the expected type: `[[~ %.n] ""]` ([basket.jibb:15](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/basket.jibb#L15)), `[~ %.n]` ([cart.jibb:8](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/stores/cart.jibb#L8)), `[ts "" ~]` ([todo-list.jibb:14](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/my-app/ui/todo-list.jibb#L14)). A reader of basket.jibb needs stores/cart.jibb open to learn what `[~ %.n]` means.

```
++ init |= ~
  [cart=[items=~ open=%.n] note=""]
++ init ^- state [items=~ open=%.n]
++ init |= ts=(list item.todo)
  [todos=ts draft="" error=~]
```

The faced form checks to the same type, and a misnamed field (`opened=`) becomes a definite error. These are the spec's teaching examples, so the matching doc blocks and `doc-*` golden sources change with them.

## Considered and dropped

| Proposal | Why it was dropped |
| --- | --- |
| Reject a bare sample name that also names a mold in scope (`\|= [n=@ud item]` binds a value named `item`) | It rejects natural code that checks today, such as `\|=(item item)` beside `+$ item` and `\|=(path …)` with the prelude's `path`, and every new prelude mold would break more. The typed spellings `=item` and `it=item` already exist. |
| Name the fields in patterns, `[%acked err=e]` | Opt-in, so it doesn't protect the positional arms that have the hazard; the probed real arms fail at the next use rather than silently; and it reopens Binding patterns ([decisions.md:55](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/docs/spec/decisions.md?plain=1#L55)). Hoon-style narrowing conflicts with Refinement types: none. A checker message naming the rest a binder took is enough if the hazard shows up. |
| Let a cell sample's `[` be left open | Only two prelude lines need it, `++ program` can take `p=(program D X M)` instead, and in an open `(turn xs` the same layout would read two ways. |
| Let a call continue its arguments onto deeper lines | A call followed by deeper lines already means a `~&` body or `?-` arms; mis-indented list items would become calls instead of layout errors; and the decided form `(field "New todo"` with deeper arguments costs only one `(`. S11 fixes the prose that suggested it. |
| Let patterns take `` `x `` and `gap+s` | A second spelling for every unit and pair pattern, and the existing hints already name the one accepted spelling. |
| Puns in tuples and changes, `[=draft]`, `m(=draft)` | The corpus has no expression `name=name` outside two test sources, and Hoon has no expression pun either (`[=a =b]` fails under urbit eval). |
| Reject `~[]`, as `[]` is rejected | `~[]` is the only empty list that types without context, `(list A)`, while a bare `~` asks for a `^-`; 38 golden uses rely on it. Instead, grammar.md's Literals table could say so. |

Five of these seven were my own candidates; the verification refuted them.

## What to keep

The reviewers agreed on these strengths, and the proposals above are built not to disturb them.

- **Open brackets with no closers**, plus the several-open-brackets rule: `column ~[gap+%s2] ~[` with one item per line reads like elm-ui without commas or closers, adding an item is a one-line diff, and every mis-nesting the reviewers tried failed to parse or failed to type.
- **Tightness as the one disambiguator, with an error for every slip**: `m(note=t)` is a change and `m (note t)` a call, `|=%got` a constructor and `|= %got` a gate, and `gap+%s2` binds tighter than a call, so attribute lists need no parentheses.
- **`|=%tag` constructors**: Elm's constructor-as-function with nothing to write, and a bare tag is always a value, so a tag never silently becomes a reply gate.
- **Named changes**, `m(draft="" error=~)`: Elm's record update in Hoon's shape, untouched when the model grows.
- **One exhaustive `?-`**, loobeans included, with no operators and so no precedence or dangling else. When a union gains a case, every `?-` that must handle it is flagged.
- **`+$` with cases below as the only union syntax**, so every union has a name and `+$ msg` reads like an Elm type declaration.
- **Left-out Hoon runes fail at the exact character** with the reason and the Jibb form to write ([inline-leftout-* cases](https://github.com/iko-soy/jibb/tree/0858191ab08738c4da5c6d84f00492e629564e73/tests/golden)).
- **Separate mold and value namespaces**, with one `.` for fields, imports and prelude groups, so `todos.todo` can be a mold and a request, and an imported module's growth never collides with the importer's names.
- **Hoon's literals exactly**, strings only `"…"` and always cords, and `{…}` holding a whole expression, so `"{lent xs} items"` needs no parentheses.
- **Rune bodies must be deeper, and a deeper line nothing takes is an error**, so structure never drifts silently. S2 is a narrow exception where no other parse is possible.
- **The LL(2) parser over layout tokens** never backtracks and puts each error at the first character that can't continue ([jibb.hoon:405-415](https://github.com/iko-soy/jibb/blob/0858191ab08738c4da5c6d84f00492e629564e73/jibb-dev/lib/jibb.hoon#L405-L415)); the layout pass works by column alone, so a tree-sitter scanner needs only an indent stack.

## Questions for @iko

In priority order. Each would be recorded in decisions.md before any code changes.

1. **S1**: (a) Does a capital bind only the type under a face, so `[A A]` fits `[x=@ y=@]`? (b) Are a gate's sample names ignored when two gate types unify, reopening decisions.md:33 and open question 8 for gate samples only?
2. **S2**: May a body's last `^-`, `~&` or `|=` take the rest of the body at the same depth, with the flat form canonical?
3. **S3**: May samples, pattern binders and local `++` reuse prelude value names, reopening settled open question 26? Decide with S5.
4. **S4**: Does a bare decimal fit only `@ud`, `@u`, `@` and `*`, as in Hoon?
5. **S5**: Is a pattern name that spells a case's tag at a union position an error?
6. **S7**: May type variables be words such as `Msg`, with the printer keeping written names?
7. **S6**: May a change's item name a wing?
8. **S10 and S11**: Do the EBNF and the indentation prose take the wording above, confirming the parser's readings 1 to 5?
9. **S12, S13 and S14**: May the spec show nested patterns, and does the canonical layout put casts and spellings as proposed?
10. **S8**, at milestone 4: should the route check catch the two narrow segment slips?

## How to rerun a probe

Every claim above came from a probe like this, run at `0858191`:

1. Make a folder with one subfolder per case, holding `source.jibb` and an `about.txt` of the four lines `source: probe`, `tests: x`, `expect: unclear`, `expect-types: probe`.
2. For prelude-aware type reports, start the source with `/=  lib /ui/lib`, add a `modules.txt` holding `/ui/lib.jibb`, and a `modules/ui/lib.jibb` holding `++ identity |=(x x)`. Without an import, the partial checker doesn't load the prelude.
3. Run `tools/golden --dir <folder> --show`. It prints each case's tokens, its tree or parse error, and the partial type report.

"Not supported by partial inference" in a report is a checker gap, not a verdict on the syntax.
