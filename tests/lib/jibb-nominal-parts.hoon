/+  jibb
|%
++  test-nominal-parts
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  literal=lit:jibb  [%term %tas %submit '%submit']
  =/  other=lit:jibb  [%term %tas %other '%other']
  =/  msg=itype:jibb  [%union ~[[%const literal] [%const other]] `[/ui/probe/jibb %msg] ~ ~]
  =/  tag=itype:jibb  [%tag 0 literal |]
  =/  key=gkey:jibb  [/ui/probe/jibb site %element]
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) key [site & ~['A'] ~ [%union ~[[%const [%term %tas %end '%end']] [%cell [%const [%term %tas %next '%next']] [%ref key ~[[%param 'A']]]]]]])
  ?.  (rg-certify:jibb [%ref key ~[[%param 'A']]] graph)  ~[leaf+"recursive nominal test mold is not valid"]
  =/  open=itype:jibb  [%mrec /ui/probe/jibb site %element ~ graph ~[tag]]
  =/  target=itype:jibb  [%mrec /ui/probe/jibb site %element ~ graph ~[msg]]
  =/  list-open=itype:jibb  [%collection %list ~[open]]
  =/  list-target=itype:jibb  [%collection %list ~[target]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 1, queue ~[[%tag 0 literal | site] [%fit list-open list-target site site %$ ~]])
  =/  result=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  result  ~[leaf+"nested nominal fit was rejected"]
  ?^  queue.u.result  ~[leaf+"nested nominal tag did not resolve"]
  ?.  =((itype-walk:jibb tag sub.u.result) msg)  ~[leaf+"tag did not retain its named union"]
  =/  swapped=istate:jibb  state(queue ~[[%tag 0 literal | site] [%fit list-target list-open site site %$ ~]])
  =/  reversed=(unit istate:jibb)  (icore-solve:jibb swapped)
  ?~  reversed  ~[leaf+"reversed nominal fit was rejected"]
  ?^  queue.u.reversed  ~[leaf+"reversed nominal tag did not resolve"]
  ?.  =((itype-walk:jibb tag sub.u.reversed) msg)  ~[leaf+"reversed tag lost its union"]
  ::  Different open tags need a later common union, not a premature error.
  =/  other-tag=itype:jibb  [%tag 1 other |]
  =/  later=itype:jibb  [%mrec /ui/probe/jibb site %element ~ graph ~[other-tag]]
  =/  pending=istate:jibb
    state(next 2, queue ~[[%fit open later site site %$ ~] [%fit tag msg site site %$ ~] [%fit other-tag msg site site %$ ~]])
  =/  completed=(unit istate:jibb)  (icore-solve:jibb pending)
  ?~  completed  ~[leaf+"two open tags could not wait for their union"]
  ?^  queue.u.completed  ~[leaf+"two tags did not resolve after their common union"]
  ?.  &(=(msg (itype-walk:jibb tag sub.u.completed)) =(msg (itype-walk:jibb other-tag sub.u.completed)))
    ~[leaf+"tag constraints did not retain the common union"]
  ::  Imported/source-proven named unions carry their parameters the same way.
  =/  union-open=itype:jibb  [%union ~[[%cell [%const other] tag]] `[/ui/probe/jibb %element] `%element ~[tag]]
  =/  union-target=itype:jibb  [%union ~[[%cell [%const other] msg]] `[/ui/probe/jibb %element] `%element ~[msg]]
  =/  union-state=istate:jibb
    state(queue ~[[%tag 0 literal | site] [%fit union-open union-target site site %$ ~]])
  =/  union-result=(unit istate:jibb)  (icore-solve:jibb union-state)
  ?~  union-result  ~[leaf+"named union argument fit was rejected"]
  ?^  queue.u.union-result  ~[leaf+"named union argument did not resolve"]
  ?.  =((itype-walk:jibb tag sub.u.union-result) msg)  ~[leaf+"named union argument lost its context"]
  =/  foreign-key=gkey:jibb  [/ui/foreign/jibb site %element]
  =/  foreign-graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) foreign-key [site & ~['A'] ~ [%union ~[[%const [%term %tas %end '%end']] [%cell [%const [%term %tas %next '%next']] [%ref foreign-key ~[[%param 'A']]]]]]])
  =/  foreign=itype:jibb  [%mrec /ui/foreign/jibb site %element ~ foreign-graph ~[msg]]
  ?^  (icore-fit-parts:jibb open foreign ~ site site %$ ~)  ~[leaf+"distinct nominal origins were decomposed"]
  =/  faced=itype:jibb  [%collection %list ~[[%face %field [%atom %t]]]]
  =/  unfaced=itype:jibb  [%collection %list ~[[%atom %t]]]
  ?^  (icore-fit-parts:jibb faced unfaced ~ site site %$ ~)  ~[leaf+"a value face could be lost through nominal decomposition"]
  =/  atoms=istate:jibb
    state(queue ~[[%fit [%collection %list ~[[%atom %t]]] [%collection %list ~[[%atom %ud]]] site site %$ ~]])
  =/  solved=(unit istate:jibb)  (icore-solve:jibb atoms)
  ?~  solved  ~
  ?~  core-error.u.solved  ~[leaf+"incompatible nominal arguments were accepted"]
  ~
--
