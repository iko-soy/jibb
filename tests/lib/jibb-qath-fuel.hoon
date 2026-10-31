::  Recursive qath unfolding uses bounded fuel and preserves uncertain faces.
/+  jibb
|%
++  qath-fuel-errors
  ^-  (list tape)
  =/  typ=itype:jibb  [%jrec /lib/jibb/internal/jibb %qath ~ %i %ta %t]
  =/  lit=expr:jibb  [%lit *span:jibb [%null %n 0 '~']]
  =/  state=istate:jibb  *istate:jibb
  =/  faced=itype:jibb  [%face %field typ]
  =/  wrong=itype:jibb  [%face %other typ]
  =/  bound=isub:jibb  ~[[0 typ]]
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
  =/  static-zero  (qath-static-fuel:jibb ~[[%knot 'x']] 0)
  =/  static-one   (qath-static-fuel:jibb ~[[%knot 'x']] 1)
  =/  static-two   (qath-static-fuel:jibb ~[[%knot 'x']] 2)
  ?.  &(=(~ static-zero) =(static-one [~ 0]) =(static-two [~ 1]))
    ~["qath static path fuel failed"]
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
  =/  match-zero  (jrec-match-view:jibb branch [%& typ state(jrec-fuel 0)])
  =/  match-one   (jrec-match-view:jibb branch [%& typ state(jrec-fuel 1)])
  =/  match-two   (jrec-match-view:jibb branch [%& typ state(jrec-fuel 2)])
  ?.  &(?=(%| -.cell-zero) ?=(%| -.cell-one) ?=(%& -.cell-two) ?=(%| -.match-zero) ?=(%& -.match-one) ?=(%& -.match-two))
    ~["qath cell or match fuel failed"]
  ~
++  test-qath-fuel
  ^-  tang
  (turn qath-fuel-errors |=(reason=tape leaf+reason))
--
