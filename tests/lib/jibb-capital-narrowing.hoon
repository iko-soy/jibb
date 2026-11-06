::  A branch cannot specialize a written capital, but may infer its allowed
::  arithmetic constraint without making it a concrete aura.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-capital-narrowing
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /tests/capital-narrowing/jibb
  =/  bad=@t
    (of-wain:format ~['++ bad |= [x=? y=A] ^- A' '  ?- x' '    %.y %go' '    %.n %stay'])
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at bad ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)  ~[leaf+"specialized capital was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ bad: capital `A` cannot be fixed to %go' '/tests/capital-narrowing.jibb:1:18: capital' '++ bad |= [x=? y=A] ^- A' '                 ^' '/tests/capital-narrowing.jibb:3:9: forcing expression' '    %.y %go' '        ^'])
  ?.  =(message.p.result expected)
    ~[leaf+"capital diagnostic differed: {(trip message.p.result)}"]
  =/  good=@t
    (of-wain:format ~['++ good |= [x=? y=A] ^- A' '  ?- x' '    %.y (add y 1)' '    %.n y'])
  =/  good-result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at good ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.good-result)
    ~[leaf+"permitted arithmetic constraint was rejected: {(trip message.p.good-result)}"]
  ~
++  test-capital-number-and-list
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /tests/capital-narrowing/jibb
  =/  cases=(list [source=@t expected=@t])
    :~  :-  '++ bad |= x=A ^- A 1'
        (of-wain:format ~['++ bad: capital `A` cannot be fixed to @ud' '/tests/capital-narrowing.jibb:1:13: capital' '++ bad |= x=A ^- A 1' '            ^' '/tests/capital-narrowing.jibb:1:20: forcing expression' '++ bad |= x=A ^- A 1' '                   ^'])
        :-  '++ bad |= x=A ^- A ~[1]'
        (of-wain:format ~['++ bad: capital `A` cannot be fixed to (list @ud)' '/tests/capital-narrowing.jibb:1:13: capital' '++ bad |= x=A ^- A ~[1]' '            ^' '/tests/capital-narrowing.jibb:1:20: forcing expression' '++ bad |= x=A ^- A ~[1]' '                   ^'])
    ==
  |-
  ?~  cases  ~
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source.i.cases ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)  ~[leaf+"specialized capital was accepted"]
  ?.  =(message.p.result expected.i.cases)
    ~[leaf+"capital diagnostic differed: {(trip message.p.result)}"]
  $(cases t.cases)
--
