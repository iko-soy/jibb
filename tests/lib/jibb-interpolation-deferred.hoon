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
++  test-later-body-context
  ^-  tang
  =/  src=@t  '++ render |= n\0a  ~& "{n}"\0a    ^- @ud n\0a'
  =/  got=@t  (golden-types:jibb /tests/interpolation/jibb src)
  ?.  =(got 'module kind: library\0a++ render: $-(@ud @ud)')
    ~[leaf+"later body context did not fix interpolation" leaf+(trip got)]
  ~
++  test-later-module-context
  ^-  tang
  =/  src=@t  '++ render |= n "{n}"\0a++ used (render "hi")\0a'
  =/  got=@t  (golden-types:jibb /tests/interpolation/jibb src)
  ?.  =(got 'module kind: library\0a++ render: $-(@t @t)\0a++ used: @t')
    ~[leaf+"later call did not fix the implicit interpolation type" leaf+(trip got)]
  ~
++  test-explicit-capital-stays-generic
  ^-  tang
  =/  src=@t  '++ render |= n=A "{n}"\0a++ used (render "hi")\0a'
  =/  got=@t  (golden-types:jibb /tests/interpolation/jibb src)
  ?.  (contains (trip got) "generic value in interpolation needs a printer")
    ~[leaf+"later call specialized an explicit capital's printer" leaf+(trip got)]
  ?.  (contains (trip got) "capital `A` keeps its type generic")
    ~[leaf+"generic printer error lost the capital declaration" leaf+(trip got)]
  ~
++  test-arithmetic-and-tape
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed"]
  =/  src=@t  '++ value "{(add 1 2)}"\0a++ render |= x=(list @tD) "{x}"\0a'
  =/  got=@t  (golden-types-with-prepared-prelude:jibb /tests/interpolation/jibb src ~ ~ ~ prepared)
  ?.  =(got 'module kind: library\0a++ value: @t\0a++ render: $-((list @tD) @t)')
    ~[leaf+"arithmetic or tape interpolation failed" leaf+(trip got)]
  ~
++  test-tape-element-context
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed"]
  =/  src=@t  '++ render |= n "{~[n]}"\0a++ use |= c=@tD (render c)\0a'
  =/  got=@t  (golden-types-with-prepared-prelude:jibb /tests/interpolation/jibb src ~ ~ ~ prepared)
  ?.  =(got 'module kind: library\0a++ render: $-(@tD @t)\0a++ use: $-(@tD @t)')
    ~[leaf+"later element context did not determine a tape printer" leaf+(trip got)]
  =/  generic=@t  '++ render |= n=A "{~[n]}"\0a++ use |= c=@tD (render c)\0a'
  =/  rejected=@t  (golden-types-with-prepared-prelude:jibb /tests/interpolation/jibb generic ~ ~ ~ prepared)
  ?.  (contains (trip rejected) "generic value in interpolation needs a printer")
    ~[leaf+"a later call specialized a generic list's element printer" leaf+(trip rejected)]
  ~
--
