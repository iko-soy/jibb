::  Deferred constraints use the same checker as every complete module.
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
++  source-report
  |=  [name=@t source=wain]
  ^-  @t
  (cat 3 name (cat 3 '\0a' (golden-types-with-marks:jibb /ui/obligation/jibb (text source) ~ ~)))
++  report
  ^-  @t
  %-  of-wain:format
  :~  (source-report 'nested' nested-src)
      (source-report 'principal' principal-src)
      (source-report 'missing' missing-src)
      (source-report 'conflict' conflict-src)
      (source-report 'duplicate' duplicate-src)
      (source-report 'hole' hole-src)
      (source-report 'local' local-src)
      (source-report 'mutual' mutual-src)
      (source-report 'mold hole' mold-hole-src)
      (source-report 'faced callback' face-good-src)
      (source-report 'wrong callback face' face-bad-src)
  ==
++  test-source
  ^-  tang
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"common checker source reports differ"]
  ~
++  test-queue
  ^-  tang
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 100, general-defer &)
  =/  open=icore-edge:jibb  [%fit [%var 20] [%var 21] *span:jibb *span:jibb %open ~]
  =/  partial=(unit istate:jibb)  (icore-solve:jibb st(queue ~[open]))
  ?~  partial  ~[leaf+"open constraint solver failed"]
  ?^  core-error.u.partial  ~[leaf+"open constraint was reported as an error"]
  ?^  (icore-close-env:jibb ~[[%x [[%var 20] ~ ~]]] sub.u.partial)
    ~[leaf+"an unresolved module variable escaped"]
  =/  lit=lit:jibb  [%term %tas %got '%got']
  =/  cases=(list itype:jibb)  ~[[%cell [%const lit] [%face %value [%atom %t]]]]
  =/  target=itype:jibb  [%fn [%face %value [%atom %t]] [%union cases ~ ~ ~]]
  =/  edge=icore-edge:jibb  [%fit [%tag 10 lit &] target *span:jibb *span:jibb %callback ~]
  =/  solved=(unit istate:jibb)  (icore-solve:jibb st(queue ~[edge]))
  ?~  solved  ~[leaf+"constructor constraint solver failed"]
  ?^  core-error.u.solved  ~[leaf+"constructor constraint was rejected"]
  ?^  queue.u.solved  ~[leaf+"constructor constraint remained pending"]
  ?.  =((itype-normalize:jibb [%var 10] sub.u.solved) target)
    ~[leaf+"resolved constructor lost its callback face"]
  =/  repeated=(unit istate:jibb)  (icore-solve:jibb u.solved)
  ?~  repeated  ~[leaf+"settled solver failed on replay"]
  ?.  &(=(sub.u.repeated sub.u.solved) =(next.u.repeated next.u.solved))
    ~[leaf+"settled solver changed its substitution or allocated variables"]
  =/  wrong=itype:jibb  [%fn [%face %different [%atom %t]] [%union cases ~ ~ ~]]
  =/  hostile=istate:jibb  st(queue ~[edge], sub (isub-from-bindings:jibb ~[[10 wrong]]))
  =/  rejected=(unit istate:jibb)  (icore-solve:jibb hostile)
  ?:  ?~(rejected | ?=(~ core-error.u.rejected))
    ~[leaf+"prebound incompatible callback escaped"]
  ~
++  test-generalization
  ^-  tang
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(next 1.000, general-defer &, levels (ilevel-register:jibb 0 1.000 1 ~))
  =/  captured=istate:jibb  st(levels (~(put by levels.st) 80 0))
  =/  cap=(unit ischeme:jibb)  (icore-generalize:jibb [%fn [%var 80] [%var 81]] 0 captured)
  ?~  cap  ~[leaf+"captured-variable generalization failed"]
  ?.  =(vars.u.cap ~[81])  ~[leaf+"outer variable was generalized"]
  =/  lit=lit:jibb  [%term %tas %watch '%watch']
  =/  tagged=istate:jibb  st(sub (isub-from-bindings:jibb ~[[720 [%var 721]]]), tags ~[[720 lit *span:jibb]])
  =/  tag=(unit ischeme:jibb)  (icore-generalize:jibb [%fn [%var 721] [%var 722]] 0 tagged)
  ?~  tag  ~[leaf+"tag-constrained generalization failed"]
  ?.  =(vars.u.tag ~[722])  ~[leaf+"tag-reachable variable was generalized"]
  =/  edges=(list icore-edge:jibb)
    :~  [%fit [%var 710] [%var 711] *span:jibb *span:jibb %a ~]
        [%fit [%var 711] [%var 712] *span:jibb *span:jibb %b ~]
        [%fit [%var 712] [%var 710] *span:jibb *span:jibb %c ~]
    ==
  =/  cyc=(unit ischeme:jibb)
    (icore-generalize:jibb [%fn [%var 710] [%fn [%var 712] [%var 713]]] 0 st(queue edges))
  ?~  cyc  ~[leaf+"recursive constraint generalization failed"]
  ?.  =(vars.u.cyc ~[713])  ~[leaf+"recursive constraint component was generalized"]
  ~
