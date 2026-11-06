/+  jibb
/*  expected  %txt  /tests/type-import-diagnostic/mold-controls-expected/txt
|%
++  report
  ^-  @t
  =/  invalid=*  [%invalid %aura 'signed and float auras cannot be imported']
  =/  input=iexternals:jibb  ~[[%foo %first [%invalid %core 'cores and gates cannot be imported']] [%foo %bad invalid]]
  =/  duplicate=iexternals:jibb  ~[[%foo %bad invalid] [%foo %bad invalid]]
  =/  generic=@t  '/- foo\0a+$ box |$ [A] [first=A second=bad.foo]\0a'
  =/  earlier=@t  '/- foo\0a+$ box [first=first.foo second=bad.foo]\0a'
  =/  repeated=@t  '/- foo\0a+$ box [first=bad.foo second=bad.foo]\0a'
  =/  dup=@t  '/- foo\0a+$ box bad.foo\0a'
  =/  okay=@t  '/- foo\0a+$ box |$ [A] [first=A second=@t]\0a++ id |= x=(box @ud) x\0a'
  =/  generic-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb generic input ~)
  =/  earlier-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb earlier input ~)
  =/  repeated-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb repeated input ~)
  =/  dup-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb dup duplicate ~)
  =/  okay-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb okay input ~)
  =/  union=@t  '/- foo\0a+$ box\0a  %none\0a  [%some bad.foo]\0a'
  =/  application=@t  '/- foo\0a+$ box (list bad.foo)\0a'
  =/  bad-callee=@t  '/- foo\0a+$ box (bad.foo @t)\0a'
  =/  nested-good=@t  '++ good |= [a=@t [b=@t c=@t]] a\0a'
  =/  repeated-value-faces=@t  '++ good |= [outer=[same=@t] inner=[same=@t]] inner\0a'
  =/  union-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb union input ~)
  =/  application-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb application input ~)
  =/  bad-callee-r=@t  (golden-types-with-reader-diagnostics:jibb /tests/mold-control/jibb bad-callee input ~)
  =/  nested-good-r=@t  (golden-types:jibb /tests/mold-control/jibb nested-good)
  =/  faces-r=@t  (golden-types:jibb /tests/mold-control/jibb repeated-value-faces)
  (of-wain:format ~['generic:' generic-r 'earlier:' earlier-r 'repeated:' repeated-r 'duplicate input:' dup-r 'valid:' okay-r 'union:' union-r 'application:' application-r 'bad callee:' bad-callee-r 'nested good:' nested-good-r 'independent faces:' faces-r])
++  test-import-mold-controls
  ^-  tang
  ?~  expected  ~[leaf+"mold diagnostic control expectations are missing"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"mold diagnostic controls differ"]
  ~
--
