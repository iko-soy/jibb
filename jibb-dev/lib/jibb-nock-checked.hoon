::  /lib/jibb-nock-checked.hoon: provenance-checked Core Nock execution
::
::  Every runtime value is [proof raw].  Function provenance is introduced only
::  by lambda, recursive-reference, and authenticated native expressions.  The
::  raw emitter remains independent; this emitter shares its lexical and rec-core
::  layout helpers but never infers functionhood from a raw noun's shape.
::
::  API
::    +emit         [expr native-registry]         checked formula
::    +execute      [subject formula]              canonical outcome
::    +run          [expr native-registry]         canonical outcome
::    +noun-native  authenticated raw Hoon gate    checked native gate
::    +turn-native  higher-order checked-list native gate
::
::  Native entries are raw Hoon-ABI gate nouns.  Their samples and products are
::  checked values at axis 6; registry authentication is always caller-supplied.
::
/+  jibb-core, jibb-nock
|%
+$  proof  noun
+$  checked  [proof=proof raw=noun]
+$  checked-native  noun
+$  native-registry  (map name:jibb-core checked-native)
::
++  noun-proof
  |=  p=proof
  ^-  ?
  ?@  p  =(%noun p)  |
::
++  function-proof
  |=  p=proof
  ^-  ?
  ?@  p  =(%function p)  |
::
++  cell-proof
  |=  p=proof
  ^-  ?
  ?@  p  |  =(%cell -.p)
::
++  lift-noun
  |=  raw=noun
  ^-  checked
  ?@  raw  [%noun raw]
  =/  hed=checked  $(raw -.raw)
  =/  tal=checked  $(raw +.raw)
  [[%cell proof.hed proof.tal] [raw.hed raw.tal]]
::
++  canonical
  |=  value=noun
  ^-  noun
  ?@  value  !!
  =/  tag=noun  -.value
  =/  raw=noun  +.value
  ?@  tag
    ?:  =(%function tag)  !!
    ?.  =(%noun tag)  !!
    ?^  raw  !!
    raw
  ?^  -.tag  !!
  ?.  =(%cell -.tag)  !!
  ?@  raw  !!
  =/  head-proof=noun  +.tag
  ?@  head-proof  !!
  =/  hed=noun  [-.head-proof -.raw]
  =/  tal=noun  [+.head-proof +.raw]
  [$(value hed) $(value tal)]
::
++  cons-values
  |=  [hed=checked tal=checked]
  ^-  checked
  [[%cell proof.hed proof.tal] [raw.hed raw.tal]]
::
++  cell-value
  |=  value=checked
  ^-  checked
  ?:  (function-proof proof.value)  !!
  ?:  (cell-proof proof.value)  [%noun 0]
  ?.  (noun-proof proof.value)  !!
  [%noun 1]
::
++  slot-inner
  |=  [axis=@ value=checked]
  ^-  checked
  ?:  =(1 axis)  value
  ?.  (cell-proof proof.value)  !!
  ?@  raw.value  !!
  =/  pick  (cap axis)
  %=  $
    axis   (mas axis)
    value  ?-(pick %2 [-.+.proof.value -.raw.value], %3 [+.+.proof.value +.raw.value])
  ==
::
++  slot-value
  |=  [axis=@ value=checked]
  ^-  checked
  ?:  =(0 axis)  !!
  ?:  (function-proof proof.value)  !!
  (slot-inner axis value)
::
++  edit-inner
  |=  [axis=@ old=checked new=checked]
  ^-  checked
  ?:  =(1 axis)  new
  ?.  (cell-proof proof.old)  !!
  ?@  raw.old  !!
  =/  pick  (cap axis)
  ?-  pick
    %2
      =/  hed=checked  $(axis (mas axis), old [-.+.proof.old -.raw.old])
      [[%cell proof.hed +.+.proof.old] [raw.hed +.raw.old]]
    %3
      =/  tal=checked  $(axis (mas axis), old [+.+.proof.old +.raw.old])
      [[%cell -.+.proof.old proof.tal] [-.raw.old raw.tal]]
  ==
