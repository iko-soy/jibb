::  Source-proven generic tree construction; not a backend/runtime test.
/+  jibb
/*  real-prelude     %jibb  /lib/jibb/prelude/jibb
/*  real-internal    %jibb  /lib/jibb/internal/jibb
/*  tree             %txt   /tests/type-generic-construction/tree/txt
/*  alias            %txt   /tests/type-generic-construction/alias/txt
/*  client           %txt   /tests/type-generic-construction/client/txt
/*  alias-client     %txt   /tests/type-generic-construction/alias-client/txt
/*  tree-no-event    %txt   /tests/type-generic-construction/tree-no-event/txt
/*  no-event-client  %txt   /tests/type-generic-construction/no-event-client/txt
/*  owner-positive   %txt   /tests/type-generic-construction/owner-positive/txt
/*  owner-negative   %txt   /tests/type-generic-construction/owner-negative/txt
/*  sibling-values   %txt   /tests/type-generic-construction/sibling-values/txt
/*  expected         %txt   /tests/type-generic-construction/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  line
  |=  [label=@t ok=?]
  ^-  @t
  (crip "{(trip label)}: {?:(ok "ok" "BAD")}")
++  construction-output
  |=  [pre=@t internal=@t tree=@t alias=@t client=@t alias-client=@t tree-no-event=@t no-event-client=@t owner-positive=@t owner-negative=@t sibling-values=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb pre internal)
  ?~  prep  'BAD prelude preparation'
  :: Complete owner is checked by the real source interface, not this unit state.
  =/  owner=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb owner-positive ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.owner)  'BAD valid owner'
  =/  bad-owner=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb owner-negative ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  bad-parse=(each module:jibb error:jibb)  (parse:jibb /ui/tree/jibb owner-negative)
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %node-tree iface.p.owner)
  ?~  mold  'BAD owner mold'
  ?.  ?=(%grec -.typ.u.mold)  'BAD nominal owner'
  =/  generic=itype:jibb  typ.u.mold(args ~[[%var 42]])
  =/  target=itype:jibb  typ.u.mold(args ~[[%atom %t]])
  ?>  ?=(%grec -.generic)
  ?>  ?=(%grec -.target)
  =/  owner-leaf=(unit ischeme:jibb)  (ienv-lookup:jibb %made-leaf values.iface.p.owner)
  =/  owner-node=(unit ischeme:jibb)  (ienv-lookup:jibb %made-node values.iface.p.owner)
  =/  leaf-ok=?  ?~(owner-leaf | &(?=(~ vars.u.owner-leaf) =(target typ.u.owner-leaf)))
  =/  node-ok=?  ?~(owner-node | &(?=(~ vars.u.owner-node) =(target typ.u.owner-node)))
  =/  foreign=itype:jibb  target(at /ui/foreign/jibb)
  =/  view=(unit [view=itype:jibb left=@ud])  (grec-unfold-view:jibb generic 2)
  ?~  view  'BAD generic view'
  =/  target-view=(unit [view=itype:jibb left=@ud])  (grec-unfold-view:jibb target 2)
  ?~  target-view  'BAD target view'
  =/  expected-leaf=itype:jibb  [%cell [%const [%term %tas %text '%text']] [%face %value [%atom %t]]]
  =/  expected-node=itype:jibb  [%cell [%const [%term %tas %node '%node']] [%cell [%face %event [%fn [%atom %t] [%var 42]]] [%face %children [%collection %list ~[generic]]]]]
  =/  expected-view=itype:jibb  [%union ~[expected-leaf expected-node] ~ ~ ~]
  =/  wrong-view=(unit [view=itype:jibb left=@ud])  (grec-unfold-view:jibb foreign 2)
  =/  malformed=shape:jibb  *shape:jibb
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/tree/values/jibb sibling-values)
  ?:  ?=(%| -.parsed)  'BAD values parse'
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([* [* [* [* ~]]]] ds)  'BAD values count'
  =/  a=def:jibb  i.ds
  =/  b=def:jibb  i.t.ds
  =/  c=def:jibb  i.t.t.ds
  =/  d=def:jibb  i.t.t.t.ds
  ?.  &(?=(%value -.a) ?=(%value -.b) ?=(%value -.c) ?=(%value -.d))  'BAD value declarations'
  =/  env=ienv:jibb  ~[[%text-event [[%fn [%atom %t] [%atom %t]] ~]]]
  =/  tag=ipending:jibb  [100 [%term %tas %unrelated '%unrelated']]
  =/  projection=iwprojection:jibb  *iwprojection:jibb
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 201, prelude `iface.u.prep, tags ~[tag], holes ~[[99 (span-of:jibb val.a)]], projections ~[projection])
  =/  r0=iresult:jibb  (infer-call-context-arg:jibb val.a target env st(jrec-fuel 0) (span-of:jibb val.a))
  =/  r1=iresult:jibb  (infer-call-context-arg:jibb val.a target env st(jrec-fuel 1) (span-of:jibb val.a))
  =/  rnode=iresult:jibb  (infer-call-context-arg:jibb val.b target env st(jrec-fuel 1) (span-of:jibb val.b))
  =/  short=iresult:jibb  (infer-call-context-arg:jibb val.c target env st(jrec-fuel 1) (span-of:jibb val.c))
  =/  nested=iresult:jibb  (infer-call-context-arg:jibb val.c target env st(jrec-fuel 2) (span-of:jibb val.c))
  =/  sibling-short=iresult:jibb  (infer-call-context-arg:jibb val.d target env st(jrec-fuel 2) (span-of:jibb val.d))
  =/  siblings=iresult:jibb  (infer-call-context-arg:jibb val.d target env st(jrec-fuel 3) (span-of:jibb val.d))
  =/  retry=iresult:jibb  (infer-call-context-arg:jibb val.a target env st(jrec-fuel 1) (span-of:jibb val.a))
  =/  failed-retry=iresult:jibb  (infer-call-context-arg:jibb val.a target env st(jrec-fuel 0) (span-of:jibb val.a))
  =/  rvar=iresult:jibb  (infer-call-context-arg:jibb val.b generic env st(jrec-fuel 1) (span-of:jibb val.b))
  =/  hidden=istate:jibb  st(sub ~[[200 target]], jrec-fuel 2)
  =/  rhidden=iresult:jibb  (infer-call-context-arg:jibb val.a [%var 200] env hidden (span-of:jibb val.a))
  =/  hidden-safe=?
    ?:  ?=(%| -.rhidden)  &
    =/  fit=ifit:jibb  (itype-fit:jibb typ.p.rhidden [%var 200] sub.state.p.rhidden next.state.p.rhidden)
    ?=(%unknown -.fit)
  =/  exact=isub:jibb  (turn (gulf 1 4.096) |=(n=@ud [(add 1.000 n) [%atom %t]]))
  =/  over=isub:jibb  [[9.999 [%atom %t]] exact]
  =/  face-exact=isub:jibb  (turn (gulf 1 4.095) |=(n=@ud [(add 1.000 n) [%atom %t]]))
  =/  checks=(list [label=@t ok=?])
    :~  ['complete owner' ?=(%& -.owner)]
        ['owner exports constructed nominal values' &(leaf-ok node-ok)]
        ['invalid owner declined' &(?=(%& -.bad-parse) ?=(%| -.bad-owner))]
        ['view spends one step' =(1 left.u.view)]
        ['view retains argument and child identity' =(expected-view view.u.view)]
        ['zero view fuel declined' ?=(~ (grec-unfold-view:jibb generic 0))]
        ['malformed proof declined' ?=(~ (grec-unfold-view:jibb generic(proof malformed) 2))]
        ['foreign recursive tail retained' ?:(?=(~ wrong-view) | !=(view.u.wrong-view view.u.target-view))]
        ['zero inference fuel declined' ?=(%| -.r0)]
        ['one-step leaf retains nominal identity' ?:(?=(%& -.r1) &(=(target typ.p.r1) =(0 jrec-fuel.state.p.r1)) |)]
        ['one-step node succeeds' ?:(?=(%& -.rnode) &(=(target typ.p.rnode) =(0 jrec-fuel.state.p.rnode)) |)]
        ['nested one-step declined' ?=(%| -.short)]
        ['nested two-step succeeds' ?:(?=(%& -.nested) &(=(target typ.p.nested) =(0 jrec-fuel.state.p.nested)) |)]
        ['siblings share fuel' &(?=(%| -.sibling-short) ?:(?=(%& -.siblings) =(0 jrec-fuel.state.p.siblings) |))]
        ['same-state retry agrees' =(r1 retry)]
        ['failed retry agrees' =(r0 failed-retry)]
        ['argument binding retains source identity' ?:(?=(%& -.rvar) =(target (itype-normalize:jibb typ.p.rvar sub.state.p.rvar)) |)]
        ['pending tag retained' ?:(?=(%& -.r1) (lien tags.state.p.r1 |=(entry=ipending:jibb =(entry tag))) |)]
        ['pending hole retained' ?:(?=(%& -.r1) =(holes.st holes.state.p.r1) |)]
        ['projection evidence retained' ?:(?=(%& -.r1) =(projections.st projections.state.p.r1) |)]
        ['hidden variable declined' hidden-safe]
        ['scan exact limit' (grec-direct-context:jibb target exact)]
        ['scan over limit declined' !(grec-direct-context:jibb target over)]
        ['faced scan exact limit' (grec-direct-context:jibb [%face %field target] face-exact)]
        ['faced scan over limit declined' !(grec-direct-context:jibb [%face %field target] exact)]
        ['structural substitution declined' !(grec-direct-context:jibb target ~[[9 [%cell [%atom %t] [%atom %t]]]])]
    ==
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb tree] [/ui/tree-two/jibb tree] [/ui/tree-alias/jibb alias]]
  =/  small=jbundle:jibb  ~[[/ui/tree/jibb tree-no-event] [/ui/tree-two/jibb tree-no-event]]
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/client/jibb client ~ ~ modules prep)
  =/  aliases=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/alias-client/jibb alias-client ~ ~ modules prep)
  =/  no-event=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/no-event-client/jibb no-event-client ~ ~ small prep)
  (cat 3 (of-wain:format (turn checks line)) (cat 3 '\0a' (cat 3 report (cat 3 '\0a' (cat 3 aliases (cat 3 '\0a' no-event))))))
++  test-generic-construction
  ^-  tang
  ?~  tree  ~[leaf+"tree source missing"]
  ?~  alias  ~[leaf+"alias source missing"]
  ?~  client  ~[leaf+"client source missing"]
  ?~  alias-client  ~[leaf+"alias client missing"]
  ?~  tree-no-event  ~[leaf+"tree without event missing"]
  ?~  no-event-client  ~[leaf+"no-event client missing"]
  ?~  owner-positive  ~[leaf+"owner source missing"]
  ?~  owner-negative  ~[leaf+"invalid owner source missing"]
  ?~  sibling-values  ~[leaf+"sibling source missing"]
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t
    (construction-output real-prelude real-internal (text tree) (text alias) (text client) (text alias-client) (text tree-no-event) (text no-event-client) (text owner-positive) (text owner-negative) (text sibling-values))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"generic construction output differs from expected"]
  ~
--
