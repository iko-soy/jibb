::  /lib/jibb-import.hoon: a partial reader of Hoon's type graph
::
::  +read-mold accepts one selected Hoon type and its module/name, rather
::  than loading a whole /sur. +read-mold-in also takes the originating
::  /sur core and verifies the selected arm; this provenance is required
::  to identify collections without mistaking a local shadow for one.
::  The caller selects only types actually used.
::  Hoon's %hold nodes retain the generator's Hoon and its bound arguments.
::  Comparing that Hoon to the standard generators identifies collections
::  before they expand into trees. Recursive holds are tracked by identity;
::  a repeated named hold becomes a module-qualified reference.
::
::  A direct $^ is read from its original branches and accepted only when
::  their imported shapes prove disjoint. A single nested $^ in a
::  static record is checked by splitting and reassembling its branches;
::  other nested forms and unprovably disjoint cases remain unsupported. Source-level overlap in
::  other unions, general nested ordered maps, broader Ford subject
::  shapes, ambiguous recursive origins and full error locations still
::  need work. A nested ordered map is recovered only when its key and
::  value are fixed atom molds and
::  the other fields are fixed atoms or collections of static atoms;
::  other source shapes fail closed.
::
::  The checker has a small bridge for successful unfaced atom and cell
::  results; it rejects other importer shapes. Failures return %|; no
::  partial tree is returned as success.
::
|%
+$  imported
  $~  [%noun ~]
  $%  [%noun ~]
      [%void ~]
      [%atom aura=term value=(unit @)]
      [%cell head=imported tail=imported]
      [%face name=term body=imported]
      [%fork cases=(list imported)]
      [%apply name=term args=(list imported)]
      [%ref module=term name=term]
      [%bad reason=@t]
  ==
+$  signatures  (list [name=term code=hoon])
+$  visiting    (list [typ=type name=(unit term)])
::
::  +code-of: the generator body, independent of its mold arguments.
::
++  code-of
  |=  text=@t
  ^-  hoon
  =/  typ=type  (~(play ut -:!>(..zuse)) (ream text))
  ?>  ?=([%hold *] typ)
  q.typ
::
++  catalog
  ^-  signatures
  :~  [%map (code-of '*(map @ud @ud)')]
      [%set (code-of '*(set @ud)')]
      [%qeu (code-of '*(qeu @ud)')]
      [%jar (code-of '*(jar @ud @ud)')]
      [%jug (code-of '*(jug @ud @ud)')]
      [%list (code-of '*(list @ud)')]
      [%unit (code-of '*(unit @ud)')]
      [%vase (code-of '*vase')]
  ==
::
++  read-mold
  |=  [module=term name=term typ=type]
  ^-  (each imported @t)
  (read-with module name typ ~)
::
::  +read-mold-in: accept the /sur core as provenance. The core must be
::  built against zuse or validated Ford imports, and its selected arm
::  must be this type. Unknown subject shapes fail closed.
++  read-mold-in
  |=  [module=term name=term typ=type cor=type]
  ^-  (each imported @t)
  ?.  ?=([%core *] cor)  [%| 'Hoon module provenance is unavailable']
  ?:  =(cor -:!>(..zuse))  [%| 'Hoon module provenance is unavailable']
  ?.  (scope-safe cor %$)  [%| 'Hoon module provenance is unavailable']
  =/  chapters=(map term tome)  q.r.q.cor
  ?.  (lien ~(tap by chapters) |=(entry=[term tome] =((chapter-has +.entry name) [~ &])))
    [%| (crip "Hoon mold `{(trip name)}` is not declared")]
  ?.  =(typ (~(play ut cor) (ream (cat 3 '*' name))))
    [%| 'Hoon module provenance does not match the selected mold']
  =/  result  (read-with module name typ [~ cor])
  ?.  ?=([%& *] result)  result
  result
::
::  +read-named is the source-aware entry point for callers that have
::  not selected a Hoon type yet. Check the core and the local arm
::  before invoking Hoon's type engine, which otherwise crashes when
::  the requested name is absent.
++  read-named
  |=  [module=term name=term cor=type]
  ^-  (each imported @t)
  ?.  ?=([%core *] cor)  [%| 'Hoon module provenance is unavailable']
  ?:  =(cor -:!>(..zuse))  [%| 'Hoon module provenance is unavailable']
  ?.  (scope-safe cor %$)  [%| 'Hoon module provenance is unavailable']
  =/  chapters=(map term tome)  q.r.q.cor
  ?.  (lien ~(tap by chapters) |=(entry=[term tome] =((chapter-has +.entry name) [~ &])))
    [%| (crip "Hoon mold `{(trip name)}` is not declared")]
  =/  attempted=(each type tang)
    (mule |.((~(play ut cor) (ream (cat 3 '*' name)))))
  ?-  attempted
    [%& *]  (read-mold-in module name p.attempted cor)
    [%| *]
      =/  lines=wall  (zing (turn (flop p.attempted) |=(a=tank (wash [0 80] a))))
      =/  rev=wall  (flop lines)
      ?~  rev  [%| (crip "Hoon mold `{(trip name)}` could not be evaluated")]
      [%| (crip "Hoon mold `{(trip name)}` could not be evaluated: {i.rev}")]
  ==
::
::  A mark door's payload is [sample build-subject]. Its outer sample
::  face names the door sample, not the imported mark type. Collection
::  lookup for the sample happened against the pre-door build subject.
++  read-mark
  |=  [name=term cor=type]
  ^-  (each imported @t)
  ?.  ?=([%core *] cor)  [%| 'Hoon mark provenance is unavailable']
  ?.  ?=([%cell *] p.cor)  [%| 'Hoon mark sample is unavailable']
  ?.  =(p.cor q.q.cor)  [%| 'Hoon mark provenance is unavailable']
  ?.  (scope-safe q.p.cor %$)  [%| 'Hoon mark provenance is unavailable']
  =/  sample=type  p.p.cor
  =/  raw=type  ?:(?=([%face *] sample) q.sample sample)
  =/  result  (read-with name name raw [~ q.p.cor])
  ?.  ?=([%& *] result)  result
  result
::
++  read-with
  |=  [module=term name=term typ=type context=(unit type)]
  ^-  (each imported @t)
  =/  out  (walk module typ catalog ~ context)
  =/  err  (first-bad out)
  ?~  err  [%& out]
  [%| u.err]
::
::  +hold-name: names supplied by Hoon's %made note survive on a hold.
::
++  hold-name
  |=  h=hoon
  ^-  (unit term)
  ?:  ?=([%tsls [%note [%made *] *] *] h)
    [~ p.p.p.h]
  ~
::
::  The named wrapper records an alias before Hoon reduces it to a map.
++  source-alias
  |=  body=hoon
  ^-  (unit term)
  ?.  ?=([%cncl *] body)  ~
  ?.  ?=([%tsgr *] p.body)  ~
  ?.  ?=([%cncl *] q.p.body)  ~
  ?.  ?=([%wing *] p.q.p.body)  ~
  =/  w=wing  p.p.q.p.body
  ?:  =(w ~[%jar])  [~ %jar]
  ?:  =(w ~[%jug])  [~ %jug]
  ?:  =(w ~[%map])  [~ %map]
  ?:  =(w ~[%set])  [~ %set]
  ?:  =(w ~[%qeu])  [~ %qeu]
  ?:  =(w ~[%list])  [~ %list]
  ?:  =(w ~[%unit])  [~ %unit]
  ~
::
++  hold-alias
  |=  h=hoon
  ^-  (unit term)
  ?.  ?=([%tsls [%note * *] *] h)  ~
  (source-alias q.p.h)
