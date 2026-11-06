/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-progress-before-local-error
  ^-  tang
  =/  good=@t  '++ run |= x=@t\0a  ++ first |= [value=A stop=?]\0a    ?- stop\0a    %.y (third value %.y)\0a    %.n (second value %.y)\0a  ++ second |= [value=A stop=?]\0a    ?- stop\0a    %.y value\0a    %.n (first value %.y)\0a  ++ third |= [value=A stop=?]\0a    ?- stop\0a    %.y value\0a    %.n (fourth value %.y)\0a  ++ fourth |= [value=A stop=?]\0a    ?- stop\0a    %.y value\0a    %.n (third value %.y)\0a  (first x %.y)\0a'
  =/  bad=@t  '++ run |= x=@t\0a  ++ first |= [value=A stop=?]\0a    ?- stop\0a    %.y [left=value]\0a    %.n (second value %.y)\0a  ++ second |= [value=A stop=?]\0a    ?- stop\0a    %.y [right=value]\0a    %.n (first value %.y)\0a  ++ third |= [value=A stop=?]\0a    ?- stop\0a    %.y value\0a    %.n (fourth value %.y)\0a  ++ fourth |= [value=A stop=?]\0a    ?- stop\0a    %.y value\0a    %.n (third value %.y)\0a  (third x %.y)\0a'
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  good-report=@t  (golden-types-with-prepared-prelude:jibb /ui/local-groups/jibb good ~ ~ ~ prep)
  ?.  =(good-report 'module kind: library\0a++ run: $-(@t @t)')  ~[leaf+(trip good-report)]
  =/  bad-report=@t  (golden-types-with-prepared-prelude:jibb /ui/local-groups/jibb bad ~ ~ ~ prep)
  ?.  (contains (trip bad-report) "branch results have conflicting value faces")  ~[leaf+(trip bad-report)]
  ~
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
--
