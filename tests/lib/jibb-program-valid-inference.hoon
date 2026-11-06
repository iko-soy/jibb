::  Programs accepted by general inference, with exact published schemes.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %txt  /tests/type-program-main/initializer/txt
/*  generic  %txt  /tests/type-program-main/initializer-generic/txt
/*  no-main  %txt  /tests/type-program-main/initializer-no-main/txt
/*  subs  %txt  /tests/type-program-main/initializer-subs/txt
/*  gate-alias  %txt  /tests/type-program-main/initializer-gate-alias/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  checked
  |=  [src=@t prep=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  =/  at=path  /tests/program-main/initializer/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.prep molds.prep ~ `iface.prep)
++  expected-program-main
  ^-  tape
  ;:  weld
    "[init=$-((list @t) [xs=(list @t) [draft=@t error=(unit @t)]]) "
    "[update=$-([message [xs=(list @t) [draft=@t error=(unit @t)]]] "
    "[[xs=(list @t) [draft=@t error=(unit @t)]] (list (cmd message))]) "
    "[view=$-([xs=(list @t) [draft=@t error=(unit @t)]] (element message)) "
    "subs=$-([xs=(list @t) [draft=@t error=(unit @t)]] (list (sub message)))]]]"
  ==
++  test-program-valid-inference
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude failed"]
  =/  base=jfile-detailed-result:jibb  (checked (text source) u.prep)
  ?:  ?=(%| -.base)  ~[leaf+"reference island rejected" leaf+(trip message.p.base)]
  =/  init=(unit ischeme:jibb)  (ienv-lookup:jibb %init values.iface.p.base)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.base)
  =/  base-subs=(unit ischeme:jibb)  (ienv-lookup:jibb %subs values.iface.p.base)
  ?~  init  ~[leaf+"reference init missing"]
  ?~  main  ~[leaf+"reference main missing"]
  ?~  base-subs  ~[leaf+"reference subscriptions missing"]
  ?.  =(expected-program-main (show-itype:jibb typ.u.main ~))
    ~[leaf+"reference main interface differs" leaf+(show-itype:jibb typ.u.main ~)]
  ?.  ?=(~ vars.u.main)  ~[leaf+"reference main is not closed"]
  =/  generic-result=jfile-detailed-result:jibb  (checked (text generic) u.prep)
  ?:  ?=(%| -.generic-result)  ~[leaf+"inferred init sample rejected" leaf+(trip message.p.generic-result)]
  =/  generic-init=(unit ischeme:jibb)  (ienv-lookup:jibb %init values.iface.p.generic-result)
  =/  generic-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.generic-result)
  ?~  generic-init  ~[leaf+"inferred init missing"]
  ?~  generic-main  ~[leaf+"inferred main missing"]
  ?.  =((show-itype:jibb typ.u.generic-init ~) "$-(A [A [@t (unit @t)]])")
    ~[leaf+"inferred init principal type differs: {(show-itype:jibb typ.u.generic-init ~)}"]
  ?.  ?=([@ ~] vars.u.generic-init)
    ~[leaf+"inferred init did not generalize its input"]
  ?.  =((canonical-itype:jibb typ.u.main vars.u.main) (canonical-itype:jibb typ.u.generic-main vars.u.generic-main))
    ~[leaf+"inferred init changed main interface"]
  =/  library=jfile-detailed-result:jibb  (checked (text no-main) u.prep)
  ?:  ?=(%| -.library)  ~[leaf+"no-main program library rejected" leaf+(trip message.p.library)]
  ?^  (ienv-lookup:jibb %main values.iface.p.library)  ~[leaf+"library acquired a main"]
  =/  direct=(unit ischeme:jibb)  (ienv-lookup:jibb %direct values.iface.p.library)
  ?~  direct  ~[leaf+"program-valued library definition missing"]
  ?.  =((canonical-itype:jibb typ.u.main vars.u.main) (canonical-itype:jibb typ.u.direct vars.u.direct))
    ~[leaf+"program-valued library interface differs"]
  =/  subs-result=jfile-detailed-result:jibb  (checked (text subs) u.prep)
  ?:  ?=(%| -.subs-result)  ~[leaf+"unannotated no-subscriptions gate rejected" leaf+(trip message.p.subs-result)]
  =/  actual-subs=(unit ischeme:jibb)  (ienv-lookup:jibb %subs values.iface.p.subs-result)
  =/  subs-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.subs-result)
  ?~  actual-subs  ~[leaf+"unannotated subscriptions missing"]
  ?~  subs-main  ~[leaf+"subscriptions main missing"]
  ?.  ?=([@ ~] vars.u.actual-subs)  ~[leaf+"unannotated subscriptions did not generalize its sample"]
  ?.  ?=(%fn -.typ.u.actual-subs)  ~[leaf+"unannotated subscriptions is not a gate"]
  ?.  ?=(%var -.sample.typ.u.actual-subs)  ~[leaf+"unannotated subscriptions sample is not generic"]
  ?.  =(id.sample.typ.u.actual-subs i.vars.u.actual-subs)  ~[leaf+"subscriptions quantified a different variable"]
  ?.  ?=(%fn -.typ.u.base-subs)  ~[leaf+"reference subscriptions is not a gate"]
  ?.  =(product.typ.u.base-subs product.typ.u.actual-subs)
    ~[leaf+"unannotated subscriptions result differs"]
  ?.  =((canonical-itype:jibb typ.u.main vars.u.main) (canonical-itype:jibb typ.u.subs-main vars.u.subs-main))
    ~[leaf+"unannotated subscriptions changed main interface"]
  ~
++  test-program-gate-alias
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude failed"]
  =/  result=jfile-detailed-result:jibb  (checked (text gate-alias) u.prep)
  ?:  ?=(%| -.result)  ~[leaf+"gate alias rejected" leaf+(trip message.p.result)]
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.result)
  ?~  main  ~[leaf+"alias main missing"]
  ?.  ?=(~ vars.u.main)  ~[leaf+"alias main is not closed"]
  ?.  =(expected-program-main (show-itype:jibb typ.u.main ~))
    ~[leaf+"gate alias changed the published program type" leaf+(show-itype:jibb typ.u.main ~)]
  ~

--
