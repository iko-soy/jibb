/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  source
  |=  invalid=?
  ^-  @t
  %-  of-wain:format
  :~  '+$ event %tick'
      '++ seed |= datum=@ud datum'
      '++ step |= [ev=event m=@ud] [m ~]'
      '++ draw |= m=@ud (text "tick")'
      ?:(invalid '++ streams |= m=@ud ~[[%watch (pure %tick)]]' '++ streams |= m=@ud ~')
      '++ embedded (program seed step draw streams)'
      '++ copied |= xs=(list @ud)'
      '  ++ reverse-into |= args=[(list @ud) (list @ud)]'
      '    ?- args'
      '      [rest acc]'
      '        ?- rest'
      '          ~'
      '            ~& (island embedded 0)'
      '              acc'
      '          [item more] (reverse-into more [item acc])'
      '  (reverse-into xs ~)'
      '++ main (page load view)'
      '++ load |= ~ (pure ~[1 2])'
      '++ view |= xs=(list @ud)'
      '  text "{(lent (copied xs))}"'
  ==
++  check
  |=  invalid=?
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/recursive-watch/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at (source invalid) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  invalid
    ?:  ?=(%& -.checked)  ~[leaf+"recursive data abstraction lost an invalid discarded island"]
    ?.  (contains (trip message.p.checked) "watch")  ~[leaf+(trip message.p.checked)]
    ~
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  ~
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-valid-recursive-data
  ^-  tang
  (check |)
++  test-discarded-recursive-island
  ^-  tang
  (check &)
++  test-data-does-not-prove-requests
  ^-  tang
  =/  site=iav-site:jibb  [/ui/proof/jibb *span:jibb]
  =/  data=iav-value:jibb  [site %data ~]
  =/  request=iav-value:jibb  [site %request /ui/api/example/jibb %all]
  ?.  (iav-gate-free-value:jibb data 64)  ~[leaf+"data abstraction lost its absence proof"]
  ?:  (iav-gate-free-value:jibb request 64)  ~[leaf+"request evidence was treated as data"]
  =/  combined=iav-value:jibb  [site %cell data request]
  ?:  (iav-gate-free-value:jibb combined 64)  ~[leaf+"a data field erased adjacent request evidence"]
  =/  field=iav-value:jibb  (iav-axis:jibb data 6 64)
  ?.  ?=(%data -.node.field)  ~[leaf+"data projection lost its absence proof"]
  ~
++  test-finite-subscription-data
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  lines=wain
    %+  turn  (to-wain:format (source |))
    |=  line=@t
    ?:  =(line '++ streams |= m=@ud ~')
      '++ streams |= m=@ud (flop (^- (list (sub event)) ~[[%every ~s1 |=(time=@da %tick)] [%every ~s2 |=(time=@da %tick)]]))'
    line
  =/  at=path  /ui/recursive-watch/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at (of-wain:format lines) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  ~
++  test-data-growth
  ^-  tang
  =/  old=*  [%cell [%data ~] [%atom 0]]
  =/  grown=*  [%cell [%data ~] [%cell [%data ~] [%atom 0]]]
  ?.  (iav-argument-grows:jibb old grown)  ~[leaf+"growing accumulator was not abstracted"]
  =/  before=*  [%cell [%cell [%atom 1] [%atom 0]] [%atom 0]]
  =/  after=*  [%cell [%atom 0] [%cell [%atom 1] [%atom 0]]]
  ?:  (iav-argument-grows:jibb before after)  ~[leaf+"finite shrinking input was widened"]
  ?:  (iav-argument-grows:jibb old old)  ~[leaf+"unchanged argument was classified as growing"]
  ~
--
