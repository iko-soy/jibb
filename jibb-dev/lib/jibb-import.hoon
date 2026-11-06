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
::  a repeated named hold becomes a module-qualified reference. A proven
::  nested self-recursive tagged union retains its own named boundary.
::
::  A direct $^ is read from its original branches and accepted only when
::  their imported shapes prove disjoint. A single nested $^ in a
::  static record is checked by splitting and reassembling its branches;
::  other nested forms and unprovably disjoint cases remain unsupported. Source-level overlap in
::  other unions, general nested ordered maps, broader Ford subject
::  shapes, ambiguous recursive origins and full error locations still
::  need work. One direct union argument to a standard collection is
::  recovered only from its exact call wrapper, static independent cases,
::  proven disjoint branches and unshadowed standard names. Other source
::  shapes fail closed. A nested ordered map is recovered only when its key and
::  value are fixed atom molds and
::  the other fields are fixed atoms or collections of static atoms;
::  other source shapes fail closed.
::
::  The partial checker bridges supported nouns, atoms, cells, faces,
::  proven forks and collections, and keeps proven recursive roots nominal.
::  Unsupported shapes fail closed. Reader failures return %|; no partial
::  tree is returned as success.
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
      [%named module=term name=term body=imported]
      [%apply name=term args=(list imported)]
      [%ref module=term name=term]
      [%param index=@ud]
      [%generic arity=@ud body=imported]
      [%generic-source arity=@ud body=imported at=path source=@t arm=hoon scope=@uvH]
      [%bad reason=@t]
      [%invalid code=?(%aura %core %vase %face) reason=@t]
  ==
+$  import-diagnostic
  $%  [%ok value=imported]
      [%invalid code=?(%aura %core %vase %face %overlap %missing) message=@t]
      [%unsupported message=@t]
  ==
+$  mark-source-span  [beg=[line=@ud col=@ud] end=[line=@ud col=@ud]]
+$  mark-source-origin
  [module=term name=term at=path source=@t site=mark-source-span]
+$  mark-source
  [%mark-source body=imported origin=(unit mark-source-origin)]
+$  mark-source-declaration
  [module=term name=term at=path source=@t arm=hoon]
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
::  When Hoon's expanded type has lost source cases, inspect the exact
::  selected local arm. Restrict this fallback to literal head tags and
::  proven-safe dependencies, then prove projected branches disjoint.
+$  tagged-case  [tag=@ branch=spec]
::  Clay and eval expose different versions of the spec union. Inspect help
::  and source-location wrappers as nouns before checking their contained spec.
++  source-gist-tail
  |=  raw=*
  ^-  (unit *)
  ?:  ?=([%gist [%help *] *] raw)  `+.+.raw
  ?:  ?=([%dbug * *] raw)  `+.+.raw
  ~
::
::  Bound metadata work separately from semantic source-node visits.
++  source-unwrap
  |=  [raw=* left=@ud]
  ^-  (unit *)
  =/  wrapper=(unit *)  (source-gist-tail raw)
  ?~  wrapper  `raw
  ?:  =(left 0)  ~
  $(raw u.wrapper, left (dec left))
::
++  tagged-term
  |=  leaf=spec
  ^-  (unit @)
  =/  plain=(unit *)  (source-unwrap leaf 4)
  ?~  plain  ~
  ?.  ?=([%leaf @ @] u.plain)  ~
  ?.  (lien `(list term)`~[%tas %f %ud] |=(a=term =(a -.+.u.plain)))  ~
  `+.+.u.plain
