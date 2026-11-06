::  A syntactic null can take a determined list or unit context in either
::  direction of an invariant gate fit; other zero-valued literals cannot.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  fit-ok
  |=  [a=itype:jibb b=itype:jibb]
  ^-  ?
  =/  fit=ifit:jibb  (itype-fit:jibb a b ~ 2)
  ?=(%ok -.fit)
++  test-null-constraints
  ^-  tang
  =/  nil=itype:jibb  [%tag 0 [%null %n 0 '~'] |]
  =/  knot=itype:jibb  [%tag 0 [%term %tas 0 '%$'] |]
  =/  yes=itype:jibb  [%tag 0 [%loobean %f 0 '%.y'] |]
  =/  list=itype:jibb  [%collection %list ~[[%atom %ud]]]
  =/  open-list=itype:jibb  [%collection %list ~[[%var 1]]]
  =/  forward=ifit:jibb  (itype-fit:jibb nil list ~ 2)
  ?.  ?=(%ok -.forward)  ~[leaf+"null did not fit a known list"]
  ?.  =((itype-walk:jibb [%var 0] sub.forward) list)
    ~[leaf+"the list context did not bind the null"]
  =/  reverse=ifit:jibb  (itype-fit:jibb list nil ~ 2)
  ?.  ?=(%ok -.reverse)  ~[leaf+"known list did not fix null from the other direction"]
  ?.  =((itype-walk:jibb [%var 0] sub.reverse) list)
    ~[leaf+"reverse list context did not bind the null"]
  ?:  (fit-ok knot list)
    ~[leaf+"%$ was treated as an empty list"]
  ?:  (fit-ok yes list)
    ~[leaf+"%.y was treated as an empty list"]
  ?:  (fit-ok list knot)
    ~[leaf+"a list fixed %$ as a null"]
  ?:  (fit-ok list yes)
    ~[leaf+"a list fixed %.y as a null"]
  =/  open-forward=ifit:jibb  (itype-fit:jibb nil open-list ~ 2)
  ?.  ?=(%ok -.open-forward)  ~[leaf+"known open-list constructor did not fix null"]
  ?.  =((itype-walk:jibb [%var 0] sub.open-forward) open-list)  ~[leaf+"null lost its open list context"]
  ?^  (itype-lookup:jibb 1 sub.open-forward)  ~[leaf+"open-list element was specialized"]
  =/  open-reverse=ifit:jibb  (itype-fit:jibb open-list nil ~ 2)
  ?.  ?=(%ok -.open-reverse)  ~[leaf+"reverse known open-list constructor did not fix null"]
  ?.  =((itype-walk:jibb [%var 0] sub.open-reverse) open-list)  ~[leaf+"reverse null lost its open list context"]
  ?^  (itype-lookup:jibb 1 sub.open-reverse)  ~[leaf+"reverse open-list element was specialized"]
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  unit-template=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit iface.u.prepared)
  ?~  unit-template  ~[leaf+"unit mold is missing"]
  =/  unit-ud=(unit itype:jibb)  (template-apply:jibb u.unit-template ~[[%atom %ud]])
  ?~  unit-ud  ~[leaf+"unit mold did not instantiate"]
  ?.  (fit-ok nil u.unit-ud)
    ~[leaf+"null did not fit a known unit"]
  ?.  (fit-ok u.unit-ud nil)
    ~[leaf+"known unit did not fix null from the other direction"]
  =/  open-unit=(unit itype:jibb)  (template-apply:jibb u.unit-template ~[[%var 1]])
  ?~  open-unit  ~[leaf+"open unit mold did not instantiate"]
  =/  unit-forward=ifit:jibb  (itype-fit:jibb nil u.open-unit ~ 2)
  ?.  ?=(%ok -.unit-forward)  ~[leaf+"known open-unit constructor did not fix null"]
  ?^  (itype-lookup:jibb 1 sub.unit-forward)  ~[leaf+"open-unit element was specialized"]
  =/  unit-reverse=ifit:jibb  (itype-fit:jibb u.open-unit nil ~ 2)
  ?.  ?=(%ok -.unit-reverse)  ~[leaf+"reverse known open-unit constructor did not fix null"]
  ?^  (itype-lookup:jibb 1 sub.unit-reverse)  ~[leaf+"reverse open-unit element was specialized"]
  =/  a=itype:jibb  [%fn [%atom %ud] nil]
  =/  b=itype:jibb  [%fn [%atom %ud] list]
  =/  state=istate:jibb  *istate:jibb
  =/  first-state=istate:jibb  state(queue ~[[%fit a b *span:jibb *span:jibb %$ ~]])
  =/  first=(unit istate:jibb)
    (icore-solve:jibb first-state)
  ?~  first  ~[leaf+"gate fit with null first failed"]
  ?^  queue.u.first  ~[leaf+"gate fit with null first stayed open"]
  =/  second-state=istate:jibb  state(queue ~[[%fit b a *span:jibb *span:jibb %$ ~]])
  =/  second=(unit istate:jibb)
    (icore-solve:jibb second-state)
  ?~  second  ~[leaf+"gate fit with null second failed"]
  ?^  queue.u.second  ~[leaf+"gate fit with null second stayed open"]
  ~
--
