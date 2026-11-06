/+  jibb
|%
++  test-fit-sample
  ^-  tang
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  actual=itype:jibb  [%fn [%cell [%slot %m [%atom %t]] [%slot %state model]] model]
  =/  expected=itype:jibb  [%fn [%cell [%atom %t] model] model]
  =/  result=ifit:jibb  (itype-fit:jibb actual expected ~ 0)
  ?.  ?=(%ok -.result)  ~[leaf+"gate fit did not accept positional binders"]
  ~
++  test-unify-sample
  ^-  tang
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  actual=itype:jibb  [%fn [%cell [%slot %m [%atom %t]] [%slot %state model]] model]
  =/  expected=itype:jibb  [%fn [%cell [%atom %t] model] model]
  ?~  (itype-unify:jibb actual expected ~)  ~[leaf+"gate unifier rejected positional binders"]
  ~
++  test-sample-negative
  ^-  tang
  =/  left=itype:jibb  [%fn [%cell [%slot %m [%atom %t]] [%slot %state [%face %count [%atom %ud]]]] [%atom %ud]]
  =/  right=itype:jibb  [%fn [%cell [%atom %t] [%face %other [%atom %ud]]] [%atom %ud]]
  =/  result=ifit:jibb  (itype-fit:jibb left right ~ 0)
  ?:  ?=(%ok -.result)  ~[leaf+"gate fit discarded a conflicting nested face"]
  ~
++  test-record-gates
  ^-  tang
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  init=itype:jibb  [%fn [%atom %t] model]
  =/  update=itype:jibb  [%fn [%cell [%slot %m [%atom %t]] [%slot %state model]] model]
  =/  wanted=itype:jibb  [%fn [%cell [%atom %t] model] model]
  =/  actual=itype:jibb  [%cell init update]
  =/  expected=itype:jibb  [%cell [%slot %init init] [%slot %update wanted]]
  =/  result=ifit:jibb  (itype-fit:jibb actual expected ~ 0)
  ?.  ?=(%ok -.result)  ~[leaf+"gate-bearing record fit did not accept positional binders"]
  ~

++  test-three-sample-slots
  ^-  tang
  =/  actual=itype:jibb  [%fn [%cell [%slot %a [%atom %t]] [%cell [%slot %b [%atom %p]] [%slot %c [%face %count [%atom %ud]]]]] [%atom %ud]]
  =/  expected=itype:jibb  [%fn [%cell [%atom %t] [%cell [%atom %p] [%face %count [%atom %ud]]]] [%atom %ud]]
  =/  result=ifit:jibb  (itype-fit:jibb actual expected ~ 0)
  ?.  ?=(%ok -.result)  ~[leaf+"three sample binders did not fit their values"]
  ~

++  test-four-field-program
  ^-  tang
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  init=itype:jibb  [%fn [%atom %t] model]
  =/  update=itype:jibb  [%fn [%cell [%slot %m [%atom %t]] [%slot %state model]] model]
  =/  wanted=itype:jibb  [%fn [%cell [%atom %t] model] model]
  =/  view=itype:jibb  [%fn model [%atom %t]]
  =/  subs=itype:jibb  [%fn model [%collection %list ~[[%atom %t]]]]
  =/  actual=itype:jibb  [%cell init [%cell update [%cell view subs]]]
  =/  expected=itype:jibb  [%cell [%slot %init init] [%cell [%slot %update wanted] [%cell [%slot %view view] [%slot %subs subs]]]]
  =/  result=ifit:jibb  (itype-fit:jibb actual expected ~ 0)
  ?.  ?=(%ok -.result)  ~[leaf+"four-field program record did not fit"]
  ~

++  test-nested-sample-record
  ^-  tang
  =/  left-fields=itype:jibb  [%cell [%slot %inner [%atom %p]] [%slot %flag [%atom %ud]]]
  =/  right-fields=itype:jibb  [%cell [%slot %other [%atom %p]] [%slot %flag [%atom %ud]]]
  =/  left=itype:jibb  [%fn [%cell [%slot %a [%atom %t]] [%slot %record left-fields]] [%atom %ud]]
  =/  right=itype:jibb  [%fn [%cell [%atom %t] right-fields] [%atom %ud]]
  =/  result=ifit:jibb  (itype-fit:jibb left right ~ 0)
  ?:  ?=(%ok -.result)  ~[leaf+"nested record field name was discarded"]
  ~

++  test-bound-face-and-capital
  ^-  tang
  =/  atom=itype:jibb  [%atom %ud]
  =/  faced=itype:jibb  [%face %count atom]
  =/  sub=isub:jibb  (itype-bind:jibb 0 faced ~)
  ?~  (itype-unify:jibb [%var 0] faced sub)  ~[leaf+"matching bound value face failed"]
  ?:  ?=(^ (itype-unify:jibb [%var 0] [%face %other atom] sub))  ~[leaf+"conflicting bound value face was accepted"]
  =/  bound=(unit isub:jibb)  (itype-unify:jibb [%var 1] faced ~)
  ?~  bound  ~[leaf+"capital did not fit a faced value"]
  ?.  =((itype-walk:jibb [%var 1] u.bound) atom)  ~[leaf+"capital acquired the value face"]
  ~

--
