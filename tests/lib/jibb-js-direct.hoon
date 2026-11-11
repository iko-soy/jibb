::  Direct hole evaluation preserves strict discarded work while avoiding
::  fixed layout nouns. The shared emitter corpus covers broader expressions.
/+  jibb-core, jibb-js-direct
|%
++  check
  |=  [source=@t axes=(list @ud) expected=(unit @t)]
  ^-  tang
  =/  native=native:jibb-core  |=(v=value:jibb-core [v ~])
  =/  registry=native-registry:jibb-core
    (~(put by *(map name:jibb-core native:jibb-core)) [%own %raw-seal] native)
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core source registry)
  ?:  ?=(%| -.parsed)  ~[leaf+"direct Core did not read" leaf+(trip p.parsed)]
  =/  actual=(unit @t)  (direct-holes:jibb-js-direct p.parsed ~ axes ~)
  ?:  =(expected actual)  ~
  ~[leaf+"direct hole evaluator differs" leaf+(trip source) leaf+(trip ?~(actual 'no evaluator' u.actual))]
::
++  test-direct-text-without-element-allocation
  ^-  tang
  %-  check
  :*  '(lam words (app (native raw-seal) (cons %text words)))'
      ~[7]
      `'(($model) => {\0acheckValue($model, "cons tail");\0areturn [$model];\0a})'
  ==
::
++  test-direct-keeps-strict-discarded-cons-checks-after-tail-trace
  ^-  tang
  %-  check
  :*  '(lam words (let ignored (cons words (trace 1 ~)) (app (native raw-seal) (cons %text words))))'
      ~[7]
      `'(($model) => {\0atraceLazy(BigInt("1"), () => 0n);\0acheckValue($model, "cons head");\0acheckValue($model, "cons tail");\0areturn [$model];\0a})'
  ==
::
++  test-direct-local-recursion-retains-ordinary-path
  ^-  tang
  (check '(lam words (let ignored (rec ((f (lam n n))) (app f words)) (app (native raw-seal) (cons %text words))))' ~[7] ~)
--
