/+  jibb
|%
++  check
  |=  [at=path src=@t modules=jbundle:jibb]
  ^-  jlowering-result:jibb
  (check-jibb-file-for-lowering:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
++  owned-occurrences
  |=  [owner=term root=checked-module:jibb]
  ^-  (list lowering-occurrence:jibb)
  (skim occurrences.root |=(o=lowering-occurrence:jibb =(owner owner.o)))
++  owned-references
  |=  [owner=term root=checked-module:jibb]
  ^-  (list lowering-reference:jibb)
  (skim references.root |=(r=lowering-reference:jibb =(owner owner.r)))
++  has-final-type
  |=  [owner=term typ=itype:jibb root=checked-module:jibb]
  ^-  ?
  (lien (owned-occurrences owner root) |=(o=lowering-occurrence:jibb =(typ typ.o)))
++  test-final-substitution-and-local-scopes
  ^-  tang
  =/  src=@t  '++ id |= x x\0a++ answer (id 42)\0a++ outer |= x=@ud\0a  ++ inner x\0a  inner\0a'
  =/  built=jlowering-result:jibb  (check /tests/lowering/basic/jibb src ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  ?.  (has-final-type %answer [%atom %ud] root)
    ~[leaf+"defaulted numeric substitution missing from answer occurrences"]
  =/  id-refs=(list lowering-reference:jibb)  (owned-references %id root)
  ?.  ?=([* ~] id-refs)  ~[leaf+"identity use does not have one resolved reference"]
  ?.  ?=(%local -.definition.i.id-refs)
    ~[leaf+"identity use was not resolved to its sample binder"]
  =/  id-binders=(list lowering-binder:jibb)
    (skim binders.root |=(b=lowering-binder:jibb =(%id owner.b)))
  ?.  ?=([* ~] id-binders)
    ~[leaf+"identity sample binder is not unique"]
  ?.  =(at.definition.i.id-refs at.id.i.id-binders)
    ~[leaf+"local reference and binder identities differ"]
  ?.  =(definition.i.id-binders [%local %x at.id.i.id-binders])
    ~[leaf+"sample binder definition identity differs"]
  =/  answer-refs=(list lowering-reference:jibb)  (owned-references %answer root)
  ?.  ?=([* ~] answer-refs)  ~[leaf+"own definition reference is missing"]
  ?.  =(definition.i.answer-refs [%own /tests/lowering/basic/jibb %id])
    ~[leaf+"own definition identity differs"]
  =/  outer-refs=(list lowering-reference:jibb)  (owned-references %outer root)
  ?.  ?=([* ~] outer-refs)  ~[leaf+"local definition reference is missing"]
  ?.  ?=(%local -.definition.i.outer-refs)
    ~[leaf+"local definition did not retain local identity"]
  ?.  =(%inner name.definition.i.outer-refs)
    ~[leaf+"wrong local definition identity"]
  ?.  (lien components.root |=(c=lowering-scc:jibb &(?=(^ scope.c) =(members.c ~[%inner]))))
    ~[leaf+"local dependency SCC is missing"]
  ~
++  test-prelude-reference-and-native-placeholder
  ^-  tang
  =/  prelude=ifile:jibb  *ifile:jibb
  =.  prelude
    prelude(values ~[[%forty [[%atom %ud] ~ ~]]], at /lib/jibb/prelude/jibb)
  =/  at=path  /tests/lowering/prelude/jibb
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering:jibb at '++ answer forty\0a' ~ ~ ~ ~[at] ~[%forty] ~ ~ `prelude)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  refs=(list lowering-reference:jibb)  (owned-references %answer root.p.built)
  ?.  ?=([* ~] refs)  ~[leaf+"prelude reference is missing"]
  ?.  =(definition.i.refs [%prelude /lib/jibb/prelude/jibb %forty])
    ~[leaf+"prelude definition identity differs"]
  ?.  ?=(~ native.i.refs)  ~[leaf+"prelude native identity was guessed"]
  ~
++  test-imported-references-and-cache-retention
  ^-  tang
  =/  dep-at=path  /tests/lowering/dep/jibb
  =/  root-at=path  /tests/lowering/root/jibb
  =/  dep=@t  '++ base 42\0a'
  =/  src=@t  '/= dep /tests/lowering/dep\0a++ answer base.dep\0a'
  =/  modules=jbundle:jibb  ~[[dep-at dep]]
  =/  built=jlowering-result:jibb  (check root-at src modules)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  ?.  =(imports.root ~[[%dep dep-at]])  ~[leaf+"direct import face/path mapping differs"]
  =/  refs=(list lowering-reference:jibb)  (owned-references %answer root)
  ?.  ?=([* ~] refs)  ~[leaf+"imported reference is missing"]
  ?.  =(definition.i.refs [%import dep-at %base])
    ~[leaf+"imported reference identity differs"]
  ?.  ?=(~ native.i.refs)  ~[leaf+"unregistered native identity was guessed"]
  =/  cached=(unit checked-module:jibb)  (find-jlowering-cache:jibb dep-at cache.p.built)
  ?~  cached  ~[leaf+"dependency lowering artifact was not retained"]
  ?.  (has-final-type %base [%atom %ud] u.cached)
    ~[leaf+"retained dependency artifact lost final types"]
  =/  ordinary=jcache:jibb
    (turn cache.p.built |=(e=[at=path artifact=checked-module:jibb] [at.e interface.artifact.e]))
  =/  reused=jlowering-result:jibb
    (check-jibb-file-for-lowering-with-cache:jibb root-at src ~ ~ modules ~[root-at] ~ ~ ordinary ~ cache.p.built)
  ?:  ?=(%| -.reused)  ~[leaf+(trip message.p.reused)]
  ?~  (find-jlowering-cache:jibb dep-at cache.p.reused)
    ~[leaf+"enriched cache reuse dropped dependency artifact"]
  ?.  =(2 (lent cache.p.reused))  ~[leaf+"cache reuse duplicated root or dependency artifacts"]
  =/  stale=checked-module:jibb
    u.cached(interface interface.u.cached(source `'++ base 99\0a'))
  =/  stale-cache=jlowering-cache:jibb
    [[dep-at stale] (skim cache.p.built |=(e=[at=path artifact=checked-module:jibb] !=(at.e dep-at)))]
  =/  rebuilt=jlowering-result:jibb
    (check-jibb-file-for-lowering-with-cache:jibb root-at src ~ ~ modules ~[root-at] ~ ~ ordinary ~ stale-cache)
  ?:  ?=(%| -.rebuilt)  ~[leaf+(trip message.p.rebuilt)]
  =/  refreshed=(unit checked-module:jibb)  (find-jlowering-cache:jibb dep-at cache.p.rebuilt)
  ?~  refreshed  ~[leaf+"stale dependency artifact was not rebuilt"]
  ?.  =(interface.u.refreshed interface.u.cached)
    ~[leaf+"stale dependency artifact survived interface validation"]
  ~
