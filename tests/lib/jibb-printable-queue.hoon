/+  jibb
|%
++  test-printable-queue
  ^-  tang
  =/  site=span:jibb  [[1 3] [1 4]]
  =/  edge=icore-edge:jibb  [%printable [%var 0] site %route ~ site |]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, next 1, queue ~[edge], levels (~(put by *(map @ud @ud)) 0 1))
  =/  first=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  first  ~[leaf+"open printable constraint failed"]
  ?.  =(queue.u.first ~[edge])  ~[leaf+"open printable constraint was discarded"]
  =/  scheme=(unit ischeme:jibb)  (icore-generalize:jibb [%fn [%var 0] [%var 0]] 0 u.first)
  ?~  scheme  ~[leaf+"printable generalization declined"]
  ?^  vars.u.scheme  ~[leaf+"printable-constrained variable generalized"]
  =/  changed=isub:jibb  (itype-bind:jibb 0 [%atom %t] sub.u.first)
  =/  solved=(unit istate:jibb)  (icore-solve:jibb u.first(sub changed))
  ?~  solved  ~[leaf+"printable did not wake on its variable"]
  ?^  queue.u.solved  ~[leaf+"fixed printable constraint remained queued"]
  =/  bad=isub:jibb  (itype-bind:jibb 0 [%cell [%atom %t] [%atom %t]] sub.u.first)
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb u.first(sub bad))
  ?~  rejected  ~[leaf+"bad printable did not report its error"]
  ?~  core-error.u.rejected  ~[leaf+"cell-bound segment was accepted"]
  ?.  =(owner.u.core-error.u.rejected %route)  ~[leaf+"printable owner was lost"]
  =/  diag=idiag:jibb  diag.u.core-error.u.rejected
  ?.  =(sites.diag ~[[site "non-atom segment has type [@t @t]"]])  ~[leaf+"printable site was lost"]
  ::  Decimal-only variables default after context; a written capital does not.
  =/  decimal=icore-edge:jibb  [%printable [%nvar 2] site %route ~ site |]
  =/  decimal-state=istate:jibb  state(queue ~[decimal], next 3)
  =/  defaulted=(unit istate:jibb)  (icore-default-printables:jibb queue.decimal-state decimal-state)
  ?~  defaulted  ~[leaf+"decimal aura could not default"]
  ?.  =((itype-walk:jibb [%nvar 2] sub.u.defaulted) [%atom %ud])
    ~[leaf+"decimal aura did not default to @ud"]
  =/  caps=icaps:jibb  ~[['A' 2 site]]
  =/  generic-sub=isub:jibb  (itype-bind:jibb 2 [%rnvar 2] ~)
  =/  generic=icore-edge:jibb  [%printable [%rnvar 2] site %route caps site |]
  =/  generic-state=istate:jibb  state(queue ~[generic], next 3, sub generic-sub)
  =/  preserved=(unit istate:jibb)  (icore-default-printables:jibb queue.generic-state generic-state)
  ?~  preserved  ~[leaf+"generic aura defaulting failed"]
  ?.  =((itype-walk:jibb [%var 2] sub.u.preserved) [%rnvar 2])
    ~[leaf+"written capital was incorrectly defaulted"]
  ~
--
