/+  jibb
|%
++  test-unique-selection
  ^-  tang
  =/  add=lit:jibb  [%term %tas %add '%add']
  =/  sub=lit:jibb  [%term %tas %sub '%sub']
  =/  value=itype:jibb  [%cell [%tag 0 add |] [%atom %ud]]
  =/  selected=itype:jibb  [%cell [%const add] [%atom %ud]]
  =/  rival=itype:jibb  [%cell [%const sub] [%atom %ud]]
  =/  target=itype:jibb  [%union ~[rival selected] `[/tests/model/jibb %msg] `'%msg' ~]
  ?.  =((contextual-tagged-case:jibb target %add ~) `selected)  ~[leaf+"distinct known heads did not select their unique case"]
  =/  duplicate=itype:jibb  [%union ~[selected selected] `[/tests/model/jibb %msg] `'%msg' ~]
  ?^  (contextual-tagged-case:jibb duplicate %add ~)  ~[leaf+"same-head cases were selected without payload proof"]
  =/  open=itype:jibb  [%cell [%var 2] [%atom %ud]]
  =/  ambiguous=itype:jibb  [%union ~[selected open] `[/tests/model/jibb %msg] `'%msg' ~]
  ?^  (contextual-tagged-case:jibb ambiguous %add ~)  ~[leaf+"open rival head was ignored"]
  =/  open-tag=itype:jibb  [%cell [%tag 5 sub |] [%atom %ud]]
  =/  ambiguous-tag=itype:jibb  [%union ~[selected open-tag] `[/tests/model/jibb %msg] `'%msg' ~]
  ?^  (contextual-tagged-case:jibb ambiguous-tag %add ~)  ~[leaf+"unresolved rival tag was ignored"]
  =/  broad=itype:jibb  [%union ~[selected [%noun ~]] `[/tests/model/jibb %msg] `'%msg' ~]
  ?^  (contextual-tagged-case:jibb broad %add ~)  ~[leaf+"noun rival was ignored"]
  =/  gate=itype:jibb  [%fn [%atom %t] [%atom %ud]]
  =/  gate-rival=itype:jibb  [%union ~[selected gate] `[/tests/model/jibb %msg] `'%msg' ~]
  ?^  (contextual-tagged-case:jibb gate-rival %add ~)  ~[leaf+"opaque gate rival was ignored"]
  =/  atomic=itype:jibb  [%union ~[[%atom %t] selected] `[/tests/model/jibb %msg] `'%msg' ~]
  ?.  =((contextual-tagged-case:jibb atomic %add ~) `selected)  ~[leaf+"atomic rival was not disjoint from a cell"]
  ~
++  test-queue-preserves-tag
  ^-  tang
  =/  add=lit:jibb  [%term %tas %add '%add']
  =/  sub=lit:jibb  [%term %tas %sub '%sub']
  =/  other=lit:jibb  [%term %tas %other '%other']
  =/  message=itype:jibb  [%union ~[[%const other]] `[/tests/model/jibb %message] `'%message' ~]
  =/  value=itype:jibb  [%cell [%tag 0 add |] [%fn [%slot %now [%atom %da]] [%tag 1 other |]]]
  =/  selected=itype:jibb  [%cell [%const add] [%fn [%atom %da] message]]
  =/  rival=itype:jibb  [%cell [%const sub] [%atom %ud]]
  =/  target=itype:jibb  [%union ~[rival selected] `[/tests/model/jibb %msg] `'%msg' ~]
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  state=istate:jibb  *istate:jibb
  =/  source=expr:jibb  [%tuple site ~[[site ~ [%lit site add]] [site ~ [%crash site ~]]]]
  =.  state  state(next 2, queue ~[[%tag 0 add | site] [%tag 1 other | site] [%tagged-cell value target source site %value ~ ~ ~ ~ ~ ~ 0 ~]])
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  solved  ~[leaf+"unique tagged case did not solve"]
  ?.  ?=(~ queue.u.solved)  ~[leaf+"original tag obligations were not discharged"]
  =/  outer=itype:jibb  (itype-walk:jibb [%tag 0 add |] sub.u.solved)
  ?.  =(outer [%const add])  ~[leaf+"original outer tag was not bound"]
  =/  inner=itype:jibb  (itype-walk:jibb [%tag 1 other |] sub.u.solved)
  ?.  =(inner message)  ~[leaf+"nested tag did not retain the message union"]
  ~
--
