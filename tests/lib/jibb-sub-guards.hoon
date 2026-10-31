::  Source-backed sub retains the public ask and depends on its actual source.
/+  jibb
/*  public  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  sub-guard-errors
  ^-  (list tape)
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prep  ~["real prelude did not prepare"]
  ?~  (find-jibb-mold:jibb %sub iface.u.prep)  ~["sub is unavailable in real prelude"]
  =/  intro=@t  '/= internal /lib/jibb/internal\0a'
  =/  list-src=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a'
  =/  unit-src=@t  '+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a'
  =/  ask-src=@t  '+$ ask |$ [M] (ask.internal M)\0a'
  =/  path-src=@t  '+$ knot @ta\0a+$ path (list knot)\0a'
  =/  sub-src=@t  '+$ sub |$ [M]\0a  [%watch a=(ask M)]\0a  [%every gap=@dr reply=$-(@da M)]\0a  [%url reply=$-(path M)]\0a'
  =/  cases=(list [label=@t src=@t want=?])
    :~  ['minimal' (rap 3 ~[intro list-src unit-src ask-src path-src sub-src]) &]
        ['missing ask' (rap 3 ~[intro list-src unit-src path-src sub-src]) |]
        ['missing list' (rap 3 ~[intro unit-src ask-src path-src sub-src]) |]
        ['missing unit' (rap 3 ~[intro list-src ask-src path-src sub-src]) |]
        ['missing path' (rap 3 ~[intro list-src unit-src ask-src sub-src]) |]
        ['altered list' (rap 3 ~[intro '+$ list |$ [A] ~\0a' unit-src ask-src path-src sub-src]) |]
        ['valid alternate path' (rap 3 ~[intro list-src unit-src ask-src '+$ path @t\0a' sub-src]) &]
    ==
  =/  failures=(list @t)
    %+  turn  cases
    |=  c=[label=@t src=@t want=?]
    =/  p=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb src.c internal)
    =/  present=?  ?~(p | ?=(^ (find-jibb-mold:jibb %sub iface.u.p)))
    ?:  =(want.c present)  ''
    (cat 3 label.c ': unexpected availability')
  (turn (skim failures |=(x=@t !=(x ''))) trip)
++  test-sub-guards
  ^-  tang
  (turn sub-guard-errors |=(reason=tape leaf+reason))
--
