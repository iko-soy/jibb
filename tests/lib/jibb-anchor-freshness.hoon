/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-generic-closed-result-independent
  ^-  tang
  =/  src=@t  '++ fixed |= x=A [1 2]\0a++ left ^- [a=@ud b=@ud] (fixed "text")\0a++ right ^- [c=@ud d=@ud] (fixed ~zod)\0a'
  =/  at=path  /tests/anchor-freshness/jibb
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"independent generic calls were rejected" leaf+(trip message.p.result)]
  =/  left=(unit ischeme:jibb)  (ienv-lookup:jibb %left values.iface.p.result)
  =/  right=(unit ischeme:jibb)  (ienv-lookup:jibb %right values.iface.p.result)
  ?~  left  ~[leaf+"left missing"]
  ?~  right  ~[leaf+"right missing"]
  =/  l=(unit itype:jibb)  (scheme-display-type:jibb u.left)
  =/  r=(unit itype:jibb)  (scheme-display-type:jibb u.right)
  ?~  l  ~[leaf+"left did not resolve"]
  ?~  r  ~[leaf+"right did not resolve"]
  ?.  =((show-itype:jibb u.l ~) "[a=@ud b=@ud]")  ~[leaf+"left result faces changed" leaf+(show-itype:jibb u.l ~)]
  ?.  =((show-itype:jibb u.r ~) "[c=@ud d=@ud]")  ~[leaf+"right result faces changed" leaf+(show-itype:jibb u.r ~)]
  ~
++  test-imported-generic-result-independent
  ^-  tang
  =/  base=@t  '++ fixed |= x=A [1 2]\0a++ copy-fixed fixed\0a'
  =/  src=@t  '/= source /tests/source\0a++ left ^- [a=@ud b=@ud] (copy-fixed.source "text")\0a++ right ^- [c=@ud d=@ud] (copy-fixed.source ~zod)\0a'
  =/  at=path  /tests/anchor-import/jibb
  =/  modules=jbundle:jibb  ~[[/tests/source/jibb base]]
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"independent imported calls were rejected" leaf+(trip message.p.result)]
  =/  left=(unit ischeme:jibb)  (ienv-lookup:jibb %left values.iface.p.result)
  =/  right=(unit ischeme:jibb)  (ienv-lookup:jibb %right values.iface.p.result)
  ?~  left  ~[leaf+"left missing"]
  ?~  right  ~[leaf+"right missing"]
  =/  l=(unit itype:jibb)  (scheme-display-type:jibb u.left)
  =/  r=(unit itype:jibb)  (scheme-display-type:jibb u.right)
  ?~  l  ~[leaf+"left did not resolve"]
  ?~  r  ~[leaf+"right did not resolve"]
  ?.  =((show-itype:jibb u.l ~) "[a=@ud b=@ud]")  ~[leaf+"imported left result faces changed" leaf+(show-itype:jibb u.l ~)]
  ?.  =((show-itype:jibb u.r ~) "[c=@ud d=@ud]")  ~[leaf+"imported right result faces changed" leaf+(show-itype:jibb u.r ~)]
  ~
++  test-generic-mapped-results-independent
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  src=@t  '++ fixed |= x=A [1 2]\0a++ left ^- (list [a=@ud b=@ud]) (turn ~["text"] fixed)\0a++ right ^- (list [c=@ud d=@ud]) (turn ~[~zod] fixed)\0a'
  =/  at=path  /tests/anchor-mapped/jibb
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.result)  ~[leaf+"independent mapped calls were rejected" leaf+(trip message.p.result)]
  =/  left=(unit ischeme:jibb)  (ienv-lookup:jibb %left values.iface.p.result)
  =/  right=(unit ischeme:jibb)  (ienv-lookup:jibb %right values.iface.p.result)
  ?~  left  ~[leaf+"left missing"]
  ?~  right  ~[leaf+"right missing"]
  =/  l=(unit itype:jibb)  (scheme-display-type:jibb u.left)
  =/  r=(unit itype:jibb)  (scheme-display-type:jibb u.right)
  ?~  l  ~[leaf+"left did not resolve"]
  ?~  r  ~[leaf+"right did not resolve"]
  ?.  =((show-itype:jibb u.l ~) "(list [a=@ud b=@ud])")  ~[leaf+"first mapped result changed" leaf+(show-itype:jibb u.l ~)]
  ?.  =((show-itype:jibb u.r ~) "(list [c=@ud d=@ud])")  ~[leaf+"second mapped result changed" leaf+(show-itype:jibb u.r ~)]
  ~
--
