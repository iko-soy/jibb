/+  jibb
|%
++  test-cell-boundary
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  number=itype:jibb  [%atom %ud]
  =/  text=itype:jibb  [%atom %t]
  =/  model=itype:jibb  [%cell [%face %count number] [%face %title text]]
  =/  bad-model=itype:jibb  [%cell [%face %other number] [%face %title text]]
  =/  sub=isub:jibb  (itype-bind:jibb 0 model ~)
  =/  actual=itype:jibb  [%cell text [%var 0]]
  =/  expected=itype:jibb  [%cell [%face %msg text] [%face %m model]]
  ?.  =((icore-cell-arity:jibb actual sub 0) `2)  ~[leaf+"a bound record value was flattened"]
  ?.  =((icore-cell-arity:jibb expected sub 0) `2)  ~[leaf+"a faced record value lost its boundary"]
  =/  flattened=itype:jibb  [%cell text model]
  ?.  =((icore-cell-arity:jibb flattened sub 0) `3)  ~[leaf+"a genuinely flattened tuple gained a boundary"]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(sub sub, next 1, queue ~[[%fit actual expected site site %$ ~]])
  =/  fitted=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  fitted  ~[leaf+"a nested record field did not fit"]
  ?^  core-error.u.fitted  ~[leaf+"a nested record fit reported a conflict"]
  ?^  queue.u.fitted  ~[leaf+"a nested record fit did not close"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.fitted) model)  ~[leaf+"nested value faces were not preserved"]
  =/  reverse-state=istate:jibb  state(queue ~[[%fit expected actual site site %$ ~]])
  =/  reversed=(unit istate:jibb)  (icore-solve:jibb reverse-state)
  ?~  reversed  ~[leaf+"the reversed nested fit failed"]
  ?^  core-error.u.reversed  ~[leaf+"the reversed nested fit reported a conflict"]
  ?^  queue.u.reversed  ~[leaf+"the reversed nested fit did not close"]
  =/  bad=itype:jibb  [%cell [%face %msg text] [%face %m bad-model]]
  =/  wrong=istate:jibb  state(queue ~[[%fit actual bad site site %$ ~]])
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb wrong)
  =/  rejected-cleanly=?  ?~(rejected & ?=(^ core-error.u.rejected))
  ?.  rejected-cleanly  ~[leaf+"different value face names were accepted"]
  ?^  (icore-fit-parts:jibb flattened expected sub site site %$ ~)
    ~[leaf+"a flattened tuple bypassed the decomposition arity guard"]
  ~
--