::
++  edit-value
  |=  [axis=@ old=checked new=checked]
  ^-  checked
  ?:  =(0 axis)  !!
  ?:  (function-proof proof.old)  !!
  (edit-inner axis old new)
::
++  eq-values
  |=  [left=checked right=checked]
  ^-  checked
  [%noun ?:(=((canonical left) (canonical right)) 0 1)]
::
++  loobean-raw
  |=  value=checked
  ^-  @
  ?.  (noun-proof proof.value)  !!
  ?@  raw.value  ?:(|(=(0 raw.value) =(1 raw.value)) raw.value !!)  !!
::
++  trace-printer
  =/  printed=noun
    %-  emit:jibb-nock
    :_  ~
    [%trace [%lit [%ud 0 '0']] [%lit [%ud 0 '0']]]
  =/  hint=noun
    =/  result  (mock [printed [0 13]] |=(^ ~))
    ?>(?=(%0 -.result) p.result)
  =/  result  (mock [hint [0 63]] |=(^ ~))
  ?>(?=(%0 -.result) p.result)
::
++  message-raw
  =/  proof-test=noun  [5 [0 12] [1 %noun]]
  =/  raw-test=noun  [5 [1 1] [3 [0 13]]]
  =/  battery=noun
    [6 proof-test [6 raw-test [0 13] [0 0]] [0 0]]
  [battery 0 0]
::
++  function-raw
  |=  value=checked
  ^-  noun
  ?:  (function-proof proof.value)  raw.value  !!
::
++  noun-native
  |=  raw=noun
  ^-  checked-native
  =/  input=noun  (call-helper canonical [0 6])
  =/  output=noun  [9 2 10 [6 input] [1 raw]]
  =/  battery=noun  (call-helper lift-noun output)
  [battery 0 0]
::
++  swap-value
  |=  value=checked
  ^-  checked
  ?.  (cell-proof proof.value)  !!
  ?@  raw.value  !!
  [[%cell +.+.proof.value -.+.proof.value] [+.raw.value -.raw.value]]
::
++  swap-native
  ^-  checked-native
  =/  battery=noun  (call-helper swap-value [0 6])
  [battery 0 0]
::
++  apply-checked
  |=  [fun=checked sample=checked]
  ^-  checked
  ?.  (function-proof proof.fun)  !!
  ;;(checked .*(raw.fun [9 2 10 [6 [1 sample]] [0 1]]))
::
++  turn-one
  |=  [item=checked callback=checked]
  ^-  checked
  (apply-checked callback item)
::
++  turn-items
  |=  [items=checked callback=checked]
  ^-  checked
  ?:  (noun-proof proof.items)
    ?.  =(0 raw.items)  !!
    [%noun 0]
  ?.  (cell-proof proof.items)  !!
  ?@  raw.items  !!
  =/  hed=checked  [-.+.proof.items -.raw.items]
  =/  tal=checked  [+.+.proof.items +.raw.items]
  =/  mapped=checked  (turn-one hed callback)
  =/  rest=checked  $(items tal)
  (cons-values mapped rest)
::
++  turn-value
  |=  value=checked
  ^-  checked
  ?.  (cell-proof proof.value)  !!
  ?@  raw.value  !!
  =/  items=checked  [-.+.proof.value -.raw.value]
  =/  callback=checked  [+.+.proof.value +.raw.value]
  (turn-items items callback)
::
++  turn-native
  ^-  checked-native
  =/  battery=noun  (call-helper turn-value [0 6])
  [battery 0 0]
::
++  call-helper
  |=  [helper=noun sample=noun]
  ^-  noun
  [9 2 10 [6 sample] [1 helper]]
::
++  rec-battery
  |=  $:  arms=(list rec-arm:jibb-core)
          group=(list rec-arm:jibb-core)
          outer=environment:jibb-nock
          registry=native-registry
      ==
  ^-  (list noun)
  ?~  arms  ~
  =/  fun=expr:jibb-core  fun.i.arms
  ?>  ?=(%lam -.fun)
  =/  sample-scope=environment:jibb-nock  [[sample.fun [%local 6]] ~]
  =/  rec-scope=environment:jibb-nock  (recursive-environment:jibb-nock group 14)
  =/  outer-scope=environment:jibb-nock  (shift-environment:jibb-nock 15 outer)
  =/  body=noun
    (emit-env body.fun :(weld sample-scope rec-scope outer-scope) registry)
  [(rec-arm-formula:jibb-nock body) $(arms t.arms)]
