/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-recursive-coverage
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]' '++ inspect |= t=(rbranch @t @ud) ^- @tas' '  ?- t' '    %done %done' '    [%node x y children] %node'])
  =/  file=path  /tests/recursive-coverage/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %inspect values.iface.p.result)
  ?~  found  ~[leaf+"recursive match was not exported"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"recursive match type did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "$-((rbranch @t @ud) @tas)")  ~[leaf+"recursive match has the wrong type"]
  ~
++  test-recursive-missing-case
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]' '++ inspect |= t=(rbranch @t @ud) ^- @tas' '  ?- t' '    %done %done'])
  =/  file=path  /tests/recursive-coverage/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)  ~[leaf+"missing recursive case was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ inspect: missing match case [%node ["" [0 ~]]]' '/tests/recursive-coverage.jibb:5:3: non-exhaustive match' '  ?- t' '  ^' '/tests/recursive-coverage.jibb:5:6: subject has type (rbranch @t @ud)' '  ?- t' '     ^'])
  ?.  =(message.p.result expected)  ~[leaf+(trip message.p.result)]
  ~
++  test-local-recursive-mold
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['++ local-run |= input=@t' '  +$ local |$ [A]' '    %done' '    [%node value=A next=(local A)]' '  ++ temp ^- (local @t) %done' '  ?- temp' '    %done input' '    [%node item next] item'])
  =/  file=path  /tests/local-recursive-mold/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %local-run values.iface.p.result)
  ?~  found  ~[leaf+"local recursive match was not exported"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"local recursive match type did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "$-(@t @t)")  ~[leaf+"local recursive match has the wrong type"]
  ~
++  test-local-recursive-escape
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['++ leak |= input=@t' '  +$ local |$ [A]' '    %done' '    [%node value=A next=(local A)]' '  ^- (local @t) %done'])
  =/  file=path  /tests/local-recursive-escape/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %leak values.iface.p.result)
  ?~  found  ~[leaf+"local recursive value was not published"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"local recursive value type did not realize"]
  =/  report=@t  (render-full-types:jibb file source result)
  =/  expected=@t  'module kind: library\0alocal type local-1: local at /tests/local-recursive-escape.jibb:2:12\0a++ leak: $-(@t (local-1 @t))'
  ?.  =(report expected)  ~[leaf+"local recursive legend differs" leaf+(trip report)]
  ~
--
