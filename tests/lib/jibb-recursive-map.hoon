/+  jibb
|%
++  test-recursive-map
  ^-  tang
  =/  tests=(list [name=@t node=* good=?])
    :~  ['valid' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %notes %node]]]]]] &]
        ['wrong-module' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %other %node]]]]]] |]
        ['wrong-name' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %notes %other]]]]]] |]
        ['malformed-key' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%gate ~] [%ref %notes %node]]]]]] |]
        ['malformed-reference' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %notes]]]]]] |]
        ['one-argument' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%ref %notes %node]]]]]] |]
        ['three-arguments' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %notes %node] [%atom %t ~]]]]]] |]
        ['possible-overlap' [%fork ~[[%atom %n [~ 0]] [%apply %map ~[[%atom %t ~] [%ref %notes %node]]]]] |]
        ['same-tag-overlap' [%fork ~[[%cell [%atom %tas [~ %object]] [%atom %ud ~]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %notes %node]]]]]] |]
        ['no-recursion' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%atom %ud ~]]]]]] |]
    ==
  =/  bad=(list [name=@t node=* good=?])
    %+  skim  tests
    |=  t=[name=@t node=* good=?]
    =/  got=(unit itype:jibb)
      (find-imported-mold:jibb %notes %node ~[[%notes %node [%& node.t]]] ~[%notes])
    =/  yes=?  ?=([~ [%recursive *]] got)
    !=(yes good.t)
  %+  turn  bad
  |=  t=[name=@t node=* good=?]
  leaf+"recursive map {(trip name.t)} had wrong result"

++  test-standard-origin
  ^-  tang
  =/  standard=*
    [%named %$ %node [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %$ %node]]]]]]]
  =/  ordinary=*
    [%named %zuse %node [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %object]] [%apply %map ~[[%atom %t ~] [%ref %zuse %node]]]]]]]
  =/  a=(unit itype:jibb)  (import-to-itype:jibb standard)
  =/  b=(unit itype:jibb)  (import-to-itype:jibb ordinary)
  ?.  ?=([~ [%recursive %$ %node *]] a)  ~[leaf+"standard origin rejected"]
  ?.  ?=([~ [%recursive %zuse %node *]] b)  ~[leaf+"ordinary origin rejected"]
  =/  fit=ifit:jibb  (itype-fit:jibb u.a u.b ~ 0)
  ?:  ?=(%ok -.fit)  ~[leaf+"standard and module origins collided"]
  ~

--
