/+  jibb, jibb-import
/*  sur       %txt  /tests/type-import-structural/sur/txt
/*  source    %txt  /tests/type-import-structural/source/txt
/*  expected  %txt  /tests/type-import-structural/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-import-structural
  ^-  tang
  ?~  sur  ~[leaf+"structural overlap /sur is missing"]
  ?~  source  ~[leaf+"structural overlap client is missing"]
  ?~  expected  ~[leaf+"structural overlap expected is missing"]
  =/  got  (structural-output (text sur) (text source))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"structural overlap output differs from expected"]
  ~
++  structural-output
  |=  [sur-text=@t src=@t]
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) sur-text)
  =/  names=(list term)
    ~[%same-alias %separate-alias %deep-match %deep-distinct %tail-distinct %later-overlap %many-safe %open-atoms %different-aura]
  =/  cases=wall
    %+  turn  names
    |=  n=term
    "{(trip n)}: {(show-import-diagnostic:jibb-import (read-named-diagnostic:jibb-import %fixture n cor))}"
  =/  ext=(list [module=term name=term result=*])
    :~  [%fixture %deep-match (read-named-diagnostic:jibb-import %fixture %deep-match cor)]
        [%fixture %separate-alias (read-named-diagnostic:jibb-import %fixture %separate-alias cor)]
        [%fixture %different-aura (read-named-diagnostic:jibb-import %fixture %different-aura cor)]
        [%fixture %later-overlap (read-named-diagnostic:jibb-import %fixture %later-overlap cor)]
    ==
  =/  report=@t  (golden-types-with-reader-diagnostics:jibb /ui/structural/jibb src ext ~)
  =/  zero=imported:jibb-import  [%atom %tas `0]
  =/  one=imported:jibb-import  [%atom %tas `1]
  =/  two=imported:jibb-import  [%atom %tas `2]
  =/  txt=imported:jibb-import  [%atom %t ~]
  =/  ship=imported:jibb-import  [%atom %p ~]
  =/  flag=imported:jibb-import  [%atom %f ~]
  =/  opaque=imported:jibb-import  [%ref %m %x]
  =/  named=imported:jibb-import  [%named %m %x zero]
  =/  arm  (local-arm-source:jibb-import cor %later-overlap)
  ?~  arm  !!
  =/  shape  (local-mold-spec:jibb-import u.arm %later-overlap)
  ?~  shape  !!
  =/  body  (tagged-default-union:jibb-import u.shape 4)
  ?~  body  !!
  ?>  ?=([%bcwt *] u.body)
  =/  specs=(list spec)  p.u.body
  ?~  specs  !!
  =/  checks=(list [label=@t ok=?])
    :~  ['same literal' ?=([~ [%.y *]] (overlap-pair:jibb-import zero zero 20))]
        ['different literals' ?=([~ [%.n *]] (overlap-pair:jibb-import one two 20))]
        ['named expands' ?=([~ [%.y *]] (overlap-pair:jibb-import named zero 20))]
        ['opaque declines' ?=([~ [%.n *]] (overlap-pair:jibb-import opaque opaque 20))]
        ['opaque versus noun' ?=([~ [%.n *]] (overlap-pair:jibb-import opaque [%noun ~] 20))]
        ['unknown aura' ?=([~ [%.n *]] (overlap-pair:jibb-import ship txt 20))]
        ['open admits zero' ?=([~ [%.y *]] (overlap-pair:jibb-import flag zero 20))]
        ['different tail' ?=([~ [%.n *]] (overlap-pair:jibb-import [%cell zero one] [%cell zero two] 20))]
        ['nested face' ?=([~ [%.y *]] (overlap-pair:jibb-import [%face %a [%cell named one]] [%face %b [%cell zero one]] 20))]
        ['fork later case' ?=([~ [%.y *]] (overlap-pair:jibb-import [%fork ~[one zero]] zero 20))]
        ['empty fuel' ?=(~ (overlap-pair:jibb-import zero zero 0))]
        ['cell needs both' ?=(~ (overlap-pair:jibb-import [%cell zero one] [%cell zero one] 2))]
        ['later pair' ?=([~ [%.y *]] (overlap-case-pairs:jibb-import ~[one two zero zero] 100))]
        ['pair fuel' ?=(~ (overlap-case-pairs:jibb-import ~[one two zero zero] 2))]
        ['void' ?=([~ [%.n *]] (overlap-pair:jibb-import [%void ~] [%noun ~] 20))]
        ['void position' ?=([~ [%.n *]] (overlap-pair:jibb-import [%cell zero [%void ~]] [%cell zero [%noun ~]] 20))]
        ['opaque apply' ?=([~ [%.n *]] (overlap-pair:jibb-import [%apply %list ~[txt]] [%noun ~] 20))]
        ['source node fuel' ?=(~ (overlap-source-cases:jibb-import specs 1 128))]
        ['source case cap' ?=(~ (overlap-source-cases:jibb-import specs 4.096 3))]
        ['wrong projected head' !(overlap-projections-match:jibb-import ~[[%a i.specs]] ~[[%cell [%atom %tas `%b] txt]])]
        ['wrong case count' !(overlap-projections-match:jibb-import ~[[%a i.specs]] ~)]
    ==
  =/  results=wall
    %+  turn  checks
    |=  c=[label=@t ok=?]
    "{(trip label.c)}: {?:(ok.c "ok" "BAD")}"
  =/  lines=(list @t)  (turn (weld cases results) |=(line=tape (crip line)))
  (cat 3 (of-wain:format lines) (cat 3 '\0a' report))
--
