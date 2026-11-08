::  Differential provenance checks for checked Core Nock execution.
/+  jibb-core, jibb-nock, jibb-nock-checked, jibb-nock-trace
|%
++  empty-interpreter-registry
  ^-  native-registry:jibb-core
  *(map name:jibb-core native:jibb-core)
::
++  empty-raw-registry
  ^-  native-registry:jibb-nock
  *(map name:jibb-core noun)
::
++  empty-checked-registry
  ^-  native-registry:jibb-nock-checked
  *(map name:jibb-core checked-native:jibb-nock-checked)
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
++  swap-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%cell -.v)  !!
  [[%cell tal.v hed.v] ~]
::
++  fail-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  !!
::
++  apply-interpreted
  |=  [fun=value:jibb-core sample=value:jibb-core]
  ^-  evaluation:jibb-core
  ?-  -.fun
    ?(%atom %cell)  !!
    %native         (run.fun sample)
    %closure
      =/  env=environment:jibb-core
        [[%value sample.fun sample] env.fun]
      (evaluate-env:jibb-core body.fun env interpreter-registry)
  ==
::
++  interpreted-turn-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  ?.  ?=(%cell -.v)  !!
  =/  items=value:jibb-core  hed.v
  =/  fun=value:jibb-core  tal.v
  |-
  ^-  evaluation:jibb-core
  ?:  ?=(%atom -.items)
    ?.  =(0 val.items)  !!
    [[%atom 0] ~]
  ?.  ?=(%cell -.items)  !!
  =/  hed=evaluation:jibb-core  (apply-interpreted fun hed.items)
  =/  tal=evaluation:jibb-core  $(items tal.items)
  [[%cell val.hed val.tal] (weld traces.hed traces.tal)]
::
++  interpreter-registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  empty-interpreter-registry
  =.  r  (~(put by r) [%own %inc] inc-native)
  =.  r  (~(put by r) [%own %dec] dec-native)
  =.  r  (~(put by r) [%own %add] add-native)
  =.  r  (~(put by r) [%own %swap] swap-native)
  =.  r  (~(put by r) [%own %fail] fail-native)
  =.  r  (~(put by r) [%own %bad-gate] fail-native)
  (~(put by r) [%own %turn] interpreted-turn-native)
::
++  raw-registry
  ^-  native-registry:jibb-nock
  =/  r=native-registry:jibb-nock  empty-raw-registry
  =.  r  (~(put by r) [%own %inc] |=(a=@ +(a)))
  =.  r  (~(put by r) [%own %dec] |=(a=@ ?:(=(0 a) !! (dec a))))
  =.  r  (~(put by r) [%own %add] |=([a=@ b=@] (add a b)))
  =.  r  (~(put by r) [%own %swap] |=([a=@ b=@] [b a]))
  =.  r  (~(put by r) [%own %fail] |=(* !!))
  (~(put by r) [%own %turn] turn)
::
++  checked-registry
  ^-  native-registry:jibb-nock-checked
  =/  r=native-registry:jibb-nock-checked  empty-checked-registry
  =.  r  (~(put by r) [%own %inc] (noun-native:jibb-nock-checked |=(a=@ +(a))))
  =.  r  (~(put by r) [%own %dec] (noun-native:jibb-nock-checked |=(a=@ ?:(=(0 a) !! (dec a)))))
  =.  r  (~(put by r) [%own %add] (noun-native:jibb-nock-checked |=([a=@ b=@] (add a b))))
  =.  r  (~(put by r) [%own %swap] swap-native:jibb-nock-checked)
  =.  r  (~(put by r) [%own %fail] (noun-native:jibb-nock-checked |=(* !!)))
  =.  r  (~(put by r) [%own %bad-gate] (noun-native:jibb-nock-checked 0))
  (~(put by r) [%own %turn] turn-native:jibb-nock-checked)
