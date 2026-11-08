::  Differential and structural checks for the Core Nock backend.
/+  jibb-core, jibb-nock
|%
++  empty-interpreter-registry
  ^-  native-registry:jibb-core
  *(map name:jibb-core native:jibb-core)
::
++  empty-nock-registry
  ^-  native-registry:jibb-nock
  *(map name:jibb-core noun)
::
++  inc-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  [%atom +(val.v)]
::
++  dec-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  ?:  =(0 val.v)  !!
  [%atom (dec val.v)]
::
++  add-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%cell -.v)  !!
  ?.  ?=(%atom -.hed.v)  !!
  ?.  ?=(%atom -.tal.v)  !!
  [%atom (add val.hed.v val.tal.v)]
::
++  fail-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  !!
::
++  apply-interpreted
  |=  [fun=value:jibb-core sample=value:jibb-core]
  ^-  value:jibb-core
  ?-  -.fun
    ?(%atom %cell)  !!
    %native         (run.fun sample)
    %closure
      =/  env=environment:jibb-core
        [[%value sample.fun sample] env.fun]
      val:(evaluate-env:jibb-core body.fun env interpreter-registry)
  ==
::
++  turn-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ^-  value:jibb-core
  ?.  ?=(%cell -.v)  !!
  =/  items=value:jibb-core  hed.v
  =/  fun=value:jibb-core  tal.v
  |-
  ^-  value:jibb-core
  ?:  ?=(%atom -.items)
    ?.  =(0 val.items)  !!
    [%atom 0]
  ?.  ?=(%cell -.items)  !!
  =/  hed=value:jibb-core  (apply-interpreted fun hed.items)
  =/  tal=value:jibb-core  $(items tal.items)
  [%cell hed tal]
::
++  interpreter-registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  empty-interpreter-registry
  =.  r  (~(put by r) [%own %inc] inc-native)
  =.  r  (~(put by r) [%own %dec] dec-native)
  =.  r  (~(put by r) [%own %add] add-native)
  =.  r  (~(put by r) [%own %fail] fail-native)
  (~(put by r) [%own %turn] turn-native)
::
++  nock-registry
  ^-  native-registry:jibb-nock
  =/  r=native-registry:jibb-nock  empty-nock-registry
  =.  r  (~(put by r) [%own %inc] |=(a=@ +(a)))
  =.  r  (~(put by r) [%own %dec] |=(a=@ ?:(=(0 a) !! (dec a))))
  =.  r  (~(put by r) [%own %add] |=([a=@ b=@] (add a b)))
  =.  r  (~(put by r) [%own %fail] |=(* !!))
  (~(put by r) [%own %turn] turn)
::
++  parse
  |=  src=@t
  ^-  expr:jibb-core
  =/  parsed=(each expr:jibb-core @t)
    (read-expr:jibb-core src interpreter-registry)
  ?-  -.parsed
    %|  !!
    %&  p.parsed
  ==
::
++  outcome-is
  |=  [got=outcome:jibb-core expected=noun]
  ^-  ?
  &(?=(%ok -.got) =(val.got expected))
::
++  agrees
  |=  src=@t
  ^-  ?
  =/  e=expr:jibb-core  (parse src)
  =/  expected=outcome:jibb-core  (run:jibb-core e interpreter-registry)
  =/  got=outcome:jibb-core  (run:jibb-nock e nock-registry)
  =(expected got)
