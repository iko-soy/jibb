::  Closed-gate sample labels must not erase nested faces or uncertain origins.
/+  jibb
|%
++  closed-gate-guard-errors
  ^-  (list tape)
  =/  t=itype:jibb  [%atom %t]
  =/  p=itype:jibb  [%atom %p]
  =/  n=itype:jibb  [%atom %ud]
  =/  tag=itype:jibb  [%const [%term %tas %delta '%delta']]
  =/  payload=itype:jibb  [%cell tag n]
  =/  bare=itype:jibb  [%cell payload t]
  =/  named=itype:jibb  [%cell [%face %diff payload] [%face %state t]]
  =/  differently-named=itype:jibb  [%cell [%face %other payload] [%face %state t]]
  =/  face-one=itype:jibb  [%face %first t]
  =/  face-two=itype:jibb  [%face %second t]
  =/  inner-one=itype:jibb  [%cell face-one n]
  =/  inner-two=itype:jibb  [%cell face-two n]
  =/  nested-a=itype:jibb  [%cell [%face %diff inner-one] [%face %state t]]
  =/  nested-b=itype:jibb  [%cell inner-two t]
  =/  tail-a=itype:jibb  [%cell payload [%face %rest [%cell t n]]]
  =/  tail-b=itype:jibb  [%cell payload [%cell t n]]
  =/  samples-mismatch=itype:jibb  [%cell payload p]
  =/  cases=(list [label=@t actual=itype:jibb expected=itype:jibb sub=isub:jibb want=?])
    :~  ['named fold to bare' [%fn named t] [%fn bare t] ~ &]
        ['same named gate' [%fn named t] [%fn named t] ~ &]
        ['different slot names' [%fn named t] [%fn differently-named t] ~ |]
        ['different nested names' [%fn nested-a t] [%fn nested-b t] ~ |]
        ['faced tail versus cell' [%fn tail-a t] [%fn tail-b t] ~ |]
        ['different result face' [%fn bare face-one] [%fn bare face-two] ~ |]
        ['faced result versus bare' [%fn bare face-one] [%fn bare t] ~ |]
        ['wrong sample aura' [%fn named t] [%fn samples-mismatch t] ~ |]
        ['wrong result aura' [%fn named p] [%fn bare t] ~ |]
        ['open sample' [%fn [%var 0] t] [%fn bare t] ~ &]
        ['variable-bound sample' [%fn [%var 0] t] [%fn bare t] ~[[0 named]] |]
        ['variable-bound actual function' [%var 0] [%fn bare t] ~[[0 [%fn named t]]] |]
        ['variable-bound expected function' [%fn bare t] [%var 0] ~[[0 [%fn named t]]] |]
    ==
  =/  outcomes=(list @t)
    %+  turn  cases
    |=  c=[label=@t actual=itype:jibb expected=itype:jibb sub=isub:jibb want=?]
    =/  fit=ifit:jibb  (itype-fit:jibb actual.c expected.c sub.c 1)
    ?:  =(want.c ?=(%ok -.fit))  ''
    (cat 3 label.c ': unexpected fit')
  =/  bad=(list @t)  (skim outcomes |=(s=@t !=(s '')))
  =/  build
    |=  depth=@ud
    ^-  [a=itype:jibb b=itype:jibb]
    =/  a=itype:jibb  [%face %inside t]
    =/  b=itype:jibb  t
    |-
    ?:  =(depth 0)  [a b]
    $(depth (dec depth), a [%fn [%cell a t] t], b [%fn [%cell b t] t])
  =/  deep  (build 12)
  =/  deep-fit=ifit:jibb  (itype-fit:jibb a.deep b.deep ~ 0)
  =?  bad  !?=(%unknown -.deep-fit)  ['nested gate face uncertainty changed' bad]
  (turn bad trip)
++  test-closed-gate-guards
  ^-  tang
  (turn closed-gate-guard-errors |=(reason=tape leaf+reason))
--
