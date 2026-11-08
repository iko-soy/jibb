::  Full-check Jibb -> checked artifact -> linked Core differential execution.
::  Expected nouns, crashes, and traces below are specified from the source
::  programs, not obtained from either implementation under test.
/+  jibb, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
+$  fixture
  $:  label=term
      entry=term
      source=@t
      modules=jbundle:jibb
      arguments=(list noun)
      expected=outcome:jibb-core
      traces=(unit (list @t))
      needs=(list term)
  ==
::
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  value-case
  |=  [label=term source=@t expected=noun]
  ^-  fixture
  [label %result source ~ ~ [%ok expected] ~ ~]
::
++  crash-case
  |=  label=term
  ^-  fixture
  [label %result '++ result !!\0a' ~ ~ [%crash ~] ~ ~]
::
++  noun-value
  |=  n=noun
  ^-  value:jibb-core
  ?@  n  [%atom n]
  [%cell $(n -.n) $(n +.n)]
::
++  atom-native
  |=  [v=value:jibb-core operation=$-(@ @)]
  ^-  evaluation:jibb-core
  ?.  ?=(%atom -.v)  !!
  [[%atom (operation val.v)] ~]
::
++  pair-native
  |=  [v=value:jibb-core operation=$-([@ @] @)]
  ^-  evaluation:jibb-core
  ?.  ?=(%cell -.v)  !!
  ?.  ?=(%atom -.hed.v)  !!
  ?.  ?=(%atom -.tal.v)  !!
  [[%atom (operation val.hed.v val.tal.v)] ~]
::
++  apply-reference
  |=  [fun=value:jibb-core sample=value:jibb-core]
  ^-  evaluation:jibb-core
  ?-  -.fun
    ?(%atom %cell)  !!
    %native         (run.fun sample)
    %closure
      %:  evaluate-env:jibb-core
        body.fun
        [[%value sample.fun sample] env.fun]
        reference-registry
      ==
  ==
::
++  turn-native
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  ?.  ?=(%cell -.v)  !!
  =/  items=value:jibb-core  hed.v
  =/  fun=value:jibb-core  tal.v
  |-
  ^-  evaluation:jibb-core
  ?:  ?=(%atom -.items)
    ?.  =(0 val.items)  !!
    [[%atom 0] ~]
  ?.  ?=(%cell -.items)  !!
  =/  called=evaluation:jibb-core  (apply-reference fun hed.items)
  =/  rest=evaluation:jibb-core  $(items tal.items)
  [[%cell val.called val.rest] (weld traces.called traces.rest)]
::
++  lent-native
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  =/  count=@ud  0
  |-
  ?:  ?=(%atom -.v)
    ?.  =(0 val.v)  !!
    [[%atom count] ~]
  ?.  ?=(%cell -.v)  !!
  $(v tal.v, count +(count))
::
++  fail-native
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  !!
::
++  reference-registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  *(map name:jibb-core native:jibb-core)
  =.  r  (~(put by r) [%own %add] |=(v=value:jibb-core (pair-native v add)))
  =.  r  (~(put by r) [%own %sub] |=(v=value:jibb-core (pair-native v sub)))
  =.  r  (~(put by r) [%own %mul] |=(v=value:jibb-core (pair-native v mul)))
  =.  r  (~(put by r) [%own %gth] |=(v=value:jibb-core (pair-native v gth)))
  =.  r  (~(put by r) [%own %dec] |=(v=value:jibb-core (atom-native v dec)))
  =.  r  (~(put by r) [%own %lent] lent-native)
  =.  r  (~(put by r) [%own %turn] turn-native)
  =.  r  (~(put by r) [%own %fail] fail-native)
  %+  ~(put by r)  [%own %eq]
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  ?.  ?=(%cell -.v)  !!
  [[%atom ?:(=((value-noun:jibb-core hed.v) (value-noun:jibb-core tal.v)) 0 1)] ~]
::
++  nock-registry
  ^-  native-registry:jibb-nock
  =/  r=native-registry:jibb-nock  *(map name:jibb-core noun)
  =.  r  (~(put by r) [%own %add] add)
  =.  r  (~(put by r) [%own %sub] sub)
  =.  r  (~(put by r) [%own %mul] mul)
  =.  r  (~(put by r) [%own %gth] gth)
  =.  r  (~(put by r) [%own %dec] dec)
  =.  r  (~(put by r) [%own %lent] lent)
  =.  r  (~(put by r) [%own %turn] turn)
  =.  r  (~(put by r) [%own %fail] |=(* !!))
  (~(put by r) [%own %eq] |=([a=* b=*] =(a b)))
