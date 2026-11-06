::  Public arithmetic gates preserve auras and reject loobean arithmetic.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %jibb  /tests/golden/types-prelude-recursive-arithmetic/source/jibb
/*  loobean  %txt  /tests/type-prelude-arithmetic/loobean/txt
/*  loobean-expected  %txt  /tests/type-prelude-arithmetic/loobean-expected/txt
|%
++  test-prelude-arithmetic
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/helpers/jibb
  =/  result
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  cases=(list [name=term want=itype:jibb])
    :~  [%minimum [%atom %ud]]
        [%difference [%atom %ud]]
        [%product [%atom %ud]]
        [%hex-product [%atom %ux]]
        [%duration-difference [%atom %dr]]
        [%bit-minimum [%flag ~]]
    ==
  =/  errors=tang
    |-  ^-  tang
    ?~  cases  ~
    =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.cases values.iface.p.result)
    ?~  found  ~[leaf+"arithmetic call result missing"]
    ?.  &(=(typ.u.found want.i.cases) ?=(~ vars.u.found))
      ~[leaf+"arithmetic result lost its aura"]
    $(cases t.cases)
  ?^  errors  errors
  =/  scale=(unit ischeme:jibb)  (ienv-lookup:jibb %scale values.iface.p.result)
  ?~  scale  ~[leaf+"generic scale missing"]
  ?.  ?=([@ ~] vars.u.scale)  ~[leaf+"scale did not stay generic"]
  =/  a=itype:jibb  [%rvar i.vars.u.scale]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.scale)
  ?~  display  ~[leaf+"scale scheme did not realize"]
  ?.  =(u.display [%fn [%cell a a] a])
    ~[leaf+"scale lost its shared arithmetic constraint"]
  =/  invalid=@t  (of-wain:format loobean)
  =/  rejected
    (infer-jibb-file-detailed:jibb file invalid ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.rejected)  ~[leaf+"loobean multiplication was accepted"]
  ?.  =((to-wain:format (cat 3 message.p.rejected '\0a')) loobean-expected)
    ~[leaf+"loobean arithmetic diagnostic differs from expected"]
  ~
--
