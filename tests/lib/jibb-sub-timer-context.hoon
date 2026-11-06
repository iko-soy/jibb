::  A heterogeneous subscription list supplies context to a nested timer gate.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-sub-timer-context
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ msg' '  [%got value=@t]' '  %other' '++ subs |= [model=@ud req=(ask msg)]' '  ^- (list (sub msg))' '  ~[[%every ~s1 |=(now=@da %other)] [%watch req]]'])
  =/  at=path  /tests/sub-timer-context/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)
    =/  details=@t  (golden-types-with-prepared-prelude:jibb at source ~ ~ ~ prepared)
    ~[leaf+"timer list was rejected: {(trip message.p.result)}\0a{(trip details)}"]
  ~
--
