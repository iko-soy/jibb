::  Partial source-owned deferred type transaction; not module or island validation.
/+  jibb
/*  nested-src  %txt  /tests/type-deferred/nested-src/txt
/*  principal-src  %txt  /tests/type-deferred/principal-src/txt
/*  missing-src  %txt  /tests/type-deferred/missing-src/txt
/*  conflict-src  %txt  /tests/type-deferred/conflict-src/txt
/*  duplicate-src  %txt  /tests/type-deferred/duplicate-src/txt
/*  hole-src  %txt  /tests/type-deferred/hole-src/txt
/*  local-src  %txt  /tests/type-deferred/local-src/txt
/*  mutual-src  %txt  /tests/type-deferred/mutual-src/txt
/*  mold-hole-src  %txt  /tests/type-deferred/mold-hole-src/txt
/*  face-good-src  %txt  /tests/type-deferred/face-good-src/txt
/*  face-bad-src  %txt  /tests/type-deferred/face-bad-src/txt
/*  expected  %txt  /tests/type-deferred/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  case-nested
  |=  source=@t
  ^-  (list @t)
  =/  result=(unit dgcommit:jibb)  (checked-source /ui/obligation/jibb source)
  ?~  result  ~['BAD-nested-transaction']
  =/  nested=(unit ischeme:jibb)  (ienv-lookup:jibb %nested env.u.result)
  =/  alias=(unit ischeme:jibb)  (ienv-lookup:jibb %alias env.u.result)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main env.u.result)
  ?~  nested  ~['BAD-nested']
  ?~  alias  ~['BAD-alias']
  ?~  main  ~['BAD-main']
  :~  ?:(=(typ.u.nested typ.u.alias) 'nested lexical gate and alias agree' 'BAD-alias-type')
      ?:(=(typ.u.nested typ.u.main) 'later source context closes nested constructor' 'BAD-main-type')
      ?:(!(pending-tags:jibb tags.state.u.result sub.state.u.result) 'nested obligation discharged' 'BAD-pending')
  ==
++  case-principal
  |=  source=@t
  ^-  (list @t)
  =/  result=(unit dgcommit:jibb)  (checked-source /ui/obligation/jibb source)
  ?~  result  ~['BAD-root-transaction']
  =/  built=(unit ischeme:jibb)  (ienv-lookup:jibb %built env.u.result)
  =/  text=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal env.u.result)
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal-ship env.u.result)
  ?~  built  ~['BAD-built']
  ?~  text  ~['BAD-text']
  ?~  ship  ~['BAD-ship']
  :~  ?:(?=(^ vars.u.built) 'independent built result stays polymorphic' 'BAD-principal')
      ?:(?=([%atom %t] typ.u.text) 'text use inferred' 'BAD-text-type')
      ?:(?=([%atom %p] typ.u.ship) 'ship use inferred independently' 'BAD-ship-type')
  ==
++  case-negative
  |=  [missing=@t conflict=@t duplicate=@t hole=@t]
  ^-  (list @t)
  :~  ?:(?=(~ (checked-source /ui/obligation/jibb missing)) 'missing constructor leaves no result' 'BAD-missing')
      ?:(?=(~ (checked-source /ui/obligation/jibb conflict)) 'conflicting context leaves no result' 'BAD-conflict')
      ?:(?=(~ (checked-source /ui/obligation/jibb duplicate)) 'duplicate source binding declined' 'BAD-duplicate')
      ?:(?=(~ (checked-source /ui/obligation/jibb hole)) 'definition hole does not escape' 'BAD-hole')
  ==
++  case-groups
  |=  [local=@t mutual=@t]
  ^-  (list @t)
  :~  ?:(?=(~ (checked-source /ui/obligation/jibb local)) 'local deferred definition declined' 'BAD-local')
      ?:(?=(~ (checked-source /ui/obligation/jibb mutual)) 'recursive deferred group declined' 'BAD-group')
  ==
++  case-mold-hole
  |=  hole=@t
  ^-  (list @t)
  :~  ?:(?=(~ (checked-source /ui/a/jibb hole)) 'unused mold hole declined' 'unused mold hole committed')
  ==
++  case-fresh
  ^-  (list @t)
  =/  env=ienv:jibb  ~[[%x [[%fn [%var 1.000.007] [%var 1.000.007]] ~[1.000.007 2.000.001]]]]
  =/  scanned=(unit dgscan:jibb)  (dg-all-env-ids:jibb env 200 ~)
  =/  small=(unit dgscan:jibb)  (dg-all-env-ids:jibb env 1 ~)
  ?~  scanned  ~['BAD-scan']
  :~  ?:(=(2.000.002 (dg-next-id:jibb ids.u.scanned 0)) 'fresh ID exceeds raw and quantified IDs' 'BAD-fresh')
      ?:(?=(~ small) 'fresh ID scan respects budget' 'BAD-fuel')
  ==
++  case-safety
  ^-  (list @t)
  =/  actual=itype:jibb  [%cell [%atom %ud] [%cell [%face %wrong [%atom %t]] [%atom %p]]]
  =/  expected=itype:jibb  [%cell [%atom %ud] [%var 0]]
  =/  correct=itype:jibb  [%cell [%face %right [%atom %t]] [%atom %p]]
  =/  bound=isub:jibb  ~[[0 correct]]
  =/  with-binding=ifit:jibb  (itype-fit:jibb actual expected bound 1)
  =/  dropped=ifit:jibb  (itype-fit:jibb actual expected ~ 1)
  =/  open-edges=(list dgo:jibb)  ~[[[%var 20] [%var 21] *span:jibb *span:jibb]]
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 2.000.002)
  =/  partial=(unit istate:jibb)  (dg-replay-edges:jibb open-edges st 64)
  ?~  partial  ~['BAD-partial-replay']
  =/  still-open=(unit dgscan:jibb)  (dg-obligations:jibb open-edges sub.u.partial 100 ~)
  ?~  still-open  ~['BAD-open-scan']
  =/  tag-literal=lit:jibb  [%term %tas %got '%got']
  =/  target=itype:jibb  [%fn [%atom %t] [%union ~[[%cell [%const tag-literal] [%face %value [%atom %t]]]] ~ ~ ~]]
  =/  edge=dgo:jibb  [[%tag 10 tag-literal &] target *span:jibb *span:jibb]
  =/  complete=(unit istate:jibb)  (dg-replay-edges:jibb ~[edge] st 64)
  ?~  complete  ~['BAD-complete-replay']
  =/  closed=(unit dgscan:jibb)  (dg-obligations:jibb ~[edge] sub.u.complete 100 ~)
  ?~  closed  ~['BAD-closed-scan']
  =/  repeated=(unit istate:jibb)  (dg-replay-edges:jibb ~[edge] u.complete 64)
  ?~  repeated  ~['BAD-final-replay']
  =/  open-env=ienv:jibb  ~[[%x [[%var 55] ~]]]
  =/  raw-atom=itype:jibb  [%var 900]
  =/  atom-sub=isub:jibb  ~[[900 [%avar 901]]]
  =/  normalized-atom=itype:jibb  (itype-normalize:jibb raw-atom atom-sub)
  =/  capture-state=istate:jibb  st(sub ~[[500 [%var 42]]])
  =/  capture-env=ienv:jibb  ~[[%polymorphic [[%fn [%var 42] [%var 500]] ~[42]]]]
  =/  capture-check=(unit ischeme:jibb)  (dg-generalize:jibb [%fn [%var 42] [%var 43]] capture-env ~ ~ ~ capture-state 300)
  ?~  capture-check  ~['BAD-capture-scan']
  =/  explicit-capture=(unit ischeme:jibb)  (dg-generalize:jibb [%fn [%var 80] [%var 81]] ~ ~ ~ ~[80] st 300)
  ?~  explicit-capture  ~['BAD-explicit-capture-scan']
  =/  tag-lit=lit:jibb  [%term %tas %watch '%watch']
  =/  bound-tag-state=istate:jibb  st(sub ~[[720 [%var 721]]])
  =/  tag-check=(unit ischeme:jibb)  (dg-generalize:jibb [%fn [%var 721] [%var 722]] ~ ~ ~[[720 tag-lit]] ~ bound-tag-state 300)
  ?~  tag-check  ~['BAD-tag-scan']
  =/  cycle=(list dgo:jibb)  ~[[[%var 710] [%var 711] *span:jibb *span:jibb] [[%var 711] [%var 712] *span:jibb *span:jibb] [[%var 712] [%var 710] *span:jibb *span:jibb]]
  =/  cyc=(unit ischeme:jibb)  (dg-generalize:jibb [%fn [%var 710] [%fn [%var 712] [%var 713]]] ~ cycle ~ ~ st 300)
  ?~  cyc  ~['BAD-cycle-scan']
  :~  ?:(!?=(%ok -.with-binding) 'original structural binding rejects wrong face' 'BAD-wrong-face')
      ?:(?=(%ok -.dropped) 'dropping binding would accept wrong face' 'BAD-counterexample')
      ?:(?=(^ ids.u.still-open) 'unresolved edge remains open after fit' 'BAD-open-edge')
      ?:(?=(~ ids.u.closed) 'closed constructor edge has no free IDs' 'BAD-closed-edge')
      ?:(&(=(sub.u.repeated sub.u.complete) =(next.u.repeated next.u.complete)) 'final replay is unchanged' 'BAD-final-state')
      ?:(?=(~ (dg-close-env:jibb open-env ~ 100)) 'open interface stays unpublished' 'BAD-open-interface')
      ?:(!(unsupported-atom-vars:jibb raw-atom ~ ~ atom-sub) 'raw bound variable hides atom constraint' 'BAD-raw-atom')
      ?:((unsupported-atom-vars:jibb normalized-atom ~ ~ atom-sub) 'normalized unsupported atom constraint rejected' 'BAD-normalized-atom')
      ?:(=(vars.u.capture-check ~[43]) 'scheme-local quantifier cannot hide captured ID' 'BAD-capture')
      ?:(=(vars.u.explicit-capture ~[81]) 'captured outer variable remains monomorphic' 'BAD-explicit-capture')
      ?:(=(vars.u.tag-check ~[722]) 'pending tag binding keeps reachable variable monomorphic' 'BAD-tag-binding')
      ?:(=(vars.u.cyc ~[713]) 'recursive obligation component stays monomorphic' 'BAD-cycle')
  ==
++  case-face-source
  |=  [good-src=@t bad-src=@t]
  ^-  (list @t)
  =/  good=(unit dgcommit:jibb)  (checked-source /ui/test/jibb good-src)
  =/  bad=(unit dgcommit:jibb)  (checked-source /ui/test/jibb bad-src)
  :~  ?:(?=(^ good) 'faced callback source accepted' 'BAD-faced-source')
      ?:(?=(~ bad) 'wrong nested callback face rejected' 'BAD-wrong-face-source')
  ==
++  case-face-replay
  ^-  (list @t)
  =/  tag=lit:jibb  [%term %tas %got '%got']
  =/  cases=(list itype:jibb)  ~[[%cell [%const tag] [%face %value [%atom %t]]]]
  =/  callback=itype:jibb  [%fn [%face %value [%atom %t]] [%union cases ~ ~ ~]]
  =/  edge=dgo:jibb  [[%tag 10 tag &] callback *span:jibb *span:jibb]
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 20)
  =/  solved=(unit istate:jibb)  (dg-replay-edges:jibb ~[edge] st 64)
  ?~  solved  ~['BAD-faced-replay']
  =/  after-left=itype:jibb  (itype-walk:jibb left.edge sub.u.solved)
  =/  after-right=itype:jibb  (itype-walk:jibb right.edge sub.u.solved)
  =/  record-output=itype:jibb  [%cell [%face %answer [%atom %t]] [%atom %p]]
  =/  wrong=itype:jibb  [%fn [%face %different [%atom %t]] [%union cases ~ ~ ~]]
  =/  hostile=istate:jibb  st(sub ~[[10 wrong]])
  =/  rejected=(unit istate:jibb)  (dg-replay-edges:jibb ~[edge] hostile 64)
  :~  ?:(=(after-left after-right) 'constructor resolves to exact callback' 'BAD-not-exact')
      ?:((itype-has-face:jibb left.edge sub.u.solved) 'callback retains its face' 'BAD-face-lost')
      ?:(!(itype-face-asym:jibb left.edge right.edge sub.u.solved) 'post-fit face asymmetry is absent' 'BAD-face-asymmetry')
      ?:((itype-output-may-be-cell:jibb record-output sub.u.solved) 'record output stays cell-capable' 'BAD-output')
      ?:(?=(~ rejected) 'prebound incompatible callback is rejected' 'BAD-incompatible')
  ==
++  checked-source
  |=  [at=path source=@t]
  ^-  (unit dgcommit:jibb)
  =/  detail=dgparse:jibb  (dg-root-detail:jibb at source)
  ?>  parsed.detail
  result.detail
++  case-grec-scan
  ^-  (list @t)
  =/  tree=itype:jibb  [%grec /ui/test/jibb %tree ~ *shape:jibb ~[[%var 7]]]
  =/  bounded=(unit dgscan:jibb)  (dg-scan:jibb ~[tree] ~ 256 ~)
  =/  env=ienv:jibb  ~[[%t [tree ~[7]]]]
  =/  all=(unit dgscan:jibb)  (dg-all-env-ids:jibb env 256 ~)
  :~  ?:(?=(~ bounded) 'grec constraint scan declines' 'BAD-grec-scan')
      ?:(?=(~ all) 'grec fresh-id scan declines' 'BAD-grec-freshness')
  ==
++  case-default-behavior
  ^-  @t
  =/  parsed  (parse:jibb /ui/test/jibb '++ example (send |=%got)')
  ?:  ?=(%| -.parsed)  'BAD parse'
  ?~  defs.p.parsed  'BAD missing definition'
  =/  d=def:jibb  i.defs.p.parsed
  ?.  ?=(%value -.d)  'BAD not value'
  =/  callback=itype:jibb  [%fn [%atom %t] [%var 100]]
  =/  head=itype:jibb  [%fn callback callback]
  =/  env=ienv:jibb  ~[[%send [head ~[100]]]]
  =/  state=istate:jibb  *istate:jibb
  =/  ordinary=iresult:jibb  (infer-fragment:jibb val.d env state)
  ?:  ?=(%& -.ordinary)  'BAD default deferred inference accepted'
  =/  enabled=iresult:jibb  (infer-fragment:jibb val.d env state(defer `~))
  ?:  ?=(%| -.enabled)  'BAD explicit capability failed'
  ?~  obligations.state.p.enabled  'BAD missing obligation'
  'default inference declines; explicit capability creates obligation'
++  case-screen-bounds
  ^-  @t
  =/  parsed  (parse:jibb /ui/test/jibb '++ example (send |=%got)\0a++ other 1\0a')
  ?:  ?=(%| -.parsed)  'BAD parse'
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([* [* ~]] ds)  'BAD definitions'
  =/  good=def:jibb  i.ds
  =/  other=def:jibb  i.t.ds
  ?.  &(?=(%value -.good) ?=(%value -.other))  'BAD value types'
  =/  raw=expr:jibb  val.good
  ?.  ?=(%group -.raw)  'BAD group'
  =/  call=expr:jibb  inner.raw
  ?.  ?=(%call -.call)  'BAD call'
  =/  wrap
    |=  [n=@ud e=expr:jibb]
    ^-  expr:jibb
    |-
    ?~  n  e
    $(n (dec n), e [%group (span-of:jibb e) e])
  =/  w63=expr:jibb  (wrap 63 call)
  =/  w64=expr:jibb  (wrap 64 call)
  ?.  (dg-direct-source:jibb w63 64)  'BAD 63 wrappers rejected'
  ?:  (dg-direct-source:jibb w64 64)  'BAD 64 wrappers accepted'
  =/  exact=(list def:jibb)  (weld (reap 63 other) ~[good])
  =/  over=(list def:jibb)  [other exact]
  ?.  (dg-source-candidate:jibb exact 64)  'BAD exact definitions rejected'
  ?:  (dg-source-candidate:jibb over 64)  'BAD excessive definitions accepted'
  =/  unsupported=expr:jibb  [%trace (span-of:jibb call) call call]
  ?:  (dg-direct-source:jibb unsupported 64)  'BAD unsupported wrapper accepted'
  'candidate screen boundaries passed'
++  deferred-report
  |=  [nested-src=@t principal-src=@t missing-src=@t conflict-src=@t duplicate-src=@t hole-src=@t local-src=@t mutual-src=@t mold-hole-src=@t face-good-src=@t face-bad-src=@t]
  ^-  @t
  =/  lines=(list @t)  (case-nested nested-src)
  =.  lines  (weld lines (case-principal principal-src))
  =.  lines  (weld lines (case-negative missing-src conflict-src duplicate-src hole-src))
  =.  lines  (weld lines (case-groups local-src mutual-src))
  =.  lines  (weld lines (case-mold-hole mold-hole-src))
  =.  lines  (weld lines case-fresh)
  =.  lines  (weld lines case-safety)
  =.  lines  (weld lines (case-face-source face-good-src face-bad-src))
  =.  lines  (weld lines case-face-replay)
  =.  lines  (weld lines case-grec-scan)
  =.  lines  (weld lines ~[case-default-behavior case-screen-bounds])
  (of-wain:format lines)
++  test-deferred
  ^-  tang
  =/  result=@t  (deferred-report (text nested-src) (text principal-src) (text missing-src) (text conflict-src) (text duplicate-src) (text hole-src) (text local-src) (text mutual-src) (text mold-hole-src) (text face-good-src) (text face-bad-src))
  ?.  =((to-wain:format (cat 3 result '\0a')) expected)  ~[leaf+"deferred partial transaction report differs"]
  ~
--