::
++  parse
  |=  src=@t
  ^-  expr:jibb-core
  =/  parsed=(each expr:jibb-core @t)
    (read-expr:jibb-core src interpreter-registry)
  ?-  -.parsed
    %|  ~|(p.parsed !!)
    %&  p.parsed
  ==
::
++  lit
  |=  val=@
  ^-  expr:jibb-core
  [%lit [%ud val (scot %ud val)]]
::
++  note
  |=  [message=@t body=expr:jibb-core]
  ^-  expr:jibb-core
  [%trace [%lit [%t message message]] body]
::
++  agrees
  |=  e=expr:jibb-core
  ^-  ?
  =/  expected=outcome:jibb-core  (run:jibb-core e interpreter-registry)
  =/  got=outcome:jibb-core  (run:jibb-nock-checked e checked-registry)
  =(expected got)
::
++  ok
  |=  [e=expr:jibb-core expected=noun]
  ^-  ?
  &((agrees e) =([%ok expected] (run:jibb-nock-checked e checked-registry)))
::
++  crashes
  |=  e=expr:jibb-core
  ^-  ?
  =/  got=outcome:jibb-core  (run:jibb-nock-checked e checked-registry)
  &((agrees e) ?=(%crash -.got))
::
++  raw-agrees
  |=  e=expr:jibb-core
  ^-  ?
  =/  expected=outcome:jibb-core  (run:jibb-core e interpreter-registry)
  =/  raw=outcome:jibb-core  (run:jibb-nock e raw-registry)
  =/  checked=outcome:jibb-core  (run:jibb-nock-checked e checked-registry)
  &(=(expected raw) =(expected checked))
::
++  report-agreements
  |=  sources=(list @t)
  ^-  tang
  ?~  sources  ~
  ?.  (agrees (parse i.sources))
    ~[leaf+(trip (cat 3 'checked/Core disagreement: ' i.sources))]
  $(sources t.sources)
::
++  report-raw-agreements
  |=  sources=(list @t)
  ^-  tang
  ?~  sources  ~
  =/  e=expr:jibb-core  (parse i.sources)
  =/  expected=outcome:jibb-core  (run:jibb-core e interpreter-registry)
  =/  raw=outcome:jibb-core  (run:jibb-nock e raw-registry)
  =/  checked=outcome:jibb-core  (run:jibb-nock-checked e checked-registry)
  ?.  &(=(expected raw) =(expected checked))
    ~[leaf+(trip (cat 3 'checked/raw/Core disagreement: ' i.sources)) (sell !>([expected raw checked]))]
  $(sources t.sources)
::
++  report-crashes
  |=  [label=@t expressions=(list expr:jibb-core)]
  ^-  tang
  ?~  expressions  ~
  ?.  (crashes i.expressions)
    ~[leaf+(trip label) leaf+"expression did not crash in both evaluators" (sell !>(i.expressions))]
  $(expressions t.expressions)
::
++  traced
  |=  [e=expr:jibb-core expected=outcome:jibb-core messages=(list @t)]
  ^-  ?
  =/  got=execution:jibb-core
    (run-checked-traced:jibb-nock-trace e checked-registry)
  &(=(out.got expected) =(traces.got messages))
::
++  ordinary-gate-noun
  ^-  expr:jibb-core
  =/  c
    |=  [a=expr:jibb-core b=expr:jibb-core]
    ^-  expr:jibb-core
    [%cons a b]
  =/  one  |=(a=expr:jibb-core (c (lit 1) a))
  =/  zero  |=(a=expr:jibb-core (c (lit 0) a))
  (c (one (zero (lit 6))) (c (one (zero (lit 1))) (zero (lit 1))))
