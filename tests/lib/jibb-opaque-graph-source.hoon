/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-recursive-element-mold
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  source=@t  '+$ node-tree |$ [M]\0a  [%leaf view=(element M)]\0a  [%node children=(list (node-tree M))]\0a++ identity |= x=(node-tree @t) x\0a'
  =/  at=path  /tests/element-tree/jibb
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+"recursive mold containing an element failed" leaf+(trip message.p.result)]
  =/  identity=(unit ischeme:jibb)  (ienv-lookup:jibb %identity values.iface.p.result)
  ?~  identity  ~[leaf+"identity missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.identity)
  ?~  shown  ~[leaf+"identity type could not be displayed"]
  ?.  =((show-itype:jibb u.shown ~) "$-((node-tree @t) (node-tree @t))")
    ~[leaf+"recursive element mold lost its public identity" leaf+(show-itype:jibb u.shown ~)]
  ~
--
