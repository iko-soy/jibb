::  Checked Jibb recursive molds validate untrusted nouns on both backends.
/+  jibb, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
+$  fact-case  [label=@t fact=* accepts=?]
::
++  literal
  |=  value=*
  ^-  expr:jibb-core
  ?@  value  [%lit [%ud value (scot %ud value)]]
  [%cons $(value -.value) $(value +.value)]
::
++  validate
  |=  typ=itype:jibb
  ^-  lowered:jibb-lower
  (check-noun:jibb-lower typ [%var [%own %incoming]] [*checked-module:jibb 1 |])
::
++  check-cases
  |=  [typ=itype:jibb cases=(list fact-case)]
  ^-  tang
  =/  made=lowered:jibb-lower  (validate typ)
  ?:  ?=(%| -.made)  ~[leaf+(trip p.made)]
  =/  validator=expr:jibb-core  [%lam [%own %incoming] value.p.made]
  |-
  ?~  cases  ~
  =/  c=fact-case  i.cases
  =/  program=expr:jibb-core  [%app validator (literal fact.c)]
  =/  expected=outcome:jibb-core  ?:(accepts.c [%ok 0] [%crash ~])
  =/  reference=execution:jibb-core
    (run-traced:jibb-core program *(map name:jibb-core native:jibb-core))
  ?.  =(expected out.reference)
    ~[leaf+(trip label.c) leaf+"reference validator outcome differs" (sell !>(reference))]
  ?^  traces.reference
    ~[leaf+(trip label.c) leaf+"validator emitted a trace" (sell !>(reference))]
  =/  nock=outcome:jibb-core
    (run:jibb-nock program *(map name:jibb-core noun))
  ?.  =(expected nock)
    ~[leaf+(trip label.c) leaf+"Nock validator outcome differs" (sell !>(nock))]
  $(cases t.cases)
::
++  source
  ^-  @t
  %-  of-wain:format
  :~  '/= foreign /tests/fact-validation-other'
      '+$ fact-foreign-tree fact-tree.foreign'
      '+$ fact-tree |$ [A]'
      '  %done'
      '  [%leaf value=A]'
      '  [%node kids=(list (fact-tree A))]'
      '+$ fact-left'
      '  %stop'
      '  [%next peer=(unit fact-right)]'
      '+$ fact-right'
      '  %end'
      '  [%back peer=(unit fact-left)]'
      '+$ fact-choice'
      '  %stop'
      '  [%node side=%left value=? rest=fact-choice]'
      '  [%node side=%right value=@ud rest=fact-choice]'
      '+$ fact-forest (map @t (fact-tree ?))'
      '+$ fact-nested'
      '  %done'
      '  [%node kids=(list (unit fact-nested))]'
      '+$ fact-empty-loop [next=fact-empty-loop value=@t]'
      '+$ fact-zig |$ [A B]'
      '  %done'
      '  [%leaf value=A]'
      '  [%next rest=(fact-zig B A)]'
      '+$ fact-grow |$ [A]'
      '  %done'
      '  [%leaf value=A]'
      '  [%next rest=(fact-grow (list A))]'
  ==
::
++  foreign-source
  ^-  @t
  %-  of-wain:format
  :~  '+$ fact-tree'
      '  %done'
      '  [%leaf value=?]'
      '  [%node kids=(list fact-tree)]'
  ==
::
++  mold
  |=  [iface=ifile:jibb name=term args=(list itype:jibb)]
  ^-  (unit itype:jibb)
  =/  found=(unit ischeme:jibb)  (find-jibb-mold:jibb name iface)
  ?~  found  ~
  (template-apply:jibb u.found args)
::
++  deep-choice
  |=  [count=@ud tail=*]
  ^-  *
  ?:  =(0 count)  tail
  $(count (dec count), tail [%node %left & tail])
