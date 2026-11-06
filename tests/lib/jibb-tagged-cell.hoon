/+  jibb
|%
++  test-tagged-cell
  ^-  tang
  =/  source=@t  '++ one [%toggled 1]'
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/probe/jibb source)
  ?:  ?=(%| -.parsed)  ~[leaf+"tagged cell control did not parse"]
  =/  defs=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] defs)  ~[leaf+"tagged cell definition missing"]
  =/  value=expr:jibb  val.i.defs
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(general-defer &, owner %one)
  =/  inferred=iresult:jibb  (infer-fragment:jibb value ~ st)
  ?:  ?=(%| -.inferred)  ~[leaf+"tagged cell inference failed: {msg.p.inferred}"]
  ?.  ?=(%var -.typ.p.inferred)  ~[leaf+"tagged cell did not retain an open result"]
  =/  pending=(unit istate:jibb)  (icore-solve:jibb state.p.inferred)
  ?~  pending  ~[leaf+"open tagged cell was rejected"]
  ?~  queue.u.pending  ~[leaf+"tagged cell resolved without context"]
  =/  tagged=lit:jibb  [%term %tas %toggled '%toggled']
  =/  submit=lit:jibb  [%term %tas %submit '%submit']
  =/  case=itype:jibb  [%cell [%const tagged] [%atom %ud]]
  =/  union=itype:jibb  [%union ~[[%const submit] case] `[/ui/probe/jibb %msg] `%msg ~]
  =/  bound=isub:jibb  (itype-bind:jibb id.typ.p.inferred union sub.u.pending)
  =/  ready=istate:jibb  u.pending(sub bound)
  =/  solved=(unit istate:jibb)  (icore-solve:jibb ready)
  ?~  solved  ~[leaf+"tagged cell did not fit its later union"]
  ?^  core-error.u.solved  ~[leaf+"tagged cell produced a wrong error"]
  ?^  queue.u.solved  ~[leaf+"tagged cell union constraint did not close"]
  ?.  =((itype-walk:jibb typ.p.inferred sub.u.solved) union)  ~[leaf+"tagged cell lost its union result"]
  =/  structural=isub:jibb  (itype-bind:jibb id.typ.p.inferred case sub.u.pending)
  =/  fixed=(unit istate:jibb)  (icore-solve:jibb u.pending(sub structural))
  ?~  fixed  ~[leaf+"tagged cell did not fit a structural cell context"]
  ?^  queue.u.fixed  ~[leaf+"structural tagged cell constraint did not close"]
  =/  wrong=itype:jibb  [%union ~[[%const submit]] `[/ui/probe/jibb %msg] `%msg ~]
  =/  bad=isub:jibb  (itype-bind:jibb id.typ.p.inferred wrong sub.u.pending)
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb u.pending(sub bad))
  ?~  rejected  ~[leaf+"closed missing-tag diagnostic was lost"]
  ?~  core-error.u.rejected  ~[leaf+"wrong tagged cell was accepted"]
  ?.  =(msg.diag.u.core-error.u.rejected "msg has no case `%toggled`")
    ~[leaf+"wrong tagged-cell diagnostic differs: {msg.diag.u.core-error.u.rejected}"]
  ~
--