::
++  emit-env
  |=  [e=expr:jibb-core env=environment:jibb-nock registry=native-registry]
  ^-  noun
  ?-  -.e
    %lit     [1 %noun val.lit.e]
    %var
      =/  found=(unit reference:jibb-nock)  (find-reference:jibb-nock name.e env)
      ?~  found  [0 0]
      ?:  ?=(%local -.u.found)
        [0 axis.u.found]
      [[1 %function] (emit-reference:jibb-nock u.found)]
    %cons    (call-helper cons-values [$(e hed.e) $(e tal.e)])
    %slot
      ?:  =(0 axis.e)  [0 0]
      (call-helper slot-value [[1 axis.e] $(e body.e)])
    %edit
      ?:  =(0 axis.e)  [0 0]
      (call-helper edit-value [[1 axis.e] $(e body.e) $(e value.e)])
    %cell    (call-helper cell-value $(e body.e))
    %eq      (call-helper eq-values [$(e left.e) $(e right.e)])
    %if
      ?:  &(?=(%lit -.test.e) =(0 val.lit.test.e))
        $(e yes.e)
      ?:  &(?=(%lit -.test.e) =(1 val.lit.test.e))
        $(e no.e)
      [6 (call-helper loobean-raw $(e test.e)) $(e yes.e) $(e no.e)]
    %let
      =/  scope=environment:jibb-nock
        [[name.e [%local 2]] (shift-environment:jibb-nock 3 env)]
      [8 (emit-env value.e env registry) (emit-env body.e scope registry)]
    %rec
      ?~  arms.e  $(e body.e)
      ?.  (valid-rec-arms:jibb-nock arms.e)  [0 0]
      =/  formulas=(list noun)  (rec-battery arms.e arms.e env registry)
      =/  core=noun  (rec-core-formula:jibb-nock formulas)
      =/  scope=environment:jibb-nock
        (weld (recursive-environment:jibb-nock arms.e 2) (shift-environment:jibb-nock 3 env))
      [8 core $(e body.e, env scope)]
    %lam
      =/  scope=environment:jibb-nock
        [[sample.e [%local 6]] (shift-environment:jibb-nock 7 env)]
      =/  battery=noun  $(e body.e, env scope)
      [[1 %function] [[1 battery] [[1 0] [0 1]]]]
    %app
      ?:  ?=(%lam -.fun.e)
        $(e [%let sample.fun.e sample.e body.fun.e])
      =/  fun=noun  (call-helper function-raw $(e fun.e))
      [9 2 10 [6 $(e sample.e)] fun]
    %native
      =/  found=(unit checked-native)  (~(get by registry) name.e)
      ?~  found  [0 0]
      [[1 %function] [1 u.found]]
    %crash   [0 0]
    %trace
      =/  message=noun  (call-helper message-raw $(e message.e))
      =/  printer=noun  [1 trace-printer]
      =/  hint=noun  [9 2 10 [6 message] printer]
      [11 [%slog hint] $(e body.e)]
  ==
::
++  emit
  |=  [e=expr:jibb-core registry=native-registry]
  ^-  noun
  (emit-env e ~ registry)
::
++  execute
  |=  [subject=noun formula=noun]
  ^-  outcome:jibb-core
  =/  tried=(each noun tang)
    %-  mule
    |.
    =/  result  (mock [subject formula] |=(^ ~))
    ?-  -.result
      %0  (canonical p.result)
      %1  !!
      %2  !!
    ==
  ?-  -.tried
    %&  [%ok p.tried]
    %|  [%crash ~]
  ==
::
++  run
  |=  [e=expr:jibb-core registry=native-registry]
  ^-  outcome:jibb-core
  (execute 0 (emit e registry))
--
