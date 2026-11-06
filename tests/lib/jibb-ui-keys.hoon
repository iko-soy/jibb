/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  hoon  %jibb  /lib/jibb/groups/hoon/jibb
/*  bit  %jibb  /lib/jibb/groups/bit/jibb
|%
++  prepared
  ^-  (unit iprelude:jibb)
  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb bit]])
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  check
  |=  src=@t
  ^-  jfile-detailed-result:jibb
  =/  prep=(unit iprelude:jibb)  prepared
  ?~  prep  [%| ['prelude did not prepare' ~]]
  =/  at=path  /tests/ui-keys/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
++  test-prelude-keys-constrained
  ^-  tang
  =/  prep=(unit iprelude:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  names=(list term)  ~[%each %table]
  |-
  ?~  names  ~
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb i.names values.iface.u.prep)
  ?~  scheme  ~[leaf+"missing keyed constructor"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.scheme)
  ?~  shown  ~[leaf+"keyed constructor scheme did not close"]
  =/  constraint=tape  (show-atom-constraint:jibb u.shown)
  ?.  (contains constraint "contains no gates")
    ~[leaf+(weld "missing key restriction: " (weld (show-itype:jibb u.shown ~) constraint))]
  $(names t.names)
++  test-gate-free-data-and-generic
  ^-  tang
  =/  src=@t  '++ render |= xs=(list [key=K el=(element M)]) (each xs)\0a++ alias each\0a++ word (alias ~[[key="one" el=(text "x")]])\0a++ nested (each ~[[key=[label="one" count=1] el=(text "x")]])\0a++ tabular (table ~ ~[[key=~zod cells=~[(text "x")]]])\0a++ callback |= x=@ud x\0a++ gate-message (each ~[[key="ok" el=(button "x" callback)]])\0a'
  =/  got=jfile-detailed-result:jibb  (check src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  render=(unit ischeme:jibb)  (ienv-lookup:jibb %render values.iface.p.got)
  ?~  render  ~[leaf+"generic wrapper missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.render)
  ?~  shown  ~[leaf+"generic wrapper did not close"]
  ?.  (contains (show-atom-constraint:jibb u.shown) "contains no gates")
    ~[leaf+"generic wrapper lost the key restriction"]
  ~
++  test-gate-keys-rejected
  ^-  tang
  =/  cases=(list @t)
    :~  '++ callback |= x=@ud x\0a++ bad (each ~[[key=callback el=(text "x")]])\0a'
        '++ callback |= x=@ud x\0a++ bad (each ~[[key=[v=callback label="x"] el=(text "x")]])\0a'
        '++ callback |= x=@ud x\0a++ alias each\0a++ bad (alias ~[[key=callback el=(text "x")]])\0a'
        '++ callback |= x=@ud x\0a++ bad (table ~ ~[[key=callback cells=~[(text "x")]]])\0a'
        '++ callback |= x=@ud x\0a++ bad (table ~ ~[[key=[v=callback label="x"] cells=~[(text "x")]]])\0a'
    ==
  |-
  ?~  cases  ~
  =/  got=jfile-detailed-result:jibb  (check i.cases)
  ?:  ?=(%& -.got)  ~[leaf+"a key containing a gate was accepted"]
  ?.  (contains (trip message.p.got) "contains no gates")
    ~[leaf+"gate-containing key lost its constraint diagnostic" leaf+(trip message.p.got)]
  $(cases t.cases)
--