::
++  reference-execution
  |=  [e=expr:jibb-core arguments=(list noun)]
  ^-  execution:jibb-core
  =/  first=(each evaluation:jibb-core tang)
    (mule |.((evaluate:jibb-core e reference-registry)))
  ?:  ?=(%| -.first)  [[%crash ~] ~]
  =/  current=evaluation:jibb-core  p.first
  |-
  ?~  arguments
    =/  canonical=(each noun tang)  (mule |.((value-noun:jibb-core val.current)))
    ?:  ?=(%| -.canonical)  [[%crash ~] traces.current]
    [[%ok p.canonical] traces.current]
  =/  called=(each evaluation:jibb-core tang)
    %-  mule
    |.((apply-reference val.current (noun-value i.arguments)))
  ?:  ?=(%| -.called)  [[%crash ~] traces.current]
  =/  next=evaluation:jibb-core  p.called
  %=  $
    arguments  t.arguments
    current    next(traces (weld traces.current traces.next))
  ==
::
++  nock-outcome
  |=  [subject=noun formula=noun]
  ^-  outcome:jibb-core
  =/  result  (mock [subject formula] |=(^ ~))
  ?-  -.result
    %0  [%ok p.result]
    %1  [%crash ~]
    %2  [%crash ~]
  ==
::
++  run-nock
  |=  [e=expr:jibb-core arguments=(list noun)]
  ^-  outcome:jibb-core
  =/  made=outcome:jibb-core  (nock-outcome 0 (emit:jibb-nock e nock-registry))
  ?:  ?=(%crash -.made)  made
  =/  current=noun  val.made
  |-
  ?~  arguments  [%ok current]
  =/  called=outcome:jibb-core
    (nock-outcome current [9 2 10 [6 [1 i.arguments]] [0 1]])
  ?:  ?=(%crash -.called)  called
  $(arguments t.arguments, current val.called)
::
++  native-id
  |=  definition=lowering-definition:jibb
  ^-  (unit term)
  ?.  ?=(%prelude -.definition)  ~
  ?.  =(at.definition /lib/jibb/prelude/jibb)  ~
  ?.  (lien `(list term)`~[%add %sub %mul %gth %dec %lent %turn %eq] |=(n=term =(n name.definition)))  ~
  `name.definition
::
++  authenticate-root
  |=  root=checked-module:jibb
  ^-  checked-module:jibb
  =/  refs=(list lowering-reference:jibb)
    %+  turn  references.root
    |=  ref=lowering-reference:jibb
    ref(native (native-id definition.ref))
  root(references refs)
::
++  authenticate-cache
  |=  cache=jlowering-cache:jibb
  ^-  jlowering-cache:jibb
  %+  turn  cache
  |=  entry=[at=path artifact=checked-module:jibb]
  entry(artifact (authenticate-root artifact.entry))
::
++  artifacts
  |=  [root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (list checked-module:jibb)
  :-  root
  (turn cache |=(entry=[at=path artifact=checked-module:jibb] artifact.entry))
::
++  feature-present
  |=  [feature=term root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  ?
  =/  all=(list checked-module:jibb)  (artifacts root cache)
  ?-  feature
    %native
      %-  lien
      :-  all
      |=  artifact=checked-module:jibb
      (lien references.artifact |=(ref=lowering-reference:jibb ?=(^ native.ref)))
    %wing   (lien all |=(artifact=checked-module:jibb ?=(^ wings.artifact)))
    %edit   (lien all |=(artifact=checked-module:jibb ?=(^ edits.artifact)))
    %match  (lien all |=(artifact=checked-module:jibb ?=(^ matches.artifact)))
    %import  ?=(^ imports.root)
    %local-rec
      %-  lien
      :-  all
      |=  artifact=checked-module:jibb
      (lien components.artifact |=(c=lowering-scc:jibb ?=(^ scope.c)))
    %top-rec
      %-  lien
      :-  all
      |=  artifact=checked-module:jibb
      %+  lien  components.artifact
      |=  c=lowering-scc:jibb
      &(?=(~ scope.c) (gth (lent members.c) 1))
    *  |
  ==
::
++  missing-feature
  |=  [features=(list term) root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (unit @t)
  ?~  features  ~
  ?.  (feature-present i.features root cache)
    `(cat 3 'feature artifact unavailable: ' i.features)
  $(features t.features)
