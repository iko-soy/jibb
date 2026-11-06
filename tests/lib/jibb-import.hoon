::  The importer fixtures and their golden output, read as text so -test
::  does not try to compile the fixture /sur files as test programs. The
::  probes and synthetic types below live here, not in the importer, which
::  app desks vendor; =, jibb-import gives them the importer's arms.
/+  jibb-import
/*  small     %txt  /tests/importer/small/txt
/*  epic      %txt  /tests/importer/tlon-epic/txt
/*  presence  %txt  /tests/importer/tlon-presence/txt
/*  docs      %txt  /tests/importer/tlon-docs/txt
/*  shadow    %txt  /tests/importer/shadow/txt
/*  shadow-static  %txt  /tests/importer/shadow-static/txt
/*  ford  %txt  /tests/importer/ford/txt
/*  mark  %txt  /tests/importer/mark/txt
/*  mark-rec  %txt  /tests/importer/mark-recursive/txt
/*  mark-gate  %txt  /tests/importer/mark-gate/txt
/*  mark-basic  %txt  /tests/importer/mark-list/txt
/*  origin-trans  %txt  /tests/importer/origin-transitive/txt
/*  origin-first  %txt  /tests/importer/origin-first/txt
/*  origin-other  %txt  /tests/importer/origin-other/txt
/*  expected  %txt  /tests/importer/tree/txt
|%
++  lines-to-cord
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  report
  ^-  @t
  (of-wain:format (fixture-output (lines-to-cord small) (lines-to-cord epic) (lines-to-cord presence) (lines-to-cord docs) (lines-to-cord shadow) (lines-to-cord shadow-static) (lines-to-cord ford) (lines-to-cord mark) (lines-to-cord mark-rec) (lines-to-cord mark-gate) (lines-to-cord mark-basic) (lines-to-cord origin-trans) (lines-to-cord origin-first) (lines-to-cord origin-other)))
::
++  test-importer-golden
  ^-  tang
  ?~  small  ~[leaf+"small importer fixture is missing"]
  ?~  epic  ~[leaf+"Tlon importer fixture is missing"]
  ?~  presence  ~[leaf+"Tlon presence fixture is missing"]
  ?~  docs  ~[leaf+"Tlon docs fixture is missing"]
  ?~  shadow  ~[leaf+"shadow fixture is missing"]
  ?~  shadow-static  ~[leaf+"static shadow fixture is missing"]
  ?~  ford  ~[leaf+"Ford importer fixture is missing"]
  ?~  mark  ~[leaf+"mark fixture is missing"]
  ?~  mark-rec  ~[leaf+"recursive mark fixture is missing"]
  ?~  mark-gate  ~[leaf+"gate mark fixture is missing"]
  ?~  mark-basic  ~[leaf+"list mark fixture is missing"]
  ?~  origin-trans  ~[leaf+"transitive origin fixture is missing"]
  ?~  origin-first  ~[leaf+"origin alias fixture is missing"]
  ?~  origin-other  ~[leaf+"distinct origin fixture is missing"]
  ?~  expected  ~[leaf+"importer golden output is missing"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"importer projection differs from tests/importer/tree.txt"]
  ~
::
::  The structured values behind the golden file's printed trees.
++  test-structured-values
  ^-  tang
  %+  turn
    (fixture-test (lines-to-cord small) (lines-to-cord epic) (lines-to-cord presence) (lines-to-cord docs) (lines-to-cord shadow))
  |=(what=@t leaf+"importer structured value differs: {(trip what)}")
::
::  The standard library's type, which the fixtures are built against.
::  Under =, jibb-import, ..zuse no longer finds the standard library.
++  zuse-type
  ^-  type
  -:!>(..zuse)
::
::  A synthetic hold whose first $^ branch cannot be evaluated. It tests
::  that a failed branch probe is reported rather than crashing the host.
++  bad-branch-fixture
  ^-  type
  [%hold zuse-type [%tsls [%note [%made %bad ~] [%wtcl [%dtwt [%$ 12]] [%wing ~[%jibb-no-such-branch-name]] [%rock %n 0]]] [%$ 1]]]
::
::  +show-result prints a tree, so it cannot tell %bad from %invalid;
::  +fixture-test checks the structured values themselves.
++  fixture-test
  =,  jibb-import
  |=  [small=@t epic=@t presence=@t docs=@t shadow=@t]
  ^-  (list @t)
  =/  sc=type  -:(ride zuse-type small)
  =/  ec=type  -:(ride zuse-type epic)
  =/  pc=type  -:(ride zuse-type presence)
  =/  dc=type  -:(ride zuse-type docs)
  =/  hc=type  -:(ride zuse-type shadow)
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
  =/  errors  ?:  =((read-mold %std %vase (~(play ut zuse-type) (ream '*vase'))) [%| 'vases cannot be imported'])  errors
    ['vase rejected' errors]
  =/  expect-valid=imported
    [%fork ~[[%cell [%face %x [%atom %ud ~]] [%face %y [%atom %ud ~]]] [%atom %ud ~]]]
  =/  errors  ?:  =((sample %valid-cell) [%& expect-valid])  errors
    ['disjoint cell union' errors]
  =/  errors  ?:  =((sample %invalid-cell) [%| 'Hoon union cases overlap'])  errors
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
::
::  Clay includes debug spans around source nodes. Reproduce that
::  shape without Clay so the same regression runs under eval and -test.
++  decorate-union-source
  |=  h=hoon
  ^-  hoon
  =/  at=spot  [/tests/importer/synthetic/hoon [[1 1] [1 2]]]
  ?^  -.h  [%dbug at [$(h -.h) $(h +.h)]]
  ?+  h  [%dbug at h]
    [%note *]  [%dbug at h(q $(h q.h))]
    [%ktts *]  [%dbug at h(q $(h q.h))]
    [%wtcl *]  [%dbug at h(q $(h q.h), r $(h r.h))]
  ==
::
++  debug-union-fixture
  =,  jibb-import
  |=  [cor=type name=term]
  ^-  (each imported @t)
  =/  typ=type  (~(play ut cor) (ream (cat 3 '*' name)))
  ?.  ?=([%hold *] typ)  [%| 'synthetic union is not a hold']
  =/  original=hoon  q.typ
  ?.  ?=([%tsls [%note * *] *] original)  [%| 'synthetic union source is unavailable']
  =/  source=hoon  original(q.p (decorate-union-source q.p.original))
  (read-mold %small name typ(q source))
::
::  Test debug metadata at the spec boundary without assuming that the
::  eval version of Hoon's spec mold itself includes Clay's %dbug tag.
++  debug-spec-fixture
  =,  jibb-import
  ^-  tape
  =/  location=*  [/tests/importer/synthetic/hoon [[1 1] [1 2]]]
  =/  wrapped=*  [%dbug location [%leaf %tas %x]]
  =/  got=(unit *)  (source-gist-tail wrapped)
  ?~  got  "debug wrapper missing"
  =/  leaf=(each spec tang)  (mule |.(;;(spec u.got)))
  ?.  ?=([%& [%leaf %tas %x]] leaf)  "debug leaf not recovered"
  =/  branch=spec  [%bccl ~[p.leaf [%base [%atom %t]]]]
  ?~  (tagged-cases ~[branch branch] ~)  "duplicate tags not projected"
  =/  broken=(unit *)  (source-gist-tail [%dbug location 42])
  ?~  broken  "debug wrapper missing"
  =/  invalid=(each spec tang)  (mule |.(;;(spec u.broken)))
  ?:  ?=(%& -.invalid)  "malformed spec accepted"
  "valid wrapper; duplicate tags projected; malformed rejected"
::
::  The same named-operand call with Clay-style source-location wrappers.
++  debug-mop-fixture
  =,  jibb-import
  |=  cor=type
  ^-  tape
  =/  typ=type  (~(play ut cor) (ream '*mop-wing-valid'))
  ?>  ?=([%hold *] typ)
  =/  original=hoon  q.typ
  ?>  ?=([%tsls [%note * *] *] original)
  =/  body=hoon  q.p.original
  ?>  ?=([%cncl *] body)
  ?>  ?=([%tsgr *] p.body)
  =/  b=hoon  q.p.body
  ?>  ?=([%cncl *] b)
  =/  call=hoon  p.b
  ?>  ?=([%cncl *] call)
  ?>  ?=([* [* ~]] q.call)
  =/  at=spot  [/tests/importer/synthetic/hoon [[1 1] [1 2]]]
  =/  inner=hoon  call(p [%dbug at p.call], q ~[[%dbug at i.q.call] [%dbug at i.t.q.call]])
  =/  outer=hoon  body(p p.body(q b(p [%dbug at inner])))
  =/  mixed=hoon  body(p p.body(q b(p inner)))
  =/  multi=hoon  body(p p.body(q b(p call(p [%dbug at [%wing ~[%one %two]]]))))
  =/  plain=(unit [key=spec value=spec])  (mop-specs body)
  ?~  plain  "unwrapped mop not recognized"
  ?.  =((mop-specs [%dbug at outer]) plain)  "wrapped mop not recognized"
  ?.  =((mop-specs mixed) plain)  "mixed mop not recognized"
  ?^  (mop-specs multi)  "multi-segment callee accepted"
  ?^  (mop-specs [%dbug at [%sand %ud 42]])  "malformed call accepted"
  ?^  (source-single-wing [%dbug at 42])  "malformed wing accepted"
  ?^  (source-single-wing [%dbug at [%wing ~[%one %two]]])  "multi-segment operand accepted"
  =/  four=*  [%dbug at [%dbug at [%dbug at [%dbug at [%wing ~[%mop]]]]]]
  =/  five=*  [%dbug at four]
  ?~  (source-single-wing four)  "four wrappers rejected"
  ?^  (source-single-wing five)  "wrapper limit exceeded"
  ?~  (source-note-unwrap four 4)  "four note wrappers rejected"
  ?^  (source-note-unwrap five 4)  "note wrapper limit exceeded"
  =/  selected=(unit hoon)  (local-arm-source cor %tag-valid)
  ?~  selected  "selected union not found"
  =/  arm-four=hoon  [%dbug at [%dbug at [%dbug at [%dbug at u.selected]]]]
  =/  arm-five=hoon  [%dbug at arm-four]
  ?~  (tagged-source-code arm-four %tag-valid)  "four wrapped selected arms rejected"
  ?^  (tagged-source-code arm-five %tag-valid)  "selected arm wrapper limit exceeded"
  "wrapped and mixed calls accepted; malformed, multi-segment and excessive wrappers rejected"
::
::  Synthetic nodes test each part of the direct collection-call proof.
++  collection-wrapper-fixture
  =,  jibb-import
  ^-  tape
  =/  call=hoon  [%cncl [%tsgr [%wing ~[[%.y 7]]] [%cncl [%wing ~[%list]] ~]] ~[[%$ 6]]]
  =/  subject=hoon  [%cncl [%tsgr [%wing ~[[%.y 8]]] [%cncl [%wing ~[%list]] ~]] ~[[%$ 6]]]
  =/  sample=hoon  [%cncl [%tsgr [%wing ~[[%.y 7]]] [%cncl [%wing ~[%list]] ~]] ~[[%$ 2]]]
  =/  good=hoon  [%tsls [%note [%made %x ~] call] [%tsls [%dtts [%$ 14] [%$ 2]] [%$ 6]]]
  =/  tail=hoon  [%tsls [%note [%made %x ~] call] [%$ 6]]
  =/  args=(list [hoon hoon])  ~[[call good] [subject good] [sample good] [call tail]]
  =/  flags=(list ?)  (turn args |=(pair=[hoon hoon] (direct-collection-source -.pair +.pair)))
  ?:  =(flags ~[& | | |])  "valid; forged subject, sample and tail rejected"
  "wrapper guard failed"
::
++  overlap-fork-fixture
  ^-  type
  =/  nodes=(list type)  ~[[%atom %ud ~] [%atom %t ~]]
  [%fork (silt nodes)]
::
++  invalid-fork-fixture
  ^-  type
  =/  nodes=(list type)  ~[[%atom %ud ~] [%atom %sd ~]]
  [%fork (silt nodes)]
::
++  fixture-output
  =,  jibb-import
  |=  [small=@t epic=@t presence=@t docs=@t shadow=@t shadow-static=@t ford=@t mark=@t mark-rec=@t mark-gate=@t mark-basic=@t origin-trans=@t origin-first=@t origin-other=@t]
  ^-  wain
  =/  sc=type  -:(ride zuse-type small)
  =/  ec=type  -:(ride zuse-type epic)
  =/  pc=type  -:(ride zuse-type presence)
  =/  dc=type  -:(ride zuse-type docs)
  =/  hc=type  -:(ride zuse-type shadow)
  =/  xc=type  -:(ride zuse-type shadow-static)
  =/  fp=type  [%cell [%face %small sc] zuse-type]
  =/  other=type  -:(ride zuse-type origin-other)
  =/  fc=type  -:(ride fp ford)
  ?>  ?=([%core *] fc)
  =/  only-list=@t  '|%\0a+$  lists  (list @ud)\0a--\0a'
  =/  tp=type  [%cell [%face %intermediate fc] zuse-type]
  =/  tc=type  -:(ride tp only-list)
  =/  sp=type  [%cell [%face %small xc] zuse-type]
  =/  shc=type  -:(ride sp only-list)
  =/  mark-core=type  -:(ride fp mark)
  =/  mark-rec-core=type  -:(ride fp mark-rec)
  =/  mark-gate-core=type  -:(ride zuse-type mark-gate)
  =/  mark-basic-core=type  -:(ride zuse-type mark-basic)
  =/  make-mark
    |=  [field=@t scope=type]
    ^-  type
    -:(ride scope (crip "|_  a={(trip field)}\0a++  grab  |%  ++  noun  a  --\0a++  grow  |%  ++  noun  a  --\0a++  grad  %noun\0a--\0a"))
  =/  mark-union-core=type  (make-mark 'mark-flag-valid:small' fp)
  =/  mark-overlap-core=type  (make-mark 'mark-flag-overlap:small' fp)
  =/  mark-hidden-core=type  (make-mark 'mark-flag-hidden:small' fp)
  =/  mark-signed-core=type  (make-mark 'signed:small' fp)
  =/  mark-callable-core=type  (make-mark 'gate-test:small' fp)
  =/  extra-subject=type  [%cell [%face %other other] fp]
  =/  mark-extra-core=type  (make-mark 'mark-flag-valid:small' extra-subject)
  =/  other-hold=type  (~(play ut other) (ream '*chain'))
  =/  recursive-hold=type  (~(play ut sc) (ream '*chain'))
  =/  fake-vase=type  -:(ride zuse-type '|%\0a+$  vase  @ud\0a--\0a')
  =/  spoof=(unit import-diagnostic)
    (first-invalid [%bad 'signed and float auras cannot be imported'])
  ?>  ?=(^ spoof)
  =/  mark-shadow-core=type  -:(ride sp mark-basic)
  =/  tshp=type  [%cell [%face %intermediate shc] zuse-type]
  =/  tshc=type  -:(ride tshp only-list)
  =/  trans=type  -:(ride tp origin-trans)
  =/  ambiguous-parent=type  [%cell [%face %first sc] [%cell [%face %second sc] zuse-type]]
  =/  ambiguous=type  -:(ride ambiguous-parent origin-first)
  =/  distinct-parent=type  [%cell [%face %first sc] [%cell [%face %second other] zuse-type]]
  =/  distinct=type  -:(ride distinct-parent origin-first)
  =/  trans-amb-parent=type  [%cell [%face %intermediate fc] [%cell [%face %second sc] zuse-type]]
  =/  trans-amb=type  -:(ride trans-amb-parent origin-trans)
  =/  tag-child=@t
    '|%\0a+$  tag-invalid-cell  @t\0a+$  choice  $%([%ok a=tag-invalid-cell] [%err a=@ud])\0a--\0a'
  =/  tag-collision=type  -:(ride [%cell [%face %base sc] zuse-type] tag-child)
  =/  tag-clean=type  -:(ride [%cell [%face %base other] zuse-type] tag-child)
  =/  tag-zuse=@t
    '|%\0a+$  ship  @t\0a+$  path  @ud\0a+$  choice  $%([%ok who=ship] [%err where=path])\0a--\0a'
  =/  tag-zuse-core=type  -:(ride zuse-type tag-zuse)
  =/  nest-parent-src=@t
    '|%\0a+$  tag-nest-inner  $%([%foreign @t] [%foreign @t])\0a--\0a'
  =/  nest-parent=type  -:(ride zuse-type nest-parent-src)
  =/  nest-child-src=@t
    '|%\0a+$  tag-nest-inner  $%([%left @t] [%right @ud])\0a+$  tag-nest-middle  $%([%one x=tag-nest-inner] [%two ~])\0a--\0a'
  =/  nest-collision=type  -:(ride [%cell [%face %base nest-parent] zuse-type] nest-child-src)
  =/  self-parent=type
    -:(ride zuse-type '|%\0a+$  tag-self  ?(%same %same)\0a--\0a')
  =/  self-child=@t
    '|%\0a+$  tag-self  $%([%branch children=(list tag-self)] [%leaf value=@t])\0a--\0a'
  =/  self-collision=type  -:(ride [%cell [%face %tag-self self-parent] zuse-type] self-child)
  =/  self-other=type
    -:(ride zuse-type '|%\0a+$  tag-self  $%([%branch children=(list tag-self)] [%leaf value=@ud])\0a--\0a')
  =/  mop-ford-parent=type
    -:(ride zuse-type '|%\0a+$  value  ?(%same %same)\0a--\0a')
  =/  mop-ford-child=type
    -:(ride [%cell [%face %value mop-ford-parent] zuse-type] '|%\0a+$  key  @ud\0a+$  value  @t\0a+$  mm  ((mop key value) lte)\0a--\0a')
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
  =/  vase  (read-mold %std %vase (~(play ut zuse-type) (ream '*vase')))
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
      (crip "mark-flag-source: {(show-result (read-named %small %mark-flag-valid sc))}")
      (crip "mark-flag-union: {(show-result (read-mark %flag-union mark-union-core))}")
      (crip "mark-flag-overlap: {(show-result (read-mark %flag-overlap mark-overlap-core))}")
      (crip "mark-flag-hidden: {(show-result (read-mark %flag-hidden mark-hidden-core))}")
      (crip "mark-flag-signed: {(show-result (read-mark %flag-signed mark-signed-core))}")
      (crip "mark-flag-callable: {(show-result (read-mark %flag-callable mark-callable-core))}")
      (crip "mark-flag-extra: {(show-result (read-mark %flag-extra mark-extra-core))}")
      (crip "mark-flag-other-hold: {?~((mark-union-fallback other-hold fp) "unsupported" "BAD")}")
      (crip "mark-flag-recursive-fallback: {?~((mark-union-fallback recursive-hold fp) "unsupported" "BAD")}")
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
      (crip "ford-shadow-face: {?:((scope-safe [%cell [%face %list sc] zuse-type] %list) "wrong" "unsafe")}")
      (crip "ford-unknown: {?:((scope-safe [%cell [%atom %ud ~] zuse-type] %list) "wrong" "unsafe")}")
      (crip "ford-mismatched-core: {?:((scope-safe fc(p zuse-type) %list) "wrong" "unsafe")}")
      (crip "shadow-list-mop: {(show-result (read-mold-in %shadow-static %bad (~(play ut xc) (ream '*bad')) xc))}")
      (crip "named-mop: {(show-result (sample %named-mop))}")
      (crip "mop-list: {(show-result (sample %mop-list))}")
      (crip "mop-wing-valid: {(show-result (sample %mop-wing-valid))}")
      (crip "mop-wing-invalid-key: {(show-result (sample %mop-wing-invalid-key))}")
      (crip "mop-wing-invalid-key-alias: {(show-result (sample %mop-wing-invalid-key-alias))}")
      (crip "mop-wing-invalid-value: {(show-result (sample %mop-wing-invalid-value))}")
      (crip "mop-wing-invalid-value-alias: {(show-result (sample %mop-wing-invalid-value-alias))}")
      (crip "mop-wing-rec-key: {(show-result (sample %mop-wing-rec-key))}")
      (crip "mop-wing-rec-value: {(show-result (sample %mop-wing-rec-value))}")
      (crip "mop-wing-shadow: {(show-result (read-named %shadow %mmw hc))}")
      (crip "mop-wing-ford-collision: {(show-result (read-named %child %mm mop-ford-child))}")
      (crip "mop-wing-debug: {(debug-mop-fixture sc)}")
      (crip "signed: {(show-result (sample %signed))}")
      (crip "float: {(show-result (sample %float))}")
      (crip "gate: {(show-result (sample %gate-test))}")
      (crip "vase: {(show-result vase)}")
      (crip "failed-branch: {(show-result (read-mold %external %bad bad-branch-fixture))}")
      (crip "debug-spec: {debug-spec-fixture}")
      (crip "debug-union: {(show-result (debug-union-fixture sc %action))}")
      (crip "debug-union-overlap: {(show-result (debug-union-fixture sc %explicit-wut-overlap))}")
      (crip "debug-nested-cell: {(show-result (debug-union-fixture sc %nested-valid-cell))}")
      (crip "debug-nested-cell-overlap: {(show-result (debug-union-fixture sc %nested-invalid-cell))}")
      (crip "explicit-graph: {(show-result (read-mold %raw %raw overlap-fork-fixture))}")
      (crip "explicit-graph-unsupported: {(show-result (read-mold %raw %raw invalid-fork-fixture))}")
      (crip "explicit-wut-safe: {(show-result (sample %explicit-wut-safe))}")
      (crip "explicit-percent-overlap: {(show-result (sample %explicit-percent-overlap))}")
      (crip "explicit-wut-overlap: {(show-result (sample %explicit-wut-overlap))}")
      (crip "explicit-collapsed: {(show-result (sample %explicit-collapsed))}")
      (crip "explicit-subsumed: {(show-result (sample %explicit-subsumed))}")
      (crip "explicit-three: {(show-result (sample %explicit-three))}")
      (crip "explicit-unknown: {(show-result (sample %explicit-unknown))}")
      (crip "explicit-nested: {(show-result (sample %explicit-nested))}")
      (crip "collection-union-wrapper: {collection-wrapper-fixture}")
      (crip "collection-union-list: {(show-result (sample %collection-union-list))}")
      (crip "collection-union-set: {(show-result (sample %collection-union-set))}")
      (crip "collection-union-map-key: {(show-result (sample %collection-union-map-key))}")
      (crip "collection-union-map-value: {(show-result (sample %collection-union-map-value))}")
      (crip "collection-union-unit: {(show-result (sample %collection-union-unit))}")
      (crip "collection-union-collapsed: {(show-result (sample %collection-union-collapsed))}")
      (crip "collection-union-multiple: {(show-result (sample %collection-union-multiple))}")
      (crip "collection-union-nested: {(show-result (sample %collection-union-nested))}")
      (crip "collection-union-dependent: {(show-result (sample %collection-union-dependent))}")
      (crip "collection-union-shadow: {(show-result (read-named %shadow %collection-union-shadow xc))}")
      (crip "explicit-list: {(show-result (sample %explicit-list))}")
      (crip "explicit-set: {(show-result (sample %explicit-set))}")
      (crip "explicit-faces: {(show-result (sample %explicit-faces))}")
      (crip "explicit-alias: {(show-result (sample %explicit-alias))}")
      (crip "explicit-ford: {(show-result (read-named %outer %bad-union trans))}")
      (crip "explicit-shadow-path: {(show-result (read-named %shadow %path-shadow xc))}")
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
      (crip "diagnostic-items: {(show-import-diagnostic (read-named-diagnostic %small %items sc))}")
      (crip "diagnostic-signed: {(show-import-diagnostic (read-named-diagnostic %small %signed sc))}")
      (crip "diagnostic-float: {(show-import-diagnostic (read-named-diagnostic %small %float sc))}")
      (crip "diagnostic-overlap: {(show-import-diagnostic (read-named-diagnostic %small %explicit-percent-overlap sc))}")
      (crip "diagnostic-unproved: {(show-import-diagnostic (read-named-diagnostic %small %list-nested-invalid-cell sc))}")
      (crip "diagnostic-mark-gate: {(show-import-diagnostic (read-mark-diagnostic %bad mark-gate-core))}")
      (crip "diagnostic-shadow-vase: {(show-import-diagnostic (read-named-diagnostic %fake %vase fake-vase))}")
      (crip "diagnostic-spoof: {(show-import-diagnostic u.spoof)}")
      (crip "missing-arm: {(show-result (read-mold-in %small %missing [%atom %ud ~] sc))}")
      (crip "wrong-provenance: {(show-result (read-mold-in %small %action (~(play ut sc) (ream '*items')) sc))}")
      (crip "unverified-subject: {(show-result (read-mold-in %std %jar (~(play ut zuse-type) (ream '*(jar @ud @t)')) zuse-type))}")
      (crip "tag-ford-collision: {(show-result (read-named %child %choice tag-collision))}")
      (crip "tag-ford-clean: {(show-result (read-named %child %choice tag-clean))}")
      (crip "tag-zuse-local: {(show-result (read-named %child %choice tag-zuse-core))}")
      (crip "tag-nest-inner: {(show-result (sample %tag-nest-inner))}")
      (crip "tag-nest-middle: {(show-result (sample %tag-nest-middle))}")
      (crip "tag-nest-diamond: {(show-result (sample %tag-nest-diamond))}")
      (crip "tag-nest-deep: {(show-result (sample %tag-nest-deep))}")
      (crip "tag-nest-hidden: {(show-result (sample %tag-nest-hidden))}")
      (crip "tag-nest-overlap: {(show-result (sample %tag-nest-overlap))}")
      (crip "tag-nest-recursive: {(show-result (sample %tag-nest-recursive-outer))}")
      (crip "tag-nest-rec-list: {(show-result (sample %tag-nest-rec-list-outer))}")
      (crip "tag-nest-rec-repeat: {(show-result (sample %tag-nest-rec-repeat))}")
      (crip "tag-nest-rec-duplicate: {(show-result (sample %tag-nest-rec-bad-outer))}")
      (crip "tag-nest-rec-hidden: {(show-result (sample %tag-nest-rec-hidden-outer))}")
      (crip "tag-nest-rec-mutual: {(show-result (sample %tag-nest-rec-mutual-outer))}")
      (crip "tag-nest-rec-outer-overlap: {(show-result (sample %tag-nest-rec-outer-overlap))}")
      (crip "tag-nest-rec-owner: {?:(&((contains-named-ref [%ref %small %tag-self] %small %tag-self) !(contains-named-ref [%named %small %other [%ref %small %tag-self]] %small %tag-self)) "yes" "wrong")}")
      (crip "tag-nest-many: {(show-result (sample %tag-nest-many))}")
      (crip "tag-nest-shadow: {(show-result (read-named %shadow-static %tag-nest-shadow xc))}")
      (crip "tag-nest-wrong-hold: {?~((nested-tagged-union %small (~(play ut other) (ream '*chain')) `sc) "unsupported" "BAD")}")
      (crip "tag-nest-ford-collision: {(show-result (read-named %outer %tag-nest-middle nest-collision))}")
      (crip "tag-self: {(show-result (sample %tag-self))}")
      (crip "tag-self-tail: {(show-result (sample %tag-self-tail))}")
      (crip "tag-self-duplicate: {(show-result (sample %tag-self-duplicate))}")
      (crip "tag-self-hidden: {(show-result (sample %tag-self-hidden))}")
      (crip "tag-self-indirect: {(show-result (sample %tag-self-indirect))}")
      (crip "tag-mutual-a: {(show-result (sample %tag-mutual-a))}")
      (crip "tag-mutual-b: {(show-result (sample %tag-mutual-b))}")
      (crip "tag-self-pair: {(show-result (sample %tag-self-pair))}")
      (crip "tag-self-ford-collision: {(show-result (read-named %child %tag-self self-collision))}")
      (crip "tag-self-wrong-core: {(show-result (read-mold-in %other %tag-self (~(play ut sc) (ream '*tag-self')) self-other))}")
      (crip "tag-flat-large: {?:(&(?=(~ (safe-source-name-mode %tag-fuel-7 sc ~ 256 |)) ?=(^ (safe-source-name-mode %tag-fuel-7 sc ~ 4.096 |)) ?=([%& *] (sample %tag-flat-large))) "supported above 256" "BAD")}")
      (crip "tag-null-good: {(show-result (sample %tag-null-good))}")
      (crip "tag-null-duplicate: {(show-result (sample %tag-null-duplicate))}")
      (crip "tag-null-hidden: {(show-result (sample %tag-null-hidden))}")
      (crip "tag-valid: {(show-result (sample %tag-valid))}")
      (crip "tag-duplicate: {(show-result (sample %tag-duplicate))}")
      (crip "tag-collapsed: {(show-result (sample %tag-collapsed))}")
      (crip "tag-invalid-direct: {(show-result (sample %tag-invalid-direct))}")
      (crip "tag-invalid-alias: {(show-result (sample %tag-invalid-alias))}")
      (crip "tag-invalid-list: {(show-result (sample %tag-invalid-list))}")
      (crip "tag-enum-good: {(show-result (sample %tag-enum-good))}")
      (crip "tag-enum-bad: {(show-result (sample %tag-enum-bad))}")
      (crip "tag-nested-good: {(show-result (sample %tag-nested-good))}")
      (crip "tag-shadow-jar: {(show-result (read-named %shadow-static %tag-shadow-jar xc))}")
      (crip "tag-shadow-jug: {(show-result (read-named %shadow-static %tag-shadow-jug xc))}")
      (crip "tag-fuel-small: {?:(?=(^ (safe-source-name %tag-fuel-2 sc ~ 64)) "yes" "no")}")
      (crip "tag-fuel-large: {?:(?=(~ (safe-source-name %tag-fuel-11 sc ~ 64)) "rejected" "wrong")}")
      (crip "presence-action-1: {(show-result (present %action-1))}")
      (crip "presence-command-1: {(show-result (present %command-1))}")
      (crip "presence-update-1: {(show-result (present %update-1))}")
      (crip "presence-response-1: {(show-result (present %response-1))}")
      (crip "presence-topic: {(show-result (present %topic))}")
      (crip "presence-timing: {(show-result (present %timing))}")
      (crip "presence-places: {(show-result (present %places))}")
      (crip "docs-ent: {(show-result (docs-type %ent))}")
      (crip "docs-nud: {(show-result (docs-type %nud))}")
      (crip "tlon-saga: {(show-result (tlon %saga))}")
      (crip "tlon-epic: {(show-result (tlon %epic))}")
  ==
--