::
::  Reconcile source aliases with the expanded type in corresponding
::  cells and fields. Return an error unless every alias is accounted for.
++  recover-spec
  |=  [src=spec out=imported]
  ^-  (each imported @t)
  ?.  (has-hidden-alias src)  [%& out]
  ?.  ?=([%make [%wing *] *] src)
    [%| 'nested collection arguments need source-aware import']
  =/  w=wing  p.p.src
  =/  name=term
    ?:  =(w ~[%jar])  %jar
    ?:  =(w ~[%jug])  %jug
    ?:  =(w ~[%map])  %map
    ?:  =(w ~[%set])  %set
    ?:  =(w ~[%qeu])  %qeu
    ?:  =(w ~[%list])  %list
    ?:  =(w ~[%unit])  %unit
    %$
  ?:  =(%$ name)  [%| 'nested collection arguments need source-aware import']
  =/  original=(each imported @t)
    ?:  |(=(%jar name) =(%jug name))
      ?.  ?=([%apply %map [* [%apply * [* ~]] ~]] out)
        [%| 'nested collection arguments need source-aware import']
      =/  inn  i.args.i.t.args.out
      ?.  |(&(?=(%jar name) ?=(%list name.i.t.args.out)) &(?=(%jug name) ?=(%set name.i.t.args.out)))
        [%| 'nested collection arguments need source-aware import']
      [%& [%apply name ~[i.args.out inn]]]
    [%& out]
  ?.  ?=([%& *] original)  original
  =/  fixed=imported  p.original
  ?.  ?=([%apply *] fixed)  [%| 'nested collection arguments need source-aware import']
  ?.  =(name name.fixed)  [%| 'nested collection arguments need source-aware import']
  =/  args  (recover-specs q.src args.fixed)
  ?-  args
    [%| *]  args
    [%& *]  [%& [%apply name p.args]]
  ==
::
++  recover-specs
  |=  [src=(list spec) args=(list imported)]
  ^-  (each (list imported) @t)
  ?~  src  ?~(args [%& ~] [%| 'collection argument count mismatch'])
  ?~  args  [%| 'collection argument count mismatch']
  =/  first  (recover-spec i.src i.args)
  ?-  first
    [%| *]  [%| p.first]
    [%& *]
      =/  rest  $(src t.src, args t.args)
      ?-  rest
        [%| *]  rest
        [%& *]  [%& [p.first p.rest]]
      ==
  ==
::
++  recover-hoons
  |=  [src=(list hoon) args=(list imported)]
  ^-  (each (list imported) @t)
  ?~  src  ?~(args [%& ~] [%| 'collection argument count mismatch'])
  ?~  args  [%| 'collection argument count mismatch']
  =/  first=(each imported @t)
    ?.  (has-hidden-alias i.src)  [%& i.args]
    ?.  ?=([%ktcl *] i.src)  [%| 'nested collection arguments need source-aware import']
    (recover-spec p.i.src i.args)
  ?-  first
    [%| *]  [%| p.first]
    [%& *]
      =/  rest  $(src t.src, args t.args)
      ?-  rest
        [%| *]  rest
        [%& *]  [%& [p.first p.rest]]
      ==
  ==
::
::  Replace direct mop expressions in records with a simple placeholder;
::  recover-alias restores each from its original source specs afterward.
::  Other fields must be fixed atom molds or standard collections with
::  statically fixed atom arguments. A dependent mold could otherwise
::  change when a field changes. All collection names are checked below.
++  static-spec
  |=  shape=spec
  ^-  ?
  ?+  shape  |
    [%base *]  ?=([%atom *] p.shape)
    [%make *]
      ?.  ?=([%wing *] p.shape)  |
      =/  w=wing  p.p.shape
      ?.  |(=(w ~[%map]) =(w ~[%set]) =(w ~[%qeu]) =(w ~[%list]) =(w ~[%unit]) =(w ~[%jar]) =(w ~[%jug]))  |
      (levy q.shape |=(a=spec (static-spec a)))
  ==
::
++  static-arguments
  |=  args=(list hoon)
  ^-  ?
  ?~  args  &
  ?.  ?=([%ktcl *] i.args)  |
  ?.  (static-spec p.i.args)  |
  $(args t.args)
::
++  static-collection
  |=  src=hoon
  ^-  ?
  =/  alias  (source-alias src)
  ?~  alias  |
  ?>  ?=([%cncl *] src)
  ?>  ?=([%tsgr *] p.src)
  ?>  ?=([%cncl *] q.p.src)
  (static-arguments q.q.p.src)
::
++  patchable-mop-record
  |=  src=hoon
  ^-  ?
  ?^  -.src  &($(src -.src) $(src +.src))
  ?+  src  |
    [%note *]  $(src q.src)
    [%ktts *]  $(src q.src)
    [%ktls *]  ?=([%sand *] p.src)
    [%cncl *]
      =/  specs  (mop-specs src)
      ?~  specs  (static-collection src)
      &(?=([%base [%atom *]] key.u.specs) ?=([%base [%atom *]] value.u.specs))
  ==
::
++  patch-mops
  |=  src=hoon
  ^-  hoon
  ?^  -.src  [$(src -.src) $(src +.src)]
  ?+  src  src
    [%note *]  src(q $(src q.src))
    [%ktts *]  src(q $(src q.src))
    [%cncl *]  ?:  ?=(^ (mop-specs src))  (ream '*@t')
               src
  ==
::
++  recover-alias
  |=  [src=hoon out=imported subject=type module=term sig=signatures seen=visiting context=(unit type)]
  ^-  (each imported @t)
  ?.  (has-hidden-alias src)  [%& out]
  ?^  -.src
    ?.  ?=([%cell *] out)  [%| 'a nested collection alias needs source-aware import']
    =/  hed  $(src -.src, out head.out)
    ?-    hed
        [%| *]  hed
        [%& *]
      =/  tal  $(src +.src, out tail.out)
      ?-  tal
        [%| *]  tal
        [%& *]  [%& [%cell p.hed p.tal]]
      ==
    ==
  ?+  src  [%| 'a nested collection alias needs source-aware import']
    [%note *]  $(src q.src)
    [%ktts *]
      ?.  ?=([%face *] out)  [%| 'a nested collection alias needs source-aware import']
      ?.  =(p.src name.out)  [%| 'a nested collection alias needs source-aware import']
      =/  child  $(src q.src, out body.out)
      ?-  child
        [%| *]  child
        [%& *]  [%& [%face name.out p.child]]
      ==
    [%cncl *]
      =/  mop=(unit [key=spec value=spec])  (mop-specs src)
      ?^  mop
        =/  attempt=(each [type type] tang)
          (mule |.([(~(play ut subject) [%kttr key.u.mop]) (~(play ut subject) [%kttr value.u.mop])]))
        ?-  attempt
          [%| *]  [%| 'a nested Hoon mop needs source-aware import']
          [%& *]
            =/  key  (walk module -.p.attempt sig seen context)
            =/  val  (walk module +.p.attempt sig seen context)
            [%& [%apply %mop ~[key val]]]
        ==
      =/  alias  (source-alias src)
      ?~  alias  [%| 'a nested collection alias needs source-aware import']
      =/  original=(each imported @t)
        ?:  |(=(%jar u.alias) =(%jug u.alias))
          ?.  ?=([%apply %map [* [%apply * [* ~]] ~]] out)
            [%| 'a nested collection alias needs source-aware import']
          =/  inner  i.args.i.t.args.out
          ?.  |(&(?=(%jar u.alias) ?=(%list name.i.t.args.out)) &(?=(%jug u.alias) ?=(%set name.i.t.args.out)))
            [%| 'a nested collection alias needs source-aware import']
          [%& [%apply u.alias ~[i.args.out inner]]]
        [%& out]
      ?.  ?=([%& *] original)  original
      =/  fixed=imported  p.original
      ?.  ?=([%apply *] fixed)  [%| 'a nested collection alias needs source-aware import']
      ?.  =(name.fixed u.alias)  [%| 'a nested collection alias needs source-aware import']
      ?>  ?=([%tsgr *] p.src)
      ?>  ?=([%cncl *] q.p.src)
      =/  args  (recover-hoons q.q.p.src args.fixed)
      ?-  args
        [%| *]  [%| p.args]
        [%& *]  [%& [%apply u.alias p.args]]
      ==
  ==
