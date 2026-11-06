/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  check
  |=  [source=@t expected=tape]
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /tests/failed-gate/jibb source ~ ~ ~ ~[/tests/failed-gate/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)  ~[leaf+"failed gate was exported successfully"]
  =/  actual=tape  (trip message.p.result)
  ?.  =(expected (scag (lent expected) actual))  ~[leaf+"unexpected failure owner or reason" leaf+actual]
  ~
++  test-consumer-context
  ^-  tang
  =/  source=@t  '++ first ~\0a++ broken |= x=(unit @t) ^- @ud "wrong"\0a++ consume |= [x=(unit @t) f=$-((unit @t) @ud)] (f x)\0a++ result (consume first broken)\0a'
  (check source "++ broken:")
++  test-unrelated-open
  ^-  tang
  =/  source=@t  '++ first %orphan\0a++ broken |= x=(unit @t) ^- @ud "wrong"\0a++ result [first broken]\0a'
  (check source "++ first: nothing fixes the union of %orphan")
++  test-generic-sample
  ^-  tang
  =/  source=@t  '++ broken |= x=A ^- @ud "wrong"\0a++ result broken\0a'
  (check source "++ broken:")
++  test-failed-result
  ^-  tang
  =/  source=@t  '++ broken |= x=@t ^- @ud "wrong"\0a++ result (broken "input")\0a'
  (check source "++ broken:")
--
