/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  run-source
  |=  src=@t
  ^-  jfile-detailed-result:jibb
  =/  prep=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb group]])
  ?~  prep  [%| ['prelude did not prepare' ~]]
  =/  file=path  /tests/local-mold-capture/jibb
  (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
++  test-recursive-local-mold-capture
  ^-  tang
  =/  src=@t  '++ extract |= x=A\0a  +$ chain |$ [B]\0a    ~\0a    [outer=A inner=B rest=(chain B)]\0a  ++ first |= xs=(chain @t)\0a    ?- xs\0a      ~ x\0a      [v b r] v\0a  (first (^- (chain @t) [outer=x inner="ok" rest=~]))\0a++ ship (extract ~zod)\0a++ word (extract "hi")\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  a=(unit ischeme:jibb)  (ienv-lookup:jibb %ship values.iface.p.got)
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %word values.iface.p.got)
  ?~  a  ~[leaf+"ship missing"]
  ?~  b  ~[leaf+"word missing"]
  ?.  &(=([%atom %p] typ.u.a) =([%atom %t] typ.u.b))
    ~[leaf+"recursive local mold lost its enclosing capital"]
  ~
++  test-recursive-capture-does-not-leak
  ^-  tang
  ::  Share only immutable preparation; each case starts fresh inference.
  =/  prep=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/local-mold-capture/jibb
  =/  bads=(list [src=@t want=@t])
    :~  :-  '++ make |= x=A\0a  +$ chain |$ [B]\0a    ~\0a    [outer=C inner=B rest=(chain B)]\0a  ^- (chain @t) [outer=x inner="hi" rest=~]\0a'
        (of-wain:format ~['++ make: local molds need unsupported inference' '/tests/local-mold-capture.jibb:1:14: gate sample mold' '++ make |= x=A' '             ^'])
        :-  '+$ chain |$ [B]\0a  ~\0a  [outer=A inner=B rest=(chain B)]\0a++ make |= x=A ^- (chain @t) [outer=x inner="hi" rest=~]\0a'
        (of-wain:format ~['+$ chain: mold needs unsupported inference' '/tests/local-mold-capture.jibb:1:10: unsupported mold' '+$ chain |$ [B]' '         ^'])
        :-  '++ maker |= x=A\0a  +$ chain |$ [B]\0a    ~\0a    [outer=A inner=B rest=(chain B)]\0a  x\0a++ outside |= x=A ^- (chain @t) [outer=x inner="hi" rest=~]\0a'
        (of-wain:format ~['++ outside: mold `chain` is not defined' '/tests/local-mold-capture.jibb:6:22: unknown mold' '++ outside |= x=A ^- (chain @t) [outer=x inner="hi" rest=~]' '                     ^'])
    ==
  |-
  ?~  bads  ~
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src.i.bads ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.got)  ~[leaf+"a recursive mold captured an unbound or out-of-scope capital"]
  ?.  =(want.i.bads message.p.got)
    ~[leaf+"recursive local mold capture diagnostic differs" leaf+"expected:" leaf+(trip want.i.bads) leaf+"actual:" leaf+(trip message.p.got)]
  $(bads t.bads)
++  test-nested-recursive-local-mold-capture
  ^-  tang
  =/  src=@t  '++ extract |= x=A\0a  +$ chain |$ [B]\0a    ~\0a    [outer=A inner=B rest=(chain B)]\0a  +$ bundle |$ [B]\0a    ~\0a    [current=(chain B) rest=(bundle B)]\0a  ++ first |= xs=(chain @t)\0a    ?- xs\0a      ~ x\0a      [v b r] v\0a  ++ unwrap |= bs=(bundle @t)\0a    ?- bs\0a      ~ x\0a      [c r] (first c)\0a  (unwrap (^- (bundle @t) [current=[outer=x inner="ok" rest=~] rest=~]))\0a++ ship (extract ~zod)\0a++ word (extract "hi")\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  a=(unit ischeme:jibb)  (ienv-lookup:jibb %ship values.iface.p.got)
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %word values.iface.p.got)
  ?~  a  ~[leaf+"nested ship missing"]
  ?~  b  ~[leaf+"nested word missing"]
  ?.  &(=([%atom %p] typ.u.a) =([%atom %t] typ.u.b))
    ~[leaf+"nested recursive mold lost its transitive enclosing capital"]
  ~
++  test-recursive-capture-in-late-match
  ^-  tang
  =/  src=@t  '++ extract |= [x=A selector]\0a  +$ chain |$ [B]\0a    ~\0a    [outer=A inner=B rest=(chain B)]\0a  ++ first |= xs=(chain @t)\0a    ?- xs\0a      ~ x\0a      [v b r] v\0a  ?- selector\0a    %.y (first (^- (chain @t) [outer=x inner="yes" rest=~]))\0a    %.n (first (^- (chain @t) [outer=x inner="no" rest=~]))\0a++ word (extract "hi" %.n)\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %word values.iface.p.got)
  ?~  b  ~[leaf+"deferred word missing"]
  ?.  =([%atom %t] typ.u.b)
    ~[leaf+"deferred recursive mold lost its enclosing capital"]
  ~
--
