::  Source-backed generic union aliases must print with a valid public name.
/+  jibb
|%
++  generic-alias-errors
  ^-  (list tape)
  =/  internal=@t
    '+$ union-source |$ [A B]\0a  [%left first=A]\0a  [%right second=B]\0a+$ choice\0a  [%alpha first=@t]\0a  [%beta second=@p]\0a'
  =/  public=@t
    '/= internal /lib/jibb/internal\0a+$ forward |$ [A B] (union-source.internal A B)\0a+$ reverse |$ [A B] (union-source.internal B A)\0a+$ fixed |$ [A] (union-source.internal A @t)\0a+$ phantom |$ [A B] (union-source.internal A @t)\0a+$ repeated |$ [A] (union-source.internal A A)\0a+$ choice choice.internal\0a'
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prepared  ~["synthetic prelude did not prepare"]
  =/  dependency=@t  '++ identity |= x=(forward A B) x\0a++ choice-id |= x=choice x\0a'
  =/  source=@t
    '/= dep /ui/dep\0a++ direct |= x=(forward A B) x\0a++ concrete |= x=(forward @t @p) x\0a++ imported identity.dep\0a++ choice-imported choice-id.dep\0a++ swapped |= x=(reverse A B) x\0a++ fixed-alias |= x=(fixed A) x\0a++ phantom-alias |= x=(phantom A B) x\0a++ repeat-alias |= x=(repeated A) x\0a'
  =/  report=@t
    (golden-types-with-prepared-prelude:jibb /ui/client/jibb source ~ ~ ~[[/ui/dep/jibb dependency]] prepared)
  =/  want=@t
    'module kind: library\0a++ direct: $-((forward A B) (forward A B))\0a++ concrete: $-((forward @t @p) (forward @t @p))\0a++ imported: $-((forward A B) (forward A B))\0a++ choice-imported: $-(choice choice)\0a++ swapped: $-((forward B A) (forward B A))\0a++ fixed-alias: $-((forward A @t) (forward A @t))\0a++ phantom-alias: $-((forward A @t) (forward A @t))\0a++ repeat-alias: $-((forward A A) (forward A A))'
  ?.  =(report want)  ~["generic alias source or import report changed"]
  =/  orig=[at=path name=term]  [/lib/jibb/internal/jibb %union-source]
  =/  args=(list itype:jibb)  ~[[%atom %t] [%atom %p]]
  =/  aliases=imold-types:jibb  molds.iface.u.prepared
  ?.  =((prelude-union-alias:jibb orig args aliases) [~ %forward])
    ~["identity alias was not selected"]
  ?^  (prelude-union-alias:jibb [/other %union-source] args aliases)
    ~["a different origin was accepted"]
  ?^  (prelude-union-alias:jibb [/lib/jibb/internal/jibb %other] args aliases)
    ~["a different mold name was accepted"]
  ?^  (prelude-union-alias:jibb orig ~[[%atom %t]] aliases)
    ~["a different arity was accepted"]
  =/  fixed-public=@t
    '/= internal /lib/jibb/internal\0a+$ specialized (union-source.internal @t @p)\0a'
  =/  fixed-prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb fixed-public internal)
  ?~  fixed-prepared  ~["fixed specialization prelude did not prepare"]
  ?^  (prelude-union-alias:jibb orig args molds.iface.u.fixed-prepared)
    ~["nongeneric specialization was printed with arguments"]
  =/  fixed-dep=@t  '++ identity |= x=specialized x\0a'
  =/  fixed-source=@t  '/= dep /ui/dep\0a++ exposed identity.dep\0a'
  =/  fixed-report=@t
    (golden-types-with-prepared-prelude:jibb /ui/client/jibb fixed-source ~ ~ ~[[/ui/dep/jibb fixed-dep]] fixed-prepared)
  ?.  =(fixed-report 'module kind: library\0a++ exposed: $-(specialized specialized)')
    ~["fixed specialization import did not print its public mold name"]
  ~
++  test-generic-alias
  ^-  tang
  (turn generic-alias-errors |=(reason=tape leaf+reason))
--
