::  /lib/jibb-core.hoon: independent Core text form and reference interpreter
::
::  API
::    +print-expr    expr                            @t
::    +print-module  module                          @t
::    +read-expr     [src=@t native-registry]        (each expr @t)
::    +read-module   [src=@t native-registry]        (each module @t)
::    +validate-expr [expr native-registry]          (unit @t)
::    +evaluate-env  [expr environment native-registry]  evaluation
::    +evaluate      [expr native-registry]              evaluation
::    +apply-value   [value value native-registry]       evaluation
::    +run-traced    [expr native-registry]              execution
::    +run           [expr native-registry]              outcome
::
::  Functions are values and may occur in cells, but are not nouns. Recursive
::  environments are finite frames: looking up a recursive arm makes a closure
::  over a freshly assembled frame for its group. Native lookup uses only the
::  explicit registry supplied by the caller.
::
|%
+$  literal  [aura=@ta val=@ txt=@t]
+$  name
  $~  [%own %x]
  $%  [%own name=@tas]
      [%qualified at=path name=@tas]
      [%generated name=@t]
  ==
+$  expr
  $~  [%lit [%ud 0 '0']]
  $%  [%lit lit=literal]
      [%var name=name]
      [%cons hed=expr tal=expr]
      [%slot axis=@ body=expr]
      [%edit axis=@ body=expr value=expr]
      [%cell body=expr]
      [%eq left=expr right=expr]
      [%if test=expr yes=expr no=expr]
      [%let name=name value=expr body=expr]
      [%rec arms=(list rec-arm) body=expr]
      [%lam sample=name body=expr]
      [%app fun=expr sample=expr]
      [%native name=name]
      [%crash ~]
      [%trace message=expr body=expr]
  ==
+$  rec-arm  [name=name fun=expr]
+$  definition  [name=name value=expr]
+$  module  [at=path defs=(list definition)]
+$  value
  $~  [%atom 0]
  $%  [%atom val=@]
      [%cell hed=value tal=value]
      [%closure sample=name body=expr env=environment]
      [%native name=name run=native]
  ==
+$  native  $-(value evaluation)
+$  native-registry  (map name native)
+$  binding
  $~  [%value [%own %x] [%atom 0]]
  $%  [%value name=name val=value]
      [%recursive name=name sample=name body=expr arms=(list rec-arm) parent=environment]
  ==
+$  environment  (list binding)
+$  evaluation  [val=value traces=(list @t)]
+$  outcome
  $~  [%crash ~]
  $%  [%ok val=noun]
      [%crash ~]
  ==
+$  execution  [out=outcome traces=(list @t)]
::
::  Internal text trees. Strings remain single word tokens, including spaces
::  and comment markers inside their quotes.
::
+$  token  [kind=?(%open %close %word) txt=@t]
+$  tree
  $~  [%atom '']
  $%  [%atom txt=@t]
      [%list items=(list tree)]
  ==
::
::  Canonical printers are single-line and whitespace-insensitive to read.
::  They never regenerate a literal from its numeric value: its retained text
::  is part of the textual representation contract.
::
++  join-text
  |=  [sep=@t items=(list @t)]
  ^-  @t
  ?~  items  ''
  =/  out=@t  i.items
  |-
  ?~  t.items  out
  $(items t.items, out (rap 3 ~[out sep i.t.items]))
::
++  print-path
  |=  at=path
  ^-  @t
  (join-text '/' (turn at |=(part=@ta (crip (trip part)))))
::
++  print-axis
  |=  axis=@
  ^-  @t
  =|  rev=tape
  |-
  =/  split=[quot=@ rem=@]  (dvr axis 10)
  =.  rev  [(add '0' rem.split) rev]
  ?:  =(0 quot.split)  (crip rev)
  $(axis quot.split)
::
++  print-name
  |=  n=name
  ^-  @t
  ?-  -.n
    %own        (crip (trip name.n))
    %qualified  (rap 3 ~[(print-path at.n) ':' (crip (trip name.n))])
    %generated  name.n
  ==
::
++  print-rec-arm
  |=  arm=rec-arm
  ^-  @t
  (rap 3 ~['(' (print-name name.arm) ' ' (print-expr fun.arm) ')'])
::
++  print-definition
  |=  def=definition
  ^-  @t
  (rap 3 ~['(def ' (print-name name.def) ' ' (print-expr value.def) ')'])
