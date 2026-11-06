/+  jibb
|%
++  test-seal-graph
  ^-  tang
  =/  origin=[at=path name=term]  [/lib/jibb/primitives/jibb %seal]
  =/  seal=itype:jibb  [%opaque origin `'element' ~[[%var 0]] [%fn [%var 0] [%atom %ud]]]
  =/  node=(unit gnode:jibb)  (rg-type-node:jibb seal ~[0])
  ?~  node  ~[leaf+"could not encode a seal in a recursive type graph"]
  ?.  ?=(%sealed -.u.node)  ~[leaf+"graph lost the private seal"]
  =/  env=(list [name=@t val=itype:jibb])  ~[['0' [%atom %t]]]
  =/  lowered=(unit itype:jibb)  (rg-lower:jibb u.node ~ /tests/element/jibb env)
  ?~  lowered  ~[leaf+"could not lower a sealed graph node"]
  =/  expected=itype:jibb  [%opaque origin `'element' ~[[%atom %t]] [%fn [%atom %t] [%atom %ud]]]
  ?.  =(u.lowered expected)  ~[leaf+"lowering lost the seal origin, argument, or payload"]
  =/  projected=(unit upat:jibb)  (rg-project:jibb u.node ~ ~ 256)
  ?.  =(projected `[%unknown ~])  ~[leaf+"recursive coverage inspected private seal contents"]
  =/  free=(unit igf-form:jibb)  (rg-gate-free-form:jibb u.lowered ~ ~ 256)
  ?^  free  ~[leaf+"recursive gate freedom inspected a sealed type"]
  =/  forged=itype:jibb  [%opaque [/lib/other/jibb %seal] `'element' ~[[%atom %t]] [%fn [%atom %t] [%atom %ud]]]
  =/  fit=ifit:jibb  (itype-fit:jibb forged u.lowered ~ 2)
  ?:  ?=(%ok -.fit)  ~[leaf+"graph lowering conflated distinct private origins"]
  ~
--
