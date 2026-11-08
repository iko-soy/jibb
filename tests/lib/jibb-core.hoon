::  Hand-written Core reader, printer, and reference-interpreter checks.
::  These tests deliberately do not import the surface Jibb compiler.
/+  jibb-core
|%
++  empty-registry
  ^-  native-registry:jibb-core
  *(map name:jibb-core native:jibb-core)
::
++  inc-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  [[%atom +(val.v)] ~]
::
++  dec-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  ?:  =(0 val.v)  !!
  [[%atom (dec val.v)] ~]
::
++  add-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%cell -.v)  !!
  ?.  ?=(%atom -.hed.v)  !!
  ?.  ?=(%atom -.tal.v)  !!
  [[%atom (add val.hed.v val.tal.v)] ~]
::
++  fail-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  !!
::
++  registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  empty-registry
  =.  r  (~(put by r) [%own %inc] inc-native)
  =.  r  (~(put by r) [%own %dec] dec-native)
  =.  r  (~(put by r) [%own %add] add-native)
  (~(put by r) [%own %fail] fail-native)
::
++  parse
  |=  [src=@t natives=native-registry:jibb-core]
  ^-  expr:jibb-core
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src natives)
  ?-  -.parsed
    %|  !!
    %&  p.parsed
  ==
::
++  parse-module
  |=  [src=@t natives=native-registry:jibb-core]
  ^-  module:jibb-core
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core src natives)
  ?-  -.parsed
    %|  !!
    %&  p.parsed
  ==
::
++  rejected
  |=  [src=@t natives=native-registry:jibb-core]
  ^-  ?
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src natives)
  ?=(%| -.parsed)
::
++  rejected-module
  |=  [src=@t natives=native-registry:jibb-core]
  ^-  ?
  =/  parsed=(each module:jibb-core @t)  (read-module:jibb-core src natives)
  ?=(%| -.parsed)
::
++  outcome-is
  |=  [got=outcome:jibb-core expected=noun]
  ^-  ?
  &(?=(%ok -.got) =(val.got expected))
::
++  source-outcome
  |=  [src=@t expected=noun natives=native-registry:jibb-core]
  ^-  ?
  (outcome-is (run:jibb-core (parse src natives) natives) expected)
::
++  source-crash
  |=  [src=@t natives=native-registry:jibb-core]
  ^-  ?
  =/  o=outcome:jibb-core  (run:jibb-core (parse src natives) natives)
  ?=(%crash -.o)
::
++  round-trip-error
  |=  [sources=(list @t) natives=native-registry:jibb-core]
  ^-  (unit @t)
  ?~  sources  ~
  =/  src=@t  i.sources
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core src natives)
  ?:  ?=(%| -.parsed)  `(cat 3 'reader rejected: ' src)
  =/  printed=@t  (print-expr:jibb-core p.parsed)
  ?.  =(src printed)  `(cat 3 'noncanonical print: ' src)
  =/  again=(each expr:jibb-core @t)  (read-expr:jibb-core printed natives)
  ?:  ?=(%| -.again)  `(cat 3 'printer emitted unreadable text: ' src)
  ?.  =(p.parsed p.again)  `(cat 3 'round trip changed AST: ' src)
  $(sources t.sources)
::
++  outcome-error
  |=  [cases=(list [src=@t expected=noun]) natives=native-registry:jibb-core]
  ^-  (unit @t)
  ?~  cases  ~
  ?.  (source-outcome src.i.cases expected.i.cases natives)
    `(cat 3 'wrong outcome: ' src.i.cases)
  $(cases t.cases)
::
++  crash-error
  |=  [sources=(list @t) natives=native-registry:jibb-core]
  ^-  (unit @t)
  ?~  sources  ~
  ?.  (source-crash i.sources natives)  `(cat 3 'did not crash: ' i.sources)
  $(sources t.sources)