::
++  test-checked-recursive-fact-validation
  ^-  tang
  =/  prep=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"fact validator prelude did not prepare"]
  =/  at=path  /tests/fact-validation/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~[[/tests/fact-validation-other/jibb foreign-source]] ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  tree=(unit itype:jibb)  (mold iface.p.checked %fact-tree ~[[%atom %ud]])
  =/  flags=(unit itype:jibb)  (mold iface.p.checked %fact-tree ~[[%flag ~]])
  =/  mutual=(unit itype:jibb)  (mold iface.p.checked %fact-left ~)
  =/  choice=(unit itype:jibb)  (mold iface.p.checked %fact-choice ~)
  =/  forest=(unit itype:jibb)  (mold iface.p.checked %fact-forest ~)
  =/  nested=(unit itype:jibb)  (mold iface.p.checked %fact-nested ~)
  =/  empty=(unit itype:jibb)  (mold iface.p.checked %fact-empty-loop ~)
  =/  foreign=(unit itype:jibb)  (mold iface.p.checked %fact-foreign-tree ~)
  =/  zig=(unit itype:jibb)  (mold iface.p.checked %fact-zig ~[[%flag ~] [%atom %ud]])
  =/  grow=(unit itype:jibb)  (mold iface.p.checked %fact-grow ~[[%atom %ud]])
  ?~  tree  ~[leaf+"generic tree mold missing"]
  ?~  flags  ~[leaf+"generic flag tree mold missing"]
  ?~  mutual  ~[leaf+"mutual mold missing"]
  ?~  choice  ~[leaf+"same-head union mold missing"]
  ?~  forest  ~[leaf+"recursive map mold missing"]
  ?~  nested  ~[leaf+"nested collection mold missing"]
  ?~  empty  ~[leaf+"empty recursive mold missing"]
  ?~  foreign  ~[leaf+"foreign recursive mold missing"]
  ?~  zig  ~[leaf+"alternating recursive mold missing"]
  ?~  grow  ~[leaf+"growing recursive mold missing"]
  ?.  (levy `(list itype:jibb)`~[u.tree u.flags u.mutual u.choice u.nested u.empty u.foreign u.zig u.grow] |=(t=itype:jibb ?=(%mrec -.t)))
    ~[leaf+"full checker did not retain recursive graph types"]
  ?.  ?=([%collection %map [* [%mrec *] ~]] u.forest)
    ~[leaf+"full checker did not retain a map containing recursive values"]
  =/  a=tang
    %+  check-cases  u.tree
    :~  ['generic base' %done &]
        ['generic leaf' [%leaf 42] &]
        ['generic nested children' [%node ~[[%leaf 7] [%node ~[[%leaf 8] %done]]]] &]
        ['generic empty children' [%node ~] &]
        ['unknown recursive tag' [%wrong 42] |]
        ['recursive root shape' %leaf |]
        ['generic leaf cell' [%leaf [1 2]] |]
        ['improper recursive list' [%node [[%leaf 7] 42]] |]
        ['nested unknown tag' [%node ~[[%node ~[[%wrong 7]]]]] |]
    ==
  ?^  a  a
  =/  b=tang
    %+  check-cases  [%cell u.tree u.flags]
    :~  ['distinct generic instances' [[%leaf 2] [%leaf &]] &]
        ['recursive generic instances' [[%node ~[[%leaf 2]]] [%node ~[[%leaf |]]]] &]
        ['generic argument cannot reuse atom validator' [[%leaf 2] [%leaf 2]] |]
        ['nested generic argument cannot reuse atom validator' [[%leaf 2] [%node ~[[%leaf 2]]]] |]
    ==
  ?^  b  b
  =/  c=tang
    %+  check-cases  u.mutual
    :~  ['mutual base' %stop &]
        ['mutual empty unit' [%next ~] &]
        ['mutual nested' [%next `[%back `[%next `%end]]] &]
        ['mutual wrong node' [%next `[%next ~]] |]
        ['mutual malformed unit' [%next [1 %end]] |]
        ['mutual wrong base' [%next `%stop] |]
    ==
  ?^  c  c
  =/  d=tang
    %+  check-cases  u.choice
    :~  ['same-head left case' [%node %left & %stop] &]
        ['same-head right case' [%node %right 2 %stop] &]
        ['same-head mixed recursion' [%node %left | [%node %right 7 %stop]] &]
        ['same-head left malformed value' [%node %left 2 %stop] |]
        ['same-head right malformed value' [%node %right [1 2] %stop] |]
        ['same-head unknown discriminator' [%node %other 0 %stop] |]
        ['same-head missing fields' [%node %left] |]
        ['deep recursive value' (deep-choice 192 %stop) &]
        ['deep malformed leaf' (deep-choice 192 [%node %left 2 %stop]) |]
    ==
  ?^  d  d
  =/  by-name=*  [[%oak [%node ~[[%leaf &]]]] ~ ~]
  =/  e=tang
    %+  check-cases  u.forest
    :~  ['recursive empty map' ~ &]
        ['recursive map' by-name &]
        ['recursive map malformed value' [[%oak [%leaf 2]] ~ ~] |]
        ['recursive map malformed key' [[[1 2] [%leaf &]] ~ ~] |]
        ['recursive map malformed child' [[%oak [%leaf &]] 42 ~] |]
    ==
  ?^  e  e
  =/  f=tang
    %+  check-cases  u.nested
    :~  ['nested list and units' [%node ~[~ `%done `[%node ~[`%done]]]] &]
        ['nested malformed unit tag' [%node ~[[1 %done]]] |]
        ['nested malformed inner list' [%node ~[`[%node 42]]] |]
    ==
  ?^  f  f
  =/  g=tang
    %+  check-cases  u.empty
    :~  ['empty domain atom' 0 |]
        ['empty domain finite cell' [[0 'x'] 'y'] |]
    ==
  ?^  g  g
  =/  h=tang
    %+  check-cases  [%cell u.tree u.foreign]
    :~  ['distinct source graph identities' [[%leaf 2] [%leaf &]] &]
        ['foreign graph cannot reuse same-name validator' [[%leaf 2] [%leaf 2]] |]
    ==
  ?^  h  h
  =/  j=tang
    %+  check-cases  u.zig
    :~  ['alternating first argument' [%leaf &] &]
        ['alternating second argument' [%next [%leaf 2]] &]
        ['alternating returns to first argument' [%next [%next [%leaf |]]] &]
        ['alternating invalid first argument' [%leaf 2] |]
        ['alternating invalid second argument' [%next [%leaf [1 2]]] |]
        ['alternating invalid returned argument' [%next [%next [%leaf 2]]] |]
    ==
  ?^  j  j
  ::  The full checker accepts changing arguments. Construction must remain
  ::  bounded even when no instantiated recursive type ever repeats.
  =/  bounded=fact-result:jibb-lower
    (fact-check:jibb-lower u.grow [%var [%own %incoming]] [[*checked-module:jibb 1 |] ~ ~ 64 ~ ~ ~] ~ 0)
  ?:  ?=(%& -.bounded)  ~[leaf+"infinitely growing recursive validator escaped its construction budget"]
  =/  suffix=tape  " cannot be checked yet: validator construction exceeds its node budget"
  =/  error=tape  (trip p.bounded)
  ?.  &((gte (lent error) (lent suffix)) =((flop (scag (lent suffix) (flop error))) suffix))
    ~[leaf+"growing recursive validator did not fail at its construction budget" leaf+(trip p.bounded)]
  ~
::
++  test-set-fact-shapes
  ^-  tang
  ::  Set is an existing importer collection type, not a public Jibb mold.
  ::  Incoming-fact validation deliberately does not check tree ordering.
  %+  check-cases  [%collection %set ~[[%atom %ud]]]
  :~  ['empty set' ~ &]
      ['set node' [7 ~ ~] &]
      ['set ordering remains unchecked' [2 [7 ~ ~] ~] &]
      ['set malformed item' [[1 2] ~ ~] |]
      ['set malformed child' [7 ~ 42] |]
      ['set malformed root' 42 |]
  ==
::
++  rejected
  |=  [label=@t typ=itype:jibb reason=@t]
  ^-  tang
  =/  made=lowered:jibb-lower  (validate typ)
  ?:  ?=(%& -.made)  ~[leaf+(trip label) leaf+"unsupported fact type was accepted"]
  =/  expected=@t
    (crip "a fact of type {(show-itype:jibb typ ~)} cannot be checked yet: {(trip reason)}")
  ?.  =(expected p.made)
    ~[leaf+(trip label) leaf+"fact validator diagnostic differs" leaf+"expected:" leaf+(trip expected) leaf+"actual:" leaf+(trip p.made)]
  ~
::
++  test-invalid-fact-graphs-fail-closed
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  at=path  /tests/fact-validation/jibb
  =/  root=gkey:jibb  [at site %root]
  =/  child=gkey:jibb  [at site %child]
  =/  none=(map gkey:jibb gdef:jibb)  *(map gkey:jibb gdef:jibb)
  =/  missing=itype:jibb  [%mrec at site %root `'root' none ~]
  =/  a=tang  (rejected 'missing graph root' missing 'its recursive graph cannot be unfolded')
  ?^  a  a
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by none) root [site & ~['A'] ~ [%cell [%param 'A'] [%ref root ~[[%param 'A']]]]])
  =/  arity=itype:jibb  [%mrec at site %root `'root' graph ~]
  =/  b=tang  (rejected 'wrong graph arity' arity 'its recursive graph cannot be unfolded')
  ?^  b  b
  =/  stale=(map gkey:jibb gdef:jibb)
    (~(put by none) root [[[2 1] [2 2]] & ~ ~ [%atom %ud]])
  =/  c=tang  (rejected 'graph site mismatch' [%mrec at site %root `'root' stale ~] 'its recursive graph cannot be unfolded')
  ?^  c  c
  =/  dangling=(map gkey:jibb gdef:jibb)
    (~(put by none) root [site & ~ ~ [%cell [%atom %ud] [%ref child ~]]])
  =/  d=tang  (rejected 'missing graph child' [%mrec at site %root `'root' dangling ~] 'its recursive graph cannot be unfolded')
  ?^  d  d
  =/  alias=(map gkey:jibb gdef:jibb)
    (~(put by none) root [site & ~ ~ [%ref root ~]])
  =/  e=tang  (rejected 'same-noun alias cycle' [%mrec at site %root `'root' alias ~] 'recursive validation does not descend through a cell')
  ?^  e  e
  ::  A cell outside this inner cycle must not justify its own back edge.
  =/  inner=(map gkey:jibb gdef:jibb)
    (~(put by none) child [site & ~ ~ [%ref child ~]])
  =.  inner
    (~(put by inner) root [site & ~ ~ [%union ~[[%atom %ud] [%cell [%ref child ~] [%ref root ~]]]]])
  =/  nested=itype:jibb  [%mrec at site %root `'root' inner ~]
  =/  got=lowered:jibb-lower  (validate nested)
  ?:  ?=(%& -.got)  ~[leaf+"productive outer graph hid an unguarded inner cycle"]
  =/  expected=@t  'a fact of type child cannot be checked yet: recursive validation does not descend through a cell'
  ?.  =(expected p.got)
    ~[leaf+"inner-cycle diagnostic differs" leaf+"expected:" leaf+(trip expected) leaf+"actual:" leaf+(trip p.got)]
  ::  The first alternative compiles child under a cell. The second reuses
  ::  that completed validator on the same noun and must still be rejected.
  =/  reused=(map gkey:jibb gdef:jibb)
    (~(put by none) child [site & ~ ~ [%ref root ~]])
  =.  reused
    (~(put by reused) root [site & ~ ~ [%union ~[[%cell [%atom %ud] [%ref child ~]] [%ref child ~]]]])
  =/  hidden=itype:jibb  [%mrec at site %root `'root' reused ~]
  =/  h=tang  (rejected 'completed validator hides an unguarded cycle' hidden 'recursive validation does not descend through a cell')
  ?^  h  h
  ~
