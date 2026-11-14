::  Real Hoon marks -> checked API/client -> Core receivers on both backends.
::  The pinned linked Core is also executed by js/test/recursive-facts.test.mjs.
/+  jibb, jibb-import, jibb-core, jibb-lower, jibb-nock, jibb-nock-trace, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  tree-mark  %txt  /tests/type-recursive-facts/tree-mark/txt
/*  tree-diff-mark  %txt  /tests/type-recursive-facts/tree-diff-mark/txt
/*  queue-mark  %txt  /tests/type-recursive-facts/queue-mark/txt
/*  api  %txt  /tests/type-recursive-facts/api/txt
/*  client  %txt  /tests/type-recursive-facts/client/txt
/*  expected  %txt  /tests/type-recursive-facts/core/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (of-wain:format lines)
::
++  readers
  ^-  imark-externals:jibb
  =/  tree=type  -:(ride -:!>(..zuse) (text tree-mark))
  =/  diff=type  -:(ride -:!>(..zuse) (text tree-diff-mark))
  :~  [%tree-state (read-mark:jibb-import %tree-state tree)]
      [%tree-diff (read-mark:jibb-import %tree-diff diff)]
  ==
::
++  linked
  ^-  (each expr:jibb-core @t)
  =/  prepared=(unit iprelude-lowering:jibb)
    (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
  ?~  prepared  [%| 'recursive facts prelude did not prepare']
  =/  at=path  /tests/recursive-facts/jibb
  =/  built=jlowering-result:jibb
    %:  check-jibb-file-for-lowering-prepared:jibb
      at  (text client)  ~  readers
      ~[[/ui/api/recursive/jibb (text api)]]  ~[at]  ~  u.prepared
    ==
  ?:  ?=(%| -.built)  [%| message.p.built]
  (link-entry:jibb-lower %request root.p.built cache.p.built)
::
++  unsupported-request
  ^-  (each expr:jibb-core @t)
  =/  prepared=(unit iprelude-lowering:jibb)
    (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
  ?~  prepared  [%| 'queue prelude did not prepare']
  =/  mark=type  -:(ride -:!>(..zuse) (text queue-mark))
  =/  marks=imark-externals:jibb
    ~[[%queue-state (read-mark:jibb-import %queue-state mark)]]
  =/  source=@t  '/% %queue-state\0a+$ paths\0a  [%queue /queue queue-state]\0a'
  =/  at=path  /tests/unsupported-facts/jibb
  =/  built=jlowering-result:jibb
    %:  check-jibb-file-for-lowering-prepared:jibb
      at  '/= api /ui/api/queue\0a++ request queue.api\0a'  ~  marks
      ~[[/ui/api/queue/jibb source]]  ~[at]  ~  u.prepared
    ==
  ::  A reader/checker rejection is not the lowering error this control tests.
  ?:  ?=(%| -.built)  [%| (cat 3 'full check failed: ' message.p.built)]
  (link-entry:jibb-lower %request root.p.built cache.p.built)
::
++  test-unsupported-fact-source-diagnostic
  ^-  tang
  =/  made=(each expr:jibb-core @t)  unsupported-request
  ?:  ?=(%& -.made)  ~[leaf+"unsupported queue fact acquired a validator"]
  =/  wanted=@t
    %-  of-wain:format
    :~  'derived request queue: a fact of type (qeu @ud) cannot be checked yet: only lists, units, sets and maps are checked'
        '/ui/api/queue.jibb:3:3: fact validator for this request'
        '  [%queue /queue queue-state]'
        '  ^'
    ==
  ?.  =(wanted p.made)
    ~[leaf+"unsupported fact lost its complete source diagnostic" leaf+"expected:" leaf+(trip wanted) leaf+"actual:" leaf+(trip p.made)]
  ~
::
++  report
  ^-  @t
  =/  made=(each expr:jibb-core @t)  linked
  ?:  ?=(%| -.made)  (cat 3 'FAIL ' p.made)
  (print-expr:jibb-core p.made)
::
++  test-checked-recursive-receivers
  ^-  tang
  =/  made=(each expr:jibb-core @t)  linked
  ?:  ?=(%| -.made)  ~[leaf+(trip p.made)]
  ?.  =((text expected) (print-expr:jibb-core p.made))
    ~[leaf+"checked recursive receiver Core changed" leaf+(trip (print-expr:jibb-core p.made))]
  ~
::
++  literal
  |=  value=*
  ^-  expr:jibb-core
  ?@  value  [%lit [%ud value (scot %ud value)]]
  [%cons $(value -.value) $(value +.value)]
::
++  trace-text
  |=  message=@t
  ^-  expr:jibb-core
  [%lit [%t message message]]
::
++  receive
  |=  [request-gate=expr:jibb-core mark=term state=(unit *) fact=*]
  ^-  expr:jibb-core
  =/  reply=expr:jibb-core
    [%lam [%own %answer] [%trace (trace-text 'reply') [%cons (literal %got) [%var [%own %answer]]]]]
  =/  previous=expr:jibb-core  (literal ?~(state 0 u.state))
  =/  fold=expr:jibb-core
    [%lam [%own %change] [%trace (trace-text 'fold') [%if [%eq [%slot 3 [%var [%own %change]]] previous] [%slot 10 [%var [%own %change]]] [%crash ~]]]]
  =/  request=expr:jibb-core  [%app request-gate [%cons reply fold]]
  [%app [%slot 127 request] (literal [mark state fact])]
::
+$  fact-case
  [label=@t mark=term state=(unit *) fact=* expected=outcome:jibb-core traces=(list @t)]
::
++  good
  |=  [label=@t mark=term state=(unit *) fact=*]
  ^-  fact-case
  =/  next=*  ?~(state fact ?@(fact !! -.fact))
  [label mark state fact [%ok [next [%got next]]] ?~(state ~['reply'] ~['fold' 'reply'])]
::
++  bad
  |=  [label=@t mark=term state=(unit *) fact=*]
  ^-  fact-case
  [label mark state fact [%crash ~] ~]
::
++  deep-tree
  |=  [count=@ud leaf=*]
  ^-  *
  ?:  =(0 count)  leaf
  $(count (dec count), leaf [%branch ~[leaf]])
::
++  cases
  ^-  (list fact-case)
  =/  branch=*  [%branch ~[[%leaf & 7] [%branch ~[[%leaf | 9]]]]]
  =/  tree=*  [~[branch] 42]
  :~  (good 'tree leaf' %tree-state ~ [~[[%leaf & 7]] 1])
      (good 'tree nested full' %tree-state ~ tree)
      (good 'tree nested diff' %tree-diff `[~[[%leaf & 1]] 0] [tree 7])
      (good 'tree empty children' %tree-diff `tree [[~[[%branch ~]] 2] 8])
      (good 'tree empty roots' %tree-state ~ [~ 3])
      (bad 'tree unknown root tag' %tree-state ~ [~[[%unknown ~]] 0])
      (bad 'tree root atom' %tree-state ~ %leaf)
      (bad 'tree nested unknown tag' %tree-state ~ [~[[%branch ~[[%wrong & 1]]]] 0])
      (bad 'tree nested boolean' %tree-state ~ [~[[%branch ~[[%leaf 2 1]]]] 0])
      (bad 'tree nested atom field' %tree-state ~ [~[[%branch ~[[%leaf & [1 2]]]]] 0])
      (bad 'tree improper children' %tree-state ~ [~[[%branch [[%leaf & 1] 42]]] 0])
      (bad 'tree malformed diff' %tree-diff `tree [[~[[%branch ~[[%leaf 2 1]]]] 0] 7])
      (bad 'tree unknown diff mark' %unknown `tree [tree 7])
      (bad 'tree improper roots' %tree-state ~ [[branch 42] 0])
      (bad 'tree invalid stamp' %tree-state ~ [~[branch] [1 2]])
      (bad 'tree valid sibling then invalid' %tree-state ~ [~[branch [%leaf 2 1]] 0])
      (bad 'tree full shape is not a diff' %tree-diff `tree tree)
      (bad 'tree diff shape is not full state' %tree-state ~ [tree 7])
      (bad 'tree invalid diff nonce' %tree-diff `tree [tree [1 2]])
      (good 'tree deep full state' %tree-state ~ [~[(deep-tree 192 [%leaf & 7])] 0])
      (bad 'tree deep malformed leaf' %tree-state ~ [~[(deep-tree 192 [%leaf 2 7])] 0])
      (good 'tree valid after malformed' %tree-diff `tree [[~[[%leaf | 8]] 99] 9])
  ==
::
++  test-recursive-fact-outcomes
  ^-  tang
  =/  made=(each expr:jibb-core @t)  linked
  ?:  ?=(%| -.made)  ~[leaf+(trip p.made)]
  =/  remaining=(list fact-case)  cases
  |-
  ?~  remaining  ~
  =/  c=fact-case  i.remaining
  =/  program=expr:jibb-core  (receive p.made mark.c state.c fact.c)
  =/  reference=execution:jibb-core
    (run-traced:jibb-core program *(map name:jibb-core native:jibb-core))
  ?.  =(expected.c out.reference)
    ~[leaf+(trip label.c) leaf+"reference outcome differs" (sell !>(reference))]
  ?.  =(traces.c traces.reference)
    ~[leaf+(trip label.c) leaf+"reference callback order differs" (sell !>(reference))]
  =/  nock=outcome:jibb-core
    (run:jibb-nock program *(map name:jibb-core noun))
  ?.  =(expected.c nock)
    ~[leaf+(trip label.c) leaf+"Nock outcome differs" (sell !>(nock))]
  =/  traced=execution:jibb-core
    (run-traced:jibb-nock-trace program *(map name:jibb-core noun))
  ?.  =(nock out.traced)
    ~[leaf+(trip label.c) leaf+"traced Nock outcome differs from actual execution" (sell !>(traced))]
  ?.  =(traces.c traces.traced)
    ~[leaf+(trip label.c) leaf+"Nock invoked callbacks before validation or in the wrong order" (sell !>(traced))]
  $(remaining t.remaining)
--
