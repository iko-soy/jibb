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
::    +show-tokens   (list token)                 @t
::    +show-module   module                       @t
::    +show-error    [src=@t error]               @t
::  A file is a Clay path whose last segment is the extension, as the
::  golden runners pass /tests/golden/<case>/source/jibb. +layout never
::  fails: an error it finds is its last token (2.0), and +layout-error
::  takes it out.
::
::  Status: the types, the printers, +golden and the layout pass
::  (+layout, +lexer) work. +parse-tokens is a stub that returns an
::  error; it is implemented next, against the design below. Choices the
::  doc leaves open are marked "(doc question)": they follow the most
::  likely reading and are listed, with the doc's words, for the doc's
::  author to settle. The golden corpus's "expect:" lines give each
::  error's position. The layout pass's errors sit there, except where
::  the parser finds an earlier error first, as in `++ 2nd 5` (2.0, 2.8).
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
::  bracket, a body, ?-'s arms and $?'s cases end with their last line's
::  code, not at the line that closes them. Every node's span holds its
::  children's spans, in source order. The printed tree shows starts
::  only, and milestone 1's errors use starts only, so ends are first
::  tested by milestone 2's excerpts; the parser's own tests should check
::  the two rules above on every golden tree.
::
::  ===================================================================
::  2. The layout pass (+layout)
::  ===================================================================
::
::  +layout turns the text into tokens one line at a time: no token
::  crosses a line break, and only layout tokens join lines.
::
::  2.0 Errors. +layout never fails. Where the text breaks a rule of this
::  section, it emits one error token, [%error msg], at the first
::  character that breaks it, and stops reading. The parser accepts no
::  error token, so it reports whichever comes first, its own error or
::  this one (section 3, Errors). Every error, from either stage, points
::  at the first character where the text stops being the start of any
::  valid module: everything before it could still be right. Hoon's
::  parser reports errors the same way, and the golden corpus's expect
::  lines assume it. It also puts `++ x ]` on line 1 before a bad string
::  on line 9, which a lexer that failed first would report instead. The
::  positions below follow from it. Messages quote code in backticks, as
::  the parser's do (section 3, Errors).
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
::  arms, $?'s cases, a +$ mold on the next line. A bracket opened and
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
::    %a...          term literal: % and a name [a-z][a-z0-9-]*, [%tas name];
::                   a capital or _ right after it is an error there,
::                   "names are lowercase letters, digits and -"
::    %0...          term literal: % and digits [0-9]+, [%ud value]
::                   (doc question: digits only, as the EBNF says, so
::                   %1000 is a term and %1.000 an error at the dot); a
::                   letter, _, - or . right after it is an error there,
::                   "unexpected `a`: a numeric term is `%` and digits
::                   only, as %1000"
::    %              anything else after it: error at 2nd, "`%` begins a
::                   term, a loobean or `%/`"
::    /- /% /=       import glyphs at column 1, where imports go; anywhere
::                   else / is a path's, so ++ x /- is the path whose
::                   one segment is -, as the EBNF's knot allows
::    /              glyph, then a path segment may follow (2.7)
::    ++  +$  +      glyphs
::    |=(  |=  |$    glyphs
::    $?(  $?  $-(   glyphs; $- followed by anything but ( is an error
::                   at 3rd, "`$-` has only the wide form `$-(sample
::                   product)`"
::    ^-  ?-  !!  ?  glyphs (? alone is the loobean mold)
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
::                   "`$` begins `$?`, `$?(` or `$-(`", "`^` begins `^-`"
::    :              followed by anything but :, an error at 2nd: the
::                   table's :~ :* and a:b, else "a comment starts with
::                   `::`"
::    anything else  an error at it, naming it: "unexpected `,`", with a
::                   hint where one helps (+unexpected): for , . - and <,
::                   what Jibb writes instead
::
::  Hoon forms the doc leaves out are errors with the doc's reason, as
::  "`|%` is left out: modules are records". Each points where the text
::  stops being Jibb: at its second character when its first can begin
::  Jibb there, else at its first.
::
::    |%  |_  |*    2nd    modules are records
::    |-            2nd    gates recurse by name
::    $(            1st    gates recurse by name; no expression starts $
::    $%            2nd    $? covers unions
::    ?+  ?:        2nd    ?- is the branch (?:: is ? and a comment)
::    ?!            2nd    eq and not are gates
::    .=            1st    eq and not are gates
::    !x            2nd    not is a gate: ! then anything but ! or >
::    !>  /+        2nd    code also runs in the browser
::    =<  =>  .*    1st    names never shadow, and . reads imports too
::    a:b           2nd    of the :, right after a name: names never
::                         shadow, and . reads imports too; write a.b
::    :~  :*        2nd    indentation covers them; write ~[…] or […]
::    %:  %=        2nd    indentation covers them
::    ==  --        1st    the closers are left out: indentation covers
::                         them
::    ~|            2nd    ~& covers debugging
::    ;             1st    Sail's ; runes are left out: layout is Jibb's
::                         elements
::    '             1st    there is no '…' form: strings are "…"
::
::  The parser finds the doc's other left-out forms (section 3, Errors):
::  =(a b), =/, *mold, ^-(…) and ?-(…). The lexer can't, since =( =/ and *
::  begin valid Jibb too: open=(not open.s), scry=/todos, a * mold.
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
::  how much it read and how far it looked (p.edge):
::    - It read the whole run, as an aura Jibb takes: the token. Numbers
::      take %ud, %ux and %uv: 1.000, 0x1f, 0v5.fdf99 (Hoon reads 0x1F
::      too). ~ runs take %p, %da, %dr and %ta: ~zod, ~sampel-palnet,
::      ~2026.10.23..14.30.00, ~h1.m30, ~.my-post.
::    - It read the run or part of it as an aura Jibb doesn't take: 0w1,
::      0i1, ~~a (a cord), ~-a (a @c). An error at 2nd, "Jibb writes no
::      @uw literals". A run starting 0b, 0c, 0i or 0w gets that error
::      before nuck:so reads it, since no Jibb literal goes on that way:
::      Hoon's parser would read 0b, or a 0c1 whose checksum fails, as
::      the number 0 and an error past the run.
::    - It read only part of the run, as an aura Jibb takes: that part is
::      a token, then an error token at p.edge, the furthest character
::      Hoon's parser looked at, where Hoon reports it too. 1000 is the
::      token 100 and an error at its fourth digit ("a decimal is digits
::      in groups of three joined by dots, as 1.000": each kind of literal
::      has its message, +literal-msg); 0v5.fdfz9 is 0v5 and an error at the
::      z; ~2026.10.29..14.30 is ~2026.10.29 and an error just past the
::      run. The token lets the parser report an earlier error first: in
::      `++ 2nd 5` it finds the number 2 where a name goes, at 1:4.
::      When it read a ship, or only the ~ of a run that goes on with a
::      letter, the error goes instead at the first letter that no
::      syllable continues (+ship-stop), or just past a duration's unit,
::      d h m or s, if that is later: Hoon's parser reads a syllable's
::      three letters before it looks them up, so it looks past that
::      letter. `++ x ~x` fails at the x, 1:7, as no syllable starts with
::      x, and ~sampel-palnez at the z.
::  A run that starts as a date BC does, ~ and a year then -, fails at the
::  - if the year is 0 or past 292.277.024.401, before nuck:so sees it:
::  Hoon's +year crashes on those years, as in ~0-.1.1 (+year-bc).
::  The token is [%lit [form aura val]]: form names the literal rule that
::  matched, aura and val are the dime Hoon's parser gives. Terms,
::  loobeans and the bare ~ are read by hand (2.6).
::
::  2.9 Strings. A " starts a string, which ends on the same line. Up to
::  the closing ":
::    \\ \" \{ and \ with two lowercase hex digits are escapes, as in
::      Hoon's tapes (doc question: the doc names only \{ and \"). Any
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
::  `{…}`", and so is a {; inside a string, :: is text. A line that ends
::  inside a string or an interpolation is an error at its end, "this
::  string has no closing `\"` on its line" or "this `{` has no `}` on its
::  line". Token texts hold the decoded text. Spaces after { and before }
::  are allowed, as after any opener.
::
::  2.10 What fails here. Bad characters (2.2), an indented first line and
::  a dedent to no open level (2.4), characters that start no token or a
::  left-out form (2.6), malformed literals, auras, type variables and
::  wings (2.6, 2.8), a character that no token lets follow a path
::  segment, a ~. knot or a numeric term (2.6, 2.7), and unclosed strings
::  and interpolations, bad escapes and stray { or } (2.9). Everything
::  else is the parser's: brackets that don't match or don't close, a
::  missing or extra space, a deeper line that nothing takes, a token
::  where it can't go.
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
::  rune, so there |= is a constructor and needs its term at once:
::  (state.cart |= %got) is an error at the space after |=, 1:20. Loops
::  over many items (definitions, arms, lines, items) may recurse: vere's
::  stack takes ten million plain frames, so no Jibb file nests or runs
::  long enough to overflow it.
::
::  The EBNF and its nodes (see the types below):
::    module      { import NEWLINE } { definition NEWLINE }, then the end
::                of the tokens; an import after a definition is the error
::                "expected a definition, found `/-`; imports come first"
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
::                just grouped. A ( followed by a rune is the closed form.
::                Lines of an open group or list take no name= (doc
::                question)
::    change      every item and line has name= (the EBNF's "items named")
::    rune        |= -> %gate; ^- -> %cast; ~& -> %trace; ?- -> %branch;
::                !! -> %crash. !! is not an operand, so [a !!] needs
::                [a (!!)] (doc question)
::    sample      the sample of |= and |=(…): a field, except that a bare
::                name binds (%bind) wherever it stands in the sample: the
::                whole sample, as |= x and |=(p title.p), or a field of a
::                cell sample at any depth, as b in |= [a=@ b], which is
::                a %cell of samples (doc question). A name inside a mold,
::                as a in (list a), $-(a b) or $?(a b), is a mold
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
::    - pathlit as an operand (above), with / alone the empty path.
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
::    - Where errors point: the doc says only "line, column and an
::      excerpt"; 2.0 and Errors below say where.
::
::  Spacing. Two tokens on one line are separated by spaces, except:
::    - tight, always: name+operand (pair), `operand (unit), |=term
::      (constructor), wing( (change), name= and = value (faces, in items,
::      lines, fields and samples), =name (pun); in a path or application
::      path, each / and the segment after it, and all of a typed segment,
::      [id=@ud]
::    - either way: right after an opener ( [ ~[ |=( $?( $-( or {, and
::      right before a closer ) ] or } (the theme example writes `[ space=`),
::      the ( and ) of an application path's segment included; inside
::      them the expression is spaced as anywhere else, as %/x/(f a)
::  A missing space is an error at the tight token, and so is a space
::  inside a tight form, at the space (Errors). A rune with children, and
::  an import glyph, is followed by a space (or, for $? with its cases
::  below, the end of the line). Items are separated by one or more
::  spaces; how many isn't checked. This is how the parser makes "one
::  space between items; more for alignment" precise (doc question).
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
::    - At the token's start; for a layout token, at the start of the
::      line it begins, or just past the last token at the end of the
::      file (+where). So `++ view` above `++ main view` is an error at
::      2:1, the line that isn't deeper.
::    - Where a tight form needs its next token at once (after name+, `,
::      |= in an operand, name=, the = of a pun, a path's / and %/, a
::      typed segment's parts) and finds a space: at the end of the
::      previous token, where the space starts, "expected a term right
::      after `|=`, found a space" (+fail-space). A wing and a ( after a
::      space are no error: that is a call.
::    - At an error token: the lexer's position and message, unchanged.
::    - Three pattern errors point inside their token, where it stops
::      being a pattern: a date, duration or knot at its second character
::      (~ alone is null, and no ship goes on so), ~[ at its [, and a
::      string with {…} at its {.
::  In a bracket, a closer that doesn't match is "expected `]` to close
::  the `~[` at 1:6, found `)`", checked before spacing; after an item, a
::  tight token that isn't a closer is "expected a space between items,
::  found `M`". Hints name the left-out forms the lexer can't see (2.6):
::  where an expression starts, = followed tight by ( is "=(a b) is left
::  out: eq is a gate", = followed tight by / is "=/ is left out: ++
::  defines values", and * is "*mold is left out: no defaults"; ^- or ?-
::  followed tight by ( is "the wide form ^-(…) is left out: indentation
::  covers it". Examples:
::    expected `]` or an item on a deeper line, found a line at the same
::      depth
::    expected the end of the line, found a deeper line; only a bracket
::      open at the end of a line, or a rune's body, takes deeper lines
::    expected an expression, found `^-`; inside a call, a rune goes in
::      parentheses
::    expected a named item, found `x`; a change's items are named, as in
::      m(done=%.y)
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
::  lit (the literal as Hoon prints its dime: 1.000, 0x1f, ~zod, ~h1.m30,
::  ~.knot; terms as %add, %0, %& and %|; loobeans %.y and %.n; null ~),
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
::  last kid's line. (module …) always breaks. Bare fields and samples
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
      [%error p=tape]                                   ::  2.0: what broke
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
::    Never fails: an error it finds is its last token, [%error msg], at
::    the error's position (2.0). +lexer does the work.
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
::    error and the layout pass's (2.0). The stub reports an error token
::    that comes first, as the parser will, and fails otherwise.
::
++  parse-tokens
  |=  [file=path toks=(list token)]
  ^-  (each module error)
  ?:  ?=([[* * [%error *]] *] toks)
    (fail file toks "a module")
  =/  at=loc  ?~(toks [1 1] (where i.toks))
  [%| file line.at col.at "parser not implemented"]
::
::  +golden: both stages printed, or the rendered error
::
::    tokens: the layout pass's tokens, or its error if it found one
::    tree: the parser's tree, or the first error of either stage, which
::    the parser reports since it accepts no error token (2.0)
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
  ?^  bad  (show-error src u.bad)
  (show-module p.par)
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
  ++  err
    |=  [c=@ud msg=tape]
    ^+  cor
    cor(out [[[[lin c] [lin c]] | [%error msg]] out])
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
        %+  err  col
        "`={[b ~]}` is left out: names never shadow, and `.` reads imports too"
      ?:  =('=' b)
        (err col "the closer `==` is left out: indentation covers it")
      (emit 1 %'=')
    ?:  =('`' a)  (emit 1 %'`')
    ?:  =('*' a)  (emit 1 %'*')
    ?:  =('~' a)
      ?:  =('[' b)  (emit 2 %'~[')
      ?:  =('&' b)  (emit 2 %'~&')
      ?:  =('|' b)  (err +(col) "`~|` is left out: `~&` covers debugging")
      =/  n=@ud  (run-len t.cs knot-mask)
      ?:  =(0 n)  (emit 1 [%lit %null %n 0])
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
      ?:  &(=('?' b) =('(' c))  (emit 3 %'$?(')
      ?:  =('?' b)  (emit 2 %'$?')
      ?:  &(=('-' b) =('(' c))  (emit 3 %'$-(')
      ?:  =('-' b)
        (err (add 2 col) "`$-` has only the wide form `$-(sample product)`")
      ?:  =('(' b)  (err col "`$(…)` is left out: gates recurse by name")
      ?:  =('%' b)  (err +(col) "`$%` is left out: `$?` covers unions")
      (err +(col) "`$` begins `$?`, `$?(` or `$-(`")
    ?:  =('^' a)
      ?:  =('-' b)  (emit 2 %'^-')
      (err +(col) "`^` begins `^-`")
    ?:  =('?' a)
      ?:  =('-' b)  (emit 2 %'?-')
      ?:  =('+' b)  (err +(col) "`?+` is left out: `?-` is the branch")
      ?:  &(=(':' b) !=(':' c))
        (err +(col) "`?:` is left out: `?-` is the branch")
      ?:  =('!' b)  (err +(col) "`?!` is left out: eq and not are gates")
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
      ?:  =('y' c)  (emit 3 [%lit %loobean %f 0])
      ?:  =('n' c)  (emit 3 [%lit %loobean %f 1])
      (err (add 2 col) "the loobeans are `%.y` and `%.n`")
    ?:  =('&' b)  (emit 2 [%lit %term %f 0])
    ?:  =('|' b)  (emit 2 [%lit %term %f 1])
    ?:  =(':' b)  (err +(col) "`%:` is left out: indentation covers it")
    ?:  =('=' b)
      %+  err  +(col)
      "`%=` is left out: indentation covers it; write a change, as m(a=b)"
    =/  rest=tape  ?~(cs ~ t.cs)
    ?:  (is-lower b)
      =/  n=@ud  (run-len rest name-mask)
      =>  (emit +(n) [%lit %term %tas (crip (scag n rest))])
      ?.  &(?=(^ cs) |((is-upper i.cs) =('_' i.cs)))  cor
      (err col "names are lowercase letters, digits and -")
    ?:  (is-digit b)
      =/  n=@ud  (run-len rest digit-mask)
      =>  (emit +(n) [%lit %term %ud (decimal (scag n rest))])
      ?.  &(?=(^ cs) (in i.cs term-tail-mask))  cor
      %+  err  col
      "unexpected `{[i.cs ~]}`: a numeric term is `%` and digits only, as %1000"
    (err +(col) "`%` begins a term, a loobean or `%/`")
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
    ::  0b 0c 0i 0w begin auras Jibb doesn't write, whatever follows
    ?:  &(=('0' a) |(=('b' b) =('c' b) =('i' b) =('w' b)))
      (err +(col) "Jibb writes no @u{[b ~]} literals")
    ::  a year BC that Hoon's dates can't hold, which its date code
    ::  crashes on: an error at the - that makes it BC
    =/  bc=(unit [at=@ud y=@ud])  (year-bc col run)
    ?:  &(?=(^ bc) =(0 y.u.bc))
      (err at.u.bc "there is no year 0 BC: 1 BC is ~1-, as ~1-.1.1")
    ?:  &(?=(^ bc) (gth y.u.bc 292.277.024.401))
      (err at.u.bc "Hoon's dates begin in 292.277.024.401 BC")
    =/  ed  (nuck:so [[lin col] run])
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
    =/  lex=lexeme  [%lit u.form p.p.con q.p.con]
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
    (err:(emit used lex) at (literal-msg run p.p.con))
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
::  after a numeric term: a-z A-Z _ - .
++  term-tail-mask  0x7ff.fffe.87ff.fffe.0000.6000.0000.0000
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
  =/  lines=wall
    ?~  kids  ~["(module)"]
    :-  "(module"
    (close (zing (turn kids |=(k=sexp (render 2 k)))))
  (of-wain:format (turn lines crip))
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
::    At an error token, the layout pass's error instead (2.0). The token
::    list always ends with NEWLINE or an error token (2.5), and the
::    parser stops at either, so it never runs out; if it did, the error
::    would sit at 1:1.
::
++  fail
  |=  [file=path toks=(list token) want=tape]
  ^-  [%| p=error]
  ?~  toks  [%| file 1 1 "expected {want}, found the end of the tokens"]
  ?:  ?=([%error *] lex.i.toks)
    [%| file line.beg.at.i.toks col.beg.at.i.toks p.lex.i.toks]
  =/  l=loc  (where i.toks)
  [%| file line.l col.l "expected {want}, found {(show-found i.toks)}"]
::
::  +fail-space: a tight form found a space before its next token
::
::    The error sits where the space starts, just past prev, the token
::    that needs its next one at once (section 3, Errors). If the next
::    token is a layout or error token, it is +fail's error instead.
::
++  fail-space
  |=  [file=path prev=token toks=(list token) want=tape]
  ^-  [%| p=error]
  ?:  ?|  ?=(~ toks)
          ?=(?(%indent %dedent %newline) lex.i.toks)
          ?=([%error *] lex.i.toks)
      ==
    (fail file toks want)
  :+  %|  file
  :+  line.end.at.prev  col.end.at.prev
  "expected {want} right after {(show-found prev)}, found a space"
--