::
++  tagged-head
  |=  branch=spec
  ^-  (unit @)
  =/  plain=(unit *)  (source-unwrap branch 4)
  ?~  plain  ~
  =.  branch  ;;(spec u.plain)
  ?+  branch  ~
    [%base *]  ?:(|(?=([%atom *] p.branch) =(%null p.branch)) `0 ~)
    [%leaf *]  (tagged-term branch)
    [%bccl *]
      ?~  t.p.branch  ~
      (tagged-term i.p.branch)
  ==
::
++  tagged-cases
  |=  [cases=(list spec) tags=(list @)]
  ^-  (unit (list tagged-case))
  ?~  cases  `~
  ?:  |((has-spec-cell-union i.cases) (has-spec-general-union i.cases))  ~
  =/  tag=(unit @)  (tagged-head i.cases)
  ?~  tag  ~
  =/  rest  $(cases t.cases, tags [u.tag tags])
  ?~  rest  ~
  `[[u.tag i.cases] u.rest]

::
::  Bound the new $? branch screen independently of the existing $% path.
::  Count raw noun nodes across all cases, and cap pairwise tag comparisons.
++  bounded-no-spec-unions
  |=  [h=* fuel=@ud]
  ^-  (unit @ud)
  ?:  =(fuel 0)  ~
  =.  fuel  (dec fuel)
  ?@  h  `fuel
  ?:  ?=([%bckt ^ ^] h)  ~
  ?:  ?=([%bcwt [^ [^ *]]] h)  ~
  ?:  ?=([%bccn [^ [^ *]]] h)  ~
  =/  left=(unit @ud)  $(h -.h)
  ?~  left  ~
  $(h +.h, fuel u.left)
++  tagged-bounded-cases
  |=  [cases=(list spec) tags=(list @) fuel=@ud left=@ud]
  ^-  (unit (list tagged-case))
  ?~  cases  `~
  ?:  =(left 0)  ~
  =/  remaining=(unit @ud)  (bounded-no-spec-unions i.cases fuel)
  ?~  remaining  ~
  =/  tag=(unit @)  (tagged-head i.cases)
  ?~  tag  ~
  =/  rest  $(cases t.cases, tags [u.tag tags], fuel u.remaining, left (dec left))
  ?~  rest  ~
  `[[u.tag i.cases] u.rest]
::
::  Benign source annotations have different typed representations on
::  Clay and under eval. Inspect the wrapper as a noun, and validate the
::  contained Hoon before examining an arm.
++  source-note-tail
  |=  raw=*
  ^-  (unit *)
  ?:  ?=([%note [%help *] *] raw)  `+.+.raw
  ?:  ?=([%dbug * *] raw)  `+.+.raw
  ~
::
++  source-note-unwrap
  |=  [raw=* left=@ud]
  ^-  (unit *)
  =/  wrapper=(unit *)  (source-note-tail raw)
  ?~  wrapper  `raw
  ?:  =(left 0)  ~
  $(raw u.wrapper, left (dec left))
::
::  A bounded $~ source wrapper changes the default, not the mold.
::  Each annotation chain and default chain is separately bounded.
++  tagged-default-union
  |=  [body=spec left=@ud]
  ^-  (unit spec)
  =/  plain=(unit *)  (source-unwrap body 4)
  ?~  plain  ~
  =.  body  ;;(spec u.plain)
  ?.  ?=([%bcsg *] body)  `body
  ?:  =(left 0)  ~
  $(body q.body, left (dec left))
::
++  tagged-source-code
  |=  [code=hoon name=term]
  ^-  (unit (list tagged-case))
  =/  found=(unit spec)  (local-mold-spec code name)
  ?~  found  ~
  =/  body=(unit spec)  (tagged-default-union u.found 4)
  ?~  body  ~
  ?-  u.body
    [%bccn *]
      =/  cases=(list spec)  p.u.body
      ?~  cases  ~
      ?~  t.cases  ~
      (tagged-cases cases ~)
    [%bcwt *]
      =/  cases=(list spec)  p.u.body
      ?~  cases  ~
      ?~  t.cases  ~
      (tagged-bounded-cases cases ~ 4.096 128)
    [%bcpt *]
      =/  first=(unit (list tagged-case))  (tagged-cases ~[p.u.body] ~)
      ?~  first  ~
      =/  raw=(unit *)  (source-unwrap q.u.body 4)
      ?~  raw  ~
      =/  right=spec  ;;(spec u.raw)
      =/  rest=(unit (list tagged-case))
        ?+  right  (tagged-cases ~[right] ~)
          [%bccn *]  (tagged-cases p.right ~)
          [%bcwt *]  (tagged-bounded-cases p.right ~ 4.096 128)
        ==
      ?~  rest  ~
      `(weld u.first u.rest)
    *  ~
  ==
::
::  Source proof for dependencies of an explicitly tagged union. Only
::  simple local molds, standard collections and distinct term enums are
::  accepted; computed molds, nested cell unions and cycles fail closed.
::  One shared fuel budget bounds repeated visits through acyclic aliases;
::  exhaustion or an inherited same-name arm leaves the result unsupported.
++  local-arm-source
  |=  [cor=type name=term]
  ^-  (unit hoon)
  ?.  ?=([%core *] cor)  ~
  =/  chapters=(map term tome)  q.r.q.cor
  =/  all=(list [term tome])  ~(tap by chapters)
  ?:  (lien all |=(e=[term tome] &(!=(-.e %$) (chapter-unsafe +.e name))))  ~
  =/  chapter=(unit tome)  (~(get by chapters) %$)
  ?~  chapter  ~
  (chapter-source u.chapter name)
::
++  local-mold-spec
  |=  [code=hoon name=term]
  ^-  (unit spec)
  =/  plain=(unit *)  (source-note-unwrap code 4)
  ?~  plain  ~
  =.  code  ;;(hoon u.plain)
  ?+  code  ~
    [%ktcl *]
      ?.  ?=([%name * *] p.code)  ~
      ?.  =(name p.p.code)  ~
      `q.p.code
  ==
::
++  source-direct-spec
  |=  code=hoon
  ^-  (unit spec)
  =/  plain=(unit *)  (source-note-unwrap code 4)
  ?~  plain  ~
  =.  code  ;;(hoon u.plain)
  ?+  code  ~
    [%ktcl *]  `p.code
  ==
::
::  Report a repeated record face only when the original Hoon spec proves
::  it. Expanded type graphs can erase nested cell boundaries, so they are
::  not sufficient evidence that two faces came from the same record.
++  source-record-repeat
  |=  [fields=(list spec) names=(list term) fuel=@ud]
  ^-  (unit (unit term))
  ?~  fields  `~
  ?:  =(0 fuel)  ~
  =/  plain=(unit *)  (source-unwrap i.fields 4)
  ?~  plain  ~
  ?.  ?=([%bcts @ *] u.plain)  $(fields t.fields, fuel (dec fuel))
  =/  name=term  ;;(term -.+.u.plain)
  ?:  (lien names |=(n=term =(n name)))  ``name
  $(fields t.fields, names [name names], fuel (dec fuel))
::
++  source-repeat-work
  |=  [pending=(list spec) fuel=@ud]
  ^-  (unit (unit term))
  ?~  pending  `~
  ?:  =(0 fuel)  ~
  =/  plain=(unit *)  (source-unwrap i.pending 4)
  ?~  plain  ~
  =/  shape=spec  ;;(spec u.plain)
  =.  fuel  (dec fuel)
  ?+  shape  $(pending t.pending)
    [%bccl *]
      =/  repeated=(unit (unit term))  (source-record-repeat p.shape ~ fuel)
      ?~  repeated  ~
      ?^  u.repeated  repeated
      $(pending (weld p.shape t.pending))
    [%bcts *]  $(pending [q.shape t.pending])
    [%bcsg *]  $(pending [q.shape t.pending])
    [%bcpt *]  $(pending [p.shape q.shape t.pending])
    [%bckt *]  $(pending [p.shape q.shape t.pending])
    [%bccn *]  $(pending (weld p.shape t.pending))
    [%bcwt *]  $(pending (weld p.shape t.pending))
    [%make *]  $(pending (weld q.shape t.pending))
  ==
::
::  Inline mark samples retain record molds as Hoon cell trees, not specs.
::  Peel annotations and compare only faces that are siblings in one cell.
++  source-hoon-plain
  |=  [raw=* left=@ud]
  ^-  (unit hoon)
  =/  wrapper=(unit *)
    ?:  ?=([%note * *] raw)  `+.+.raw
    ?:  ?=([%dbug * *] raw)  `+.+.raw
    ~
  ?~  wrapper  `;;(hoon raw)
  ?:  =(left 0)  ~
  $(raw u.wrapper, left (dec left))
::
++  source-hoon-fields
  |=  [code=hoon fuel=@ud]
  ^-  (unit (list hoon))
  ?:  =(0 fuel)  ~
  =/  plain=(unit hoon)  (source-hoon-plain code 4)
  ?~  plain  ~
  =.  code  u.plain
  ?@  -.code  `~[code]
  =/  rest=(unit (list hoon))  $(code +.code, fuel (dec fuel))
  ?~  rest  ~
  `[-.code u.rest]
::
++  source-hoon-record-repeat
  |=  [fields=(list hoon) names=(list term) fuel=@ud]
  ^-  (unit (unit term))
  ?~  fields  `~
  ?:  =(0 fuel)  ~
  =/  plain=(unit hoon)  (source-hoon-plain i.fields 4)
  ?~  plain  ~
  ?.  ?=([%ktts @ *] u.plain)  $(fields t.fields, fuel (dec fuel))
  =/  name=term  p.u.plain
  ?:  (lien names |=(n=term =(n name)))  ``name
  $(fields t.fields, names [name names], fuel (dec fuel))
::
++  source-hoon-repeat-work
  |=  [pending=(list hoon) fuel=@ud]
  ^-  (unit (unit term))
  ?~  pending  `~
  ?:  =(0 fuel)  ~
  =/  plain=(unit hoon)  (source-hoon-plain i.pending 4)
  ?~  plain  ~
  =/  shape=hoon  u.plain
  =.  fuel  (dec fuel)
  ?:  ?=([%ktts @ *] shape)  $(pending [q.shape t.pending])
  ?@  -.shape  $(pending t.pending)
  =/  fields=(unit (list hoon))  (source-hoon-fields shape fuel)
  ?~  fields  ~
  =/  repeated=(unit (unit term))
    (source-hoon-record-repeat u.fields ~ fuel)
  ?~  repeated  ~
  ?^  u.repeated  repeated
  $(pending (weld u.fields t.pending))
::
++  source-repeated-field
  |=  [name=term cor=type]
  ^-  (unit (unit term))
  =/  selected=(unit hoon)  (local-arm-source cor name)
  ?~  selected  `~
  =/  shape=(unit spec)  (local-mold-spec u.selected name)
  ?~  shape  `~
  (source-repeat-work ~[u.shape] 4.096)
::
::  A direct mark payload's hold authenticates its own unexpanded mold.
++  hold-repeated-field
  |=  typ=type
  ^-  (unit (unit term))
  =/  raw=type  typ
  |-  ^-  (unit (unit term))
  ?:  ?=([%face *] raw)  $(raw q.raw)
  ?.  ?=([%hold *] raw)  ~
  =/  original=hoon  q.raw
  =/  shape=(unit spec)  (source-direct-spec original)
  ?^  shape  (source-repeat-work ~[u.shape] 4.096)
  (source-hoon-repeat-work ~[original] 4.096)
::
++  type-cell-fields
  |=  typ=type
  ^-  (list type)
  ?:  ?=([%cell *] typ)  [p.typ $(typ q.typ)]
  ~[typ]
::
++  type-face-name
  |=  typ=type
  ^-  (unit term)
  ?.  ?=([%face *] typ)  ~
  ?:  ?=(@tas p.typ)  `p.typ
  ?:  =(~ p.typ)  ~
  =/  head=*  -.p.typ
  =/  name=*  -.head
  ?.  ?=(@tas name)  ~
  `name
::
++  type-sibling-repeat
  |=  [fields=(list type) seen=(list term)]
  ^-  (unit term)
  ?~  fields  ~
  =/  current=type  i.fields
  =/  name=(unit term)  (type-face-name current)
  ?~  name  $(fields t.fields)
  ?:  (lien seen |=(n=term =(n u.name)))  `u.name
  $(fields t.fields, seen [u.name seen])
::
++  type-repeated-field
  |=  typ=type
  ^-  (unit term)
  =/  pending=(list type)  ~[typ]
  =/  fuel=@ud  4.096
  |-  ^-  (unit term)
  ?~  pending  ~
  ?:  =(0 fuel)  ~
  =/  current=type  i.pending
  ?:  ?=([%face *] current)
    $(pending [q.current t.pending], fuel (dec fuel))
  ?.  ?=([%cell *] current)  $(pending t.pending, fuel (dec fuel))
  =/  fields=(list type)  (type-cell-fields current)
  =/  repeated=(unit term)  (type-sibling-repeat fields ~)
  ?^  repeated  repeated
  $(pending (weld fields t.pending), fuel (dec fuel))
::
++  safe-source-enum
  |=  [cases=(list spec) seen=(list @) fuel=@ud]
  ^-  (unit @ud)
  ?~  cases  `fuel
  ?:  =(fuel 0)  ~
  =/  tag=(unit @)  (tagged-term i.cases)
  ?~  tag  ~
  ?:  (lien seen |=(n=@ =(n u.tag)))  ~
  $(cases t.cases, seen [u.tag seen], fuel (dec fuel))
::
++  safe-source-specs-mode
  |=  [xs=(list spec) cor=type seen=(list term) fuel=@ud allow-nested=?]
  ^-  (unit @ud)
  ?~  xs  `fuel
  =/  left=(unit @ud)  (safe-source-spec-mode i.xs cor seen fuel allow-nested)
  ?~  left  ~
  $(xs t.xs, fuel u.left)
::
++  safe-source-name-mode
  |=  [name=term cor=type seen=(list term) fuel=@ud allow-nested=?]
  ^-  (unit @ud)
  ::  Permit a direct root revisit or one proven nested self-revisit.
  ::  Mutual cycles and inherited same-name bindings remain unavailable.
  ?:  (lien seen |=(x=term =(name x)))
    ?.  ?=([%core *] cor)  ~
    ?.  (scope-safe p.cor name)  ~
    ?:  =(seen ~[name])  `fuel
    ?.  allow-nested  ~
    ?.  ?=([* [* ~]] seen)  ~
    ?.  =(i.seen name)  ~
    =/  selected=(unit hoon)  (local-arm-source cor name)
    ?~  selected  ~
    =/  cases=(unit (list tagged-case))  (tagged-source-code u.selected name)
    ?~  cases  ~
    `fuel
  =/  arm=(unit hoon)  (local-arm-source cor name)
  ?~  arm
    ?.  &(|(=(name %ship) =(name %path)) (scope-safe cor name))  ~
    `fuel
  ?.  ?=([%core *] cor)  ~
  ?.  (scope-safe p.cor name)  ~
  =/  body=(unit spec)  (local-mold-spec u.arm name)
  ?~  body  ~
  (safe-source-spec-mode u.body cor [name seen] fuel allow-nested)
::
++  safe-source-spec-mode
  |=  [shape=spec cor=type seen=(list term) fuel=@ud allow-nested=?]
  ^-  (unit @ud)
  =/  plain=(unit *)  (source-unwrap shape 4)
  ?~  plain  ~
  =.  shape  ;;(spec u.plain)
  ?:  =(fuel 0)  ~
  =.  fuel  (dec fuel)
  ?+  shape  ~
    [%base *]  ?:(|(?=([%atom *] p.shape) =(%flag p.shape) =(%null p.shape) =(%noun p.shape)) `fuel ~)
    [%leaf *]  `fuel
    [%bcsg *]  $(shape q.shape)
    [%bcts *]  ?@  p.shape  $(shape q.shape)
               ~
    [%bccl *]  (safe-source-specs-mode p.shape cor seen fuel allow-nested)
    [%bccn *]
      ::  A source proof may cross one named union dependency. Deeper
      ::  named unions stay unsupported to bound recursive reprojection.
      ?.  allow-nested  ~
      ?.  ?=([* [* ~]] seen)  ~
      =/  cases=(unit (list tagged-case))  (tagged-cases p.shape ~)
      ?~  cases  ~
      ?~  u.cases  ~
      ?~  t.u.cases  ~
      (safe-source-tagged-fuel-mode u.cases cor seen fuel allow-nested)
    [%bcwt *]  (safe-source-enum p.shape ~ fuel)
    [%like *]
      ?.  ?=([@ ~] p.shape)  ~
      ?.  ?=(~ q.shape)  ~
      (safe-source-name-mode i.p.shape cor seen fuel allow-nested)
    [%make *]
      =/  wing=(unit term)  (source-single-wing p.shape)
      ?~  wing  ~
      =/  n=term  u.wing
      ?.  (lien `(list term)`~[%map %set %qeu %list %unit %jar %jug] |=(x=term =(x n)))  ~
      ?.  (scope-safe cor n)  ~
      (safe-source-specs-mode q.shape cor seen fuel allow-nested)
  ==
::
++  safe-source-tagged-fuel-mode
  |=  [cases=(list tagged-case) cor=type seen=(list term) fuel=@ud allow-nested=?]
  ^-  (unit @ud)
  ?~  cases  `fuel
  =/  left=(unit @ud)  (safe-source-spec-mode branch.i.cases cor seen fuel allow-nested)
  ?~  left  ~
  $(cases t.cases, fuel u.left)
::
++  safe-source-name
  |=  [name=term cor=type seen=(list term) fuel=@ud]
  ^-  (unit @ud)
  (safe-source-name-mode name cor seen fuel &)
::
++  safe-source-tagged
  |=  [cases=(list tagged-case) cor=type seen=(list term) fuel=@ud]
  ^-  ?
  ?=(^ (safe-source-tagged-fuel-mode cases cor seen fuel &))
::
++  tagged-union-fallback
  |=  [module=term name=term cor=type]
  ^-  (unit (each imported @t))
  ?.  ?=([%core *] cor)  ~
  =/  chapters=(map term tome)  q.r.q.cor
  =/  other=(list [term tome])  ~(tap by chapters)
  ?:  (lien other |=(e=[term tome] &(!=(-.e %$) (chapter-unsafe +.e name))))  ~
  =/  chapter=(unit tome)  (~(get by chapters) %$)
  ?~  chapter  ~
  =/  selected=(unit hoon)  (chapter-source u.chapter name)
  ?~  selected  ~
  =/  cases  (tagged-source-code u.selected name)
  ?~  cases  ~
  ::  Preserve the original budget when no nested union recovery is needed.
  =/  plain=?  ?=(^ (safe-source-tagged-fuel-mode u.cases cor ~[name] 4.096 |))
  ?.  |(plain (safe-source-tagged u.cases cor ~[name] 256))  ~
  =/  tried=(each (list type) tang)
    (mule |.((turn u.cases |=(c=tagged-case (~(play ut cor) [%kttr branch.c])))))
  ?.  ?=([%& *] tried)  ~
  ::  Record the selected hold before projecting branches so an exact
  ::  recursive revisit can retain its independently verified origin.
  =/  selected-type=(each type tang)
    (mule |.((~(play ut cor) (ream (cat 3 '*' name)))))
  ?.  ?=([%& *] selected-type)  ~
  =/  projected=(each (list imported) tang)
    (mule |.((turn p.tried |=(t=type (walk module t catalog ~[[p.selected-type [~ name]]] `cor)))))
  ?.  ?=([%& *] projected)  ~
  ?^  (first-bads p.projected)  ~
  ?.  (all-disjoint p.projected)  ~
  =/  xs=(list tagged-case)  u.cases
  =/  ys=(list imported)  p.projected
  |-
  ?~  xs
    ?^  ys  ~
    `[%& [%fork (sort p.projected |=(pair=[imported imported] (dor -.pair +.pair)))]]
  ?~  ys  ~
  =/  source=(unit *)  (source-unwrap branch.i.xs 4)
  ?~  source  ~
  ?:  ?=([%bccl *] u.source)
    ?.  ?=([%cell [%atom @ [~ @]] *] i.ys)  ~
    ?.  =(tag.i.xs u.value.head.i.ys)  ~
    $(xs t.xs, ys t.ys)
  ?:  ?=([%base [%atom *]] u.source)
    ?.  ?=([%atom @ ~] i.ys)  ~
    $(xs t.xs, ys t.ys)
  ?.  ?=([%atom @ [~ @]] i.ys)  ~
  ?.  =(tag.i.xs u.value.i.ys)  ~
  $(xs t.xs, ys t.ys)

::
::  Check original union branches under one shared source budget.
++  overlap-source-parts
  |=  [parts=(list spec) fuel=@ud left=@ud]
  ^-  (unit @ud)
  ?~  parts  `fuel
  ?:  =(0 left)  ~
  =/  remaining=(unit @ud)  (bounded-no-spec-unions i.parts fuel)
  ?~  remaining  ~
  $(parts t.parts, fuel u.remaining, left (dec left))
