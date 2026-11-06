/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-imported-alias-mold
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]' '+$ swap |$ [A B] (rbranch B A)' '+$ word @t'])
  =/  wrapper=@t
    (of-wain:format ~['/= base /ui/base' '+$ graft |$ [A]' '  %end' '  [%link ext=(swap.base @ud A) text=word.base tail=(graft A)]'])
  =/  client=@t
    (of-wain:format ~['/= base /ui/base' '/= outer /ui/outer' '++ item ^- (graft.outer @t) %end'])
  =/  file=path  /tests/recursive-qualified/jibb
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb owner] [/ui/other/jibb owner] [/ui/outer/jibb wrapper]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file client ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  item=(unit ischeme:jibb)  (ienv-lookup:jibb %item values.iface.p.result)
  ?~  item  ~[leaf+"recursive value with imported dependency missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.item)
  ?~  typ  ~[leaf+"recursive value type did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "(graft.outer @t)")  ~[leaf+"recursive type or arguments were lost"]
  ~
--
