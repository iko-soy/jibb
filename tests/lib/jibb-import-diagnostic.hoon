::  Exercise definite and unsupported reader diagnostics through the checker.
/+  jibb, jibb-import
/*  sur       %txt  /tests/type-import-diagnostic/sur/txt
/*  mark      %txt  /tests/type-import-diagnostic/mark/txt
/*  source    %txt  /tests/type-import-diagnostic/source/txt
/*  expected  %txt  /tests/type-import-diagnostic/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-import-diagnostic
  ^-  tang
  ?~  sur  ~[leaf+"diagnostic /sur fixture is missing"]
  ?~  mark  ~[leaf+"diagnostic mark fixture is missing"]
  ?~  source  ~[leaf+"diagnostic source fixture is missing"]
  ?~  expected  ~[leaf+"diagnostic expected output is missing"]
  =/  got  (diagnostic-output (text sur) (text mark) (text source))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"import diagnostic output differs from tests/type-import-diagnostic/expected.txt"]
  ~
++  diagnostic-output
  |=  [sur-text=@t mark-text=@t src=@t]
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) sur-text)
  =/  mark-cor=type  -:(ride -:!>(..zuse) mark-text)
  =/  ext=(list [module=term name=term result=*])
    :~  [%fixture %signed (read-named-diagnostic:jibb-import %fixture %signed cor)]
        [%fixture %core (read-named-diagnostic:jibb-import %fixture %core cor)]
        [%fixture %good (read-named-diagnostic:jibb-import %fixture %good cor)]
    ==
  =/  marks=(list [name=term result=*])
    ~[[%bad-mark (read-mark-diagnostic:jibb-import %bad-mark mark-cor)]]
  =/  real  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb src ext marks)
  =/  sample=@t  (crip "/- foo\0a++ cast ^- bad.foo 0\0a++ sample |= x=bad.foo x\0a++ safe |= x=@t x\0a")
  =/  noimport=@t  (crip "++ cast ^- bad.foo 0\0a++ safe |= x=@t x\0a")
  =/  shadow=@t  (crip "/- foo\0a++ shadow |= shadow=bad.foo shadow\0a++ safe |= x=@t x\0a")
  =/  invalid  [%invalid %aura 'signed and float auras cannot be imported']
  =/  unsupported  [%unsupported 'Hoon type is unsupported']
  =/  dup  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~[[%foo %bad invalid] [%foo %bad invalid]] ~)
  =/  inconclusive  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~[[%foo %bad unsupported]] ~)
  =/  bad-code  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~[[%foo %bad [%invalid %other 'forged']]] ~)
  =/  bad-message  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~[[%foo %bad [%invalid %aura [1 2]]]] ~)
  =/  absent  (golden-types-with-reader-diagnostics:jibb /test/jibb noimport ~[[%foo %bad invalid]] ~)
  =/  collision  (golden-types-with-reader-diagnostics:jibb /test/jibb shadow ~[[%foo %bad invalid]] ~)
  =/  missing  (golden-types-with-reader-diagnostics:jibb /test/jibb sample ~ ~)
  =/  unused-src=@t  (crip "/- foo\0a++ safe |= x=@t x\0a")
  =/  unused  (golden-types-with-reader-diagnostics:jibb /test/jibb unused-src ~[[%foo %bad invalid]] ~)
  =/  import-clash=@t  (crip "/- foo\0a/% %foo\0a++ use |= x=bad.foo x\0a++ use-mark |= x=foo x\0a")
  =/  value-clash=@t  (crip "/- foo\0a++ foo \"value\"\0a++ use |= x=bad.foo x\0a")
  =/  mold-clash=@t  (crip "/% %foo\0a+$ foo @t\0a++ use |= x=foo x\0a")
  =/  ic  (golden-types-with-reader-diagnostics:jibb /test/jibb import-clash ~[[%foo %bad invalid]] ~[[%foo invalid]])
  =/  vc  (golden-types-with-reader-diagnostics:jibb /test/jibb value-clash ~[[%foo %bad invalid]] ~)
  =/  mc  (golden-types-with-reader-diagnostics:jibb /test/jibb mold-clash ~ ~[[%foo invalid]])
  (of-wain:format ~['real reader:' real 'duplicate:' dup 'unsupported:' inconclusive 'unknown code:' bad-code 'malformed message:' bad-message 'missing:' missing 'unused:' unused 'undeclared:' absent 'shadow:' collision 'import clash:' ic 'value clash:' vc 'mold clash:' mc])
--
