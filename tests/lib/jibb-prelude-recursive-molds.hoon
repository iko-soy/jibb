::  Recursive prelude molds must be usable through their exported interfaces.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-prelude-recursive-molds
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  tank=(unit ischeme:jibb)  (find-jibb-mold:jibb %tank iface.u.prepared)
  ?~  tank  ~[leaf+"tank mold is not exported"]
  =/  tang-mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %tang iface.u.prepared)
  ?~  tang-mold  ~[leaf+"tang mold is not exported"]
  =/  source=@t  (of-wain:format ~['++ leaf ^- tank [%leaf ~]' '++ logs ^- tang ~[leaf]'])
  =/  file=path  /tests/prelude-recursive-molds/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  leaf-type=(unit ischeme:jibb)  (ienv-lookup:jibb %leaf values.iface.p.result)
  ?~  leaf-type  ~[leaf+"tank value was not exported"]
  =/  logs-type=(unit ischeme:jibb)  (ienv-lookup:jibb %logs values.iface.p.result)
  ?~  logs-type  ~[leaf+"tang value was not exported"]
  ~
++  test-generic-recursive-molds
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]' '++ text-empty ^- (rbranch @t @ud) %done' '++ atom-empty ^- (rbranch @p @t) %done'])
  =/  file=path  /tests/generic-recursive-molds/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  cases=(list [name=term want=tape])  ~[[%text-empty "(rbranch @t @ud)"] [%atom-empty "(rbranch @p @t)"]]
  |-  ^-  tang
  ?~  cases  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.cases values.iface.p.result)
  ?~  found  ~[leaf+"generic recursive value missing"]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  display  ~[leaf+"generic recursive value type did not realize"]
  ?.  =((show-itype:jibb u.display ~) want.i.cases)  ~[leaf+"generic recursive value has the wrong type"]
  $(cases t.cases)
--