::
++  test-core-round-trip
  ^-  tang
  =/  sources=(list @t)
    :~  '0'
        '42'
        '340.282.366.920.938.463.463.374.607.431.768.211.456'
        '0x1.0000.0000.0000.0000.0000.0000.0000.0001'
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
        '~2026.10.23'
        '~h1.m30'
        '~.my-post'
        '""'
        '"milk"'
        '"λ"'
        '"quote \\" and hex\\0a"'
        '":: not a comment"'
        'plain-name'
        'api/todo:todo-action'
        '_1'
        '_Generated9'
        '(cons 1 2)'
        '(slot 3 (cons 1 2))'
        '(edit 2 (cons 1 2) 9)'
        '(cell? (cons 1 2))'
        '(eq 1 1)'
        '(if %.y 1 2)'
        '(let x 1 x)'
        '(rec ((even (lam n (if (eq n 0) %.y (app odd (app (native dec) n))))) (odd (lam n (if (eq n 0) %.n (app even (app (native dec) n)))))) (app even 10))'
        '(lam x x)'
        '(app (lam x x) 1)'
        '(native inc)'
        '(crash)'
        '(trace "hello" 7)'
    ==
  =/  bad  (round-trip-error sources registry)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  huge=(each expr:jibb-core @t)
    (read-expr:jibb-core '0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff' registry)
  ?:  ?=(%| -.huge)  ~[leaf+"big hexadecimal literal did not read"]
  ?.  ?=([%lit *] p.huge)  ~[leaf+"big literal produced a nonliteral node"]
  ?.  &(=(%ux aura.lit.p.huge) =(0xffff.ffff.ffff.ffff.ffff.ffff.ffff.ffff val.lit.p.huge))
    ~[leaf+"big literal lost its value or print aura"]
  ~
::
++  test-core-comments-and-modules
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
  ?.  =(canonical (print-module:jibb-core p.parsed))
    ~[leaf+"module printer was not canonical"]
  =/  again=(each module:jibb-core @t)  (read-module:jibb-core canonical registry)
  ?:  ?=(%| -.again)  ~[leaf+"canonical module did not read"]
  ?.  =(p.parsed p.again)  ~[leaf+"module round trip changed definitions"]
  ?.  =(3 (lent defs.p.parsed))  ~[leaf+"module reader lost a definition"]
  =/  empty=(each module:jibb-core @t)  (read-module:jibb-core '(module empty)' registry)
  ?:  ?=(%| -.empty)  ~[leaf+"empty module was rejected"]
  ?.  =('(module empty)' (print-module:jibb-core p.empty))
    ~[leaf+"empty module printed incorrectly"]
  ~
::
++  test-core-malformed-reader
  ^-  tang
  =/  bad=(list @t)
    :~  ''
        '()'
        '(unknown 1)'
        '(cons 1)'
        '(cons 1 2 3)'
        '(slot 0 1)'
        '(slot nope 1)'
        '(edit 0 1 2)'
        '(cell?)'
        '(eq 1)'
        '(if %.y 1)'
        '(let x 1)'
        '(rec ((f 1)) f)'
        '(rec ((f (lam x x)) (f (lam y y))) f)'
        '(lam x)'
        '(app (lam x x))'
        '(native)'
        '(native unknown)'
        '(crash 1)'
        '(trace "x")'
        '1 2'
        '(cons 1 2'
        ')'
        'Bad'
        '-bad'
        '_'
        '_bad-name'
        'api//todo:x'
        'api/todo:'
        'api/todo:x:y'
        '"unterminated'
        '"interpolated {x}"'
        '"bad \\GG escape"'
        '0b101'
        '~~cord'
        '~0v1'
        '%bad_name'
        '%.maybe'
    ==
  |-
  ?~  bad
    =/  bad-modules=(list @t)
      :~  '(module)'
          '(module /absolute (def x 1))'
          '(module Bad (def x 1))'
          '(module ok (def x))'
          '(module ok (value x 1))'
          '(module ok (def x 1) (def x 2))'
          '(module ok (def x (native missing)))'
          '(module ok) trailing'
      ==
    |-
    ?~  bad-modules  ~
    ?.  (rejected-module i.bad-modules registry)
      ~[leaf+(trip (cat 3 'malformed module accepted: ' i.bad-modules))]
    $(bad-modules t.bad-modules)
  ?.  (rejected i.bad registry)  ~[leaf+(trip (cat 3 'malformed expression accepted: ' i.bad))]
  $(bad t.bad)
