/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /tests/type-bit/internal/jibb
/*  original-internal  %jibb  /tests/type-bit/original-internal/jibb
/*  hoon  %jibb  /lib/jibb/groups/hoon/jibb
/*  bit  %jibb  /tests/type-bit/bit/jibb
|%
++  bit-prepared
  ^-  (unit iprelude:jibb)
  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb bit]])
++  bit-check
  |=  src=@t
  ^-  jfile-detailed-result:jibb
  =/  prep=(unit iprelude:jibb)  bit-prepared
  ?~  prep  [%| ['bit prelude did not prepare' ~]]
  =/  at=path  /tests/bit/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
++  test-not-bit
  ^-  tang
  =/  got=jfile-detailed-result:jibb  (bit-check '++ x (not.bit 0 4 42)\0a++ y (not.bit %.y %.n 42)\0a')
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  x=(unit ischeme:jibb)  (ienv-lookup:jibb %x values.iface.p.got)
  =/  y=(unit ischeme:jibb)  (ienv-lookup:jibb %y values.iface.p.got)
  ?~  x  ~[leaf+"bit result x is missing"]
  ?~  y  ~[leaf+"bit result y is missing"]
  ?.  =(typ.u.x typ.u.y)  ~[leaf+"bit calls do not share the public result type"]
  ?.  ?=(%any-atom -.typ.u.x)  ~[leaf+"bit result is not an unrestricted atom"]
  ~
++  test-not-bit-rejects-cell
  ^-  tang
  =/  got=jfile-detailed-result:jibb  (bit-check '++ x (not.bit [0 1] 4 42)\0a')
  ?:  ?=(%& -.got)  ~[leaf+"bit not accepted a cell"]
  ~
++  test-internal-remains-private
  ^-  tang
  =/  got=jfile-detailed-result:jibb  (bit-check '/= internal /lib/jibb/internal\0a++ x (bit-not.internal 0 4 42)\0a')
  ?:  ?=(%& -.got)  ~[leaf+"ordinary source imported the private prelude module"]
  ~
++  test-checked-group-not-private-authority
  ^-  tang
  =/  prep=(unit iprelude:jibb)  bit-prepared
  ?~  prep  ~[leaf+"bit prelude did not prepare"]
  =/  at=path  /lib/jibb/groups/bit/jibb
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at bit ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.got)  ~[leaf+"finished group interface authorized a new private import"]
  ~

++  test-internal-source-required
  ^-  tang
  =/  built=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude original-internal ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb bit]])
  ?^  built  ~[leaf+"bit group used a primitive absent from the checked internal source"]
  ~
++  test-transitive-internal-remains-private
  ^-  tang
  =/  outer=@t  '/= helper /lib/bit-helper\0a++ not |= args=[@ @ @] (run.helper args)\0a'
  =/  helper=@t  '/= internal /lib/jibb/internal\0a++ run |= args=[@ @ @] (bit-not.internal args)\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb outer]]
  =/  built=(unit iprelude:jibb)
    (prepare-bundle:jibb-prelude-fixture prelude internal groups ~[[/lib/bit-helper/jibb helper]])
  ?^  built  ~[leaf+"transitive module imported the private prelude"]
  ~

++  test-not-bit-exact-scheme
  ^-  tang
  =/  prep=(unit iprelude:jibb)  bit-prepared
  ?~  prep  ~[leaf+"bit prelude did not prepare"]
  ?^  (ienv-lookup:jibb %raw-bit-not values.iface.u.prep)  ~[leaf+"raw bit primitive leaked into the public prelude"]
  =/  got=jfile-detailed-result:jibb  (bit-check '++ operation not.bit\0a')
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  operation=(unit ischeme:jibb)  (ienv-lookup:jibb %operation values.iface.p.got)
  ?~  operation  ~[leaf+"bit gate was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.operation)
  ?~  shown  ~[leaf+"bit gate scheme did not close"]
  =/  atom=itype:jibb  [%any-atom ~]
  =/  expected=itype:jibb  [%fn [%cell atom [%cell atom atom]] atom]
  ?.  =(u.shown expected)  ~[leaf+(weld "bit gate scheme differs: " (show-itype:jibb u.shown ~))]
  ~

++  has-text
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-private-group-diagnostic
  ^-  tang
  =/  source=@t  '/= internal /lib/jibb/internal\0a++ valid (bit-not.internal 0 4 42)\0a++ broken (1 "bad")\0a'
  =/  groups=(list iprelude-group-source:jibb)
    ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%demo /lib/jibb/groups/demo/jibb source]]
  =/  got=(each iprelude:jibb @t)
    (prepare-bundle-detailed:jibb-prelude-fixture prelude internal groups ~)
  ?:  ?=(%& -.got)  ~[leaf+"invalid group was accepted"]
  ?.  &((has-text (trip p.got) "++ broken:") (has-text (trip p.got) "/lib/jibb/groups/demo.jibb:3:"))
    ~[leaf+"group diagnostic did not use the checked private interface" leaf+(trip p.got)]
  ~
--
