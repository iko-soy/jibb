/+  jibb
|%
++  test-flattened-tail
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  lit=lit:jibb  [%term %tas %yes '%yes']
  =/  other=lit:jibb  [%term %tas %no '%no']
  =/  msg=itype:jibb  [%union ~[[%const lit] [%const other]] `[/ui/probe/jibb %msg] ~ ~]
  =/  tag=itype:jibb  [%tag 1 lit |]
  =/  left=itype:jibb  [%cell [%atom %ud] [%var 0]]
  =/  right=itype:jibb  [%cell [%atom %ud] [%cell msg [%atom %t]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state
    state(general-defer &, next 2, sub (itype-bind:jibb 0 [%cell tag [%atom %t]] ~), queue ~[[%tag 1 lit | site] [%fit left right site site %$ ~]])
  =/  longer=itype:jibb  [%cell [%atom %ud] [%cell msg [%cell [%atom %t] [%atom %ud]]]]
  ?^  (icore-fit-parts:jibb left longer sub.state site site %$ ~)
    ~[leaf+"different flattened tuple lengths were decomposed"]
  ?^  (icore-fit-parts:jibb longer left sub.state site site %$ ~)
    ~[leaf+"reverse different flattened tuple lengths were decomposed"]
  =/  result=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  result  ~[leaf+"equivalent flattened tuple fit was rejected"]
  ?^  queue.u.result  ~[leaf+"equivalent flattened tuple fit remained open"]
  ?.  =(msg (itype-walk:jibb tag sub.u.result))  ~[leaf+"flattened tuple did not supply tag context"]
  =/  reverse=istate:jibb  state(queue ~[[%tag 1 lit | site] [%fit right left site site %$ ~]])
  =/  back=(unit istate:jibb)  (icore-solve:jibb reverse)
  ?~  back  ~[leaf+"reverse flattened tuple fit was rejected"]
  ?^  queue.u.back  ~[leaf+"reverse flattened tuple fit remained open"]
  ?.  =(msg (itype-walk:jibb tag sub.u.back))  ~[leaf+"reverse flattened tuple lost tag context"]
  ~
++  test-one-value-tail
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  lit=lit:jibb  [%term %tas %yes '%yes']
  =/  other=lit:jibb  [%term %tas %no '%no']
  =/  msg=itype:jibb  [%union ~[[%const lit] [%const other]] `[/ui/probe/jibb %msg] ~ ~]
  =/  tag=itype:jibb  [%tag 1 lit |]
  =/  left=itype:jibb  [%cell [%atom %ud] [%var 0]]
  =/  right=itype:jibb  [%cell [%face %x [%atom %ud]] [%face %model [%cell msg [%atom %t]]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state
    state(general-defer &, next 2, sub (itype-bind:jibb 0 [%cell tag [%atom %t]] ~), queue ~[[%tag 1 lit | site] [%fit left right site site %$ ~]])
  =/  result=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  result  ~[leaf+"single model-value fit was rejected"]
  ?^  queue.u.result  ~[leaf+"single model-value fit remained open"]
  ?.  =(msg (itype-walk:jibb tag sub.u.result))  ~[leaf+"single model-value lost tag context"]
  =/  reverse=istate:jibb  state(queue ~[[%tag 1 lit | site] [%fit right left site site %$ ~]])
  =/  back=(unit istate:jibb)  (icore-solve:jibb reverse)
  ?~  back  ~[leaf+"reverse single model-value fit was rejected"]
  ?^  queue.u.back  ~[leaf+"reverse single model-value fit remained open"]
  ?.  =(msg (itype-walk:jibb tag sub.u.back))  ~[leaf+"reverse single model-value lost tag context"]
  ~
--
