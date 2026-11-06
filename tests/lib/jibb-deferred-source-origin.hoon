/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  wrong-source  %txt  /tests/type-deferred-origin/wrong/txt
/*  valid-source  %txt  /tests/type-deferred-origin/valid/txt
/*  decoy-source  %txt  /tests/type-deferred-origin/decoy/txt
/*  alias-source  %txt  /tests/type-deferred-origin/alias/txt
/*  null-source  %txt  /tests/type-deferred-origin/null/txt
/*  null-decoy-source  %txt  /tests/type-deferred-origin/null-decoy/txt
/*  priority-source  %txt  /tests/type-deferred-origin/priority/txt
/*  aura-priority-source  %txt  /tests/type-deferred-origin/aura-priority/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-source-origin
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/w-path/jibb
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb at (text wrong-source) ~ ~ ~ prepared)
  =/  expected=@t  '++ init: value does not fit its expected type\0a/tests/w-path.jibb:1:24: expected field type has type @t\0a+$ model [xs=(list @t) draft=@t error=(unit @t)]\0a                       ^\0a/tests/w-path.jibb:6:29: value has type @p\0a++ init |= ts=(list @t) [ts ~zod ~]\0a                            ^'
  ?.  =(actual expected)  ~[leaf+"wrong initializer diagnostic differs" leaf+(trip actual)]
  =/  decoy=@t  (golden-types-with-prepared-prelude:jibb at (text decoy-source) ~ ~ ~ prepared)
  =/  expected-decoy=@t  '++ init: value does not fit its expected type\0a/tests/w-path.jibb:1:24: expected field type has type @t\0a+$ model [xs=(list @t) draft=@t error=(unit @t)]\0a                       ^\0a/tests/w-path.jibb:7:29: value has type @p\0a++ init |= ts=(list @t) [ts ~zod ~]\0a                            ^'
  ?.  =(decoy expected-decoy)  ~[leaf+"unrelated same-shaped value captured the origin" leaf+(trip decoy)]
  =/  alias=@t  (golden-types-with-prepared-prelude:jibb at (text alias-source) ~ ~ ~ prepared)
  =/  expected-alias=@t  '++ init: value does not fit its expected type\0a/tests/w-path.jibb:1:24: expected field type has type @t\0a+$ model [xs=(list @t) draft=@t error=(unit @t)]\0a                       ^\0a/tests/w-path.jibb:7:29: value has type @p\0a++ init |= ts=(list @t) [ts ~zod ~]\0a                            ^'
  ?.  =(alias expected-alias)  ~[leaf+"local alias lost its checked source" leaf+(trip alias)]
  =/  null=@t  (golden-types-with-prepared-prelude:jibb at (text null-source) ~ ~ ~ prepared)
  =/  expected-null=@t  '++ init: value does not fit its expected type\0a/tests/w-path.jibb:1:33: expected field type has type @t\0a+$ model [xs=(list @t) draft=@t error=@t]\0a                                ^\0a/tests/w-path.jibb:6:32: value has type ~\0a++ init |= ts=(list @t) [ts "" ~]\0a                               ^'
  ?.  =(null expected-null)  ~[leaf+"wrong null initializer diagnostic differs" leaf+(trip null)]
  =/  null-decoy=@t  (golden-types-with-prepared-prelude:jibb at (text null-decoy-source) ~ ~ ~ prepared)
  =/  expected-null-decoy=@t  '++ init: value does not fit its expected type\0a/tests/w-path.jibb:1:33: expected field type has type @t\0a+$ model [xs=(list @t) draft=@t error=@t]\0a                                ^\0a/tests/w-path.jibb:7:32: value has type ~\0a++ init |= ts=(list @t) [ts "" ~]\0a                               ^'
  ?.  =(null-decoy expected-null-decoy)  ~[leaf+"another null captured the initializer origin" leaf+(trip null-decoy)]
  =/  priority=@t  (golden-types-with-prepared-prelude:jibb at (text priority-source) ~ ~ ~ prepared)
  =/  expected-priority=@t  '++ independent: nothing fixes the union of %orphan; add a `^-`\0a/tests/w-path.jibb:5:16: nothing fixes the union of %orphan; add a `^-`\0a++ independent %orphan\0a               ^'
  ?.  =(priority expected-priority)  ~[leaf+"an earlier independent tag lost diagnostic priority" leaf+(trip priority)]
  =/  aura-priority=@t  (golden-types-with-prepared-prelude:jibb at (text aura-priority-source) ~ ~ ~ prepared)
  ?.  =(aura-priority expected-priority)  ~[leaf+"aura mismatch hid an earlier independent tag" leaf+(trip aura-priority)]
  =/  valid=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at (text valid-source) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.valid)  ~[leaf+"valid initializer rejected" leaf+(trip message.p.valid)]
  ~
--
