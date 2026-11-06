/+  jibb
|%
++  test-all-alternatives
  ^-  tang
  =/  state=itype:jibb  [%atom %ud]
  =/  action=itype:jibb  [%atom %t]
  =/  plain=itype:jibb  [%fn [%cell action state] state]
  =/  named=itype:jibb  [%fn [%cell [%slot %message action] [%slot %model state]] state]
  =/  alternatives=itype:jibb  [%union ~[plain named] ~ ~ ~]
  =/  main=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined alternatives]]] ~ ~]
  ?.  (store-main-evidence:jibb main action state)  ~[leaf+"compatible gate alternatives were rejected"]
  =/  mixed=itype:jibb  [%union ~[plain [%atom %ud]] ~ ~ ~]
  =.  main  [[%cell [%face %init state] [%face %update [%refined mixed]]] ~ ~]
  ?:  (store-main-evidence:jibb main action state)  ~[leaf+"a non-gate alternative was accepted"]
  =/  wrong=itype:jibb  [%fn [%cell action state] [%atom %t]]
  =/  conflict=itype:jibb  [%union ~[plain wrong] ~ ~ ~]
  =.  main  [[%cell [%face %init state] [%face %update [%refined conflict]]] ~ ~]
  ?:  (store-main-evidence:jibb main action state)  ~[leaf+"a conflicting gate alternative was accepted"]
  =/  empty=itype:jibb  [%union ~ ~ ~ ~]
  =.  main  [[%cell [%face %init state] [%face %update [%refined empty]]] ~ ~]
  ?:  (store-main-evidence:jibb main action state)  ~[leaf+"empty alternatives proved an update"]
  ~
++  test-shared-specialization
  ^-  tang
  =/  state=itype:jibb  [%atom %ud]
  =/  action=itype:jibb  [%atom %t]
  =/  first=itype:jibb  [%fn [%cell [%var 0] state] state]
  =/  second=itype:jibb  [%fn [%cell action state] [%var 0]]
  =/  alternatives=itype:jibb  [%union ~[first second] ~ ~ ~]
  =/  main=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined alternatives]]] ~[0] ~]
  ?:  (store-main-evidence:jibb main action state)  ~[leaf+"inconsistent shared alternatives were accepted"]
  ~
--
