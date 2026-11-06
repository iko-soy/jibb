/+  jibb
|%
++  test-queued-constructor-identity
  ^-  tang
  =/  at=span:jibb  [[1 1] [1 8]]
  =/  other-at=span:jibb  [[2 1] [2 8]]
  =/  head=expr:jibb  [%lit at [%term %tas %pad '%pad']]
  =/  value=expr:jibb  [%lit at [%term %tas %s4 '%s4']]
  =/  source=expr:jibb  [%tuple at ~[[at ~ head] [at ~ value]]]
  =/  actual=itype:jibb  [%cell [%tag 0 [%term %tas %pad '%pad'] |] [%tag 1 [%term %tas %s4 '%s4'] |]]
  =/  result=itype:jibb  [%var 2]
  =/  edge=icore-edge:jibb  [%tagged-cell actual result source at %owner ~ ~ ~ ~ ~ ~ 0 ~]
  ?>  ?=(%tagged-cell -.edge)
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(owner %owner, queue ~[edge])
  ?.  =((contextual-tagged-value:jibb source result state) `actual)  ~[leaf+"matching queued constructor was not found"]
  ?^  (contextual-tagged-value:jibb source result state(owner %other))  ~[leaf+"foreign owner supplied a constructor"]
  ?^  (contextual-tagged-value:jibb source [%var 3] state)  ~[leaf+"unrelated result root supplied a constructor"]
  ?^  (contextual-tagged-value:jibb source result state(queue ~[edge(at other-at)]))  ~[leaf+"different source span supplied a constructor"]
  =/  other-source=expr:jibb  [%lit at [%term %tas %other '%other']]
  ?^  (contextual-tagged-value:jibb source result state(queue ~[edge(source other-source)]))  ~[leaf+"different source expression supplied a constructor"]
  ?^  (contextual-tagged-value:jibb source result state(queue ~[edge edge]))  ~[leaf+"ambiguous queued constructors were accepted"]
  ~
--
