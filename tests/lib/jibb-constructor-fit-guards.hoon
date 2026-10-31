::  Constructor cases distinguish proven absence from unknown cases.
/+  jibb
|%
++  constructor-base-errors
  ^-  (list tape)
  =/  tag=lit:jibb  [%term %tas %got '%got']
  =/  t=itype:jibb  [%atom %t]
  =/  p=itype:jibb  [%atom %p]
  =/  good=itype:jibb  [%cell [%const tag] t]
  =/  bad-payload=itype:jibb  [%cell [%const tag] p]
  =/  wrong=itype:jibb  [%cell [%const [%term %tas %other '%other']] t]
  =/  tests=(list [name=@t cases=(list itype:jibb) sub=isub:jibb expected=?(%ok %bad %unknown)])
    :~  ['known matching' ~[good] ~ %ok]
        ['known missing' ~[wrong] ~ %bad]
        ['mismatched payload' ~[bad-payload] ~ %bad]
        ['explicit noun' ~[[%noun ~]] ~ %bad]
        ['unbound case' ~[[%var 0]] ~ %unknown]
        ['bound case remains uncertain' ~[[%var 0]] ~[[0 good]] %unknown]
        ['unknown case alongside match' ~[good [%var 0]] ~ %unknown]
        ['unbound head' ~[[%cell [%var 0] t]] ~ %unknown]
        ['bound head remains uncertain' ~[[%cell [%var 0] t]] ~[[0 [%const tag]]] %unknown]
        ['faced unknown case' ~[[%face %part good]] ~ %unknown]
        ['known atom face at head' ~[[%cell [%face %text t] [%const tag]]] ~ %bad]
        ['nested face at head' ~[[%cell [%face %outer [%face %inner t]] [%const tag]]] ~ %unknown]
    ==
  =/  failures=(list @t)
    %+  turn  tests
    |=  test=[name=@t cases=(list itype:jibb) sub=isub:jibb expected=?(%ok %bad %unknown)]
    =/  got=ifit:jibb  (itype-fit-ctor-cases:jibb tag t cases.test sub.test 1)
    ?:  =(expected.test -.got)  ''
    (cat 3 name.test ': unexpected status')
  ::  Null and other zero-valued literals have different source forms.
  =/  zero-tag=lit:jibb  [%term %tas 0 '%$']
  =/  null-head=itype:jibb  [%cell [%const [%null %n 0 '~']] t]
  =/  flag-head=itype:jibb  [%cell [%const [%loobean %f 0 '%.y']] t]
  =/  term-head=itype:jibb  [%cell [%const zero-tag] t]
  =/  variable-head=itype:jibb  [%cell [%var 0] t]
  =/  zero-tests=(list [name=@t cases=(list itype:jibb) sub=isub:jibb expected=?(%ok %bad %unknown)])
    :~  ['null head' ~[null-head] ~ %ok]
        ['loobean zero head' ~[flag-head] ~ %ok]
        ['matching term zero head' ~[term-head] ~ %ok]
        ['unknown zero head' ~[variable-head] ~ %unknown]
        ['bound unknown zero head' ~[variable-head] ~[[0 [%const zero-tag]]] %unknown]
        ['unknown competitor' ~[null-head variable-head] ~ %unknown]
        ['loobean competitor' ~[term-head flag-head] ~ %unknown]
    ==
  =/  zero-failures=(list @t)
    %+  turn  zero-tests
    |=  test=[name=@t cases=(list itype:jibb) sub=isub:jibb expected=?(%ok %bad %unknown)]
    =/  got=ifit:jibb  (itype-fit-ctor-cases:jibb zero-tag t cases.test sub.test 1)
    ?:  =(expected.test -.got)  ''
    (cat 3 name.test ': unexpected status')
  =/  failures  (skim (weld failures zero-failures) |=(x=@t !=(x '')))
  (turn failures trip)