::
++  agreement-error
  |=  sources=(list @t)
  ^-  (unit @t)
  ?~  sources  ~
  ?.  (agrees i.sources)  `(cat 3 'backend disagreement: ' i.sources)
  $(sources t.sources)
::
++  report-agreements
  |=  sources=(list @t)
  ^-  tang
  =/  bad=(unit @t)  (agreement-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  ~
::
++  direct-agrees
  |=  e=expr:jibb-core
  ^-  ?
  =/  expected=outcome:jibb-core  (run:jibb-core e interpreter-registry)
  =/  got=outcome:jibb-core  (run:jibb-nock e nock-registry)
  =(expected got)
::
++  test-nock-noun-nodes
  ^-  tang
  %-  report-agreements
  :~  '0'
      '42'
      '340.282.366.920.938.463.463.374.607.431.768.211.456'
      '(cons 1 2)'
      '(cons 1 (cons 2 3))'
      '(slot 1 (cons 1 2))'
      '(slot 2 (cons 1 2))'
      '(slot 3 (cons 1 2))'
      '(slot 6 (cons 1 (cons 2 3)))'
      '(slot 2 (slot 3 (cons 1 (cons 2 3))))'
      '(edit 1 0 9)'
      '(edit 2 (cons 1 2) 9)'
      '(edit 3 (cons 1 2) 9)'
      '(edit 6 (cons 1 (cons 2 3)) 9)'
      '(cell? 0)'
      '(cell? (cons 1 2))'
      '(eq 1 1)'
      '(eq 1 2)'
      '(eq (cons 1 (cons 2 3)) (cons 1 (cons 2 3)))'
      '(let x 40 (app (native inc) x))'
      '(let unused 1 42)'
  ==
::
++  test-nock-strictness-if-and-rewrites
  ^-  tang
  =/  sources=(list @t)
    :~  '(if %.y 42 (crash))'
        '(if %.n (crash) 42)'
        '(if (eq 1 1) 42 (crash))'
        '(app (lam x x) 42)'
        '(app (lam unused 42) 41)'
        '(let unused (crash) 42)'
        '(app (lam unused 42) (crash))'
        '(app (crash) 42)'
        '(cons (crash) 1)'
        '(cons 1 (crash))'
        '(if 2 1 2)'
        '(if (cons 1 2) 1 2)'
    ==
  =/  bad=(unit @t)  (agreement-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  folded=noun  (emit:jibb-nock (parse '(if %.y 42 (crash))') nock-registry)
  ?.  =(folded [1 42])  ~[leaf+"constant if was not locally simplified"]
  =/  beta=noun
    (emit:jibb-nock (parse '(app (lam x x) 41)') nock-registry)
  ?.  =(beta [8 [1 41] [0 2]])  ~[leaf+"beta rewrite changed strict let structure"]
  =/  strict=noun
    (emit:jibb-nock (parse '(let unused (crash) 42)') nock-registry)
  ?.  =(strict [8 [0 0] [1 42]])  ~[leaf+"unused strict let was deleted"]
  =/  composed=noun
    (emit:jibb-nock (parse '(slot 2 (slot 3 (cons 1 2)))') nock-registry)
  ?.  =(composed [7 [[1 1] [1 2]] 0 6])
    ~[leaf+"nested slots did not compose to axis 6"]
  ~
::
++  test-nock-closures-and-higher-order
  ^-  tang
  ::  Every function result is applied before canonical noun comparison.
  %-  report-agreements
  :~  '(app (lam x x) 42)'
      '(app (lam f (app f 41)) (lam x (app (native inc) x)))'
      '(app (app (lam x (lam y (app (native add) (cons x y)))) 40) 2)'
      '(app (slot 2 (cons (lam x (app (native inc) x)) 0)) 41)'
      '(app (let x 40 (lam y (app (native add) (cons x y)))) 2)'
      '(app (app (app (lam x (lam y (lam z (app (native add) (cons x (app (native add) (cons y z))))))) 1) 2) 3)'
  ==
::
++  test-nock-recursion
  ^-  tang
  =/  second=@t  '(rec ((even (lam n %.y)) (odd (lam n %.n))) (app odd 0))'
  =/  second-result=outcome:jibb-core  (run:jibb-nock (parse second) nock-registry)
  ?:  ?=(%crash -.second-result)  ~[leaf+"direct second recursive arm crashed"]
  ?.  (outcome-is second-result 1)  ~[leaf+"direct second recursive arm returned the wrong noun"]
  =/  mutual=@t  '(rec ((even (lam n (if (eq n 0) %.y (app odd (app (native dec) n))))) (odd (lam n (if (eq n 0) %.n (app even (app (native dec) n)))))) (cons (app even 10) (cons (app odd 10) (cons (app even 11) (app odd 11)))))'
  =/  mutual-result=outcome:jibb-core  (run:jibb-nock (parse mutual) nock-registry)
  ?:  ?=(%crash -.mutual-result)  ~[leaf+"mutual recursion crashed in Nock"]
  ?.  (outcome-is mutual-result [0 1 1 0])
    ~[leaf+"mutual recursion returned the wrong noun" (sell !>(val.mutual-result))]
  =/  three=@t  '(rec ((one (lam n 1)) (two (lam n 2)) (three (lam n 3))) (cons (app one 0) (cons (app two 0) (app three 0))))'
  =/  three-formula=noun  (emit:jibb-nock (parse three) nock-registry)
  =/  three-result=outcome:jibb-core  (run:jibb-nock (parse three) nock-registry)
  ?:  ?=(%crash -.three-result)  ~[leaf+"three-arm selection crashed" (sell !>(three-formula))]
  ?.  (outcome-is three-result [1 2 3])  ~[leaf+"three-arm selection returned wrong result" (sell !>(three-formula))]
  %-  report-agreements
  :~  '(rec ((loop (lam n (if (eq n 0) 42 (app loop (app (native dec) n)))))) (app loop 20))'
      mutual
      '(let base 40 (rec ((add-base (lam n (app (native add) (cons base n))))) (app add-base 2)))'
      '(rec ((outer (lam n (app (lam m (app (native add) (cons n m))) 2)))) (app outer 40))'
      '(rec ((one (lam n (if (eq n 0) 1 (app two (app (native dec) n))))) (two (lam n (if (eq n 0) 2 (app three (app (native dec) n))))) (three (lam n (if (eq n 0) 3 (app one (app (native dec) n)))))) (app one 8))'
      '(rec () 42)'
  ==
::
++  test-nock-natives-and-gate-abi
  ^-  tang
  =/  sources=(list @t)
    :~  '(app (native inc) 41)'
        '(app (native add) (cons 40 2))'
        '(app (native add) (cons 340.282.366.920.938.463.463.374.607.431.768.211.456 1))'
        '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (app (native inc) x))))'
        '(app (native turn) (cons ~ (lam x (app (native inc) x))))'
        '(app (native fail) 1)'
        '(app (native dec) 0)'
        '(app (native add) 1)'
    ==
  =/  bad=(unit @t)  (agreement-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  callback=outcome:jibb-core
    (run:jibb-nock (parse '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (app (native inc) x))))') nock-registry)
  ?.  (outcome-is callback [2 3 0])  ~[leaf+"Hoon turn did not call the Jibb gate correctly"]
  =/  e=expr:jibb-core  (parse '(lam x (app (native inc) x))')
  =/  made  (mock [0 (emit:jibb-nock e nock-registry)] |=(^ ~))
  ?.  ?=(%0 -.made)  ~[leaf+"lambda emission did not produce a gate"]
  =/  gate=noun  p.made
  =/  battery  (mock [gate [0 2]] |=(^ ~))
  ?.  &(?=(%0 -.battery) ?=(^ p.battery))  ~[leaf+"gate battery is absent from axis 2"]
  =/  sample  (mock [gate [0 6]] |=(^ ~))
  ?.  &(?=(%0 -.sample) =(0 p.sample))  ~[leaf+"gate sample is absent from axis 6"]
  =/  called
    (mock [gate [9 2 10 [6 [1 41]] [0 1]]] |=(^ ~))
  ?.  &(?=(%0 -.called) =(42 p.called))
    ~[leaf+"external Hoon ABI call returned the wrong result"]
  =/  direct=noun  (emit:jibb-nock (parse '(native inc)') nock-registry)
  ?.  ?=([%1 *] direct)  ~[leaf+"native was not emitted as a direct gate constant"]
  =/  missing=expr:jibb-core  [%app [%native [%own %inc]] [%lit [%ud 1 '1']]]
  =/  empty-got=outcome:jibb-core  (run:jibb-nock missing empty-nock-registry)
  ?.  ?=(%crash -.empty-got)  ~[leaf+"spelling manufactured an unregistered native gate"]
  ~
::
++  test-nock-invalid-runtime-nouns
  ^-  tang
  =/  sources=(list @t)
    :~  '(slot 2 0)'
        '(slot 4 (cons 1 2))'
        '(edit 2 0 9)'
        '(edit 4 (cons 1 2) 9)'
        '(crash)'
        '(app 0 1)'
        '(trace (cons 1 2) 0)'
        '(app (native turn) (cons 1 (lam x x)))'
        '(app (native turn) (cons (cons 1 ~) 0))'
    ==
  =/  bad=(unit @t)  (agreement-error sources)
  ?^  bad  ~[leaf+(trip u.bad)]
  =/  direct=(list expr:jibb-core)
    :~  [%slot 0 [%lit [%ud 1 '1']]]
        [%edit 0 [%lit [%ud 1 '1']] [%lit [%ud 2 '2']]]
        [%var [%own %unbound]]
        [%rec ~[[[%own %bad] [%lit [%ud 1 '1']]]] [%lit [%ud 2 '2']]]
        [%app [%native [%own %missing]] [%lit [%ud 1 '1']]]
    ==
  |-
  ?~  direct  ~
  ?.  (direct-agrees i.direct)
    ~[leaf+"malformed direct AST disagreed with the interpreter"]
  $(direct t.direct)
::
++  test-nock-trace-hint-and-result
  ^-  tang
  =/  e=expr:jibb-core  (parse '(trace "hello" 9)')
  =/  formula=noun  (emit:jibb-nock e nock-registry)
  ?.  ?=([%11 [%slog [%9 %2 %10 [%6 *] *]] *] formula)
    ~[leaf+"trace is not a dynamic Nock 11 %slog hint"]
  =/  got=outcome:jibb-core  (run:jibb-nock e nock-registry)
  ?.  (outcome-is got 9)  ~[leaf+"trace hint did not return its body result"]
  =/  nested=@t  '(trace "first" (trace "second" (app (native inc) 41)))'
  ?.  (agrees nested)  ~[leaf+"nested traces changed the body result"]
  =/  crashed=outcome:jibb-core
    (run:jibb-nock (parse '(trace "before" (crash))') nock-registry)
  ?.  ?=(%crash -.crashed)  ~[leaf+"trace hid a body crash"]
  ~
::
++  test-nock-explicit-formulas
  ^-  tang
  =/  literal=noun  (emit:jibb-nock (parse '42') nock-registry)
  ?.  =(literal [1 42])  ~[leaf+"literal formula is not Nock 1"]
  =/  cons=noun  (emit:jibb-nock (parse '(cons 1 2)') nock-registry)
  ?.  =(cons [[1 1] [1 2]])  ~[leaf+"cons did not use autocons"]
  =/  slot=noun  (emit:jibb-nock (parse '(slot 2 (cons 1 2))') nock-registry)
  ?.  =(slot [7 [[1 1] [1 2]] 0 2])  ~[leaf+"slot formula is not composed Nock 0"]
  =/  edit=noun  (emit:jibb-nock (parse '(edit 2 (cons 1 2) 9)') nock-registry)
  ?.  =(edit [10 [2 [1 9]] [[1 1] [1 2]]])  ~[leaf+"edit formula is not Nock 10"]
  =/  cell=noun  (emit:jibb-nock (parse '(cell? 0)') nock-registry)
  ?.  =(cell [3 [1 0]])  ~[leaf+"cell formula is not Nock 3"]
  =/  eq=noun  (emit:jibb-nock (parse '(eq 1 1)') nock-registry)
  ?.  =(eq [5 [1 1] [1 1]])  ~[leaf+"eq formula is not Nock 5"]
  =/  conditional=noun  (emit:jibb-nock (parse '(if (eq 1 1) 1 2)') nock-registry)
  ?.  ?=([%6 * * *] conditional)  ~[leaf+"dynamic if formula is not Nock 6"]
  =/  lam=noun  (emit:jibb-nock (parse '(lam x x)') nock-registry)
  ?.  =(lam [[1 [0 6]] [[1 0] [0 1]]])  ~[leaf+"lambda does not construct the documented gate"]
  =/  app=noun  (emit:jibb-nock (parse '(app (native inc) 41)') nock-registry)
  ?.  ?=([%9 %2 %10 *] app)
    ~[leaf+"application does not use direct Nock 9/Nock 10 gate invocation"]
  =/  crash=noun  (emit:jibb-nock (parse '(crash)') nock-registry)
  ?.  =(crash [0 0])  ~[leaf+"crash formula is not invalid Nock 0"]
  ~
--
