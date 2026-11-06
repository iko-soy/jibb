/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-recursive-named-union
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]' '+$ choice |$ [A B]' '  [%left A]' '  [%right B]'])
  =/  wrapper=@t
    (of-wain:format ~['/= base /ui/base' '+$ graft |$ [A]' '  %end' '  [%link ext=(choice.base A @ud) tail=(graft A)]'])
  =/  client=@t
    (of-wain:format ~['/= base /ui/base' '/= outer /ui/outer' '++ item ^- (graft.outer @t) %end' '++ assemble |= x=(choice.base @t @ud) ^- (graft.outer @t) [%link ext=x tail=%end]'])
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
  =/  assemble=(unit ischeme:jibb)  (ienv-lookup:jibb %assemble values.iface.p.result)
  ?~  assemble  ~[leaf+"qualified recursive constructor missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.assemble)
  ?~  shown  ~[leaf+"qualified recursive constructor type did not realize"]
  ?.  =((show-itype:jibb u.shown ~) "$-((choice.base @t @ud) (graft.outer @t))")
    ~[leaf+"qualified recursive dependency or result type changed"]
  =/  bad-source=@t
    (of-wain:format ~['/= alien /ui/other' '/= outer /ui/outer' '++ wrong |= x=(choice.alien @t @ud) ^- (graft.outer @t) [%link ext=x tail=%end]'])
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file bad-source ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"foreign recursive dependency was accepted"]
  ~
--