::
++  has-hidden-alias
  |=  h=*
  ^-  ?
  ?:  |(=(h [%wing ~[%jar]]) =(h [%wing ~[%jug]]) =(h [%wing ~[%mop]]))  &
  ?@  h  |
  |($(h -.h) $(h +.h))
::
::  $^ is lowered to a conditional by Hoon's parser; conservatively
::  reject its distinctive test until the original branches have been
::  checked for disjointness. The tested axis follows the field path;
::  tracking that path distinguishes a nested $^ from an ordinary $@.
::  Other Hoon code can look the same, so some valid molds may be rejected.
::  Collection argument syntax retains $^ as %bckt, before Hoon
::  reduces the resulting type and can collapse overlapping cases. Until
::  argument-level disjointness is checked, reject those source forms.
++  has-spec-cell-union
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  ?=([%bckt ^ ^] h)  &
  |($(h -.h) $(h +.h))
::
++  has-cell-union
  |=  h=hoon
  ^-  ?
  ?.  ?=([%tsls [%note * *] *] h)  (has-cell-union-any h)
  (has-cell-union-at q.p.h 6)
::
++  has-cell-union-any
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  =(h [%dtwt [%$ 12]])  &
  |($(h -.h) $(h +.h))
::
++  has-cell-union-at
  |=  [h=hoon axis=@ud]
  ^-  ?
  ?^  -.h
    |($(h -.h, axis (mul 2 axis)) $(h +.h, axis (add 1 (mul 2 axis))))
  ?+  h  (has-cell-union-any h)
    [%note *]  $(h q.h)
    [%ktts *]  $(h q.h)
    [%wtcl *]
      ?:  =(p.h [%dtwt [%$ (mul 2 axis)]])  &
      |($(h q.h) $(h r.h))
  ==
::
++  cell-branches
  |=  h=type
  ^-  (unit [left=type right=type])
  ?.  ?=([%hold *] h)  ~
  =/  original=hoon  q.h
  ?.  ?=([%tsls [%note * *] *] original)  ~
  =/  body=hoon  q.p.original
  ?.  ?=([%wtcl *] body)  ~
  ?.  =(p.body [%dtwt [%$ 12]])  ~
  =/  one=hoon  original(q.p q.body)
  =/  two=hoon  original(q.p r.body)
  ::  Branches can rely on narrowing in the original conditional. When a
  ::  branch cannot be evaluated on its own, report it as unsupported.
  =/  attempt=(each [type type] tang)
    (mule |.([(~(play ut p.h) one) (~(play ut p.h) two)]))
  ?-  attempt
    [%& *]  [~ p.attempt]
    [%| *]  ~
  ==
::
::  A static branch contains atom molds, exact tag constants and cells.
::  A tag shape must compare the current axis to the same atom it returns.
++  fixed-cell-mold
  |=  [h=hoon axis=@ud]
  ^-  ?
  ?^  -.h
    &($(h -.h, axis (mul 2 axis)) $(h +.h, axis (add 1 (mul 2 axis))))
  ?+  h  |
    [%note *]  $(h q.h)
    [%ktts *]  $(h q.h)
    [%ktls *]  ?=([%sand *] p.h)
    [%wtgr *]
      ?.  ?=([%dtts [%$ *] [%rock %$ *]] p.h)  |
      ?.  ?=([%rock %tas *] q.h)  |
      ?^  q.q.h  |
      &(=(p.p.p.h axis) =(q.q.p.h q.q.h))
  ==
::
::  Return two source records with a single $^ replaced by each branch.
++  split-cell-record
  |=  [h=hoon axis=@ud]
  ^-  (unit [one=hoon two=hoon])
  ?^  -.h
    =/  left  $(h -.h, axis (mul 2 axis))
    =/  right  $(h +.h, axis (add 1 (mul 2 axis)))
    ?^  left
      ?^  right  ~
      ?.  (fixed-cell-mold +.h (add 1 (mul 2 axis)))  ~
      [~ [[one.u.left +.h] [two.u.left +.h]]]
    ?~  right  ~
    ?.  (fixed-cell-mold -.h (mul 2 axis))  ~
    [~ [[-.h one.u.right] [-.h two.u.right]]]
  ?+  h  ~
    [%note *]
      =/  out  $(h q.h)
      ?~  out  ~
      [~ [h(q one.u.out) h(q two.u.out)]]
    [%ktts *]
      =/  out  $(h q.h)
      ?~  out  ~
      [~ [h(q one.u.out) h(q two.u.out)]]
    [%wtcl *]
      ?.  =(p.h [%dtwt [%$ (mul 2 axis)]])  ~
      ?.  &((fixed-cell-mold q.h axis) (fixed-cell-mold r.h axis))  ~
      [~ [q.h r.h]]
  ==
::
::  Reassemble a split source record. Non-union fields must have remained
::  unchanged; the replaced field must have provably disjoint branches.
++  merge-cell-record
  |=  [h=hoon axis=@ud a=imported b=imported]
  ^-  (each imported @t)
  ?^  -.h
    ?.  &(?=([%cell *] a) ?=([%cell *] b))
      [%| 'a nested Hoon $^ union needs a source-level disjointness check']
    =/  left  $(h -.h, axis (mul 2 axis), a head.a, b head.b)
    ?.  ?=([%& *] left)  left
    =/  right  $(h +.h, axis (add 1 (mul 2 axis)), a tail.a, b tail.b)
    ?.  ?=([%& *] right)  right
    [%& [%cell p.left p.right]]
  ?+  h
    ?:  =(a b)  [%& a]
    [%| 'a nested Hoon $^ union needs a source-level disjointness check']
    [%note *]  $(h q.h)
    [%ktts *]
      ?.  &(?=([%face *] a) ?=([%face *] b))
        [%| 'a nested Hoon $^ union needs a source-level disjointness check']
      ?.  &(=(p.h name.a) =(p.h name.b))
        [%| 'a nested Hoon $^ union needs a source-level disjointness check']
      =/  child  $(h q.h, a body.a, b body.b)
      ?.  ?=([%& *] child)  child
      [%& [%face name.a p.child]]
    [%wtcl *]
      ?.  =(p.h [%dtwt [%$ (mul 2 axis)]])
        [%| 'a nested Hoon $^ union needs a source-level disjointness check']
      ?.  (disjoint a b)  [%| 'a Hoon $^ union has overlapping cases']
      [%& [%fork (sort ~[a b] |=(pair=[imported imported] (dor -.pair +.pair)))]]
  ==
++  disjoint
  |=  [a=imported b=imported]
  ^-  ?
  ?:  ?=([%face *] a)  $(a body.a)
  ?:  ?=([%face *] b)  $(b body.b)
  ?:  ?=([%fork *] a)
    (levy cases.a |=(item=imported (disjoint item b)))
  ?:  ?=([%fork *] b)
    (levy cases.b |=(item=imported (disjoint a item)))
  ?:  |(?=([%void *] a) ?=([%void *] b))  &
  ?:  ?=([%atom *] a)
    ?:  ?=([%cell *] b)  &
    ?.  ?=([%atom *] b)  |
    ?~  value.a  |
    ?~  value.b  |
    !=(u.value.a u.value.b)
  ?:  ?=([%cell *] a)
    ?:  ?=([%atom *] b)  &
    ?.  ?=([%cell *] b)  |
    |($(a head.a, b head.b) $(a tail.a, b tail.b))
  |
