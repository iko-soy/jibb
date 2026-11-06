/+  jibb
|%
++  test-value-face
  ^-  tang
  =/  state=itype:jibb  [%face %count [%atom %ud]]
  =/  action=itype:jibb  [%atom %t]
  =/  gate=itype:jibb  [%fn [%cell action state] state]
  =/  bare=ischeme:jibb  [[%cell state gate] ~ ~]
  ?.  (store-main-evidence:jibb bare action state)  ~[leaf+"one-field state value face was mistaken for the store slot"]
  =/  state-init=itype:jibb  [%face %init [%atom %ud]]
  =/  gate-init=itype:jibb  [%fn [%cell action state-init] state-init]
  =/  same-name=ischeme:jibb  [[%cell state-init gate-init] ~ ~]
  ?.  (store-main-evidence:jibb same-name action state-init)  ~[leaf+"state value named init lost its face"]
  =/  wrong-state=itype:jibb  [%face %other [%atom %ud]]
  =/  wrong-gate=itype:jibb  [%fn [%cell action wrong-state] state]
  =/  wrong-value=ischeme:jibb  [[%cell state wrong-gate] ~ ~]
  ?:  (store-main-evidence:jibb wrong-value action state)  ~[leaf+"different state value face was erased"]
  =/  wrong=ischeme:jibb  [[%cell [%slot %wrong state] [%slot %update gate]] ~ ~]
  ?:  (store-main-evidence:jibb wrong action state)  ~[leaf+"conflicting explicit init slot was accepted"]
  ~
--
