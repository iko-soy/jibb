::  Compare source-backed list alias preparation under eval and ship.
/+  jibb
/*  expected  %txt  /tests/type-list-alias/expected/txt
|%
++  list-alias-output
  ^-  @t
  =/  src=@t  (crip "++ text-value |= x=(alias @t) x\0a++ ship |= x=(alias @p) x\0a++ wrong ^- (alias @t) ~[~zod]\0a++ shadow |= x=(list @t)\0a  +$ list @t\0a  x\0a")
  =/  canonical=@t  (crip "+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a")
  =/  altered=@t  (crip "+$ list |$ [A] [A A]\0a+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a")
  =/  omitted=@t  (crip "+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a")
  =/  duplicate=@t  (crip "+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ list |$ [A] [A A]\0a+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a")
  =/  malformed=@t  (crip "+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)\0a")
  =/  cyclic=@t  (crip "+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ bag |$ [A] (alias A)\0a+$ alias |$ [A] (bag A)\0a")
  =/  good  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ canonical)
  =/  bad  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ altered)
  =/  missing  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ omitted)
  =/  repeated  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ duplicate)
  =/  broken  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ malformed)
  =/  cycle  (golden-types-with-prelude:jibb /ui/test/jibb src ~ ~ ~ cyclic)
  (of-wain:format ~['canonical' good 'altered' bad 'omitted' missing 'duplicate' repeated 'malformed' broken 'cyclic' cycle])
++  test-list-alias-guards
  ^-  tang
  ?~  expected  ~[leaf+"list alias expected output is missing"]
  ?.  =((to-wain:format (cat 3 list-alias-output '\0a')) expected)
    ~[leaf+"list alias preparation differs from its golden"]
  ~
--
