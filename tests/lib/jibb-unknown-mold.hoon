/+  jibb
/*  expected  %txt  /tests/type-import-diagnostic/unknown-mold-expected/txt
|%
++  report
  ^-  @t
  =/  invalid=*  [%invalid %aura 'signed and float auras cannot be imported']
  =/  input=iexternals:jibb  ~[[%foo %bad invalid]]
  =/  first=@t  '/- foo\0a+$ box [first=missing second=bad.foo]\0a'
  =/  second=@t  '/- foo\0a+$ box [first=bad.foo second=missing]\0a'
  =/  sample=@t  '++ bad |= x=missing x\0a'
  =/  applied=@t  '++ bad ^- (missing @t) !!\0a'
  =/  known=@t  '+$ known @t\0a++ good |= x=known x\0a'
  =/  generic=@t  '+$ box |$ [A] [first=A second=@t]\0a++ good |= x=(box @ud) x\0a'
  =/  f=@t  (golden-types-with-reader-diagnostics:jibb /tests/unknown-mold/jibb first input ~)
  =/  s=@t  (golden-types-with-reader-diagnostics:jibb /tests/unknown-mold/jibb second input ~)
  =/  a=@t  (golden-types:jibb /tests/unknown-mold/jibb sample)
  =/  b=@t  (golden-types:jibb /tests/unknown-mold/jibb applied)
  =/  c=@t  (golden-types:jibb /tests/unknown-mold/jibb known)
  =/  d=@t  (golden-types:jibb /tests/unknown-mold/jibb generic)
  (of-wain:format ~['unknown first:' f 'reader first:' s 'sample:' a 'application:' b 'known:' c 'generic:' d])
++  test-unknown-mold
  ^-  tang
  ?~  expected  ~[leaf+"unknown-mold expected output is missing"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"unknown-mold diagnostics differ"]
  ~
--
