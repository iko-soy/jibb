/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-recursive-import
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]'])
  =/  client=@t
    (of-wain:format ~['/= base /ui/base' '/= other /ui/other' '++ sample ^- (rbranch.base @t @ud) %done' '++ other-sample ^- (rbranch.other @t @ud) %done'])
  =/  file=path  /tests/recursive-import/jibb
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb owner] [/ui/other/jibb owner]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file client ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  sample=(unit ischeme:jibb)  (ienv-lookup:jibb %sample values.iface.p.result)
  ?~  sample  ~[leaf+"imported recursive value missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.sample)
  ?~  typ  ~[leaf+"imported recursive type did not realize"]
  ?.  (itype-has-recursive:jibb u.typ)  ~[leaf+"imported recursive identity missing"]
  ?.  =((show-itype:jibb u.typ ~) "(rbranch.base @t @ud)")  ~[leaf+"recursive imported name or arguments changed"]
  =/  other=(unit ischeme:jibb)  (ienv-lookup:jibb %other-sample values.iface.p.result)
  ?~  other  ~[leaf+"second imported recursive value missing"]
  =/  other-type=(unit itype:jibb)  (scheme-display-type:jibb u.other)
  ?~  other-type  ~[leaf+"second imported recursive type did not realize"]
  =/  fit=ifit:jibb  (itype-fit:jibb u.typ u.other-type ~ 0)
  ?.  ?=(%bad -.fit)  ~[leaf+"inhabited recursive molds with different origins were not rejected"]
  ~
++  test-recursive-transitive
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]'])
  =/  bridge=@t
    (of-wain:format ~['/= base /ui/base' '++ empty ^- (rbranch.base @t @ud) %done'])
  =/  client=@t
    (of-wain:format ~['/= base /ui/base' '/= via /ui/bridge' '++ same-tree ^- (rbranch.base @t @ud) empty.via'])
  =/  foreign=@t
    (of-wain:format ~['/= other /ui/other' '/= via /ui/bridge' '++ wrong ^- (rbranch.other @t @ud) empty.via'])
  =/  file=path  /tests/recursive-transitive/jibb
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb owner] [/ui/other/jibb owner] [/ui/bridge/jibb bridge]]
  =/  good=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file client ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.good)  ~[leaf+(trip message.p.good)]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file foreign ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"transitive recursive origins were conflated"]
  ~
++  test-qualified-recursive-reference
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]'])
  =/  wrapper=@t
    (of-wain:format ~['/= base /ui/base' '+$ graft |$ [A]' '  %end' '  [%link ext=(rbranch.base A @ud) tail=(graft A)]'])
  =/  client=@t
    (of-wain:format ~['/= base /ui/base' '/= outer /ui/outer' '++ item ^- (graft.outer @t) %end' '++ assemble |= x=(rbranch.base @t @ud) ^- (graft.outer @t) [%link ext=x tail=%end]'])
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
  ?.  =((show-itype:jibb u.shown ~) "$-((rbranch.base @t @ud) (graft.outer @t))")
    ~[leaf+"qualified recursive dependency or result type changed"]
  =/  bad-source=@t
    (of-wain:format ~['/= alien /ui/other' '/= outer /ui/outer' '++ wrong |= x=(rbranch.alien @t @ud) ^- (graft.outer @t) [%link ext=x tail=%end]'])
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file bad-source ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"foreign recursive dependency was accepted"]
  ~
++  test-hidden-recursive-report
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  owner=@t
    (of-wain:format ~['+$ rbranch |$ [A B]' '  %done' '  [%node value=A other=B kids=(list (rbranch A B))]'])
  =/  bridge=@t  (of-wain:format ~['/= base /ui/base' '++ empty ^- (rbranch.base @t @ud) %done'])
  =/  source=@t  (of-wain:format ~['/= via /ui/bridge' '++ value empty.via'])
  =/  file=path  /tests/recursive-hidden-report/jibb
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb owner] [/ui/bridge/jibb bridge]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  actual=@t  (render-full-types:jibb file source result)
  =/  expected=@t  'module kind: library\0a/= types-1 /ui/base\0a++ value: (rbranch.types-1 @t @ud)'
  ?.  =(expected actual)  ~[leaf+"hidden recursive type report differs" leaf+(trip actual)]
  ~
--
