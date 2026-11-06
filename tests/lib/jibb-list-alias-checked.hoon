/+  jibb
|%
++  report
  ^-  @t
  =/  prelude=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a'
  =/  positive=@t  '++ text-value |= x=(alias @t) x\0a++ ship |= x=(alias @p) x\0a'
  =/  wrong=@t  '++ wrong ^- (alias @t) ~[~zod]\0a'
  =/  shadow=@t  '++ shadow |= x=(list @t)\0a  +$ list @t\0a  x\0a'
  =/  a=@t  (golden-types-with-prelude:jibb /ui/test/jibb positive ~ ~ ~ prelude)
  =/  b=@t  (golden-types-with-prelude:jibb /ui/test/jibb wrong ~ ~ ~ prelude)
  =/  c=@t  (golden-types-with-prelude:jibb /ui/test/jibb shadow ~ ~ ~ prelude)
  (of-wain:format ~['positive' a 'wrong' b 'shadow' c])
++  test-list-alias-checked
  ^-  tang
  =/  expected=@t  'positive\0amodule kind: library\0a++ text-value: $-((list @t) (list @t))\0a++ ship: $-((list @p) (list @p))\0awrong\0a++ wrong: list item does not fit its expected type\0a/ui/test.jibb:1:13: expected item has type @t\0a++ wrong ^- (alias @t) ~[~zod]\0a            ^\0a/ui/test.jibb:1:26: list item has type @p\0a++ wrong ^- (alias @t) ~[~zod]\0a                         ^\0ashadow\0a++ shadow: local mold `list` shadows an imported or prelude name\0a/lib/jibb/prelude.jibb:1:4: earlier binding\0a+$ list |$ [A]\0a   ^\0a/ui/test.jibb:2:3: conflicting local mold\0a  +$ list @t\0a  ^\0a'
  ?.  =((cat 3 report '\0a') expected)
    ~[leaf+"checked list alias reports differ"]
  ~
--