::
++  print-expr
  |=  e=expr
  ^-  @t
  ?-  -.e
    %lit     txt.lit.e
    %var     (print-name name.e)
    %cons    (rap 3 ~['(cons ' (print-expr hed.e) ' ' (print-expr tal.e) ')'])
    %slot    (rap 3 ~['(slot ' (print-axis axis.e) ' ' (print-expr body.e) ')'])
    %edit    (rap 3 ~['(edit ' (print-axis axis.e) ' ' (print-expr body.e) ' ' (print-expr value.e) ')'])
    %cell    (rap 3 ~['(cell? ' (print-expr body.e) ')'])
    %eq      (rap 3 ~['(eq ' (print-expr left.e) ' ' (print-expr right.e) ')'])
    %if      (rap 3 ~['(if ' (print-expr test.e) ' ' (print-expr yes.e) ' ' (print-expr no.e) ')'])
    %let     (rap 3 ~['(let ' (print-name name.e) ' ' (print-expr value.e) ' ' (print-expr body.e) ')'])
    %rec
      =/  printed-arms=(list @t)  (turn arms.e print-rec-arm)
      =/  printed-body=@t  (print-expr body.e)
      (rap 3 ~['(rec (' (join-text ' ' printed-arms) ') ' printed-body ')'])
    %lam     (rap 3 ~['(lam ' (print-name sample.e) ' ' (print-expr body.e) ')'])
    %app     (rap 3 ~['(app ' (print-expr fun.e) ' ' (print-expr sample.e) ')'])
    %native  (rap 3 ~['(native ' (print-name name.e) ')'])
    %crash   '(crash)'
    %trace   (rap 3 ~['(trace ' (print-expr message.e) ' ' (print-expr body.e) ')'])
  ==
::
++  print-module
  |=  m=module
  ^-  @t
  =/  defs=@t  (join-text ' ' (turn defs.m print-definition))
  ?~  defs.m  (rap 3 ~['(module ' (print-path at.m) ')'])
  (rap 3 ~['(module ' (print-path at.m) ' ' defs ')'])
::
::  Lexer and structural S-expression reader.
::
++  whitespace
  |=  c=@
  ^-  ?
  |(=(' ' c) =('\0a' c) =('\09' c) =('\0b' c) =('\0c' c) =('\0d' c))
::
++  comment-start
  |=  cs=tape
  ^-  ?
  ?=([%':' %':' *] cs)
::
++  scan-word
  |=  cs=tape
  ^-  [word=@t rest=tape]
  =|  rev=tape
  |-
  ?~  cs  [(crip (flop rev)) ~]
  ?:  |((whitespace i.cs) =('(' i.cs) =(')' i.cs) (comment-start cs))
    [(crip (flop rev)) cs]
  $(cs t.cs, rev [i.cs rev])
::
++  scan-string
  |=  [cs=tape rev=tape]
  ^-  (each [word=@t rest=tape] @t)
  ?~  cs  [%| 'unterminated string literal']
  ?:  |(=('\0a' i.cs) =('\0d' i.cs))
    [%| 'a string literal must close on its own line']
  ?:  |((lth i.cs 32) =(127 i.cs))
    [%| 'unescaped control character in string literal']
  ?:  =('"' i.cs)
    [%& [(crip (flop ['"' rev])) t.cs]]
  ?:  =('\\' i.cs)
    ?~  t.cs  [%| 'unterminated string escape']
    ?:  |(=('\0a' i.t.cs) =('\0d' i.t.cs))
      [%| 'a string literal must close on its own line']
    $(cs t.t.cs, rev [i.t.cs i.cs rev])
  $(cs t.cs, rev [i.cs rev])
::
++  skip-comment
  |=  cs=tape
  ^-  tape
  ?~  cs  ~
  ?:  |(=('\0a' i.cs) =('\0d' i.cs))  cs
  $(cs t.cs)
::
++  lex
  |=  src=@t
  ^-  (each (list token) @t)
  =/  cs=tape  (trip src)
  =|  rev=(list token)
  |-
  ?~  cs  [%& (flop rev)]
  ?:  (whitespace i.cs)  $(cs t.cs)
  ?:  (comment-start cs)  $(cs (skip-comment cs))
  ?:  =('(' i.cs)  $(cs t.cs, rev [[%open '('] rev])
  ?:  =(')' i.cs)  $(cs t.cs, rev [[%close ')'] rev])
  ?:  =('"' i.cs)
    =/  scanned  (scan-string t.cs ~['"'])
    ?:  ?=(%| -.scanned)  scanned
    $(cs rest.p.scanned, rev [[%word word.p.scanned] rev])
  =/  scanned  (scan-word cs)
  ?.  =('' word.scanned)
    $(cs rest.scanned, rev [[%word word.scanned] rev])
  [%| 'unexpected character in Core text']