::
++  test-checked-ordinary-corpus-and-raw-agreement
  ^-  tang
  %-  report-raw-agreements
  :~  '0'
      '42'
      '(cons 1 (cons 2 3))'
      '(slot 1 (cons 1 2))'
      '(slot 2 (slot 3 (cons 1 (cons 2 3))))'
      '(edit 6 (cons 1 (cons 2 3)) 9)'
      '(cell? (cons 1 2))'
      '(eq (cons 1 (cons 2 3)) (cons 1 (cons 2 3)))'
      '(if (eq 1 1) 42 (crash))'
      '(if %.y 42 (crash))'
      '(if %.n (crash) 42)'
      '(let x 40 (app (native inc) x))'
      '(app (lam x x) 42)'
      '(app (app (lam x (lam y (app (native add) (cons x y)))) 40) 2)'
      '(app (native swap) (cons 1 2))'
      '(trace "ordinary" 9)'
  ==
::
++  test-checked-function-results-and-containers
  ^-  tang
  =/  sources=(list @t)
    :~  '(lam x x)'
        '(native inc)'
        '(let x 40 (lam y (app (native add) (cons x y))))'
        '(app (lam x (lam y x)) 1)'
        '(cons (lam x x) 0)'
        '(cons 0 (native inc))'
        '(cons 1 (cons 2 (cons (lam x x) 0)))'
        '(cell? (lam x x))'
        '(cell? (native inc))'
    ==
  =/  bad=(unit @t)
    |-
    ?~  sources  ~
    ?.  (crashes (parse i.sources))  `i.sources
    $(sources t.sources)
  ?^  bad  ~[leaf+(trip (cat 3 'function accepted as noun: ' u.bad))]
  =/  positives=(list @t)
    :~  '(cell? (cons (lam x x) 0))'
        '(app (slot 2 (cons (lam x (app (native inc) x)) 0)) 41)'
        '(slot 3 (edit 3 (cons (lam x x) 0) 42))'
        '(app (slot 2 (edit 2 (cons 0 0) (lam x (app (native inc) x)))) 41)'
        '(app (app (lam f (lam x (app f x))) (lam x (app (native inc) x))) 41)'
    ==
  =/  expected=(list noun)  ~[0 42 42 42 42]
  |-
  ?~  positives  ?~(expected ~ ~[leaf+"missing positive expected value"])
  ?~  expected  ~[leaf+"extra positive expected value"]
  ?.  (ok (parse i.positives) i.expected)
    ~[leaf+(trip (cat 3 'function container control failed: ' i.positives))]
  $(positives t.positives, expected t.expected)
::
++  test-checked-eq-rejects-functions-deeply
  ^-  tang
  =/  f=expr:jibb-core  (parse '(lam x x)')
  =/  n=expr:jibb-core  (parse '(native inc)')
  =/  fc=expr:jibb-core  [%cons f (lit 0)]
  =/  nc=expr:jibb-core  [%cons (lit 0) n]
  =/  data=expr:jibb-core  [%cons (lit 1) (lit 2)]
  %+  report-crashes  'eq provenance'
  :~  [%eq f f]
      [%eq f data]
      [%eq data f]
      [%eq n n]
      [%eq fc fc]
      [%eq nc nc]
      [%eq data fc]
      [%eq fc data]
      [%eq data nc]
      [%eq nc data]
      [%eq [%cons data fc] data]
      [%eq data [%cons data nc]]
  ==
::
++  test-checked-slot-edit-root-and-intermediate-guards
  ^-  tang
  =/  f=expr:jibb-core  (parse '(lam x x)')
  =/  n=expr:jibb-core  (parse '(native inc)')
  =/  fc=expr:jibb-core  [%cons f (lit 0)]
  =/  nested=expr:jibb-core  [%cons (lit 0) fc]
  %+  report-crashes  'slot/edit provenance'
  :~  [%slot 1 f]
      [%slot 2 f]
      [%slot 3 f]
      [%slot 1 n]
      [%slot 2 n]
      [%edit 1 f (lit 0)]
      [%edit 2 f (lit 0)]
      [%edit 3 f (lit 0)]
      [%edit 1 n (lit 0)]
      [%edit 2 n (lit 0)]
      [%slot 2 [%slot 2 fc]]
      [%slot 3 [%slot 2 fc]]
      [%slot 6 [%slot 3 nested]]
      [%edit 2 [%slot 2 fc] (lit 0)]
      [%slot 4 nested]
      [%edit 4 nested (lit 9)]
  ==
::
++  test-checked-ordinary-gate-shaped-noun-is-data
  ^-  tang
  =/  ordinary=expr:jibb-core  ordinary-gate-noun
  ?.  (ok [%cell ordinary] 0)  ~[leaf+"ordinary gate-shaped noun was not a cell"]
  ?.  (ok [%eq ordinary ordinary] 0)  ~[leaf+"ordinary gate-shaped noun was not noun-equal"]
  ?.  (ok [%slot 2 ordinary] [1 0 6])  ~[leaf+"ordinary gate-shaped noun projection changed"]
  ?.  (ok [%slot 2 [%edit 2 ordinary (lit 9)]] 9)  ~[leaf+"ordinary gate-shaped noun edit changed"]
  ?.  (crashes [%app ordinary (lit 41)])  ~[leaf+"ordinary gate-shaped noun acquired function provenance"]
  ~
::
++  test-checked-strictness-lazy-if-and-messages
  ^-  tang
  =/  x=name:jibb-core  [%own %x]
  =/  pair=expr:jibb-core  [%cons (lit 1) (lit 2)]
  %+  report-crashes  'strict checked operand'
  :~  [%let x [%crash ~] (lit 42)]
      [%app [%lam x (lit 42)] [%crash ~]]
      [%app [%crash ~] (lit 42)]
      [%cons [%crash ~] (lit 1)]
      [%cons (lit 1) [%crash ~]]
      [%slot 1 [%crash ~]]
      [%edit 1 [%crash ~] (lit 1)]
      [%edit 1 (lit 1) [%crash ~]]
      [%cell [%crash ~]]
      [%eq [%crash ~] (lit 1)]
      [%eq (lit 1) [%crash ~]]
      [%trace [%crash ~] (lit 42)]
      [%if [%crash ~] (lit 1) (lit 2)]
      [%if (lit 2) (lit 1) (lit 2)]
      [%if pair (lit 1) (lit 2)]
      [%if [%lam x [%var x]] (lit 1) (lit 2)]
      [%trace pair (lit 0)]
      [%trace [%lam x [%var x]] (lit 0)]
  ==
::
++  test-checked-recursion-and-closures
  ^-  tang
  %-  report-agreements
  :~  '(let x 40 (app (lam y (app (native add) (cons x y))) 2))'
      '(app (app (lam x (lam y (app (native add) (cons x y)))) 40) 2)'
      '(rec ((loop (lam n (if (eq n 0) 42 (app loop (app (native dec) n)))))) (app loop 20))'
      '(rec ((even (lam n (if (eq n 0) %.y (app odd (app (native dec) n))))) (odd (lam n (if (eq n 0) %.n (app even (app (native dec) n)))))) (cons (app even 10) (cons (app odd 10) (cons (app even 11) (app odd 11)))))'
      '(let base 40 (rec ((add-base (lam n (app (native add) (cons base n))))) (app add-base 2)))'
      '(rec ((loop (lam n (if (eq n 0) 42 (app loop (app (native dec) n)))))) (app (slot 2 (cons loop 0)) 5))'
      '(rec ((outer (lam n (lam m (app (native add) (cons n m)))))) (app (app outer 40) 2))'
  ==
::
++  test-checked-noun-only-native-adapters
  ^-  tang
  ?.  (ok (parse '(app (native inc) 41)') 42)
    ~[leaf+"noun-only native increment failed" (sell !>((run:jibb-nock-checked (parse '(app (native inc) 41)') checked-registry)))]
  ?.  (ok (parse '(app (native swap) (cons 1 (cons 2 3)))') [[2 3] 1])
    ~[leaf+"raw native cell result was not recursively lifted"]
  ?.  (ok (parse '(app (slot 2 (app (native swap) (cons 0 (lam x (app (native inc) x))))) 41)') 42)
    ~[leaf+"cell-preserving native rejected or lost a callback result"]
  =/  invalid=(list @t)
    :~  '(app (native inc) (lam x x))'
        '(app (native add) (cons (lam x x) 1))'
        '(app (native swap) (cons 0 (native inc)))'
        '(app (native bad-gate) 0)'
        '(app (native fail) 1)'
        '(app (native dec) 0)'
    ==
  |-
  ?~  invalid
    =/  shape=noun  [[1 0 6] [[1 0] [0 1]]]
    =/  adapter=checked-native:jibb-nock-checked
      (noun-native:jibb-nock-checked |=(* shape))
    =/  called
      (mock [adapter [9 2 10 [6 [1 %noun 0]] [0 1]]] |=(^ ~))
    ?.  ?=(%0 -.called)  ~[leaf+"native adapter raw ABI call crashed"]
    =/  made=checked:jibb-nock-checked  ;;(checked:jibb-nock-checked p.called)
    ?.  =(raw.made shape)  ~[leaf+"native raw result changed"]
    ?.  (cell-proof:jibb-nock-checked proof.made)  ~[leaf+"gate-shaped native result acquired function proof"]
    ?.  =((canonical:jibb-nock-checked made) shape)
      ~[leaf+"recursively lifted native noun did not canonicalize"]
    ~
  ?.  (crashes (parse i.invalid))
    ~[leaf+(trip (cat 3 'noun-only native accepted invalid input: ' i.invalid))]
  $(invalid t.invalid)
::
++  test-checked-turn-adapter
  ^-  tang
  =/  callback-expr=expr:jibb-core  (parse '(lam x (app (native inc) x))')
  =/  made  (mock [0 (emit:jibb-nock-checked callback-expr checked-registry)] |=(^ ~))
  ?.  ?=(%0 -.made)  ~[leaf+"turn test callback did not compile"]
  =/  callback=checked:jibb-nock-checked  ;;(checked:jibb-nock-checked p.made)
  =/  direct=checked:jibb-nock-checked
    (apply-checked:jibb-nock-checked callback [%noun 1])
  ?.  =(raw.direct 2)  ~[leaf+"direct checked callback application failed"]
  =/  single=checked:jibb-nock-checked
    (turn-one:jibb-nock-checked [%noun 1] callback)
  ?.  =(raw.single 2)  ~[leaf+"singleton raw turn bridge failed"]
  =/  successes=(list @t)
    :~  '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (app (native inc) x))))'
        '(app (native turn) (cons ~ (lam x (app (native inc) x))))'
        '(let captured 1 (app (native turn) (cons (cons 40 (cons 41 ~)) (lam x (app (native add) (cons x captured))))))'
      '(app (slot 2 (app (native turn) (cons (cons 41 ~) (lam x (lam y (app (native add) (cons x y))))))) 1)'
      '(app (native turn) (cons ~ 0))'
    ==
  =/  expected=(list noun)  ~[[2 3 0] 0 [41 42 0] 42 0]
  |-
  ?~  successes
    ?~  expected
      %+  report-crashes  'turn callback provenance'
      :~  (parse '(app (native turn) (cons (cons 1 ~) (lam x (lam y x))))')
          (parse '(app (native turn) (cons (cons 1 ~) (lam x (cons x (lam y y)))))')
          (parse '(app (native turn) (cons 1 (lam x x)))')
          (parse '(app (native turn) (cons (cons 1 ~) 0))')
          (parse '(app (native turn) (cons (cons 1 2) (lam x x)))')
      ==
    ~[leaf+"extra turn expected value"]
  ?~  expected  ~[leaf+"missing turn expected value"]
  =/  current=expr:jibb-core  (parse i.successes)
  ?.  (ok current i.expected)
    ~[leaf+(trip (cat 3 'checked turn failed: ' i.successes)) (sell !>((mock [0 (emit:jibb-nock-checked current checked-registry)] |=(^ ~))))]
  $(successes t.successes, expected t.expected)
::
++  test-checked-native-provenance-is-explicit
  ^-  tang
  =/  e=expr:jibb-core  (parse '(app (native inc) 1)')
  =/  missing=outcome:jibb-core
    (run:jibb-nock-checked e empty-checked-registry)
  ?.  ?=(%crash -.missing)  ~[leaf+"raw/interpreter registry manufactured checked native"]
  =/  lookalike=expr:jibb-core  [%native [%qualified /prelude %inc]]
  =/  lookalike-result=outcome:jibb-core
    (run:jibb-nock-checked lookalike checked-registry)
  ?.  ?=(%crash -.lookalike-result)
    ~[leaf+"qualified native lookalike was authenticated"]
  =/  unknown=expr:jibb-core  [%native [%own %not-registered]]
  =/  unknown-result=outcome:jibb-core
    (run:jibb-nock-checked unknown checked-registry)
  ?.  ?=(%crash -.unknown-result)
    ~[leaf+"unknown checked native did not fail closed"]
  ~
::
++  test-checked-canonical-execution-contract
  ^-  tang
  =/  valid=outcome:jibb-core
    (execute:jibb-nock-checked 0 [1 [%cell %noun %noun] [1 2]])
  ?.  =(valid [%ok 1 2])  ~[leaf+"valid mirrored noun was not canonicalized"]
  =/  invalid=(list noun)
    :~  [1 [%noun [1 2]]]
        [1 [%function 0]]
        [1 [%cell %noun] 0]
        [1 [%cell %noun %function] [1 0]]
        [1 [%unknown 0]]
    ==
  |-
  ?~  invalid  ~
  =/  got=outcome:jibb-core  (execute:jibb-nock-checked 0 i.invalid)
  ?.  ?=(%crash -.got)  ~[leaf+"malformed checked value escaped canonical execution"]
  $(invalid t.invalid)
::
++  test-checked-traces-and-canonicalization
  ^-  tang
  ?.  (traced (parse '(trace "first" (trace "second" (app (native inc) 41)))') [%ok 42] ~['first' 'second'])
    ~[leaf+"nested checked traces were lost or reordered"]
  ?.  (traced (parse '(trace "before" (crash))') [%crash ~] ~['before'])
    ~[leaf+"checked trace before crash was not retained"]
  ?.  (traced (parse '(cons (trace "left" 1) (cons (trace "right" 2) (crash)))') [%crash ~] ~['left' 'right'])
    ~[leaf+"checked sibling traces before crash were not retained"]
  ?.  (traced (parse '(trace (crash) (trace "body" 7))') [%crash ~] ~)
    ~[leaf+"checked trace evaluated its body after a message crash"]
  ?.  (traced (parse '(trace "made" (lam x x))') [%crash ~] ~['made'])
    ~[leaf+"canonical function rejection lost its completed trace"]
  ~
::
++  test-checked-turn-callback-traces
  ^-  tang
  =/  callback=@t
    '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (trace "callback" (app (native inc) x)))))'
  ?.  (traced (parse callback) [%ok [2 3 0]] ~['callback' 'callback'])
    ~[leaf+"checked turn callback traces were lost or reordered"]
  =/  callback-crash=@t
    '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (if (eq x 1) (trace "callback" (app (native inc) x)) (trace "before-crash" (crash))))))'
  ?.  (traced (parse callback-crash) [%crash ~] ~['callback' 'before-crash'])
    ~[leaf+"checked turn traces before callback crash were lost"]
  =/  improper=@t
    '(app (native turn) (cons (cons 1 2) (lam x (trace "callback" (app (native inc) x)))))'
  ?.  (traced (parse improper) [%crash ~] ~['callback'])
    ~[leaf+"checked turn validated an improper tail before completing the head callback"]
  =/  functions=@t
    '(app (native turn) (cons (cons 41 (cons 40 ~)) (lam x (trace "callback" (lam y (app (native add) (cons x y)))))))'
  ?.  (traced (parse functions) [%crash ~] ~['callback' 'callback'])
    ~[leaf+"checked turn canonicalized callback functions before finishing later callbacks"]
  ~
--