::
::  Source names may resolve to a local Hoon arm rather than zuse. A
::  missing verified subject or any local arm with that name is unsafe.
::  A chapter's +tome has different wrappers under eval and Clay. Walk
::  its noun map without relying on either version's field names.
++  arm-map-has
  |=  [m=* target=term]
  ^-  ?
  ?@  m  |
  ?@  -.m  |
  =/  kv=*  -.m
  ?^  -.kv  |
  ?:  =(-.kv target)  &
  =/  children=*  +.m
  ?@  children  |
  |($(m -.children) $(m +.children))
::
++  arm-map-valid
  |=  m=*
  ^-  ?
  ?@  m  =(m ~)
  ?@  -.m  |
  =/  kv=*  -.m
  ?^  -.kv  |
  =/  children=*  +.m
  ?@  children  |
  &($(m -.children) $(m +.children))
::
::  ~ means this is neither supported chapter representation. The
::  caller treats that as unsafe, not as a validated miss.
++  chapter-has
  |=  [chapter=* target=term]
  ^-  (unit ?)
  ?:  (arm-map-valid chapter)  [~ (arm-map-has chapter target)]
  ?@  chapter  ~
  ?.  (arm-map-valid +.chapter)  ~
  [~ (arm-map-has +.chapter target)]
::
++  chapter-unsafe
  |=  [chapter=* target=term]
  ^-  ?
  =/  has  (chapter-has chapter target)
  ?~  has  &
  u.has
::
::  Verify every lexical subject layer until the exact standard subject.
::  Refuse unknown forms, malformed chapters, mismatched core payloads,
::  faces that shadow the selected name, and imported arms of that name.
++  scope-safe
  |=  [scope=type target=term]
  ^-  ?
  ?:  =(scope -:!>(..zuse))  &
  ?-  scope
    [%cell *]
      ?.  ?=([%face *] p.scope)  |
      ?^  p.p.scope  |
      ?:  =(p.p.scope target)  |
      ?.  ?=([%core *] q.p.scope)  |
      &($(scope q.p.scope) $(scope q.scope))
    [%core *]
      ?.  =(p.scope q.q.scope)  |
      =/  chapters=(map term tome)  q.r.q.scope
      ?:  (lien ~(tap by chapters) |=(entry=[term tome] (chapter-unsafe +.entry target)))  |
      $(scope p.scope)
    *  |
  ==
::
++  alias-safe
  |=  [context=(unit type) target=term]
  ^-  ?
  ?~  context  |
  (scope-safe u.context target)
::
++  source-uses
  |=  [src=* target=term]
  ^-  ?
  ?:  =(src [%wing [target ~]])  &
  ?@  src  |
  |($(src -.src) $(src +.src))
::
++  mop-specs-raw
  |=  body=hoon
  ^-  (unit [key=spec value=spec])
  ?.  ?=([%cncl *] body)  ~
  ?.  ?=([%tsgr *] p.body)  ~
  =/  b=hoon  q.p.body
  ?.  ?=([%cncl *] b)  ~
  ?.  ?=([%cncl *] p.b)  ~
  ?.  ?=([%wing *] p.p.b)  ~
  ?.  =(p.p.p.b ~[%mop])  ~
  =/  specs=(list spec)  ;;((list spec) q.p.b)
  ?.  ?=([* [* ~]] specs)  ~
  [~ [i.specs i.t.specs]]
::
++  mop-specs
  |=  body=hoon
  ^-  (unit [key=spec value=spec])
  =/  attempt=(each (unit [key=spec value=spec]) tang)
    (mule |.((mop-specs-raw body)))
  ?-  attempt
    [%& *]  p.attempt
    [%| *]  ~
  ==
::
++  mop-arguments-raw
  |=  h=type
  ^-  (unit [key=type value=type])
  ?.  ?=([%hold *] h)  ~
  =/  original=hoon  q.h
  ?.  ?=([%tsls [%note * *] *] original)  ~
  =/  specs  (mop-specs q.p.original)
  ?~  specs  ~
  [~ [(~(play ut p.h) [%kttr key.u.specs]) (~(play ut p.h) [%kttr value.u.specs])]]
::
++  mop-arguments
  |=  h=type
  ^-  (unit [key=type value=type])
  =/  attempt=(each (unit [key=type value=type]) tang)
    (mule |.((mop-arguments-raw h)))
  ?-  attempt
    [%& *]  p.attempt
    [%| *]  ~
  ==
::
++  match-signature
  |=  [h=hoon sig=signatures]
  ^-  (unit term)
  ?~  sig  ~
  ?:  =(h code.i.sig)  [~ name.i.sig]
  $(sig t.sig)
::
++  find-seen
  |=  [typ=type seen=visiting]
  ^-  (unit (unit term))
  ?~  seen  ~
  ?:  =(typ typ.i.seen)  [~ name.i.seen]
  $(seen t.seen)
::
::  Find the source module for an exact recursive hold by evaluating
::  locally declared arms of each validated core in the subject. An
::  unlabelled core, failed evaluation, or multiple labels is ambiguous.
++  origin-candidates
  |=  [scope=type label=(unit term) name=term typ=type]
  ^-  (list (unit term))
  ?:  =(scope -:!>(..zuse))  ~
  ?-  scope
    [%cell *]
      ?.  ?=([%face *] p.scope)  ~[~]
      ?^  p.p.scope  ~[~]
      %+  weld
        $(scope q.p.scope, label [~ p.p.scope])
      $(scope q.scope, label ~)
    [%core *]
      =/  chapters=(map term tome)  q.r.q.scope
      =/  present=?  (lien ~(tap by chapters) |=(entry=[term tome] =((chapter-has +.entry name) [~ &])))
      =/  own=(list (unit term))
        ?.  present  ~
        =/  trial=(each type tang)  (mule |.((~(play ut scope) (ream (cat 3 '*' name)))))
        ?-  trial
          [%| *]  ~[~]
          [%& *]  ?:  =(p.trial typ)  ~[label]
                    ~
        ==
      (weld own $(scope p.scope, label ~))
    *  ~[~]
  ==
::
++  ref-origin
  |=  [module=term name=term typ=type context=(unit type)]
  ^-  (unit term)
  ?~  context  ~
  =/  found  (origin-candidates u.context [~ module] name typ)
  ?~  found  ~
  ?~  i.found  ~
  =/  choice=term  u.i.found
  =/  same
    |=  item=(unit term)
    ^-  ?
    ?~  item  |
    =(u.item choice)
  ?.  (levy t.found same)  ~
  [~ choice]
