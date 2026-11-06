::  The public prelude exports max and a module can call it.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-max
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  ?~  (ienv-lookup:jibb %max values.iface.u.prepared)
    ~[leaf+"max is missing from the prelude"]
  =/  src=@t
    '++ maximum (max 1 2)\0a++ clamp |= [lo=A hi=A n=A]\0a  ?- (gth n hi)\0a    %.y hi\0a    %.n (max lo n)\0a'
  =/  at=path  /ui/max-test/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  ~
--
