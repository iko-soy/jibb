::  A used Hoon vase is an invalid imported mold at its Jibb use site.
/+  jibb, jibb-import
|%
++  test-import-vase
  ^-  tang
  =/  source=@t
    (rap 3 (turn ~['|%' '+$  boxed  vase' '--'] |=(line=@t (cat 3 line '\0a'))))
  =/  cor=type  -:(ride -:!>(..zuse) source)
  =/  vase  (read-named-diagnostic:jibb-import %fixture %boxed cor)
  ?.  ?=([%invalid %vase *] vase)
    ~[leaf+"reader did not classify a vase as invalid"]
  =/  external=(list [module=term name=term result=*])  ~[[%fixture %boxed vase]]
  =/  jibb-source=@t  (of-wain:format ~['/- fixture' '++ keep |= x=boxed.fixture x'])
  =/  at=path  /ui/probe/jibb
  =/  checked  (infer-jibb-file-detailed:jibb at jibb-source external ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.checked)  ~[leaf+"full checker accepted an imported vase"]
  =/  lines=wall  (turn (to-wain:format message.p.checked) |=(line=@t (trip line)))
  ?.  (lien lines |=(line=tape =(line "++ keep: vases cannot be imported")))
    ~[leaf+"full checker lost the vase diagnostic: {(trip message.p.checked)}"]
  ?.  (lien lines |=(line=tape =(line "/ui/probe.jibb:2:14: invalid imported mold")))
    ~[leaf+"full checker did not locate the vase use"]
  ~
--
