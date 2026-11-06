::  Quantified restrictions survive saved structural scheme graphs.
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
++  test-generic-collection-constraints
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  checks=(list [source=@t expected=@t])
    :~  ['++ same-list |= xs=(list A) (eq xs xs)\0a' 'module kind: library\0a++ same-list: $-((list A) ?) where A contains no gates']
        ['++ same-nested |= xs=(list (unit A)) (eq xs xs)\0a' 'module kind: library\0a++ same-nested: $-((list (unit A)) ?) where A contains no gates']
        ['++ same-record |= xs=[left=(list A) right=B] (eq xs xs)\0a' 'module kind: library\0a++ same-record: $-([left=(list A) right=B] ?) where A contains no gates, B contains no gates']
        ['++ same-list |= xs=(list A) (eq xs xs)\0a++ words-ok (same-list ~["hi"])\0a++ ships-ok (same-list ~[~zod])\0a' 'module kind: library\0a++ same-list: $-((list A) ?) where A contains no gates\0a++ words-ok: ?\0a++ ships-ok: ?']
        ['++ keep-list |= xs=(list A) xs\0a++ callback |= x=@ud x\0a++ callbacks (keep-list ~[callback])\0a' 'module kind: library\0a++ keep-list: $-((list A) (list A))\0a++ callback: $-(@ud @ud)\0a++ callbacks: (list $-(@ud @ud))']
    ==
  =/  errors=tang  ~
  |-
  ?~  checks  errors
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb /tests/constraints/jibb source.i.checks ~ ~ ~ prepared)
  =?  errors  !=(actual expected.i.checks)  [leaf+"generic constraint changed or was lost" leaf+(trip actual) errors]
  $(checks t.checks)
++  test-gate-collection-rejected
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  checks=(list [source=@t reason=@t at=@t])
    :~  ['++ same-list |= xs=(list A) (eq xs xs)\0a++ callback |= x=@ud x\0a++ bad (same-list ~[callback])\0a' '++ bad: list item does not fit its expected type' '/tests/constraints.jibb:3:21: list item has type $-(@ud @ud)']
        ['++ same-nested |= xs=(list (unit A)) (eq xs xs)\0a++ callback |= x=@ud x\0a++ bad (same-nested ~[`callback])\0a' '++ bad: unit payload does not fit its expected type' '/tests/constraints.jibb:3:24: payload has type $-(@ud @ud)']
        ['++ same-list |= xs=(list A) (eq xs xs)\0a++ alias same-list\0a++ callback |= x=@ud x\0a++ bad (alias ~[callback])\0a' '++ bad: list item does not fit its expected type' '/tests/constraints.jibb:4:17: list item has type $-(@ud @ud)']
    ==
  =/  errors=tang  ~
  |-
  ?~  checks  errors
  =/  actual=tape  (trip (golden-types-with-prepared-prelude:jibb /tests/constraints/jibb source.i.checks ~ ~ ~ prepared))
  =?  errors  !&((contains actual (trip reason.i.checks)) (contains actual "A contains no gates") (contains actual (trip at.i.checks)))
    [leaf+"gate-containing collection escaped its quantified restriction" leaf+actual errors]
  $(checks t.checks)
++  test-imported-collection-constraint
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  modules=jbundle:jibb  ~[[/ui/helper/jibb '++ same-list |= xs=(list A) (eq xs xs)\0a']]
  =/  source=@t  '/= helper /ui/helper\0a++ callback |= x=@ud x\0a++ bad (same-list.helper ~[callback])\0a'
  =/  actual=tape  (trip (golden-types-with-prepared-prelude:jibb /tests/constraints/jibb source ~ ~ modules prepared))
  ?.  &((contains actual "++ bad: list item does not fit its expected type") (contains actual "A contains no gates") (contains actual "/tests/constraints.jibb:3:28: list item has type $-(@ud @ud)"))
    ~[leaf+"imported scheme lost its nested restriction" leaf+actual]
  ~
--
