::  Nested tagged-case context requires a direct union and unique explicit case.
/+  jibb
|%
++  nested-union-base-errors
  ^-  (list tape)
  =/  a=itype:jibb  [%cell [%const [%term %tas %a '%a']] [%atom %t]]
  =/  b=itype:jibb  [%cell [%const [%term %tas %b '%b']] [%atom %p]]
  =/  union=itype:jibb  [%union ~[a b] ~ ~ ~]
  =/  variable=itype:jibb  [%var 0]
  =/  bound=isub:jibb  (isub-from-bindings:jibb ~[[0 union]])
  =/  failures=(list tape)  ~
  =?  failures  !(contextual-direct-union:jibb union)
    ["direct union not recognized" failures]
  =?  failures  !(contextual-direct-union:jibb [%face %item union])
    ["explicit faced union not recognized" failures]
  =?  failures  (contextual-direct-union:jibb variable)
    ["variable-bound root treated as direct union" failures]
  =/  tests=(list [label=@t target=itype:jibb tag=@ sub=isub:jibb expect=?])
    :~  ['unique tag' union %a ~ &]
        ['missing tag' union %missing ~ |]
        ['null-headed zero' [%union ~[[%cell [%const [%null %n 0 '~']] [%atom %t]] b] ~ ~ ~] 0 ~ &]
        ['loobean-headed zero' [%union ~[[%cell [%const [%loobean %f 0 '%.y']] [%atom %t]] b] ~ ~ ~] 0 ~ &]
        ['term-headed zero' [%union ~[[%cell [%const [%term %tas 0 '%$']] [%atom %t]] b] ~ ~ ~] 0 ~ &]
        ['equal zero heads' [%union ~[[%cell [%const [%null %n 0 '~']] [%atom %t]] [%cell [%const [%loobean %f 0 '%.y']] [%atom %p]]] ~ ~ ~] 0 ~ |]
        ['variable root' variable %a bound |]
        ['bare term competitor' [%union ~[a [%const [%term %tas %b '%b']]] ~ ~ ~] %a ~ &]
        ['null competitor' [%union ~[a [%const [%null %n 0 '~']]] ~ ~ ~] %a ~ &]
        ['noun competitor' [%union ~[a [%noun ~]] ~ ~ ~] %a ~ |]
        ['variable competitor' [%union ~[a variable] ~ ~ ~] %a bound |]
        ['variable head' [%union ~[a [%cell variable [%atom %t]]] ~ ~ ~] %a bound |]
        ['duplicate tag' [%union ~[a a] ~ ~ ~] %a ~ |]
        ['duplicate other head' [%union ~[a b [%cell [%const [%term %tas %b '%b']] [%atom %t]]] ~ ~ ~] %a ~ |]
        ['faced competitor' [%union ~[a [%face %x b]] ~ ~ ~] %a ~ |]
    ==
  =/  errs=(list @t)
    %+  turn  tests
    |=  test=[label=@t target=itype:jibb tag=@ sub=isub:jibb expect=?]
    =/  found=(unit itype:jibb)  (contextual-tagged-case:jibb target.test tag.test sub.test)
    ?:  =(expect.test ?=(^ found))  ''
    (cat 3 label.test ': incorrect case selection')
  (weld (turn (skim errs |=(x=@t !=(x ''))) trip) failures)
++  test-nested-union-guards
  ^-  tang
  (turn nested-union-base-errors |=(reason=tape leaf+reason))
--
