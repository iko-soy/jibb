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
++  source-witness
  |=  [file=path source=@t name=term]
  ^-  ?
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  |
  =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
  =/  found=(unit shape:jibb)  (find-simple-mold:jibb name molds)
  ?~  found  |
  =/  sh=shape:jibb  u.found
  =?  sh  ?=(%generic -.sh)  body.sh
  ?.  ?=(%union -.sh)  |
  ?=(^ (union-source-overlap:jibb cases.sh molds 256))
++  detailed
  |=  [file=path source=@t modules=jbundle:jibb]
  ^-  detailed-result
  (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] ~ ~ ~ ~)
++  expected-overlap
  |=  [file=path source=@t name=term]
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
     =(3 line.beg.first.cases.ev)
     =(3 col.beg.first.cases.ev)
     =(4 line.beg.second.cases.ev)
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
  |=  [same=@t zero=@t unsupported=@t precedence=@t duplicate=@t invalid=@t distinct=@t parent=@t child=@t generic=@t duplicate-generic=@t]
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
      ['same head has source-bound overlap' (expected-overlap root same %bad)]
      ['zero spelling has source-bound overlap' (expected-overlap root zero %bad)]
      ['generic wrapper has source-bound overlap' (expected-overlap root generic %bad)]
      ['duplicate generic parameters remain unstructured' (plain-failure root duplicate-generic)]
      ['unsupported remains unstructured' (plain-failure root unsupported)]
      ['later overlap exists in precedence source' (source-witness root precedence %bad)]
      ['earlier unsupported mold takes precedence' (plain-failure root precedence)]
      ['duplicate source parsed but rejects without overlap' (plain-failure root duplicate)]
      ['invalid source rejects without overlap' invalid-clean]
      ['distinct alias source parses and checks' &(?=(%& -.good-parsed) ?=(%& -.good-result))]
      ['parent itself has different positive overlap' (source-witness root parent %parent-bad)]
      ['legacy full-module error contains both excerpts' legacy-excerpts]
      ['import overlap retains exact child source' import-valid]
  ==
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  output
  |=  [same=@t zero=@t unsupported=@t precedence=@t duplicate=@t invalid=@t distinct=@t parent=@t child=@t generic=@t duplicate-generic=@t]
  ^-  @t
  =/  result=(list [@t ?])  (run same zero unsupported precedence duplicate invalid distinct parent child generic duplicate-generic)
  (of-wain:format (turn result |=(entry=[@t ?] (crip "{(trip -.entry)}: {?:(+.entry "ok" "BAD")}"))))
++  test-full-overlap-basic
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  (output (text same) (text zero) (text unsupported) (text precedence) (text duplicate) (text invalid) (text distinct) (text parent) (text child) (text generic) (text duplicate-generic))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"full-module overlap output differs"]
  ~
--
