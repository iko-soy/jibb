/+  jibb
|%
++  test-fresh-evidence
  ^-  tang
  =/  typ=itype:jibb  [%refined [%var 0]]
  =/  body=itype:jibb  [%fn [%var 1] [%var 1]]
  =/  scheme=ischeme:jibb  [typ ~[1] `[[[0 body] ~] ~]]
  =/  closed=(unit ischeme:jibb)  (graph-close-scheme:jibb scheme ~)
  ?~  closed  ~[leaf+"closed private evidence graph was rejected"]
  =/  state=istate:jibb  *istate:jibb
  =/  first=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb u.closed state)
  ?~  first  ~[leaf+"first evidence graph instance failed"]
  ?.  ?=([%refined [%var *]] typ.u.first)  ~[leaf+"evidence root was not retained"]
  =/  second=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb u.closed state.u.first)
  ?~  second  ~[leaf+"second evidence graph instance failed"]
  ?.  ?=([%refined [%var *]] typ.u.second)  ~[leaf+"second evidence root was not retained"]
  ?:  =(id.proof.typ.u.first id.proof.typ.u.second)  ~[leaf+"fresh instances shared private evidence roots"]
  =/  resolved=(unit itype:jibb)  (itype-realize:jibb typ.u.first sub.state.u.first)
  ?.  ?=([~ [%refined [%fn [%var *] [%var *]]]] resolved)  ~[leaf+"evidence graph did not realize its gate"]
  ?.  =(sample.proof.u.resolved product.proof.u.resolved)  ~[leaf+"evidence lost gate identity"]
  =/  escaped=ischeme:jibb  [[%refined [%var 9]] ~ ~]
  ?^  (graph-close-scheme:jibb escaped ~)  ~[leaf+"unbound private evidence escaped"]
  ~
--
