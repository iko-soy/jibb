/+  jibb
|%
++  test-closed-list-defer
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  item=expr:jibb  [%wing site ~[%x]]
  =/  source=itype:jibb  [%union ~[[%atom %t]] ~ ~ ~]
  =/  target=itype:jibb  [%union ~[[%atom %ud]] ~ ~ ~]
  =/  env=ienv:jibb  ~[[%x [source ~ ~]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &)
  =/  result=iresult:jibb  (infer-list-items:jibb ~[item] target env state site)
  ?:  ?=(%| -.result)  ~[leaf+"an unknown list fit did not defer"]
  ?.  ?=([[%guarded-fit *] ~] queue.state.p.result)  ~[leaf+"the list item obligation was not queued with its source"]
  =/  pending=icore-edge:jibb  i.queue.state.p.result
  ?>  ?=(%guarded-fit -.pending)
  ?~  ancestors.pending  ~[leaf+"the list item lost its root provenance"]
  =/  root=ifit-ancestor:jibb  (rear ancestors.pending)
  ?~  list-item.root  ~[leaf+"the list item marker is missing"]
  =/  marker  u.list-item.root
  ?.  =(source.marker item)  ~[leaf+"the wrong source expression was retained"]
  =/  still=(unit istate:jibb)  (icore-solve:jibb state.p.result)
  ?~  still  ~[leaf+"the unresolved fit was discarded"]
  ?~  queue.u.still  ~[leaf+"the unresolved fit was accepted"]
  =/  bad-env=ienv:jibb  ~[[%x [[%atom %t] ~ ~]]]
  =/  bad=iresult:jibb  (infer-list-items:jibb ~[item] [%atom %ud] bad-env state site)
  ?:  ?=(%& -.bad)  ~[leaf+"a definite list item mismatch was deferred"]
  ?.  =(msg.p.bad "list item does not fit its expected type")  ~[leaf+"the definite list diagnostic changed"]
  =/  legacy=iresult:jibb  (infer-list-items:jibb ~[item] target env state(general-defer |) site)
  ?:  ?=(%& -.legacy)  ~[leaf+"legacy inference guessed an unknown list fit"]
  ~
++  test-open-tag-fit
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  a=lit:jibb  [%term %tas %add '%add']
  =/  b=lit:jibb  [%term %tas %clear '%clear']
  =/  left=itype:jibb  [%tag 0 a |]
  =/  right=itype:jibb  [%tag 1 b |]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 2, queue ~[[%fit left right site site %view ~]])
  =/  pending=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  pending  ~[leaf+"open tag fit caused the solver to fail"]
  ?~  queue.u.pending  ~[leaf+"open tag fit was accepted without context"]
  =/  message=itype:jibb  [%union ~[[%const a] [%const b]] `[/ui/example/jibb %msg] `'msg' ~]
  =/  fit-left=ifit:jibb  (itype-fit:jibb left message sub.u.pending next.u.pending)
  ?.  ?=(%ok -.fit-left)  ~[leaf+"first tag did not fit later union"]
  =/  fit-right=ifit:jibb  (itype-fit:jibb right message sub.fit-left next.fit-left)
  ?.  ?=(%ok -.fit-right)  ~[leaf+"second tag did not fit later union"]
  =/  done=(unit istate:jibb)  (icore-solve:jibb u.pending(sub sub.fit-right, next next.fit-right))
  ?~  done  ~[leaf+"the common union did not resolve the pending fit"]
  ?^  core-error.u.done  ~[leaf+"the common union produced a conflict"]
  ?^  queue.u.done  ~[leaf+"the common union left the fit pending"]
  =/  conflict=istate:jibb  state(queue ~[[%fit [%atom %t] [%atom %ud] site site %view ~]])
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb conflict)
  ?~  rejected  ~[leaf+"closed mismatch did not retain a diagnostic"]
  ?~  core-error.u.rejected  ~[leaf+"closed mismatch was left unresolved or accepted"]
  =/  wrong=istate:jibb  state(queue ~[[%fit left [%atom %ud] site site %view ~]])
  =/  settled=(unit istate:jibb)  (icore-solve:jibb wrong)
  ?~  settled  ~[leaf+"a bad tag fit lost its source diagnostic"]
  =/  diagnostic=(unit [owner=term display=term diag=idiag:jibb])
    (icore-pending-conflict:jibb queue.u.settled u.settled ~)
  ?~  diagnostic  ~[leaf+"a tag against an incompatible aura lost its conflict"]
  ?.  =(owner.u.diagnostic %view)  ~[leaf+"a bad tag fit lost its owner"]
  ?.  =(2 (lent sites.diag.u.diagnostic))  ~[leaf+"a bad tag fit lost one of its sites"]
  ~
--
