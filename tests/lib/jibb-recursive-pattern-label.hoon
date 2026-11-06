/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  tree  %txt  /tests/type-generic-construction/tree/txt
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-recursive-pattern-label
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb (of-wain:format tree)] [/ui/tree-two/jibb (of-wain:format tree)]]
  =/  src=@t
    (of-wain:format ~['/= first /ui/tree' '/= second /ui/tree-two' '++ foreign-children |= x=(node-tree.first @t)' '  ^- (list (node-tree.second @t)) ?- x' '    [%text value] ~' '    [%node event kids] kids'])
  =/  file=path  /tests/tree/client/jibb
  =/  out=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ modules ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.out)  ~[leaf+"foreign recursive result was accepted"]
  =/  msg=tape  (trip message.p.out)
  ?.  (contains msg "node-tree.first @t")  ~[leaf+"actual recursive type lost its checked import alias"]
  ?.  (contains msg "node-tree.second @t")  ~[leaf+"expected recursive type lost its distinct import alias"]
  ?.  (contains msg "/tests/tree/client.jibb:6:")  ~[leaf+"recursive mismatch lost the arm source site"]
  ~
--
