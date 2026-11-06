/+  jibb
|%
++  test-private-proof-not-noun-shape
  ^-  tang
  =/  atom=itype:jibb  [%refined [%atom %ud]]
  =/  cell=itype:jibb  [%refined [%cell [%atom %ud] [%atom %t]]]
  ?.  =(%unknown (diagnostic-noun-shape:jibb atom ~ 100))  ~[leaf+"private atom evidence narrowed the public noun"]
  ?.  =(%unknown (diagnostic-noun-shape:jibb cell ~ 100))  ~[leaf+"private cell evidence narrowed the public noun"]
  =/  inhabited=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb atom ~ ~ 100)
  ?.  ?=([~ %unknown *] inhabited)  ~[leaf+"private evidence became an ordinary inhabitance proof"]
  ?^  (itype-gate-free-form:jibb atom ~ 100)  ~[leaf+"private atom evidence proved public noun gate-free"]
  ?^  (rg-gate-free-form:jibb atom ~ ~ 100)  ~[leaf+"recursive gate-free proof inspected private evidence"]
  ~
--