::
++  parse-one
  |=  ts=(list token)
  ^-  (each [val=tree rest=(list token)] @t)
  ?~  ts  [%| 'expected an expression, found end of input']
  ?-  kind.i.ts
    %word   [%& [%atom txt.i.ts] t.ts]
    %close  [%| 'unexpected closing parenthesis']
    %open
      =/  rest=(list token)  t.ts
      =|  rev=(list tree)
      |-
      ?~  rest  [%| 'unterminated list']
      ?:  =(%close kind.i.rest)
        [%& [%list (flop rev)] t.rest]
      =/  item  (parse-one rest)
      ?:  ?=(%| -.item)  item
      $(rest rest.p.item, rev [val.p.item rev])
  ==
::
++  parse-root
  |=  src=@t
  ^-  (each tree @t)
  =/  tokens  (lex src)
  ?:  ?=(%| -.tokens)  tokens
  =/  parsed  (parse-one p.tokens)
  ?:  ?=(%| -.parsed)  parsed
  ?^  rest.p.parsed  [%| 'trailing input after the Core form']
  [%& val.p.parsed]
::
::  Names and paths.
::
++  lower
  |=  c=@
  ^-  ?
  &((gte c 'a') (lte c 'z'))
::
++  upper
  |=  c=@
  ^-  ?
  &((gte c 'A') (lte c 'Z'))
::
++  digit
  |=  c=@
  ^-  ?
  &((gte c '0') (lte c '9'))
::
++  valid-jname-tail
  |=  cs=tape
  ^-  ?
  ?~  cs  &
  ?.  |((lower i.cs) (digit i.cs) =('-' i.cs))  |
  $(cs t.cs)
::
++  valid-jname-tape
  |=  cs=tape
  ^-  ?
  ?~  cs  |
  ?.  (lower i.cs)  |
  (valid-jname-tail t.cs)
::
++  valid-jname
  |=  n=@t
  ^-  ?
  (valid-jname-tape (trip n))
::
++  generated-tail
  |=  cs=tape
  ^-  ?
  ?~  cs  |
  ?.  |((lower i.cs) (upper i.cs) (digit i.cs))  |
  ?~(t.cs & $(cs t.cs))
::
++  valid-generated
  |=  n=@t
  ^-  ?
  =/  cs=tape  (trip n)
  ?~  cs  |
  ?.  =('_' i.cs)  |
  (generated-tail t.cs)
::
++  valid-path-tail
  |=  at=path
  ^-  ?
  ?~  at  &
  ?.  (valid-jname i.at)  |
  $(at t.at)
::
++  valid-module-path
  |=  at=path
  ^-  ?
  ?~  at  |
  (valid-path-tail at)
::
++  valid-name
  |=  n=name
  ^-  ?
  ?-  -.n
    %own        (valid-jname name.n)
    %generated  (valid-generated name.n)
    %qualified  &((valid-jname name.n) (valid-module-path at.n))
  ==
::
++  split-tape
  |=  [sep=@ cs=tape]
  ^-  (list tape)
  =|  part=tape
  =|  out=(list tape)
  |-
  ?~  cs
    (flop [(flop part) out])
  ?:  =(sep i.cs)
    $(cs t.cs, part ~, out [(flop part) out])
  $(cs t.cs, part [i.cs part])
::
++  read-path
  |=  txt=@t
  ^-  (each path @t)
  =/  parts=(list tape)  (split-tape '/' (trip txt))
  =|  out=(list @ta)
  |-
  ?~  parts
    [%& (flop out)]
  ?.  (valid-jname-tape i.parts)
    [%| 'invalid module path']
  $(parts t.parts, out [(crip i.parts) out])
::
++  read-name
  |=  txt=@t
  ^-  (each name @t)
  =/  cs=tape  (trip txt)
  ?:  ?=([%'_' *] cs)
    ?:  (valid-generated txt)  [%& [%generated txt]]
    [%| 'invalid generated name']
  =/  qualified=(list tape)  (split-tape ':' cs)
  ?:  ?=([* ~] qualified)
    ?:  (valid-jname txt)  [%& [%own (crip i.qualified)]]
    [%| 'invalid own name']
  ?.  ?=([* * ~] qualified)
    [%| 'invalid qualified name']
  =/  at=(each path @t)  (read-path (crip i.qualified))
  ?-  -.at
    %|  [%| p.at]
    %&
      =/  good=path  p.at
      =/  n=@t  (crip i.t.qualified)
      ?.  (valid-jname n)  [%| 'invalid qualified name']
      [%& [%qualified good n]]
  ==
::
::  Literal reading uses Hoon's arbitrary-precision coin reader, then admits
::  only auras in Jibb's literal syntax. Strings are decoded here so that an
::  unescaped interpolation opener is rejected rather than evaluated.
::
++  hex
  |=  c=@
  ^-  (unit @ud)
  ?:  &((gte c '0') (lte c '9'))  `(sub c '0')
  ?:  &((gte c 'a') (lte c 'f'))  `(add 10 (sub c 'a'))
  ~
