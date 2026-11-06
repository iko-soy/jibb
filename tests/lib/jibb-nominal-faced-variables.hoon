/+  jibb
|%
++  test-nominal-faced-variables
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  literal=lit:jibb  [%term %tas %submit '%submit']
  =/  other=lit:jibb  [%term %tas %other '%other']
  =/  msg=itype:jibb  [%union ~[[%const literal] [%const other]] `[/ui/probe/jibb %msg] ~ ~]
  =/  tag=itype:jibb  [%tag 1 literal |]
  =/  unfaced=itype:jibb  [%cell [%atom %ud] tag]
  =/  faced=itype:jibb  [%cell [%face %key [%atom %ud]] [%face %el msg]]
  =/  source=itype:jibb  [%collection %list ~[[%var 0]]]
  =/  target=itype:jibb  [%collection %list ~[faced]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 2, sub (itype-bind:jibb 0 unfaced ~), queue ~[[%tag 1 literal | site] [%fit source target site site %$ ~]])
  =/  result=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  result  ~[leaf+"rooted nominal fit was rejected"]
  ?^  queue.u.result  ~[leaf+"rooted nominal fit did not close"]
  ?.  =((itype-normalize:jibb [%var 0] sub.u.result) faced)  ~[leaf+"nominal fit lost its joined faces"]
  =/  reversed=istate:jibb  state(queue ~[[%tag 1 literal | site] [%fit target source site site %$ ~]])
  =/  back=(unit istate:jibb)  (icore-solve:jibb reversed)
  ?~  back  ~[leaf+"reversed rooted nominal fit was rejected"]
  ?^  queue.u.back  ~[leaf+"reversed rooted nominal fit did not close"]
  ?.  =((itype-normalize:jibb [%var 0] sub.u.back) faced)  ~[leaf+"reversed nominal fit lost its joined faces"]
  ::  A capital in a faced target position binds the underlying value only.
  =/  capital=itype:jibb  [%cell [%face %key [%var 2]] [%face %el msg]]
  =/  capital-target=itype:jibb  [%collection %list ~[capital]]
  =/  capital-state=istate:jibb
    state(next 3, queue ~[[%tag 1 literal | site] [%fit source capital-target site site %$ ~]])
  =/  capital-result=(unit istate:jibb)  (icore-solve:jibb capital-state)
  ?~  capital-result  ~[leaf+"capital in faced nominal target was rejected"]
  ?^  queue.u.capital-result  ~[leaf+"capital in faced nominal target did not close"]
  ?.  =((itype-normalize:jibb [%var 2] sub.u.capital-result) [%atom %ud])
    ~[leaf+"capital captured the target position face"]
  ?.  =((itype-normalize:jibb [%var 0] sub.u.capital-result) faced)
    ~[leaf+"capital fit lost the containing value faces"]
  =/  wrong=itype:jibb  [%collection %list ~[[%cell [%face %wrong [%atom %ud]] [%face %el msg]]]]
  ?^  (icore-fit-parts:jibb target wrong ~ site site %$ ~)  ~[leaf+"different faces were decomposed"]
  =/  wrong-root=isub:jibb  (itype-bind:jibb 0 [%cell [%face %wrong [%atom %ud]] [%face %el msg]] ~)
  ?^  (icore-fit-parts:jibb source target wrong-root site site %$ ~)  ~[leaf+"a rooted pair with a conflicting face was decomposed"]
  ::  A top-level face cannot be retained by the cell-root join.
  =/  top-face=itype:jibb  [%collection %list ~[[%face %whole faced]]]
  ?^  (icore-fit-parts:jibb source top-face sub.state site site %$ ~)
    ~[leaf+"top-level face was decomposed without a preserving join"]
  ?^  (icore-fit-parts:jibb top-face source sub.state site site %$ ~)
    ~[leaf+"reversed top-level face was decomposed without a preserving join"]
  =/  no-root=itype:jibb  [%collection %list ~[unfaced]]
  ?^  (icore-fit-parts:jibb no-root target ~ site site %$ ~)  ~[leaf+"unrooted face loss was permitted"]
  ~
--
