::  Recursive qath unfolding uses bounded fuel and preserves uncertain faces.
/+  jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  qath-fuel-errors
  ^-  (list tape)
  =/  source=@t  '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a'
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb source internal)
  ?~  prepared  ~["qath source did not prepare"]
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %qath iface.u.prepared)
  ?~  mold  ~["qath source did not export its mold"]
  =/  typ=itype:jibb  typ.u.mold
  ?.  ?=(%mrec -.typ)  ~["qath did not use the general recursive graph"]
  =/  lit=expr:jibb  [%lit *span:jibb [%null %n 0 '~']]
  =/  state=istate:jibb  *istate:jibb
  =/  faced=itype:jibb  [%face %field typ]
  =/  wrong=itype:jibb  [%face %other typ]
  =/  bound=isub:jibb  (isub-from-bindings:jibb ~[[0 typ]])
  =/  checks
    :^  -:(infer-call-context-arg:jibb lit typ ~ state(jrec-fuel 0) *span:jibb)
        -:(infer-call-context-arg:jibb lit typ ~ state(jrec-fuel 1) *span:jibb)
        -:(infer-call-context-arg:jibb lit typ ~ state(jrec-fuel 2) *span:jibb)
        :~  -:(itype-fit:jibb [%var 0] faced bound 1)
            -:(itype-fit:jibb faced [%var 0] bound 1)
            -:(itype-fit:jibb typ faced ~ 1)
            -:(itype-fit:jibb faced typ ~ 1)
            -:(itype-fit:jibb faced wrong ~ 1)
            -:(itype-fit:jibb wrong faced ~ 1)
        ==
  ?.  ?=([%| %& %& %unknown %unknown %ok %ok %bad %bad ~] checks)
    ~["qath null fuel or recursive face fitting failed"]
  =/  static-zero  (infer-qath-segments:jibb ~[[%knot 'x']] ~ state(jrec-fuel 0))
  =/  static-one   (infer-qath-segments:jibb ~[[%knot 'x']] ~ state(jrec-fuel 1))
  =/  static-two   (infer-qath-segments:jibb ~[[%knot 'x']] ~ state(jrec-fuel 2))
  ?.  ?=(%| -.static-zero)  ~["qath path with no fuel was accepted"]
  ?.  ?=(%& -.static-one)  ~["qath path with one unit of fuel was rejected"]
  ?.  ?=(%& -.static-two)  ~["qath path with two units of fuel was rejected"]
  ?.  &(=(0 jrec-fuel.p.static-one) =(1 jrec-fuel.p.static-two))
    ~["qath path consumed the wrong fuel"]
  =/  source=@t  (crip "++ nil ~\0a++ cell [i=~.hi t=~]\0a++ branch ?- x\0a  ~ 0\0a  [a b] 1\0a")
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/test/jibb source)
  ?:  ?=(%| -.parsed)  ~["qath fuel controls did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?~  ds  ~["qath fuel controls are missing definitions"]
  ?~  t.ds  ~["qath fuel controls are missing definitions"]
  ?~  t.t.ds  ~["qath fuel controls are missing definitions"]
  ?>  &(?=(%value -.i.t.ds) ?=(%value -.i.t.t.ds))
  =/  cell=expr:jibb  val.i.t.ds
  =/  branch=expr:jibb  val.i.t.t.ds
  =/  cell-zero  (infer-call-context-arg:jibb cell typ ~ state(jrec-fuel 0) *span:jibb)
  =/  cell-one   (infer-call-context-arg:jibb cell typ ~ state(jrec-fuel 1) *span:jibb)
  =/  cell-two   (infer-call-context-arg:jibb cell typ ~ state(jrec-fuel 2) *span:jibb)
  ::  A known cell fits the one-step view directly; only that unfold
  ::  consumes this construction budget. Type fitting has its own bound.
  ?.  &(?=(%& -.cell-one) ?=(%& -.cell-two))
    ~["qath cell did not fit its checked recursive view"]
  ?.  &(=(0 jrec-fuel.state.p.cell-one) =(1 jrec-fuel.state.p.cell-two))
    ~["recursive construction consumed the wrong fuel"]
  =/  match-zero  (rg-unfold-view:jibb typ 0)
  =/  match-one   (rg-unfold-view:jibb typ 1)
  =/  match-two   (rg-unfold-view:jibb typ 2)
  ?.  &(?=(%| -.cell-zero) ?=(~ match-zero) ?=(^ match-one) ?=(^ match-two))
    ~["qath cell or match fuel failed"]
  ?.  &(=(0 left.u.match-one) =(1 left.u.match-two) =(view.u.match-one view.u.match-two))
    ~["recursive views consumed the wrong fuel or changed between retries"]
  =/  coverage=coverage-check:jibb  (coverage-branch-check:jibb branch typ ~)
  ?.  ?=(%ok -.coverage)  ~["recursive qath patterns did not cover the checked graph"]
  ~
++  test-qath-fuel
  ^-  tang
  (turn qath-fuel-errors |=(reason=tape leaf+reason))
--