::
++  pack-bytes
  |=  bytes=tape
  ^-  @t
  =|  out=@t
  =|  offset=@
  |-
  ?~  bytes  out
  $(bytes t.bytes, out (add out (lsh [3 offset] i.bytes)), offset +(offset))
::
++  read-string
  |=  txt=@t
  ^-  (each literal @t)
  =/  cs=tape  (trip txt)
  ?.  ?=([%'"' *] cs)  [%| 'invalid string literal']
  =/  rest=tape  t.cs
  =|  rev=tape
  |-
  ?~  rest  [%| 'unterminated string literal']
  ?:  =('"' i.rest)
    ?^  t.rest  [%| 'trailing characters after a string literal']
    [%& [%t (pack-bytes (flop rev)) txt]]
  ?:  =('{' i.rest)
    [%| 'interpolated strings are not Core atom literals']
  ?:  |(=('\0a' i.rest) =('\0d' i.rest))
    [%| 'a string literal must close on its own line']
  ?:  |((lth i.rest 32) =(127 i.rest))
    [%| 'unescaped control character in string literal']
  ?.  =('\\' i.rest)
    $(rest t.rest, rev [i.rest rev])
  ?~  t.rest  [%| 'unterminated string escape']
  =/  esc=@  i.t.rest
  ?:  |(=('\\' esc) =('"' esc) =('{' esc))
    $(rest t.t.rest, rev [esc rev])
  =/  more=tape  t.t.rest
  ?~  more  [%| 'a string escape needs two lowercase hex digits']
  =/  hi=(unit @ud)  (hex esc)
  =/  lo=(unit @ud)  (hex i.more)
  ?~  hi  [%| 'invalid string escape']
  ?~  lo  [%| 'invalid string escape']
  $(rest t.more, rev [(add (mul 16 u.hi) u.lo) rev])
::
++  literal-aura
  |=  aura=@ta
  ^-  ?
  ?=(?(%ud %ux %uv %p %da %dr %ta %tas %f %n) aura)
::
++  read-term
  |=  txt=@t
  ^-  (each literal @t)
  =/  cs=tape  (trip txt)
  ?.  ?=([%'%' *] cs)  [%| 'invalid term literal']
  =/  rest=tape  t.cs
  ?:  =('%.y' txt)  [%& [%f 0 txt]]
  ?:  =('%.n' txt)  [%& [%f 1 txt]]
  ?:  =('%&' txt)  [%& [%f 0 txt]]
  ?:  =('%|' txt)  [%& [%f 1 txt]]
  ?:  =('%$' txt)  [%& [%tas 0 txt]]
  ?:  =('%0' txt)  [%& [%tas 0 txt]]
  ?~  rest  [%| 'invalid term literal']
  ?:  (digit i.rest)
    ?:  =('0' i.rest)  [%| 'invalid numeric term literal']
    =/  number=(each literal @t)  (read-literal (crip rest))
    ?-  -.number
      %|  [%| p.number]
      %&
        ?.  =(%ud aura.p.number)  [%| 'a numeric term must be decimal']
        [%& [%ud val.p.number txt]]
    ==
  ?.  (valid-jname-tape rest)  [%| 'invalid term literal']
  [%& [%tas (crip rest) txt]]
::
++  read-literal
  |=  txt=@t
  ^-  (each literal @t)
  =/  cs=tape  (trip txt)
  ?~  cs  [%| 'empty atom literal']
  ?:  =('"' i.cs)  (read-string txt)
  ?:  =('%' i.cs)  (read-term txt)
  =/  tried=(each (like coin) tang)
    (mule |.((nuck:so [[1 1] cs])))
  ?:  ?=(%| -.tried)  [%| 'invalid Core atom literal']
  =/  ed=(like coin)  p.tried
  ?~  q.ed  [%| 'invalid Core atom literal']
  ?^  q.q.u.q.ed  [%| 'invalid Core atom literal']
  =/  con=coin  p.u.q.ed
  ?.  ?=([%$ *] con)  [%| 'invalid Core atom literal']
  ?.  (literal-aura p.p.con)  [%| 'unsupported literal aura in Core']
  [%& [p.p.con q.p.con txt]]
::
++  literal-start
  |=  txt=@t
  ^-  ?
  =/  cs=tape  (trip txt)
  ?~  cs  |
  |((digit i.cs) =('~' i.cs) =('%' i.cs) =('"' i.cs))
::
++  decimal-digits
  |=  cs=tape
  ^-  ?
  ?~  cs  &
  ?.  (digit i.cs)  |
  $(cs t.cs)
