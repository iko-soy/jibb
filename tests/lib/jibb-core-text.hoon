::  Core text-form reader, printer, and validation checks.
::  These tests are independent of the surface Jibb parser and checker.
/+  jibb-core
|%
++  empty-registry
  ^-  native-registry:jibb-core
  *(map name:jibb-core native:jibb-core)
::
++  own
  |=  n=@tas
  ^-  name:jibb-core
  [%own n]
::
++  pack-test-bytes
  |=  bytes=(list @ud)
  ^-  @t
  =|  out=@t
  =|  offset=@
  |-
  ?~  bytes  out
  $(bytes t.bytes, out (add out (lsh [3 offset] i.bytes)), offset +(offset))
::
++  inc-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  [[%atom +(val.v)] ~]
::
++  registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  empty-registry
  =.  r  (~(put by r) (own %inc) inc-native)
  =.  r  (~(put by r) (own %dec) inc-native)
  =.  r  (~(put by r) [%qualified /prelude %join] inc-native)
  (~(put by r) [%generated '_Native9'] inc-native)
::
++  rejected
  |=  src=@t
  ^-  ?
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src registry)
  ?=(%| -.parsed)
::
++  rejected-module
  |=  src=@t
  ^-  ?
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core src registry)
  ?=(%| -.parsed)
::
++  rejection-error
  |=  [sources=(list @t) label=@t]
  ^-  (unit @t)
  ?~  sources  ~
  ?.  (rejected i.sources)  `(rap 3 ~[label ': ' i.sources])
  $(sources t.sources)
::
++  module-rejection-error
  |=  sources=(list @t)
  ^-  (unit @t)
  ?~  sources  ~
  ?.  (rejected-module i.sources)  `(cat 3 'malformed module accepted: ' i.sources)
  $(sources t.sources)
::
++  round-trip-error
  |=  sources=(list @t)
  ^-  (unit @t)
  ?~  sources  ~
  =/  src=@t  i.sources
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src registry)
  ?:  ?=(%| -.parsed)  `(rap 3 ~['reader rejected ' src ': ' p.parsed])
  =/  printed=@t  (print-expr:jibb-core p.parsed)
  ?.  =(src printed)  `(rap 3 ~['noncanonical print for ' src ': ' printed])
  =/  again=(each expr:jibb-core @t)  (read-expr:jibb-core printed registry)
  ?:  ?=(%| -.again)  `(cat 3 'printer emitted unreadable text: ' src)
  ?.  =(p.parsed p.again)  `(cat 3 'round trip changed AST: ' src)
  $(sources t.sources)
