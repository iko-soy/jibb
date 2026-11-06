::  The common matrix checks both branch arms against the supplied context.
/+  jibb, jibb-prelude-fixture
/*  public    %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  good      %txt   /tests/type-cell-branch/good/txt
/*  bad       %txt   /tests/type-cell-branch/bad/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-cell-branch
  ^-  tang
  ?~  good  ~[leaf+"cell branch good source missing"]
  ?~  bad  ~[leaf+"cell branch bad source missing"]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"cell branch prelude unavailable"]
  =/  a  (parse:jibb /tests/branch/jibb (text good))
  =/  b  (parse:jibb /tests/branch/jibb (text bad))
  ?:  |(?=(%| -.a) ?=(%| -.b))  ~[leaf+"cell branch source parse failed"]
  =/  ad=(list def:jibb)  defs.p.a
  =/  bd=(list def:jibb)  defs.p.b
  ?.  &(?=([* ~] ad) ?=([* ~] bd) ?=(%value -.i.ad) ?=(%value -.i.bd))
    ~[leaf+"cell branch declarations unavailable"]
  =/  unit-scheme=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit iface.u.prep)
  ?~  unit-scheme  ~[leaf+"cell branch unit unavailable"]
  =/  computed=(unit itype:jibb)  (template-apply:jibb u.unit-scheme ~[[%atom %t]])
  ?~  computed  ~[leaf+"cell branch unit instantiation failed"]
  =/  expected=itype:jibb  [%cell [%atom %t] u.computed]
  =/  env=ienv:jibb  ~[[%flag [[%flag ~] ~ ~]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(prelude `iface.u.prep, jrec-fuel 256)
  =/  failed=iresult:jibb  (infer-call-context-arg:jibb val.i.bd expected env state (span-of:jibb val.i.bd))
  =/  success=iresult:jibb  (infer-call-context-arg:jibb val.i.ad expected env state (span-of:jibb val.i.ad))
  ?.  ?=(%| -.failed)  ~[leaf+"wrong branch arm was accepted"]
  ?.  ?=([* * *] sites.p.failed)  ~[leaf+"wrong branch arm lost its two diagnostic sites"]
  ?.  ?=(%& -.success)  ~[leaf+"valid branch did not infer"]
  =/  fitted=ifit:jibb  (itype-fit:jibb typ.p.success expected sub.state.p.success next.state.p.success)
  ?.  ?=(%ok -.fitted)  ~[leaf+"branch result does not fit its context"]
  =/  hidden=isub:jibb  (isub-from-bindings:jibb ~[[55 [%face %x [%atom %t]]]])
  =/  unrelated=iresult:jibb  (infer-call-context-arg:jibb val.i.ad expected env state(sub hidden) (span-of:jibb val.i.ad))
  ?.  ?=(%& -.unrelated)  ~[leaf+"unrelated type binding prevented a valid branch"]
  ~
--
