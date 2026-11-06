::  List helpers are ordinary prelude definitions with reusable signatures.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %jibb  /tests/golden/types-prelude-list-index-sort/source/jibb
|%
++  test-prelude-lists
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/list-helpers/jibb
  =/  result
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  cases=(list [name=term want=itype:jibb])
    :~  [%index-number [%atom %ud]]
        [%index-text [%atom %t]]
        [%prefix [%collection %list ~[[%atom %t]]]]
        [%suffix [%collection %list ~[[%atom %t]]]]
        [%repeated [%collection %list ~[[%atom %t]]]]
        [%ascending [%collection %list ~[[%atom %ud]]]]
        [%descending [%collection %list ~[[%atom %ud]]]]
        [%empty [%collection %list ~[[%atom %ud]]]]
    ==
  |-  ^-  tang
  ?~  cases  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.cases values.iface.p.result)
  ?~  found  ~[leaf+"list helper result missing"]
  ?.  &(=(typ.u.found want.i.cases) ?=(~ vars.u.found))
    ~[leaf+"list helper result has the wrong type"]
  $(cases t.cases)
--
