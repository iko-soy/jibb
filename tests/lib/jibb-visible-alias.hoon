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