::
++  decimal-value
  |=  cs=tape
  ^-  @
  =|  out=@
  |-
  ?~  cs  out
  $(cs t.cs, out (add (mul 10 out) (sub i.cs '0')))
::
++  read-axis
  |=  txt=@t
  ^-  (each @ @t)
  =/  cs=tape  (trip txt)
  ?~  cs  [%| 'an axis needs decimal digits']
  ?.  (decimal-digits cs)  [%| 'an axis needs decimal digits']
  =/  parsed=@  (decimal-value cs)
  ?:  =(0 parsed)  [%| 'Core axis 0 is invalid']
  [%& parsed]
::
::  Structural conversion. Arity is checked by each node before recursion.
::
++  tree-name
  |=  t=tree
  ^-  (each name @t)
  ?.  ?=(%atom -.t)  [%| 'expected a name']
  (read-name txt.t)
::
++  tree-axis
  |=  t=tree
  ^-  (each @ @t)
  ?.  ?=(%atom -.t)  [%| 'expected an axis']
  (read-axis txt.t)
::
++  expr-atom
  |=  txt=@t
  ^-  (each expr @t)
  ?:  (literal-start txt)
    =/  lit  (read-literal txt)
    ?:  ?=(%| -.lit)  lit
    [%& [%lit p.lit]]
  =/  n  (read-name txt)
  ?:  ?=(%| -.n)  n
  [%& [%var p.n]]
::
++  rec-arms
  |=  ts=(list tree)
  ^-  (each (list rec-arm) @t)
  ?~  ts  [%& ~]
  ?.  ?=(%list -.i.ts)  [%| 'a rec binding must be a list']
  ?.  ?=([* * ~] items.i.ts)  [%| 'a rec binding needs a name and a lam']
  =/  n  (tree-name i.items.i.ts)
  ?:  ?=(%| -.n)  n
  =/  fun  (expr-tree i.t.items.i.ts)
  ?:  ?=(%| -.fun)  fun
  ?.  ?=(%lam -.p.fun)  [%| 'every rec right side must be a lam']
  =/  rest  (rec-arms t.ts)
  ?:  ?=(%| -.rest)  rest
  [%& [[p.n p.fun] p.rest]]
::
++  expr-tree
  |=  t=tree
  ^-  (each expr @t)
  ?:  ?=(%atom -.t)  (expr-atom txt.t)
  ?~  items.t  [%| 'an empty list is not a Core expression']
  ?.  ?=(%atom -.i.items.t)  [%| 'a Core form needs an operator name']
  =/  op=@t  txt.i.items.t
  =/  args=(list tree)  t.items.t
  ?:  =('cons' op)
    ?.  ?=([* * ~] args)  [%| 'cons arity is 2']
    =/  a  (expr-tree i.args)
    ?:  ?=(%| -.a)  a
    =/  b  (expr-tree i.t.args)
    ?:  ?=(%| -.b)  b
    [%& [%cons p.a p.b]]
  ?:  =('slot' op)
    ?.  ?=([* * ~] args)  [%| 'slot arity is 2']
    =/  axis  (tree-axis i.args)
    ?:  ?=(%| -.axis)  axis
    =/  body  (expr-tree i.t.args)
    ?:  ?=(%| -.body)  body
    [%& [%slot p.axis p.body]]
  ?:  =('edit' op)
    ?.  ?=([* * * ~] args)  [%| 'edit arity is 3']
    =/  axis  (tree-axis i.args)
    ?:  ?=(%| -.axis)  axis
    =/  body  (expr-tree i.t.args)
    ?:  ?=(%| -.body)  body
    =/  val  (expr-tree i.t.t.args)
    ?:  ?=(%| -.val)  val
    [%& [%edit p.axis p.body p.val]]
  ?:  =('cell?' op)
    ?.  ?=([* ~] args)  [%| 'cell? arity is 1']
    =/  body  (expr-tree i.args)
    ?:  ?=(%| -.body)  body
    [%& [%cell p.body]]
  ?:  =('eq' op)
    ?.  ?=([* * ~] args)  [%| 'eq arity is 2']
    =/  a  (expr-tree i.args)
    ?:  ?=(%| -.a)  a
    =/  b  (expr-tree i.t.args)
    ?:  ?=(%| -.b)  b
    [%& [%eq p.a p.b]]
  ?:  =('if' op)
    ?.  ?=([* * * ~] args)  [%| 'if arity is 3']
    =/  c  (expr-tree i.args)
    ?:  ?=(%| -.c)  c
    =/  yes  (expr-tree i.t.args)
    ?:  ?=(%| -.yes)  yes
    =/  no  (expr-tree i.t.t.args)
    ?:  ?=(%| -.no)  no
    [%& [%if p.c p.yes p.no]]
  ?:  =('let' op)
    ?.  ?=([* * * ~] args)  [%| 'let arity is 3']
    =/  n  (tree-name i.args)
    ?:  ?=(%| -.n)  n
    =/  val  (expr-tree i.t.args)
    ?:  ?=(%| -.val)  val
    =/  body  (expr-tree i.t.t.args)
    ?:  ?=(%| -.body)  body
    [%& [%let p.n p.val p.body]]
  ?:  =('rec' op)
    ?.  ?=([* * ~] args)  [%| 'rec arity is 2']
    ?.  ?=(%list -.i.args)  [%| 'rec bindings must form a list']
    =/  arms  (rec-arms items.i.args)
    ?:  ?=(%| -.arms)  arms
    =/  body  (expr-tree i.t.args)
    ?:  ?=(%| -.body)  body
    [%& [%rec p.arms p.body]]
  ?:  =('lam' op)
    ?.  ?=([* * ~] args)  [%| 'lam arity is 2']
    =/  n  (tree-name i.args)
    ?:  ?=(%| -.n)  n
    =/  body  (expr-tree i.t.args)
    ?:  ?=(%| -.body)  body
    [%& [%lam p.n p.body]]
  ?:  =('app' op)
    ?.  ?=([* * ~] args)  [%| 'app arity is 2']
    =/  fun  (expr-tree i.args)
    ?:  ?=(%| -.fun)  fun
    =/  sample  (expr-tree i.t.args)
    ?:  ?=(%| -.sample)  sample
    [%& [%app p.fun p.sample]]
  ?:  =('native' op)
    ?.  ?=([* ~] args)  [%| 'native arity is 1']
    =/  n  (tree-name i.args)
    ?:  ?=(%| -.n)  n
    [%& [%native p.n]]
  ?:  =('crash' op)
    ?.  ?=(~ args)  [%| 'crash arity is 0']
    [%& [%crash ~]]
  ?:  =('trace' op)
    ?.  ?=([* * ~] args)  [%| 'trace arity is 2']
    =/  message  (expr-tree i.args)
    ?:  ?=(%| -.message)  message
    =/  body  (expr-tree i.t.args)
    ?:  ?=(%| -.body)  body
    [%& [%trace p.message p.body]]
  [%| 'unknown Core operator']
