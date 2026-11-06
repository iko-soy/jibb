/+  jibb, jibb-import
|%
++  test-recursive-map-import
  ^-  tang
  =/  sur=@t  '|%\0a+$  tree  $%  [%leaf value=@ud]  [%node kids=(map @t tree)]  ==\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  result  (read-named:jibb-import %fixture %tree cor)
  ?:  ?=(%| -.result)  ~[leaf+"recursive map import failed: {(trip p.result)}"]
  =/  found=(unit itype:jibb)  (find-imported-mold:jibb %fixture %tree ~[[%fixture %tree result]] ~[%fixture])
  ?.  ?=([~ [%recursive %fixture %tree *]] found)  ~[leaf+"recursive map did not reach bridge"]
  =/  source=@t  '/- fixture\0a++ identity |= x=tree.fixture x\0a'
  =/  at=path  /tests/import-map/jibb
  =/  ext=iexternals:jibb  ~[[%fixture %tree result]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"recursive map checker failed: {(trip message.p.checked)}"]
  ~
--
