/+  jibb, jibb-import
|%
++  test-recursive-set-import
  ^-  tang
  =/  sur=@t  '|%\0a+$  tree  $%  [%leaf value=@ud]  [%node kids=(set tree)]  ==\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  result  (read-named:jibb-import %fixture %tree cor)
  ?:  ?=(%| -.result)  ~[leaf+"recursive set import failed: {(trip p.result)}"]
  =/  found=(unit itype:jibb)  (find-imported-mold:jibb %fixture %tree ~[[%fixture %tree result]] ~[%fixture])
  ?.  ?=([~ [%recursive %fixture %tree *]] found)  ~[leaf+"recursive set did not reach bridge"]
  =/  source=@t  '/- fixture\0a++ identity |= x=tree.fixture x\0a'
  =/  at=path  /tests/import-set/jibb
  =/  ext=iexternals:jibb  ~[[%fixture %tree result]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"recursive set checker failed: {(trip message.p.checked)}"]
  ~
--