++  payload-candidates-errors
  ^-  (list tape)
  =/  tag=lit:jibb  [%term %tas %one '%one']
  =/  c=itype:jibb  [%atom %t]
  =/  p=itype:jibb  [%atom %p]
  =/  ud=itype:jibb  [%atom %ud]
  =/  good=itype:jibb  [%cell [%const tag] c]
  =/  other=itype:jibb  [%cell [%const tag] p]
  =/  unknown=itype:jibb  [%cell [%const tag] [%var 0]]
  =/  tests=(list [label=@t sample=itype:jibb cases=(list itype:jibb) want=?(%ok %bad %unknown)])
    :~  ['one fit' c ~[other good] %ok]
        ['one fit reversed' c ~[good other] %ok]
        ['second fit' p ~[good other] %ok]
        ['none fit' ud ~[good other] %bad]
        ['two fit' c ~[good good] %unknown]
        ['unknown rival' c ~[good unknown] %unknown]
        ['unknown rival first' c ~[unknown good] %unknown]
    ==
  =/  errors=(list @t)
    %+  turn  tests
    |=  test=[label=@t sample=itype:jibb cases=(list itype:jibb) want=?(%ok %bad %unknown)]
    =/  got=ifit:jibb  (itype-fit-ctor-cases:jibb tag sample.test cases.test ~ 1)
    ?:  =(want.test -.got)  ''
    (cat 3 label.test ': unexpected status')
  =/  errors  (skim errors |=(x=@t !=(x '')))
  (turn errors trip)
++  flag-fit-errors
  ^-  (list tape)
  =/  flag=itype:jibb  [%flag ~]
  =/  f=itype:jibb  [%atom %f]
  =/  yes=itype:jibb  [%const [%loobean %f 0 '%.y']]
  =/  tests=(list [label=@t actual=itype:jibb expected=itype:jibb sub=isub:jibb want=?(%ok %bad %unknown)])
    :~  ['flag to f' flag f ~ %unknown]
        ['bound flag to f' [%var 0] f ~[[0 flag]] %unknown]
        ['flag to bound f' flag [%var 0] ~[[0 f]] %unknown]
        ['singleton to f' yes f ~ %unknown]
        ['singleton to any' yes [%any-atom ~] ~ %ok]
        ['singleton to flag' yes flag ~ %ok]
        ['singleton to tas' yes [%atom %tas] ~ %bad]
    ==
  =/  errors=(list @t)
    %+  turn  tests
    |=  test=[label=@t actual=itype:jibb expected=itype:jibb sub=isub:jibb want=?(%ok %bad %unknown)]
    =/  got=ifit:jibb  (itype-fit:jibb actual.test expected.test sub.test 1)
    ?:  =(want.test -.got)  ''
    (cat 3 label.test ': unexpected status')
  =/  errors  (skim errors |=(x=@t !=(x '')))
  (turn errors trip)
++  singleton-union-errors
  ^-  (list tape)
  =/  nil=itype:jibb  [%const [%null %n 0 '~']]
  =/  yes=itype:jibb  [%const [%loobean %f 0 '%.y']]
  =/  cell=itype:jibb  [%cell nil [%atom %t]]
  =/  tests=(list [name=@t typ=itype:jibb expect=?])
    :~  ['literal and cell' [%union ~[nil cell] ~ ~ ~] &]
        ['duplicate same-noun literals' [%union ~[nil yes] ~ ~ ~] |]
        ['variable competitor' [%union ~[nil [%var 0]] ~ ~ ~] |]
        ['faced competitor' [%union ~[nil [%face %other cell]] ~ ~ ~] |]
        ['collection competitor' [%union ~[nil [%collection %list ~[[%atom %t]]]] ~ ~ ~] |]
        ['variable root' [%var 0] |]
    ==
  =/  errs=(list @t)
    %+  turn  tests
    |=  test=[name=@t typ=itype:jibb expect=?]
    ?:  =(expect.test (explicit-singleton-in-union:jibb typ.test 0))  ''
    (cat 3 name.test ': incorrect singleton proof')
  (turn (skim errs |=(x=@t !=(x ''))) trip)
++  constructor-fit-guard-errors
  ^-  (list tape)
  (weld constructor-base-errors (weld payload-candidates-errors (weld flag-fit-errors singleton-union-errors)))
++  test-constructor-fit-guards
  ^-  tang
  (turn constructor-fit-guard-errors |=(reason=tape leaf+reason))
--
