::  /lib/jibb-nock.hoon: Core AST to Nock formula emission
::
::  API
::    +emit     [expr native-registry]             noun
::    +execute  [subject=noun formula=noun]        outcome:jibb-core
::    +run      [expr native-registry]             outcome:jibb-core
::
::  A native registry contains authenticated Hoon gate nouns. Definition
::  identity is established by the caller during prelude preparation; this
::  library never recognizes a native from its spelling. Unknown names and
::  malformed direct AST nodes emit a crashing formula. +run exposes the raw
::  Nock result: differential callers must apply function results to noun
::  samples before comparing them with the interpreter's canonical outcomes.
::
::  Lexical references contain static axes. A let puts its value at axis 2.
::  A closure captures its whole current subject at axis 7 and its sample at
::  axis 6. A rec group is a finite core of gate-building arm formulas. Its
::  complete battery is right-nested beneath axis 2. Each resulting gate captures
::  [rec-core outer-subject] at axis 7, so recursive arms use core axis 14 and
::  captured outer bindings use axis 15. No cyclic runtime noun is required.
::
/+  jibb-core
|%
+$  native-registry  (map name:jibb-core noun)
+$  reference
  $~  [%local 1]
  $%  [%local axis=@]
      [%arm arm=@ core=@]
  ==
+$  binding  [name=name:jibb-core ref=reference]
+$  environment  (list binding)
::
++  shift-reference
  |=  [at=@ ref=reference]
  ^-  reference
  ?-  -.ref
    %local  [%local (peg at axis.ref)]
    %arm    [%arm arm.ref (peg at core.ref)]
  ==
::
++  shift-environment
  |=  [at=@ env=environment]
  ^-  environment
  (turn env |=(b=binding [name.b (shift-reference at ref.b)]))
::
++  find-reference
  |=  [n=name:jibb-core env=environment]
  ^-  (unit reference)
  ?~  env  ~
  ?:  =(n name.i.env)  `ref.i.env
  $(env t.env)
::
++  emit-reference
  |=  ref=reference
  ^-  noun
  ?-  -.ref
    %local  [0 axis.ref]
    %arm    [9 arm.ref 0 core.ref]
  ==
::
++  recursive-environment
  |=  [arms=(list rec-arm:jibb-core) core=@]
  ^-  environment
  =|  out=(list binding)
  =/  battery=@  2
  |-
  ?~  arms  (flop out)
  =/  arm=@  ?~(t.arms battery (peg battery 2))
  =/  rest-battery=@  ?~(t.arms battery (peg battery 3))
  $(arms t.arms, battery rest-battery, out [[name.i.arms [%arm arm core]] out])
::
++  battery-noun
  |=  formulas=(list noun)
  ^-  noun
  ?~  formulas  !!
  ?~  t.formulas  i.formulas
  [i.formulas $(formulas t.formulas)]
::
++  rec-core-formula
  |=  formulas=(list noun)
  ^-  noun
  ?~  formulas  !!
  [[1 (battery-noun formulas)] [0 1]]
::
++  valid-rec-arms
  |=  arms=(list rec-arm:jibb-core)
  ^-  ?
  ?~  arms  &
  ?.  ?=(%lam -.fun.i.arms)  |
  $(arms t.arms)
::
++  rec-arm-formula
  |=  battery=noun
  ^-  noun
  ::  On the rec core, build [battery [0 [rec-core outer-subject]]].
  [[1 battery] [[1 0] [[0 1] [0 3]]]]
::
++  rec-battery
  |=  $:  arms=(list rec-arm:jibb-core)
          group=(list rec-arm:jibb-core)
          outer=environment
          registry=native-registry
      ==
  ^-  (list noun)
  ?~  arms  ~
  =/  fun=expr:jibb-core  fun.i.arms
  ?>  ?=(%lam -.fun)
  =/  sample-scope=environment  [[sample.fun [%local 6]] ~]
  =/  rec-scope=environment  (recursive-environment group 14)
  =/  outer-scope=environment  (shift-environment 15 outer)
  =/  body=noun
    (emit-env body.fun :(weld sample-scope rec-scope outer-scope) registry)
  [(rec-arm-formula body) $(arms t.arms)]
::
++  emit-env
  |=  [e=expr:jibb-core env=environment registry=native-registry]
  ^-  noun
  ?-  -.e
    %lit     [1 val.lit.e]
    %var
      =/  found=(unit reference)  (find-reference name.e env)
      ?~  found  [0 0]
      (emit-reference u.found)
    %cons    [$(e hed.e) $(e tal.e)]
    %slot
      ?:  =(0 axis.e)  [0 0]
      ?:  =(1 axis.e)  $(e body.e)
      ?:  ?=(%slot -.body.e)
        ?:  =(0 axis.body.e)  [0 0]
        $(e [%slot (peg axis.body.e axis.e) body.body.e])
      [7 $(e body.e) 0 axis.e]
    %edit
      ?:  =(0 axis.e)  [0 0]
      [10 [axis.e $(e value.e)] $(e body.e)]
    %cell    [3 $(e body.e)]
    %eq      [5 $(e left.e) $(e right.e)]
    %if
      ?:  &(?=(%lit -.test.e) =(0 val.lit.test.e))
        $(e yes.e)
      ?:  &(?=(%lit -.test.e) =(1 val.lit.test.e))
        $(e no.e)
      [6 $(e test.e) $(e yes.e) $(e no.e)]
    %let
      =/  scope=environment
        [[name.e [%local 2]] (shift-environment 3 env)]
      [8 (emit-env value.e env registry) (emit-env body.e scope registry)]
    %rec
      ?~  arms.e  $(e body.e)
      ?.  (valid-rec-arms arms.e)  [0 0]
      =/  formulas=(list noun)  (rec-battery arms.e arms.e env registry)
      =/  core=noun  (rec-core-formula formulas)
      =/  scope=environment
        (weld (recursive-environment arms.e 2) (shift-environment 3 env))
      [8 core $(e body.e, env scope)]
    %lam
      =/  scope=environment
        [[sample.e [%local 6]] (shift-environment 7 env)]
      =/  battery=noun  $(e body.e, env scope)
      ::  Build [battery [0 current-subject]], the Hoon gate ABI.
      [[1 battery] [[1 0] [0 1]]]
    %app
      ?:  ?=(%lam -.fun.e)
        $(e [%let sample.fun.e sample.e body.fun.e])
      [9 2 10 [6 $(e sample.e)] $(e fun.e)]
    %native
      =/  found=(unit noun)  (~(get by registry) name.e)
      ?~  found  [0 0]
      [1 u.found]
    %crash   [0 0]
    %trace
      =/  message=noun  $(e message.e)
      =/  printer=noun
        [1 |=(text=@ [0 %leaf (trip text)])]
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
  =/  result  (mock [subject formula] |=(^ ~))
  ?-  -.result
    %0  [%ok p.result]
    %1  [%crash ~]
    %2  [%crash ~]
  ==
::
++  run
  |=  [e=expr:jibb-core registry=native-registry]
  ^-  outcome:jibb-core
  (execute 0 (emit e registry))
--
