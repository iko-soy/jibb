/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  original-source  %txt  /tests/type-record-origin/original/txt
/*  duplicate-source  %txt  /tests/type-record-origin/duplicate/txt
/*  inline-source  %txt  /tests/type-record-origin/inline/txt
/*  valid-source  %txt  /tests/type-record-origin/valid/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
++  test-record-origins
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/w-path/jibb
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb at (text original-source) ~ ~ ~ prepared)
  =/  expected=@t  '++ main: record molds `model` and `other` do not unify\0a/tests/w-path.jibb:1:4: expected record mold\0a+$ model [xs=(list @t) draft=@t error=(unit @t)]\0a   ^\0a/tests/w-path.jibb:2:4: actual record mold\0a+$ other [xs=(list @t) draft=@t error=(unit @t) extra=@ud]\0a   ^'
  ?.  =(actual expected)  ~[leaf+"record-origin diagnostic differs" leaf+(trip actual)]
  =/  duplicate-report=@t  (golden-types-with-prepared-prelude:jibb at (text duplicate-source) ~ ~ ~ prepared)
  ?:  (contains (trip duplicate-report) "record molds `model` and `other`")  ~[leaf+"ambiguous duplicate mold acquired a guessed origin"]
  =/  inline-report=@t  (golden-types-with-prepared-prelude:jibb at (text inline-source) ~ ~ ~ prepared)
  ?:  (contains (trip inline-report) "record molds `model` and `other`")  ~[leaf+"unreferenced mold acquired a guessed origin"]
  =/  good=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at (text valid-source) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.good)  ~[leaf+"matching record molds were rejected" leaf+(trip message.p.good)]
  ~
--
