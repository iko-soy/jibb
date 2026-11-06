/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-forgery-paths
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/element-forgery/jibb
  =/  cases=(list [name=tape src=@t])
    :~  ["raw island" '++ forged ^- (element !!) [%island 5]\0a']
        ["raw text" '++ forged ^- (element !!) [%text "evil"]\0a']
        ["grouped raw" '++ forged ^- (element !!) ([%island 5])\0a']
        ["through identity" '++ forged ^- (element !!) (same [%island 5])\0a']
        ["unknown noun" '++ raw ^- * [5 6]\0a++ forged ^- (element !!) raw\0a']
        ["private import" '/= internal /lib/jibb/internal\0a++ forged (seal.internal 5)\0a']
        ["private primitive" '/= core /lib/jibb/primitives\0a++ forged (raw-seal.core 5)\0a']
    ==
  %+  murn  cases
  |=  case=[name=tape src=@t]
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src.case ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.checked)  `leaf+(weld name.case " was accepted")
  ~
--
