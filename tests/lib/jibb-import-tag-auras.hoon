::  Literal head tags use noun equality, including non-term Hoon auras.
/+  jibb-import
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
  ?.  ?=([%invalid %overlap *] bad)
    ~[leaf+"noun-equal %& and %0 were not reported as overlapping: {(show-import-diagnostic:jibb-import bad)}"]
  =/  separate  (read-named-diagnostic:jibb-import %fixture %separate cor)
  ?.  ?=([%ok *] separate)
    ~[leaf+"noun-equal heads with disjoint payloads were rejected"]
  =/  vase  (read-named-diagnostic:jibb-import %fixture %boxed cor)
  ?.  ?=([%invalid %vase *] vase)
    ~[leaf+"a standard vase was not reported as invalid"]
  ~
--
