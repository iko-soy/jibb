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
++  dvr-native
  |=  v=value:jibb-core
  ^-  evaluation:jibb-core
  ?.  ?=(%cell -.v)  !!
  ?.  ?=(%atom -.hed.v)  !!
  ?.  ?=(%atom -.tal.v)  !!
  =/  split=[p=@ q=@]  (dvr val.hed.v val.tal.v)
  [[%cell [%atom p.split] [%atom q.split]] ~]
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
  =.  r  (~(put by r) [%own %dvr] dvr-native)
  =.  r  (~(put by r) [%own %div] |=(v=value:jibb-core (pair-native v div)))
  =.  r  (~(put by r) [%own %mod] |=(v=value:jibb-core (pair-native v mod)))
  =.  r  (~(put by r) [%own %pow] |=(v=value:jibb-core (pair-native v pow)))
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
  =.  r  (~(put by r) [%own %dvr] dvr)
  =.  r  (~(put by r) [%own %div] div)
  =.  r  (~(put by r) [%own %mod] mod)
  =.  r  (~(put by r) [%own %pow] pow)
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
  ?.  (lien `(list term)`~[%add %sub %mul %dvr %div %mod %pow %gth %dec %lent %turn %eq] |=(n=term =(n name.definition)))  ~
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
    %projection  (lien all |=(artifact=checked-module:jibb ?=(^ projections.artifact)))
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
  =/  term-literals=fixture
    %^  value-case  %term-literals
      %-  text
      :~  '++ choose |= flag=? ^- @ud'
          '  ?- flag'
          '    %& (add %40 %2)'
          '    %| (dec %43)'
          '++ result ^- [@ud @ud @u @t @tas @]'
          '  [(choose %&) (choose %|) %1.000 %add %add %1.000]'
      ==
    [42 42 1.000 %add %add 1.000]
  =.  needs.term-literals  ~[%native %match]
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
  =/  projection-reversal=fixture
    %^  value-case  %projection-reversal
      %-  text
      :~  '++ source'
          '  ~& "project-source"'
          '    [a=1 b=2 c=3]'
          '++ result ^- [c=@ud b=@ud a=@ud] (proj (source))'
      ==
    [3 2 1]
  =.  traces.projection-reversal  `~['project-source']
  =.  needs.projection-reversal  ~[%projection]
  =/  projection-nested=fixture
    %^  value-case  %projection-nested-subset-reorder
      '++ result |= x=[a=@ud inner=[left=@ud right=@ud] b=@ud] ^- [inner=[left=@ud right=@ud] a=@ud] (proj x)\0a++ answer (result [a=1 inner=[left=2 right=3] b=4])\0a'
    [2 3]
  =.  entry.projection-nested  %answer
  =.  expected.projection-nested  [%ok [[2 3] 1]]
  =.  needs.projection-nested  ~[%projection]
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
  ::  Two or more atom cases beside a cell case each test their literal.
  =/  two-atoms=fixture
    %^  value-case  %two-atom-cases
      %-  text
      :~  '+$ msg'
          '  %inc'
          '  %dec'
          '  [%set to=@ud]'
          '++ step |= [m=msg n=@ud]'
          '  ?- m'
          '  %inc (add n 1)'
          '  %dec (dec n)'
          '  [%set v] v'
          '++ result [(step %inc 5) (step %dec 5) (step [%set 9] 5)]'
      ==
    [6 4 9]
  =.  needs.two-atoms  ~[%native %match]
  =/  atoms-wild=fixture
    %^  value-case  %atom-cases-and-wildcard
      %-  text
      :~  '+$ key'
          '  %up'
          '  %down'
          '  %left'
          '  [%char c=@t]'
          '++ dir |= k=key ^- @ud'
          '  ?- k'
          '  %up 1'
          '  [%char c] 4'
          '  %down 2'
          '  * 0'
          '++ result [(dir %up) (dir %down) (dir %left) (dir [%char "x"])]'
      ==
    [1 2 0 4]
  =.  needs.atoms-wild  ~[%match]
  =/  columns=fixture
    %^  value-case  %multi-column-atom-cases
      %-  text
      :~  '+$ msg'
          '  %inc'
          '  %dec'
          '  [%set to=@ud]'
          '++ pick |= [m=msg on=?] ^- @ud'
          '  ?- [m on]'
          '  [%inc %.y] 1'
          '  [%dec %.y] 2'
          '  [[%set v] %.y] v'
          '  [* %.n] 0'
          '++ result [(pick %inc %.y) (pick %dec %.y) (pick [%set 9] %.y) (pick %dec %.n) (pick [%set 9] %.n)]'
      ==
    [1 2 9 0 0]
  =.  needs.columns  ~[%match]
  ::  An arm binds its own pattern's names only, never those of a match or
  ::  gate in its body: an atom arm has no fields to take apart.
  =/  nested-arm=fixture
    %^  value-case  %atom-arm-nested-match
      %-  text
      :~  '+$ act'
          '  %reset'
          '  [%set to=@ud]'
          '++ apply |= [a=act xs=(list @ud)] ^- @ud'
          '  ?- a'
          '  %reset'
          '    ?- xs'
          '    ~ 0'
          '    [first rest] first'
          '  [%set to] to'
          '++ result [(apply %reset ~[3 4]) (apply %reset ~) (apply [%set 7] ~[1])]'
      ==
    [3 0 7]
  =.  needs.nested-arm  ~[%match]
  =/  gate-arm=fixture
    %^  value-case  %atom-arm-gate
      %-  text
      :~  '+$ act'
          '  %reset'
          '  [%set to=@ud]'
          '++ bump |= [a=act xs=(list @ud)] ^- (list @ud)'
          '  ?- a'
          '  %reset (turn xs |=(k=@ud (add k 1)))'
          '  [%set to] xs'
          '++ result [(bump %reset ~[1 2]) (bump [%set 0] ~[5])]'
      ==
    [[2 3 0] [5 0]]
  =.  needs.gate-arm  ~[%native %match]
  ::  The prelude's scag has this shape: a loobean test, whose arms bind
  ::  nothing, around a match that binds.
  =/  loobean-arm=fixture
    %^  value-case  %loobean-arm-nested-match
      %-  text
      :~  '++ take |= args=[@ud (list @ud)] ^- (list @ud)'
          '  ?- args'
          '  [count xs]'
          '    ?- (eq count 0)'
          '    %.y ~'
          '    %.n'
          '      ?- xs'
          '      ~ ~'
          '      [item rest] [item (take (dec count) rest)]'
          '++ result [(take 2 ~[7 8 9]) (take 5 ~[1]) (take 0 ~[1])]'
      ==
    [[7 8 0] [1 0] 0]
  =.  needs.loobean-arm  ~[%native %match]
  =/  arithmetic-natives=fixture
    %^  value-case  %arithmetic-natives
      '++ result [(sub 10 3) (mul 6 7) (dvr 17 5) (div 17 5) (mod 17 5) (pow 2 10) (pow 0 0) (div 4 9) (mod 4 9) (sub 9 9)]\0a'
    [7 42 [3 2] 3 2 1.024 1 0 4 0]
  =.  needs.arithmetic-natives  ~[%native]
  :~  literals
      term-literals
      data
      arithmetic
      closure
      local-rec
      mutual
      record
      projection-reversal
      projection-nested
      constructors
      collection-match
      callback
      traced
      imported
      lazy-match
      two-atoms
      atoms-wild
      columns
      nested-arm
      gate-arm
      loobean-arm
      arithmetic-natives
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
      :*  %native-div-zero-crash  %result
          '++ result (div 1 0)\0a'
          ~  ~  [%crash ~]  ~  ~[%native]
      ==
      :*  %native-mod-zero-crash  %result
          '++ result (mod 1 0)\0a'
          ~  ~  [%crash ~]  ~  ~[%native]
      ==
      :*  %native-dvr-zero-crash  %result
          '++ result (dvr 0 0)\0a'
          ~  ~  [%crash ~]  ~  ~[%native]
      ==
  ==
::
::  Programs linked against the checked prelude for lowering, with native
::  identities from its authenticated table only: the prelude's own scag,
::  slag, oust, swag, snap and into link and run, and checked arithmetic
::  calls are natives, not the prelude's unary recursion.
++  prelude-for-lowering
  ^-  (unit iprelude-lowering:jibb)
  %:  prepare-prelude-with-group-evidence-for-lowering:jibb
    prelude
    internal
    ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]]
    (bundle:jibb-prelude-fixture ~)
    evidence:jibb-prelude-fixture
  ==
::
++  core-natives
  |=  e=expr:jibb-core
  ^-  (list name:jibb-core)
  ?-  -.e
    ?(%lit %var %crash)  ~
    %native  ~[name.e]
    %cons    (weld $(e hed.e) $(e tal.e))
    %slot    $(e body.e)
    %edit    (weld $(e body.e) $(e value.e))
    %cell    $(e body.e)
    %eq      (weld $(e left.e) $(e right.e))
    %if      :(weld $(e test.e) $(e yes.e) $(e no.e))
    %let     (weld $(e value.e) $(e body.e))
    %rec
      =/  in-arms=(list name:jibb-core)
        %-  zing
        (turn arms.e |=(a=rec-arm:jibb-core ^$(e fun.a)))
      (weld in-arms $(e body.e))
    %lam     $(e body.e)
    %app     (weld $(e fun.e) $(e sample.e))
    %trace   (weld $(e message.e) $(e body.e))
  ==
::
+$  prelude-case
  [label=term source=@t expected=outcome:jibb-core natives=(list term)]
::
::  The names a linked program binds: its definitions and locals.
++  core-binders
  |=  e=expr:jibb-core
  ^-  (list name:jibb-core)
  ?-  -.e
    ?(%lit %var %native %crash)  ~
    %cons    (weld $(e hed.e) $(e tal.e))
    %slot    $(e body.e)
    %edit    (weld $(e body.e) $(e value.e))
    %cell    $(e body.e)
    %eq      (weld $(e left.e) $(e right.e))
    %if      :(weld $(e test.e) $(e yes.e) $(e no.e))
    %let     [name.e (weld $(e value.e) $(e body.e))]
    %rec
      =/  in-arms=(list name:jibb-core)
        %-  zing
        (turn arms.e |=(a=rec-arm:jibb-core [name.a ^$(e fun.a)]))
      (weld in-arms $(e body.e))
    %lam     [sample.e $(e body.e)]
    %app     (weld $(e fun.e) $(e sample.e))
    %trace   (weld $(e message.e) $(e body.e))
  ==
::
::  Every checked call of the prelude's arithmetic, from another module or
::  from the prelude itself, is its native: no linked program contains the
::  unary source of one.
++  unary-arithmetic
  ^-  (list name:jibb-core)
  %+  turn  `(list term)`~[%sub %mul %dvr %div %mod %pow]
  |=(n=term [%qualified /lib/jibb/prelude n])
::
++  run-prelude-case
  |=  [c=prelude-case prepared=iprelude-lowering:jibb]
  ^-  (unit @t)
  =/  at=path  (weld /tests/lower-differential ~[label.c %jibb])
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb at source.c ~ ~ ~ ~[at] ~ prepared)
  ?:  ?=(%| -.built)
    `(rap 3 ~[label.c ': full check failed: ' message.p.built])
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %result root.p.built cache.p.built)
  ?:  ?=(%| -.linked)
    `(rap 3 ~[label.c ': linking failed: ' p.linked])
  =/  bound=(list name:jibb-core)  (core-binders p.linked)
  =/  unary=(list name:jibb-core)
    (skim unary-arithmetic |=(n=name:jibb-core (lien bound |=(b=name:jibb-core =(b n)))))
  ?^  unary
    `(rap 3 ~[label.c ': the linked program contains the unary ' (print-name:jibb-core i.unary)])
  =/  used=(list name:jibb-core)  (core-natives p.linked)
  =/  absent=(list term)
    (skip natives.c |=(n=term (lien used |=(u=name:jibb-core =(u [%own n])))))
  ?^  absent
    `(rap 3 ~[label.c ': a checked call did not lower to the native ' i.absent])
  =/  unknown=(list name:jibb-core)
    (skip used |=(u=name:jibb-core (~(has by reference-registry) u)))
  ?^  unknown
    `(rap 3 ~[label.c ': no test registry has the native ' (print-name:jibb-core i.unknown)])
  =/  reference=execution:jibb-core  (reference-execution p.linked ~)
  ?.  =(expected.c out.reference)
    `(rap 3 ~[label.c ': reference result differs from source-level expectation'])
  =/  nock=outcome:jibb-core  (run-nock p.linked ~)
  ?.  =(expected.c nock)
    `(rap 3 ~[label.c ': Nock result differs from source-level expectation'])
  ~
