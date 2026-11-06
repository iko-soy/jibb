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
++  report
  ^-  @t
  %-  of-wain:format
  :~  (case-report 'rich' rich)
      (case-report 'plain' plain)
      (case-report 'simple' simple)
      (case-report 'missing' missing)
      (case-report 'wrong' wrong)
      (case-report 'duplicate' duplicate)
      (case-report 'dangling' dangling)
      (case-report 'collision early' collision-early)
      (case-report 'collision late' collision-late)
  ==
++  case-report
  |=  [label=@t source=wain]
  ^-  @t
  (cat 3 label (cat 3 '\0a' (golden-types-with-marks:jibb /ui/context/jibb (text source) ~ ~)))
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
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)  ~[leaf+"report differs from committed types"]
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
  =/  atom=itype:jibb  [%const literal]
  =/  faced=itype:jibb  [%face %named atom]
  =/  union=itype:jibb  [%union ~[atom [%cell [%const [%term %tas %some '%some']] [%face %value [%atom %t]]]] ~ ~ ~]
  =/  faced-case=itype:jibb  [%union ~[faced] ~ ~ ~]
  =/  fit
    |=  target=itype:jibb
    ^-  ?
    =/  edge=icore-edge:jibb  [%fit actual target *span:jibb *span:jibb %literal ~]
    =/  solved=(unit istate:jibb)  (icore-solve:jibb st(queue ~[edge], general-defer &))
    ?~  solved  |
    &(?=(~ core-error.u.solved) ?=(~ queue.u.solved))
  ::  The retired transaction declined faced targets as a recovery limit.
  ::  The ordinary queue can resolve them; incompatible written faces
  ::  must still fail, and an explicit cast must retain its value face.
  ?.  &((fit atom) (fit union) (fit faced) (fit faced-case))
    ~[leaf+"known literal target did not settle"]
  =/  incompatible=icore-edge:jibb
    [%fit [%face %other atom] faced *span:jibb *span:jibb %literal ~]
  =/  rejected=(unit istate:jibb)
    (icore-solve:jibb st(queue ~[incompatible], general-defer &))
  ?:  ?~(rejected | ?=(~ core-error.u.rejected))
    ~[leaf+"conflicting literal faces were accepted"]
  =/  literal-source=@t  '++ literal ^- [named=%none] %none\0a'
  =/  literal-result=jfile-result:jibb
    (infer-jibb-file:jibb at literal-source ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.literal-result)  ~[leaf+(trip p.literal-result)]
  =/  value=(unit ischeme:jibb)  (ienv-lookup:jibb %literal values.iface.p.literal-result)
  ?~  value  ~[leaf+"faced literal is missing"]
  ?.  =(typ.u.value faced)  ~[leaf+"faced literal lost its declared face"]
  ~
--
