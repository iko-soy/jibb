::  Generic slots bind below faces; joining positions retains faces.
/+  jibb
|%
++  test-face-rulings
  ^-  tang
  =/  atom=itype:jibb  [%atom %t]
  =/  x=itype:jibb  [%face %x atom]
  =/  y=itype:jibb  [%face %y atom]
  =/  record=itype:jibb  [%cell x y]
  =/  generic=itype:jibb  [%cell [%var 0] [%var 0]]
  =/  fitted=ifit:jibb  (itype-fit:jibb record generic ~ 1)
  ?.  ?=(%ok -.fitted)  ~[leaf+"repeated generic did not fit faced positions"]
  ?.  =((itype-walk:jibb [%var 0] sub.fitted) atom)
    ~[leaf+"generic captured a face"]
  =/  x-slot=itype:jibb  [%slot %x atom]
  ?:  (itype-face-asym:jibb [%var 0] x-slot sub.fitted)
    ~[leaf+"a bound generic on the left became slot-asymmetric"]
  ?.  (itype-face-asym:jibb [%var 0] x sub.fitted)
    ~[leaf+"a bound generic discarded a value face"]
  ?:  (itype-face-asym:jibb x [%var 0] sub.fitted)
    ~[leaf+"a bound generic on the right became face-asymmetric"]
  =/  left-fit=ifit:jibb  (itype-fit:jibb [%var 0] x-slot sub.fitted 1)
  ?.  ?=(%ok -.left-fit)  ~[leaf+"a bound generic on the left did not fit a slot"]
  =/  right-fit=ifit:jibb  (itype-fit:jibb x [%var 0] sub.fitted 1)
  ?.  ?=(%ok -.right-fit)  ~[leaf+"a bound generic on the right did not fit a face"]
  =/  unified=(unit isub:jibb)  (itype-unify:jibb generic record ~)
  ?~  unified  ~[leaf+"generic did not unify with faced positions"]
  ?.  =((itype-walk:jibb [%var 0] u.unified) atom)
    ~[leaf+"unification captured a face"]
  =/  reversed=(unit isub:jibb)  (itype-unify:jibb record generic ~)
  ?~  reversed  ~[leaf+"reversed generic did not unify with faced positions"]
  ?.  =((itype-walk:jibb [%var 0] u.reversed) atom)
    ~[leaf+"reversed unification captured a face"]
  =/  left=(unit [typ=itype:jibb sub=isub:jibb])
    (itype-branch-join-list:jibb ~[atom x] ~)
  =/  right=(unit [typ=itype:jibb sub=isub:jibb])
    (itype-branch-join-list:jibb ~[x atom] ~)
  ?.  =(left `[x ~])  ~[leaf+"join lost the later face"]
  ?.  =(right `[x ~])  ~[leaf+"join lost the earlier face"]
  =/  nested=(unit [typ=itype:jibb sub=isub:jibb])
    (itype-branch-join-list:jibb ~[[%cell atom atom] record] ~)
  ?.  =(nested `[record ~])  ~[leaf+"join lost faces within a cell"]
  ?^  (itype-branch-join:jibb x y ~)  ~[leaf+"different explicit faces joined"]
  ~
--