::
++  run-fixture
  |=  [f=fixture prepared=iprelude:jibb]
  ^-  (unit @t)
  =/  at=path  (weld /tests/lower-differential ~[label.f %jibb])
  =/  built=jlowering-result:jibb
    %:  check-jibb-file-for-lowering:jibb
      at
      source.f
      ~
      ~
      modules.f
      ~[at]
      values.prepared
      molds.prepared
      ~
      `iface.prepared
    ==
  ?:  ?=(%| -.built)
    `(rap 3 ~[label.f ': full check failed: ' message.p.built])
  =/  root=checked-module:jibb  (authenticate-root root.p.built)
  =/  cache=jlowering-cache:jibb  (authenticate-cache cache.p.built)
  =/  missing=(unit @t)  (missing-feature needs.f root cache)
  ?^  missing  `(rap 3 ~[label.f ': ' u.missing])
  =/  lowered=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root)
  ?:  ?=(%| -.lowered)
    `(rap 3 ~[label.f ': lowering failed: ' p.lowered])
  =/  linked=(each expr:jibb-core @t)  (link-entry:jibb-lower entry.f root cache)
  ?:  ?=(%| -.linked)
    `(rap 3 ~[label.f ': linking failed: ' p.linked])
  =/  reference=execution:jibb-core  (reference-execution p.linked arguments.f)
  ?.  =(expected.f out.reference)
    `(rap 3 ~[label.f ': reference result differs from source-level expectation'])
  =/  trace-error=(unit @t)
    ?~  traces.f  ~
    ?.  =(u.traces.f traces.reference)
      `(rap 3 ~[label.f ': reference traces differ from source-level expectation'])
    ~
  ?^  trace-error  trace-error
  =/  nock=outcome:jibb-core  (run-nock p.linked arguments.f)
  ?.  =(expected.f nock)
    `(rap 3 ~[label.f ': Nock result differs from source-level expectation'])
  ?.  =(out.reference nock)
    `(rap 3 ~[label.f ': backend crash/noun disagreement'])
  ~
::
++  run-fixtures
  |=  [fixtures=(list fixture) prepared=iprelude:jibb]
  ^-  (list @t)
  ?~  fixtures  ~
  =/  rest=(list @t)  $(fixtures t.fixtures)
  =/  bad=(unit @t)  (run-fixture i.fixtures prepared)
  ?~  bad  rest
  [u.bad rest]
::
++  fixtures
  ^-  (list fixture)
  =/  literals=fixture
    %^  value-case  %literals
      '++ result ^- [@ud @ux @t @tas ? ~] [42 0x2a "ok" %yes %.y ~]\0a'
    [42 42 'ok' %yes 0 0]
  =/  data=fixture
    %^  value-case  %lists-units
      '++ result ^- [(list @ud) (unit @ud) ~] [~[1 2 3] `9 ~]\0a'
    [[1 2 3 0] [0 9] 0]
  =/  arithmetic=fixture
    %^  value-case  %arithmetic
      '++ result [(add 40 2) (sub 42 2) (mul 6 7) (dec 43) (gth 42 41) (eq [1 [2 3]] [1 [2 3]]) (lent ~[4 5 6]) (add 340.282.366.920.938.463.463.374.607.431.768.211.456 1)]\0a'
    [42 40 42 42 0 0 3 340.282.366.920.938.463.463.374.607.431.768.211.457]
  =.  needs.arithmetic  ~[%native]
  =/  closure=fixture
    :*  %closure  %add-offset
        '++ add-offset |= x=@ud |= y=@ud (add x y)\0a'
        ~  ~[40 2]  [%ok 42]  ~  ~[%native]
    ==
  =/  local-rec=fixture
    %^  value-case  %local-recursion
      %-  text
      :~  '++ countdown |= n=@ud'
          '  ++ loop |= left=@ud'
          '    ?- (eq left 0)'
          '      %.y 42'
          '      %.n (loop (dec left))'
          '  (loop n)'
          '++ result (countdown 12)'
      ==
    42
  =.  needs.local-rec  ~[%native %match %local-rec]
  =/  mutual=fixture
    %^  value-case  %mutual-recursion
      %-  text
      :~  '++ even |= n=@ud'
          '  ?- (eq n 0)'
          '    %.y %.y'
          '    %.n (odd (dec n))'
          '++ odd |= n=@ud'
          '  ?- (eq n 0)'
          '    %.y %.n'
          '    %.n (even (dec n))'
          '++ result [(even 12) (odd 12)]'
      ==
    [0 1]
  =.  needs.mutual  ~[%native %match %top-rec]
  =/  record=fixture
    %^  value-case  %record-wings-changes
      %-  text
      :~  '++ update |= m=[count=@ud label=@t]'
          '  [m(count=42 label="changed") count.m label.m]'
          '++ result (update [7 "old"])'
      ==
    [[42 'changed'] 7 'old']
  =.  needs.record  ~[%wing %edit]
  =/  constructors=fixture
    %^  value-case  %constructors-matches
      %-  text
      :~  '+$ choice'
          '  [%left @t]'
          '  [%right @ud]'
          '++ make-left ^- $-(@t choice) |=%left'
          '++ make-right ^- $-(@ud choice) |=%right'
          '++ render |= c=choice'
          '  ?- c'
          '    [%left words] words'
          '    [%right n] "number"'
          '++ result [(render (make-left "ok")) (render (make-right 7))]'
      ==
    ['ok' 'number']
  =.  needs.constructors  ~[%match]
  =/  collection-match=fixture
    %^  value-case  %list-unit-matches
      %-  text
      :~  '++ describe |= xs=(list @ud)'
          '  ?- xs'
          '    ~ 0'
          '    [x *] x'
          '++ unwrap |= x=(unit @ud)'
          '  ?- x'
          '    ~ 0'
          '    [~ n] n'
          '++ result [(describe ~[8 9]) (describe ~) (unwrap `7) (unwrap ~)]'
      ==
    [8 0 7 0]
  =.  needs.collection-match  ~[%match]
  =/  callback=fixture
    %^  value-case  %callback-native
      '++ result (turn ~[1 2 3] |=(x=@ud (add x 1)))\0a'
    [2 3 4 0]
  =.  needs.callback  ~[%native]
  =/  traced=fixture
    %^  value-case  %traces-by-result
      %-  text
      :~  '++ result'
          '  ~& "first"'
          '    ~& "second"'
          '      [9 "done"]'
      ==
    [9 'done']
  =.  traces.traced  `~['first' 'second']
  =/  imported=fixture
    :*  %import-root  %result
        '/= dep /tests/lower-differential/import-dep\0a++ result (bump.dep base.dep)\0a'
        ~[[/tests/lower-differential/import-dep/jibb '++ base 40\0a++ bump |= x=@ud (add x 1)\0a']]
        ~  [%ok 41]  ~  ~[%import %native]
    ==
  =/  lazy-match=fixture
    %^  value-case  %taken-match-only
      '++ result\0a  ?- %.y\0a    %.y 42\0a    %.n !!\0a'
    42
  =.  needs.lazy-match  ~[%match]
  :~  literals
      data
      arithmetic
      closure
      local-rec
      mutual
      record
      constructors
      collection-match
      callback
      traced
      imported
      lazy-match
      :*  %strict-unused-crash  %result
          '++ result\0a  ++ unused !!\0a  42\0a'
          ~  ~  [%crash ~]  ~  ~
      ==
      (crash-case %deliberate-crash)
      :*  %trace-before-crash  %result
          '++ result\0a  ~& "before"\0a    !!\0a'
          ~  ~  [%crash ~]  ~  ~
      ==
      :*  %native-zero-crash  %result
          '++ result (dec 0)\0a'
          ~  ~  [%crash ~]  ~  ~[%native]
      ==
      :*  %native-underflow-crash  %result
          '++ result (sub 1 2)\0a'
          ~  ~  [%crash ~]  ~  ~[%native]
      ==
  ==
::
++  test-lower-differential
  ^-  tang
  =/  prepared=(each iprelude:jibb @t)
    %:  prepare-bundle-detailed:jibb-prelude-fixture
      prelude
      internal
      ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]]
      ~
    ==
  ?:  ?=(%| -.prepared)
    ~[leaf+(trip (cat 3 'feature artifact unavailable: ' p.prepared))]
  ?.  =(18 (lent fixtures))  ~[leaf+"differential fixture inventory changed"]
  =/  bad=(list @t)  (run-fixtures fixtures p.prepared)
  (turn bad |=(reason=@t leaf+(trip reason)))
--
