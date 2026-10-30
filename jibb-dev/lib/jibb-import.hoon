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
::  their imported shapes prove disjoint. Nested $^ and some valid but
::  unprovably disjoint cases remain unsupported. Source-level overlap in
::  other unions, nested ordered maps, Ford import provenance, marks and
::  full error locations still need work.
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
::  built directly against zuse and its selected arm must be this type;
::  imported Ford subjects need a future provenance-aware host.
++  read-mold-in
  |=  [module=term name=term typ=type cor=type]
  ^-  (each imported @t)
  ?.  ?=([%core *] cor)  [%| 'Hoon module provenance is unavailable']
  ?.  =(q.q.cor -:!>(..zuse))  [%| 'Hoon module provenance is unavailable']
  ?.  =(typ (~(play ut cor) (ream (cat 3 '*' name))))
    [%| 'Hoon module provenance does not match the selected mold']
  (read-with module name typ [~ cor])
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
++  recover-alias
  |=  [src=hoon out=imported]
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
::  checked for disjointness. Other Hoon code can produce the same test,
::  so this partial reader may reject some supported molds too.
++  has-cell-union
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  =(h [%dtwt [%$ 12]])  &
  |($(h -.h) $(h +.h))
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
++  alias-safe
  |=  [context=(unit type) target=term]
  ^-  ?
  ?~  context  |
  =/  cor=type  u.context
  ?.  ?=([%core *] cor)  |
  ?.  =(q.q.cor -:!>(..zuse))  |
  =/  chapters=(map term tome)  q.r.q.cor
  ?:  (lien ~(tap by chapters) |=(entry=[term tome] (chapter-unsafe +.entry target)))  |
  &
::
++  source-uses
  |=  [src=* target=term]
  ^-  ?
  ?:  =(src [%wing [target ~]])  &
  ?@  src  |
  |($(src -.src) $(src +.src))
::
++  mop-arguments-raw
  |=  h=type
  ^-  (unit [key=type value=type])
  ?.  ?=([%hold *] h)  ~
  =/  original=hoon  q.h
  ?.  ?=([%tsls [%note * *] *] original)  ~
  =/  body=hoon  q.p.original
  ?.  ?=([%cncl *] body)  ~
  ?.  ?=([%tsgr *] p.body)  ~
  =/  b=hoon  q.p.body
  ?.  ?=([%cncl *] b)  ~
  ?.  ?=([%cncl *] p.b)  ~
  ?.  ?=([%wing *] p.p.b)  ~
  ?.  =(p.p.p.b ~[%mop])  ~
  =/  specs=(list spec)  ;;((list spec) q.p.b)
  ?.  ?=([* [* ~]] specs)  ~
  [~ [(~(play ut p.h) [%kttr i.specs]) (~(play ut p.h) [%kttr i.t.specs])]]
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
        [%ref module u.u.prior]
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
        [%bad 'a nested Hoon mop needs source-aware import']
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
        [%bad 'a Hoon $^ union needs a source-level disjointness check']
      =/  alias  (hold-alias q.typ)
      =/  hidden  (has-hidden-alias q.typ)
      =/  body  $(typ ~(repo ut typ), seen [[typ nm] seen])
      ?~  alias
        ?.  hidden  body
        ?.  ?=([%tsls [%note * *] *] q.typ)
          [%bad 'a nested collection alias needs source-aware import']
        =/  corrected  (recover-alias q.p.q.typ body)
        ?-  corrected
          [%& *]  p.corrected
          [%| *]  [%bad p.corrected]
        ==
      ?.  ?=([%tsls [%note * *] *] q.typ)
        [%bad 'a Hoon collection alias could not be recovered']
      =/  corrected  (recover-alias q.p.q.typ body)
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
  =/  errors  ?:  =((sample %nested-mop) [%| 'a nested Hoon mop needs source-aware import'])  errors
    ['nested ordered map remains unsupported' errors]
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
  |=  [small=@t epic=@t presence=@t docs=@t shadow=@t]
  ^-  wain
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
      (crip "signed: {(show-result (sample %signed))}")
      (crip "float: {(show-result (sample %float))}")
      (crip "gate: {(show-result (sample %gate-test))}")
      (crip "vase: {(show-result vase)}")
      (crip "failed-branch: {(show-result (read-mold %external %bad bad-branch-fixture))}")
      (crip "valid-cell: {(show-result (sample %valid-cell))}")
      (crip "invalid-cell: {(show-result (sample %invalid-cell))}")
      (crip "chapter-malformed: {?:((chapter-unsafe [%x %y %z] %jar) "unsafe" "wrong")}")
      (crip "chapter-wrapped-malformed: {?:((chapter-unsafe [~ [%x %y %z]] %jar) "unsafe" "wrong")}")
      (crip "chapter-direct-hit: {?:(=((chapter-has chapter-tree %jar) [~ &]) "yes" "no")}")
      (crip "chapter-wrapped-hit: {?:(=((chapter-has [~ chapter-tree] %jar) [~ &]) "yes" "no")}")
      (crip "chapter-direct-miss: {?:(=((chapter-has chapter-tree %jug) [~ &]) "yes" "no")}")
      (crip "chapter-wrapped-miss: {?:(=((chapter-has [~ chapter-tree] %jug) [~ &]) "yes" "no")}")
      (crip "shadow-mop: {(show-result (shad %mm))}")
      (crip "shadow-jar: {(show-result (shad %aa))}")
      (crip "shadow-jug: {(show-result (shad %bb))}")
      (crip "no-provenance: {(show-result (read-mold %small %jar-test (~(play ut sc) (ream '*jar-test'))))}")
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
