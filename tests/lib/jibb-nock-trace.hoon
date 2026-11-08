::  Focused checks for trace-retaining Nock execution.
/+  jibb-core, jibb-nock, jibb-nock-trace
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
  ^-  $-(value:jibb-core evaluation:jibb-core)
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  [[%atom +(val.v)] ~]
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
++  turn-native
  ^-  $-(value:jibb-core evaluation:jibb-core)
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
  (~(put by r) [%own %turn] turn-native)
::
++  nock-registry
  ^-  native-registry:jibb-nock
  =/  r=native-registry:jibb-nock  empty-nock-registry
  =.  r  (~(put by r) [%own %inc] |=(a=@ +(a)))
  (~(put by r) [%own %turn] turn)
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
++  noun-at
  |=  [axis=@ value=noun]
  ^-  noun
  =/  got  (mock [value [0 axis]] |=(^ ~))
  ?.  ?=(%0 -.got)  !!
  p.got
::
++  check-traced
  |=  $:  e=expr:jibb-core
          expected=outcome:jibb-core
          expected-traces=(list @t)
      ==
  ^-  tang
  =/  formula=noun  (emit:jibb-nock e nock-registry)
  =/  raw=outcome:jibb-core  (execute:jibb-nock 0 formula)
  ?.  =(raw expected)
    ~[leaf+"raw execute disagreed with the focused expected outcome"]
  =/  traced=execution:jibb-core
    (run-traced:jibb-nock-trace e nock-registry)
  ?.  =(out.traced raw)
    ~[leaf+"traced execution out disagreed with raw execute"]
  ?.  =(traces.traced expected-traces)
    ~[leaf+"traced execution lost, reordered, or manufactured messages"]
  ~
::
++  test-nock-trace-nested-success
  ^-  tang
  %-  check-traced
  :+  (parse '(trace "first" (trace "second" (app (native inc) 41)))')
    [%ok 42]
  ~['first' 'second']
::
++  test-nock-trace-before-crash
  ^-  tang
  %-  check-traced
  :+  (parse '(trace "before" (crash))')
    [%crash ~]
  ~['before']
::
++  test-nock-trace-siblings-before-crash
  ^-  tang
  %-  check-traced
  :+  (parse '(cons (trace "left" 1) (cons (trace "right" 2) (crash)))')
    [%crash ~]
  ~['left' 'right']
::
++  test-nock-trace-clue-crash
  ^-  tang
  %-  check-traced
  :+  (parse '(trace (crash) (trace "body" 7))')
    [%crash ~]
  ~
::
++  test-nock-trace-turn-callbacks
  ^-  tang
  %-  check-traced
  :+  (parse '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (trace "callback" (app (native inc) x)))))')
    [%ok [2 3 0]]
  ~['callback' 'callback']
::
++  test-nock-trace-turn-callback-crash
  ^-  tang
  %-  check-traced
  :+  (parse '(app (native turn) (cons (cons 1 (cons 2 ~)) (lam x (if (eq x 1) (trace "callback" (app (native inc) x)) (crash)))))')
    [%crash ~]
  ~['callback']
::
++  test-nock-trace-lookalike-core-uses-selected-arm
  ^-  tang
  =/  printed=noun
    %-  emit:jibb-nock
    :_  ~
    [%trace [%lit [%ud 0 '0']] [%lit [%ud 0 '0']]]
  =/  printer=noun  (noun-at 63 (noun-at 13 printed))
  =/  battery=noun  (noun-at 2 printer)
  =/  selected=noun  (emit:jibb-nock (parse '(trace "forged" 42)') nock-registry)
  =/  formula=noun  [9 3 [1 [battery selected]]]
  =/  raw=outcome:jibb-core  (execute:jibb-nock 0 formula)
  ?.  =(raw [%ok 42])  ~[leaf+"lookalike-core control changed the raw result"]
  =/  traced=execution:jibb-core  (execute-traced:jibb-nock-trace 0 formula)
  ?.  &(=(out.traced raw) =(traces.traced ~['forged']))
    ~[leaf+"printer fast path discarded a selected non-printer arm's traces"]
  ~
--
