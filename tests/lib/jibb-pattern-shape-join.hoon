/+  jibb
|%
++  test-pattern-shape-conflict
  ^-  tang
  =/  text=itype:jibb  [%atom %t]
  =/  pair=itype:jibb  [%cell [%atom %t] [%atom %ud]]
  ?.  (itype-shape-mismatch:jibb text pair ~)  ~[leaf+"inhabited atom and cell conflict was missed"]
  ?.  (itype-shape-mismatch:jibb pair text ~)  ~[leaf+"reversed atom and cell conflict was missed"]
  =/  empty-pair=itype:jibb  [%cell [%empty ~] [%atom %ud]]
  ?:  (itype-shape-mismatch:jibb text empty-pair ~)  ~[leaf+"uninhabited cell was declared incompatible"]
  =/  mixed=itype:jibb  [%union ~[text pair] ~ ~ ~]
  ?:  (itype-shape-mismatch:jibb mixed pair ~)  ~[leaf+"overlapping union was declared incompatible"]
  ?:  (itype-shape-mismatch:jibb [%var 7] pair ~)  ~[leaf+"open type was declared incompatible"]
  =/  left=itype:jibb  [%cell [%const [%term %tas %left '%left']] [%atom %ud]]
  =/  right=itype:jibb  [%cell [%const [%term %tas %right '%right']] [%atom %ud]]
  ?:  (itype-shape-mismatch:jibb left right ~)  ~[leaf+"tagged cells were diagnosed before later union context"]
  ~
--
