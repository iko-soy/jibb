/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  hoon  %jibb  /lib/jibb/groups/hoon/jibb
/*  bit  %jibb  /lib/jibb/groups/bit/jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-map-and-private-group
  ^-  tang
  =/  groups=(list iprelude-group-source:jibb)
    ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb bit]]
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal groups)
  ?~  prepared  ~[leaf+"map and private bit groups did not prepare together"]
  =/  code=@t  '++ invert not.bit\0a++ map-id |= value=(map @ud @t) value\0a'
  =/  result=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb code ~ ~ ~ prepared)
  ?.  &((contains (trip result) "++ invert: $-([@ [@ @]] @)") (contains (trip result) "++ map-id: $-((map @ud @t) (map @ud @t))"))
    ~[leaf+"map or private bit group lost its type" leaf+(trip result)]
  ~
--
