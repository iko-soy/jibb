::  A realistic view reaches template emission through the full checker
::  and authenticated linked constructors, including opaque element holes.
/+  jibb, jibb-core, jibb-js, jibb-lower, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %jibb  /tests/view-template/elements/jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-checked-element-hole-template
  ^-  tang
  =/  prepared=(unit iprelude-lowering:jibb)
    (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
  ?~  prepared  ~[leaf+"element-hole template prelude did not prepare"]
  =/  at=path  /ui/template-elements/jibb
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb at source ~ ~ ~ ~[at] ~ u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %view root.p.built cache.p.built)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  actual=@t  (compile:jibb-js p.linked)
  ::  Constant attribute axes, the unique static heading, and element-hole
  ::  axes all belong to this view's full returned sealed value.
  =/  wanted=@t
    ', ["column",14,[["h2",{"tabIndex":"-1"},["Items"]],-1,["row",1014,[["el",16246,[-2]],-3]],["el",2038,[-4]]]], [62, 16247, 4062, 2039], natives)'
  ?.  (contains (trip actual) (trip wanted))
    ~[leaf+"checked view lost its static attributes or element-hole template" leaf+(trip actual)]
  ~
--
