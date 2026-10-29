::  /lib/jibb.hoon: the Jibb compiler, milestone 1
::
::  The layout pass, the parser, the printers and errors for Jibb, the UI
::  language of the design doc. The doc's Grammar tab is the spec; where
::  this file and the doc disagree, the doc wins. One core with no Ford
::  runes, so `urbit eval` runs it as `=>  <this file>  <expression>` and a
::  ship builds it as /lib/jibb.hoon.
::
::  API
::    +layout        [file=path src=@t]           (each (list token) error)
::    +parse         [file=path src=@t]           (each module error)
::    +parse-tokens  [file=path toks=(list token)] (each module error)
::    +golden        [file=path src=@t]           [tokens=@t tree=@t]
::    +show-tokens   (list token)                 @t
::    +show-module   module                       @t
::    +show-error    [src=@t error]               @t
::  A file is a Clay path whose last segment is the extension, as the
::  golden runners pass /tests/golden/<case>/source/jibb.
::
::  Status: the types, the printers and +golden work. +layout and
::  +parse-tokens are stubs that return an error; they are implemented
::  next, against the design below. Choices the doc leaves open are marked
::  "(doc question)": they follow the most likely reading and are listed,
::  with the doc's words, for the doc's author to settle.
::
::  ===================================================================
::  1. Positions
::  ===================================================================
::
::  Lines and columns count from 1, as in Hoon's hair. Columns count
::  characters, not bytes: every byte that isn't a UTF-8 continuation byte
::  (10xx.xxxx) starts a column, so our columns match an editor's. Jibb
::  allows non-ASCII only in strings and comments, so columns and byte
::  offsets differ only after such text on the same line.
::
::  Every token and every tree node carries at=span: from its first
::  character to just past its last (the end is exclusive; an empty span
::  has beg = end). Nodes keep their ends because the checker's errors in
::  milestone 2 name both conflicting sites with excerpts, and an excerpt
::  that underlines a whole expression, as Elm and Rust do, needs its end;
::  so does editor tooling later. Ends cost the parser nothing: a node ends
::  where its last child or closing token ends. The printed tree shows
::  starts only, and milestone 1's errors use starts only.
::
::  ===================================================================
::  2. The layout pass (+layout)
::  ===================================================================
::
::  +layout turns the text into tokens one line at a time: no token
::  crosses a line break, and only layout tokens join lines.
::
::  2.1 Lines. The text is split at every \0a. A final \0a ends the last
::  line rather than starting an empty one. Lines are numbered from 1.
::
::  2.2 Characters. Anywhere in the text, strings and comments included,
::  these are errors: tab (9), carriage return (13), every other byte
::  below 32 except \0a, and 127. Jibb, like Hoon, spaces with spaces
::  only ("tab: Jibb uses spaces only"). Bytes from 128 up (UTF-8) are
::  allowed only inside strings and comments ("non-ASCII text outside a
::  string or comment"). Outside strings and comments, see 2.6 for which
::  printable characters start a token.
::
::  2.3 Blank and comment-only lines. A line of spaces only, or whose first
::  non-space characters are ::, emits nothing and changes no level. Its
::  characters are still checked (2.2).
::
::  2.4 Levels. The stack holds the columns of the open levels, innermost
::  first, and starts as ~[1]. For every other line let c be the column of
::  its first non-space character; then:
::    - The first such line needs c = 1, else the error "the first line is
::      indented: top-level lines start at column 1".
::    - c > top: push c, emit INDENT.
::    - c = top: emit NEWLINE.
::    - c < top: while c < top, pop and emit DEDENT. Then c must equal the
::      new top, else the error "this line's indentation matches no
::      enclosing line: indent it to column 1 or 5" (the stack's columns,
::      outermost first); emit NEWLINE.
::  Then the line's tokens (2.6). A layout token's span runs from just past
::  the previous token, on an earlier line, to column c of this line:
::  its start is where the previous line's code ended, where "found the
::  end of the line" errors point, and its end is where the new line
::  starts, where "found a deeper line" errors point (see +where).
::
::  2.5 End of file. If any token was emitted: pop every level above 1,
::  emitting DEDENT for each, then emit one NEWLINE, all with empty spans
::  just past the last token. So every import and definition, the last
::  one included, is followed by NEWLINE, as `module = { import NEWLINE }
::  { definition NEWLINE }` needs. A file without tokens (empty, or only
::  blank and comment lines) gives no tokens: an empty module.
::
::  The layout pass knows nothing of brackets: it emits INDENT, NEWLINE and
::  DEDENT by column alone. The parser decides what takes an indented
::  block: a bracket left open at the end of its line, a rune's body, ?-'s
::  arms, $?'s cases, a +$ mold on the next line. A bracket opened and
::  closed on one line is just tokens.
::
::  2.6 Tokens. After the indentation, tokens are read left to right;
::  spaces separate them and are dropped. A token is tight when it
::  follows the previous token on the same line with no space between;
::  the first token of a line never is. Tightness is how the parser tells
::  the tight forms apart: m( from m (, a+b from a + b, `x from ` x,
::  |=%got from |= %got, name=value from name = value. What a token is
::  depends on its first characters:
::
::    ::             a comment: the rest of the line is skipped
::    ( ) [ ] ` = *  glyphs
::    ~[  ~&         glyphs
::    ~              a ~ literal: ~ and the run of [a-z0-9._~-] after it;
::                   a bare ~ is null (2.8)
::    %/             glyph, then a path segment may follow (2.7)
::    %.y  %.n       loobean literals, [%f 0] and [%f 1]
::    %&  %|         term literals, [%f 0] and [%f 1]
::    %a...          term literal: % and a name [a-z][a-z0-9-]*, [%tas name]
::    %0...          term literal: % and digits [0-9]+, [%ud value]
::                   (doc question: digits only, as the EBNF says, so
::                   %1000 is a term and %1.000 an error, unlike Hoon)
::    /- /% /=       import glyphs, when followed by a space or the end
::                   of the line
::    /              glyph, then a path segment may follow (2.7)
::    ++  +$  +      glyphs
::    |=(  |=  |$    glyphs
::    $?(  $?  $-(   glyphs; $- without ( is the error "$- has only the
::                   wide form $-(sample product)"
::    ^-  ?-  !!  ?  glyphs (? alone is the loobean mold)
::    @              aura: @, then [a-z]*, then at most one [A-Z]; the
::                   token holds the text after @. Auras starting @s or @r
::                   are errors: "signed and floating-point auras are left
::                   out of Jibb"
::    A-Z            type variable: one capital; a letter or digit right
::                   after it is the error "a type variable is one capital
::                   letter"
::    a-z            name [a-z][a-z0-9-]*, or a wing: two or more names
::                   joined by dots. A . must be followed by [a-z] ("a . in
::                   a wing is followed by a name"); a capital or _ right
::                   after a name is the error "names are lowercase letters,
::                   digits and -"
::    0-9            number literal: the run of [0-9a-zA-Z.] (2.8)
::    "              string (2.9)
::    }              ends the innermost interpolation (2.9), else an error
::    anything else  an error naming the character: "unexpected `,`"
::
::  Hoon runes the doc leaves out are errors with the doc's reason, found
::  where the token would start: |% |_ |* "modules are records"; $% "$?
::  covers unions"; ?+ ?: "?- is the branch"; .= ?! and !x "eq and not
::  are gates"; =/ "++ defines values"; |- $( "gates recurse by name"; ~|
::  "~& covers debugging"; => =< .* and a:b "names never shadow, and .
::  reads imports too"; !> /+ "code also runs in the browser"; ; "layout
::  is Jibb's elements"; :~ :* %: %= == -- "indentation covers them"; '
::  "there is no '...' form: strings are \"...\"". Wide forms the doc
::  leaves out, ^-(...) and ?-(...), lex fine and fail in the parser: a
::  rune is followed by a space.
::
::  2.7 Paths. Right after a / or %/ glyph, a run of knot characters
::  [a-z0-9._~-] is one knot token, tight. So /posts/~zod is / knot / knot;
::  %/static/img/logo.png is %/ knot / knot / knot; in /todo/[id=@ud] and
::  %/blog/(slug) the [ and ( after / are ordinary glyphs. This is the one
::  place knot tokens appear and the one context, besides strings, the
::  lexer tracks: segments such as logo.png, 1 or ~zod would otherwise lex
::  as a wing, a number or a ship. A / followed by anything else is just a
::  glyph: / alone is the empty path, and the parser rejects empty
::  segments such as //.
::
::  2.8 Literals. The lexer takes the literal's characters first, then
::  reads them with Hoon's own parser, which must consume all of them:
::    0-9 run   (rush run nuck:so) must give [%$ %ud|%ux|%uv val]: 1.000,
::              0x1f, 0v5.fdf99. So 1000 is an error, as in Hoon (groups
::              of three), and 0b1, 0w1, 0i1, 0c1 are errors. Hoon reads
::              0x1F too.
::    ~ run     a bare ~ is null, [%n 0]. Otherwise (rush run nuck:so) must
::              give [%$ %p|%da|%dr|%ta val]: ~zod, ~sampel-palnet,
::              ~2026.10.23..14.30.00, ~h1.m30, ~.my-post. ~~a, ~-a and
::              ~0v... are errors.
::    terms and loobeans as in 2.6.
::  The token is [%lit [form aura val]]: form names the literal rule that
::  matched, aura and val are the dime Hoon's parser gives.
::
::  2.9 Strings. A " starts a string, which ends on the same line. Up to
::  the closing ":
::    \\ \" \{ and \ with two lowercase hex digits are escapes, as in
::      Hoon's tapes (doc question: the doc names only \{ and \"); any
::      other \ is an error at the \
::    { starts an interpolation: the text so far is emitted as str-head
::      (at the opening ") or str-mid (at the } that ended the previous
::      interpolation); then tokens are lexed as usual, strings included,
::      up to the } that ends this interpolation, where the string resumes
::    the closing " emits str when there was no interpolation (at the
::      opening ") or str-tail (at the last })
::  So "Since {day}!" is str-head "Since ", name day, str-tail "!", and the
::  parser reads head expr { mid expr } tail. The lexer keeps a stack of
::  open interpolations, since strings nest inside them. Inside an
::  interpolation, :: is the error "a comment can't start inside {...}"
::  and { is an error; inside a string, :: is text. The end of the line
::  inside a string or an interpolation is an error at its " ("this
::  string has no closing \" on its line") or { ("this { has no }").
::  Token texts hold the decoded text. Spaces after { and before } are
::  allowed, as after any opener.
::
::  2.10 What fails here. Bad characters (2.2), an indented first line and
::  a dedent to no open level (2.4), characters that start no token or a
::  left-out rune (2.6), malformed literals, auras, type variables and
::  wings (2.6, 2.8), and unclosed strings and interpolations, bad escapes
::  and stray { or } (2.9). Everything else is the parser's: brackets that
::  don't match or don't close, a missing or extra space, a deeper line
::  that nothing takes, a token where it can't go.
::
::  ===================================================================
::  3. The parser (+parse-tokens)
::  ===================================================================
::
::  Hand-written recursive descent over the token list: one arm per EBNF
::  rule, each taking the remaining tokens and returning (pare node): the
::  node and the tokens after it, or an error. Steps chain with ;< and
::  +then, so an error stops the parse:
::
::    ;<  [s=shape ts=(list token)]  then  (mold ts)
::    ;<  [e=expr ts=(list token)]   then  (expr-or-body ts)
::    [%& [%cast [beg.at.rune end:(span-of e)] s e] ts]
::
::  Why: after the layout pass the grammar is LL(2). Each choice is made by
::  the next token, at most with the one after it and whether it is tight:
::    name, then = tight            a face (items, lines, fields, samples)
::    name, then + tight            a pair
::    name or wing, then ( tight    a change
::    |=, then a term tight         a constructor; else the tall gate
::    ++ or +$                      a definition; else a body's final expr
::    INDENT                        a body, an open bracket's lines, arms
::                                  or cases; else the expression goes on
::  So the parser never backtracks, its first failure is its furthest, and
::  "expected X, found Y" falls out of each arm without tracking failures
::  across alternatives. Hoon's combinators read tapes of characters and
::  their failures carry a position but no expectation; over tokens they
::  would need a token "tape" and an expectation set bolted on. Recursive
::  descent is shorter, and each error names what its construct expected.
::
::  The EBNF and its nodes (see the types below):
::    module      { import NEWLINE } { definition NEWLINE }, then the end
::                of the tokens; an import after a definition is the error
::                "imports come first"
::    import      /- name -> %sur;  /% term -> %mark;  /= name pathlit ->
::                %jibb. /% takes % and a name only: no mark is called %0,
::                %& or %| (doc question)
::    definition  +$ name mold, or the mold alone on a deeper line ->
::                %mold (both layouts give one node); ++ name expr or body
::                -> %value (a body becomes a %body expr)
::    body        INDENT { definition NEWLINE } expr DEDENT -> %body
::    call        one operand is that operand; more -> %call head args
::    operand     literal -> %lit or %str; pathlit -> %path (not in the
::                EBNF's operand, but in the Literals table: doc
::                question); qath -> %qath; ref -> %wing; change -> %change;
::                pair -> %pair; unit -> %unit; group -> %group; list ->
::                %list; tuple -> %tuple; gate -> %gate-wide; ctor -> %ctor
::    group       ( expr ) -> %group of the expr. The open form ( {operand}
::                open -> %group of the call whose elements are the first
::                line's operands, then one per line; one element alone is
::                just grouped. Lines of an open group or list take no
::                name= (doc question)
::    change      every item and line has name= (the EBNF's "items named")
::    rune        |= -> %gate; ^- -> %cast; ~& -> %trace; ?- -> %branch;
::                !! -> %crash. A bare name as the whole sample binds, in
::                |=(…) and in the tall |= alike; inside a cell sample a
::                bare name is a mold, as field says (doc question). !!
::                is not an operand, so [a !!] needs [a (!!)] (doc
::                question)
::    mold        aura -> %aura; * -> %noun; !! -> %void; ? -> %flag;
::                ~ term loobean -> %const; ref -> %ref; typevar -> %tvar;
::                pathmold -> %path; ( ref mold … ) -> %apply; [ field … ]
::                -> %cell; $? with cases below, and $?( … ) -> %union;
::                $-( mold mold ) -> %fn; |$ [ typevar … ] mold -> %generic
::    field       name=mold -> %face; =name -> %pun; mold -> %bare
::    pattern     term number ship loobean ~ -> %lit (dates, durations and
::                knots are errors); string without {…} -> %str; * -> %any;
::                name -> %bind; [ pattern … ] -> %cell
::
::  What the EBNF leaves out, and how this design fills it in:
::    - Rules it names but doesn't define: string, ship, date, duration,
::      knotlit, decimal, hex, base32, lower, upper and digit. They are
::      Hoon's literals (the Literals table; Decisions: "Hoon's runes as
::      keywords, and its literals"), read as 2.6, 2.8 and 2.9 say.
::    - A string's interpolations: str alone, or str-head expr { str-mid
::      expr } str-tail, where each expr is a full expression.
::    - Spaces, comments and blank lines: the layout pass, and Spacing
::      below.
::    - pathlit as an operand (above).
::    - knot may be empty: only / alone uses that, as the empty path; //
::      and a trailing / are errors (doc question).
::    - Open brackets in molds: mold has no open form, so a mold's [ or (
::      closes on its line, and only $? takes lines below (doc question).
::    - Two brackets left open on one line, as (column ~[: the last one
::      takes the deeper lines, and the other is then unclosed, an error
::      (doc question).
::    - Local definitions: the EBNF takes them in every body (of ++, |=,
::      ^-, ~& and arms), the Runes prose says "inside a gate"; the parser
::      takes them in every body and leaves the rest to the checker (doc
::      question).
::
::  Spacing. Two tokens on one line are separated by spaces, except:
::    - tight, always: name+operand (pair), `operand (unit), |=term
::      (constructor), wing( (change), name= and = value (faces, in items,
::      lines, fields and samples), =name (pun), and every token of a path
::      or application path after its first / or %/, typed segments
::      ([id=@ud]) included
::    - either way: right after an opener ( [ ~[ |=( $?( $-( or {, and
::      right before a closer ) ] or } (the theme example writes `[ space=`)
::  A missing space is an error ("expected a space between items, found
::  `[`"), and so is a space inside a tight form ("a pair has no spaces,
::  as in gap+%s2"). A rune with children, and an import glyph, is
::  followed by a space (or, for $? with its cases below, the end of the
::  line). This is how the parser makes "one space between items; more for
::  alignment" precise (doc question).
::
::  Errors. "expected <what>, found <token>", with an optional "; <hint>",
::  lowercase, no final period. <what> uses the doc's words: "an
::  expression", "a mold", "a pattern", "a name", "`]`", "the end of the
::  line". <token> is +show-found: the token's text in backticks, "a
::  string", "a deeper line" for INDENT, "the end of the line" for NEWLINE
::  and DEDENT. The error sits where +where says: at the token's start, but
::  at the end of the previous line's code for NEWLINE and DEDENT, and at
::  the start of the deeper line for INDENT. Examples:
::    expected `]` to close the `[` at 3:5, found the end of the line
::    expected the end of the line, found a deeper line; only a bracket
::      open at the end of a line, or a rune's body, takes deeper lines
::    expected an expression, found `^-`; inside a call, a rune goes in
::      parentheses
::    a change's items are named, as in m(done=%.y)
::  Messages of milestone 1 are golden-tested, so their wording is fixed
::  by the tests once written.
::
::  ===================================================================
::  4. Printed formats
::  ===================================================================
::
::  Each printer returns a cord: lines joined by \0a, no final newline.
::
::  4.1 Tokens (+show-tokens): one token per line, "<line>:<col>", then
::  "tight " if the token is tight, then the kind and the text. Kinds:
::  glyph (with its text), INDENT, DEDENT, NEWLINE, name, wing, lit (the
::  literal as Hoon prints its dime: 1.000, 0x1f, ~zod, ~h1.m30, ~.knot;
::  terms as %add, %0, %& and %|; loobeans %.y and %.n; null ~), str,
::  str-head, str-mid and str-tail (quoted, with \\ \" \{ and \XX
::  escapes), knot, aura (@ud), tvar. Layout tokens print their span's
::  start: the end of the previous line's code. For `++ main view`:
::
::    1:1 glyph ++
::    1:4 name main
::    1:9 name view
::    1:13 NEWLINE
::
::  4.2 Trees (+show-module): S-expressions, (kind line:col fields kids),
::  with the node's start. A leaf is a node whose kids, if any, are atoms
::  (a string's quoted text, an application path's knots). A node whose
::  kids are all leaves prints on one line; otherwise each kid goes on its
::  own line, indented two more spaces, and the closing parens end the
::  last kid's line. (module …) always breaks. Bare fields and samples
::  print as their mold, unnamed items as their expr; strings print text
::  pieces quoted, between their interpolated exprs; application paths
::  print knots bare between their (expr) segments. The cart store from
::  the Grammar tab, its code block's first line being line 1:
::
::    (module
::      (mold 2:1 state
::        (cell 2:10
::          (face 2:11 items
::            (apply 2:17 list (aura 2:23 @t)))
::          (face 2:27 open (flag 2:32))))
::      (mold 3:1 cart-action
::        (union 3:16
::          (cell 4:3
::            (const 4:4 %add)
::            (face 4:9 item (aura 4:14 @t)))
::          (const 5:3 %toggle)))
::      (mold 6:1 poke (ref 6:9 cart-action))
::      (value 8:1 main
::        (group 8:9
::          (call 8:10 (wing 8:10 store) (wing 8:16 init) (wing 8:21 update))))
::      (value 9:1 init
::        (cast 9:9
::          (ref 9:12 state)
::          (tuple 9:18 (lit 9:19 ~) (lit 9:21 %.n))))
::      (value 10:1 update
::        (gate 10:11
::          (cell 10:14
::            (face 10:15 a (ref 10:17 cart-action))
::            (face 10:29 s (ref 10:31 state)))
::          (body 11:3
::            (branch 11:3
::              (wing 11:6 a)
::              (arm 12:5
::                (cell 12:5 (lit 12:6 %add) (bind 12:11 item))
::                (change 12:18 s
::                  (edit 12:20 items
::                    (tuple 12:26 (wing 12:27 item) (wing 12:32 items.s)))))
::              (arm 13:5
::                (lit 13:5 %toggle)
::                (change 13:18 s
::                  (edit 13:20 open
::                    (group 13:25
::                      (call 13:26 (wing 13:26 not) (wing 13:30 open.s)))))))))))
::
::  4.3 Errors (+show-error): "<file>:<line>:<col>: <message>", then the
::  source line, then a caret under the column (col - 1 spaces, then ^).
::  The file prints as a Clay path with its last segment as the extension:
::  /tests/golden/x/source/jibb is /tests/golden/x/source.jibb. A line
::  past the end of the text prints as an empty line.
::
::    /ui/basket.jibb:22:5: msg has no case %submitt
::        %submitt       [m(note="") ~]
::        ^
::
|%
+|  %positions
::
::  +loc: a position, line and column from 1 (columns count characters)
::
+$  loc  [line=@ud col=@ud]
::
::  +span: from the first character to just past the last
::
+$  span  [beg=loc end=loc]
::
::  +error: file, line, column, message
::
::    The file is a Clay path whose last segment is the extension, as
::    /ui/basket/jibb. Milestone 2 may add an end column, to underline.
::
+$  error  [file=path line=@ud col=@ud msg=tape]
::
+|  %tokens
::
::  +token: what the layout pass emits
::
::    tight is %.y when the token follows the previous one on the same
::    line with no space between them; layout tokens are never tight.
::
+$  token  [at=span tight=? lex=lexeme]
::
+$  lexeme
  $@  glyph
  $%  [%name p=term]                                    ::  todo-action
      [%wing p=(list term)]                             ::  title.p: 2+ names
      [%lit p=lit]                                      ::  any literal but "…"
      [%str p=@t]                                       ::  "…" without {…}
      [%str-head p=@t]                                  ::  "…{  text before
      [%str-mid p=@t]                                   ::  }…{  text between
      [%str-tail p=@t]                                  ::  }…"  text after
      [%knot p=@ta]                                     ::  path segment
      [%aura p=@ta]                                     ::  @ud as 'ud', @ as ''
      [%tvar p=@t]                                      ::  M
  ==
::
::  +glyph: a token that is its text, and the layout tokens
::
+$  glyph
  $?  %indent  %dedent  %newline                        ::  layout
      %'('  %')'  %'['  %']'                            ::  brackets
      %'~['  %'|=('  %'$?('  %'$-('                     ::  openers
      %'%/'  %'/'                                       ::  paths
      %'+'  %'`'  %'='                                  ::  pair, unit, face
      %'*'  %'?'                                        ::  noun, loobean mold
      %'++'  %'+$'  %'|='  %'|$'  %'$?'                 ::  runes
      %'^-'  %'~&'  %'?-'  %'!!'                        ::  runes
      %'/-'  %'/%'  %'/='                               ::  imports
  ==
::
::  +lit: a literal other than a string, as Hoon's parsers read it
::
::    form is the literal rule that matched; aura and val are the dime
::    nuck:so gives, or for terms and loobeans:
::      %number    1.000 0x1f 0v5.fdf99   %ud %ux %uv
::      %ship      ~zod                    %p
::      %date      ~2026.10.23             %da
::      %duration  ~h1.m30                 %dr
::      %knot      ~.my-post               %ta
::      %term      %add  %0  %&  %|        %tas 'add', %ud 0, %f 0, %f 1
::      %loobean   %.y  %.n                %f 0, %f 1
::      %null      ~                       %n 0
::
+$  lit  [form=lit-form aura=@ta val=@]
+$  lit-form
  ?(%number %ship %date %duration %knot %term %loobean %null)
::
+|  %tree
::
::  The syntax tree. Every node is [%tag at=span …] with at least one
::  field after at, so +span-of finds the span of any node at +<.
::  Types avoid the standard library's names (mold, wing, gate, sym…),
::  hence +shape for a mold as written. Every type in a recursive cycle
::  has a $~ default that is a leaf: Hoon can't build the default of
::  mutually recursive molds otherwise (the compile overflows).
::
::  +module: a file: imports, then definitions
::
+$  module  [imports=(list import) defs=(list def)]
::
+$  import
  $%  [%sur at=span name=term]                  ::  /-  todo
      [%mark at=span mark=term]                 ::  /%  %todo-action
      [%jibb at=span face=term =path]           ::  /=  card  /ui/components/card
  ==
::
+$  def
  $~  [%mold *span %$ *shape]
  $%  [%mold at=span name=term =shape]          ::  +$  name  mold
      [%value at=span name=term val=expr]       ::  ++  name  expr-or-body
  ==
::
::  +expr: an expression; operands are the cases from %lit to %ctor
::
+$  expr
  $~  [%crash *span ~]
  $%  [%lit at=span =lit]                       ::  1.000 ~zod %add %.y ~
      [%str at=span pieces=(list piece)]        ::  "Since {day}"
      [%path at=span segs=(list @ta)]           ::  /posts/~zod
      [%qath at=span segs=(list qseg)]          ::  %/blog/(slug)
      [%wing at=span names=(list term)]         ::  title.p
      [%change at=span target=(list term) edits=(list edit)]  ::  m(note=t)
      [%pair at=span tag=term val=expr]         ::  gap+%s2
      [%unit at=span val=expr]                  ::  `x
      [%group at=span inner=expr]               ::  (f a): open or closed
      [%list at=span items=(list expr)]         ::  ~[a b]: open or closed
      [%tuple at=span items=(list item)]        ::  [a b]: open or closed
      [%gate-wide at=span =sample body=expr]    ::  |=(p title.p)
      [%ctor at=span tag=lit]                   ::  |=%got
      [%call at=span head=expr args=(list expr)]  ::  f a b; args not empty
      [%gate at=span =sample body=expr]         ::  |=  m=model  …
      [%cast at=span =shape val=expr]           ::  ^-  state  …
      [%trace at=span val=expr then=expr]       ::  ~&  x  then a %body
      [%branch at=span subject=expr arms=(list arm)]  ::  ?-  msg  …
      [%crash at=span ~]                        ::  !!
      [%body at=span defs=(list def) final=expr]  ::  an indented body
  ==
::
::  +piece: a string's text or {…}; no empty or adjacent text pieces
::
+$  piece  $~([%text ''] $%([%text p=@t] [%expr p=expr]))
::
::  +qseg: an application path's segment, a knot or (expr)
::
+$  qseg  $~([%knot ~.] $%([%knot p=@ta] [%expr p=expr]))
::
::  +item: a tuple's item or line, [name=]value
::
+$  item  $~([*span ~ *expr] [at=span face=(unit term) val=expr])
::
::  +edit: a change's item or line, name=value
::
+$  edit  $~([*span %$ *expr] [at=span name=term val=expr])
::
::  +arm: a ?- arm, a pattern and an expression or body
::
+$  arm  $~([*span *pattern *expr] [at=span pat=pattern val=expr])
::
::  +sample: a gate's sample; a bare name binds (%bind)
::
+$  sample
  $~  [%bind *span %$]
  $%  [%bind at=span name=term]                 ::  p
      [%face at=span name=term =shape]          ::  m=model
      [%pun at=span name=term]                  ::  =msg, for msg=msg
      [%bare at=span =shape]                    ::  ~  [a=@ b=@]
  ==
::
::  +field: a field of a cell mold; nests in +sample
::
+$  field
  $~  [%pun *span %$]
  $%  [%face at=span name=term =shape]          ::  text=@t
      [%pun at=span name=term]                  ::  =msg
      [%bare at=span =shape]                    ::  @t  %add
  ==
::
+$  pattern
  $~  [%any *span ~]
  $%  [%lit at=span =lit]                       ::  %add 1.000 ~zod %.y ~
      [%str at=span text=@t]                    ::  "milk"
      [%any at=span ~]                          ::  *
      [%bind at=span name=term]                 ::  x
      [%cell at=span items=(list pattern)]      ::  [%add t]
  ==
::
::  +shape: a mold as written
::
+$  shape
  $~  [%noun *span ~]
  $%  [%aura at=span aura=@ta]                  ::  @ @ud @uvJ
      [%noun at=span ~]                         ::  *
      [%void at=span ~]                         ::  !!
      [%flag at=span ~]                         ::  ?
      [%const at=span =lit]                     ::  ~ %add %.y
      [%ref at=span names=(list term)]          ::  state item.todo
      [%tvar at=span name=@t]                   ::  M
      [%path at=span segs=(list pseg)]          ::  / /todos /todo/[id=@ud]
      [%apply at=span ref=(list term) args=(list shape)]  ::  (list @t)
      [%cell at=span fields=(list field)]       ::  [text=@t done=?]
      [%union at=span cases=(list shape)]       ::  $? below, or $?(%a %b)
      [%fn at=span sample=shape product=shape]  ::  $-(@t M)
      [%generic at=span vars=(list @t) body=shape]  ::  |$ [M] $? …
  ==
::
::  +pseg: a path mold's segment, a knot or [name=aura]
::
+$  pseg  $%([%knot p=@ta] [%typed at=span name=term aura=@ta])
::
+|  %api
::
::  +layout: source to tokens (design: section 2)
::
++  layout
  |=  [file=path src=@t]
  ^-  (each (list token) error)
  [%| file 1 1 "layout pass not implemented"]
::
::  +parse: source to tree
::
++  parse
  |=  [file=path src=@t]
  ^-  (each module error)
  =/  lay  (layout file src)
  ?:  ?=(%| -.lay)  lay
  (parse-tokens file p.lay)
::
::  +parse-tokens: tokens to tree (design: section 3)
::
++  parse-tokens
  |=  [file=path toks=(list token)]
  ^-  (each module error)
  =/  at=loc  ?~(toks [1 1] (where i.toks))
  [%| file line.at col.at "parser not implemented"]
::
::  +golden: both stages printed, or the rendered error
::
::    tokens: the layout pass's output, or its error
::    tree: the parser's output, or the layout pass's or parser's error
::
++  golden
  |=  [file=path src=@t]
  ^-  [tokens=@t tree=@t]
  =/  lay  (layout file src)
  ?:  ?=(%| -.lay)
    =/  msg=@t  (show-error src p.lay)
    [msg msg]
  :-  (show-tokens p.lay)
  =/  par  (parse-tokens file p.lay)
  ?:  ?=(%| -.par)
    (show-error src p.par)
  (show-module p.par)
::
+|  %printers
::
::  +show-tokens: one token per line (format: section 4.1)
::
++  show-tokens
  |=  toks=(list token)
  ^-  @t
  (of-wain:format (turn toks |=(t=token (crip (show-token t)))))
::
++  show-token
  |=  t=token
  ^-  tape
  ;:  weld
    (show-loc beg.at.t)
    " "
    ?:(tight.t "tight " "")
    (show-lexeme lex.t)
  ==
::
++  show-lexeme
  |=  x=lexeme
  ^-  tape
  ?@  x
    ?+  x  "glyph {(trip x)}"
      %indent   "INDENT"
      %dedent   "DEDENT"
      %newline  "NEWLINE"
    ==
  ?-  -.x
    %name      "name {(trip p.x)}"
    %wing      "wing {(show-names p.x)}"
    %lit       "lit {(show-lit p.x)}"
    %str       "str {(show-quoted p.x)}"
    %str-head  "str-head {(show-quoted p.x)}"
    %str-mid   "str-mid {(show-quoted p.x)}"
    %str-tail  "str-tail {(show-quoted p.x)}"
    %knot      "knot {(trip p.x)}"
    %aura      "aura @{(trip p.x)}"
    %tvar      "tvar {(trip p.x)}"
  ==
::
::  +show-module: the tree as S-expressions (format: section 4.2)
::
++  show-module
  |=  mod=module
  ^-  @t
  =/  kids=(list sexp)
    (weld (turn imports.mod sexp-import) (turn defs.mod sexp-def))
  =/  lines=wall
    ?~  kids  ~["(module)"]
    :-  "(module"
    (close (zing (turn kids |=(k=sexp (render 2 k)))))
  (of-wain:format (turn lines crip))
::
::  +show-error: "<file>:<line>:<col>: <message>", the line, a caret
::
++  show-error
  |=  [src=@t err=error]
  ^-  @t
  =/  lines=wain  (to-wain:format src)
  =/  text=@t
    ?:  |(=(0 line.err) (gth line.err (lent lines)))  ''
    (snag (dec line.err) lines)
  %-  crip
  ;:  weld
    (show-file file.err)
    ":"
    (a-co:co line.err)
    ":"
    (a-co:co col.err)
    ": "
    msg.err
    "\0a"
    (trip text)
    "\0a"
    (reap (dec (max 1 col.err)) ' ')
    "^"
  ==
::
::  +show-found: a token as error messages name it
::
++  show-found
  |=  t=token
  ^-  tape
  =/  x=lexeme  lex.t
  ?@  x
    ?+  x  "`{(trip x)}`"
      %indent   "a deeper line"
      %dedent   "the end of the line"
      %newline  "the end of the line"
    ==
  ?-  -.x
    %name      "`{(trip p.x)}`"
    %wing      "`{(show-names p.x)}`"
    %lit       "`{(show-lit p.x)}`"
    %str       "a string"
    %str-head  "a string"
    %str-mid   "`}`"
    %str-tail  "`}`"
    %knot      "`{(trip p.x)}`"
    %aura      "`@{(trip p.x)}`"
    %tvar      "`{(trip p.x)}`"
  ==
::
::  +where: where an error at a token points
::
::    At the token's start; for NEWLINE and DEDENT that is the end of the
::    previous line's code. For INDENT, the start of the deeper line.
::
++  where
  |=  t=token
  ^-  loc
  ?:  ?=(%indent lex.t)  end.at.t
  beg.at.t
::
++  show-loc
  |=  l=loc
  ^-  tape
  "{(a-co:co line.l)}:{(a-co:co col.l)}"
::
::  +show-file: a Clay path as a file name, /a/b/jibb as /a/b.jibb
::
++  show-file
  |=  p=path
  ^-  tape
  ?~  p  "/"
  ?~  t.p  (spud p)
  "{(spud (snip `path`p))}.{(trip (rear p))}"
::
++  show-names
  |=  ns=(list term)
  ^-  tape
  ?~  ns  ""
  ?~  t.ns  (trip i.ns)
  "{(trip i.ns)}.{$(ns t.ns)}"
::
::  +show-lit: a literal as Hoon prints it
::
++  show-lit
  |=  l=lit
  ^-  tape
  ?-  form.l
    %number    (scow aura.l val.l)
    %ship      (scow %p val.l)
    %date      (scow %da val.l)
    %duration  (scow %dr val.l)
    %knot      (scow %ta val.l)
    %loobean   ?:(=(0 val.l) "%.y" "%.n")
    %null      "~"
    %term
      ?+  aura.l  (weld "%" (trip val.l))
        %ud  (weld "%" (a-co:co val.l))
        %f   ?:(=(0 val.l) "%&" "%|")
      ==
  ==
::
::  +show-quoted: text as a Jibb string, with \\ \" \{ and \XX escapes
::
++  show-quoted
  |=  t=@t
  ^-  tape
  =/  cs=tape  (trip t)
  %+  weld  "\""
  |-  ^-  tape
  ?~  cs  "\""
  =/  c=@  i.cs
  ?:  =('"' c)   (weld "\\\"" $(cs t.cs))
  ?:  =('\\' c)  (weld "\\\\" $(cs t.cs))
  ?:  =('{' c)   (weld "\\\{" $(cs t.cs))
  ?:  |((lth c 32) =(127 c))
    (weld ~['\\' (hex-digit (div c 16)) (hex-digit (mod c 16))] $(cs t.cs))
  [i.cs $(cs t.cs)]
::
++  hex-digit
  |=  n=@
  ^-  @tD
  ?:((lth n 10) (add '0' n) (add 'a' (sub n 10)))
::
::  +show-psegs: a path mold, / or /todo/[id=@ud]
::
++  show-psegs
  |=  segs=(list pseg)
  ^-  tape
  ?~  segs  "/"
  %-  zing
  %+  turn  segs
  |=  s=pseg
  ^-  tape
  ?-  -.s
    %knot   (weld "/" (trip p.s))
    %typed  "/[{(trip name.s)}=@{(trip aura.s)}]"
  ==
::
++  show-tvars
  |=  vs=(list @t)
  ^-  tape
  ?~  vs  ""
  ?~  t.vs  (trip i.vs)
  "{(trip i.vs)} {$(vs t.vs)}"
::
::  +sexp: a printed node: an atom, or (head kid …)
::
+$  sexp
  $~  [%atom ~]
  $%  [%atom p=tape]
      [%node head=tape kids=(list sexp)]
  ==
::
::  +render: a node as lines, at an indent
::
::    On one line when every kid is a leaf: an atom, or a node whose kids
::    are all atoms (a string's text, a path's knots). Else each kid on
::    its own lines, two spaces deeper.
::
++  render
  |=  [ind=@ud s=sexp]
  ^-  wall
  =/  pad=tape  (reap ind ' ')
  ?:  ?=(%atom -.s)  ~[(weld pad p.s)]
  ?:  (levy kids.s is-leaf)  ~[(weld pad (flat s))]
  :-  "{pad}({head.s}"
  (close (zing (turn kids.s |=(k=sexp (render (add ind 2) k)))))
::
++  is-leaf
  |=  s=sexp
  ^-  ?
  ?:  ?=(%atom -.s)  &
  (levy kids.s |=(k=sexp ?=(%atom -.k)))
::
++  flat
  |=  s=sexp
  ^-  tape
  ?:  ?=(%atom -.s)  p.s
  "({head.s}{(zing (turn kids.s |=(k=sexp (weld " " (flat k)))))})"
::
::  +close: end the last line with )
::
++  close
  |=  w=wall
  ^-  wall
  ?~  w  ~
  ?~  t.w  ~[(weld i.w ")")]
  [i.w $(w t.w)]
::
::  +nod: a node's sexp: "kind line:col extra" and its kids
::
++  nod
  |=  [kind=tape at=span extra=tape kids=(list sexp)]
  ^-  sexp
  :+  %node
    ?~  extra  "{kind} {(show-loc beg.at)}"
    "{kind} {(show-loc beg.at)} {extra}"
  kids
::
++  sexp-import
  |=  i=import
  ^-  sexp
  ?-  -.i
    %sur   (nod "sur" at.i (trip name.i) ~)
    %mark  (nod "mark" at.i "%{(trip mark.i)}" ~)
    %jibb  (nod "jibb" at.i "{(trip face.i)} {(spud path.i)}" ~)
  ==
::
++  sexp-def
  |=  d=def
  ^-  sexp
  ?-  -.d
    %mold   (nod "mold" at.d (trip name.d) ~[(sexp-shape shape.d)])
    %value  (nod "value" at.d (trip name.d) ~[(sexp-expr val.d)])
  ==
::
++  sexp-expr
  |=  e=expr
  ^-  sexp
  ?-  -.e
    %lit        (nod "lit" at.e (show-lit lit.e) ~)
    %str        (nod "str" at.e "" (sexp-pieces pieces.e))
    %path       (nod "path" at.e (spud segs.e) ~)
    %qath       (nod "qath" at.e "" (turn segs.e sexp-qseg))
    %wing       (nod "wing" at.e (show-names names.e) ~)
    %change     (nod "change" at.e (show-names target.e) (turn edits.e sexp-edit))
    %pair       (nod "pair" at.e (trip tag.e) ~[(sexp-expr val.e)])
    %unit       (nod "unit" at.e "" ~[(sexp-expr val.e)])
    %group      (nod "group" at.e "" ~[(sexp-expr inner.e)])
    %list       (nod "list" at.e "" (turn items.e sexp-expr))
    %tuple      (nod "tuple" at.e "" (turn items.e sexp-item))
    %gate-wide  (nod "gate-wide" at.e "" ~[(sexp-sample sample.e) (sexp-expr body.e)])
    %ctor       (nod "ctor" at.e (show-lit tag.e) ~)
    %call       (nod "call" at.e "" [(sexp-expr head.e) (turn args.e sexp-expr)])
    %gate       (nod "gate" at.e "" ~[(sexp-sample sample.e) (sexp-expr body.e)])
    %cast       (nod "cast" at.e "" ~[(sexp-shape shape.e) (sexp-expr val.e)])
    %trace      (nod "trace" at.e "" ~[(sexp-expr val.e) (sexp-expr then.e)])
    %branch     (nod "branch" at.e "" [(sexp-expr subject.e) (turn arms.e sexp-arm)])
    %crash      (nod "crash" at.e "" ~)
    %body       (nod "body" at.e "" (snoc (turn defs.e sexp-def) (sexp-expr final.e)))
  ==
::
++  sexp-pieces
  |=  ps=(list piece)
  ^-  (list sexp)
  ?~  ps  ~[[%atom "\"\""]]
  %+  turn  ps
  |=  p=piece
  ^-  sexp
  ?-  -.p
    %text  [%atom (show-quoted p.p)]
    %expr  (sexp-expr p.p)
  ==
::
++  sexp-qseg
  |=  s=qseg
  ^-  sexp
  ?-  -.s
    %knot  [%atom (trip p.s)]
    %expr  (sexp-expr p.s)
  ==
::
++  sexp-item
  |=  i=item
  ^-  sexp
  ?~  face.i  (sexp-expr val.i)
  (nod "face" at.i (trip u.face.i) ~[(sexp-expr val.i)])
::
++  sexp-edit
  |=  e=edit
  ^-  sexp
  (nod "edit" at.e (trip name.e) ~[(sexp-expr val.e)])
::
++  sexp-arm
  |=  a=arm
  ^-  sexp
  (nod "arm" at.a "" ~[(sexp-pattern pat.a) (sexp-expr val.a)])
::
++  sexp-sample
  |=  s=sample
  ^-  sexp
  ?-  -.s
    %bind  (nod "bind" at.s (trip name.s) ~)
    %face  (nod "face" at.s (trip name.s) ~[(sexp-shape shape.s)])
    %pun   (nod "pun" at.s (trip name.s) ~)
    %bare  (sexp-shape shape.s)
  ==
::
++  sexp-field
  |=  f=field
  ^-  sexp
  (sexp-sample f)
::
++  sexp-pattern
  |=  p=pattern
  ^-  sexp
  ?-  -.p
    %lit   (nod "lit" at.p (show-lit lit.p) ~)
    %str   (nod "str" at.p (show-quoted text.p) ~)
    %any   (nod "any" at.p "" ~)
    %bind  (nod "bind" at.p (trip name.p) ~)
    %cell  (nod "cell" at.p "" (turn items.p sexp-pattern))
  ==
::
++  sexp-shape
  |=  s=shape
  ^-  sexp
  ?-  -.s
    %aura     (nod "aura" at.s "@{(trip aura.s)}" ~)
    %noun     (nod "noun" at.s "" ~)
    %void     (nod "void" at.s "" ~)
    %flag     (nod "flag" at.s "" ~)
    %const    (nod "const" at.s (show-lit lit.s) ~)
    %ref      (nod "ref" at.s (show-names names.s) ~)
    %tvar     (nod "tvar" at.s (trip name.s) ~)
    %path     (nod "path" at.s (show-psegs segs.s) ~)
    %apply    (nod "apply" at.s (show-names ref.s) (turn args.s sexp-shape))
    %cell     (nod "cell" at.s "" (turn fields.s sexp-field))
    %union    (nod "union" at.s "" (turn cases.s sexp-shape))
    %fn       (nod "fn" at.s "" ~[(sexp-shape sample.s) (sexp-shape product.s)])
    %generic  (nod "generic" at.s (show-tvars vars.s) ~[(sexp-shape body.s)])
  ==
::
+|  %parser-helpers
::
::  For the parser (section 3). +pare is a step's result, +then chains
::  steps with ;< so that an error stops the parse, +span-of is any
::  node's span, +fail builds "expected …, found …" at a token.
::
::  +pare: a parse step's result: the value and the tokens after it
::
++  pare  |$  [a]  (each [val=a rest=(list token)] error)
::
::  +then: the bind for ;<, as in  ;<  [e=expr ts=(list token)]  then  (expr ts)
::
++  then
  |*  m=mold
  |*  [res=(each m error) next=$-(m *)]
  ?-  -.res
    %|  [%| p.res]
    %&  (next p.res)
  ==
::
::  +span-of: the span of any node: every node is [%tag at=span …]
::
++  span-of
  |*  node=[@ span *]
  ^-  span
  +<.node
::
::  +fail: the error "expected <want>, found <the next token>"
::
++  fail
  |=  [file=path toks=(list token) want=tape]
  ^-  [%| p=error]
  ?~  toks  [%| file 1 1 "expected {want}, found the end of the tokens"]
  =/  l=loc  (where i.toks)
  [%| file line.l col.l "expected {want}, found {(show-found i.toks)}"]
--
