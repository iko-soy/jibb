/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
++  test-nested-model-gate
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  at=path  /ui/probe/jibb
  =/  src=@t  '+$ message\0a  %start\0a  %stop\0a+$ model [count=@ud inner=[cb=(list $-(@t @t))]]\0a++ main (program init update view subs)\0a++ init |= input=@t ^- model [count=0 inner=[cb=~]]\0a++ update |= [msg=message state=model]\0a  ^- [model (list (cmd message))] [state ~]\0a++ view |= state=model ^- (element message) (text "view")\0a++ subs |= state=model ^- (list (sub message)) ~\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.result)  ~[leaf+"gate-bearing island model accepted"]
  =/  message=tape  (trip message.p.result)
  ?.  (contains message "island model field `inner.cb` contains a gate")  ~[leaf+"wrong nested model error" leaf+message]
  ?.  (contains message "/ui/probe.jibb:4:28: gate-bearing island type")  ~[leaf+"nested model field site missing" leaf+message]
  ?.  (contains message "/ui/probe.jibb:5:10: island main")  ~[leaf+"program site missing" leaf+message]
  ~
++  test-singleton-list-record
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  at=path  /tests/singleton-list/jibb
  =/  src=@t  '++ data ^- [cb=(list $-(@t @t))] [cb=~]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.result)  ~[leaf+"valid singleton list record rejected" leaf+(trip message.p.result)]
  ~
++  test-tuple-cast-field-error
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  at=path  /ui/probe/jibb
  =/  src=@t  '+$ model [xs=(list @t) draft=@t error=(unit @t)]\0a+$ message\0a  %start\0a  %stop\0a++ main (program init update view subs)\0a++ init |= ts=(list @t) ^- model [ts ~zod ~]\0a++ update |= [msg=message state=model]\0a  ^- [model (list (cmd message))] [state ~]\0a++ view |= state=model ^- (element message) (text "view")\0a++ subs |= state=model ^- (list (sub message)) ~\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.result)  ~[leaf+"bad field accepted"]
  =/  message=tape  (trip message.p.result)
  ?.  (contains message "cast field `draft` does not fit")  ~[leaf+"wrong field diagnostic" leaf+message]
  ?.  (contains message "/ui/probe.jibb:1:24: expected field")  ~[leaf+"field declaration site missing" leaf+message]
  ?.  (contains message "/ui/probe.jibb:6:38: expression")  ~[leaf+"bad value site missing" leaf+message]
  ~
++  test-singleton-face-mismatch
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  at=path  /tests/singleton-mismatch/jibb
  =/  src=@t  '++ data ^- [cb=(list @t)] [wrong=~]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.result)  ~[leaf+"different record faces accepted"]
  =/  message=tape  (trip message.p.result)
  ?.  (contains message "cast mold and expression type do not unify")  ~[leaf+"wrong face-mismatch diagnostic" leaf+message]
  ?.  (contains message "/tests/singleton-mismatch.jibb:1:12:")  ~[leaf+"expected record site missing" leaf+message]
  ?.  (contains message "/tests/singleton-mismatch.jibb:1:27:")  ~[leaf+"actual record site missing" leaf+message]
  ~
--
