/+  jibb
|%
++  test-recursive-nominal-mismatch
  ^-  tang
  =/  key=gkey:jibb  [/ui/a/jibb *span:jibb %node]
  =/  other-key=gkey:jibb  [/ui/b/jibb *span:jibb %node]
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) key [*span:jibb & ~['A'] ~ [%const [%term %tas %end '%end']]])
  =/  other-graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) other-key [*span:jibb & ~['A'] ~ [%const [%term %tas %end '%end']]])
  =/  left=itype:jibb  [%mrec /ui/a/jibb *span:jibb %node `'node' graph ~[[%atom %t]]]
  =/  foreign=itype:jibb  [%mrec /ui/b/jibb *span:jibb %node `'node' other-graph ~[[%atom %t]]]
  =/  wrong-arg=itype:jibb  [%mrec /ui/a/jibb *span:jibb %node `'node' graph ~[[%atom %ud]]]
  ?.  =(%bad -:(itype-fit:jibb left foreign ~ 0))  ~[leaf+"closed foreign origin did not mismatch"]
  ?.  =(%bad -:(itype-fit:jibb left wrong-arg ~ 0))  ~[leaf+"closed wrong generic argument did not mismatch"]
  =/  opened=itype:jibb  [%mrec /ui/b/jibb *span:jibb %node `'node' other-graph ~[[%var 12]]]
  ?.  =(%unknown -:(itype-fit:jibb left opened ~ 0))  ~[leaf+"open recursive mismatch became definite"]
  =/  void-graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) key [*span:jibb & ~['A'] ~ [%void ~]])
  =/  empty=itype:jibb  [%mrec /ui/a/jibb *span:jibb %node `'node' void-graph ~[[%atom %t]]]
  ?.  =(%unknown -:(itype-fit:jibb empty foreign ~ 0))  ~[leaf+"uninhabited recursive mismatch became definite"]
  =/  actual-list=itype:jibb  [%collection %list ~[left]]
  =/  foreign-list=itype:jibb  [%collection %list ~[foreign]]
  ?.  =(%bad -:(itype-fit:jibb actual-list foreign-list ~ 0))
    ~[leaf+"inhabited foreign recursive list did not mismatch"]
  =/  empty-list=itype:jibb  [%collection %list ~[[%empty ~]]]
  ?:  =(%bad -:(itype-fit:jibb empty-list foreign-list ~ 0))
    ~[leaf+"empty-only list became a definite mismatch"]
  =/  open-list=itype:jibb  [%collection %list ~[[%var 42]]]
  ?:  =(%bad -:(itype-fit:jibb open-list foreign-list ~ 0))
    ~[leaf+"open list element became a definite mismatch"]
  ~
--