++  test-explicit-recursive-sccs
  ^-  tang
  =/  src=@t  '++ ping |= x=@ud (pong x)\0a++ pong |= x=@ud (ping x)\0a'
  =/  built=jlowering-result:jibb  (check /tests/lowering/scc/jibb src ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  components=(list lowering-scc:jibb)  components.root.p.built
  =/  mutual=(list lowering-scc:jibb)
    (skim components |=(c=lowering-scc:jibb =(2 (lent members.c))))
  ?.  ?=([* ~] mutual)  ~[leaf+"mutual definitions were flattened or split"]
  ?.  &((lien members.i.mutual |=(n=term =(%ping n))) (lien members.i.mutual |=(n=term =(%pong n))))
    ~[leaf+"mutual SCC has wrong members"]
  ?.  ?=(~ scope.i.mutual)  ~[leaf+"top-level SCC has a local scope"]
  ~
++  test-wing-and-edit-axes
  ^-  tang
  =/  src=@t  '++ pick |= r=[a=@t b=@ud] a.r\0a++ change |= r=[a=@t b=@ud] r(a="ok")\0a'
  =/  built=jlowering-result:jibb  (check /tests/lowering/axes/jibb src ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  ?.  ?=([* ~] wings.root)  ~[leaf+"field wing plan is missing"]
  ?.  =(steps.i.wings.root ~[[%a 2]])  ~[leaf+"field wing axis differs"]
  ?.  ?=([* ~] edits.root)  ~[leaf+"record edit plan is missing"]
  ?.  =(steps.i.edits.root ~[[%a 2]])  ~[leaf+"record edit axis differs"]
  ?.  (has-final-type %pick [%atom %t] root)  ~[leaf+"wing result type is not final"]
  ?.  (has-final-type %change [%atom %t] root)  ~[leaf+"edit field type is not final"]
  ~
++  test-match-artifacts-and-binder-axes
  ^-  tang
  =/  src=@t  '+$ choice\0a  [%left @t]\0a  [%right @ud]\0a++ render |= c=choice\0a  ?- c\0a    [%left t] t\0a    [%right n] "number"\0a'
  =/  built=jlowering-result:jibb  (check /tests/lowering/match/jibb src ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  ?.  ?=([* ~] matches.root)  ~[leaf+"checked match artifact is missing"]
  =/  match=lowering-match:jibb  i.matches.root
  ?.  =(2 (lent matrix.match))  ~[leaf+"ordered match matrix row count differs"]
  ?.  =(2 (lent arms.match))  ~[leaf+"match arm occurrence count differs"]
  ?.  =(2 (lent refinements.match))  ~[leaf+"pattern binder refinements are missing"]
  ?.  (levy refinements.match |=(b=lowering-binder:jibb =(3 axis.b)))
    ~[leaf+"tail pattern binder axes differ"]
  ?.  (lien occurrences.root |=(o=lowering-occurrence:jibb &(?=(%pattern role.id.o) =(typ.o [%atom %t]))))
    ~[leaf+"left pattern refinement did not finalize to text"]
  ~
++  test-projection-and-value-occurrences
  ^-  tang
  =/  proj-src=@t  '++ exact ^- [a=@t b=@p] (proj [a="hi" b=~zod])\0a'
  =/  projected=jlowering-result:jibb  (check /tests/lowering/projection/jibb proj-src ~)
  ?:  ?=(%| -.projected)  ~[leaf+(trip message.p.projected)]
  =/  root=checked-module:jibb  root.p.projected
  ?.  ?=([* ~] projections.root)  ~[leaf+"projection plan is missing"]
  =/  projection=lowering-projection:jibb  i.projections.root
  ?.  =(steps.plan.projection ~[[%a 2] [%b 3]])  ~[leaf+"projection axes differ"]
  ?.  (lien occurrences.root |=(o=lowering-occurrence:jibb =(id.o id.projection)))
    ~[leaf+"projection and typed tree occurrence IDs differ"]
  =/  value-src=@t  '++ values\0a  ~& 42\0a    "n={42}"\0a'
  =/  values=jlowering-result:jibb  (check /tests/lowering/values/jibb value-src ~)
  ?:  ?=(%| -.values)  ~[leaf+(trip message.p.values)]
  =/  occurrences=(list lowering-occurrence:jibb)  (owned-occurrences %values root.p.values)
  =/  numbers=(list lowering-occurrence:jibb)
    (skim occurrences |=(o=lowering-occurrence:jibb =(typ.o [%atom %ud])))
  ?.  (gth (lent numbers) 1)  ~[leaf+"trace/interpolation numeric final types are missing"]
  ?.  (has-final-type %values [%atom %t] root.p.values)
    ~[leaf+"interpolated string final type is missing"]
  ~
++  test-failed-and-provisional-modules-publish-nothing
  ^-  tang
  =/  bad=jlowering-result:jibb
    (check /tests/lowering/bad/jibb '++ bad ^- @ud "text"\0a' ~)
  ?.  ?=(%| -.bad)  ~[leaf+"failed module published a lowering result"]
  =/  provisional=jlowering-result:jibb
    (check /tests/lowering/provisional/jibb '++ provisional unknown\0a' ~)
  ?.  ?=(%| -.provisional)  ~[leaf+"provisional module published a lowering result"]
  =/  ordinary=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb /tests/lowering/ordinary/jibb '++ okay 1\0a' ~ ~ ~ ~[/tests/lowering/ordinary/jibb] ~ ~ ~ ~)
  ?.  ?=(%& -.ordinary)  ~[leaf+"ordinary detailed checker result changed"]
  ~
--
