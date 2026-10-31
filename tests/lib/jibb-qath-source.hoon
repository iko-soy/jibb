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
  =/  original=(list tape)
    ?:  (levy sources |=(c=[source=@t internal=@t want=@tas] (check-source-prelude source.c internal.c want.c)))  ~
    ~["qath source provenance guard failed"]
  (weld original qath-fallback-errors)
++  qath-fallback-errors
  ^-  (list tape)
  =/  cases=(list [label=@t source=@t private=@t prepared=? qath=? ask=? hidden=?])
    :~  ['neither' '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & | |]
        ['list only' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & | |]
        ['unit only' '/= internal /lib/jibb/internal\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & | |]
        ['altered list' '/= internal /lib/jibb/internal\0a+$ list |$ [A] ~\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & | |]
        ['altered unit' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  %wrong\0a  [~ u=A]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & | |]
        ['canonical' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal & & & &]
        ['duplicate list' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ list |$ [A] ~\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal | | | |]
        ['duplicate unit' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ unit |$ [A] ~\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' real-internal | | | |]
        ['unavailable direct alias' '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a+$ agent-path agent-path.internal\0a' real-internal | | | |]
        ['invalid private mold' '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' (cat 3 real-internal '\0a+$ unrelated missing\0a') | | | |]
        ['invalid private value' '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' (cat 3 real-internal '\0a++ unrelated (missing 1)\0a') | | | |]
        ['invalid private dependency' '/= internal /lib/jibb/internal\0a+$ qath qath.internal\0a+$ ask |$ [M] (ask.internal M)\0a+$ hidden (ask @t)\0a' (cat 3 real-internal '\0a+$ bad (missing @t)\0a+$ unrelated bad\0a') | | | |]
    ==
  =/  outcomes=(list tape)
    %+  turn  cases
    |=  c=[label=@t source=@t private=@t prepared=? qath=? ask=? hidden=?]
    =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb source.c private.c)
    ?:  !=(prepared.c ?=(^ prep))  (weld (trip label.c) ": wrong preparation result")
    ?~  prep  ""
    =/  q=?  ?=(^ (find-jibb-mold:jibb %qath iface.u.prep))
    =/  a=?  ?=(^ (find-jibb-mold:jibb %ask iface.u.prep))
    =/  h=?  ?=(^ (find-jibb-mold:jibb %hidden iface.u.prep))
    ?:  !=(q qath.c)  (weld (trip label.c) ": wrong qath availability")
    ?:  !=(a ask.c)  (weld (trip label.c) ": wrong ask availability")
    ?:  !=(h hidden.c)  (weld (trip label.c) ": wrong transitive alias availability")
    ""
  (skim outcomes |=(x=tape !=(x "")))
++  test-qath-source
  ^-  tang
  (turn qath-source-errors |=(reason=tape leaf+reason))
--
