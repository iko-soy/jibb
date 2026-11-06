/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-bare-recursive-result
  ^-  tang
  =/  source=@t
    (of-wain:format ~['++ run |= x=@t' '  ++ first |= [value=A stop=?]' '    ?- stop' '    %.y [left=value]' '    %.n (second value %.y)' '  ++ second |= [value=A stop=?]' '    ?- stop' '    %.y value' '    %.n (first value %.y)' '  (second x %.y)' '++ untouched |= x=@p x'])
  =/  got=@t  (golden-bundle:jibb-prelude-fixture /tests/result-face/jibb source ~ ~ ~ prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] ~)
  ?.  =(got 'module kind: library\0a++ run: $-(@t [left=@t])\0a++ untouched: $-(@p @p)')  ~[leaf+(trip got)]
  ~
++  test-conflicting-recursive-result
  ^-  tang
  =/  source=@t
    (of-wain:format ~['++ run |= x=@t' '  ++ first |= [value=A stop=?]' '    ?- stop' '    %.y [left=value]' '    %.n (second value %.y)' '  ++ second |= [value=A stop=?]' '    ?- stop' '    %.y [right=value]' '    %.n (first value %.y)' '  (second x %.y)'])
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/result-face/jibb
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~[leaf+"conflicting-face source did not parse"]
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.got)  ~[leaf+(trip (golden-bundle:jibb-prelude-fixture file source ~ ~ ~ prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] ~))]
  ~
--
