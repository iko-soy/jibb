::  Deferred obligations wake only for reachable binding changes.
/+  jibb
|%
++  test-wake-index
  ^-  tang
  =/  tag=itype:jibb  [%tag 0 [%term %tas %go '%go'] |]
  =/  first=icore-edge:jibb  [%fit tag [%var 1] *span:jibb *span:jibb %$ ~]
  =/  other=icore-edge:jibb  [%fit [%tag 2 [%term %tas %stop '%stop'] |] [%var 3] *span:jibb *span:jibb %$ ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 10, general-defer &, queue ~[other first])
  =/  ready=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  ready  ~[leaf+"open edges were rejected"]
  ?~  wake.u.ready  ~[leaf+"the waiting queue was not indexed"]
  ?.  ?=(^ (~(get by index.u.wake.u.ready) 1))  ~[leaf+"first edge was not indexed"]
  ?.  ?=(^ (~(get by index.u.wake.u.ready) 3))  ~[leaf+"second edge was not indexed"]
  =/  unrelated=istate:jibb  u.ready(sub (itype-bind:jibb 9 [%atom %t] sub.u.ready))
  =/  skipped=(unit (unit istate:jibb))  (iwake-attempt:jibb unrelated)
  ?~  skipped  ~[leaf+"unrelated binding could not skip the queue"]
  ?~  u.skipped  ~[leaf+"unrelated binding rejected the queue"]
  ?.  =(queue.u.u.skipped queue.u.ready)  ~[leaf+"skipping changed pending edges"]
  =/  rollback=istate:jibb  u.u.skipped(sub (itype-bind:jibb 1 [%atom %tas] ~))
  ?^  (iwake-attempt:jibb rollback)  ~[leaf+"a divergent transaction reused the old watch index"]
  =/  recovered=(unit istate:jibb)  (icore-solve:jibb rollback)
  ?~  recovered  ~[leaf+"the full solver did not recover a divergent transaction"]
  ?.  =(queue.u.recovered ~[other])  ~[leaf+"rollback did not wake the correct edge"]
  =/  changed=istate:jibb  u.u.skipped(sub (itype-bind:jibb 1 [%atom %tas] sub.u.u.skipped))
  =/  solved=(unit istate:jibb)  (icore-solve:jibb changed)
  ?~  solved  ~[leaf+"a relevant binding was rejected"]
  ?.  =(queue.u.solved ~[other])  ~[leaf+"the relevant edge did not wake independently"]
  =/  alias=istate:jibb  u.ready(sub (itype-bind:jibb 1 [%var 4] sub.u.ready))
  =/  still=(unit istate:jibb)  (icore-solve:jibb alias)
  ?~  still  ~[leaf+"an unresolved alias was rejected"]
  ?~  wake.u.still  ~[leaf+"the alias lost its watch index"]
  ?.  ?=(^ (~(get by index.u.wake.u.still) 4))  ~[leaf+"the alias target was not watched"]
  =/  closed=istate:jibb  u.still(sub (itype-bind:jibb 4 [%atom %tas] sub.u.still))
  =/  fast=(unit istate:jibb)  (icore-solve:jibb closed)
  =/  baseline=(unit istate:jibb)  (icore-solve-full:jibb closed)
  ?~  fast  ~[leaf+"the aliased binding did not wake its edge"]
  ?~  baseline  ~[leaf+"the baseline rejected the aliased binding"]
  ?.  =(u.fast(wake ~) u.baseline(wake ~))  ~[leaf+"indexed wakeups changed the solver result"]
  =/  wrong=istate:jibb  u.ready(sub (itype-bind:jibb 1 [%atom %ud] sub.u.ready))
  ::  An open literal retains its failed fit until module finalization,
  ::  where the source-bearing diagnostic is rendered. It must never be
  ::  discarded as solved by either the indexed or the baseline solver.
  =/  wrong-fast=(unit istate:jibb)  (icore-solve:jibb wrong)
  =/  wrong-full=(unit istate:jibb)  (icore-solve-full:jibb wrong)
  ?~  wrong-fast  ~[leaf+"the failed literal lost its diagnostic constraint"]
  ?~  wrong-full  ~[leaf+"the baseline lost the failed literal constraint"]
  ?.  =(u.wrong-fast(wake ~) u.wrong-full(wake ~))
    ~[leaf+"indexed wakeups changed the deferred failure"]
  ?.  (lien queue.u.wrong-fast |=(edge=icore-edge:jibb =(edge first)))
    ~[leaf+"an incompatible woken edge was discarded as solved"]
  =/  conflict=(unit [owner=term display=term diag=idiag:jibb])
    (icore-pending-conflict:jibb queue.u.wrong-fast u.wrong-fast ~)
  ?~  conflict  ~[leaf+"the retained mismatch has no final diagnostic"]
  ?.  =(msg.diag.u.conflict "types do not unify")
    ~[leaf+"the retained mismatch was reported as an unresolved limit"]
  ?.  =(2 (lent sites.diag.u.conflict))
    ~[leaf+"the retained mismatch lost one of its source sites"]
  =/  tail=itype:jibb  [%cell [%var 6] [%atom %t]]
  =/  join=icore-edge:jibb  [%join [%var 5] [%cell [%var 9] [%atom %t]] *span:jibb *span:jibb]
  =.  state  state(sub (itype-bind:jibb 5 tail ~), queue ~[join])
  =/  joined=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  joined  ~[leaf+"an open structural join was rejected"]
  ?~  wake.u.joined  ~[leaf+"the structural join was not indexed"]
  ?.  ?=(^ (~(get by index.u.wake.u.joined) 5))  ~[leaf+"the bound root was not watched"]
  =/  refined=istate:jibb  u.joined(sub (itype-bind:jibb 5 [%cell [%var 8] [%atom %t]] sub.u.joined))
  =/  retried=(unit istate:jibb)  (icore-solve:jibb refined)
  ?~  retried  ~[leaf+"a refined root was rejected"]
  ?~  wake.u.retried  ~[leaf+"the refined join lost its watch index"]
  ?.  ?=(^ (~(get by index.u.wake.u.retried) 8))  ~[leaf+"refining a bound root did not index its new child"]
  ~
--
