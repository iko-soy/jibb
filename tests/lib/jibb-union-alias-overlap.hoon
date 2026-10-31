::  Source-backed alias overlap diagnostics, without a full module claim.
/+  jibb
/*  positive  %txt  /tests/type-union-alias-overlap/positive/txt
/*  negative  %txt  /tests/type-union-alias-overlap/negative/txt
/*  nonzero  %txt  /tests/type-union-alias-overlap/nonzero/txt
/*  multi  %txt  /tests/type-union-alias-overlap/multi/txt
/*  opaque  %txt  /tests/type-union-alias-overlap/opaque/txt
/*  wrong  %txt  /tests/type-union-alias-overlap/wrong/txt
/*  duplicate  %txt  /tests/type-union-alias-overlap/duplicate/txt
/*  qualified  %txt  /tests/type-union-alias-overlap/qualified/txt
/*  flag-source  %txt  /tests/type-union-alias-overlap/flag-source/txt
/*  expected  %txt  /tests/type-union-alias-overlap/expected/txt
|%
++  checks
  |=  [positive=@t negative=@t nonzero=@t multi=@t opaque=@t wrong=@t duplicate=@t qualified=@t flag-source=@t]
  ^-  (list [@t ?])
  =/  project
    |=  [source=@t name=term]
    ^-  (unit [cases=(list shape:jibb) molds=imolds:jibb])
    =/  parsed  (parse:jibb /tests/overlap/jibb source)
    ?:  ?=(%| -.parsed)  ~
    =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
    =/  found=(unit shape:jibb)  (find-simple-mold:jibb name molds)
    ?~  found  ~
    =/  sh=shape:jibb  u.found
    =?  sh  ?=(%generic -.sh)  body.sh
    ?.  ?=(%union -.sh)  ~
    `[cases.sh molds]
  =/  a  (project positive %same)
  =/  z  (project positive %same-zero)
  =/  d  (project negative %distinct-head)
  =/  c  (project negative %distinct-constant)
  =/  e  (project negative %empty-payload)
  =/  g  (project negative %generic)
  =/  x  (project negative %unknown-name)
  =/  nz  (project nonzero %same)
  =/  m  (project multi %choice)
  =/  o  (project opaque %choice)
  =/  w  (project wrong %bad)
  =/  dup  (project duplicate %choice)
  =/  q  (project qualified %choice)
  =/  fz  (project flag-source %flag-zero)
  =/  fn  (project flag-source %flag-nonzero)
  ?~  a  ~[['BAD same parse' |]]
  ?~  z  ~[['BAD zero parse' |]]
  ?~  d  ~[['BAD distinct parse' |]]
  ?~  c  ~[['BAD constants parse' |]]
  ?~  e  ~[['BAD empty parse' |]]
  ?~  g  ~[['BAD generic parse' |]]
  ?~  x  ~[['BAD reference parse' |]]
  ?~  nz  ~[['BAD nonzero parse' |]]
  ?~  m  ~[['BAD multi parse' |]]
  ?~  o  ~[['BAD opaque parse' |]]
  ?~  w  ~[['BAD wrong arity parse' |]]
  ?~  dup  ~[['BAD duplicate parse' |]]
  ?~  q  ~[['BAD qualified parse' |]]
  ?~  fz  ~[['BAD flag-zero parse' |]]
  ?~  fn  ~[['BAD flag-nonzero parse' |]]
  ?~  cases.u.a  ~[['BAD same cases' |]]
  ?~  t.cases.u.a  ~[['BAD second same case' |]]
  =/  same=(unit upair:jibb)  (union-source-overlap:jibb cases.u.a molds.u.a 256)
  =/  zero=(unit upair:jibb)  (union-source-overlap:jibb cases.u.z molds.u.z 256)
  =/  report=wain  (to-wain:format (golden-types-in-context:jibb /tests/overlap/jibb positive ~ ~ ~ ~ ~ ~))
  =/  failed=jfile-result:jibb  (infer-jibb-file:jibb /tests/overlap/jibb positive ~ ~ ~ ~[/tests/overlap/jibb] ~ ~ ~ ~)
  =/  nonzero-report=wain  (to-wain:format (golden-types-in-context:jibb /tests/overlap/jibb nonzero ~ ~ ~ ~ ~ ~))
  :~  ['same head and inhabited payload overlap' ?=(^ same)]
      ['zero spelling overlap' ?=(^ zero)]
      ['original same-case spans retained' ?~(same | &(=(first.u.same at.i.cases.u.a) =(second.u.same at.i.t.cases.u.a)))]
      ['partial report displays same overlap' (lien report |=(line=@t =(line '+$ same: overlapping cases; mold not checked')))]
      ['partial report displays zero overlap' (lien report |=(line=@t =(line '+$ same-zero: overlapping cases; mold not checked')))]
      ['distinct heads do not overlap' ?=(~ (union-source-overlap:jibb cases.u.d molds.u.d 256))]
      ['distinct singleton payloads do not overlap' ?=(~ (union-source-overlap:jibb cases.u.c molds.u.c 256))]
      ['empty payload has no witness' ?=(~ (union-source-overlap:jibb cases.u.e molds.u.e 256))]
      ['outer variable has no witness' ?=(~ (union-source-overlap:jibb cases.u.g molds.u.g 256))]
      ['unresolved reference has no witness' ?=(~ (union-source-overlap:jibb cases.u.x molds.u.x 256))]
      ['equal nonzero singleton payload overlaps' ?=(^ (union-source-overlap:jibb cases.u.nz molds.u.nz 256))]
      ['nonzero overlap reported' (lien nonzero-report |=(line=@t =(line '+$ same: overlapping cases; mold not checked')))]
      ['late pair in three cases overlaps' ?=(^ (union-source-overlap:jibb cases.u.m molds.u.m 256))]
      ['opaque gate payload declines' ?=(~ (union-source-overlap:jibb cases.u.o molds.u.o 256))]
      ['wrong alias arity declines' ?=(~ (union-source-overlap:jibb cases.u.w molds.u.w 256))]
      ['full module remains rejected' ?=(%| -.failed)]
      ['first source excerpt retained' (lien report |=(line=@t =(line '/tests/overlap.jibb:3:3: first union case')))]
      ['second source excerpt retained' (lien report |=(line=@t =(line '/tests/overlap.jibb:4:3: overlapping case')))]
      ['flag and zero payload overlap' ?=(^ (union-source-overlap:jibb cases.u.fz molds.u.fz 256))]
      ['flag and nonzero payload decline' ?=(~ (union-source-overlap:jibb cases.u.fn molds.u.fn 256))]
      ['duplicate owner declines' ?=(~ (union-source-overlap:jibb cases.u.dup molds.u.dup 256))]
      ['qualified owner declines' ?=(~ (union-source-overlap:jibb cases.u.q molds.u.q 256))]
      ['20 proof fuel succeeds' ?=(^ (union-source-overlap:jibb cases.u.a molds.u.a 20))]
      ['19 proof fuel declines' ?=(~ (union-source-overlap:jibb cases.u.a molds.u.a 19))]
      ['zero proof fuel declines' ?=(~ (union-source-overlap:jibb cases.u.a molds.u.a 0))]
  ==
++  overlap-output
  |=  [positive=@t negative=@t nonzero=@t multi=@t opaque=@t wrong=@t duplicate=@t qualified=@t flag-source=@t]
  ^-  @t
  =/  result=(list [@t ?])  (checks positive negative nonzero multi opaque wrong duplicate qualified flag-source)
  (of-wain:format (turn result |=(entry=[@t ?] (crip "{(trip -.entry)}: {?:(+.entry "ok" "BAD")}"))))
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-union-alias-overlap
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  (overlap-output (text positive) (text negative) (text nonzero) (text multi) (text opaque) (text wrong) (text duplicate) (text qualified) (text flag-source))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)  ~[leaf+"generic union overlap output differs"]
  ~
--