::
++  test-unsupported-fact-types-fail-closed
  ^-  tang
  =/  closed=(list [label=@t typ=itype:jibb reason=@t])
    :~  ['open variable' [%var 0] 'its type is not closed']
        ['gate-free variable' [%fvar 0] 'its type is not closed']
        ['atom variable' [%avar 0] 'its type is not closed']
        ['aura variable' [%rvar 0] 'its type is not closed']
        ['numeric variable' [%nvar 0] 'its type is not closed']
        ['numeric aura variable' [%rnvar 0] 'its type is not closed']
        ['refined type' [%refined [%atom %ud]] 'its type is not closed']
        ['gate' [%fn [%atom %ud] [%atom %ud]] 'a gate cannot arrive in a fact']
        ['opaque' [%opaque [/tests/private/jibb %secret] `'secret' ~ [%atom %ud]] 'its representation is private']
        ['nested gate' [%collection %list ~[[%fn [%atom %ud] [%atom %ud]]]] 'a gate cannot arrive in a fact']
    ==
  |-
  ?~  closed  ~
  =/  c=[label=@t typ=itype:jibb reason=@t]  i.closed
  ::  A nested unsupported type is reported at that type, not its container.
  =/  displayed=itype:jibb
    ?.  ?=(%collection -.typ.c)  typ.c
    =/  args=(list itype:jibb)  args.typ.c
    ?>  ?=([* ~] args)
    i.args
  =/  made=lowered:jibb-lower  (validate typ.c)
  ?:  ?=(%& -.made)  ~[leaf+(trip label.c) leaf+"unsupported fact type was accepted"]
  =/  expected=@t
    (crip "a fact of type {(show-itype:jibb displayed ~)} cannot be checked yet: {(trip reason.c)}")
  ?.  =(expected p.made)
    ~[leaf+(trip label.c) leaf+"unsupported-type diagnostic differs" leaf+"expected:" leaf+(trip expected) leaf+"actual:" leaf+(trip p.made)]
  $(closed t.closed)
--
