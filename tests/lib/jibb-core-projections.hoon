::  Projection actions survive ordinary and recursive common-core inference.
/+  jibb, jibb-prelude-fixture
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  check
  |=  [source=@t names=(list term)]
  ^-  tang
  =/  file=path  /tests/core-projection/jibb
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~[leaf+"projection source failed to parse"]
  =/  defs=(list def:jibb)  defs.p.parsed
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at file, globals (global-value-names:jibb defs), in-mold |, jrec-fuel 256)
  =/  core=icore-output:jibb  (icore-check:jibb defs state)
  ?~  result.core
    ?~  error.core  ~[leaf+"common projection checker declined without a diagnostic"]
    ~[leaf+msg.diag.u.error.core]
  =/  full=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  ?.  =(artifacts.u.result.core elaborations.iface.p.full)
    ~[leaf+"full checker did not retain the common projection artifacts"]
  =/  artifacts=(list iwidth-definition:jibb)  artifacts.u.result.core
  |-
  ?~  names  ~
  =/  entries=(list iwidth-definition:jibb)
    (skim artifacts |=(d=iwidth-definition:jibb =(name.d i.names)))
  ?.  ?=([* ~] entries)  ~[leaf+"projection ownership is not unique"]
  =/  projections=(list iwprojection:jibb)  projections.i.entries
  ?.  ?=([* ~] projections)  ~[leaf+"projection action is missing or duplicated"]
  ?.  =(steps.i.projections ~[[%left 2]])  ~[leaf+"projection kept the wrong record axis"]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb i.names env.u.result.core)
  ?~  scheme  ~[leaf+"projecting definition is missing"]
  =/  visible=(list @ud)  vars.u.scheme
  =/  ids=(list @ud)
    (weld (itype-vars:jibb source.i.projections) (itype-vars:jibb target.i.projections))
  ?.  (levy ids |=(n=@ud (lien visible |=(v=@ud =(n v)))))
    ~[leaf+"projection contains a variable outside its exported scheme"]
  $(names t.names)
++  test-generic-projection
  ^-  tang
  (check '++ pick |= x=[left=A right=B]\0a  ^- [left=A] (proj x)\0a++ text (pick [left="hi" right=~zod])\0a++ ship (pick [left=~zod right="hi"])\0a' ~[%pick])
++  test-mutual-projection
  ^-  tang
  (check '++ first |= [x=[left=@t right=@p] stop=?]\0a  ?- stop\0a  %.y ^- [left=@t] (proj x)\0a  %.n (second x %.y)\0a++ second |= [x=[left=@t right=@p] stop=?]\0a  ?- stop\0a  %.y ^- [left=@t] (proj x)\0a  %.n (first x %.y)\0a' ~[%first %second])
