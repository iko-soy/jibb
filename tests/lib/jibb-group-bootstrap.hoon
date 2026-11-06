/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  group
  ^-  @t
  '/- jibb-collections\0a+$ step @u\0a+$ map |$ [K V] (table.jibb-collections K V)\0a++ convert |= x=@t (bootstrap-id x)\0a'
++  public
  ^-  @t
  (cat 3 prelude '\0a++ bootstrap-id |= x=@t x\0a+$ bootstrap-bite\0a  bloq\0a  [bloq=bloq step=step.hoon]\0a++ bite-id |= b=bootstrap-bite b\0a++ forwarded bite-id\0a++ group-gate convert.hoon\0a++ local-dependent\0a  +$ local-bite bootstrap-bite\0a  |= b=local-bite b\0a++ forward-local local-dependent\0a+$ group-step step.hoon\0a++ group-step-id |= x=group-step x\0a')
++  test-bootstrap-dependent-values
  ^-  tang
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  prep=(each iprelude:jibb @t)  (prepare-bundle-detailed:jibb-prelude-fixture public internal groups ~)
  ?:  ?=(%| -.prep)  ~[leaf+(trip p.prep)]
  =/  bite=(unit ischeme:jibb)  (find-jibb-mold:jibb %bootstrap-bite iface.p.prep)
  ?~  bite  ~[leaf+"completed public mold is missing"]
  ?~  (find-jibb-mold:jibb %group-step iface.p.prep)  ~[leaf+"direct group mold alias is missing"]
  ?~  (ienv-lookup:jibb %group-step-id values.iface.p.prep)  ~[leaf+"direct group mold dependent value is missing"]
  =/  one=(unit ischeme:jibb)  (ienv-lookup:jibb %bite-id values.iface.p.prep)
  =/  two=(unit ischeme:jibb)  (ienv-lookup:jibb %forwarded values.iface.p.prep)
  =/  three=(unit ischeme:jibb)  (ienv-lookup:jibb %group-gate values.iface.p.prep)
  =/  four=(unit ischeme:jibb)  (ienv-lookup:jibb %local-dependent values.iface.p.prep)
  =/  five=(unit ischeme:jibb)  (ienv-lookup:jibb %forward-local values.iface.p.prep)
  ?~  four  ~[leaf+"local mold dependency was not checked in the final pass"]
  ?~  five  ~[leaf+"local mold dependent alias is missing"]
  ?.  =(u.four u.five)  ~[leaf+"local mold alias has a different scheme"]
  ?~  one  ~[leaf+"mold-dependent public value is missing"]
  ?~  two  ~[leaf+"transitively dependent public value is missing"]
  ?~  three  ~[leaf+"direct group-dependent public value is missing"]
  ?.  =(u.one u.two)  ~[leaf+"forwarded public value has a different scheme"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.three)
  ?~  typ  ~[leaf+"group-dependent gate did not close"]
  ?.  =((show-itype:jibb u.typ ~) "$-(@t @t)")  ~[leaf+"group-dependent gate has wrong type"]
  ~
++  test-bootstrap-circular-dependency
  ^-  tang
  =/  source=@t  '+$ step @u\0a++ convert bite-id\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb source]]
  ?^  (prepare-groups:jibb-prelude-fixture public internal groups)  ~[leaf+"circular group dependency was accepted"]
  ~
++  test-bootstrap-unrelated-failure
  ^-  tang
  =/  broken=@t  (cat 3 public '\0a++ broken (unknown-name 0)\0a')
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  ?^  (prepare-groups:jibb-prelude-fixture broken internal groups)  ~[leaf+"unrelated invalid public definition was skipped"]
  ~
++  test-bootstrap-invalid-public-mold
  ^-  tang
  =/  broken=@t  (cat 3 public '\0a+$ missing thing.unknown\0a')
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  ?^  (prepare-groups:jibb-prelude-fixture broken internal groups)  ~[leaf+"unresolved public mold was published"]
  ~
--
