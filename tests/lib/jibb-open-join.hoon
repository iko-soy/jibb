/+  jibb
|%
++  test-open-join
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  base=itype:jibb  [%cell [%var 1] [%atom %t]]
  =/  faced=itype:jibb  [%cell [%face %key [%var 1]] [%face %value [%atom %t]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 3, sub (itype-bind:jibb 0 base ~), queue ~[[%join [%var 0] faced site site]])
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  solved  ~[leaf+"same-variable join failed"]
  ?^  core-error.u.solved  ~[leaf+"same-variable join reported an error"]
  ?^  queue.u.solved  ~[leaf+"same-variable join remained open"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.solved) faced)  ~[leaf+"join lost a face or changed the shared variable"]
  =/  foreign=itype:jibb  [%cell [%face %key [%var 2]] [%face %value [%atom %t]]]
  =/  other=istate:jibb  state(queue ~[[%join [%var 0] foreign site site]])
  =/  pending=(unit istate:jibb)  (icore-solve:jibb other)
  ?~  pending  ~[leaf+"independent variables were rejected"]
  ?~  queue.u.pending  ~[leaf+"independent variables were merged"]
  ?.  =((itype-walk:jibb [%var 0] sub.u.pending) base)  ~[leaf+"pending join changed the target"]
  =/  left=itype:jibb  [%cell [%face %x [%var 1]] [%atom %t]]
  =/  right=itype:jibb  [%cell [%face %y [%var 1]] [%atom %t]]
  =/  conflict=istate:jibb  state(sub (itype-bind:jibb 0 left ~), queue ~[[%join [%var 0] right site site]])
  ?^  (icore-solve:jibb conflict)  ~[leaf+"conflicting value faces were joined"]
  ~
--
