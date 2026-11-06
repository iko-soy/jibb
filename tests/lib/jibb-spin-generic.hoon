/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  rendered
  |=  [name=term env=ienv:jibb]
  ^-  (unit tape)
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name env)
  ?~  found  ~
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  display  ~
  `(show-itype:jibb (canonical-itype:jibb u.display vars.u.found) ~)
++  test-spin-generic
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude not prepared"]
  =/  source=@t  (of-wain:format ~['++ spin-items |= args=[(list A) B $-([A B] [C B])] ^- [p=(list C) q=B]' '  ?- args' '  [xs state apply]' '    ?- xs' '    ~ [p=~ q=state]' '    [item rest]' '      ?- (apply item state)' '      [mapped next]' '        ++ result (spin-items rest next apply)' '        [p=[mapped p.result] q=q.result]' '' '++ map-state |= args=[@ud @ud]' '  ?- args' '  [item state] ["item" (add item state)]' '++ output (spin-items ~[1 2] 0 map-state)' '++ map-two |= args=[@t @t]' '  ?- args' '  [item state] [1 state]' '++ output-two (spin-items ~["a"] "state" map-two)'])
  =/  at=path  /tests/spin-generic/jibb
  =/  out=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.out)  ~[leaf+(trip message.p.out)]
  =/  spin=(unit tape)  (rendered %spin-items values.iface.p.out)
  ?.  =(spin `"$-([(list A) [B $-([A B] [C B])]] [p=(list C) q=B])")
    ~[leaf+"spin lost its principal generic scheme"]
  =/  first=(unit tape)  (rendered %output values.iface.p.out)
  ?.  =(first `"[p=(list @t) q=@ud]")  ~[leaf+"first spin instance differs"]
  =/  second=(unit tape)  (rendered %output-two values.iface.p.out)
  ?.  =(second `"[p=(list @ud) q=@t]")  ~[leaf+"second spin instance differs"]
  ~
--
