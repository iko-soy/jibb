::  List helpers are ordinary prelude definitions with reusable signatures.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %jibb  /tests/golden/types-prelude-list-edit/source/jibb
|%
++  test-prelude-list-edit
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/list-helpers/jibb
  =/  result
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  cases=(list [name=term want=itype:jibb])
    :~  [%range [%collection %list ~[[%atom %ud]]]]
        [%hex-range [%collection %list ~[[%atom %ux]]]]
        [%cut [%collection %list ~[[%atom %ud]]]]
        [%slice [%collection %list ~[[%atom %t]]]]
        [%replace [%collection %list ~[[%atom %ud]]]]
        [%insert [%collection %list ~[[%atom %t]]]]
        [%halves [%cell [%face %p [%collection %list ~[[%atom %ud]]]] [%face %q [%collection %list ~[[%atom %ud]]]]]]
        [%split-text [%cell [%face %p [%collection %list ~[[%atom %t]]]] [%face %q [%collection %list ~[[%atom %t]]]]]]
    ==
  |-  ^-  tang
  ?~  cases  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.cases values.iface.p.result)
  ?~  found  ~[leaf+"list helper result missing"]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  display  ~[leaf+"list helper scheme did not realize"]
  ?.  &(=((itype-slots-as-faces:jibb u.display) (itype-slots-as-faces:jibb want.i.cases)) ?=(~ vars.u.found))
    ~[leaf+"list helper result has the wrong type"]
  $(cases t.cases)
--
