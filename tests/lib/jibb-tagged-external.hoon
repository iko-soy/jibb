/+  jibb
|%
++  test-tagged-external
  ^-  tang
  =/  source=@t  '++ one [%other 1]'
  =/  at=path  /ui/local/jibb
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  ~[leaf+"external union control did not parse"]
  =/  defs=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] defs)  ~[leaf+"external union definition missing"]
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(general-defer &, owner %one, at at)
  =/  value=iresult:jibb  (infer-fragment:jibb val.i.defs ~ st)
  ?:  ?=(%| -.value)  ~[leaf+"tagged cell inference failed"]
  ?.  ?=(%var -.typ.p.value)  ~[leaf+"tagged cell did not wait for context"]
  =/  submit=lit:jibb  [%term %tas %submit '%submit']
  =/  union=itype:jibb  [%union ~[[%const submit]] `[/ui/remote/jibb %msg] `%msg ~]
  =/  bound=isub:jibb  (itype-bind:jibb id.typ.p.value union sub.state.p.value)
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb state.p.value(sub bound))
  ?~  rejected  ~[leaf+"external union error was dropped"]
  ?~  core-error.u.rejected  ~[leaf+"invalid external union case was accepted"]
  =/  diag=idiag:jibb  diag.u.core-error.u.rejected
  ?.  =(msg.diag "msg has no case `%other`")  ~[leaf+"external union error wording differs"]
  =/  expected=(list [at=span:jibb note=tape])
    ~[[[[1 8] [1 18]] "expected union has type msg"] [[[1 9] [1 15]] "tag literal has type %other"]]
  ?.  =(sites.diag expected)  ~[leaf+"external union lost its actual tuple and tag sites"]
  ~
--
