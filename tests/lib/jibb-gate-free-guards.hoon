::  Budgeted gate-free verdicts require a witness and an inhabited sibling.
/+  jibb
|%
++  gate-free-guard-errors
  ^-  (list tape)
  =/  atom=itype:jibb  [%atom %t]
  =/  flag=itype:jibb  [%flag ~]
  =/  noun=itype:jibb  [%noun ~]
  =/  var=itype:jibb  [%var 0]
  =/  gate=itype:jibb  [%fn atom atom]
  =/  item=itype:jibb  [%cell [%face %id [%atom %ud]] [%cell [%face %done flag] [%face %text atom]]]
  =/  model=itype:jibb  [%cell [%face %todos [%collection %list ~[item]]] [%cell [%face %draft atom] [%face %error [%union ~[[%const [%null %n 0 '~']] [%cell [%const [%null %n 0 '~']] [%face %u atom]]] ~ ~ ~]]]]
  =/  with-callback=itype:jibb  [%cell [%face %data atom] [%face %callback gate]]
  =/  ask-like=itype:jibb  [%union ~[[%cell [%const [%term %tas %pure '%pure']] [%face %value atom]] [%cell [%const [%term %tas %agent '%agent']] [%face %receive gate]]] ~ ~ ~]
  =/  sub-like=itype:jibb  [%union ~[[%cell [%const [%term %tas %watch '%watch']] [%face %request ask-like]] [%cell [%const [%term %tas %every '%every']] [%face %reply gate]]] ~ ~ ~]
  =/  controls=(list [name=@t typ=itype:jibb fuel=@ud want=?(%yes %no %unknown)])
    :~  ['atom' atom 8 %yes]
        ['flag' flag 8 %yes]
        ['atom variable' [%avar 0] 8 %yes]
        ['open variable' var 8 %unknown]
        ['noun' noun 8 %unknown]
        ['raw gate' gate 8 %no]
        ['data item' item 30 %yes]
        ['todo model' model 100 %yes]
        ['callback field' with-callback 30 %no]
        ['ask receiver' ask-like 100 %no]
        ['subscription receiver' sub-like 100 %no]
        ['list of data items' [%collection %list ~[item]] 40 %yes]
        ['list of gates' [%collection %list ~[gate]] 20 %no]
        ['other collection' [%collection %map ~[atom atom]] 20 %unknown]
        ['open list member' [%collection %list ~[var]] 20 %unknown]
        ['known-inhabited noun after gate' [%cell gate noun] 30 %no]
        ['known-inhabited noun before gate' [%cell noun gate] 30 %no]
        ['unknown sibling after gate' [%cell gate var] 30 %unknown]
        ['unknown sibling before gate' [%cell var gate] 30 %unknown]
        ['nested unknown sibling' [%cell [%face %callback gate] [%face %other var]] 30 %unknown]
        ['unknown union and gate union' [%union ~[var gate] ~ ~ ~] 30 %no]
        ['empty union' [%union ~ ~ ~ ~] 30 %unknown]
        ['validated jrec qath' [%jrec /lib/jibb/internal/jibb %qath ~ %i %ta %t] 30 %yes]
        ['jrec gate sibling' [%cell gate [%jrec /lib/jibb/internal/jibb %qath ~ %i %ta %t]] 30 %no]
        ['jrec list member' [%collection %list ~[[%jrec /lib/jibb/internal/jibb %qath ~ %i %ta %t]]] 30 %yes]
        ['nominal recursion' [%recursive %sur %node ~] 30 %unknown]
        ['unknown sibling budget' [%cell gate var] 2 %unknown]
        ['known sibling budget' [%cell gate atom] 2 %unknown]
        ['zero budget' atom 0 %unknown]
        ['one atom budget' atom 1 %yes]
        ['cell needs 3 visits' [%cell atom flag] 2 %unknown]
        ['cell exact 3 visits' [%cell atom flag] 3 %yes]
    ==
  =/  errors=(list @t)
    %+  turn  controls
    |=  c=[name=@t typ=itype:jibb fuel=@ud want=?(%yes %no %unknown)]
    =/  result=igate-free:jibb  (gate-free-type:jibb typ.c fuel.c ~)
    ?:  =(want.c verdict.result)  ''
    (cat 3 name.c ': wrong verdict')
  =/  a=igate-free:jibb  (gate-free-type:jibb with-callback 30 ~)
  =?  errors  !=(path.a `~[[%tail ~] [%field %callback]])  ['callback path incorrect' errors]
  =/  b=igate-free:jibb  (gate-free-type:jibb [%collection %list ~[gate]] 20 ~)
  =?  errors  !=(path.b `~[[%item ~]])  ['list path incorrect' errors]
  =/  c=igate-free:jibb  (gate-free-type:jibb model 100 ~)
  =?  errors  ?=(^ path.c)  ['gate-free result carries witness path' errors]
  ::  The explicit budget is shared across the entire normalized type.
  =/  deep
    |=  depth=@ud
    ^-  itype:jibb
    =/  out=itype:jibb  [%atom %t]
    |-
    ?:  =(0 depth)  out
    $(depth (dec depth), out [%face %nested out])
  =/  fits=igate-free:jibb  (gate-free-type:jibb (deep 255) 256 ~)
  =/  exceeds=igate-free:jibb  (gate-free-type:jibb (deep 256) 256 ~)
  =?  errors  !=(%yes verdict.fits)  ['256 node budget rejected exact fit' errors]
  =?  errors  !=(%unknown verdict.exceeds)  ['257 node budget did not fail closed' errors]
  =/  errors  (skim errors |=(x=@t !=(x '')))
  (turn errors trip)
++  test-gate-free-guards
  ^-  tang
  (turn gate-free-guard-errors |=(reason=tape leaf+reason))
--
