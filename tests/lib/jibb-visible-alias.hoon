::  Visible aliases describe checked nominal arguments without changing them.
/+  jibb
|%
++  expect
  |=  [source=@t modules=jbundle:jibb wanted=@t]
  ^-  tang
  =/  got=@t  (golden-types-with-modules:jibb /ui/client/jibb source ~ ~ modules)
  ?:  =(got wanted)  ~
  ~[leaf+"visible alias report differs" leaf+(trip got)]
++  base
  ^-  @t
  '+$ choice |$ [A B]\0a  [%ok value=A]\0a  [%err reason=B]\0a'
++  test-reverse-only-alias
  ^-  tang
  =/  mid=@t  '/= base /ui/base\0a+$ relay |$ [A B] (choice.base B A)\0a++ identity |= x=(relay A B) x\0a'
  (expect '/= mid /ui/mid\0a++ via identity.mid\0a' ~[[/ui/base/jibb base] [/ui/mid/jibb mid]] 'module kind: library\0a++ via: $-((relay.mid A B) (relay.mid A B))')
++  test-partial-and-repeated-aliases
  ^-  tang
  =/  mid=@t  '/= base /ui/base\0a+$ text-error |$ [A] (choice.base A @t)\0a+$ both |$ [A] (choice.base A A)\0a++ partial |= x=(text-error A) x\0a++ repeated |= x=(both A) x\0a'
  (expect '/= mid /ui/mid\0a++ fixed partial.mid\0a++ same repeated.mid\0a' ~[[/ui/base/jibb base] [/ui/mid/jibb mid]] 'module kind: library\0a++ fixed: $-((text-error.mid A) (text-error.mid A))\0a++ same: $-((both.mid A) (both.mid A))')
++  test-specialized-alias-identity
  ^-  tang
  =/  mid=@t  '/= base /ui/base\0a+$ text-ship (choice.base @t @p)\0a+$ text-number (choice.base @t @ud)\0a++ ship-id |= x=text-ship x\0a++ number-id |= x=text-number x\0a'
  (expect '/= mid /ui/mid\0a++ ships ship-id.mid\0a++ numbers number-id.mid\0a' ~[[/ui/base/jibb base] [/ui/mid/jibb mid]] 'module kind: library\0a++ ships: $-(text-ship.mid text-ship.mid)\0a++ numbers: $-(text-number.mid text-number.mid)')
