::  Source-bound full-module overlap diagnostics.
/+  jibb
/*  parent  %txt  /tests/type-full-overlap/parent/txt
/*  child  %txt  /tests/type-full-overlap/child/txt
/*  distinct  %txt  /tests/type-full-overlap/distinct/txt
/*  expected  %txt  /tests/type-full-overlap/expected-graph/txt
|%
+$  overlap-evidence  [file=path source=@t name=term cases=upair:jibb]
+$  detailed-result
  (each [iface=ifile:jibb cache=jcache:jibb] [message=@t overlap=(unit overlap-evidence)])
++  detailed
  |=  [file=path source=@t modules=jbundle:jibb]
  ^-  detailed-result
  (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] ~ ~ ~ ~)
++  source-pair
  |=  [file=path source=@t]
  ^-  (unit upair:jibb)
  =/  parsed  (parse:jibb file source)
  ?:  ?=(%| -.parsed)  ~
  =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
  =/  found=(unit shape:jibb)  (find-simple-mold:jibb %child-bad molds)
  ?~  found  ~
  ?.  ?=(%union -.u.found)  ~
  ?~  cases.u.found  ~
  ?~  t.cases.u.found  ~
  `[at.i.cases.u.found at.i.t.cases.u.found %overlap]
++  failure-message
  |=  [r=detailed-result expected-message=@t]
  ^-  ?
  ?:  ?=(%& -.r)  |
  &(=(message.p.r expected-message) ?=(~ overlap.p.r))
++  run
  |=  [parent=@t child=@t distinct=@t]
  ^-  (list [@t ?])
  =/  root=path  /ui/root/jibb
  =/  child-file=path  /ui/child/jibb
  =/  good-parsed  (parse:jibb child-file distinct)
  =/  parent-parsed  (parse:jibb root parent)
  =/  child-parsed  (parse:jibb child-file child)
  ?:  ?=(%| -.good-parsed)  ~[['BAD valid child parse' |]]
  ?:  ?=(%| -.parent-parsed)  ~[['BAD parent parse' |]]
  ?:  ?=(%| -.child-parsed)  ~[['BAD child parse' |]]
  =/  child-pair=(unit upair:jibb)  (source-pair child-file child)
  ?~  child-pair  ~[['BAD child pair' |]]
  =/  old=detailed-result  (detailed child-file distinct ~)
  =/  cache-controls=[rebuilt=? stale=? source-bound=?]
    ?:  ?=(%| -.old)  [| | |]
    =/  previous=ifile:jibb  iface.p.old
    =/  source-bound=?
      ?~  source.previous  |
      ?~  graph.previous  |
      ?&  =(at.previous child-file)
          =(u.source.previous distinct)
          (request-graph-reusable:jibb previous distinct ~ ~ ~ ~ ~ ~ ~)
          !(request-graph-reusable:jibb previous child ~ ~ ~ ~ ~ ~ ~)
      ==
    =/  detached=ifile:jibb  previous(graph ~)
    =/  rebuilt=detailed-result
      (infer-jibb-file-detailed:jibb root parent ~ ~ ~[[child-file child]] ~[root] ~ ~ ~[[child-file detached]] ~)
    =/  stale=detailed-result
      (infer-jibb-file-detailed:jibb root parent ~ ~ ~[[child-file child]] ~[root] ~ ~ ~[[child-file previous]] ~)
    =/  rebuilt-ok=?
      ?:  ?=(%& -.rebuilt)  |
      ?~  overlap.p.rebuilt  |
      ?&  =(file.u.overlap.p.rebuilt child-file)
          =(source.u.overlap.p.rebuilt child)
          =(name.u.overlap.p.rebuilt %child-bad)
          =(cases.u.overlap.p.rebuilt u.child-pair)
      ==
    =/  stale-ok=?
      ?:  ?=(%& -.stale)  |
      &(=(message.p.stale 'cached module evidence needs unsupported inference') ?=(~ overlap.p.stale))
    [rebuilt-ok stale-ok source-bound]
  =/  middle=@t  (of-wain:format ~['/= leaf /ui/leaf' '+$ okay @t'])
  =/  leaf-file=path  /ui/leaf/jibb
  =/  middle-parsed  (parse:jibb child-file middle)
  =/  transitive=detailed-result
    (infer-jibb-file-detailed:jibb root parent ~ ~ ~[[child-file middle] [leaf-file child]] ~[root] ~ ~ ~ ~)
  =/  transitive-ok=?
    ?:  ?=(%| -.middle-parsed)  |
    ?:  ?=(%& -.transitive)  |
    ?~  overlap.p.transitive  |
    ?&  =(file.u.overlap.p.transitive leaf-file)
        =(source.u.overlap.p.transitive child)
        =(name.u.overlap.p.transitive %child-bad)
        =(cases.u.overlap.p.transitive u.child-pair)
    ==
  =/  clean-failure
    |=  r=detailed-result
    ^-  ?
    ?:  ?=(%& -.r)  |
    &(!=(0 message.p.r) ?=(~ overlap.p.r))
  =/  private-src=@t  (of-wain:format ~['/= secret /lib/jibb/internal' '+$ good @t'])
  =/  cycle-src=@t  (of-wain:format ~['/= mine /ui/root' '+$ good @t'])
  =/  private-parsed  (parse:jibb root private-src)
  =/  cycle-parsed  (parse:jibb root cycle-src)
  =/  private-result=detailed-result  (detailed root private-src ~)
  =/  cycle-result=detailed-result  (detailed root cycle-src ~)
  =/  duplicate-result=detailed-result  (detailed root parent ~[[child-file child] [child-file child]])
  =/  missing-result=detailed-result  (detailed root parent ~)
  :~  ['detached cache rebuild preserves child evidence' rebuilt.cache-controls]
      ['mismatched graph cache declines without evidence' stale.cache-controls]
      ['verified cache source binding' source-bound.cache-controls]
      ['private import declines before source proof' &(?=(%& -.private-parsed) (failure-message private-result 'the prelude internal module is private'))]
      ['active cycle declines before source proof' &(?=(%& -.cycle-parsed) (failure-message cycle-result (crip "import cycle at {(spud root)}")))]
      ['duplicate child sources decline without evidence' (clean-failure duplicate-result)]
      ['missing child source declines without evidence' (clean-failure missing-result)]
      ['transitive import retains leaf source' transitive-ok]
  ==
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  output
  |=  [parent=@t child=@t distinct=@t]
  ^-  @t
  =/  result=(list [@t ?])  (run parent child distinct)
  (of-wain:format (turn result |=(entry=[@t ?] (crip "{(trip -.entry)}: {?:(+.entry "ok" "BAD")}"))))
++  test-full-overlap-graph
  ^-  tang
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t  (output (text parent) (text child) (text distinct))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"full-module overlap output differs"]
  ~
--
