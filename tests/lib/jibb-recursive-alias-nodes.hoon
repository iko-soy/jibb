/+  jibb
|%
++  test-alias-template-substitution
  ^-  tang
  =/  key=gkey:jibb  [/ui/base/jibb *span:jibb %rbranch]
  =/  graph=(map gkey:jibb gdef:jibb)  *(map gkey:jibb gdef:jibb)
  =/  typ=itype:jibb  [%mrec /ui/base/jibb *span:jibb %rbranch `'rbranch' graph ~[[%var 1] [%var 0]]]
  =/  node=(unit gnode:jibb)  (rg-type-node:jibb typ ~[0 1])
  ?~  node  ~[leaf+"cannot represent imported alias"]
  =/  entry=gentry:jibb  [%template ~['0' '1'] u.node]
  =/  applied=(unit gnode:jibb)  (rg-apply-entry:jibb entry ~[[%atom %ud] [%atom %t]])
  ?~  applied  ~[leaf+"cannot apply imported alias"]
  ?.  =(u.applied [%ref key ~[[%atom %t] [%atom %ud]]])
    ~[leaf+"alias parameter order or source identity changed"]
  ?^  (rg-apply-entry:jibb entry ~[[%atom %ud]])  ~[leaf+"bad alias arity accepted"]
  ~
++  test-alias-face-provenance
  ^-  tang
  =/  graph=(map gkey:jibb gdef:jibb)  *(map gkey:jibb gdef:jibb)
  =/  original=itype:jibb  [%cell [%slot %x [%atom %ud]] [%face %count [%atom %ud]]]
  =/  node=(unit gnode:jibb)  (rg-type-node:jibb original ~)
  ?~  node  ~[leaf+"imported face type cannot be represented"]
  =/  lowered=(unit itype:jibb)  (rg-lower:jibb u.node graph /ui/base/jibb ~)
  ?~  lowered  ~[leaf+"imported face type cannot be lowered"]
  ?.  =(original u.lowered)  ~[leaf+"slot and value faces became indistinguishable"]
  ~
++  test-reachable-recursive-graph
  ^-  tang
  =/  root=gkey:jibb  [/ui/a/jibb *span:jibb %root]
  =/  child=gkey:jibb  [/ui/b/jibb *span:jibb %child]
  =/  extra=gkey:jibb  [/ui/c/jibb *span:jibb %extra]
  =/  graph=(map gkey:jibb gdef:jibb)  *(map gkey:jibb gdef:jibb)
  =.  graph  (~(put by graph) root [*span:jibb & ~ ~ [%ref child ~]])
  =.  graph  (~(put by graph) child [*span:jibb & ~ ~ [%atom %ud]])
  =.  graph  (~(put by graph) extra [*span:jibb & ~ ~ [%atom %t]])
  =/  scope=gscope:jibb  [*(map gname:jibb gentry:jibb) graph]
  =/  built=(unit (map gkey:jibb gdef:jibb))  (rg-build-graph-checked:jibb ~[root] ~ /ui/a/jibb scope 32)
  ?~  built  ~[leaf+"reachable graph failed"]
  ?~  (~(get by u.built) root)  ~[leaf+"root was lost"]
  ?~  (~(get by u.built) child)  ~[leaf+"dependency was lost"]
  ?^  (~(get by u.built) extra)  ~[leaf+"unrelated definition was retained"]
  ~
++  test-graph-proof-rejections
  ^-  tang
  =/  loop=gkey:jibb  [/tests/proof/jibb *span:jibb %loop]
  =/  missing=gkey:jibb  [/tests/proof/jibb *span:jibb %missing]
  =/  changing=gkey:jibb  [/tests/proof/jibb *span:jibb %changing]
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) loop [*span:jibb & ~ ~ [%ref loop ~]])
  ?:  (rg-certify:jibb [%ref loop ~] graph)  ~[leaf+"unproductive graph accepted"]
  ?:  (rg-certify:jibb [%ref missing ~] graph)  ~[leaf+"missing graph reference accepted"]
  ?:  (rg-certify:jibb [%ref loop ~[[%noun ~]]] graph)  ~[leaf+"wrong graph arity accepted"]
  ?:  (rg-certify:jibb [%union ~[[%atom %ud] [%atom %t]]] graph)  ~[leaf+"overlapping union accepted"]
  ?:  (rg-certify:jibb [%union ~[[%param 'A'] [%atom %t]]] graph)  ~[leaf+"unknown overlap accepted"]
  =/  changed=(map gkey:jibb gdef:jibb)
    (~(put by graph) changing [*span:jibb & ~['A'] ~ [%union ~[[%param 'A'] [%cell [%atom %ud] [%ref changing ~[[%cell [%atom %t] [%atom %ud]]]]]]]])
  ?:  (rg-certify:jibb [%ref changing ~[[%atom %t]]] changed)  ~[leaf+"changed recursive argument hid an overlap"]
  ~
++  test-prelude-list-origin
  ^-  tang
  =/  canonical=ischeme:jibb  [[%collection %list ~[[%var 0]]] ~[0] ~]
  =/  prep=ifile:jibb  *ifile:jibb
  =.  prep  prep(at /lib/jibb/prelude/jibb, molds ~[[%list canonical]])
  ?.  (rg-standard-list:jibb `prep)  ~[leaf+"checked prelude list rejected"]
  ?:  (rg-standard-list:jibb `prep(at /tests/spoof/jibb))  ~[leaf+"foreign list origin accepted"]
  =/  spoof=ifile:jibb  prep(molds ~[[%list [[%noun ~] ~ ~]]])
  ?:  (rg-standard-list:jibb `spoof)  ~[leaf+"wrong list scheme accepted"]
  ~
++  test-named-union-provenance
  ^-  tang
  =/  graph=(map gkey:jibb gdef:jibb)  *(map gkey:jibb gdef:jibb)
  =/  choice=itype:jibb
    [%union ~[[%const [%term %tas %yes '%yes']] [%const [%term %tas %no '%no']]] `[/ui/base/jibb %choice] `'choice' ~[[%atom %t] [%atom %ud]]]
  =/  node=(unit gnode:jibb)  (rg-type-node:jibb choice ~)
  ?~  node  ~[leaf+"named union could not enter a recursive graph"]
  =/  lowered=(unit itype:jibb)  (rg-lower:jibb u.node graph /ui/outer/jibb ~)
  ?~  lowered  ~[leaf+"named union could not leave a recursive graph"]
  ?.  ?=(%union -.u.lowered)  ~[leaf+"named union lost its type"]
  ?.  =(origin.u.lowered `[/ui/base/jibb %choice])  ~[leaf+"named union lost its source identity"]
  ?.  =(args.u.lowered ~[[%atom %t] [%atom %ud]])  ~[leaf+"named union lost its generic arguments"]
  ~
--
