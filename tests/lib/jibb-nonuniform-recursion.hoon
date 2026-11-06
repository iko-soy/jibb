/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-nonuniform-recursion
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ mixed-tree |$ [A]' '  [%text value=@t]' '  [%node event=$-(@t A) children=(list (mixed-tree @t))]' '++ child-list |= x=(mixed-tree @p)' '  ?- x' '    [%text t] ^- (list (mixed-tree @t)) ~' '    [%node event kids] kids'])
  =/  file=path  /tests/nonuniform-recursion/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %child-list values.iface.p.result)
  ?~  found  ~[leaf+"nonuniform recursive match was not exported"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"nonuniform recursive match type did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "$-((mixed-tree @p) (list (mixed-tree @t)))")
    ~[leaf+"nonuniform recursive child argument was not preserved"]
  ~
--
