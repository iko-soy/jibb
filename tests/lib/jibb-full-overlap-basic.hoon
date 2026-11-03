::  Source-bound full-module overlap diagnostics.
/+  jibb
/*  same  %txt  /tests/type-full-overlap/same/txt
/*  zero  %txt  /tests/type-full-overlap/zero/txt
/*  unsupported  %txt  /tests/type-full-overlap/unsupported/txt
/*  precedence  %txt  /tests/type-full-overlap/precedence/txt
/*  duplicate  %txt  /tests/type-full-overlap/duplicate/txt
/*  invalid  %txt  /tests/type-full-overlap/invalid/txt
/*  distinct  %txt  /tests/type-full-overlap/distinct/txt
/*  parent  %txt  /tests/type-full-overlap/parent/txt
/*  child  %txt  /tests/type-full-overlap/child/txt
/*  generic  %txt  /tests/type-full-overlap/generic/txt
/*  duplicate-generic  %txt  /tests/type-full-overlap/duplicate-generic/txt
/*  atoms  %txt  /tests/type-full-overlap/atoms/txt
/*  flag  %txt  /tests/type-full-overlap/flag/txt
/*  nested  %txt  /tests/type-full-overlap/nested/txt
/*  order  %txt  /tests/type-full-overlap/order/txt
/*  expected  %txt  /tests/type-full-overlap/expected-basic/txt
|%
+$  overlap-evidence  [file=path source=@t name=term cases=upair:jibb]
+$  detailed-result
  (each [iface=ifile:jibb cache=jcache:jibb] [message=@t overlap=(unit overlap-evidence)])
++  source-pair
  |=  [file=path source=@t name=term]
  ^-  (unit upair:jibb)
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~
  =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
  =/  found=(unit shape:jibb)  (find-simple-mold:jibb name molds)
  ?~  found  ~
  =/  sh=shape:jibb  u.found
  =?  sh  ?=(%generic -.sh)  body.sh
  ?.  ?=(%union -.sh)  ~
  ?~  cases.sh  ~
  ?~  t.cases.sh  ~
  `[at.i.cases.sh at.i.t.cases.sh %overlap]
++  source-overlap
  |=  [file=path source=@t name=term]
  ^-  (unit upair:jibb)
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~
  =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
  =/  found=(unit shape:jibb)  (find-simple-mold:jibb name molds)
  ?~  found  ~
  =/  sh=shape:jibb  u.found
  =?  sh  ?=(%generic -.sh)  body.sh
  ?.  ?=(%union -.sh)  ~
  (union-source-overlap:jibb cases.sh molds 256)
++  source-witness
  |=  [file=path source=@t name=term]
  ^-  ?
  ?=(^ (source-overlap file source name))
::  An overlapping pair of cases written at column 3 of the given lines.
++  pair-at
  |=  [pair=upair:jibb first=@ud second=@ud]
  ^-  ?
  ?&  =(%overlap relation.pair)
     =(first line.beg.first.pair)
     =(3 col.beg.first.pair)
     =(second line.beg.second.pair)
     =(3 col.beg.second.pair)
  ==
++  detailed
  |=  [file=path source=@t modules=jbundle:jibb]
  ^-  detailed-result
  (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] ~ ~ ~ ~)
::  The first two cases overlap, written on consecutive lines from .line.
++  expected-overlap
  |=  [file=path source=@t name=term line=@ud]
  ^-  ?
  =/  expected=(unit upair:jibb)  (source-pair file source name)
  ?~  expected  |
  =/  result=detailed-result  (detailed file source ~)
  ?:  ?=(%& -.result)  |
  ?~  overlap.p.result  |
  =/  ev=overlap-evidence  u.overlap.p.result
  ?&  !=(0 message.p.result)
     =(file.ev file)
     =(source.ev source)
     =(name.ev name)
     =(cases.ev u.expected)
     =(%overlap relation.cases.ev)
     =(line line.beg.first.cases.ev)
     =(3 col.beg.first.cases.ev)
     =(+(line) line.beg.second.cases.ev)
     =(3 col.beg.second.cases.ev)
  ==
++  plain-failure
  |=  [file=path source=@t]
  ^-  ?
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  |
  =/  result=detailed-result  (detailed file source ~)
  ?:  ?=(%& -.result)  |
  &(!=(0 message.p.result) ?=(~ overlap.p.result))
++  run
  |=  [same=@t zero=@t unsupported=@t precedence=@t duplicate=@t invalid=@t distinct=@t parent=@t child=@t generic=@t duplicate-generic=@t atoms=@t flag=@t nested=@t order=@t]
  ^-  (list [@t ?])
  =/  root=path  /ui/root/jibb
  =/  names256=(list @t)  (turn (gulf 0 255) |=(n=@ud (scot %ud n)))
  =/  names257=(list @t)  (turn (gulf 0 256) |=(n=@ud (scot %ud n)))
  =/  child-file=path  /ui/child/jibb
  =/  good-parsed  (parse:jibb root distinct)
  =/  good-result=detailed-result  (detailed root distinct ~)
  =/  bad-parsed  (parse:jibb root invalid)
  =/  bad-result=detailed-result  (detailed root invalid ~)
  =/  invalid-clean=?
    ?:  ?=(%& -.bad-parsed)  |
    ?:  ?=(%& -.bad-result)  |
    &(!=(0 message.p.bad-result) ?=(~ overlap.p.bad-result))
  =/  legacy=jfile-result:jibb  (infer-jibb-file:jibb root same ~ ~ ~ ~[root] ~ ~ ~ ~)
  =/  legacy-excerpts=?
    ?:  ?=(%& -.legacy)  |
    =/  lines=wain  (to-wain:format p.legacy)
    &((lien lines |=(line=@t =(line '/ui/root.jibb:3:3: first union case'))) (lien lines |=(line=@t =(line '/ui/root.jibb:4:3: overlapping case'))))
  ::  A projected overlap renders the same error as a source witness.
  =/  legacy-atoms=jfile-result:jibb  (infer-jibb-file:jibb root atoms ~ ~ ~ ~[root] ~ ~ ~ ~)
  =/  legacy-projected=?
    ?:  ?=(%& -.legacy-atoms)  |
    =((to-wain:format p.legacy-atoms) ~['module mold bad has overlapping cases' '/ui/root.jibb:2:3: first union case' '  @t' '  ^' '/ui/root.jibb:3:3: overlapping case' '  @ud' '  ^'])
  ::  The source witness alone proves the first two cases of .order, but
  ::  the projection proves the last two and is consulted first, so both
  ::  the full check and the partial report name the later pair.
  =/  order-source=(unit upair:jibb)  (source-overlap root order %bad)
  =/  order-result=detailed-result  (detailed root order ~)
  =/  order-full=?
    ?:  ?=(%& -.order-result)  |
    ?~  overlap.p.order-result  |
    =/  ev=overlap-evidence  u.overlap.p.order-result
    &(=(file.ev root) =(name.ev %bad) (pair-at cases.ev 5 6))
  =/  order-partial=wain  (to-wain:format (golden-types:jibb root order))
  =/  order-reported=?
    ?&  (lien order-partial |=(line=@t =(line '+$ bad: overlapping cases; mold not checked')))
       (lien order-partial |=(line=@t =(line '/ui/root.jibb:5:3: first union case')))
       (lien order-partial |=(line=@t =(line '/ui/root.jibb:6:3: overlapping case')))
    ==
  =/  imported=detailed-result  (detailed root parent ~[[child-file child]])
  =/  child-pair=(unit upair:jibb)  (source-pair child-file child %child-bad)
  =/  import-valid=?
    ?:  ?=(%& -.imported)  |
    ?:  =(0 message.p.imported)  |
    ?~  overlap.p.imported  |
    ?~  child-pair  |
    =/  ev=overlap-evidence  u.overlap.p.imported
    ?&  =(file.ev child-file)
       =(source.ev child)
       =(name.ev %child-bad)
       =(cases.ev u.child-pair)
    ==
  :~  ['256 generic parameters accepted by scan' (module-mold-params-valid:jibb names256 *(set @t) 256)]
      ['257 generic parameters exhaust scan' !(module-mold-params-valid:jibb names257 *(set @t) 256)]
      ['duplicate generic parameters fail scan' !(module-mold-params-valid:jibb ~['A' 'A'] *(set @t) 256)]
      ['same head has source-bound overlap' (expected-overlap root same %bad 3)]
      ['zero spelling has source-bound overlap' (expected-overlap root zero %bad 3)]
      ['generic wrapper has source-bound overlap' (expected-overlap root generic %bad 3)]
      ['two auras have source-bound overlap' (expected-overlap root atoms %bad 2)]
      ['flag and yes have source-bound overlap' (expected-overlap root flag %bad 2)]
      ['nested equal tags have source-bound overlap' (expected-overlap root nested %bad 2)]
      ['source witness alone names the earlier pair' ?~(order-source | (pair-at u.order-source 3 4))]
      ['full check names the later projected pair' order-full]
      ['partial report names the same later pair' order-reported]
      ['duplicate generic parameters remain unstructured' (plain-failure root duplicate-generic)]
      ['unsupported remains unstructured' (plain-failure root unsupported)]
      ['later overlap exists in precedence source' (source-witness root precedence %bad)]
      ['earlier unsupported mold takes precedence' (plain-failure root precedence)]
      ['duplicate source parsed but rejects without overlap' (plain-failure root duplicate)]
      ['invalid source rejects without overlap' invalid-clean]
      ['distinct alias source parses and checks' &(?=(%& -.good-parsed) ?=(%& -.good-result))]
      ['parent itself has different positive overlap' (source-witness root parent %parent-bad)]
      ['legacy full-module error contains both excerpts' legacy-excerpts]
      ['legacy projected overlap error is exact' legacy-projected]
      ['import overlap retains exact child source' import-valid]
  ==
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  output
  |=  [same=@t zero=@t unsupported=@t precedence=@t duplicate=@t invalid=@t distinct=@t parent=@t child=@t generic=@t duplicate-generic=@t atoms=@t flag=@t nested=@t order=@t]
  ^-  @t
  =/  result=(list [@t ?])  (run same zero unsupported precedence duplicate invalid distinct parent child generic duplicate-generic atoms flag nested order)
  (of-wain:format (turn result |=(entry=[@t ?] (crip "{(trip -.entry)}: {?:(+.entry "ok" "BAD")}"))))
++  report
  ^-  @t
  (output (text same) (text zero) (text unsupported) (text precedence) (text duplicate) (text invalid) (text distinct) (text parent) (text child) (text generic) (text duplicate-generic) (text atoms) (text flag) (text nested) (text order))
++  test-full-overlap-basic
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"full-module overlap output differs"]
  ~
--