::
++  duplicate-name
  |=  ns=(list name)
  ^-  (unit name)
  ?~  ns  ~
  ?:  (lien t.ns |=(n=name =(n i.ns)))  `i.ns
  $(ns t.ns)
::
++  validation-both
  |=  [first=(unit @t) second=(unit @t)]
  ^-  (unit @t)
  ?^(first first second)
::
++  name-visible
  |=  [wanted=name scope=(list name)]
  ^-  ?
  ?~  scope  |
  ?:  =(wanted i.scope)  &
  $(scope t.scope)
::
++  validate-scoped
  |=  [e=expr registry=native-registry scope=(list name)]
  ^-  (unit @t)
  ?-  -.e
    %lit
      =/  lit  (read-literal txt.lit.e)
      ?:  ?=(%| -.lit)  `p.lit
      ?.  &(=(aura.p.lit aura.lit.e) =(val.p.lit val.lit.e))
        `'literal text, aura, and value disagree'
      ~
    %var      ?.((valid-name name.e) `'invalid name' ~)
    %cons     (validation-both (validate-scoped hed.e registry scope) (validate-scoped tal.e registry scope))
    %slot
      ?:  =(0 axis.e)  `'Core axis 0 is invalid'
      (validate-scoped body.e registry scope)
    %edit
      ?:  =(0 axis.e)  `'Core axis 0 is invalid'
      ?~  a=(validate-scoped body.e registry scope)
        (validate-scoped value.e registry scope)
      a
    %cell     (validate-scoped body.e registry scope)
    %eq       (validation-both (validate-scoped left.e registry scope) (validate-scoped right.e registry scope))
    %if
      ?~  a=(validate-scoped test.e registry scope)
        (validation-both (validate-scoped yes.e registry scope) (validate-scoped no.e registry scope))
      a
    %let
      ?.  (valid-name name.e)  `'invalid binding name'
      =/  bad  (validate-scoped value.e registry scope)
      ?^  bad  bad
      ?:  (name-visible name.e scope)  `'binding shadows an enclosing binding'
      (validate-scoped body.e registry [name.e scope])
    %rec
      =/  names=(list name)  (turn arms.e |=(a=rec-arm name.a))
      =/  duplicate  (duplicate-name names)
      ?^  duplicate  `'duplicate rec binding'
      =/  check=(list name)  names
      |-
      ?~  check
        =/  inner=(list name)  (weld names scope)
        =/  check-arms=(list rec-arm)  arms.e
        |-
        ?~  check-arms  (validate-scoped body.e registry inner)
        ?.  ?=(%lam -.fun.i.check-arms)  `'every rec right side must be a lam'
        =/  bad  (validate-scoped fun.i.check-arms registry inner)
        ?^  bad  bad
        $(check-arms t.check-arms)
      ?.  (valid-name i.check)  `'invalid rec binding name'
      ?:  (name-visible i.check scope)  `'rec binding shadows an enclosing binding'
      $(check t.check)
    %lam
      ?.  (valid-name sample.e)  `'invalid lambda sample name'
      ?:  (name-visible sample.e scope)  `'lambda sample shadows an enclosing binding'
      (validate-scoped body.e registry [sample.e scope])
    %app      (validation-both (validate-scoped fun.e registry scope) (validate-scoped sample.e registry scope))
    %native
      ?.  (valid-name name.e)  `'invalid native name'
      ?:  (~(has by registry) name.e)  ~
      `'unknown native'
    %crash    ~
    %trace    (validation-both (validate-scoped message.e registry scope) (validate-scoped body.e registry scope))
  ==