::
++  walk
  |=  [module=term typ=type sig=signatures seen=visiting context=(unit type)]
  ^-  imported
  ?-  typ
    %noun  [%noun ~]
    %void  [%void ~]
    [%atom *]
      ?:  |(=('s' (cut 3 [0 1] p.typ)) =('r' (cut 3 [0 1] p.typ)))
        [%bad 'signed and float auras cannot be imported']
      [%atom p.typ q.typ]
    [%cell *]  [%cell $(typ p.typ) $(typ q.typ)]
    [%core *]  [%bad 'cores and gates cannot be imported']
    [%face *]
      ?@  p.typ  [%face p.typ $(typ q.typ)]
      [%bad 'a complex Hoon face needs translation']
    [%fork *]
      =/  cases=(list imported)
        (turn ~(tap in:..zuse p.typ) |=(t=type ^$(typ t)))
      [%fork (sort cases |=(pair=[imported imported] (dor -.pair +.pair)))]
    [%hint *]  $(typ q.typ)
    [%hold *]
      ?:  &(?=([%tsls [%note * *] *] q.typ) (has-spec-cell-union q.typ))
        [%bad 'a Hoon $^ union needs a source-level disjointness check']
      =/  named=(unit term)  (match-signature q.typ sig)
      ?^  named
        =/  name  u.named
        ?:  =(%vase name)  [%bad 'vases cannot be imported']
        ?.  (alias-safe context name)
          [%bad 'Hoon collection provenance is unavailable or shadowed']
        =/  first=type
          (~(play ut p.typ) (ream ?:(|(=(%map name) =(%jar name) =(%jug name)) '*key' '*item')))
        =/  first-import  $(typ first)
        ?:  |(=(%map name) =(%jar name) =(%jug name))
          =/  second=type  (~(play ut p.typ) (ream '*value'))
          [%apply name ~[first-import $(typ second)]]
        [%apply name ~[first-import]]
      =/  prior=(unit (unit term))  (find-seen typ seen)
      ?^  prior
        ?~  u.prior  [%bad 'an anonymous recursive Hoon mold cannot be named']
        =/  origin  (ref-origin module u.u.prior typ context)
        ?~  origin  [%bad 'a recursive Hoon mold needs unambiguous source provenance']
        [%ref u.origin u.u.prior]
      =/  nm  (hold-name q.typ)
      ?:  =(nm [~ %vase])  [%bad 'vases cannot be imported']
      ?:  &((source-uses q.typ %jar) !(alias-safe context %jar))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      ?:  &((source-uses q.typ %jug) !(alias-safe context %jug))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      ?:  &((source-uses q.typ %mop) !(alias-safe context %mop))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      =/  mop  (mop-arguments typ)
      ?^  mop
        [%apply %mop ~[$(typ key.u.mop) $(typ value.u.mop)]]
      ?:  (source-uses q.typ %mop)
        =/  checked-names=(list term)  ~[%map %set %qeu %list %unit]
        ?:  (lien checked-names |=(n=term &((source-uses q.typ n) !(alias-safe context n))))
          [%bad 'Hoon collection provenance is unavailable or shadowed']
        ?.  ?=([%tsls [%note * *] *] q.typ)
          [%bad 'a nested Hoon mop needs source-aware import']
        =/  original=hoon  q.typ
        ?>  ?=([%tsls [%note * *] *] original)
        =/  source=hoon  q.p.original
        ?.  (patchable-mop-record source)
          [%bad 'a nested Hoon mop needs source-aware import']
        =/  patched=hoon  (patch-mops source)
        ?:  |(=(source patched) (source-uses patched %mop))
          [%bad 'a nested Hoon mop needs source-aware import']
        =/  replacement=hoon  original(q.p patched)
        =/  attempt=(each type tang)  (mule |.((~(play ut p.typ) replacement)))
        ?-  attempt
          [%| *]  [%bad 'a nested Hoon mop needs source-aware import']
          [%& *]
            =/  projected  $(typ p.attempt, seen [[typ nm] seen])
            =/  corrected  (recover-alias source projected p.typ module sig seen context)
            ?-  corrected
              [%| *]  [%bad p.corrected]
              [%& *]  p.corrected
            ==
        ==
      =/  branches  (cell-branches typ)
      ?^  branches
        =/  first  $(typ left.u.branches, seen [[typ nm] seen])
        =/  second  $(typ right.u.branches, seen [[typ nm] seen])
        =/  err  (first-bads ~[first second])
        ?^  err  [%bad u.err]
        ?:  (disjoint first second)
          [%fork (sort ~[first second] |=(pair=[imported imported] (dor -.pair +.pair)))]
        [%bad 'a Hoon $^ union has overlapping cases']
      ?:  (has-cell-union q.typ)
        ?.  ?=([%tsls [%note * *] *] q.typ)
          [%bad 'a Hoon $^ union needs a source-level disjointness check']
        =/  original=hoon  q.typ
        ?>  ?=([%tsls [%note * *] *] original)
        =/  body=hoon  q.p.original
        =/  split  (split-cell-record body 6)
        ?~  split  [%bad 'a Hoon $^ union needs a source-level disjointness check']
        =/  try=(each [type type] tang)
          (mule |.([(~(play ut p.typ) original(q.p one.u.split)) (~(play ut p.typ) original(q.p two.u.split))]))
        ?.  ?=([%& *] try)  [%bad 'a Hoon $^ union needs a source-level disjointness check']
        =/  first  $(typ -.p.try, seen [[typ nm] seen])
        =/  second  $(typ +.p.try, seen [[typ nm] seen])
        =/  err  (first-bads ~[first second])
        ?^  err  [%bad u.err]
        =/  combined  (merge-cell-record body 6 first second)
        ?-  combined
          [%& *]  p.combined
          [%| *]  [%bad p.combined]
        ==
      =/  alias  (hold-alias q.typ)
      =/  hidden  (has-hidden-alias q.typ)
      =/  body  $(typ ~(repo ut typ), seen [[typ nm] seen])
      ?~  alias
        ?.  hidden  body
        ?.  ?=([%tsls [%note * *] *] q.typ)
          [%bad 'a nested collection alias needs source-aware import']
        =/  corrected  (recover-alias q.p.q.typ body p.typ module sig seen context)
        ?-  corrected
          [%& *]  p.corrected
          [%| *]  [%bad p.corrected]
        ==
      ?.  ?=([%tsls [%note * *] *] q.typ)
        [%bad 'a Hoon collection alias could not be recovered']
      =/  corrected  (recover-alias q.p.q.typ body p.typ module sig seen context)
      ?-  corrected
        [%& *]  p.corrected
        [%| *]  [%bad p.corrected]
      ==
  ==
::
++  first-bad
  |=  out=imported
  ^-  (unit @t)
  ?-  out
    [%noun *]  ~
    [%void *]  ~
    [%atom *]  ~
    [%ref *]  ~
    [%bad *]  [~ reason.out]
    [%face *]  $(out body.out)
    [%cell *]
      =/  err  $(out head.out)
      ?~  err  $(out tail.out)
      err
    [%fork *]  (first-bads cases.out)
    [%apply *]  (first-bads args.out)
  ==
::
++  first-bads
  |=  xs=(list imported)
  ^-  (unit @t)
  ?~  xs  ~
  =/  err  (first-bad i.xs)
  ?~  err  $(xs t.xs)
  err
::  +fixture-test: shared golden expectations for eval and the ship.
::  A synthetic hold whose first $^ branch cannot be evaluated. It tests
::  that a failed branch probe is reported rather than crashing the host.
++  bad-branch-fixture
  ^-  type
  [%hold -:!>(..zuse) [%tsls [%note [%made %bad ~] [%wtcl [%dtwt [%$ 12]] [%wing ~[%jibb-no-such-branch-name]] [%rock %n 0]]] [%$ 1]]]
