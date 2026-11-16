/+  jibb
|%
++  test-values
  =>  jibb
  ^-  tang
  |^  =/  cases=(list [label=@t src=@t call=? wanted=*])
        :~  ['identity and named fields' '++ identity |= item item\0a++ pair |= [x y] [left=x right=y]\0a++ chosen (identity 42)\0a++ both (pair chosen 13)\0a++ value left.both\0a' | [%atom 42]]
            ['captured lexical value' '++ keep |= saved |= discard saved\0a++ held (keep 42)\0a++ value (held 13)\0a' | [%atom 42]]
            ['known branch' '++ value\0a  ?- %.y\0a  %.y 42\0a  %.n 13\0a' | [%atom 42]]
            ['unknown condition' '++ value |= flag\0a  ?- flag\0a  %.y 42\0a  %.n 13\0a' & [%choice ~[[%atom 42] [%atom 13]]]]
            ['unknown noun cell pattern' '++ value |= subject\0a  ?- subject\0a  [a b] 42\0a  * 13\0a' & [%choice ~[[%atom 42] [%atom 13]]]]
            ['recursive unknown is unproved' '++ value |= item (value item)\0a' & [%unknown ~]]
            ['later local definition' '++ value\0a  ++ answer (identity 42)\0a  ++ identity |= item item\0a  answer\0a' | [%atom 42]]
            ['closure instances retain captured values' '++ wrap |= next |= value (next value)\0a++ chain |= [items final]\0a  ?- items\0a  ~ final\0a  [head rest] (wrap (chain rest final))\0a++ value ((chain ~[1 2 3] |=(item 42)) 0)\0a' | [%atom 42]]
            ['explicit unface preserves value' '++ value (unface [name=42])\0a' | [%atom 42]]
            ['flat tuple cannot match an atom tail' '++ value\0a  ?- ~[1]\0a  [i j k] 13\0a  [i ~] 42\0a  ~ 7\0a' | [%atom 42]]
            ['flat tuple is uncertain on an unknown tail' '++ value |= s\0a  ?- [1 s]\0a  [n i t] 13\0a  [n ~] 42\0a' & [%choice ~[[%atom 13] [%atom 42]]]]
            ['flat tuple is certain on a known cell tail' '++ value\0a  ?- ~[1 2]\0a  [i j k] 42\0a  [i ~] 13\0a  ~ 7\0a' | [%atom 42]]
            ['doubly referenced definition chain' (doubled-chain 30) | [%atom 1]]
        ==
      %+  murn  cases
      |=  c=[label=@t src=@t call=? wanted=*]
      =/  actual=*  (run src.c call.c)
      ?:  =(actual wanted.c)  ~
      `[%rose [" " "[" "]"] ~[leaf+(trip label.c) (noun-tank actual)]]
  ++  noun-tank
    |=  n=*
    ^-  tank
    ?@  n  leaf+(scow %ud n)
    [%rose [" " "[" "]"] ~[$(n -.n) $(n +.n)]]
  ::  ++ a<k> (fst [a<k-1> a<k-1>]) up to a<n>: evaluating every reference
  ::  anew would evaluate a0 2^n times.
  ++  doubled-chain
    |=  n=@ud
    ^-  @t
    =/  lines=(list tape)  ~["++ fst |= p" "  ?- p" "  [a b] a" "++ a0 1"]
    =/  k=@ud  1
    |-
    ?.  (lte k n)
      (crip (zing (turn (snoc lines "++ value a{<n>}") |=(line=tape (weld line "\0a")))))
    $(k +(k), lines (snoc lines "++ a{<k>} (fst [a{<(dec k)>} a{<(dec k)>}])"))
  ++  run
    |=  [source=@t call=?]
    ^-  *
    =/  at=path  /tests/watch-values/jibb
    =/  parsed  (parse at source)
    ?:  ?=(%| -.parsed)  [%parse-error (show-error source p.parsed)]
    =/  iface=ifile  [~ ~ at ~ ~ ~ `source ~ ~]
    =/  prelude=ifile  [~ ~ /lib/jibb/prelude/jibb ~ ~ ~ ~ ~ ~]
    =/  graph=irequest-graph  [~ ~ ~ ~ ~ ~ ~ ~ ~]
    =/  context=iav-context  (iav-context-new (~(put by *(map path ifile)) at iface) prelude graph)
    =/  result=iav-value  -:(iav-member at %value context 256 ~ ~)
    =?  result  call
      -:(iav-call result (iav-unknown [at *span]) [at *span] context 256 ~ ~)
    (iav-value-key result 32)
  --
--
