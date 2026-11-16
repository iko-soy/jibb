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
++  test-imported-set-key-diagnostic
  ^-  tang
  =/  sur=@t  '|%\0a+$  texts  (set @t)\0a+$  nouns  (set *)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  texts=*  (read-named:jibb-import %fixture %texts cor)
  =/  nouns=*  (read-named:jibb-import %fixture %nouns cor)
  ?.  &(?=(%& -.texts) ?=(%& -.nouns))  ~[leaf+"the Hoon reader rejected a set before the checker boundary"]
  =/  at=path  /tests/import-set/jibb
  =/  ext=iexternals:jibb  ~[[%fixture %texts texts] [%fixture %nouns nouns]]
  =/  source=@t  '/- fixture\0a++ identity |= x=texts.fixture x\0a'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"an imported set with a gate-free key was rejected" leaf+(trip message.p.checked)]
  =/  identity=(unit ischeme:jibb)  (ienv-lookup:jibb %identity values.iface.p.checked)
  ?~  identity  ~[leaf+"safe imported set identity was not exported"]
  ?.  =((show-itype:jibb typ.u.identity ~) "$-((set @t) (set @t))")
    ~[leaf+"safe imported set changed type" leaf+(show-itype:jibb typ.u.identity ~)]
  =/  invalid=@t  '/- fixture\0a+$ box nouns.fixture\0a'
  =/  rejected=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at invalid ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.rejected)  ~[leaf+"an imported set with a noun key was accepted"]
  =/  expected=@t
    (of-wain:format ~['+$ box: set keys cannot contain `*`, which a gate or an element may fit' '/tests/import-set.jibb:2:8: invalid imported mold' '+$ box nouns.fixture' '       ^'])
  ?.  =(expected message.p.rejected)
    ~[leaf+"imported set noun-key diagnostic differs" leaf+"expected:" leaf+(trip expected) leaf+"actual:" leaf+(trip message.p.rejected)]
  ~
--