::
++  prelude-cases
  ^-  (list prelude-case)
  :~  :*  %prelude-list-edits
          %-  text
          :~  '++ items ^- (list @ud) ~[10 11 12 13 14]'
              '++ taken (scag 2 items)'
              '++ dropped (slag 3 items)'
              '++ ousted (oust [1 2] items)'
              '++ swagged (swag [1 3] items)'
              '++ snapped (snap items 1 99)'
              '++ inserted (into items 1 99)'
              '++ result [taken dropped ousted swagged snapped inserted (scag 9 items) (slag 9 items) (snap items 9 7)]'
          ==
          :-  %ok
          :*  [10 11 0]  [13 14 0]  [10 13 14 0]  [11 12 13 0]
              [10 99 12 13 14 0]  [10 99 11 12 13 14 0]  [10 11 12 13 14 0]  0
              [10 11 12 13 14 7 0]
          ==
          ~
      ==
      :*  %prelude-arithmetic-natives
          %-  text
          :~  '++ split (dvr 1.000.000.007 1.000)'
              '++ day (sub ~2026.1.2 ~2026.1.1)'
              '++ result [(sub 10.000.000 1) (mul 100.000 100.000) split (div 1.000.000.007 1.000) (mod 1.000.000.007 1.000) (pow 2 200) day]'
          ==
          :-  %ok
          :*  9.999.999  10.000.000.000  [1.000.000 7]  1.000.000  7  (pow 2 200)
              (mul 86.400 (bex 64))
          ==
          ~[%sub %mul %dvr %div %mod %pow]
      ==
      ::  sqt calls the prelude's own lth, add, div, lte, mul and sub. On a
      ::  101-bit value the first round of its binary search alone would
      ::  take about 2^99 unary steps, for the div through dvr's repeated
      ::  subtraction and again for (mul middle middle); natively the whole
      ::  search is about a hundred rounds.
      :*  %prelude-sqt-natives
          %-  text
          :~  '++ big (sqt 1.267.650.600.228.229.401.496.703.217.721)'
              '++ square (sqt 1.000.000.000.000.000.000.000.000.000.000)'
              '++ result [p.big q.big p.square q.square]'
          ==
          [%ok [(bex 50) 12.345 (pow 10 15) 0]]
          ~[%sub %mul %div %add %gth]
      ==
      [%prelude-sub-underflow '++ result (sub 0 1)\0a' [%crash ~] ~[%sub]]
      [%prelude-div-zero '++ result (div 7 0)\0a' [%crash ~] ~[%div]]
      [%prelude-mod-zero '++ result (mod 7 0)\0a' [%crash ~] ~[%mod]]
      [%prelude-dvr-zero '++ result (dvr 7 0)\0a' [%crash ~] ~[%dvr]]
  ==
::
++  test-lower-differential-prelude
  ^-  tang
  =/  prepared=(unit iprelude-lowering:jibb)  prelude-for-lowering
  ?~  prepared  ~[leaf+"the real prelude did not prepare for lowering"]
  =/  cases=(list prelude-case)  prelude-cases
  =|  bad=(list @t)
  |-
  ?~  cases  (turn (flop bad) |=(reason=@t leaf+(trip reason)))
  =/  one=(unit @t)  (run-prelude-case i.cases u.prepared)
  $(cases t.cases, bad ?~(one bad [u.one bad]))
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
  ?.  =(31 (lent fixtures))  ~[leaf+"differential fixture inventory changed"]
  =/  bad=(list @t)  (run-fixtures fixtures p.prepared)
  (turn bad |=(reason=@t leaf+(trip reason)))
--
