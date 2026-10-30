::  Exercise supplied prelude scope and fail-closed module imports.
/+  jibb
/*  expected  %txt  /tests/type-module-scope/expected/txt
|%
++  test-module-scope
  ^-  tang
  ?~  expected  ~[leaf+"module scope expected output is missing"]
  =/  got  scope-output
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"module scope output differs from tests/type-module-scope/expected.txt"]
  ~
++  scope-output
  ^-  @t
  =/  source=@t  (crip "/= dep /ui/dep\0a++ identity |= x=value.dep x\0a++ atom mold.dep\0a")
  =/  dep=@t  (crip "+$ value @t\0a++ mold ~zod\0a")
  =/  prelude=@t  (crip "++ value |= x x\0a+$ mold @t\0a")
  =/  fixtures=(list [at=path source=@t])  ~[[~[%ui %dep %jibb] dep]]
  =/  okay  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures prelude)
  =/  empty  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures '')
  =/  bad  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures (crip "+$"))
  =/  conflict=@t  (crip "/= value /ui/dep\0a++ identity |= x x\0a")
  =/  collision  (golden-types-with-prelude:jibb /ui/main/jibb conflict ~ ~ fixtures prelude)
  (of-wain:format ~[okay empty bad collision])
--
