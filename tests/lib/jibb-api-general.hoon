/+  jibb, jibb-import, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  sur  %txt  /my-app/sur/todo/hoon
/*  todos  %txt  /my-app/mar/todos/hoon
/*  update  %txt  /my-app/mar/todo-update/hoon
/*  item  %txt  /my-app/mar/todo-item/hoon
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  mark-text
  |=  lines=wain
  ^-  @t
  (text (skip lines |=(line=@t =('/-' (end [3 2] line)))))
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-general-api
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  todo=type  -:(ride -:!>(..zuse) (text sur))
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject (mark-text todos)))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject (mark-text update)))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject (mark-text item)))
  =/  marks=imark-externals:jibb  ~[[%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  api=@t  '/% %todos\0a/% %todo-update\0a/% %todo-item\0a+$ ordinal @ud\0a++ helper |= x=@t x\0a++ alias helper\0a+$ poke todo-update\0a++ complex-alias complex\0a++ separate-alias separate\0a++ poke-alias poke\0a++ call-complex |= [id=@ud slug=@ta] (complex-alias id slug same |=([diff prev] prev))\0a++ call-separate |= id=@ud (separate-alias id same)\0a++ call-poke |= action=todo-update (poke-alias action same)\0a+$ paths\0a  [%complex /todo/[id=@ud]/[slug=@ta] (facts todos todo-update todo-item)]\0a  [%separate /watch/[id=@ud] todos scry=/peek/[id=@ud]]\0a'
  =/  at=path  /ui/api/other/jibb
  =/  result  (infer-jibb-file:jibb at api ~ marks ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+"general API was rejected" leaf+(trip p.result)]
  =/  interface=ifile:jibb  iface.p.result
  =/  complex=(unit ischeme:jibb)  (ienv-lookup:jibb %complex values.interface)
  =/  separate=(unit ischeme:jibb)  (ienv-lookup:jibb %separate values.interface)
  ?~  complex  ~[leaf+"multi-parameter, multi-diff request was not exported"]
  ?~  separate  ~[leaf+"separate-scry request was not exported"]
  ?.  ?=(%fn -.typ.u.complex)  ~[leaf+"complex request is not a gate"]
  =/  ordinal=(unit ischeme:jibb)  (find-jibb-mold:jibb %ordinal interface)
  =/  alias=(unit ischeme:jibb)  (ienv-lookup:jibb %alias values.interface)
  ?~  ordinal  ~[leaf+"ordinary API mold was not exported"]
  ?~  alias  ~[leaf+"ordinary API value alias was not exported"]
  =/  derived=(list term)
    ~[%complex-alias %separate-alias %poke-alias %call-complex %call-separate %call-poke]
  ?.  (levy derived |=(n=term ?=(^ (ienv-lookup:jibb n values.interface))))
    ~[leaf+"ordinary definition depending on a derived gate was not exported"]
  =/  value-names=(list term)  (turn values.interface |=(e=[name=term scheme=ischeme:jibb] name.e))
  ?.  (levy value-names |=(n=term (unique-value-name:jibb n value-names)))
    ~[leaf+"derived gates were duplicated during ordinary inference"]
  =/  sample=itype:jibb  sample.typ.u.complex
  ?.  ?=([%cell [%atom %ud] [%cell [%atom %ta] [%cell [%fn *] [%fn *]]]] sample)
    ~[leaf+"request parameters, callback, and fold were not in path order" leaf+(show-itype:jibb sample ~)]
  =/  fold=itype:jibb  tal.tal.tal.sample
  ?.  ?=(%fn -.fold)  ~[leaf+"fold is not a gate"]
  ?.  ?=(%cell -.sample.fold)  ~[leaf+"fold sample is not a cell"]
  =/  diff=itype:jibb  hed.sample.fold
  ?.  ?=(%union -.diff)  ~[leaf+"multiple diff marks did not form a union"]
  ?.  =((lent cases.diff) 2)  ~[leaf+"diff union has wrong number of cases"]
  ?~  graph.interface  ~[leaf+"API provenance missing"]
  =/  imports=ijimports:jibb  ~[[%other interface]]
  ?.  ?=(^ (derived-request-member:jibb %complex %other imports u.graph.interface iface.u.prepared))
    ~[leaf+"multi-parameter folded request lost watchability"]
  ?^  (derived-request-member:jibb %separate %other imports u.graph.interface iface.u.prepared)
    ~[leaf+"separate-scry request was treated as watchable"]
  =/  modules=jbundle:jibb  ~[[at api]]
  =/  client=@t  '/= other /ui/api/other\0a++ a (complex.other 7 %slug same |=([diff prev] prev))\0a++ b (separate.other 7 same)\0a++ c (alias.other "ok")\0a++ d ^- ordinal.other 7\0a++ e (complex-alias.other 7 %slug same |=([diff prev] prev))\0a++ f (call-complex.other 8 ~.other)\0a++ g (separate-alias.other 7 same)\0a++ h (call-separate.other 8)\0a++ i (poke-alias.other [%added [7 %.n "ok"]] same)\0a++ j (call-poke.other [%added [7 %.n "ok"]])\0a'
  =/  client-at=path  /tests/general-api/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb client-at client ~ marks modules ~[client-at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"general API calls failed" leaf+(trip message.p.checked)]
  =/  page=@t  '/= other /ui/api/other\0a++ load |= id=@ud (separate.other id same)\0a++ view |= data=todos.other ^- (element !!) (text "ok")\0a++ main (page load view)\0a'
  ::  A page whose load takes an id has the route parameter _id.
  =/  page-at=path  /ui/search/[~._id]/jibb
  =/  page-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb page-at page ~ marks modules ~[page-at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.page-result)  ~[leaf+"page using separate-scry request failed" leaf+(trip message.p.page-result)]
  ?.  =(%page kind.p.page-result)  ~[leaf+"separate-scry page has wrong kind"]
  =/  bad-derived=jfile-result:jibb
    (infer-jibb-file:jibb at (cat 3 api '++ bad-derived (complex "bad" %slug same |=([diff prev] prev))\0a') ~ marks ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad-derived)  ~[leaf+"invalid call through a derived request was published"]
  =/  bad-message=tape  (trip p.bad-derived)
  ?.  (contains bad-message "++ bad-derived: call's sample and argument types do not unify")
    ~[leaf+"derived request failure lost its ordinary owner" leaf+bad-message]
  ?.  (contains bad-message "/ui/api/other.jibb:17:25: argument has type @t")
    ~[leaf+"derived request failure lost its argument site" leaf+bad-message]
  =/  cycle=jfile-result:jibb
    (infer-jibb-file:jibb at (cat 3 api '++ cycle-a cycle-b\0a++ cycle-b cycle-a\0a') ~ marks ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.cycle)  ~[leaf+"ordinary API value cycle bypassed SCC inference"]
  =/  cycle-message=tape  (trip p.cycle)
  ?.  (contains cycle-message "++ cycle-a: non-gate value `cycle-a` depends on itself through the cycle cycle-a -> cycle-b -> cycle-a")
    ~[leaf+"ordinary API cycle lost its diagnostic" leaf+cycle-message]
  ?.  (contains cycle-message "/ui/api/other.jibb:17:12: `cycle-a` depends on `cycle-b` here")
    ~[leaf+"ordinary API cycle lost its first dependency site" leaf+cycle-message]
  =/  broken=jfile-result:jibb
    (infer-jibb-file:jibb at (cat 3 api '++ broken |= x=@t (missing x)\0a') ~ marks ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.broken)  ~[leaf+"invalid ordinary API definition was published"]
  =/  message=tape  (trip p.broken)
  ?.  (contains message "++ broken: unknown name `missing`")
    ~[leaf+"ordinary API failure lost its owner or cause" leaf+message]
  ?.  (contains message "/ui/api/other.jibb:17:20: unknown name")
    ~[leaf+"ordinary API failure lost its source site" leaf+message]
  ~
--
