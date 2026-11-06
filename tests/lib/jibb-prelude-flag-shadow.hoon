::  Prelude names cannot be rebound by an unused local module mold.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-prelude-flag-shadow
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/flag-shadow/jibb
  =/  src=@t  '+$ flag ?\0a++ value 1\0a'
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)  ~[leaf+"prelude flag shadow was accepted"]
  =/  expected=@t  'definition `flag` shadows a prelude name\0a/tests/flag-shadow.jibb:1:1: conflicting definition\0a+$ flag ?\0a^\0a/lib/jibb/prelude.jibb:85:1: prelude declaration\0a+$ flag ?\0a^'
  ?.  =(expected message.p.result)  ~[leaf+"prelude flag shadow diagnostic differed" leaf+(trip message.p.result)]
  ~
--
