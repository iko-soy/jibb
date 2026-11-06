/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  run
  |=  [body=@t valid=?]
  ^-  tang
  =/  prep=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  src=@t  (of-wain:format ~['+$ event %tick' '++ identity |= value=A value' (cat 3 '++ delayed ' body) '++ use ^- (list (sub event)) delayed'])
  =/  at=path  /tests/stream-context/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  valid
    ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
    ~
  ?:  ?=(%& -.checked)  ~[leaf+"wrong subscription event was published"]
  =/  message=tape  (trip message.p.checked)
  ?:  (contains message "constraints could not be solved")  ~[leaf+"wrong subscription event only stalled inference"]
  ?:  (contains message "gate result does not fit its expected type")  ~
  ~[leaf+message]
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-direct
  ^-  tang
  (run '~[[%every ~s1 |=(time=@da %tick)] [%every ~s2 |=(time=@da %tick)]]' &)
++  test-identity
  ^-  tang
  (run '(identity ~[[%every ~s1 |=(time=@da %tick)] [%every ~s2 |=(time=@da %tick)]])' &)
++  test-flop
  ^-  tang
  (run '(flop ~[[%every ~s1 |=(time=@da %tick)] [%every ~s2 |=(time=@da %tick)]])' &)
++  test-wrong-event-direct
  ^-  tang
  (run '~[[%every ~s1 |=(time=@da %tock)]]' |)
++  test-wrong-event-identity
  ^-  tang
  (run '(identity ~[[%every ~s1 |=(time=@da %tock)]])' |)
++  test-wrong-event-flop
  ^-  tang
  (run '(flop ~[[%every ~s1 |=(time=@da %tock)]])' |)
--