++  check-local
  |=  [source=@t count=@ud quantifiers=@ud numeric=?]
  ^-  tang
  =/  file=path  /tests/local-core-projection/jibb
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~[leaf+"local projection source failed to parse"]
  =/  defs=(list def:jibb)  defs.p.parsed
  =/  prepared=(unit iprelude:jibb)
    ?.(numeric ~ (prepare-groups:jibb-prelude-fixture real-prelude real-internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]]))
  ?:  &(numeric ?=(~ prepared))  ~[leaf+"numeric projection prelude did not prepare"]
  =/  prelude=(unit ifile:jibb)  ?~(prepared ~ `iface.u.prepared)
  =/  values=(list term)  ?~(prepared ~ values.u.prepared)
  =/  molds=(list term)  ?~(prepared ~ molds.u.prepared)
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at file, globals (weld values (global-value-names:jibb defs)), in-mold |, jrec-fuel 256, prelude prelude, reserved-molds molds)
  =/  core=icore-output:jibb  (icore-check:jibb defs state)
  ?~  result.core
    ?~  error.core  ~[leaf+"common local projection checker declined"]
    ~[leaf+msg.diag.u.error.core]
  =/  full=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values molds ~ prelude)
  ?:  ?=(%| -.full)  ~[leaf+(trip message.p.full)]
  ?.  =(artifacts.u.result.core elaborations.iface.p.full)
    ~[leaf+"local projection artifacts differ in the full checker"]
  =/  entries=(list iwidth-definition:jibb)  artifacts.u.result.core
  ?.  ?=([* ~] entries)  ~[leaf+"local projection has no unique top-level owner"]
  =/  projections=(list iwprojection:jibb)  projections.i.entries
  ?.  =((lent projections) count)  ~[leaf+"local projection actions were lost or duplicated"]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %run env.u.result.core)
  ?~  scheme  ~[leaf+"local projection owner missing"]
  |-
  ?~  projections  ~
  =/  p=iwprojection:jibb  i.projections
  ?.  =((lent quantified.p) quantifiers)
    ~[leaf+"local proof has the wrong quantifiers"]
  ?.  =(steps.p ~[[%left 2]])  ~[leaf+"local projection kept the wrong axis"]
  =/  allowed=(list @ud)  (weld vars.u.scheme quantified.p)
  =/  ids=(list @ud)  (weld (itype-vars:jibb source.p) (itype-vars:jibb target.p))
  ?.  (levy ids |=(n=@ud (lien allowed |=(v=@ud =(n v)))))
    ~[leaf+"local proof contains a free variable outside either scope"]
  ?:  &(numeric !(lien quantified.p |=(n=@ud (has-atom-var:jibb n target.p))))
    ~[leaf+"local projection erased its arithmetic aura constraint"]
  $(projections t.projections)
++  test-generic-local-projection
  ^-  tang
  (check-local '++ run |= words=@t\0a  ++ pick |= x=[left=A right=B]\0a    ^- [left=A] (proj x)\0a  (pick [left=words right=~zod])\0a' 1 2 |)
++  test-generic-local-projection-independent
  ^-  tang
  (check-local '++ run |= words=@t\0a  ++ pick |= x=[left=A right=B]\0a    ^- [left=A] (proj x)\0a  [(pick [left=words right=~zod]) (pick [left=~zod right=words])]\0a' 1 2 |)
++  test-generic-nested-local-projection
  ^-  tang
  (check-local '++ run |= [words=@t ship=@p]\0a  ++ outer |= x=[first=A second=B]\0a    ++ pick |= y=[left=C right=D]\0a      ^- [left=C] (proj y)\0a    [(pick [left=first.x right=second.x]) (pick [left=second.x right=first.x])]\0a  (outer [first=words second=ship])\0a' 1 2 |)
++  test-generic-local-projection-capture
  ^-  tang
  (check-local '++ run |= words=@t\0a  ++ pick |= right=A\0a    ^- [left=@t] (proj [left=words right=right])\0a  [(pick ~zod) (pick "hi")]\0a' 1 1 |)
++  test-generic-local-projection-shared-capital
  ^-  tang
  (check-local '++ run |= words=A\0a  ++ pick |= x=[left=A right=B]\0a    ^- [left=A] (proj x)\0a  (pick [left=words right=~zod])\0a' 1 1 |)
++  test-generic-local-mutual-projection
  ^-  tang
  (check-local '++ run |= words=@t\0a  ++ first |= [x=[left=A right=B] stop=?]\0a    ?- stop\0a    %.y ^- [left=A] (proj x)\0a    %.n (second x %.y)\0a  ++ second |= [x=[left=A right=B] stop=?]\0a    ?- stop\0a    %.y ^- [left=A] (proj x)\0a    %.n (first x %.y)\0a  (first [left=words right=~zod] %.y)\0a' 2 2 |)
++  test-generic-local-numeric-projection
  ^-  tang
  (check-local '++ run |= number=@ud\0a  ++ pick |= x=[left=A right=B]\0a    ^- [left=A] (proj x(left=(add left.x 1)))\0a  (pick [left=number right=~zod])\0a' 1 2 &)
--
