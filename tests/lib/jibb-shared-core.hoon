::  A tag in one definition is constrained by a later definition.
/+  jibb
|%
++  core
  |=  src=@t
  ^-  (unit iresolved:jibb)
  =/  at=path  /ui/shared/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  molds=imolds:jibb  (collect-simple-molds:jibb ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape:jibb] name.m))
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(molds molds, globals (global-value-names:jibb ds), top-molds top, at at, in-mold |, jrec-fuel 256)
  (icore-resolve:jibb ds state)
++  test-shared-core
  ^-  tang
  =/  valid=@t
    (of-wain:format ~['+$ msg' '  %add' '  %sub' '++ make |= x [x %add]' '++ use |= x=@t ^- [@t msg] (make x)'])
  =/  checked=(unit iresolved:jibb)  (core valid)
  ?~  checked  ~[leaf+"later cast did not constrain the earlier tag"]
  =/  make=(unit ischeme:jibb)  (ienv-lookup:jibb %make env.u.checked)
  ?~  make  ~[leaf+"checked module did not export make"]
  ?.  ?=([%fn * [%cell * [%union *]]] typ.u.make)
    ~[leaf+"the earlier tag did not retain its named union context"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at valid ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  =/  atom-context=@t
    (of-wain:format ~['++ make |= x [x %add]' '++ use |= x=@t ^- [@t @tas] (make x)'])
  =/  atom-checked=(unit iresolved:jibb)  (core atom-context)
  ?~  atom-checked  ~[leaf+"a later atom context did not fix the tag"]
  =/  atom-make=(unit ischeme:jibb)  (ienv-lookup:jibb %make env.u.atom-checked)
  ?~  atom-make  ~[leaf+"atom-context module did not export make"]
  ?.  ?=([%fn * [%cell * [%const *]]] typ.u.atom-make)
    ~[leaf+"an atom context did not make the tag a constant"]
  =/  wrong=@t
    (of-wain:format ~['+$ msg' '  %add' '  %sub' '++ make |= x [x %wrong]' '++ use |= x=@t ^- [@t msg] (make x)'])
  ?^  (core wrong)  ~[leaf+"an unknown tag satisfied the later union"]
  =/  bad  (infer-jibb-file-detailed:jibb at wrong ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.bad)  ~[leaf+"full checker accepted an unknown tag"]
  =/  open=@t  (of-wain:format ~['++ make |= x [x %add]'])
  ?^  (core open)  ~[leaf+"an unfixed tag was published"]
  ~
++  test-queue-retry
  ^-  tang
  =/  tag=itype:jibb  [%tag 0 [%term %tas %go '%go'] |]
  =/  edge=icore-edge:jibb  [%fit tag [%fvar 1] *span:jibb *span:jibb %$ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 2, queue ~[edge], general-defer &)
  =/  waiting=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  waiting  ~[leaf+"an unresolved fit was rejected instead of waiting"]
  ?.  =(queue.u.waiting ~[edge])  ~[leaf+"an unresolved fit left the queue"]
  =.  state  u.waiting(sub (isub-from-bindings:jibb ~[[1 [%atom %tas]]]))
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  solved  ~[leaf+"a now-concrete fit was rejected"]
  ?^  queue.u.solved  ~[leaf+"a resolved fit remained in the queue"]
  ?.  ?=([%const [%term %tas %go *]] (itype-walk:jibb tag sub.u.solved))
    ~[leaf+"the tag did not resolve to its constant"]
  ~
++  test-wing-retry
  ^-  tang
  =/  src=@t  (of-wain:format ~['++ pick |= x name.x' '++ use (pick [name="hi" age=~zod])'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"a later record did not resolve the wing"]
  =/  pick=(unit ischeme:jibb)  (ienv-lookup:jibb %pick env.u.checked)
  ?~  pick  ~[leaf+"checked module did not export pick"]
  ?.  ?=([%fn * [%atom %t]] typ.u.pick)  ~[leaf+"the wing did not retain its field type"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  =/  wrong=@t  (of-wain:format ~['++ pick |= x name.x' '++ use (pick [title="hi" age=~zod])'])
  ?^  (core wrong)  ~[leaf+"a missing field was accepted"]
  ~
++  test-change-retry
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ rename |= x x(name="new")' '++ use (rename [name="hi" age=~zod])'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"a later record did not resolve the change"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  =/  wrong=@t
    (of-wain:format ~['++ rename |= x x(age="bad")' '++ use (rename [name="hi" age=~zod])'])
  ?^  (core wrong)  ~[leaf+"a replacement with the wrong type was accepted"]
  ~
++  test-match-retry
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ choose |= x' '  ?- x' '    %.y "yes"' '    %.n "no"' '++ unrelated "still waiting"' '++ use (choose %.y)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"a later loobean did not resolve the match"]
  =/  choose=(unit ischeme:jibb)  (ienv-lookup:jibb %choose env.u.checked)
  ?~  choose  ~[leaf+"checked module did not export choose"]
  ?.  ?=([%fn [%flag ~] [%atom %t]] typ.u.choose)
    ~[leaf+"the resolved match has the wrong type"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  =/  missing=@t
    (of-wain:format ~['++ choose |= x' '  ?- x' '    %.y "yes"' '++ use (choose %.y)'])
  ?^  (core missing)  ~[leaf+"an incomplete match was accepted"]
  =/  parsed  (parse:jibb at missing)
  ?:  ?=(%| -.parsed)  ~[leaf+"missing-match source failed to parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(globals (global-value-names:jibb ds), at at, in-mold |, jrec-fuel 256)
  =/  detailed=icore-output:jibb  (icore-check:jibb ds state)
  ?~  error.detailed  ~[leaf+"the deferred match error was discarded"]
  ?.  =(owner.u.error.detailed %choose)  ~[leaf+"the deferred match reported the wrong definition"]
  ?.  =(msg.diag.u.error.detailed "missing match case %.n")
    ~[leaf+"the deferred match did not report its missing case" leaf+msg.diag.u.error.detailed]
  ?.  =((lent sites.diag.u.error.detailed) 2)  ~[leaf+"the deferred match did not retain both sites"]
  ~
++  test-unface-retry
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ strip |= x (unface x)' '++ use (strip [name="hi" age=~zod])'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"a later record did not resolve unface"]
  =/  strip=(unit ischeme:jibb)  (ienv-lookup:jibb %strip env.u.checked)
  ?~  strip  ~[leaf+"checked module did not export strip"]
  ?.  ?=([%fn * [%cell [%atom %t] [%atom %p]]] typ.u.strip)
    ~[leaf+"unface did not remove the resolved record faces"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  =/  open=@t  (of-wain:format ~['++ strip |= x (unface x)'])
  ?^  (core open)  ~[leaf+"an unresolved unface was published"]
  ~
++  test-core-error
  ^-  tang
  =/  diag=idiag:jibb  ["definite test error" ~[[*span:jibb "test site"]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(core-error `[%owner diag])
  =/  result=icore-output:jibb  (icore-check:jibb ~ state)
  ?~  error.result  ~[leaf+"a definite constraint error was discarded"]
  ?.  =(u.error.result [%owner diag])  ~[leaf+"a definite constraint error changed"]
  ?^  result.result  ~[leaf+"a module with a definite error was published"]
  ~
++  test-joined-faces
  ^-  tang
  =/  bare=itype:jibb  [%cell [%atom %t] [%atom %p]]
  =/  faced=itype:jibb  [%cell [%face %name [%atom %t]] [%face %ship [%atom %p]]]
  =/  edge=icore-edge:jibb  [%join [%var 0] faced *span:jibb *span:jibb]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(sub (isub-from-bindings:jibb ~[[0 bare]]), queue ~[edge])
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  solved  ~[leaf+"a faced record could not join a previously bound variable"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.solved) faced)
    ~[leaf+"the bound record did not retain its faces"]
  =/  conflicting=itype:jibb  [%cell [%face %other [%atom %t]] [%face %ship [%atom %p]]]
  =.  state  state(sub (isub-from-bindings:jibb ~[[0 conflicting]]))
  ?^  (icore-solve:jibb state)  ~[leaf+"different explicit faces were joined"]
  ~
++  test-mutual-gates
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ left |= x (right x)' '++ right |= y (left y)' '++ use (left "hi")'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"mutually recursive gates did not infer together"]
  =/  left=(unit ischeme:jibb)  (ienv-lookup:jibb %left env.u.checked)
  ?~  left  ~[leaf+"the recursive group did not export left"]
  ?~  vars.u.left  ~[leaf+"the recursive group did not generalize its own variables"]
  =/  at=path  /ui/shared/jibb
  =/  full  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  ~
++  test-component-index
  ^-  tang
  =/  src=@t  (of-wain:format ~['++ zebra 1' '+$ texty @t' '++ apple 2'])
  =/  parsed  (parse:jibb /ui/shared/jibb src)
  ?:  ?=(%| -.parsed)  ~[leaf+"component-index source failed to parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  index=(map term icore-definition:jibb)  (icore-definition-index:jibb ds ~ 0)
  =/  members=(list def:jibb)  (icore-members:jibb ~[%apple %missing %zebra] index)
  ?.  =((turn members |=(d=def:jibb name.d)) ~[%zebra %apple])
    ~[leaf+"component lookup changed source order or admitted a missing member"]
  =/  names=(list term)  (global-value-names:jibb ds)
  =/  nameset=ivisited:jibb  (graph-nameset:jibb names ~)
  =/  graph=iadj:jibb  (graph-make-forward:jibb ds nameset ~)
  ?.  =((graph-components:jibb ds names) (graph-components-for:jibb names graph))
    ~[leaf+"reusing the indexed graph changed the dependency components"]
  ~
++  test-branch-join-deferred
  ^-  tang
  =/  add=itype:jibb  [%tag 0 [%term %tas %add '%add'] |]
  =/  sub=itype:jibb  [%tag 1 [%term %tas %sub '%sub'] |]
  =/  result=itype:jibb  [%var 2]
  =/  first=span:jibb  [[2 3] [2 7]]
  =/  second=span:jibb  [[3 4] [3 8]]
  =/  branch=span:jibb  [[1 1] [3 8]]
  =/  edge=icore-edge:jibb  [%branch-join ~[[add first] [sub second]] result branch %choose]
  =/  fits=(list dgo:jibb)  (icore-pending-fits:jibb ~[edge])
  ?.  =(fits ~[[add result first branch] [sub result second branch]])
    ~[leaf+"pending branch fits did not retain both arm sites"]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 3, general-defer &, queue ~[edge])
  =/  waiting=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  waiting  ~[leaf+"open branch join was rejected"]
  ?.  =(queue.u.waiting ~[edge])  ~[leaf+"open branch join did not wait"]
  ?~  wake.u.waiting  ~[leaf+"open branch join was not indexed"]
  ?~  (~(get by index.u.wake.u.waiting) 0)  ~[leaf+"first arm was not indexed"]
  ?~  (~(get by index.u.wake.u.waiting) 1)  ~[leaf+"second arm was not indexed"]
  ?~  (~(get by index.u.wake.u.waiting) 2)  ~[leaf+"result was not indexed"]
  ?^  (itype-lookup:jibb 2 sub.u.waiting)  ~[leaf+"the first arm fixed the open result"]
  =/  msg=itype:jibb  [%union ~[[%const [%term %tas %add '%add']] [%const [%term %tas %sub '%sub']]] ~ `'msg' ~]
  =/  ready=istate:jibb  u.waiting(sub (itype-bind:jibb 2 msg sub.u.waiting))
  =/  done=(unit istate:jibb)  (icore-solve:jibb ready)
  ?~  done  ~[leaf+"context did not resolve both branch arms"]
  ?^  queue.u.done  ~[leaf+"resolved branch join stayed queued"]
  =/  reverse=icore-edge:jibb  [%branch-join ~[[sub *span:jibb] [add *span:jibb]] result *span:jibb %choose]
  =.  state  state(queue ~[reverse])
  =/  reverse-wait=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  reverse-wait  ~[leaf+"reversed open branch join was rejected"]
  =.  ready  u.reverse-wait(sub (itype-bind:jibb 2 msg sub.u.reverse-wait))
  =/  reverse-done=(unit istate:jibb)  (icore-solve:jibb ready)
  ?~  reverse-done  ~[leaf+"reversed branch did not resolve"]
  ?^  queue.u.reverse-done  ~[leaf+"reversed branch join stayed queued"]
  =/  only-add=itype:jibb  [%union ~[[%const [%term %tas %add '%add']]] ~ `'msg' ~]
  =.  ready  u.waiting(sub (itype-bind:jibb 2 only-add sub.u.waiting))
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb ready)
  ?~  rejected  ~[leaf+"incompatible branch lost its definite diagnostic"]
  ?~  core-error.u.rejected  ~[leaf+"a branch with a case outside the union was accepted"]
  ?.  =(%choose owner.u.core-error.u.rejected)  ~[leaf+"branch diagnostic lost its owning definition"]
  =/  diag=idiag:jibb  diag.u.core-error.u.rejected
  ?.  =(msg.diag "msg has no case `%sub`")  ~[leaf+"wrong branch diagnostic" leaf+msg.diag]
  ?.  ?=([* * ~] sites.diag)  ~[leaf+"branch diagnostic did not retain both sites"]
  ?:  ?=(%external -.i.sites.diag)  ~[leaf+"unexpected external first diagnostic site"]
  ?:  ?=(%external -.i.t.sites.diag)  ~[leaf+"unexpected external second diagnostic site"]
  ?.  &(=(at.i.sites.diag branch) =(at.i.t.sites.diag second))
    ~[leaf+"branch diagnostic points at the wrong sites"]
  =/  faced=itype:jibb  [%face %x [%atom %t]]
  =/  bare=itype:jibb  [%atom %t]
  =/  face-edge=icore-edge:jibb  [%branch-join ~[[faced first] [bare second]] result branch %choose]
  =/  face-state=istate:jibb  *istate:jibb
  =.  face-state  face-state(next 3, general-defer &, queue ~[face-edge])
  =/  faces=(unit istate:jibb)  (icore-solve:jibb face-state)
  ?~  faces  ~[leaf+"faced branch join failed"]
  ?.  =((itype-walk:jibb result sub.u.faces) faced)  ~[leaf+"faced branch lost its face"]
  =.  face-edge  [%branch-join ~[[bare first] [faced second]] result branch %choose]
  =.  face-state  face-state(queue ~[face-edge])
  =/  reverse-faces=(unit istate:jibb)  (icore-solve:jibb face-state)
  ?~  reverse-faces  ~[leaf+"reversed faced branch join failed"]
  ?.  =((itype-walk:jibb result sub.u.reverse-faces) faced)  ~[leaf+"reversed branch lost its face"]
  ~
++  test-branch-join-module
  ^-  tang
  =/  a=@t  (of-wain:format ~['+$ msg' '  %add' '  %sub' '++ choose |= b=?' '  ?- b' '    %.y %add' '    %.n %sub' '++ use |= b=? ^- msg (choose b)'])
  =/  b=@t  (of-wain:format ~['+$ msg' '  %add' '  %sub' '++ choose |= b=?' '  ?- b' '    %.y %sub' '    %.n %add' '++ use |= b=? ^- msg (choose b)'])
  ?~  (core a)  ~[leaf+"later union did not constrain branch arms"]
  ?~  (core b)  ~[leaf+"reversed branch arms did not resolve"]
  =/  open=@t  (of-wain:format ~['++ choose |= b=?' '  ?- b' '    %.y %add' '    %.n %sub'])
  ?^  (core open)  ~[leaf+"unfixed branch tags were generalized"]
  =/  wrong=@t  (of-wain:format ~['+$ msg' '  %add' '++ choose |= b=?' '  ?- b' '    %.y %add' '    %.n %sub' '++ use |= b=? ^- msg (choose b)'])
  ?^  (core wrong)  ~[leaf+"branch accepted a tag outside its union"]
  =/  clash=@t  (of-wain:format ~['++ choose |= b=?' '  ?- b' '    %.y "text"' '    %.n ~zod'])
  ?^  (core clash)  ~[leaf+"incompatible concrete branch results were accepted"]
  ~

++  test-branch-join-union
  ^-  tang
  =/  forward=@t
    (of-wain:format ~['+$ input' '  %left' '  %right' '  %both' '+$ msg' '  %add' '  %sub' '  %toggle' '++ choose |= x=input' '  ?- x' '    %left %add' '    %right %sub' '    %both %toggle' '++ use |= x=input ^- msg (choose x)'])
  =/  reverse=@t
    (of-wain:format ~['+$ input' '  %left' '  %right' '  %both' '+$ msg' '  %add' '  %sub' '  %toggle' '++ choose |= x=input' '  ?- x' '    %both %toggle' '    %right %sub' '    %left %add' '++ use |= x=input ^- msg (choose x)'])
  ?~  (core forward)  ~[leaf+"later union did not constrain all match arms"]
  ?~  (core reverse)  ~[leaf+"reordered union match arms did not resolve"]
  =/  wrong=@t
    (of-wain:format ~['+$ input' '  %left' '  %right' '  %both' '+$ msg' '  %add' '  %sub' '++ choose |= x=input' '  ?- x' '    %left %add' '    %right %sub' '    %both %toggle' '++ use |= x=input ^- msg (choose x)'])
  ?^  (core wrong)  ~[leaf+"union match accepted a result outside its context"]
  ~

++  test-branch-fit-definite
  ^-  tang
  =/  branch=span:jibb  [[1 1] [1 5]]
  =/  arm=span:jibb  [[2 3] [2 8]]
  =/  left=itype:jibb  [%collection %list ~[[%var 0]]]
  =/  right=itype:jibb  [%atom %t]
  =/  edge=icore-edge:jibb  [%branch-fit left right arm branch %local]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 1, general-defer &, queue ~[edge])
  =/  waiting=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  waiting  ~[leaf+"an open mismatch was reported as definite"]
  ?^  core-error.u.waiting  ~[leaf+"an open mismatch reported an error"]
  ?.  =(queue.u.waiting ~[edge])  ~[leaf+"an open mismatch was not deferred"]
  =/  resolved=istate:jibb  u.waiting(sub (itype-bind:jibb 0 [%atom %ud] sub.u.waiting))
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb resolved)
  ?~  rejected  ~[leaf+"closed mismatch lost its diagnostic"]
  ?~  core-error.u.rejected  ~[leaf+"closed incompatible branch was accepted"]
  ?.  =(%local owner.u.core-error.u.rejected)  ~[leaf+"closed mismatch lost the local owner"]
  =/  a=itype:jibb  [%cell [%var 1] [%atom %ud]]
  =/  b=itype:jibb  [%cell [%var 2] [%atom %t]]
  =.  edge  [%branch-fit a b arm branch %local]
  =.  state  state(next 3, queue ~[edge])
  =/  decomposed=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  decomposed  ~[leaf+"decomposed mismatch lost its diagnostic"]
  ?~  core-error.u.decomposed  ~[leaf+"decomposed incompatible branch was accepted"]
  ?.  =(%local owner.u.core-error.u.decomposed)  ~[leaf+"decomposition lost the local owner"]
  =/  diag=idiag:jibb  diag.u.core-error.u.decomposed
  ?.  ?=([* * ~] sites.diag)  ~[leaf+"decomposition lost branch sites"]
  ?:  ?=(%external -.i.sites.diag)  ~[leaf+"unexpected external first diagnostic site"]
  ?:  ?=(%external -.i.t.sites.diag)  ~[leaf+"unexpected external second diagnostic site"]
  ?.  &(=(at.i.sites.diag branch) =(at.i.t.sites.diag arm))  ~[leaf+"decomposition changed the sites"]
  =/  later=span:jibb  [[3 2] [3 7]]
  =/  closed-edge=icore-edge:jibb
    [%branch-join ~[[[%atom %t] arm] [[%atom %p] later]] [%var 3] branch %local]
  =/  closed-state=istate:jibb  *istate:jibb
  =.  closed-state  closed-state(next 4, general-defer &, queue ~[closed-edge])
  =/  closed=(unit istate:jibb)  (icore-solve:jibb closed-state)
  ?~  closed  ~[leaf+"closed branch mismatch was rejected before later context"]
  ?^  core-error.u.closed  ~[leaf+"closed branch mismatch was diagnosed before module end"]
  ?~  queue.u.closed  ~[leaf+"closed incompatible arms did not wait for context"]
  =/  final-error=(unit [owner=term diag=idiag:jibb])
    (icore-branch-error:jibb (flop queue.u.closed) u.closed)
  ?~  final-error  ~[leaf+"closed mismatch lost its module-final diagnostic"]
  ?.  =(%local owner.u.final-error)  ~[leaf+"closed mismatch lost its owner"]
  =/  closed-diag=idiag:jibb  diag.u.final-error
  ?.  =(msg.closed-diag "branch arms have incompatible types")  ~[leaf+"closed mismatch has the wrong reason"]
  ?.  ?=([* * ~] sites.closed-diag)  ~[leaf+"closed mismatch lost its arm sites"]
  ?:  ?=(%external -.i.sites.closed-diag)  ~[leaf+"unexpected external first diagnostic site"]
  ?:  ?=(%external -.i.t.sites.closed-diag)  ~[leaf+"unexpected external second diagnostic site"]
  ?.  &(=(at.i.sites.closed-diag arm) =(at.i.t.sites.closed-diag later))
    ~[leaf+"closed mismatch changed the arm sites"]
  =/  add=itype:jibb  [%const [%term %tas %add '%add']]
  =/  other=itype:jibb  [%const [%term %tas %other '%other']]
  =/  tags-edge=icore-edge:jibb  [%branch-join ~[[add arm] [other later]] [%var 3] branch %local]
  =/  tags-state=istate:jibb  *istate:jibb
  =.  tags-state  tags-state(next 4, general-defer &, queue ~[tags-edge])
  =/  tags-wait=(unit istate:jibb)  (icore-solve:jibb tags-state)
  ?~  tags-wait  ~[leaf+"closed tag arms were rejected before their later union"]
  ?^  core-error.u.tags-wait  ~[leaf+"closed tag arms produced a premature error"]
  =/  msg=itype:jibb  [%union ~[add other] ~ `'msg' ~]
  =/  tags-ready=istate:jibb  u.tags-wait(sub (itype-bind:jibb 3 msg sub.u.tags-wait))
  =/  tags-done=(unit istate:jibb)  (icore-solve:jibb tags-ready)
  ?~  tags-done  ~[leaf+"later union did not accept closed tag arms"]
  ?^  core-error.u.tags-done  ~[leaf+"later union rejected closed tag arms"]
  ?^  queue.u.tags-done  ~[leaf+"closed tag arms remained queued after union context"]
  ~
++  test-branch-fit-local-owner
  ^-  tang
  =/  src=@t
    (of-wain:format ~['+$ msg' '  %add' '  %other' '++ outer |= x=?' '  ++ choose |= b=?' '    ?- b' '      %.y %add' '      %.n %sub' '  ^- msg (choose x)'])
  =/  at=path  /ui/shared/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"local branch fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  molds=imolds:jibb  (collect-simple-molds:jibb ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape:jibb] name.m))
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(molds molds, globals (global-value-names:jibb ds), top-molds top, at at, jrec-fuel 256)
  =/  checked=icore-output:jibb  (icore-check:jibb ds state)
  ?~  error.checked  ~[leaf+"local incompatible branch did not produce a definite error"]
  ?.  =(%choose owner.u.error.checked)  ~[leaf+"local incompatible branch lost its definition owner"]
  ~

++  test-full-branch-diagnostic
  ^-  tang
  =/  src=@t
    (of-wain:format ~['+$ msg' '  %add' '  %other' '++ choose |= b=?' '  ?- b' '    %.y %add' '    %.n %sub' '++ use |= b=? ^- msg (choose b)'])
  =/  at=path  /ui/full-branch/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"branch fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  molds=imolds:jibb  (collect-simple-molds:jibb ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape:jibb] name.m))
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(molds molds, globals (global-value-names:jibb ds), top-molds top, at at, jrec-fuel 256)
  =/  checked=icore-output:jibb  (icore-check:jibb ds state)
  ?~  error.checked  ~[leaf+"invalid branch produced no core diagnostic"]
  ?.  =(%choose owner.u.error.checked)  ~[leaf+"invalid branch has the wrong owner"]
  =/  diag=idiag:jibb  diag.u.error.checked
  ?.  ?=([* * ~] sites.diag)  ~[leaf+"invalid branch did not retain two sites"]
  ?:  ?=(%external -.i.sites.diag)  ~[leaf+"unexpected external first diagnostic site"]
  ?:  ?=(%external -.i.t.sites.diag)  ~[leaf+"unexpected external second diagnostic site"]
  ?.  &(=(line.beg.at.i.sites.diag 5) =(line.beg.at.i.t.sites.diag 7))
    ~[leaf+(trip (show-inference-diagnostic:jibb at src %choose diag))]
  =/  full=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.full)  ~[leaf+"full checker accepted the incompatible branch"]
  =/  expected=@t
    (of-wain:format ~['++ choose: msg has no case `%sub`' '/ui/full-branch.jibb:1:4: expected union has type msg' '+$ msg' '   ^' '/ui/full-branch.jibb:2:3: expected union has type msg' '  %add' '  ^' '/ui/full-branch.jibb:5:3: expected union has type msg' '  ?- b' '  ^' '/ui/full-branch.jibb:7:9: tag literal has type %sub' '    %.n %sub' '        ^'])
  ?.  =(message.p.full expected)  ~[leaf+"full checker lost branch diagnostic" leaf+(trip message.p.full)]
  ~

++  test-branch-later-main
  ^-  tang
  =/  forward=@t
    (of-wain:format ~['++ choose |= b=?' '  ?- b' '    %.y "text"' '    %.n ~zod' '++ main ^- * (choose %.y)'])
  =/  reverse=@t
    (of-wain:format ~['++ choose |= b=?' '  ?- b' '    %.y ~zod' '    %.n "text"' '++ main ^- * (choose %.y)'])
  ?~  (core forward)  ~[leaf+"later main did not constrain closed branch results"]
  ?~  (core reverse)  ~[leaf+"reordered closed branch results did not resolve through main"]
  ~

--