++  test-cell-printer
  ^-  tang
  =/  txt=itype:jibb  [%atom %t]
  =/  num=itype:jibb  [%atom %ud]
  =/  ship=itype:jibb  [%atom %p]
  =/  tail=itype:jibb  [%cell txt [%cell num ship]]
  ?.  =("[@t @ud @p]" (show-itype:jibb tail ~))
    ~[leaf+"an unfaced right-nested tail did not flatten"]
  =/  faced=itype:jibb  [%cell txt [%face %rest [%cell num ship]]]
  ?.  =("[@t rest=[@ud @p]]" (show-itype:jibb faced ~))
    ~[leaf+"a faced cell tail lost its brackets"]
  =/  non-tail=itype:jibb  [%cell [%cell txt num] ship]
  ?.  =("[[@t @ud] @p]" (show-itype:jibb non-tail ~))
    ~[leaf+"a non-tail cell lost its brackets"]
  =/  sub=isub:jibb
    (isub-from-bindings:jibb ~[[1 txt] [2 [%cell num ship]]])
  =/  substituted=itype:jibb  [%cell [%var 1] [%var 2]]
  ?.  =("[@t @ud @p]" (show-itype:jibb substituted sub))
    ~[leaf+"substitution did not expose an unfaced cell tail"]
  =/  named=itype:jibb  [%named ~ `%rest ~ [%cell num ship]]
  ?.  =("[@t rest]" (show-itype:jibb [%cell txt named] ~))
    ~[leaf+"a named cell tail was flattened through its reference"]
  =/  nil=itype:jibb  [%const [%null %n 0 '~']]
  =/  unit-body=itype:jibb
    [%union ~[nil [%cell nil [%slot %u [%var 0]]]] `[/lib/jibb/prelude/jibb %unit] `%unit ~[[%var 0]]]
  =/  unit-view=itype:jibb  [%named `[/lib/jibb/prelude/jibb %unit] `%unit ~[[%var 0]] unit-body]
  ?.  (standard-unit-template:jibb [unit-view ~[0] ~] /lib/jibb/prelude/jibb)
    ~[leaf+"display metadata changed the standard unit template"]
  =/  minimal=@t  '+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a'
  =/  checked=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb minimal '++ unused 0\0a')
  ?~  checked  ~[leaf+"minimal unit prelude did not prepare"]
  =/  found=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit iface.u.checked)
  ?~  found  ~[leaf+"minimal unit mold missing"]
  ?.  (standard-unit-template:jibb u.found /lib/jibb/prelude/jibb)
    ~[leaf+"checked unit template changed" leaf+(show-itype:jibb (itype-display-body:jibb typ.u.found) ~)]
  =/  model-body=itype:jibb  [%cell [%slot %count [%atom %ud]] [%slot %other [%atom %t]]]
  =/  model-view=itype:jibb  [%named ~ `%model ~ model-body]
  =/  actual=itype:jibb  [%cell [%slot %count [%nvar 90]] [%slot %other [%atom %t]]]
  =/  fit=ifit:jibb  (itype-fit:jibb actual model-view ~ 100)
  ?.  ?=(%ok -.fit)  ~[leaf+"a transparent record reference did not fit its body"]
  =/  projected=(unit itype:jibb)  (iav-type-axis:jibb model-view 2 20)
  ?.  =(`[%slot %count [%atom %ud]] projected)  ~[leaf+"a transparent record reference blocked its field axis" leaf+?~(projected "none" (show-itype:jibb u.projected ~))]
  =/  cast-report=@t
    (golden-types:jibb /ui/cast/jibb '+$ model [count=@ud]\0a++ init |= input=@t ^- model [count=0]\0a')
  ?.  =(cast-report 'module kind: library\0a+$ model: model\0a++ init: $-(@t model)')
    ~[leaf+"minimal named cast failed" leaf+(trip cast-report)]
  =/  gate-cast-report=@t
    (golden-types:jibb /ui/cast/jibb '+$ flag-headed [%.y value=@t]\0a++ constructor ^- $-(@t flag-headed) |=%$\0a')
  ?.  =(gate-cast-report 'module kind: library\0a+$ flag-headed: flag-headed\0a++ constructor: $-(@t flag-headed)')
    ~[leaf+"named gate cast product was lost" leaf+(trip gate-cast-report)]
  ~
++  test-render-does-not-specialize
  ^-  tang
  =/  origin=[at=path name=term]  [/ui/base/jibb %choice]
  =/  pair=itype:jibb  [%union ~ `origin ~ ~[[%var 7] [%var 8]]]
  =/  repeated=ischeme:jibb  [[%union ~ `origin ~ ~[[%var 0] [%var 0]]] ~[0] ~]
  =/  wrong=ischeme:jibb  [[%union ~ `[/ui/elsewhere/jibb %choice] ~ ~[[%var 0] [%var 1]]] ~[0 1] ~]
  ?^  (report-union-alias:jibb pair ~[['repeated' repeated]] |)
    ~[leaf+"printing forced two independent actual parameters equal"]
  ?^  (report-union-alias:jibb pair ~[['wrong' wrong]] |)
    ~[leaf+"printing confused two nominal origins"]
  =/  specialized=ischeme:jibb  [[%union ~ `origin ~ ~[[%atom %t] [%atom %p]]] ~ ~]
  ?^  (report-union-alias:jibb pair ~[['specialized' specialized]] |)
    ~[leaf+"printing specialized unresolved actual parameters"]
  =/  real=itype:jibb  [%union ~ `origin ~ ~[[%atom %t] [%atom %p]]]
  =/  view=itype:jibb  (report-itype:jibb real ~[['specialized' specialized]])
  ?.  =((show-itype:jibb view ~) "specialized")  ~[leaf+"specialized alias retained spurious display arguments"]
  ?.  =((show-itype:jibb real ~) "")  ~[leaf+"rendering changed the checked type"]
  ?.  &(?=(%union -.real) =(args.real ~[[%atom %t] [%atom %p]]))
    ~[leaf+"rendering erased checked nominal arguments"]
  ~
--
