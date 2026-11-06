/+  jibb
|%
++  test-evidence
  ^-  tang
  =/  state=itype:jibb  [%atom %ud]
  =/  action=itype:jibb  [%atom %t]
  =/  gate=itype:jibb  [%fn [%cell action state] state]
  =/  main=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined gate]]] ~ ~]
  ?.  (store-main-evidence:jibb main action state)  ~[leaf+"valid retained update gate was rejected"]
  =/  raw=ischeme:jibb  [[%cell [%face %init state] [%face %update gate]] ~ ~]
  ?.  (store-main-evidence:jibb raw action state)  ~[leaf+"valid hand-built gate was rejected"]
  =/  bare=ischeme:jibb  [[%cell state gate] ~ ~]
  ?.  (store-main-evidence:jibb bare action state)  ~[leaf+"unfaced checked store was rejected"]
  =/  mislabeled=ischeme:jibb  [[%cell [%face %wrong state] [%face %update gate]] ~ ~]
  ?:  (store-main-evidence:jibb mislabeled action state)  ~[leaf+"conflicting record face was accepted"]
  =/  longer=itype:jibb  [%cell [%face %init state] [%cell [%face %update gate] [%face %view gate]]]
  ?^  (store-value-parts:jibb longer)  ~[leaf+"a longer record was classified as a store"]
  =/  unknown=ischeme:jibb  [[%cell [%face %init state] [%face %update [%noun ~]]] ~ ~]
  ?:  (store-main-evidence:jibb unknown action state)  ~[leaf+"unknown update was accepted"]
  =/  malformed=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined [%atom %ud]]]] ~ ~]
  ?:  (store-main-evidence:jibb malformed action state)  ~[leaf+"non-gate update was accepted"]
  =/  bad-result=itype:jibb  [%fn [%cell action state] [%atom %t]]
  =/  wrong=ischeme:jibb  [[%cell [%face %init state] [%face %update [%refined bad-result]]] ~ ~]
  ?:  (store-main-evidence:jibb wrong action state)  ~[leaf+"wrong update result was accepted"]
  ~
--
