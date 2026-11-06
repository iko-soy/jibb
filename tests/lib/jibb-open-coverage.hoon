/+  jibb
|%
++  test-late-dead-arm
  ^-  tang
  =/  site=span:jibb  *span:jibb
  =/  subject=itype:jibb  [%cell [%var 0] [%atom %ud]]
  =/  pat=pattern:jibb  [%cell site ~[[%any site ~] [%any site ~]]]
  =/  branch=expr:jibb  [%branch site [%wing site ~[%x]] ~[[site pat [%crash site ~]]]]
  =/  edge=icore-edge:jibb  [%coverage subject branch site %probe]
  =/  start=istate:jibb  *istate:jibb
  =.  start  start(next 1, general-defer &, queue ~[edge])
  =/  open=(unit istate:jibb)  (icore-solve:jibb start)
  ?~  open  ~[leaf+"open coverage did not wait"]
  ?~  queue.u.open  ~[leaf+"open coverage was discarded"]
  ?^  core-error.u.open  ~[leaf+"open coverage diagnosed prematurely"]
  =/  closed=istate:jibb  u.open(sub (itype-bind:jibb 0 [%empty ~] sub.u.open))
  =/  checked=(unit istate:jibb)  (icore-solve:jibb closed)
  ?~  checked  ~[leaf+"late coverage check failed without a diagnostic"]
  ?~  core-error.u.checked  ~[leaf+"late unreachable arm was accepted"]
  ~
++  test-late-invalid-literal
  ^-  tang
  =/  site=span:jibb  *span:jibb
  =/  subject=itype:jibb  [%cell [%var 0] [%atom %ud]]
  =/  literal=lit:jibb  [%term %tas %go '%go']
  =/  first=pattern:jibb  [%cell site ~[[%lit site literal] [%any site ~]]]
  =/  fallback=pattern:jibb  [%cell site ~[[%any site ~] [%any site ~]]]
  =/  branch=expr:jibb  [%branch site [%wing site ~[%x]] ~[[site first [%crash site ~]] [site fallback [%crash site ~]]]]
  =/  edge=icore-edge:jibb  [%coverage subject branch site %probe]
  =/  start=istate:jibb  *istate:jibb
  =.  start  start(next 1, general-defer &, queue ~[edge])
  =/  open=(unit istate:jibb)  (icore-solve:jibb start)
  ?~  open  ~[leaf+"open literal coverage did not wait"]
  ?^  core-error.u.open  ~[leaf+"open literal was rejected before its aura was known"]
  =/  closed=istate:jibb  u.open(sub (itype-bind:jibb 0 [%atom %ud] sub.u.open))
  =/  indexed=(unit istate:jibb)  (icore-solve:jibb closed)
  =/  full=(unit istate:jibb)  (icore-solve-full:jibb closed(wake ~))
  ?~  indexed  ~[leaf+"indexed coverage did not report an error"]
  ?~  full  ~[leaf+"full coverage did not report an error"]
  ?~  core-error.u.indexed  ~[leaf+"incompatible pattern was accepted after aura resolution"]
  ?.  =(core-error.u.indexed core-error.u.full)  ~[leaf+"indexed and full coverage disagree"]
  ~
++  test-open-pattern-safety
  ^-  tang
  =/  site=span:jibb  *span:jibb
  =/  subject=itype:jibb  [%cell [%var 0] [%atom %ud]]
  =/  literal=lit:jibb  [%term %tas %go '%go']
  =/  safe=pattern:jibb  [%cell site ~[[%bind site %x] [%any site ~]]]
  =/  unknown-tag=pattern:jibb  [%cell site ~[[%lit site literal] [%any site ~]]]
  =/  unknown-cell=pattern:jibb  [%cell site ~[[%cell site ~[[%any site ~] [%any site ~]]] [%any site ~]]]
  ?.  (coverage-open-safe:jibb safe subject ~ 128)  ~[leaf+"known record binder was not safe"]
  ?:  (coverage-open-safe:jibb unknown-tag subject ~ 128)  ~[leaf+"unknown tag position was guessed"]
  ?:  (coverage-open-safe:jibb unknown-cell subject ~ 128)  ~[leaf+"unknown cell position was guessed"]
  ~
++  test-final-coverage
  ^-  tang
  =/  site=span:jibb  *span:jibb
  =/  subject=itype:jibb  [%cell [%var 0] [%atom %ud]]
  =/  pat=pattern:jibb  [%cell site ~[[%any site ~] [%any site ~]]]
  =/  branch=expr:jibb  [%branch site [%wing site ~[%x]] ~[[site pat [%crash site ~]]]]
  =/  edge=icore-edge:jibb  [%coverage subject branch site %probe]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 1, queue ~[edge])
  =/  final=(unit istate:jibb)  (icore-final-coverage:jibb queue.state state)
  ?~  final  ~[leaf+"generic exhaustive coverage did not close"]
  ?^  queue.u.final  ~[leaf+"final coverage left an obligation"]
  =/  fit=icore-edge:jibb  [%fit [%var 0] [%atom %ud] site site %probe ~]
  ?^  (icore-final-coverage:jibb ~[edge fit] state)  ~[leaf+"coverage hid an unresolved fit"]
  ~
--