++  overlap-source-witness
  |=  [module=term name=term cor=type]
  ^-  ?
  ?.  ?=([%core *] cor)  |
  =/  selected=(unit hoon)  (local-arm-source cor name)
  ?~  selected  |
  =/  shape=(unit spec)  (local-mold-spec u.selected name)
  ?~  shape  |
  =/  body=(unit spec)  (tagged-default-union u.shape 4)
  ?~  body  |
  =/  branches=(unit (list spec))
    ?:  ?=(%bcpt -.u.body)
      =/  cases=(unit (list tagged-case))  (tagged-source-code u.selected name)
      ?~  cases  `~[p.u.body q.u.body]
      `(turn u.cases |=(c=tagged-case branch.c))
    (union-spec-parts u.body)
  ?~  branches  |
  ?~  u.branches  |
  ?~  t.u.branches  |
  =/  budget=(unit @ud)  (overlap-source-parts u.branches 4.096 128)
  ?~  budget  |
  ?.  ?=(^ (safe-source-specs-mode u.branches cor ~[name] u.budget |))  |
  =/  tried=(each (list type) tang)
    (mule |.((turn u.branches |=(branch=spec (~(play ut cor) [%kttr branch])))))
  ?.  ?=([%& *] tried)  |
  =/  projected=(each (list imported) tang)
    (mule |.((turn p.tried |=(t=type (walk module t catalog ~ `cor)))))
  ?.  ?=([%& *] projected)  |
  ?^  (first-bads p.projected)  |
  =/  witness=(unit overlap-proof-result)  (overlap-case-pairs p.projected 4.096)
  ?~  witness  |
  found.u.witness
::
::  Positive overlap evidence only: false means no proof, not disjointness.
::  Fuel is shared across all examined nodes and sibling alternatives.
+$  overlap-proof-result  [found=? left=@ud]
++  overlap-known-atom
  |=  aura=term
  ^-  ?
  (lien `(list term)`~[%t %tas %ud %f] |=(n=term =(n aura)))
++  overlap-inhabited-list
  |=  [xs=(list imported) fuel=@ud]
  ^-  (unit overlap-proof-result)
  ?~  xs  `[| fuel]
  ?:  =(0 fuel)  ~
  =/  one=(unit overlap-proof-result)  (overlap-inhabited i.xs (dec fuel))
  ?~  one  ~
  ?:  found.u.one  one
  $(xs t.xs, fuel left.u.one)
++  overlap-inhabited
  |=  [x=imported fuel=@ud]
  ^-  (unit overlap-proof-result)
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  ?-  x
    [%noun *]  `[& fuel]
    [%void *]  `[| fuel]
    [%atom *]  `[|(?=(^ value.x) (overlap-known-atom aura.x)) fuel]
    [%face *]  $(x body.x)
    [%named *]  $(x body.x)
    [%fork *]  (overlap-inhabited-list cases.x fuel)
    [%cell *]
      =/  a=(unit overlap-proof-result)  $(x head.x)
      ?~  a  ~
      ?.  found.u.a  a
      $(x tail.x, fuel left.u.a)
    *  `[| fuel]
  ==
++  overlap-pair-list
  |=  [xs=(list imported) y=imported fuel=@ud]
  ^-  (unit overlap-proof-result)
  ?~  xs  `[| fuel]
  ?:  =(0 fuel)  ~
  =/  p=(unit overlap-proof-result)  (overlap-pair i.xs y (dec fuel))
  ?~  p  ~
  ?:  found.u.p  p
  $(xs t.xs, fuel left.u.p)
++  overlap-pair
  |=  [a=imported b=imported fuel=@ud]
  ^-  (unit overlap-proof-result)
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  ?:  ?=([%face *] a)  $(a body.a)
  ?:  ?=([%face *] b)  $(b body.b)
  ?:  ?=([%named *] a)  $(a body.a)
  ?:  ?=([%named *] b)  $(b body.b)
  ?:  ?=([%fork *] a)  (overlap-pair-list cases.a b fuel)
  ?:  ?=([%fork *] b)  (overlap-pair-list cases.b a fuel)
  ?:  ?=([%noun *] a)  (overlap-inhabited b fuel)
  ?:  ?=([%noun *] b)  (overlap-inhabited a fuel)
  ?:  &(?=([%cell *] a) ?=([%cell *] b))
    =/  p=(unit overlap-proof-result)  $(a head.a, b head.b)
    ?~  p  ~
    ?.  found.u.p  p
    $(a tail.a, b tail.b, fuel left.u.p)
  ?.  &(?=([%atom *] a) ?=([%atom *] b))  `[| fuel]
  ?^  value.a
    ?^  value.b  `[=(u.value.a u.value.b) fuel]
    `[&(=(u.value.a 0) (overlap-known-atom aura.b)) fuel]
  ?^  value.b  `[&(=(u.value.b 0) (overlap-known-atom aura.a)) fuel]
  `[&((overlap-known-atom aura.a) (overlap-known-atom aura.b)) fuel]
++  overlap-case-pairs
  |=  [xs=(list imported) fuel=@ud]
  ^-  (unit overlap-proof-result)
  ?~  xs  `[| fuel]
  ?:  =(0 fuel)  ~
  =/  p=(unit overlap-proof-result)  (overlap-pair-list t.xs i.xs (dec fuel))
  ?~  p  ~
  ?:  found.u.p  p
  $(xs t.xs, fuel left.u.p)
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
  =/  repeated=(each (unit (unit term)) tang)  (mule |.((source-repeated-field name cor)))
  ?:  ?=(%| -.repeated)  [%| 'Hoon record fields could not be verified']
  ?~  p.repeated  [%| 'Hoon record fields could not be verified']
  ?^  u.p.repeated  [%| (crip "Hoon record repeats field `{(trip u.u.p.repeated)}`")]
  =/  overlap=(each ? tang)  (mule |.((overlap-source-witness module name cor)))
  ?:  &(?=(%& -.overlap) p.overlap)  [%| 'Hoon union cases overlap']
  =/  result  (read-with module name typ [~ cor])
  ?:  ?=([%& *] result)  result
  =/  fallback=(each (unit (each imported @t)) tang)
    (mule |.((tagged-union-fallback module name cor)))
  ?:  ?=(%| -.fallback)  result
  ?~  p.fallback  result
  u.p.fallback
::
::  +read-named is the source-aware entry point for callers that have
::  not selected a Hoon type yet. Check the core and the local arm
::  before invoking Hoon's type engine, which otherwise crashes when
::  the requested name is absent.
::  Recognize only a source-owned wet mold forwarding its formal parameters
::  into unshadowed catalogued standard collection generators.  One shared
::  fuel budget bounds nested applications and metadata traversal.
++  generic-parameter
  |=  [name=term params=(list term) index=@ud]
  ^-  (unit @ud)
  ?~  params  ~
  ?:  =(name i.params)  `index
  $(params t.params, index +(index))
++  generic-parameters-bounded
  |=  [params=(list term) left=@ud]
  ^-  ?
  ?~  params  &
  ?:  =(0 left)  |
  $(params t.params, left (dec left))
++  generic-distinct
  |=  params=(list term)
  ^-  ?
  ?~  params  &
  ?:  (lien t.params |=(name=term =(name i.params)))  |
  $(params t.params)
++  generic-standard-arity
  |=  name=term
  ^-  @ud
  ?:  ?=(?(%list %unit %set %qeu) name)  1
  ?:  ?=(?(%map %jar %jug) name)  2
  0
++  generic-specs-proof
  |=  [parts=(list spec) params=(list term) scope=type fuel=@ud]
  ^-  (unit [nodes=(list imported) left=@ud])
  ?~  parts  `[~ fuel]
  =/  first=(unit [node=imported left=@ud])  (generic-spec-proof i.parts params scope fuel)
  ?~  first  ~
  =/  rest=(unit [nodes=(list imported) left=@ud])  $(parts t.parts, fuel left.u.first)
  ?~  rest  ~
  `[[node.u.first nodes.u.rest] left.u.rest]
++  generic-spec-proof
  |=  [part=spec params=(list term) scope=type fuel=@ud]
  ^-  (unit [node=imported left=@ud])
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  =/  plain=(unit *)  (source-unwrap part 8)
  ?~  plain  ~
  =.  part  ;;(spec u.plain)
  ?+  -.part  ~
    %like
      ?.  ?=([@ ~] p.part)  ~
      ?^  q.part  ~
      =/  idx=(unit @ud)  (generic-parameter `term`i.p.part params 0)
      ?~  idx  ~
      `[[%param u.idx] fuel]
    %make
      =/  target=(unit term)  (source-single-wing p.part)
      ?~  target  ~
      ?:  (lien params |=(n=term =(n u.target)))  ~
      =/  arity=@ud  (generic-standard-arity u.target)
      ?:  =(arity 0)  ~
      ?.  ?:(=(arity 1) ?=([* ~] q.part) ?=([* * ~] q.part))  ~
      ?.  (scope-safe scope u.target)  ~
      =/  args=(unit [nodes=(list imported) left=@ud])  (generic-specs-proof q.part params scope fuel)
      ?~  args  ~
      `[[%apply u.target nodes.u.args] left.u.args]
  ==
++  generic-source-proof-raw
  |=  [name=term scope=type]
  ^-  (unit imported)
  ?.  ?=([%core *] scope)  ~
  ?:  =(scope -:!>(..zuse))  ~
  ?.  (scope-safe scope %$)  ~
  =/  source=(unit hoon)  (local-arm-source scope name)
  ?~  source  ~
  =/  plain=(unit *)  (source-unwrap u.source 8)
  ?~  plain  ~
  ?.  ?=([%brbc * *] u.plain)  ~
  =/  generator=hoon  ;;(hoon u.plain)
  ?>  ?=(%brbc -.generator)
  =/  params=(list term)  `(list term)`sample.generator
  ?~  params  ~
  ?.  (generic-parameters-bounded params 16)  ~
  ?.  (generic-distinct params)  ~
  =/  result=(unit [node=imported left=@ud])  (generic-spec-proof body.generator params scope 512)
  ?~  result  ~
  ?.  ?=(%apply -.node.u.result)  ~
  `[%generic (lent params) node.u.result]
++  generic-source-proof
  |=  [name=term scope=type]
  ^-  (unit imported)
  =/  result=(each (unit imported) tang)  (mule |.((generic-source-proof-raw name scope)))
  ?:  ?=(%| -.result)  ~
  p.result
::
::  This source-bearing entry point verifies the selected core against the
::  exact source, then retains both in the reader evidence.  Source contexts
::  requiring Ford dependencies are not reconstructed here and fail closed.
++  read-generic-source
  |=  [module=term name=term at=path source=@t cor=type]
  ^-  (each imported @t)
  ?.  =(at ~[%sur module %hoon])
    [%| 'Hoon generic source path does not match its imported module']
  =/  rebuilt=(each type tang)  (mule |.(-:(ride -:!>(..zuse) source)))
  ?:  ?=(%| -.rebuilt)  [%| 'Hoon generic source could not be reconstructed']
  ?.  =(p.rebuilt cor)  [%| 'Hoon generic source does not match its selected core']
  =/  proof=(unit imported)  (generic-source-proof name cor)
  ?~  proof  [%| 'Hoon generic collection forwarding is not proven']
  ?.  ?=(%generic -.u.proof)  [%| 'Hoon generic collection forwarding is not proven']
  =/  selected=(unit hoon)  (local-arm-source cor name)
  ?~  selected  [%| 'Hoon generic source arm is unavailable']
  [%& [%generic-source arity.u.proof body.u.proof at source u.selected (sham cor)]]
::
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
::  Fallback for a mark whose sample is exactly one arm of its only
::  Ford-imported /sur core. Source validation remains in read-mold-in.
::  Recursive results need a separate mark-origin/interface design.
++  mark-has-ref
  |=  node=imported
  ^-  ?
  ?-  node
    [%ref *]  &
    [%named *]  $(node body.node)
    [%face *]  $(node body.node)
    [%cell *]  |($(node head.node) $(node tail.node))
    [%fork *]  (lien cases.node |=(child=imported (mark-has-ref child)))
    [%apply *]  (lien args.node |=(child=imported (mark-has-ref child)))
    *  |
  ==
::
++  mark-union-fallback
  |=  [raw=type context=type]
  ^-  (unit (each imported @t))
  ?.  ?=([%cell [%face @ [%core *]] *] context)  ~
  ?.  =(q.context -:!>(..zuse))  ~
  =/  alias=term  p.p.context
  =/  core=type  q.p.context
  ?.  ?=([%hold *] raw)  ~
  =/  name=(unit term)  (hold-name q.raw)
  ?~  name  ~
  =/  selected=(each type tang)
    (mule |.((~(play ut core) (ream (cat 3 '*' u.name)))))
  ?.  ?=([%& *] selected)  ~
  ?.  =(p.selected raw)  ~
  =/  result=(each imported @t)  (read-mold-in alias u.name raw core)
  ?.  ?=([%& [%fork *]] result)  ~
  ?:  (mark-has-ref p.result)  ~
  `result
::
::  A named payload must reselect to the exact hold in its authenticated
::  build core; neither the mark spelling nor the expanded type is evidence.
++  mark-repeated-field
  |=  [raw=type context=type]
  ^-  (unit (unit term))
  =/  direct=(unit (unit term))  (hold-repeated-field raw)
  ?^  direct  direct
  =/  structural=(unit term)  (type-repeated-field raw)
  ?^  structural  `structural
  ?.  ?=([%cell [%face @ [%core *]] *] context)  ~
  ?.  =(q.context -:!>(..zuse))  ~
  =/  core=type  q.p.context
  ?:  =(core -:!>(..zuse))  ~
  ?.  (scope-safe core %$)  ~
  ?.  ?=([%hold *] raw)  ~
  =/  selected-name=(unit term)  (hold-name q.raw)
  ?~  selected-name  ~
  =/  selected=(each type tang)
    (mule |.((~(play ut core) (ream (cat 3 '*' u.selected-name)))))
  ?.  ?=(%& -.selected)  ~
  ?.  =(p.selected raw)  ~
  (source-repeated-field u.selected-name core)
::
++  mark-repeated-field-evidence
  |=  [raw=type context=type]
  ^-  (unit term)
  =/  repeated=(each (unit (unit term)) tang)
    (mule |.((mark-repeated-field raw context)))
  ?.  ?=(%& -.repeated)  ~
  ?~  p.repeated  ~
  u.p.repeated
::
++  read-mark
  |=  [name=term cor=type]
  ^-  (each imported @t)
  ?.  ?=([%core *] cor)  [%| 'Hoon mark provenance is unavailable']
  ?.  ?=([%cell *] p.cor)  [%| 'Hoon mark sample is unavailable']
  ?.  =(p.cor q.q.cor)  [%| 'Hoon mark provenance is unavailable']
  ?.  (scope-safe q.p.cor %$)  [%| 'Hoon mark provenance is unavailable']
  =/  sample=type  p.p.cor
  =/  raw=type  ?:(?=([%face *] sample) q.sample sample)
  =/  field=(unit term)  (mark-repeated-field-evidence raw q.p.cor)
  ?^  field
    [%| (crip "Hoon record repeats field `{(trip u.field)}`")]
  =/  result  (read-with name name raw [~ q.p.cor])
  ?:  ?=([%& *] result)  result
  =/  fallback=(each (unit (each imported @t)) tang)
    (mule |.((mark-union-fallback raw q.p.cor)))
  ?:  ?=(%| -.fallback)  result
  ?~  p.fallback  result
  u.p.fallback
::
++  read-named-diagnostic
  |=  [module=term name=term cor=type]
  ^-  import-diagnostic
  =/  result=(each imported @t)  (read-named module name cor)
  =/  field=(unit term)
    ?.  &(?=([%core *] cor) !=(cor -:!>(..zuse)) (scope-safe cor %$))  ~
    =/  repeated=(each (unit (unit term)) tang)  (mule |.((source-repeated-field name cor)))
    ?.  ?=(%& -.repeated)  ~
    ?~  p.repeated  ~
    u.p.repeated
  ?^  field
    [%invalid %face (crip "Hoon record repeats field `{(trip u.field)}`")]
  ?:  ?=(%& -.result)  [%ok p.result]
  ?.  ?=([%core *] cor)  [%unsupported p.result]
  ?:  =(cor -:!>(..zuse))  [%unsupported p.result]
  ?.  (scope-safe cor %$)  [%unsupported p.result]
  =/  chapters=(map term tome)  q.r.q.cor
  ?.  (lien ~(tap by chapters) |=(entry=[term tome] =((chapter-has +.entry name) [~ &])))
    [%invalid %missing p.result]
  =/  selected=(each type tang)  (mule |.((~(play ut cor) (ream (cat 3 '*' name)))))
  ?.  ?=(%& -.selected)  [%unsupported p.result]
  =/  overlap=(each ? tang)  (mule |.((overlap-source-witness module name cor)))
  ?:  &(?=(%& -.overlap) p.overlap)  [%invalid %overlap 'Hoon union cases overlap']
  =/  again=(each imported tang)  (mule |.((walk module p.selected catalog ~ [~ cor])))
  ?.  ?=(%& -.again)  [%unsupported p.result]
  =/  evidence=(unit import-diagnostic)  (first-invalid p.again)
  ?~  evidence  [%unsupported p.result]
  u.evidence
::
++  mark-source-declaration-of  |=  [input=[module=term at=path source=@t] raw=type context=type]
  ^-  (unit mark-source-declaration)
  ?.  =(at.input ~[%sur module.input %hoon])  ~
  =/  rebuilt=(each type tang)
    (mule |.(-:(ride -:!>(..zuse) source.input)))
  ?:  ?=(%| -.rebuilt)  ~
  ?.  ?=([%core *] p.rebuilt)  ~
  ?:  =(p.rebuilt -:!>(..zuse))  ~
  ?.  (scope-safe p.rebuilt %$)  ~
  ?.  ?=([%cell [%face @ [%core *]] *] context)  ~
  ?.  =(p.p.context module.input)  ~
  ?.  ?=([%hold *] raw)  ~
  =/  selected-name=(unit term)  (hold-name q.raw)
  ?~  selected-name  ~
  =/  arm=(unit hoon)  (local-arm-source p.rebuilt u.selected-name)
  ?~  arm  ~
  =/  selected=(each type tang)
    (mule |.((~(play ut p.rebuilt) (ream (cat 3 '*' u.selected-name)))))
  ?:  ?=(%| -.selected)  ~
  =/  selected-import=(each imported @t)  (read-mold module.input u.selected-name p.selected)
  ?:  ?=(%| -.selected-import)  ~
  =/  raw-import=(each imported @t)  (read-mold module.input u.selected-name raw)
  ?:  ?=(%| -.raw-import)  ~
  ?.  =(p.selected-import p.raw-import)  ~
  `[module.input u.selected-name at.input source.input u.arm]
::
++  mark-source-declarations
  |=  [inputs=(list [module=term at=path source=@t]) raw=type context=type]
  ^-  (list mark-source-declaration)
  ?~  inputs  ~
  =/  first=(unit mark-source-declaration)
    (mark-source-declaration-of i.inputs raw context)
  =/  rest=(list mark-source-declaration)
    $(inputs t.inputs)
  ?~  first  rest
  [u.first rest]
::
++  mark-declaration-spots
  |=  [code=hoon name=term spots=(list spot) left=@ud]
  ^-  (unit (list spot))
  ?+  code  ~
    [%dbug *]
      ?:  =(left 0)  ~
      $(code q.code, spots [p.code spots], left (dec left))
    [%note *]
      =/  inner=(unit *)  (source-note-tail code)
      ?~  inner  ~
      ?:  =(left 0)  ~
      $(code ;;(hoon u.inner), left (dec left))
    [%ktcl *]
      ?~  (local-mold-spec code name)  ~
      `spots
  ==
::
++  mark-declaration-site
  |=  declaration=mark-source-declaration
  ^-  (unit mark-source-span)
  =/  spots=(unit (list spot))
    (mark-declaration-spots arm.declaration name.declaration ~ 8)
  ?~  spots  ~
  ?~  u.spots  ~
  =/  first=spot  i.u.spots
  ?.  (levy t.u.spots |=(item=spot =(item first)))  ~
  ?.  =(p.first at.declaration)  ~
  `q.first
::
++  mark-source-prefix
  |=  [prefix=tape text=tape]
  ^-  ?
  ?~  prefix  &
  ?~  text  |
  ?:  =(i.prefix i.text)  $(prefix t.prefix, text t.text)
  |
::
++  mark-source-drop
  |=  [count=@ud text=tape]
  ^-  tape
  ?:  =(0 count)  text
  ?~  text  ~
  $(count (dec count), text t.text)
::
++  mark-source-after-space
  |=  [rest=tape col=@ud wanted=tape]
  ^-  (unit @ud)
  ?~  rest  ~
  ?:  =(' ' i.rest)  $(rest t.rest, col +(col))
  ?.  (mark-source-prefix wanted rest)  ~
  =/  tail=tape  (mark-source-drop (lent wanted) rest)
  ?~  tail  `col
  ?.  =(' ' i.tail)  ~
  `col
::
++  mark-source-line-site
  |=  [line=tape wanted=tape]
  ^-  (unit @ud)
  =/  col=@ud  1
  |-
  ?~  line  ~
  ?:  =(' ' i.line)  $(line t.line, col +(col))
  ?.  (mark-source-prefix "+$" line)  ~
  =/  rest=tape  (mark-source-drop 2 line)
  =.  col  (add col 2)
  ?~  rest  ~
  ?.  =(' ' i.rest)  ~
  (mark-source-after-space rest col wanted)
::
++  mark-source-text-site
  |=  [source=@t name=term]
  ^-  (unit mark-source-span)
  =/  lines=wain  (to-wain:format source)
  =/  wanted=tape  (trip name)
  =/  number=@ud  1
  =/  found=(list mark-source-span)  ~
  |-
  ?~  lines  ?:(?=([* ~] found) `i.found ~)
  =/  hit=(unit @ud)  (mark-source-line-site (trip i.lines) wanted)
  =/  rest=(unit mark-source-span)  $(lines t.lines, number +(number))
  ?~  hit  rest
  =/  site=mark-source-span  [[number u.hit] [number u.hit]]
  $(lines t.lines, number +(number), found [site found])
::
++  mark-source-origin-of  |=  [sources=(list [module=term at=path source=@t]) cor=type]
  ^-  (unit mark-source-origin)
  ?.  ?=([%core *] cor)  ~
  ?.  ?=([%cell *] p.cor)  ~
  =/  sample=type  p.p.cor
  =/  raw=type  ?:(?=([%face *] sample) q.sample sample)
  =/  declarations=(list mark-source-declaration)
    (mark-source-declarations sources raw q.p.cor)
  ?.  ?=([* ~] declarations)  ~
  =/  declaration=mark-source-declaration  i.declarations
  =/  site=(unit mark-source-span)
    =/  debug=(unit mark-source-span)  (mark-declaration-site declaration)
    ?^  debug  debug
    (mark-source-text-site source.declaration name.declaration)
  ?~  site  ~
  `[module.declaration name.declaration at.declaration source.declaration u.site]
::
++  read-mark-source
  |=  [name=term sources=(list [module=term at=path source=@t]) cor=type]
  ^-  (each mark-source @t)
  =/  result=(each imported @t)  (read-mark name cor)
  ?:  ?=(%| -.result)  [%| p.result]
  =/  attempted=(each (unit mark-source-origin) tang)
    (mule |.((mark-source-origin-of sources cor)))
  =/  origin=(unit mark-source-origin)
    ?:  ?=(%& -.attempted)  p.attempted
    ~
  [%& [%mark-source p.result origin]]
::
++  read-mark-diagnostic
  |=  [name=term cor=type]
  ^-  import-diagnostic
  =/  result=(each imported @t)  (read-mark name cor)
  ?:  ?=(%& -.result)  [%ok p.result]
  ?.  ?=([%core *] cor)  [%unsupported p.result]
  ?.  ?=([%cell *] p.cor)  [%unsupported p.result]
  ?.  =(p.cor q.q.cor)  [%unsupported p.result]
  ?.  (scope-safe q.p.cor %$)  [%unsupported p.result]
  =/  sample=type  p.p.cor
  =/  raw=type  ?:(?=([%face *] sample) q.sample sample)
  =/  field=(unit term)  (mark-repeated-field-evidence raw q.p.cor)
  ?^  field
    [%invalid %face (crip "Hoon record repeats field `{(trip u.field)}`")]
  =/  again=(each imported tang)  (mule |.((walk name raw catalog ~ [~ q.p.cor])))
  ?.  ?=(%& -.again)  [%unsupported p.result]
  =/  evidence=(unit import-diagnostic)  (first-invalid p.again)
  ?~  evidence  [%unsupported p.result]
  u.evidence
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
::  The Grammar's disjointness rule applies to imported $% and $? too;
::  @iko confirmed the rule for imported unions on 2026-10-30.
++  has-spec-general-union
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  ?=([%bcwt [^ [^ *]]] h)  &
  ?:  ?=([%bccn [^ [^ *]]] h)  &
  |($(h -.h) $(h +.h))
::
++  has-fits-union
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  ?=([%wtcl [%fits *] * *] h)  &
  |($(h -.h) $(h +.h))
::
++  fits-union-at
  |=  [h=hoon axis=@ud]
  ^-  ?
  ?.  ?=([%fits *] h)  |
  |(=(q.h ~[[%.y axis]]) =(q.h ~[[%.y (mul 2 axis)]]))
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
    [%dbug *]  $(h q.h)
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
    [%dbug *]  $(h q.h)
    [%ktts *]  $(h q.h)
    [%ktls *]  ?=([%sand *] p.h)
    [%cncl *]
      ?:  =(h [%cncl [%tsgr [%wing ~[[%.y 7]]] [%wing ~[%path]]] ~[[%$ axis]]])  &
      (static-collection h)
    [%wtcl *]
      ?.  (fits-union-at p.h axis)  |
      &($(h q.h) $(h r.h))
    [%wtgr *]
      ?:  =(h [%wtgr [%dtts [%bust %noun] [%$ axis]] [%rock %n 0]])  &
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
    [%dbug *]
      =/  out  $(h q.h)
      ?~  out  ~
      [~ [h(q one.u.out) h(q two.u.out)]]
    [%ktts *]
      =/  out  $(h q.h)
      ?~  out  ~
      [~ [h(q one.u.out) h(q two.u.out)]]
    [%wtcl *]
      ?.  |(=(p.h [%dtwt [%$ (mul 2 axis)]]) (fits-union-at p.h axis))  ~
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
    [%dbug *]  $(h q.h)
    [%ktts *]
      ?.  &(?=([%face *] a) ?=([%face *] b))
        [%| 'a nested Hoon $^ union needs a source-level disjointness check']
      ?.  &(=(p.h name.a) =(p.h name.b))
        [%| 'a nested Hoon $^ union needs a source-level disjointness check']
      =/  child  $(h q.h, a body.a, b body.b)
      ?.  ?=([%& *] child)  child
      [%& [%face name.a p.child]]
    [%wtcl *]
      ?.  |(=(p.h [%dtwt [%$ (mul 2 axis)]]) (fits-union-at p.h axis))
        [%| 'a Hoon union needs a source-level disjointness check']
      ?.  (disjoint a b)
        ?:  ?=([%fits *] p.h)  [%| 'Hoon union disjointness could not be verified']
        [%| 'Hoon $^ union disjointness could not be verified']
      [%& [%fork (sort (weld (union-cases a) (union-cases b)) |=(pair=[imported imported] (dor -.pair +.pair)))]]
  ==
++  union-cases
  |=  a=imported
  ^-  (list imported)
  ?.  ?=([%fork *] a)  ~[a]
  (zing (turn cases.a |=(item=imported (union-cases item))))
::
++  all-disjoint
  |=  cases=(list imported)
  ^-  ?
  ?~  cases  &
  ?.  (levy t.cases |=(item=imported (disjoint i.cases item)))  |
  $(cases t.cases)
::
++  disjoint
  |=  [a=imported b=imported]
  ^-  ?
  ?:  ?=([%face *] a)  $(a body.a)
  ?:  ?=([%face *] b)  $(b body.b)
  ?:  ?=([%named *] a)  $(a body.a)
  ?:  ?=([%named *] b)  $(b body.b)
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
::  Return a unique source arm from either validated tome wrapper. Walk
::  the noun map rather than relying on fields that differ on Clay.
++  arm-map-sources
  |=  [m=* target=term]
  ^-  (list hoon)
  ?@  m  ~
  =/  kv=*  -.m
  =/  children=*  +.m
  =/  found=(list hoon)  ?:(=(-.kv target) ~[;;(hoon +.kv)] ~)
  (weld found (weld $(m -.children) $(m +.children)))
::
++  chapter-source
  |=  [chapter=* target=term]
  ^-  (unit hoon)
  ?:  (arm-map-valid chapter)  (unique-arm-source chapter target)
  ?@  chapter  ~
  ?.  (arm-map-valid +.chapter)  ~
  (unique-arm-source +.chapter target)
::
++  unique-arm-source
  |=  [arms=* target=term]
  ^-  (unit hoon)
  =/  sources=(list hoon)  (arm-map-sources arms target)
  ?.  ?=([* ~] sources)  ~
  `i.sources
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
++  scope-safe-base
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
::  A selected Hoon hold may belong to a core inherited by the trusted
::  standard subject. Identify that core by exact noun identity, with one
::  shared traversal budget; arbitrary source cores are not trusted.
++  standard-ancestor
  |=  [wanted=type scope=type fuel=@ud]
  ^-  (unit [found=? left=@ud])
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  ?:  =(wanted scope)  `[& fuel]
  ?-  scope
    [%core *]  $(scope p.scope)
    [%cell *]
      =/  first=(unit [found=? left=@ud])  $(scope p.scope)
      ?~  first  ~
      ?:  found.u.first  first
      $(scope q.scope, fuel left.u.first)
    [%face *]  $(scope q.scope)
    *  `[| fuel]
  ==
::
++  scope-safe
  |=  [scope=type target=term]
  ^-  ?
  ?:  (scope-safe-base scope target)  &
  ?.  ?=([%core *] scope)  |
  =/  trusted=(unit [found=? left=@ud])
    (standard-ancestor scope -:!>(..zuse) 4.096)
  ?~  trusted  |
  found.u.trusted
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
::  Clay can wrap each call component in source-location metadata.
::  Peel only those wrappers; malformed casts are trapped by +mop-specs.
++  mop-source-code
  |=  code=hoon
  ^-  hoon
  =/  plain=(unit *)  (source-unwrap code 4)
  ?~  plain  !!
  ;;(hoon u.plain)
::
++  source-single-wing
  |=  raw=*
  ^-  (unit term)
  =/  plain=(unit *)  (source-unwrap raw 4)
  ?~  plain  ~
  ?.  ?=([%wing [@ ~]] u.plain)  ~
  `;;(term -.+.u.plain)
::
++  mop-specs-raw
  |=  body=hoon
  ^-  (unit [key=spec value=spec])
  =.  body  (mop-source-code body)
  ?.  ?=([%cncl *] body)  ~
  ?.  ?=([%tsgr *] p.body)  ~
  =/  b=hoon  (mop-source-code q.p.body)
  ?.  ?=([%cncl *] b)  ~
  =/  call=hoon  (mop-source-code p.b)
  ?.  ?=([%cncl *] call)  ~
  =/  w=(unit term)  (source-single-wing p.call)
  ?~  w  ~
  ?.  =(u.w %mop)  ~
  =/  raw=*  q.call
  =/  wings=(unit [key=spec value=spec])
    ?.  ?=([* [* ~]] raw)  ~
    =/  a=(unit term)  (source-single-wing -.raw)
    =/  b=(unit term)  (source-single-wing -.+.raw)
    ?~  a  ~
    ?~  b  ~
    [~ [[%like ~[u.a] ~] [%like ~[u.b] ~]]]
  ?^  wings  wings
  =/  specs=(list spec)  ;;((list spec) raw)
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
  =/  standard=(unit [found=? left=@ud])  (standard-ancestor u.context -:!>(..zuse) 4.096)
  =/  canonical=?
    ?~  standard  |
    ?.  found.u.standard  |
    =/  source=(unit hoon)  (local-arm-source u.context name)
    ?~  source  |
    =/  selected=(each type tang)  (mule |.((~(play ut u.context) (ream (cat 3 '*' name)))))
    &(?=(%& -.selected) =(p.selected typ))
  ?:  canonical  [~ %$]
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
::
::  A collection case is independent of the subject only when its
::  original spec uses literal atoms, tags and finite record structure.
++  static-union-spec
  |=  s=spec
  ^-  ?
  ?+  s  |
    [%base *]  ?=([%atom *] p.s)
    [%leaf *]  &
    [%bcts *]  ?@  p.s  $(s q.s)
               |
    [%bccl *]  (static-union-specs p.s)
  ==
::
++  static-union-specs
  |=  parts=(list spec)
  ^-  ?
  ?~  parts  &
  &((static-union-spec i.parts) $(parts t.parts))
::
++  union-spec-parts
  |=  s=spec
  ^-  (unit (list spec))
  ?+  s  ~
    [%bcwt *]  [~ p.s]
    [%bccn *]  [~ p.s]
    [%bckt *]  [~ ~[p.s q.s]]
  ==
::
::  Select one direct union argument, replacing exactly that spec with
::  @t. The other arguments must be static and cannot contain unions.
++  safe-union-parts
  |=  cases=(list spec)
  ^-  ?
  ?~  cases  |
  ?~  t.cases  |
  =/  rest=(list spec)  t.cases
  &((static-union-spec i.cases) (levy rest |=(part=spec (static-union-spec part))))
::
++  split-union-arguments
  |=  [args=(list hoon) index=@ud]
  ^-  (unit [args=(list hoon) cases=(list spec) index=@ud])
  ?~  args  ~
  ?.  ?=([%ktcl *] i.args)  ~
  =/  cases  (union-spec-parts p.i.args)
  ?^  cases
    ?.  (safe-union-parts u.cases)  ~
    ?.  (static-arguments t.args)  ~
    [~ [[[%ktcl [%base [%atom %t]]] t.args] u.cases index]]
  ?.  (static-spec p.i.args)  ~
  =/  rest  $(args t.args, index +(index))
  ?~  rest  ~
  [~ [[i.args args.u.rest] cases.u.rest index.u.rest]]
::
++  replace-union-argument
  |=  [args=(list imported) index=@ud union=imported]
  ^-  (unit (list imported))
  ?~  args  ~
  ?:  =(index 0)
    ?.  =([%atom %t ~] i.args)  ~
    [~ [union t.args]]
  =/  rest  $(args t.args, index (dec index))
  ?~  rest  ~
  [~ [i.args u.rest]]
::
::  Accept only the compiler's direct collection call wrapper.
++  direct-collection-source
  |=  [body=hoon original=hoon]
  ^-  ?
  ?.  ?=([%cncl [%tsgr * [%cncl *]] *] body)  |
  ?.  =(p.p.body [%wing ~[[%.y 7]]])  |
  ?.  =(q.body ~[[%$ 6]])  |
  ?.  ?=([%tsls * *] original)  |
  =(q.original [%tsls [%dtts [%$ 14] [%$ 2]] [%$ 6]])
::
++  collection-union
  |=  [typ=type module=term sig=signatures seen=visiting context=(unit type)]
  ^-  imported
  ?.  ?=([%hold *] typ)  [%bad 'a Hoon union needs a source-level disjointness check']
  =/  is-cell=?  (has-spec-cell-union q.typ)
  =/  unsupported=@t
    ?:  is-cell  'a Hoon $^ union needs a source-level disjointness check'
    'a Hoon union needs a source-level disjointness check'
  =/  original=hoon  q.typ
  ?.  ?=([%tsls [%note * *] *] original)  [%bad unsupported]
  =/  body=hoon  q.p.original
  =/  alias  (source-alias body)
  ?~  alias  [%bad unsupported]
  ?.  (alias-safe context u.alias)  [%bad 'Hoon collection provenance is unavailable or shadowed']
  =/  names=(list term)  ~[%map %set %qeu %list %unit %jar %jug]
  ?:  (lien names |=(n=term &((source-uses body n) !(alias-safe context n))))
    [%bad 'Hoon collection provenance is unavailable or shadowed']
  ?.  (direct-collection-source body original)  [%bad unsupported]
  ?>  ?=([%cncl [%tsgr * [%cncl *]] *] body)
  =/  split  (split-union-arguments q.q.p.body 0)
  ?~  split  [%bad unsupported]
  =/  tried=(each (list type) tang)
    (mule |.((turn cases.u.split |=(s=spec (~(play ut p.typ) [%kttr s])))))
  ?.  ?=([%& *] tried)  [%bad unsupported]
  =/  cases=(list imported)
    (turn p.tried |=(t=type (walk module t sig seen context)))
  =/  err  (first-bads cases)
  ?^  err  [%bad u.err]
  ?.  (all-disjoint cases)
    [%bad ?:(is-cell 'Hoon $^ union disjointness could not be verified' 'Hoon union disjointness could not be verified')]
  =/  rewritten=hoon  original(q.p body(q.q.p args.u.split))
  =/  attempt=(each type tang)  (mule |.((~(play ut p.typ) rewritten)))
  ?.  ?=([%& *] attempt)  [%bad unsupported]
  =/  out=imported  (walk module p.attempt sig seen context)
  ?.  ?=([%apply *] out)  [%bad unsupported]
  ?.  =(name.out u.alias)  [%bad unsupported]
  =/  replacement=imported
    [%fork (sort cases |=(pair=[imported imported] (dor -.pair +.pair)))]
  =/  args  (replace-union-argument args.out index.u.split replacement)
  ?~  args  [%bad unsupported]
  [%apply name.out u.args]
::
::  The standard each mold is a union of two differently tagged cells.
::  Recover its two arguments from the verified direct application rather
::  than trusting a fork Hoon may have simplified. Their own source molds
::  must pass the same dependency checks as other imported union cases.
++  standard-each-arguments
  |=  [typ=type context=(unit type)]
  ^-  (unit [type type])
  ?.  ?=([%hold *] typ)  ~
  ?~  context  ~
  ?.  (alias-safe context %each)  ~
  =/  original=hoon  q.typ
  ?.  ?=([%tsls [%note * *] *] original)  ~
  =/  body=hoon  q.p.original
  ?.  (direct-collection-source body original)  ~
  ?.  ?=([%cncl [%tsgr * [%cncl *]] *] body)  ~
  =/  call=hoon  q.p.body
  ?.  ?=([%cncl [%wing [%each ~]] [* [* ~]]] call)  ~
  =/  args=(list hoon)  q.call
  ?.  ?=([[%ktcl *] [[%ktcl *] ~]] args)  ~
  =/  a=spec  p.i.args
  =/  b=spec  p.i.t.args
  ?.  ?=(^ (safe-source-spec-mode a u.context ~ 4.096 &))  ~
  ?.  ?=(^ (safe-source-spec-mode b u.context ~ 4.096 &))  ~
  `[(~(play ut p.typ) [%kttr a]) (~(play ut p.typ) [%kttr b])]
::
::  A nested named tagged union may be recovered only if its hold is
::  exactly the selected arm of this core. Provenance and all original
::  source cases are checked by the same fallback as a top-level arm.
++  inherited-source-owner
  |=  [scope=type name=term wanted=type fuel=@ud]
  ^-  (unit type)
  ?:  =(0 fuel)  ~
  =.  fuel  (dec fuel)
  ?-  scope
    [%core *]
      =/  source=(unit hoon)  (local-arm-source scope name)
      =/  match=?
        ?~  source  |
        =/  selected=(each type tang)
          (mule |.((~(play ut scope) (ream (cat 3 '*' name)))))
        &(?=(%& -.selected) =(p.selected wanted))
      ?:  match  `scope
      $(scope p.scope)
    [%cell *]
      =/  left=(unit type)  $(scope p.scope)
      ?^  left  left
      $(scope q.scope)
    [%face *]  $(scope q.scope)
    *  ~
  ==
::
++  nested-tagged-union
  |=  [module=term typ=type context=(unit type)]
  ^-  (unit imported)
  ?~  context  ~
  ?.  ?=([%core *] u.context)  ~
  ?.  ?=([%hold *] typ)  ~
  =/  n=(unit term)  (hold-name q.typ)
  ?~  n  ~
  ::  The outer proof has a shared budget. Bound each nested re-proof as
  ::  well, so rebuilding a shared source DAG cannot grow without limit.
  =/  local=(unit hoon)  (local-arm-source u.context u.n)
  =/  owner=(unit type)
    ?^  local  `u.context
    ?.  (scope-safe u.context u.n)  ~
    =/  inherited=(unit type)  (inherited-source-owner p.typ u.n typ 128)
    ?~  inherited  ~
    =/  standard=(unit [found=? left=@ud])  (standard-ancestor u.inherited -:!>(..zuse) 4.096)
    ?~  standard  ~
    ?.  found.u.standard  ~
    inherited
  ?~  owner  ~
  =/  source=(unit hoon)  (local-arm-source u.owner u.n)
  ?~  source  ~
  =/  cases=(unit (list tagged-case))  (tagged-source-code u.source u.n)
  ?~  cases  ~
  ?.  (safe-source-tagged u.cases u.owner ~[u.n] 256)  ~
  =/  selected=(each type tang)
    (mule |.((~(play ut u.owner) (ream (cat 3 '*' u.n)))))
  ?.  ?=([%& *] selected)  ~
  ?.  =(p.selected typ)  ~
  =/  standard=(unit [found=? left=@ud])  (standard-ancestor u.owner -:!>(..zuse) 4.096)
  =/  origin=term  ?~(standard module ?:(found.u.standard %$ module))
  =/  attempt=(each (unit (each imported @t)) tang)
    (mule |.((tagged-union-fallback origin u.n u.owner)))
  ?.  ?=([%& *] attempt)  ~
  ?~  p.attempt  ~
  ?.  ?=([%& [%fork *]] u.p.attempt)  ~
  ?:  =(module origin)  `p.u.p.attempt
  `[%named origin u.n p.u.p.attempt]
::
::  Keep the proven owner boundary when a nested union refers to itself.
++  contains-named-ref
  |=  [node=imported module=term name=term]
  ^-  ?
  ?-  node
    [%ref *]  &(=(module module.node) =(name name.node))
    [%named *]  |
    [%face *]  $(node body.node)
    [%cell *]  |($(node head.node) $(node tail.node))
    [%fork *]  (lien cases.node |=(child=imported (contains-named-ref child module name)))
    [%apply *]  (lien args.node |=(child=imported (contains-named-ref child module name)))
    *  |
  ==
::
++  walk
  |=  [module=term typ=type sig=signatures seen=visiting context=(unit type)]
  ^-  imported
  ?-  typ
    %noun  [%noun ~]
    %void  [%void ~]
    [%atom *]
      ?:  |(=('s' (cut 3 [0 1] p.typ)) =('r' (cut 3 [0 1] p.typ)))
        [%invalid %aura 'signed and float auras cannot be imported']
      [%atom p.typ q.typ]
    [%cell *]  [%cell $(typ p.typ) $(typ q.typ)]
    [%core *]  [%invalid %core 'cores and gates cannot be imported']
    [%face *]
      ?@  p.typ  [%face p.typ $(typ q.typ)]
      [%bad 'a complex Hoon face needs translation']
    [%fork *]
      =/  cases=(list imported)
        (turn ~(tap in:..zuse p.typ) |=(t=type ^$(typ t)))
      =/  err  (first-bads cases)
      ?^  err  [%bad u.err]
      ?.  (all-disjoint cases)  [%bad 'Hoon union disjointness could not be verified']
      [%fork (sort cases |=(pair=[imported imported] (dor -.pair +.pair)))]
    [%hint *]  $(typ q.typ)
    [%hold *]
      =/  prior=(unit (unit term))  (find-seen typ seen)
      ?^  prior
        ?~  u.prior  [%bad 'an anonymous recursive Hoon mold cannot be named']
        =/  origin  (ref-origin module u.u.prior typ context)
        ?~  origin  [%bad 'a recursive Hoon mold needs unambiguous source provenance']
        [%ref u.origin u.u.prior]
      =/  nested=(unit imported)  (nested-tagged-union module typ context)
      ?^  nested
        ?:  ?=(~ seen)  u.nested
        =/  name=(unit term)  (hold-name q.typ)
        ?~  name  u.nested
        ?.  (contains-named-ref u.nested module u.name)  u.nested
        [%named module u.name u.nested]
      =/  each-attempt=(each (unit [type type]) tang)
        (mule |.((standard-each-arguments typ context)))
      =/  each-args=(unit [type type])  ?:(?=(%& -.each-attempt) p.each-attempt ~)
      ?^  each-args
        =/  a=imported  $(typ -.u.each-args, seen [[typ ~] seen])
        =/  b=imported  $(typ +.u.each-args, seen [[typ ~] seen])
        =/  err=(unit @t)  (first-bads ~[a b])
        ?^  err  [%bad u.err]
        [%fork ~[[%cell [%atom %f `0] [%face %p a]] [%cell [%atom %f `1] [%face %p b]]]]
      ?:  &(?=([%tsls [%note * *] *] q.typ) |((has-spec-cell-union q.typ) (has-spec-general-union q.typ)))
        =/  nm  (hold-name q.typ)
        (collection-union typ module sig [[typ nm] seen] context)
      =/  named=(unit term)  (match-signature q.typ sig)
      ?^  named
        =/  name  u.named
        ?:  =(%vase name)  [%invalid %vase 'vases cannot be imported']
        ?.  (alias-safe context name)
          [%bad 'Hoon collection provenance is unavailable or shadowed']
        =/  first=type
          (~(play ut p.typ) (ream ?:(|(=(%map name) =(%jar name) =(%jug name)) '*key' '*item')))
        =/  first-import  $(typ first)
        ?:  |(=(%map name) =(%jar name) =(%jug name))
          =/  second=type  (~(play ut p.typ) (ream '*value'))
          [%apply name ~[first-import $(typ second)]]
        [%apply name ~[first-import]]
      =/  nm  (hold-name q.typ)
      ?:  =(nm [~ %vase])  [%bad 'a Hoon type named vase needs source provenance']
      ?:  &((source-uses q.typ %jar) !(alias-safe context %jar))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      ?:  &((source-uses q.typ %jug) !(alias-safe context %jug))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      ?:  &((source-uses q.typ %mop) !(alias-safe context %mop))
        [%bad 'Hoon collection provenance is unavailable or shadowed']
      =/  mop  (mop-arguments typ)
      ?^  mop
        ::  An exact revisit fails closed without guessing a name.
        [%apply %mop ~[$(typ key.u.mop, seen [[typ ~] seen]) $(typ value.u.mop, seen [[typ ~] seen])]]
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
        [%bad 'Hoon $^ union disjointness could not be verified']
      ?:  |((has-cell-union q.typ) (has-fits-union q.typ))
        =/  cannot=@t
          ?:  (has-fits-union q.typ)  'a Hoon union needs a source-level disjointness check'
          'a Hoon $^ union needs a source-level disjointness check'
        =/  checked-names=(list term)  ~[%map %set %qeu %list %unit %jar %jug %path]
        ?:  (lien checked-names |=(n=term &((source-uses q.typ n) !(alias-safe context n))))
          [%bad 'Hoon collection provenance is unavailable or shadowed']
        ?.  ?=([%tsls [%note * *] *] q.typ)
          [%bad cannot]
        =/  original=hoon  q.typ
        ?>  ?=([%tsls [%note * *] *] original)
        =/  body=hoon  q.p.original
        =/  split  (split-cell-record body 6)
        ?~  split  [%bad cannot]
        =/  try=(each [type type] tang)
          (mule |.([(~(play ut p.typ) original(q.p one.u.split)) (~(play ut p.typ) original(q.p two.u.split))]))
        ?.  ?=([%& *] try)  [%bad cannot]
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
    [%param *]  ~
    [%generic *]  $(out body.out)
    [%generic-source *]  $(out body.out)
    [%bad *]  [~ reason.out]
    [%invalid *]  [~ reason.out]
    [%face *]  $(out body.out)
    [%named *]  $(out body.out)
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
::
++  first-invalid
  |=  out=imported
  ^-  (unit import-diagnostic)
  ?-  out
    [%noun *]  ~
    [%void *]  ~
    [%atom *]  ~
    [%ref *]  ~
    [%param *]  ~
    [%generic *]  $(out body.out)
    [%generic-source *]  $(out body.out)
    [%bad *]  `[%unsupported reason.out]
    [%invalid *]  `[%invalid code.out reason.out]
    [%face *]  $(out body.out)
    [%named *]  $(out body.out)
    [%cell *]
      =/  first  $(out head.out)
      ?~  first  $(out tail.out)
      first
    [%fork *]  (first-invalids cases.out)
    [%apply *]  (first-invalids args.out)
  ==
::
++  first-invalids
  |=  xs=(list imported)
  ^-  (unit import-diagnostic)
  ?~  xs  ~
  =/  first  (first-invalid i.xs)
  ?~  first  $(xs t.xs)
  first
::
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
      ?:  =(%tas aura.out)
        ?:  =(0 u.value.out)  "%$"
        "{(trip (scot %tas u.value.out))}"
      "@{(trip aura.out)}:{(trip (scot %ud u.value.out))}"
    [%cell *]  "[{(show-import head.out)} {(show-import tail.out)}]"
    [%face *]  "{(trip name.out)}={(show-import body.out)}"
    [%fork *]  "(union {(show-imports cases.out)})"
    [%named *]
      ?:  =(%$ module.out)  "(named {(trip name.out)} {(show-import body.out)})"
      "(named {(trip name.out)}.{(trip module.out)} {(show-import body.out)})"
    [%apply *]  "({(trip name.out)} {(show-imports args.out)})"
    [%ref *]  ?:(=(%$ module.out) (trip name.out) "{(trip name.out)}.{(trip module.out)}")
    [%param *]  "#{(scow %ud index.out)}"
    [%generic *]  "(generic {(scow %ud arity.out)} {(show-import body.out)})"
    [%generic-source *]  "(source-generic {(scow %ud arity.out)} {(show-import body.out)})"
    [%bad *]  "error: {(trip reason.out)}"
    [%invalid *]  "error: {(trip reason.out)}"
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
++  show-import-diagnostic
  |=  result=import-diagnostic
  ^-  tape
  ?-  result
    [%ok *]  (show-import value.result)
    [%invalid *]  "invalid/{(trip code.result)}: {(trip message.result)}"
    [%unsupported *]  "unsupported: {(trip message.result)}"
  ==
--
