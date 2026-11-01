::  Bounded source-backed generic-union proof checks; no runtime claim.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
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
  =/  mixed-collected=grec-collected:jibb  (grec-collect-molds:jibb defs.p.mixed-parsed)
  =/  mixed-tree=(unit shape:jibb)  (~(get by proofs.mixed-collected) %node-tree)
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prep  ~[['BAD prepared prelude' |]]
  =/  mixed-result=jfile-result:jibb
    (infer-jibb-file:jibb /tests/empty/jibb mixed-source ~ ~ ~ ~[/tests/empty/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  mixed-report=wain  (to-wain:format (golden-types-with-prepared-prelude:jibb /tests/empty/jibb mixed-source ~ ~ ~ prep))
  =/  good-report=wain  (to-wain:format (golden-types-in-context:jibb /tests/empty/jibb good ~ ~ ~ ~ ~ ~))
  =/  shadow-report=wain  (to-wain:format (golden-types-in-context:jibb /tests/empty/jibb shadow-source ~ ~ ~ ~ ~ ~))
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
  =/  idx=[at=path source=@t prelude=ifile:jibb shapes=(map term shape:jibb)]  [/tests/empty/jibb '' *ifile:jibb *(map term shape:jibb)]
  =/  cap256=icaps:jibb  (turn (gulf 0 255) |=(n=@ud ['A' n *span:jibb]))
  =/  cap257=icaps:jibb  (turn (gulf 0 256) |=(n=@ud ['A' n *span:jibb]))
  =/  initial=istate:jibb
    state(molds molds.u.g, at /tests/empty/jibb, active ~[%outer], caps ~[['Q' 17 *span:jibb]], tags ~[[42 [%term %tas %pending '%pending']]], sub ~[[71 [%atom %t]]], next 100)
  =/  preserved=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.chosen initial)
  =/  structured=istate:jibb  initial(params ~[['A' [%cell [%atom %t] [%atom %t]]]])
  =/  rejected=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.chosen structured)
  =/  delayed=istate:jibb  initial(molds molds.u.late, in-mold &, params ~[['A' [%var 3]]])
  =/  first=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb i.cases.u.late delayed)
  =/  incomplete=(unit [typ=itype:jibb state=istate:jibb])  (infer-simple-shape:jibb u.late-shape delayed)
  :~  ['source generic distinct' (union-source-distinct-tags:jibb cases.u.g molds.u.g 256)]
      ['actual inference preserves pending and scoped state' ?:(?=(~ preserved) | =(state.u.preserved initial))]
      ['actual inference rejects structural state' ?=(~ rejected)]
      ['later source failure returns no partial state' &(?=(^ first) ?=(~ incomplete))]
      ['actual local owner shadow rejected' &(?=(%& -.shadow-parsed) ?=(%| -.shadow-checked))]
      ['full generic-alias module checks' ?=(%& -.good-checked)]
      ['same-head module is not published' ?=(%| -.collision-checked)]
      ['mixed-zero module is not published' ?=(%| -.zero-checked)]
      ['wrong-arity module is not published' ?=(%| -.arity-checked)]
      ['partial report uses source proof' (lien good-report |=(line=@t =(line '+$ choice: cases proven disjoint; mold not checked')))]
      ['partial report preserves shadow diagnostic' (lien shadow-report |=(line=@t =(line '++ bad: local molds shadow a name')))]
      ['recognized recursive tree causes conservative decline' &(?=(^ mixed-tree) ?=(%| -.mixed-result))]
      ['mixed partial report remains source-only' (lien mixed-report |=(line=@t =(line '+$ choice: cases proven disjoint; mold not checked')))]
      ['source exact fuel 18' (union-source-distinct-tags:jibb cases.u.g molds.u.g 18)]
      ['source 17 fuel declines' !(union-source-distinct-tags:jibb cases.u.g molds.u.g 17)]
      ['same head declines' !(union-source-distinct-tags:jibb cases.u.s molds.u.s 256)]
      ['equal noun cross spelling declines' !(union-source-distinct-tags:jibb cases.u.z molds.u.z 256)]
      ['nested application declines' !(union-source-distinct-tags:jibb cases.u.n molds.u.n 256)]
      ['duplicate owner declines' !(union-source-distinct-tags:jibb cases.u.d molds.u.d 256)]
      ['wrong arity declines' !(union-source-distinct-tags:jibb cases.u.w molds.u.w 256)]
      ['duplicate parameters decline' !(union-source-distinct-tags:jibb cases.u.dp molds.u.dp 256)]
      ['hidden body reference declines' !(union-source-distinct-tags:jibb cases.u.hr molds.u.hr 256)]
      ['qualified import declines' !(union-source-distinct-tags:jibb cases.u.q molds.u.q 256)]
      ['direct cases use existing proof' !(union-source-distinct-tags:jibb cases.u.direct molds.u.direct 256)]
      ['wide alias body declines' !(union-source-distinct-tags:jibb cases.u.wide molds.u.wide 256)]
      ['undeclared body parameter declines' !(union-source-distinct-tags:jibb cases.u.free molds.u.free 256)]
      ['empty state accepted' (union-source-state-safe:jibb state 256)]
      ['simple outer generic accepted' (union-source-state-safe:jibb state(params ~[['A' [%var 3]]], sub ~[[3 [%var 5]]]) 256)]
      ['structured outer argument declined' !(union-source-state-safe:jibb state(params ~[['A' [%cell [%atom %t] [%atom %t]]]]) 256)]
      ['structured substitution declined' !(union-source-state-safe:jibb state(sub ~[[3 [%cell [%atom %t] [%atom %t]]]]) 256)]
      ['pending hole declined' !(union-source-state-safe:jibb state(holes ~[[3 *span:jibb]]) 256)]
      ['recursive index declined' !(union-source-state-safe:jibb state(grec-index `idx) 256)]
      ['deferred transaction declined' !(union-source-state-safe:jibb state(defer `~) 256)]
      ['pending obligation declined' !(union-source-state-safe:jibb state(obligations ~[[[%var 1] [%var 2] *span:jibb *span:jibb]]) 256)]
      ['256 state entries accepted' (union-source-state-safe:jibb state(caps cap256) 256)]
      ['257 state entries declined' !(union-source-state-safe:jibb state(caps cap257) 256)]
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
++  test-union-source
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  (source-output prelude internal (text good) (text same) (text zero) (text nested) (text duplicate) (text wrong) (text duplicate-params) (text hidden-ref) (text qualified) (text direct-source) (text wide-source) (text free-source) (text late-source) (text shadow-source) (text mixed-source))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)  ~[leaf+"generic union source output differs"]
  ~
--
