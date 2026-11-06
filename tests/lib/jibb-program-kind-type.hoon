::  Program kind checks use the inferred main type for data and model.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-program-kind-type
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  program=(unit ischeme:jibb)  (find-jibb-mold:jibb %program iface.u.prepared)
  ?~  program  ~[leaf+"program mold is missing"]
  =/  data=itype:jibb  [%atom %ud]
  =/  model=itype:jibb  [%cell [%face %count [%atom %ud]] [%face %label [%atom %t]]]
  =/  message=itype:jibb  [%atom %t]
  =/  checked=(unit itype:jibb)  (template-apply:jibb u.program ~[data model message])
  ?~  checked  ~[leaf+"program type did not instantiate"]
  ?.  (program-type-closed:jibb ~[[%main [u.checked ~ ~]]] `iface.u.prepared)
    ~[leaf+"closed program type was not recognized"]
  =/  graphed=ischeme:jibb  [[%var 900] ~ `[~[[900 u.checked]] ~]]
  ?.  (program-type-closed:jibb ~[[%main graphed]] `iface.u.prepared)
    ~[leaf+"closed graph-backed program was not recognized"]
  =/  gate=itype:jibb  [%fn [%atom %ud] [%atom %ud]]
  =/  bad-data=(unit itype:jibb)  (template-apply:jibb u.program ~[[%cell [%face %field gate] data] model message])
  ?~  bad-data  ~[leaf+"program with a data gate did not instantiate"]
  ?:  (program-type-closed:jibb ~[[%main [u.bad-data ~ ~]]] `iface.u.prepared)
    ~[leaf+"a gate in program data passed the type check"]
  =/  bad-model=(unit itype:jibb)  (template-apply:jibb u.program ~[data [%cell [%face %callback gate] model] message])
  ?~  bad-model  ~[leaf+"program with a model gate did not instantiate"]
  ?:  (program-type-closed:jibb ~[[%main [u.bad-model ~ ~]]] `iface.u.prepared)
    ~[leaf+"a gate in the program model passed the type check"]
  ~
--
