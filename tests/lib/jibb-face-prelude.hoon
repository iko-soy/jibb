::  Generic prelude calls accept faced gate samples.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-face-prelude
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  src=@t
    (of-wain:format ~['++ lt-a |= [a=@ud b=@ud] (lth a b)' '++ search (hunt lt-a `1 `2)' '++ add-f |= [a=@ud b=@ud] (add a b)' '++ total (roll ~[1 2] 0 add-f)'])
  =/  at=path  /ui/face-test/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)
    =/  report=@t  (golden-types-with-prepared-prelude:jibb at src ~ ~ ~ prepared)
    ~[leaf+(trip message.p.result) leaf+(trip report)]
  ~
++  test-list-tag-context
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  src=@t
    (of-wain:format ~['+$ msg' '  %add' '  %sub' '++ values ~[%add %sub]' '++ use ^- (list msg) values'])
  =/  at=path  /ui/list-test/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  values=(unit ischeme:jibb)  (ienv-lookup:jibb %values values.iface.p.result)
  ?~  values  ~[leaf+"module did not export values"]
  ?.  ?=([%collection %list [[%union *] ~]] typ.u.values)
    ~[leaf+"list elements did not retain their union"]
  ~
--
