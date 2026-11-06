/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  fixture  %txt  /tests/type-deferred-prepared/main/txt
/*  library-source  %txt  /tests/type-deferred-prepared/good/txt
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
++  test-gate-main
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  source=@t  '++ main |= x=@t x\0a'
  =/  at=path  /tests/main-kind/jibb
  =/  out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.out)  ~[leaf+"gate main accepted"]
  =/  expected=@t  '++ main: main has gate type $-(@t @t); expected an element, page, program, or store\0a/tests/main-kind.jibb:1:4: main has a gate type\0a++ main |= x=@t x\0a   ^'
  ?.  =(message.p.out expected)  ~[leaf+"gate main diagnostic differs" leaf+(trip message.p.out)]
  ~
++  test-gate-main-alias
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  source=@t  (text fixture)
  =/  at=path  /tests/prepared-main/jibb
  =/  out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.out)  ~[leaf+"aliased gate main accepted"]
  =/  expected=@t  '++ main: main has gate type $-((list @t) [(list @t) [@t (unit @t)]]); expected an element, page, program, or store'
  ?.  (contains (trip message.p.out) (trip expected))  ~[leaf+"aliased gate main diagnostic differs" leaf+(trip message.p.out)]
  ?.  (contains (trip message.p.out) "/tests/prepared-main.jibb:10:4: main has a gate type\0a++ main initial\0a   ^")  ~[leaf+"main name site missing" leaf+(trip message.p.out)]
  ~
++  test-library-under-api-path
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  source=@t  (text library-source)
  =/  at=path  /ui/api/prepared/jibb
  =/  out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.out)  ~[leaf+"ordinary library under the API path was rejected" leaf+(trip message.p.out)]
  ?.  =(%library kind.p.out)  ~[leaf+"ordinary API-path library has the wrong kind"]
  ~
--