::
++  literal-error
  |=  cases=(list [src=@t aura=@ta val=@])
  ^-  (unit @t)
  ?~  cases  ~
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src.i.cases registry)
  ?:  ?=(%| -.parsed)  `(rap 3 ~['literal rejected: ' src.i.cases ': ' p.parsed])
  ?.  ?=([%lit *] p.parsed)  `(cat 3 'not a literal: ' src.i.cases)
  =/  lit=literal:jibb-core  lit.p.parsed
  ?.  =(aura.i.cases aura.lit)  `(cat 3 'wrong literal aura: ' src.i.cases)
  ?.  =(val.i.cases val.lit)  `(cat 3 'wrong literal value: ' src.i.cases)
  ?.  =(src.i.cases txt.lit)  `(cat 3 'literal spelling changed: ' src.i.cases)
  $(cases t.cases)
::
++  diagnostic-is
  |=  [src=@t expected=@t]
  ^-  ?
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src registry)
  &(?=(%| -.parsed) =(expected p.parsed))
::
++  module-diagnostic-is
  |=  [src=@t expected=@t]
  ^-  ?
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core src registry)
  &(?=(%| -.parsed) =(expected p.parsed))
::
++  validation-is
  |=  [e=expr:jibb-core expected=(unit @t)]
  ^-  ?
  =((validate-expr:jibb-core e registry) expected)
::
++  test-core-literal-families-and-spelling
  ^-  tang
  =/  sources=(list @t)
    :~  '0'
        '42'
        '1.000'
        '12.345.678.901.234.567.890.123.456.789.012.345.678.901.234.567.890'
        '0xdead.beef.0123.4567.89ab.cdef'
        '0x1.0000.0000.0000.0000.0000.0000.0000.0001'
        '0v0'
        '0v5.fdf99'
        '0v1.00000.00000.00000.00000.00000.00000.00000.00001'
        '0v1234.56789.abcde.fghij.klmno'
        '""'
        '"milk"'
        '"Unicode: 😀 λ"'
        '"quote \\" and hex\\0a"'
        '"nul\\00end"'
        '"escaped Unicode: \\ce\\bb \\f0\\9f\\98\\80"'
        '":: not a comment"'
        '"escaped brace \\{ stays text"'
        '%add'
        '%1.000'
        '%&'
        '%|'
        '%$'
        '%0'
        '%.y'
        '%.n'
        '~'
        '~zod'
        '~2026.11.8..01.02.03'
        '~0.1.1'
        '~1-.1.1'
        '~s30'
        '~h1.m30'
        '~.my-post'
    ==
  =/  bad  (round-trip-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  cases=(list [src=@t aura=@ta val=@])
    :~  ['1.000' %ud 1.000]
        ['12.345.678.901.234.567.890.123.456.789.012.345.678.901.234.567.890' %ud 12.345.678.901.234.567.890.123.456.789.012.345.678.901.234.567.890]
        ['0xdead.beef' %ux 0xdead.beef]
        ['0v0' %uv 0]
        ['0v10' %uv 32]
        ['0v5.fdf99' %uv 0v5.fdf99]
        ['0v1.00000.00000.00000.00000.00000.00000.00000.00001' %uv 0v1.00000.00000.00000.00000.00000.00000.00000.00001]
        ['"milk"' %t 'milk']
        ['"nul\\00end"' %t (pack-test-bytes ~[110 117 108 0 101 110 100])]
        ['"\\ce\\bb"' %t 'λ']
        ['%add' %tas %add]
        ['%1.000' %ud 1.000]
        ['%.y' %f 0]
        ['%.n' %f 1]
        ['%&' %f 0]
        ['%|' %f 1]
        ['%$' %tas 0]
        ['%0' %tas 0]
        ['~' %n 0]
        ['~zod' %p ~zod]
        ['~2026.11.8..01.02.03' %da ~2026.11.8..01.02.03]
        ['~0.1.1' %da ~1-.1.1]
        ['~1-.1.1' %da ~1-.1.1]
        ['~h1.m30' %dr ~h1.m30]
        ['~.my-post' %ta 'my-post']
    ==
  =/  wrong  (literal-error cases)
  ?^  wrong  ~[leaf+(trip u.wrong)]
  =/  huge=(each expr:jibb-core @t)
    (read-expr:jibb-core '0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff' registry)
  ?:  ?=(%| -.huge)  ~[leaf+"big hexadecimal literal did not read"]
  ?.  ?=([%lit *] p.huge)  ~[leaf+"big literal produced a nonliteral node"]
  ?.  &(=(%ux aura.lit.p.huge) =(0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff val.lit.p.huge))
    ~[leaf+"big literal lost its value or aura"]
  ~
::
++  test-core-all-nodes-and-names-round-trip
  ^-  tang
  =/  sources=(list @t)
    :~  'plain-name'
        'api/todo:todo-action'
        '_name'
        '_Generated9'
        '_0'
        '(cons 1 2)'
        '(slot 3 (cons 1 2))'
        '(edit 2 (cons 1 2) 9)'
        '(cell? (cons 1 2))'
        '(eq 1 1)'
        '(if %.y 1 2)'
        '(let x 1 x)'
        '(rec () ~)'
        '(rec ((even (lam n (if (eq n 0) %.y (app odd (app (native dec) n))))) (odd (lam n (if (eq n 0) %.n (app even (app (native dec) n)))))) (app even 10))'
        '(lam x x)'
        '(app (lam x x) 1)'
        '(native inc)'
        '(native prelude:join)'
        '(native _Native9)'
        '(crash)'
        '(trace "hello" 7)'
    ==
  =/  bad  (round-trip-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  free=(each expr:jibb-core @t)  (read-expr:jibb-core '(app missing also-missing)' registry)
  ?:  ?=(%| -.free)  ~[leaf+"reader invented free-variable checking"]
  =/  untyped=(each expr:jibb-core @t)  (read-expr:jibb-core '(app 1 (slot 2 0))' registry)
  ?:  ?=(%| -.untyped)  ~[leaf+"reader invented function or noun type checking"]
  ~
::
++  test-core-comments-whitespace-and-modules
  ^-  tang
  =/  src=@t
    %-  of-wain:format
    :~  ':: module comment'
        '  (module api/todo'
        '    (def answer 42)  :: definition comment'
        '    (def _2 api/todo:todo-action)'
        '    (def call (app (native inc) 2)))'
        ':: trailing comment'
    ==
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core src registry)
  ?:  ?=(%| -.parsed)  ~[leaf+(trip p.parsed)]
  =/  canonical=@t
    '(module api/todo (def answer 42) (def _2 api/todo:todo-action) (def call (app (native inc) 2)))'
  ?.  =(canonical (print-module:jibb-core p.parsed))  ~[leaf+"module printer was not canonical"]
  =/  again=(each module:jibb-core @t)  (read-module:jibb-core canonical registry)
  ?:  ?=(%| -.again)  ~[leaf+"canonical module did not read"]
  ?.  =(p.parsed p.again)  ~[leaf+"module round trip changed definitions"]
  ?.  =(3 (lent defs.p.parsed))  ~[leaf+"module reader lost a definition"]
  =/  empty=(each module:jibb-core @t)  (read-module:jibb-core '(module empty)' registry)
  ?:  ?=(%| -.empty)  ~[leaf+"empty module was rejected"]
  ?.  =('(module empty)' (print-module:jibb-core p.empty))  ~[leaf+"empty module printed incorrectly"]
  =/  cr=@t  ':: heading\0d(cons :: inside\0d 1 2) :: tail'
  =/  cr-parsed=(each expr:jibb-core @t)  (read-expr:jibb-core cr registry)
  ?:  ?=(%| -.cr-parsed)  ~[leaf+"lone CR did not end comments"]
  ?.  =('(cons 1 2)' (print-expr:jibb-core p.cr-parsed))  ~[leaf+"CR comment changed the expression"]
  =/  crlf=@t  ':: heading\0d\0a(cons\09:: between\0d\0a 1 2)\0d\0a:: tail'
  =/  crlf-parsed=(each expr:jibb-core @t)  (read-expr:jibb-core crlf registry)
  ?:  ?=(%| -.crlf-parsed)  ~[leaf+"CRLF comments or whitespace failed"]
  ?.  =('(cons 1 2)' (print-expr:jibb-core p.crlf-parsed))  ~[leaf+"CRLF changed the expression"]
  =/  vertical=(each expr:jibb-core @t)  (read-expr:jibb-core '(cons 1\0b2)' registry)
  ?:  ?=(%| -.vertical)  ~[leaf+"vertical tab did not separate tokens"]
  ?.  =('(cons 1 2)' (print-expr:jibb-core p.vertical))  ~[leaf+"vertical tab changed the expression"]
  =/  feed=(each expr:jibb-core @t)  (read-expr:jibb-core '(cons 1\0c2)' registry)
  ?:  ?=(%| -.feed)  ~[leaf+"form feed did not separate tokens"]
  ?.  =('(cons 1 2)' (print-expr:jibb-core p.feed))  ~[leaf+"form feed changed the expression"]
  ~
::
++  test-core-arbitrary-precision-axes
  ^-  tang
  =/  huge=@t  '1234567890123456789012345678901234567890'
  =/  src=@t  (rap 3 ~['(slot ' huge ' 1)'])
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src registry)
  ?:  ?=(%| -.parsed)  ~[leaf+(trip p.parsed)]
  ?.  ?=([%slot *] p.parsed)  ~[leaf+"large axis produced the wrong node"]
  ?.  =(1.234.567.890.123.456.789.012.345.678.901.234.567.890 axis.p.parsed)
    ~[leaf+"large axis lost precision"]
  ?.  =(src (print-expr:jibb-core p.parsed))  ~[leaf+"large axis printer added groups or changed digits"]
  =/  thousand=(each expr:jibb-core @t)  (read-expr:jibb-core '(slot 1000 1)' registry)
  ?:  ?=(%| -.thousand)  ~[leaf+"axis 1000 was rejected"]
  ?.  =('(slot 1000 1)' (print-expr:jibb-core p.thousand))  ~[leaf+"axis 1000 was grouped"]
  =/  leading=(each expr:jibb-core @t)  (read-expr:jibb-core '(slot 000001 1)' registry)
  ?:  ?=(%| -.leading)  ~[leaf+"leading-zero nonzero axis was rejected"]
  ?.  &(?=([%slot *] p.leading) =(1 axis.p.leading))  ~[leaf+"leading-zero axis decoded incorrectly"]
  ?.  =('(slot 1 1)' (print-expr:jibb-core p.leading))  ~[leaf+"axis printer did not canonicalize leading zeroes"]
  =/  bad=(list @t)
    :~  '(slot 0 1)'  '(slot 000 1)'  '(slot -1 1)'  '(slot +1 1)'
        '(slot 1.0 1)'  '(slot 0x10 1)'  '(slot axis 1)'  '(slot "1" 1)'
        '(edit 0 1 2)'  '(edit 000 1 2)'  '(edit nope 1 2)'
    ==
  =/  wrong  (rejection-error bad 'invalid axis accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  ~
::
++  test-core-fixed-arities-and-malformed-structure
  ^-  tang
  =/  bad=(list @t)
    :~  '(cons 1)'  '(cons 1 2 3)'
        '(slot 1)'  '(slot 1 x y)'
        '(edit 1 x)'  '(edit 1 x y z)'
        '(cell?)'  '(cell? x y)'
        '(eq x)'  '(eq x y z)'
        '(if c t)'  '(if c t f extra)'
        '(let x value)'  '(let x value body extra)'
        '(rec ())'  '(rec () body extra)'
        '(lam x)'  '(lam x body extra)'
        '(app f)'  '(app f x extra)'
        '(native)'  '(native inc extra)'
        '(crash extra)'
        '(trace message)'  '(trace message body extra)'
        '(rec bindings body)'  '(rec (binding) body)'  '(rec ((f)) body)'
        '(rec ((f (lam x x) extra)) body)'  '(rec ((f 1)) body)'
        '(rec ((f (app (lam x x) 1))) body)'  '(rec ((1 (lam x x))) body)'
        ''  ':: only a comment'  '()'  '(unknown 1)'  '((lam x x) 1)'
        '1 2'  '(cons 1 2'  ')'  '(cons 1 2))'
    ==
  =/  wrong  (rejection-error bad 'malformed structure accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  ~
::
++  test-core-names-and-generated-names
  ^-  tang
  =/  bad=(list @t)
    :~  'Bad'  '-bad'  '_'  '_bad-name'  '_name!'  'a_b'
        'a:b:c'  'api/:name'  'api/todo:'  ':name'
        'api//todo:name'  '/api:name'  'api//todo:x'
        '(let Bad 1 2)'  '(lam _bad-name body)'  '(native missing!)'
        '0b101'  '0c3'  '0i9'  '0w9'  '~~cord'  '~0v1'
        '0v'  '0v.'  '0v1.'  '0v.1'  '0v1..2'  '0vw'  '0v1w'
        '0v00'  '0v01'  '0v0.000'  '0v00.000'  '0v123456789abcdefghijklmno'
        '%bad_name'  '%.maybe'  '%01'  '%0x10'  '%1000'
        '00'  '01'  '1000'  '12345678901234567890123456789012345678901234567890'
        '1.00'  '1.0000'  '1.'  '1..000'  '1.000.00'
    ==
  =/  wrong  (rejection-error bad 'malformed name or literal accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  ~
::
++  test-core-string-decoding-and-rejection
  ^-  tang
  =/  controls=(list @t)
    :~  (pack-test-bytes ~[34 97 0 98 34])
        (pack-test-bytes ~[34 97 9 98 34])
        (pack-test-bytes ~[34 97 31 98 34])
        (pack-test-bytes ~[34 97 127 98 34])
        '"two\0alines"'
        '"two\0dlines"'
        '"two\0d\0alines"'
    ==
  =/  bad=(list @t)
    (weld controls :~('"unterminated' '"unterminated escape\\' '"interpolated {x}"' '"bad \\GG escape"' '"bad \\0A escape"' '"bad \\a escape"'))
  =/  wrong  (rejection-error bad 'malformed string accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  =/  nul=(each expr:jibb-core @t)  (read-expr:jibb-core '"\\00\\07\\0a\\7f"' registry)
  ?:  ?=(%| -.nul)  ~[leaf+"escaped controls, including NUL, were rejected"]
  ?.  ?=([%lit *] p.nul)  ~[leaf+"escaped controls did not produce a literal"]
  ?.  =((pack-test-bytes ~[0 7 10 127]) val.lit.p.nul)  ~[leaf+"escaped control bytes decoded incorrectly"]
  ?.  =('"\\00\\07\\0a\\7f"' txt.lit.p.nul)  ~[leaf+"escaped control spelling was not retained"]
  =/  unicode=(each expr:jibb-core @t)  (read-expr:jibb-core '"\\ce\\bb"' registry)
  ?:  ?=(%| -.unicode)  ~[leaf+"escaped Unicode bytes were rejected"]
  ?.  &(?=([%lit *] p.unicode) =('λ' val.lit.p.unicode))  ~[leaf+"UTF-8 bytes decoded in the wrong order"]
  ~
::
++  test-core-lexical-scope-and-recursion
  ^-  tang
  =/  bad=(list @t)
    :~  '(let x 1 (let x 2 x))'
        '(lam x (let x 1 x))'
        '(let x 1 (lam x x))'
        '(rec ((f (lam x x)) (f (lam y y))) f)'
        '(let f 1 (rec ((f (lam x x))) f))'
        '(rec ((f (lam g g)) (g (lam x x))) f)'
        '(rec ((f (lam f f))) f)'
        '(rec ((f (lam x x))) (lam f f))'
        '(rec ((f (lam x (let x 1 x)))) f)'
    ==
  =/  wrong  (rejection-error bad 'duplicate or shadowing binding accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  =/  good=(list @t)
    :~  '(cons (let x 1 x) (let x 2 x))'
        '(let x (lam x x) x)'
        '(cons (lam x x) (lam x x))'
        '(cons (rec ((f (lam x x))) f) (rec ((f (lam y y))) f))'
        '(rec () (lam x x))'
        '(rec ((f (lam x x)) (g (lam y (app f y)))) (app g 1))'
    ==
  =/  bad-round  (round-trip-error good)
  ?^  bad-round  ~[leaf+(trip u.bad-round)]
  ~
::
++  test-core-module-validation-and-scope
  ^-  tang
  =/  bad=(list @t)
    :~  '(module)'  '(module "api/todo")'  '(module api//todo)'
        '(module /api/todo)'  '(module Bad)'  '(module api/todo value)'
        '(module m (define x 1))'  '(module m (def x))'
        '(module m (def x 1 2))'  '(module m (def "x" 1))'
        '(module m (def x 1) (def x 2))'
        '(module m (def x 1) (def f (lam x x)))'
        '(module m (def f (lam f f)))'
        '(module m (def x (let x 1 x)))'
        '(module m (def x (native missing)))'
        '(module m) trailing'  '1'  '(let m 1 (module inner))'
    ==
  =/  wrong  (module-rejection-error bad)
  ?^  wrong  ~[leaf+(trip u.wrong)]
  =/  good=(list @t)
    :~  '(module m)'
        '(module m (def one (let x 1 x)) (def two (let x 2 x)))'
        '(module m (def f (lam x x)) (def g (lam y (app f y))))'
    ==
  |-
  ?~  good  ~
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core i.good registry)
  ?:  ?=(%| -.parsed)  ~[leaf+(trip (rap 3 ~['valid module rejected: ' i.good ': ' p.parsed]))]
  =/  printed=@t  (print-module:jibb-core p.parsed)
  ?.  =(i.good printed)  ~[leaf+"valid module did not print canonically"]
  =/  again=(each module:jibb-core @t)  (read-module:jibb-core printed registry)
  ?:  ?=(%| -.again)  ~[leaf+"printed module did not read"]
  ?.  =(p.parsed p.again)  ~[leaf+"module AST did not round trip"]
  $(good t.good)
::
++  test-core-native-registry-is-exact
  ^-  tang
  =/  bad=(list @t)
    :~  '(native missing)'  '(native incs)'  '(native prelude:inc)'
        '(native api/todo:join)'  '(native _native9)'  '(native _Native99)'
    ==
  =/  wrong  (rejection-error bad 'unknown or lookalike native accepted')
  ?^  wrong  ~[leaf+(trip u.wrong)]
  =/  good=(list @t)  ~['(native inc)' '(native prelude:join)' '(native _Native9)']
  =/  round  (round-trip-error good)
  ?^  round  ~[leaf+(trip u.round)]
  =/  without=(each expr:jibb-core @t)  (read-expr:jibb-core '(native inc)' empty-registry)
  ?.  ?=(%| -.without)  ~[leaf+"native spelling manufactured registry membership"]
  ~
::
++  test-core-programmatic-validation
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  valid=expr:jibb-core
    [%let x [%cons [%lit [%ud 1 '1']] [%lit [%ux 2 '0x2']]] [%slot 2 [%var x]]]
  ?.  (validation-is valid ~)  ~[leaf+"valid programmatic AST was rejected"]
  =/  no-types=expr:jibb-core  [%app [%lit [%ud 1 '1']] [%var (own %free)]]
  ?.  (validation-is no-types ~)  ~[leaf+"validation added type or free-variable checks"]
  ?.  (validation-is [%lit [%ud 1 '2']] `'literal text, aura, and value disagree')
    ~[leaf+"literal value/text disagreement was not diagnosed"]
  ?.  (validation-is [%lit [%ux 1 '1']] `'literal text, aura, and value disagree')
    ~[leaf+"literal aura/text disagreement was not diagnosed"]
  ?.  (validation-is [%slot 0 [%lit [%ud 1 '1']]] [~ 'Core axis 0 is invalid'])
    ~[leaf+"programmatic zero axis was not diagnosed"]
  ?.  (validation-is [%var [%generated '_bad-name']] [~ 'invalid name'])
    ~[leaf+"invalid programmatic name was not diagnosed"]
  ?.  (validation-is [%native (own %missing)] [~ 'unknown native'])
    ~[leaf+"unknown programmatic native was not diagnosed"]
  =/  duplicate=expr:jibb-core
    [%rec ~[[(own %f) [%lam x [%var x]]] [(own %f) [%lam x [%var x]]]] [%var (own %f)]]
  ?.  (validation-is duplicate [~ 'duplicate rec binding'])  ~[leaf+"programmatic duplicate rec was accepted"]
  =/  shadow=expr:jibb-core  [%lam x [%let x [%lit [%ud 1 '1']] [%var x]]]
  ?.  (validation-is shadow [~ 'binding shadows an enclosing binding'])  ~[leaf+"programmatic shadowing was accepted"]
  ~
::
++  test-core-selected-exact-diagnostics
  ^-  tang
  ?.  (diagnostic-is '' 'expected an expression, found end of input')  ~[leaf+"empty-input diagnostic differed"]
  ?.  (diagnostic-is '(cons 1)' 'cons arity is 2')  ~[leaf+"arity diagnostic differed"]
  ?.  (diagnostic-is '(slot 0 1)' 'Core axis 0 is invalid')  ~[leaf+"zero-axis diagnostic differed"]
  ?.  (diagnostic-is '(native missing)' 'unknown native')  ~[leaf+"native diagnostic differed"]
  ?.  (diagnostic-is '(rec ((f (lam x x)) (f (lam y y))) f)' 'duplicate rec binding')  ~[leaf+"duplicate-rec diagnostic differed"]
  ?.  (diagnostic-is '(let x 1 (let x 2 x))' 'binding shadows an enclosing binding')  ~[leaf+"let-shadow diagnostic differed"]
  ?.  (diagnostic-is '(let x 1 (lam x x))' 'lambda sample shadows an enclosing binding')  ~[leaf+"lambda-shadow diagnostic differed"]
  ?.  (diagnostic-is '"bad {interpolation}"' 'interpolated strings are not Core atom literals')  ~[leaf+"interpolation diagnostic differed"]
  ?.  (diagnostic-is '"bad \\GG"' 'invalid string escape')  ~[leaf+"escape diagnostic differed"]
  ?.  (diagnostic-is (rap 3 ~['"bad' 31 'control"']) 'unescaped control character in string literal')  ~[leaf+"control diagnostic differed"]
  ?.  (diagnostic-is '1 2' 'trailing input after the Core form')  ~[leaf+"trailing-input diagnostic differed"]
  ?.  (diagnostic-is '(cons 1 2' 'unterminated list')  ~[leaf+"unterminated-list diagnostic differed"]
  ?.  (module-diagnostic-is '(module m (def x 1) (def x 2))' 'duplicate module definition')  ~[leaf+"duplicate-module diagnostic differed"]
  ?.  (module-diagnostic-is '(module m (def f (lam f f)))' 'lambda sample shadows an enclosing binding')  ~[leaf+"module-scope diagnostic differed"]
  ~
--