::
++  fixture-test
  |=  [small=@t epic=@t presence=@t docs=@t shadow=@t]
  ^-  (list @t)
  =/  sc=type  -:(ride -:!>(..zuse) small)
  =/  ec=type  -:(ride -:!>(..zuse) epic)
  =/  pc=type  -:(ride -:!>(..zuse) presence)
  =/  dc=type  -:(ride -:!>(..zuse) docs)
  =/  hc=type  -:(ride -:!>(..zuse) shadow)
  =/  sample
    |=  name=term
    (read-mold-in %small name (~(play ut sc) (ream (cat 3 '*' name))) sc)
  =/  tlon
    |=  name=term
    (read-mold-in %epic name (~(play ut ec) (ream (cat 3 '*' name))) ec)
  =/  present
    |=  name=term
    (read-mold-in %presence name (~(play ut pc) (ream (cat 3 '*' name))) pc)
  =/  shad
    |=  name=term
    (read-mold-in %shadow name (~(play ut hc) (ream (cat 3 '*' name))) hc)
  =/  docs-type
    |=  name=term
    (read-mold-in %docs name (~(play ut dc) (ream (cat 3 '*' name))) dc)
  =/  errors=(list @t)  ~
  =/  expect-action=imported
    [%fork ~[[%cell [%atom %tas [~ %add]] [%face %text [%atom %t ~]]] [%cell [%atom %tas [~ %remove]] [%face %id [%atom %ud ~]]]]]
  =/  errors  ?:  =((sample %action) [%& expect-action])  errors
    ['union cases and faces' errors]
  =/  expect-map=imported
    [%apply %map ~[[%atom %ud ~] [%cell [%face %id [%atom %ud ~]] [%face %text [%atom %t ~]]]]]
  =/  errors  ?:  =((sample %items) [%& expect-map])  errors
    ['map and its arguments' errors]
  =/  expect-optional=imported
    [%fork ~[[%cell [%face %name [%atom %t ~]] [%face %stamp [%atom %ud ~]]] [%atom %ud ~]]]
  =/  errors  ?:  =((sample %optional) [%& expect-optional])  errors
    ['atom-or-cell union' errors]
  =/  expect-containers=imported
    [%cell [%apply %set ~[[%atom %ud ~]]] [%cell [%apply %qeu ~[[%atom %ud ~]]] [%cell [%apply %list ~[[%atom %t ~]]] [%apply %unit ~[[%atom %ud ~]]]]]]
  =/  errors  ?:  =((sample %containers) [%& expect-containers])  errors
    ['set queue list and unit' errors]
  =/  expect-chain=imported
    [%fork ~[[%cell [%face %value [%atom %ud ~]] [%face %next [%ref %small %chain]]] [%atom %n [~ 0]]]]
  =/  errors  ?:  =((sample %chain) [%& expect-chain])  errors
    ['recursive reference' errors]
  =/  expect-jar=imported  [%apply %jar ~[[%atom %ud ~] [%atom %t ~]]]
  =/  expect-jug=imported  [%apply %jug ~[[%atom %ud ~] [%atom %t ~]]]
  =/  errors  ?:  =((sample %jar-test) [%& expect-jar])  errors
    ['jar name and arguments' errors]
  =/  errors  ?:  =((sample %jug-test) [%& expect-jug])  errors
    ['jug name and arguments' errors]
  =/  expect-nested-jar=imported  [%face %field [%apply %jar ~[[%atom %ud ~] [%atom %t ~]]]]
  =/  errors  ?:  =((sample %nested-jar) [%& expect-nested-jar])  errors
    ['nested jar is preserved' errors]
  =/  expect-paired=imported
    [%cell [%face %values [%apply %jar ~[[%atom %ud ~] [%atom %t ~]]]] [%face %cache [%apply %jug ~[[%atom %ud ~] [%atom %t ~]]]]]
  =/  errors  ?:  =((sample %paired-aliases) [%& expect-paired])  errors
    ['multiple collection aliases are preserved' errors]
  =/  expect-nested-alias=imported
    [%apply %jar ~[[%atom %ud ~] [%apply %jug ~[[%atom %ud ~] [%atom %t ~]]]]]
  =/  errors  ?:  =((sample %nested-alias) [%& expect-nested-alias])  errors
    ['nested collection arguments preserve names' errors]
  =/  expect-mop=imported  [%apply %mop ~[[%atom %ud ~] [%atom %t ~]]]
  =/  errors  ?:  =((sample %mop-test) [%& expect-mop])  errors
    ['ordered map name and arguments' errors]
  =/  expect-nested-mop=imported
    [%cell [%face %table expect-mop] [%face %other [%atom %ud ~]]]
  =/  errors  ?:  =((sample %nested-mop) [%& expect-nested-mop])  errors
    ['ordered map field is preserved' errors]
  =/  expect-mixed=imported
    [%cell [%face %a expect-mop] [%face %b [%apply %list ~[[%atom %ud ~]]]]]
  =/  errors  ?:  =((sample %mixed-mop) [%& expect-mixed])  errors
    ['static list sibling is preserved' errors]
  =/  errors  ?:  =((sample %named-mop) [%| 'a nested Hoon mop needs source-aware import'])  errors
    ['non-atom argument remains unsupported' errors]
  =/  errors  ?:  =((sample %mop-list) [%| 'a nested Hoon mop needs source-aware import'])  errors
    ['ordered map in a list remains unsupported' errors]
  =/  errors  ?:  =((sample %signed) [%| 'signed and float auras cannot be imported'])  errors
    ['signed aura rejected' errors]
  =/  errors  ?:  =((sample %float) [%| 'signed and float auras cannot be imported'])  errors
    ['float aura rejected' errors]
  =/  errors  ?:  =((sample %gate-test) [%| 'cores and gates cannot be imported'])  errors
    ['gate rejected' errors]
  =/  errors  ?:  =((read-mold %std %vase (~(play ut -:!>(..zuse)) (ream '*vase'))) [%| 'vases cannot be imported'])  errors
    ['vase rejected' errors]
  =/  expect-valid=imported
    [%fork ~[[%cell [%face %x [%atom %ud ~]] [%face %y [%atom %ud ~]]] [%atom %ud ~]]]
  =/  errors  ?:  =((sample %valid-cell) [%& expect-valid])  errors
    ['disjoint cell union' errors]
  =/  errors  ?:  =((sample %invalid-cell) [%| 'a Hoon $^ union has overlapping cases'])  errors
    ['overlapping cell union is rejected' errors]
  =/  errors  ?:  =((shad %mn) [%| 'Hoon collection provenance is unavailable or shadowed'])  errors
    ['local mop shadow in a field is rejected' errors]
  =/  errors  ?:  =((shad %mm) [%| 'Hoon collection provenance is unavailable or shadowed'])  errors
    ['local mop shadow is rejected' errors]
  =/  errors  ?:  =((shad %aa) [%| 'Hoon collection provenance is unavailable or shadowed'])  errors
    ['local jar shadow is rejected' errors]
  =/  errors  ?:  =((shad %bb) [%| 'Hoon collection provenance is unavailable or shadowed'])  errors
    ['local jug shadow in a field is rejected' errors]
  =/  errors  ?:  =((read-mold %small %jar-test (~(play ut sc) (ream '*jar-test'))) [%| 'Hoon collection provenance is unavailable or shadowed'])  errors
    ['missing provenance is rejected' errors]
  =/  expect-timing=imported
    [%cell [%face %since [%atom %da ~]] [%face %timeout [%apply %unit ~[[%atom %dr ~]]]]]
  =/  errors  ?:  =((present %timing) [%& expect-timing])  errors
    ['Tlon presence timing' errors]
  =/  errors  ?:  =((read-mold %external %bad bad-branch-fixture) [%| 'a Hoon $^ union needs a source-level disjointness check'])  errors
    ['failed branch expansion is reported' errors]
  =/  expect-saga=imported
    [%fork ~[[%cell [%atom %tas [~ %chi]] [%atom %n [~ 0]]] [%cell [%atom %tas [~ %lev]] [%atom %n [~ 0]]] [%cell [%atom %tas [~ %dex]] [%face %ver [%atom %ud ~]]]]]
  =/  errors  ?:  =((tlon %saga) [%& expect-saga])  errors
    ['Tlon saga union' errors]
  =/  errors  ?:  =((tlon %epic) [%& [%atom %ud ~]])  errors
    ['Tlon epic atom' errors]
  errors