::
++  test-core-noun-evaluation
  ^-  tang
  =/  cases=(list [src=@t expected=noun])
    :~  ['340.282.366.920.938.463.463.374.607.431.768.211.456' 340.282.366.920.938.463.463.374.607.431.768.211.456]
        ['(cons 1 2)' [1 2]]
        ['(cons 1 (cons 2 3))' [1 2 3]]
        ['(slot 1 (cons 1 2))' [1 2]]
        ['(slot 2 (cons 1 2))' 1]
        ['(slot 3 (cons 1 2))' 2]
        ['(slot 6 (cons 1 (cons 2 3)))' 2]
        ['(edit 1 0 9)' 9]
        ['(edit 2 (cons 1 2) 9)' [9 2]]
        ['(edit 3 (cons 1 2) 9)' [1 9]]
        ['(edit 6 (cons 1 (cons 2 3)) 9)' [1 9 3]]
        ['(cell? 0)' 1]
        ['(cell? (cons 1 2))' 0]
        ['(eq 1 1)' 0]
        ['(eq 1 2)' 1]
        ['(eq (cons 1 (cons 2 3)) (cons 1 (cons 2 3)))' 0]
        ['(eq (cons 1 2) (cons 2 1))' 1]
        ['(let x 40 (app (native inc) x))' 41]
        ['(let unused 1 42)' 42]
    ==
  =/  bad=(unit @t)  (outcome-error cases registry)
  ?^  bad  ~[leaf+(trip u.bad)]
  ~
::
++  test-core-strictness-and-if
  ^-  tang
  =/  good=(list [src=@t expected=noun])
    :~  ['(if %.y 42 (crash))' 42]
        ['(if %.n (crash) 42)' 42]
        ['(if (eq 1 1) 42 (crash))' 42]
    ==
  =/  bad-good  (outcome-error good registry)
  ?^  bad-good  ~[leaf+(trip u.bad-good)]
  =/  bad=(list @t)
    :~  '(let unused (crash) 42)'
        '(app (lam x 42) (crash))'
        '(app (crash) 42)'
        '(cons (crash) 1)'
        '(cons 1 (crash))'
        '(trace (crash) 42)'
        '(if 2 1 2)'
        '(if (cons 1 2) 1 2)'
    ==
  =/  bad-crash  (crash-error bad registry)
  ?^  bad-crash  ~[leaf+(trip u.bad-crash)]
  ~
::
++  test-core-closures-and-higher-order
  ^-  tang
  =/  cases=(list [src=@t expected=noun])
    :~  ['(app (lam x x) 42)' 42]
        ['(app (lam f (app f 41)) (lam x (app (native inc) x)))' 42]
        ['(app (app (lam x (lam y (app (native add) (cons x y)))) 40) 2)' 42]
        ['(app (slot 2 (cons (lam x (app (native inc) x)) 0)) 41)' 42]
        ['(cell? (cons (lam x x) 0))' 0]
    ==
  =/  bad  (outcome-error cases registry)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  function=outcome:jibb-core  (run:jibb-core (parse '(lam x x)' registry) registry)
  ?.  ?=(%crash -.function)  ~[leaf+"a function was treated as a canonical noun"]
  =/  crashes=(list @t)
    :~  '(cell? (lam x x))'
        '(eq (lam x x) (lam x x))'
        '(slot 1 (lam x x))'
        '(edit 1 (lam x x) 0)'
        '(app 0 1)'
    ==
  =/  bad-crash  (crash-error crashes registry)
  ?^  bad-crash  ~[leaf+(trip u.bad-crash)]
  ~
