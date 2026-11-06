/+  jibb
|%
++  test-reverse-tag
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  lit=lit:jibb  [%term %tas %yes '%yes']
  =/  other=lit:jibb  [%term %tas %no '%no']
  =/  wrong=lit:jibb  [%term %tas %missing '%missing']
  =/  msg=itype:jibb  [%union ~[[%const lit] [%const other]] `[/ui/probe/jibb %msg] `%msg ~]
  =/  tag=itype:jibb  [%tag 0 lit |]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 1, queue ~[[%tag 0 lit | site] [%fit msg tag site site %$ ~]])
  =/  result=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  result  ~[leaf+"closed union could not fix tag on expected side"]
  ?^  queue.u.result  ~[leaf+"reverse union tag fit remained open"]
  ?.  =(msg (itype-walk:jibb tag sub.u.result))  ~[leaf+"reverse tag lost its union"]
  =/  invalid=istate:jibb  state(queue ~[[%fit msg [%tag 0 wrong |] site site %$ ~]])
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb invalid)
  ?~  rejected  ~[leaf+"reverse missing-tag error was dropped"]
  ?~  core-error.u.rejected  ~[leaf+"reverse union fit accepted a missing tag"]
  ?^  queue.u.rejected  ~[leaf+"reverse missing-tag fit remained queued"]
  =/  diag=idiag:jibb  diag.u.core-error.u.rejected
  ?.  =(msg.diag "msg has no case `%missing`")  ~[leaf+"reverse missing-tag wording differs" leaf+msg.diag]
  =/  expected=(list [at=span:jibb note=tape])
    ~[[site "expected union has type msg"] [site "tag literal has type %missing"]]
  ?.  =(sites.diag expected)  ~[leaf+"reverse missing-tag sites differ"]
  =/  invalid-branch=istate:jibb
    state(queue ~[[%branch-fit msg [%tag 0 wrong |] site site %$]])
  =/  branch-rejected=(unit istate:jibb)  (icore-solve:jibb invalid-branch)
  ?~  branch-rejected  ~[leaf+"reverse branch error was dropped"]
  ?~  core-error.u.branch-rejected  ~[leaf+"reverse branch fit accepted a missing tag"]
  =/  branch-diag=idiag:jibb  diag.u.core-error.u.branch-rejected
  ?.  =(msg.branch-diag msg.diag)  ~[leaf+"reverse branch wording differs"]
  ?.  =(sites.branch-diag expected)  ~[leaf+"reverse branch sites differ"]
  ::  A constructor still needs its own gate or tagged-cell context.
  =/  constructor=istate:jibb  state(queue ~[[%fit msg [%tag 0 lit &] site site %$ ~]])
  =/  unresolved=(unit istate:jibb)  (icore-solve:jibb constructor)
  ?^  unresolved
    ?~  queue.u.unresolved  ~[leaf+"constructor was fixed as a bare tag"]
    ~
  ~
--