::
++  validate-expr
  |=  [e=expr registry=native-registry]
  ^-  (unit @t)
  (validate-scoped e registry ~)
::
++  read-expr
  |=  [src=@t registry=native-registry]
  ^-  (each expr @t)
  =/  root  (parse-root src)
  ?:  ?=(%| -.root)  root
  =/  e  (expr-tree p.root)
  ?:  ?=(%| -.e)  e
  =/  bad  (validate-expr p.e registry)
  ?^  bad  [%| u.bad]
  e
::
++  module-tree
  |=  [t=tree registry=native-registry]
  ^-  (each module @t)
  ?.  ?=(%list -.t)  [%| 'expected a module form']
  ?.  ?=([* * *] items.t)  [%| 'a module needs a path']
  ?.  ?=(%atom -.i.items.t)  [%| 'expected module']
  ?.  =('module' txt.i.items.t)  [%| 'expected module']
  ?.  ?=(%atom -.i.t.items.t)  [%| 'a module path must be an atom']
  =/  at  (read-path txt.i.t.items.t)
  ?:  ?=(%| -.at)  at
  =/  ds=(list tree)  t.t.items.t
  =|  defs=(list definition)
  |-
  ?~  ds
    =/  m=module  [p.at (flop defs)]
    =/  names=(list name)  (turn defs.m |=(d=definition name.d))
    =/  duplicate  (duplicate-name names)
    ?^  duplicate  [%| 'duplicate module definition']
    =/  check=(list definition)  defs.m
    |-
    ?~  check  [%& m]
    =/  bad  (validate-scoped value.i.check registry names)
    ?^  bad  [%| u.bad]
    $(check t.check)
  ?.  ?=(%list -.i.ds)  [%| 'a module member must be a def form']
  ?.  ?=([* * * ~] items.i.ds)  [%| 'def arity is 2']
  ?.  ?=(%atom -.i.items.i.ds)  [%| 'expected def']
  ?.  =('def' txt.i.items.i.ds)  [%| 'a module member must be a def form']
  =/  n  (tree-name i.t.items.i.ds)
  ?:  ?=(%| -.n)  n
  =/  val  (expr-tree i.t.t.items.i.ds)
  ?:  ?=(%| -.val)  val
  $(ds t.ds, defs [[p.n p.val] defs])
::
++  read-module
  |=  [src=@t registry=native-registry]
  ^-  (each module @t)
  =/  root  (parse-root src)
  ?:  ?=(%| -.root)  root
  (module-tree p.root registry)
::  Convert a complete value to a noun, rejecting functions at any depth.
::
++  value-noun
  |=  v=value
  ^-  noun
  ?-  -.v
    %atom                val.v
    %cell                [$(v hed.v) $(v tal.v)]
    ?(%closure %native)  !!
  ==