::  A compact diagnostic projection for importer golden files. This is
::  not the Jibb type printer: it exposes constants and recursive refs.
++  show-import
  |=  out=imported
  ^-  tape
  ?-  out
    [%noun *]  "*"
    [%void *]  "!!"
    [%atom *]
      ?~  value.out  "@{(trip aura.out)}"
      ?:  =(%tas aura.out)  "{(trip (scot %tas u.value.out))}"
      "@{(trip aura.out)}:{(trip (scot %ud u.value.out))}"
    [%cell *]  "[{(show-import head.out)} {(show-import tail.out)}]"
    [%face *]  "{(trip name.out)}={(show-import body.out)}"
    [%fork *]  "(union {(show-imports cases.out)})"
    [%apply *]  "({(trip name.out)} {(show-imports args.out)})"
    [%ref *]  "{(trip name.out)}.{(trip module.out)}"
    [%bad *]  "error: {(trip reason.out)}"
  ==
::
++  show-imports
  |=  xs=(list imported)
  ^-  tape
  ?~  xs  ""
  ?~  t.xs  (show-import i.xs)
  "{(show-import i.xs)} {$(xs t.xs)}"
::
++  show-result
  |=  result=(each imported @t)
  ^-  tape
  ?-  result
    [%& *]  (show-import p.result)
    [%| *]  "error: {(trip p.result)}"
  ==
