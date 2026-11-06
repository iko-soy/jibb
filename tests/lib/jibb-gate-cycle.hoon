/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  check
  |=  [src=@t reference=tape values=(list term) molds=(list term) prelude=(unit ifile:jibb)]
  ^-  tang
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] values molds ~ prelude)
  ?:  ?=(%& -.got)  ~[leaf+"recursive value was accepted"]
  =/  text=tape  (trip message.p.got)
  ?.  (contains text "title -> title")  ~[leaf+text]
  ?.  (contains text "/ui/cycle.jibb:1:4: definition in cycle")  ~[leaf+text]
  ?.  (contains text reference)  ~[leaf+text]
  ~
++  test-call-cycles
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  cases=(list [src=@t reference=tape])
    :~  ['++ title (trim title)\0a' "/ui/cycle.jibb:1:16: `title` depends on `title` here"]
        ['++ title ^- @t (trim title)\0a' "/ui/cycle.jibb:1:22: `title` depends on `title` here"]
    ==
  |-  ^-  tang
  ?~  cases  ~
  =/  c=[src=@t reference=tape]  i.cases
  =/  known=tang  (check src.c reference.c values.u.prep molds.u.prep `iface.u.prep)
  ?^  known  known
  =/  unknown=tang  (check src.c reference.c ~ ~ ~)
  ?^  unknown  unknown
  $(cases t.cases)
--