::
::  Nock axes are arbitrary-precision atoms. cap/mas consume one path bit per
::  step rather than converting an axis to a machine integer.
::
++  slot-inner
  |=  [axis=@ v=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  =(1 axis)  v
  ?.  ?=(%cell -.v)  !!
  ?-  (cap axis)
    %2  $(axis (mas axis), v hed.v)
    %3  $(axis (mas axis), v tal.v)
  ==
::
++  slot-value
  |=  [axis=@ v=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  ?=(%closure -.v)  !!
  ?:  ?=(%native -.v)  !!
  (slot-inner axis v)
::
++  edit-value
  |=  [axis=@ old=value new=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  ?=(%closure -.old)  !!
  ?:  ?=(%native -.old)  !!
  ?:  =(1 axis)  new
  ?.  ?=(%cell -.old)  !!
  ?-  (cap axis)
    %2  [%cell $(axis (mas axis), old hed.old) tal.old]
    %3  [%cell hed.old $(axis (mas axis), old tal.old)]
  ==
::
++  lookup
  |=  [n=name env=environment]
  ^-  value
  ?~  env  !!
  ?.  =(n name.i.env)  $(env t.env)
  ?-  -.i.env
    %value      val.i.env
    %recursive  [%closure sample.i.env body.i.env (rec-env arms.i.env parent.i.env)]
  ==
::
++  rec-env
  |=  [arms=(list rec-arm) parent=environment]
  ^-  environment
  =/  made=(list binding)
    %+  turn  arms
    |=  arm=rec-arm
    ?>  ?=(%lam -.fun.arm)
    [%recursive name.arm sample.fun.arm body.fun.arm arms parent]
  (weld made parent)
::
++  apply-value
  |=  [fun=value sample=value registry=native-registry]
  ^-  evaluation
  ?-  -.fun
    ?(%atom %cell)  !!
    %closure
      (evaluate-env body.fun [[%value sample.fun sample] env.fun] registry)
    %native
      (run.fun sample)
  ==
::
++  evaluate-env
  |=  [e=expr env=environment registry=native-registry]
  ^-  evaluation
  ?-  -.e
    %lit   [[%atom val.lit.e] ~]
    %var   [(lookup name.e env) ~]
    %cons
      =/  hed  (evaluate-env hed.e env registry)
      =/  tal  (evaluate-env tal.e env registry)
      [[%cell val.hed val.tal] (weld traces.hed traces.tal)]
    %slot
      =/  body  (evaluate-env body.e env registry)
      [(slot-value axis.e val.body) traces.body]
    %edit
      =/  body  (evaluate-env body.e env registry)
      =/  val  (evaluate-env value.e env registry)
      [(edit-value axis.e val.body val.val) (weld traces.body traces.val)]
    %cell
      =/  body  (evaluate-env body.e env registry)
      ?:  ?=(%closure -.val.body)  !!
      ?:  ?=(%native -.val.body)  !!
      [[%atom ?:(?=(%cell -.val.body) 0 1)] traces.body]
    %eq
      =/  left  (evaluate-env left.e env registry)
      =/  right  (evaluate-env right.e env registry)
      =/  same=?  =((value-noun val.left) (value-noun val.right))
      [[%atom ?:(same 0 1)] (weld traces.left traces.right)]
    %if
      =/  test  (evaluate-env test.e env registry)
      ?.  ?=(%atom -.val.test)  !!
      ?.  |(=(0 val.val.test) =(1 val.val.test))  !!
      =/  branch=expr  ?:(=(0 val.val.test) yes.e no.e)
      =/  result  (evaluate-env branch env registry)
      result(traces (weld traces.test traces.result))
    %let
      =/  val  (evaluate-env value.e env registry)
      =/  body  (evaluate-env body.e [[%value name.e val.val] env] registry)
      body(traces (weld traces.val traces.body))
    %rec
      (evaluate-env body.e (rec-env arms.e env) registry)
    %lam
      [[%closure sample.e body.e env] ~]
    %app
      =/  fun  (evaluate-env fun.e env registry)
      =/  sample  (evaluate-env sample.e env registry)
      =/  called  (apply-value val.fun val.sample registry)
      called(traces (weld (weld traces.fun traces.sample) traces.called))
    %native
      =/  found  (~(get by registry) name.e)
      ?~  found  !!
      [[%native name.e u.found] ~]
    %crash
      !!
    %trace
      =/  message  (evaluate-env message.e env registry)
      ?.  ?=(%atom -.val.message)  !!
      ~&  val.val.message
      =/  body  (evaluate-env body.e env registry)
      body(traces (weld traces.message [val.val.message traces.body]))
  ==
::
++  evaluate
  |=  [e=expr registry=native-registry]
  ^-  evaluation
  (evaluate-env e ~ registry)
::
::  The sole trap is outside both evaluation and canonical noun conversion.
::  A crash in either phase has the same canonical result.
::
++  run-traced
  |=  [e=expr registry=native-registry]
  ^-  execution
  =/  tried=(each [val=noun traces=(list @t)] tang)
    %-  mule
    |.
    =/  got=evaluation  (evaluate e registry)
    [(value-noun val.got) traces.got]
  ?:  ?=(%| -.tried)  [[%crash ~] ~]
  [[%ok val.p.tried] traces.p.tried]
::
++  run
  |=  [e=expr registry=native-registry]
  ^-  outcome
  out:(run-traced e registry)
--
