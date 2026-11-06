/+  jibb
|%
++  test-generic-evidence
  ^-  tang
  =/  state=itype:jibb  [%atom %ud]
  =/  action=itype:jibb  [%atom %t]
  =/  generic=itype:jibb  [%fn [%cell [%var 0] state] state]
  =/  main=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined generic]]] ~[0] ~]
  =/  specialized=(unit ischeme:jibb)  (store-main-specialize:jibb main action state)
  ?~  specialized  ~[leaf+"generic update did not specialize"]
  ?.  ?=(~ vars.u.specialized)  ~[leaf+"generic update remained open"]
  =/  updates=(list itype:jibb)  (record-fields-named:jibb %update typ.u.specialized ~)
  =/  expected=itype:jibb  [%refined [%fn [%cell action state] state]]
  ?.  =(updates ~[expected])  ~[leaf+"specialized update has wrong action or state"]
  =/  wrong=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined [%fn [%cell [%var 0] state] [%var 0]]]]] ~[0] ~]
  ?^  (store-main-specialize:jibb wrong action state)  ~[leaf+"inconsistent shared update variable was accepted"]
  ~
--
