::  The unmodified Tlon presence /sur passes through the real reader into
::  the partial checker, under both eval and Clay.
/+  jibb, jibb-import
/*  presence  %txt  /tests/importer/tlon-presence/txt
/*  source    %txt  /tests/type-tlon/source/txt
/*  expected  %txt  /tests/type-tlon/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-tlon-bridge
  ^-  tang
  ?~  presence  ~[leaf+"Tlon presence fixture is missing"]
  ?~  source  ~[leaf+"Tlon bridge source is missing"]
  ?~  expected  ~[leaf+"Tlon bridge expected output is missing"]
  =/  got  (bridge-output (text presence) (text source))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"Tlon bridge output differs from tests/type-tlon/expected.txt"]
  ~
++  bridge-output
  |=  [sur=@t src=@t]
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  names=(list term)  ~[%action-1 %command-1 %update-1 %response-1 %key]
  =/  external=(list [module=term name=term result=*])
    (turn names |=(n=term [%presence n (read-named:jibb-import %presence n cor)]))
  (golden-types-imports:jibb /test/jibb src external)
--
