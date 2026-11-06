/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-cell-guarded-graph
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  key=gkey:jibb  [/tests/tree/jibb site %tree]
  =/  body=gnode:jibb  [%cell [%ref key ~] [%atom %t]]
  =/  graph=(map gkey:jibb gdef:jibb)  (~(put by *(map gkey:jibb gdef:jibb)) key [site & ~ ~ body])
  ?.  (rg-certify:jibb [%ref key ~] graph)  ~[leaf+"structurally recursive cell was rejected"]
  ?.  !=((rg-productive:jibb [%ref key ~] graph *(set gkey:jibb) 128) %yes)  ~[leaf+"test unexpectedly has a finite productivity proof"]
  =/  typ=itype:jibb  [%mrec /tests/tree/jibb site %tree `%tree graph ~]
  =/  inhabited=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb typ ~ ~ 128)
  =/  claims-inhabited=?  ?~(inhabited | =(%yes result.u.inhabited))
  ?:  claims-inhabited  ~[leaf+"recursive empty domain was declared inhabited"]
  =/  bad-graph=(map gkey:jibb gdef:jibb)  (~(put by *(map gkey:jibb gdef:jibb)) key [site & ~ ~ [%ref key ~]])
  ?:  (rg-certify:jibb [%ref key ~] bad-graph)  ~[leaf+"unguarded alias cycle was accepted"]
  ?:  (rg-contractive:jibb [%ref key ~] graph *(map gkey:jibb @ud) 0 0)  ~[leaf+"guard proof ignored its budget"]
  =/  other=gkey:jibb  [/tests/tree/jibb site %other]
  =/  nested=(map gkey:jibb gdef:jibb)  (~(put by graph) other [site & ~ ~ [%ref other ~]])
  =.  nested  (~(put by nested) key [site & ~ ~ [%cell [%ref other ~] [%ref key ~]]])
  ?:  (rg-certify:jibb [%ref key ~] nested)  ~[leaf+"a cell outside an unguarded inner cycle was treated as a guard"]
  =/  foreign=gnode:jibb  [%ref [/tests/foreign/jibb site %missing] ~]
  ?:  (rg-certify:jibb foreign graph)  ~[leaf+"a missing graph origin was accepted"]
  ?:  (rg-certify:jibb [%ref key ~[[%atom %t]]] graph)  ~[leaf+"a recursive reference with wrong arity was accepted"]
  =/  gate=(map gkey:jibb gdef:jibb)  (~(put by graph) key [site & ~ ~ [%fn [%atom %t] [%ref key ~]]])
  ?.  (rg-certify:jibb [%ref key ~] gate)  ~[leaf+"a contractive recursive gate mold was rejected"]
  ~
++  test-empty-recursive-modules
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t  '+$ recursive [next=recursive value=@t]\0a+$ loop |$ [A] [value=A rest=(loop A)]\0a+$ gate-loop $-(@t gate-loop)\0a++ keep-rec |= x=recursive x\0a++ keep-loop |= x=(loop @t) x\0a++ keep-gate-loop |= x=gate-loop x\0a'
  =/  file=path  /tests/recursive-empty/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+"guarded recursive molds were rejected" leaf+(trip message.p.result)]
  =/  first=(unit ischeme:jibb)  (find-jibb-mold:jibb %recursive iface.p.result)
  =/  second=(unit ischeme:jibb)  (find-jibb-mold:jibb %loop iface.p.result)
  ?~  first  ~[leaf+"recursive mold was not exported"]
  ?~  second  ~[leaf+"generic recursive mold was not exported"]
  ?.  ?=(%mrec -.typ.u.first)  ~[leaf+"recursive nominal identity was erased"]
  =/  applied=(unit itype:jibb)  (template-apply:jibb u.second ~[[%atom %t]])
  ?~  applied  ~[leaf+"generic recursive mold did not instantiate"]
  ?.  ?=(%mrec -.u.applied)  ~[leaf+"generic recursive nominal identity was erased"]
  =/  overlap=@t  '+$ bad\0a  %done\0a  [%node next=bad]\0a  [%node next=bad]\0a'
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file overlap ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"overlapping recursive cases were accepted"]
  =/  invalid-source=@t  '+$ recursive [next=recursive value=@t]\0a++ bad ^- recursive [~ "x"]\0a'
  =/  invalid=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file invalid-source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.invalid)  ~[leaf+"a finite value was fabricated for an empty recursive domain"]
  =/  expected=@t  '++ bad: recursive constructor does not fit its mold\0a/tests/recursive-empty.jibb:2:11: recursive mold has type recursive\0a++ bad ^- recursive [~ "x"]\0a          ^\0a/tests/recursive-empty.jibb:2:22: constructor has type A; A remains unresolved for tag `~`\0a++ bad ^- recursive [~ "x"]\0a                     ^'
  ?.  =(expected message.p.invalid)  ~[leaf+"invalid recursive value lost its diagnostic sites" leaf+(trip message.p.invalid)]
  ~
--
