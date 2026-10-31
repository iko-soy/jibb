/+  jibb
/*  rich  %txt  /tests/type-deferred-context/rich/txt
/*  plain  %txt  /tests/type-deferred-context/plain/txt
/*  simple  %txt  /tests/type-deferred-context/simple/txt
/*  missing  %txt  /tests/type-deferred-context/missing/txt
/*  wrong  %txt  /tests/type-deferred-context/wrong/txt
/*  duplicate  %txt  /tests/type-deferred-context/duplicate/txt
/*  dangling  %txt  /tests/type-deferred-context/dangling/txt
/*  collision-early  %txt  /tests/type-deferred-context/collision-early/txt
/*  collision-late  %txt  /tests/type-deferred-context/collision-late/txt
/*  expected  %txt  /tests/type-deferred-context/report/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-context
  ^-  tang
  =/  at=path  /ui/context/jibb
  =/  good=(list wain)  ~[rich plain simple]
  =/  bad=(list wain)  ~[missing wrong duplicate dangling collision-early collision-late]
  ?.  (levy (weld good bad) |=(src=wain ?=(^ src)))  ~[leaf+"source missing"]
  =/  source=@t  (text rich)
  =/  parsed  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  ~[leaf+"positive source does not parse"]
  =/  result=jfile-result:jibb  (infer-jibb-file:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"positive library did not publish"]
  =/  values=ienv:jibb  values.iface.p.result
  =/  built=(unit ischeme:jibb)  (ienv-lookup:jibb %built values)
  ?~  built  ~[leaf+"built missing"]
  ?~  vars.u.built  ~[leaf+"principal polymorphism lost"]
  ?^  t.vars.u.built  ~[leaf+"unexpected additional quantifiers"]
  =/  built-type=itype:jibb  typ.u.built
  ?.  ?=(%fn -.built-type)  ~[leaf+"built is not a gate"]
  ?.  ?=(%var -.sample.built-type)  ~[leaf+"built sample is not generic"]
  ?.  =(sample.built-type product.built-type)  ~[leaf+"built input and result differ"]
  ?.  =(id.sample.built-type i.vars.u.built)  ~[leaf+"built quantified identity differs"]
  =/  reveal=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal values)
  =/  reveal-ship=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal-ship values)
  ?~  reveal  ~[leaf+"text result missing"]
  ?~  reveal-ship  ~[leaf+"ship result missing"]
  ?.  ?=([%atom %t] typ.u.reveal)  ~[leaf+"text result changed"]
  ?.  ?=([%atom %p] typ.u.reveal-ship)  ~[leaf+"ship result changed"]
  =/  report=@t  (golden-types-with-marks:jibb at source ~ ~)
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)  ~[leaf+"report differs from committed types"]
  =/  rest-good=(list wain)  ~[plain simple]
  =/  checked=?
    %+  levy  rest-good
    |=  src=wain
    =/  source=@t  (text src)
    =/  parsed  (parse:jibb at source)
    ?:  ?=(%| -.parsed)  |
    =/  result=jfile-result:jibb  (infer-jibb-file:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
    ?=(%& -.result)
  ?.  checked  ~[leaf+"simple positive declined or did not parse"]
  =.  checked
    %+  levy  bad
    |=  src=wain
    =/  source=@t  (text src)
    =/  parsed  (parse:jibb at source)
    ?:  ?=(%| -.parsed)  |
    =/  result=jfile-result:jibb  (infer-jibb-file:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
    ?=(%| -.result)
  ?.  checked  ~[leaf+"negative source published or did not parse"]
  =/  literal=lit:jibb  [%term %tas %none '%none']
  =/  actual=itype:jibb  [%tag 10 literal |]
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 20)
  ?^  (dg-stage:jibb ~ ~ ~ st ~ 65)  ~[leaf+"oversized retry fuel accepted"]
  ?^  (dg-stage:jibb defs.p.parsed ~ ~ st ~ 0)  ~[leaf+"source beyond retry fuel accepted"]
  =/  atom=itype:jibb  [%const literal]
  =/  faced=itype:jibb  [%face %named atom]
  =/  union=itype:jibb  [%union ~[atom [%cell [%const [%term %tas %some '%some']] [%face %value [%atom %t]]]] ~ ~ ~]
  =/  faced-case=itype:jibb  [%union ~[faced] ~ ~ ~]
  =/  fit
    |=  target=itype:jibb
    ^-  ?
    =/  edge=dgo:jibb  [actual target *span:jibb *span:jibb]
    ?=(^ (dg-replay-edges:jibb ~[edge] st 64))
  ?.  &((fit atom) (fit union))  ~[leaf+"plain literal replay declined"]
  ?:  |((fit faced) (fit faced-case))  ~[leaf+"faced literal replay accepted"]
  ~
--
