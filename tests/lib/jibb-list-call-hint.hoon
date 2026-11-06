::  A list error suggests a call only when that call itself checks.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  expected  %txt  /tests/type-list-call-hint/expected/txt
|%
++  report
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  'prelude unavailable'
  =/  cases=(list [label=@t source=@t])
    :~  ['contextual UI call' '++ value ^- (list (element !!)) ~[text "hi"]\0a']
        ['ordinary call' '++ identity |= x=@t x\0a++ value ~[identity "hi"]\0a']
        ['unicode columns' '++ identity |= x=@t x\0a++ value ["é" ~[identity "hé"]]\0a']
        ['several arguments' '++ choose |= [left=@t right=@p] left\0a++ value ~[choose "hi" ~zod]\0a']
        ['incompatible argument' '++ identity |= x=@t x\0a++ value ~[identity ~zod]\0a']
        ['parenthesized call' '++ value ^- (list (element !!)) ~[(text "hi")]\0a']
        ['list of gates' '++ first |= x=@t x\0a++ second |= x=@t x\0a++ value ~[first second]\0a']
    ==
  %-  of-wain:format
  %+  turn  cases
  |=  [label=@t source=@t]
  (cat 3 label (cat 3 '\0a' (golden-types-with-prepared-prelude:jibb /ui/lists/jibb source ~ ~ ~ prep)))
++  test-list-call-hint
  ^-  tang
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+(trip actual)]
  ~
--
