/+  jibb
|%
++  test-guarded-fit-capital
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  arg-site=span:jibb  [[4 12] [4 13]]
  =/  target-site=span:jibb  [[3 5] [3 7]]
  =/  forcing=expr:jibb  [%wing arg-site ~[%x]]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  edge=icore-edge:jibb  [%guarded-fit [%var 0] [%atom %t] arg-site target-site %bad ~ caps forcing | ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 2, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"guarded fit declined"]
  ?~  core-error.u.out  ~[leaf+"guarded fit specialized a written capital"]
  =/  error=idiag:jibb  diag.u.core-error.u.out
  ?.  =(owner.u.core-error.u.out %bad)  ~[leaf+"wrong owner"]
  ?.  =(msg.error "capital `M` cannot be fixed to @t")  ~[leaf+"wrong capital diagnostic"]
  ?.  =(sites.error ~[[cap-site "capital"] [arg-site "forcing expression"]])  ~[leaf+"wrong capital sites"]
  ~
++  test-guarded-fit-unrelated
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  arg-site=span:jibb  [[4 12] [4 13]]
  =/  forcing=expr:jibb  [%wing arg-site ~[%x]]
  =/  caps=icaps:jibb  ~[['M' 1 cap-site]]
  =/  edge=icore-edge:jibb  [%guarded-fit [%var 0] [%atom %t] arg-site cap-site %ok ~ caps forcing | ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 2, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"unrelated fit declined"]
  ?^  core-error.u.out  ~[leaf+"unrelated capital was rejected"]
  ?^  queue.u.out  ~[leaf+"concrete fit remained queued"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.out) [%atom %t])  ~[leaf+"fit did not bind argument"]
  ?.  =((itype-walk:jibb [%var 1] sub.u.out) [%var 1])  ~[leaf+"unrelated capital changed"]
  ~
++  test-guarded-fit-decomposed
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  arg-site=span:jibb  [[4 12] [4 13]]
  =/  forcing=expr:jibb  [%wing arg-site ~[%x]]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  tag=itype:jibb  [%tag 2 [%term %tas %hit '%hit'] |]
  =/  left=itype:jibb  [%cell [%var 0] tag]
  =/  right=itype:jibb  [%cell [%atom %t] [%var 1]]
  =/  edge=icore-edge:jibb  [%guarded-fit left right arg-site cap-site %bad ~ caps forcing | ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 3, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"decomposed fit declined"]
  ?~  core-error.u.out  ~[leaf+"decomposed fit specialized a written capital"]
  =/  error=idiag:jibb  diag.u.core-error.u.out
  ?.  =(msg.error "capital `M` cannot be fixed to @t")  ~[leaf+"decomposed fit lost capital diagnostic"]
  ?.  =(sites.error ~[[cap-site "capital"] [arg-site "forcing expression"]])  ~[leaf+"decomposed fit lost sites"]
  ~
++  test-guarded-fit-numeric
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  arg-site=span:jibb  [[4 12] [4 13]]
  =/  forcing=expr:jibb  [%lit arg-site [%number %ud 1 '1']]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  edge=icore-edge:jibb  [%guarded-fit [%var 0] [%nvar 1] arg-site cap-site %generic ~ caps forcing & ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 2, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"numeric argument declined"]
  ?^  core-error.u.out  ~[leaf+"numeric-only argument fixed its capital"]
  =/  typ=itype:jibb  (itype-walk:jibb [%var 0] sub.u.out)
  ?.  ?=(?(%nvar %rnvar %var %rvar) -.typ)  ~[leaf+"numeric capital became concrete"]
  ~
++  test-guarded-positional-tail
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  first=span:jibb  [[4 11] [4 18]]
  =/  second=span:jibb  [[4 19] [4 20]]
  =/  head=expr:jibb  [%wing [[4 3] [4 9]] ~[%expects]]
  =/  pending=expr:jibb  [%wing first ~[%pending]]
  =/  actual=expr:jibb  [%wing second ~[%x]]
  =/  forcing=expr:jibb  [%call [[4 2] [4 21]] head ~[pending actual]]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  tag=itype:jibb  [%tag 2 [%term %tas %hit '%hit'] |]
  =/  literal=lit:jibb  [%term %tas %base '%base']
  =/  union-open=itype:jibb  [%union ~[[%const literal]] `[/ui/sample/jibb %choice] ~ ~[tag]]
  =/  msg=itype:jibb  [%union ~[[%const [%term %tas %hit '%hit']]] `[/ui/sample/jibb %msg] ~ ~]
  =/  union-target=itype:jibb  [%union ~[[%const literal]] `[/ui/sample/jibb %choice] ~ ~[msg]]
  =/  left=itype:jibb  [%cell union-open [%var 0]]
  =/  right=itype:jibb  [%cell union-target [%atom %t]]
  =/  edge=icore-edge:jibb  [%guarded-fit left right first cap-site %bad ~[first second] caps forcing & ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 4, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"positional fit declined"]
  ?~  core-error.u.out  ~[leaf+"positional tail specialized a capital"]
  =/  error=idiag:jibb  diag.u.core-error.u.out
  ?.  =(msg.error "capital `M` cannot be fixed to @t")  ~[leaf+"positional fit lost capital diagnostic"]
  ?.  =(sites.error ~[[cap-site "capital"] [second "forcing expression"]])  ~[leaf+"positional fit lost second argument site"]
  ~
++  test-guarded-positional-empty
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  first=span:jibb  [[4 11] [4 18]]
  =/  second=span:jibb  [[4 19] [4 20]]
  =/  head=expr:jibb  [%wing [[4 3] [4 9]] ~[%expects]]
  =/  forcing=expr:jibb  [%call [[4 2] [4 21]] head ~[[%crash first ~] [%wing second ~[%x]]]]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  left=itype:jibb  [%cell [%empty ~] [%var 0]]
  =/  right=itype:jibb  [%cell [%atom %p] [%atom %t]]
  =/  edge=icore-edge:jibb  [%guarded-fit left right first cap-site %safe ~[first second] caps forcing & ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 1, queue ~[edge])
  =/  out=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  out  ~[leaf+"empty positional fit declined"]
  ?^  core-error.u.out  ~[leaf+"empty positional fit forced its unreachable tail"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.out) [%var 0])  ~[leaf+"empty positional fit constrained a capital"]
  ~
++  test-guarded-positional-open
  ^-  tang
  =/  cap-site=span:jibb  [[2 8] [2 9]]
  =/  first=span:jibb  [[4 11] [4 18]]
  =/  second=span:jibb  [[4 19] [4 20]]
  =/  head=expr:jibb  [%wing [[4 3] [4 9]] ~[%expects]]
  =/  forcing=expr:jibb  [%call [[4 2] [4 21]] head ~[[%wing first ~[%unknown]] [%wing second ~[%x]]]]
  =/  caps=icaps:jibb  ~[['M' 0 cap-site]]
  =/  left=itype:jibb  [%cell [%var 1] [%var 0]]
  =/  right=itype:jibb  [%cell [%atom %p] [%atom %t]]
  =/  edge=icore-edge:jibb  [%guarded-fit left right first cap-site %safe ~[first second] caps forcing & ~ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 2, queue ~[edge])
  =/  parts=(unit (list icore-edge:jibb))
    (icore-positional-fit-parts:jibb left right ~[first second] sub.state cap-site %safe caps)
  ?^  parts  ~[leaf+"open positional fit was split without an inhabitance proof"]
  ~
--
