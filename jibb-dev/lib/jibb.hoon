::  /lib/jibb.hoon: the Jibb compiler, milestone 1
::
::  The layout pass, the parser, the printers and errors for Jibb, the UI
::  language of the design doc. The doc's Grammar tab is the spec; where
::  this file and the doc disagree, the doc wins. One core with no Ford
::  runes, so `urbit eval` runs it as `=>  <this file>  <expression>` and a
::  ship builds it as /lib/jibb.hoon.
::
::  API
::    +layout        [file=path src=@t]           (list token)
::    +parse         [file=path src=@t]           (each module error)
::    +parse-tokens  [file=path toks=(list token)] (each module error)
::    +golden        [file=path src=@t]           [tokens=@t tree=@t]
::    +golden-types  [file=path src=@t]           @t (partial inference)
::    +show-tokens   (list token)                 @t
::    +show-module   module                       @t
::    +show-error    [src=@t error]               @t
::  A file is a Clay path whose last segment is the extension, as the
::  golden runners pass /tests/golden/<case>/source/jibb. +layout never
::  fails: an error it finds is its last token (2.0), and +layout-error
::  takes it out.
::
::  Status: the syntax types, the printers, +golden, the layout pass (+layout,
::  +lexer) and the parser (+parse-tokens, +parser) work, and +golden
::  checks every tree's spans (+check-spans, section 1). Choices the
::  doc leaves open are marked "(doc question)": they follow the most
::  likely reading and are listed, with the doc's words, for the doc's
::  author to settle. Those the author has settled, in the Decisions
::  tab's rows of 2026-10-30, are marked "(Decisions)" beside the rule
::  decided. The golden corpus's "expect:" lines give each error's
::  position. A partial inference fragment is in %type-inference; its
::  output explicitly says the module has not been checked. The layout
::  pass's errors sit there, except where the
::  parser finds an earlier error first, as in `++ 2nd 5`, or moves one
::  back to the start of its text, as in `++ x @sd` (2.0, 2.8, and
::  section 3, Errors).
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
::  so does editor tooling later. A node starts at its first token and
::  ends where its last token ends: its closing token if it has one, else
::  its last child's last token, never a layout token. So an open
::  bracket, a body, ?-'s arms and a +$'s cases end with their last line's
::  code, not at the line that closes them. Every node's span holds its
::  children's spans, in source order. The printed tree shows starts
::  only, and milestone 1's errors use starts only, so ends are first
::  used by milestone 2's excerpts. Until then +check-spans tests the two
::  rules above on every tree +golden prints, and a tree that breaks one
::  ends with a line "SPAN ERROR: (<kind> <start> to <end>) <why>". It
::  finds each node's end from the tokens alone, matching each opener
::  with its closer on the line, so a node that stops at a child where
::  its closer follows fails it, and +check-spans-test plants such
::  wrong ends to show that it does (tools/hoon check-spans-test prints
::  the empty list, <<>>, when it passes).
::
::  ===================================================================
::  2. The layout pass (+layout)
::  ===================================================================
::
::  +layout turns the text into tokens one line at a time: no token
::  crosses a line break, and only layout tokens join lines.
::
::  2.0 Errors. +layout never fails. Where the text breaks a rule of this
::  section, it emits one error token, [%error msg from c], at the first
::  character that breaks it, and stops reading. from is where the text it
::  was reading began, c is that text's first character, and the token is
::  tight when that text follows the previous token with no space. Where
::  the lexer has already cut a token from the front of that text, as 100
::  from 1000, the parser takes that token before it reaches the error, so
::  the text the error token stands for begins at the error: from is the
::  error's own place, and c the character there (2.8, +err-on). The
::  parser accepts no error token, so it reports whichever comes first,
::  its own error or this one (section 3, Errors). Every error, from
::  either stage, points at the first character where the text stops being
::  the start of any valid module: everything before it could still be
::  right. Hoon's parser reports errors the same way, and the golden
::  corpus's expect lines assume it. It also puts `++ x ]` on line 1
::  before a bad string on line 9, which a lexer that failed first would
::  report instead. The positions below follow from it, for text that
::  could begin a token where it stands; where the parser's place can't
::  begin with c at all, the parser moves the error back to from, as
::  `++ x @sd` at the @ (section 3, Errors). Spaces and comments emit
::  nothing (2.3, 2.6), so where a line ends before what it needs, the
::  error is just past the line's last token, not at its trailing
::  spaces or comment: `++ x ^-  :: c` above a deeper line fails at 1:8
::  (section 3, Errors). Messages quote code in backticks, as the
::  parser's do.
::
::  2.1 Lines. The text is split at every \0a. A final \0a ends the last
::  line rather than starting an empty one. Lines are numbered from 1.
::
::  2.2 Characters. Anywhere in the text, strings and comments included,
::  these are errors at the character: tab (9), "a tab: Jibb uses spaces
::  only"; carriage return (13), "a carriage return: Jibb lines end with
::  a line feed alone"; every other byte below 32 except \0a, and 127, "a
::  control character". Bytes from 128 up (UTF-8) are allowed only inside
::  strings and comments ("non-ASCII text outside a string or comment").
::  Outside strings and comments, see 2.6 for which printable characters
::  start a token.
::
::  2.3 Blank and comment-only lines. A line of spaces only, or whose first
::  non-space characters are ::, emits nothing and changes no level. Its
::  characters are still checked (2.2).
::
::  2.4 Levels. The stack holds the columns of the open levels, innermost
::  first, and starts as ~[1]. For every other line let c be the column of
::  its first non-space character. The first such line emits no layout
::  token and needs c = 1, else the error "the first line is indented:
::  top-level lines start at column 1". Each later one emits:
::    - c > top: push c, emit INDENT.
::    - c = top: emit NEWLINE.
::    - c < top: while c < top, pop and emit DEDENT. Then c must equal the
::      new top, else the error "this line's indentation matches no
::      enclosing line: indent it to column 1, 5 or 7" (the stack's
::      columns before the pops, outermost first); emit NEWLINE.
::  Then the line's tokens (2.6). These errors, and a bad character (2.2)
::  at column c, sit at column c and come before the line's layout
::  tokens. A layout token's span runs from just past the previous token,
::  on an earlier line, to column c of this line. Errors and the token
::  printer place a layout token at its span's end, the start of the line
::  it begins (+where): the line's column is what made it INDENT, NEWLINE
::  or DEDENT, and until that line, a deeper one could still have come.
::
::  2.5 End of file. If any token was emitted and no error token: pop
::  every level above 1, emitting DEDENT for each, then emit one NEWLINE,
::  all with empty spans just past the last token. They are the only
::  layout tokens with empty spans, which is how errors name "the end of
::  the file". So every import and definition, the last one included, is
::  followed by NEWLINE, as `module = { import NEWLINE } { definition
::  NEWLINE }` needs. A file without tokens (empty, or only blank and
::  comment lines) gives no tokens: an empty module.
::
::  The layout pass knows nothing of brackets: it emits INDENT, NEWLINE and
::  DEDENT by column alone. The parser decides what takes an indented
::  block: a bracket left open at the end of its line, a rune's body, ?-'s
::  arms, and a +$'s cases on the next lines. A bracket opened and
::  closed on one line is just tokens.
::
::  2.6 Tokens. After the indentation, tokens are read left to right;
::  spaces separate them and are dropped, spaces at the end of a line too.
::  A token is tight when it follows the previous token on the same line
::  with no space between; the first token of a line never is. Tightness
::  is how the parser tells the tight forms apart: m( from m (, a+b from
::  a + b, `x from ` x, |=%got from |= %got, name=value from name = value.
::  What a token is depends on its first characters. An error "at 2nd" is
::  at the token's second character, the first that no Jibb token allows
::  after its first:
::
::    ::             a comment: the rest of the line is skipped
::    ( ) [ ] ` = *  glyphs
::    ~[  ~&         glyphs
::    ~              a ~ literal: ~ and the run of [a-z0-9._~-] after it,
::                   read as 2.8 says; a bare ~ is null, [%null %n 0]
::    %/             glyph, then a path segment may follow (2.7)
::    %.y  %.n       loobean literals, [%f 0] and [%f 1]; %. then anything
::                   else is an error at 3rd, "the loobeans are `%.y` and
::                   `%.n`"
::    %&  %|         term literals, [%f 0] and [%f 1]
::    %$             the empty term, [%tas 0]
::    %a...          term literal: % and a name [a-z][a-z0-9-]*, [%tas name];
::                   a capital or _ right after it is an error there,
::                   "names are lowercase letters, digits and -"
::    %0...          term literal: % and a decimal written as a number
::                   literal's is, [%ud value]: %0, %42, %1.000
::                   (Decisions). The run of [0-9a-zA-Z.] after the % is
::                   read as a number literal's run (2.8) and fails at
::                   the same character of the run: %1000 at its fourth
::                   digit, as 1000 does, and %1.0 just past its run.
::                   But %0 alone is a term, so anything in the run after
::                   its 0 fails there, as the second 0 of %007 and the x
::                   of %0x1f. That holds for every run of 0 and a letter,
::                   which fails at the letter whether Hoon reads the run
::                   as another aura or not (2.0): %0x and %0xg at the x,
::                   as %0x1f, though 0x and 0xg as numbers fail at the
::                   character after the x, since nothing goes on from
::                   the 0 of %0. The message is "a numeric term is
::                   `%` and a decimal, digits in groups of three joined
::                   by dots, as %1.000" (+numeric-term)
::    %              anything else after it: error at 2nd, "`%` begins a
::                   term, a loobean or `%/`"
::    /- /% /=       import glyphs at column 1, where imports go; anywhere
::                   else / is a path's, so ++ x /- is the path whose
::                   one segment is -, as the EBNF's knot allows
::    /              glyph, then a path segment may follow (2.7)
::    ++  +$  +      glyphs
::    |=(  |=  |$    glyphs
::    $-(            glyph; $- followed by anything but ( is an error
::                   at 3rd, "`$-` has only the wide form `$-(sample
::                   product)`"
::    ^-  ?-  !!  ?  glyphs (? alone is the loobean mold; ? then a
::                   character of Hoon's other ? runes is left out, below)
::    @              aura: @, then [a-z]*, then at most one [A-Z]; the
::                   token holds the text after @. An aura starting @s or
::                   @r is an error at 2nd: "signed and floating-point
::                   auras are left out of Jibb"
::    A-Z            type variable: one capital. A letter or digit right
::                   after it is an error there, "a type variable is one
::                   capital letter", after the type variable's token
::    a-z            name [a-z][a-z0-9-]*, or a wing: two or more names
::                   joined by dots. Right after the name or wing, which
::                   is emitted first, a capital or _ is an error there,
::                   "names are lowercase letters, digits and -", and so
::                   is a . not followed by [a-z], at the character after
::                   the dot, "a `.` in a wing is followed by a name"
::    0-9            number literal: the run of [0-9a-zA-Z.] (2.8)
::    "              string (2.9)
::    }              ends the innermost interpolation (2.9), else an error
::                   at it, "this `}` closes no `{`"
::    | $ ^          followed by nothing above or in the table below:
::                   an error at 2nd, "`|` begins `|=`, `|=(` or `|$`",
::                   "`$` begins `$-(`", "`^` begins `^-`"
::    :              followed by anything but :, an error at 2nd: the
::                   table's :~ :* :- :+ :^ :_ and a:b, else "a comment
::                   starts with `::`"
::    anything else  an error at it, naming it: "unexpected `,`", with a
::                   hint where one helps (+unexpected): for , . - and <,
::                   what Jibb writes instead
::
::  Hoon forms the doc leaves out are errors with the doc's reason, as
::  "`|%` is left out: modules are records". Each points where the text
::  stops being Jibb: at its second character when its first can begin
::  some Jibb token, else at its first. Where the parser's place can't
::  begin with that first character, the parser moves the error to it
::  (2.0): `|%` at the top of a file fails at the |, `++ x |%` at the %.
::  The doc's list says "such as" of the tall forms and the wide ones,
::  so Hoon's runes of the same kinds get the same reason (doc
::  question):
::
::    |%  |_  |*    2nd    modules are records
::    |-            2nd    gates recurse by name
::    $(            2nd    gates recurse by name (at the $ where an
::                         expression goes, as no expression starts $)
::    $?  $%        2nd    a union is a +$ with its cases below
::    ?:  ?+        2nd    ?- is the branch, and so for Hoon's other ?
::                         runes, ?~ ?= ?. ?@ ?^ ?& ?| ?< ?> (?:: is ?
::                         and a comment)
::    ?!            2nd    eq and not are gates
::    .=            1st    eq and not are gates
::    !x            2nd    not is a gate: ! then anything but ! or >
::    !>  /+        2nd    code also runs in the browser
::    =<  =>        2nd    names never shadow, and . reads imports too
::    .*            1st    the same
::    a:b           2nd    of the :, right after a name: names never
::                         shadow, and . reads imports too; write a.b
::    :~  :*        2nd    indentation covers them; write ~[…] or […]
::    :-  :+  :^ :_ 2nd    indentation covers them; write a cell as [a b]
::    %:  %-  %+    2nd    indentation covers them; a call is (f a b)
::    %^  %~
::    %=            2nd    indentation covers it; write a change, m(a=b)
::    ==            2nd    the closers are left out: indentation covers
::    --            1st    them
::    ~|            2nd    ~& covers debugging
::    ;:            1st    nest the calls, as (add a (add b c))
::    ;             1st    Sail's ; runes are left out: layout is Jibb's
::                         elements
::    '             1st    there is no '…' form: strings are "…"
::
::  The parser finds the doc's other left-out forms (section 3, Errors):
::  =(a b), =/, *mold, ^-(…), ?-(…) and ~&(…), and Hoon's =+ =? and =.
::  The lexer can't, since = and * begin valid Jibb too: open=(not
::  open.s), scry=/todos, a * mold.
::
::  2.7 Paths. Right after a / or %/ glyph, a run of knot characters
::  [a-z0-9._~-] is one knot token, tight. So /posts/~zod is / knot / knot;
::  %/static/img/logo.png is %/ knot / knot / knot; in /todo/[id=@ud] and
::  %/blog/(slug) the [ and ( after / are ordinary glyphs. This is the one
::  place knot tokens appear and the one context, besides strings, the
::  lexer tracks: segments such as logo.png, 1 or ~zod would otherwise lex
::  as a wing, a number or a ship. A / followed by anything else is just a
::  glyph: / alone is the empty path, and the parser rejects empty
::  segments such as //. After the glyph and its knot, if any, comes a /,
::  ( or [, a closer ) ] or }, a : (of a comment) or a space: any other
::  printable character is an error there, "unexpected `P`: a path
::  segment holds lowercase letters, digits and - . ~ _", which for ?
::  and # also says a path carries no query or fragment. No Jibb token
::  goes on a path that way, so /Posts and %/blog?page=2 fail at the P
::  and the ?. A ~. knot literal (2.8) gets the same check, "a knot
::  holds lowercase letters, digits and - . ~ _".
::
::  2.8 Literals. The lexer takes a literal's run (2.6), then reads it
::  with Hoon's own parser, (nuck:so [[line col] run]), whose edge says
::  how much it read and how far it looked (p.edge). Some runs never
::  reach it, since they begin an aura Jibb doesn't write, whatever
::  follows, or text Hoon's parser crashes on:
::    - 0b, 0c, 0i and 0w: an error at 2nd, "Jibb writes no @uw
::      literals" and so on. Hoon's parser would read 0b, or a 0c1 whose
::      checksum fails, as the number 0 and an error past the run.
::    - ~- (a @c), "Jibb writes no @c literals", and ~~ (a cord), "Jibb
::      writes no @t literals; strings are "…"", at 2nd. Hoon's reader of
::      @c crashes on a control character, as in ~-~1.
::    - ~0 and a base-32 digit, at 3rd: Hoon's parser reads a blob there
::      and cues it, which can run out of memory, past what mule catches.
::      No Jibb literal goes on so, since a year has no leading 0: after
::      a letter it is "Jibb writes no blob literals", after a digit the
::      date's message (+literal-msg). ~0.1.1 is a date (below).
::    - A year BC of 0 or past 292.277.024.401, as in ~0-.1.1, at the -
::      that makes it BC: Hoon's +year crashes on it (+year-bc).
::    - A fifth sub-second group, after a duration's .. or a date's
::      second .., at the dot that begins it: "a date or duration takes
::      at most four sub-second groups", as Hoon's do, since its +yule
::      crashes on a fifth (+fifth-group).
::  A date or duration is also read under mule, so that any other crash
::  is an error at the run's start, "Jibb can't read this literal"; other
::  runs aren't, since mule costs about a millisecond a call. Then:
::    - It read the whole run, as an aura Jibb takes: the token. Numbers
::      take %ud, %ux and %uv: 1.000, 0x1f, 0v5.fdf99 (Hoon reads 0x1F
::      too). ~ runs take %p, %da, %dr and %ta: ~zod, ~sampel-palnet,
::      ~2026.10.23..14.30.00, ~h1.m30, ~.my-post. Its value is Hoon's,
::      as every literal reads exactly as Hoon reads it (Decisions):
::      ~0.1.1 is 1 BC and prints as ~1-.1.1, ~2026.2.31 is ~2026.3.3,
::      and years BC and sub-second groups are dates.
::    - It read the run or part of it as another aura Jibb doesn't take:
::      an error at 2nd that names the aura, as "Jibb writes no @if
::      literals".
::    - It read only part of the run, as an aura Jibb takes: that part is
::      a token, then an error token at p.edge, the furthest character
::      Hoon's parser looked at, where Hoon reports it too. 1000 is the
::      token 100 and an error at its fourth digit ("a decimal is digits
::      in groups of three joined by dots, as 1.000": each kind of literal
::      has its message, +literal-msg); 0v5.fdfz9 is 0v5 and an error at the
::      z; ~2026.10.29..14.30, the minute form print-date writes, is no
::      literal (Decisions) but ~2026.10.29 and an error just past the
::      run. The token lets the parser report an earlier error first: in
::      `++ 2nd 5` it finds the number 2 where a name goes, at 1:4.
::      When it read a ship, or only the ~ of a run that goes on with a
::      letter, the error goes instead at the first letter that no
::      syllable continues (+ship-stop), or just past a duration's unit,
::      d h m or s, if that is later: Hoon's parser reads a syllable's
::      three letters before it looks them up, so it looks past that
::      letter. `++ x ~x` fails at the x, 1:7, as no syllable starts with
::      x, and ~sampel-palnez at the z. The error token's from is the
::      error's own place, not the run's start, since the parser has
::      taken the run's first part as a token by the time it reaches the
::      error (2.0, +err-on): so `+$ x ~x` fails at the x too, the ~
::      being a mold, and `+$ x %1.0` at 1:10, as `++ x %1.0` does.
::  The token is [%lit [form aura val txt]]: form names the literal rule
::  that matched, aura and val are the dime Hoon's parser gives, and txt
::  is the literal as written. A numeric term's decimal is read as a
::  number's run is, here, from the character after its % (2.6,
::  +numeric-term); the other terms, loobeans and the bare ~ are read by
::  hand (2.6).
::
::  2.9 Strings. A " starts a string, which ends on the same line, as each
::  of its {…} does (Decisions). Up to the closing ":
::    \\ \" \{ and \ with two lowercase hex digits are escapes, Hoon's
::      (Decisions), so \\ writes a backslash and \0a a line feed. Any
::      other \ is an error at the first character that can't continue
::      the escape: the one after the \, or a bad second hex digit (2.2's
::      error if it is a tab or another control character)
::    { starts an interpolation. The text so far is emitted as str-head,
::      spanning from the opening " to just past the {, or as str-mid,
::      from the } that ended the previous interpolation to just past the
::      {. Then tokens are lexed as usual, strings included, up to the }
::      that ends this interpolation, where the string resumes
::    the closing " emits str when there was no interpolation, spanning
::      the whole string, or str-tail, from the last } to just past the "
::    any other character is text, } included, as in Hoon
::  So "Since {day}!" is str-head "Since ", name day, str-tail "!", and the
::  parser reads head expr { mid expr } tail. The lexer keeps a stack of
::  open interpolations, since strings nest inside them. Inside an
::  interpolation a : is an error at it, "a comment can't start inside
::  `{…}`", and so is a {; inside a string, :: is text (Decisions). A
::  line that ends inside a string or an interpolation is an error at
::  its end, "this string has no closing `\"` on its line" or "this `{`
::  has no `}` on its line". Token texts hold the decoded text. Spaces
::  after { and before } are allowed, as after any opener (Decisions).
::
::  2.10 What fails here. Bad characters (2.2), an indented first line and
::  a dedent to no open level (2.4), characters that start no token or a
::  left-out form (2.6), malformed literals and numeric terms, auras,
::  type variables and wings (2.6, 2.8), a character that no token lets
::  follow a path segment or a ~. knot (2.7), and unclosed strings and
::  interpolations, bad escapes and stray { or } (2.9). Everything
::  else is the parser's: brackets that don't match or don't close, a
::  missing or extra space, a deeper line that nothing takes, a token
::  where it can't go.
::
::  ===================================================================
::  3. The parser (+parse-tokens)
::  ===================================================================
::
::  Hand-written recursive descent over the token list (+parser): one
::  arm per EBNF rule, each taking the remaining tokens and returning
::  (pare node): the node and the tokens after it, or an error. Steps
::  chain with ;< and +then, so an error stops the parse (+read-cast):
::
::    ;<  [s=shape after=(list token)]  then  (read-mold ts)
::    ;<  [e=expr more=(list token)]  then
::      (read-expr-or-body "the mold" after)
::    [%& [%cast [beg.at.ket end:(span-of e)] s e] more]
::
::  Why: after the layout pass the grammar is LL(2). Each choice is made by
::  the next token, at most with the one after it and whether it is tight:
::    name, then = tight            a face (items, lines, fields, samples)
::    name, then + tight            a pair
::    name or wing, then ( tight    a change
::    |=, then a term tight         a constructor; else, where an
::                                  expression starts, the tall gate
::    ++ or +$                      a definition; else a body's final expr
::    INDENT                        a body, an open bracket's lines, arms
::                                  or cases; else the expression goes on
::  So the parser never backtracks, its first failure is its furthest, and
::  "expected X, found Y" falls out of each arm without tracking failures
::  across alternatives. Hoon's combinators read tapes of characters and
::  their failures carry a position but no expectation; over tokens they
::  would need a token "tape" and an expectation set bolted on. Recursive
::  descent is shorter, and each error names what its construct expected.
::  An operand that isn't where an expression starts (a call's argument,
::  an item, a pair's or unit's operand, the wide gate's body) can't be a
::  rune, so there |= is a constructor and needs its term at once, or
::  the ( of the wide gate: in ++ x (state.cart |= %got) the space after
::  |= is an error, 1:20. A loop over many items (definitions, arms,
::  lines, items) is a trap whose every step, through +then, is a tail
::  call, so a long module grows no stack. Nesting does, by a few frames
::  a level: 100.000 nested parentheses parse, closed on their line or
::  left open above one deeper line, and so do 100.000 nested calls,
::  ++ x (f (f … ~[ above one deeper line, and a 20.000-line module.
::  Brackets left open on one line close together at one test each
::  (+shut), with no look back at their tokens. +golden's tree stops
::  indenting past 64 levels (4.2), so its size grows with the text's,
::  not with its square, and its time a little faster than the nesting:
::  tools/golden takes 12 s, 23 s and 70 s on 10.000, 30.000 and
::  100.000 such calls, 8 s of it starting urbit and building the
::  library, and most of the rest printing the tree, 46 MB at 100.000.
::
::  @iko decided 2026-10-30 (Decisions): "No `$?`: a `+$` with its cases
::  on the lines below is a union, so every union written in Jibb has a
::  name; one case is just that mold; a mold that isn't a union counts as
::  a union of one case for tags and `|=%tag`; a generic's `|$` comes right
::  after the `+$`'s name; tags anywhere".
::
::  The EBNF and its nodes (see the types below):
::    module      { import NEWLINE } { definition NEWLINE }, then the end
::                of the tokens; an import after a definition is the error
::                "expected a definition, found `/-`; imports come first"
::    import      /- name -> %sur;  /% term -> %mark;  /= name pathlit ->
::                %jibb. /% takes % and a name only: no mark is called %0,
::                %& or %| (doc question). /='s path has a segment, as it
::                names a module's file: /=  card  / is an error just past
::                the / (doc question)
::    definition  +$ name, optional |$ [vars], then a mold on its line or
::                cases below -> %mold; one case is that mold, several
::                are %union. The optional generic wraps either in %generic.
::                ++ name expr or body -> %value (a body becomes a %body expr)
::    body        INDENT { definition NEWLINE } expr DEDENT -> %body
::    call        one operand is that operand; more -> %call head args
::    operand     literal -> %lit or %str; pathlit -> %path, as a path
::                literal is an expression (Decisions); !! -> %crash, as
::                !! is an operand (Decisions), so f !!, [a !!], ~[!!],
::                `!!, a+!!, m(a=!!) and |=(a !!) need no parentheses;
::                qath -> %qath; ref -> %wing; change -> %change; pair ->
::                %pair; unit -> %unit; group -> %group; list -> %list;
::                tuple -> %tuple; gate -> %gate-wide; ctor -> %ctor
::    group       ( expr ) -> %group of the expr. The open form ( {operand}
::                open -> %group of the call whose elements are the first
::                line's operands, then one per line; one element alone is
::                just grouped. A ( alone at the end of its line puts the
::                head on the first deeper line (Decisions), and needs
::                that line, as () is no group. A ( followed by a rune is
::                the closed form. Lines of an open group or list take no
::                name= (doc question)
::    change      every item and line has name= (the EBNF's "items named")
::    rune        |= -> %gate; ^- -> %cast; ~& -> %trace; ?- -> %branch.
::                !! is an operand, not a rune (Decisions): alone where an
::                expression goes it is a call of one operand, and !! a
::                is a call whose head is !!, for the checker to judge
::    sample      the sample of |= and |=(…): a field, except that a bare
::                name binds (%bind) wherever it stands in the sample: the
::                whole sample, as |= x and |=(p title.p), or a field of a
::                cell sample at any depth, as b in |= [a=@ b], which is
::                a %cell of samples (Decisions: every bare name in a
::                sample binds, at any depth). A name inside a mold, as a
::                in (list a) or $-(a b), is a mold. A cell
::                sample's [ has no open form, as a cell pattern's hasn't
::                (Decisions)
::    mold        aura -> %aura; * -> %noun; !! -> %void; ? -> %flag;
::                ~ term loobean -> %const; ref -> %ref; typevar -> %tvar;
::                pathmold -> %path; ( ref mold … ) -> %apply; [ field … ]
::                -> %cell; $-( mold mold ) -> %fn. Only a +$ definition
::                introduces %union or %generic.
::                A mold's ( and [ may be left open at the end of their
::                line, as an expression's brackets can (Decisions):
::                ( ref { mold } mlines -> %apply, the name staying on
::                the first line, so ( alone there is an error at the end
::                of its line, where the name goes; [ { field } flines ->
::                %cell, [ alone too.
::                mlines and flines are INDENT and one mold or field per
::                deeper line, which may itself open, to the DEDENT; a
::                second item on a line, or a closer, is an error. The
::                node is the closed form's, ending with its last item.
::                $-( has no open form.
::    field       name=mold -> %face; =name -> %pun; mold -> %bare
::    pattern     term number ship loobean ~ -> %lit (dates, durations and
::                knots are errors); string without {…} -> %str; * -> %any;
::                name -> %bind; [ pattern … ] -> %cell
::
::  What the EBNF leaves out, and how this design fills it in:
::    - Rules it names but doesn't define: string, ship, date, duration,
::      knotlit, decimal, hex, base32, lower, upper and digit. They are
::      Hoon's literals, exactly (the Literals table; Decisions: 1000 is
::      an error, ~2026.2.31 is ~2026.3.3, years BC and sub-second groups
::      are dates, and print-date's minute form is no literal), read as
::      2.6, 2.8 and 2.9 say; a numeric term's decimal is a number's.
::    - A string's interpolations: str alone, or str-head expr { str-mid
::      expr } str-tail, where each expr is a full expression.
::    - Spaces, comments and blank lines: the layout pass, and Spacing
::      below.
::    - knot may be empty: only / alone uses that, as the empty path in
::      an expression or a mold, not in an import; // and a trailing /
::      are errors (doc question).
::    - Several brackets left open on one line, which its layout comment
::      allows and its productions can't say (Decisions): the deeper
::      lines go to the last bracket or rune left open on the line, and
::      every bracket open before it closes with it, at the first line
::      that isn't deeper, with no closer, ending where its last item
::      ends. So (column ~ ~[ above its items is (column ~ ~[…]), and
::      the next line at its depth goes to what holds that line. This
::      holds for every bracket before the last, whether or not it has
::      an open form of its own, as the Decisions say "the brackets
::      before it close with it": an expression's ( [ and ~[, a change's
::      (, |=(, a mold's ( [ and $-(, an application path's (…), and
::      a cell sample's [. A segment's ( holds an expression as an
::      expression's ( does and needs only its ), so %/a/(f ~[ above its
::      items is %/a/(f ~[…]), as $-(, which has no open form
::      either, closes so; a sample's [ that closes so leaves its gate no
::      body. A cell pattern's [ and |$'s [ hold no other bracket, and
::      an interpolation's {…} closes on its line (2.9). A rune's body
::      or arms that took the lines close the brackets before the rune
::      too: (|= a above its body is a group holding the gate. A bracket
::      closes so when the last item it read ends on a later line than
::      its opener, which needs no look back (+shut). One that still
::      needs a part after that item, as |=( or $-( with only its
::      sample, can't close so, and neither can a rune before the last
::      opener that needs deeper lines of its own: errors at the end of
::      the line (Errors below). A mold's ( never needs more than its )
::      once it holds its name: one that is the last opener on its line
::      takes the deeper lines as its open form (Decisions), and one
::      before a later opener holds that mold after its name and closes
::      with it.
::    - Local definitions: at the start of any body, a gate's, an arm's,
::      a ^-'s, a ~&'s or a ++'s, as the EBNF's body takes them
::      (Decisions); +$ as well as ++, as the Runes prose's "likewise"
::      says.
::    - Where errors point: the doc says only "line, column and an
::      excerpt"; 2.0 and Errors below say where.
::
::  Spacing. Two tokens on one line are separated by spaces, except:
::    - tight, always: name+operand (pair), `operand (unit), |=term
::      (constructor), wing( (change), name= and = value (faces, in items,
::      lines, fields and samples), =name (pun); in a path or application
::      path, each / and the segment after it, and all of a typed segment,
::      [id=@ud]
::    - either way: right after an opener ( [ ~[ |=( $-( or {, and
::      right before a closer ) ] or } (the theme example writes `[ space=`),
::      the ( and ) of an application path's segment included; inside
::      them the expression is spaced as anywhere else, as %/x/(f a)
::  A missing space is an error at the tight token, and a space inside
::  a tight form, or the end of the line there, is one where it starts
::  (Errors). A rune with children, and an import glyph, is followed by
::  a space.
::  Items are separated by one or more spaces; how many isn't checked,
::  and a line may end in spaces. Spacing beyond this is style, which
::  the formatter keeps: "one space between items; more for alignment"
::  (Decisions).
::
::  Errors. The parser stops at the first token it can't accept and
::  reports "expected <what>, found <token>", with an optional "; <hint>",
::  lowercase, no final period. <what> uses the doc's words: "an
::  expression", "a mold", "a pattern", "a name", "`]`", "a space between
::  items". <token> is +show-found: the token's text in backticks, "a
::  string", and for layout tokens "a deeper line" (INDENT), "a line at
::  the same depth" (NEWLINE), "a shallower line" (DEDENT), or "the end of
::  the file" (an empty span, 2.5). Each error points at the first
::  character that can't begin a valid module (2.0):
::    - At a token the place can't take: just past the part of it that
::      could still begin what the place takes (+fail-in, +prefix). That
::      is none when the place can't begin with its first character, so
::      `++ 2nd 5` fails at the 2, 1:4; a wing's first name where a name
::      goes, so `++ a.b 1` fails at the dot, 1:5; else one character,
::      as the % of %.y where a term goes, the ~ of ~zod where a mold
::      goes (~ alone is one), or a + or ? alone. A layout token is at
::      the start of the line it begins, or just past the last token at
::      the end of the file (+where), where another line, deeper or not,
::      would have done. So `++ view` above `++ main view` is an error at
::      2:1, the line that isn't deeper.
::    - Where a tight form needs its next token at once (after name+, `,
::      |= in an operand, name=, the = of a pun, a / after a path
::      segment, a typed segment's parts) and finds a space or the end
::      of the line: at the end of the previous token, where the space or
::      the line's end starts, as "expected an operand right after `+`,
::      found the end of the line" (+fail-space). No later line can give
::      a tight form its next token. A wing and a ( after a space are no
::      error: that is a call; nor is / or %/ alone, a whole path. A
::      change's item is name=, so a name there with no = right after it
::      fails just past the name, whatever follows: `m(b c)` at the
::      space, `m(b)` at the ), `m(a"x)` at the " with the layout pass's
::      message after the parser's (+unnamed, +moved). `m(a==1)` has its
::      =, and fails at the second, where the layout pass does.
::    - Where the place needs text on its own line and the line ends,
::      whatever line comes next: at the end of that line, just past its
::      last token, "found the end of the line" (+fail-line), as no later
::      line can supply it. That is a rune's part on its line (|='s
::      sample, ^-'s mold, ~&'s value, ?-'s subject, |$'s [), a
::      name after ++ or +$, an import's parts, and what a bracket that
::      closes on its line still needs: one with no open form ($-(
::      |=(, a cell sample's or cell pattern's [, |$'s [, an application
::      path's (…), a ( before a rune), or a mold's ( before its name,
::      which stays on the first line (Decisions); the bracket adds "this
::      bracket closes on its line" (+unclosed-want). So `++ x ^-` above
::      a deeper line fails at 1:8, "expected a mold, found the end of the
::      line". Spaces and a comment after the last token
::      emit nothing (2.3, 2.6), so they don't move the end of the line:
::      `++ x ^-  :: c` fails at 1:8 too. At the end of the file the place
::      is the same, and the message says "the end of the file".
::    - At an error token: the lexer's position and message, unless the
::      text it was reading begins with a character the place can't
::      begin with. Then at that character, the lexer's message after
::      the parser's (+moved): `++ x @sd` is "expected an expression,
::      found `@`; signed and floating-point auras are left out of Jibb"
::      at the @, while `+$ x @sd` fails at the s. The place includes
::      what could still go on before it: after a call's operand and a
::      space, another operand, so `++ x a ?:` fails at the ? and `++ x
::      a |%` at the % (+read-operands), as `++ x !! |%` does, !! being
::      an operand; after a mold or an import that ends a line, nothing,
::      so `+$ x @ |%` fails at the | (+bad-end-in), and so after an
::      open mold bracket's line's one item; tight after an item, a
::      closer, or after a name the ( . + or = of a change, wing, pair
::      or face (+tight-error, which doesn't look at what the item was,
::      though it takes no = after a call's operand). A : stays where
::      the lexer put it, since it could begin a comment. An error token
::      after a space or on a later line, where a tight form needed its
::      next token, comes after the tight form's error (+fail-space).
::    - At layout tokens followed by an error token whose text begins
::      the line, both errors are at the line's start, and the lexer's
::      message, about that text, says more: a line `==` that closes a
::      ?- is "the closer `==` is left out: indentation covers it", not
::      "expected the end of the body" (+lexer-error).
::    - Where a line's last open bracket or rune took the deeper lines
::      while something before it on the line still needs more: deeper
::      lines of its own (a ~&'s body, a ?-'s arms, a tall |='s or ^-'s
::      body when nothing on the line gives one), a part after the one
::      that took them (|=('s body, $-('s product), or the } of an
::      interpolation (2.9): at the end of that line, since no later
::      line can supply it (+doomed). The brackets before the last close
::      with the deeper lines instead (What the EBNF leaves out), so a
::      gate whose cell sample's [ closed so still has no body.
::      `++ x ~& a ~[` above deeper lines is "expected `~&`'s body on
::      deeper lines, found the end of the line; the deeper lines go to
::      the last bracket or rune left open on this line", at 1:13.
::    - Pattern errors point inside their token, where it stops being a
::      pattern: a date or knot at its second character (~ alone is
::      null, and no ship goes on so), a duration just past its unit
::      letter (~d begins ships, as ~dur), ~[ at its [, and a string
::      with {…} at its {.
::  In a bracket, a closer that doesn't match is "expected `]` to close
::  the `~[` at 1:6, found `)`", checked before spacing; after an item, a
::  tight token that isn't a closer is "expected a space between items,
::  found `M`". A bracket that closes on its line names, at a closer that
::  doesn't match or at its line's end, what it still needs: its closer
::  once it holds all it needs, else its next part, as `$-(@)` and `$-(@]`
::  are "expected a mold, the product", and `$-(]` "expected a
::  mold", `|=(]` and `|= []` "expected a sample", `|=(a]` "expected the
::  gate's body" (+unclosed-want). So does a group's ( with nothing after
::  it on its line, as () is no group: `()` and `(]` are "expected an
::  expression", and a ( alone whose next line isn't deeper "expected the
::  call's head on a deeper line" (+read-group). A ) or ] that closes no
::  bracket opened before it on its line adds "this `)` closes no bracket"
::  (+stray), and a closer on a line of an open bracket "a bracket open at
::  the end of its line takes no closer: its items end at the first line
::  that isn't deeper". Hints name the left-out forms the lexer can't see
::  (2.6): where an expression starts, = followed tight by ( is "=(a b) is
::  left out: eq is a gate"; = followed tight by / is "=/ is left out: ++
::  defines values", and so for Hoon's =+ =? and =.; * is "*mold is left
::  out: no defaults"; ^-, ?- or ~& followed tight by ( is "the wide form
::  ^-(…) is left out: indentation covers it". Others name likely slips:
::  |= and a space where an operand goes, "a gate in an operand is |=(a
::  body)", or before a term "a case's constructor takes its term with no
::  space, as |=%got"; name= in a pattern, "patterns take no `name=`: a
::  bare name binds, as [a b]"; a capital or a wing where a name goes, "a
::  name starts with a lowercase letter" and "a name has no `.`"; a lone +
::  where a definition goes, "`+` begins `++` or `+$`"; a mold's ( alone
::  at the end of its line, "a `(` keeps the mold's name on its first
::  line"; a second item on a line of an open mold bracket, "a bracket
::  open at the end of its line takes one field per line" (or mold). The
::  messages quote that code in backticks (2.0), as in "`=(a b)` is left
::  out: eq is a gate".
::  Examples:
::    expected `]` or an item on a deeper line, found a line at the same
::      depth
::    expected `]` or a field on a deeper line, found a line at the same
::      depth
::    expected the end of the line, found a deeper line; only a bracket
::      open at the end of a line, or a rune's body, takes deeper lines
::    expected an expression, found `^-`; inside a call, a rune goes in
::      parentheses
::    expected a named item, found `1`; a change's items are named, as in
::      m(done=%.y)
::    expected `=` right after `b`, found a space; a change's items are
::      named, as in m(done=%.y)
::  Messages of milestone 1 are golden-tested, so their wording is fixed
::  by the tests once written.
::
::  ===================================================================
::  4. Printed formats
::  ===================================================================
::
::  Each printer returns a cord: lines joined by \0a, no final newline.
::
::  4.1 Tokens (+show-tokens): one token per line, "<line>:<col>" at
::  +where, then "tight " if the token is tight, then the kind and the
::  text. Kinds: glyph (with its text), INDENT, DEDENT, NEWLINE, name, wing,
::  lit (the literal as written: 1.000, 0x1f, ~zod, ~h1.m30, ~.knot;
::  terms as %add, %1.000, %& and %|; loobeans %.y and %.n; null ~),
::  str, str-head, str-mid and str-tail (quoted, with \\ \" \{ and \XX
::  escapes), knot, aura (@ud), tvar, and ERROR with its message (+golden
::  prints the rendered error instead). A layout token prints at the
::  start of the line it begins, beside that line's first token; at the
::  end of the file, just past the last token. For `++ main view`:
::
::    1:1 glyph ++
::    1:4 name main
::    1:9 name view
::    1:13 NEWLINE
::
::  and for `++ init |= ~` with `  [[~ %.n] ""]` below it:
::
::    1:1 glyph ++
::    1:4 name init
::    1:9 glyph |=
::    1:12 lit ~
::    2:3 INDENT
::    2:3 glyph [
::    2:4 tight glyph [
::    2:5 tight lit ~
::    2:7 lit %.n
::    2:10 tight glyph ]
::    2:12 str ""
::    2:14 tight glyph ]
::    2:15 DEDENT
::    2:15 NEWLINE
::
::  4.2 Trees (+show-module): S-expressions, (kind line:col fields kids),
::  with the node's start. A leaf is a node whose kids, if any, are atoms
::  (a string's quoted text, an application path's knots). A node whose
::  kids are all leaves prints on one line; otherwise each kid goes on its
::  own line, indented two more spaces, and the closing parens end the
::  last kid's line. (module …) always breaks. Past 64 levels the indent
::  stops growing: a deeper line starts with 128 spaces and its depth
::  between bars, as `|65| (group 1:69`, so the printed tree's size is
::  linear in the text's however deep it nests. Bare fields and samples
::  print as their mold, and a cell sample as (cell …) of its samples, a
::  bare name there as (bind …); unnamed items print as their expr;
::  strings print text pieces quoted, between their interpolated exprs;
::  application paths print knots bare between their (expr) segments. The
::  cart store from the Grammar tab, its code block's first line being
::  line 1:
::
::    (module
::      (mold 2:1 state
::        (cell 2:10
::          (face 2:11 items
::            (apply 2:17 list (aura 2:23 @t)))
::          (face 2:27 open (flag 2:32))))
::      (mold 3:1 cart-action
::        (union 4:3
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
::  past the end of the text prints as an empty line. In the excerpt every
::  control character, a tab or carriage return being the likely ones,
::  prints as a space, so the caret stays under its column and golden
::  files hold no raw control bytes.
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
::    A layout token's span runs from just past the previous token to the
::    start of the line it begins, or is empty at the end of the file
::    (2.4, 2.5). An error token is the last token, if any (2.0).
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
      [%error p=tape from=loc c=@]                      ::  2.0: what broke
  ==
::
::  +glyph: a token that is its text, and the layout tokens
::
+$  glyph
  $?  %indent  %dedent  %newline                        ::  layout
      %'('  %')'  %'['  %']'                            ::  brackets
      %'~['  %'|=('  %'$-('                     ::  openers
      %'%/'  %'/'                                       ::  paths
      %'+'  %'`'  %'='                                  ::  pair, unit, face
      %'*'  %'?'  %'_'                                ::  noun, loobean, type hole
      %'++'  %'+$'  %'|='  %'|$'                 ::  runes
      %'^-'  %'~&'  %'?-'  %'!!'                        ::  runes
      %'/-'  %'/%'  %'/='                               ::  imports
  ==
::
::  +lit: a literal other than a string, as Hoon's parsers read it
::
::    form is the literal rule that matched; txt is the literal as
::    written, which the printers show, since Hoon's own printing of
::    some auras (@da) differs between Hoon versions; aura and val are
::    the dime nuck:so gives, or for terms and loobeans:
::      %number    1.000 0x1f 0v5.fdf99   %ud %ux %uv
::      %ship      ~zod                    %p
::      %date      ~2026.10.23             %da
::      %duration  ~h1.m30                 %dr
::      %knot      ~.my-post               %ta
::      %term      %add  %1.000  %&  %|  %$  %tas 'add', %ud 1.000, %f 0, %f 1, %tas 0
::      %loobean   %.y  %.n                %f 0, %f 1
::      %null      ~                       %n 0
::
+$  lit  [form=lit-form aura=@ta val=@ txt=@t]
+$  lit-form
  ?(%number %ship %date %duration %knot %term %loobean %null)
::
+|  %tree
::
::  The syntax tree. Every node is [%tag at=span …] with at least one
::  field after at, so +span-of finds its span at +<, except +item, +edit
::  and +arm, which have no tag and start with at=span; and a path's
::  knots (+pseg, +qseg) and a string's text (+piece), which have no
::  span: their node's span covers them.
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
::  +sample: a gate's sample, or a field of a cell sample
::
::    A bare name binds (%bind) wherever it stands in a sample, so a cell
::    sample is a %cell of samples, never a %bare cell (section 3).
::
+$  sample
  $~  [%bind *span %$]
  $%  [%bind at=span name=term]                 ::  p
      [%face at=span name=term =shape]          ::  m=model
      [%pun at=span name=term]                  ::  =msg, for msg=msg
      [%cell at=span items=(list sample)]       ::  [a=@ b]  [=msg m=model]
      [%bare at=span =shape]                    ::  ~  @t  (list @t)  %add
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
      [%hole at=span ~]                         ::  _
      [%path at=span segs=(list pseg)]          ::  / /todos /todo/[id=@ud]
      [%apply at=span ref=(list term) args=(list shape)]  ::  (list @t)
      [%cell at=span fields=(list field)]       ::  [text=@t done=?]
      [%union at=span cases=(list shape)]       ::  several +$ cases below
      [%fn at=span sample=shape product=shape]  ::  $-(@t M)
      [%generic at=span vars=(list @t) body=shape]  ::  +$ name |$ [M] …
  ==
::
::  +pseg: a path mold's segment, a knot, [name=aura], or [name=_]
::
+$  pseg  $%([%knot p=@ta] [%typed at=span name=term aura=@ta] [%inferred at=span name=term hole-at=span])
::
+|  %api
::
::  +layout: source to tokens (design: section 2)
::
::    Never fails: an error it finds is its last token, [%error msg from
::    c], at the error's position (2.0). +lexer does the work.
::
++  layout
  |=  [file=path src=@t]
  ^-  (list token)
  ~(run lexer [(trip src) 1 1 ~ ~[1] [0 0] 0 &])
::
::  +layout-error: the error of a token list's error token, if any
::
++  layout-error
  |=  [file=path toks=(list token)]
  ^-  (unit error)
  ?~  toks  ~
  =/  last=token  (rear toks)
  ?.  ?=([%error *] lex.last)  ~
  `[file line.beg.at.last col.beg.at.last p.lex.last]
::
::  +parse: source to tree
::
++  parse
  |=  [file=path src=@t]
  ^-  (each module error)
  (parse-tokens file (layout file src))
::
::  +parse-tokens: tokens to tree (design: section 3)
::
::    It accepts no error token, so it fails at the first of its own
::    error and the layout pass's (2.0). +parser does the work.
::
++  parse-tokens
  |=  [file=path toks=(list token)]
  ^-  (each module error)
  (~(read-module parser file toks) toks)
::
::  +golden: both stages printed, or the rendered error
::
::    tokens: the layout pass's tokens, or its error if it found one
::    tree: the parser's tree, or the first error of either stage, which
::    the parser reports since it accepts no error token (2.0). A tree
::    whose spans break section 1's rules (+check-spans) gets a last
::    line saying how, "SPAN ERROR: …", so every golden case checks
::    them.
::
++  golden
  |=  [file=path src=@t]
  ^-  [tokens=@t tree=@t]
  =/  toks=(list token)  (layout file src)
  =/  bad=(unit error)  (layout-error file toks)
  :-  ?^  bad  (show-error src u.bad)
      (show-tokens toks)
  =/  par  (parse-tokens file toks)
  ?:  ?=(%| -.par)  (show-error src p.par)
  ::  a parser that accepted an error token would be wrong; say so
  ?^  bad
    %^  cat  3  (show-error src u.bad)
    '\0aPARSER ERROR: the parser accepted an error token'
  =/  tree=@t  (show-module p.par)
  =/  why=(unit tape)  (check-spans p.par toks)
  ?~  why  tree
  (cat 3 tree (crip "\0aSPAN ERROR: {u.why}"))
::
+|  %lexer
::
::  +lexer: the layout pass (section 2), a door over its state
::
::    It reads the text as one tape, a line at a time, keeps its tokens
::    last first and flops them at the end, so its time is linear in the
::    text. Each +step reads a line's indentation, one token or the end of
::    a line, and returns the door; +run steps until the text ends or an
::    error token stops it (2.0). Every loop is a trap whose recursive
::    call is a tail call, so a long file grows no stack.
::
++  lexer
  |_  $:  cs=tape                       ::  the text not yet read
          lin=@ud                       ::  the line it starts on
          col=@ud                       ::  the column it starts at
          out=(list token)              ::  the tokens so far, last first
          lev=(list @ud)                ::  open levels, innermost first
          pend=loc                      ::  just past the last token
          dep=@ud                       ::  open interpolations (2.9)
          bol=?                         ::  at the start of a line
      ==
  ++  cor  .
  ::
  ::  +run: the tokens, to an error token or the end of the file
  ::
  ++  run
    ^-  (list token)
    =/  lx  cor
    |-  ^-  (list token)
    ?:  stopped:lx  (flop out.lx)
    ?:  &(bol.lx ?=(~ cs.lx))  (flop out:eof:lx)
    $(lx step:lx)
  ::
  ::  +stopped: whether an error token was emitted (2.0)
  ::
  ++  stopped  ?=([[* * [%error *]] *] out)
  ::
  ::  +eof: the end of the file (2.5): a DEDENT for each open level but
  ::  the first, then NEWLINE, all with empty spans just past the last
  ::  token; nothing in a file without tokens
  ::
  ++  eof
    ^+  cor
    ?~  out  cor
    =/  at=span  [pend pend]
    =/  n=@ud  (dec (max 1 (lent lev)))
    cor(out [[at | %newline] (weld (reap n `token`[at | %dedent]) out)])
  ::
  ::  +step: a line's indentation, or the line's next token or its end
  ::
  ++  step
    ^+  cor
    ?:  bol  indent:spaces
    read:spaces
  ::
  ::  +spaces: past the spaces at the head of the text
  ::
  ++  spaces
    ^+  cor
    |-  ^+  cor
    ?.  &(?=(^ cs) =(' ' i.cs))  cor
    $(cs t.cs, col +(col))
  ::
  ::  +next: past the end of the line, to the start of the next one
  ::
  ++  next
    ^+  cor
    ?~  cs  cor(bol &)
    cor(cs t.cs, lin +(lin), col 1, bol &)
  ::
  ::  +indent: a line, from its first character that isn't a space. A
  ::  blank or comment-only line gives nothing (2.3); another line gets
  ::  that character checked (2.2), then its layout tokens (2.4).
  ::
  ++  indent
    ^+  cor
    ?:  |(?=(~ cs) =('\0a' i.cs))  next
    ?:  &(=(':' i.cs) ?=(^ t.cs) =(':' i.t.cs))  next:comment
    =/  bad=(unit tape)  (bad-char i.cs)
    ?^  bad  (err col u.bad)
    ?:  (gte i.cs 128)  (err col non-ascii)
    ?~  out
      ?.  =(1 col)
        %+  err  col
        "the first line is indented: top-level lines start at column 1"
      cor(bol |)
    =/  top=@ud  ?~(lev 1 i.lev)
    ?:  (gth col top)  (lay(lev [col lev], bol |) 1 %indent)
    ?:  =(col top)  (lay(bol |) 1 %newline)
    =/  n=@ud  0
    =/  rest=(list @ud)  lev
    |-  ^+  cor
    ?:  &(?=(^ rest) (lth col i.rest))  $(n +(n), rest t.rest)
    ?.  &(?=(^ rest) =(col i.rest))  (err col (no-level lev))
    (lay:(lay(lev rest, bol |) n %dedent) 1 %newline)
  ::
  ::  +lay: n layout tokens g, spanning from just past the last token to
  ::  this line's first character (2.4); they leave pend as it is
  ::
  ++  lay
    |=  [n=@ud g=?(%indent %dedent %newline)]
    ^+  cor
    cor(out (weld (reap n `token`[[pend [lin col]] | g]) out))
  ::
  ::  +err: the error token, at column c of this line (2.0)
  ::
  ::    It also records where the text it was reading began, from, and
  ::    that text's first character: the parser moves the error there
  ::    when the place it is in can't begin with that character (section
  ::    3, Errors). Like any token, it is tight when that text follows the
  ::    last token with no space.
  ::
  ++  err
    |=  [c=@ud msg=tape]
    ^+  cor
    (err-from c msg [lin col] ?~(cs 0 i.cs))
  ::
  ::  +err-from: +err, where the text began at from with first
  ::
  ++  err-from
    |=  [c=@ud msg=tape from=loc first=@]
    ^+  cor
    cor(out [[[[lin c] [lin c]] =(from pend) [%error msg from first]] out])
  ::
  ::  +err-on: +err after a token cut from the front of the text that
  ::  fails, as 100 from 1000 or %1 from %1.0: the parser has taken that
  ::  token by the time it reaches the error, so the error token's text
  ::  begins at the error, column c, and its first character is the one
  ::  there (0 past the end of the text). The parser then never moves
  ::  it back (2.0, 2.8).
  ::
  ++  err-on
    |=  [c=@ud msg=tape]
    ^+  cor
    ?:  (lth c col)  (err c msg)
    =/  rest=tape  (slag (sub c col) cs)
    (err-from c msg [lin c] ?~(rest 0 i.rest))
  ::
  ::  +put: a token from beg to end on this line, with rest the text
  ::  after it, which starts at end
  ::
  ++  put
    |=  [beg=loc end=loc lex=lexeme rest=tape]
    ^+  cor
    %=  cor
      out   [[[beg end] =(beg pend) lex] out]
      pend  end
      cs    rest
      col   col.end
    ==
  ::
  ::  +emit: a token of the next n characters, which are ASCII
  ::
  ++  emit
    |=  [n=@ud lex=lexeme]
    ^+  cor
    (put [lin col] [lin (add col n)] lex (slag n cs))
  ::
  ::  +comment: past a comment to the end of its line, checking its
  ::  characters (2.2)
  ::
  ++  comment
    ^+  cor
    |-  ^+  cor
    ?:  |(?=(~ cs) =('\0a' i.cs))  cor
    ?:  (in i.cs bad-mask)  (err col (need (bad-char i.cs)))
    $(cs t.cs, col (next-col col i.cs))
  ::
  ::  +read: the line's next token, or its end (2.6)
  ::
  ::    A token is told by its first characters a, b and c, where b and c
  ::    are 0 past the end of the text. Names, the most common, go first.
  ::
  ++  read
    ^+  cor
    ?:  |(?=(~ cs) =('\0a' i.cs))
      ?.  =(0 dep)  (err col "this `\{` has no `}` on its line")
      next
    =/  a=@  i.cs
    ?:  (is-lower a)  name
    =/  b=@  ?~(t.cs 0 i.t.cs)
    =/  c=@  ?~(t.cs 0 ?~(t.t.cs 0 i.t.t.cs))
    ?:  =('(' a)  (emit 1 %'(')
    ?:  =(')' a)  (emit 1 %')')
    ?:  =('[' a)  (emit 1 %'[')
    ?:  =(']' a)  (emit 1 %']')
    ?:  =('"' a)  (text |)
    ?:  =('}' a)
      ?:  =(0 dep)  (err col "this `}` closes no `\{`")
      (text(dep (dec dep)) &)
    ?:  (is-digit a)  (literal (run-len cs number-mask))
    ?:  =('%' a)  (percent b c)
    ?:  =('=' a)
      ?:  |(=('<' b) =('>' b))
        %+  err  +(col)
        "`={[b ~]}` is left out: names never shadow, and `.` reads imports too"
      ?:  =('=' b)
        (err +(col) "the closer `==` is left out: indentation covers it")
      (emit 1 %'=')
    ?:  =('`' a)  (emit 1 %'`')
    ?:  =('*' a)  (emit 1 %'*')
    ?:  =('_' a)  (emit 1 %'_')
    ?:  =('~' a)
      ?:  =('[' b)  (emit 2 %'~[')
      ?:  =('&' b)  (emit 2 %'~&')
      ?:  =('|' b)  (err +(col) "`~|` is left out: `~&` covers debugging")
      =/  n=@ud  (run-len t.cs knot-mask)
      ?:  =(0 n)  (emit 1 [%lit %null %n 0 '~'])
      (literal +(n))
    ?:  =('/' a)
      ?:  &(=(1 col) |(=('-' b) =('%' b) =('=' b)))
        (emit 2 ?:(=('-' b) %'/-' ?:(=('%' b) %'/%' %'/=')))
      ?:  =('+' b)
        (err +(col) "`/+` is left out: code also runs in the browser")
      segment:(emit 1 %'/')
    ?:  =('+' a)
      ?:  =('+' b)  (emit 2 %'++')
      ?:  =('$' b)  (emit 2 %'+$')
      (emit 1 %'+')
    ?:  =('|' a)
      ?:  &(=('=' b) =('(' c))  (emit 3 %'|=(')
      ?:  =('=' b)  (emit 2 %'|=')
      ?:  =('$' b)  (emit 2 %'|$')
      ?:  |(=('%' b) =('_' b) =('*' b))
        (err +(col) "`|{[b ~]}` is left out: modules are records")
      ?:  =('-' b)  (err +(col) "`|-` is left out: gates recurse by name")
      (err +(col) "`|` begins `|=`, `|=(` or `|$`")
    ?:  =('$' a)
      ?:  =('?' b)
        (err +(col) "`$?` is left out: a union is a `+$` with its cases below")
      ?:  &(=('-' b) =('(' c))  (emit 3 %'$-(')
      ?:  =('-' b)
        (err (add 2 col) "`$-` has only the wide form `$-(sample product)`")
      ?:  =('(' b)  (err +(col) "`$(…)` is left out: gates recurse by name")
      ?:  =('%' b)  (err +(col) "`$%` is left out: a union is a `+$` with its cases below")
      (err +(col) "`$` begins `$-(`")
    ?:  =('^' a)
      ?:  =('-' b)  (emit 2 %'^-')
      (err +(col) "`^` begins `^-`")
    ?:  =('?' a)
      ?:  =('-' b)  (emit 2 %'?-')
      ?:  &(=(':' b) !=(':' c))
        (err +(col) "`?:` is left out: `?-` is the branch")
      ?:  =('!' b)  (err +(col) "`?!` is left out: eq and not are gates")
      ::  Hoon's other ? runes; nothing in Jibb goes tight after a ? mold
      ?:  (in b wut-mask)
        (err +(col) "`?{[b ~]}` is left out: `?-` is the branch")
      (emit 1 %'?')
    ?:  =('!' a)
      ?:  =('!' b)  (emit 2 %'!!')
      ?:  =('>' b)
        (err +(col) "`!>` is left out: code also runs in the browser")
      (err +(col) "`!` begins only `!!`: `!x` is left out, as not is a gate")
    ?:  =('@' a)
      ?:  |(=('s' b) =('r' b))
        (err +(col) "signed and floating-point auras are left out of Jibb")
      =/  n=@ud  (run-len t.cs lower-mask)
      =/  rest=tape  (slag n t.cs)
      =?  n  &(?=(^ rest) (is-upper i.rest))  +(n)
      (emit +(n) [%aura (@ta (crip (scag n t.cs)))])
    ?:  (is-upper a)
      =>  (emit 1 [%tvar a])
      ?.  &(?=(^ cs) |((is-lower i.cs) (is-upper i.cs) (is-digit i.cs)))
        cor
      (err col "a type variable is one capital letter")
    ?:  =(':' a)
      ?.  =(0 dep)  (err col "a comment can't start inside `\{…}`")
      ?:  =(':' b)  comment
      ?:  =('~' b)
        (err +(col) "`:~` is left out: indentation covers it; write ~[…]")
      ?:  =('*' b)
        (err +(col) "`:*` is left out: indentation covers it; write […]")
      ?:  |(=('-' b) =('+' b) =('^' b) =('_' b))
        %+  err  +(col)
        "`:{[b ~]}` is left out: indentation covers it; write a cell as [a b]"
      ?:  &(=(pend [lin col]) ?=([[* * ?([%name *] [%wing *])] *] out))
        %+  err  +(col)
        %+  weld  "`a:b` is left out: names never shadow, "
        "and `.` reads imports too; write a.b"
      (err +(col) "a comment starts with `::`")
    ?:  =('.' a)
      ?:  =('=' b)  (err col "`.=` is left out: eq and not are gates")
      ?:  =('*' b)
        %+  err  col
        "`.*` is left out: names never shadow, and `.` reads imports too"
      (err col (unexpected a))
    ?:  =('-' a)
      ?:  =('-' b)
        (err col "the closer `--` is left out: indentation covers it")
      (err col (unexpected a))
    ?:  =(';' a)
      ?:  =(':' b)
        (err col "`;:` is left out: nest the calls, as (add a (add b c))")
      (err col "Sail's `;` runes are left out: layout is Jibb's elements")
    ?:  =('\'' a)  (err col "there is no '…' form: strings are \"…\"")
    ?:  =('{' a)
      (err col "unexpected `\{`: `\{…}` interpolates only inside a string")
    ?:  (gte a 128)  (err col non-ascii)
    =/  bad=(unit tape)  (bad-char a)
    ?^  bad  (err col u.bad)
    (err col (unexpected a))
  ::
  ::  +unexpected: the error for a character that starts no token (2.6),
  ::  with a hint where one helps
  ::
  ++  unexpected
    |=  a=@
    ^-  tape
    =/  what=tape  "unexpected `{[a ~]}`"
    ?:  =('.' a)  "{what}: a `.` joins the names of a wing, as title.p"
    ?:  =(',' a)  "{what}: items are separated by spaces"
    ?:  =('-' a)
      "{what}: a name starts with a letter, and Jibb has no operators"
    ?:  =('<' a)
      "{what}: there is no `<…>`, since `\{…}` prints a value by its aura"
    what
  ::
  ::  +percent: a token that starts with %, whose next characters are b
  ::  and c: %/, a loobean or a term (2.6)
  ::
  ++  percent
    |=  [b=@ c=@]
    ^+  cor
    ?:  =('/' b)  segment:(emit 2 %'%/')
    ?:  =('.' b)
      ?:  =('y' c)  (emit 3 [%lit %loobean %f 0 '%.y'])
      ?:  =('n' c)  (emit 3 [%lit %loobean %f 1 '%.n'])
      (err (add 2 col) "the loobeans are `%.y` and `%.n`")
    ?:  =('&' b)  (emit 2 [%lit %term %f 0 '%&'])
    ?:  =('|' b)  (emit 2 [%lit %term %f 1 '%|'])
    ?:  =('$' b)  (emit 2 [%lit %term %tas 0 '%$'])
    ?:  |(=(':' b) =('-' b) =('+' b) =('^' b) =('~' b))
      %+  err  +(col)
      "`%{[b ~]}` is left out: indentation covers it; a call is (f a b)"
    ?:  =('=' b)
      %+  err  +(col)
      "`%=` is left out: indentation covers it; write a change, as m(a=b)"
    =/  rest=tape  ?~(cs ~ t.cs)
    ?:  (is-lower b)
      =/  n=@ud  (run-len rest name-mask)
      =/  nam=tape  (scag n rest)
      =>  (emit +(n) [%lit %term %tas (crip nam) (crip ['%' nam])])
      ?.  &(?=(^ cs) |((is-upper i.cs) =('_' i.cs)))  cor
      (err col "names are lowercase letters, digits and -")
    ?:  (is-digit b)  (numeric-term (scag (run-len rest number-mask) rest))
    (err +(col) "`%` begins a term, a loobean or `%/`")
  ::
  ::  +numeric-term: % and a decimal, whose run, the characters a number
  ::  literal's run takes, is run (2.6)
  ::
  ::    The decimal is a number literal's (2.8): nuck:so reads the run,
  ::    and the error, if any, is where it stopped looking, one column on
  ::    for the %, so %1000 fails at its fourth digit as 1000 does. %0
  ::    alone is a term and no decimal goes on from its 0, so anything
  ::    after the 0 fails at once, as the x of %0x1f. Whatever was read
  ::    is a term token before the error token, as a number literal's is,
  ::    and the error token begins at the error (+err-on), so a place
  ::    that takes the term keeps the error there: `+$ x %1.0` fails at
  ::    1:10, as `++ x %1.0` does.
  ::
  ++  numeric-term
    |=  run=tape
    ^+  cor
    =/  n=@ud  (lent run)
    =/  red=[used=@ud val=@ud at=@ud]
      ?:  =('0' ?~(run 0 i.run))  [1 0 (add 2 col)]
      =/  ed=(like coin)  (nuck:so [[lin +(col)] run])
      ?~  q.ed  [0 0 q.p.ed]
      =/  con=coin  p.u.q.ed
      ?.  ?=([%$ %ud @] con)  [0 0 q.p.ed]
      [(sub n (lent q.q.u.q.ed)) q.p.con q.p.ed]
    =/  lex=lexeme
      [%lit %term %ud val.red (crip ['%' (scag used.red run)])]
    ?:  =(used.red n)  (emit +(n) lex)
    ?:  =(0 used.red)  (err-from at.red term-msg [lin col] '%')
    (err-on:(emit +(used.red) lex) at.red term-msg)
  ::
  ::  +name: a name, or a wing, names joined by dots (2.6)
  ::
  ++  name
    ^+  cor
    =|  ns=(list term)
    =|  len=@ud
    =/  rest=tape  cs
    |-  ^+  cor
    =/  n=@ud  (run-len rest name-mask)
    =/  nam=term  (@tas (crip (scag n rest)))
    =.  rest  (slag n rest)
    ?:  &(?=([@ @ *] rest) =('.' i.rest) (is-lower i.t.rest))
      $(ns [nam ns], len (add +(len) n), rest t.rest)
    =/  lex=lexeme  ?~(ns [%name nam] [%wing (flop [nam ns])])
    =>  (emit (add len n) lex)
    ?~  cs  cor
    ?:  |((is-upper i.cs) =('_' i.cs))
      (err col "names are lowercase letters, digits and -")
    ?.  =('.' i.cs)  cor
    (err +(col) "a `.` in a wing is followed by a name")
  ::
  ::  +segment: after / or %/, a run of knot characters as one knot
  ::  token, tight (2.7)
  ::
  ++  segment
    ^+  cor
    =/  n=@ud  (run-len cs knot-mask)
    =>  ?:(=(0 n) cor (emit n [%knot (@ta (crip (scag n cs)))]))
    ::  what follows a segment: / ( [, a closer, a comment or a space
    ?.  &(?=(^ cs) (in i.cs seg-bad-mask))  cor
    %+  err  col
    ;:  weld
      "unexpected `{[i.cs ~]}`: "
      ?:  =('?' i.cs)  "a path carries no query, and a "
      ?:  =('#' i.cs)  "a path carries no fragment, and a "
      "a path "
      "segment holds lowercase letters, digits and - . ~ _"
    ==
  ::
  ::  +literal: a number or a ~ literal, the next n characters, read by
  ::  Hoon's own parser, nuck:so (2.8)
  ::
  ++  literal
    |=  n=@ud
    ^+  cor
    =/  run=tape  (scag n cs)
    =/  a=@  ?~(run 0 i.run)
    =/  b=@  ?~(run 0 ?~(t.run 0 i.t.run))
    ::  0b 0c 0i 0w, ~- and ~~ begin auras Jibb doesn't write, whatever
    ::  follows; Hoon's reader of ~- (@c) crashes on a control character
    ?:  &(=('0' a) |(=('b' b) =('c' b) =('i' b) =('w' b)))
      (err +(col) "Jibb writes no @u{[b ~]} literals")
    ?:  &(=('~' a) =('-' b))  (err +(col) "Jibb writes no @c literals")
    ?:  &(=('~' a) =('~' b))
      (err +(col) "Jibb writes no @t literals; strings are \"…\"")
    ::  ~0 and a base-32 digit begin a blob, which Hoon's reader cues, and
    ::  cue can run out of memory, which nothing catches; no Jibb literal
    ::  goes on so (a date's year has no leading 0)
    =/  c=@  ?~(run 0 ?~(t.run 0 ?~(t.t.run 0 i.t.t.run)))
    ?:  &(=('~' a) =('0' b) (in c b32-mask))
      ?:  (is-digit c)  (err (add 2 col) (literal-msg run %da))
      (err (add 2 col) "Jibb writes no blob literals")
    ::  a year BC that Hoon's dates can't hold, which its date code
    ::  crashes on: an error at the - that makes it BC
    =/  bc=(unit [at=@ud y=@ud])  (year-bc col run)
    ?:  &(?=(^ bc) =(0 y.u.bc))
      (err at.u.bc "there is no year 0 BC: 1 BC is ~1-, as ~1-.1.1")
    ?:  &(?=(^ bc) (gth y.u.bc 292.277.024.401))
      (err at.u.bc "Hoon's dates begin in 292.277.024.401 BC")
    ::  a fifth sub-second group, which Hoon's +yule crashes on
    =/  five=(unit @ud)  (fifth-group run)
    ?^  five
      %+  err  (add col u.five)
      "a date or duration takes at most four sub-second groups"
    ::  Hoon's date code reads dates and durations, and has crashed on
    ::  forms the checks above now stop; it runs under mule, in case
    =/  try=(each (like coin) tang)
      ?.  (is-time run)  [%& (nuck:so [[lin col] run])]
      (mule |.((nuck:so [[lin col] run])))
    ?:  ?=(%| -.try)  (err col "Jibb can't read this literal")
    =/  ed=(like coin)  p.try
    ?~  q.ed  (err q.p.ed (literal-msg run %$))
    =/  used=@ud  (sub n (lent q.q.u.q.ed))
    =/  con=coin  p.u.q.ed
    ?:  =(0 used)  (err col (literal-msg run %$))
    ?.  ?=([%$ *] con)  (err +(col) "Jibb writes no such literal")
    =/  form=(unit lit-form)  (lit-form-of p.p.con)
    ?~  form
      %+  err  +(col)
      %+  weld  "Jibb writes no @{(trip p.p.con)} literals"
      ?:(=(%t p.p.con) "; strings are \"…\"" "")
    =/  lex=lexeme  [%lit u.form p.p.con q.p.con (crip (scag used run))]
    ?:  =(used n)
      ?.  =(%ta p.p.con)  (emit n lex)
      ::  a ~. knot is followed as a path segment is (2.7)
      =>  (emit n lex)
      ?.  &(?=(^ cs) (in i.cs seg-bad-mask))  cor
      %+  err  col
      %+  weld  "unexpected `{[i.cs ~]}`: "
      "a knot holds lowercase letters, digits and - . ~ _"
    ::  the error goes where Hoon's parser stopped looking; after a ship,
    ::  or a bare ~ that a letter follows, at the first letter that no
    ::  syllable continues (+ship-stop), or past a duration's unit, d h m
    ::  or s, if that is later (2.8)
    =/  at=@ud  q.p.ed
    =?  at  &(=('~' a) (is-lower b) ?=(?(%n %p) p.p.con))
      =/  dur=@ud  ?:(|(=('d' b) =('h' b) =('m' b) =('s' b)) 2 1)
      (min at (add col (max dur (ship-stop run))))
    ::  the run's first part is a token, which the parser takes before
    ::  it reaches the error, so the error token begins at the error
    (err-on:(emit used lex) at (literal-msg run p.p.con))
  ::
  ::  +text: a string's text, from its opening " or the } that closes
  ::  an interpolation, through the " or { that ends it (2.9). mid: it
  ::  resumes after a }, so it is str-mid or str-tail, not str-head or str.
  ::
  ++  text
    |=  mid=?
    ^+  cor
    =/  beg=loc  [lin col]
    =/  rest=tape  ?~(cs ~ t.cs)
    =/  at=@ud  +(col)
    =|  acc=tape
    |-  ^+  cor
    ?:  |(?=(~ rest) =('\0a' i.rest))
      (err at "this string has no closing `\"` on its line")
    =/  ch=@  i.rest
    ?:  =('"' ch)
      =/  txt=@t  (crip (flop acc))
      (put beg [lin +(at)] ?:(mid [%str-tail txt] [%str txt]) t.rest)
    ?:  =('{' ch)
      =/  txt=@t  (crip (flop acc))
      =>  (put beg [lin +(at)] ?:(mid [%str-mid txt] [%str-head txt]) t.rest)
      cor(dep +(dep))
    ?:  =('\\' ch)
      ?~  t.rest  (err +(at) bad-escape)
      =/  d=@  i.t.rest
      ?:  |(=('\\' d) =('"' d) =('{' d))
        $(rest t.t.rest, at (add 2 at), acc [d acc])
      =/  bd=(unit tape)  (bad-char d)
      ?^  bd  (err +(at) u.bd)
      ?.  (is-hex d)  (err +(at) bad-escape)
      ?~  t.t.rest  (err (add 2 at) bad-hex)
      =/  e=@  i.t.t.rest
      =/  be=(unit tape)  (bad-char e)
      ?^  be  (err (add 2 at) u.be)
      ?.  (is-hex e)  (err (add 2 at) bad-hex)
      %=  $
        rest  t.t.t.rest
        at    (add 3 at)
        acc   [(add (mul 16 (hex-val d)) (hex-val e)) acc]
      ==
    ?:  =(1 (cut 0 [ch 1] bad-mask))  (err at (need (bad-char ch)))
    %=  $
      rest  t.rest
      at    ?:(=(1 (cut 0 [ch 1] cont-mask)) at +(at))
      acc   [ch acc]
    ==
  --
::
::  +bad-char: the error for a character that no text may hold (2.2)
::
++  bad-char
  |=  c=@
  ^-  (unit tape)
  ?:  =(9 c)  `"a tab: Jibb uses spaces only"
  ?:  =(13 c)  `"a carriage return: Jibb lines end with a line feed alone"
  ?:  |((lth c 32) =(127 c))  `"a control character"
  ~
::
++  non-ascii  "non-ASCII text outside a string or comment"
++  term-msg
  %+  weld  "a numeric term is `%` and a decimal, "
  "digits in groups of three joined by dots, as %1.000"
++  bad-escape  "a `\\` begins `\\\\`, `\\\"`, `\\\{` or two hex digits"
++  bad-hex  "a `\\` escape takes two lowercase hex digits, as `\\0a`"
::
::  Character classes are masks, bit c set for each character c in the
::  class, so a test is one (cut 0 [c 1] mask) rather than a chain of
::  comparisons.
::
++  lower-mask   0x7ff.fffe.0000.0000.0000.0000.0000.0000  ::  a-z
++  upper-mask   0x7ff.fffe.0000.0000.0000.0000           ::  A-Z
++  digit-mask   0x3ff.0000.0000.0000                      ::  0-9
++  hex-mask     0x7e.0000.0000.03ff.0000.0000.0000        ::  0-9 a-f
++  name-mask    0x7ff.fffe.0000.0000.03ff.2000.0000.0000  ::  a-z 0-9 -
++  knot-mask    0x47ff.fffe.8000.0000.03ff.6000.0000.0000 ::  and . ~ _
++  number-mask  0x7ff.fffe.07ff.fffe.03ff.4000.0000.0000  ::  a-z A-Z 0-9 .
++  bad-mask     0x8000.0000.0000.0000.0000.0000.ffff.fbff ::  2.2
::  after a path segment (2.7): printable, but not a knot character,
::  / ( [ ) ] } or :
++  seg-bad-mask    0x1800.0001.57ff.ffff.f800.1cfe.0000.0000
::  after a ? glyph, Hoon's ? runes but ?- ?: and ?! (2.6): + ~ = . @ ^ & | < >
++  wut-mask    0x5000.0000.4000.0001.7000.4840.0000.0000
::  base-32 digits: 0-9 a-v
++  b32-mask    0x7f.fffe.0000.0000.03ff.0000.0000.0000
::
::  What may begin each place the parser reads (section 3, Errors):
::    an expression    a-z 0-9 " ( [ ~ % / ` | ^ ? !
::    an operand       a-z 0-9 " ( [ ~ % / ` | !
::    a mold           a-z A-Z @ * ! ? ~ % / ( [ $ _
::    a pattern        a-z 0-9 " ~ % * [
::  and what may go tight after an operand: . ( + = after a name, a
::  closer ) ] }, or the : of a comment
::
++  expr-mask     0x57ff.ffff.4800.0000.83ff.8126.0000.0000
++  operand-mask  0x57ff.ffff.0800.0000.03ff.8126.0000.0000
++  mold-mask     0x47ff.fffe.8fff.ffff.8000.8532.0000.0000
++  bar-mask      0x1000.0000.0000.0000.0000.0000.0000.0000
++  pattern-mask  0x47ff.fffe.0800.0000.03ff.0424.0000.0000
++  after-mask    0x2000.0000.2000.0000.2400.4b00.0000.0000
++  plus-mask     0x800.0000.0000                            ::  +
++  cen-mask      0x20.0000.0000                             ::  %
++  fas-mask      0x8000.0000.0000                           ::  /
++  tis-mask      0x2000.0000.0000.0000                      ::  =
++  pat-mask      0x1.0000.0000.0000.0000                    ::  @
++  sel-mask      0x800.0000.0000.0000.0000.0000             ::  [
++  ser-mask      0x2000.0000.0000.0000.0000.0000            ::  ]
::
::  +cont-mask: UTF-8 continuation bytes, 10xx.xxxx, which start no
::  column (1)
::
++  cont-mask
  0xffff.ffff.ffff.ffff.0000.0000.0000.0000.0000.0000.0000.0000
::
++  in         |=([c=@ m=@] =(1 (cut 0 [c 1] m)))
++  is-lower   |=(c=@ (in c lower-mask))
++  is-upper   |=(c=@ (in c upper-mask))
++  is-digit   |=(c=@ (in c digit-mask))
++  is-hex     |=(c=@ (in c hex-mask))
++  hex-val    |=(c=@ ^-(@ ?:((is-digit c) (sub c '0') (sub c 87))))
::
::  +next-col: the column after character c at column col
::
++  next-col
  |=  [col=@ud c=@]
  ^-  @ud
  ?:(=(1 (cut 0 [c 1] cont-mask)) col +(col))
::
::  +run-len: how many characters at the head of cs are in class m
::
++  run-len
  |=  [cs=tape m=@]
  ^-  @ud
  =|  n=@ud
  |-  ^-  @ud
  ?~  cs  n
  ?.  =(1 (cut 0 [`@`i.cs 1] m))  n
  $(cs t.cs, n +(n))
::
::  +decimal: digits as a number
::
++  decimal
  |=  ds=tape
  ^-  @ud
  (roll ds |=([d=@ a=@ud] (add (mul 10 a) (sub d '0'))))
::
::  +lit-form-of: the literal rule of a dime's aura, if Jibb takes it (2.8)
::
++  lit-form-of
  |=  aura=@ta
  ^-  (unit lit-form)
  ?+  aura  ~
    %ud  `%number
    %ux  `%number
    %uv  `%number
    %p   `%ship
    %da  `%date
    %dr  `%duration
    %ta  `%knot
    %n   `%null
  ==
::
::  +literal-msg: why a literal stops where nuck:so stops (2.8), told by
::  its first characters and the aura of what nuck:so read
::
++  literal-msg
  |=  [run=tape aura=@ta]
  ^-  tape
  =/  a=@  ?~(run 0 i.run)
  =/  b=@  ?~(run 0 ?~(t.run 0 i.t.run))
  ?.  =('~' a)
    ?:  &(=('0' a) =('x' b))
      %+  weld  "a hexadecimal number is 0x and digits 0-9 and a-f, "
      "in groups of four joined by dots, as 0x1.ffff"
    ?:  &(=('0' a) =('v' b))
      %+  weld  "a base-32 number is 0v and digits 0-9 and a-v, "
      "in groups of five joined by dots, as 0v5.fdf99"
    "a decimal is digits in groups of three joined by dots, as 1.000"
  ?:  |(=(%da aura) &(=(%n aura) (is-digit b)))
    %+  weld  "a date is ~year.month.day, then optionally "
    "..hours.minutes.seconds, as ~2026.10.23..14.30.00"
  ?:  =(%dr aura)
    "a duration is units of d, h, m and s joined by dots, as ~h1.m30"
  ?:  =(%p aura)
    %+  weld  "a ship is syllables in pairs joined by hyphens, "
    "as ~zod, ~marzod or ~sampel-palnet"
  %+  weld  "`~` alone is null, and nothing here reads as a ship, "
  "date, duration or knot"
::
::  +year-bc: a ~ literal run's year and the column of its -, if it
::  starts as a date BC does, ~ then digits Hoon reads as a year, then -
::
::    Hoon's +year crashes on a year BC of 0 or past 292.277.024.401, as
::    in ~0-.1.1, so these never reach nuck:so (2.8).
::
++  year-bc
  |=  [col=@ud run=tape]
  ^-  (unit [at=@ud y=@ud])
  ?.  ?=([%'~' @ *] run)  ~
  =/  tr=tape  t.run
  =/  ds=tape  (scag (run-len tr digit-mask) tr)
  ?~  ds  ~
  ::  a year is 0 or has no leading 0, as dim:ag reads it
  ?:  &(=('0' i.ds) ?=(^ t.ds))  ~
  =/  rest=tape  (slag (lent ds) tr)
  ?.  ?=([%'-' *] rest)  ~
  `[(add col +((lent ds))) (decimal ds)]
::
::  +fifth-group: where in a ~ literal's run, counting from its ~, the
::  dot that begins a fifth sub-second group is, if the first four are
::  well formed
::
::    Sub-seconds follow a duration's first .. or a date's second, as in
::    ~s1..0000 and ~2026.10.23..14.30.00..0000: groups of four
::    lowercase hex digits joined by dots. Hoon's reader takes any
::    number, and its +yule crashes on a fifth (2.8).
::
++  fifth-group
  |=  run=tape
  ^-  (unit @ud)
  =/  b=@  ?.(?=([%'~' @ *] run) 0 i.t.run)
  =/  k=@ud
    ?:  (is-digit b)  2
    ?:(|(=('d' b) =('h' b) =('m' b) =('s' b)) 1 0)
  ?:  =(0 k)  ~
  =/  past=(unit [i=@ud cs=tape])  (past-dots k 0 run)
  ?~  past  ~
  =/  i=@ud  i.u.past
  =/  cs=tape  cs.u.past
  =/  g=@ud  1
  |-  ^-  (unit @ud)
  =/  quad=tape  (scag 4 cs)
  ?.  &(=(4 (lent quad)) (levy quad is-hex))  ~
  =.  cs  (slag 4 cs)
  =.  i  (add 4 i)
  ?.  ?=([%'.' *] cs)  ~
  ?:  =(4 g)  `i
  $(g +(g), i +(i), cs t.cs)
::
::  +past-dots: where the text past the k-th .. of cs starts, counting
::  from i, and that text
::
++  past-dots
  |=  [k=@ud i=@ud cs=tape]
  ^-  (unit [i=@ud cs=tape])
  ?~  cs  ~
  ?.  &(=('.' i.cs) ?=(^ t.cs) =('.' i.t.cs))
    $(i +(i), cs t.cs)
  ?:  =(1 k)  `[(add 2 i) t.t.cs]
  $(k (dec k), i (add 2 i), cs t.t.cs)
::
::  +is-time: whether a ~ literal's run starts as a date or a duration
::  does, which Hoon's date code reads (2.8)
::
++  is-time
  |=  run=tape
  ^-  ?
  ?.  ?=([%'~' @ *] run)  |
  ?:  (is-digit i.t.run)  &
  ?&  |(=('d' i.t.run) =('h' i.t.run) =('m' i.t.run) =('s' i.t.run))
      ?=([@ @ @ *] run)
      (is-digit i.t.t.run)
  ==
::
::  +ship-stop: how many characters of a ~ literal's run, from its ~,
::  could still begin a ship (2.8)
::
::    Hoon's parser reads a syllable's three letters before it looks
::    them up, so it stops past the first letter that no syllable
::    continues; this stops at that letter. It takes a galaxy's suffix,
::    or words of a prefix and a suffix joined by - or --, as many as
::    come. That is a few more texts than Hoon reads, so it never stops
::    before Hoon's parser could have gone on.
::
++  ship-stop
  |=  run=tape
  ^-  @ud
  =/  cs=tape  ?~(run ~ t.run)
  =/  pre=@ud  (syllable cs sis:po)
  ::  a galaxy's suffix, or a word's prefix
  ?.  =(3 pre)  +((max pre (syllable cs dex:po)))
  =/  i=@ud  4
  =.  cs  (slag 3 cs)
  |-  ^-  @ud
  ::  the word's suffix
  =/  suf=@ud  (syllable cs dex:po)
  ?.  =(3 suf)  (add i suf)
  =.  i  (add i 3)
  =.  cs  (slag 3 cs)
  ::  then - or --, and the next word's prefix
  ?.  &(?=(^ cs) =('-' i.cs))  i
  =/  h=@ud  ?:(&(?=([@ @ *] cs) =('-' i.t.cs)) 2 1)
  =/  word=tape  (slag h `tape`cs)
  =/  nex=@ud  (syllable word sis:po)
  ?.  =(3 nex)  :(add i h nex)
  $(i :(add i h 3), cs (slag 3 word))
::
::  +syllable: how many of cs's first three characters begin one of the
::  256 syllables in syls, the prefixes or suffixes of +po
::
++  syllable
  |=  [cs=tape syls=@t]
  ^-  @ud
  =/  l=tape  (scag 3 cs)
  =/  k=@ud  0
  |-  ^-  @ud
  ?:  =(k (lent l))  k
  =/  head=@  (crip (scag +(k) l))
  ?.  (lien (gulf 0 255) |=(i=@ =(head (cut 3 [(mul 3 i) +(k)] syls))))
    k
  $(k +(k))
::
::  +no-level: the error for a line that returns to no open level (2.4),
::  naming the open levels' columns, outermost first
::
++  no-level
  |=  lev=(list @ud)
  ^-  tape
  %+  weld
    "this line's indentation matches no enclosing line: indent it to column "
  (join-or (turn (flop lev) |=(c=@ud (a-co:co c))))
::
::  +join-or: words as "a", "a or b", "a, b or c"
::
++  join-or
  |=  ws=(list tape)
  ^-  tape
  ?~  ws  ""
  ?~  t.ws  i.ws
  ?~  t.t.ws  "{i.ws} or {i.t.ws}"
  "{i.ws}, {$(ws t.ws)}"
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
    (show-loc (where t))
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
    %error     "ERROR {p.x}"
  ==
::
::  +show-module: the tree as S-expressions (format: section 4.2)
::
++  show-module
  |=  mod=module
  ^-  @t
  =/  kids=(list sexp)
    (weld (turn imports.mod sexp-import) (turn defs.mod sexp-def))
  ?~  kids  '(module)'
  (of-wain:format (render kids))
::
::  +show-error: "<file>:<line>:<col>: <message>", the line, a caret
::
::    In the excerpt a control character prints as a space (4.3).
::
++  show-error
  |=  [src=@t err=error]
  ^-  @t
  =/  lines=wain  (to-wain:format src)
  =/  text=@t
    ?:  |(=(0 line.err) (gth line.err (lent lines)))  ''
    (snag (dec line.err) lines)
  =/  excerpt=tape
    %+  turn  (trip text)
    |=(c=@tD ?:(|((lth c 32) =(127 c)) ' ' c))
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
    excerpt
    "\0a"
    (reap (dec (max 1 col.err)) ' ')
    "^"
  ==
::
::  +show-found: a token as error messages name it
::
::    A layout token with an empty span is at the end of the file (2.5).
::
++  show-found
  |=  t=token
  ^-  tape
  =/  x=lexeme  lex.t
  ?@  x
    ?:  &(?=(?(%indent %dedent %newline) x) =(beg.at.t end.at.t))
      "the end of the file"
    ?+  x  "`{(trip x)}`"
      %indent   "a deeper line"
      %dedent   "a shallower line"
      %newline  "a line at the same depth"
      %'`'      "`` ` ``"
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
    %error     "an error"
  ==
::
::  +where: where a token is, for errors and the token printer
::
::    At the token's start; for a layout token, at the end of its span:
::    the start of the line it begins, or at the end of the file just
::    past the last token (2.4, 2.5).
::
++  where
  |=  t=token
  ^-  loc
  ?:  ?=(?(%indent %dedent %newline) lex.t)  end.at.t
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
::  +show-lit: a literal as written for atoms read by nuck:so, whose
::  printing differs between Hoon versions (@da), and for terms, whose
::  one form is as written (%1.000); loobeans and ~ in their one form
::
++  show-lit
  |=  l=lit
  ^-  tape
  ?-  form.l
    ?(%number %ship %date %duration %knot %term)  (trip txt.l)
    %loobean   ?:(=(0 val.l) "%.y" "%.n")
    %null      "~"
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
    %inferred  "/[{(trip name.s)}=_]"
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
::  +render: a module's kids as the tree's lines (4.2)
::
::    A node whose kids are all leaves goes on one line; else its head,
::    then each kid a level deeper, and its ) at the end of its last
::    kid's last line; (module …) always breaks. Each line is built once,
::    from its depth: a line deeper than 64 levels keeps 64 levels'
::    indent and says its depth, as |65| (group 3:1 …), so printing is
::    linear in the tree's size however deep it nests. Each line becomes
::    a cord as soon as it is built: as a tape, a character takes some
::    24 bytes, and holding the lines of a tree 100.000 levels deep made
::    +golden half again as slow.
::
++  render
  |=  kids=(list sexp)
  ^-  wain
  =/  acc=(list pline)  ~[[0 "(module" 0]]
  =.  acc
    |-  ^-  (list pline)
    ?~  kids  acc
    $(kids t.kids, acc (put-sexp 1 i.kids acc))
  (flop (turn (shut-last acc) |=(l=pline (crip (show-pline l)))))
::
::  +pline: a printed line: its depth, its text, and how many )s end it
::
+$  pline  [dep=@ud txt=tape shut=@ud]
::
::  +put-sexp: a node's lines at depth dep, last first, onto acc
::
++  put-sexp
  |=  [dep=@ud s=sexp acc=(list pline)]
  ^-  (list pline)
  ?:  ?=(%atom -.s)  [[dep p.s 0] acc]
  ?:  (levy kids.s is-leaf)  [[dep (flat s) 0] acc]
  =/  ks=(list sexp)  kids.s
  =.  acc  [[dep "({head.s}" 0] acc]
  |-  ^-  (list pline)
  ?~  ks  (shut-last acc)
  $(ks t.ks, acc (put-sexp +(dep) i.ks acc))
::
::  +shut-last: one more ) at the end of the last line
::
++  shut-last
  |=  acc=(list pline)
  ^-  (list pline)
  ?~  acc  ~
  [i.acc(shut +(shut.i.acc)) t.acc]
::
++  show-pline
  |=  l=pline
  ^-  tape
  =/  pad=tape
    ?:  (lte dep.l 64)  (reap (mul 2 dep.l) ' ')
    "{(reap 128 ' ')}|{(a-co:co dep.l)}| "
  :(weld pad txt.l (reap shut.l ')'))
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
    %cell  (nod "cell" at.s "" (turn items.s sexp-sample))
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
    %hole     (nod "hole" at.s "" ~)
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
::  +span-of: the span of a tagged node, [%tag at=span …]; an +item,
::  +edit or +arm has its span at its head, at.node
::
++  span-of
  |*  node=[@ span *]
  ^-  span
  +<.node
::
::  +fail: the error "expected <want>, found <the next token>"
::
::    At the layout pass's error instead (+lexer-error). The token list
::    always ends with NEWLINE or an error token (2.5), and the parser
::    stops at either, so it never runs out; if it did, the error would
::    sit at 1:1.
::
++  fail
  |=  [file=path toks=(list token) want=tape]
  ^-  [%| p=error]
  ?~  toks  [%| file 1 1 "expected {want}, found the end of the tokens"]
  =/  lex=(unit error)  (lexer-error file toks)
  ?^  lex  [%| u.lex]
  =/  l=loc  (where i.toks)
  [%| file line.l col.l "expected {want}, found {(show-found i.toks)}"]
::
::  +lexer-error: the layout pass's error, where the parser fails at it
::
::    At an error token, its error. At layout tokens followed by an error
::    token whose text begins the line, both errors point at the line's
::    start (+where), and the layout pass's message, about that text,
::    says more: a line `==` closing a ?- is "the closer `==` is left
::    out", not "expected the end of the body".
::
++  lexer-error
  |=  [file=path toks=(list token)]
  ^-  (unit error)
  ?~  toks  ~
  ?:  ?=([%error *] lex.i.toks)
    `[file line.beg.at.i.toks col.beg.at.i.toks p.lex.i.toks]
  ?.  (is-layout i.toks)  ~
  =/  l=loc  (where i.toks)
  =/  rest=(list token)  t.toks
  |-  ^-  (unit error)
  ?~  rest  ~
  ?:  (is-layout i.rest)  $(rest t.rest)
  ?.  ?=([%error *] lex.i.rest)  ~
  ?.  =(l from.lex.i.rest)  ~
  `[file line.l col.l p.lex.i.rest]
::
::  +fail-in: +fail where the next token begins a place, such as an
::  expression or a mold, whose first character is one of the mask can
::
::    The error points at the first character where the text stops being
::    the start of any valid module (2.0), so at a token the place can't
::    take, just past the part of it the place could: none if the place
::    can't begin with its first character; a wing's first name, as in
::    `++ a.b`, where a name goes; else that first character, as the ~ of
::    ~zod where a mold goes (~ alone is one). At an error token whose
::    text begins with a character the place can't, the error moves to
::    that character, with the layout pass's message: `++ x @sd` fails
::    at the @, since no expression begins with @, while `+$ x @sd`
::    fails at the s. Every place that reaches this at a layout token
::    needs text on its line, so the error is at the line's end
::    (+fail-line): `++ x ^-` above a deeper line fails at 1:8.
::
++  fail-in
  |=  [file=path toks=(list token) want=tape can=@]
  ^-  [%| p=error]
  ?~  toks  (fail file toks want)
  =*  t  i.toks
  ?:  ?=([%error *] lex.t)
    ::  a : could begin a comment anywhere, which this leaves out
    ?:  |(=(':' c.lex.t) (in c.lex.t can))  (fail file toks want)
    [%| (moved file want t)]
  ?:  (is-layout t)  (fail-line file toks want "")
  =/  n=@ud  (prefix t can)
  =/  e=[%| p=error]  (fail file toks want)
  e(col.p (add n col.p.e))
::
::  +prefix: how many of the first characters of a token that a place
::  can't take could still begin it, the place beginning with a
::  character of the mask can (+fail-in)
::
++  prefix
  |=  [t=token can=@]
  ^-  @ud
  ?.  (in (first-char t) can)  0
  ?.  ?=([%wing *] lex.t)  1
  ?~(p.lex.t 1 (met 3 i.p.lex.t))
::
::  +first-char: a token's first character, or one like it: a number
::  begins with a digit, ~zod with ~ and %add with %
::
++  first-char
  |=  t=token
  ^-  @
  =/  x=lexeme  lex.t
  ?@  x  ?:(?=(?(%indent %dedent %newline) x) 0 (end 3 x))
  ?-  -.x
    %name      (end 3 p.x)
    %wing      ?~(p.x 0 (end 3 i.p.x))
    %str       '"'
    %str-head  '"'
    %str-mid   '}'
    %str-tail  '}'
    %knot      (end 3 p.x)
    %aura      '@'
    %tvar      (end 3 p.x)
    %error     c.x
  ::
      %lit
    ?-  form.p.x
      %number                                  '0'
      ?(%term %loobean)                        '%'
      ?(%ship %date %duration %knot %null)     '~'
    ==
  ==
::
::  +fail-space: a tight form found no next token right after prev
::
::    The error sits just past prev, the token that needs its next one
::    at once, where the space or the end of the line starts (section 3,
::    Errors): no deeper line can supply a tight form's next token. So
::    does an error token past a space or on a later line, whose error
::    comes after. A tight error token's text begins right after prev,
::    and its error is +fail's. why is a hint, if not empty.
::
++  fail-space
  |=  [file=path prev=token toks=(list token) want=tape why=tape]
  ^-  [%| p=error]
  =/  at=loc  end.at.prev
  ?:  &(?=(^ toks) ?=([%error *] lex.i.toks) =(at from.lex.i.toks))
    (fail file toks want)
  =/  found=tape
    ?~  toks  "the end of the file"
    =*  t  i.toks
    ?:  (is-layout t)
      ?:(=(beg.at.t end.at.t) "the end of the file" "the end of the line")
    ?:  &(?=([%error *] lex.t) !=(line.at line.from.lex.t))
      "the end of the line"
    "a space"
  =/  msg=tape
    "expected {want} right after {(show-found prev)}, found {found}"
  [%| file line.at col.at ?~(why msg "{msg}; {why}")]
::
::  +fail-line: +fail where the place needs text on the line that toks
::  ends, as a rune's mold or what a bracket that closes on its line
::  still needs: at a layout token, at the end of that line, just past
::  its last token, where the token's span starts, "found the end of the
::  line", since no later line can supply it (2.0, section 3, Errors).
::  At the end of the file that is where +fail puts it. why is a hint,
::  if not empty, given only at the end of a line.
::
++  fail-line
  |=  [file=path toks=(list token) want=tape why=tape]
  ^-  [%| p=error]
  ?.  ?&  ?=(^ toks)
          (is-layout i.toks)
          !=(beg.at.i.toks end.at.i.toks)
      ==
    (fail file toks want)
  =/  at=loc  beg.at.i.toks
  =/  msg=tape  "expected {want}, found the end of the line"
  [%| file line.at col.at ?~(why msg "{msg}; {why}")]
::
::  +fail-why: +fail with a hint after its message, "; <why>"
::
::    The layout pass's error (+lexer-error) stays as it is (2.0).
::
++  fail-why
  |=  [file=path toks=(list token) want=tape why=tape]
  ^-  [%| p=error]
  =/  e=[%| p=error]  (fail file toks want)
  ?^  (lexer-error file toks)  e
  e(msg.p (weld msg.p.e "; {why}"))
::
::  +fail-in-why: +fail-in with a hint, as +fail-why
::
++  fail-in-why
  |=  [file=path toks=(list token) want=tape can=@ why=tape]
  ^-  [%| p=error]
  =/  e=[%| p=error]  (fail-in file toks want can)
  ?:  &(?=(^ toks) ?=([%error *] lex.i.toks))  e
  ?^  (lexer-error file toks)  e
  e(msg.p (weld msg.p.e "; {why}"))
::
::  +tight-error: the error at an error token tight after an operand or
::  an item, if its text's first character can't go there: the layout
::  pass's message, at that character (+fail-in)
::
::    What may go tight after an item is a closer, a comment's :, or,
::    after a name, the ( . + or = of a change, a wing, a pair or a face
::    (after-mask, which doesn't look at what the item was).
::
++  tight-error
  |=  [file=path toks=(list token)]
  ^-  (unit error)
  (tight-error-in file toks after-mask)
::
::  +tight-error-in: +tight-error where what may go tight is can, as no
::  = goes tight after a call's operand, which takes no face
::
++  tight-error-in
  |=  [file=path toks=(list token) can=@]
  ^-  (unit error)
  ?.  ?=([[* %& [%error *]] *] toks)  ~
  ?:  (in c.lex.i.toks can)  ~
  `(moved file "a space between items" i.toks)
::
::  +moved: an error token's error, moved to the first character of the
::  text it was reading, which can't go where it is (+fail-in): "expected
::  <want>, found <that character>; <the layout pass's message>"
::
++  moved
  |=  [file=path want=tape t=token]
  ^-  error
  ?.  ?=([%error *] lex.t)  [file line.beg.at.t col.beg.at.t "expected {want}"]
  =*  x  lex.t
  ?:  =(from.x beg.at.t)  [file line.from.x col.from.x p.x]
  =/  what=tape  ?:(=('"' c.x) "a string" "`{[c.x ~]}`")
  [file line.from.x col.from.x "expected {want}, found {what}; {p.x}"]
::
::  Token tests for the parser
::
::  +is-layout: INDENT, DEDENT or NEWLINE
::
++  is-layout
  |=  t=token
  ^-  ?
  ?=(?(%indent %dedent %newline) lex.t)
::
::  +is-closer: ) or ], or the } that ends an interpolation
::
++  is-closer
  |=  t=token
  ^-  ?
  ?|  =(%')' lex.t)
      =(%']' lex.t)
      ?=([?(%str-mid %str-tail) *] lex.t)
  ==
::
::  +ends-call: a token that ends a call, or the operands on a group's
::  first line, without an error of their own: a layout token, a
::  closer, or the layout pass's error
::
++  ends-call
  |=  t=token
  ^-  ?
  ?|  (is-layout t)
      (is-closer t)
      ?=([%error *] lex.t)
  ==
::
::  +tail-can: what may begin text that goes on, on its line, after an
::  expression: more operands, as after a call or !!, or after a rune
::  what may go on after its last part (+bad-end-in)
::
++  tail-can
  |=  e=expr
  ^-  @
  ?+  -.e  operand-mask
    %cast   $(e val.e)
    %gate   $(e body.e)
  ==
::
::  +def-can: +tail-can after a definition: nothing after a mold
::
++  def-can
  |=  d=def
  ^-  @
  ?-  -.d
    %mold   0
    %value  (tail-can val.d)
  ==
::
::  +is-operand-start: a token an operand starts with; where an operand
::  goes, |= is the constructor's (section 3)
::
++  is-operand-start
  |=  t=token
  ^-  ?
  ?|  ?=(?(%'%/' %'/' %'`' %'(' %'~[' %'[' %'|=(' %'|=' %'!!') lex.t)
      ?=([?(%lit %str %str-head %name %wing) *] lex.t)
  ==
::
::  +is-rune: a rune that is never an operand: ^- ~& ?-
::
++  is-rune
  |=  t=token
  ^-  ?
  ?=(?(%'^-' %'~&' %'?-') lex.t)
::
::  +is-ctor: |= with a term tight after it, a case's constructor
::
++  is-ctor
  |=  ts=(list token)
  ^-  ?
  ?=([[* * %'|='] [* %& [%lit %term *]] *] ts)
::
::  +is-rune-start: a rune where an expression starts; |= is a rune
::  there unless it is the constructor
::
++  is-rune-start
  |=  ts=(list token)
  ^-  ?
  ?~  ts  |
  ?|  (is-rune i.ts)
      &(=(%'|=' lex.i.ts) !(is-ctor ts))
  ==
::
::  +text-piece: a string's text as its pieces: none when it is empty
::
++  text-piece
  |=  txt=@t
  ^-  (list piece)
  ?:(=('' txt) ~ ~[[%text txt]])
::
::  +names-of: a name's or a wing's names
::
++  names-of
  |=  x=lexeme
  ^-  (list term)
  ?+  x  ~
    [%name *]  ~[p.x]
    [%wing *]  p.x
  ==
::
::  +call-of: a call's elements as one expression: one alone is itself
::
++  call-of
  |=  els=(list expr)
  ^-  expr
  ?~  els  [%crash *span ~]
  ?~  t.els  i.els
  [%call [beg:(span-of i.els) end:(span-of (rear t.els))] i.els t.els]
::
::  +bracket-node: a tuple, list or change from its items, ending at fin
::
++  bracket-node
  |=  $:  kind=?(%tuple %list %change)
          op=token
          target=(unit [t=token names=(list term)])
          its=(list item)
          fin=loc
      ==
  ^-  expr
  ?-    kind
    %tuple  [%tuple [beg.at.op fin] its]
    %list   [%list [beg.at.op fin] (turn its |=(i=item val.i))]
  ::
      %change
    =/  beg=loc  ?~(target beg.at.op beg.at.t.u.target)
    :^  %change  [beg fin]  ?~(target ~ names.u.target)
    (turn its |=(i=item ^-(edit [at.i ?~(face.i %$ u.face.i) val.i])))
  ==
::
+|  %parser
::
::  +parser: section 3's recursive descent over one file's tokens
::
::    Each +read- arm reads one rule of the EBNF from the head of the
::    tokens it is given and returns (pare node): the node and the
::    tokens after it, or the first error. It decides by the next token,
::    at most with the one after it and whether that one is tight
::    (section 3), so it never backtracks. A loop over items is a trap
::    whose every step, through +then, is a tail call, so a long module
::    grows no stack; only nesting does, and a line's nesting is bounded
::    by its length. all is the whole token list, which only errors
::    read (+stray).
::
++  parser
  |_  [file=path all=(list token)]
  ::
  ::  +bad: "expected <want>, found <the next token>" (+fail)
  ::
  ++  bad
    |=  [ts=(list token) want=tape]
    ^-  [%| p=error]
    (fail file ts want)
  ::
  ::  +bad-why: +bad with a hint (+fail-why)
  ::
  ++  bad-why
    |=  [ts=(list token) want=tape why=tape]
    ^-  [%| p=error]
    (fail-why file ts want why)
  ::
  ::  +bad-in: +bad where a place begins whose first characters are the
  ::  mask can (+fail-in)
  ::
  ++  bad-in
    |=  [ts=(list token) want=tape can=@]
    ^-  [%| p=error]
    (fail-in file ts want can)
  ::
  ::  +bad-in-why: +bad-in with a hint (+fail-in-why)
  ::
  ++  bad-in-why
    |=  [ts=(list token) want=tape can=@ why=tape]
    ^-  [%| p=error]
    (fail-in-why file ts want can why)
  ::
  ::  +bad-space: a tight form that found no next token right after prev
  ::  (+fail-space)
  ::
  ++  bad-space
    |=  [prev=token ts=(list token) want=tape]
    ^-  [%| p=error]
    (fail-space file prev ts want "")
  ::
  ::  +bad-at: an error inside a token, or at the end of a line
  ::
  ++  bad-at
    |=  [at=loc msg=tape]
    ^-  [%| p=error]
    [%| file line.at col.at msg]
  ::
  ::  +closing: what a bracket op still needs, its closer close
  ::
  ++  closing
    |=  [op=token close=tape]
    ^-  tape
    "`{close}` to close the {(show-found op)} at {(show-loc beg.at.op)}"
  ::
  ::  +bad-end: a line that should end and goes on, after a call
  ::
  ++  bad-end
    |=  ts=(list token)
    ^-  [%| p=error]
    (bad-end-in ts operand-mask)
  ::
  ::  +bad-end-in: +bad-end after a construct that text beginning with
  ::  a character of the mask can could still go on, as more operands go
  ::  on a call; at an error token whose text can't, at that text's
  ::  start (+fail-in): +$ x @ ?: fails at the ?
  ::
  ++  bad-end-in
    |=  [ts=(list token) can=@]
    ^-  [%| p=error]
    =/  want=tape  "the end of the line"
    ?:  ?=([[* * %indent] *] ts)
      %^  bad-why  ts  want
      %+  weld  "only a bracket open at the end of a line, "
      "or a rune's body, takes deeper lines"
    ?:  &(?=(^ ts) (stray i.ts))
      (bad-why ts want "this {(show-found i.ts)} closes no bracket")
    ?.  ?=([[* * [%error *]] *] ts)  (bad ts want)
    =/  ok=@  ?:(tight.i.ts after-mask can)
    ?:  |(=(':' c.lex.i.ts) (in c.lex.i.ts ok))  (bad ts want)
    [%| (moved file want i.ts)]
  ::
  ::  +no-gap: a token tight where a space goes, after a rune, a name, a
  ::  sample or a pattern; at an error token, whose text can't go tight
  ::  there unless it is a comment's :, at that text's start (+fail-in)
  ::
  ++  no-gap
    |=  [ts=(list token) want=tape]
    ^-  [%| p=error]
    ?.  &(?=([[* * [%error *]] *] ts) !=(':' c.lex.i.ts))  (bad ts want)
    [%| (moved file want i.ts)]
  ::
  ::  +no-space: a token tight after an item, where a space goes
  ::
  ++  no-space
    |=  ts=(list token)
    ^-  [%| p=error]
    =/  te=(unit error)  (tight-error file ts)
    ?^  te  [%| u.te]
    ?.  ?=([[* * %'='] *] ts)  (bad ts "a space between items")
    %^  bad-why  ts  "a space between items"
    "`name=value` goes in a cell, as [a=1], or a change, as m(a=1)"
  ::
  ::  +no-space-pattern: +no-space in a cell pattern
  ::
  ++  no-space-pattern
    |=  ts=(list token)
    ^-  [%| p=error]
    ?.  ?=([[* * %'='] *] ts)  (no-space ts)
    %^  bad-why  ts  "a space between items"
    "patterns take no `name=`: a bare name binds, as [a b]"
  ::
  ::  +no-operand: a token where an expression or an operand goes that
  ::  starts none (can: what may start one), with a hint for the left-out
  ::  forms the lexer can't see (2.6) and other likely slips
  ::
  ++  no-operand
    |=  [ts=(list token) can=@]
    ^-  [%| p=error]
    =/  want=tape  "an expression"
    ?:  ?=([[* * %'='] [* %& %'('] *] ts)
      (bad-why ts want "`=(a b)` is left out: eq is a gate")
    ?:  ?=([[* * %'='] [* %& %'/'] *] ts)
      (bad-why ts want "`=/` is left out: `++` defines values")
    ?:  ?=([[* * %'='] [* %& %'+'] *] ts)
      (bad-why ts want "`=+` is left out: `++` defines values")
    ?:  ?=([[* * %'='] [* %& %'?'] *] ts)
      (bad-why ts want "`=?` is left out: `++` defines values")
    ?:  ?&  ?=([[* * %'='] [* %& [%error *]] *] ts)
            =('.' c.lex.i.t.ts)
        ==
      (bad-why ts want "`=.` is left out: `++` defines values")
    ?:  ?=([[* * %'*'] *] ts)
      (bad-why ts want "`*mold` is left out: no defaults")
    ?:  ?=([[* * %'+'] *] ts)
      (bad-why ts want "a pair takes no spaces, as gap+%s2")
    ?:  ?=([[* * %'?'] *] ts)
      %:  bad-in-why  ts  want  can
        "`?` alone is the loobean mold, and `?-` the branch"
      ==
    ?:  &(?=(^ ts) (is-rune i.ts))
      (bad-in-why ts want can "a rune here goes in parentheses")
    ?:  &(?=(^ ts) (stray i.ts))
      (bad-why ts want "this {(show-found i.ts)} closes no bracket")
    (bad-in ts want can)
  ::
  ::  +no-name: a token where a name goes that isn't one
  ::
  ++  no-name
    |=  ts=(list token)
    ^-  [%| p=error]
    ?:  ?=([[* * [%tvar *]] *] ts)
      (bad-why ts "a name" "a name starts with a lowercase letter")
    ?:  ?=([[* * [%wing *]] *] ts)
      (bad-in-why ts "a name" lower-mask "a name has no `.`")
    (bad-in ts "a name" lower-mask)
  ::
  ::  +unclosed: where the closer of the bracket op opened should be, once
  ::  it holds all it needs (+unclosed-want)
  ::
  ++  unclosed
    |=  [op=token close=tape ts=(list token)]
    ^-  [%| p=error]
    (unclosed-want (closing op close) ts)
  ::
  ::  +unclosed-want: what a bracket still needs where ts begins, want:
  ::  its closer once it is complete, else its next part, as "a mold,
  ::  the product" in $-(@. At a layout token, the bracket being one
  ::  that closes on its line, the error is at the end of that line,
  ::  as no later line can close it (+fail-line)
  ::
  ++  unclosed-want
    |=  [want=tape ts=(list token)]
    ^-  [%| p=error]
    (fail-line file ts want "this bracket closes on its line")
  ::
  ::  +bad-line: +bad where what is wanted goes on the line (+fail-line)
  ::
  ++  bad-line
    |=  [ts=(list token) want=tape]
    ^-  [%| p=error]
    (fail-line file ts want "")
  ::
  ::  +unclosed-open: a bracket that may be left open, whose line ends
  ::  with neither its closer nor deeper lines, nor an item that took
  ::  them (+shut); noun names its items
  ::
  ++  unclosed-open
    |=  [op=token close=tape noun=tape ts=(list token)]
    ^-  [%| p=error]
    ?.  ?=([[* * ?(%newline %dedent)] *] ts)  (unclosed op close ts)
    (bad ts "`{close}` or {noun} on a deeper line")
  ::
  ::  +wide-rune: a rune followed tight; txt( is a left-out wide form
  ::
  ++  wide-rune
    |=  [txt=tape ts=(list token)]
    ^-  [%| p=error]
    =/  want=tape  "a space after `{txt}`"
    ?.  ?=([[* * %'('] *] ts)  (no-gap ts want)
    %^  bad-why  ts  want
    "the wide form `{txt}(…)` is left out: indentation covers it"
  ::
  ::  +unnamed: a change's item or line without its name=
  ::
  ::    A name could still begin one, so the error is just past it, as
  ::    a tight form's is (+fail-space): `m(b c)` at the space, `m(b)`
  ::    at the ). So is an error token's text there, unless it begins
  ::    with the =: `m(a"x)` at the ", with the layout pass's message
  ::    after the parser's (+moved), but `m(a==1)` at the lexer's error,
  ::    the second =. So is a wing's first name: `m(a.b=1)` fails at the
  ::    dot (+fail-in). At an error token whose text can't begin a name,
  ::    at that text, as `m( @sd` at the @ (+fail-in).
  ::
  ++  unnamed
    |=  ts=(list token)
    ^-  [%| p=error]
    =/  why=tape  "a change's items are named, as in m(done=%.y)"
    ?:  ?=([[* * [%error *]] *] ts)  (bad-in ts "a named item" lower-mask)
    ?:  ?=([[* * [%wing *]] *] ts)
      (bad-in-why ts "a named item" lower-mask why)
    ?.  ?=([[* * [%name *]] *] ts)  (bad-why ts "a named item" why)
    =/  want=tape  "`=` right after {(show-found i.ts)}"
    ?:  ?&  ?=([* [* * [%error *]] *] ts)
            =(end.at.i.ts from.lex.i.t.ts)
            !=('=' c.lex.i.t.ts)
        ==
      [%| (moved file want i.t.ts)]
    ?:  &(?=([* [* %& *] *] ts) !?=([* [* * [%error *]] *] ts))
      (bad-why t.ts want why)
    (fail-space file i.ts t.ts "`=`" why)
  ::
  ::  +doomed: where a part of a line, read from ts up to after, took
  ::  the deeper lines while what holds it needs more: deeper lines of
  ::  its own (a rune's body or arms), a part after it (the body of
  ::  |=(, the product of $-(), or the } of an interpolation, which
  ::  closes on its line (2.9). A bracket that needs none of these
  ::  closes with the deeper lines instead (+shut). No later line can
  ::  give it that, so the error is at the end of the line that took
  ::  them (section 3, Errors). want is what it needs. Only an error path
  ::  calls this, and it looks only when after begins with NEWLINE or
  ::  DEDENT, so it costs nothing on the way to a tree.
  ::
  ++  doomed
    |=  [ts=(list token) after=(list token) want=tape]
    ^-  (unit [%| p=error])
    ?.  ?=([[* * ?(%newline %dedent)] *] after)  ~
    =/  ind=(unit token)  (took ts after)
    ?~  ind  ~
    :-  ~
    %+  bad-at  beg.at.u.ind
    ;:  weld
      "expected {want}, found the end of the line; the deeper lines "
      "go to the last bracket or rune left open on this line"
    ==
  ::
  ::  +shut: whether the bracket op closes before ts with no closer, as
  ::  a bracket left open before the last bracket or rune on its line
  ::  does: ts begins a line that isn't deeper, and the bracket's last
  ::  item, whose span is last, took the deeper lines (section 3)
  ::
  ::    An item ends on a later line than op only if it read the deeper
  ::    lines, as no token crosses a line. So this looks at no token but
  ::    the next, and brackets nested on one line that close together
  ::    cost one test each.
  ::
  ++  shut
    |=  [op=token last=(unit span) ts=(list token)]
    ^-  ?
    ?~  last  |
    ?&  ?=([[* * ?(%newline %dedent)] *] ts)
        (gth line.end.u.last line.beg.at.op)
    ==
  ::
  ::  +took: the INDENT among the tokens from ts up to after, if any
  ::
  ++  took
    |=  [ts=(list token) after=(list token)]
    ^-  (unit token)
    ?~  after  ~
    =/  stop=loc  beg.at.i.after
    |-  ^-  (unit token)
    ?~  ts  ~
    ?.  (loc-lth beg.at.i.ts stop)  ~
    ?:  ?=(%indent lex.i.ts)  `i.ts
    $(ts t.ts)
  ::
  ::  +stray: whether a ) or ] closes no bracket opened before it on its
  ::  line, or none inside the interpolation it is in
  ::
  ++  stray
    |=  t=token
    ^-  ?
    ?.  ?=(?(%')' %']') lex.t)  |
    =|  open=(list ?)
    =/  ts=(list token)  all
    |-  ^-  ?
    ?~  ts  |
    =*  u  i.ts
    ?:  =(at.u at.t)  |(?=(~ open) !i.open)
    ?:  (is-layout u)  $(ts t.ts, open ~)
    ?:  ?=(?(%'(' %'[' %'~[' %'|=(' %'$-(') lex.u)
      $(ts t.ts, open [& open])
    ?:  ?=([%str-head *] lex.u)  $(ts t.ts, open [| open])
    ?:  ?=([%str-mid *] lex.u)  $(ts t.ts, open [| ?~(open ~ t.open)])
    ?:  |(?=(?(%')' %']') lex.u) ?=([%str-tail *] lex.u))
      $(ts t.ts, open ?~(open ~ t.open))
    $(ts t.ts)
  ::
  ::  +read-module: { import NEWLINE } { definition NEWLINE }, then the
  ::  end of the tokens
  ::
  ++  read-module
    |=  ts=(list token)
    ^-  (each module error)
    =|  ims=(list import)
    |-  ^-  (each module error)
    ?:  ?=([[* * ?(%'/-' %'/%' %'/=')] *] ts)
      ;<  [im=import after=(list token)]  then  (read-import ts)
      ?.  ?=([[* * %newline] *] after)  (bad-end-in after 0)
      $(ims [im ims], ts t.after)
    =|  defs=(list def)
    |-  ^-  (each module error)
    ?~  ts  [%& (flop ims) (flop defs)]
    ?:  ?=([[* * ?(%'/-' %'/%' %'/=')] *] ts)
      (bad-why ts "a definition" "imports come first")
    ::  what may begin the line: a definition, or before any, an import
    =/  can=@  ?~(defs (con plus-mask fas-mask) plus-mask)
    ;<  [d=def after=(list token)]  then  (read-def ts can)
    ?.  ?=([[* * %newline] *] after)  (bad-end-in after (def-can d))
    $(defs [d defs], ts t.after)
  ::
  ::  +read-import: /- name, /% term, or /= name pathlit
  ::
  ++  read-import
    |=  ts=(list token)
    ^-  (pare import)
    ?~  ts  (bad ts "an import")
    =*  g  i.ts
    =/  rest=(list token)  t.ts
    ?:  &(?=(^ rest) tight.i.rest)
      (no-gap rest "a space after {(show-found g)}")
    ?:  =(%'/%' lex.g)
      ?:  ?=([[* * [%lit %term %tas *]] *] rest)
        ?:  =(0 val.p.lex.i.rest)
          (bad-in rest "a mark's term, as `%todo-action`" cen-mask)
        [%& [%mark [beg.at.g end.at.i.rest] val.p.lex.i.rest] t.rest]
      =/  want=tape  "a mark's term, as `%todo-action`"
      ?.  ?=([[* * [%name *]] *] rest)  (bad-in rest want cen-mask)
      (bad-why rest want "`/%` takes no face: it names the type after its mark")
    ?.  ?=([[* * [%name *]] *] rest)  (no-name rest)
    =*  nam  i.rest
    ?.  =(%'/=' lex.g)
      [%& [%sur [beg.at.g end.at.nam] p.lex.nam] t.rest]
    =/  more=(list token)  t.rest
    ?:  &(?=(^ more) tight.i.more)  (no-gap more "a space after the name")
    ?.  ?=([[* * %'/'] *] more)
      (bad-in more "a module's path, as /ui/components/card" fas-mask)
    ;<  [[sp=span segs=(list @ta)] after=(list token)]  then
      (read-pathlit i.more t.more |)
    [%& [%jibb [beg.at.g end.sp] p.lex.nam segs] after]
  ::
  ::  +read-pathlit: after a path's /, its knots, each after a tight /
  ::  and tight itself; / alone is the empty path where empty allows it,
  ::  in an expression but not an import (doc question)
  ::
  ++  read-pathlit
    |=  [sl=token ts=(list token) empty=?]
    ^-  (pare [span (list @ta)])
    ?.  ?=([[* %& [%knot *]] *] ts)
      ?:  &(?=(^ ts) tight.i.ts !(is-closer i.ts))
        (bad ts "a path segment")
      ?.  empty  (bad-space sl ts "a path segment")
      [%& [at.sl ~] ts]
    =/  segs=(list @ta)  ~[p.lex.i.ts]
    =/  fin=loc  end.at.i.ts
    =/  rest=(list token)  t.ts
    |-  ^-  (pare [span (list @ta)])
    ?.  ?=([[* %& %'/'] *] rest)
      [%& [[beg.at.sl fin] (flop segs)] rest]
    =/  nex=(list token)  t.rest
    ?:  ?=([[* %& [%knot *]] *] nex)
      $(segs [p.lex.i.nex segs], fin end.at.i.nex, rest t.nex)
    ?:  &(?=(^ nex) tight.i.nex)  (bad nex "a path segment")
    (bad-space i.rest nex "a path segment")
  ::
  ::  +read-def: ++ name, then an expression or a body; +$ name, then a
  ::  mold on its line or cases on deeper lines. can is what may begin
  ::  a line where a definition goes (+fail-in).
  ::
  ++  read-def
    |=  [ts=(list token) can=@]
    ^-  (pare def)
    ?~  ts  (bad ts "a definition")
    =*  rune  i.ts
    ?:  =(%'++' lex.rune)
      ;<  [nam=term after=(list token)]  then  (read-def-name rune t.ts)
      ;<  [e=expr more=(list token)]  then
        (read-expr-or-body "the name" after)
      [%& [%value [beg.at.rune end:(span-of e)] nam e] more]
    ?:  (is-closer rune)
      %^  bad-why  ts  "a definition"
      "this closes no bracket, as one open at the end of its line needs none"
    =/  want=tape
      ?.((in '/' can) "a definition" "an import or a definition")
    ?:  =(%'+' lex.rune)
      (bad-in-why ts want can "`+` begins `++` or `+$`")
    ?.  =(%'+$' lex.rune)  (bad-in ts want can)
    ;<  [nam=term after=(list token)]  then  (read-def-name rune t.ts)
    ?:  &(?=(^ after) tight.i.after)
      (no-gap after "a space after the name")
    ?:  ?=([[* * [%error *]] *] after)
      (bad-in after "a mold" (con mold-mask bar-mask))
    ?:  ?=([[* * ?(%'|=' %'|=(')] *] after)
      %:  bad-in-why  after  "a mold"  (con mold-mask bar-mask)
        "a gate's mold is $-(sample product)"
      ==
    ;<  [s=shape more=(list token)]  then
      ?:  ?=([[* * %'|$'] *] after)
        (read-generic i.after t.after)
      (read-def-body after)
    [%& [%mold [beg.at.rune end:(span-of s)] nam s] more]
  ::
  ::  +hoon-union: a tight ( immediately after a ? mold
  ::
  ++  hoon-union
    |=  [ts=(list token) after=(list token)]
    ^-  ?
    ?.  ?=([[* %& %'('] *] after)  |
    |-  ^-  ?
    ?~  ts  |
    ?:  =(t.ts after)  =(%'?' lex.i.ts)
    $(ts t.ts)
  ::
  ::  +read-def-body: one mold on the definition line or its cases below
  ::
  ++  read-def-body
    |=  ts=(list token)
    ^-  (pare shape)
    ?.  ?=([[* * %indent] *] ts)
      ?:  ?=([[* * ?(%newline %dedent)] *] ts)
        (bad ts "a mold, on its line or a deeper one")
      ;<  [s=shape more=(list token)]  then  (read-mold ts)
      ?:  (hoon-union ts more)
        (bad-why more "the end of the line" "a union is a `+$` with its cases below")
      ?:  ?=([[* * %indent] *] more)
        %^  bad-why  more  "the end of the line"
        "a `+$` takes one mold on its line or its cases below, not both"
      [%& s more]
    =|  cs=(list shape)
    =/  rest=(list token)  t.ts
    |-  ^-  (pare shape)
    ;<  [c=shape after=(list token)]  then  (read-mold rest)
    ?:  (hoon-union rest after)
      (bad-why after "the end of the line" "a union is a `+$` with its cases below")
    ?:  ?=([[* * %newline] *] after)  $(cs [c cs], rest t.after)
    ?:  ?=([[* * %dedent] *] after)
      ?~  cs  [%& c t.after]
      =/  cases=(list shape)  (flop [c cs])
      [%& [%union [beg:(span-of (rear cs)) end:(span-of c)] cases] t.after]
    ?:  ?=([[* * %'='] *] after)
      %^  bad-why  after  "the end of the line"
      "a `+$`'s lines below are its cases; a record's fields go in a [ left open on the `+$` line"
    ?:  ?=([[* * %indent] *] after)  (bad-end after)
    ?:  &(?=(^ after) (stray i.after))  (bad-end after)
    (bad-why after "the end of the line" "a union takes one case per line")
  ::
  ::  +read-def-name: after ++ or +$, a space and a name
  ::
  ++  read-def-name
    |=  [rune=token ts=(list token)]
    ^-  (pare term)
    ?:  &(?=(^ ts) tight.i.ts)
      (no-gap ts "a space after {(show-found rune)}")
    ?.  ?=([[* * [%name *]] *] ts)  (no-name ts)
    [%& p.lex.i.ts t.ts]
  ::
  ::  +read-expr-or-body: a space and an expression on the line, or a
  ::  body on deeper lines; what names what comes before, for errors
  ::
  ++  read-expr-or-body
    |=  [what=tape ts=(list token)]
    ^-  (pare expr)
    ?:  ?=([[* * %indent] *] ts)  (read-body t.ts)
    ?:  ?=([[* * ?(%newline %dedent)] *] ts)
      (bad ts "an expression, or a body on deeper lines")
    ?:  &(?=(^ ts) tight.i.ts)  (no-gap ts "a space after {what}")
    (read-expr ts)
  ::
  ::  +read-body: after its INDENT, { definition NEWLINE } expr DEDENT
  ::
  ++  read-body
    |=  ts=(list token)
    ^-  (pare expr)
    =|  defs=(list def)
    |-  ^-  (pare expr)
    ?:  ?=([[* * ?(%'++' %'+$')] *] ts)
      ;<  [d=def after=(list token)]  then  (read-def ts plus-mask)
      ?:  ?=([[* * %newline] *] after)  $(defs [d defs], ts t.after)
      ?.  ?=([[* * %dedent] *] after)  (bad-end-in after (def-can d))
      (bad after "the body's final expression, after its definitions")
    ?:  ?=([[* * %'+'] *] ts)
      %:  bad-in-why  ts  "a definition or an expression"  plus-mask
        "`+` begins `++` or `+$`"
      ==
    ;<  [e=expr after=(list token)]  then  (read-expr ts)
    ?:  ?=([[* * %dedent] *] after)
      =/  ds=(list def)  (flop defs)
      =/  beg=loc  ?~(ds beg:(span-of e) beg:(span-of i.ds))
      [%& [%body [beg end:(span-of e)] ds e] t.after]
    ?.  ?=([[* * %newline] *] after)  (bad-end-in after (tail-can e))
    %^  bad-why  after  "the end of the body"
    "a body's final expression is its last line"
  ::
  ::  +read-expr: a rune, or a call
  ::
  ++  read-expr
    |=  ts=(list token)
    ^-  (pare expr)
    ?~  ts  (bad ts "an expression")
    =*  t  i.ts
    ?+  lex.t  (read-call ts)
      %'|='  ?:((is-ctor ts) (read-call ts) (read-gate t t.ts))
      %'^-'  (read-cast t t.ts)
      %'~&'  (read-trace t t.ts)
      %'?-'  (read-branch t t.ts)
    ==
  ::
  ::  +read-call: operand { operand }; one operand alone is itself
  ::
  ++  read-call
    |=  ts=(list token)
    ^-  (pare expr)
    ;<  [els=(list expr) after=(list token)]  then  (read-operands ts)
    ?~  els  (no-operand ts expr-mask)
    [%& (call-of els) after]
  ::
  ::  +read-operands: a call's operands, or those on a group's first
  ::  line, to the end of the call; each after the first follows a space
  ::
  ++  read-operands
    |=  ts=(list token)
    ^-  (pare (list expr))
    =|  els=(list expr)
    |-  ^-  (pare (list expr))
    ?~  ts  [%& (flop els) ts]
    =*  t  i.ts
    ?:  (ends-call t)
      ::  an error token whose text can't go tight after an operand
      =/  te=(unit error)
        ::  after-mask without its =
        ?~(els ~ (tight-error-in file ts (mix after-mask tis-mask)))
      ?^  te  [%| u.te]
      ::  or, past a space, can't begin one (+fail-in)
      ?:  ?&  ?=(^ els)  ?=([%error *] lex.t)  !tight.t
              !=(':' c.lex.t)  !(in c.lex.t operand-mask)
          ==
        [%| (moved file "an expression" t)]
      [%& (flop els) ts]
    ?:  &(tight.t ?=(^ els))  (no-space ts)
    ?:  (is-operand-start t)
      ;<  [e=expr more=(list token)]  then  (read-operand ts)
      $(els [e els], ts more)
    ?:  &(?=(^ els) (is-rune t))
      %:  bad-in-why  ts  "an expression"  operand-mask
        "inside a call, a rune goes in parentheses"
      ==
    (no-operand ts ?~(els expr-mask operand-mask))
  ::
  ::  +read-operand: one operand, told by its first token and, after a
  ::  name or a wing, by a tight ( or +
  ::
  ++  read-operand
    |=  ts=(list token)
    ^-  (pare expr)
    ?~  ts  (bad ts "an expression")
    =*  t  i.ts
    ?+  lex.t  (no-operand ts operand-mask)
      [%lit *]       [%& [%lit at.t p.lex.t] t.ts]
      [%str *]       [%& [%str at.t (text-piece p.lex.t)] t.ts]
      [%str-head *]  (read-string t t.ts)
      [%name *]      (read-ref t t.ts)
      [%wing *]      (read-ref t t.ts)
      %'%/'          (read-qath t t.ts)
      %'/'           (read-path t t.ts)
      %'`'           (read-unit t t.ts)
      %'('           (read-group t t.ts)
      %'~['          (read-bracket %list t ~ t.ts)
      %'['           (read-bracket %tuple t ~ t.ts)
      %'|=('         (read-gate-wide t t.ts)
      %'|='          (read-ctor t t.ts)
      %'!!'          [%& [%crash at.t ~] t.ts]
    ==
  ::
  ::  +read-ref: after a name or wing, a tight ( makes a change, and
  ::  after a name a tight + a pair; else it is a wing
  ::
  ++  read-ref
    |=  [t=token ts=(list token)]
    ^-  (pare expr)
    =/  names=(list term)  (names-of lex.t)
    ?:  ?=([[* %& %'('] *] ts)
      (read-bracket %change i.ts `[t names] t.ts)
    ?:  &(?=([[* %& %'+'] *] ts) ?=([%name *] lex.t))
      (read-pair t p.lex.t i.ts t.ts)
    [%& [%wing at.t names] ts]
  ::
  ::  +read-pair: name+operand, with no spaces
  ::
  ++  read-pair
    |=  [t=token tag=term lus=token ts=(list token)]
    ^-  (pare expr)
    ?:  |(?=(~ ts) !tight.i.ts)  (bad-space lus ts "an operand")
    ;<  [v=expr after=(list token)]  then  (read-operand ts)
    [%& [%pair [beg.at.t end:(span-of v)] tag v] after]
  ::
  ::  +read-unit: ` and an operand, with no space
  ::
  ++  read-unit
    |=  [tic=token ts=(list token)]
    ^-  (pare expr)
    ?:  |(?=(~ ts) !tight.i.ts)  (bad-space tic ts "an operand")
    ;<  [v=expr after=(list token)]  then  (read-operand ts)
    [%& [%unit [beg.at.tic end:(span-of v)] v] after]
  ::
  ::  +read-ctor: |= and a term, with no space: a case's constructor
  ::
  ::    Where an operand goes, |= can only be a constructor or begin |=(,
  ::    so a tall gate there fails at the space after |=.
  ::
  ++  read-ctor
    |=  [bar=token ts=(list token)]
    ^-  (pare expr)
    ?:  |(?=(~ ts) !tight.i.ts)
      %:  fail-space  file  bar  ts  "`(` or a term"
        ?:  ?=([[* * [%lit %term *]] *] ts)
          "a case's constructor takes its term with no space, as |=%got"
        "a gate in an operand is |=(a body)"
      ==
    ?.  ?=([[* * [%lit %term *]] *] ts)  (bad-in ts "a term" cen-mask)
    [%& [%ctor [beg.at.bar end.at.i.ts] p.lex.i.ts] t.ts]
  ::
  ::  +read-path: a path literal, as /posts/~zod, an operand (Decisions)
  ::
  ++  read-path
    |=  [sl=token ts=(list token)]
    ^-  (pare expr)
    ;<  [[sp=span segs=(list @ta)] after=(list token)]  then
      (read-pathlit sl ts &)
    [%& [%path sp segs] after]
  ::
  ::  +read-qath: %/, then its segments, knots or (expr), each after a
  ::  tight / and tight itself; %/ alone is the root
  ::
  ++  read-qath
    |=  [cen=token ts=(list token)]
    ^-  (pare expr)
    ?.  ?=([[* %& ?([%knot *] %'(')] *] ts)
      ?:  &(?=(^ ts) tight.i.ts !(is-closer i.ts))
        (bad ts "a path segment")
      [%& [%qath at.cen ~] ts]
    =|  segs=(list qseg)
    |-  ^-  (pare expr)
    ;<  [[s=qseg fin=loc] after=(list token)]  then  (read-qseg ts)
    ?.  ?=([[* %& %'/'] *] after)
      [%& [%qath [beg.at.cen fin] (flop [s segs])] after]
    =/  nex=(list token)  t.after
    ?:  ?=([[* %& ?([%knot *] %'(')] *] nex)
      $(segs [s segs], ts nex)
    ?:  &(?=(^ nex) tight.i.nex)  (bad nex "a path segment")
    (bad-space i.after nex "a path segment")
  ::
  ::  +read-qseg: an application path's segment, a knot or (expr), and
  ::  where it ends: at its ), or with the deeper lines when its expr
  ::  took them, as any bracket before the last on its line (+shut)
  ::
  ++  read-qseg
    |=  ts=(list token)
    ^-  (pare [qseg loc])
    ?:  ?=([[* * [%knot *]] *] ts)
      [%& [[%knot p.lex.i.ts] end.at.i.ts] t.ts]
    ?.  ?=([[* * %'('] *] ts)  (bad ts "a path segment")
    =*  par  i.ts
    ?:  &(?=(^ t.ts) (is-layout i.t.ts))  (unclosed-want "an expression" t.ts)
    ;<  [e=expr after=(list token)]  then  (read-expr t.ts)
    ?:  ?=([[* * %')'] *] after)
      [%& [[%expr e] end.at.i.after] t.after]
    ?:  (shut par `(span-of e) after)
      [%& [[%expr e] end:(span-of e)] after]
    (unclosed par ")" after)
  ::
  ::  +read-string: after its str-head, a string's interpolations and
  ::  text: expr { str-mid expr } str-tail
  ::
  ++  read-string
    |=  [head=token ts=(list token)]
    ^-  (pare expr)
    =/  ps=(list piece)
      ?.(?=([%str-head *] lex.head) ~ (text-piece p.lex.head))
    =/  op=token  head
    |-  ^-  (pare expr)
    ;<  [e=expr after=(list token)]  then  (read-expr ts)
    =.  ps  [[%expr e] ps]
    ?:  ?=([[* * [%str-mid *]] *] after)
      $(ps (weld (text-piece p.lex.i.after) ps), op i.after, ts t.after)
    ?.  ?=([[* * [%str-tail *]] *] after)
      =/  brace=loc  [line.end.at.op (dec (max 2 col.end.at.op))]
      =/  want=tape  "`}` to close the `\{` at {(show-loc brace)}"
      =/  dm  (doomed ts after want)
      ?^  dm  u.dm
      (bad after want)
    =.  ps  (weld (text-piece p.lex.i.after) ps)
    [%& [%str [beg.at.head end.at.i.after] (flop ps)] t.after]
  ::
  ::  +read-group: ( expr ), or ( { operand } and its lines below, left
  ::  open
  ::
  ::    A ( followed by a rune is the closed form. Else the group holds
  ::    its first line's operands and then its lines as one call, or the
  ::    one element alone; with ( alone, the first line below is the
  ::    head. Either form closes with the deeper lines, with no ), when
  ::    the last thing on its line took them (+shut). A ( with nothing
  ::    after it on its line needs those lines, as () is no group: so
  ::    where they don't come it wants the call's head on a deeper line,
  ::    and at a closer or an error token an expression (+no-operand),
  ::    which moves an error token whose text no expression begins
  ::    with to that text, as `( @sd` at the @ (+fail-in).
  ::
  ++  read-group
    |=  [par=token ts=(list token)]
    ^-  (pare expr)
    ?:  (is-rune-start ts)
      ;<  [e=expr after=(list token)]  then  (read-expr ts)
      ?:  ?=([[* * %')'] *] after)
        [%& [%group [beg.at.par end.at.i.after] e] t.after]
      ?:  (shut par `(span-of e) after)
        [%& [%group [beg.at.par end:(span-of e)] e] after]
      (unclosed par ")" after)
    ;<  [els=(list expr) after=(list token)]  then  (read-operands ts)
    ?:  ?=([[* * %indent] *] after)
      ;<  [ls=(list item) more=(list token)]  then
        (read-lines %group t.after)
      =/  inner=expr  (call-of (weld els (turn ls |=(i=item val.i))))
      [%& [%group [beg.at.par end:(span-of inner)] inner] more]
    ?~  els
      ?:  ?=([[* * ?(%newline %dedent)] *] after)
        (bad after "the call's head on a deeper line")
      (no-operand after expr-mask)
    ?:  ?=([[* * %')'] *] after)
      [%& [%group [beg.at.par end.at.i.after] (call-of els)] t.after]
    =/  inner=expr  (call-of els)
    ?:  (shut par `(span-of inner) after)
      [%& [%group [beg.at.par end:(span-of inner)] inner] after]
    (unclosed-open par ")" "an argument" after)
  ::
  ::  +read-bracket: a tuple's, list's or change's items, to its closer
  ::  on the line, or to the end of its lines below when left open, or
  ::  with its last item's lines when that took the deeper lines (+shut)
  ::
  ++  read-bracket
    |=  $:  kind=?(%tuple %list %change)
            op=token
            target=(unit [t=token names=(list term)])
            ts=(list token)
        ==
    ^-  (pare expr)
    =/  close=?(%')' %']')  ?:(?=(%change kind) %')' %']')
    =|  its=(list item)
    |-  ^-  (pare expr)
    ?~  ts  (bad ts "an item")
    =*  t  i.ts
    ?:  =(close lex.t)
      [%& (bracket-node kind op target (flop its) end.at.t) t.ts]
    ?:  (is-closer t)  (unclosed op (trip close) ts)
    ?:  ?=(%indent lex.t)
      ;<  [ls=(list item) more=(list token)]  then  (read-lines kind t.ts)
      =/  every=(list item)  (weld (flop its) ls)
      =/  fin=loc  ?~(every end.at.op end.at:(rear every))
      [%& (bracket-node kind op target every fin) more]
    ?:  &(?=(^ its) (shut op `at.i.its ts))
      [%& (bracket-node kind op target (flop its) end.at.i.its) ts]
    ?:  ?=(?(%newline %dedent) lex.t)
      (unclosed-open op (trip close) "an item" ts)
    ?:  &(tight.t ?=(^ its))  (no-space ts)
    ;<  [i=item more=(list token)]  then  (read-item kind ts)
    $(its [i its], ts more)
  ::
  ::  +read-item: [ name= ] operand; a tuple's item may be named, a
  ::  change's must be, a list's is not
  ::
  ++  read-item
    |=  [kind=?(%tuple %list %change) ts=(list token)]
    ^-  (pare item)
    ?:  &(!?=(%list kind) ?=([[* * [%name *]] [* %& %'='] *] ts))
      =*  nam  i.ts
      =/  rest=(list token)  t.t.ts
      ?:  |(?=(~ rest) !tight.i.rest)  (bad-space i.t.ts rest "a value")
      ;<  [v=expr after=(list token)]  then  (read-operand rest)
      [%& [[beg.at.nam end:(span-of v)] `p.lex.nam v] after]
    ?:  ?=(%change kind)  (unnamed ts)
    ?:  &(?=(^ ts) (is-rune i.ts))
      %:  bad-in-why  ts  "an expression"  operand-mask
        "inside brackets, a rune goes in parentheses"
      ==
    ;<  [v=expr after=(list token)]  then  (read-operand ts)
    [%& [(span-of v) ~ v] after]
  ::
  ::  +read-lines: after an open bracket's INDENT, its lines, an item
  ::  each, to its DEDENT
  ::
  ++  read-lines
    |=  [kind=?(%tuple %list %change %group) ts=(list token)]
    ^-  (pare (list item))
    =|  ls=(list item)
    |-  ^-  (pare (list item))
    ;<  [l=item after=(list token)]  then  (read-line kind ts)
    ?:  ?=([[* * %newline] *] after)  $(ls [l ls], ts t.after)
    ?:  ?=([[* * %dedent] *] after)  [%& (flop [l ls]) t.after]
    ?.  ?=([[* * ?(%')' %']')] *] after)  (bad-end-in after (tail-can val.l))
    (closer-after after)
  ::
  ::  +closer-after: a ) or ] after an open bracket's line's item
  ::
  ++  closer-after
    |=  ts=(list token)
    ^-  [%| p=error]
    %^  bad-why  ts  "the end of the line"
    "a bracket open at the end of its line takes no closer"
  ::
  ::  +closer-first: an open bracket's line that starts with a ) or ],
  ::  where want, its item, goes
  ::
  ++  closer-first
    |=  [ts=(list token) want=tape]
    ^-  (unit [%| p=error])
    ?.  ?=([[* * ?(%')' %']')] *] ts)  ~
    :-  ~
    %^  bad-why  ts  want
    %+  weld  "a bracket open at the end of its line takes no closer: "
    "its items end at the first line that isn't deeper"
  ::
  ::  +read-line: an open bracket's line, [ name= ] expr; a tuple's may
  ::  be named, a change's must be, a list's and a group's are not
  ::  (doc question)
  ::
  ++  read-line
    |=  [kind=?(%tuple %list %change %group) ts=(list token)]
    ^-  (pare item)
    =/  cf  (closer-first ts "an item")
    ?^  cf  u.cf
    ?:  ?&  ?=(?(%tuple %change) kind)
            ?=([[* * [%name *]] [* %& %'='] *] ts)
        ==
      =*  nam  i.ts
      =/  rest=(list token)  t.t.ts
      ?:  |(?=(~ rest) !tight.i.rest)  (bad-space i.t.ts rest "a value")
      ;<  [v=expr after=(list token)]  then  (read-expr rest)
      [%& [[beg.at.nam end:(span-of v)] `p.lex.nam v] after]
    ?:  ?=(%change kind)  (unnamed ts)
    ;<  [v=expr after=(list token)]  then  (read-expr ts)
    [%& [(span-of v) ~ v] after]
  ::
  ::  +read-gate-wide: |=( sample operand ), the one wide expression; it
  ::  closes with its body's lines when its body took the deeper lines
  ::  (+shut), but a sample that took them leaves it no body (+doomed)
  ::
  ++  read-gate-wide
    |=  [op=token ts=(list token)]
    ^-  (pare expr)
    ?:  &(?=(^ ts) |((is-closer i.ts) (is-layout i.ts)))
      (unclosed-want "a sample" ts)
    ;<  [s=sample after=(list token)]  then  (read-sample ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space after the sample" "a union is a `+$` with its cases below")
    ?:  &(?=(^ after) |((is-closer i.after) (is-layout i.after)))
      =/  dm  (doomed ts after "the gate's body")
      ?^  dm  u.dm
      (unclosed-want "the gate's body" after)
    ?:  &(?=(^ after) tight.i.after)
      (no-gap after "a space after the sample")
    ?:  &(?=(^ after) (is-rune i.after))
      %:  bad-in-why  after  "an expression"  operand-mask
        "the wide gate's body is an operand, so a rune goes in parentheses"
      ==
    ;<  [b=expr more=(list token)]  then  (read-operand after)
    ?:  ?=([[* * %')'] *] more)
      [%& [%gate-wide [beg.at.op end.at.i.more] s b] t.more]
    ?:  (shut op `(span-of b) more)
      [%& [%gate-wide [beg.at.op end:(span-of b)] s b] more]
    ?.  &(?=(^ more) !tight.i.more (is-operand-start i.more))
      (unclosed op ")" more)
    %^  bad-why  more  (closing op ")")
    "the wide gate's body is one operand, so a call goes in parentheses"
  ::
  ::  +read-gate: |= sample, then an expression or a body
  ::
  ++  read-gate
    |=  [bar=token ts=(list token)]
    ^-  (pare expr)
    ?:  &(?=(^ ts) tight.i.ts)
      ::  a % could begin a constructor's term, as |=%got
      ?:  =('%' (first-char i.ts))  (bad-in ts "a term" cen-mask)
      (no-gap ts "a space after `|=`")
    ;<  [s=sample after=(list token)]  then  (read-sample ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space after the sample" "a union is a `+$` with its cases below")
    =/  dm  (doomed ts after "an expression, or a body on deeper lines")
    ?^  dm  u.dm
    ;<  [e=expr more=(list token)]  then
      (read-expr-or-body "the sample" after)
    [%& [%gate [beg.at.bar end:(span-of e)] s e] more]
  ::
  ::  +read-cast: ^- mold, then an expression or a body
  ::
  ++  read-cast
    |=  [ket=token ts=(list token)]
    ^-  (pare expr)
    ?:  &(?=(^ ts) tight.i.ts)  (wide-rune "^-" ts)
    ;<  [s=shape after=(list token)]  then  (read-mold ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space after the mold" "a union is a `+$` with its cases below")
    =/  dm  (doomed ts after "an expression, or a body on deeper lines")
    ?^  dm  u.dm
    ;<  [e=expr more=(list token)]  then
      (read-expr-or-body "the mold" after)
    [%& [%cast [beg.at.ket end:(span-of e)] s e] more]
  ::
  ::  +read-trace: ~& expr, then its body below
  ::
  ++  read-trace
    |=  [sig=token ts=(list token)]
    ^-  (pare expr)
    ?:  &(?=(^ ts) tight.i.ts)  (wide-rune "~&" ts)
    ;<  [v=expr after=(list token)]  then  (read-expr ts)
    ?.  ?=([[* * %indent] *] after)
      =/  dm  (doomed ts after "`~&`'s body on deeper lines")
      ?^  dm  u.dm
      (bad after "`~&`'s body on deeper lines")
    ;<  [b=expr more=(list token)]  then  (read-body t.after)
    [%& [%trace [beg.at.sig end:(span-of b)] v b] more]
  ::
  ::  +read-branch: ?- expr, then its arms below, one per line
  ::
  ++  read-branch
    |=  [wut=token ts=(list token)]
    ^-  (pare expr)
    ?:  &(?=(^ ts) tight.i.ts)  (wide-rune "?-" ts)
    ;<  [s=expr after=(list token)]  then  (read-expr ts)
    ?.  ?=([[* * %indent] *] after)
      =/  dm  (doomed ts after "`?-`'s arms on deeper lines")
      ?^  dm  u.dm
      (bad after "`?-`'s arms on deeper lines")
    =|  arms=(list arm)
    =/  rest=(list token)  t.after
    |-  ^-  (pare expr)
    ;<  [a=arm more=(list token)]  then  (read-arm rest)
    ?:  ?=([[* * %newline] *] more)  $(arms [a arms], rest t.more)
    ?.  ?=([[* * %dedent] *] more)  (bad-end-in more (tail-can val.a))
    [%& [%branch [beg.at.wut end.at.a] s (flop [a arms])] t.more]
  ::
  ::  +read-arm: a pattern, then an expression or a body
  ::
  ++  read-arm
    |=  ts=(list token)
    ^-  (pare arm)
    ;<  [p=pattern after=(list token)]  then  (read-pattern ts)
    ?:  ?=([[* %& %'+'] *] after)
      %^  bad-why  after  "a space after the pattern"
      "patterns take no pairs: write a cell, as [%gap %s2]"
    ?:  ?=([[* %& %'='] *] after)
      %^  bad-why  after  "a space after the pattern"
      "patterns take no `name=`: a bare name binds, as [a b]"
    ;<  [e=expr more=(list token)]  then
      (read-expr-or-body "the pattern" after)
    [%& [[beg:(span-of p) end:(span-of e)] p e] more]
  ::
  ::  +read-pattern: a term, number, string, ship, loobean, ~, * or name,
  ::  or a cell of patterns
  ::
  ::    Where a pattern can't take a token, the error points where the
  ::    token stops being a pattern's start (+fail-in): a date or knot
  ::    at its second character, since ~ alone is null; a duration at its
  ::    third, as ~s could begin the ship ~sev; ~[ at its [; a string
  ::    with {…} at its {; a wing at its first dot.
  ::
  ++  read-pattern
    |=  ts=(list token)
    ^-  (pare pattern)
    ?~  ts  (bad ts "a pattern")
    =*  t  i.ts
    ?+    lex.t  (bad-in ts "a pattern" pattern-mask)
        [%lit *]
      =*  l  p.lex.t
      ?:  ?=(?(%number %ship %term %loobean %null) form.l)
        [%& [%lit at.t l] t.ts]
      =/  what=tape
        ?-  form.l
          %date      "dates"
          %duration  "durations"
          %knot      "knots"
        ==
      =/  n=@ud  ?:(?=(%duration form.l) 2 1)
      %+  bad-at  [line.beg.at.t (add n col.beg.at.t)]
      ;:  weld
        "expected a pattern, found {(show-found t)}; patterns take no "
        what
        ": compare values with ?- (eq a b)"
      ==
    ::
      [%str *]   [%& [%str at.t p.lex.t] t.ts]
      %'*'       [%& [%any at.t ~] t.ts]
      [%name *]  [%& [%bind at.t p.lex.t] t.ts]
      %'['       (read-cell-pattern t t.ts)
      %'`'       (bad-why ts "a pattern" "patterns take no units: write [~ x]")
    ::
        [%wing *]
      %:  bad-in-why  ts  "a pattern"  pattern-mask
        "a name in a pattern binds anew, so it has no `.`"
      ==
    ::
        [%str-head *]
      %+  bad-at  [line.end.at.t (dec (max 2 col.end.at.t))]
      %+  weld  "expected a pattern, found a string with `\{…}`; "
      "patterns take strings without `\{…}`"
    ::
        %'~['
      %+  bad-at  [line.beg.at.t +(col.beg.at.t)]
      "expected a pattern, found `~[`; patterns take no lists"
    ==
  ::
  ::  +read-cell-pattern: [ pattern { pattern } ], closed on its line
  ::
  ++  read-cell-pattern
    |=  [op=token ts=(list token)]
    ^-  (pare pattern)
    =|  ps=(list pattern)
    |-  ^-  (pare pattern)
    ?:  ?=([[* * %']'] *] ts)
      ?~  ps  (bad ts "a pattern")
      [%& [%cell [beg.at.op end.at.i.ts] (flop ps)] t.ts]
    ?:  &(?=(^ ts) |((is-closer i.ts) (is-layout i.ts)))
      ?~  ps  (unclosed-want "a pattern" ts)
      (unclosed op "]" ts)
    ?:  &(?=(^ ps) ?=(^ ts) tight.i.ts)  (no-space-pattern ts)
    ;<  [p=pattern after=(list token)]  then  (read-pattern ts)
    $(ps [p ps], ts after)
  ::
  ::  +read-sample: a gate's sample, a field, except that a bare name
  ::  binds, alone or in a cell sample at any depth (section 3). A cell
  ::  sample's [ has no open form, but closes with the deeper lines when
  ::  its last item took them (+shut), which leaves the gate no body
  ::
  ++  read-sample
    |=  ts=(list token)
    ^-  (pare sample)
    ?:  ?=([[* * [%name *]] [* %& %'='] *] ts)  (read-face ts)
    ?:  ?=([[* * [%name *]] *] ts)  [%& [%bind at.i.ts p.lex.i.ts] t.ts]
    ?:  ?=([[* * %'='] *] ts)  (read-pun i.ts t.ts)
    ?:  &(?=(^ ts) (is-layout i.ts))  (bad-line ts "a sample")
    ?:  ?=([[* * [%error *]] *] ts)
      (bad-in ts "a mold" (con mold-mask tis-mask))
    ?.  ?=([[* * %'['] *] ts)
      ;<  [s=shape after=(list token)]  then  (read-mold ts)
      [%& [%bare (span-of s) s] after]
    =*  op  i.ts
    =|  ss=(list sample)
    =/  rest=(list token)  t.ts
    |-  ^-  (pare sample)
    ?:  ?=([[* * %']'] *] rest)
      ?~  ss  (bad rest "a sample")
      [%& [%cell [beg.at.op end.at.i.rest] (flop ss)] t.rest]
    ?:  &(?=(^ ss) (shut op `(span-of i.ss) rest))
      [%& [%cell [beg.at.op end:(span-of i.ss)] (flop ss)] rest]
    ?:  &(?=(^ rest) |((is-closer i.rest) (is-layout i.rest)))
      ?~  ss  (unclosed-want "a sample" rest)
      (unclosed op "]" rest)
    ?:  &(?=(^ ss) ?=(^ rest) tight.i.rest)  (no-space rest)
    ;<  [s=sample after=(list token)]  then  (read-sample rest)
    ?:  (hoon-union rest after)
      (bad-why after "a space between items" "a union is a `+$` with its cases below")
    $(ss [s ss], rest after)
  ::
  ::  +read-field: a cell mold's field: name=mold, =name, or a mold
  ::
  ++  read-field
    |=  ts=(list token)
    ^-  (pare field)
    ?:  ?=([[* * [%name *]] [* %& %'='] *] ts)  (read-face ts)
    ?:  ?=([[* * %'='] *] ts)  (read-pun i.ts t.ts)
    ::  = begins a pun here, as a mold's first characters begin a mold
    ?:  ?=([[* * [%error *]] *] ts)
      (bad-in ts "a mold" (con mold-mask tis-mask))
    ;<  [s=shape after=(list token)]  then  (read-mold ts)
    [%& [%bare (span-of s) s] after]
  ::
  ::  +read-face: name=mold, with no spaces
  ::
  ++  read-face
    |=  ts=(list token)
    ^-  (pare field)
    ?.  ?=([[* * [%name *]] [* * %'='] *] ts)  (bad ts "a name")
    =*  nam  i.ts
    =/  rest=(list token)  t.t.ts
    ?:  |(?=(~ rest) !tight.i.rest)  (bad-space i.t.ts rest "a mold")
    ;<  [s=shape after=(list token)]  then  (read-mold rest)
    [%& [%face [beg.at.nam end:(span-of s)] p.lex.nam s] after]
  ::
  ::  +read-pun: =name, with no space, for name=name
  ::
  ++  read-pun
    |=  [tis=token ts=(list token)]
    ^-  (pare field)
    ?:  |(?=(~ ts) !tight.i.ts)  (bad-space tis ts "a name")
    ?.  ?=([[* * [%name *]] *] ts)  (no-name ts)
    [%& [%pun [beg.at.tis end.at.i.ts] p.lex.i.ts] t.ts]
  ::
  ::  +read-mold: one mold
  ::
  ++  read-mold
    |=  ts=(list token)
    ^-  (pare shape)
    ?~  ts  (bad ts "a mold")
    =*  t  i.ts
    ?+    lex.t  (bad-in ts "a mold" mold-mask)
      [%aura *]  [%& [%aura at.t p.lex.t] t.ts]
      %'*'       [%& [%noun at.t ~] t.ts]
      %'!!'      [%& [%void at.t ~] t.ts]
      %'?'       [%& [%flag at.t ~] t.ts]
      %'_'       [%& [%hole at.t ~] t.ts]
      [%name *]  [%& [%ref at.t ~[p.lex.t]] t.ts]
      [%wing *]  [%& [%ref at.t p.lex.t] t.ts]
      [%tvar *]  [%& [%tvar at.t p.lex.t] t.ts]
      %'/'       (read-pathmold t t.ts)
      %'('       (read-apply t t.ts)
      %'['       (read-cell-mold t t.ts)
      %'$-('     (read-fn t t.ts)
      %'|$'      %:  bad-in-why  ts  "a mold"  mold-mask
        "`|$` goes right after a `+$`'s name, as in +$ result |$ [V E]"
      ==
    ::
        ?(%'|=' %'|=(')
      %:  bad-in-why  ts  "a mold"  mold-mask
        "a gate's mold is $-(sample product)"
      ==
    ::
        [%lit *]
      ?.  ?=(?(%null %term %loobean) form.p.lex.t)
        (bad-in ts "a mold" mold-mask)
      [%& [%const at.t p.lex.t] t.ts]
    ==
  ::
  ::  +read-molds: molds after an application name, to its ) or its last
  ::  mold's deeper lines (+shut). Each follows a space; ( may be left
  ::  open, with one mold per deeper line (mlines).
  ::
  ++  read-molds
    |=  [op=token ts=(list token)]
    ^-  (pare [(list shape) loc])
    =|  ms=(list shape)
    |-  ^-  (pare [(list shape) loc])
    ?:  ?=([[* * %')'] *] ts)
      ?~  ms  (bad ts "a mold")
      [%& [(flop ms) end.at.i.ts] t.ts]
    ?:  ?=([[* * %indent] *] ts)
      ;<  [ls=(list shape) more=(list token)]  then  (read-mlines t.ts)
      =/  every=(list shape)  (weld (flop ms) ls)
      [%& [every ?~(every end.at.op end:(span-of (rear every)))] more]
    ?:  (shut op ?~(ms ~ `(span-of i.ms)) ts)
      [%& [(flop ms) ?~(ms end.at.op end:(span-of i.ms))] ts]
    ?:  ?=([[* * ?(%newline %dedent)] *] ts)
      (unclosed-open op ")" "a mold" ts)
    ?:  &(?=(^ ts) |((is-closer i.ts) (is-layout i.ts)))
      ?~  ms  (unclosed-want "a mold" ts)
      (unclosed op ")" ts)
    ?:  &(?=(^ ts) tight.i.ts)  (no-space ts)
    ;<  [m=shape after=(list token)]  then  (read-mold ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space between items" "a union is a `+$` with its cases below")
    $(ms [m ms], ts after)
  ::
  ::  +read-apply: ( ref mold { mold } ), or ( ref { mold } and its
  ::  lines below, left open; the name stays on the first line
  ::
  ++  read-apply
    |=  [op=token ts=(list token)]
    ^-  (pare shape)
    =/  want=tape  "a mold's name, as in (list @t)"
    ?:  &(?=(^ ts) (is-layout i.ts))
      %:  fail-line  file  ts  want
        "a `(` keeps the mold's name on its first line"
      ==
    ?.  ?=([[* * ?([%name *] [%wing *])] *] ts)  (bad-in ts want lower-mask)
    ;<  [[ms=(list shape) fin=loc] after=(list token)]  then
      (read-molds op t.ts)
    [%& [%apply [beg.at.op fin] (names-of lex.i.ts) ms] after]
  ::
  ::  +read-fn: $-( mold mold ), closed on its line, or with the product
  ::  when that took the deeper lines (+shut); a sample that took them
  ::  leaves it no product (+doomed)
  ::
  ++  read-fn
    |=  [op=token ts=(list token)]
    ^-  (pare shape)
    ?:  &(?=(^ ts) |((is-closer i.ts) (is-layout i.ts)))
      (unclosed-want "a mold" ts)
    ;<  [a=shape after=(list token)]  then  (read-mold ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space between items" "a union is a `+$` with its cases below")
    =/  want=tape  "a mold, the product"
    ?:  &(?=(^ after) |((is-closer i.after) (is-layout i.after)))
      =/  dm  (doomed ts after want)
      ?^  dm  u.dm
      (unclosed-want want after)
    ?:  &(?=(^ after) tight.i.after)  (no-space after)
    ;<  [b=shape more=(list token)]  then  (read-mold after)
    ?:  (hoon-union after more)
      (bad-why more "a space between items" "a union is a `+$` with its cases below")
    ?:  ?=([[* * %')'] *] more)
      [%& [%fn [beg.at.op end.at.i.more] a b] t.more]
    ?:  (shut op `(span-of b) more)
      [%& [%fn [beg.at.op end:(span-of b)] a b] more]
    (unclosed op ")" more)
  ::
  ::  +read-cell-mold: [ field { field } ], or [ { field } and its lines
  ::  below, left open (flines), or closed with its last field's lines
  ::  when that took the deeper lines (+shut)
  ::
  ++  read-cell-mold
    |=  [op=token ts=(list token)]
    ^-  (pare shape)
    =|  fs=(list field)
    |-  ^-  (pare shape)
    ?:  ?=([[* * %']'] *] ts)
      ?~  fs  (bad ts "a mold")
      [%& [%cell [beg.at.op end.at.i.ts] (flop fs)] t.ts]
    ?:  ?=([[* * %indent] *] ts)
      ;<  [ls=(list field) more=(list token)]  then  (read-flines t.ts)
      =/  every=(list field)  (weld (flop fs) ls)
      =/  fin=loc  ?~(every end.at.op end:(span-of (rear every)))
      [%& [%cell [beg.at.op fin] every] more]
    ?:  &(?=(^ fs) (shut op `(span-of i.fs) ts))
      [%& [%cell [beg.at.op end:(span-of i.fs)] (flop fs)] ts]
    ?:  ?=([[* * ?(%newline %dedent)] *] ts)
      (unclosed-open op "]" "a field" ts)
    ?:  &(?=(^ ts) |((is-closer i.ts) (is-layout i.ts)))
      (unclosed op "]" ts)
    ?:  &(?=(^ fs) ?=(^ ts) tight.i.ts)  (no-space ts)
    ;<  [f=field after=(list token)]  then  (read-field ts)
    ?:  (hoon-union ts after)
      (bad-why after "a space between items" "a union is a `+$` with its cases below")
    $(fs [f fs], ts after)
  ::
  ::  +read-mlines: after a mold's open ('s INDENT, one mold per line, to
  ::  its DEDENT
  ::
  ++  read-mlines
    |=  ts=(list token)
    ^-  (pare (list shape))
    =|  ms=(list shape)
    |-  ^-  (pare (list shape))
    =/  cf  (closer-first ts "a mold")
    ?^  cf  u.cf
    ;<  [m=shape after=(list token)]  then  (read-mold ts)
    ?:  (hoon-union ts after)
      (bad-why after "the end of the line" "a union is a `+$` with its cases below")
    ?:  ?=([[* * %newline] *] after)  $(ms [m ms], ts t.after)
    ?:  ?=([[* * %dedent] *] after)  [%& (flop [m ms]) t.after]
    (mold-line-end after "mold")
  ::
  ::  +read-flines: after a mold's open ['s INDENT, one field per line, to
  ::  its DEDENT
  ::
  ++  read-flines
    |=  ts=(list token)
    ^-  (pare (list field))
    =|  fs=(list field)
    |-  ^-  (pare (list field))
    =/  cf  (closer-first ts "a field")
    ?^  cf  u.cf
    ;<  [f=field after=(list token)]  then  (read-field ts)
    ?:  (hoon-union ts after)
      (bad-why after "the end of the line" "a union is a `+$` with its cases below")
    ?:  ?=([[* * %newline] *] after)  $(fs [f fs], ts t.after)
    ?:  ?=([[* * %dedent] *] after)  [%& (flop [f fs]) t.after]
    (mold-line-end after "field")
  ::
  ::  +mold-line-end: what goes on after the one mold or field of an open
  ::  mold bracket's line (noun: which); nothing does but its end
  ::
  ++  mold-line-end
    |=  [ts=(list token) noun=tape]
    ^-  [%| p=error]
    ?:  ?=([[* * ?(%')' %']')] *] ts)  (closer-after ts)
    ?:  |(?=(~ ts) tight.i.ts (is-layout i.ts) ?=([%error *] lex.i.ts))
      (bad-end-in ts 0)
    %^  bad-why  ts  "the end of the line"
    "a bracket open at the end of its line takes one {noun} per line"
  ::
  ::  +read-generic: |$ [ typevar { typevar } ], then a definition body
  ::
  ++  read-generic
    |=  [bar=token ts=(list token)]
    ^-  (pare shape)
    ?:  &(?=(^ ts) tight.i.ts)  (wide-rune "|$" ts)
    ?.  ?=([[* * %'['] *] ts)
      (bad-in ts "`[` and its type variables, as in |$ [M]" sel-mask)
    =*  op  i.ts
    =|  vs=(list @t)
    =/  rest=(list token)  t.ts
    |-  ^-  (pare shape)
    ?:  ?=([[* * %']'] *] rest)
      ?~  vs  (bad rest "a type variable")
      =/  more=(list token)  t.rest
      ?:  &(?=(^ more) tight.i.more)  (no-gap more "a space after `]`")
      ;<  [b=shape after=(list token)]  then  (read-def-body more)
      [%& [%generic [beg.at.bar end:(span-of b)] (flop vs) b] after]
    ?:  &(?=(^ rest) |((is-closer i.rest) (is-layout i.rest)))
      ?~  vs  (unclosed-want "a type variable" rest)
      (unclosed op "]" rest)
    ?:  &(?=(^ vs) ?=(^ rest) tight.i.rest)  (no-space rest)
    ?.  ?=([[* * [%tvar *]] *] rest)
      (bad-in rest "a type variable" upper-mask)
    $(vs [p.lex.i.rest vs], rest t.rest)
  ::
  ::  +read-pathmold: / [ segment { / segment } ], each / and segment
  ::  tight; / alone is the empty path
  ::
  ++  read-pathmold
    |=  [sl=token ts=(list token)]
    ^-  (pare shape)
    ?.  ?=([[* %& ?([%knot *] %'[')] *] ts)
      ?:  &(?=(^ ts) tight.i.ts !(is-closer i.ts))
        (bad ts "a path segment")
      [%& [%path at.sl ~] ts]
    =|  segs=(list pseg)
    |-  ^-  (pare shape)
    ;<  [[s=pseg fin=loc] after=(list token)]  then  (read-pseg ts)
    ?.  ?=([[* %& %'/'] *] after)
      [%& [%path [beg.at.sl fin] (flop [s segs])] after]
    =/  nex=(list token)  t.after
    ?:  ?=([[* %& ?([%knot *] %'[')] *] nex)
      $(segs [s segs], ts nex)
    ?:  &(?=(^ nex) tight.i.nex)  (bad nex "a path segment")
    (bad-space i.after nex "a path segment")
  ::
  ::  +read-pseg: a path mold's knot, [name=aura], or [name=_] with no
  ::  spaces, and where it ends
  ::
  ++  read-pseg
    |=  ts=(list token)
    ^-  (pare [pseg loc])
    ?:  ?=([[* * [%knot *]] *] ts)
      [%& [[%knot p.lex.i.ts] end.at.i.ts] t.ts]
    ?.  ?=([[* * %'['] *] ts)  (bad ts "a path segment")
    =*  op  i.ts
    =/  r1=(list token)  t.ts
    ?:  |(?=(~ r1) !tight.i.r1)  (bad-space op r1 "a name")
    ?.  ?=([[* * [%name *]] *] r1)  (no-name r1)
    =/  r2=(list token)  t.r1
    ?:  |(?=(~ r2) !tight.i.r2)  (bad-space i.r1 r2 "`=`")
    ?.  ?=([[* * %'='] *] r2)  (bad-in r2 "`=`" tis-mask)
    =/  r3=(list token)  t.r2
    ?:  |(?=(~ r3) !tight.i.r3)  (bad-space i.r2 r3 "an aura or type hole")
    ?.  ?=([[* * ?([%aura *] %'_')] *] r3)  (bad-in r3 "an aura or type hole" (con pat-mask (bex 95)))
    =/  r4=(list token)  t.r3
    ?:  |(?=(~ r4) !tight.i.r4)  (bad-space i.r3 r4 "`]`")
    ?.  ?=([[* * %']'] *] r4)  (bad-in r4 "`]`" ser-mask)
    =/  at=span  [beg.at.op end.at.i.r4]
    =/  seg=pseg
      ?:  ?=(%'_' lex.i.r3)  [%inferred at p.lex.i.r1 at.i.r3]
      [%typed at p.lex.i.r1 p.lex.i.r3]
    [%& [seg end.at.i.r4] t.r4]
  --
::
+|  %span-check
::
::  +outline: a node as +check-spans sees it
::
::    lead lists the kinds (+kind-of) of token the node may start with,
::    or is ~ when it starts with its first child; stop says where it
::    ends (+stop).
::
+$  outline
  $~  [%$ *span ~ %kid ~]
  $:  kind=@tas
      at=span
      lead=(list @)
      =stop
      kids=(list outline)
  ==
::
::  +stop: where a node ends, by the tokens of its text alone
::
::    %kid     with its last child
::    %one     where its first token ends: a name, a literal
::    %two     where the token after its first ends: |=%got, =msg, /- todo
::    %shut    at the closer of its first token, an opener closed on its
::             line; or with its last child, if that opener is left open
::             or is a rune with its body below
::    %shut2   likewise from the token after its first, a change's (
::    %run     at the end of the path it starts: then each tight / and
::             knot, and each tight [ or ( to its closer; or with its
::             last child, if a ( is left open
::    %run3    likewise from its third token, an import's path
::    %string  at the str-tail that ends its string, past each str-mid
::
+$  stop  ?(%kid %one %two %shut %shut2 %run %run3 %string)
::
::  +tinfo: a token as +check-spans sees it: its kind, its end, and the
::  next token's start and whether that is tight, unless it is a layout
::  token
::
+$  tinfo  [kind=@ end=loc nex=(unit [beg=loc tight=?])]
::
::  +check-spans: whether a module's spans follow section 1's rules
::
::    A node starts at its first token and ends where its last token
::    ends, never at a layout token: at its own token where it has one
::    there (a rune, a name, an opener), else where its first child does;
::    and at the token +stop names, which it finds from the tokens alone,
::    matching each opener with its closer on the line. Its children's
::    spans lie inside its own in source order, and so do the module's
::    imports and definitions. Gives the first node that breaks a rule,
::    and how, or ~. +check-spans-test checks that it catches spans a
::    parser bug could give.
::
++  check-spans
  |=  [mod=module toks=(list token)]
  ^-  (unit tape)
  %+  check-outlines  toks
  (weld (turn imports.mod outline-import) (turn defs.mod outline-def))
::
::  +check-outlines: +check-spans over the outlines of a module's nodes
::
++  check-outlines
  |=  [toks=(list token) os=(list outline)]
  ^-  (unit tape)
  (check-kids (index-tokens toks) ~ os)
::
::  +index-tokens: each token that isn't a layout token, by its start,
::  and each opener's closer on its line, by their starts
::
::    A str-head opens an interpolation that a str-mid or str-tail
::    closes, and a str-mid opens the next. Openers still open at the end
::    of a line have no closer.
::
++  index-tokens
  |=  toks=(list token)
  ^-  [info=(map loc tinfo) mat=(map loc loc)]
  =|  info=(map loc tinfo)
  =|  mat=(map loc loc)
  =|  open=(list loc)
  |-  ^-  [info=(map loc tinfo) mat=(map loc loc)]
  ?~  toks  [info mat]
  =*  t  i.toks
  ?:  (is-layout t)  $(toks t.toks, open ~)
  =/  k=@  (kind-of t)
  =/  nex=(unit [beg=loc tight=?])
    ?:  |(?=(~ t.toks) (is-layout i.t.toks))  ~
    `[beg.at.i.t.toks tight.i.t.toks]
  =.  info  (~(put by info) beg.at.t [k end.at.t nex])
  ?:  ?=(?(%'(' %'[' %'~[' %'|=(' %'$-(' %str-head) k)
    $(toks t.toks, open [beg.at.t open])
  ?.  ?=(?(%')' %']' %str-mid %str-tail) k)  $(toks t.toks)
  ?~  open  $(toks t.toks)
  %=  $
    toks  t.toks
    mat   (~(put by mat) i.open beg.at.t)
    open  ?:(?=(%str-mid k) [beg.at.t t.open] t.open)
  ==
::
::  +kind-of: a token's kind: a glyph, or its lexeme's tag
::
++  kind-of
  |=  t=token
  ^-  @
  ?@(lex.t lex.t -.lex.t)
::
::  +check-kids: nodes in source order, inside the span in, each checked
::
++  check-kids
  |=  $:  idx=[info=(map loc tinfo) mat=(map loc loc)]
          in=(unit span)
          os=(list outline)
      ==
  ^-  (unit tape)
  =|  prev=(unit span)
  |-  ^-  (unit tape)
  ?~  os  ~
  =*  o  i.os
  ?:  &(?=(^ in) (loc-lth beg.at.o beg.u.in))
    `(span-bad o "starts before its parent")
  ?:  &(?=(^ in) (loc-lth end.u.in end.at.o))
    `(span-bad o "ends after its parent")
  ?:  &(?=(^ prev) (loc-lth beg.at.o end.u.prev))
    `(span-bad o "starts before the node before it ends")
  =/  bad=(unit tape)  (check-outline idx o)
  ?^  bad  bad
  $(prev `at.o, os t.os)
::
::  +check-outline: one node's start and end, then its children
::
++  check-outline
  |=  [idx=[info=(map loc tinfo) mat=(map loc loc)] o=outline]
  ^-  (unit tape)
  =*  ks  kids.o
  =/  head=(unit span)  ?~(ks ~ `at.i.ks)
  =/  tail=(unit span)  ?~(ks ~ `at:(rear ks))
  ?.  (loc-lth beg.at.o end.at.o)  `(span-bad o "is empty")
  ::  the start: its own token, or its first child's
  =/  start=(unit tape)
    ?~  lead.o
      ?~  head  `"has no token or child to start with"
      ?:  =(beg.at.o beg.u.head)  ~
      `"should start where its first child does, at {(show-loc beg.u.head)}"
    =/  t=(unit tinfo)  (~(get by info.idx) beg.at.o)
    ?~  t  `"starts where no token does"
    ?.  (lien `(list @)`lead.o |=(a=@ =(a kind.u.t)))
      `"starts at a token of a kind it can't start with"
    ?:  &(?=(^ head) !(loc-lth beg.at.o beg.u.head))
      `"should start with its own token, before its first child"
    ~
  ?^  start  `(span-bad o u.start)
  ::  the end: where +stop says
  =/  want=(unit loc)  (stop-of idx o tail)
  ?~  want  `(span-bad o "has no end that its tokens give")
  ?.  =(u.want end.at.o)
    `(span-bad o "should end at {(show-loc u.want)}")
  (check-kids idx `at.o ks)
::
::  +stop-of: where a node should end, from its stop, the tokens, and
::  its last child's span, tail
::
++  stop-of
  |=  $:  idx=[info=(map loc tinfo) mat=(map loc loc)]
          o=outline
          tail=(unit span)
      ==
  ^-  (unit loc)
  =*  info  info.idx
  =/  first=(unit tinfo)  (~(get by info) beg.at.o)
  ::  the token after the one at beg, if it is on the same line
  =/  after
    |=  beg=loc
    ^-  (unit loc)
    =/  t=(unit tinfo)  (~(get by info) beg)
    ?~  t  ~
    ?~  nex.u.t  ~
    `beg.u.nex.u.t
  ::  the end of the token at beg
  =/  end-at
    |=  beg=loc
    ^-  (unit loc)
    =/  t=(unit tinfo)  (~(get by info) beg)
    ?~(t ~ `end.u.t)
  ::  the closer of the opener at beg, else the last child
  =/  shut
    |=  beg=loc
    ^-  (unit loc)
    =/  c=(unit loc)  (~(get by mat.idx) beg)
    ?^  c  (end-at u.c)
    ?~(tail ~ `end.u.tail)
  ::  a path from the token at beg: each tight / and knot after it, and
  ::  each tight [ or ( to its closer, or a ( left open to the end of
  ::  the last child, whose lines it closed with
  =/  run
    |=  beg=loc
    ^-  (unit loc)
    |-  ^-  (unit loc)
    =/  t=(unit tinfo)  (~(get by info) beg)
    ?~  t  ~
    =/  n  nex.u.t
    ?.  &(?=(^ n) tight.u.n)  `end.u.t
    =/  nk=(unit tinfo)  (~(get by info) beg.u.n)
    ?~  nk  `end.u.t
    ?:  ?=(?(%'/' %knot) kind.u.nk)  $(beg beg.u.n)
    ?.  ?=(?(%'[' %'(') kind.u.nk)  `end.u.t
    =/  c=(unit loc)  (~(get by mat.idx) beg.u.n)
    ?^  c  $(beg u.c)
    ?.  &(?=(%'(' kind.u.nk) ?=(^ tail))  `end.u.t
    `end.u.tail
  ?-    stop.o
    %kid    ?~(tail ~ `end.u.tail)
    %one    (end-at beg.at.o)
    %shut   (shut beg.at.o)
    %run    (run beg.at.o)
    %two    =/(n (after beg.at.o) ?~(n ~ (end-at u.n)))
    %shut2  =/(n (after beg.at.o) ?~(n ~ (shut u.n)))
  ::
      %run3
    =/  n  (after beg.at.o)
    ?~  n  ~
    =/  m  (after u.n)
    ?~  m  ~
    (run u.m)
  ::
      %string
    =/  beg=loc  beg.at.o
    |-  ^-  (unit loc)
    =/  c=(unit loc)  (~(get by mat.idx) beg)
    ?~  c  ~
    =/  t=(unit tinfo)  (~(get by info) u.c)
    ?~  t  ~
    ?:  ?=(%str-tail kind.u.t)  `end.u.t
    $(beg u.c)
  ==
::
::  +span-bad: a span check's error, naming the node by kind and span
::
++  span-bad
  |=  [o=outline why=tape]
  ^-  tape
  "({(trip kind.o)} {(show-loc beg.at.o)} to {(show-loc end.at.o)}) {why}"
::
::  +loc-lth: whether a comes before b
::
++  loc-lth
  |=  [a=loc b=loc]
  ^-  ?
  ?|  (lth line.a line.b)
      &(=(line.a line.b) (lth col.a col.b))
  ==
::
++  outline-import
  |=  i=import
  ^-  outline
  ?-  -.i
    %sur   [%sur at.i ~[%'/-'] %two ~]
    %mark  [%mark at.i ~[%'/%'] %two ~]
    %jibb  [%jibb at.i ~[%'/='] %run3 ~]
  ==
::
++  outline-def
  |=  d=def
  ^-  outline
  ?-  -.d
    %mold   [%mold at.d ~[%'+$'] %kid ~[(outline-shape shape.d)]]
    %value  [%value at.d ~[%'++'] %kid ~[(outline-expr val.d)]]
  ==
::
++  outline-expr
  |=  e=expr
  ^-  outline
  ?-    -.e
    %lit    [%lit at.e ~[%lit] %one ~]
    %str    (outline-str at.e pieces.e)
    %path   [%path at.e ~[%'/'] %run ~]
    %wing   [%wing at.e ~[%name %wing] %one ~]
    %pair   [%pair at.e ~[%name] %kid ~[(outline-expr val.e)]]
    %unit   [%unit at.e ~[%'`'] %kid ~[(outline-expr val.e)]]
    %group  [%group at.e ~[%'('] %shut ~[(outline-expr inner.e)]]
    %list   [%list at.e ~[%'~['] %shut (turn items.e outline-expr)]
    %tuple  [%tuple at.e ~[%'['] %shut (turn items.e outline-item)]
    %ctor   [%ctor at.e ~[%'|='] %two ~]
    %crash  [%crash at.e ~[%'!!'] %one ~]
  ::
      %qath
    =/  ks=(list outline)
      %+  murn  segs.e
      |=(s=qseg ?.(?=(%expr -.s) ~ `(outline-expr p.s)))
    [%qath at.e ~[%'%/'] %run ks]
  ::
      %change
    =/  ks=(list outline)  (turn edits.e outline-edit)
    [%change at.e ~[%name %wing] %shut2 ks]
  ::
      %gate-wide
    =/  ks=(list outline)
      ~[(outline-sample sample.e) (outline-expr body.e)]
    [%gate-wide at.e ~[%'|=('] %shut ks]
  ::
      %call
    [%call at.e ~ %kid [(outline-expr head.e) (turn args.e outline-expr)]]
  ::
      %gate
    =/  ks=(list outline)
      ~[(outline-sample sample.e) (outline-expr body.e)]
    [%gate at.e ~[%'|='] %kid ks]
  ::
      %cast
    =/  ks=(list outline)  ~[(outline-shape shape.e) (outline-expr val.e)]
    [%cast at.e ~[%'^-'] %kid ks]
  ::
      %trace
    =/  ks=(list outline)  ~[(outline-expr val.e) (outline-expr then.e)]
    [%trace at.e ~[%'~&'] %kid ks]
  ::
      %branch
    =/  ks=(list outline)
      [(outline-expr subject.e) (turn arms.e outline-arm)]
    [%branch at.e ~[%'?-'] %kid ks]
  ::
      %body
    =/  ks=(list outline)
      (snoc (turn defs.e outline-def) (outline-expr final.e))
    [%body at.e ~ %kid ks]
  ==
::
++  outline-str
  |=  [at=span ps=(list piece)]
  ^-  outline
  =/  ks=(list outline)
    (murn ps |=(p=piece ?.(?=(%expr -.p) ~ `(outline-expr p.p))))
  ?~  ks  [%str at ~[%str] %one ~]
  [%str at ~[%str-head] %string ks]
::
++  outline-item
  |=  i=item
  ^-  outline
  ?~  face.i  [%item at.i ~ %kid ~[(outline-expr val.i)]]
  [%face at.i ~[%name] %kid ~[(outline-expr val.i)]]
::
++  outline-edit
  |=  e=edit
  ^-  outline
  [%edit at.e ~[%name] %kid ~[(outline-expr val.e)]]
::
++  outline-arm
  |=  a=arm
  ^-  outline
  [%arm at.a ~ %kid ~[(outline-pattern pat.a) (outline-expr val.a)]]
::
++  outline-sample
  |=  s=sample
  ^-  outline
  ?-  -.s
    %bind  [%bind at.s ~[%name] %one ~]
    %face  [%face at.s ~[%name] %kid ~[(outline-shape shape.s)]]
    %pun   [%pun at.s ~[%'='] %two ~]
    %cell  [%cell at.s ~[%'['] %shut (turn items.s outline-sample)]
    %bare  [%bare at.s ~ %kid ~[(outline-shape shape.s)]]
  ==
::
++  outline-pattern
  |=  p=pattern
  ^-  outline
  ?-  -.p
    %lit   [%lit at.p ~[%lit] %one ~]
    %str   [%str at.p ~[%str] %one ~]
    %any   [%any at.p ~[%'*'] %one ~]
    %bind  [%bind at.p ~[%name] %one ~]
    %cell  [%cell at.p ~[%'['] %shut (turn items.p outline-pattern)]
  ==
::
++  outline-shape
  |=  s=shape
  ^-  outline
  ?-    -.s
    %aura   [%aura at.s ~[%aura] %one ~]
    %noun   [%noun at.s ~[%'*'] %one ~]
    %void   [%void at.s ~[%'!!'] %one ~]
    %flag   [%flag at.s ~[%'?'] %one ~]
    %const  [%const at.s ~[%lit] %one ~]
    %ref    [%ref at.s ~[%name %wing] %one ~]
    %tvar   [%tvar at.s ~[%tvar] %one ~]
    %hole   [%hole at.s ~[%'_'] %one ~]
    %apply  [%apply at.s ~[%'('] %shut (turn args.s outline-shape)]
    %cell   [%cell at.s ~[%'['] %shut (turn fields.s outline-sample)]
  ::
      %path
    =/  ks=(list outline)
      %+  murn  segs.s
      |=  g=pseg
      ^-  (unit outline)
      ?-  -.g
        %knot  ~
        %typed  `[%typed at.g ~[%'['] %shut ~]
        %inferred  `[%typed at.g ~[%'['] %shut ~[[%hole hole-at.g ~[%'_'] %one ~]]]
      ==
    [%path at.s ~[%'/'] %run ks]
  ::
      %union
    =/  ks=(list outline)  (turn cases.s outline-shape)
    [%union at.s ~ %kid ks]
  ::
      %fn
    =/  ks=(list outline)
      ~[(outline-shape sample.s) (outline-shape product.s)]
    [%fn at.s ~[%'$-('] %shut ks]
  ::
      %generic
    [%generic at.s ~[%'|$'] %kid ~[(outline-shape body.s)]]
  ==
::
::  +check-spans-test: +check-spans's own test: ~, or what went wrong
::
::    Each case parses a source, checks that its spans pass, then moves
::    the span of every node of a kind that starts at a place, as a
::    parser bug would, and checks that +check-spans says so. Run it as
::    tools/hoon check-spans-test, which prints <<>> when every case
::    passes.
::
++  check-spans-test
  ^-  (list tape)
  =/  cases=(list [src=@t bends=(list [kind=@tas beg=loc at=span])])
    :~  ::  a closed bracket ending before its closer, or at its parent's
        :-  '++ x [a [b c]]'
        ~[[%tuple [1 9] [1 9] [1 13]] [%item [1 9] [1 9] [1 13]]]
        :-  '++ x [a [b c]]'
        ~[[%tuple [1 9] [1 9] [1 15]] [%item [1 9] [1 9] [1 15]]]
        ::  a bracket starting at its parent's opener
        :-  '++ x [[b c] a]'
        ~[[%tuple [1 7] [1 6] [1 12]] [%item [1 7] [1 6] [1 12]]]
        ::  a group without its ), a list at the next line, a call with )
        :-  '++ x ~[\0a  (f a)\0a++ y 1'
        :~  [%group [2 3] [2 3] [2 7]]
            [%list [1 6] [1 6] [2 7]]
            [%value [1 1] [1 1] [2 7]]
        ==
        :-  '++ x ~[\0a  (f a)\0a++ y 1'
        ~[[%list [1 6] [1 6] [3 1]] [%value [1 1] [1 1] [3 1]]]
        ['++ x ~[\0a  (f a)\0a++ y 1' ~[[%call [2 4] [2 4] [2 8]]]]
        ::  a literal running on to the next one's end
        ['++ x f 1 2' ~[[%lit [1 8] [1 8] [1 11]]]]
        ::  a path, a string, a change and a union cut short
        ['++ x f /a/b c' ~[[%path [1 8] [1 8] [1 10]]]]
        ['++ x f "a{b}c" d' ~[[%str [1 8] [1 8] [1 13]]]]
        ['++ x m(a=1) b' ~[[%change [1 6] [1 6] [1 11]]]]
        :-  '+$ x\0a  %a\0a  %b'
        ~[[%union [2 3] [2 3] [2 5]] [%mold [1 1] [1 1] [2 5]]]
        ::  a mold's cell before its closer, a typed segment past its own
        :-  '+$ x [a=[@ @] b=@]'
        ~[[%cell [1 9] [1 9] [1 13]] [%face [1 7] [1 7] [1 13]]]
        :-  '+$ x [p=/a/[id=@ud]]'
        :~  [%typed [1 12] [1 12] [1 21]]
            [%path [1 9] [1 9] [1 21]]
            [%face [1 7] [1 7] [1 21]]
        ==
        ::  an inferred path aura's hole spanning its = as well
        ['+$ x /a/[id=_]' ~[[%hole [1 13] [1 12] [1 14]]]]
        ::  an import's path cut short
        ['/=  c  /ui/c' ~[[%jibb [1 1] [1 1] [1 11]]]]
        ::  brackets that close with the deeper lines, cut at their line's
        ::  end: a group and a list, an application path's (, a wide gate,
        ::  and a mold's [ left open
        ['++ x (f ~[\0a  1' ~[[%group [1 6] [1 6] [1 11]]]]
        ['++ x (f ~[\0a  1' ~[[%list [1 9] [1 9] [1 11]]]]
        ['++ x %/a/(f ~[\0a  1' ~[[%qath [1 6] [1 6] [1 10]]]]
        ['++ g |=(a ~[\0a  1' ~[[%gate-wide [1 6] [1 6] [1 13]]]]
        :-  '+$ x [\0a  a=@\0a  b=@'
        ~[[%cell [1 6] [1 6] [2 6]] [%mold [1 1] [1 1] [2 6]]]
    ==
  %-  zing
  %+  turn  cases
  |=  [src=@t bends=(list [kind=@tas beg=loc at=span])]
  ^-  (list tape)
  =/  name=tape  "`{(trip src)}`, {<bends>}"
  =/  toks=(list token)  (layout /test/jibb src)
  =/  res  (parse-tokens /test/jibb toks)
  ?:  ?=(%| -.res)  ~["{name}: doesn't parse: {msg.p.res}"]
  =/  os=(list outline)
    %+  weld  (turn imports.p.res outline-import)
    (turn defs.p.res outline-def)
  =/  true=(unit tape)  (check-outlines toks os)
  ?^  true  ~["{name}: its true spans fail: {u.true}"]
  =/  bent=(list outline)
    =/  o=(list outline)  os
    |-  ^-  (list outline)
    ?~  bends  o
    $(bends t.bends, o (bend-outlines o kind.i.bends beg.i.bends at.i.bends))
  ?:  =(bent os)  ~["{name}: no such node"]
  ?^  (check-outlines toks bent)  ~
  ~["{name}: not caught"]
::
::  +bend-outlines: os, with the span of each node of kind kind that
::  starts at beg set to at, as a parser bug could set it
::
++  bend-outlines
  |=  [os=(list outline) kind=@tas beg=loc at=span]
  ^-  (list outline)
  ?~  os  ~
  =/  o=outline  i.os
  =?  at.o  &(=(kind kind.o) =(beg beg.at.o))  at
  :-  o(kids $(os kids.o))
  $(os t.os)
::
+|  %type-inference
::
::  Preliminary type inference substrate. These types are internal and do
::  not yet represent every Jibb mold. In particular this is not a complete
::  module checker. A substitution is an association list whose first entry
::  for a variable is its binding. The occurs check prevents infinite types;
::  recursive named molds need their own representation, not cyclic vars.
::  Each top-level inferred definition generalizes its free variables, and
::  a use instantiates them afresh. Binders inside a gate stay monomorphic;
::  capital variables in molds share one allocation within the definition.
::  Atom constraints tied to an explicit capital or an inferred sample
::  are generalized and printed. Other aura variables remain unsupported until
::  their defaulting and inferred generalization are implemented.
::  Restricted-number promotion considers written capitals only; if there
::  are none, it skips the otherwise unnecessary environment traversal.
::  Bare @ is a separate unrestricted atom type. A directional fit check
::  permits concrete atoms to widen to it, never the reverse. A fit that
::  needs a not-yet-implemented constraint remains unsupported. Named unions
::  retain origin and ordered arguments, including phantom arguments, apart
::  from their display name. Generic cases must be disjoint for all arguments.
::  Unnamed union printing is informational; it is not Jibb syntax.
::
::  `proj` is a reserved, type-directed operation, not an ordinary gate.
::  The supported fragment selects uniquely faced fields from a known record
::  in source order (reordering is a doc question). It records the original
::  call, source and target types, and source axes with its definition;
::  A single selected field keeps its face and uses one source axis.
::  Checked module interfaces retain that evidence and their source, including
::  the private prelude dependency. A later lowerer must replace the call by
::  an inline gate applied to the operand once; no lowering is implemented yet.
::  Ordinary fits never insert a projection. Unknown or variable-origin record
::  spines, nested projected fields and projections in
::  recursive groups remain unsupported. Directional fits bound faced-spine
::  proofs to fewer than 1,024 cells; the projection planner has a separate
::  4,096-step bound. These are inference limits, not language limits.
::
::  Supported API imports derive request-gate types atomically for multiple
::  paths, including one typed segment or one diff fold per case. Their checked
::  ordinary definitions, mark molds and supported poke constructor are also
::  exported. A selected /sur mold is checked through its trusted reader result;
::  unused cores and other bindings are not independently validated. APIs
::  with /= imports, separate scry paths, multiple parameters or diffs, or a
::  parameter together with a fold remain unsupported. The unchanged todo API
::  fits this fragment, including named closed fold gates.
::
::  Each case's source-derived schema and canonical API identity travel in a
::  dependency closure bound to the exact supplied bundle, prelude, scope and
::  trusted reader results. Unknown cached entries are rebuilt. Request-bearing
::  closures are limited to 256 source paths and requests. This is type
::  inference only: no request lowering, runtime schema validator or proof that
::  an arbitrary ask value is watchable is supplied.
::
::  A closed gate sample may omit one outer face from a known input slot when
::  its product is identical. Distinct written names, nested value faces,
::  ambiguous cell tails and raw-variable-origin fits retain their prior rules.
::
::  In one synthetic eval of a 48-module deep and 48-module wide request-free
::  graph, baseline versus certificate inference took 21.53 s versus 23.10 s
::  elapsed (21.10 s versus 22.34 s CPU), including startup. The deep cache's
::  jam grew from 2,402 to 4,209 bytes (+1,807 bytes). These single-run figures
::  are not production memory or performance benchmarks.
::
+$  itype
  $~  [%var 0]
  $%  [%var id=@ud]
      [%avar id=@ud]
      [%rvar id=@ud]
      [%nvar id=@ud]
      [%rnvar id=@ud]
      [%atom aura=@ta]
      [%any-atom ~]
      [%flag ~]
      [%noun ~]
      [%tag id=@ud literal=lit constructor=?]
      [%const literal=lit]
      [%collection name=term args=(list itype)]
      [%recursive module=term name=term label=(unit @t)]
      [%jrec at=path name=term label=(unit @t) head=term aura=@ta tail=term]
      [%grec at=path name=term label=(unit @t) proof=shape args=(list itype)]
      [%union cases=(list itype) origin=(unit [at=path name=term]) label=(unit @t) args=(list itype)]
      [%face name=term body=itype]
      [%fn sample=itype product=itype]
      [%cell hed=itype tal=itype]
  ==
+$  ibinding  [id=@ud val=itype]
+$  isub  (list ibinding)
+$  ipending  [id=@ud literal=lit]
::
++  itype-lookup
  |=  [n=@ud sub=isub]
  ^-  (unit itype)
  ?~  sub  ~
  ?:  =(n id.i.sub)  `val.i.sub
  $(sub t.sub)
::
++  itype-walk
  |=  [t=itype sub=isub]
  ^-  itype
  ?+  -.t  t
    %var
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
    %avar
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
    %rvar
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
    %nvar
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
    %rnvar
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
    %tag
      =/  found=(unit itype)  (itype-lookup id.t sub)
      ?~  found  t
      ?:  &(|(?=(%rvar -.u.found) ?=(%rnvar -.u.found)) =(id.t +.u.found))  u.found
      $(t u.found)
  ==
::
++  itype-occurs
  |=  [n=@ud t=itype sub=isub]
  ^-  ?
  =.  t  (itype-walk t sub)
  ?-  -.t
    %var   =(n id.t)
    %avar  =(n id.t)
    %rvar  =(n id.t)
    %nvar  =(n id.t)
    %rnvar  =(n id.t)
    %atom  |
    %any-atom  |
    %flag  |
    %noun  |
    %tag   =(n id.t)
    %const  |
    %union  |((lien cases.t |=(c=itype (itype-occurs n c sub))) (lien args.t |=(c=itype (itype-occurs n c sub))))
    %recursive  |
    %jrec       |
    %grec       (lien args.t |=(c=itype (itype-occurs n c sub)))
    %collection  (lien args.t |=(c=itype (itype-occurs n c sub)))
    %face  $(t body.t)
    %fn    |($(t sample.t) $(t product.t))
    %cell  |($(t hed.t) $(t tal.t))
  ==
::
::  +itype-unify: consistent substitutions, or ~ for a mismatch
::
::    Different concrete auras conflict. A variable may become an atom or
::    a function, but cannot contain itself. Aura-only variables and faces
::    require further distinctions before this supports general Jibb.
::
++  itype-unify
  |=  [a=itype b=itype sub=isub]
  ^-  (unit isub)
  =.  a  (itype-walk a sub)
  =.  b  (itype-walk b sub)
  ?:  =(a b)  `sub
  ?:  &(?=(%grec -.a) ?=(%grec -.b))
    ?.  &(=(at.a at.b) =(name.a name.b))  ~
    (itype-unify-args args.a args.b sub)
  ?:  &(?=(%jrec -.a) ?=(%jrec -.b))
    ?:(&(=(at.a at.b) =(name.a name.b) =(head.a head.b) =(aura.a aura.b) =(tail.a tail.b)) `sub ~)
  ?:  &(?=(%recursive -.a) ?=(%recursive -.b))
    ?:(&(=(module.a module.b) =(name.a name.b)) `sub ~)
  ?:  &(?=(%union -.a) ?=(%union -.b))
    ?.  =(origin.a origin.b)  ~
    ?:  &(?=(~ args.a) ?=(~ args.b))  ?:(=(cases.a cases.b) `sub ~)
    ?~  origin.a  ~
    (itype-unify-args args.a args.b sub)
  ?:  &(?=(%collection -.a) ?=(%collection -.b))
    ?.  =(name.a name.b)  ~
    (itype-unify-args args.a args.b sub)
  ?:  ?=(%var -.a)
    ?:  (itype-occurs id.a b sub)  ~
    `[[id.a b] sub]
  ?:  ?=(%var -.b)
    ?:  (itype-occurs id.b a sub)  ~
    `[[id.b a] sub]
  ::  Arithmetic's aura variable excludes loobeans; decimal literals
  ::  remain defaultable until a later constraint makes them concrete.
  ?:  &(?=(%nvar -.a) ?=(%rvar -.b))
    `[[id.b [%rnvar id.a]] [id.a [%rnvar id.a]] sub]
  ?:  &(?=(%rvar -.a) ?=(%nvar -.b))
    `[[id.a [%rnvar id.b]] [id.b [%rnvar id.b]] sub]
  ?:  &(?=(%rnvar -.a) ?=(%rvar -.b))  `[[id.b a] sub]
  ?:  &(?=(%rvar -.a) ?=(%rnvar -.b))  `[[id.a b] sub]
  ?:  &(?=(%rnvar -.a) ?=(%nvar -.b))  `[[id.b a] sub]
  ?:  &(?=(%nvar -.a) ?=(%rnvar -.b))  `[[id.a b] sub]
  ?:  &(?=(%rnvar -.a) ?=(%avar -.b))  `[[id.b a] sub]
  ?:  &(?=(%avar -.a) ?=(%rnvar -.b))  `[[id.a b] sub]
  ?:  ?=(%rnvar -.a)
    ?.  |(?=(%rnvar -.b) ?=(%atom -.b))  ~
    `[[id.a b] sub]
  ?:  ?=(%rnvar -.b)
    ?.  ?=(%atom -.a)  ~
    `[[id.b a] sub]
  ?:  &(?=(%avar -.a) ?=(%rvar -.b))  `[[id.a b] sub]
  ?:  &(?=(%rvar -.a) ?=(%avar -.b))  `[[id.b a] sub]
  ?:  ?=(%rvar -.a)
    ?.  |(?=(%rvar -.b) ?=(%atom -.b))  ~
    `[[id.a b] sub]
  ?:  ?=(%rvar -.b)
    ?.  ?=(%atom -.a)  ~
    `[[id.b a] sub]
  ::  The narrower decimal constraint survives a match with an atom
  ::  variable; decimal syntax alone does not make it a loobean.
  ?:  &(?=(%nvar -.a) ?=(%avar -.b))  `[[id.b a] sub]
  ?:  &(?=(%avar -.a) ?=(%nvar -.b))  `[[id.a b] sub]
  ?:  ?=(%nvar -.a)
    ?.  |(?=(%nvar -.b) ?=(%atom -.b))  ~
    `[[id.a b] sub]
  ?:  ?=(%nvar -.b)
    ?.  ?=(%atom -.a)  ~
    `[[id.b a] sub]
  ?:  ?=(%avar -.a)
    ?.  |(?=(%avar -.b) ?=(%atom -.b) ?=(%any-atom -.b) ?=(%flag -.b))  ~
    `[[id.a b] sub]
  ?:  ?=(%avar -.b)
    ?.  |(?=(%atom -.a) ?=(%any-atom -.a) ?=(%flag -.a))  ~
    `[[id.b a] sub]
  ?:  &(?=(%const -.a) ?=(%const -.b))
    ?:(=(val.literal.a val.literal.b) `sub ~)
  ?:  &(?=(%atom -.a) ?=(%atom -.b))  ~
  ?:  &(?=(%face -.a) ?=(%face -.b))
    ?.  =(name.a name.b)  ~
    $(a body.a, b body.b)
  ?:  &(?=(%fn -.a) ?=(%fn -.b))
    =/  first=(unit isub)  $(a sample.a, b sample.b)
    ?~  first  ~
    $(a product.a, b product.b, sub u.first)
  ?:  &(?=(%cell -.a) ?=(%cell -.b))
    =/  first=(unit isub)  $(a hed.a, b hed.b)
    ?~  first  ~
    $(a tal.a, b tal.b, sub u.first)
  ~
::
++  itype-unify-args
  |=  [as=(list itype) bs=(list itype) sub=isub]
  ^-  (unit isub)
  ?~  as  ?~(bs `sub ~)
  ?~  bs  ~
  =/  next=(unit isub)  (itype-unify i.as i.bs sub)
  ?~  next  ~
  $(as t.as, bs t.bs, sub u.next)
::
::  +itype-fit: one-way widening from an actual type to an expected type
::
::    An unknown variable used where @ is expected gains a fresh atom
::    constraint. Function compatibility involving @ remains unknown.
::
+$  ifit  $%([%ok sub=isub next=@ud] [%bad ~] [%unknown ~])
++  itype-has-any-atom
  |=  [t=itype sub=isub]
  ^-  ?
  =.  t  (itype-walk t sub)
  ?-  -.t
    %var       |
    %avar      |
    %rvar      |
    %nvar      |
    %rnvar      |
    %atom      |
    %any-atom  &
    %flag      |
    %noun  |
    %tag       |
    %const     |
    %union     |((lien cases.t |=(c=itype (itype-has-any-atom c sub))) (lien args.t |=(c=itype (itype-has-any-atom c sub))))
    %recursive  |
    %jrec       |
    %grec       (lien args.t |=(c=itype (itype-has-any-atom c sub)))
    %collection  (lien args.t |=(c=itype (itype-has-any-atom c sub)))
    %face      $(t body.t)
    %fn        |($(t sample.t) $(t product.t))
    %cell      |($(t hed.t) $(t tal.t))
  ==
::
::
::  Hoon aura families are textual prefixes: @tD is in @t, and @uvJ
::  is in @uv and @u. Jibb permits widening toward the prefix only.
::
++  aura-prefix
  |=  [parent=@ta child=@ta]
  ^-  ?
  =/  a=tape  (trip parent)
  =/  b=tape  (trip child)
  |-
  ?~  a  &
  ?~  b  |
  ?.  =(i.a i.b)  |
  $(a t.a, b t.b)
::
::  Related auras in a structural unification need a common-type rule;
::  until that rule is implemented, report an unknown rather than error.
::
++  itype-family-related-collection-args
  |=  [as=(list itype) bs=(list itype) sub=isub]
  ^-  ?
  ?~  as  |
  ?~  bs  |
  ?:  (itype-family-related i.as i.bs sub)  &
  $(as t.as, bs t.bs)
::
++  itype-family-related
  |=  [a=itype b=itype sub=isub]
  ^-  ?
  =.  a  (itype-walk a sub)
  =.  b  (itype-walk b sub)
  ?:  &(?=(%atom -.a) ?=(%atom -.b))
    ?.  !=(aura.a aura.b)  |
    |((aura-prefix aura.a aura.b) (aura-prefix aura.b aura.a))
  ?:  &(?=(%collection -.a) ?=(%collection -.b))
    ?.  =(name.a name.b)  |
    (itype-family-related-collection-args args.a args.b sub)
  ?:  &(?=(%face -.a) ?=(%face -.b))
    ?.  =(name.a name.b)  |
    $(a body.a, b body.b)
  ?:  &(?=(%cell -.a) ?=(%cell -.b))
    |($(a hed.a, b hed.b) $(a tal.a, b tal.b))
  ?:  &(?=(%fn -.a) ?=(%fn -.b))
    |($(a sample.a, b sample.b) $(a product.a, b product.b))
  |
::
::  A branch whose two result types are already concrete can use an
::  explicitly present parent aura (or @) as its result. This does not
::  guess a parent for sibling auras or solve variable-dependent joins.
::
++  itype-has-fixed-atom
  |=  typ=itype
  ^-  ?
  ?-  -.typ
    %var       |
    %avar      |
    %rvar      |
    %nvar      |
    %rnvar      |
    %atom      &
    %any-atom  &
    %flag      &
    %noun  |
    %tag       &
    %const     &
    %union     |((lien cases.typ |=(c=itype (itype-has-fixed-atom c))) (lien args.typ |=(c=itype (itype-has-fixed-atom c))))
    %recursive  |
    %jrec       |
    %grec       (lien args.typ |=(c=itype (itype-has-fixed-atom c)))
    %collection  (lien args.typ |=(c=itype (itype-has-fixed-atom c)))
    %face      $(typ body.typ)
    %fn        |($(typ sample.typ) $(typ product.typ))
    %cell      |($(typ hed.typ) $(typ tal.typ))
  ==
::
++  itype-concrete-join
  |=  [a=itype b=itype sub=isub]
  ^-  (unit itype)
  =.  a  (itype-walk a sub)
  =.  b  (itype-walk b sub)
  ?:  &(?=(%atom -.a) ?=(%atom -.b))
    ?:  (aura-prefix aura.a aura.b)  `a
    ?:  (aura-prefix aura.b aura.a)  `b
    ~
  ?:  &(?=(%any-atom -.a) |(?=(%atom -.b) ?=(%flag -.b)))  `a
  ?:  &(?=(%any-atom -.b) |(?=(%atom -.a) ?=(%flag -.a)))  `b
  ~
::
::  Unifying an already-bound tuple with a faced position would need to
::  update the bound type. Until substitutions can retain that information,
::  variable-dependent face merges stay unresolved.
::
++  itype-has-face
  |=  [t=itype sub=isub]
  ^-  ?
  =.  t  (itype-walk t sub)
  ?-  -.t
    %grec  (lien args.t |=(c=itype (itype-has-face c sub)))
    %collection  (lien args.t |=(c=itype (itype-has-face c sub)))
    %face      &
    %cell      |($(t hed.t) $(t tal.t))
    %fn        |($(t sample.t) $(t product.t))
    *          |
  ==
::
::  Closed function samples may omit a slot face, but a known name must
::  match another known name.  Keep nested value faces and require exact
::  invariant compatibility; a faced tail against a cell is ambiguous.
++  itype-closed-slot-match
  |=  [a=itype b=itype]
  ^-  ?
  ?:  &(?=(%face -.a) ?=(%face -.b))
    ?.  =(name.a name.b)  |
    ?=(^ (itype-unify body.a body.b ~))
  ?:  ?=(%face -.a)  ?=(^ (itype-unify body.a b ~))
  ?:  ?=(%face -.b)  ?=(^ (itype-unify a body.b ~))
  ?=(^ (itype-unify a b ~))
++  itype-closed-sample-match
  |=  [a=itype b=itype fuel=@ud]
  ^-  ?
  ?:  =(0 fuel)  |
  ?.  &(?=(%cell -.a) ?=(%cell -.b))  |
  ?.  (itype-closed-slot-match hed.a hed.b)  |
  =/  x=itype  tal.a
  =/  y=itype  tal.b
  ?:  &(?=(%cell -.x) ?=(%cell -.y))
    ?=(^ (itype-unify x y ~))
  ?:  |(&(?=(%face -.x) ?=(%cell -.y)) &(?=(%cell -.x) ?=(%face -.y)))  |
  (itype-closed-slot-match x y)
++  itype-closed-gates-match
  |=  [a=itype b=itype]
  ^-  ?
  ?.  &(?=(%fn -.a) ?=(%fn -.b))  |
  ?.  &(?=(%cell -.sample.a) ?=(%cell -.sample.b))  |
  ?.  =(product.a product.b)  |
  ?^  (itype-vars a)  |
  ?^  (itype-vars b)  |
  ?:  |((itype-has-tag a) (itype-has-tag b))  |
  ?.  (itype-closed-sample-match sample.a sample.b 1.024)  |
  ?=(^ (itype-unify product.a product.b ~))
::
++  itype-face-asym-collection-args
  |=  [as=(list itype) bs=(list itype) sub=isub]
  ^-  ?
  ?~  as  |
  ?~  bs  |
  ?:  (itype-face-asym i.as i.bs sub)  &
  $(as t.as, bs t.bs)
::
++  itype-face-asym
  |=  [a=itype b=itype sub=isub]
  ^-  ?
  =.  a  (itype-walk a sub)
  =.  b  (itype-walk b sub)
  ?:  &(?=(%grec -.a) ?=(%grec -.b))
    ?.  &(=(at.a at.b) =(name.a name.b))  |
    (itype-face-asym-collection-args args.a args.b sub)
  ?:  &(?=(%collection -.a) ?=(%collection -.b))
    ?.  =(name.a name.b)  |
    (itype-face-asym-collection-args args.a args.b sub)
  ?:  &(?=(%face -.a) ?=(%face -.b))  $(a body.a, b body.b)
  ?:  ?=(%face -.a)  !|(?=(%var -.b) ?=(%avar -.b) ?=(%rvar -.b) |(?=(%nvar -.b) ?=(%rnvar -.b)))
  ?:  ?=(%face -.b)  !|(?=(%var -.a) ?=(%avar -.a) ?=(%rvar -.a) |(?=(%nvar -.a) ?=(%rnvar -.a)))
  ?:  &(?=(%cell -.a) ?=(%cell -.b))  |($(a hed.a, b hed.b) $(a tal.a, b tal.b))
  ?:  &(?=(%fn -.a) ?=(%fn -.b))  |($(a sample.a, b sample.b) $(a product.a, b product.b))
  |
::
::  A successful cast keeps any explicit faces from either side while
::  retaining the target's aura choices. Both faces have already matched.
::
++  itype-merge-faces
  |=  [actual=itype expected=itype sub=isub]
  ^-  itype
  =.  actual  (itype-walk actual sub)
  =.  expected  (itype-walk expected sub)
  ?:  &(?=(%face -.actual) ?=(%face -.expected))
    [%face name.expected $(actual body.actual, expected body.expected)]
  ?:  ?=(%face -.actual)
    [%face name.actual $(actual body.actual)]
  ?:  ?=(%face -.expected)
    [%face name.expected $(expected body.expected)]
  ?:  &(?=(%cell -.actual) ?=(%cell -.expected))
    [%cell $(actual hed.actual, expected hed.expected) $(actual tal.actual, expected tal.expected)]
  expected
::
::  Positional call arguments do not write the sample's enclosing field
::  labels.  Ignore one raw sample-slot face per written argument while
::  checking value faces as usual.  An unknown or variable-bound cell spine
::  cannot justify this distinction, so keep the existing conservative guard.
++  itype-positional-slot-face-asym
  |=  [actual=itype expected=itype sub=isub]
  ^-  ?
  ?:  &(?=(%fn -.actual) ?=(%fn -.expected) (itype-closed-gates-match actual expected))  |
  (itype-face-asym actual expected sub)
::
++  itype-positional-face-asym
  |=  [args=(list expr) actual=itype expected=itype sub=isub]
  ^-  ?
  ?~  args  &
  ?~  t.args
    =/  slot=itype  expected
    =?  slot  ?=(%face -.slot)  body.slot
    (itype-positional-slot-face-asym actual slot sub)
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  &
  =/  slot=itype  hed.expected
  =?  slot  ?=(%face -.slot)  body.slot
  ?:  (itype-positional-slot-face-asym hed.actual slot sub)  &
  $(args t.args, actual tal.actual, expected tal.expected)
::
++  itype-output-may-be-cell
  |=  [t=itype sub=isub]
  ^-  ?
  =.  t  (itype-walk t sub)
  ?-  -.t
    %var       &
    %cell      &
    %union     &
    %recursive  &
    %jrec       &
    %grec       &
    %noun       &
    %collection  &
    %face      $(t body.t)
    %fn        |($(t sample.t) $(t product.t))
    *          |
  ==
::
++  pending-tags
  |=  [tags=(list ipending) sub=isub]
  ^-  ?
  ?~  tags  |
  ?~  (itype-lookup id.i.tags sub)  &
  $(tags t.tags)
::
++  pending-null
  |=  [tags=(list ipending) sub=isub]
  ^-  ?
  ?~  tags  |
  ?:  &(?=(%null form.literal.i.tags) ?=(~ (itype-lookup id.i.tags sub)))  &
  $(tags t.tags)
::
::  Tags remain constrained until a mold selects a case or permitted atom
::  type. Never generalize an unresolved tag through aliases or cells.
::
++  itype-has-tag
  |=  t=itype
  ^-  ?
  ?-  -.t
    %tag   &
    %grec  (lien args.t |=(c=itype (itype-has-tag c)))
    %collection  (lien args.t |=(c=itype (itype-has-tag c)))
    %face  $(t body.t)
    %fn    |($(t sample.t) $(t product.t))
    %cell  |($(t hed.t) $(t tal.t))
    %union  |((lien cases.t |=(c=itype (itype-has-tag c))) (lien args.t |=(c=itype (itype-has-tag c))))
    *      |
  ==
::
++  itype-has-union
  |=  t=itype
  ^-  ?
  ?-  -.t
    %union  &
    %grec  (lien args.t |=(c=itype (itype-has-union c)))
    %collection  (lien args.t |=(c=itype (itype-has-union c)))
    %face   $(t body.t)
    %fn     |($(t sample.t) $(t product.t))
    %cell   |($(t hed.t) $(t tal.t))
    *       |
  ==
::
::  Until a visible generic alias can be selected, expanding a named
::  generic union would hide phantom arguments and its origin. This is a
::  limitation of partial inference, not the unnamed-union print notation.
::
++  itype-has-hidden-generic
  |=  t=itype
  ^-  ?
  ?-  -.t
    %union
      ?:  &(?=(~ label.t) ?=(^ args.t))  &
      (lien (weld args.t cases.t) |=(c=itype (itype-has-hidden-generic c)))
    %grec  |(?=(~ label.t) (lien args.t |=(c=itype (itype-has-hidden-generic c))))
    %collection  (lien args.t |=(c=itype (itype-has-hidden-generic c)))
    %face  $(t body.t)
    %fn    |($(t sample.t) $(t product.t))
    %cell  |($(t hed.t) $(t tal.t))
    *      |
  ==
::
++  itype-has-recursive
  |=  t=itype
  ^-  ?
  ?-  -.t
    %recursive  &
    %jrec       &
    %grec       &
    %collection  (lien args.t |=(c=itype (itype-has-recursive c)))
    %union  (lien (weld args.t cases.t) |=(c=itype (itype-has-recursive c)))
    %face  $(t body.t)
    %cell  |($(t hed.t) $(t tal.t))
    %fn    |($(t sample.t) $(t product.t))
    *      |
  ==
::
++  itype-has-hidden-recursive
  |=  t=itype
  ^-  ?
  ?-  -.t
    %recursive  ?=(~ label.t)
    %jrec       ?=(~ label.t)
    %grec       |(?=(~ label.t) (lien args.t |=(c=itype (itype-has-hidden-recursive c))))
    %collection  (lien args.t |=(c=itype (itype-has-hidden-recursive c)))
    %union  (lien (weld args.t cases.t) |=(c=itype (itype-has-hidden-recursive c)))
    %face  $(t body.t)
    %cell  |($(t hed.t) $(t tal.t))
    %fn    |($(t sample.t) $(t product.t))
    *      |
  ==
::
++  itype-fit-cases
  |=  [actual=itype cases=(list itype) sub=isub next=@ud]
  ^-  ifit
  =/  good=(unit ifit)  ~
  =/  pending=?  |
  |-
  ?~  cases
    ?:  pending  [%unknown ~]
    ?~  good  [%bad ~]
    u.good
  =/  trial=ifit  (itype-fit actual i.cases sub next)
  ?-  -.trial
    %unknown  $(cases t.cases, pending &)
    %bad      $(cases t.cases)
    %ok
      ?^  good  [%unknown ~]
      $(cases t.cases, good `trial)
  ==
::
::  A constructor needs a case whose head has the same literal noun as its
::  tag. An unresolved or opaque case may reveal one later, so it cannot
::  prove a mismatch or a unique match. A broad atom mold is not a case.
::
++  itype-fit-ctor-cases
  |=  [tag=lit sample=itype cases=(list itype) sub=isub next=@ud]
  ^-  ifit
  =/  found=(unit ifit)  ~
  =/  pending=?  |
  |-
  ?~  cases
    ?:  pending  [%unknown ~]
    ?~  found  [%bad ~]
    u.found
  =/  raw=itype  i.cases
  ?:  ?=(%var -.raw)
    $(cases t.cases, pending &)
  =/  c=itype  (itype-walk raw sub)
  ?:  ?=(?(%var %tag %recursive %jrec %grec %union %face) -.c)
    $(cases t.cases, pending &)
  ?.  ?=(%cell -.c)  $(cases t.cases)
  =/  raw-head=itype  hed.c
  ?:  ?=(%var -.raw-head)
    $(cases t.cases, pending &)
  =/  head=itype  (itype-walk raw-head sub)
  ::  A single faced, explicitly atom-only head cannot be the tag case.
  ::  Do not follow variables or peel nested faces for this negative proof.
  ?:  ?=(%face -.head)
    ?:  ?=(?(%atom %any-atom %flag %avar %rvar %nvar %rnvar) -.body.head)
      $(cases t.cases)
    $(cases t.cases, pending &)
  ?:  ?=(?(%var %tag %recursive %jrec %grec %union) -.head)
    $(cases t.cases, pending &)
  ?.  ?=(%const -.head)  $(cases t.cases)
  ?.  =(val.literal.head val.tag)  $(cases t.cases)
  ::  Equal heads can have disjoint payloads. Test each from the original
  ::  substitution; a unique success is usable only with no unknown rival.
  =/  trial=ifit  (itype-fit sample tal.c sub next)
  ?-  -.trial
    %bad      $(cases t.cases)
    %unknown  $(cases t.cases, pending &)
    %ok
      ?^  found  [%unknown ~]
      $(cases t.cases, found `trial)
  ==
::
++  itype-fit
  |=  [actual=itype expected=itype sub=isub next=@ud]
  ^-  ifit
  (itype-fit-inner actual expected sub next | |)
++  itype-fit-inner
  |=  [actual=itype expected=itype sub=isub next=@ud skip-width=? spine-proof=?]
  ^-  ifit
  ?:  &(!skip-width ?=(%cell -.actual) ?=(%cell -.expected) |((width-spine-exhausted actual 1.024) (width-spine-exhausted expected 1.024)))
    [%unknown ~]
  =/  known=(unit [source=iwfields target=iwfields])
    ?:  skip-width  ~
    (width-known-shape actual expected sub)
  =/  too-wide=?  ?~(known | (gth (lent order.source.u.known) (lent order.target.u.known)))
  ?:  too-wide  [%unknown ~]
  =/  spine-checked=?  |(spine-proof ?=(^ known))
  =/  uncertain=?
    |(?=(%var -.actual) ?=(%avar -.actual) ?=(%rvar -.actual) |(?=(%nvar -.actual) ?=(%rnvar -.actual)) ?=(%var -.expected) ?=(%avar -.expected) ?=(%rvar -.expected) |(?=(%nvar -.expected) ?=(%rnvar -.expected)))
  =/  actual-open=?
    |(?=(%var -.actual) ?=(%avar -.actual) ?=(%rvar -.actual) |(?=(%nvar -.actual) ?=(%rnvar -.actual)))
  =.  actual  (itype-walk actual sub)
  =.  expected  (itype-walk expected sub)
  ?:  =(actual expected)  [%ok sub next]
  ::  The relation of the source loobean mold to explicit @f is not yet
  ::  established. Keep it unsupported rather than asserting a mismatch.
  ?:  &(?=(%flag -.actual) ?=(%atom -.expected) =(%f aura.expected))  [%unknown ~]
  ::  Any value can be used where a noun is expected. An unresolved
  ::  bare tag is fixed as a constant; a constructor still needs a gate.
  ?:  ?=(%noun -.expected)
    ?:  ?=(%tag -.actual)
      ?:  constructor.actual  [%unknown ~]
      [%ok [[id.actual expected] sub] next]
    [%ok sub next]
  ::  An arbitrary noun is not known to fit a narrower type.
  ?:  &(?=(%noun -.actual) !?=(%var -.expected))  [%unknown ~]
  ?:  &(!uncertain ?=(%grec -.actual) ?=(%face -.expected))  $(expected body.expected)
  ?:  &(!uncertain ?=(%face -.actual) ?=(%grec -.expected))  $(actual body.actual)
  ?:  &(?=(%grec -.actual) ?=(%grec -.expected))
    ?.  &(=(at.actual at.expected) =(name.actual name.expected))  [%unknown ~]
    =/  matched=(unit isub)  (itype-unify-args args.actual args.expected sub)
    ?~  matched  [%unknown ~]
    [%ok u.matched next]
  ?:  &(|(?=(%grec -.actual) ?=(%grec -.expected)) !|(?=(%var -.actual) ?=(%var -.expected)))  [%unknown ~]
  ?:  &(!uncertain ?=(%jrec -.actual) ?=(%face -.expected))  $(expected body.expected)
  ?:  &(!uncertain ?=(%face -.actual) ?=(%jrec -.expected))  $(actual body.actual)
  ?:  &(?=(%jrec -.actual) ?=(%jrec -.expected))
    ?:(&(=(at.actual at.expected) =(name.actual name.expected) =(head.actual head.expected) =(aura.actual aura.expected) =(tail.actual tail.expected)) [%ok sub next] [%bad ~])
  ?:  &(|(?=(%jrec -.actual) ?=(%jrec -.expected)) !|(?=(%var -.actual) ?=(%var -.expected)))  [%unknown ~]
  ?:  &(?=(%recursive -.actual) ?=(%recursive -.expected))
    ?:(&(=(module.actual module.expected) =(name.actual name.expected)) [%ok sub next] [%bad ~])
  ?:  &(|(?=(%recursive -.actual) ?=(%recursive -.expected)) !|(?=(%var -.actual) ?=(%var -.expected)))  [%unknown ~]
  ?:  &(?=(%union -.actual) ?=(%union -.expected))
    ?.  =(origin.actual origin.expected)  [%unknown ~]
    ?:  &(?=(~ args.actual) ?=(~ args.expected))
      ?:(=(cases.actual cases.expected) [%ok sub next] [%unknown ~])
    ?~  origin.actual  [%unknown ~]
    =/  unified=(unit isub)  (itype-unify-args args.actual args.expected sub)
    ?^  unified  [%ok u.unified next]
    [%unknown ~]
  ::  A known union can instantiate an unconstrained sample directly;
  ::  preserve unknown results for variable-bound union origins.
  ?:  &(!actual-open ?=(%union -.actual) ?=(%var -.expected))
    ?~  origin.actual  [%unknown ~]
    =/  normalized=itype  (itype-normalize actual sub)
    ?:  |((itype-has-tag normalized) (itype-has-recursive normalized) (itype-has-any-atom actual sub))  [%unknown ~]
    =/  unified=(unit isub)  (itype-unify actual expected sub)
    ?~  unified  [%unknown ~]
    [%ok u.unified next]
  ::  A concrete union value in a tuple may acquire the expected field's
  ::  face. A variable-bound union still needs face propagation support.
  ?:  &(!uncertain ?=(%union -.actual) ?=(%face -.expected))
    $(expected body.expected)
  ?:  ?=(%union -.actual)  [%unknown ~]
  ?:  &(?=(%union -.expected) |(?=(%avar -.actual) ?=(%rvar -.actual) |(?=(%nvar -.actual) ?=(%rnvar -.actual))))  [%unknown ~]
  ?:  &(?=(%union -.expected) !?=(%var -.actual))
    (itype-fit-cases actual cases.expected sub next)
  ?:  ?=(%tag -.actual)
    ?:  ?=(%var -.expected)
      =/  u=(unit isub)  (itype-unify actual expected sub)
      ?~  u  [%bad ~]
      [%ok u.u next]
    ?:  |(?=(%avar -.expected) ?=(%rvar -.expected) |(?=(%nvar -.expected) ?=(%rnvar -.expected)))  [%unknown ~]
    ?:  ?=(%face -.expected)  $(expected body.expected)
    ?:  constructor.actual
      ?.  ?=(%fn -.expected)  [%bad ~]
      =/  product=itype  (itype-walk product.expected sub)
      =/  cases=(list itype)  ?:(?=(%union -.product) cases.product ~[product])
      =/  trial=ifit  (itype-fit-ctor-cases literal.actual sample.expected cases sub next)
      ?.  ?=(%ok -.trial)  trial
      [%ok [[id.actual expected] sub.trial] next.trial]
    ::  Zero may be the empty list. A nested cell fit lacks the context
    ::  needed to resolve it here, so do not report a definite mismatch.
    ?:  &(?=(%collection -.expected) =(%list name.expected) =(0 val.literal.actual))
      [%unknown ~]
    ?:  ?=(%const -.expected)
      ?:(=(val.literal.actual val.literal.expected) [%ok [[id.actual expected] sub] next] [%bad ~])
    ?:  ?=(%atom -.expected)
      ?:  |(=(%tas aura.expected) =(%ta aura.expected))
        [%ok [[id.actual expected] sub] next]
      [%bad ~]
    ?:  ?=(%flag -.expected)
      ?:(|(=(0 val.literal.actual) =(1 val.literal.actual)) [%ok [[id.actual expected] sub] next] [%bad ~])
    ?:  ?=(%any-atom -.expected)  [%ok [[id.actual expected] sub] next]
    [%bad ~]
  ?:  ?=(%const -.actual)
    ?:  ?=(%var -.expected)
      =/  u=(unit isub)  (itype-unify actual expected sub)
      ?~  u  [%bad ~]
      [%ok u.u next]
    ?:  |(?=(%avar -.expected) ?=(%rvar -.expected) |(?=(%nvar -.expected) ?=(%rnvar -.expected)))  [%unknown ~]
    ?:  ?=(%face -.expected)  $(expected body.expected)
    ?:  &(?=(%collection -.expected) =(%list name.expected) =(0 val.literal.actual))
      [%unknown ~]
    ?:  ?=(%const -.expected)
      ?:(=(val.literal.actual val.literal.expected) [%ok sub next] [%bad ~])
    ?:  ?=(%atom -.expected)
      ::  A loobean singleton must not silently widen into another aura.
      ?:  =(%loobean form.literal.actual)
        ?:  =(%f aura.expected)  [%unknown ~]
        [%bad ~]
      ?:  |(=(%tas aura.expected) =(%ta aura.expected))  [%ok sub next]
      [%bad ~]
    ?:  ?=(%flag -.expected)
      ?:(|(=(0 val.literal.actual) =(1 val.literal.actual)) [%ok sub next] [%bad ~])
    ?:  ?=(%any-atom -.expected)  [%ok sub next]
    [%bad ~]
  ?:  &(uncertain (itype-face-asym actual expected sub))  [%unknown ~]
  ::  A known face labels the same noun. Peel it before applying the
  ::  directional unrestricted-atom rule, preserving raw-variable guards.
  ?:  &(!uncertain ?=(%any-atom -.actual) ?=(%face -.expected))
    $(expected body.expected, skip-width |, spine-proof |)
  ?:  &(!uncertain ?=(%any-atom -.expected) ?=(%face -.actual))
    $(actual body.actual, skip-width |, spine-proof |)
  ?:  ?=(%any-atom -.expected)
    ?:  |(?=(%atom -.actual) ?=(%avar -.actual) ?=(%rvar -.actual) |(?=(%nvar -.actual) ?=(%rnvar -.actual)) ?=(%flag -.actual))  [%ok sub next]
    ?:  ?=(%var -.actual)
      =/  unified=(unit isub)  (itype-unify actual [%avar next] sub)
      ?~  unified  [%bad ~]
      [%ok u.unified +(next)]
    [%bad ~]
  ?:  ?=(%any-atom -.actual)
    ?:  ?=(%var -.expected)
      =/  unified=(unit isub)  (itype-unify actual expected sub)
      ?~  unified  [%bad ~]
      [%ok u.unified next]
    ?:  |(?=(%avar -.expected) ?=(%rvar -.expected) |(?=(%nvar -.expected) ?=(%rnvar -.expected)))  [%unknown ~]
    [%bad ~]
  ?:  &(?=(%atom -.actual) ?=(%atom -.expected))
    ?:  (aura-prefix aura.expected aura.actual)  [%ok sub next]
    ?:  &((aura-prefix aura.actual aura.expected) uncertain)  [%unknown ~]
    [%bad ~]
  ?:  &(?=(%cell -.actual) ?=(%cell -.expected))
    =/  first=ifit  $(actual hed.actual, expected hed.expected, skip-width |, spine-proof |)
    ?.  ?=(%ok -.first)  first
    $(actual tal.actual, expected tal.expected, sub sub.first, next next.first, skip-width spine-checked, spine-proof spine-checked)
  ::  A field may add a face to an occurrence of the very same type
  ::  variable. Binding that variable to a face around itself would fail
  ::  the occurs check, but its underlying type has already matched.
  ?:  &(?=(%var -.actual) ?=(%face -.expected) =(actual (itype-walk body.expected sub)))
    [%ok sub next]
  ::  Differing variables and faces need propagation that is not yet
  ::  represented. Binding one to the face can create a false mismatch.
  ?:  &(?=(%var -.actual) ?=(%face -.expected))  [%unknown ~]
  ?:  &(?=(%face -.actual) ?=(%var -.expected))  [%unknown ~]
  ?:  &(?=(%var -.actual) (itype-has-any-atom expected sub))
    [%unknown ~]
  ?:  |(?=(%var -.actual) ?=(%var -.expected))
    =/  unified=(unit isub)  (itype-unify actual expected sub)
    ?~  unified
      ?:  |(?=(%face -.actual) ?=(%face -.expected))  [%unknown ~]
      ?:  |((itype-has-recursive (itype-normalize actual sub)) (itype-has-recursive (itype-normalize expected sub)))  [%unknown ~]
      ?:  (itype-family-related actual expected sub)  [%unknown ~]
      [%bad ~]
    [%ok u.unified next]
  ?:  &(?=(%face -.actual) ?=(%face -.expected))
    ?.  =(name.actual name.expected)  [%bad ~]
    $(actual body.actual, expected body.expected, skip-width |, spine-proof |)
  ?:  ?=(%face -.actual)  $(actual body.actual, skip-width |, spine-proof |)
  ?:  ?=(%face -.expected)  $(expected body.expected, skip-width |, spine-proof |)
  ?:  &(!uncertain (itype-closed-gates-match actual expected))  [%ok sub next]
  ?:  (itype-face-asym actual expected sub)  [%unknown ~]
  ?:  |((itype-has-any-atom actual sub) (itype-has-any-atom expected sub))
    [%unknown ~]
  =/  unified=(unit isub)  (itype-unify actual expected sub)
  ?~  unified
    ?:  |((itype-has-union (itype-normalize actual sub)) (itype-has-union (itype-normalize expected sub)))  [%unknown ~]
    ?:  |((itype-has-recursive (itype-normalize actual sub)) (itype-has-recursive (itype-normalize expected sub)))  [%unknown ~]
    ?:  (itype-family-related actual expected sub)  [%unknown ~]
    [%bad ~]
  [%ok u.unified next]
::
++  itype-unify-test
  ^-  (list tape)
  =/  a=itype  [%var 0]
  =/  b=itype  [%var 1]
  =/  txt=itype  [%atom %t]
  =/  num=itype  [%atom %ud]
  =/  same=itype  [%fn a a]
  =/  mismatch=itype  [%fn txt num]
  =/  fine=itype  [%fn txt txt]
  =/  sub=(unit isub)  (itype-unify a b ~)
  ?~  sub  ~["variables should unify"]
  =/  sub2=(unit isub)  (itype-unify b txt u.sub)
  ?~  sub2  ~["a chained variable should unify"]
  =/  problems=(list tape)  ~
  =?  problems  !=((itype-walk a u.sub2) txt)
    ["substitutions should follow chains" problems]
  =?  problems  ?=(^ (itype-unify txt num ~))
    ["different concrete auras should conflict" problems]
  =?  problems  ?=(^ (itype-unify a [%fn a txt] ~))
    ["occurs check should reject an infinite type" problems]
  =?  problems  ?=(^ (itype-unify same mismatch ~))
    ["a shared type variable should reject incompatible arguments" problems]
  =?  problems  ?=(~ (itype-unify same fine ~))
    ["a shared type variable should accept equal arguments" problems]
  =/  list-a=itype  [%collection %list ~[a]]
  =/  list-t=itype  [%collection %list ~[txt]]
  =/  list-n=itype  [%collection %list ~[num]]
  =?  problems  ?=(^ (itype-unify a list-a ~))
    ["occurs check should look through collection arguments" problems]
  =?  problems  !=((itype-vars list-a) ~[0])
    ["generalization should see collection argument variables" problems]
  =?  problems  !=((itype-rename list-a ~[[0 num]]) list-n)
    ["instantiation should rename collection argument variables" problems]
  =?  problems  ?=(^ (itype-unify list-t list-n ~))
    ["collection arguments with different auras should conflict" problems]
  =?  problems  ?=(^ (itype-unify list-t [%collection %unit ~[txt]] ~))
    ["different collection names should conflict" problems]
  =?  problems  !(itype-family-related list-t [%collection %list ~[[%atom 'tD']]] ~)
    ["collection arguments should preserve aura-family uncertainty" problems]
  =?  problems  !(itype-face-asym [%collection %list ~[[%face %x txt]]] list-t ~)
    ["collection arguments should preserve face uncertainty" problems]
  =/  recursive=itype  [%recursive %fixture %chain `'chain.fixture']
  =/  same-recursive=itype  [%recursive %fixture %chain ~]
  =/  other-recursive=itype  [%recursive %other %chain `'chain.other']
  =?  problems  ?=(~ (itype-unify recursive same-recursive ~))
    ["recursive identity should not depend on its visible name" problems]
  =?  problems  ?=(^ (itype-unify recursive other-recursive ~))
    ["recursive identity should include the source module" problems]
  =/  recursive-fit=ifit  (itype-fit recursive txt ~ 0)
  =?  problems  !?=(%unknown -.recursive-fit)
    ["opaque recursive types should not be unfolded by a fit" problems]
  =/  nested-fit=ifit
    (itype-fit [%collection %list ~[a]] list-t ~[[0 recursive]] 1)
  =?  problems  !?=(%unknown -.nested-fit)
    ["recursive types behind substitutions should remain uncertain" problems]
  problems
::
::  The expression inference below is deliberately a fragment: bindings,
::  simple gates, calls, fixed-aura literals, and some interpolated strings. The
::  result for unsupported syntax is a diagnostic, never a checked module.
::
+$  ischeme  [typ=itype vars=(list @ud)]
+$  ienv  (list [name=term scheme=ischeme])
+$  imold-types  (list [name=term template=ischeme])
+$  iderived  [name=term agent=term mark=term]
+$  iwidth-definition  [name=term original=expr typ=itype sub=isub projections=(list iwprojection)]
+$  iwidth-dependency  [at=path source=(unit @t) definitions=(list iwidth-definition)]
::  Nonrecursive request evidence is compiler-owned metadata, not a property
::  of an arbitrary ask value. Reader graphs and source inputs are trusted.
+$  irequest-evidence
  [api-at=path name=term path=iapi-path-typed api-source=@t public-source=@t internal-source=@t prelude-values=(list term) prelude-molds=(list term) externals=iexternals marks=imark-externals]
::  A unit distinguishes a verified empty closure from a detached legacy file.
::  The opaque prelude is an exact trusted input, not a recursive interface mold.
+$  irequest-graph
  [paths=(set path) requests=(list irequest-evidence) bundle-input=* prelude-input=* prelude-values=(list term) prelude-molds=(list term) externals=iexternals marks=imark-externals]
+$  ifile  [values=ienv molds=imold-types at=path derived=(list iderived) elaborations=(list iwidth-definition) dependencies=(list iwidth-dependency) source=(unit @t) graph=(unit irequest-graph)]
+$  ijimports  (list [face=term interface=ifile])
+$  icap  [name=@t id=@ud at=span]
+$  icaps  (list icap)
+$  iparams  (list [name=@t typ=itype])
+$  imolds  (list [name=term body=shape])
::  A caller supplies the exact noun returned by +read-mold:jibb-import.
::  This core has no Ford dependencies; unrecognized payloads fail closed.
+$  iexternals  (list [module=term name=term result=*])
+$  imark-externals  (list [mark=term result=*])
::  Hole obligations survive discarded expressions until their owning
::  definition has inferred; their source spans support unresolved reports.
+$  ihole  [id=@ud at=span]
::  Recursive-mold unfolding spends fuel in the threaded inference state.
::  Retries can restart from an earlier state, so this bounds an attempt,
::  not all parsing or module-checking work.
::  Experimental: only closed, uniquely faced records have known axes.
+$  iwfield  [name=term axis=@ud typ=itype]
+$  iwfields  [order=(list iwfield) index=(map term iwfield)]
+$  iwstep  [name=term axis=@ud]
+$  iwidth-result  [steps=(list iwstep) sub=isub next=@ud]
+$  iwprojection  [at=span original=expr source=itype target=itype steps=(list iwstep)]
++  width-scan
  |=  [typ=itype sub=isub axis=@ud fuel=@ud]
  ^-  (unit iwfields)
  =/  order=(list iwfield)  ~
  =/  index=(map term iwfield)  *(map term iwfield)
  |-
  ?:  =(0 fuel)  ~
  ?:  |(?=(%var -.typ) ?=(%avar -.typ) ?=(%rvar -.typ) ?=(%nvar -.typ) ?=(%rnvar -.typ))  ~
  ?:  ?=(%face -.typ)
    =/  entry=iwfield  [name.typ axis body.typ]
    ?:  ?=(^ (~(get by index) name.entry))  ~
    `[(flop [entry order]) (~(put by index) name.entry entry)]
  ?.  ?=(%cell -.typ)  ~
  =/  head=itype  hed.typ
  ?:  |(?=(%var -.head) ?=(%avar -.head) ?=(%rvar -.head) ?=(%nvar -.head) ?=(%rnvar -.head))  ~
  ?.  ?=(%face -.head)  ~
  =/  entry=iwfield  [name.head (mul 2 axis) body.head]
  ?:  ?=(^ (~(get by index) name.entry))  ~
  $(typ tal.typ, axis +((mul 2 axis)), fuel (dec fuel), order [entry order], index (~(put by index) name.entry entry))
++  width-in-order
  |=  [source=(list iwfield) target=(list iwfield)]
  ^-  ?
  ?~  target  &
  ?~  source  |
  ?:  =(name.i.source name.i.target)  $(source t.source, target t.target)
  $(source t.source)
++  width-fit-fields
  |=  [source=(map term iwfield) target=(list iwfield) sub=isub next=@ud]
  ^-  (unit iwidth-result)
  ?~  target  `[~ sub next]
  =/  found=(unit iwfield)  (~(get by source) name.i.target)
  ?~  found  ~
  =/  fit=ifit  (itype-fit typ.u.found typ.i.target sub next)
  ?.  ?=(%ok -.fit)  ~
  =/  rest=(unit iwidth-result)  $(target t.target, sub sub.fit, next next.fit)
  ?~  rest  ~
  `[[[name.i.target axis.u.found] steps.u.rest] sub.u.rest next.u.rest]
++  width-spine-exhausted
  |=  [t=itype fuel=@ud]
  ^-  ?
  ?:  =(0 fuel)  &
  ?.  ?=(%cell -.t)  |
  ?.  ?=(%face -.hed.t)  |
  $(t tal.t, fuel (dec fuel))
++  width-known-shape
  |=  [actual=itype expected=itype sub=isub]
  ^-  (unit [source=iwfields target=iwfields])
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
  =/  source=(unit iwfields)  (width-scan actual sub 1 1.024)
  =/  target=(unit iwfields)  (width-scan expected sub 1 1.024)
  ?~  source  ~
  ?~  target  ~
  `[u.source u.target]
::
++  width-shape
  |=  [actual=itype expected=itype sub=isub]
  ^-  (unit [source=iwfields target=iwfields])
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
  =/  source=(unit iwfields)  (width-scan actual sub 1 4.096)
  =/  target=(unit iwfields)  (width-scan expected sub 1 4.096)
  ?~  source  ~
  ?~  target  ~
  ?.  (gth (lent order.u.source) (lent order.u.target))  ~
  `[u.source u.target]
++  width-proj-shape
  |=  [actual=itype expected=itype sub=isub]
  ^-  (unit [source=iwfields target=iwfields])
  ?.  &(|(?=(%cell -.actual) ?=(%face -.actual)) |(?=(%cell -.expected) ?=(%face -.expected)))  ~
  =/  source=(unit iwfields)  (width-scan actual sub 1 4.096)
  =/  target=(unit iwfields)  (width-scan expected sub 1 4.096)
  ?~  source  ~
  ?~  target  ~
  ?:  (lth (lent order.u.source) (lent order.u.target))  ~
  `[u.source u.target]
::
++  width-project
  |=  [shape=[source=iwfields target=iwfields] sub=isub next=@ud]
  ^-  (unit iwidth-result)
  ?.  (width-in-order order.source.shape order.target.shape)  ~
  (width-fit-fields index.source.shape order.target.shape sub next)
::
::  Provisional, globally budgeted gate-free proof.  %no includes a
::  gate-bearing witness; an uninhabited sibling could invalidate it.
::  Input types must be resolved and normalized under valid substitutions,
::  from trusted source-backed interfaces and reader results. Collection
::  list/unit names rely on their existing identity invariant; this arm
::  does not validate fabricated internal types.
+$  igf-segment
  $%  [%field name=term]
      [%head ~]
      [%tail ~]
      [%item ~]
      [%case index=@ud]
  ==
+$  igate-free  [verdict=?(%yes %no %unknown) inhabited=? left=@ud path=(unit (list igf-segment))]
++  gate-free-types
  |=  [types=(list itype) fuel=@ud path=(list igf-segment) index=@ud]
  ^-  igate-free
  ?~  types  [%yes | fuel ~]
  ?:  =(0 fuel)  [%unknown | 0 ~]
  =/  first=igate-free  (gate-free-type i.types fuel [[%case index] path])
  ?:  =(%no verdict.first)  first
  =/  rest=igate-free  $(types t.types, fuel left.first, index +(index))
  ?:  =(%no verdict.rest)  rest
  =/  inhabited=?  |(inhabited.first inhabited.rest)
  ?:  |(=(%unknown verdict.first) =(%unknown verdict.rest))  [%unknown inhabited left.rest ~]
  [%yes inhabited left.rest ~]
++  gate-free-type
  |=  [typ=itype fuel=@ud path=(list igf-segment)]
  ^-  igate-free
  ?:  =(0 fuel)  [%unknown | 0 ~]
  =.  fuel  (dec fuel)
  ?-  -.typ
    %fn         [%no & fuel `(flop path)]
    %atom       [%yes & fuel ~]
    %any-atom   [%yes & fuel ~]
    %flag       [%yes & fuel ~]
    %const      [%yes & fuel ~]
    %face       $(typ body.typ, path [[%field name.typ] path])
    %cell
      =/  head=igate-free  $(typ hed.typ, path [[%head ~] path])
      =/  tail=igate-free  $(typ tal.typ, fuel left.head, path [[%tail ~] path])
      =/  inhabited=?  &(inhabited.head inhabited.tail)
      ?:  &(=(%no verdict.head) inhabited.tail)  head(left left.tail)
      ?:  &(=(%no verdict.tail) inhabited.head)  tail
      ?:  |(!=(%yes verdict.head) !=(%yes verdict.tail))  [%unknown inhabited left.tail ~]
      [%yes inhabited left.tail ~]
    %collection
      ?.  |(=(%list name.typ) =(%unit name.typ))  [%unknown | fuel ~]
      ?.  ?=([* ~] args.typ)  [%unknown | fuel ~]
      =/  item=igate-free  $(typ i.args.typ, path [[%item ~] path])
      item(inhabited &)
    %union
      ?~  cases.typ  [%unknown | fuel ~]
      (gate-free-types cases.typ fuel path 0)
    %noun       [%unknown & fuel ~]
    %var        [%unknown | fuel ~]
    %avar       [%yes & fuel ~]
    %rvar       [%yes & fuel ~]
    %nvar       [%yes & fuel ~]
    %rnvar      [%yes & fuel ~]
    %tag        [%unknown | fuel ~]
    %recursive  [%unknown | fuel ~]
    %jrec       [%yes & fuel ~]
    %grec       [%unknown | fuel ~]
  ==
::
+$  igate-prelude-evidence  [iface=ifile gates=(map term def)]
+$  dgo  [left=itype right=itype at=span context=span]
+$  istate  [next=@ud sub=isub caps=icaps binders=(list @ud) molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) params=iparams active=(list term) tags=(list ipending) in-mold=? at=path top-molds=(list term) prelude=(unit ifile) holes=(list ihole) jrec-fuel=@ud projections=(list iwprojection) gate-defs=(map term def) head-evidence=(unit igate-prelude-evidence) grec-index=(unit [at=path source=@t prelude=ifile shapes=(map term shape)]) defer=(unit ~) obligations=(list dgo)]
+$  idiag  [msg=tape sites=(list [at=span note=tape])]
+$  iresult  (each [typ=itype state=istate] idiag)
+$  isample-result  (each [typ=itype env=ienv state=istate] tape)
::
++  ienv-lookup
  |=  [name=term env=ienv]
  ^-  (unit ischeme)
  ?~  env  ~
  ?:  =(name name.i.env)  `scheme.i.env
  $(env t.env)
::
::  Generalized variables are renamed freshly on each use. The renaming
::  substitutes only once, so an old variable and its fresh number may
::  coincide without forming a substitution cycle.
::
++  itype-normalize
  |=  [t=itype sub=isub]
  ^-  itype
  =.  t  (itype-walk t sub)
  ?:  ?=(%grec -.t)  t(args (turn args.t |=(c=itype (itype-normalize c sub))))
  ?:  ?=(%collection -.t)  [%collection name.t (turn args.t |=(c=itype (itype-normalize c sub)))]
  ?:  ?=(%union -.t)
    [%union (turn cases.t |=(c=itype (itype-normalize c sub))) origin.t label.t (turn args.t |=(c=itype (itype-normalize c sub)))]
  ?:  ?=(%face -.t)
    [%face name.t $(t body.t)]
  ?:  ?=(%fn -.t)
    [%fn $(t sample.t) $(t product.t)]
  ?:  ?=(%cell -.t)
    [%cell $(t hed.t) $(t tal.t)]
  t
::
::
::  Default decimal variables only in types with no gates. A gate can
::  generalize an aura from its sample, which requires constraint analysis
::  beyond this fragment; leave those cases unresolved.
::
::  This helper only controls decimal defaulting in visible types. A noun
::  may contain gates and is not proof of a gate-free value.
++  itype-has-gate
  |=  t=itype
  ^-  ?
  ?-  -.t
    %fn        &
    %cell      |($(t hed.t) $(t tal.t))
    %recursive  |
    %jrec       |
    %grec       &
    %collection  (lien args.t |=(c=itype (itype-has-gate c)))
    %face      $(t body.t)
    %union     (lien cases.t |=(c=itype (itype-has-gate c)))
    %tag       |
    %const     |
    %var       |
    %avar      |
    %rvar      |
    %nvar      |
    %rnvar      |
    %atom      |
    %any-atom  |
    %flag      |
    %noun  |
  ==
::
++  default-decimals
  |=  t=itype
  ^-  itype
  ?:  (itype-has-gate t)  t
  ?-  -.t
    %nvar      [%atom %ud]
    %rnvar      [%atom %ud]
    %grec  t(args (turn args.t |=(c=itype (default-decimals c))))
    %collection  [%collection name.t (turn args.t |=(c=itype (default-decimals c)))]
    %face      [%face name.t $(t body.t)]
    %cell      [%cell $(t hed.t) $(t tal.t)]
    *          t
  ==
::
::  A hole is solved only by a fully determined type or a written
::  in-scope type variable. Ordinary fresh variables are not evidence.
::  Compare representatives after substitution, since unification can
::  orient a written capital toward the hole rather than the reverse.
++  hole-variable-id
  |=  t=itype
  ^-  (unit @ud)
  ?-  -.t
    %var   `id.t
    %avar  `id.t
    %rvar  `id.t
    %nvar  `id.t
    %rnvar  `id.t
    %tag   `id.t
    *  ~
  ==
++  hole-same-variable
  |=  [a=itype b=itype]
  ^-  ?
  =/  x=(unit @ud)  (hole-variable-id a)
  ?~  x  |
  =/  y=(unit @ud)  (hole-variable-id b)
  ?~  y  |
  =(u.x u.y)
++  hole-known
  |=  [t=itype state=istate]
  ^-  ?
  =.  t  (itype-walk t sub.state)
  ?-  -.t
    ?(%var %avar %rvar %nvar %rnvar)
      ?:  (lien caps.state |=(c=icap (hole-same-variable t (itype-walk [%var id.c] sub.state))))  &
      (lien params.state |=(p=[name=@t typ=itype] (hole-same-variable t (itype-walk typ.p sub.state))))
    %tag  |
    %any-atom  &
    %union  &((levy cases.t |=(c=itype (hole-known c state))) (levy args.t |=(c=itype (hole-known c state))))
    %grec  (levy args.t |=(c=itype (hole-known c state)))
    %collection  (levy args.t |=(c=itype (hole-known c state)))
    %face  $(t body.t)
    %fn  &($(t sample.t) $(t product.t))
    %cell  &($(t hed.t) $(t tal.t))
    *  &
  ==
++  promote-restricted-numbers
  |=  [state=istate env=ienv]
  ^-  istate
  ::  With no written capitals, there is nothing to promote.
  ?~  caps.state  state
  =/  ids=(list @ud)  (turn caps.state |=(c=icap id.c))
  =/  free=(list @ud)  (free-env-vars env sub.state)
  |-
  ?~  ids  state
  =/  t=itype  (itype-walk [%var i.ids] sub.state)
  ?:  &(?=(%rnvar -.t) !(lien free |=(n=@ud =(n +.t))))
    $(ids t.ids, state state(sub [[+.t [%rvar +.t]] sub.state]))
  $(ids t.ids)
::
++  default-hole-numbers
  |=  [all=(list ihole) prior=(list ihole) state=istate env=ienv permit=?]
  ^-  istate
  ::  Do not default a named capital or a variable captured from env.
  ?.  permit  state
  ?:  =(all prior)  state
  ?~  all  state
  =/  t=itype  (itype-walk [%var id.i.all] sub.state)
  =/  free=(list @ud)  (free-env-vars env sub.state)
  =?  state  &(?=(?(%nvar %rnvar) -.t) !(hole-known t state) !(lien free |=(id=@ud =(id id.t))))
    state(sub [[id.t [%atom %ud]] sub.state])
  $(all t.all)
::
::  Only obligations created inside this definition belong to it.
++  holes-created
  |=  [all=(list ihole) prior=(list ihole)]
  ^-  (list ihole)
  ?:  =(all prior)  ~
  ?~  all  ~
  [i.all $(all t.all)]
++  hole-uncertain
  |=  [t=itype state=istate]
  ^-  ?
  =.  t  (itype-walk t sub.state)
  ?-  -.t
    ?(%tag %nvar %rnvar %avar %rvar)  !(hole-known t state)
    %union  |((lien cases.t |=(c=itype (hole-uncertain c state))) (lien args.t |=(c=itype (hole-uncertain c state))))
    %grec  (lien args.t |=(c=itype (hole-uncertain c state)))
    %collection  (lien args.t |=(c=itype (hole-uncertain c state)))
    %face  $(t body.t)
    %fn  |($(t sample.t) $(t product.t))
    %cell  |($(t hed.t) $(t tal.t))
    *  |
  ==
::
++  unresolved-hole
  |=  [all=(list ihole) prior=(list ihole) state=istate]
  ^-  (unit idiag)
  =/  work=(list ihole)  (flop (holes-created all prior))
  |-
  ?~  work  ~
  ?:  (hole-known [%var id.i.work] state)  $(work t.work)
  ?:  (hole-uncertain [%var id.i.work] state)
    `["type hole needs unsupported inference" ~[[at.i.work "type hole"]]]
  `["type hole needs a determined type" ~[[at.i.work "unresolved type hole"]]]
::
++  itype-vars
  |=  t=itype
  ^-  (list @ud)
  ?-  -.t
    %var   ~[id.t]
    %avar  ~[id.t]
    %rvar  ~[id.t]
    %nvar  ~[id.t]
    %rnvar  ~[id.t]
    %atom  ~
    %any-atom  ~
    %flag  ~
    %noun  ~
    %tag   ~
    %const  ~
    %union  (zing (turn (weld args.t cases.t) |=(c=itype (itype-vars c))))
    %recursive  ~
    %jrec       ~
    %grec       (zing (turn args.t |=(c=itype (itype-vars c))))
    %collection  (zing (turn args.t |=(c=itype (itype-vars c))))
    %face  $(t body.t)
    %fn    (weld $(t sample.t) $(t product.t))
    %cell  (weld $(t hed.t) $(t tal.t))
  ==
::
++  unique-type-vars
  |=  ns=(list @ud)
  ^-  (list @ud)
  =/  out=(list @ud)  ~
  |-
  ?~  ns  (flop out)
  ?:  (lien out |=(x=@ud =(x i.ns)))  $(ns t.ns)
  $(ns t.ns, out [i.ns out])
::
++  itype-rename
  |=  [t=itype ren=isub]
  ^-  itype
  ?-  -.t
    %var
      =/  found=(unit itype)  (itype-lookup id.t ren)
      ?~  found  t
      u.found
    %avar
      =/  found=(unit itype)  (itype-lookup id.t ren)
      ?~  found  t
      u.found
    %rvar
      =/  found=(unit itype)  (itype-lookup id.t ren)
      ?~  found  t
      u.found
    %nvar
      =/  found=(unit itype)  (itype-lookup id.t ren)
      ?~  found  t
      u.found
    %rnvar
      =/  found=(unit itype)  (itype-lookup id.t ren)
      ?~  found  t
      u.found
    %atom  t
    %any-atom  t
    %flag  t
    %noun  t
    %tag   t
    %const  t
    %union  [%union (turn cases.t |=(c=itype (itype-rename c ren))) origin.t label.t (turn args.t |=(c=itype (itype-rename c ren)))]
    %recursive  t
    %jrec       t
    %grec       t(args (turn args.t |=(c=itype (itype-rename c ren))))
    %collection  [%collection name.t (turn args.t |=(c=itype (itype-rename c ren)))]
    %face  [%face name.t $(t body.t)]
    %fn    [%fn $(t sample.t) $(t product.t)]
    %cell  [%cell $(t hed.t) $(t tal.t)]
  ==
::
::  Variable IDs are unique across the two kinds. Inspecting the
::  normalized type preserves the atom constraint when renaming.
::
++  itype-var-is-atom
  |=  [n=@ud t=itype]
  ^-  ?
  ?-  -.t
    %var       |
    %avar      =(n id.t)
    %rvar      =(n id.t)
    %nvar      =(n id.t)
    %rnvar      =(n id.t)
    %atom      |
    %any-atom  |
    %flag      |
    %noun  |
    %tag       |
    %const     |
    %union     |((lien cases.t |=(c=itype (itype-var-is-atom n c))) (lien args.t |=(c=itype (itype-var-is-atom n c))))
    %recursive  |
    %jrec       |
    %grec       (lien args.t |=(c=itype (itype-var-is-atom n c)))
    %collection  (lien args.t |=(c=itype (itype-var-is-atom n c)))
    %face      $(t body.t)
    %fn        |($(t sample.t) $(t product.t))
    %cell      |($(t hed.t) $(t tal.t))
  ==
++  itype-var-is-restricted
  |=  [n=@ud t=itype]
  ^-  ?
  ?-  -.t
    %var       |
    %avar      |
    %rvar      =(n id.t)
    %nvar      |
    %rnvar      |
    %atom      |
    %any-atom  |
    %flag      |
    %noun  |
    %tag       |
    %const     |
    %union     |((lien cases.t |=(c=itype (itype-var-is-restricted n c))) (lien args.t |=(c=itype (itype-var-is-restricted n c))))
    %recursive  |
    %jrec       |
    %grec       (lien args.t |=(c=itype (itype-var-is-restricted n c)))
    %collection  (lien args.t |=(c=itype (itype-var-is-restricted n c)))
    %face      $(t body.t)
    %fn        |($(t sample.t) $(t product.t))
    %cell      |($(t hed.t) $(t tal.t))
  ==
::
::  Canonical numbering makes printed variables independent of the order
::  the unifier happened to allocate intermediates.
::
++  canonical-itype
  |=  [t=itype vars=(list @ud)]
  ^-  itype
  =/  ren=isub  ~
  =/  n=@ud  0
  |-
  ?~  vars  (itype-rename t ren)
  =/  replacement=itype  ?:((itype-var-is-restricted i.vars t) [%rvar n] ?:((itype-var-is-atom i.vars t) [%avar n] [%var n]))
  $(vars t.vars, ren [[i.vars replacement] ren], n +(n))
::
++  instantiate-scheme
  |=  [scheme=ischeme state=istate]
  ^-  [typ=itype state=istate]
  =/  ren=isub  ~
  =/  vars=(list @ud)  vars.scheme
  |-
  ?~  vars  [(itype-rename typ.scheme ren) state]
  =/  replacement=itype
    ?:((itype-var-is-restricted i.vars typ.scheme) [%rvar next.state] ?:((itype-var-is-atom i.vars typ.scheme) [%avar next.state] [%var next.state]))
  ::  A generalized atom variable is a valid origin for re-generalizing
  ::  an alias, just as a sample binder is.
  =/  st=istate  state(next +(next.state))
  =?  binders.st  |(?=(%avar -.replacement) ?=(%rvar -.replacement))  [next.state binders.state]
  $(vars t.vars, ren [[i.vars replacement] ren], state st)
::
++  icap-lookup
  |=  [n=@t caps=icaps]
  ^-  (unit @ud)
  ?~  caps  ~
  ?:  =(n name.i.caps)  `id.i.caps
  $(caps t.caps)
::
::
::  Only an unambiguous local name can be expanded. Import faces and
::  recursive mold identity need the full module interface.
::
++  find-simple-mold
  |=  [n=term molds=imolds]
  ^-  (unit shape)
  =/  matches=imolds  (skim molds |=(m=[name=term body=shape] =(n name.m)))
  ?~  matches  ~
  ?^  t.matches  ~
  `body.i.matches
::
++  collect-simple-molds
  |=  ds=(list def)
  ^-  imolds
  ?~  ds  ~
  ?:  ?=(%mold -.i.ds)
    [[name.i.ds shape.i.ds] $(ds t.ds)]
  $(ds t.ds)
::
::
::  The caller supplies unchanged results from the source-aware importer.
::  That boundary is trusted for source provenance: a fork alone cannot
::  reveal cases Hoon collapsed before it was constructed. Validate the
::  supplied graph independently, including pairwise disjointness. Fixed
::  atoms, term singletons, cells, faces and proven forks are decoded;
::  unsupported singletons, collections and recursive references fail.
::
++  jibb-face-name
  |=  name=@
  ^-  ?
  =/  chars=tape  (trip (@t name))
  ?~  chars  |
  ?.  (is-lower i.chars)  |
  (levy t.chars |=(c=@tD (in c name-mask)))
::
::  A source-aware reader result is trusted for origin. Validate every
::  supplied branch and keep the recursive mold opaque: unfolding its
::  root while naming only its tail would change its type identity.
+$  irec-pattern  [pat=upat has=?]
++  rec-pattern
  |=  [node=* module=term name=term]
  ^-  (unit irec-pattern)
  ?@  node  ~
  ?+  -.node  ~
    %atom
      ?:  ?=([%atom %n [~ @]] node)
        ?.  =(0 +>+.node)  ~
        `[[%atom `0] |]
      ?:  ?=([%atom %tas [~ @]] node)
        =/  value=@  +>+.node
        ?.  |(=(value 0) (jibb-face-name value))  ~
        `[[%atom `value] |]
      ?.  ?=([%atom @ ~] node)  ~
      =/  aura=@ta  (@ta +<.node)
      ?.  |(?=(?(%u %ud %ux %uv %t %ta %tas %p %da %dr) aura) =('tD' aura))  ~
      `[[%atom ~] |]
    %ref
      ?.  ?=([%ref @ @] node)  ~
      ?.  &(=(module +<.node) =(name +>.node))  ~
      `[[%unknown ~] &]
    %apply
      ?.  ?=([%apply %list [* ~]] node)  ~
      =/  item  $(node -.+>.node)
      ?~  item  ~
      `[[%or ~[[%atom `0] [%cell pat.u.item [%unknown ~]]]] has.u.item]
    %face
      ?.  ?=([%face @ *] node)  ~
      ?.  (jibb-face-name +<.node)  ~
      $(node +>.node)
    %cell
      ?.  ?=([%cell * *] node)  ~
      =/  left  $(node +<.node)
      ?~  left  ~
      =/  right  $(node +>.node)
      ?~  right  ~
      `[[%cell pat.u.left pat.u.right] |(has.u.left has.u.right)]
    %fork
      =/  cases  (rec-patterns +.node module name)
      ?~  cases  ~
      ?~  pats.u.cases  ~
      ?~  t.pats.u.cases  ~
      ?.  (rec-patterns-disjoint pats.u.cases)  ~
      `[[%or pats.u.cases] has.u.cases]
  ==
::
++  rec-patterns
  |=  [nodes=* module=term name=term]
  ^-  (unit [pats=(list upat) has=?])
  ?@  nodes  ?:(=(nodes 0) `[~ |] ~)
  =/  first  (rec-pattern -.nodes module name)
  ?~  first  ~
  =/  rest  $(nodes +.nodes)
  ?~  rest  ~
  `[[pat.u.first pats.u.rest] |(has.u.first has.u.rest)]
::
++  rec-patterns-disjoint
  |=  pats=(list upat)
  ^-  ?
  ?~  pats  &
  ?.  (levy t.pats |=(p=upat =(%disjoint (union-relate i.pats p))))  |
  $(pats t.pats)
::
::
::
::  Repeated faces along an imported record spine fail closed. Hoon's type
::  graph can erase unfaced nested-cell boundaries, so that alone does not
::  prove the original source repeated a name within one record. A faced
::  body and each union alternative have separate scopes. Check recursive
::  roots before making them opaque; unused molds are never inspected.
::
++  imported-faces-valid
  |=  node=*
  ^-  ?
  ?@  node  &
  ?+  -.node  &
    %face  ?:(?=([%face @ *] node) $(node +>.node) |)
    %cell  ?:(?=([%cell * *] node) (imported-record-faces-valid node ~) |)
    %fork  (imported-faces-valid-list +.node)
    %apply  ?:(?=([%apply @ *] node) (imported-faces-valid-list +>.node) |)
    %named
      ?.  ?=([%named @ @ *] node)  |
      =/  n=[%named module=@ name=@ body=*]  ;;([%named module=@ name=@ body=*] node)
      (imported-faces-valid body.n)
  ==
::
++  imported-faces-valid-list
  |=  nodes=*
  ^-  ?
  ?@  nodes  =(nodes 0)
  ?.  (imported-faces-valid -.nodes)  |
  $(nodes +.nodes)
::
++  imported-record-faces-valid
  |=  [node=* names=(list @)]
  ^-  ?
  ?:  ?=([%cell * *] node)
    =/  head=*  +<.node
    =/  rest=*  +>.node
    ?:  ?=([%face @ *] head)
      ?:  (lien names |=(n=@ =(n +<.head)))  |
      ?.  (imported-faces-valid +>.head)  |
      $(node rest, names [+<.head names])
    ?.  (imported-faces-valid head)  |
    $(node rest)
  ?:  ?=([%face @ *] node)
    ?:  (lien names |=(n=@ =(n +<.node)))  |
    (imported-faces-valid +>.node)
  (imported-faces-valid node)
::
++  import-to-itype
  |=  node=*
  ^-  (unit itype)
  ?@  node  ~
  ?+  -.node  ~
    %noun  ?:(=(node [%noun ~]) `[%noun ~] ~)
    %atom
      ::  A Hoon loobean singleton is one of the two Jibb loobeans.
      ?:  ?=([%atom %f [~ @]] node)
        =/  value=@  +>+.node
        ?.  |(=(value 0) =(value 1))  ~
        =/  printed=@t  ?:(=(value 0) '%.y' '%.n')
        `[%const [%loobean %f value printed]]
      ::  Hoon's null singleton is the same noun as Jibb's `~` mold.
      ::  Other non-term singleton atoms remain unsupported here.
      ?:  ?=([%atom %n [~ @]] node)
        ?.  =(0 +>+.node)  ~
        `[%const [%null %n 0 '~']]
      ?:  ?=([%atom %tas [~ @]] node)
        =/  value=@  +>+.node
        ?.  |(=(value 0) (jibb-face-name value))  ~
        =/  printed=@t  ?:(=(value 0) '%$' (cat 3 '%' value))
        `[%const [%term %tas value printed]]
      ?.  ?=([%atom @ ~] node)  ~
      =/  aura=@ta  (@ta +<.node)
      ?.  |(?=(?(%u %ud %ux %uv %t %ta %tas %p %da %dr) aura) =('tD' aura))  ~
      `[%atom aura]
    %named
      ?.  ?=([%named @ @ *] node)  ~
      =/  n=[%named module=@ name=@ body=*]  ;;([%named module=@ name=@ body=*] node)
      ?.  &((jibb-face-name module.n) (jibb-face-name name.n))  ~
      ?.  ?=([%fork *] body.n)  ~
      =/  proof=(unit irec-pattern)  (rec-pattern body.n (@tas module.n) (@tas name.n))
      ?~  proof  ~
      ?.  has.u.proof  ~
      `[%recursive (@tas module.n) (@tas name.n) `(crip "{(trip name.n)}.{(trip module.n)}")]
    %apply
      ?.  ?=([%apply @ *] node)  ~
      =/  name=term  (@tas +<.node)
      =/  arity=@ud
        ?:  |(=(%list name) =(%unit name) =(%set name) =(%qeu name))  1
        ?:  |(=(%map name) =(%mop name) =(%jar name) =(%jug name))  2
        0
      ?:  =(arity 0)  ~
      =/  args=(unit (list itype))  (import-to-itypes +>.node)
      ?~  args  ~
      ?.  =(arity (lent u.args))  ~
      `[%collection name u.args]
    %fork
      ::  Hoon's ordinary ? mold is the fork of its two %f singletons.
      =/  raw=*  +.node
      ?:  |(=(raw ~[[%atom %f `0] [%atom %f `1]]) =(raw ~[[%atom %f `1] [%atom %f `0]]))
        `[%flag ~]
      =/  cases=(unit (list itype))  (import-to-itypes raw)
      ?~  cases  ~
      ?~  u.cases  ~
      ?~  t.u.cases  ~
      ?:  (import-has-loobean-singleton u.cases)  ~
      ?.  (import-cases-disjoint u.cases)  ~
      `[%union u.cases ~ ~ ~]
    %face
      ?.  ?=([%face @ *] node)  ~
      =/  name=@  +<.node
      ?.  (jibb-face-name name)  ~
      =/  body=(unit itype)  $(node +>.node)
      ?~  body  ~
      `[%face (@tas name) u.body]
    %cell
      ?.  ?=([%cell * *] node)  ~
      =/  left=(unit itype)  $(node +<.node)
      ?~  left  ~
      =/  right=(unit itype)  $(node +>.node)
      ?~  right  ~
      `[%cell u.left u.right]
  ==
::
++  import-direct-loobean
  |=  t=itype
  ^-  ?
  ?:  ?=(%face -.t)  $(t body.t)
  ?:  ?=(%union -.t)  (import-has-loobean-singleton cases.t)
  ?=([%const [%loobean *]] t)
::
++  import-has-loobean-singleton
  |=  cases=(list itype)
  ^-  ?
  ?~  cases  |
  ?:  (import-direct-loobean i.cases)  &
  $(cases t.cases)
::
++  import-to-itypes
  |=  nodes=*
  ^-  (unit (list itype))
  ?@  nodes  ?:(=(nodes 0) `~ ~)
  =/  first  (import-to-itype -.nodes)
  ?~  first  ~
  =/  rest  $(nodes +.nodes)
  ?~  rest  ~
  `[u.first u.rest]
::
++  import-type-pattern
  |=  typ=itype
  ^-  upat
  ?-  -.typ
    %noun   [%all ~]
    %atom   [%atom ~]
    %flag   [%or ~[[%atom `0] [%atom `1]]]
    %const  [%atom `val.literal.typ]
    %face   $(typ body.typ)
    %cell   [%cell $(typ hed.typ) $(typ tal.typ)]
    %union  [%or (turn cases.typ |=(t=itype (import-type-pattern t)))]
    *       [%unknown ~]
  ==
::
++  import-cases-disjoint
  |=  cases=(list itype)
  ^-  ?
  ?~  cases  &
  =/  first=upat  (import-type-pattern i.cases)
  ?.  (levy t.cases |=(t=itype =(%disjoint (union-relate first (import-type-pattern t)))))  |
  $(cases t.cases)
::
++  find-imported-mold
  |=  [module=term name=term externals=iexternals surs=(list term)]
  ^-  (unit itype)
  ?.  (lien surs |=(n=term =(n module)))  ~
  =/  found=iexternals
    (skim externals |=(e=[module=term name=term result=*] &(=(module module.e) =(name name.e))))
  ?~  found  ~
  ?^  t.found  ~
  =/  result=*  result.i.found
  ?@  result  ~
  ?.  ?=(%& -.result)  ~
  =/  node=*  +.result
  ?.  (imported-faces-valid node)  ~
  ?@  node  (import-to-itype node)
  ?:  ?=(%ref -.node)  (import-to-itype node)
  =/  pattern=(unit irec-pattern)  (rec-pattern node module name)
  ?~  pattern  (import-to-itype node)
  ?.  has.u.pattern  (import-to-itype node)
  `[%recursive module name `(crip "{(trip name)}.{(trip module)}")]

::
++  collect-sur-imports
  |=  imports=(list import)
  ^-  (list term)
  ?~  imports  ~
  ?:  ?=(%sur -.i.imports)
    [name.i.imports $(imports t.imports)]
  $(imports t.imports)
::
++  collect-mark-imports
  |=  imports=(list import)
  ^-  (list term)
  ?~  imports  ~
  ?:  ?=(%mark -.i.imports)
    [mark.i.imports $(imports t.imports)]
  $(imports t.imports)
::
++  find-imported-mark
  |=  [name=term externals=imark-externals marks=(list term)]
  ^-  (unit itype)
  ?.  (unique-value-name name marks)  ~
  =/  found=imark-externals
    (skim externals |=(e=[mark=term result=*] =(name mark.e)))
  ?~  found  ~
  ?^  t.found  ~
  =/  result=*  result.i.found
  ?@  result  ~
  ?.  ?=(%& -.result)  ~
  ?.  (imported-faces-valid +.result)  ~
  (import-to-itype +.result)
::
++  find-jibb-interface
  |=  [face=term imports=ijimports]
  ^-  (unit ifile)
  ?~  imports  ~
  ?:  =(face face.i.imports)  `interface.i.imports
  $(imports t.imports)
::
++  find-jibb-mold
  |=  [name=term iface=ifile]
  ^-  (unit ischeme)
  =/  ms=imold-types  molds.iface
  |-
  ?~  ms  ~
  ?:  =(name name.i.ms)  `template.i.ms
  $(ms t.ms)
::
::  An exported alias may name a union from another module. Only a
::  nongeneric alias of the same origin is usable through this import face.
::
++  imported-union-alias
  |=  [origin=[at=path name=term] molds=imold-types]
  ^-  (unit term)
  ?~  molds  ~
  =/  template=ischeme  template.i.molds
  ?:  &(?=(~ vars.template) ?=(%union -.typ.template))
    ?:(=(`origin origin.typ.template) `name.i.molds $(molds t.molds))
  $(molds t.molds)
::
::  A prelude union alias is a display name, not a new union identity.  An
::  identity-generic alias can carry the origin's arguments only when the
::  origin, arity and ordered parameters match.  Swapped, repeated, fixed
::  or phantom parameters cannot be printed that way and remain unsupported
::  when their only available name is private.  A nongeneric alias of a
::  generic instantiation cannot be printed with the origin's arguments.
++  identity-union-parameters
  |=  [vars=(list @ud) args=(list itype)]
  ^-  ?
  ?~  vars  ?=(~ args)
  ?~  args  |
  ?.  =([%var i.vars] i.args)  |
  $(vars t.vars, args t.args)
++  prelude-union-alias
  |=  [origin=[at=path name=term] args=(list itype) molds=imold-types]
  ^-  (unit term)
  ?~  molds  ~
  =/  template=ischeme  template.i.molds
  ?.  ?=(%union -.typ.template)  $(molds t.molds)
  ?.  =(`origin origin.typ.template)  $(molds t.molds)
  ?~  vars.template
    ?^  args  $(molds t.molds)
    ?:(=(args args.typ.template) `name.i.molds $(molds t.molds))
  ?:  &((identity-union-parameters vars.template args.typ.template) =((lent vars.template) (lent args)))
    `name.i.molds
  $(molds t.molds)
::
::  Names exported by the directly imported module are visible through its
::  face; a matching prelude alias is also visible without a qualifier.
::
++  jrec-alias
  |=  [origin=path name=term molds=imold-types]
  ^-  (unit term)
  ?~  molds  ~
  =/  template=ischeme  template.i.molds
  ?:  &(?=(~ vars.template) ?=(%jrec -.typ.template) =(at.typ.template origin) =(name.typ.template name))  `name.i.molds
  $(molds t.molds)
::
++  grec-visible-alias
  |=  [origin=path name=term proof=shape args=(list itype) molds=imold-types]
  ^-  (unit term)
  ?~  molds  ~
  =/  template=ischeme  template.i.molds
  ?.  ?=(%grec -.typ.template)  $(molds t.molds)
  ?.  &(=(at.typ.template origin) =(name.typ.template name) =(proof.typ.template proof))  $(molds t.molds)
  ?.  &((identity-union-parameters vars.template args.typ.template) =((lent vars.template) (lent args)))  $(molds t.molds)
  `name.i.molds
::
++  itype-in-import
  |=  [t=itype iface=ifile face=term prelude=(unit ifile)]
  ^-  itype
  ?-  -.t
    %union
      =/  label=(unit @t)
        ?~  origin.t  ~
        ?:  =(at.u.origin.t /lib/jibb/prelude/jibb)  `name.u.origin.t
        =/  public=(unit term)
          ?~  prelude  ~
          (prelude-union-alias u.origin.t args.t molds.u.prelude)
        ?^  public  `u.public
        =/  alias=(unit term)  ~
        =?  alias  &(=(at.u.origin.t at.iface) ?=(^ (find-jibb-mold name.u.origin.t iface)))  `name.u.origin.t
        =?  alias  ?=(~ alias)  (imported-union-alias u.origin.t molds.iface)
        ?~  alias  ~
        `(crip "{(trip u.alias)}.{(trip face)}")
      [%union (turn cases.t |=(c=itype (itype-in-import c iface face prelude))) origin.t label (turn args.t |=(c=itype (itype-in-import c iface face prelude)))]
    %recursive  [%recursive module.t name.t ~]
    %grec
      =/  public=(unit term)  ?~(prelude ~ (grec-visible-alias at.t name.t proof.t args.t molds.u.prelude))
      =/  alias=(unit term)  ?~(public (grec-visible-alias at.t name.t proof.t args.t molds.iface) public)
      =/  label=(unit @t)  ?~(alias ~ ?~(public `(crip "{(trip u.alias)}.{(trip face)}") `u.alias))
      t(label label, args (turn args.t |=(c=itype (itype-in-import c iface face prelude))))
    %jrec
      =/  public=(unit term)  ?~(prelude ~ (jrec-alias at.t name.t molds.u.prelude))
      ?^  public  t(label `u.public)
      =/  alias=(unit term)  (jrec-alias at.t name.t molds.iface)
      ?~  alias  t(label ~)
      t(label `(crip "{(trip u.alias)}.{(trip face)}"))
    %collection  [%collection name.t (turn args.t |=(c=itype (itype-in-import c iface face prelude)))]
    %face  [%face name.t $(t body.t)]
    %fn    [%fn $(t sample.t) $(t product.t)]
    %cell  [%cell $(t hed.t) $(t tal.t)]
    *      t
  ==
::
++  label-direct-union
  |=  [typ=itype body=shape name=term state=istate]
  ^-  itype
  ?.  ?=(%union -.typ)  typ
  =/  direct=?  ?=(%union -.body)
  =?  direct  ?=(%generic -.body)  ?=(%union -.body.body)
  ?.  direct  typ
  ?.  (lien top-molds.state |=(n=term =(n name)))  typ
  [%union cases.typ `[at.state name] `name args.typ]
::
::  Generic mold parameters are lexical and distinct from the enclosing
::  value's capital variables. Arguments are substituted only once, so
::  an argument's variable ID cannot be captured by a template ID.
::  A generic alias of a named union keeps the underlying union's origin
::  and substituted argument order; an originless union stays unsupported.
::
++  iparam-lookup
  |=  [name=@t params=iparams]
  ^-  (unit itype)
  ?~  params  ~
  ?:  =(name name.i.params)  `typ.i.params
  $(params t.params)
::
++  distinct-params
  |=  names=(list @t)
  ^-  ?
  ?~  names  &
  ?:  (lien t.names |=(n=@t =(n i.names)))  |
  $(names t.names)
::
++  bind-params
  |=  [names=(list @t) args=(list itype)]
  ^-  (unit iparams)
  ?~  names  ?~(args `~ ~)
  ?~  args  ~
  =/  rest=(unit iparams)  $(names t.names, args t.args)
  ?~  rest  ~
  `[[i.names i.args] u.rest]
::
++  template-apply
  |=  [template=ischeme args=(list itype)]
  ^-  (unit itype)
  =/  vars=(list @ud)  vars.template
  =/  ren=isub  ~
  |-
  ?~  vars  ?~(args `(itype-rename typ.template ren) ~)
  ?~  args  ~
  $(vars t.vars, args t.args, ren [[i.vars i.args] ren])
::
++  infer-shape-args
  |=  [args=(list shape) state=istate]
  ^-  (unit [types=(list itype) state=istate])
  ?~  args  `[~ state]
  =/  head=(unit [typ=itype state=istate])  (infer-simple-shape i.args state)
  ?~  head  ~
  =/  tail=(unit [types=(list itype) state=istate])  $(args t.args, state state.u.head)
  ?~  tail  ~
  `[[typ.u.head types.u.tail] state.u.tail]
::
++  fresh-mold-params
  |=  [names=(list @t) next=@ud]
  ^-  [params=iparams vars=(list @ud) next=@ud]
  ?~  names  [~ ~ next]
  =/  rest=[params=iparams vars=(list @ud) next=@ud]  $(names t.names, next +(next))
  [[[i.names [%var next]] params.rest] [next vars.rest] next.rest]
::
::  Recognize a unique top-level source mold with exactly a null case and a
::  faced atom-headed cell whose faced tail names that same mold. Its Jibb
::  path and name provide nominal identity. Other recursive shapes fail closed;
::  construction and matching expose the proven shape one layer at a time.
++  simple-source-recursive
  |=  [name=term sh=shape state=istate]
  ^-  (unit itype)
  ?.  (lien top-molds.state |=(n=term =(n name)))  ~
  =/  original=(unit shape)  (find-simple-mold name molds.state)
  ?~  original  ~
  ?.  =(u.original sh)  ~
  ?.  ?=(%union -.sh)  ~
  =/  cs=(list shape)  cases.sh
  ?~  cs  ~
  ?~  t.cs  ~
  ?^  t.t.cs  ~
  ?.  ?=(%const -.i.cs)  ~
  ?.  =(%null form.lit.i.cs)  ~
  ?.  ?=(%cell -.i.t.cs)  ~
  =/  fs=(list field)  fields.i.t.cs
  ?~  fs  ~
  ?~  t.fs  ~
  ?^  t.t.fs  ~
  ?.  ?=(%face -.i.fs)  ~
  ?.  ?=(%aura -.shape.i.fs)  ~
  ?.  !=(0 aura.shape.i.fs)  ~
  ?.  ?=(%face -.i.t.fs)  ~
  ?.  !=(name.i.fs name.i.t.fs)  ~
  =/  tail=shape  shape.i.t.fs
  ?.  ?=(%ref -.tail)  ~
  ?.  =(names.tail ~[name])  ~
  `[%jrec at.state name `name name.i.fs aura.shape.i.fs name.i.t.fs]
::
++  simple-source-generic-recursive
  |=  [name=term sh=shape args=(list itype) state=istate]
  ^-  (unit itype)
  ?.  ?=(%generic -.sh)  ~
  ?.  ?=([@ ~] vars.sh)  ~
  ?.  ?=([* ~] args)  ~
  ?~  grec-index.state  ~
  ?.  =(at.u.grec-index.state at.state)  ~
  ?~  prelude.state  ~
  ?.  =(prelude.u.grec-index.state u.prelude.state)  ~
  =/  proof=(unit shape)  (~(get by shapes.u.grec-index.state) name)
  ?~  proof  ~
  ?.  =(u.proof sh)  ~
  `[%grec at.state name `name sh args]
::

++  infer-mold-template
  |=  [sh=shape state=istate]
  ^-  (unit [template=ischeme state=istate])
  =/  generic=(unit itype)
    ?.  ?=([@ ~] active.state)  ~
    (simple-source-generic-recursive i.active.state sh ~[[%var next.state]] state)
  ?^  generic  `[[u.generic ~[next.state]] state(next +(next.state))]
  =/  direct=(unit itype)
    ?.  ?=([@ ~] active.state)  ~
    (simple-source-recursive i.active.state sh state)
  ?^  direct  `[[u.direct ~] state]
  ?:  ?=(%generic -.sh)
    ?~  vars.sh  ~
    ?.  (distinct-params vars.sh)  ~
    =/  fresh=[params=iparams vars=(list @ud) next=@ud]  (fresh-mold-params vars.sh next.state)
    =/  out=(unit [typ=itype state=istate])
      (infer-simple-shape body.sh state(next next.fresh, params params.fresh, in-mold &))
    ?~  out  ~
    ?^  (unresolved-hole holes.state.u.out holes.state state.u.out)  ~
    ?:  &(?=(%union -.typ.u.out) !?=(%union -.body.sh) ?=(~ origin.typ.u.out))  ~
    =?  typ.u.out  &(?=(%union -.typ.u.out) ?=(%union -.body.sh))
      typ.u.out(args (turn vars.fresh |=(n=@ud `itype`[%var n])))
    =/  used=(list @ud)  (itype-vars typ.u.out)
    ?.  (levy used |=(n=@ud (lien vars.fresh |=(p=@ud =(p n)))))  ~
    `[[typ.u.out vars.fresh] state.u.out(params params.state, in-mold in-mold.state, holes holes.state)]
  =/  out=(unit [typ=itype state=istate])
    (infer-simple-shape sh state(params ~, in-mold &))
  ?~  out  ~
  ?^  (unresolved-hole holes.state.u.out holes.state state.u.out)  ~
  ?:  ?=(^ (itype-vars typ.u.out))  ~
  `[[typ.u.out ~] state.u.out(params params.state, in-mold in-mold.state, holes holes.state)]
::
::  A direct imported reference may carry definite reader evidence. Only
::  uniquely supplied, declared inputs are used; unsupported data stay generic.
++  direct-import-invalid
  |=  [sh=shape state=istate]
  ^-  (unit idiag)
  ?.  ?=(%ref -.sh)  ~
  ?~  names.sh  ~
  =/  n=term  i.names.sh
  =/  raw=*
    ?~  t.names.sh
      ?.  (unique-value-name n marks.state)  ~
      ?:  (lien surs.state |=(x=term =(x n)))  ~
      ?:  ?=(^ (find-jibb-interface n jimports.state))  ~
      ?:  (lien globals.state |=(x=term =(x n)))  ~
      ?:  (lien reserved-molds.state |=(x=term =(x n)))  ~
      ?:  (lien molds.state |=(m=[name=term body=shape] =(n name.m)))  ~
      =/  found=imark-externals  (skim mark-externals.state |=(e=[mark=term result=*] =(mark.e n)))
      ?~  found  ~
      ?^  t.found  ~
      result.i.found
    ?^  t.t.names.sh  ~
    =/  mod=term  i.t.names.sh
    ?:  ?=(^ (find-jibb-interface mod jimports.state))  ~
    ?.  (unique-value-name mod surs.state)  ~
    ?:  (lien marks.state |=(x=term =(x mod)))  ~
    ?:  (lien globals.state |=(x=term =(x mod)))  ~
    ?:  (lien reserved-molds.state |=(x=term =(x mod)))  ~
    ?:  (lien molds.state |=(m=[name=term body=shape] =(mod name.m)))  ~
    =/  found=iexternals  (skim externals.state |=(e=[module=term name=term result=*] &(=(module.e mod) =(name.e n))))
    ?~  found  ~
    ?^  t.found  ~
    result.i.found
  ?.  ?=([%invalid ?(%aura %core %overlap) @] raw)  ~
  `["{(trip +>.raw)}" ~[[at.sh "invalid imported mold"]]]
::
::  Replay only the shape branches whose evaluation order we can prove.
::  Successful prefixes must be checked before descending to a failure.
++  nested-import-invalid
  |=  [sh=shape state=istate]
  ^-  (unit idiag)
  ?:  ?=(^ (infer-simple-shape sh state))  ~
  ?-  -.sh
    %ref
      =/  direct=(unit idiag)  (direct-import-invalid sh state)
      ?^  direct  direct
      ?~  names.sh  ~
      ?^  t.names.sh  ~
      =/  n=term  i.names.sh
      ?:  (lien marks.state |=(x=term =(x n)))  ~
      ?:  (lien active.state |=(x=term =(x n)))  ~
      =/  found=(unit shape)  (find-simple-mold n molds.state)
      ?~  found  ~
      $(sh u.found, state state(active [n active.state], in-mold &, params ~))
    %fn
      =/  first=(unit [typ=itype state=istate])  (infer-simple-shape sample.sh state)
      ?~  first  $(sh sample.sh)
      $(sh product.sh, state state.u.first)
    %cell  (nested-field-invalid fields.sh state)
    *  ~
  ==
::
++  nested-field-invalid
  |=  [fields=(list field) state=istate]
  ^-  (unit idiag)
  ?~  fields  ~
  =/  sh=shape
    ?-  -.i.fields
      %bare  shape.i.fields
      %face  shape.i.fields
      %pun   [%ref at.i.fields ~[name.i.fields]]
    ==
  =/  out=(unit [typ=itype state=istate])  (infer-simple-shape sh state)
  ?~  out  (nested-import-invalid sh state)
  $(fields t.fields, state state.u.out)
::
++  sample-import-invalid
  |=  [s=sample env=ienv state=istate]
  ^-  (unit idiag)
  =/  result=isample-result  (infer-sample s env state)
  ?:  ?=(%& -.result)  ~
  ?.  =(p.result "sample mold is not supported by partial inference")  ~
  ?-  s
    [%face *]  (nested-import-invalid shape.s state)
    [%bare *]  (nested-import-invalid shape.s state)
    [%pun *]  (nested-import-invalid [%ref at.s ~[name.s]] state)
    [%cell *]  (nested-samples-invalid items.s env state)
    *  ~
  ==
::
++  nested-samples-invalid
  |=  [items=(list sample) env=ienv state=istate]
  ^-  (unit idiag)
  ?~  items  ~
  =/  head=isample-result  (infer-sample i.items env state)
  ?:  ?=(%| -.head)  (sample-import-invalid i.items env state)
  $(items t.items, env env.p.head, state state.p.head)
::
++  infer-simple-shape
  |=  [sh=shape state=istate]
  ^-  (unit [typ=itype state=istate])
  ?-  -.sh
    %hole  `[[%var next.state] state(next +(next.state), holes [[next.state at.sh] holes.state])]
    %aura
      ?:  =(0 aura.sh)  `[[%any-atom ~] state]
      `[[%atom aura.sh] state]
    %flag  `[[%flag ~] state]
    %noun  `[[%noun ~] state]
    %const
      ?.  |(=(%term form.lit.sh) =(%null form.lit.sh) =(%loobean form.lit.sh))  ~
      ?:  &(=(%loobean form.lit.sh) !|(=(0 val.lit.sh) =(1 val.lit.sh)))  ~
      `[[%const lit.sh] state]
    %union
      =/  pairs=(list upair)  (union-pairs cases.sh molds.state)
      ?.  (levy pairs |=(p=upair =(%disjoint relation.p)))  ~
      =/  cs=(unit [types=(list itype) state=istate])  (infer-shape-args cases.sh state)
      ?~  cs  ~
      `[[%union types.u.cs ~ ~ ~] state.u.cs]
    %cell  (infer-simple-fields fields.sh state)
    %fn
      =/  arg=(unit [typ=itype state=istate])  $(sh sample.sh)
      ?~  arg  ~
      =/  out=(unit [typ=itype state=istate])  $(sh product.sh, state state.u.arg)
      ?~  out  ~
      `[[%fn typ.u.arg typ.u.out] state.u.out]
    %ref
      ?~  names.sh  ~
      =/  n=term  i.names.sh
      ?^  t.names.sh
        ?^  t.t.names.sh  ~
        =/  iface=(unit ifile)  (find-jibb-interface i.t.names.sh jimports.state)
        ?^  iface
          =/  found=(unit ischeme)  (find-jibb-mold n u.iface)
          ?~  found  ~
          ?^  vars.u.found  ~
          `[(itype-in-import typ.u.found u.iface i.t.names.sh prelude.state) state]
        =/  found=(unit itype)
          (find-imported-mold i.t.names.sh n externals.state surs.state)
        ?~  found  ~
        `[u.found state]
      ?:  (lien marks.state |=(x=term =(x n)))
        ?^  (find-simple-mold n molds.state)  ~
        =/  imported=(unit itype)  (find-imported-mark n mark-externals.state marks.state)
        ?~  imported  ~
        `[u.imported state]
      ?:  (lien active.state |=(x=term =(x n)))  ~
      =/  found=(unit shape)  (find-simple-mold n molds.state)
      ?~  found
        ?:  (lien molds.state |=(m=[name=term body=shape] =(name.m n)))  ~
        ?~  prelude.state  ~
        =/  prelude-entry=(unit ischeme)  (find-jibb-mold n u.prelude.state)
        ?~  prelude-entry  ~
        ?^  vars.u.prelude-entry  ~
        `[typ.u.prelude-entry state]
      =/  direct=(unit itype)  (simple-source-recursive n u.found state)
      ?^  direct  `[u.direct state]
      =/  out=(unit [typ=itype state=istate])
        $(sh u.found, state state(active [n active.state], in-mold &, params ~))
      ?~  out  ~
      ?^  (unresolved-hole holes.state.u.out holes.state state.u.out)  ~
      `[(label-direct-union typ.u.out u.found n state) state.u.out(active active.state, in-mold in-mold.state, params params.state, holes holes.state)]
    %apply
      ?~  ref.sh  ~
      =/  args=(unit [types=(list itype) state=istate])  (infer-shape-args args.sh state)
      ?~  args  ~
      =/  n=term  i.ref.sh
      ?^  t.ref.sh
        ?^  t.t.ref.sh  ~
        =/  iface=(unit ifile)  (find-jibb-interface i.t.ref.sh jimports.state.u.args)
        ?~  iface  ~
        =/  template=(unit ischeme)  (find-jibb-mold n u.iface)
        ?~  template  ~
        ?~  vars.u.template  ~
        =/  applied=(unit itype)  (template-apply u.template types.u.args)
        ?~  applied  ~
        `[(itype-in-import u.applied u.iface i.t.ref.sh prelude.state.u.args) state.u.args]
      ?:  (lien active.state.u.args |=(x=term =(x n)))  ~
      =/  found=(unit shape)  (find-simple-mold n molds.state.u.args)
      ?~  found
        ?:  (lien molds.state.u.args |=(m=[name=term body=shape] =(name.m n)))  ~
        ?~  prelude.state.u.args  ~
        =/  prelude-entry=(unit ischeme)  (find-jibb-mold n u.prelude.state.u.args)
        ?~  prelude-entry  ~
        ?~  vars.u.prelude-entry  ~
        =/  applied=(unit itype)  (template-apply u.prelude-entry types.u.args)
        ?~  applied  ~
        `[u.applied state.u.args]
      ?.  ?=(%generic -.u.found)  ~
      =/  grec=(unit itype)  (simple-source-generic-recursive n u.found types.u.args state.u.args)
      ?^  grec  `[u.grec state.u.args]
      ?.  (distinct-params vars.u.found)  ~
      =/  params=(unit iparams)  (bind-params vars.u.found types.u.args)
      ?~  params  ~
      =/  out=(unit [typ=itype state=istate])
        $(sh body.u.found, state state.u.args(active [n active.state.u.args], in-mold &, params u.params))
      ?~  out  ~
      ?^  (unresolved-hole holes.state.u.out holes.state.u.args state.u.out)  ~
      ?:  &(?=(%union -.typ.u.out) !?=(%union -.body.u.found) ?=(~ origin.typ.u.out))  ~
      ?:  &(?=(%union -.typ.u.out) ?=(%union -.body.u.found) !(lien top-molds.state.u.args |=(x=term =(x n))))  ~
      =?  typ.u.out  &(?=(%union -.typ.u.out) ?=(%union -.body.u.found))
        (label-direct-union typ.u.out(args types.u.args) u.found n state.u.args)
      `[typ.u.out state.u.out(active active.state.u.args, in-mold in-mold.state.u.args, params params.state.u.args, holes holes.state.u.args)]
    %tvar
      =/  param=(unit itype)  (iparam-lookup name.sh params.state)
      ?^  param  `[u.param state]
      ?:  in-mold.state  ~
      =/  n=(unit @ud)  (icap-lookup name.sh caps.state)
      ?^  n  `[[%var u.n] state]
      `[[%var next.state] state(next +(next.state), caps [[name.sh next.state at.sh] caps.state])]
    *      ~
  ==
::
++  infer-simple-fields
  |=  [fields=(list field) state=istate]
  ^-  (unit [typ=itype state=istate])
  ?~  fields  ~
  =/  field-shape=shape
    ?-  -.i.fields
      %bare  shape.i.fields
      %face  shape.i.fields
      %pun   [%ref at.i.fields ~[name.i.fields]]
    ==
  =/  head=(unit [typ=itype state=istate])  (infer-simple-shape field-shape state)
  ?~  head  ~
  =/  t=itype  typ.u.head
  =.  t
    ?-  -.i.fields
      %bare  t
      %face  [%face name.i.fields t]
      %pun   [%face name.i.fields t]
    ==
  ?~  t.fields  `[t state.u.head]
  =/  tail=(unit [typ=itype state=istate])  $(fields t.fields, state state.u.head)
  ?~  tail  ~
  `[[%cell t typ.u.tail] state.u.tail]
::
++  infer-sample
  |=  [s=sample env=ienv state=istate]
  ^-  isample-result
  ?-  -.s
    %bind
      ?:  |(=(name.s %proj) ?=(^ (ienv-lookup name.s env)) (lien globals.state |=(x=term =(x name.s))))
        [%| "sample shadows a name"]
      =/  t=itype  [%var next.state]
      [%& t [[name.s [t ~]] env] state(next +(next.state), binders [next.state binders.state])]
    %face
      ?:  |(=(name.s %proj) ?=(^ (ienv-lookup name.s env)) (lien globals.state |=(x=term =(x name.s))))
        [%| "sample shadows a name"]
      =/  t=(unit [typ=itype state=istate])  (infer-simple-shape shape.s state)
      ?~  t  [%| "sample mold is not supported by partial inference"]
      [%& typ.u.t [[name.s [typ.u.t ~]] env] state.u.t]
    %bare
      =/  t=(unit [typ=itype state=istate])  (infer-simple-shape shape.s state)
      ?~  t  [%| "sample mold is not supported by partial inference"]
      [%& typ.u.t env state.u.t]
    %pun
      $(s [%face at.s name.s [%ref at.s ~[name.s]]])
    %cell
      (infer-sample-items items.s env state)
  ==
::
::  Cell-sample binders are faces on their positions; at the top of a
::  sample a binder only supplies a name for the whole sample.
::
++  infer-sample-items
  |=  [items=(list sample) env=ienv state=istate]
  ^-  isample-result
  ?~  items  [%| "empty sample is not supported by partial inference"]
  =/  head=isample-result  (infer-sample i.items env state)
  ?:  ?=(%| -.head)  head
  =/  ht=itype  typ.p.head
  =.  ht
    ?-  -.i.items
      %bind  [%face name.i.items ht]
      %face  [%face name.i.items ht]
      %pun   [%face name.i.items ht]
      *      ht
    ==
  ?~  t.items  [%& ht env.p.head state.p.head]
  =/  tail=isample-result  $(items t.items, env env.p.head, state state.p.head)
  ?:  ?=(%| -.tail)  tail
  [%& [%cell ht typ.p.tail] env.p.tail state.p.tail]
::
::  Local definitions generalize only variables outside their enclosing
::  environment and explicit-capital scope. Recursive gate groups use
::  monomorphic placeholders while their bodies are checked.
::
+$  ilocal-result  (each [env=ienv state=istate] idiag)
++  free-env-vars
  |=  [env=ienv sub=isub]
  ^-  (list @ud)
  ?~  env  ~
  =/  sc=ischeme  scheme.i.env
  =/  ids=(list @ud)  (unique-type-vars (itype-vars typ.sc))
  =/  free=(list @ud)  ~
  |-
  ?~  ids  (weld free (free-env-vars t.env sub))
  ?:  (lien vars.sc |=(n=@ud =(n i.ids)))  $(ids t.ids)
  =/  resolved=itype  (itype-normalize [%var i.ids] sub)
  $(ids t.ids, free (weld (itype-vars resolved) free))
::
++  free-cap-vars
  |=  [caps=icaps sub=isub]
  ^-  (list @ud)
  ?~  caps  ~
  (weld (itype-vars (itype-normalize [%var id.i.caps] sub)) $(caps t.caps))
::
++  local-names-valid
  |=  [ds=(list def) env=ienv state=istate]
  ^-  ?
  =/  names=(list term)  (global-value-names ds)
  |-
  ?~  ds  &
  ?:  ?=(%mold -.i.ds)  $(ds t.ds)
  ?:  =(name.i.ds %proj)  |
  ?.  (unique-value-name name.i.ds names)  |
  ?:  ?=(^ (ienv-lookup name.i.ds env))  |
  ?:  (lien globals.state |=(n=term =(n name.i.ds)))  |
  $(ds t.ds)
::
::  The supported local molds are nonrecursive simple aliases. Validate
::  all of them, including unused ones, before checking any local values.
::  The enclosing gate sample was checked before this scope was entered.
::
++  local-value-defs
  |=  ds=(list def)
  ^-  (list def)
  ?~  ds  ~
  ?:  ?=(%mold -.i.ds)  $(ds t.ds)
  [i.ds $(ds t.ds)]
::
++  local-mold-names-valid
  |=  [locals=imolds state=istate]
  ^-  ?
  =/  names=(list term)  (turn locals |=(m=[name=term body=shape] name.m))
  |-
  ?~  locals  &
  =/  n=term  name.i.locals
  ?:  =(n %proj)  |
  ?.  (unique-value-name n names)  |
  ?:  (lien molds.state |=(m=[name=term body=shape] =(n name.m)))  |
  ?:  (lien marks.state |=(m=term =(n m)))  |
  ?:  (lien reserved-molds.state |=(m=term =(n m)))  |
  ?:  (lien surs.state |=(m=term =(n m)))  |
  $(locals t.locals)
::
++  local-molds-supported
  |=  [locals=imolds state=istate]
  ^-  ?
  ?~  locals  &
  =/  m=[name=term body=shape]  i.locals
  =/  inferred=(unit [template=ischeme state=istate])
    (infer-mold-template body.m state(active [name.m active.state], in-mold &))
  ?~  inferred  |
  $(locals t.locals)
::
::  Gather written capitals belonging to one ++. Nested local definitions
::  establish their own scopes; inline gates remain in the enclosing scope.
+$  icap-site  [name=@t at=span]
++  scope-shape
  |=  s=shape
  ^-  (list icap-site)
  ?-  -.s
    %tvar     ~[[name.s at.s]]
    %apply    (zing (turn args.s scope-shape))
    %cell     (zing (turn fields.s scope-field))
    %union    (zing (turn cases.s scope-shape))
    %fn       (weld (scope-shape sample.s) (scope-shape product.s))
    %generic
      =/  inside=(list icap-site)  (scope-shape body.s)
      (skim inside |=(site=icap-site !(lien vars.s |=(v=@t =(v name.site)))))
    *  ~
  ==
::
++  scope-field
  |=  f=field
  ^-  (list icap-site)
  ?-  -.f
    %face  (scope-shape shape.f)
    %bare  (scope-shape shape.f)
    %pun   ~
  ==
::
++  scope-sample
  |=  s=sample
  ^-  (list icap-site)
  ?-  -.s
    %face  (scope-shape shape.s)
    %bare  (scope-shape shape.s)
    %cell  (zing (turn items.s scope-sample))
    *      ~
  ==
::
++  scope-pieces
  |=  ps=(list piece)
  ^-  (list icap-site)
  ?~  ps  ~
  =/  first=(list icap-site)
    ?-  -.i.ps
      %expr  (scope-expr p.i.ps)
      %text  ~
    ==
  (weld first $(ps t.ps))
::
++  scope-qsegs
  |=  ps=(list qseg)
  ^-  (list icap-site)
  ?~  ps  ~
  =/  first=(list icap-site)
    ?-  -.i.ps
      %expr  (scope-expr p.i.ps)
      %knot  ~
    ==
  (weld first $(ps t.ps))
::
++  scope-edits
  |=  xs=(list edit)
  ^-  (list icap-site)
  ?~  xs  ~
  =/  first=(list icap-site)  (scope-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  scope-items
  |=  xs=(list item)
  ^-  (list icap-site)
  ?~  xs  ~
  =/  first=(list icap-site)  (scope-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  scope-arms
  |=  xs=(list arm)
  ^-  (list icap-site)
  ?~  xs  ~
  =/  first=(list icap-site)  (scope-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  scope-exprs
  |=  xs=(list expr)
  ^-  (list icap-site)
  ?~  xs  ~
  =/  first=(list icap-site)  (scope-expr i.xs)
  (weld first $(xs t.xs))
::
++  scope-expr
  |=  e=expr
  ^-  (list icap-site)
  ?-  -.e
    %str     (scope-pieces pieces.e)
    %qath    (scope-qsegs segs.e)
    %change  (scope-edits edits.e)
    %pair    (scope-expr val.e)
    %unit    (scope-expr val.e)
    %group   (scope-expr inner.e)
    %list    (scope-exprs items.e)
    %tuple   (scope-items items.e)
    %gate
      =/  first=(list icap-site)  (scope-sample sample.e)
      =/  last=(list icap-site)  (scope-expr body.e)
      (weld first last)
    %gate-wide
      =/  first=(list icap-site)  (scope-sample sample.e)
      =/  last=(list icap-site)  (scope-expr body.e)
      (weld first last)
    %call
      =/  first=(list icap-site)  (scope-expr head.e)
      =/  last=(list icap-site)  (scope-exprs args.e)
      (weld first last)
    %cast
      =/  first=(list icap-site)  (scope-shape shape.e)
      =/  last=(list icap-site)  (scope-expr val.e)
      (weld first last)
    %trace
      =/  first=(list icap-site)  (scope-expr val.e)
      =/  last=(list icap-site)  (scope-expr then.e)
      (weld first last)
    %branch
      =/  first=(list icap-site)  (scope-expr subject.e)
      =/  last=(list icap-site)  (scope-arms arms.e)
      (weld first last)
    %body  (scope-expr final.e)
    *  ~
  ==
::
++  reserve-cap-sites
  |=  [sites=(list icap-site) state=istate]
  ^-  istate
  ?~  sites  state
  ?:  ?=(^ (icap-lookup name.i.sites caps.state))  $(sites t.sites)
  $(sites t.sites, state state(next +(next.state), caps [[name.i.sites next.state at.i.sites] caps.state]))
::
++  reserve-def-caps
  |=  [e=expr state=istate]
  ^-  istate
  (reserve-cap-sites (scope-expr e) state)
::
++  infer-local-defs
  |=  [ds=(list def) env=ienv state=istate]
  ^-  ilocal-result
  =/  remaining=(list def)  ~
  =/  progressed=?  |
  |-
  ?~  ds
    ?~  remaining  [%& env state]
    ?.  progressed
      =/  pending=(list def)  (flop remaining)
      =/  groups=icomponents  (graph-components pending (global-value-names pending))
      =/  grouped=(unit [rest=(list def) env=ienv state=istate])
        (try-local-group pending groups env state)
      ?~  grouped  [%| ["local definitions need unsupported inference" ~]]
      $(ds rest.u.grouped, remaining ~, env env.u.grouped, state state.u.grouped, progressed |)
    $(ds (flop remaining), remaining ~, progressed |)
  =/  d=def  i.ds
  ?>  ?=(%value -.d)
  =/  local-state=istate  (reserve-def-caps val.d state)
  =/  inferred=iresult  (infer-fragment val.d env local-state)
  =/  retried=?  ?=(%| -.inferred)
  =?  inferred  retried  (infer-recursive-gate d env local-state)
  ?:  ?=(%| -.inferred)  $(ds t.ds, remaining [d remaining])
  ?:  !=(obligations.state.p.inferred obligations.state)  [%| ["deferred local definition needs unsupported inference" ~]]
  =.  state.p.inferred  (promote-restricted-numbers state.p.inferred env)
  =.  state.p.inferred  (default-hole-numbers holes.state.p.inferred holes.state state.p.inferred env !(itype-has-gate (itype-normalize typ.p.inferred sub.state.p.inferred)))
  =/  hole=(unit idiag)  (unresolved-hole holes.state.p.inferred holes.state state.p.inferred)
  ?^  hole  [%| u.hole]
  =/  merged=(unit [first=icap second=icap])
    (merged-capitals caps.state.p.inferred sub.state.p.inferred)
  ?^  merged
    [%| ["distinct type variables `{(trip name.first.u.merged)}` and `{(trip name.second.u.merged)}` must not be forced equal; use the same capital for a shared type" ~[[at.first.u.merged "first type variable"] [at.second.u.merged "second type variable"]]]]
  ?:  (constrained-capitals caps.state.p.inferred sub.state.p.inferred)
    [%| ["explicit capital constraints are not supported by partial inference" ~]]
  =/  typ=itype  (itype-normalize typ.p.inferred sub.state.p.inferred)
  ?:  |((pending-tags tags.state.p.inferred sub.state.p.inferred) (itype-has-tag typ))
    $(ds t.ds, remaining [d remaining])
  ?:  (unsupported-atom-vars typ caps.state.p.inferred binders.state.p.inferred sub.state.p.inferred)
    $(ds t.ds, remaining [d remaining])
  =/  free=(list @ud)
    (weld (free-env-vars env sub.state.p.inferred) (free-cap-vars caps.state sub.state.p.inferred))
  =/  vars=(list @ud)  (unique-type-vars (itype-vars typ))
  =.  vars  (skim vars |=(n=@ud !(lien free |=(f=@ud =(f n)))))
  $(ds t.ds, env [[name.d [typ vars]] env], state state.p.inferred(caps caps.state, holes holes.state), progressed &)
::
::  Try complete cyclic local groups after individual definitions stall.
::  Components with non-gates or unresolved constraints stay unavailable.
::
++  try-local-group
  |=  [ds=(list def) groups=icomponents env=ienv state=istate]
  ^-  (unit [rest=(list def) env=ienv state=istate])
  ?~  groups  ~
  =/  names=(list term)  i.groups
  ?.  (gth (lent names) 1)  $(groups t.groups)
  =/  members=(list def)
    (skim ds |=(d=def &(?=(%value -.d) (lien names |=(n=term =(n name.d))))))
  ?.  =((lent members) (lent names))  $(groups t.groups)
  =/  result=ilocal-result  (infer-gate-group members env state)
  ?:  ?=(%| -.result)  $(groups t.groups)
  =/  rest=(list def)
    (skim ds |=(d=def !(lien names |=(n=term =(n name.d)))))
  =/  more=(unit [rest=(list def) env=ienv state=istate])
    $(ds rest, groups t.groups, env env.p.result, state state.p.result)
  ?^  more  more
  `[rest env.p.result state.p.result]
::
::  Read only fields of a known record. Unresolved field constraints and
::  ambiguous repeated faces are outside this fragment. Imported record
::  spines with repeated names are unavailable when used.
::
++  record-fields-named
  |=  [name=term t=itype sub=isub]
  ^-  (list itype)
  =.  t  (itype-walk t sub)
  ?:  ?=(%face -.t)
    ?:(=(name name.t) ~[body.t] ~)
  ?.  ?=(%cell -.t)  ~
  =/  first=(list itype)  ~
  =/  head=itype  (itype-walk hed.t sub)
  =?  first  ?=(%face -.head)  ?:(=(name name.head) ~[body.head] ~)
  (weld first $(t tal.t))
::
++  infer-field-wing
  |=  [names=(list term) env=ienv state=istate]
  ^-  iresult
  =/  reverse=(list term)  (flop names)
  ?~  reverse  [%| ["empty wing" ~]]
  =/  iface=(unit ifile)  (find-jibb-interface i.reverse jimports.state)
  =/  fields=(list term)  t.reverse
  ?~  fields  [%| ["field access is not supported by partial inference" ~]]
  =/  scheme=(unit ischeme)
    ?~  iface
      (ienv-lookup i.reverse env)
    (ienv-lookup i.fields values.u.iface)
  ?~  scheme
    ?^  iface  [%| ["module member is not available to partial inference" ~]]
    [%| ["field access is not supported by partial inference" ~]]
  =/  inst=[typ=itype state=istate]
    ?~  iface  (instantiate-scheme u.scheme state)
    =/  imported=ischeme  u.scheme
    =.  typ.imported  (itype-in-import typ.imported u.iface i.reverse prelude.state)
    (instantiate-scheme imported state)
  =/  remaining=(list term)  ?~(iface fields t.fields)
  =/  typ=itype  typ.inst
  |-
  ?~  remaining  [%& typ state.inst]
  =/  found=(list itype)  (record-fields-named i.remaining typ sub.state.inst)
  ?~  found  [%| ["field is not available to partial inference" ~]]
  ?^  t.found  [%| ["field name is ambiguous in partial inference" ~]]
  $(remaining t.remaining, typ i.found)
::
::  Propagate a known union or list through supported loobean, unit and list
::  branches. Empty bodies and groups are transparent; bodies with definitions
::  keep their normal scoping and wait for general bidirectional inference.
::
++  context-union-branch
  |=  e=expr
  ^-  ?
  ?-  -.e
    %branch  &
    %group   $(e inner.e)
    %body    ?~(defs.e $(e final.e) |)
    *        |
  ==
::
++  infer-union-context
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?:  &(?=(%collection -.expected) =(%list name.expected) (context-list-expression e))
    (infer-list-context e expected env state context)
  ?:  ?=(%branch -.e)
    ?~  arms.e  [%| ["branch is not supported by partial inference" ~]]
    ?~  t.arms.e  [%| ["branch pattern is not supported by partial inference" ~]]
    ?^  t.t.arms.e  [%| ["branch is not supported by partial inference" ~]]
    =/  x=arm  i.arms.e
    =/  y=arm  i.t.arms.e
    ?:  |((unit-empty-pattern pat.x) (unit-empty-pattern pat.y))
      (infer-unit-branch e env state `[expected context])
    ?.  &(?=(%lit -.pat.x) ?=(%lit -.pat.y))
      [%| ["branch pattern is not supported by partial inference" ~]]
    ?.  &(=(%loobean form.lit.pat.x) =(%loobean form.lit.pat.y))
      [%| ["branch pattern is not supported by partial inference" ~]]
    ?:  =(val.lit.pat.x val.lit.pat.y)
      [%| ["branch does not cover both loobeans" ~]]
    =/  subject=iresult  (infer-fragment subject.e env state)
    ?:  ?=(%| -.subject)  subject
    =/  subject-type=itype  (itype-normalize typ.p.subject sub.state.p.subject)
    ?:  ?=(%union -.subject-type)
      [%| ["contextual union-pattern branch is not supported by partial inference" ~]]
    =/  su=(unit isub)  (itype-unify typ.p.subject [%flag ~] sub.state.p.subject)
    ?~  su  [%| ["loobean branch subject does not unify with ?" ~]]
    =/  left=iresult  $(e val.x, state state.p.subject(sub u.su))
    ?:  ?=(%| -.left)  left
    =/  right=iresult  $(e val.y, state state.p.left)
    ?:  ?=(%| -.right)  right
    [%& expected state.p.right]
  =/  value=iresult  (infer-fragment e env state)
  ?:  ?=(%| -.value)  value
  =/  fit=ifit  (itype-fit typ.p.value expected sub.state.p.value next.state.p.value)
  ?:  ?=(%unknown -.fit)
    ?:  &(?=(%collection -.expected) =(%list name.expected))
      [%| ["branch list constraint is not supported by partial inference" ~]]
    ?:  ?=(%flag -.expected)  [%| ["branch loobean constraint is not supported by partial inference" ~]]
    [%| ["branch union constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    =/  missing=(unit idiag)  (missing-union-tag e expected sub.state.p.value context)
    ?^  missing  [%| u.missing]
    =/  nested=(unit idiag)  (nested-missing-tag e typ.p.value expected sub.state.p.value next.state.p.value context)
    ?^  nested  [%| u.nested]
    ?:  &(?=(%collection -.expected) =(%list name.expected))
      [%| ["branch arm does not fit its expected list" ~[[context "expected list"] [(span-of e) "branch arm"]]]]
    ?:  ?=(%flag -.expected)
      [%| ["branch arm does not fit its expected loobean" ~[[context "expected loobean"] [(span-of e) "branch arm"]]]]
    [%| ["branch arm does not fit its expected union" ~[[context "expected union"] [(span-of e) "branch arm"]]]]
  [%& expected state.p.value(sub sub.fit, next next.fit)]
::
::  A list expression needs a known list target and the validated prelude list.
::  Literal items and unfaced two-item cons cells receive that target one by
::  one; pending constraints elsewhere stay in the threaded state.
::
++  context-list-expression
  |=  e=expr
  ^-  ?
  ?-  -.e
    %list   &
    %tuple  &
    %lit    |(=(%null form.lit.e) &(=(%term form.lit.e) =(0 val.lit.e)))
    %group  $(e inner.e)
    %body   ?~(defs.e $(e final.e) |)
    *       |
  ==
::
++  infer-list-context
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?~  prelude.state  [%| ["list literal needs the standard prelude in partial inference" ~]]
  ?.  =(at.u.prelude.state /lib/jibb/prelude/jibb)
    [%| ["list literal needs the standard prelude in partial inference" ~]]
  =/  standard=(unit ischeme)  (find-jibb-mold %list u.prelude.state)
  ?~  standard  [%| ["list literal needs the standard prelude in partial inference" ~]]
  ?.  =(u.standard [[%collection %list ~[[%var 0]]] ~[0]])
    [%| ["list literal needs the standard prelude in partial inference" ~]]
  =/  target=itype  (itype-walk expected sub.state)
  ?.  ?=(%collection -.target)  [%| ["list context is not supported by partial inference" ~]]
  ?.  =(%list name.target)  [%| ["list context is not supported by partial inference" ~]]
  ?~  args.target  [%| ["list context is not supported by partial inference" ~]]
  ?^  t.args.target  [%| ["list context is not supported by partial inference" ~]]
  ?:  ?=(%lit -.e)
    ?.  |(=(%null form.lit.e) &(=(%term form.lit.e) =(0 val.lit.e)))
      [%| ["list expression is not supported by partial inference" ~]]
    [%& target state]
  ?:  ?=(%list -.e)
    =/  result=iresult  (infer-list-items items.e i.args.target env state context)
    ?:  ?=(%| -.result)  result
    [%& target state.p.result]
  ?.  ?=(%tuple -.e)  [%| ["list expression is not supported by partial inference" ~]]
  ?~  items.e  [%| ["cons shape is not supported by partial inference" ~]]
  ?~  t.items.e  [%| ["cons shape is not supported by partial inference" ~]]
  ?^  t.t.items.e  [%| ["cons shape is not supported by partial inference" ~]]
  ?^  face.i.items.e  [%| ["faced cons is not supported by partial inference" ~]]
  ?^  face.i.t.items.e  [%| ["faced cons is not supported by partial inference" ~]]
  =/  head=iresult  (infer-list-items ~[val.i.items.e] i.args.target env state context)
  ?:  ?=(%| -.head)  head
  =/  target=itype  (itype-walk target sub.state.p.head)
  =/  tail=iresult
    ?:  (context-list-expression val.i.t.items.e)
      (infer-list-context val.i.t.items.e target env state.p.head context)
    (infer-fragment val.i.t.items.e env state.p.head)
  ?:  ?=(%| -.tail)  tail
  =/  fit=ifit  (itype-fit typ.p.tail target sub.state.p.tail next.state.p.tail)
  ?:  ?=(%unknown -.fit)  [%| ["list tail constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    [%| ["list tail does not fit its expected type" ~[[context (site-type-note "expected list" target sub.state.p.tail)] [(span-of val.i.t.items.e) (site-type-note "list tail" typ.p.tail sub.state.p.tail)]]]]
  [%& target state.p.tail(sub sub.fit, next next.fit)]
::
++  infer-open-list-items
  |=  [items=(list expr) expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?~  items  [%& expected state]
  =/  target=itype  (itype-walk expected sub.state)
  =/  value=iresult  (infer-call-context-arg i.items target env state context)
  ?:  ?=(%| -.value)  value
  =/  fit=ifit  (itype-fit typ.p.value target sub.state.p.value next.state.p.value)
  ?:  ?=(%unknown -.fit)  [%| ["list item constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    ?:  |((itype-family-related typ.p.value target sub.state.p.value) (itype-has-any-atom typ.p.value sub.state.p.value) (itype-has-any-atom target sub.state.p.value))
      [%| ["list item widening is not supported by partial inference" ~]]
    [%| ["list items do not have compatible types" ~[[context (site-type-note "expected item" target sub.state.p.value)] [(span-of i.items) (site-type-note "list item" typ.p.value sub.state.p.value)]]]]
  ?:  (itype-has-tag (itype-normalize expected sub.fit))
    [%| ["list item needs context in partial inference" ~]]
  $(items t.items, state state.p.value(sub sub.fit, next next.fit))
::
++  infer-list-items
  |=  [items=(list expr) expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?~  items  [%& expected state]
  =/  target=itype  (itype-walk expected sub.state)
  =/  value=iresult  (infer-call-context-arg i.items target env state context)
  ?:  ?=(%| -.value)  value
  =/  fit=ifit  (itype-fit typ.p.value target sub.state.p.value next.state.p.value)
  ?:  ?=(%unknown -.fit)  [%| ["list item constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    =/  missing=(unit idiag)  (missing-union-tag i.items target sub.state.p.value context)
    ?^  missing  [%| u.missing]
    =/  nested=(unit idiag)  (nested-missing-tag i.items typ.p.value target sub.state.p.value next.state.p.value context)
    ?^  nested  [%| u.nested]
    [%| ["list item does not fit its expected type" ~[[context (site-type-note "expected item" target sub.state.p.value)] [(span-of i.items) (site-type-note "list item" typ.p.value sub.state.p.value)]]]]
  $(items t.items, state state.p.value(sub sub.fit, next next.fit))
::
::  The supported unit pattern covers exactly an atom zero and a cell
::  headed by zero, with a single binder for its payload. Unresolved
::  subjects and all other pattern matrices stay outside this fragment.
::
++  unit-empty-pattern
  |=  p=pattern
  ^-  ?
  ?.  ?=(%lit -.p)  |
  =(%null form.lit.p)
::
++  unit-payload-pattern
  |=  p=pattern
  ^-  (unit term)
  ?.  ?=(%cell -.p)  ~
  ?~  items.p  ~
  ?~  t.items.p  ~
  ?^  t.t.items.p  ~
  ?.  (unit-empty-pattern i.items.p)  ~
  ?.  ?=(%bind -.i.t.items.p)  ~
  `name.i.t.items.p
::
++  unit-empty-case
  |=  t=itype
  ^-  ?
  ?.  ?=(%const -.t)  |
  =(0 val.literal.t)
::
++  unit-payload-case
  |=  t=itype
  ^-  (unit itype)
  ?.  ?=(%cell -.t)  ~
  ?.  (unit-empty-case hed.t)  ~
  =/  payload=itype  tal.t
  =?  payload  ?=(%face -.payload)  body.payload
  `payload
::
++  unit-union-payload
  |=  t=itype
  ^-  (unit itype)
  ?.  ?=(%union -.t)  ~
  ?~  cases.t  ~
  ?~  t.cases.t  ~
  ?^  t.t.cases.t  ~
  ?:  (unit-empty-case i.cases.t)  (unit-payload-case i.t.cases.t)
  ?:  (unit-empty-case i.t.cases.t)  (unit-payload-case i.cases.t)
  ~
::
::  List matching currently covers exactly null and a cell of two binders.
::  The head has the element type and the tail has the whole list type.
::  Other patterns and lists whose element mold is empty remain unsupported.
::
++  list-payload-pattern
  |=  p=pattern
  ^-  (unit [head=term tail=term])
  ?.  ?=(%cell -.p)  ~
  ?~  items.p  ~
  ?~  t.items.p  ~
  ?^  t.t.items.p  ~
  ?.  ?=(%bind -.i.items.p)  ~
  ?.  ?=(%bind -.i.t.items.p)  ~
  `[name.i.items.p name.i.t.items.p]
::
++  infer-list-branch
  |=  [e=expr env=ienv state=istate expected=(unit [typ=itype context=span]) typ=itype]
  ^-  iresult
  ?>  ?=(%branch -.e)
  ?>  ?=(%collection -.typ)
  ?.  =(%list name.typ)  [%| ["list pattern is not supported by partial inference" ~]]
  ?~  prelude.state  [%| ["list pattern needs the standard prelude in partial inference" ~]]
  ?.  =(at.u.prelude.state /lib/jibb/prelude/jibb)
    [%| ["list pattern needs the standard prelude in partial inference" ~]]
  =/  standard=(unit ischeme)  (find-jibb-mold %list u.prelude.state)
  ?~  standard  [%| ["list pattern needs the standard prelude in partial inference" ~]]
  ?.  =(u.standard [[%collection %list ~[[%var 0]]] ~[0]])
    [%| ["list pattern needs the standard prelude in partial inference" ~]]
  ?~  args.typ  [%| ["list pattern is not supported by partial inference" ~]]
  ?^  t.args.typ  [%| ["list pattern is not supported by partial inference" ~]]
  ?~  arms.e  [%| ["list branch is not supported by partial inference" ~]]
  ?~  t.arms.e  [%| ["list branch is not supported by partial inference" ~]]
  ?^  t.t.arms.e  [%| ["list branch is not supported by partial inference" ~]]
  =/  x=arm  i.arms.e
  =/  y=arm  i.t.arms.e
  =/  first-empty=?  (unit-empty-pattern pat.x)
  =/  first-name=(unit [head=term tail=term])  (list-payload-pattern pat.x)
  =/  second-name=(unit [head=term tail=term])  (list-payload-pattern pat.y)
  ?.  |(&(first-empty ?=(^ second-name)) &((unit-empty-pattern pat.y) ?=(^ first-name)))
    [%| ["list branch pattern is not supported by partial inference" ~]]
  =/  binder=(unit [head=term tail=term])  ?:(first-empty second-name first-name)
  ?~  binder  [%| ["list branch pattern is not supported by partial inference" ~]]
  ?:  |(=(head.u.binder %proj) =(tail.u.binder %proj) =(head.u.binder tail.u.binder) ?=(^ (ienv-lookup head.u.binder env)) ?=(^ (ienv-lookup tail.u.binder env)) (lien globals.state |=(n=term |(=(n head.u.binder) =(n tail.u.binder)))))
    [%| ["pattern binder shadows a name" ~]]
  =/  extended=ienv  [[head.u.binder [i.args.typ ~]] [tail.u.binder [typ ~]] env]
  =/  left=iresult
    ?~  expected  (infer-fragment val.x ?:(first-empty env extended) state)
    (infer-union-context val.x typ.u.expected ?:(first-empty env extended) state context.u.expected)
  ?:  ?=(%| -.left)  left
  =/  right=iresult
    ?~  expected  (infer-fragment val.y ?:(first-empty extended env) state.p.left)
    (infer-union-context val.y typ.u.expected ?:(first-empty extended env) state.p.left context.u.expected)
  ?:  ?=(%| -.right)  right
  ?^  expected  [%& typ.u.expected state.p.right]
  =/  joined=(unit isub)  (itype-unify typ.p.left typ.p.right sub.state.p.right)
  ?~  joined  [%| ["list branch results need unsupported inference" ~]]
  [%& typ.p.left state.p.right(sub u.joined)]
::
++  infer-unit-branch
  |=  [e=expr env=ienv state=istate expected=(unit [typ=itype context=span])]
  ^-  iresult
  ?>  ?=(%branch -.e)
  ?~  arms.e  [%| ["unit branch is not supported by partial inference" ~]]
  ?~  t.arms.e  [%| ["unit branch is not supported by partial inference" ~]]
  ?^  t.t.arms.e  [%| ["unit branch is not supported by partial inference" ~]]
  =/  subject=iresult  (infer-fragment subject.e env state)
  ?:  ?=(%| -.subject)  subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?:  &(?=(%collection -.typ) =(%list name.typ))
    (infer-list-branch e env state.p.subject expected typ)
  =/  x=arm  i.arms.e
  =/  y=arm  i.t.arms.e
  =/  first-empty=?  (unit-empty-pattern pat.x)
  =/  first-name=(unit term)  (unit-payload-pattern pat.x)
  =/  second-name=(unit term)  (unit-payload-pattern pat.y)
  ?.  |(&(first-empty ?=(^ second-name)) &((unit-empty-pattern pat.y) ?=(^ first-name)))
    [%| ["unit branch pattern is not supported by partial inference" ~]]
  =/  binder=(unit term)  ?:(first-empty second-name first-name)
  ?~  binder  [%| ["unit branch pattern is not supported by partial inference" ~]]
  ?:  |(=(u.binder %proj) ?=(^ (ienv-lookup u.binder env)) (lien globals.state |=(n=term =(n u.binder))))
    [%| ["pattern binder shadows a name" ~]]
  =/  payload=(unit itype)  (unit-union-payload typ)
  ?~  payload  [%| ["unit branch subject is not supported by partial inference" ~]]
  =/  extended=ienv  [[u.binder [u.payload ~]] env]
  =/  left=iresult
    ?~  expected  (infer-fragment val.x ?:(first-empty env extended) state.p.subject)
    (infer-union-context val.x typ.u.expected ?:(first-empty env extended) state.p.subject context.u.expected)
  ?:  ?=(%| -.left)  left
  =/  right=iresult
    ?~  expected  (infer-fragment val.y ?:(first-empty extended env) state.p.left)
    (infer-union-context val.y typ.u.expected ?:(first-empty extended env) state.p.left context.u.expected)
  ?:  ?=(%| -.right)  right
  ?^  expected  [%& typ.u.expected state.p.right]
  =/  joined=(unit isub)  (itype-unify typ.p.left typ.p.right sub.state.p.right)
  ?~  joined  [%| ["unit branch results need unsupported inference" ~]]
  [%& typ.p.left state.p.right(sub u.joined)]
::
::  Infer pieces in order, retaining their substitutions and pending tags.
::  A bare decimal literal has no outside type constraint, so it takes its
::  normal @ud default here. Other open numeric and aura variables wait for
::  deferred constraints, which this fragment does not implement yet.
++  infer-string-pieces
  |=  [ps=(list piece) env=ienv state=istate]
  ^-  iresult
  ?~  ps  [%& [%atom %t] state]
  ?:  ?=(%text -.i.ps)  $(ps t.ps)
  =/  item=iresult  (infer-fragment p.i.ps env state)
  ?:  ?=(%| -.item)  item
  =/  t=itype  (itype-normalize typ.p.item sub.state.p.item)
  ?:  |(?=(%atom -.t) ?=(%any-atom -.t))
    $(ps t.ps, state state.p.item)
  ?:  &(|(?=(%nvar -.t) ?=(%rnvar -.t)) ?=(%lit -.p.i.ps) =(%number form.lit.p.i.ps))
    $(ps t.ps, state state.p.item)
  ?:  &(?=(%collection -.t) =(%list name.t) =(~[[%atom 'tD']] args.t))
    $(ps t.ps, state state.p.item)
  ?:  &(?=(%avar -.t) (atom-var-from-cap id.t caps.state.p.item sub.state.p.item))
    [%| ["a generic atom in interpolation needs an aura" ~[[(span-of p.i.ps) "atom with a generic aura"]]]]
  ?:  &(?=(%rvar -.t) (atom-var-from-cap id.t caps.state.p.item sub.state.p.item))
    [%| ["a generic atom in interpolation needs an aura" ~[[(span-of p.i.ps) "atom with a generic aura"]]]]
  ?:  ?=(%cell -.t)
    [%| ["a cell in interpolation needs a printer" ~[[(span-of p.i.ps) "cell without a printer"]]]]
  [%| ["interpolation type needs unsupported inference" ~]]
::
::  Whole-case coverage for a known union. When a pattern may cover only
::  part of a case, finite loobean refinements are tried below; other
::  partial coverage stays unsupported until the general pattern matrix.
+$  imatch  ?(%full %none %unknown)
++  union-pattern-items
  |=  [ps=(list pattern) t=itype]
  ^-  imatch
  ?~  ps  %unknown
  ?~  t.ps  (union-pattern i.ps t)
  =.  t  ?:(?=(%face -.t) body.t t)
  ?.  ?=(%cell -.t)
    ?:  |(?=(%atom -.t) ?=(%any-atom -.t) ?=(%flag -.t) ?=(%const -.t))  %none
    %unknown
  =/  a=imatch  (union-pattern i.ps hed.t)
  =/  b=imatch  $(ps t.ps, t tal.t)
  ?:  |(=(%none a) =(%none b))  %none
  ?:(&(=(%full a) =(%full b)) %full %unknown)
::
++  union-pattern
  |=  [p=pattern t=itype]
  ^-  imatch
  =.  t  ?:(?=(%face -.t) body.t t)
  ?-  -.p
    %any   %full
    %bind  %full
    %lit
      ?:  ?=(%const -.t)  ?:(=(val.literal.t val.lit.p) %full %none)
      ?:  ?=(%cell -.t)  %none
      ?:  ?=(%flag -.t)
        ?:(|(=(0 val.lit.p) =(1 val.lit.p)) %unknown %none)
      %unknown
    %str  ?:(?=(%cell -.t) %none %unknown)
    %cell  (union-pattern-items items.p t)
  ==
::
++  union-pattern-has-bind
  |=  p=pattern
  ^-  ?
  ?:  ?=(%bind -.p)  &
  ?.  ?=(%cell -.p)  |
  (lien items.p union-pattern-has-bind)
::
++  union-pattern-bind-items
  |=  [ps=(list pattern) t=itype env=ienv globals=(list term)]
  ^-  (unit ienv)
  ?~  ps  ~
  ?~  t.ps  (union-pattern-bind i.ps t env globals)
  =.  t  ?:(?=(%face -.t) body.t t)
  ?.  ?=(%cell -.t)  ~
  =/  first=(unit ienv)  (union-pattern-bind i.ps hed.t env globals)
  ?~  first  ~
  $(ps t.ps, t tal.t, env u.first)
::
++  union-pattern-bind
  |=  [p=pattern t=itype env=ienv globals=(list term)]
  ^-  (unit ienv)
  =.  t  ?:(?=(%face -.t) body.t t)
  ?:  ?=(%bind -.p)
    ?:  |(=(name.p %proj) ?=(^ (ienv-lookup name.p env)) (lien globals |=(n=term =(n name.p))))  ~
    `[[name.p [t ~]] env]
  ?:  ?=(%cell -.p)  (union-pattern-bind-items items.p t env globals)
  `env
::
::  Split loobean fields into finite refinements for partial patterns.
::  Keep original cases for binder types and preserve whole-case matching
::  before trying refinements. Cap products at 64; unknown, empty or opaque
::  shapes stay unsupported rather than implying complete pattern checking.
+$  ifinite  [origin=@ud base=itype part=itype]
++  finite-product
  |=  [hs=(list itype) ts=(list itype) out=(list itype)]
  ^-  (list itype)
  ?~  hs  out
  =/  rows=(list itype)  (turn ts |=(t=itype [%cell i.hs t]))
  $(hs t.hs, out (weld rows out))
::
++  finite-type
  |=  t=itype
  ^-  (unit (list itype))
  ?-  -.t
    %flag
      `~[[%const [%loobean %f 0 '%.y']] [%const [%loobean %f 1 '%.n']]]
    %face
      =/  body=(unit (list itype))  $(t body.t)
      ?~  body  ~
      `(turn u.body |=(x=itype [%face name.t x]))
    %cell
      =/  hed=(unit (list itype))  $(t hed.t)
      ?~  hed  ~
      =/  tal=(unit (list itype))  $(t tal.t)
      ?~  tal  ~
      ?:  (gth (mul (lent u.hed) (lent u.tal)) 64)  ~
      `(finite-product u.hed u.tal ~)
    *  `~[t]
  ==
::
++  finite-cases
  |=  [xs=(list itype) out=(list ifinite) origin=@ud]
  ^-  (unit (list ifinite))
  ?~  xs  `out
  =/  parts=(unit (list itype))  (finite-type i.xs)
  ?~  parts  ~
  ?:  (gth (add (lent out) (lent u.parts)) 64)  ~
  =/  rows=(list ifinite)  (turn u.parts |=(t=itype [origin i.xs t]))
  $(xs t.xs, out (weld out rows), origin +(origin))
::
++  infer-known-union-whole
  |=  [e=expr env=ienv subject=iresult]
  ^-  (unit iresult)
  ?>  ?=(%branch -.e)
  ?:  ?=(%| -.subject)  `subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  ?=(%union -.typ)  `[%| ["branch is not supported by partial inference" ~]]
  =/  cases=(list itype)  cases.typ
  =/  remaining=(list itype)  cases
  =/  arms=(list arm)  arms.e
  =/  st=istate  state.p.subject
  =/  answer=(unit itype)  ~
  |-
  ?~  arms
    ?^  remaining
      `[%| ["missing union case {(show-itype i.remaining sub.st)}" ~]]
    ?~  answer  `[%| ["empty union branch is not supported by partial inference" ~]]
    `[%& u.answer st]
  =/  a=arm  i.arms
  ?:  (lien remaining |=(c=itype =(%unknown (union-pattern pat.a c))))
    ~
  =/  matching=(list itype)  (skim remaining |=(c=itype =(%full (union-pattern pat.a c))))
  ?~  matching
    ?:  (lien cases |=(c=itype =(%full (union-pattern pat.a c))))
      `[%| ["branch arm is covered by earlier arms" ~[[at.pat.a "covered arm"]]]]
    `[%| ["union pattern is not supported by partial inference" ~]]
  ?:  &(?=(^ t.matching) (union-pattern-has-bind pat.a))
    `[%| ["a union pattern binding several cases is not supported by partial inference" ~]]
  =/  bound=(unit ienv)  (union-pattern-bind pat.a i.matching env globals.st)
  ?~  bound  `[%| ["pattern binder shadows a name" ~]]
  =/  body=iresult  (infer-fragment val.a u.bound st)
  ?:  ?=(%| -.body)  `body
  =/  result=itype  (itype-normalize typ.p.body sub.state.p.body)
  =/  mismatch=?  ?~(answer | !=((itype-normalize u.answer sub.state.p.body) result))
  ?:  mismatch  `[%| ["union branch result matching needs unsupported inference" ~]]
  $(arms t.arms, remaining (skim remaining |=(c=itype !=(%full (union-pattern pat.a c)))), st state.p.body, answer `result)
::
++  infer-known-union-context-whole
  |=  [e=expr expected=itype env=ienv subject=iresult context=span]
  ^-  (unit iresult)
  ?>  ?=(%branch -.e)
  ?:  ?=(%| -.subject)  `subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  ?=(%union -.typ)  `[%| ["branch is not supported by partial inference" ~]]
  =/  cases=(list itype)  cases.typ
  =/  remaining=(list itype)  cases
  =/  arms=(list arm)  arms.e
  =/  st=istate  state.p.subject
  =/  answer=(unit itype)  ~
  |-
  ?~  arms
    ?^  remaining
      `[%| ["missing union case {(show-itype i.remaining sub.st)}" ~]]
    ?~  answer  `[%| ["empty union branch is not supported by partial inference" ~]]
    `[%& expected st]
  =/  a=arm  i.arms
  ?:  (lien remaining |=(c=itype =(%unknown (union-pattern pat.a c))))
    ~
  =/  matching=(list itype)  (skim remaining |=(c=itype =(%full (union-pattern pat.a c))))
  ?~  matching
    ?:  (lien cases |=(c=itype =(%full (union-pattern pat.a c))))
      `[%| ["branch arm is covered by earlier arms" ~[[at.pat.a "covered arm"]]]]
    `[%| ["union pattern is not supported by partial inference" ~]]
  ?:  &(?=(^ t.matching) (union-pattern-has-bind pat.a))
    `[%| ["a union pattern binding several cases is not supported by partial inference" ~]]
  =/  bound=(unit ienv)  (union-pattern-bind pat.a i.matching env globals.st)
  ?~  bound  `[%| ["pattern binder shadows a name" ~]]
  =/  body=iresult  (infer-call-context-arg val.a expected u.bound st context)
  ?:  ?=(%| -.body)  `body
  =/  fit=ifit  (itype-fit typ.p.body expected sub.state.p.body next.state.p.body)
  ?:  ?=(%unknown -.fit)  `[%| ["union branch result constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    =/  missing=(unit idiag)  (missing-union-tag val.a expected sub.state.p.body context)
    ?^  missing  `[%| u.missing]
    =/  nested=(unit idiag)  (nested-missing-tag val.a typ.p.body expected sub.state.p.body next.state.p.body context)
    ?^  nested  `[%| u.nested]
    `[%| ["union branch arm does not fit its expected type" ~[[context "expected type"] [(span-of val.a) "branch arm"]]]]
  ?:  (itype-has-tag (itype-normalize expected sub.fit))
    `[%| ["union branch result needs context in partial inference" ~]]
  $(arms t.arms, remaining (skim remaining |=(c=itype !=(%full (union-pattern pat.a c)))), st state.p.body(sub sub.fit, next next.fit), answer `expected)
::
++  infer-known-union-finite
  |=  [e=expr env=ienv subject=iresult expected=(unit [typ=itype context=span])]
  ^-  iresult
  ?>  ?=(%branch -.e)
  ?:  ?=(%| -.subject)  subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  ?=(%union -.typ)  [%| ["branch is not supported by partial inference" ~]]
  =/  expanded=(unit (list ifinite))  (finite-cases cases.typ ~ 0)
  ?~  expanded  [%| ["union pattern expansion needs unsupported inference" ~]]
  =/  cases=(list ifinite)  u.expanded
  =/  remaining=(list ifinite)  cases
  =/  arms=(list arm)  arms.e
  =/  st=istate  state.p.subject
  =/  answer=(unit itype)  ~
  |-
  ?~  arms
    ?^  remaining
      [%| ["missing union case {(show-itype part.i.remaining sub.st)}" ~]]
    ?~  answer  [%| ["empty union branch is not supported by partial inference" ~]]
    ?~  expected  [%& u.answer st]
    [%& typ.u.expected st]
  =/  a=arm  i.arms
  ?:  (lien remaining |=(c=ifinite =(%unknown (union-pattern pat.a part.c))))
    [%| ["partial union pattern is not supported by partial inference" ~]]
  =/  matching=(list ifinite)  (skim remaining |=(c=ifinite =(%full (union-pattern pat.a part.c))))
  ?~  matching
    ?:  (lien cases |=(c=ifinite =(%full (union-pattern pat.a part.c))))
      [%| ["branch arm is covered by earlier arms" ~[[at.pat.a "covered arm"]]]]
    [%| ["union pattern is not supported by partial inference" ~]]
  ?:  &((union-pattern-has-bind pat.a) (lien t.matching |=(c=ifinite !=(origin.c origin.i.matching))))
    [%| ["a union pattern binding several cases is not supported by partial inference" ~]]
  =/  bound=(unit ienv)  (union-pattern-bind pat.a base.i.matching env globals.st)
  ?~  bound  [%| ["pattern binder shadows a name" ~]]
  =/  body=iresult
    ?~  expected  (infer-fragment val.a u.bound st)
    (infer-call-context-arg val.a typ.u.expected u.bound st context.u.expected)
  ?:  ?=(%| -.body)  body
  ?^  expected
    =/  fit=ifit  (itype-fit typ.p.body typ.u.expected sub.state.p.body next.state.p.body)
    ?:  ?=(%unknown -.fit)  [%| ["union branch result constraint is not supported by partial inference" ~]]
    ?:  ?=(%bad -.fit)
      =/  missing=(unit idiag)  (missing-union-tag val.a typ.u.expected sub.state.p.body context.u.expected)
      ?^  missing  [%| u.missing]
      =/  nested=(unit idiag)  (nested-missing-tag val.a typ.p.body typ.u.expected sub.state.p.body next.state.p.body context.u.expected)
      ?^  nested  [%| u.nested]
      [%| ["union branch arm does not fit its expected type" ~[[context.u.expected "expected type"] [(span-of val.a) "branch arm"]]]]
    ?:  (itype-has-tag (itype-normalize typ.u.expected sub.fit))
      [%| ["union branch result needs context in partial inference" ~]]
    $(arms t.arms, remaining (skim remaining |=(c=ifinite !=(%full (union-pattern pat.a part.c)))), st state.p.body(sub sub.fit, next next.fit), answer `typ.u.expected)
  =/  result=itype  (itype-normalize typ.p.body sub.state.p.body)
  =/  mismatch=?  ?~(answer | !=((itype-normalize u.answer sub.state.p.body) result))
  ?:  mismatch  [%| ["union branch result matching needs unsupported inference" ~]]
  $(arms t.arms, remaining (skim remaining |=(c=ifinite !=(%full (union-pattern pat.a part.c)))), st state.p.body, answer `result)
::
::  Prove a one-arm record pattern covers a known, non-union subject.
::  Variable or partial matches stay unsupported; binding uses the same
::  scope and original payload types as the existing union matcher.
++  single-structured-pattern
  |=  e=expr
  ^-  ?
  ?.  ?=(%branch -.e)  |
  ?~  arms.e  |
  ?^  t.arms.e  |
  =/  p=pattern  pat.i.arms.e
  ?.  ?=(%cell -.p)  |
  !(levy items.p |=(x=pattern ?=(%bind -.x)))
::
++  infer-single-case-branch
  |=  [e=expr env=ienv state=istate expected=(unit [typ=itype context=span])]
  ^-  iresult
  ?>  (single-structured-pattern e)
  ?>  ?=(%branch -.e)
  ?>  ?=(^ arms.e)
  =/  a=arm  i.arms.e
  =/  subject=iresult  (infer-fragment subject.e env state)
  ?:  ?=(%| -.subject)  subject
  =/  st=istate  state.p.subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.st)
  ?:  ?=(%union -.typ)  [%| ["single-case pattern needs unsupported inference" ~]]
  ?.  =(%full (union-pattern pat.a typ))
    [%| ["single-case pattern needs unsupported inference" ~]]
  =/  bound=(unit ienv)  (union-pattern-bind pat.a typ env globals.st)
  ?~  bound  [%| ["pattern binder shadows a name" ~]]
  ?~  expected  (infer-fragment val.a u.bound st)
  =/  body=iresult  (infer-call-context-arg val.a typ.u.expected u.bound st context.u.expected)
  ?:  ?=(%| -.body)  body
  =/  fit=ifit  (itype-fit typ.p.body typ.u.expected sub.state.p.body next.state.p.body)
  ?:  ?=(%unknown -.fit)  [%| ["single-case branch result constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    =/  missing=(unit idiag)  (missing-union-tag val.a typ.u.expected sub.state.p.body context.u.expected)
    ?^  missing  [%| u.missing]
    =/  nested=(unit idiag)  (nested-missing-tag val.a typ.p.body typ.u.expected sub.state.p.body next.state.p.body context.u.expected)
    ?^  nested  [%| u.nested]
    [%| ["single-case branch arm does not fit its expected type" ~[[context.u.expected "expected type"] [(span-of val.a) "branch arm"]]]]
  ?:  (itype-has-tag (itype-normalize typ.u.expected sub.fit))
    [%| ["single-case branch result needs context in partial inference" ~]]
  [%& typ.u.expected state.p.body(sub sub.fit, next next.fit)]
::
::  This view is used only by pattern analysis, never exported or bound as
::  the subject. Only null plus a two-binder/wildcard cell is supported; its
::  tail keeps the original recursive type. Other patterns fail closed.
++  jrec-match-view
  |=  [e=expr subject=iresult]
  ^-  iresult
  ?:  ?=(%| -.subject)  subject
  ?.  ?=(%branch -.e)  subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  ?=(%jrec -.typ)  subject
  ?~  arms.e  subject
  ?~  t.arms.e  subject
  ?^  t.t.arms.e  subject
  =/  x=pattern  pat.i.arms.e
  =/  y=pattern  pat.i.t.arms.e
  =/  empty=?  &(?=(%lit -.x) =(%null form.lit.x))
  =/  full=pattern  ?:(empty y x)
  ?.  |(empty &(?=(%lit -.y) =(%null form.lit.y)))  subject
  ?.  ?=(%cell -.full)  subject
  ?~  items.full  subject
  ?~  t.items.full  subject
  ?^  t.t.items.full  subject
  ?.  |(?=(%bind -.i.items.full) ?=(%any -.i.items.full))  subject
  ?.  |(?=(%bind -.i.t.items.full) ?=(%any -.i.t.items.full))  subject
  ?:  =(0 jrec-fuel.state.p.subject)
    [%| ["recursive mold unfolding needs unsupported inference" ~]]
  =/  nil=itype  [%const [%null %n 0 '~']]
  =/  cell=itype  [%cell [%face head.typ [%atom aura.typ]] [%face tail.typ typ]]
  [%& [%union ~[nil cell] ~ ~ ~] state.p.subject(jrec-fuel (dec jrec-fuel.state.p.subject))]
::
::  A bounded source-proven tree match permits flat tag patterns and
::  nonbinding catch-alls. Whole-case binders cannot consume the temporary
::  structural view. Pattern count and field arity are checked first.
++  grec-simple-pattern
  |=  [pat=pattern view=itype]
  ^-  ?
  ?.  ?=(%cell -.pat)  |
  ?~  items.pat  |
  =/  first=pattern  i.items.pat
  ?.  ?=(%lit -.first)  |
  ?.  =(%term form.lit.first)  |
  =/  chosen=(unit itype)  (contextual-tagged-case view val.lit.first ~)
  ?~  chosen  |
  ?>  ?=(%cell -.u.chosen)
  =/  rest=(list pattern)  t.items.pat
  =/  arity=?  ?:(?=(%cell -.tal.u.chosen) ?=([* [* ~]] rest) ?=([* ~] rest))
  ?.  arity  |
  (levy rest |=(p=pattern |(?=(%bind -.p) ?=(%any -.p))))
::
::  A catch-all with no binder is safe even when it covers both cases.
::  A bound whole case still declines to avoid exporting the analysis view.
++  grec-patterns-eligible
  |=  [arms=(list arm) view=itype left=@ud]
  ^-  ?
  ?~  arms  &
  ?:  =(0 left)  |
  =/  pat=pattern  pat.i.arms
  ?.  |(?=(%any -.pat) (grec-simple-pattern pat view))  |
  $(arms t.arms, left (dec left))
++  grec-match-view
  |=  [e=expr subject=iresult]
  ^-  iresult
  ?:  ?=(%| -.subject)  subject
  ?.  ?=(%branch -.e)  subject
  ?.  (grec-direct-context typ.p.subject sub.state.p.subject)  subject
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  ?=(%grec -.typ)  subject
  ?~  arms.e  subject
  =/  view=(unit [view=itype left=@ud])  (grec-unfold-view typ jrec-fuel.state.p.subject)
  ?~  view  [%| ["recursive mold unfolding needs unsupported inference" ~]]
  ?.  (grec-patterns-eligible arms.e view.u.view 128)  subject
  [%& view.u.view state.p.subject(jrec-fuel left.u.view)]
::
::  A single-arm diagnostic only probes a direct, source-typed in-scope wing;
::  other subjects retain the prior single-pattern inference path.
++  grec-single-wing-subject
  |=  [e=expr env=ienv state=istate]
  ^-  (unit iresult)
  ?.  ?=(%wing -.e)  ~
  ?.  ?=([@ ~] names.e)  ~
  =/  scheme=(unit ischeme)  (ienv-lookup i.names.e env)
  ?~  scheme  ~
  ?.  (grec-direct-context typ.u.scheme sub.state)  ~
  `(infer-fragment e env state)
::
++  infer-known-union-branch-subject
  |=  [e=expr env=ienv subject=iresult]
  ^-  iresult
  =.  subject  (grec-match-view e subject)
  =.  subject  (jrec-match-view e subject)
  =/  whole=(unit iresult)  (infer-known-union-whole e env subject)
  ?~  whole  (infer-known-union-finite e env subject ~)
  u.whole
::
++  infer-known-union-branch
  |=  [e=expr env=ienv state=istate]
  ^-  iresult
  ?>  ?=(%branch -.e)
  (infer-known-union-branch-subject e env (infer-fragment subject.e env state))
::
++  infer-known-union-context-subject
  |=  [e=expr expected=itype env=ienv subject=iresult context=span]
  ^-  iresult
  =.  subject  (grec-match-view e subject)
  =.  subject  (jrec-match-view e subject)
  =/  whole=(unit iresult)  (infer-known-union-context-whole e expected env subject context)
  ?~  whole  (infer-known-union-finite e env subject `[expected context])
  u.whole
::
::  Limit speculative subject inference to wings and shallow calls;
::  grouping is peeled linearly and cannot introduce a nested branch.
++  simple-union-subject-arg
  |=  e=expr
  ^-  ?
  ?-  -.e
    %wing  &
    %lit   &
    %str   !(lien pieces.e |=(p=piece ?=(%expr -.p)))
    *      |
  ==
::
++  safe-union-subject
  |=  e=expr
  ^-  ?
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  ?=(%wing -.e)  &
  ?.  ?=(%call -.e)  |
  ?.  ?=(%wing -.head.e)  |
  (levy args.e simple-union-subject-arg)
::
++  duplicate-loobean-arms
  |=  e=expr
  ^-  ?
  ?.  ?=(%branch -.e)  |
  ?~  arms.e  |
  ?~  t.arms.e  |
  ?^  t.t.arms.e  |
  =/  x=pattern  pat.i.arms.e
  =/  y=pattern  pat.i.t.arms.e
  ?.  &(?=(%lit -.x) ?=(%lit -.y))  |
  ?.  &(=(%loobean form.lit.x) =(%loobean form.lit.y))  |
  =(val.lit.x val.lit.y)
::
++  union-subject-call
  |=  e=expr
  ^-  ?
  ?:  ?=(%group -.e)  $(e inner.e)
  ?=(%call -.e)
::
++  known-union-subject
  |=  [e=expr env=ienv state=istate]
  ^-  (unit iresult)
  ?.  (safe-union-subject e)  ~
  =/  subject=iresult  (infer-fragment e env state)
  ?:  ?=(%| -.subject)  ?:((union-subject-call e) `subject ~)
  =/  typ=itype  (itype-normalize typ.p.subject sub.state.p.subject)
  ?.  |(?=(%union -.typ) ?=(%jrec -.typ) &(?=(%grec -.typ) (grec-direct-context typ.p.subject sub.state.p.subject)))  ~
  `subject
::
::
::  Infer changes only against a fully known record spine. Retain the
::  target type; unknown spines and repeated edits remain unsupported.
++  change-spine-known
  |=  [t=itype sub=isub]
  ^-  ?
  =.  t  (itype-walk t sub)
  ?:  ?=(%face -.t)  &
  ?.  ?=(%cell -.t)  |
  =/  first=itype  (itype-walk hed.t sub)
  ?.  ?=(%face -.first)  |
  $(t tal.t)
::
++  infer-change-edits
  |=  [edits=(list edit) target=itype env=ienv state=istate seen=(list term)]
  ^-  iresult
  ?~  edits  [%& target state]
  =/  entry=edit  i.edits
  ?:  (lien seen |=(name=term =(name name.entry)))
    [%| ["repeated change fields are not supported by partial inference" ~]]
  ?.  (change-spine-known target sub.state)
    [%| ["change target needs a known record in partial inference" ~]]
  =/  found=(list itype)  (record-fields-named name.entry target sub.state)
  ?~  found
    [%| ["record has no field `{(trip name.entry)}`" ~[[at.entry "unknown field"]]]]
  ?^  t.found  [%| ["change field is ambiguous in partial inference" ~]]
  =/  expected=itype  i.found
  =/  value=iresult  (infer-call-context-arg val.entry expected env state at.entry)
  ?:  ?=(%| -.value)  value
  =/  fit=ifit  (itype-fit typ.p.value expected sub.state.p.value next.state.p.value)
  ?:  ?=(%unknown -.fit)  [%| ["change field constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    [%| ["change field and replacement do not unify" ~[[at.entry (site-type-note "expected replacement" expected sub.state.p.value)] [(span-of val.entry) (site-type-note "replacement" typ.p.value sub.state.p.value)]]]]
  $(edits t.edits, state state.p.value(sub sub.fit, next next.fit), seen [name.entry seen])
::
::  Backtick constructs the canonical prelude unit, after checking its
::  prepared template has the standard null and [~ u=A] cases.
++  standard-unit-template
  |=  [template=ischeme at=path]
  ^-  ?
  ?.  =(at /lib/jibb/prelude/jibb)  |
  ?~  vars.template  |
  ?^  t.vars.template  |
  =/  v=@ud  i.vars.template
  =/  nil=itype  [%const [%null %n 0 '~']]
  =/  expected=itype
    [%union ~[nil [%cell nil [%face %u [%var v]]]] `[at %unit] `%unit ~[[%var v]]]
  =(typ.template expected)
::
::  A named missing-case diagnostic needs more than a failed fit: a case
::  with that tag but the wrong payload is not a missing case. Unknown
::  shapes and atom types that accept terms keep the proof conservative.
+$  itag-presence  ?(%yes %no %maybe)
++  tag-presence-cases
  |=  [cases=(list itype) value=@ sub=isub]
  ^-  itag-presence
  ?~  cases  %no
  =/  first=itag-presence  (tag-presence i.cases value sub)
  ?:  =(%yes first)  %yes
  =/  rest=itag-presence  $(cases t.cases)
  ?:  =(%yes rest)  %yes
  ?:  |(=(%maybe first) =(%maybe rest))  %maybe
  %no
::
++  tag-presence
  |=  [t=itype value=@ sub=isub]
  ^-  itag-presence
  =.  t  (itype-walk t sub)
  ?-  -.t
    %const  ?:(=(value val.literal.t) %yes %no)
    %flag  ?:(|(=(value 0) =(value 1)) %yes %no)
    %atom  ?:(|(=(%tas aura.t) =(%ta aura.t)) %maybe %no)
    %face  $(t body.t)
    %cell
      =/  first=itag-presence  $(t hed.t)
      ?:  =(%yes first)  %yes
      =/  rest=itag-presence  $(t tal.t)
      ?:  =(%yes rest)  %yes
      ?:  |(=(%maybe first) =(%maybe rest))  %maybe
      %no
    %union  (tag-presence-cases cases.t value sub)
    *  %maybe
  ==
::
++  missing-union-tag
  |=  [e=expr expected=itype sub=isub context=span]
  ^-  (unit idiag)
  ?.  ?=(%lit -.e)  ~
  ?.  =(%term form.lit.e)  ~
  =.  expected  (itype-walk expected sub)
  |-
  ?:  ?=(%face -.expected)  $(expected (itype-walk body.expected sub))
  ?.  ?=(%union -.expected)  ~
  ?.  =(%no (tag-presence-cases cases.expected val.lit.e sub))  ~
  =/  label=tape
    ?~  label.expected  "union {(show-itype expected sub)}"
    (show-itype expected sub)
  `["{label} has no case `{(trip txt.lit.e)}`" ~[[context "expected union"] [(span-of e) "tag"]]]
::
::  Locate a missing tag inside a syntactic tuple only by replaying the
::  directional fit in source order. Uncertain or earlier failures stop
::  the walk, preserving the generic diagnostic rather than guessing.
++  nested-missing-tag
  |=  [e=expr actual=itype expected=itype sub=isub next=@ud context=span]
  ^-  (unit idiag)
  =/  original=[left=itype right=itype]  [actual expected]
  ?:  |(?=(%var -.left.original) ?=(%avar -.left.original) ?=(%rvar -.left.original) |(?=(%nvar -.left.original) ?=(%rnvar -.left.original)) ?=(%var -.right.original) ?=(%avar -.right.original) ?=(%rvar -.right.original) |(?=(%nvar -.right.original) ?=(%rnvar -.right.original)))  ~
  =/  fit=ifit  (itype-fit actual expected sub next)
  ?.  ?=(%bad -.fit)  ~
  =.  actual  (itype-walk actual sub)
  =.  expected  (itype-walk expected sub)
  ?:  &(?=(%face -.actual) ?=(%face -.expected))
    ?.  =(name.actual name.expected)  ~
    $(actual body.actual, expected body.expected)
  ?:  ?=(%face -.actual)  $(actual body.actual)
  ?:  ?=(%face -.expected)  $(expected body.expected)
  =/  direct=(unit idiag)  (missing-union-tag e expected sub context)
  ?^  direct  direct
  ?.  ?=(%tuple -.e)  ~
  (nested-missing-items items.e actual expected sub next context)
::
++  nested-missing-items
  |=  [items=(list item) actual=itype expected=itype sub=isub next=@ud context=span]
  ^-  (unit idiag)
  ?~  items  ~
  ?~  t.items  (nested-missing-tag val.i.items actual expected sub next context)
  =/  original=[left=itype right=itype]  [actual expected]
  ?:  |(?=(%var -.left.original) ?=(%avar -.left.original) ?=(%rvar -.left.original) |(?=(%nvar -.left.original) ?=(%rnvar -.left.original)) ?=(%var -.right.original) ?=(%avar -.right.original) ?=(%rvar -.right.original) |(?=(%nvar -.right.original) ?=(%rnvar -.right.original)))  ~
  =.  actual  (itype-walk actual sub)
  =.  expected  (itype-walk expected sub)
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
  =/  first=ifit  (itype-fit hed.actual hed.expected sub next)
  ?:  ?=(%bad -.first)
    (nested-missing-tag val.i.items hed.actual hed.expected sub next context)
  ?.  ?=(%ok -.first)  ~
  $(items t.items, actual tal.actual, expected tal.expected, sub sub.first, next next.first)
::
::  A term-headed pair is the same noun as a two-item cell. Preserve the
::  whole pair span for the synthetic head and the value's own span for
::  the payload; unresolved term constraints follow ordinary cell inference.
++  pair-as-cell
  |=  e=expr
  ^-  expr
  ?>  ?=(%pair -.e)
  =/  head=expr  [%lit at.e [%term %tas tag.e (crip ['%' (trip tag.e)])]]
  [%tuple at.e ~[[at.e ~ head] [(span-of val.e) ~ val.e]]]
::
::  A segment costs one shared step; dynamic segments are not handled yet.
++  qath-static-fuel
  |=  [segs=(list qseg) fuel=@ud]
  ^-  (unit @ud)
  ?~  segs  `fuel
  ?:  =(0 fuel)  ~
  ?.  ?=(%knot -.i.segs)  ~
  $(segs t.segs, fuel (dec fuel))
::
++  infer-fragment
  |=  [e=expr env=ienv state=istate]
  ^-  iresult
  ?-  -.e
    %pair  $(e (pair-as-cell e))
    %lit
      ?-  form.lit.e
        %number    ?:  =(%ud aura.lit.e)
                     [%& [%nvar next.state] state(next +(next.state))]
                   [%& [%atom aura.lit.e] state]
        %ship      [%& [%atom %p] state]
        %date      [%& [%atom %da] state]
        %duration  [%& [%atom %dr] state]
        %knot      [%& [%atom %ta] state]
        %loobean   [%& [%flag ~] state]
        %term      [%& [%tag next.state lit.e |] state(next +(next.state), tags [[next.state lit.e] tags.state])]
        %null      [%& [%tag next.state lit.e |] state(next +(next.state), tags [[next.state lit.e] tags.state])]
      ==
    %unit
      ?~  prelude.state  [%| ["unit construction needs the standard prelude in partial inference" ~]]
      =/  standard=(unit ischeme)  (find-jibb-mold %unit u.prelude.state)
      ?~  standard  [%| ["unit construction needs the standard prelude in partial inference" ~]]
      ?.  (standard-unit-template u.standard at.u.prelude.state)
        [%| ["unit construction needs the standard prelude in partial inference" ~]]
      =/  value=iresult  $(e val.e)
      ?:  ?=(%| -.value)  value
      =/  result=(unit itype)  (template-apply u.standard ~[typ.p.value])
      ?~  result  [%| ["unit construction is not supported by partial inference" ~]]
      [%& u.result state.p.value]
    %list
      ?~  prelude.state  [%| ["list literal needs the standard prelude in partial inference" ~]]
      ?.  =(at.u.prelude.state /lib/jibb/prelude/jibb)
        [%| ["list literal needs the standard prelude in partial inference" ~]]
      =/  standard=(unit ischeme)  (find-jibb-mold %list u.prelude.state)
      ?~  standard  [%| ["list literal needs the standard prelude in partial inference" ~]]
      ?.  =(u.standard [[%collection %list ~[[%var 0]]] ~[0]])
        [%| ["list literal needs the standard prelude in partial inference" ~]]
      =/  element=itype  [%var next.state]
      =/  result=iresult  (infer-open-list-items items.e element env state(next +(next.state)) at.e)
      ?:  ?=(%| -.result)  result
      [%& [%collection %list ~[element]] state.p.result]
    %str  (infer-string-pieces pieces.e env state)
    %qath
      ?~  prelude.state  [%| ["application path needs the standard prelude in partial inference" ~]]
      ?.  =(at.u.prelude.state /lib/jibb/prelude/jibb)
        [%| ["application path needs the standard prelude in partial inference" ~]]
      =/  standard=(unit ischeme)  (find-jibb-mold %qath u.prelude.state)
      ?~  standard  [%| ["application path needs the standard prelude in partial inference" ~]]
      ?.  ?=(~ vars.u.standard)  [%| ["application path mold needs unsupported inference" ~]]
      =/  typ=itype  typ.u.standard
      ?.  ?=(%jrec -.typ)  [%| ["application path mold needs unsupported inference" ~]]
      ?.  &(=(at.typ /lib/jibb/internal/jibb) =(%qath name.typ) =(%i head.typ) =(%ta aura.typ) =(%t tail.typ))
        [%| ["application path mold needs unsupported inference" ~]]
      ?:  =(0 jrec-fuel.state)  [%| ["recursive mold unfolding needs unsupported inference" ~]]
      =/  remain=(unit @ud)  (qath-static-fuel segs.e (dec jrec-fuel.state))
      ?~  remain  [%| ["application path segments need unsupported inference" ~]]
      [%& typ state(jrec-fuel u.remain)]
    %wing
      ?~  names.e  [%| ["empty wing" ~]]
      ?^  t.names.e
        ?^  t.t.names.e  (infer-field-wing names.e env state)
        =/  iface=(unit ifile)  (find-jibb-interface i.t.names.e jimports.state)
        ?~  iface  (infer-field-wing names.e env state)
        =/  member=(unit ischeme)  (ienv-lookup i.names.e values.u.iface)
        ?~  member  [%| ["module member is not available to partial inference" ~]]
        =.  typ.u.member  (itype-in-import typ.u.member u.iface i.t.names.e prelude.state)
        =/  instance=[typ=itype state=istate]  (instantiate-scheme u.member state)
        [%& typ.instance state.instance]
      =/  scheme=(unit ischeme)  (ienv-lookup i.names.e env)
      ?~  scheme
        ?~  prelude.state  [%| ["name is not available to partial inference" ~]]
        =/  prelude-entry=(unit ischeme)  (ienv-lookup i.names.e values.u.prelude.state)
        ?~  prelude-entry  [%| ["name is not available to partial inference" ~]]
        =/  inst=[typ=itype state=istate]  (instantiate-scheme u.prelude-entry state)
        [%& typ.inst state.inst]
      =/  instance=[typ=itype state=istate]  (instantiate-scheme u.scheme state)
      [%& typ.instance state.instance]
    %group  $(e inner.e)
    %change
      ?~  edits.e  [%| ["a change takes at least one field" ~[[at.e "empty change"]]]]
      =/  target=iresult  $(e [%wing at.e target.e])
      ?:  ?=(%| -.target)  target
      (infer-change-edits edits.e typ.p.target env state.p.target ~)
    %ctor  [%& [%tag next.state tag.e &] state(next +(next.state), tags [[next.state tag.e] tags.state])]
    %trace
      =/  traced=iresult  $(e val.e)
      ?:  ?=(%| -.traced)  traced
      $(e then.e, state state.p.traced)
    %tuple  (infer-simple-items items.e env state)
    %body
      ?~  defs.e  $(e final.e)
      =/  local-names=(list term)  (global-value-names defs.e)
      ?.  (local-names-valid defs.e env state)
        [%| ["local definitions shadow a name" ~]]
      =/  local-molds=imolds  (collect-simple-molds defs.e)
      ?.  (local-mold-names-valid local-molds state)
        [%| ["local molds shadow a name" ~]]
      =/  local-state=istate
        state(globals (weld local-names globals.state), molds (weld local-molds molds.state))
      =/  mold-hole=(unit span)  (simple-local-mold-hole defs.e)
      ?^  mold-hole
        [%| ["type hole needs a determined type" ~[[u.mold-hole "unresolved type hole"]]]]
      ?.  (local-molds-supported local-molds local-state)
        [%| ["local molds need unsupported inference" ~]]
      =/  values=(list def)  (local-value-defs defs.e)
      =/  locals=ilocal-result  (infer-local-defs values env local-state)
      ?:  ?=(%| -.locals)  locals
      =/  result=iresult  $(e final.e, env env.p.locals, state state.p.locals)
      ?:  ?=(%| -.result)  result
      [%& typ.p.result state.p.result(globals globals.state, molds molds.state)]
    %branch
      ?~  arms.e  [%| ["branch is not supported by partial inference" ~]]
      ?~  t.arms.e
        =/  single=(unit iresult)  (grec-single-wing-subject subject.e env state)
        ?^  single  (infer-known-union-branch-subject e env u.single)
        ?:  (single-structured-pattern e)  (infer-single-case-branch e env state ~)
        (infer-cell-branch e env state ~)
      ?^  t.t.arms.e  (infer-known-union-branch e env state)
      =/  known=(unit iresult)  (known-union-subject subject.e env state)
      ?:  &(?=(^ known) ?=(%| -.u.known) !(duplicate-loobean-arms e))  u.known
      ?:  &(?=(^ known) ?=(%& -.u.known) ?=(~ (unit-union-payload (itype-normalize typ.p.u.known sub.state.p.u.known))))
        (infer-known-union-branch-subject e env u.known)
      =/  x=arm  i.arms.e
      =/  y=arm  i.t.arms.e
      ?:  |((unit-empty-pattern pat.x) (unit-empty-pattern pat.y))
        (infer-unit-branch e env state ~)
      ?.  ?=(%lit -.pat.x)  (infer-known-union-branch e env state)
      ?.  ?=(%lit -.pat.y)  (infer-known-union-branch e env state)
      ?.  &(=(%loobean form.lit.pat.x) =(%loobean form.lit.pat.y))
        (infer-known-union-branch e env state)
      ?:  &(?=(^ known) ?=(%& -.u.known))  (infer-known-union-branch-subject e env u.known)
      ?:  =(val.lit.pat.x val.lit.pat.y)
        [%| ["branch does not cover both loobeans" ~]]
      =/  subject=iresult  $(e subject.e)
      ?:  ?=(%| -.subject)  subject
      =/  subject-type=itype  (itype-normalize typ.p.subject sub.state.p.subject)
      ?:  ?=(%union -.subject-type)
        [%| ["union-pattern branch subject is not supported by partial inference" ~]]
      =/  su=(unit isub)  (itype-unify typ.p.subject [%flag ~] sub.state.p.subject)
      ?~  su  [%| ["loobean branch subject does not unify with ?" ~]]
      =/  left=iresult  $(e val.x, state state.p.subject(sub u.su))
      ?:  ?=(%| -.left)  left
      =/  right=iresult  $(e val.y, state state.p.left)
      ?:  ?=(%| -.right)  right
      =/  ltype=itype  (itype-normalize typ.p.left sub.state.p.right)
      =/  rtype=itype  (itype-normalize typ.p.right sub.state.p.right)
      ?:  &(!=(ltype rtype) |(?=(^ (itype-vars ltype)) ?=(^ (itype-vars rtype))) |((itype-has-fixed-atom ltype) (itype-has-fixed-atom rtype)))
        [%| ["branch widening is not supported by partial inference" ~]]
      =/  joined=(unit isub)  (itype-unify typ.p.left typ.p.right sub.state.p.right)
      ?~  joined
        ?:  |((itype-has-recursive ltype) (itype-has-recursive rtype))
          [%| ["recursive branch matching is not supported by partial inference" ~]]
        ?:  |((itype-has-tag ltype) (itype-has-tag rtype) (itype-has-union ltype) (itype-has-union rtype))
          [%| ["branch tag or union context is not supported by partial inference" ~]]
        =/  common=(unit itype)  (itype-concrete-join typ.p.left typ.p.right sub.state.p.right)
        ?^  common  [%& u.common state.p.right]
        ?:  |((itype-has-face typ.p.left sub.state.p.right) (itype-has-face typ.p.right sub.state.p.right))
          [%| ["record branch matching is not supported by partial inference" ~]]
        ?:  |((itype-has-any-atom typ.p.left sub.state.p.right) (itype-has-any-atom typ.p.right sub.state.p.right) (itype-family-related typ.p.left typ.p.right sub.state.p.right))
          [%| ["branch widening is not supported by partial inference" ~]]
        [%| ["branch arms have incompatible types" ~[[(span-of val.x) (site-type-note "first arm" typ.p.left sub.state.p.right)] [(span-of val.y) (site-type-note "second arm" typ.p.right sub.state.p.right)]]]]
      [%& typ.p.left state.p.right(sub u.joined)]
    %cast
      =/  target=(unit [typ=itype state=istate])  (infer-simple-shape shape.e state)
      ?~  target
        =/  diag=(unit idiag)  (nested-import-invalid shape.e state)
        ?^  diag  [%| u.diag]
        [%| ["cast mold is not supported by partial inference" ~]]
      =/  value=iresult
        (infer-call-context-arg val.e typ.u.target env state.u.target at.shape.e)
      ?:  ?=(%| -.value)  value
      =/  shape=(unit [source=iwfields target=iwfields])
        (width-shape typ.p.value typ.u.target sub.state.p.value)
      ?^  shape  [%| ["record width constraint needs unsupported inference" ~]]
      =/  fit=ifit  (itype-fit typ.p.value typ.u.target sub.state.p.value next.state.p.value)
      ?:  ?=(%unknown -.fit)  [%| ["cast constraint is not supported by partial inference" ~]]
      ?:  ?=(%bad -.fit)
        =/  missing=(unit idiag)  (missing-union-tag val.e typ.u.target sub.state.p.value at.shape.e)
        ?^  missing  [%| u.missing]
        =/  nested=(unit idiag)  (nested-missing-tag val.e typ.p.value typ.u.target sub.state.p.value next.state.p.value at.shape.e)
        ?^  nested  [%| u.nested]
        [%| ["cast mold and expression type do not unify" ~[[at.shape.e (site-type-note "cast mold" typ.u.target sub.state.p.value)] [(span-of val.e) (site-type-note "expression" typ.p.value sub.state.p.value)]]]]
      =/  merged=itype  (itype-merge-faces typ.p.value typ.u.target sub.fit)
      [%& merged state.p.value(sub sub.fit, next next.fit)]
    %crash  [%& [%var next.state] state(next +(next.state))]
    %gate
      =/  sam=isample-result  (infer-sample sample.e env state)
      ?:  ?=(%| -.sam)
        =/  diag=(unit idiag)  (sample-import-invalid sample.e env state)
        ?:  &(=(p.sam "sample mold is not supported by partial inference") ?=(^ diag))  [%| u.diag]
        [%| [p.sam ~]]
      =/  body=iresult  $(e body.e, env env.p.sam, state state.p.sam)
      ?:  ?=(%| -.body)  body
      [%& [%fn typ.p.sam typ.p.body] state.p.body]
    %gate-wide
      =/  sam=isample-result  (infer-sample sample.e env state)
      ?:  ?=(%| -.sam)
        =/  diag=(unit idiag)  (sample-import-invalid sample.e env state)
        ?:  &(=(p.sam "sample mold is not supported by partial inference") ?=(^ diag))  [%| u.diag]
        [%| [p.sam ~]]
      =/  body=iresult  $(e body.e, env env.p.sam, state state.p.sam)
      ?:  ?=(%| -.body)  body
      [%& [%fn typ.p.sam typ.p.body] state.p.body]
    %call
      ?~  args.e  [%| ["call has no argument" ~]]
      ?:  (explicit-proj-call e env state)
        [%| ["proj needs an expected record type" ~]]
      (infer-call-with-head e env state (infer-fragment head.e env state))
    *  [%| ["expression is not supported by partial inference" ~]]
  ==
::
::  Locate a definite failing argument after the complete sample fit has
::  failed. If an intermediate fit is uncertain, retain the whole argument
::  span rather than assigning blame to a particular argument.
::
::  Check a call using the head already inferred in this state.  Keeping
::  this shared avoids evaluating or instantiating a contextual head twice.
++  width-has-projections
  |=  ps=(list iwprojection)
  ^-  ?
  ?~  ps  |
  &
::
+$  iwidth-elaboration  [original=expr typ=itype sub=isub projections=(list iwprojection)]
++  infer-width-elaboration
  |=  [e=expr env=ienv state=istate]
  ^-  (each iwidth-elaboration idiag)
  =/  out=iresult  (infer-fragment e env state)
  ?:  ?=(%| -.out)  [%| p.out]
  [%& [e typ.p.out sub.state.p.out (flop projections.state.p.out)]]
::
::  Source-bound gate-layout evidence, confined to checked root gate
::  definitions and direct unshadowed prelude calls. The prepared prelude
::  interface and its retained source are trusted as a matching artifact.
::  Layouts identify sample binder faces; they do not change call arity or
::  authorize stripping nested value faces. Unknown origins use ordinary fit.
++  direct-written-gates
  |=  [ds=(list def) out=ivisited]
  ^-  ivisited
  ?~  ds  out
  ?:  ?=(%mold -.i.ds)  $(ds t.ds)
  ?.  |(?=(%gate -.val.i.ds) ?=(%gate-wide -.val.i.ds))  $(ds t.ds)
  $(ds t.ds, out (~(put by out) name.i.ds &))
++  direct-may-use-prelude
  |=  [ds=(list def) root=ivisited heads=ivisited]
  ^-  ?
  ?~  ds  |
  ?:  ?=(%mold -.i.ds)  $(ds t.ds)
  =/  refs=(list term)  (dependency-expr val.i.ds)
  =/  has-root=?  (lien refs |=(n=term ?=(^ (~(get by root) n))))
  =/  has-head=?  (lien refs |=(n=term ?=(^ (~(get by heads) n))))
  ?:  &(has-root has-head)  &
  $(ds t.ds)
++  direct-unique-names
  |=  [names=(list term) seen=ivisited]
  ^-  ?
  ?~  names  &
  ?:  ?=(^ (~(get by seen) i.names))  |
  $(names t.names, seen (~(put by seen) i.names &))
++  direct-prelude-evidence
  |=  [ds=(list def) prelude=(unit ifile)]
  ^-  (unit igate-prelude-evidence)
  ?~  prelude  ~
  ?~  source.u.prelude  ~
  =/  root=ivisited  (direct-written-gates ds ~)
  =/  names=(list term)  (turn values.u.prelude |=(e=[name=term scheme=ischeme] name.e))
  =/  heads=ivisited  (graph-nameset names ~)
  ?.  (direct-may-use-prelude ds root heads)  ~
  =/  parsed  (parse at.u.prelude u.source.u.prelude)
  ?:  ?=(%| -.parsed)  ~
  ?^  (duplicate-defs defs.p.parsed)  ~
  ?.  (direct-unique-names (global-value-names defs.p.parsed) ~)  ~
  =/  gates=(map term def)  (direct-checked-gates defs.p.parsed values.u.prelude)
  `[u.prelude gates]
++  direct-checked-gates
  |=  [ds=(list def) env=ienv]
  ^-  (map term def)
  =/  names=(list term)  (turn env |=(e=[name=term scheme=ischeme] name.e))
  =/  known=ivisited  (graph-nameset names ~)
  =/  out=(map term def)  ~
  |-
  ?~  ds  out
  =/  d=def  i.ds
  ?:  ?=(%mold -.d)  $(ds t.ds)
  ?.  ?=(^ (~(get by known) name.d))  $(ds t.ds)
  ?.  |(?=(%gate -.val.d) ?=(%gate-wide -.val.d))  $(ds t.ds)
  $(ds t.ds, out (~(put by out) name.d d))
++  direct-find-gate
  |=  [n=term ds=(list def)]
  ^-  (unit def)
  ?~  ds  ~
  ?:  &(?=(%value -.i.ds) =(n name.i.ds))  `i.ds
  $(ds t.ds)
++  direct-gate-sample
  |=  d=def
  ^-  (unit sample)
  ?.  ?=(%value -.d)  ~
  ?-  -.val.d
    %gate       `sample.val.d
    %gate-wide  `sample.val.d
    *           ~
  ==
++  direct-sample-name
  |=  sam=sample
  ^-  (unit term)
  ?-  -.sam
    %bind  `name.sam
    %face  `name.sam
    %pun   `name.sam
    *      ~
  ==
++  direct-field-name
  |=  f=field
  ^-  (unit term)
  ?-  -.f
    %face  `name.f
    %pun   `name.f
    *      ~
  ==
++  direct-slot-body
  |=  [typ=itype name=(unit term)]
  ^-  (unit itype)
  ?~  name  `typ
  ?.  ?=(%face -.typ)  ~
  ?.  =(name.typ u.name)  ~
  `body.typ
++  direct-invariant
  |=  [a=itype b=itype sub=isub next=@ud]
  ^-  ifit
  ?:  (itype-face-asym a b sub)  [%unknown ~]
  =/  forward=ifit  (itype-fit a b sub next)
  ?.  ?=(%ok -.forward)  [%unknown ~]
  ?:  (itype-face-asym a b sub.forward)  [%unknown ~]
  =/  reverse=ifit  (itype-fit b a sub.forward next.forward)
  ?.  ?=(%ok -.reverse)  [%unknown ~]
  reverse
++  direct-function-fit
  |=  [a=itype b=itype sam=sample sh=shape sub=isub next=@ud]
  ^-  ifit
  ?.  &(?=(%fn -.a) ?=(%fn -.b) ?=(%cell -.sam) ?=(%fn -.sh))  [%unknown ~]
  ?.  ?=(%cell -.sample.sh)  [%unknown ~]
  =/  as=(list sample)  items.sam
  =/  bs=(list field)  fields.sample.sh
  ?~  as  [%unknown ~]
  ?~  t.as  [%unknown ~]
  ?^  t.t.as  [%unknown ~]
  ?~  bs  [%unknown ~]
  ?~  t.bs  [%unknown ~]
  ?^  t.t.bs  [%unknown ~]
  ?.  &(?=(%cell -.sample.a) ?=(%cell -.sample.b))  [%unknown ~]
  =/  an=(unit term)  (direct-sample-name i.as)
  =/  bn=(unit term)  (direct-field-name i.bs)
  ?:  &(?=(^ an) ?=(^ bn) !=(u.an u.bn))  [%unknown ~]
  =/  x=(unit itype)  (direct-slot-body hed.sample.a an)
  =/  y=(unit itype)  (direct-slot-body hed.sample.b bn)
  ?~  x  [%unknown ~]
  ?~  y  [%unknown ~]
  =/  first=ifit  (direct-invariant u.x u.y sub next)
  ?.  ?=(%ok -.first)  [%unknown ~]
  =.  an  (direct-sample-name i.t.as)
  =.  bn  (direct-field-name i.t.bs)
  ?:  &(?=(^ an) ?=(^ bn) !=(u.an u.bn))  [%unknown ~]
  =/  x2=(unit itype)  (direct-slot-body tal.sample.a an)
  =/  y2=(unit itype)  (direct-slot-body tal.sample.b bn)
  ?~  x2  [%unknown ~]
  ?~  y2  [%unknown ~]
  =/  second=ifit  (direct-invariant u.x2 u.y2 sub.first next.first)
  ?.  ?=(%ok -.second)  [%unknown ~]
  (direct-invariant product.a product.b sub.second next.second)
::  This is a tentative proof: its caller must require closed call samples
::  and repeat every positional check under the stable final substitution.
++  direct-positional-fit
  |=  [args=(list expr) slots=(list sample) actual=itype expected=itype env=ienv state=istate sub=isub next=@ud]
  ^-  ifit
  ?~  args  [%unknown ~]
  ?~  slots  [%unknown ~]
  =/  last=?  ?=(~ t.args)
  ?:  !=(last ?=(~ t.slots))  [%unknown ~]
  =/  split=(unit [left=itype right=itype])
    ?:  last  `[actual expected]
    ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
    `[hed.actual hed.expected]
  ?~  split  [%unknown ~]
  =/  x=itype  left.u.split
  =/  y=itype  right.u.split
  =/  expected-name=(unit term)  (direct-sample-name i.slots)
  =/  expected-body=(unit itype)  (direct-slot-body y expected-name)
  ?~  expected-body  [%unknown ~]
  =.  y  u.expected-body
  =/  fit=ifit  (itype-fit x y sub next)
  =/  accepted=?  &(?=(%ok -.fit) !(itype-positional-slot-face-asym x y sub.fit))
  =/  result=(unit ifit)
    ?:  accepted  `fit
    ?.  &(?=(%face -.i.slots) ?=(%fn -.shape.i.slots))  ~
    ?.  ?=(%wing -.i.args)  ~
    ?.  ?=([@ ~] names.i.args)  ~
    ?.  (unique-value-name i.names.i.args globals.state)  ~
    =/  source=(unit def)  (~(get by gate-defs.state) i.names.i.args)
    ?~  source  ~
    =/  sample=(unit sample)  (direct-gate-sample u.source)
    ?~  sample  ~
    =/  trial=ifit  (direct-function-fit x y u.sample shape.i.slots sub next)
    ?.  ?=(%ok -.trial)  ~
    `trial
  ?~  result  [%unknown ~]
  =.  fit  u.result
  ?:  last  fit
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  [%unknown ~]
  ?.  ?=(%ok -.fit)  [%unknown ~]
  $(args t.args, slots t.slots, actual tal.actual, expected tal.expected, sub sub.fit, next next.fit)
++  direct-any-gate-arg
  |=  [args=(list expr) defs=(map term def)]
  ^-  ?
  ?~  args  |
  =/  found=?
    ?.  ?=(%wing -.i.args)  |
    ?.  ?=([@ ~] names.i.args)  |
    ?=(^ (~(get by defs) i.names.i.args))
  ?:  found  &
  $(args t.args)
++  direct-gate-call-fit
  |=  [e=expr actual=itype expected=itype env=ienv state=istate]
  ^-  (unit ifit)
  ?.  ?=(%call -.e)  ~
  ?~  args.e  ~
  ?~  t.args.e  ~
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
  ?.  ?=(%wing -.head.e)  ~
  ?.  ?=([@ ~] names.head.e)  ~
  ?.  ?=(~ (ienv-lookup i.names.head.e env))  ~
  ?.  (unique-value-name i.names.head.e globals.state)  ~
  ?.  (direct-any-gate-arg args.e gate-defs.state)  ~
  ?~  prelude.state  ~
  ?~  source.u.prelude.state  ~
  ?~  head-evidence.state  ~
  ?.  =(u.prelude.state iface.u.head-evidence.state)  ~
  ?.  ?=(^ (ienv-lookup i.names.head.e values.u.prelude.state))  ~
  =/  head=(unit def)  (~(get by gates.u.head-evidence.state) i.names.head.e)
  ?~  head  ~
  =/  sam=(unit sample)  (direct-gate-sample u.head)
  ?~  sam  ~
  ?.  ?=(%cell -.u.sam)  ~
  =/  fit=ifit  (direct-positional-fit args.e items.u.sam actual expected env state sub.state next.state)
  ?.  ?=(%ok -.fit)  ~
  ::  Enclosing inference may add constraints after this call. Only a
  ::  closed call-sample proof can remain stable under those later bindings.
  =/  actual-final=itype  (itype-normalize actual sub.fit)
  =/  expected-final=itype  (itype-normalize expected sub.fit)
  ?^  (itype-vars actual-final)  ~
  ?^  (itype-vars expected-final)  ~
  ?:  |((itype-has-tag actual-final) (itype-has-tag expected-final))  ~
  ::  A later argument may resolve a variable used by an earlier slot.
  ::  Recheck every fit and face against the completed substitution; no
  ::  additional binding or fresh variable is permitted in the second pass.
  =/  verified=ifit  (direct-positional-fit args.e items.u.sam actual expected env state sub.fit next.fit)
  ?.  ?=(%ok -.verified)  ~
  ?.  &(=(sub.fit sub.verified) =(next.fit next.verified))  ~
  `fit
::
++  infer-call-with-head
  |=  [e=expr env=ienv state=istate head=iresult]
  ^-  iresult
  ?>  ?=(%call -.e)
  ?~  args.e  [%| ["call has no argument" ~]]
  ?:  ?=(%| -.head)  head
  =/  head-type=itype  (itype-walk typ.p.head sub.state.p.head)
  =/  arg=iresult
    ?^  t.args.e
      ?:  ?=(%fn -.head-type)
        (infer-call-context-args args.e sample.head-type env state.p.head (span-of head.e))
      (infer-simple-items (turn args.e |=(a=expr [(span-of a) ~ a])) env state.p.head)
    ?:  ?=(%fn -.head-type)
      (infer-call-context-arg i.args.e sample.head-type env state.p.head (span-of head.e))
    (infer-fragment i.args.e env state.p.head)
  ?:  ?=(%| -.arg)  arg
  =/  st=istate  state.p.arg
  =/  ht=itype  (itype-walk typ.p.head sub.st)
  ?:  ?=(%fn -.ht)
    =/  shape=(unit [source=iwfields target=iwfields])
      ?^  t.args.e  ~
      (width-shape typ.p.arg sample.ht sub.st)
    ?^  shape  [%| ["record width constraint needs unsupported inference" ~]]
    =/  fit=ifit
      ?^  t.args.e  (itype-fit-inner typ.p.arg sample.ht sub.st next.st & |)
      (itype-fit typ.p.arg sample.ht sub.st next.st)
    =/  direct=(unit ifit)
      ?:  ?=(%ok -.fit)  ~
      (direct-gate-call-fit e typ.p.arg sample.ht env st)
    =.  fit  ?~(direct fit u.direct)
    ?:  ?=(%unknown -.fit)
      ?~  defer.st  [%| ["call constraint is not supported by partial inference" ~]]
      =/  edge=(unit dgo)  (dg-eligible-ctor e typ.p.head typ.p.arg sample.ht st)
      ?~  edge  [%| ["call constraint is not supported by partial inference" ~]]
      ?:  (gth (lent obligations.st) 63)  [%| ["call constraint is not supported by partial inference" ~]]
      [%& product.ht st(obligations [u.edge obligations.st])]

    ?:  ?=(%bad -.fit)
      ?~  t.args.e
        =/  missing=(unit idiag)  (missing-union-tag i.args.e sample.ht sub.st (span-of head.e))
        ?^  missing  [%| u.missing]
        =/  nested=(unit idiag)  (nested-missing-tag i.args.e typ.p.arg sample.ht sub.st next.st (span-of head.e))
        ?^  nested  [%| u.nested]
        [%| ["call's sample and argument types do not unify" ~[[(span-of head.e) (site-type-note "called gate" ht sub.st)] [(span-of i.args.e) (site-type-note "argument" typ.p.arg sub.st)]]]]
      =/  bad=(unit [at=span typ=itype])
        (call-error-site args.e typ.p.arg sample.ht sub.st next.st)
      =/  whole-args=span
        [beg:(span-of i.args.e) end:(span-of (rear args.e))]
      =/  arg-at=span  ?~(bad whole-args at.u.bad)
      =/  arg-type=itype  ?~(bad typ.p.arg typ.u.bad)
      [%| ["call's sample and argument types do not unify" ~[[(span-of head.e) (site-type-note "called gate" ht sub.st)] [arg-at (site-type-note "argument" arg-type sub.st)]]]]
    =/  face-asym=?
      ?^  direct  |
      ?^  t.args.e  (itype-positional-face-asym args.e typ.p.arg sample.ht sub.fit)
      (itype-face-asym typ.p.arg sample.ht sub.fit)
    ?:  &((itype-has-face typ.p.arg sub.fit) face-asym (itype-output-may-be-cell product.ht sub.fit))
      [%| ["call result face propagation is not supported by partial inference" ~]]
    [%& product.ht st(sub sub.fit, next next.fit)]
  =/  result=itype  [%var next.st]
  =/  uni=(unit isub)  (itype-unify ht [%fn typ.p.arg result] sub.st)
  ?~  uni
    [%| ["call's sample and argument types do not unify" ~[[(span-of head.e) (site-type-note "called gate" ht sub.st)] [(span-of i.args.e) (site-type-note "argument" typ.p.arg sub.st)]]]]
  [%& result st(next +(next.st), sub u.uni)]
::
++  call-error-site
  |=  [args=(list expr) actual=itype expected=itype sub=isub next=@ud]
  ^-  (unit [at=span typ=itype])
  ?~  args  ~
  =/  original=[left=itype right=itype]  [actual expected]
  ?:  |(?=(%var -.left.original) ?=(%avar -.left.original) ?=(%rvar -.left.original) |(?=(%nvar -.left.original) ?=(%rnvar -.left.original)) ?=(%var -.right.original) ?=(%avar -.right.original) ?=(%rvar -.right.original) |(?=(%nvar -.right.original) ?=(%rnvar -.right.original)))  ~
  =.  actual  (itype-walk actual sub)
  =.  expected  (itype-walk expected sub)
  ?:  &(?=(%face -.expected) !?=(%face -.actual))
    $(expected body.expected)
  ?~  t.args
    =/  fit=ifit  (itype-fit actual expected sub next)
    ?.  ?=(%bad -.fit)  ~
    `[(span-of i.args) (itype-normalize actual sub)]
  ?.  &(?=(%cell -.actual) ?=(%cell -.expected))  ~
  =/  first=ifit  (itype-fit hed.actual hed.expected sub next)
  ?:  ?=(%bad -.first)  `[(span-of i.args) (itype-normalize hed.actual sub)]
  ?:  ?=(%unknown -.first)  ~
  $(args t.args, actual tal.actual, expected tal.expected, sub sub.first, next next.first)
::
::  Context can help a call argument or cast value while the final fit
::  checks the complete right-nested type, including any written faces.
::
::  Context can resolve the payload of a canonical prelude unit, but an
::  unrelated union with a similar noun shape is not the same mold.
++  infer-unit-context
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?>  ?=(%unit -.e)
  ?>  ?=(%union -.expected)
  ?~  prelude.state  (infer-fragment e env state)
  =/  standard=(unit ischeme)  (find-jibb-mold %unit u.prelude.state)
  ?~  standard  (infer-fragment e env state)
  ?.  (standard-unit-template u.standard at.u.prelude.state)  (infer-fragment e env state)
  ?.  =(origin.expected `[at.u.prelude.state %unit])  (infer-fragment e env state)
  ?~  args.expected  (infer-fragment e env state)
  ?^  t.args.expected  (infer-fragment e env state)
  =/  payload=itype  i.args.expected
  =/  canonical=(unit itype)  (template-apply u.standard ~[payload])
  ?~  canonical  (infer-fragment e env state)
  ?>  ?=(%union -.u.canonical)
  ?.  =((itype-normalize expected(label ~) sub.state) (itype-normalize u.canonical(label ~) sub.state))
    (infer-fragment e env state)
  =/  value=iresult  (infer-call-context-arg val.e payload env state context)
  ?:  ?=(%| -.value)  value
  =/  fit=ifit  (itype-fit typ.p.value payload sub.state.p.value next.state.p.value)
  ?:  ?=(%unknown -.fit)  [%| ["unit payload constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)
    =/  missing=(unit idiag)  (missing-union-tag val.e payload sub.state.p.value context)
    ?^  missing  [%| u.missing]
    =/  nested=(unit idiag)  (nested-missing-tag val.e typ.p.value payload sub.state.p.value next.state.p.value context)
    ?^  nested  [%| u.nested]
    [%| ["unit payload does not fit its expected type" ~[[context (site-type-note "expected unit payload" payload sub.state.p.value)] [(span-of val.e) (site-type-note "payload" typ.p.value sub.state.p.value)]]]]
  [%& expected state.p.value(sub sub.fit, next next.fit)]
::
::  A known gate may receive an enclosing target before its argument is
::  inferred when its result is open or a direct, matching named generic
::  union. Opaque, recursive, tag-constrained and variable-bound union
::  results keep the existing directional path.
++  infer-contextual-call
  |=  [e=expr expected=itype env=ienv state=istate]
  ^-  iresult
  ?>  ?=(%call -.e)
  ?~  args.e  [%| ["call has no argument" ~]]
  =/  head=iresult  (infer-fragment head.e env state)
  ?:  ?=(%| -.head)  head
  =/  ht=itype  (itype-walk typ.p.head sub.state.p.head)
  ?.  ?=(%fn -.ht)  (infer-call-with-head e env state head)
  =/  result=itype  (itype-walk product.ht sub.state.p.head)
  =/  eligible=?
    ?:  ?=(%var -.result)  &
    ::  A direct known generic union may receive the same nominal result
    ::  context before its arguments are checked. Variable-bound origins,
    ::  pending tags, recursive identities and unknown atoms stay open.
    ?.  &(?=(%union -.product.ht) ?=(%union -.result) ?=(%union -.expected))  |
    ?~  origin.result  |
    ?.  =(origin.result origin.expected)  |
    ?~  args.result  |
    ?.  =((lent args.result) (lent args.expected))  |
    ?:  |((itype-has-tag (itype-normalize result sub.state.p.head)) (itype-has-tag (itype-normalize expected sub.state.p.head)))  |
    ?:  |((itype-has-recursive (itype-normalize result sub.state.p.head)) (itype-has-recursive (itype-normalize expected sub.state.p.head)))  |
    ?:  |((itype-has-any-atom result sub.state.p.head) (itype-has-any-atom expected sub.state.p.head))  |
    &
  ?.  eligible  (infer-call-with-head e env state head)
  ?:  |(?=(%var -.expected) ?=(%avar -.expected) ?=(%rvar -.expected) |(?=(%nvar -.expected) ?=(%rnvar -.expected)) (itype-has-tag (itype-normalize expected sub.state.p.head)))
    (infer-call-with-head e env state head)
  =/  sub=(unit isub)  (itype-unify result expected sub.state.p.head)
  ?~  sub  (infer-call-with-head e env state head)
  (infer-call-with-head e env state [%& typ.p.head state.p.head(sub u.sub)])
::
::  An eligible fully faced literal receives context by name, in source order.
++  width-literal-fields
  |=  [items=(list item) axis=@ud fuel=@ud]
  ^-  (unit iwfields)
  =/  order=(list iwfield)  ~
  =/  index=(map term iwfield)  *(map term iwfield)
  |-
  ?~  items  ~
  ?:  =(0 fuel)  ~
  ?~  face.i.items  ~
  =/  at-axis=@ud  ?~(t.items axis (mul 2 axis))
  =/  entry=iwfield  [u.face.i.items at-axis [%noun ~]]
  ?:  ?=(^ (~(get by index) name.entry))  ~
  =.  index  (~(put by index) name.entry entry)
  =.  order  [entry order]
  ?~  t.items  `[(flop order) index]
  $(items t.items, axis +((mul 2 axis)), fuel (dec fuel))
++  width-infer-items
  |=  [items=(list item) expected=(map term iwfield) env=ienv state=istate context=span]
  ^-  iresult
  ?~  items  [%| ["empty record is not supported" ~]]
  ?~  face.i.items  [%| ["record face needs unsupported inference" ~]]
  =/  field=(unit iwfield)  (~(get by expected) u.face.i.items)
  =/  head=iresult
    ?~  field  (infer-fragment val.i.items env state)
    (infer-call-context-arg val.i.items typ.u.field env state context)
  ?:  ?=(%| -.head)  head
  =/  typ=itype  [%face u.face.i.items typ.p.head]
  ?~  t.items  [%& typ state.p.head]
  =/  tail=iresult  $(items t.items, state state.p.head)
  ?:  ?=(%| -.tail)  tail
  [%& [%cell typ typ.p.tail] state.p.tail]
++  width-infer-literal
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  (unit iresult)
  ?.  ?=(%tuple -.e)  ~
  ?.  |(?=(%cell -.expected) ?=(%face -.expected))  ~
  =/  source=(unit iwfields)  (width-literal-fields items.e 1 4.096)
  =/  target=(unit iwfields)  (width-scan expected sub.state 1 4.096)
  ?~  source  ~
  ?~  target  ~
  ?:  (lth (lent order.u.source) (lent order.u.target))  ~
  ?.  (width-in-order order.u.source order.u.target)
    `(infer-simple-items items.e env state)
  `(width-infer-items items.e index.u.target env state context)
::
::  Experimental intrinsic recognition; real bindings retain normal calls.
++  explicit-proj-call
  |=  [e=expr env=ienv state=istate]
  ^-  ?
  ?.  ?=(%call -.e)  |
  ?.  ?=([* ~] args.e)  |
  ?.  ?=(%wing -.head.e)  |
  ?.  =(names.head.e ~[%proj])  |
  ?:  ?=(^ (ienv-lookup %proj env))  |
  ?:  (lien globals.state |=(n=term =(n %proj)))  |
  ?~  prelude.state  &
  ?:(?=(^ (ienv-lookup %proj values.u.prelude.state)) | &)
++  infer-proj-source
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?:  ?=(%group -.e)  $(e inner.e)
  =/  literal=(unit iresult)  (width-infer-literal e expected env state context)
  ?^  literal  u.literal
  (infer-fragment e env state)
++  infer-proj-context
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?>  ?=(%call -.e)
  ?~  args.e  [%| ["proj needs one record" ~]]
  ?.  |(?=(%cell -.expected) ?=(%face -.expected))  [%| ["proj needs an expected record type" ~]]
  =/  value=iresult  (infer-proj-source i.args.e expected env state context)
  ?:  ?=(%| -.value)  value
  =/  shape=(unit [source=iwfields target=iwfields])
    (width-proj-shape typ.p.value expected sub.state.p.value)
  ?~  shape  [%| ["proj needs a known record containing its expected fields" ~]]
  =/  project=(unit iwidth-result)  (width-project u.shape sub.state.p.value next.state.p.value)
  ?~  project  [%| ["proj constraint needs unsupported inference" ~]]
  =/  st=istate  state.p.value(sub sub.u.project, next next.u.project)
  [%& expected st(projections [[at.e e typ.p.value expected steps.u.project] projections.st])]
::
::  A known literal singleton in a direct union can contextualize a
::  loobean literal of the same noun. Only explicit singleton and cell
::  competitors are considered; opaque or variable cases stay unknown.
++  explicit-singleton-in-union
  |=  [t=itype noun=@]
  ^-  ?
  ?.  ?=(%union -.t)  |
  =/  cases=(list itype)  cases.t
  =/  found=?  |
  |-
  ?~  cases  found
  =/  c=itype  i.cases
  ?:  ?=(%cell -.c)  $(cases t.cases)
  ?.  ?=(%const -.c)  |
  ?:  =(noun val.literal.c)
    ?:  found  |
    $(cases t.cases, found &)
  $(cases t.cases)
::
::  Select a written literal-headed case only when every competing case is
::  also an explicit singleton-headed cell and exactly one matches. Opaque,
::  variable-bound and differently shaped cases keep inference unchanged.
::  This first slice supplies context to a directly called payload. Plain
::  literal data and other expressions retain their existing inference path.
++  contextual-atomic-arguments
  |=  args=(list expr)
  ^-  ?
  ?~  args  &
  ?.  ?=(?(%lit %wing %ctor) -.i.args)  |
  $(args t.args)
++  contextual-direct-payload-call
  |=  e=expr
  ^-  ?
  ?:  ?=(%group -.e)  $(e inner.e)
  ?.  ?=(%call -.e)  |
  ?.  ?=(%wing -.head.e)  |
  ?~  args.e  |
  (contextual-atomic-arguments args.e)
::
::  A walked variable may have concealed a union inside a substituted
::  structure before this arm was called. Decline in that case rather than
::  deriving provenance from the already-walked type.
++  contextual-simple-sub
  |=  sub=isub
  ^-  ?
  ?~  sub  &
  ?:  ?=(?(%cell %face %fn %union %collection) -.val.i.sub)  |
  $(sub t.sub)
::
::  Check the syntactic root before scanning; scan substitutions once.
++  grec-direct-context
  |=  [expected=itype sub=isub]
  ^-  ?
  =/  left=@ud  4.096
  |-
  ?:  ?=(%face -.expected)
    ?:  =(0 left)  |
    $(expected body.expected, left (dec left))
  ?.  ?=(%grec -.expected)  |
  ?~  sub  &
  ?:  =(0 left)  |
  ?:  ?=(?(%cell %face %fn %union %collection %grec) -.val.i.sub)  |
  $(sub t.sub, left (dec left))
++  contextual-direct-union
  |=  target=itype
  ^-  ?
  ?:  ?=(%face -.target)  $(target body.target)
  ?=(%union -.target)
++  contextual-tagged-case
  |=  [target=itype tag=@ sub=isub]
  ^-  (unit itype)
  ?.  ?=(%union -.target)  ~
  =/  remaining=(list itype)  cases.target
  =/  found=(unit itype)  ~
  =/  seen=(set @)  *(set @)
  |-
  ?~  remaining  found
  =/  c=itype  i.remaining
  ?.  ?=(%cell -.c)  ~
  =/  head=itype  hed.c
  ?.  ?=(%const -.head)  ~
  ?:  (~(has in:..zuse seen) val.literal.head)  ~
  =.  seen  (~(put in:..zuse seen) val.literal.head)
  ?:  =(tag val.literal.head)
    $(remaining t.remaining, found `c)
  $(remaining t.remaining)
::
++  infer-call-context-arg
  |=  [e=expr expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?:  ?=(%pair -.e)  $(e (pair-as-cell e))
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?:  ?=(%trace -.e)
    =/  traced=iresult  (infer-fragment val.e env state)
    ?:  ?=(%| -.traced)  traced
    $(e then.e, state state.p.traced)
  =/  target=itype  (itype-walk expected sub.state)
  |-
  ?:  ?=(%face -.target)  $(target (itype-walk body.target sub.state))
  ?:  (explicit-proj-call e env state)
    (infer-proj-context e expected env state context)
  ::  Experimental construction only for a source-proven direct target.
  ::  Decline any walked structural binding to retain raw-variable provenance.
  ?:  &(?=(%grec -.target) ?=(%tuple -.e) (grec-direct-context expected sub.state))
    =/  unfolded=(unit [view=itype left=@ud])  (grec-unfold-view target jrec-fuel.state)
    ?~  unfolded  [%| ["recursive mold unfolding needs unsupported inference" ~]]
    ?~  items.e  [%| ["recursive mold constructor needs unsupported inference" ~]]
    =/  first=item  i.items.e
    ?.  &(?=(~ face.first) ?=(%lit -.val.first) =(%term form.lit.val.first))
      [%| ["recursive mold constructor needs unsupported inference" ~]]
    =/  chosen=(unit itype)  (contextual-tagged-case view.u.unfolded val.lit.val.first sub.state)
    ?~  chosen  [%| ["recursive mold constructor has no matching case" ~]]
    =/  value=iresult  (infer-call-context-items items.e u.chosen env state(jrec-fuel left.u.unfolded) context)
    ?:  ?=(%| -.value)  value
    =/  fit=ifit  (itype-fit typ.p.value u.chosen sub.state.p.value next.state.p.value)
    ?:  ?=(%unknown -.fit)  [%| ["recursive mold case needs unsupported inference" ~]]
    ?:  ?=(%bad -.fit)  [%| ["recursive mold case does not fit its source shape" ~]]
    [%& target state.p.value(sub sub.fit, next next.fit)]
  ::  Only the source-proven one-layer cell is exposed. Each recursive
  ::  descent consumes one written tuple; named values use ordinary fit.
  ?:  &(?=(%jrec -.target) ?=(%lit -.e) =(%null form.lit.e))
    ?:  =(0 jrec-fuel.state)  [%| ["recursive mold unfolding needs unsupported inference" ~]]
    [%& target state(jrec-fuel (dec jrec-fuel.state))]
  ?:  &(?=(%jrec -.target) ?=(%tuple -.e))
    ?:  =(0 jrec-fuel.state)  [%| ["recursive mold unfolding needs unsupported inference" ~]]
    =.  state  state(jrec-fuel (dec jrec-fuel.state))
    =/  shape=itype
      [%cell [%face head.target [%atom aura.target]] [%face tail.target target]]
    =/  value=iresult  (infer-call-context-items items.e shape env state context)
    ?:  ?=(%| -.value)  value
    =/  fit=ifit  (itype-fit typ.p.value shape sub.state.p.value next.state.p.value)
    ?:  ?=(%unknown -.fit)  [%| ["recursive mold cell constraint needs unsupported inference" ~]]
    ?:  ?=(%bad -.fit)  [%| ["recursive mold cell does not fit its source shape" ~]]
    [%& target state.p.value(sub sub.fit, next next.fit)]
  ?:  ?=(%call -.e)  (infer-contextual-call e target env state)
  ?:  (single-structured-pattern e)
    ?>  ?=(%branch -.e)
    =/  single=(unit iresult)  (grec-single-wing-subject subject.e env state)
    ?^  single  (infer-known-union-context-subject e target env u.single context)
    (infer-single-case-branch e env state `[target context])
  ?:  (cell-binder-pattern e)
    (infer-cell-branch e env state `[target context])
  ::  In an explicit singleton context retain the written loobean noun;
  ::  the ordinary singleton fit compares its noun, not its spelling.
  =/  singleton=(unit itype)
    ?.  ?=(%lit -.e)  ~
    ?.  =(%loobean form.lit.e)  ~
    ?.  |(?=(%const -.target) &(?=(%union -.expected) (explicit-singleton-in-union expected val.lit.e)))  ~
    `[%const lit.e]
  ?^  singleton  [%& u.singleton state]
  =/  known=(unit iresult)
    ?:  ?=(%branch -.e)  (known-union-subject subject.e env state)
    ~
  ?:  &(?=(^ known) ?=(%| -.u.known) !(duplicate-loobean-arms e))  u.known
  ?:  &(?=(^ known) ?=(%& -.u.known) ?=(~ (unit-union-payload (itype-normalize typ.p.u.known sub.state.p.u.known))))
    (infer-known-union-context-subject e target env u.known context)
  ?:  &(?=(%union -.target) ?=(%unit -.e))
    (infer-unit-context e target env state context)
  ?:  &(?=(%flag -.target) (context-union-branch e))
    (infer-union-context e target env state context)
  ?:  &(?=(%union -.target) (context-union-branch e))
    (infer-union-context e target env state context)
  ?:  &(?=(%collection -.target) =(%list name.target) (context-union-branch e))
    (infer-union-context e target env state context)
  ?:  &(?=(%collection -.target) =(%list name.target) (context-list-expression e))
    (infer-list-context e target env state context)
  ::  A literal-headed tuple can receive the unique case's payload
  ::  context. The ordinary final fit still checks the complete union.
  =/  selected=(unit itype)
    ?.  &((contextual-simple-sub sub.state) (contextual-direct-union expected) ?=(%union -.target) ?=(%tuple -.e) ?=(^ items.e))  ~
    ?~  t.items.e  ~
    ?^  t.t.items.e  ~
    ?.  (contextual-direct-payload-call val.i.t.items.e)  ~
    =/  first=item  i.items.e
    ?.  &(?=(~ face.first) ?=(%lit -.val.first) |(=(%term form.lit.val.first) =(%null form.lit.val.first) =(%loobean form.lit.val.first)))  ~
    (contextual-tagged-case target val.lit.val.first sub.state)
  ?^  selected
    ?>  ?=(%tuple -.e)
    ::  On this bounded shallow-call shape, preserve any inference that
    ::  already fits before trying the new contextual path. Neither pass
    ::  can recursively select a nested tuple from the atomic arguments.
    =/  ordinary=(unit iresult)
      =/  initial=iresult  (infer-fragment e env state)
      ?:  ?=(%| -.initial)  ~
      =/  fit=ifit  (itype-fit typ.p.initial target sub.state.p.initial next.state.p.initial)
      ?.  ?=(%ok -.fit)  ~
      `initial
    ?^  ordinary  u.ordinary
    =/  value=iresult  (infer-call-context-items items.e u.selected env state context)
    ?:  ?=(%| -.value)  value
    =/  fit=ifit  (itype-fit typ.p.value u.selected sub.state.p.value next.state.p.value)
    ?:  ?=(%unknown -.fit)  [%| ["tagged case needs unsupported inference" ~]]
    ?:  ?=(%bad -.fit)  [%| ["tagged case does not fit its expected type" ~[[context "expected union case"] [(span-of e) "value"]]]]
    [%& typ.p.value state.p.value(sub sub.fit, next next.fit)]
  ?:  &(?=(%cell -.target) ?=(%tuple -.e))
    (infer-call-context-items items.e target env state context)
  (infer-fragment e env state)
::
::  Preserve each written face; the final complete sample fit checks faces.
::  A tuple or positional field face belongs to the enclosing sample,
::  not to the expression at that position. A second face, if present,
::  is part of the value's own expected type.
++  projection-field-target
  |=  expected=itype
  ^-  itype
  ?:(?=(%face -.expected) body.expected expected)
::
++  infer-call-context-items
  |=  [items=(list item) expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?~  items  [%| ["empty cell is not supported by partial inference" ~]]
  ?~  t.items
    =/  last=iresult  (infer-call-context-arg val.i.items (projection-field-target expected) env state context)
    ?:  ?=(%| -.last)  last
    =/  typ=itype  typ.p.last
    =.  typ  ?~(face.i.items typ [%face u.face.i.items typ])
    [%& typ state.p.last]
  =/  target=itype  (itype-walk expected sub.state)
  |-
  ?:  ?=(%face -.target)  $(target (itype-walk body.target sub.state))
  ?.  ?=(%cell -.target)  (infer-simple-items items env state)
  =/  head=iresult  (infer-call-context-arg val.i.items (projection-field-target hed.target) env state context)
  ?:  ?=(%| -.head)  head
  =/  typ=itype  typ.p.head
  =.  typ  ?~(face.i.items typ [%face u.face.i.items typ])
  =/  tail=iresult  (infer-call-context-items t.items tal.target env state.p.head context)
  ?:  ?=(%| -.tail)  tail
  [%& [%cell typ typ.p.tail] state.p.tail]
::
++  infer-call-context-args
  |=  [args=(list expr) expected=itype env=ienv state=istate context=span]
  ^-  iresult
  ?~  args  [%| ["call has no argument" ~]]
  ?~  t.args  (infer-call-context-arg i.args (projection-field-target expected) env state context)
  =/  target=itype  (itype-walk expected sub.state)
  |-
  ?:  ?=(%face -.target)  $(target (itype-walk body.target sub.state))
  ?.  ?=(%cell -.target)
    (infer-simple-items (turn args |=(a=expr [(span-of a) ~ a])) env state)
  =/  head=iresult  (infer-call-context-arg i.args (projection-field-target hed.target) env state context)
  ?:  ?=(%| -.head)  head
  =/  tail=iresult  (infer-call-context-args t.args tal.target env state.p.head context)
  ?:  ?=(%| -.tail)  tail
  [%& [%cell typ.p.head typ.p.tail] state.p.tail]
::
::  Tuple and record expressions preserve their explicitly written faces.
::
++  infer-simple-items
  |=  [items=(list item) env=ienv state=istate]
  ^-  iresult
  ?~  items  [%| ["empty cell is not supported by partial inference" ~]]
  =/  head=iresult  (infer-fragment val.i.items env state)
  ?:  ?=(%| -.head)  head
  =/  ht=itype  typ.p.head
  =.  ht  ?~(face.i.items ht [%face u.face.i.items ht])
  ?~  t.items  [%& ht state.p.head]
  =/  tail=iresult  $(items t.items, state state.p.head)
  ?:  ?=(%| -.tail)  tail
  [%& [%cell ht typ.p.tail] state.p.tail]
::
::  A single all-binder cell pattern covers a known cell spine; the final
::  binder captures the remaining noun. Other pattern matrices stay partial.
::
::  Validate binders before reading the subject, preserving shadow-error
::  precedence. The last binder receives the entire remaining tail.
++  cell-pattern-names
  |=  [pats=(list pattern) env=ienv globals=(list term) seen=(list term)]
  ^-  (each (list term) @t)
  ?~  pats  [%& ~]
  ?.  ?=(%bind -.i.pats)  [%| 'branch pattern is not supported by partial inference']
  =/  name=term  name.i.pats
  ?:  |(=(name %proj) ?=(^ (ienv-lookup name env)) (lien globals |=(n=term =(n name))) (lien seen |=(n=term =(n name))))
    [%| 'pattern shadows a name']
  =/  rest=(each (list term) @t)  $(pats t.pats, seen [name seen])
  ?:  ?=(%| -.rest)  rest
  [%& [name p.rest]]
::
++  cell-pattern-types
  |=  [names=(list term) env=ienv next=@ud]
  ^-  [typ=itype env=ienv next=@ud]
  ?~  names  !!
  =/  head=itype  [%var next]
  =/  scope=ienv  [[i.names [head ~]] env]
  ?~  t.names  [head scope +(next)]
  =/  tail=[typ=itype env=ienv next=@ud]  $(names t.names, env scope, next +(next))
  [[%cell head typ.tail] env.tail next.tail]
::
::  At every position that must be a cell, opaque or sum types may still
::  contain cells. Do not report a definite mismatch without unfolding them.
++  cell-pattern-spine-unknown
  |=  [typ=itype names=(list term) sub=isub]
  ^-  ?
  ?~  names  |
  ?~  t.names  |
  =.  typ  (itype-walk typ sub)
  ?:  ?=(%cell -.typ)  $(typ tal.typ, names t.names)
  |(?=(%union -.typ) ?=(%collection -.typ) ?=(%recursive -.typ) ?=(%jrec -.typ) ?=(%grec -.typ) ?=(%noun -.typ) ?=(%fn -.typ) ?=(%tag -.typ))
::
++  cell-binder-pattern
  |=  e=expr
  ^-  ?
  ?.  ?=(%branch -.e)  |
  ?~  arms.e  |
  ?^  t.arms.e  |
  ?.  ?=(%cell -.pat.i.arms.e)  |
  !(single-structured-pattern e)
::
++  infer-cell-branch
  |=  [e=expr env=ienv state=istate expected=(unit [typ=itype context=span])]
  ^-  iresult
  ?>  ?=(%branch -.e)
  ?~  arms.e  [%| ["branch is not supported by partial inference" ~]]
  =/  arm=arm  i.arms.e
  ?.  ?=(%cell -.pat.arm)  [%| ["branch pattern is not supported by partial inference" ~]]
  =/  pats=(list pattern)  items.pat.arm
  ?~  pats  [%| ["branch pattern is not supported by partial inference" ~]]
  ?~  t.pats  [%| ["branch pattern is not supported by partial inference" ~]]
  =/  names=(each (list term) @t)  (cell-pattern-names pats env globals.state ~)
  ?:  ?=(%| -.names)  [%| [(trip p.names) ~]]
  =/  subject=iresult  (infer-fragment subject.e env state)
  ?:  ?=(%| -.subject)  subject
  =/  st=istate  state.p.subject
  =/  subject-type=itype  (itype-normalize typ.p.subject sub.st)
  ?:  (itype-has-recursive subject-type)
    [%| ["recursive pattern is not supported by partial inference" ~]]
  ?:  (itype-has-face typ.p.subject sub.st)
    [%| ["record patterns are not supported by partial inference" ~]]
  ?:  (cell-pattern-spine-unknown subject-type p.names sub.st)
    [%| ["cell pattern subject is not supported by partial inference" ~]]
  =/  binders=[typ=itype env=ienv next=@ud]  (cell-pattern-types p.names env next.st)
  =/  sub=(unit isub)  (itype-unify typ.p.subject typ.binders sub.st)
  ?~  sub  [%| ["cell pattern does not match the subject type" ~]]
  =.  st  st(next next.binders, sub u.sub)
  ?~  expected  (infer-fragment val.arm env.binders st)
  =/  body=iresult  (infer-call-context-arg val.arm typ.u.expected env.binders st context.u.expected)
  ?:  ?=(%| -.body)  body
  =/  fit=ifit  (itype-fit typ.p.body typ.u.expected sub.state.p.body next.state.p.body)
  ?:  ?=(%unknown -.fit)  [%| ["cell branch result constraint is not supported by partial inference" ~]]
  ?:  ?=(%bad -.fit)  [%| ["cell branch arm does not fit its expected type" ~[[context.u.expected "expected type"] [(span-of val.arm) "branch arm"]]]]
  ?:  (itype-has-tag (itype-normalize typ.u.expected sub.fit))
    [%| ["cell branch result needs context in partial inference" ~]]
  [%& typ.u.expected state.p.body(sub sub.fit, next next.fit)]
::
++  show-itype
  |=  [t=itype sub=isub]
  ^-  tape
  =.  t  (itype-walk t sub)
  ?-  -.t
    %var
      ?:  (lth id.t 26)  [(add 65 id.t) ~]
      "T{<id.t>}"
    %avar
      ?:  (lth id.t 26)  [(add 65 id.t) ~]
      "T{<id.t>}"
    %rvar
      ?:  (lth id.t 26)  [(add 65 id.t) ~]
      "T{<id.t>}"
    %nvar
      ?:  (lth id.t 26)  [(add 65 id.t) ~]
      "T{<id.t>}"
    %rnvar
      ?:  (lth id.t 26)  [(add 65 id.t) ~]
      "T{<id.t>}"
    %atom  "@{(trip aura.t)}"
    %any-atom  "@"
    %flag  "?"
    %noun  "*"
    %tag   (trip txt.literal.t)
    %const  (trip txt.literal.t)
    %union
      ?~  label.t  (show-itype-cases cases.t sub)
      ?~  args.t  (trip u.label.t)
      "({(trip u.label.t)} {(show-itype-cases args.t sub)})"
    %recursive  ?~(label.t "recursive mold" (trip u.label.t))
    %jrec       ?~(label.t "recursive mold" (trip u.label.t))
    %grec       ?~(label.t "recursive mold" "({(trip u.label.t)} {(show-itype-cases args.t sub)})")
    %collection  "({(trip name.t)} {(show-itype-cases args.t sub)})"
    %face  "[{(trip name.t)}={(show-itype-context body.t sub)}]"
    %fn    "$-({(show-itype-context sample.t sub)} {(show-itype-context product.t sub)})"
    %cell  "[{(show-itype-item hed.t sub)} {(show-itype-item tal.t sub)}]"
  ==
::
++  show-itype-item
  |=  [t=itype sub=isub]
  ^-  tape
  =.  t  (itype-walk t sub)
  ?:  ?=(%face -.t)  "{(trip name.t)}={(show-itype-context body.t sub)}"
  (show-itype-context t sub)
::
++  show-itype-context
  |=  [t=itype sub=isub]
  ^-  tape
  =.  t  (itype-walk t sub)
  ?:  &(?=(%union -.t) ?=(~ label.t))  "({(show-itype t sub)})"
  (show-itype t sub)
::
++  show-itype-cases
  |=  [cases=(list itype) sub=isub]
  ^-  tape
  ?~  cases  ""
  ?~  t.cases  (show-itype-context i.cases sub)
  "{(show-itype-context i.cases sub)} {$(cases t.cases)}"
::
::  Include the type at a conflicting site where it can be printed.
::  A lone unresolved variable or decimal variable keeps the neutral label.
::
++  itype-has-nvar
  |=  typ=itype
  ^-  ?
  ?-  -.typ
    %nvar      &
    %rnvar      &
    %var       |
    %avar      |
    %rvar      |
    %atom      |
    %any-atom  |
    %flag      |
    %noun  |
    %tag       |
    %const     |
    %union     |((lien cases.typ |=(c=itype (itype-has-nvar c))) (lien args.typ |=(c=itype (itype-has-nvar c))))
    %recursive  |
    %jrec       |
    %grec       (lien args.typ |=(c=itype (itype-has-nvar c)))
    %collection  (lien args.typ |=(c=itype (itype-has-nvar c)))
    %face      $(typ body.typ)
    %fn        |($(typ sample.typ) $(typ product.typ))
    %cell      |($(typ hed.typ) $(typ tal.typ))
  ==
::
++  site-type-note
  |=  [label=tape typ=itype sub=isub]
  ^-  tape
  =/  normalized=itype  (itype-normalize typ sub)
  ?:  |(?=(%var -.normalized) ?=(%avar -.normalized) ?=(%rvar -.normalized) (itype-has-nvar normalized) (itype-has-tag normalized) (itype-has-union normalized))  label
  ?:  (itype-has-hidden-recursive normalized)  label
  =/  vars=(list @ud)  (unique-type-vars (itype-vars normalized))
  ?:  (gth (lent vars) 26)  label
  =/  printable=itype  (canonical-itype normalized vars)
  "{label} has type {(show-itype printable ~)}{(show-atom-constraint printable)}"
::
::  A capital in a written mold is generalized with its enclosing ++.
::  Atom constraints may remain generic; until full rigidity checking
::  is implemented, do not report a type if one became more specific.
::  Distinct written capitals cannot be forced equal; use the same
::  capital where a type must be shared (Decisions 2026-10-30).
::
++  cap-id-in
  |=  [n=@ud caps=icaps sub=isub]
  ^-  ?
  ?~  caps  |
  =/  resolved=itype  (itype-walk [%var id.i.caps] sub)
  =/  ident=(unit @ud)
    ?+  -.resolved  ~
      %var   `id.resolved
      %avar  `id.resolved
      %rvar  `id.resolved
    ==
  ?~  ident  $(caps t.caps)
  ?:  =(n u.ident)  &
  $(caps t.caps)
::
++  cap-with-id
  |=  [n=@ud caps=icaps sub=isub]
  ^-  (unit icap)
  ?~  caps  ~
  =/  resolved=itype  (itype-walk [%var id.i.caps] sub)
  =/  ident=(unit @ud)
    ?+  -.resolved  ~
      %var   `id.resolved
      %avar  `id.resolved
      %rvar  `id.resolved
    ==
  ?~  ident  $(caps t.caps)
  ?:  =(n u.ident)  `i.caps
  $(caps t.caps)
::
++  merged-capitals
  |=  [caps=icaps sub=isub]
  ^-  (unit [first=icap second=icap])
  ?~  caps  ~
  =/  resolved=itype  (itype-walk [%var id.i.caps] sub)
  =/  ident=(unit @ud)
    ?+  -.resolved  ~
      %var   `id.resolved
      %avar  `id.resolved
      %rvar  `id.resolved
    ==
  ?~  ident  $(caps t.caps)
  =/  found=(unit icap)  (cap-with-id u.ident t.caps sub)
  ?^  found  `[u.found i.caps]
  $(caps t.caps)
::
++  constrained-capitals
  |=  [caps=icaps sub=isub]
  ^-  ?
  ?~  caps  |
  =/  resolved=itype  (itype-walk [%var id.i.caps] sub)
  =/  ident=(unit @ud)
    ?+  -.resolved  ~
      %var   `id.resolved
      %avar  `id.resolved
      %rvar  `id.resolved
    ==
  ?~  ident  &
  ?:  (cap-id-in u.ident t.caps sub)  &
  $(caps t.caps)
::
::  An atom variable may be generalized when an explicit capital, sample
::  binder or instantiated constraint resolves to it. Decimal variables need
::  defaulting and must not be generalized as arbitrary atom types.
::
++  atom-var-from-cap
  |=  [n=@ud caps=icaps sub=isub]
  ^-  ?
  ?~  caps  |
  =/  resolved=itype  (itype-walk [%var id.i.caps] sub)
  ?:  |(?=(%avar -.resolved) ?=(%rvar -.resolved))
    ?:  =(n +.resolved)  &
    $(caps t.caps)
  $(caps t.caps)
::
++  has-atom-var
  |=  [n=@ud t=itype]
  ^-  ?
  ?-  -.t
    %var       |
    %avar      =(n id.t)
    %rvar      =(n id.t)
    %nvar      |
    %rnvar      |
    %atom      |
    %any-atom  |
    %flag      |
    %noun  |
    %tag       |
    %const     |
    %union     |((lien cases.t |=(c=itype (has-atom-var n c))) (lien args.t |=(c=itype (has-atom-var n c))))
    %recursive  |
    %jrec       |
    %grec       (lien args.t |=(c=itype (has-atom-var n c)))
    %collection  (lien args.t |=(c=itype (has-atom-var n c)))
    %face      $(t body.t)
    %fn        |($(t sample.t) $(t product.t))
    %cell      |($(t hed.t) $(t tal.t))
  ==
::
++  atom-var-from-binder
  |=  [n=@ud binders=(list @ud) sub=isub]
  ^-  ?
  ?~  binders  |
  =/  resolved=itype  (itype-normalize [%var i.binders] sub)
  ::  An instantiated atom variable is not itself a substitution, so
  ::  its origin still walks as an unbound variable of the same ID.
  ?:  ?=(%var -.resolved)
    ?:  =(n id.resolved)  &
    $(binders t.binders)
  ?:  (has-atom-var n resolved)  &
  $(binders t.binders)
::
++  unsupported-atom-vars
  |=  [t=itype caps=icaps binders=(list @ud) sub=isub]
  ^-  ?
  =/  vars=(list @ud)  (unique-type-vars (itype-vars t))
  |-
  ?~  vars  |
  ?:  (itype-var-is-atom i.vars t)
    ?.  (has-atom-var i.vars t)  &
    ?.  |((atom-var-from-cap i.vars caps sub) (atom-var-from-binder i.vars binders sub))  &
    $(vars t.vars)
  $(vars t.vars)
::
++  show-atom-constraint
  |=  t=itype
  ^-  tape
  =/  vars=(list @ud)  (unique-type-vars (itype-vars t))
  =/  printed=?  |
  =/  out=tape  ""
  |-
  ?~  vars  out
  ?:  (itype-var-is-restricted i.vars t)
    =/  sep=tape  ?:(printed ", " " where ")
    =/  clause=tape  "{sep}{(show-itype [%rvar i.vars] ~)} is an atom other than ?"
    $(vars t.vars, printed &, out (weld out clause))
  ?:  (itype-var-is-atom i.vars t)
    =/  sep=tape  ?:(printed ", " " where ")
    =/  clause=tape  "{sep}{(show-itype [%avar i.vars] ~)} is an atom"
    $(vars t.vars, printed &, out (weld out clause))
  $(vars t.vars)
::
::  Build the supported part of the value environment in dependency order.
::  Each pass adds successful definitions. Forward references become
::  available on a later pass; unsupported syntax does not enter the
::  environment. Generalized definitions are closed, so a use instantiates
::  its variables afresh.
::
++  global-value-names
  |=  ds=(list def)
  ^-  (list term)
  ?~  ds  ~
  ?:  ?=(%value -.i.ds)
    [name.i.ds $(ds t.ds)]
  $(ds t.ds)
::
++  unique-value-name
  |=  [n=term names=(list term)]
  ^-  ?
  =/  hits=(list term)  (skim names |=(x=term =(x n)))
  ?~  hits  |
  ?~  t.hits  &
  |
::
::  A top-level gate may refer to itself through one monomorphic placeholder.
::  Its declared sample is inferred first and preserves its field faces.
::  Unify the completed body with that placeholder before generalization;
::  reporting repeats the same check instead of instantiating the gate's
::  generalized interface inside its own body. Mutual groups stay unsupported.
::
++  direct-self-call
  |=  [e=expr name=term]
  ^-  ?
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?.  ?=(%call -.e)  |
  ?.  ?=(%wing -.head.e)  |
  =(names.head.e ~[name])
::
++  branch-base-arm
  |=  [e=expr name=term]
  ^-  (unit expr)
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?.  ?=(%branch -.e)  ~
  ?~  arms.e  ~
  ?~  t.arms.e  ~
  ?^  t.t.arms.e  ~
  =/  x=arm  i.arms.e
  =/  y=arm  i.t.arms.e
  ?.  &(?=(%lit -.pat.x) ?=(%lit -.pat.y))  ~
  ?.  &(=(%loobean form.lit.pat.x) =(%loobean form.lit.pat.y))  ~
  ?:  =(val.lit.pat.x val.lit.pat.y)  ~
  =/  first=?  (direct-self-call val.x name)
  =/  second=?  (direct-self-call val.y name)
  ?:  =(first second)  ~
  `?:(first val.y val.x)
::
::  Infer the base arm independently, with the self binding removed. Only
::  a closed type whose constraints resolved can seed the recursive result.
::  The regular body inference then checks both arms with shared state.
::
++  recursive-branch-seed
  |=  [d=def env=ienv state=istate]
  ^-  (unit itype)
  ?.  ?=(%value -.d)  ~
  ?.  |(?=(%gate -.val.d) ?=(%gate-wide -.val.d))  ~
  =/  gate=expr  val.d
  =/  body=expr
    ?-  -.gate
      %gate       body.gate
      %gate-wide  body.gate
      *           !!
    ==
  =/  base=(unit expr)  (branch-base-arm body name.d)
  ?~  base  ~
  =/  outer=ienv  (skim env |=(entry=[name=term scheme=ischeme] !=(name.entry name.d)))
  =/  sam=isample-result
    ?-  -.gate
      %gate       (infer-sample sample.gate outer state)
      %gate-wide  (infer-sample sample.gate outer state)
      *           !!
    ==
  ?:  ?=(%| -.sam)  ~
  =/  inferred=iresult  (infer-fragment u.base env.p.sam state.p.sam)
  ?:  ?=(%| -.inferred)  ~
  ?:  (pending-tags tags.state.p.inferred sub.state.p.inferred)  ~
  ?:  (constrained-capitals caps.state.p.inferred sub.state.p.inferred)  ~
  =/  typ=itype  (itype-normalize typ.p.inferred sub.state.p.inferred)
  ?:  ?=(^ (itype-vars typ))  ~
  ?:  (itype-has-tag typ)  ~
  `typ
::
++  infer-recursive-gate
  |=  [d=def env=ienv state=istate]
  ^-  iresult
  ?^  defer.state  [%| ["deferred recursive inference is unsupported" ~]]
  =.  gate-defs.state  ~
  ?.  ?=(%value -.d)  [%| ["recursive definition is not a gate" ~]]
  ?.  |(?=(%gate -.val.d) ?=(%gate-wide -.val.d))
    [%| ["recursive definition is not a gate" ~]]
  =/  result=(unit itype)  (recursive-branch-seed d env state)
  =/  gate=expr  val.d
  =/  sam=isample-result
    ?-  -.gate
      %gate       (infer-sample sample.gate env state)
      %gate-wide  (infer-sample sample.gate env state)
      *           !!
    ==
  ?:  ?=(%| -.sam)
    =/  diag=(unit idiag)
      ?-  -.gate
        %gate       (sample-import-invalid sample.gate env state)
        %gate-wide  (sample-import-invalid sample.gate env state)
        *           ~
      ==
    ?:  &(=(p.sam "sample mold is not supported by partial inference") ?=(^ diag))  [%| u.diag]
    [%| [p.sam ~]]
  =/  id=@ud  next.state.p.sam
  =/  product=itype  ?~(result [%var id] u.result)
  =/  st=istate  state.p.sam(next +(id))
  =/  seed=itype  [%fn typ.p.sam product]
  =/  seeded=ienv  [[name.d [seed ~]] env.p.sam]
  =/  body=expr
    ?-  -.gate
      %gate       body.gate
      %gate-wide  body.gate
      *           !!
    ==
  =/  out=iresult  (infer-fragment body seeded st)
  ?:  ?=(%| -.out)  out
  =/  uni=(unit isub)  (itype-unify product typ.p.out sub.state.p.out)
  ?~  uni  [%| ["recursive gate constraint is not supported by partial inference" ~]]
  [%& [%fn typ.p.sam typ.p.out] state.p.out(sub u.uni)]
::
++  dependency-root
  |=  names=(list term)
  ^-  (list term)
  ?~  names  ~
  ~[(rear names)]
::
++  dependency-exprs
  |=  xs=(list expr)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)  (dependency-expr i.xs)
  (weld first $(xs t.xs))
::
++  dependency-pieces
  |=  xs=(list piece)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)
    ?-  -.i.xs
      %expr  (dependency-expr p.i.xs)
      %text  ~
    ==
  (weld first $(xs t.xs))
::
++  dependency-qsegs
  |=  xs=(list qseg)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)
    ?-  -.i.xs
      %expr  (dependency-expr p.i.xs)
      %knot  ~
    ==
  (weld first $(xs t.xs))
::
++  dependency-items
  |=  xs=(list item)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)  (dependency-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  dependency-edits
  |=  xs=(list edit)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)  (dependency-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  dependency-arms
  |=  xs=(list arm)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)  (dependency-expr val.i.xs)
  (weld first $(xs t.xs))
::
++  dependency-defs
  |=  xs=(list def)
  ^-  (list term)
  ?~  xs  ~
  =/  first=(list term)
    ?:  ?=(%value -.i.xs)  (dependency-expr val.i.xs)
    ~
  (weld first $(xs t.xs))
::
++  dependency-expr
  |=  e=expr
  ^-  (list term)
  ?-  -.e
    %str     (dependency-pieces pieces.e)
    %qath    (dependency-qsegs segs.e)
    %wing    (dependency-root names.e)
    %change
      =/  first=(list term)  (dependency-root target.e)
      =/  last=(list term)  (dependency-edits edits.e)
      (weld first last)
    %pair    (dependency-expr val.e)
    %unit    (dependency-expr val.e)
    %group   (dependency-expr inner.e)
    %list    (dependency-exprs items.e)
    %tuple   (dependency-items items.e)
    %gate       (dependency-expr body.e)
    %gate-wide  (dependency-expr body.e)
    %call
      =/  first=(list term)  (dependency-expr head.e)
      =/  last=(list term)  (dependency-exprs args.e)
      (weld first last)
    %cast       (dependency-expr val.e)
    %trace
      =/  first=(list term)  (dependency-expr val.e)
      =/  last=(list term)  (dependency-expr then.e)
      (weld first last)
    %branch
      =/  first=(list term)  (dependency-expr subject.e)
      =/  last=(list term)  (dependency-arms arms.e)
      (weld first last)
    %body
      =/  first=(list term)  (dependency-defs defs.e)
      =/  last=(list term)  (dependency-expr final.e)
      (weld first last)
    *  ~
  ==
::
::  Infer a cyclic component with one monomorphic seed per gate. All members
::  must succeed before any scheme is available; pending constraints and
::  unresolved branch joins remain partial.
+$  igate-entry  [name=term typ=itype body=expr env=ienv caps=icaps]
+$  igate-seeds  (each [entries=(list igate-entry) state=istate] idiag)
++  seed-gate-group
  |=  [ds=(list def) env=ienv state=istate]
  ^-  igate-seeds
  ?~  ds  [%& [~ state]]
  =/  d=def  i.ds
  ?.  ?=(%value -.d)  [%| ["recursive group contains a non-gate" ~]]
  =/  gate=expr  val.d
  ?.  |(?=(%gate -.gate) ?=(%gate-wide -.gate))
    [%| ["recursive group contains a non-gate" ~]]
  =/  initial=istate  (reserve-def-caps gate state)
  =/  sam=isample-result
    ?-  -.gate
      %gate       (infer-sample sample.gate env initial)
      %gate-wide  (infer-sample sample.gate env initial)
      *           !!
    ==
  ?:  ?=(%| -.sam)  [%| [p.sam ~]]
  =/  body=expr
    ?-  -.gate
      %gate       body.gate
      %gate-wide  body.gate
      *           !!
    ==
  =/  seed=itype  [%fn typ.p.sam [%var next.state.p.sam]]
  =/  entry=igate-entry  [name.d seed body env.p.sam caps.state.p.sam]
  =/  after=istate  state.p.sam(next +(next.state.p.sam), caps caps.state)
  =/  rest=igate-seeds  $(ds t.ds, state after)
  ?:  ?=(%| -.rest)  rest
  [%& [[entry entries.p.rest] state.p.rest]]
::
++  group-seed-env
  |=  [entries=(list igate-entry) env=ienv]
  ^-  ienv
  ?~  entries  env
  [[name.i.entries [typ.i.entries ~]] $(entries t.entries)]
::
++  infer-gate-group-bodies
  |=  [entries=(list igate-entry) seeds=ienv state=istate]
  ^-  igate-seeds
  ?~  entries  [%& [~ state]]
  =/  entry=igate-entry  i.entries
  ?>  ?=(%fn -.typ.entry)
  =/  scope=ienv  (weld seeds env.entry)
  =/  out=iresult  (infer-fragment body.entry scope state(caps caps.entry))
  ?:  ?=(%| -.out)  out
  =/  uni=(unit isub)  (itype-unify product.typ.entry typ.p.out sub.state.p.out)
  ?~  uni  [%| ["recursive group constraint is not supported by partial inference" ~]]
  =.  caps.entry  caps.state.p.out
  =/  after=istate  state.p.out(sub u.uni, caps caps.state)
  =/  rest=igate-seeds  $(entries t.entries, state after)
  ?:  ?=(%| -.rest)  rest
  [%& [[entry entries.p.rest] state.p.rest]]
::
++  group-schemes
  |=  [entries=(list igate-entry) env=ienv outer=istate state=istate]
  ^-  (each ienv idiag)
  ?~  entries  [%& ~]
  =/  entry=igate-entry  i.entries
  =/  merged=(unit [first=icap second=icap])  (merged-capitals caps.entry sub.state)
  ?^  merged
    [%| ["distinct type variables must not be forced equal" ~[[at.first.u.merged "first type variable"] [at.second.u.merged "second type variable"]]]]
  ?:  (constrained-capitals caps.entry sub.state)
    [%| ["explicit capital constraints are not supported by partial inference" ~]]
  =/  typ=itype  (itype-normalize typ.entry sub.state)
  ?:  (itype-has-nvar typ)  [%| ["recursive group needs unsupported inference" ~]]
  ?:  |((itype-has-tag typ) (itype-has-hidden-generic typ) (itype-has-hidden-recursive typ) (unsupported-atom-vars typ caps.entry binders.state sub.state))
    [%| ["recursive group needs unsupported inference" ~]]
  =/  free=(list @ud)  (weld (free-env-vars env sub.state) (free-cap-vars caps.outer sub.state))
  =/  vars=(list @ud)  (unique-type-vars (itype-vars typ))
  =.  vars  (skim vars |=(n=@ud !(lien free |=(f=@ud =(f n)))))
  ?:  (gth (lent vars) 26)  [%| ["recursive group needs too many type variables" ~]]
  =/  rest=(each ienv idiag)  $(entries t.entries)
  ?:  ?=(%| -.rest)  rest
  [%& [[name.entry [typ vars]] p.rest]]
::
++  infer-gate-group
  |=  [ds=(list def) env=ienv state=istate]
  ^-  ilocal-result
  ?^  defer.state  [%| ["deferred recursive inference is unsupported" ~]]
  =/  names=(list term)  (global-value-names ds)
  ?.  (levy names |=(n=term (unique-value-name n names)))
    [%| ["recursive group contains duplicate names" ~]]
  ?:  (lien names |=(n=term ?=(^ (ienv-lookup n env))))
    [%| ["recursive group shadows a name" ~]]
  =/  scoped=istate  state(globals (weld names globals.state), gate-defs ~)
  =/  seeded=igate-seeds  (seed-gate-group ds env scoped)
  ?:  ?=(%| -.seeded)  seeded
  =/  seeds=ienv  (group-seed-env entries.p.seeded ~)
  =/  body=igate-seeds  (infer-gate-group-bodies entries.p.seeded seeds state.p.seeded)
  ?:  ?=(%| -.body)  body
  ::  Per-member ownership through mutual recursion is not implemented.
  ?:  !=(projections.state.p.body projections.state)
    [%| ["record projection in recursive groups needs unsupported inference" ~]]
  ?:  !=(holes.state.p.body holes.state)
    [%| ["holes in recursive groups need unsupported inference" ~]]
  ?:  (pending-tags tags.state.p.body sub.state.p.body)
    [%| ["recursive group has unresolved literal constraints" ~]]
  =/  schemes=(each ienv idiag)  (group-schemes entries.p.body env state state.p.body)
  ?:  ?=(%| -.schemes)  schemes
  [%& [(weld p.schemes env) state.p.body(globals globals.state)]]
::
++  width-finalize
  |=  [ps=(list iwprojection) sub=isub visible=(list @ud)]
  ^-  (unit (list iwprojection))
  ?~  ps  `~
  ?:  (lien t.ps |=(p=iwprojection =(at.p at.i.ps)))  ~
  =/  src=itype  (default-decimals (itype-normalize source.i.ps sub))
  =/  dst=itype  (default-decimals (itype-normalize target.i.ps sub))
  ?:  |((itype-has-nvar src) (itype-has-nvar dst) (itype-has-tag src) (itype-has-tag dst))  ~
  =/  vars=(list @ud)  (weld (itype-vars src) (itype-vars dst))
  ?.  (levy vars |=(n=@ud (lien visible |=(v=@ud =(n v)))))  ~
  =/  rest=(unit (list iwprojection))  $(ps t.ps)
  ?~  rest  ~
  =/  entry=iwprojection  i.ps
  =.  entry  entry(source src, target dst)
  `[entry u.rest]
::
++  add-supported-defs
  |=  [ds=(list def) all-defs=(list def) checked=(map term def) heads=(unit igate-prelude-evidence) env=ienv molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) at=path prelude=(unit ifile) artifacts=(list iwidth-definition)]
  ^-  [env=ienv artifacts=(list iwidth-definition)]
  (add-supported-defs-core ds all-defs checked heads env molds globals externals surs mark-externals marks jimports reserved-molds at prelude artifacts ~)
::

+$  iresolved  [env=ienv grouped=(list term) artifacts=(list iwidth-definition)]
+$  iadj  (map term (list term))
+$  ivisited  (map term ?)
+$  iwork  (list [name=term done=?])
+$  iwresult  [seen=ivisited order=(list term)]
+$  icresult  [seen=ivisited component=(list term)]
+$  icomponents  (list (list term))
++  graph-nameset
  |=  [names=(list term) seen=ivisited]
  ^-  ivisited
  ?~  names  seen
  $(names t.names, seen (~(put by seen) i.names &))
::
++  graph-edges
  |=  [name=term graph=iadj]
  ^-  (list term)
  =/  found=(unit (list term))  (~(get by graph) name)
  ?~  found  ~
  u.found
::
++  graph-make-forward
  |=  [ds=(list def) names=ivisited graph=iadj]
  ^-  iadj
  ?~  ds  graph
  ?.  ?=(%value -.i.ds)  $(ds t.ds)
  =/  deps=(list term)  (dependency-expr val.i.ds)
  =.  deps  (skim deps |=(n=term ?=(^ (~(get by names) n))))
  $(ds t.ds, graph (~(put by graph) name.i.ds deps))
::
++  graph-add-reverse
  |=  [name=term edges=(list term) reverse=iadj]
  ^-  iadj
  ?~  edges  reverse
  =/  prior=(list term)  (graph-edges i.edges reverse)
  $(edges t.edges, reverse (~(put by reverse) i.edges [name prior]))
::
++  graph-reverse
  |=  [names=(list term) graph=iadj reverse=iadj]
  ^-  iadj
  ?~  names  reverse
  =.  reverse  (graph-add-reverse i.names (graph-edges i.names graph) reverse)
  $(names t.names)
::
++  graph-order
  |=  [todo=iwork seen=ivisited order=(list term) graph=iadj]
  ^-  iwresult
  ?~  todo  [seen order]
  =/  event=[name=term done=?]  i.todo
  ?:  done.event  $(todo t.todo, order [name.event order])
  ?:  ?=(^ (~(get by seen) name.event))  $(todo t.todo)
  =.  seen  (~(put by seen) name.event &)
  =/  children=iwork  (turn (graph-edges name.event graph) |=(n=term [n |]))
  $(todo (weld children [[name.event &] t.todo]))
::
++  graph-collect
  |=  [todo=(list term) seen=ivisited component=(list term) graph=iadj]
  ^-  icresult
  ?~  todo  [seen component]
  ?:  ?=(^ (~(get by seen) i.todo))  $(todo t.todo)
  =.  seen  (~(put by seen) i.todo &)
  $(todo (weld (graph-edges i.todo graph) t.todo), component [i.todo component])
::
++  graph-collect-all
  |=  [order=(list term) seen=ivisited graph=iadj comps=icomponents]
  ^-  icomponents
  ?~  order  comps
  ?:  ?=(^ (~(get by seen) i.order))  $(order t.order)
  =/  found=icresult  (graph-collect ~[i.order] seen ~ graph)
  $(order t.order, seen seen.found, comps [component.found comps])
::
::  Two depth-first passes find components before group inference. Maps
::  preserve the graph identity; duplicate global names fail closed.
++  graph-components
  |=  [ds=(list def) names=(list term)]
  ^-  icomponents
  =/  nameset=ivisited  ~
  =/  pending=(list term)  names
  |-
  ?^  pending
    ?:  ?=(^ (~(get by nameset) i.pending))  ~
    $(pending t.pending, nameset (~(put by nameset) i.pending &))
  =/  graph=iadj  (graph-make-forward ds nameset ~)
  =/  reverse=iadj  (graph-reverse names graph ~)
  =/  order=iwresult  (graph-order (turn names |=(n=term [n |])) ~ ~ graph)
  (graph-collect-all order.order ~ reverse ~)
::
++  graph-cycle
  |=  [component=(list term) graph=iadj]
  ^-  ?
  ?~  component  |
  ?^  t.component  &
  (lien (graph-edges i.component graph) |=(x=term =(x i.component)))
::
++  add-groups
  |=  [ds=(list def) components=icomponents graph=iadj env=ienv grouped=(list term) artifacts=(list iwidth-definition) state=istate]
  ^-  iresolved
  ?~  components  [env grouped artifacts]
  =/  component=(list term)  i.components
  ?.  (graph-cycle component graph)  $(components t.components)
  ?:  (lien component |=(n=term ?=(^ (ienv-lookup n env))))  $(components t.components)
  =/  members=(list def)
    %+  skim  ds
    |=  d=def
    &(?=(%value -.d) (lien component |=(n=term =(n name.d))))
  ?.  =((lent members) (lent component))  $(components t.components)
  ?.  (levy component |=(n=term (unique-value-name n globals.state)))  $(components t.components)
  =/  result=ilocal-result  (infer-gate-group members env state)
  ?:  ?=(%| -.result)  $(components t.components)
  $(components t.components, env env.p.result, grouped (weld component grouped))
::
++  resolve-groups
  |=  [ds=(list def) molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) at=path prelude=(unit ifile)]
  ^-  iresolved
  (resolve-groups-core ds molds globals externals surs mark-externals marks jimports reserved-molds at prelude ~)
::

++  add-supported-defs-core
  |=  [ds=(list def) all-defs=(list def) checked=(map term def) heads=(unit igate-prelude-evidence) env=ienv molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) at=path prelude=(unit ifile) artifacts=(list iwidth-definition) index=(unit [at=path source=@t prelude=ifile shapes=(map term shape)])]
  ^-  [env=ienv artifacts=(list iwidth-definition)]
  ?~  ds  [env artifacts]
  =/  d=def  i.ds
  ?:  ?=(%mold -.d)  $(ds t.ds)
  ?.  (unique-value-name name.d globals)  $(ds t.ds)
  ?^  (ienv-lookup name.d env)  $(ds t.ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  initial=istate  [0 ~ ~ ~ molds globals externals surs mark-externals marks jimports reserved-molds ~ ~ ~ | at top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  =.  grec-index.initial  index
  =.  gate-defs.initial  checked
  =.  head-evidence.initial  heads
  =.  initial  (reserve-def-caps val.d initial)
  =/  result=iresult  (infer-fragment val.d env initial)
  =?  result  ?=(%| -.result)  (infer-recursive-gate d env initial)
  ?:  ?=(%| -.result)  $(ds t.ds)
  =.  state.p.result  (promote-restricted-numbers state.p.result env)
  =.  state.p.result  (default-hole-numbers holes.state.p.result holes.initial state.p.result env !(itype-has-gate (itype-normalize typ.p.result sub.state.p.result)))
  ?^  (unresolved-hole holes.state.p.result holes.initial state.p.result)  $(ds t.ds)
  ?:  (constrained-capitals caps.state.p.result sub.state.p.result)  $(ds t.ds)
  =/  typ=itype  (default-decimals (itype-normalize typ.p.result sub.state.p.result))
  ?:  |((pending-tags tags.state.p.result sub.state.p.result) (itype-has-tag typ))  $(ds t.ds)
  ?:  (unsupported-atom-vars typ caps.state.p.result binders.state.p.result sub.state.p.result)  $(ds t.ds)
  =/  vars=(list @ud)  (unique-type-vars (itype-vars typ))
  ?:  (gth (lent vars) 26)  $(ds t.ds)
  =/  finalized=(unit (list iwprojection))
    (width-finalize projections.state.p.result sub.state.p.result vars)
  ?~  finalized  $(ds t.ds)
  =?  artifacts  ?=(^ u.finalized)
    [[name.d val.d typ sub.state.p.result (flop u.finalized)] artifacts]
  =?  checked  |(?=(%gate -.val.d) ?=(%gate-wide -.val.d))  (~(put by checked) name.d d)
  $(ds t.ds, env [[name.d [typ vars]] env], checked checked)
::
++  resolve-groups-core
  |=  [ds=(list def) molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) at=path prelude=(unit ifile) index=(unit [at=path source=@t prelude=ifile shapes=(map term shape)])]
  ^-  iresolved
  =/  env=ienv  ~
  =/  grouped=(list term)  ~
  =/  artifacts=(list iwidth-definition)  ~
  =/  names=(list term)  (global-value-names ds)
  =/  nameset=ivisited  (graph-nameset names ~)
  =/  graph=iadj  (graph-make-forward ds nameset ~)
  =/  components=icomponents  (graph-components ds names)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  heads=(unit igate-prelude-evidence)  (direct-prelude-evidence ds prelude)
  |-
  =/  next=[env=ienv artifacts=(list iwidth-definition)]
    (add-supported-defs-core ds ds (direct-checked-gates ds env) heads env molds globals externals surs mark-externals marks jimports reserved-molds at prelude artifacts index)
  =/  initial=istate  [0 ~ ~ ~ molds globals externals surs mark-externals marks jimports reserved-molds ~ ~ ~ | at top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  =.  grec-index.initial  index
  =/  out=iresolved  (add-groups ds components graph env.next grouped artifacts.next initial)
  ?:  =(env env.out)  out
  $(env env.out, grouped grouped.out, artifacts artifacts.out)
::
++  resolve-supported-defs
  |=  [ds=(list def) molds=imolds globals=(list term) externals=iexternals surs=(list term) mark-externals=imark-externals marks=(list term) jimports=ijimports reserved-molds=(list term) at=path prelude=(unit ifile)]
  ^-  ienv
  env:(resolve-groups ds molds globals externals surs mark-externals marks jimports reserved-molds at prelude)
::
::  A diagnostic-only proof for a narrow syntactic value cycle. Every
::  edge is an unqualified wing in a supported expression, and samples
::  may not shadow global bindings. Unknown forms yield no conclusion.
+$  icyclesite  [name=term at=span]
+$  icycle  [name=term first=span next=span]
++  cycle-sites-list
  |=  [xs=(list expr) globals=(list term) locals=(list term)]
  ^-  (unit (list icyclesite))
  ?~  xs  `~
  =/  first=(unit (list icyclesite))  (cycle-sites i.xs globals locals)
  ?~  first  ~
  =/  tail=(unit (list icyclesite))  $(xs t.xs)
  ?~  tail  ~
  `(weld u.first u.tail)
::
++  cycle-sample-name
  |=  [sam=sample globals=(list term) locals=(list term)]
  ^-  (unit (unit term))
  ?-  -.sam
    %bind
      ?:  (lien (weld globals locals) |=(n=term =(n name.sam)))  ~
      ``name.sam
    %face
      ?:  (lien (weld globals locals) |=(n=term =(n name.sam)))  ~
      ``name.sam
    %bare  `~
    *      ~
  ==
::
++  cycle-sites
  |=  [e=expr globals=(list term) locals=(list term)]
  ^-  (unit (list icyclesite))
  ?-  -.e
    %wing
      ?.  ?=([@ ~] names.e)  ~
      `~[[i.names.e at.e]]
    %lit  `~
    %str
      ?:  (lien pieces.e |=(p=piece ?=(%expr -.p)))  ~
      `~
    %group  $(e inner.e)
    %body   ?~(defs.e $(e final.e) ~)
    %cast   $(e val.e)
    %gate
      =/  binder=(unit (unit term))  (cycle-sample-name sample.e globals locals)
      ?~  binder  ~
      =/  nested=(list term)  ?~(u.binder locals [u.u.binder locals])
      $(e body.e, locals nested)
    %gate-wide
      =/  binder=(unit (unit term))  (cycle-sample-name sample.e globals locals)
      ?~  binder  ~
      =/  nested=(list term)  ?~(u.binder locals [u.u.binder locals])
      $(e body.e, locals nested)
    %call
      =/  first=(unit (list icyclesite))  $(e head.e)
      ?~  first  ~
      =/  tail=(unit (list icyclesite))  (cycle-sites-list args.e globals locals)
      ?~  tail  ~
      `(weld u.first u.tail)
    *  ~
  ==
::
++  cycle-definitely-atom
  |=  e=expr
  ^-  ?
  ?:  ?=(%group -.e)  $(e inner.e)
  ?:  &(?=(%body -.e) ?=(~ defs.e))  $(e final.e)
  ?.  ?=(%cast -.e)  |
  |(?=(%aura -.shape.e) ?=(%flag -.shape.e))
::
++  cycle-proof-group
  |=  [members=(list def) globals=(list term)]
  ^-  ?
  ?~  members  &
  ?.  ?=(%value -.i.members)  |
  ?.  (unique-value-name name.i.members globals)  |
  ?.  ?=(^ (cycle-sites val.i.members globals ~))  |
  $(members t.members)
::
++  cycle-find-site
  |=  [sites=(list icyclesite) component=(list term)]
  ^-  (unit span)
  ?~  sites  ~
  ?:  (lien component |=(n=term =(n name.i.sites)))  `at.i.sites
  $(sites t.sites)
::
++  cycle-group-errors
  |=  [members=(list def) component=(list term) globals=(list term)]
  ^-  (list icycle)
  ?~  members  ~
  =/  d=def  i.members
  ?>  ?=(%value -.d)
  =/  tail=(list icycle)  $(members t.members)
  ?.  (cycle-definitely-atom val.d)  tail
  =/  sites=(unit (list icyclesite))  (cycle-sites val.d globals ~)
  ?~  sites  tail
  =/  found=(unit span)  (cycle-find-site u.sites component)
  ?~  found  tail
  [[name.d at.d u.found] tail]
::
++  definite-value-cycles
  |=  [ds=(list def) globals=(list term)]
  ^-  (list icycle)
  =/  names=(list term)  (global-value-names ds)
  =/  graph=iadj  (graph-make-forward ds (graph-nameset names ~) ~)
  =/  components=icomponents  (graph-components ds names)
  =/  out=(list icycle)  ~
  |-
  ?~  components  out
  =/  component=(list term)  i.components
  ?.  (graph-cycle component graph)  $(components t.components)
  =/  members=(list def)
    (skim ds |=(d=def &(?=(%value -.d) (lien component |=(n=term =(n name.d))))))
  ?.  =((lent members) (lent component))  $(components t.components)
  ?.  (cycle-proof-group members globals)  $(components t.components)
  $(components t.components, out (weld (cycle-group-errors members component globals) out))
::
+|  %union-analysis
::
::  A conservative projection of written molds onto noun shapes. The
::  result %unknown never establishes either overlap or disjointness.
::  Gates, applications, imports and recursive references stay unknown;
::  another position in a cell may nevertheless prove two cases apart.
::
+$  upat
  $~  [%unknown ~]
  $%  [%unknown ~]
      [%all ~]
      [%empty ~]
      [%atom val=(unit @)]
      [%flag ~]
      [%cell hed=upat tal=upat]
      [%or alts=(list upat)]
  ==
+$  urelation  ?(%disjoint %overlap %unknown)
+$  upair  [first=span second=span relation=urelation]
::
++  project-union-mold
  |=  [sh=shape molds=imolds seen=(list term)]
  ^-  upat
  ?-  -.sh
    %aura   [%atom ~]
    %noun   [%all ~]
    %tvar   [%all ~]
    %void   [%empty ~]
    ::  ? is its two atoms, 0 and 1 (Decisions 2026-10-30).
    %flag   [%flag ~]
    %const  [%atom `val.lit.sh]
    %cell   (project-union-fields fields.sh molds seen)
    %union  [%or (turn cases.sh |=(x=shape (project-union-mold x molds seen)))]
    %ref
      ?~  names.sh  [%unknown ~]
      ?^  t.names.sh  [%unknown ~]
      =/  n=term  i.names.sh
      ?:  (lien seen |=(x=term =(x n)))  [%unknown ~]
      =/  found=(unit shape)  (find-simple-mold n molds)
      ?~  found  [%unknown ~]
      $(sh u.found, seen [n seen])
    *  [%unknown ~]
  ==
::
++  project-union-fields
  |=  [fields=(list field) molds=imolds seen=(list term)]
  ^-  upat
  ?~  fields  [%unknown ~]
  =/  head=upat
    ?-  -.i.fields
      %bare  (project-union-mold shape.i.fields molds seen)
      %face  (project-union-mold shape.i.fields molds seen)
      %pun   (project-union-mold [%ref at.i.fields ~[name.i.fields]] molds seen)
    ==
  ?~  t.fields  head
  [%cell head $(fields t.fields)]
::
++  union-inhabited
  |=  p=upat
  ^-  urelation
  ?-  -.p
    %unknown  %unknown
    %empty    %disjoint
    %all      %overlap
    %atom     %overlap
    %flag     %overlap
    %cell
      =/  a=urelation  $(p hed.p)
      =/  b=urelation  $(p tal.p)
      ?:  |(=(%disjoint a) =(%disjoint b))  %disjoint
      ?:  |(=(%unknown a) =(%unknown b))  %unknown
      %overlap
    %or
      =/  alts=(list upat)  alts.p
      =/  result=urelation  %disjoint
      |-
      ?~  alts  result
      =/  r=urelation  (union-inhabited i.alts)
      ?:  =(%overlap r)  %overlap
      $(alts t.alts, result ?:(=(%unknown r) %unknown result))
  ==
::
++  union-relate-alts
  |=  [alts=(list upat) b=upat]
  ^-  urelation
  =/  result=urelation  %disjoint
  |-
  ?~  alts  result
  =/  r=urelation  (union-relate i.alts b)
  ?:  =(%overlap r)  %overlap
  $(alts t.alts, result ?:(=(%unknown r) %unknown result))
::
++  union-relate
  |=  [a=upat b=upat]
  ^-  urelation
  ?:  |(?=(%empty -.a) ?=(%empty -.b))  %disjoint
  ?:  ?=(%or -.a)  (union-relate-alts alts.a b)
  ?:  ?=(%or -.b)  (union-relate-alts alts.b a)
  ?:  ?=(%all -.a)  (union-inhabited b)
  ?:  ?=(%all -.b)  (union-inhabited a)
  ?:  |(?=(%unknown -.a) ?=(%unknown -.b))  %unknown
  ?:  |(&(?=(%cell -.a) |(?=(%atom -.b) ?=(%flag -.b))) &(?=(%cell -.b) |(?=(%atom -.a) ?=(%flag -.a))))
    %disjoint
  ?:  &(?=(%flag -.a) ?=(%flag -.b))  %overlap
  ?:  &(?=(%flag -.a) ?=(%atom -.b))
    ?~  val.b  %overlap
    ?:(|(=(0 u.val.b) =(1 u.val.b)) %overlap %disjoint)
  ?:  &(?=(%atom -.a) ?=(%flag -.b))
    ?~  val.a  %overlap
    ?:(|(=(0 u.val.a) =(1 u.val.a)) %overlap %disjoint)
  ?:  &(?=(%atom -.a) ?=(%atom -.b))
    ?~  val.a  %overlap
    ?~  val.b  %overlap
    ?:(=(u.val.a u.val.b) %overlap %disjoint)
  ?:  &(?=(%cell -.a) ?=(%cell -.b))
    =/  x=urelation  $(a hed.a, b hed.b)
    =/  y=urelation  $(a tal.a, b tal.b)
    ?:  |(=(%disjoint x) =(%disjoint y))  %disjoint
    ?:  |(=(%unknown x) =(%unknown y))  %unknown
    %overlap
  %unknown
::
++  union-pairs
  |=  [cases=(list shape) molds=imolds]
  ^-  (list upair)
  ?~  cases  ~
  =/  first=shape  i.cases
  =/  a=upat  (project-union-mold first molds ~)
  =/  pairs=(list upair)
    %+  turn  t.cases
    |=  second=shape
    ^-  upair
    [at.first at.second (union-relate a (project-union-mold second molds ~))]
  (weld pairs $(cases t.cases))
::
::  A closed structural mold supplies no equation to determine a hole.
::  Applications, references, unbound capitals and unions are unproved.
++  simple-mold-hole
  |=  sh=shape
  ^-  (unit (unit span))
  ?:  ?=(%generic -.sh)
    ?~  vars.sh  ~
    ?.  (distinct-params vars.sh)  ~
    (simple-mold-hole-in body.sh vars.sh)
  (simple-mold-hole-in sh ~)
++  simple-mold-hole-in
  |=  [sh=shape vars=(list @t)]
  ^-  (unit (unit span))
  ?-  -.sh
    %hole  ``at.sh
    ?(%aura %noun %void %flag %const)  `~
    %tvar  ?:((lien vars |=(v=@t =(v name.sh))) `~ ~)
    %cell  (simple-mold-field-holes fields.sh vars)
    %fn
      =/  a=(unit (unit span))  $(sh sample.sh)
      ?~  a  ~
      =/  b=(unit (unit span))  $(sh product.sh)
      ?~  b  ~
      `?~(u.a u.b u.a)
    %generic  ~
    *  ~
  ==
++  simple-mold-field-holes
  |=  [fields=(list field) vars=(list @t)]
  ^-  (unit (unit span))
  ?~  fields  `~
  =/  f=field  i.fields
  =/  first=(unit (unit span))
    ?-  -.f
      %face  (simple-mold-hole-in shape.f vars)
      %bare  (simple-mold-hole-in shape.f vars)
      %pun   ~
    ==
  ?~  first  ~
  =/  rest=(unit (unit span))  $(fields t.fields)
  ?~  rest  ~
  `?~(u.first u.rest u.first)
++  simple-local-mold-hole
  |=  defs=(list def)
  ^-  (unit span)
  ?~  defs  ~
  ?.  ?=(%mold -.i.defs)  $(defs t.defs)
  =/  found=(unit (unit span))  (simple-mold-hole shape.i.defs)
  ?~  found  $(defs t.defs)
  ?^  u.found  u.found
  $(defs t.defs)
::
::  A partial prelude may omit unsupported declarations, but may not
::  publish an interface while a named mold's hole remains unchecked.
++  shape-has-hole
  |=  sh=shape
  ^-  ?
  ?-  -.sh
    %hole  &
    %path  (lien segs.sh |=(s=pseg ?=(%inferred -.s)))
    %apply  (lien args.sh shape-has-hole)
    %union  (lien cases.sh shape-has-hole)
    %cell  (lien fields.sh field-has-hole)
    %fn  |($(sh sample.sh) $(sh product.sh))
    %generic  $(sh body.sh)
    *  |
  ==
++  field-has-hole
  |=  f=field
  ^-  ?
  ?-  -.f
    %face  (shape-has-hole shape.f)
    %bare  (shape-has-hole shape.f)
    %pun   |
  ==
++  named-mold-has-hole
  |=  ds=(list def)
  ^-  ?
  ?~  ds  |
  ?:  &(?=(%mold -.i.ds) (shape-has-hole shape.i.ds))  &
  $(ds t.ds)
::
++  sample-has-hole
  |=  sam=sample
  ^-  ?
  ?-  -.sam
    %face  (shape-has-hole shape.sam)
    %bare  (shape-has-hole shape.sam)
    %cell  (lien items.sam sample-has-hole)
    *  |
  ==
++  def-has-hole
  |=  d=def
  ^-  ?
  ?-  -.d
    %mold   (shape-has-hole shape.d)
    %value  (expr-has-hole val.d)
  ==
++  expr-has-hole
  |=  e=expr
  ^-  ?
  ?-  -.e
    %str  (lien pieces.e |=(p=piece ?:(?=(%expr -.p) (expr-has-hole p.p) |)))
    %qath  (lien segs.e |=(p=qseg ?:(?=(%expr -.p) (expr-has-hole p.p) |)))
    %change  (lien edits.e |=(p=edit (expr-has-hole val.p)))
    %pair  $(e val.e)
    %unit  $(e val.e)
    %group  $(e inner.e)
    %list  (lien items.e expr-has-hole)
    %tuple  (lien items.e |=(i=item (expr-has-hole val.i)))
    ?(%gate %gate-wide)  |((sample-has-hole sample.e) $(e body.e))
    %cast  |((shape-has-hole shape.e) $(e val.e))
    %call  |($(e head.e) (lien args.e expr-has-hole))
    %trace  |($(e val.e) $(e then.e))
    %branch  |($(e subject.e) (lien arms.e |=(a=arm (expr-has-hole val.a))))
    %body  |((lien defs.e def-has-hole) $(e final.e))
    *  |
  ==
++  hole-values-present
  |=  [ds=(list def) env=ienv]
  ^-  ?
  ?~  ds  &
  ?.  ?=(%value -.i.ds)  $(ds t.ds)
  ?:  (expr-has-hole val.i.ds)
    ?.  ?=(^ (ienv-lookup name.i.ds env))  |
    $(ds t.ds)
  $(ds t.ds)
++  show-partial-mold
  |=  [file=path src=@t d=def molds=imolds]
  ^-  @t
  ?>  ?=(%mold -.d)
  =/  sh=shape  shape.d
  =/  hole=(unit (unit span))  (simple-mold-hole sh)
  ?:  &(?=(^ hole) ?=(^ u.hole))
    =/  text=@t  (show-error src [file line.beg.u.u.hole col.beg.u.u.hole "unresolved type hole"])
    (of-wain:format ~[(crip "+$ {(trip name.d)}: type hole needs a determined type") text])
  =?  sh  ?=(%generic -.sh)  body.sh
  ?.  ?=(%union -.sh)  (crip "+$ {(trip name.d)}: not checked")
  =/  pairs=(list upair)  (union-pairs cases.sh molds)
  =/  overlapping=(list upair)  (skim pairs |=(p=upair =(%overlap relation.p)))
  ?^  overlapping
    =/  p=upair  i.overlapping
    =/  summary=@t  (crip "+$ {(trip name.d)}: overlapping cases; mold not checked")
    =/  first=@t  (show-error src [file line.beg.first.p col.beg.first.p "first union case"])
    =/  second=@t  (show-error src [file line.beg.second.p col.beg.second.p "overlapping case"])
    (of-wain:format ~[summary first second])
  ?:  (lien pairs |=(p=upair =(%unknown relation.p)))
    (crip "+$ {(trip name.d)}: case disjointness unresolved; mold not checked")
  (crip "+$ {(trip name.d)}: cases proven disjoint; mold not checked")
::
::  +show-inference-diagnostic: a partial report with both source sites
::
++  show-inference-diagnostic
  |=  [file=path src=@t name=term diagnostic=idiag]
  ^-  @t
  =/  summary=@t  (crip "++ {(trip name)}: {msg.diagnostic}")
  =/  excerpts=(list @t)
    %+  turn  sites.diagnostic
    |=  site=[at=span note=tape]
    (show-error src [file line.beg.at.site col.beg.at.site note.site])
  (of-wain:format [summary excerpts])
::
::  Both written field sites are shown in the source that declares them.
++  show-duplicate-fields
  |=  [file=path src=@t diagnostic=idiag]
  ^-  @t
  =/  excerpts=(list @t)
    %+  turn  sites.diagnostic
    |=  site=[at=span note=tape]
    (show-error src [file line.beg.at.site col.beg.at.site note.site])
  (of-wain:format [(crip msg.diagnostic) excerpts])
::
++  duplicate-fields-report
  |=  [file=path src=@t diagnostic=idiag]
  ^-  @t
  (of-wain:format ~['partial inference; module not checked' (show-duplicate-fields file src diagnostic)])
::
::  +golden-types: a partial report; it does not claim the module checks
::
++  golden-types
  |=  [file=path src=@t]
  ^-  @t
  (golden-types-imports file src ~)
::
::  +golden-types-imports: partial inference with caller-supplied /sur types
::
::    Each entry is [module mold result], where result is exactly the
::    noun returned by +read-mold:jibb-import. Only imports declared with
::    /- are visible. Unrecognized or failed results are unsupported.
::
++  golden-types-imports
  |=  [file=path src=@t externals=iexternals]
  ^-  @t
  (golden-types-with-marks file src externals ~)
::
::  A supplied module is addressed by its logical /ui/.../name/jibb path.
::  Interfaces are closed inference schemes, never raw source shapes.
::  Recursive modules, APIs, derived gates and unsupported definitions do
::  not yield an interface. The reachable graph is checked before the root.
::
+$  jsource  [at=path source=@t]
+$  jbundle  (list jsource)
+$  jcache  (list [at=path iface=ifile])
+$  jfile-result  (each [iface=ifile cache=jcache] @t)
+$  jimports-result  (each [resolved=ijimports cache=jcache] @t)
::
::  Written record fields each have their own lexical record scope.
+$  written-fields  (map term span)
++  duplicate-written-field
  |=  [name=term at=span seen=written-fields]
  ^-  (unit idiag)
  =/  prior=(unit span)  (~(get by seen) name)
  ?~  prior  ~
  `["record field `{(trip name)}` is repeated" ~[[u.prior "first field"] [at "repeated field"]]]
++  duplicate-shapes
  |=  xs=(list shape)
  ^-  (unit idiag)
  ?~  xs  ~
  =/  first  (duplicate-shape i.xs)
  ?^  first  first
  $(xs t.xs)
++  duplicate-fields
  |=  [fields=(list field) seen=written-fields]
  ^-  (unit idiag)
  ?~  fields  ~
  =/  f=field  i.fields
  =/  n=(unit term)
    ?-  -.f
      %face  `name.f
      %pun   `name.f
      %bare  ~
    ==
  =/  dup=(unit idiag)  ?~(n ~ (duplicate-written-field u.n at.f seen))
  ?^  dup  dup
  =/  inner=(unit idiag)
    ?-  -.f
      %face  (duplicate-shape shape.f)
      %pun   ~
      %bare  (duplicate-shape shape.f)
    ==
  ?^  inner  inner
  $(fields t.fields, seen ?~(n seen (~(put by seen) u.n at.f)))
++  duplicate-shape
  |=  s=shape
  ^-  (unit idiag)
  ?-  -.s
    %cell  (duplicate-fields fields.s ~)
    %apply  (duplicate-shapes args.s)
    %union  (duplicate-shapes cases.s)
    %fn
      =/  left  (duplicate-shape sample.s)
      ?^  left  left
      (duplicate-shape product.s)
    %generic  (duplicate-shape body.s)
    *  ~
  ==
++  duplicate-samples
  |=  [items=(list sample) seen=written-fields]
  ^-  (unit idiag)
  ?~  items  ~
  =/  a=sample  i.items
  =/  n=(unit term)
    ?-  -.a
      %bind  `name.a
      %face  `name.a
      %pun   `name.a
      *      ~
    ==
  =/  dup=(unit idiag)  ?~(n ~ (duplicate-written-field u.n at.a seen))
  ?^  dup  dup
  =/  inner  (duplicate-sample a)
  ?^  inner  inner
  $(items t.items, seen ?~(n seen (~(put by seen) u.n at.a)))
++  duplicate-sample
  |=  s=sample
  ^-  (unit idiag)
  ?-  -.s
    %cell  (duplicate-samples items.s ~)
    %face  (duplicate-shape shape.s)
    %bare  (duplicate-shape shape.s)
    *  ~
  ==
++  duplicate-exprs
  |=  xs=(list expr)
  ^-  (unit idiag)
  ?~  xs  ~
  =/  first  (duplicate-expr i.xs)
  ?^  first  first
  $(xs t.xs)
++  duplicate-items
  |=  [items=(list item) seen=written-fields]
  ^-  (unit idiag)
  ?~  items  ~
  =/  a=item  i.items
  =/  dup=(unit idiag)  ?~(face.a ~ (duplicate-written-field u.face.a at.a seen))
  ?^  dup  dup
  =/  inner  (duplicate-expr val.a)
  ?^  inner  inner
  $(items t.items, seen ?~(face.a seen (~(put by seen) u.face.a at.a)))
++  duplicate-pieces
  |=  pieces=(list piece)
  ^-  (unit idiag)
  ?~  pieces  ~
  =/  first=(unit idiag)  ?:(?=(%expr -.i.pieces) (duplicate-expr p.i.pieces) ~)
  ?^  first  first
  $(pieces t.pieces)
++  duplicate-qsegs
  |=  segs=(list qseg)
  ^-  (unit idiag)
  ?~  segs  ~
  =/  first=(unit idiag)  ?:(?=(%expr -.i.segs) (duplicate-expr p.i.segs) ~)
  ?^  first  first
  $(segs t.segs)
++  duplicate-edits
  |=  edits=(list edit)
  ^-  (unit idiag)
  ?~  edits  ~
  =/  first  (duplicate-expr val.i.edits)
  ?^  first  first
  $(edits t.edits)
++  duplicate-arms
  |=  arms=(list arm)
  ^-  (unit idiag)
  ?~  arms  ~
  =/  first  (duplicate-expr val.i.arms)
  ?^  first  first
  $(arms t.arms)
++  duplicate-defs
  |=  defs=(list def)
  ^-  (unit idiag)
  ?~  defs  ~
  =/  first=(unit idiag)
    ?-  -.i.defs
      %mold   (duplicate-shape shape.i.defs)
      %value  (duplicate-expr val.i.defs)
    ==
  ?^  first  first
  $(defs t.defs)
++  duplicate-expr
  |=  e=expr
  ^-  (unit idiag)
  ?-  -.e
    %str  (duplicate-pieces pieces.e)
    %qath  (duplicate-qsegs segs.e)
    %change  (duplicate-edits edits.e)
    %pair  (duplicate-expr val.e)
    %unit  (duplicate-expr val.e)
    %group  (duplicate-expr inner.e)
    %list  (duplicate-exprs items.e)
    %tuple  (duplicate-items items.e ~)
    %gate-wide
      =/  first  (duplicate-sample sample.e)
      ?^  first  first
      (duplicate-expr body.e)
    %gate
      =/  first  (duplicate-sample sample.e)
      ?^  first  first
      (duplicate-expr body.e)
    %cast
      =/  first  (duplicate-shape shape.e)
      ?^  first  first
      (duplicate-expr val.e)
    %call
      =/  first  (duplicate-expr head.e)
      ?^  first  first
      (duplicate-exprs args.e)
    %trace
      =/  first  (duplicate-expr val.e)
      ?^  first  first
      (duplicate-expr then.e)
    %branch
      =/  first  (duplicate-expr subject.e)
      ?^  first  first
      (duplicate-arms arms.e)
    %body
      =/  first  (duplicate-defs defs.e)
      ?^  first  first
      (duplicate-expr final.e)
    *  ~
  ==
++  import-binding-names
  |=  imports=(list import)
  ^-  (list term)
  ?~  imports  ~
  =/  n=term
    ?-  -.i.imports
      %jibb  face.i.imports
      %sur   name.i.imports
      %mark  mark.i.imports
    ==
  [n $(imports t.imports)]
::
++  reserved-proj-sample
  |=  sam=sample
  ^-  ?
  ?-  -.sam
    %bind  =(name.sam %proj)
    %face  =(name.sam %proj)
    %pun   =(name.sam %proj)
    %cell  (lien items.sam reserved-proj-sample)
    *  |
  ==
++  reserved-proj-pattern
  |=  p=pattern
  ^-  ?
  ?-  -.p
    %bind  =(name.p %proj)
    %cell  (lien items.p reserved-proj-pattern)
    *  |
  ==
++  reserved-proj-def
  |=  d=def
  ^-  ?
  ?:  =(name.d %proj)  &
  ?:  ?=(%value -.d)  (reserved-proj-expr val.d)
  |
++  reserved-proj-expr
  |=  e=expr
  ^-  ?
  ?-  -.e
    %str  (lien pieces.e |=(p=piece ?:(?=(%expr -.p) (reserved-proj-expr p.p) |)))
    %qath  (lien segs.e |=(p=qseg ?:(?=(%expr -.p) (reserved-proj-expr p.p) |)))
    %change  (lien edits.e |=(p=edit (reserved-proj-expr val.p)))
    %pair  $(e val.e)
    %unit  $(e val.e)
    %group  $(e inner.e)
    %list  (lien items.e reserved-proj-expr)
    %tuple  (lien items.e |=(i=item (reserved-proj-expr val.i)))
    ?(%gate %gate-wide)  |((reserved-proj-sample sample.e) $(e body.e))
    %cast  $(e val.e)
    %call  |($(e head.e) (lien args.e reserved-proj-expr))
    %trace  |($(e val.e) $(e then.e))
    %branch  |($(e subject.e) (lien arms.e |=(a=arm |((reserved-proj-pattern pat.a) (reserved-proj-expr val.a)))))
    %body  |((lien defs.e reserved-proj-def) $(e final.e))
    *  |
  ==
::
++  module-has-reserved-proj
  |=  mod=module
  ^-  ?
  =/  imported=(list term)  (import-binding-names imports.mod)
  =/  vals=(list term)  (global-value-names defs.mod)
  =/  molds=imolds  (collect-simple-molds defs.mod)
  =/  mold-names=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  |((lien (weld imported (weld vals mold-names)) |=(n=term =(n %proj))) (lien defs.mod reserved-proj-def))
::
++  module-scope-valid
  |=  [mod=module prelude-values=(list term) prelude-molds=(list term)]
  ^-  ?
  =/  imported=(list term)  (import-binding-names imports.mod)
  =/  vals=(list term)  (global-value-names defs.mod)
  =/  molds=imolds  (collect-simple-molds defs.mod)
  =/  mold-names=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  ?:  (module-has-reserved-proj mod)  |
  ?.  %+  levy  imported
      |=  n=term
      &((unique-value-name n imported) !(lien vals |=(v=term =(n v))) !(lien mold-names |=(m=term =(n m))) !(lien prelude-values |=(v=term =(n v))) !(lien prelude-molds |=(m=term =(n m))))
    |
  ?.  (levy vals |=(n=term &((unique-value-name n vals) !(lien prelude-values |=(v=term =(n v))))))  |
  (levy mold-names |=(n=term &((unique-value-name n mold-names) !(lien prelude-molds |=(m=term =(n m))))))
::
::  In an API file or before main's kind is known, a lone `+$ poke`
::  may be a declaration rather than a mold that shadows the prelude. Do not call
::  that one collision definite, and do not hide unrelated scope errors.
++  pending-declared-poke
  |=  [at=path mod=module prelude-values=(list term) prelude-molds=(list term)]
  ^-  ?
  ?.  (lien prelude-molds |=(n=term =(%poke n)))  |
  ?.  |(?=([%ui %api @ %jibb ~] at) (lien defs.mod |=(d=def &(?=(%value -.d) =(%main name.d)))))  |
  =/  pokes=(list def)
    (skim defs.mod |=(d=def &(?=(%mold -.d) =(%poke name.d))))
  ?~  pokes  |
  ?^  t.pokes  |
  =/  remaining=(list def)
    (skim defs.mod |=(d=def !&(?=(%mold -.d) =(%poke name.d))))
  (module-scope-valid mod(defs remaining) prelude-values prelude-molds)
::
++  module-mold-types
  |=  [molds=imolds state=istate]
  ^-  (each imold-types @t)
  ?~  molds  [%& ~]
  =/  m=[name=term body=shape]  i.molds
  =/  t=(unit [template=ischeme state=istate])
    (infer-mold-template body.m state(active [name.m active.state], in-mold &))
  ?~  t  [%| 'module mold needs unsupported inference']
  =.  typ.template.u.t  (label-direct-union typ.template.u.t body.m name.m state)
  =/  rest=(each imold-types @t)  $(molds t.molds)
  ?:  ?=(%| -.rest)  rest
  [%& [[name.m template.u.t] p.rest]]
::
::  Prepare a provisional interface from the trusted vendored source.
::  Every declared name remains reserved, but only molds and values this
::  fragment can infer are usable. Unsupported bodies are not validated.
::  An optional internal source supplies the prelude's one supported import;
::  clients cannot import that path directly. Named unions retain their origin.
::
::  Recognize only the complete standard prelude list shape. Its recursive
::  tail uses the same parameter and the unqualified list name. The reader
::  verifies Hoon's list provenance before producing the same collection type.
::  The prelude source and reader output are trusted caller inputs.
::
++  standard-prelude-list
  |=  sh=shape
  ^-  ?
  ?.  ?=(%generic -.sh)  |
  ?~  vars.sh  |
  ?^  t.vars.sh  |
  =/  var=@t  i.vars.sh
  ?.  ?=(%union -.body.sh)  |
  =/  cs=(list shape)  cases.body.sh
  ?~  cs  |
  ?~  t.cs  |
  ?^  t.t.cs  |
  ?.  ?=(%const -.i.cs)  |
  ?.  =(%null form.lit.i.cs)  |
  ?.  ?=(%cell -.i.t.cs)  |
  =/  fs=(list field)  fields.i.t.cs
  ?~  fs  |
  ?~  t.fs  |
  ?^  t.t.fs  |
  ?.  ?=(%face -.i.fs)  |
  ?.  =(%i name.i.fs)  |
  ?.  ?=(%tvar -.shape.i.fs)  |
  ?.  =(var name.shape.i.fs)  |
  ?.  ?=(%face -.i.t.fs)  |
  ?.  =(%t name.i.t.fs)  |
  =/  tail=shape  shape.i.t.fs
  ?.  ?=(%apply -.tail)  |
  ?.  =(~[%list] ref.tail)  |
  ?~  args.tail  |
  ?^  t.args.tail  |
  ?.  ?=(%tvar -.i.args.tail)  |
  =(var name.i.args.tail)
::
++  prelude-label
  |=  [typ=itype name=term vars=(list @ud)]
  ^-  itype
  ?:  ?=(%jrec -.typ)  typ(label `name)
  ?:  ?=(%grec -.typ)
    ?.  (identity-union-parameters vars args.typ)  typ(label ~)
    typ(label `name)
  ?.  ?=(%union -.typ)  typ
  ?.  (identity-union-parameters vars args.typ)
    ?~  origin.typ  typ
    ?:  =(at.u.origin.typ /lib/jibb/internal/jibb)  typ(label ~)
    typ
  typ(label `name)
::
++  partial-prelude-molds
  |=  [molds=imolds state=istate]
  ^-  imold-types
  ?~  molds  ~
  =/  m=[name=term body=shape]  i.molds
  ?:  &(=(at.state /lib/jibb/prelude/jibb) =(%list name.m))
    ?.  (standard-prelude-list body.m)  $(molds t.molds)
    [[%list [[%collection %list ~[[%var 0]]] ~[0]]] $(molds t.molds)]
  =/  out=(unit [template=ischeme state=istate])
    (infer-mold-template body.m state(active [name.m active.state], in-mold &))
  ?~  out  $(molds t.molds)
  =.  typ.template.u.out  (label-direct-union typ.template.u.out body.m name.m state)
  =.  typ.template.u.out  (prelude-label typ.template.u.out name.m vars.template.u.out)
  [[name.m template.u.out] $(molds t.molds)]
::
::  A compiler-owned interface available only to the dedicated
::  internal-prelude preparation path, never the ordinary module resolver.
++  private-primitive-interface
  ^-  ifile
  =/  a=itype  [%avar 0]
  =/  pair=itype  [%cell a a]
  =/  b=itype  [%rvar 0]
  =/  plus=ischeme  [[%fn [%cell b b] b] ~[0]]
  =/  minus=ischeme  [[%fn b b] ~[0]]
  =/  greater=ischeme  [[%fn pair [%flag ~]] ~[0]]
  [~[[%raw-add plus] [%raw-dec minus] [%raw-gth greater]] ~ /lib/jibb/primitives/jibb ~ ~ ~ ~ ~]
::
++  infer-private-internal
  |=  [src=@t public-source=@t]
  ^-  (unit ifile)
  =/  at=path  /lib/jibb/internal/jibb
  =/  parsed  (parse at src)
  ?:  ?=(%| -.parsed)  ~
  =/  mod=module  p.parsed
  ?^  (duplicate-defs defs.mod)  ~
  ?~  imports.mod
    =/  built=jfile-result  (infer-jibb-file at src ~ ~ ~ ~[at] ~ ~ ~ ~)
    ?:  ?=(%| -.built)  ~
    `iface.p.built
  ?.  ?=([[%jibb *] ~] imports.mod)  ~
  ?.  =(path.i.imports.mod /lib/jibb/primitives)  ~
  ?.  (module-scope-valid mod ~ ~)  ~
  =/  vals=(list term)  (global-value-names defs.mod)
  ?:  (lien vals |=(n=term =(n %main)))  ~
  =/  molds=imolds  (collect-simple-molds defs.mod)
  =/  globals=(list term)  (weld (import-binding-names imports.mod) vals)
  ::  The private source can use the public list and unit molds before the
  ::  prelude is otherwise prepared.  Re-read the trusted public source here
  ::  and admit only its validated canonical templates; do not accept schemes
  ::  supplied independently by the caller.
  =/  public=(each module error)  (parse /lib/jibb/prelude/jibb public-source)
  ?:  ?=(%| -.public)  ~
  ?^  (duplicate-defs defs.p.public)  ~
  ?.  (module-scope-valid p.public ~ ~)  ~
  =/  source-molds=imolds  (collect-simple-molds defs.p.public)
  =/  written-list=(unit shape)  (find-simple-mold %list source-molds)
  =/  source-list=(unit ischeme)
    ?~  written-list  ~
    ?.  (standard-prelude-list u.written-list)  ~
    `[[%collection %list ~[[%var 0]]] ~[0]]
  ::  Derive the public unit template from its actual source, then compare
  ::  the complete nominal template before making it available privately.
  =/  unit-decl=(unit shape)  (find-simple-mold %unit source-molds)
  =/  source-unit=(unit ischeme)
    ?~  unit-decl  ~
    =/  unit-molds=imolds  ~[[%unit u.unit-decl]]
    =/  unit-state=istate  [0 ~ ~ ~ unit-molds ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ | /lib/jibb/prelude/jibb ~[%unit] ~ ~ 256 ~ ~ ~ ~ ~ ~]
    =/  unit-types=imold-types  (partial-prelude-molds unit-molds unit-state)
    =/  unit-iface=ifile  [~ unit-types /lib/jibb/prelude/jibb ~ ~ ~ ~ ~]
    =/  found=(unit ischeme)  (find-jibb-mold %unit unit-iface)
    ?~  found  ~
    ?.  (standard-unit-template u.found /lib/jibb/prelude/jibb)  ~
    found
  =/  primitive=ifile  private-primitive-interface
  =?  primitive  ?=(^ source-list)
    primitive(molds [[%list u.source-list] molds.primitive])
  =?  primitive  ?=(^ source-unit)
    primitive(molds [[%unit u.source-unit] molds.primitive])
  =/  js=ijimports  ~[[face.i.imports.mod primitive]]
  =/  reserved=(list term)  ~[face.i.imports.mod]
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  state=istate  [0 ~ ~ ~ molds globals ~ ~ ~ ~ js reserved ~ ~ ~ | at top ~ ~ 256 ~ ~ ~ ~ ~ ~]
  =/  mts=(each imold-types @t)  (module-mold-types molds state)
  =/  usable=(unit imold-types)
    ?:  ?=(%& -.mts)  `p.mts
    ::  Missing public templates may make an unrelated internal mold
    ::  unavailable.  Validate all molds once with isolated canonical
    ::  templates before admitting only those inferred using the actual
    ::  source-backed templates.  The proof interface is never exported.
    ?.  |(?=(~ source-list) ?=(~ source-unit))  ~
    =/  nil=itype  [%const [%null %n 0 '~']]
    =/  canonical-unit=ischeme
      [[%union ~[nil [%cell nil [%face %u [%var 0]]]] `[/lib/jibb/prelude/jibb %unit] `%unit ~[[%var 0]]] ~[0]]
    =/  canonical-list=ischeme  [[%collection %list ~[[%var 0]]] ~[0]]
    =/  proof-primitive=ifile  private-primitive-interface
    =.  molds.proof-primitive  ~[[%list canonical-list] [%unit canonical-unit]]
    =/  proof-imports=ijimports  ~[[face.i.imports.mod proof-primitive]]
    =/  proof=(each imold-types @t)  (module-mold-types molds state(jimports proof-imports))
    ?:  ?=(%| -.proof)  ~
    `(partial-prelude-molds molds state)
  ?~  usable  ~
  =/  resolution=iresolved  (resolve-groups defs.mod molds globals ~ ~ ~ ~ js reserved at ~)
  =/  env=ienv  env.resolution
  ?.  (module-values-complete defs.mod env)  ~
  `[env u.usable at ~ artifacts.resolution ~ `src ~]
::
++  partial-prelude-interface-with-internal
  |=  [src=@t internal-source=(unit @t)]
  ^-  (unit ifile)
  ?:  =(0 src)  ~
  =/  at=path  /lib/jibb/prelude/jibb
  =/  parsed  (parse at src)
  ?:  ?=(%| -.parsed)  ~
  ?:  (named-mold-has-hole defs.p.parsed)  ~
  ?^  (duplicate-defs defs.p.parsed)  ~
  =/  private=(unit ijimports)
    ?~  imports.p.parsed  `~
    ?.  ?=([[%jibb *] ~] imports.p.parsed)  ~
    ?.  =(path.i.imports.p.parsed /lib/jibb/internal)  ~
    ?~  internal-source  ~
    =/  built=(unit ifile)  (infer-private-internal u.internal-source src)
    ?~  built  ~
    `~[[face.i.imports.p.parsed u.built]]
  ?~  private  ~
  ?~  defs.p.parsed  ~
  ?.  (module-scope-valid p.parsed ~ ~)  ~
  =/  ds=(list def)  defs.p.parsed
  =/  molds=imolds  (collect-simple-molds ds)
  =/  names=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  globals=(list term)  (weld (import-binding-names imports.p.parsed) (global-value-names ds))
  ::  Remove raw list before inferring any template, so an altered list
  ::  cannot leak through an alias. Its name remains reserved either way.
  =/  declared=?  (lien names |=(name=term =(%list name)))
  =/  env-molds=imolds  molds
  =?  env-molds  declared
    (skim molds |=(m=[name=term body=shape] !=(%list name.m)))
  =/  reserved=(list term)  ?:(declared ~[%list] ~)
  =/  state=istate  [0 ~ ~ ~ env-molds globals ~ ~ ~ ~ u.private reserved ~ ~ ~ | at names ~ ~ 256 ~ ~ ~ ~ ~ ~]
  ::  Other prelude molds may use list only after its source has passed
  ::  the standard-list check. The raw declaration remains removed.
  =/  declared-list=(unit shape)  (find-simple-mold %list molds)
  =/  mold-prelude=(unit ifile)
    ?~  declared-list  ~
    ?.  (standard-prelude-list u.declared-list)  ~
    `[~ ~[[%list [[%collection %list ~[[%var 0]]] ~[0]]]] at ~ ~ ~ ~ ~]
  =/  mt=imold-types  (partial-prelude-molds molds state(prelude mold-prelude))
  =/  partial=ifile  [~ mt at ~ ~ ~ ~ ~]
  ::  An explicitly qualified re-export must resolve. Other unsupported
  ::  prelude declarations remain reserved but absent from the interface.
  =/  required=imolds
    %+  skim  molds
    |=  m=[name=term body=shape]
    =/  sh=shape  body.m
    ?.  ?=(%ref -.sh)  |
    ?~  names.sh  |
    ?=(^ t.names.sh)
  ?.  (levy required |=(m=[name=term body=shape] ?=(^ (find-jibb-mold name.m partial))))  ~
  =/  resolution=iresolved  (resolve-groups ds env-molds globals ~ ~ ~ ~ u.private reserved at `partial)
  =/  env=ienv  env.resolution
  ?.  (hole-values-present ds env)  ~
  =/  deps=(list iwidth-dependency)
    ?~  u.private  ~
    ~[[at.interface.i.u.private source.interface.i.u.private elaborations.interface.i.u.private]]
  `[env mt at ~ artifacts.resolution deps `src ~]
::
++  partial-prelude-interface
  |=  src=@t
  ^-  (unit ifile)
  (partial-prelude-interface-with-internal src ~)
::
+$  iprelude  [iface=ifile values=(list term) molds=(list term)]
::
++  prepare-prelude
  |=  src=@t
  ^-  (unit iprelude)
  =/  iface=(unit ifile)  (partial-prelude-interface src)
  ?~  iface  ~
  =/  parsed  (parse /lib/jibb/prelude/jibb src)
  ?:  ?=(%| -.parsed)  ~
  =/  vals=(list term)  (global-value-names defs.p.parsed)
  =/  ms=(list term)  (turn (collect-simple-molds defs.p.parsed) |=(m=[name=term body=shape] name.m))
  `[u.iface vals ms]
::
++  prepare-prelude-with-internal
  |=  [src=@t internal-source=@t]
  ^-  (unit iprelude)
  =/  iface=(unit ifile)  (partial-prelude-interface-with-internal src `internal-source)
  ?~  iface  ~
  =/  parsed  (parse /lib/jibb/prelude/jibb src)
  ?:  ?=(%| -.parsed)  ~
  =/  vals=(list term)  (global-value-names defs.p.parsed)
  =/  ms=(list term)  (turn (collect-simple-molds defs.p.parsed) |=(m=[name=term body=shape] name.m))
  `[u.iface vals ms]
::
++  module-values-complete
  |=  [ds=(list def) env=ienv]
  ^-  ?
  ?~  ds  &
  ?:  ?=(%mold -.i.ds)  $(ds t.ds)
  ?~  (ienv-lookup name.i.ds env)  |
  $(ds t.ds)
::
::  Cache only completed interfaces for this invocation. The source bundle,
::  imported Hoon types and prelude are fixed for the whole graph. Check the
::  active path and duplicate sources before consulting it, so a cache hit
::  cannot hide a cycle or ambiguous source.
::
++  find-jibb-cache
  |=  [at=path cache=jcache]
  ^-  (unit ifile)
  ?~  cache  ~
  ?:  =(at at.i.cache)  `iface.i.cache
  $(cache t.cache)
::
::  These certificates retain the complete checked source closure. The
::  trusted host must supply the identical prepared prelude and reader nouns.
::  Exact bundle equality binds all source paths and versions; the set
::  retains transitive paths for active-cycle checks. Request-bearing graphs
::  alone have a size limit; incompatible diamond evidence fails closed.
++  request-graph-requests-add
  |=  [pending=(list irequest-evidence) acc=(list irequest-evidence) fuel=@ud]
  ^-  (unit (list irequest-evidence))
  ?~  pending  `acc
  ?:  =(0 fuel)  ~
  =/  hit=(list irequest-evidence)
    (skim acc |=(x=irequest-evidence &(=(api-at.x api-at.i.pending) =(name.x name.i.pending))))
  ?^  hit
    ?.  ?=([* ~] hit)  ~
    ?.  =(i.hit i.pending)  ~
    $(pending t.pending, fuel (dec fuel))
  $(pending t.pending, acc [i.pending acc], fuel (dec fuel))
++  request-graph-inputs-match
  |=  [g=irequest-graph externals=iexternals marks=imark-externals modules=jbundle values=(list term) molds=(list term) prelude=(unit ifile)]
  ^-  ?
  ?&  =(bundle-input.g modules)
      =(prelude-input.g prelude)
      =(prelude-values.g values)
      =(prelude-molds.g molds)
      =(externals.g externals)
      =(marks.g marks)
  ==
++  request-graph-merge
  |=  [imports=ijimports g=irequest-graph fuel=@ud]
  ^-  (unit irequest-graph)
  ?~  imports  `g
  ?:  =(0 fuel)  ~
  =/  child=ifile  interface.i.imports
  ?~  graph.child  ~
  =/  cg=irequest-graph  u.graph.child
  ?.  ?&  =(bundle-input.g bundle-input.cg)
           =(prelude-input.g prelude-input.cg)
           =(prelude-values.g prelude-values.cg)
           =(prelude-molds.g prelude-molds.cg)
           =(externals.g externals.cg)
           =(marks.g marks.cg)
       ==
    ~
  =/  merged=(set path)  (~(uni in:..zuse paths.g) paths.cg)
  =/  rs=(unit (list irequest-evidence))
    (request-graph-requests-add requests.cg requests.g (add 1 (lent requests.cg)))
  ?~  rs  ~
  ?:  &(?=(^ u.rs) |((gth (lent ~(tap in:..zuse merged)) 256) (gth (lent u.rs) 256)))  ~
  $(imports t.imports, g g(paths merged, requests u.rs), fuel (dec fuel))
++  request-graph-reusable
  |=  [f=ifile src=@t externals=iexternals marks=imark-externals modules=jbundle active=(list path) values=(list term) molds=(list term) prelude=(unit ifile)]
  ^-  ?
  ?~  source.f  |
  ?.  =(u.source.f src)  |
  ?~  graph.f  |
  =/  g=irequest-graph  u.graph.f
  ?.  (request-graph-inputs-match g externals marks modules values molds prelude)  |
  ?.  (~(has in:..zuse paths.g) at.f)  |
  !(lien active |=(p=path (~(has in:..zuse paths.g) p)))
::
++  resolve-jibb-imports
  |=  [imports=(list import) externals=iexternals mark-externals=imark-externals modules=jbundle active=(list path) prelude-values=(list term) prelude-molds=(list term) cache=jcache prelude=(unit ifile)]
  ^-  jimports-result
  ?~  imports  [%& [~ cache]]
  ?.  ?=(%jibb -.i.imports)  $(imports t.imports)
  =/  at=path  (weld path.i.imports `path`~[%jibb])
  ?:  =(at /lib/jibb/internal/jibb)
    [%| 'the prelude internal module is private']
  ?:  =(at /lib/jibb/primitives/jibb)
    [%| 'the prelude primitive interface is private']
  ?:  (lien active |=(p=path =(p at)))
    [%| (crip "import cycle at {(spud at)}")]
  =/  found=jbundle  (skim modules |=(m=jsource =(at at.m)))
  ?~  found  [%| (crip "module source missing: {(spud at)}")]
  ?^  t.found  [%| (crip "duplicate module sources: {(spud at)}")]
  =/  cached=(unit ifile)  (find-jibb-cache at cache)
  =/  iface=jfile-result
    ?^  cached
      ?.  =(at.u.cached at)  [%| 'cached module identity needs unsupported inference']
      ?~  graph.u.cached
        ::  A detached legacy interface has unknown evidence. Rebuild it
        ::  against the current graph, without retaining any stale entry.
        =/  clean=jcache  (skim cache |=(x=[at=path iface=ifile] !=(at.x at)))
        (infer-jibb-file at source.i.found externals mark-externals modules [at active] prelude-values prelude-molds clean prelude)
      ?.  (request-graph-reusable u.cached source.i.found externals mark-externals modules active prelude-values prelude-molds prelude)
        [%| 'cached module evidence needs unsupported inference']
      [%& [u.cached cache]]
    (infer-jibb-file at source.i.found externals mark-externals modules [at active] prelude-values prelude-molds cache prelude)
  ?:  ?=(%| -.iface)  [%| p.iface]
  =/  rest=jimports-result  $(imports t.imports, cache cache.p.iface)
  ?:  ?=(%| -.rest)  rest
  [%& [[[face.i.imports iface.p.iface] resolved.p.rest] cache.p.rest]]
::
::  Provisional declaration extraction only; this does not derive asks,
::  validate imported types, or claim that an API module has checked.
+$  iapi-path  [at=span name=term segments=(list pseg) full=term diffs=(list term) scry=(unit (list pseg))]
++  api-path-mark
  |=  [sh=shape marks=(list term)]
  ^-  (unit term)
  ?.  ?=(%ref -.sh)  ~
  ?.  ?=([@ ~] names.sh)  ~
  ?.  (unique-value-name i.names.sh marks)  ~
  `i.names.sh
::
++  api-path-diffs
  |=  [shapes=(list shape) marks=(list term) used=(list term)]
  ^-  (unit (list term))
  ?~  shapes  `~
  =/  n=(unit term)  (api-path-mark i.shapes marks)
  ?~  n  ~
  ?:  (lien used |=(x=term =(x u.n)))  ~
  =/  rest=(unit (list term))  $(shapes t.shapes, used [u.n used])
  ?~  rest  ~
  `[u.n u.rest]
::
++  api-path-payload
  |=  [sh=shape marks=(list term)]
  ^-  (unit [full=term diffs=(list term)])
  =/  direct=(unit term)  (api-path-mark sh marks)
  ?^  direct  `[u.direct ~]
  ?.  ?=(%apply -.sh)  ~
  ?.  =(~[%facts] ref.sh)  ~
  ?~  args.sh  ~
  ?~  t.args.sh  ~
  =/  full=(unit term)  (api-path-mark i.args.sh marks)
  ?~  full  ~
  =/  diffs=(unit (list term))  (api-path-diffs t.args.sh marks ~[u.full])
  ?~  diffs  ~
  `[u.full u.diffs]
::
+$  iapi-parameter  [name=term aura=@ta at=span]
++  api-path-parameters
  |=  [segments=(list pseg) seen=(list term)]
  ^-  (unit (list iapi-parameter))
  ?~  segments  `~
  ?:  ?=(%knot -.i.segments)  $(segments t.segments)
  =/  seg=pseg  i.segments
  ?.  ?=(%typed -.seg)  ~
  ?:  =(0 aura.seg)  ~
  ?:  (lien seen |=(n=term =(n name.seg)))  ~
  =/  rest=(unit (list iapi-parameter))  $(segments t.segments, seen [name.seg seen])
  ?~  rest  ~
  `[[name.seg aura.seg at.seg] u.rest]
::
++  api-scry-parameters-compatible
  |=  [scry=(list iapi-parameter) watch=(list iapi-parameter)]
  ^-  ?
  ?~  scry  &
  ?.  (lien watch |=(p=iapi-parameter &(=(name.p name.i.scry) =(aura.p aura.i.scry))))  |
  $(scry t.scry)
::
++  api-path-one
  |=  [sh=shape marks=(list term)]
  ^-  (unit iapi-path)
  ?.  ?=(%cell -.sh)  ~
  =/  fs=(list field)  fields.sh
  ?~  fs  ~
  ?~  t.fs  ~
  ?~  t.t.fs  ~
  ?:  (gth (lent fs) 4)  ~
  ?.  ?=(%bare -.i.fs)  ~
  =/  tag=shape  shape.i.fs
  ?.  ?=(%const -.tag)  ~
  ?.  =(%term form.lit.tag)  ~
  =/  name=term  val.lit.tag
  ?.  (jibb-face-name name)  ~
  ?.  ?=(%bare -.i.t.fs)  ~
  =/  path-shape=shape  shape.i.t.fs
  ?.  ?=(%path -.path-shape)  ~
  ?.  ?=(%bare -.i.t.t.fs)  ~
  =/  payload=(unit [full=term diffs=(list term)])  (api-path-payload shape.i.t.t.fs marks)
  ?~  payload  ~
  =/  scry=(unit (unit (list pseg)))
    ?~  t.t.t.fs  `~
    =/  entry=field  i.t.t.t.fs
    ?.  ?=(%face -.entry)  ~
    ?.  =(%scry name.entry)  ~
    ?.  ?=(%path -.shape.entry)  ~
    ``segs.shape.entry
  ?~  scry  ~
  =/  params=(unit (list iapi-parameter))  (api-path-parameters segs.path-shape ~)
  ?~  params  ~
  ?^  u.scry
    =/  scry-params=(unit (list iapi-parameter))  (api-path-parameters u.u.scry ~)
    ?~  scry-params  ~
    ?.  (api-scry-parameters-compatible u.scry-params u.params)  ~
    `[at.sh name segs.path-shape full.u.payload diffs.u.payload u.scry]
  `[at.sh name segs.path-shape full.u.payload diffs.u.payload u.scry]
::
++  api-path-many
  |=  [shapes=(list shape) marks=(list term) seen=(list term)]
  ^-  (unit (list iapi-path))
  ?~  shapes  `~
  =/  one=(unit iapi-path)  (api-path-one i.shapes marks)
  ?~  one  ~
  ?:  (lien seen |=(n=term =(n name.u.one)))  ~
  =/  rest=(unit (list iapi-path))  $(shapes t.shapes, seen [name.u.one seen])
  ?~  rest  ~
  `[u.one u.rest]
::
++  api-path-declaration
  |=  [sh=shape marks=(list term)]
  ^-  (unit (list iapi-path))
  ?:  ?=(%union -.sh)  (api-path-many cases.sh marks ~)
  (api-path-many ~[sh] marks ~)
::
::  Derived gates share the value namespace. /% marks name molds; /- and
::  /= also introduce faces that cannot be shadowed by a derived value.
++  api-import-faces
  |=  imports=(list import)
  ^-  (list term)
  ?~  imports  ~
  ?-  -.i.imports
    %mark  $(imports t.imports)
    %sur   [name.i.imports $(imports t.imports)]
    %jibb  [face.i.imports $(imports t.imports)]
  ==
::
++  api-derived-names-valid
  |=  [paths=(list iapi-path) poke-names=(list term) mod=module prelude-values=(list term)]
  ^-  ?
  =/  path-names=(list term)  (turn paths |=(p=iapi-path name.p))
  =/  derived=(list term)  (weld path-names poke-names)
  ?:  (lien derived |=(n=term =(n %proj)))  |
  =/  outer=(list term)  (weld prelude-values (weld (global-value-names defs.mod) (api-import-faces imports.mod)))
  (levy derived |=(n=term &((unique-value-name n derived) !(lien outer |=(x=term =(n x))))))
::
::  Analysis only. Successful external entries must be unchanged results
::  produced for the declared marks; no request interface is produced.
+$  iapi-mark-type  [name=term typ=itype]
+$  iapi-path-typed  [path=iapi-path full=itype diffs=(list iapi-mark-type)]
++  api-diff-types
  |=  [names=(list term) externals=imark-externals declared=(list term)]
  ^-  (unit (list iapi-mark-type))
  ?~  names  `~
  =/  typ=(unit itype)  (find-imported-mark i.names externals declared)
  ?~  typ  ~
  =/  tail=(unit (list iapi-mark-type))  $(names t.names)
  ?~  tail  ~
  `[[i.names u.typ] u.tail]
::
++  api-path-types
  |=  [paths=(list iapi-path) externals=imark-externals declared=(list term)]
  ^-  (unit (list iapi-path-typed))
  ?~  paths  `~
  =/  full=(unit itype)  (find-imported-mark full.i.paths externals declared)
  ?~  full  ~
  =/  diffs=(unit (list iapi-mark-type))  (api-diff-types diffs.i.paths externals declared)
  ?~  diffs  ~
  =/  tail=(unit (list iapi-path-typed))  $(paths t.paths)
  ?~  tail  ~
  `[[i.paths u.full u.diffs] u.tail]
::
++  api-poke-mark-names
  |=  [pokes=(list def) declared=(list term)]
  ^-  (unit (list term))
  ?~  pokes  `~
  ?^  t.pokes  ~
  =/  d=def  i.pokes
  ?.  ?=(%mold -.d)  ~
  =/  sh=shape  shape.d
  ?:  ?=(%union -.sh)  (api-path-diffs cases.sh declared ~)
  =/  name=(unit term)  (api-path-mark sh declared)
  ?~  name  ~
  `~[u.name]
::
++  api-path-analysis
  |=  [mod=module externals=imark-externals prelude-values=(list term) prelude-molds=(list term)]
  ^-  (unit (list iapi-path-typed))
  ?:  (lien defs.mod def-has-hole)  ~
  ?^  (duplicate-defs defs.mod)  ~
  =/  ds=(list def)  defs.mod
  =/  declarations=(list def)
    (skim ds |=(d=def &(?=(%mold -.d) =(%paths name.d))))
  ?.  ?=([* ~] declarations)  ~
  =/  pokes=(list def)
    (skim ds |=(d=def &(?=(%mold -.d) =(%poke name.d))))
  ?:  (gth (lent pokes) 1)  ~
  =/  ordinary=(list def)
    (skim ds |=(d=def !&(?=(%mold -.d) |(=(%paths name.d) =(%poke name.d)))))
  ?.  (module-scope-valid mod(defs ordinary) prelude-values prelude-molds)  ~
  =/  declared=(list term)  (collect-mark-imports imports.mod)
  =/  poke-names=(unit (list term))  (api-poke-mark-names pokes declared)
  ?~  poke-names  ~
  =/  decl=def  i.declarations
  ?>  ?=(%mold -.decl)
  =/  paths=(unit (list iapi-path))  (api-path-declaration shape.decl declared)
  ?~  paths  ~
  ?.  (api-derived-names-valid u.paths u.poke-names mod prelude-values)  ~
  (api-path-types u.paths externals declared)
::
::  Source/graph entry for path analysis only. The returned paths retain
::  reader-derived mark types and import resolution has checked reachable
::  Jibb dependencies. This is not an API interface or a module check.
++  api-path-analysis-source
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle prepared=(unit iprelude)]
  ^-  (each (list iapi-path-typed) @t)
  ?.  ?=([%ui %api @ %jibb ~] file)  [%| 'API path analysis requires /ui/api/<agent>.jibb']
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'API path source does not parse']
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  [%| (show-duplicate-fields file src u.duplicate)]
  ?~  prepared  [%| 'API path analysis needs the prepared prelude']
  =/  prelude=(unit ifile)  `iface.u.prepared
  =/  deps=jimports-result
    (resolve-jibb-imports imports.p.parsed externals marks modules ~[file] values.u.prepared molds.u.prepared ~ prelude)
  ?:  ?=(%| -.deps)  [%| p.deps]
  =/  paths=(unit (list iapi-path-typed))
    (api-path-analysis p.parsed marks values.u.prepared molds.u.prepared)
  ?~  paths  [%| 'API path declaration needs unsupported analysis']
  [%& u.paths]
::
::  Analysis evidence retains the API source, the prepared interface, the
::  caller's reader results and the resolved Jibb dependency cache alongside
::  the typed path declarations.  Reader results and prepared interfaces are
::  trusted inputs: this does not verify their underlying Hoon source/version,
::  create requests or check the provenance of arbitrary values.
+$  iapi-path-evidence
  [at=path source=@t prepared=iprelude externals=iexternals marks=imark-externals dependencies=jcache paths=(list iapi-path-typed)]
++  api-path-evidence-source
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle prepared=(unit iprelude)]
  ^-  (each iapi-path-evidence @t)
  ?.  ?=([%ui %api @ %jibb ~] file)  [%| 'API path evidence requires /ui/api/<agent>.jibb']
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'API path evidence source does not parse']
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  [%| (show-duplicate-fields file src u.duplicate)]
  ?~  prepared  [%| 'API path evidence needs the prepared prelude']
  =/  public=ifile  iface.u.prepared
  =/  deps=jimports-result
    (resolve-jibb-imports imports.p.parsed externals marks modules ~[file] values.u.prepared molds.u.prepared ~ `public)
  ?:  ?=(%| -.deps)  [%| p.deps]
  =/  paths=(unit (list iapi-path-typed))
    (api-path-analysis p.parsed marks values.u.prepared molds.u.prepared)
  ?~  paths  [%| 'API path declaration needs unsupported analysis']
  [%& [file src u.prepared externals marks cache.p.deps u.paths]]
::  Graph-aware variant preserves the caller active stack and cache.
++  api-path-evidence-graph
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle active=(list path) cache=jcache prepared=(unit iprelude)]
  ^-  (each iapi-path-evidence @t)
  ?~  active  [%| 'API analysis needs an active graph']
  ?.  =(i.active file)  [%| 'API analysis active graph does not start at the source']
  ?:  (lien t.active |=(p=path =(p file)))  [%| 'API analysis active graph contains a cycle']
  ?.  ?=([%ui %api @ %jibb ~] file)  [%| 'API path evidence requires /ui/api/<agent>.jibb']
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'API path evidence source does not parse']
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  [%| (show-duplicate-fields file src u.duplicate)]
  ?~  prepared  [%| 'API path evidence needs the prepared prelude']
  =/  public=ifile  iface.u.prepared
  =/  deps=jimports-result
    (resolve-jibb-imports imports.p.parsed externals marks modules active values.u.prepared molds.u.prepared cache `public)
  ?:  ?=(%| -.deps)  [%| p.deps]
  =/  paths=(unit (list iapi-path-typed))
    (api-path-analysis p.parsed marks values.u.prepared molds.u.prepared)
  ?~  paths  [%| 'API path declaration needs unsupported analysis']
  [%& [file src u.prepared externals marks cache.p.deps u.paths]]
::
::  This query classifies a unique path declaration only.  Missing evidence
::  or a nonunique name is unknown; it proves nothing about an ask value.
::  Like prepared interfaces, the supplied evidence is a trusted host input.
++  api-path-watchability
  |=  [evidence=(unit iapi-path-evidence) case-name=term]
  ^-  ?(%watchable %not-watchable %unknown)
  ?~  evidence  %unknown
  =/  found=(list iapi-path-typed)
    (skim paths.u.evidence |=(p=iapi-path-typed =(name.path.p case-name)))
  ?.  ?=([* ~] found)  %unknown
  ?~  scry.path.i.found  %watchable
  %not-watchable
::
::  These are declaration-derived request components, not a callable gate,
::  an ask value, or proof of a value's provenance.  Keep the exact trusted
::  source/reader evidence until a later checked interface and lowerer can
::  attach it to a generated request.  No argument ordering is claimed here.
+$  iapi-request-parameter  [name=term typ=itype at=span]
+$  iapi-request-parts
  [evidence=iapi-path-evidence path=iapi-path-typed parameters=(list iapi-request-parameter) reply-sample=itype fold=(unit itype) watchability=?(%watchable %not-watchable)]
++  api-request-parameter-types
  |=  params=(list iapi-parameter)
  ^-  (unit (list iapi-request-parameter))
  ?~  params  `~
  =/  aura=@ta  aura.i.params
  ?.  |(?=(?(%u %ud %ux %uv %t %ta %tas %p %da %dr) aura) =('tD' aura))  ~
  =/  rest=(unit (list iapi-request-parameter))  $(params t.params)
  ?~  rest  ~
  `[[name.i.params [%atom aura] at.i.params] u.rest]
::
::  A single diff's fold consumes the tagged diff and the previous full value.
::  Multiple-diff unions need a checked union representation and remain open.
++  api-request-fold-type
  |=  p=iapi-path-typed
  ^-  (unit (unit itype))
  ?~  diffs.p  `~
  ?^  t.diffs.p  ~
  =/  d=iapi-mark-type  i.diffs.p
  =/  literal=lit  [%term %tas name.d (crip ['%' (trip name.d)])]
  =/  sample=itype  [%cell [%cell [%const literal] typ.d] full.p]
  ``[%fn sample full.p]
::
++  api-request-parts
  |=  [evidence=(unit iapi-path-evidence) case-name=term]
  ^-  (unit iapi-request-parts)
  ?~  evidence  ~
  =/  found=(list iapi-path-typed)
    (skim paths.u.evidence |=(p=iapi-path-typed =(name.path.p case-name)))
  ?.  ?=([* ~] found)  ~
  =/  p=iapi-path-typed  i.found
  =/  raw=(unit (list iapi-parameter))  (api-path-parameters segments.path.p ~)
  ?~  raw  ~
  =/  params=(unit (list iapi-request-parameter))  (api-request-parameter-types u.raw)
  ?~  params  ~
  =/  fold=(unit (unit itype))  (api-request-fold-type p)
  ?~  fold  ~
  =/  watch=?(%watchable %not-watchable)  ?~(scry.path.p %watchable %not-watchable)
  `[u.evidence p u.params full.p u.fold watch]
::
::  Check ordinary API molds and values plus every declared mark type using
::  the same trusted source, prepared prelude and reader inputs as path
::  evidence.  Keep elaborations with those inputs for a later interface.
::  This is partial analysis: an unused /- core is not independently checked,
::  definitions needing derived values remain unsupported, and no complete
::  API, request or constructor is exported or given runtime behavior.
+$  iapi-support-evidence
  [paths=iapi-path-evidence values=ienv molds=imold-types marks=(list iapi-mark-type) elaborations=(list iwidth-definition)]
++  api-support-analysis-source
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle prepared=(unit iprelude)]
  ^-  (each iapi-support-evidence @t)
  =/  path-result  (api-path-evidence-source file src externals marks modules prepared)
  ?:  ?=(%| -.path-result)  [%| p.path-result]
  =/  evidence=iapi-path-evidence  p.path-result
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'API source does not parse']
  =/  mod=module  p.parsed
  =/  ordinary=(list def)
    (skim defs.mod |=(d=def !&(?=(%mold -.d) |(=(%paths name.d) =(%poke name.d)))))
  =/  prep=iprelude  prepared.evidence
  ?.  (module-scope-valid mod(defs ordinary) values.prep molds.prep)  [%| 'API ordinary scope needs unsupported inference']
  =/  vals=(list term)  (global-value-names ordinary)
  ?:  (lien vals |=(n=term =(n %main)))  [%| 'API module kind needs unsupported inference']
  =/  declared=(list term)  (collect-mark-imports imports.mod)
  =/  mark-types=(unit (list iapi-mark-type))  (api-diff-types declared marks declared)
  ?~  mark-types  [%| 'API declared marks need unsupported inference']
  =/  prelude=(unit ifile)  `iface.prep
  =/  deps=jimports-result
    (resolve-jibb-imports imports.mod externals marks modules ~[file] values.prep molds.prep dependencies.evidence prelude)
  ?:  ?=(%| -.deps)  [%| p.deps]
  =/  molds=imolds  (collect-simple-molds ordinary)
  =/  globals=(list term)  (weld values.prep (weld (import-binding-names imports.mod) vals))
  =/  surs=(list term)  (collect-sur-imports imports.mod)
  =/  reserved=(list term)  (weld molds.prep (turn resolved.p.deps |=(j=[face=term interface=ifile] face.j)))
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  state=istate  [0 ~ ~ ~ molds globals externals surs marks declared resolved.p.deps reserved ~ ~ ~ | file top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  =/  mts=(each imold-types @t)  (module-mold-types molds state)
  ?:  ?=(%| -.mts)  [%| p.mts]
  =/  resolution=iresolved  (resolve-groups ordinary molds globals externals surs marks declared resolved.p.deps reserved file prelude)
  ?.  (module-values-complete ordinary env.resolution)  [%| 'API ordinary definitions need unsupported inference']
  [%& [evidence env.resolution p.mts u.mark-types artifacts.resolution]]
::  Preserve the same graph context through supporting definitions.
++  api-support-analysis-graph
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle active=(list path) cache=jcache prepared=(unit iprelude)]
  ^-  (each iapi-support-evidence @t)
  =/  path-result  (api-path-evidence-graph file src externals marks modules active cache prepared)
  ?:  ?=(%| -.path-result)  [%| p.path-result]
  =/  evidence=iapi-path-evidence  p.path-result
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'API source does not parse']
  =/  mod=module  p.parsed
  =/  ordinary=(list def)
    (skim defs.mod |=(d=def !&(?=(%mold -.d) |(=(%paths name.d) =(%poke name.d)))))
  =/  prep=iprelude  prepared.evidence
  ?.  (module-scope-valid mod(defs ordinary) values.prep molds.prep)  [%| 'API ordinary scope needs unsupported inference']
  =/  vals=(list term)  (global-value-names ordinary)
  ?:  (lien vals |=(n=term =(n %main)))  [%| 'API module kind needs unsupported inference']
  =/  declared=(list term)  (collect-mark-imports imports.mod)
  =/  mark-types=(unit (list iapi-mark-type))  (api-diff-types declared marks declared)
  ?~  mark-types  [%| 'API declared marks need unsupported inference']
  =/  prelude=(unit ifile)  `iface.prep
  =/  deps=jimports-result
    (resolve-jibb-imports imports.mod externals marks modules active values.prep molds.prep dependencies.evidence prelude)
  ?:  ?=(%| -.deps)  [%| p.deps]
  =/  molds=imolds  (collect-simple-molds ordinary)
  =/  globals=(list term)  (weld values.prep (weld (import-binding-names imports.mod) vals))
  =/  surs=(list term)  (collect-sur-imports imports.mod)
  =/  reserved=(list term)  (weld molds.prep (turn resolved.p.deps |=(j=[face=term interface=ifile] face.j)))
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  state=istate  [0 ~ ~ ~ molds globals externals surs marks declared resolved.p.deps reserved ~ ~ ~ | file top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  =/  mts=(each imold-types @t)  (module-mold-types molds state)
  ?:  ?=(%| -.mts)  [%| p.mts]
  =/  resolution=iresolved  (resolve-groups ordinary molds globals externals surs marks declared resolved.p.deps reserved file prelude)
  ?.  (module-values-complete ordinary env.resolution)  [%| 'API ordinary definitions need unsupported inference']
  [%& [evidence env.resolution p.mts u.mark-types artifacts.resolution]]
::
::  Type-analysis artifact for one plain request. The resolver may publish
::  its interface only together with trusted source and reader evidence.
::  No lowering or runtime validator exists.
::  Value watchability remains unproved even for a watchable declaration.
+$  ione-request-interface
  [support=iapi-support-evidence parts=iapi-request-parts iface=ifile]
++  request-compatible-ask
  |=  prelude=iprelude
  ^-  (unit ischeme)
  =/  public=ifile  iface.prelude
  ?.  =(at.public /lib/jibb/prelude/jibb)  ~
  =/  ask=(unit ischeme)  (find-jibb-mold %ask public)
  ?~  ask  ~
  ?.  ?=([@ ~] vars.u.ask)  ~
  ?.  ?=(%union -.typ.u.ask)  ~
  ?.  =(origin.typ.u.ask `[/lib/jibb/internal/jibb %ask])  ~
  ?.  (identity-union-parameters vars.u.ask args.typ.u.ask)  ~
  =/  m=@ud  i.vars.u.ask
  ?:  (itype-var-is-atom m typ.u.ask)  ~
  ?.  (levy (itype-vars typ.u.ask) |=(n=@ud =(n m)))  ~
  ?:  (itype-has-tag typ.u.ask)  ~
  =/  private=(list iwidth-dependency)
    (skim dependencies.public |=(d=iwidth-dependency =(at.d /lib/jibb/internal/jibb)))
  ?.  ?=([* ~] private)  ~
  ?~  source.i.private  ~
  =/  path=(unit ischeme)  (find-jibb-mold %path public)
  ?~  path  ~
  ?^  vars.u.path  ~
  =/  path-type=itype  [%collection %list ~[[%atom %ta]]]
  ?.  =(typ.u.path path-type)  ~
  =/  unit-template=(unit ischeme)  (find-jibb-mold %unit public)
  ?~  unit-template  ~
  ?.  (standard-unit-template u.unit-template /lib/jibb/prelude/jibb)  ~
  =/  state-unit=(unit itype)  (template-apply u.unit-template ~[[%noun ~]])
  ?~  state-unit  ~
  =/  path-unit=(unit itype)  (template-apply u.unit-template ~[path-type])
  ?~  path-unit  ~
  =/  output=itype  [%cell [%face %state [%noun ~]] [%face %message [%var m]]]
  =/  agent-input=itype  [%cell [%face %mark [%atom %tas]] [%cell [%face %state u.state-unit] [%face %fact [%noun ~]]]]
  =/  store-input=itype  [%cell [%face %state u.state-unit] [%face %fact [%noun ~]]]
  =/  pure-case=itype  [%cell [%const [%term %tas %pure '%pure']] [%face %value [%var m]]]
  =/  agent-case=itype
    [%cell [%const [%term %tas %agent '%agent']] [%cell [%face %api [%atom %t]] [%cell [%face %case [%atom %tas]] [%cell [%face %agent [%atom %tas]] [%cell [%face %path path-type] [%cell [%face %scry u.path-unit] [%face %receive [%fn agent-input output]]]]]]]]
  =/  store-case=itype
    [%cell [%const [%term %tas %store '%store']] [%cell [%face %module [%atom %t]] [%cell [%face %name [%atom %tas]] [%face %receive [%fn store-input output]]]]]
  ?.  =(cases.typ.u.ask ~[pure-case agent-case store-case])  ~
  ask
::
::  The first supported standalone API has exactly one mark import and one
::  plain path declaration, with no other definitions or imports.  No partial
::  success is published when source, schema, or a required mold is unknown.
++  one-request-interface-source
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle prepared=(unit iprelude)]
  ^-  (each ione-request-interface @t)
  =/  out  (api-support-analysis-source file src externals marks modules prepared)
  ?:  ?=(%| -.out)  [%| p.out]
  =/  support=iapi-support-evidence  p.out
  =/  ev=iapi-path-evidence  paths.support
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'request source does not parse']
  =/  mod=module  p.parsed
  ?.  ?=(?([[%mark *] ~] [[%mark *] [%mark *] ~]) imports.mod)  [%| 'request imports need unsupported inference']
  ?.  ?=([[%mold *] ~] defs.mod)  [%| 'request definitions need unsupported inference']
  ?.  =(%paths name.i.defs.mod)  [%| 'request declaration needs unsupported inference']
  ?.  ?=([* ~] paths.ev)  [%| 'request count needs unsupported inference']
  =/  p=iapi-path-typed  i.paths.ev
  =/  parts=(unit iapi-request-parts)  (api-request-parts `ev name.path.p)
  ?~  parts  [%| 'request components need unsupported inference']
  ?.  ?=(?(~ [* ~]) parameters.u.parts)  [%| 'request parameters need unsupported inference']
  ?:  &(?=(^ fold.u.parts) ?=(^ parameters.u.parts))  [%| 'request parameter and fold need unsupported inference']
  ?^  scry.path.p  [%| 'request scry needs unsupported inference']
  =/  valid-marks=?
    ?~  fold.u.parts  ?=([* ~] marks.support)
    ?=([* [* ~]] marks.support)
  ?.  valid-marks  [%| 'request marks need unsupported inference']
  =/  fold-open=?
    ?~  fold.u.parts  |
    |(?=(^ (itype-vars u.fold.u.parts)) (itype-has-tag u.fold.u.parts))
  ?:  fold-open  [%| 'request fold needs unsupported inference']
  ?^  (itype-vars reply-sample.u.parts)  [%| 'request payload needs unsupported inference']
  ?:  (itype-has-tag reply-sample.u.parts)  [%| 'request payload needs unsupported inference']
  =/  ask=(unit ischeme)  (request-compatible-ask prepared.ev)
  ?~  ask  [%| 'request ask needs unsupported inference']
  =/  result=(unit itype)  (template-apply u.ask ~[[%var 0]])
  ?~  result  [%| 'request ask needs unsupported inference']
  =/  callback=itype  [%fn reply-sample.u.parts [%var 0]]
  =/  sample=itype
    ?^  fold.u.parts  [%cell callback u.fold.u.parts]
    ?~  parameters.u.parts  callback
    [%cell typ.i.parameters.u.parts callback]
  =/  scheme=ischeme  [[%fn sample u.result] ~[0]]
  =/  exports=imold-types
    (turn marks.support |=(m=iapi-mark-type [name.m [typ.m ~]]))
  =/  prelude=iprelude  prepared.ev
  =/  public=ifile  iface.prelude
  ?~  source.public  [%| 'request prelude source needs unsupported inference']
  =/  private=(list iwidth-dependency)
    (skim dependencies.public |=(d=iwidth-dependency =(at.d /lib/jibb/internal/jibb)))
  ?.  ?=([* ~] private)  [%| 'request internal source needs unsupported inference']
  ?~  source.i.private  [%| 'request internal source needs unsupported inference']
  =/  req=irequest-evidence
    [file name.path.p p src u.source.public u.source.i.private values.prelude molds.prelude externals marks]
  =/  interface=ifile  [~[[name.path.p scheme]] exports file ~ ~ ~ `src `[(silt `(list path)`~[file]) ~[req] modules `public values.prelude molds.prelude externals marks]]
  [%& [support u.parts interface]]
::  Graph-aware request artifact; resolver use remains type-only.
++  one-request-interface-graph
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle active=(list path) cache=jcache prepared=(unit iprelude)]
  ^-  (each ione-request-interface @t)
  =/  out  (api-support-analysis-graph file src externals marks modules active cache prepared)
  ?:  ?=(%| -.out)  [%| p.out]
  =/  support=iapi-support-evidence  p.out
  =/  ev=iapi-path-evidence  paths.support
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'request source does not parse']
  =/  mod=module  p.parsed
  ?.  ?=(?([[%mark *] ~] [[%mark *] [%mark *] ~]) imports.mod)  [%| 'request imports need unsupported inference']
  ?.  ?=([[%mold *] ~] defs.mod)  [%| 'request definitions need unsupported inference']
  ?.  =(%paths name.i.defs.mod)  [%| 'request declaration needs unsupported inference']
  ?.  ?=([* ~] paths.ev)  [%| 'request count needs unsupported inference']
  =/  p=iapi-path-typed  i.paths.ev
  =/  parts=(unit iapi-request-parts)  (api-request-parts `ev name.path.p)
  ?~  parts  [%| 'request components need unsupported inference']
  ?.  ?=(?(~ [* ~]) parameters.u.parts)  [%| 'request parameters need unsupported inference']
  ?:  &(?=(^ fold.u.parts) ?=(^ parameters.u.parts))  [%| 'request parameter and fold need unsupported inference']
  ?^  scry.path.p  [%| 'request scry needs unsupported inference']
  =/  valid-marks=?
    ?~  fold.u.parts  ?=([* ~] marks.support)
    ?=([* [* ~]] marks.support)
  ?.  valid-marks  [%| 'request marks need unsupported inference']
  =/  fold-open=?
    ?~  fold.u.parts  |
    |(?=(^ (itype-vars u.fold.u.parts)) (itype-has-tag u.fold.u.parts))
  ?:  fold-open  [%| 'request fold needs unsupported inference']
  ?^  (itype-vars reply-sample.u.parts)  [%| 'request payload needs unsupported inference']
  ?:  (itype-has-tag reply-sample.u.parts)  [%| 'request payload needs unsupported inference']
  =/  ask=(unit ischeme)  (request-compatible-ask prepared.ev)
  ?~  ask  [%| 'request ask needs unsupported inference']
  =/  result=(unit itype)  (template-apply u.ask ~[[%var 0]])
  ?~  result  [%| 'request ask needs unsupported inference']
  =/  callback=itype  [%fn reply-sample.u.parts [%var 0]]
  =/  sample=itype
    ?^  fold.u.parts  [%cell callback u.fold.u.parts]
    ?~  parameters.u.parts  callback
    [%cell typ.i.parameters.u.parts callback]
  =/  scheme=ischeme  [[%fn sample u.result] ~[0]]
  =/  exports=imold-types
    (turn marks.support |=(m=iapi-mark-type [name.m [typ.m ~]]))
  =/  prelude=iprelude  prepared.ev
  =/  public=ifile  iface.prelude
  ?~  source.public  [%| 'request prelude source needs unsupported inference']
  =/  private=(list iwidth-dependency)
    (skim dependencies.public |=(d=iwidth-dependency =(at.d /lib/jibb/internal/jibb)))
  ?.  ?=([* ~] private)  [%| 'request internal source needs unsupported inference']
  ?~  source.i.private  [%| 'request internal source needs unsupported inference']
  =/  req=irequest-evidence
    [file name.path.p p src u.source.public u.source.i.private values.prelude molds.prelude externals marks]
  =/  interface=ifile  [~[[name.path.p scheme]] exports file ~ ~ ~ `src `[(silt `(list path)`~[file]) ~[req] modules `public values.prelude molds.prelude externals marks]]
  [%& [support u.parts interface]]
::
++  api-mark-exports
  |=  [marks=(list term) all=(list term) externals=imark-externals]
  ^-  imold-types
  ?~  marks  ~
  =/  t=(unit itype)  (find-imported-mark i.marks externals all)
  ?~  t  $(marks t.marks)
  [[i.marks [u.t ~]] $(marks t.marks)]
::
::  Experimental direct poke-only API. Unsupported API declarations fail
::  as a whole; supplied mark reader results retain their existing boundary.
++  api-poke-interface
  |=  [at=path mod=module mark-externals=imark-externals prelude-values=(list term) prelude-molds=(list term) prelude=(unit ifile)]
  ^-  (unit ifile)
  ?:  (lien defs.mod def-has-hole)  ~
  ?.  ?=([%ui %api @ %jibb ~] at)  ~
  ?^  (duplicate-defs defs.mod)  ~
  ?~  prelude  ~
  ?.  =(at.u.prelude /lib/jibb/prelude/jibb)  ~
  =/  poke=(unit ischeme)  (find-jibb-mold %poke u.prelude)
  ?~  poke  ~
  ?.  ?=(%union -.typ.u.poke)  ~
  ?^  vars.u.poke  ~
  =/  compatible=?
    %+  lien  cases.typ.u.poke
    |=  c=itype
    ?=([%cell [%const [%term %tas %agent *]] [%cell [%face %agent [%atom %tas]] [%cell [%face %mark [%atom %tas]] [%face %payload [%noun ~]]]]] c)
  ?.  compatible  ~
  ?.  (module-scope-valid mod(defs ~) prelude-values prelude-molds)  ~
  ?.  (levy imports.mod |=(i=import ?=(%mark -.i)))  ~
  =/  marks=(list term)  (collect-mark-imports imports.mod)
  ?.  ?=([@ ~] marks)  ~
  =/  ds=(list def)  defs.mod
  ?.  ?=([[%mold *] ~] ds)  ~
  ?.  =(%poke name.i.ds)  ~
  =/  sh=shape  shape.i.ds
  ?.  ?=([%ref *] sh)  ~
  ?.  ?=([@ ~] names.sh)  ~
  =/  n=term  i.names.sh
  ?.  (unique-value-name n marks)  ~
  ?:  |((lien prelude-values |=(x=term =(n x))) (lien prelude-molds |=(x=term =(n x))))  ~
  =/  mark=(unit itype)  (find-imported-mark n mark-externals marks)
  ?~  mark  ~
  =/  sc=ischeme  [[%fn u.mark typ.u.poke] ~]
  `[~[[n sc]] (api-mark-exports marks marks mark-externals) at ~[[n i.t.t.at n]] ~ ~ ~ ~]
::
::  Source-proven ordinary helpers validate each selected /sur dependency.
::  Unused or less direct cores remain unsupported by this first interface.
++  api-sur-covered
  |=  [surs=(list term) defs=(list def) externals=iexternals all=(list term)]
  ^-  ?
  ?~  surs  &
  =/  found=(list def)
    %+  skim  defs
    |=  d=def
    ?.  ?=(%mold -.d)  |
    ?.  ?=(%ref -.shape.d)  |
    ?.  ?=([@ [@ ~]] names.shape.d)  |
    =(i.t.names.shape.d i.surs)
  ?~  found  |
  =/  selected=def  i.found
  ?.  ?=(%mold -.selected)  |
  =/  sh=shape  shape.selected
  ?.  ?=(%ref -.sh)  |
  ?.  ?=([@ [@ ~]] names.sh)  |
  =/  checked=(unit itype)  (find-imported-mold i.surs i.names.sh externals all)
  ?~  checked  |
  $(surs t.surs)
::
+$  imulti-request-gates  [values=ienv requests=(list irequest-evidence)]
++  api-request-gates
  |=  [paths=(list iapi-path-typed) ev=iapi-path-evidence ask=ischeme file=path src=@t public=@t internal=@t externals=iexternals marks=imark-externals fuel=@ud]
  ^-  (unit imulti-request-gates)
  ?~  paths  `[~ ~]
  ?:  =(0 fuel)  ~
  =/  p=iapi-path-typed  i.paths
  =/  parts=(unit iapi-request-parts)  (api-request-parts `ev name.path.p)
  ?~  parts  ~
  ?.  ?=(?(~ [* ~]) parameters.u.parts)  ~
  ?:  &(?=(^ fold.u.parts) ?=(^ parameters.u.parts))  ~
  ?^  scry.path.p  ~
  ?^  (itype-vars reply-sample.u.parts)  ~
  ?:  (itype-has-tag reply-sample.u.parts)  ~
  =/  open-fold=?
    ?~  fold.u.parts  |
    |(?=(^ (itype-vars u.fold.u.parts)) (itype-has-tag u.fold.u.parts))
  ?:  open-fold  ~
  =/  result=(unit itype)  (template-apply ask ~[[%var 0]])
  ?~  result  ~
  =/  callback=itype  [%fn reply-sample.u.parts [%var 0]]
  =/  sample=itype
    ?^  fold.u.parts  [%cell callback u.fold.u.parts]
    ?~  parameters.u.parts  callback
    [%cell typ.i.parameters.u.parts callback]
  =/  scheme=ischeme  [[%fn sample u.result] ~[0]]
  =/  prep=iprelude  prepared.ev
  =/  req=irequest-evidence
    [file name.path.p p src public internal values.prep molds.prep externals marks]
  =/  rest=(unit imulti-request-gates)
    $(paths t.paths, fuel (dec fuel))
  ?~  rest  ~
  `[[[name.path.p scheme] values.u.rest] [req requests.u.rest]]
::
++  api-poke-from-checked
  |=  [file=path mod=module marks=imark-externals values=(list term) molds=(list term) prelude=(unit ifile)]
  ^-  (unit [values=ienv derived=(list iderived)])
  =/  pokes=(list def)
    (skim defs.mod |=(d=def &(?=(%mold -.d) =(%poke name.d))))
  ?~  pokes  `[~ ~]
  ?.  ?=([* ~] pokes)  ~
  =/  declared=(list term)  (collect-mark-imports imports.mod)
  =/  ns=(unit (list term))  (api-poke-mark-names pokes declared)
  ?~  ns  ~
  ?.  ?=([@ ~] u.ns)  ~
  =/  matching=(list import)
    %+  skim  imports.mod
    |=  i=import
    ?.  ?=(%mark -.i)  |
    =(mark.i i.u.ns)
  ?.  ?=([* ~] matching)  ~
  =/  checked=(unit ifile)
    (api-poke-interface file mod(defs pokes, imports matching) marks values molds prelude)
  ?~  checked  ~
  `[values.u.checked derived.u.checked]
::
::  The partial interface is published atomically: all paths, ordinary
::  source definitions, declared marks and the poke must check. Unselected
::  /sur bindings, runtime validation and value watchability remain unproved.
++  multi-request-interface-graph
  |=  [file=path src=@t externals=iexternals marks=imark-externals modules=jbundle active=(list path) cache=jcache prepared=(unit iprelude)]
  ^-  (each [iface=ifile cache=jcache] @t)
  =/  out  (api-support-analysis-graph file src externals marks modules active cache prepared)
  ?:  ?=(%| -.out)  [%| p.out]
  =/  support=iapi-support-evidence  p.out
  =/  ev=iapi-path-evidence  paths.support
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'request source does not parse']
  =/  mod=module  p.parsed
  ?.  (levy imports.mod |=(i=import ?=(?(%mark %sur) -.i)))
    [%| 'request imports need unsupported inference']
  =/  surs=(list term)  (collect-sur-imports imports.mod)
  ?.  (api-sur-covered surs defs.mod externals surs)
    [%| 'API source dependency needs unsupported inference']
  ?~  paths.ev  [%| 'request count needs unsupported inference']
  =/  ask=(unit ischeme)  (request-compatible-ask prepared.ev)
  ?~  ask  [%| 'request ask needs unsupported inference']
  =/  prep=iprelude  prepared.ev
  =/  public=ifile  iface.prep
  ?~  source.public  [%| 'request prelude source needs unsupported inference']
  =/  private=(list iwidth-dependency)
    (skim dependencies.public |=(d=iwidth-dependency =(at.d /lib/jibb/internal/jibb)))
  ?.  ?=([* ~] private)  [%| 'request internal source needs unsupported inference']
  ?~  source.i.private  [%| 'request internal source needs unsupported inference']
  =/  gates=(unit imulti-request-gates)
    (api-request-gates paths.ev ev u.ask file src u.source.public u.source.i.private externals marks 256)
  ?~  gates  [%| 'request paths need unsupported inference']
  =/  poke=(unit [values=ienv derived=(list iderived)])
    (api-poke-from-checked file mod marks values.prep molds.prep `public)
  ?~  poke  [%| 'API poke needs unsupported inference']
  =/  mark-molds=imold-types
    (turn marks.support |=(m=iapi-mark-type [name.m [typ.m ~]]))
  =/  exports=imold-types  (weld mark-molds molds.support)
  =/  names=(list term)  (turn exports |=(m=[name=term template=ischeme] name.m))
  ?.  (levy names |=(n=term (unique-value-name n names)))
    [%| 'API exported molds need unsupported inference']
  =/  env=ienv  (weld values.u.gates (weld values.u.poke values.support))
  =/  graph=irequest-graph
    [(silt `(list path)`~[file]) requests.u.gates modules `public values.prep molds.prep externals marks]
  =/  iface=ifile
    [env exports file derived.u.poke elaborations.support ~ `src `graph]
  [%& [iface dependencies.ev]]
::
++  infer-jibb-file
  |=  [at=path src=@t externals=iexternals mark-externals=imark-externals modules=jbundle active=(list path) prelude-values=(list term) prelude-molds=(list term) cache=jcache prelude=(unit ifile)]
  ^-  jfile-result
  =/  parsed  (parse at src)
  ?:  ?=(%| -.parsed)  [%| (crip "module source does not parse: {(spud at)}")]
  =/  mod=module  p.parsed
  =/  duplicate=(unit idiag)  (duplicate-defs defs.mod)
  ?^  duplicate  [%| (show-duplicate-fields at src u.duplicate)]
  ?:  ?=([%ui %api *] at)
    =/  iface=(unit ifile)  (api-poke-interface at mod mark-externals prelude-values prelude-molds prelude)
    ?^  iface
      =/  checked=ifile  u.iface(source `src, graph `[(silt `(list path)`~[at]) ~ modules prelude prelude-values prelude-molds externals mark-externals])
      [%& [checked [[at checked] cache]]]
    ?~  prelude  [%| (crip "API module needs unsupported inference: {(spud at)}")]
    =/  prepared=iprelude  [u.prelude prelude-values prelude-molds]
    =/  narrow=?
      ?.  ?=([[%mark *] ~] imports.mod)  |
      ?.  ?=([[%mold *] ~] defs.mod)  |
      ?.  =(%paths name.i.defs.mod)  |
      !?=(%union -.shape.i.defs.mod)
    ?:  narrow
      =/  request=(each ione-request-interface @t)
        (one-request-interface-graph at src externals mark-externals modules active cache `prepared)
      ?:  ?=(%| -.request)  [%| (crip "API module needs unsupported inference: {(spud at)}")]
      =/  checked=ifile  iface.p.request
      [%& [checked [[at checked] dependencies.paths.support.p.request]]]
    =/  multi=(each [iface=ifile cache=jcache] @t)
      (multi-request-interface-graph at src externals mark-externals modules active cache `prepared)
    ?:  ?=(%| -.multi)  [%| (crip "API module needs unsupported inference: {(spud at)}")]
    [%& [iface.p.multi [[at iface.p.multi] cache.p.multi]]]
  ?.  (module-scope-valid mod prelude-values prelude-molds)
    ?:  (pending-declared-poke at mod prelude-values prelude-molds)
      [%| (crip "module kind or scope needs unsupported inference: {(spud at)}")]
    [%| (crip "module has conflicting names: {(spud at)}")]
  =/  vals=(list term)  (global-value-names defs.mod)
  ?:  (lien vals |=(n=term =(n %main)))
    [%| (crip "module kind needs unsupported inference: {(spud at)}")]
  =/  js=jimports-result  (resolve-jibb-imports imports.mod externals mark-externals modules active prelude-values prelude-molds cache prelude)
  ?:  ?=(%| -.js)  [%| p.js]
  =/  collected=grec-collected
    ?^  imports.mod  [(collect-simple-molds defs.mod) *(map term shape)]
    (grec-collect-molds defs.mod)
  =/  molds=imolds  molds.collected
  =/  globals=(list term)  (weld prelude-values (weld (import-binding-names imports.mod) vals))
  =/  surs=(list term)  (collect-sur-imports imports.mod)
  =/  marks=(list term)  (collect-mark-imports imports.mod)
  =/  reserved=(list term)  (weld prelude-molds (turn resolved.p.js |=(j=[face=term interface=ifile] face.j)))
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  state=istate  [0 ~ ~ ~ molds globals externals surs mark-externals marks resolved.p.js reserved ~ ~ ~ | at top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  :: Source and scope were checked above; preserve that exact root and prelude.
  :: This first integration only indexes import-free library sources.
  =/  index=(unit [at=path source=@t prelude=ifile shapes=(map term shape)])
    ?^  imports.mod  ~
    ?~  prelude  ~
    =/  standard=(unit ischeme)  (find-jibb-mold %list u.prelude)
    ?~  standard  ~
    ?.  =(u.standard [[%collection %list ~[[%var 0]]] ~[0]])  ~
    =/  index=(map term shape)  proofs.collected
    ?.  !=(index *(map term shape))  ~
    ?:  (lien molds |=(m=[name=term body=shape] =(%list name.m)))  ~
    `[at src u.prelude index]
  =.  grec-index.state  index
  =/  mts=(each imold-types @t)  (module-mold-types molds state)
  ?:  ?=(%| -.mts)  [%| (crip "{(trip p.mts)}: {(spud at)}")]
  =/  resolution=iresolved
    ?~  index
      (resolve-groups defs.mod molds globals externals surs mark-externals marks resolved.p.js reserved at prelude)
    (resolve-groups-core defs.mod molds globals externals surs mark-externals marks resolved.p.js reserved at prelude index)
  =/  env=ienv  env.resolution
  =.  env
    ?:  (module-values-complete defs.mod env)  env
    ?:  |(?=([%ui %stores *] at) ?=(^ imports.mod) ?=(^ prelude) ?=(^ prelude-values) ?=(^ prelude-molds))  env
    ?:  (gth (met 3 src) 65.536)  env
    ?:  (gth (lent defs.mod) 64)  env
    ?.  (dg-source-candidate defs.mod 64)  env
    =/  transaction=(unit dgcommit)  (dg-root-source at src)
    ?~  transaction  env
    ?:  (dg-interface-safe env.u.transaction)  env.u.transaction
    env
  ?.  (module-values-complete defs.mod env)
    [%| (crip "module definitions need unsupported inference: {(spud at)}")]
  =/  initial=irequest-graph  [(silt `(list path)`~[at]) ~ modules prelude prelude-values prelude-molds externals mark-externals]
  =/  graph=(unit irequest-graph)  (request-graph-merge resolved.p.js initial (add 1 (lent resolved.p.js)))
  ?~  graph  [%| 'module request evidence needs unsupported inference']
  =/  iface=ifile  [env p.mts at ~ artifacts.resolution ~ `src graph]
  [%& [iface [[at iface] cache.p.js]]]
::
::  A source-bound analysis of one named mold, not a module, island,
::  request, watchability or runtime check.  The host owns the trusted
::  prepared prelude, canonical paths and reader/source version identities.
::  The 256-node cap covers only classification, not source/graph work.
+$  igate-free-mold
  [at=path source=@t name=term prepared=iprelude externals=iexternals marks=imark-externals modules=jbundle dependencies=jcache mold=ischeme requested=@ud budget=@ud result=igate-free]
++  gate-free-mold-source
  |=  [file=path src=@t name=term externals=iexternals marks=imark-externals modules=jbundle prepared=(unit iprelude) fuel=@ud]
  ^-  (each igate-free-mold @t)
  ?~  file  [%| 'mold analysis needs a path ending in jibb']
  ?.  =(%jibb (rear file))  [%| 'mold analysis needs a path ending in jibb']
  ?:  |(=(file /lib/jibb/internal/jibb) =(file /lib/jibb/primitives/jibb))
    [%| 'the prelude internal modules are private']
  ?:  ?=([%ui %api *] file)  [%| 'API declarations need unsupported mold analysis']
  ?:  ?=([%ui %stores *] file)  [%| 'store declarations need unsupported mold analysis']
  =/  entries=jbundle  (skim modules |=(m=jsource =(file at.m)))
  ?:  (gth (lent entries) 1)  [%| 'duplicate root module sources']
  =/  wrong-root=?  ?~(entries | !=(source.i.entries src))
  ?:  wrong-root  [%| 'root module source does not match bundle']
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  [%| 'mold source does not parse']
  =/  mod=module  p.parsed
  =/  duplicate=(unit idiag)  (duplicate-defs defs.mod)
  ?^  duplicate  [%| (show-duplicate-fields file src u.duplicate)]
  ?~  prepared  [%| 'mold analysis needs the prepared prelude']
  ?.  (module-scope-valid mod values.u.prepared molds.u.prepared)
    [%| 'mold source has conflicting or unsupported scope']
  =/  selected=(list def)
    (skim defs.mod |=(d=def &(?=(%mold -.d) =(name.d name))))
  ?~  selected  [%| 'selected mold is not declared']
  ?^  t.selected  [%| 'selected mold is not unique']
  ?>  ?=(%mold -.i.selected)
  =/  public=ifile  iface.u.prepared
  =/  js=jimports-result
    (resolve-jibb-imports imports.mod externals marks modules ~[file] values.u.prepared molds.u.prepared ~ `public)
  ?:  ?=(%| -.js)  [%| p.js]
  =/  ms=imolds  (collect-simple-molds defs.mod)
  =/  vals=(list term)  (global-value-names defs.mod)
  =/  globals=(list term)  (weld values.u.prepared (weld (import-binding-names imports.mod) vals))
  =/  surs=(list term)  (collect-sur-imports imports.mod)
  =/  declared=(list term)  (collect-mark-imports imports.mod)
  =/  reserved=(list term)  (weld molds.u.prepared (turn resolved.p.js |=(j=[face=term interface=ifile] face.j)))
  =/  top=(list term)  (turn ms |=(m=[name=term body=shape] name.m))
  =/  state=istate  [0 ~ ~ ~ ms globals externals surs marks declared resolved.p.js reserved ~ ~ ~ | file top `public ~ 256 ~ ~ ~ ~ ~ ~]
  =/  inferred=(unit [template=ischeme state=istate])
    (infer-mold-template shape.i.selected state(active ~[name], in-mold &))
  ?~  inferred  [%| 'selected mold needs unsupported inference']
  =/  template=ischeme  template.u.inferred
  =.  typ.template  (label-direct-union typ.template shape.i.selected name state)
  =.  typ.template  (itype-normalize typ.template sub.state.u.inferred)
  =/  cap=@ud  (min fuel 256)
  =/  analysis=igate-free  (gate-free-type typ.template cap ~)
  [%& [file src name u.prepared externals marks modules cache.p.js template fuel cap analysis]]
::
::  +golden-types-with-modules fails closed for imports without prelude
::  scope. +golden-types-with-prelude resolves supported library graphs;
::  its report remains partial and unreachable sources are not examined.
::
++  golden-types-with-modules
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals modules=jbundle]
  ^-  @t
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  (show-error src p.parsed)
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  (duplicate-fields-report file src u.duplicate)
  ?:  (lien imports.p.parsed |=(i=import ?=(%jibb -.i)))
    'partial inference; module not checked\0aprelude source missing; module import inference unsupported'
  (golden-types-with-marks file src externals mark-externals)
::
::  The caller supplies the actual prelude source. Its declared names are
::  reserved, and supported inferred types are made available. The inventory
::  and the checker are incomplete, so this never claims a checked module.
::  Hosts may prepare the same trusted source once and reuse its interface.
::
++  golden-types-with-prelude
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals modules=jbundle prelude-source=@t]
  ^-  @t
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  (show-error src p.parsed)
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  (duplicate-fields-report file src u.duplicate)
  ?:  =(0 prelude-source)  'partial inference; module not checked\0aprelude source missing; module import inference unsupported'
  =/  prelude  (parse /lib/jibb/prelude/jibb prelude-source)
  ?:  ?=(%| -.prelude)  'partial inference; module not checked\0aprelude source does not parse; module import inference unsupported'
  =/  prepared=(unit iprelude)  (prepare-prelude prelude-source)
  ?~  prepared  'partial inference; module not checked\0aprelude interface is not supported'
  (golden-types-with-prepared-prelude file src externals mark-externals modules prepared)
::
++  golden-types-with-prelude-and-internal
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals modules=jbundle prelude-source=@t internal-source=@t]
  ^-  @t
  =/  prepared=(unit iprelude)  (prepare-prelude-with-internal prelude-source internal-source)
  (golden-types-with-prepared-prelude file src externals mark-externals modules prepared)
::
++  golden-types-with-prepared-prelude
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals modules=jbundle prepared=(unit iprelude)]
  ^-  @t
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  (show-error src p.parsed)
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  (duplicate-fields-report file src u.duplicate)
  ?~  prepared  'partial inference; module not checked\0aprelude interface is not supported'
  =/  prelude-values=(list term)  values.u.prepared
  =/  prelude-molds=(list term)  molds.u.prepared
  =/  iface=(unit ifile)  `iface.u.prepared
  ?.  (module-scope-valid p.parsed prelude-values prelude-molds)
    ?:  (pending-declared-poke file p.parsed prelude-values prelude-molds)
      'partial inference; module not checked\0amodule kind or scope needs unsupported inference'
    'partial inference; module not checked\0amodule has conflicting names'
  =/  js=jimports-result
    (resolve-jibb-imports imports.p.parsed externals mark-externals modules ~[file] prelude-values prelude-molds ~ iface)
  ?:  ?=(%| -.js)  (of-wain:format ~['partial inference; module not checked' p.js])
  =/  scope-values=(list term)
    (weld prelude-values (weld (collect-sur-imports imports.p.parsed) (collect-mark-imports imports.p.parsed)))
  (golden-types-in-context file src externals mark-externals resolved.p.js scope-values prelude-molds iface)
::
::  +golden-types-with-marks: supply declared mark types separately from /sur
::    entries, as [mark result] with the result from +read-mark:jibb-import.
::    Unknown, duplicated, failed and undeclared entries never resolve a mold.
::
::  Callers pass unchanged structured reader results; graph validation
::  remains in the existing bridge, and failures stay available lazily.
++  reader-result-for-checker
  |=  result=*
  ^-  *
  ?:  ?=([%ok *] result)  [%& +.result]
  result
::
++  golden-types-with-reader-diagnostics
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals]
  ^-  @t
  =/  ex=iexternals
    (turn externals |=(e=[module=term name=term result=*] [module.e name.e (reader-result-for-checker result.e)]))
  =/  mx=imark-externals
    (turn mark-externals |=(e=[mark=term result=*] [mark.e (reader-result-for-checker result.e)]))
  (golden-types-with-marks file src ex mx)
::
++  golden-types-with-marks
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals]
  ^-  @t
  (golden-types-in-context file src externals mark-externals ~ ~ ~ ~)
::
++  golden-types-in-context
  |=  [file=path src=@t externals=iexternals mark-externals=imark-externals jimports=ijimports prelude-values=(list term) reserved-molds=(list term) prelude=(unit ifile)]
  ^-  @t
  =.  reserved-molds  (weld reserved-molds (turn jimports |=(j=[face=term interface=ifile] face.j)))
  =/  parsed  (parse file src)
  ?:  ?=(%| -.parsed)  (show-error src p.parsed)
  =/  duplicate=(unit idiag)  (duplicate-defs defs.p.parsed)
  ?^  duplicate  (duplicate-fields-report file src u.duplicate)
  ?:  (module-has-reserved-proj p.parsed)
    'module has reserved proj name'
  =/  ds=(list def)  defs.p.parsed
  =/  molds=imolds  (collect-simple-molds ds)
  =/  globals=(list term)  (weld prelude-values (weld (turn jimports |=(j=[face=term interface=ifile] face.j)) (global-value-names ds)))
  =/  surs=(list term)  (collect-sur-imports imports.p.parsed)
  =/  marks=(list term)  (collect-mark-imports imports.p.parsed)
  =/  resolution=iresolved  (resolve-groups ds molds globals externals surs mark-externals marks jimports reserved-molds file prelude)
  =/  cycles=(list icycle)  (definite-value-cycles ds globals)
  =/  env=ienv  env.resolution
  =/  recovered=(list term)  ~
  =/  eligible=?
    ?&  ?=(~ imports.p.parsed)
       ?=(~ jimports)
       ?=(~ prelude)
       ?=(~ prelude-values)
       ?=(~ reserved-molds)
       !?=([%ui %api *] file)
       !?=([%ui %stores *] file)
       !(lien (global-value-names ds) |=(n=term =(n %main)))
       (module-scope-valid p.parsed ~ ~)
       !(module-values-complete ds env)
       (lte (met 3 src) 65.536)
       (lte (lent ds) 64)
       (dg-source-candidate ds 64)
    ==
  =/  transaction=(unit dgcommit)  ?:(eligible (dg-root-source file src) ~)
  =.  recovered
    ?~  transaction  ~
    ?.  &((module-values-complete ds env.u.transaction) (dg-interface-safe env.u.transaction))  ~
    (turn (skim env.u.transaction |=(entry=[name=term scheme=ischeme] ?=(~ (ienv-lookup name.entry env)))) |=(entry=[name=term scheme=ischeme] name.entry))
  =.  env
    ?~  transaction  env
    ?:  &((module-values-complete ds env.u.transaction) (dg-interface-safe env.u.transaction))  env.u.transaction
    env
  =/  source-defs=(map term def)  (direct-checked-gates ds env)
  =/  heads=(unit igate-prelude-evidence)  (direct-prelude-evidence ds prelude)
  =/  lines=(list @t)  ~
  |-
  ?~  ds  (of-wain:format ['partial inference; module not checked' (flop lines)])
  =/  d=def  i.ds
  ?:  ?=(%mold -.d)
    $(ds t.ds, lines [(show-partial-mold file src d molds) lines])
  ?.  (unique-value-name name.d globals)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: name already in scope") lines])
  =/  cycle=(list icycle)  (skim cycles |=(c=icycle =(name.c name.d)))
  ?^  cycle
    =/  diag=idiag  ["non-gate value depends on itself through a cycle" ~[[first.i.cycle "value in cycle"] [next.i.cycle "dependency in cycle"]]]
    $(ds t.ds, lines [(show-inference-diagnostic file src name.d diag) lines])
  ?:  (lien recovered |=(n=term =(n name.d)))
    =/  found=(unit ischeme)  (ienv-lookup name.d env)
    ?~  found  $(ds t.ds, lines [(crip "++ {(trip name.d)}: committed definition unavailable") lines])
    ?:  (itype-has-hidden-recursive typ.u.found)
      $(ds t.ds, lines [(crip "++ {(trip name.d)}: recursive mold name is not available in this scope") lines])
    ?:  (itype-has-hidden-generic typ.u.found)
      $(ds t.ds, lines [(crip "++ {(trip name.d)}: generic union name is not available in this scope") lines])
    =/  typ=itype  (canonical-itype typ.u.found vars.u.found)
    =/  line=@t  (crip "++ {(trip name.d)}: {(show-itype typ ~)}{(show-atom-constraint typ)}")
    $(ds t.ds, lines [line lines])
  ?:  (lien grouped.resolution |=(n=term =(n name.d)))
    =/  found=(unit ischeme)  (ienv-lookup name.d env)
    ?~  found  $(ds t.ds, lines [(crip "++ {(trip name.d)}: recursive group unavailable") lines])
    =/  typ=itype  (canonical-itype typ.u.found vars.u.found)
    =/  line=@t  (crip "++ {(trip name.d)}: {(show-itype typ ~)}{(show-atom-constraint typ)}")
    $(ds t.ds, lines [line lines])
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape] name.m))
  =/  initial=istate  [0 ~ ~ ~ molds globals externals surs mark-externals marks jimports reserved-molds ~ ~ ~ | file top prelude ~ 256 ~ ~ ~ ~ ~ ~]
  =.  gate-defs.initial  source-defs
  =.  head-evidence.initial  heads
  =.  initial  (reserve-def-caps val.d initial)
  =/  result=iresult
    ?:  |(?=(%gate -.val.d) ?=(%gate-wide -.val.d))
      (infer-recursive-gate d env initial)
    (infer-fragment val.d env initial)
  ?:  ?=(%| -.result)
    $(ds t.ds, lines [(show-inference-diagnostic file src name.d p.result) lines])
  =.  state.p.result  (promote-restricted-numbers state.p.result env)
  =.  state.p.result  (default-hole-numbers holes.state.p.result holes.initial state.p.result env !(itype-has-gate (itype-normalize typ.p.result sub.state.p.result)))
  =/  hole=(unit idiag)  (unresolved-hole holes.state.p.result holes.initial state.p.result)
  ?^  hole
    $(ds t.ds, lines [(show-inference-diagnostic file src name.d u.hole) lines])
  =/  merged=(unit [first=icap second=icap])
    (merged-capitals caps.state.p.result sub.state.p.result)
  ?^  merged
    =/  diag=idiag
      ["distinct type variables `{(trip name.first.u.merged)}` and `{(trip name.second.u.merged)}` must not be forced equal; use the same capital for a shared type" ~[[at.first.u.merged "first type variable"] [at.second.u.merged "second type variable"]]]
    $(ds t.ds, lines [(show-inference-diagnostic file src name.d diag) lines])
  ?:  (constrained-capitals caps.state.p.result sub.state.p.result)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: explicit capital constraints are not supported by partial inference") lines])
  =/  typ=itype  (default-decimals (itype-normalize typ.p.result sub.state.p.result))
  ?:  (pending-null tags.state.p.result sub.state.p.result)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: `~` needs context in partial inference") lines])
  ?:  |((pending-tags tags.state.p.result sub.state.p.result) (itype-has-tag typ))
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: tag needs context in partial inference") lines])
  ?:  (itype-has-hidden-recursive typ)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: recursive mold name is not available in this scope") lines])
  ?:  (itype-has-hidden-generic typ)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: generic union name is not available in this scope") lines])
  ?:  (unsupported-atom-vars typ caps.state.p.result binders.state.p.result sub.state.p.result)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: unresolved aura-variable inference") lines])
  =/  vars=(list @ud)  (unique-type-vars (itype-vars typ))
  ?:  (gth (lent vars) 26)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: too many variables for partial printer") lines])
  ?~  (width-finalize projections.state.p.result sub.state.p.result vars)
    $(ds t.ds, lines [(crip "++ {(trip name.d)}: record projection elaboration needs unsupported inference") lines])
  =/  printable=itype  (canonical-itype typ vars)
  =/  line=@t  (crip "++ {(trip name.d)}: {(show-itype printable ~)}{(show-atom-constraint printable)}")
  $(ds t.ds, lines [line lines])
::  Experimental module-owned pending-constraint generalization only.
::  Inputs, IDs and substitution come from one checker-owned transaction.
+$  dgscan  [ids=(list @ud) fuel=@ud]
++  dg-scan
  |=  [todo=(list itype) sub=isub fuel=@ud ids=(list @ud)]
  ^-  (unit dgscan)
  ?~  todo  `[ids fuel]
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  =/  t=itype  i.todo
  ?:  ?=(?(%var %avar %rvar %nvar %rnvar %tag) -.t)
    =/  node-id=@ud  ?:(?=(%tag -.t) id.t +.t)
    =/  found=(unit itype)  (itype-lookup node-id sub)
    ?~  found  $(todo t.todo, ids [node-id ids])
    ?:  &(?=(?(%rvar %rnvar) -.u.found) =(node-id +.u.found))
      $(todo t.todo, ids [node-id ids])
    $(todo [u.found t.todo])
  ?:  ?=(%jrec -.t)  $(todo t.todo)
  ?+  -.t  ~
    %collection  $(todo (weld args.t t.todo))
    %union  $(todo (weld args.t (weld cases.t t.todo)))
    %face  $(todo [body.t t.todo])
    %fn  $(todo [sample.t product.t t.todo])
    %cell  $(todo [hed.t tal.t t.todo])
    %atom  $(todo t.todo)
    %any-atom  $(todo t.todo)
    %flag  $(todo t.todo)
    %noun  $(todo t.todo)
    %const  $(todo t.todo)
  ==
::
++  dg-scan-ids
  |=  [ids=(list @ud) sub=isub fuel=@ud blocked=(list @ud)]
  ^-  (unit dgscan)
  ?~  ids  `[blocked fuel]
  =/  one=(unit dgscan)  (dg-scan ~[[%var i.ids]] sub fuel blocked)
  ?~  one  ~
  $(ids t.ids, fuel fuel.u.one, blocked ids.u.one)
::
++  dg-env
  |=  [env=ienv sub=isub fuel=@ud blocked=(list @ud)]
  ^-  (unit dgscan)
  ?~  env  `[blocked fuel]
  =/  sc=ischeme  scheme.i.env
  ::  Quantifiers are local to the scheme: first find raw free IDs, then
  ::  follow those IDs in the module substitution without capturing them.
  =/  raw=(unit dgscan)  (dg-scan ~[typ.sc] ~ fuel ~)
  ?~  raw  ~
  =/  free=(list @ud)  (skim ids.u.raw |=(n=@ud !(lien vars.sc |=(q=@ud =(q n)))))
  =/  resolved=(unit dgscan)  (dg-scan-ids free sub fuel.u.raw blocked)
  ?~  resolved  ~
  $(env t.env, fuel fuel.u.resolved, blocked ids.u.resolved)
::
++  dg-obligations
  |=  [pending=(list dgo) sub=isub fuel=@ud blocked=(list @ud)]
  ^-  (unit dgscan)
  ?~  pending  `[blocked fuel]
  =/  found=(unit dgscan)  (dg-scan ~[left.i.pending right.i.pending] sub fuel blocked)
  ?~  found  ~
  $(pending t.pending, fuel fuel.u.found, blocked ids.u.found)
::
++  dg-tags
  |=  [tags=(list ipending) sub=isub fuel=@ud blocked=(list @ud)]
  ^-  (unit dgscan)
  ?~  tags  `[blocked fuel]
  ?:  =(0 fuel)  ~
  =/  found=(unit itype)  (itype-lookup id.i.tags sub)
  ?~  found  $(tags t.tags, fuel (dec fuel), blocked [id.i.tags blocked])
  ::  Until this entry is explicitly discharged, retain variables reachable
  ::  through its binding; mere existence of a substitution is not proof.
  =/  reached=(unit dgscan)  (dg-scan ~[u.found] sub (dec fuel) blocked)
  ?~  reached  ~
  $(tags t.tags, fuel fuel.u.reached, blocked ids.u.reached)
::
++  dg-generalize
  |=  [typ=itype env=ienv pending=(list dgo) tags=(list ipending) captured=(list @ud) state=istate fuel=@ud]
  ^-  (unit ischeme)
  ::  Bound the obligation list and all graph/substitution walks. The
  ::  substitution is assumed checker-owned and occurs-checked.
  ?:  (gth (lent pending) 64)  ~
  =/  capt=(unit dgscan)  (dg-scan-ids captured sub.state fuel ~)
  ?~  capt  ~
  =/  env-free=(unit dgscan)  (dg-env env sub.state fuel.u.capt ids.u.capt)
  ?~  env-free  ~
  =/  obligations=(unit dgscan)  (dg-obligations pending sub.state fuel.u.env-free ids.u.env-free)
  ?~  obligations  ~
  =/  tagged=(unit dgscan)  (dg-tags tags sub.state fuel.u.obligations ids.u.obligations)
  ?~  tagged  ~
  =/  bounded=(unit dgscan)  (dg-scan ~[typ] sub.state fuel.u.tagged ~)
  ?~  bounded  ~
  =/  normalized=itype  (itype-normalize typ sub.state)
  =/  vars=(list @ud)  (unique-type-vars (itype-vars normalized))
  =/  quantified=(list @ud)  (skim vars |=(n=@ud !(lien ids.u.tagged |=(b=@ud =(b n)))))
  `[[normalized quantified]]
::
+$  dgcommit  [env=ienv state=istate]
++  dg-replay-edges
  |=  [edges=(list dgo) state=istate fuel=@ud]
  ^-  (unit istate)
  ?~  edges  `state
  ?:  =(0 fuel)  ~
  =/  trial=ifit  (itype-fit left.i.edges right.i.edges sub.state next.state)
  ?.  ?=(%ok -.trial)  ~
  ?.  =((itype-walk left.i.edges sub.trial) (itype-walk right.i.edges sub.trial))  ~
  $(edges t.edges, state state(sub sub.trial, next next.trial), fuel (dec fuel))
::
++  dg-close-env
  |=  [env=ienv sub=isub fuel=@ud]
  ^-  (unit ienv)
  ?~  env  `~
  ?:  =(0 fuel)  ~
  =/  s=ischeme  scheme.i.env
  :: Quantified IDs are scheme-local and cannot be rewritten on publication.
  ?.  (levy vars.s |=(n=@ud ?=(~ (itype-lookup n sub))))  ~
  =/  bounded=(unit dgscan)  (dg-scan ~[typ.s] sub (dec fuel) ~)
  ?~  bounded  ~
  =/  normalized=itype  (itype-normalize typ.s sub)
  ?:  (itype-has-tag normalized)  ~
  =/  vars=(list @ud)  (unique-type-vars (itype-vars normalized))
  ?.  (levy vars |=(n=@ud (lien vars.s |=(v=@ud =(v n)))))  ~
  =/  rest=(unit ienv)  (dg-close-env t.env sub fuel.u.bounded)
  ?~  rest  ~
  `[[name.i.env [normalized vars.s]] u.rest]
::
++  dg-stage
  |=  [ds=(list def) base=ienv env=ienv state=istate pending=(list dgo) fuel=@ud]
  ^-  (unit dgcommit)
  ?~  ds
    =/  replayed=(unit istate)  (dg-replay-edges pending state 64)
    ?~  replayed  ~
    ?:  (pending-tags tags.u.replayed sub.u.replayed)  ~
    =/  closed-edges=(unit dgscan)  (dg-obligations pending sub.u.replayed 32.768 ~)
    ?~  closed-edges  ~
    ?^  ids.u.closed-edges  ~
    =/  rechecked=(unit istate)  (dg-replay-edges pending u.replayed 64)
    ?~  rechecked  ~
    ?.  =(sub.u.rechecked sub.u.replayed)  ~
    ?.  =(next.u.rechecked next.u.replayed)  ~
    =/  closed=(unit ienv)  (dg-close-env env sub.u.replayed 32.768)
    ?~  closed  ~
    `[[u.closed u.replayed(defer ~, obligations ~)]]
  ?:  =(0 fuel)  ~
  =/  d=def  i.ds
  ?:  ?=(%mold -.d)  $(ds t.ds, fuel (dec fuel))
  ?^  (ienv-lookup name.d base)  $(ds t.ds, fuel (dec fuel))
  ?^  (ienv-lookup name.d env)  ~
  =/  local=istate  (reserve-def-caps val.d state)
  :: This first slice declines all written capitals and holes/projections.
  ?^  caps.local  ~
  =/  ordinary=iresult  (infer-fragment val.d env local)
  ?:  ?=(%| -.ordinary)  ~
  =/  typ=itype  typ.p.ordinary
  =/  after=istate  state.p.ordinary
  =/  edges=(list dgo)  obligations.after
  ?.  =(binders.after binders.state)  ~
  ?.  =(molds.after molds.state)  ~
  ?.  =(globals.after globals.state)  ~
  ?.  =(externals.after externals.state)  ~
  ?.  =(surs.after surs.state)  ~
  ?.  =(mark-externals.after mark-externals.state)  ~
  ?.  =(marks.after marks.state)  ~
  ?.  =(jimports.after jimports.state)  ~
  ?.  =(reserved-molds.after reserved-molds.state)  ~
  ?.  =(params.after params.state)  ~
  ?.  =(active.after active.state)  ~
  ?.  =(in-mold.after in-mold.state)  ~
  ?.  =(at.after at.state)  ~
  ?.  =(top-molds.after top-molds.state)  ~
  ?.  =(prelude.after prelude.state)  ~
  ?.  =(gate-defs.after gate-defs.state)  ~
  ?.  =(head-evidence.after head-evidence.state)  ~
  ?.  =(grec-index.after grec-index.state)  ~
  ?.  =(defer.after defer.state)  ~
  ?.  =(holes.after holes.state)  ~
  ?.  =(caps.after caps.state)  ~
  ?.  =(projections.after projections.state)  ~
  ?:  (unsupported-atom-vars (itype-normalize typ sub.after) caps.after binders.after sub.after)  ~
  ?:  (itype-has-nvar (itype-normalize typ sub.after))  ~
  =/  scheme=(unit ischeme)  (dg-generalize typ env edges tags.after ~ after 32.768)
  ?~  scheme  ~
  $(ds t.ds, env [[name.d u.scheme] env], state after, pending edges, fuel (dec fuel))
::
::  Cheap bounded eligibility check on the already parsed source. This
::  deliberately covers only direct constructor calls beneath transparent
::  groups, gates, casts and definition-free bodies. Other shapes decline
::  this fallback without a second parse or resolution pass.
++  dg-direct-source
  |=  [e=expr fuel=@ud]
  ^-  ?
  ?:  =(0 fuel)  |
  ?+  -.e  |
    %group  $(e inner.e, fuel (dec fuel))
    %gate  $(e body.e, fuel (dec fuel))
    %gate-wide  $(e body.e, fuel (dec fuel))
    %cast  $(e val.e, fuel (dec fuel))
    %body  ?~(defs.e $(e final.e, fuel (dec fuel)) |)
    %call
      ?.  ?=([* ~] args.e)  |
      ?=(%ctor -.i.args.e)
  ==
++  dg-source-candidate
  |=  [ds=(list def) fuel=@ud]
  ^-  ?
  ?~  ds  |
  ?:  =(0 fuel)  |
  ?.  ?=(%value -.i.ds)  $(ds t.ds, fuel (dec fuel))
  ?:  (dg-direct-source val.i.ds 64)  &
  $(ds t.ds, fuel (dec fuel))
::
++  dg-interface-safe
  |=  [env=ienv]
  ^-  ?
  ?~  env  &
  =/  sc=ischeme  scheme.i.env
  ?:  |((itype-has-hidden-recursive typ.sc) (itype-has-hidden-generic typ.sc))  |
  ?:  (gth (lent vars.sc) 26)  |
  $(env t.env)
::  Parse status and the transaction result come from the same source parse.
+$  dgparse  [parsed=? result=(unit dgcommit)]
++  dg-root-source
  |=  [at=path src=@t]
  ^-  (unit dgcommit)
  result:(dg-root-detail at src)
++  dg-root-detail
  |=  [at=path src=@t]
  ^-  dgparse
  =/  parsed  (parse at src)
  ?:  ?=(%| -.parsed)  [| ~]
  =/  transact
    |.
      ?^  imports.p.parsed  ~
      ?.  (module-scope-valid p.parsed ~ ~)  ~
      ?^  (duplicate-defs defs.p.parsed)  ~
      =/  defs=(list def)  defs.p.parsed
      ?:  (gth (lent defs) 64)  ~
      =/  molds=imolds  (collect-simple-molds defs)
      =/  globals=(list term)  (global-value-names defs)
      =/  resolution=iresolved  (resolve-groups defs molds globals ~ ~ ~ ~ ~ ~ at ~)
      ?^  grouped.resolution  ~
      ?^  artifacts.resolution  ~
      =/  base=ienv  env.resolution
      =/  free=(unit dgscan)  (dg-env base ~ 32.768 ~)
      ?~  free  ~
      ?^  ids.u.free  ~
      =/  all=(unit dgscan)  (dg-all-env-ids base 32.768 ~)
      ?~  all  ~
      =/  fresh=@ud  (dg-next-id ids.u.all 0)
      =/  st=istate  *istate
      =.  st  st(next fresh, defer `~, molds molds, globals globals, at at, top-molds (turn molds |=(m=[name=term body=shape] name.m)), in-mold |, jrec-fuel 256)
      =/  checked-molds=(each imold-types @t)  (module-mold-types molds st)
      ?:  ?=(%| -.checked-molds)  ~
      (dg-stage defs base base st ~ 64)
    ::
  [& (transact)]
++  dg-all-env-ids
  |=  [env=ienv fuel=@ud ids=(list @ud)]
  ^-  (unit dgscan)
  ?~  env  `[ids fuel]
  ?:  =(0 fuel)  ~
  =/  sc=ischeme  scheme.i.env
  ?:  (itype-has-tag typ.sc)  ~
  =/  raw=(unit dgscan)  (dg-scan ~[typ.sc] ~ (dec fuel) ids)
  ?~  raw  ~
  =/  quant=(unit dgscan)  (dg-scan-ids vars.sc ~ fuel.u.raw ids.u.raw)
  ?~  quant  ~
  $(env t.env, fuel fuel.u.quant, ids ids.u.quant)
::
++  dg-next-id
  |=  [ids=(list @ud) largest=@ud]
  ^-  @ud
  ?~  ids  +(largest)
  $(ids t.ids, largest (max largest i.ids))
::
++  dg-eligible-ctor
  |=  [e=expr head=itype actual=itype expected=itype state=istate]
  ^-  (unit dgo)
  ?.  ?=(%call -.e)  ~
  ?.  ?=([* ~] args.e)  ~
  ?.  ?=(%ctor -.i.args.e)  ~
  ?.  ?=(%fn -.head)  ~
  ?.  ?=(%fn -.expected)  ~
  ?.  ?=(%tag -.actual)  ~
  ?.  constructor.actual  ~
  ?.  ?=(%var -.product.expected)  ~
  ?^  (itype-lookup id.product.expected sub.state)  ~
  =/  bounded=(unit dgscan)  (dg-scan ~[sample.expected] sub.state 256 ~)
  ?~  bounded  ~
  ?^  ids.u.bounded  ~
  `[[actual expected (span-of i.args.e) (span-of head.e)]]
::
::  Experimental per-module, source-derived recursive tree index.
::  The two tags and the exact children/list/self layout are fixed-shape
::  checks, so ordinary definitions incur no type-tree or source scans.
++  grec-tagged-fields
  |=  sh=shape
  ^-  (unit [tag=@ fields=(list field)])
  ?.  ?=(%cell -.sh)  ~
  ?~  fields.sh  ~
  =/  head=field  i.fields.sh
  ?.  ?=(%bare -.head)  ~
  ?.  ?=(%const -.shape.head)  ~
  ?.  &(?=(%term form.lit.shape.head) =(%tas aura.lit.shape.head))  ~
  `[val.lit.shape.head t.fields.sh]
++  grec-tree-children
  |=  [fs=(list field) param=@t]
  ^-  (unit field)
  ?~  fs  ~
  ?~  t.fs  `i.fs
  ?^  t.t.fs  ~
  =/  event=field  i.fs
  =/  kids=field  i.t.fs
  ?.  &(?=(%face -.event) ?=(%face -.kids))  ~
  ?.  !=(name.event name.kids)  ~
  ?.  ?=(%fn -.shape.event)  ~
  ?.  ?=(%aura -.sample.shape.event)  ~
  ?.  =(%t aura.sample.shape.event)  ~
  ?.  ?=(%tvar -.product.shape.event)  ~
  ?.  =(param name.product.shape.event)  ~
  `kids
::
++  grec-tree-proof
  |=  [name=term sh=shape]
  ^-  ?
  ?.  ?=(%generic -.sh)  |
  ?.  ?=([@ ~] vars.sh)  |
  =/  param=@t  i.vars.sh
  ?.  ?=(%union -.body.sh)  |
  ?.  ?=([* [* ~]] cases.body.sh)  |
  =/  a=(unit [tag=@ fields=(list field)])  (grec-tagged-fields i.cases.body.sh)
  =/  b=(unit [tag=@ fields=(list field)])  (grec-tagged-fields i.t.cases.body.sh)
  ?~  a  |
  ?~  b  |
  ?.  !=(tag.u.a tag.u.b)  |
  ?.  ?=([* ~] fields.u.a)  |
  =/  value=field  i.fields.u.a
  ?.  ?=(%face -.value)  |
  ?.  ?=(%aura -.shape.value)  |
  ?.  =(%t aura.shape.value)  |
  =/  selected=(unit field)  (grec-tree-children fields.u.b param)
  ?~  selected  |
  =/  kids=field  u.selected
  ?.  ?=(%face -.kids)  |
  ?.  ?=(%apply -.shape.kids)  |
  ?.  =(ref.shape.kids ~[%list])  |
  ?.  ?=([* ~] args.shape.kids)  |
  =/  self=shape  i.args.shape.kids
  ?.  ?=(%apply -.self)  |
  ?.  =(ref.self ~[name])  |
  ?.  ?=([* ~] args.self)  |
  ?.  ?=(%tvar -.i.args.self)  |
  =(name.i.args.self param)
+$  grec-collected  [molds=imolds proofs=(map term shape)]
::  Experimental one-layer analysis view, never an exported mold identity.
++  grec-unfold-view
  |=  [typ=itype fuel=@ud]
  ^-  (unit [view=itype left=@ud])
  ?.  ?=(%grec -.typ)  ~
  ?:  =(fuel 0)  ~
  ?.  ?=([* ~] args.typ)  ~
  =/  sh=shape  proof.typ
  ?.  (grec-tree-proof name.typ sh)  ~
  ?>  ?=(%generic -.sh)
  ?>  ?=([@ ~] vars.sh)
  ?>  ?=(%union -.body.sh)
  ?>  ?=([* [* ~]] cases.body.sh)
  =/  ca=shape  i.cases.body.sh
  =/  cb=shape  i.t.cases.body.sh
  ?>  ?=(%cell -.ca)
  ?>  ?=(%cell -.cb)
  ?>  ?=([* [* ~]] fields.ca)
  ?>  ?=([* *] fields.cb)
  =/  tag-a=field  i.fields.ca
  =/  tag-b=field  i.fields.cb
  ?>  ?=(%bare -.tag-a)
  ?>  ?=(%bare -.tag-b)
  ?>  ?=(%const -.shape.tag-a)
  ?>  ?=(%const -.shape.tag-b)
  =/  text-field=field  i.t.fields.ca
  ?>  ?=(%face -.text-field)
  =/  branch=(list field)  t.fields.cb
  =/  kids=(unit field)  (grec-tree-children branch i.vars.sh)
  ?~  kids  ~
  ?>  ?=(%face -.u.kids)
  =/  children=itype  [%face name.u.kids [%collection %list ~[typ]]]
  ?>  ?=(^ branch)
  =/  payload=itype
    ?~  t.branch  children
    =/  event=field  i.branch
    ?>  ?=(%face -.event)
    [%cell [%face name.event [%fn [%atom %t] i.args.typ]] children]
  =/  leaf=itype  [%cell [%const lit.shape.tag-a] [%face name.text-field [%atom %t]]]
  =/  node=itype  [%cell [%const lit.shape.tag-b] payload]
  `[[%union ~[leaf node] ~ ~ ~] (dec fuel)]
::
++  grec-collect-molds
  |=  ds=(list def)
  ^-  grec-collected
  ?~  ds  [~ *(map term shape)]
  =/  rest=grec-collected  $(ds t.ds)
  ?.  ?=(%mold -.i.ds)  rest
  =/  name=term  name.i.ds
  =/  body=shape  shape.i.ds
  =/  proofs=(map term shape)  proofs.rest
  =?  proofs  (grec-tree-proof name body)  (~(put by proofs) name body)
  [[[name body] molds.rest] proofs]
::

--
