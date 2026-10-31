::  Source-backed qath accepts only the proven public and internal interfaces.
/+  jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
|%
++  check-literal-interface
  |=  [prelude=(unit ifile:jibb) okay=?]
  ^-  ?
  =/  literal=expr:jibb  [%qath *span:jibb ~[[%knot 'foo']]]
  =/  state=istate:jibb  *istate:jibb
  =/  out=iresult:jibb  (infer-fragment:jibb literal ~ state(prelude prelude, jrec-fuel 2))
  ?:(okay ?=(%& -.out) ?=(%| -.out))
++  check-source-prelude
  |=  [source=@t internal=@t want=@tas]
  ^-  ?
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb source internal)
  ?:  =(%unprepared want)  ?=(~ prepared)
  ?~  prepared  |
  (check-literal-interface `iface.u.prepared =(%accept want))
++  qath-source-errors
  ^-  (list tape)
  =/  minimal=@t  '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a'
  =/  sources=(list [source=@t internal=@t want=@tas])
    :~  [minimal real-internal %accept]
        [minimal '' %unprepared]
        ['++ identity |= x x\0a' real-internal %decline]
        ['+$ qath @t\0a' real-internal %decline]
        [minimal '+$ qath @t\0a' %decline]
    ==
  ?:  (levy sources |=(c=[source=@t internal=@t want=@tas] (check-source-prelude source.c internal.c want.c)))  ~
  ~["qath source provenance guard failed"]
++  test-qath-source
  ^-  tang
  (turn qath-source-errors |=(reason=tape leaf+reason))
--
