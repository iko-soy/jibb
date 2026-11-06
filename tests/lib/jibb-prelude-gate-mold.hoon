/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-prelude-gate-mold
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  gate=(unit ischeme:jibb)  (find-jibb-mold:jibb %gate iface.u.prepared)
  ?~  gate  ~[leaf+"gate mold was not exported"]
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %mold iface.u.prepared)
  ?~  mold  ~[leaf+"mold mold was not exported"]
  =/  expected=itype:jibb  [%fn [%noun ~] [%noun ~]]
  ?.  &(?=(~ vars.u.gate) =(expected typ.u.gate) ?=(~ vars.u.mold) =(expected typ.u.mold))
    ~[leaf+"gate or mold has the wrong signature"]
  =/  src=@t  (of-wain:format ~['++ use-gate |= f=gate f' '++ use-mold |= f=mold f'])
  =/  file=path  /tests/prelude-gate-mold/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  a=(unit ischeme:jibb)  (ienv-lookup:jibb %use-gate values.iface.p.result)
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %use-mold values.iface.p.result)
  ?~  a  ~[leaf+"gate user missing"]
  ?~  b  ~[leaf+"mold user missing"]
  =/  da=(unit itype:jibb)  (scheme-display-type:jibb u.a)
  =/  db=(unit itype:jibb)  (scheme-display-type:jibb u.b)
  ?~  da  ~[leaf+"gate user type did not realize"]
  ?~  db  ~[leaf+"mold user type did not realize"]
  ?.  =((show-itype:jibb u.da ~) "$-($-(* *) $-(* *))")  ~[leaf+"gate user has the wrong type"]
  ?.  =((show-itype:jibb u.db ~) "$-($-(* *) $-(* *))")  ~[leaf+"mold user has the wrong type"]
  ~
--
