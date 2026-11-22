# Open questions

Questions the doc doesn't settle yet, as of 2026-11-10. Language questions belong to the doc's author, @iko: the plan says they go "as comments on the doc, on the words they're about", and a change to the language is "agreed first and recorded in Decisions". When one is settled, record it there, change the code if needed, and move it from here to [Decisions](spec/decisions.md), which holds the settled ones.

## The plan's open questions

From [spec/implementation-plan.md](spec/implementation-plan.md), Open questions:

| Question | Needed by |
| --- | --- |
| Does the Eyre channel CSRF test reproduce on a fake ship? @iko has the write-up; if it does, it goes to Urbit privately. | Milestone 4 |
| Are the proposed loop rules adopted, along with no overlays in v1? | Milestone 6 |
| What do controls look like by default: buttons, toggles and fields, with their focus and disabled states? | Milestone 6 |

## Questions milestone 2 raises

Found while writing [prompts/milestone-2.md](prompts/milestone-2.md), checking it against the doc's examples, and building the checker. Question 32 is now settled, including its field-order detail. The prelude inventory selected in question 3 is now documented in [prelude-inventory.md](prelude-inventory.md), including its checked interfaces and deliberate omissions. The other settled answers are in [Decisions](spec/decisions.md#settled-milestone-2-questions), which keeps their numbers, so existing references stay valid.


## Questions milestone 4 raises

None remain open. The typography scale and whether a build that finishes with errors replaces the last pages are now [Decisions](spec/decisions.md) rows of 2026-11-09, chosen by the implementer at @iko's request; @iko may revise them.

## Review rulings waiting for @iko

The [2026-11-02 review](reviews/2026-11-02-repo-review.md) language and spec rulings are settled; their decisions are in [Decisions](spec/decisions.md). Full-checker diagnostics for a proposal's examples did not settle the separate language question before confirmation.

## Grammar questions never put to the doc's author

In milestone 1 the parser met about thirty places where the doc could be read more than one way. Twelve went to @iko on 2026-10-30 and are rows of the Decisions tab. These were not asked. For each, the parser follows the reading below, and some are marked "(doc question)" in the library's notes. None changes what a valid program means, except where a reading makes something an error.

| # | Question | What the parser does now |
| --- | --- | --- |
| 1 | `knot` may be empty, so the EBNF admits `//`, `/a//b` and a trailing `/`. Which are paths? | A segment has at least one character, as in Hoon. `/` alone is the empty path, in expressions and molds; `%/` alone is the root application path. `//` fails at the second `/`, and a trailing `/` just past it. `inline-mold-paths` has `/` alone as a mold |
| 2 | Is `/` alone a valid path for a `/=` import? | No: `/=` names a module's file, so its path has a segment. `/=  card  /` fails just past the `/` (`inline-import-root-bad`) |
| 3 | The EBNF's `line = [ name "=" ] expr` lets every open bracket's lines take `name=`. What would it mean on a line of an open `(` or `~[`? | An error: `name=` lines belong to tuples and changes. "expected a space between items, found `=`; `name=value` goes in a cell, as [a=1], or a change, as m(a=1)" |
| 4 | Does "items named" make every item of a change need `name=`? | Settled on 2026-11-03 (syntax review S6): yes, `name=value` or `wing=value`, as `m(open.cart=x)`. `m(x)` still fails just past `x`, "a change's items are named, as in m(done=%.y)" (`lex-tight-change-bad-3` to `-7`, where `-5` is a wing with no `=`; `-8` and `-9` test what follows a name there) |
| 5 | `term` includes `%0`, `%&` and `%\|`, which no mark is called. What does `/%` take? | `%` and a name only: `/%  %0` is "expected a mark's term, as `%todo-action`, found `%0`" |
| 6 | What does an indented first line mean? | An error: "the first line is indented: top-level lines start at column 1" (`lex-indent-bad-3`) |
| 7 | With levels open at columns 1 and 5, what does a line at column 3 mean? | An error naming the open columns: "this line's indentation matches no enclosing line: indent it to column 1 or 5". `lex-indent-bad-2`, with levels at 1, 5 and 7, gives "column 1, 5 or 7" |
| 8 | Tabs, carriage returns, other control characters, and non-ASCII text outside strings and comments? | Errors everywhere, strings and comments included, except that UTF-8 is allowed in strings and comments; a tab in a string is written `\09`. `lex-indent-bad-1` and `lex-spacing-bad-2` test tabs |
| 9 | Must a file be valid UTF-8? | Not checked yet: any byte from 128 up passes in strings and comments, and columns assume UTF-8. The proposed reading makes a byte that can't continue a UTF-8 sequence an error. An escape such as `\ff` still writes any byte, as in Hoon |
| 10 | Inside `{…}`, may `::` start a comment, which would swallow the `}` and the `"`? Is a lone `}` in a string text? May a comment follow code with no space, as in `5::note`? | A `:` inside `{…}` is "a comment can't start inside `{…}`". A lone `}` is text, as in Hoon. `5::note` is `5` and a comment |
| 11 | Is a type variable exactly one capital letter, as `typevar = upper` says? | Settled on 2026-11-03 (syntax review S7): no, a capital then lowercase letters and digits, as `Msg`; `AB` is an error |
| 12 | Hoon has more runes of the left-out kinds than the list names: `?~ ?= ?. ?@ ?^`, `:- :+ :^ :_`, `%- %+ %^ %~`, `=+ =? =.`, `;:` and `~&(…)`. Are they all left out? | Yes, with the list's reasons, as "`:-` is left out: indentation covers it; write a cell as [a b]". Naming them in the doc, or saying "Hoon's other runes", would make the messages the doc's words (`inline-leftout-*`) |
| 13 | `@s…` and `@r…` auras are "errors wherever used". Is that the parser's error in Jibb source, or the checker's? | An error before the checker. Where a mold goes, the layout pass's, at the `s` or `r`: "signed and floating-point auras are left out of Jibb". Where an expression goes, the parser's, at the `@`: "expected an expression, found `@`; signed and floating-point auras are left out of Jibb". Imported ones are milestone 2's importer's. The case `inline-leftout-signed-float-auras` still says "expect: unclear" |

Where an error points is not a doc question: the doc asks only for "errors with file, line, column and an excerpt". The library puts each error at the first character where the text stops being the start of any valid module, as Hoon's parser does (its section 2.0).
