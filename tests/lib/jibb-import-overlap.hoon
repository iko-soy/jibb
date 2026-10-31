/+  jibb, jibb-import
/*  sur       %txt  /tests/type-import-overlap/sur/txt
/*  source    %txt  /tests/type-import-overlap/source/txt
/*  expected  %txt  /tests/type-import-overlap/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-import-overlap
  ^-  tang
  ?~  sur  ~[leaf+"overlap fixture source is missing"]
  ?~  source  ~[leaf+"overlap fixture client is missing"]
  ?~  expected  ~[leaf+"overlap fixture expected output is missing"]
  =/  got  (overlap-output (text sur) (text source))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"overlap output differs from expected"]
  ~
++  bounded-screen-status
^-  @t
?.  ?=(~ (bounded-no-spec-unions:jibb-import [1 2] 2))  'three-node noun exceeded limit'
=/  exact  (bounded-no-spec-unions:jibb-import [1 2] 3)
?.  =(exact `0)  'three-node exact budget failed'
?.  ?=(~ (bounded-no-spec-unions:jibb-import [[[[1 2] 3] 4] 5] 8))  'deep noun exceeded limit'
?.  =((bounded-no-spec-unions:jibb-import [[[[1 2] 3] 4] 5] 9) `0)  'deep exact budget failed'
?.  ?=(~ (bounded-no-spec-unions:jibb-import [1 2 3 4 5] 8))  'wide noun exceeded limit'
?.  =((bounded-no-spec-unions:jibb-import [1 2 3 4 5] 9) `0)  'wide exact budget failed'
?.  ?=(~ (bounded-no-spec-unions:jibb-import [%bcwt [[1 2] [[3 4] 0]]] 100))  'nested $? accepted'
?.  ?=(~ (bounded-no-spec-unions:jibb-import [%bccn [[1 2] [[3 4] 0]]] 100))  'nested $% accepted'
?.  ?=(~ (bounded-no-spec-unions:jibb-import [%bckt [1 2] [3 4]] 100))  'nested $^ accepted'
=/  very-deep=*
  =/  n=@ud  1.000
  =/  node=*  0
  |-
  ?:  =(n 0)  node
  $(n (dec n), node [node n])
?.  =((bounded-no-spec-unions:jibb-import very-deep 2.001) `0)  'deep 2,001-node exact budget failed'
?.  ?=(~ (bounded-no-spec-unions:jibb-import very-deep 2.000))  'deep 2,001-node limit exceeded'
=/  xs=(list spec)
  (turn (gulf 1 128) |=(n=@ud `spec`[%bccl ~[[%leaf %tas n] [%base [%atom %t]]]]))
?~  xs  'generated source cases missing'
=/  first=(unit @ud)  (bounded-no-spec-unions:jibb-import i.xs 1.000)
?~  first  'simple source case unavailable'
=/  total=@ud  (mul 128 (sub 1.000 u.first))
=/  at=(unit (list tagged-case:jibb-import))  (tagged-bounded-cases:jibb-import xs ~ total 128)
?~  at  '128 exact cases rejected'
?.  =((lent u.at) 128)  'a source case was omitted'
?.  ?=(~ (tagged-bounded-cases:jibb-import xs ~ (dec total) 128))  'source node limit exceeded'
=/  over=(list spec)  (weld xs ~[`spec`[%bccl ~[[%leaf %tas 129] [%base [%atom %t]]]]])
?.  ?=(~ (tagged-bounded-cases:jibb-import over ~ 100.000 128))  '129 cases exceeded limit'
=/  nested=spec  [%bccl ~[[%leaf %tas %x] [%bcwt ~[[%leaf %tas %a] [%leaf %tas %b]]]]]
?.  ?=(~ (tagged-bounded-cases:jibb-import ~[nested] ~ 1.000 128))  'nested union case accepted'
=/  unknown=spec  [%base [%atom %t]]
?.  ?=(~ (tagged-bounded-cases:jibb-import ~[unknown] ~ 1.000 128))  'non-tagged source accepted'
'bounded source screen controls passed'

++  overlap-output
  |=  [sur-text=@t src=@t]
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) sur-text)
  =/  names=(list term)
    ~[%mixed-zero %nonzero %unequal-singletons %swapped %separate-tags %separate-terms %different-value %different-tail %unknown-middle %unsupported-gate %dollar-percent %identical %cross-zero %boolean-tail %empty-tail]
  =/  cases=wall
    %+  turn  names
    |=  n=term
    "{(trip n)}: {(show-import-diagnostic:jibb-import (read-named-diagnostic:jibb-import %fixture n cor))}"
  =/  other=type  (~(play ut cor) (ream '*separate-tags'))
  =/  provenance=wall
    :~  "mismatched-selected: {(show-result:jibb-import (read-mold-in:jibb-import %fixture %mixed-zero other cor))}"
        "missing: {(show-result:jibb-import (read-named:jibb-import %fixture %missing cor))}"
        "bare-zuse: {(show-result:jibb-import (read-named:jibb-import %fixture %mixed-zero -:!>(..zuse)))}"
    ==
  =/  external=(list [module=term name=term result=*])
    :~  [%fixture %mixed-zero (read-named-diagnostic:jibb-import %fixture %mixed-zero cor)]
        [%fixture %separate-tags (read-named-diagnostic:jibb-import %fixture %separate-tags cor)]
        [%fixture %unknown-middle (read-named-diagnostic:jibb-import %fixture %unknown-middle cor)]
    ==
  =/  report=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb src external ~)
  (cat 3 (of-wain:format (turn (weld cases (weld ~[(trip bounded-screen-status)] provenance)) |=(line=tape (crip line)))) (cat 3 '\0a' report))
--