::
++  test-core-recursion
  ^-  tang
  =/  countdown=@t
    '(rec ((loop (lam n (if (eq n 0) 42 (app loop (app (native dec) n)))))) (app loop 20))'
  ?.  (source-outcome countdown 42 registry)  ~[leaf+"self recursion returned the wrong noun"]
  =/  mutual=@t
    '(rec ((even (lam n (if (eq n 0) %.y (app odd (app (native dec) n))))) (odd (lam n (if (eq n 0) %.n (app even (app (native dec) n)))))) (cons (app even 10) (cons (app odd 10) (cons (app even 11) (app odd 11)))))'
  ?.  (source-outcome mutual [0 1 1 0] registry)  ~[leaf+"mutual recursion returned the wrong loobeans"]
  ~
::
++  test-core-invalid-runtime-nouns
  ^-  tang
  =/  sources=(list @t)
    :~  '(slot 2 0)'
        '(slot 4 (cons 1 2))'
        '(edit 2 0 9)'
        '(edit 4 (cons 1 2) 9)'
        '(crash)'
        '(app (native fail) 1)'
        '(trace (cons 1 2) 0)'
    ==
  =/  bad  (crash-error sources registry)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  zero-slot=expr:jibb-core  [%slot 0 [%lit [%ud 1 '1']]]
  =/  slot-result=outcome:jibb-core  (run:jibb-core zero-slot registry)
  ?.  ?=(%crash -.slot-result)  ~[leaf+"direct axis-zero slot did not crash"]
  =/  zero-edit=expr:jibb-core  [%edit 0 [%lit [%ud 1 '1']] [%lit [%ud 2 '2']]]
  =/  edit-result=outcome:jibb-core  (run:jibb-core zero-edit registry)
  ?.  ?=(%crash -.edit-result)  ~[leaf+"direct axis-zero edit did not crash"]
  =/  missing=expr:jibb-core  [%native [%own %not-registered]]
  =/  missing-result=outcome:jibb-core  (run:jibb-core missing registry)
  ?.  ?=(%crash -.missing-result)  ~[leaf+"direct unknown native did not fail closed"]
  ~
::
++  test-core-native-registry
  ^-  tang
  ?.  (source-outcome '(app (native inc) 41)' 42 registry)
    ~[leaf+"registered native returned the wrong result"]
  ?.  (source-outcome '(app (native add) (cons 340.282.366.920.938.463.463.374.607.431.768.211.456 1))' 340.282.366.920.938.463.463.374.607.431.768.211.457 registry)
    ~[leaf+"native arithmetic lost arbitrary precision"]
  ?.  (rejected '(native inc)' empty-registry)
    ~[leaf+"native spelling alone manufactured a native"]
  =/  direct=expr:jibb-core  [%app [%native [%own %inc]] [%lit [%ud 1 '1']]]
  =/  empty-result=outcome:jibb-core  (run:jibb-core direct empty-registry)
  ?.  ?=(%crash -.empty-result)  ~[leaf+"empty registry evaluated a lookalike native"]
  =/  native-result=outcome:jibb-core  (run:jibb-core (parse '(native inc)' registry) registry)
  ?.  ?=(%crash -.native-result)  ~[leaf+"a native function became a canonical noun"]
  ~
::
++  test-core-trace-result
  ^-  tang
  =/  e=expr:jibb-core  (parse '(trace "first" (trace "second" 9))' registry)
  =/  got=execution:jibb-core  (run-traced:jibb-core e registry)
  ?.  (outcome-is out.got 9)  ~[leaf+"trace did not return its body result"]
  ?.  =(traces.got ~['first' 'second'])
    ~[leaf+"trace messages were missing or out of order"]
  =/  crashed=outcome:jibb-core  (run:jibb-core (parse '(trace "before" (crash))' registry) registry)
  ?.  ?=(%crash -.crashed)  ~[leaf+"a crashing trace body did not crash"]
  ~
--
