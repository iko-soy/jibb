/+  jibb
/*  expected  %txt  /tests/type-import-diagnostic/incomplete-reader-expected/txt
|%
++  report
  ^-  @t
  =/  cast=@t  '/- foo\0a++ cast ^- bad.foo 0\0a\0a++ safe |= x=@t x\0a'
  =/  sample=@t  '/- foo\0a\0a++ sample |= x=bad.foo x\0a++ safe |= x=@t x\0a'
  =/  undeclared=@t  '++ cast ^- bad.foo 0\0a++ safe |= x=@t x\0a'
  =/  invalid=*  [%invalid %aura 'signed and float auras cannot be imported']
  =/  unsupported=*  [%unsupported 'Hoon type is unsupported']
  =/  duplicate=iexternals:jibb  ~[[%foo %bad invalid] [%foo %bad invalid]]
  =/  unsupported-input=iexternals:jibb  ~[[%foo %bad unsupported]]
  =/  forged-code=iexternals:jibb  ~[[%foo %bad [%invalid %other 'forged']]]
  =/  malformed=iexternals:jibb  ~[[%foo %bad [%invalid %aura [1 2]]]]
  =/  valid-error=iexternals:jibb  ~[[%foo %bad invalid]]
  =/  duplicate-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast duplicate ~)
  =/  duplicate-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample duplicate ~)
  =/  unsupported-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast unsupported-input ~)
  =/  unsupported-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample unsupported-input ~)
  =/  forged-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast forged-code ~)
  =/  forged-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample forged-code ~)
  =/  malformed-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast malformed ~)
  =/  malformed-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample malformed ~)
  =/  missing-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast ~ ~)
  =/  missing-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~ ~)
  =/  unimported=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb undeclared valid-error ~)
  =/  valid-cast=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb cast valid-error ~)
  =/  valid-sample=@t  (golden-types-with-reader-diagnostics:jibb /test/jibb sample valid-error ~)
  (of-wain:format ~['duplicate cast:' duplicate-cast 'duplicate sample:' duplicate-sample 'unsupported cast:' unsupported-cast 'unsupported sample:' unsupported-sample 'forged cast:' forged-cast 'forged sample:' forged-sample 'malformed cast:' malformed-cast 'malformed sample:' malformed-sample 'missing cast:' missing-cast 'missing sample:' missing-sample 'unimported:' unimported 'valid reader cast:' valid-cast 'valid reader sample:' valid-sample])
++  test-incomplete-reader
  ^-  tang
  ?~  expected  ~[leaf+"incomplete-reader expectations are missing"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"incomplete-reader diagnostics differ"]
  ~
--
