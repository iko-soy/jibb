::  Literal head tags use noun equality, including non-term Hoon auras.
/+  jibb, jibb-import
|%
++  test-import-tag-auras
  ^-  tang
  =/  src=@t
    (rap 3 (turn ~['|%' '+$  choice  $%([%& a=@ud] [%| b=@t] [%2 c=@ud])' '+$  overlap  $%([%& a=@ud] [%0 b=@ud])' '+$  separate  $%([%& @ud] [%0 [a=@ud b=@ud]])' '+$  boxed  vase' '--'] |=(line=@t (cat 3 line '\0a'))))
  =/  cor=type  -:(ride -:!>(..zuse) src)
  =/  good  (read-named:jibb-import %fixture %choice cor)
  =/  bad  (read-named-diagnostic:jibb-import %fixture %overlap cor)
  ?.  ?=([%& [%fork *]] good)
    ~[leaf+"non-term head tags did not import as a union"]
  ?.  =("invalid/overlap: Hoon union cases overlap" (show-import-diagnostic:jibb-import bad))
    ~[leaf+"noun-equal %& and %0 diagnostic differs: {(show-import-diagnostic:jibb-import bad)}"]
  =/  negative-source=@t  '/- fixture\0a++ bad |= x=overlap.fixture x\0a'
  =/  negative-at=path  /tests/import-negative/jibb
  =/  negative=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb negative-at negative-source ~[[%fixture %overlap bad]] ~ ~ ~[negative-at] ~ ~ ~ ~)
  ?:  ?=(%& -.negative)  ~[leaf+"full checker accepted noun-equal overlapping heads"]
  =/  negative-expected=@t
    (of-wain:format ~['++ bad: Hoon union cases overlap' '/tests/import-negative.jibb:2:13: invalid imported mold' '++ bad |= x=overlap.fixture x' '            ^'])
  ?.  =(negative-expected message.p.negative)
    ~[leaf+"full-checker overlap diagnostic differs: {(trip message.p.negative)}"]
  =/  separate  (read-named-diagnostic:jibb-import %fixture %separate cor)
  ?.  ?=([%ok *] separate)
    ~[leaf+"noun-equal heads with disjoint payloads were rejected"]
  =/  separate-external=*  ?>(?=(%ok -.separate) [%& value.separate])
  =/  positive-source=@t
    (of-wain:format ~['/- fixture' '++ split |= x=separate.fixture x' '++ left ^- separate.fixture [%& 1]' '++ right ^- separate.fixture [%0 [a=1 b=2]]'])
  =/  positive-at=path  /tests/import-positive/jibb
  =/  positive=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb positive-at positive-source ~[[%fixture %separate separate-external]] ~ ~ ~[positive-at] ~ ~ ~ ~)
  ?:  ?=(%| -.positive)
    ~[leaf+"full checker rejected disjoint noun-equal heads: {(trip message.p.positive)}"]
  =/  vase  (read-named-diagnostic:jibb-import %fixture %boxed cor)
  ?.  ?=([%invalid %vase *] vase)
    ~[leaf+"a standard vase was not reported as invalid"]
  ~
--
