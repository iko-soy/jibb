::  Source-proven generic recursive patterns; no backend/runtime claim.
/+  jibb
/*  real-prelude   %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
/*  tree           %txt   /tests/type-generic-construction/tree/txt
/*  alias          %txt   /tests/type-generic-construction/alias/txt
/*  tree-no-event  %txt   /tests/type-generic-construction/tree-no-event/txt
/*  client         %txt   /tests/type-generic-pattern/client/txt
/*  no-event       %txt   /tests/type-generic-pattern/no-event/txt
/*  values         %txt   /tests/type-generic-pattern/values/txt
/*  poly-values    %txt   /tests/type-generic-pattern/poly-values/txt
/*  owner          %txt   /tests/type-generic-pattern/owner/txt
/*  owner-bad      %txt   /tests/type-generic-pattern/owner-bad/txt
/*  expected       %txt   /tests/type-generic-pattern/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  line
  |=  [label=@t ok=?]
  ^-  @t
  (crip "{(trip label)}: {?:(ok "ok" "BAD")}")
++  pattern-output
  |=  [pre=@t internal=@t tree=@t alias=@t tree-no-event=@t client=@t no-event=@t values=@t poly-values=@t owner=@t owner-bad=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb pre internal)
  ?~  prep  'BAD prelude preparation'
  =/  checked=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb owner ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  'BAD valid owner'
  =/  bad-parse=(each module:jibb error:jibb)  (parse:jibb /ui/tree/jibb owner-bad)
  =/  bad=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb owner-bad ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %node-tree iface.p.checked)
  ?~  mold  'BAD owner mold'
  ?.  ?=(%grec -.typ.u.mold)  'BAD nominal owner'
  =/  target=itype:jibb  typ.u.mold(args ~[[%atom %t]])
  =/  generic=itype:jibb  typ.u.mold(args ~[[%var 42]])
  ?>  ?=(%grec -.target)
  ?>  ?=(%grec -.generic)
  =/  desc=(unit ischeme:jibb)  (ienv-lookup:jibb %describe values.iface.p.checked)
  =/  children=(unit ischeme:jibb)  (ienv-lookup:jibb %children values.iface.p.checked)
  =/  rebuild=(unit ischeme:jibb)  (ienv-lookup:jibb %rebuild values.iface.p.checked)
  ?~  desc  'BAD owner describe missing'
  ?~  children  'BAD owner children missing'
  ?~  rebuild  'BAD owner rebuild missing'
  ?.  &(?=(%fn -.typ.u.desc) ?=(%fn -.typ.u.children) ?=(%fn -.typ.u.rebuild))  'BAD owner gate types'
  ?.  ?=([@ ~] vars.u.children)  'BAD owner children quantification'
  =/  desc-sample=itype:jibb  sample.typ.u.desc
  =/  children-sample=itype:jibb  sample.typ.u.children
  =/  rebuild-sample=itype:jibb  sample.typ.u.rebuild
  =?  desc-sample  ?=(%face -.desc-sample)  body.desc-sample
  =?  children-sample  ?=(%face -.children-sample)  body.children-sample
  =?  rebuild-sample  ?=(%face -.rebuild-sample)  body.rebuild-sample
  =/  quantified=itype:jibb  typ.u.mold(args ~[[%var i.vars.u.children]])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/tree/values/jibb values)
  ?:  ?=(%| -.parsed)  'BAD values parse'
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([* [* [* [* [* ~]]]]] ds)  'BAD value count'
  =/  a=def:jibb  i.ds
  =/  b=def:jibb  i.t.ds
  ?.  &(?=(%value -.a) ?=(%value -.b))  'BAD value declarations'
  =/  c=def:jibb  i.t.t.ds
  =/  d=def:jibb  i.t.t.t.ds
  =/  e=def:jibb  i.t.t.t.t.ds
  ?.  &(?=(%value -.c) ?=(%value -.d) ?=(%value -.e))  'BAD extra value declarations'
  ?.  &(?=(%branch -.val.c) ?=(%branch -.val.d) ?=(%branch -.val.e))  'BAD extra branches'
  ?.  ?=([* *] arms.val.c)  'BAD fallback arms'
  =/  sample-arm=arm:jibb  i.arms.val.c
  =/  parsed-poly=(each module:jibb error:jibb)  (parse:jibb /tests/tree/poly/jibb poly-values)
  ?:  ?=(%| -.parsed-poly)  'BAD polymorphic values parse'
  =/  ps=(list def:jibb)  defs.p.parsed-poly
  ?.  ?=([* ~] ps)  'BAD polymorphic value count'
  =/  p=def:jibb  i.ps
  ?.  ?=(%value -.p)  'BAD polymorphic value'
  ?.  ?=(%branch -.val.p)  'BAD polymorphic branch'
  =/  env=ienv:jibb  ~[[%x [target ~]]]
  =/  poly=ienv:jibb  ~[[%x [generic ~[42]]]]
  =/  tag=ipending:jibb  [100 [%term %tas %unrelated '%unrelated']]
  =/  projection=iwprojection:jibb  *iwprojection:jibb
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 201, prelude `iface.u.prep, tags ~[tag], holes ~[[99 (span-of:jibb val.a)]], projections ~[projection])
  =/  zero=iresult:jibb  (infer-fragment:jibb val.a env st(jrec-fuel 0))
  =/  one=iresult:jibb  (infer-fragment:jibb val.a env st(jrec-fuel 1))
  =/  short=iresult:jibb  (infer-fragment:jibb val.b env st(jrec-fuel 1))
  =/  nested=iresult:jibb  (infer-fragment:jibb val.b env st(jrec-fuel 2))
  =/  retry=iresult:jibb  (infer-fragment:jibb val.a env st(jrec-fuel 1))
  =/  hidden=ienv:jibb  ~[[%x [[%var 200] ~]]]
  =/  hidden-result=iresult:jibb  (infer-fragment:jibb val.a hidden st(sub ~[[200 target]], jrec-fuel 2))
  =/  first=(unit iresult:jibb)  (grec-single-wing-subject:jibb subject.val.p poly st(jrec-fuel 4))
  =/  second=(unit iresult:jibb)  (grec-single-wing-subject:jibb subject.val.p poly st(next 202, jrec-fuel 4))
  ?~  first  'BAD first scheme lookup'
  ?~  second  'BAD second scheme lookup'
  ?.  &(?=(%& -.u.first) ?=(%& -.u.second))  'BAD scheme inference'
  =/  ft=itype:jibb  typ.p.u.first
  =/  stype=itype:jibb  typ.p.u.second
  ?.  &(?=(%grec -.ft) ?=(%grec -.stype))  'BAD scheme nominal identity'
  ?.  &(?=([* ~] args.ft) ?=([* ~] args.stype))  'BAD scheme argument count'
  =/  pmissing=iresult:jibb  (infer-fragment:jibb val.p poly st(jrec-fuel 4))
  =/  view=(unit [view=itype:jibb left=@ud])  (grec-unfold-view:jibb target 1)
  ?~  view  'BAD recursive view'
  =/  many=(list arm:jibb)
    =/  n=@ud  128
    =/  out=(list arm:jibb)  ~
    |-
    ?:  =(0 n)  out
    $(n (dec n), out [sample-arm out])
  =/  in-view=iresult:jibb  [%& target st(jrec-fuel 1)]
  =/  exact=expr:jibb  val.c(arms many)
  =/  over=expr:jibb  val.c(arms [sample-arm many])
  =/  rexact=iresult:jibb  (grec-match-view:jibb exact in-view)
  =/  rover=iresult:jibb  (grec-match-view:jibb over in-view)
  =/  hidden-view=iresult:jibb  [%& [%var 200] st(sub ~[[200 target]], jrec-fuel 1)]
  =/  rhidden-view=iresult:jibb  (grec-match-view:jibb exact hidden-view)
  =/  fallback=iresult:jibb  (infer-fragment:jibb val.c env st(jrec-fuel 1))
  =/  checks=(list [label=@t ok=?])
    :~  ['owner describe has nominal sample and text result' &(=(target desc-sample) =([%atom %t] product.typ.u.desc))]
        ['owner rebuild preserves nominal identity' &(=(target rebuild-sample) =(target product.typ.u.rebuild))]
        ['owner children preserves quantified recursive identity' &(=(quantified children-sample) =([%collection %list ~[quantified]] product.typ.u.children))]
        ['invalid owner parses and is rejected' &(?=(%& -.bad-parse) ?=(%| -.bad))]
        ['zero fuel declined' ?=(%| -.zero)]
        ['one-step match' ?:(?=(%& -.one) &(=([%atom %t] typ.p.one) =(0 jrec-fuel.state.p.one)) |)]
        ['nested match requires two steps' &(?=(%| -.short) ?:(?=(%& -.nested) =(0 jrec-fuel.state.p.nested) |))]
        ['same-state retry agrees' =(one retry)]
        ['pending tag retained' ?:(?=(%& -.one) (lien tags.state.p.one |=(entry=ipending:jibb =(entry tag))) |)]
        ['pending hole retained' ?:(?=(%& -.one) =(holes.st holes.state.p.one) |)]
        ['projection evidence retained' ?:(?=(%& -.one) =(projections.st projections.state.p.one) |)]
        ['raw bound variable declined' ?=(%| -.hidden-result)]
        ['polymorphic scheme gets fresh identities' &(=([%var 201] i.args.ft) =([%var 202] i.args.stype) =(at.ft at.stype) =(name.ft name.stype) =(proof.ft proof.stype))]
        ['polymorphic missing arm declined' ?=(%| -.pmissing)]
        ['catch-all eligible' (grec-patterns-eligible:jibb arms.val.c view.u.view 128)]
        ['whole binder stays unsupported' !(grec-patterns-eligible:jibb arms.val.d view.u.view 128)]
        ['whole structural tail stays unsupported' !(grec-patterns-eligible:jibb arms.val.e view.u.view 128)]
        ['128 arms eligible' (grec-patterns-eligible:jibb many view.u.view 128)]
        ['129 arms declined' !(grec-patterns-eligible:jibb [sample-arm many] view.u.view 128)]
        ['zero arm budget declined' !(grec-patterns-eligible:jibb ~[sample-arm] view.u.view 0)]
        ['128-arm view consumes one step' ?:(?=(%& -.rexact) &(?=(%union -.typ.p.rexact) =(0 jrec-fuel.state.p.rexact)) |)]
        ['129-arm view rolls back' =(in-view rover)]
        ['hidden view stays nominally unknown' =(hidden-view rhidden-view)]
        ['catch-all keeps fuel and pending state' ?:(?=(%& -.fallback) &(=(0 jrec-fuel.state.p.fallback) =(holes.st holes.state.p.fallback) =(projections.st projections.state.p.fallback) (lien tags.state.p.fallback |=(entry=ipending:jibb =(entry tag)))) |)]
    ==
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb tree] [/ui/tree-two/jibb tree] [/ui/tree-alias/jibb alias]]
  =/  small=jbundle:jibb  ~[[/ui/tree/jibb tree-no-event]]
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/client/jibb client ~ ~ modules prep)
  =/  noreport=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/no-event/jibb no-event ~ ~ small prep)
  (cat 3 (of-wain:format (turn checks line)) (cat 3 '\0a' (cat 3 report (cat 3 '\0a' noreport))))
++  test-generic-pattern
  ^-  tang
  ?~  tree  ~[leaf+"tree source missing"]
  ?~  alias  ~[leaf+"alias source missing"]
  ?~  tree-no-event  ~[leaf+"tree without event missing"]
  ?~  client  ~[leaf+"client source missing"]
  ?~  no-event  ~[leaf+"no-event client missing"]
  ?~  values  ~[leaf+"values source missing"]
  ?~  poly-values  ~[leaf+"polymorphic values source missing"]
  ?~  owner  ~[leaf+"owner source missing"]
  ?~  owner-bad  ~[leaf+"invalid owner source missing"]
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t
    (pattern-output real-prelude real-internal (text tree) (text alias) (text tree-no-event) (text client) (text no-event) (text values) (text poly-values) (text owner) (text owner-bad))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"generic pattern output differs from expected"]
  ~
--