++  test-bindings
  ^-  tang
  =/  actual=itype:jibb  [%cell [%atom %ud] [%cell [%face %wrong [%atom %t]] [%atom %p]]]
  =/  expected=itype:jibb  [%cell [%atom %ud] [%var 0]]
  =/  correct=itype:jibb  [%cell [%face %right [%atom %t]] [%atom %p]]
  =/  bound=isub:jibb  (isub-from-bindings:jibb ~[[0 correct]])
  =/  fitted=ifit:jibb  (itype-fit:jibb actual expected bound 1)
  ?:  ?=(%ok -.fitted)
    ~[leaf+"fitting forgot the original structural binding"]
  =/  unbound=ifit:jibb  (itype-fit:jibb actual expected ~ 1)
  ?.  ?=(%ok -.unbound)
    ~[leaf+"unbound structural control failed"]
  =/  raw=itype:jibb  [%var 900]
  =/  sub=isub:jibb  (isub-from-bindings:jibb ~[[900 [%avar 901]]])
  ?.  (unsupported-atom-vars:jibb (itype-normalize:jibb raw sub) ~ ~ sub)
    ~[leaf+"normalization lost the atom constraint"]
  ~
++  test-capacity
  ^-  tang
  =/  src=@t
    =/  n=@ud  100
    =/  out=@t  '+$ message\0a  [%got value=@t]\0a  %idle\0a++ send |= f=$-(@t A) f\0a'
    |-
    ?:  =(n 0)  out
    =/  name=tape  "gate-{(scow %ud n)}"
    $(n (dec n), out (cat 3 out (crip "++ {name} ^- $-(@t message) (send |=%got)\0a")))
  =/  checked=jfile-result:jibb  (infer-jibb-file:jibb /ui/many/jibb src ~ ~ ~ ~[/ui/many/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  ?.  =((lent values.iface.p.checked) 101)  ~[leaf+"large module lost definitions"]
  ~
++  case-fresh
  ^-  (list @t)
  =/  env=ienv:jibb  ~[[%x [[%fn [%var 1.000.007] [%var 1.000.007]] ~[1.000.007 2.000.001] ~]]]
  :~  ?:(=(`2.000.002 (ienv-fresh-id:jibb env)) 'fresh ID exceeds raw and quantified IDs' 'BAD-fresh')
      ?:(=(`1 (ienv-fresh-id:jibb ~)) 'fresh ID of an empty environment is 1' 'BAD-empty')
  ==
++  case-recursive-scan
  ^-  (list @t)
  =/  key=gkey:jibb  [/ui/test/jibb *span:jibb %tree]
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) key [*span:jibb & ~['A'] ~ [%union ~[[%const [%term %tas %end '%end']] [%cell [%const [%term %tas %node '%node']] [%ref key ~[[%param 'A']]]]]]])
  =/  tree=itype:jibb  [%mrec /ui/test/jibb *span:jibb %tree ~ graph ~[[%var 7]]]
  =/  bounded=(unit dgscan:jibb)  (dg-scan:jibb ~[tree] ~ 256 ~)
  =/  env=ienv:jibb  ~[[%t [tree ~[7] ~]] [%r [[%cell [%recursive %notes %node ~] [%var 9]] ~ ~]]]
  :~  ?:(?~(bounded | (lien ids.u.bounded |=(n=@ud =(n 7)))) 'recursive constraint scan retains arguments' 'BAD-recursive-scan')
      ?:(=(`10 (ienv-fresh-id:jibb env)) 'fresh ID passes over recursive arguments and leaves' 'BAD-recursive-freshness')
  ==
++  test-recursive-freshness
  ^-  tang
  =/  wanted=(list @t)
    :~  'fresh ID exceeds raw and quantified IDs'
        'fresh ID of an empty environment is 1'
        'recursive constraint scan retains arguments'
        'fresh ID passes over recursive arguments and leaves'
    ==
  ?.  =((weld case-fresh case-recursive-scan) wanted)
    ~[leaf+"recursive constraints or allocation lost variables"]
  ~
--
