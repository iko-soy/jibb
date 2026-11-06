::  Check resolved generic-union proofs and their diagnostics.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  good  %txt  /tests/type-union-source/good/txt
/*  same  %txt  /tests/type-union-source/same/txt
/*  zero  %txt  /tests/type-union-source/zero/txt
/*  nested  %txt  /tests/type-union-source/nested/txt
/*  duplicate  %txt  /tests/type-union-source/duplicate/txt
/*  wrong  %txt  /tests/type-union-source/wrong/txt
/*  duplicate-params  %txt  /tests/type-union-source/duplicate-params/txt
/*  hidden-ref  %txt  /tests/type-union-source/hidden-ref/txt
/*  qualified  %txt  /tests/type-union-source/qualified/txt
/*  direct-source  %txt  /tests/type-union-source/direct-source/txt
/*  wide-source  %txt  /tests/type-union-source/wide-source/txt
/*  free-source  %txt  /tests/type-union-source/free-source/txt
/*  late-source  %txt  /tests/type-union-source/late-source/txt
/*  shadow-source  %txt  /tests/type-union-source/shadow-source/txt
/*  mixed-source  %txt  /tests/type-union-source/mixed-source/txt
/*  expected  %txt  /tests/type-union-source/expected/txt
|%
++  checks
  |=  [public=@t internal=@t good=@t same=@t zero=@t nested=@t duplicate=@t wrong=@t duplicate-params=@t hidden-ref=@t qualified=@t direct-source=@t wide-source=@t free-source=@t late-source=@t shadow-source=@t mixed-source=@t]
  ^-  (list [@t ?])
  =/  module-choice
    |=  [source=@t name=term]
    ^-  (unit [cases=(list shape:jibb) molds=imolds:jibb])
    =/  parsed  (parse:jibb /tests/empty/jibb source)
    ?:  ?=(%| -.parsed)  ~
    =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
    =/  found=(unit shape:jibb)  (find-simple-mold:jibb name molds)
    ?~  found  ~
    ?.  ?=(%union -.u.found)  ~
    `[cases.u.found molds]
  =/  g=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice good %choice)
  =/  s=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice same %bad)
  =/  z=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice zero %bad)
  =/  n=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice nested %choice)
  =/  d=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice duplicate %choice)
  =/  w=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice wrong %bad)
  =/  dp=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice duplicate-params %choice)
  =/  hr=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice hidden-ref %choice)
  =/  q=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice qualified %choice)
  =/  direct=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice direct-source %choice)
  =/  wide=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice wide-source %choice)
  =/  free=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice free-source %choice)
  =/  late=(unit [cases=(list shape:jibb) molds=imolds:jibb])  (module-choice late-source %choice)
  ?~  g  ~[['BAD good parse' |]]
  ?~  s  ~[['BAD same parse' |]]
  ?~  z  ~[['BAD zero parse' |]]
  ?~  n  ~[['BAD nested parse' |]]
  ?~  d  ~[['BAD duplicate parse' |]]
  ?~  w  ~[['BAD arity parse' |]]
  ?~  dp  ~[['BAD duplicate params parse' |]]
  ?~  hr  ~[['BAD hidden ref parse' |]]
  ?~  q  ~[['BAD qualified parse' |]]
  ?~  direct  ~[['BAD direct parse' |]]
  ?~  wide  ~[['BAD wide parse' |]]
  ?~  free  ~[['BAD free parse' |]]
  ?~  late  ~[['BAD late parse' |]]
  ?~  cases.u.late  ~[['BAD late cases' |]]
  =/  chosen=(unit shape:jibb)  (find-simple-mold:jibb %choice molds.u.g)
  ?~  chosen  ~[['BAD chosen source' |]]
  =/  late-shape=(unit shape:jibb)  (find-simple-mold:jibb %choice molds.u.late)
  ?~  late-shape  ~[['BAD late source' |]]
  =/  mixed-parsed=(each module:jibb error:jibb)  (parse:jibb /tests/empty/jibb mixed-source)
  ?:  ?=(%| -.mixed-parsed)  ~[['BAD mixed parse' |]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[['BAD prepared prelude' |]]
  =/  mixed-result=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb mixed-source ~ ~ ~ ~[/tests/empty/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  mixed-tree=(unit ischeme:jibb)
    ?:  ?=(%| -.mixed-result)  ~
    (find-jibb-mold:jibb %node-tree iface.p.mixed-result)
  =/  mixed-report=wain  (to-wain:format (golden-types-with-prepared-prelude:jibb /tests/empty/jibb mixed-source ~ ~ ~ prep))
  =/  good-report=wain  (to-wain:format (golden-types:jibb /tests/empty/jibb good))
  =/  shadow-report=wain  (to-wain:format (golden-types:jibb /tests/empty/jibb shadow-source))
  =/  good-checked=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb good ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
  =/  collision-checked=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb same ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
  =/  zero-checked=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb zero ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
  =/  arity-checked=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb wrong ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
  =/  shadow-parsed=(each module:jibb error:jibb)  (parse:jibb /tests/empty/jibb shadow-source)
  =/  shadow-checked=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb shadow-source ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
  =/  state=istate:jibb  *istate:jibb
  =/  initial=istate:jibb
    state(molds molds.u.g, at /tests/empty/jibb, active ~[%outer], caps ~[['Q' 17 *span:jibb]], tags ~[[42 [%term %tas %pending '%pending'] *span:jibb]], sub (isub-from-bindings:jibb ~[[71 [%atom %t]]]), next 100)
  =/  preserved=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.chosen initial)
  =/  structured=istate:jibb  initial(params ~[['A' [%cell [%atom %t] [%atom %t]]]])
  =/  structural=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.chosen structured)
  =/  delayed=istate:jibb  initial(molds molds.u.late, in-mold &, params ~[['A' [%var 3]]])
  =/  first=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb i.cases.u.late delayed)
  =/  incomplete=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.late-shape delayed)
  =/  accepts
    |=  source=@t
    ^-  ?
    =/  out=jfile-result:jibb
      (infer-jibb-file:jibb /tests/empty/jibb source ~ ~ ~ ~[/tests/empty/jibb] ~ ~ ~ ~)
    ?=(%& -.out)
  :~  ['actual inference preserves pending and scoped state' ?:(?=(~ preserved) | =(state.u.preserved initial))]
      ['actual inference preserves structural state' &(?=(^ structural) =(state.u.structural structured) ?=(%union -.typ.u.structural) (import-cases-disjoint:jibb cases.typ.u.structural))]
      ['later source failure returns no partial state' &(?=(^ first) ?=(~ incomplete))]
      ['actual local owner shadow rejected' &(?=(%& -.shadow-parsed) ?=(%| -.shadow-checked))]
      ['full generic-alias module checks' ?=(%& -.good-checked)]
      ['same-head module is not published' ?=(%| -.collision-checked)]
      ['mixed-zero module is not published' ?=(%| -.zero-checked)]
      ['wrong-arity module is not published' ?=(%| -.arity-checked)]
      ['full report prints checked union' (lien good-report |=(line=@t =(line '+$ choice: choice')))]
      ['full report preserves named shadow diagnostic' (lien shadow-report |=(line=@t =(line '++ bad: local mold `tagged` shadows an enclosing mold')))]
      ['recursive mold coexists with generic alias union' ?~(mixed-tree | ?=(%mrec -.typ.u.mixed-tree))]
      ['mixed full report prints checked union' (lien mixed-report |=(line=@t =(line '+$ choice: choice')))]
      ['nested generic aliases check' (accepts nested)]
      ['direct disjoint cases check' (accepts direct-source)]
      ['resolved nonrecursive aliases check' (accepts hidden-ref)]
      ['wide alias case checks' (accepts wide-source)]
      ['duplicate owner is rejected' !(accepts duplicate)]
      ['duplicate parameters are rejected' !(accepts duplicate-params)]
      ['unbound parameter is rejected' !(accepts free-source)]
      ['undefined imported module is rejected' !(accepts qualified)]
      ['unbound case arguments are rejected' !(accepts late-source)]
  ==
++  source-output
  |=  [public=@t internal=@t good=@t same=@t zero=@t nested=@t duplicate=@t wrong=@t duplicate-params=@t hidden-ref=@t qualified=@t direct-source=@t wide-source=@t free-source=@t late-source=@t shadow-source=@t mixed-source=@t]
  ^-  @t
  =/  result=(list [@t ?])  (checks public internal good same zero nested duplicate wrong duplicate-params hidden-ref qualified direct-source wide-source free-source late-source shadow-source mixed-source)
  (of-wain:format (turn result |=(entry=[@t ?] (crip "{(trip -.entry)}: {?:(+.entry "ok" "BAD")}"))))
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  report
  ^-  @t
  (source-output prelude internal (text good) (text same) (text zero) (text nested) (text duplicate) (text wrong) (text duplicate-params) (text hidden-ref) (text qualified) (text direct-source) (text wide-source) (text free-source) (text late-source) (text shadow-source) (text mixed-source))
++  test-union-source
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)  ~[leaf+"generic union source output differs"]
  ~
--