::
++  fixture-output
  |=  [small=@t epic=@t presence=@t docs=@t shadow=@t shadow-static=@t ford=@t mark=@t mark-rec=@t mark-gate=@t mark-basic=@t origin-trans=@t origin-first=@t origin-other=@t]
  ^-  wain
  =/  sc=type  -:(ride -:!>(..zuse) small)
  =/  ec=type  -:(ride -:!>(..zuse) epic)
  =/  pc=type  -:(ride -:!>(..zuse) presence)
  =/  dc=type  -:(ride -:!>(..zuse) docs)
  =/  hc=type  -:(ride -:!>(..zuse) shadow)
  =/  xc=type  -:(ride -:!>(..zuse) shadow-static)
  =/  fp=type  [%cell [%face %small sc] -:!>(..zuse)]
  =/  other=type  -:(ride -:!>(..zuse) origin-other)
  =/  fc=type  -:(ride fp ford)
  ?>  ?=([%core *] fc)
  =/  only-list=@t  '|%\0a+$  lists  (list @ud)\0a--\0a'
  =/  tp=type  [%cell [%face %intermediate fc] -:!>(..zuse)]
  =/  tc=type  -:(ride tp only-list)
  =/  sp=type  [%cell [%face %small xc] -:!>(..zuse)]
  =/  shc=type  -:(ride sp only-list)
  =/  mark-core=type  -:(ride fp mark)
  =/  mark-rec-core=type  -:(ride fp mark-rec)
  =/  mark-gate-core=type  -:(ride -:!>(..zuse) mark-gate)
  =/  mark-basic-core=type  -:(ride -:!>(..zuse) mark-basic)
  =/  mark-shadow-core=type  -:(ride sp mark-basic)
  =/  tshp=type  [%cell [%face %intermediate shc] -:!>(..zuse)]
  =/  tshc=type  -:(ride tshp only-list)
  =/  trans=type  -:(ride tp origin-trans)
  =/  ambiguous-parent=type  [%cell [%face %first sc] [%cell [%face %second sc] -:!>(..zuse)]]
  =/  ambiguous=type  -:(ride ambiguous-parent origin-first)
  =/  distinct-parent=type  [%cell [%face %first sc] [%cell [%face %second other] -:!>(..zuse)]]
  =/  distinct=type  -:(ride distinct-parent origin-first)
  =/  trans-amb-parent=type  [%cell [%face %intermediate fc] [%cell [%face %second sc] -:!>(..zuse)]]
  =/  trans-amb=type  -:(ride trans-amb-parent origin-trans)
  =/  sample
    |=  name=term
    (read-mold-in %small name (~(play ut sc) (ream (cat 3 '*' name))) sc)
  =/  tlon
    |=  name=term
    (read-mold-in %epic name (~(play ut ec) (ream (cat 3 '*' name))) ec)
  =/  present
    |=  name=term
    (read-mold-in %presence name (~(play ut pc) (ream (cat 3 '*' name))) pc)
  =/  shad
    |=  name=term
    (read-mold-in %shadow name (~(play ut hc) (ream (cat 3 '*' name))) hc)
  =/  docs-type
    |=  name=term
    (read-mold-in %docs name (~(play ut dc) (ream (cat 3 '*' name))) dc)
  =/  chapter-tree=(map term hoon)
    (~(put by *(map term hoon)) %jar [%zpzp ~])
  =/  vase  (read-mold %std %vase (~(play ut -:!>(..zuse)) (ream '*vase')))
  :~  (crip "action: {(show-result (sample %action))}")
      (crip "optional: {(show-result (sample %optional))}")
      (crip "items: {(show-result (sample %items))}")
      (crip "containers: {(show-result (sample %containers))}")
      (crip "chain: {(show-result (sample %chain))}")
      (crip "jar: {(show-result (sample %jar-test))}")
      (crip "jug: {(show-result (sample %jug-test))}")
      (crip "nested-jar: {(show-result (sample %nested-jar))}")
      (crip "paired-aliases: {(show-result (sample %paired-aliases))}")
      (crip "nested-alias: {(show-result (sample %nested-alias))}")
      (crip "compound: {(show-result (sample %compound))}")
      (crip "compound-fields: {(show-result (sample %compound-fields))}")
      (crip "mop: {(show-result (sample %mop-test))}")
      (crip "nested-mop: {(show-result (sample %nested-mop))}")
      (crip "two-mops: {(show-result (sample %two-mops))}")
      (crip "mixed-mop: {(show-result (sample %mixed-mop))}")
      (crip "nested-static-mop: {(show-result (sample %nested-static-mop))}")
      (crip "collection-siblings: {(show-result (sample %collection-siblings))}")
      (crip "dynamic-sibling-mop: {(show-result (sample %dynamic-sibling-mop))}")
      (crip "mark-record: {(show-result (read-mark %todo-item mark-core))}")
      (crip "mark-recursive: {(show-result (read-mark %recursive mark-rec-core))}")
      (crip "mark-gate: {(show-result (read-mark %bad mark-gate-core))}")
      (crip "mark-list: {(show-result (read-mark %list-mark mark-basic-core))}")
      (crip "mark-shadow: {(show-result (read-mark %list-mark mark-shadow-core))}")
      (crip "mark-not-core: {(show-result (read-mark %bad [%atom %ud ~]))}")
      (crip "ford-list: {(show-result (read-mold-in %ford %lists (~(play ut fc) (ream '*lists')) fc))}")
      (crip "ford-imported: {(show-result (read-mold-in %ford %wrapped (~(play ut fc) (ream '*wrapped')) fc))}")
      (crip "ford-recursive: {(show-result (read-mold-in %ford %recursive (~(play ut fc) (ream '*recursive')) fc))}")
      (crip "ford-local-recursive: {(show-result (read-mold-in %ford %local (~(play ut fc) (ream '*local')) fc))}")
      (crip "ford-recursive-transitive: {(show-result (read-named %outer %wrapped trans))}")
      (crip "ford-recursive-ambiguous: {(show-result (read-named %outer %pick-one ambiguous))}")
      (crip "ford-recursive-transitive-ambiguous: {(show-result (read-named %outer %wrapped trans-amb))}")
      (crip "ford-recursive-distinct-first: {(show-result (read-named %outer %pick-one distinct))}")
      (crip "ford-recursive-distinct-second: {(show-result (read-named %outer %pick-two distinct))}")
      (crip "ford-transitive: {(show-result (read-mold-in %ford %lists (~(play ut tc) (ream '*lists')) tc))}")
      (crip "ford-shadow: {(show-result (read-mold-in %ford %lists (~(play ut shc) (ream '*lists')) shc))}")
      (crip "ford-transitive-shadow: {(show-result (read-mold-in %ford %lists (~(play ut tshc) (ream '*lists')) tshc))}")
      (crip "ford-shadow-face: {?:((scope-safe [%cell [%face %list sc] -:!>(..zuse)] %list) "wrong" "unsafe")}")
      (crip "ford-unknown: {?:((scope-safe [%cell [%atom %ud ~] -:!>(..zuse)] %list) "wrong" "unsafe")}")
      (crip "ford-mismatched-core: {?:((scope-safe fc(p -:!>(..zuse)) %list) "wrong" "unsafe")}")
      (crip "shadow-list-mop: {(show-result (read-mold-in %shadow-static %bad (~(play ut xc) (ream '*bad')) xc))}")
      (crip "named-mop: {(show-result (sample %named-mop))}")
      (crip "mop-list: {(show-result (sample %mop-list))}")
      (crip "signed: {(show-result (sample %signed))}")
      (crip "float: {(show-result (sample %float))}")
      (crip "gate: {(show-result (sample %gate-test))}")
      (crip "vase: {(show-result vase)}")
      (crip "failed-branch: {(show-result (read-mold %external %bad bad-branch-fixture))}")
      (crip "list-bckt-field: {(show-result (sample %list-bckt-field))}")
      (crip "list-noun-overlap: {(show-result (sample %list-noun-overlap))}")
      (crip "list-null-overlap: {(show-result (sample %list-null-overlap))}")
      (crip "list-nested-atom-cell: {(show-result (sample %list-nested-atom-cell))}")
      (crip "list-nested-valid-cell: {(show-result (sample %list-nested-valid-cell))}")
      (crip "list-nested-invalid-cell: {(show-result (sample %list-nested-invalid-cell))}")
      (crip "map-nested-invalid-cell: {(show-result (sample %map-nested-invalid-cell))}")
      (crip "set-direct-invalid-cell: {(show-result (sample %set-direct-invalid-cell))}")
      (crip "map-key-invalid-cell: {(show-result (sample %map-key-invalid-cell))}")
      (crip "nested-atom-cell: {(show-result (sample %nested-atom-cell))}")
      (crip "nested-tags: {(show-result (sample %nested-tags))}")
      (crip "nested-tags-overlap: {(show-result (sample %nested-tags-overlap))}")
      (crip "nested-tagged: {(show-result (sample %nested-tagged))}")
      (crip "nested-tagged-bckt: {(show-result (sample %nested-tagged-bckt))}")
      (crip "nested-tagged-overlap: {(show-result (sample %nested-tagged-overlap))}")
      (crip "nested-tagged-alias: {(show-result (sample %nested-tagged-alias))}")
      (crip "nested-tagged-ford: {(show-result (read-named %outer %tagged trans))}")
      (crip "tag-static-valid: {?:((fixed-cell-mold [%wtgr [%dtts [%$ 13] [%rock %$ %foo]] [%rock %tas %foo]] 13) "yes" "no")}")
      (crip "tag-static-wrong-axis: {?:((fixed-cell-mold [%wtgr [%dtts [%$ 12] [%rock %$ %foo]] [%rock %tas %foo]] 13) "wrong" "no")}")
      (crip "tag-static-nonconstant: {?:((fixed-cell-mold [%wtgr [%dtts [%$ 13] [%rock %$ %foo]] [%$ 13]] 13) "wrong" "no")}")
      (crip "tag-static-wrong-value: {?:((fixed-cell-mold [%wtgr [%dtts [%$ 13] [%rock %$ %foo]] [%rock %tas %bar]] 13) "wrong" "no")}")
      (crip "nested-first-cell: {(show-result (sample %nested-first-cell))}")
      (crip "nested-alias-cell: {(show-result (sample %nested-alias-cell))}")
      (crip "nested-multiple-cell: {(show-result (sample %nested-multiple-cell))}")
      (crip "nested-named-sibling: {(show-result (sample %nested-named-sibling))}")
      (crip "nested-list-sibling: {(show-result (sample %nested-list-sibling))}")
      (crip "nested-validated-sibling: {(show-result (sample %nested-validated-sibling))}")
      (crip "nested-validated-branch: {(show-result (sample %nested-validated-branch))}")
      (crip "nested-named-branch: {(show-result (sample %nested-named-branch))}")
      (crip "nested-ford-cell: {(show-result (read-named %outer %nested trans))}")
      (crip "nested-valid-cell: {(show-result (sample %nested-valid-cell))}")
      (crip "nested-invalid-cell: {(show-result (sample %nested-invalid-cell))}")
      (crip "valid-cell: {(show-result (sample %valid-cell))}")
      (crip "invalid-cell: {(show-result (sample %invalid-cell))}")
      (crip "chapter-malformed: {?:((chapter-unsafe [%x %y %z] %jar) "unsafe" "wrong")}")
      (crip "chapter-wrapped-malformed: {?:((chapter-unsafe [~ [%x %y %z]] %jar) "unsafe" "wrong")}")
      (crip "chapter-direct-hit: {?:(=((chapter-has chapter-tree %jar) [~ &]) "yes" "no")}")
      (crip "chapter-wrapped-hit: {?:(=((chapter-has [~ chapter-tree] %jar) [~ &]) "yes" "no")}")
      (crip "chapter-direct-miss: {?:(=((chapter-has chapter-tree %jug) [~ &]) "yes" "no")}")
      (crip "chapter-wrapped-miss: {?:(=((chapter-has [~ chapter-tree] %jug) [~ &]) "yes" "no")}")
      (crip "shadow-nested-mop: {(show-result (shad %mn))}")
      (crip "shadow-mop: {(show-result (shad %mm))}")
      (crip "shadow-jar: {(show-result (shad %aa))}")
      (crip "shadow-jug: {(show-result (shad %bb))}")
      (crip "no-provenance-atom: {(show-result (read-mold %small %word (~(play ut sc) (ream '*word'))))}")
      (crip "no-provenance-recursive: {(show-result (read-mold %wrong %alias (~(play ut sc) (ream '*chain'))))}")
      (crip "no-provenance: {(show-result (read-mold %small %jar-test (~(play ut sc) (ream '*jar-test'))))}")
      (crip "named-not-mold: {(show-result (read-named %small %not-mold sc))}")
      (crip "named-present: {(show-result (read-named %small %items sc))}")
      (crip "named-missing: {(show-result (read-named %small %missing sc))}")
      (crip "named-invalid-core: {(show-result (read-named %small %items [%atom %ud ~]))}")
      (crip "named-ford-recursive: {(show-result (read-named %ford %recursive fc))}")
      (crip "missing-arm: {(show-result (read-mold-in %small %missing [%atom %ud ~] sc))}")
      (crip "wrong-provenance: {(show-result (read-mold-in %small %action (~(play ut sc) (ream '*items')) sc))}")
      (crip "unverified-subject: {(show-result (read-mold-in %std %jar (~(play ut -:!>(..zuse)) (ream '*(jar @ud @t)')) -:!>(..zuse)))}")
      (crip "presence-topic: {(show-result (present %topic))}")
      (crip "presence-timing: {(show-result (present %timing))}")
      (crip "presence-places: {(show-result (present %places))}")
      (crip "docs-ent: {(show-result (docs-type %ent))}")
      (crip "docs-nud: {(show-result (docs-type %nud))}")
      (crip "tlon-saga: {(show-result (tlon %saga))}")
      (crip "tlon-epic: {(show-result (tlon %epic))}")
  ==

--
