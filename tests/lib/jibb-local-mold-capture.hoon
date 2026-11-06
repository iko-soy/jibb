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
++  test-local-mold-capture
  ^-  tang
  =/  src=@t  '++ make |= x=A\0a  +$ box |$ [B] [outer=A inner=B]\0a  ^- (box @t) [outer=x inner="hi"]\0a++ ship (make ~zod)\0a++ word (make "ho")\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %ship values.iface.p.got)
  =/  word=(unit ischeme:jibb)  (ienv-lookup:jibb %word values.iface.p.got)
  ?~  ship  ~[leaf+"ship missing"]
  ?~  word  ~[leaf+"word missing"]
  =/  a=(unit itype:jibb)  (scheme-display-type:jibb u.ship)
  =/  b=(unit itype:jibb)  (scheme-display-type:jibb u.word)
  ?~  a  ~[leaf+"ship did not close"]
  ?~  b  ~[leaf+"word did not close"]
  ?.  =((show-itype:jibb u.a ~) "[outer=@p inner=@t]")
    ~[leaf+(weld "ship differs: " (show-itype:jibb u.a ~))]
  ?.  =((show-itype:jibb u.b ~) "[outer=@t inner=@t]")
    ~[leaf+(weld "word differs: " (show-itype:jibb u.b ~))]
  ~
++  test-capture-independent-local-capital
  ^-  tang
  =/  src=@t  '++ make |= x=A\0a  +$ box |$ [B] [outer=A inner=B]\0a  ++ relay |= y=B\0a    ^- (box @t) [outer=x inner="hi"]\0a  (relay ~zod)\0a++ result (make "ho")\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result values.iface.p.got)
  ?~  result  ~[leaf+"result missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?~  shown  ~[leaf+"result did not close"]
  ?.  =((show-itype:jibb u.shown ~) "[outer=@t inner=@t]")
    ~[leaf+(weld "captured root changed: " (show-itype:jibb u.shown ~))]
  ~
++  test-capture-does-not-leak
  ^-  tang
  =/  bads=(list @t)
    ~['++ make |= x=A\0a  +$ box |$ [B] [outer=C inner=B]\0a  ^- (box @t) [outer=x inner="hi"]\0a' '+$ box |$ [B] [outer=A inner=B]\0a++ make |= x=A ^- (box @t) [outer=x inner="hi"]\0a' '++ maker |= x=A\0a  +$ box |$ [B] [outer=A inner=B]\0a  x\0a++ outside |= x=A ^- (box @t) [outer=x inner="hi"]\0a']
  |-
  ?~  bads  ~
  =/  got=jfile-detailed-result:jibb  (run-source i.bads)
  ?:  ?=(%& -.got)  ~[leaf+"an unbound mold capital was captured from the wrong scope"]
  $(bads t.bads)
++  test-nongeneric-capture
  ^-  tang
  =/  src=@t  '++ identity |= x=A\0a  +$ alias A\0a  ^- alias x\0a++ ship (identity ~zod)\0a++ word (identity "hi")\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  a=(unit ischeme:jibb)  (ienv-lookup:jibb %ship values.iface.p.got)
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %word values.iface.p.got)
  ?~  a  ~[leaf+"ship missing"]
  ?~  b  ~[leaf+"text missing"]
  ?.  &(=([%atom %p] typ.u.a) =([%atom %t] typ.u.b))
    ~[leaf+"non-generic local mold did not preserve the enclosing capital"]
  ~
++  test-capture-in-late-match
  ^-  tang
  =/  src=@t  '++ make |= [x=A selector]\0a  +$ box |$ [B] [outer=A inner=B]\0a  ?- selector\0a    %.y ^- (box @t) [outer=x inner="yes"]\0a    %.n ^- (box @t) [outer=x inner="no"]\0a++ ship (make ~zod %.y)\0a'
  =/  got=jfile-detailed-result:jibb  (run-source src)
  ?:  ?=(%| -.got)  ~[leaf+(trip message.p.got)]
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %ship values.iface.p.got)
  ?~  ship  ~[leaf+"ship missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.ship)
  ?~  shown  ~[leaf+"ship did not close"]
  ?.  =((show-itype:jibb u.shown ~) "[outer=@p inner=@t]")
    ~[leaf+(weld "late match lost captured capital: " (show-itype:jibb u.shown ~))]
  ~
--
