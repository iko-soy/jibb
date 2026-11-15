::  Manifest readers can share roots and transitive Ford dependencies.
/+  jibb, jibb-import
/*  collections-source  %hoon  /tests/prelude-ford/collections/hoon
/*  more-source  %hoon  /tests/prelude-ford/more/hoon
/*  types-source  %hoon  /tests/prelude-ford/types/hoon
/*  helpers-source  %hoon  /tests/prelude-ford/helpers/hoon
/*  base-source  %hoon  /tests/prelude-ford/base/hoon
/*  shadowed-base-source  %hoon  /tests/prelude-ford/shadowed-base/hoon
/*  group-source  %jibb  /tests/prelude-ford/group/jibb
/*  expected  %txt  /tests/type-prelude-ford/expected/txt
|%
++  sources
  ^-  jbundle:jibb
  :~  [/sur/manifest-collections/hoon collections-source]
      [/sur/manifest-more/hoon more-source]
      [/sur/manifest-types/hoon types-source]
      [/lib/manifest-helpers/hoon helpers-source]
      [/sur/manifest/base/hoon base-source]
  ==
++  declarations
  ^-  (list [module=term name=term at=path])
  :~  [%manifest-collections %table /sur/manifest-collections/hoon]
      [%manifest-collections %keys /sur/manifest-collections/hoon]
      [%manifest-more %table /sur/manifest-more/hoon]
  ==
++  readers
  |=  bundle=jbundle:jibb
  ^-  (each iexternals:jibb @t)
  =/  pending=(list [module=term name=term at=path])  declarations
  =|  out=iexternals:jibb
  |-
  ?~  pending  [%& (flop out)]
  =/  entry=[module=term name=term at=path]  i.pending
  =/  read=(each imported:jibb-import @t)
    (read-generic-bundle:jibb-import module.entry name.entry at.entry bundle)
  ?:  ?=(%| -.read)  [%| p.read]
  $(pending t.pending, out [[module.entry name.entry read] out])
++  groups
  ^-  (list iprelude-group-source:jibb)
  ~[[%ford /lib/jibb/groups/ford/jibb group-source]]
++  public
  ^-  @t
  '+$ map |$ [K V] (maps.ford K V)\0a+$ set |$ [K] (sets.ford K)\0a'
++  valid
  ^-  @t
  '++ maps |= value=(map @ud @t) value\0a++ sets |= value=(set @p) value\0a++ more |= value=(more-maps.ford @t @ud) value\0a'
++  invalid-key
  ^-  @t
  '++ wrong |= value=(map $-(@t @t) @ud) value\0a'
++  render
  |=  [bundle=jbundle:jibb evidence=iexternals:jibb src=@t]
  ^-  @t
  (golden-types-with-prelude-and-group-evidence:jibb /tests/prelude-ford/jibb src ~ ~ ~ public '' groups bundle evidence)
++  fresh
  |=  bundle=jbundle:jibb
  ^-  @t
  =/  evidence=(each iexternals:jibb @t)  (readers bundle)
  ?:  ?=(%| -.evidence)  p.evidence
  (render bundle p.evidence valid)
++  changed
  |=  [at=path source=@t]
  ^-  jbundle:jibb
  (turn sources |=(entry=jsource:jibb ?:(=(at at.entry) [at source] entry)))
++  without
  |=  at=path
  ^-  jbundle:jibb
  (skip sources |=(entry=jsource:jibb =(at at.entry)))
++  changed-base
  ^-  jbundle:jibb
  (changed /sur/manifest/base/hoon (cat 3 base-source ':: exact bytes changed\0a'))
++  shadowed-base
  ^-  jbundle:jibb
  (changed /sur/manifest/base/hoon shadowed-base-source)
++  preferred-base
  ^-  jbundle:jibb
  [[/sur/manifest-base/hoon base-source] sources]
++  duplicate-base
  ^-  jbundle:jibb
  [[/sur/manifest/base/hoon base-source] sources]
++  test-shared-ford-prelude-readers
  ^-  tang
  =/  evidence=(each iexternals:jibb @t)  (readers sources)
  ?:  ?=(%| -.evidence)
    ~[leaf+"manifest Ford readers failed" leaf+(trip p.evidence)]
  ?.  =(3 (lent p.evidence))  ~[leaf+"manifest reader count changed"]
  ?.  =(evidence (readers (flop sources)))
    ~[leaf+"source inventory order changed reader evidence"]
  =|  closures=(list jbundle:jibb)
  =/  pending=iexternals:jibb  p.evidence
  |-
  ?^  pending
    =/  raw=*  result.i.pending
    ?.  ?=([%& [%generic-ford *]] raw)
      ~[leaf+"manifest reader lost its Ford descriptor"]
    =/  proof=(unit igeneric-evidence:jibb)  (import-generic-evidence:jibb +.raw)
    ?~  proof  ~[leaf+"manifest reader descriptor did not normalize"]
    ?.  =(4 (lent sources.u.proof))
      ~[leaf+"manifest root did not retain its exact four-file closure"]
    $(pending t.pending, closures [sources.u.proof closures])
  =.  closures  (flop closures)
  ?.  ?=([* * * ~] closures)  ~[leaf+"manifest closure count changed"]
  ?.  =(i.closures i.t.closures)
    ~[leaf+"two reader arms from one root retained different source closures"]
  =/  all-files=jbundle:jibb
    `jbundle:jibb`(zing `(list jbundle:jibb)`closures)
  =/  all-paths=(list path)
    (turn all-files |=(s=jsource:jibb at.s))
  ?.  =(5 (lent ~(tap in (silt all-paths))))
    ~[leaf+"two manifest roots did not share three dependency sources"]
  ?.  (prelude-external-evidence-valid:jibb p.evidence sources)
    ~[leaf+"deduplicated manifest source bundle was rejected"]
  ?:  (prelude-external-evidence-valid:jibb p.evidence all-files)
    ~[leaf+"duplicate closure paths were accepted as unique source evidence"]
  =/  built=(each iprelude:jibb @t)
    (prepare-prelude-with-group-evidence-detailed:jibb public '' groups sources p.evidence)
  ?:  ?=(%| -.built)
    ~[leaf+"manifest Ford prelude did not prepare" leaf+(trip p.built)]
  =/  checked-groups=(list iprelude-group:jibb)  groups.iface.p.built
  ?.  ?=([* ~] checked-groups)  ~[leaf+"manifest group was not retained"]
  ?~  graph.i.checked-groups  ~[leaf+"manifest group lost its reader graph"]
  ?.  =(p.evidence externals.u.graph.i.checked-groups)
    ~[leaf+"manifest group lost exact reader evidence"]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb /tests/prelude-ford/jibb valid ~ ~ ~ ~[/tests/prelude-ford/jibb] values.p.built molds.p.built ~ `iface.p.built)
  ?:  ?=(%| -.result)
    ~[leaf+"valid manifest collection uses did not check" leaf+(trip message.p.result)]
  ~
++  report
  ^-  @t
  =/  evidence=(each iexternals:jibb @t)  (readers sources)
  ?:  ?=(%| -.evidence)  p.evidence
  %-  of-wain:format
  :~  'valid manifest collections:'  (render sources p.evidence valid)
      'invalid map key:'  (render sources p.evidence invalid-key)
      'changed dependency bytes with old proof:'  (render changed-base p.evidence valid)
      'deleted dependency with old proof:'  (render (without /sur/manifest/base/hoon) p.evidence valid)
      'preferred dependency with old proof:'  (render preferred-base p.evidence valid)
      'duplicate dependency bytes:'  (render duplicate-base p.evidence valid)
      'duplicate reader declaration:'  (render sources (weld p.evidence p.evidence) valid)
      'fresh commented dependency:'  (fresh changed-base)
      'fresh preferred dependency:'  (fresh preferred-base)
      'fresh shadowed constructor:'  (fresh shadowed-base)
      'missing direct dependency:'  (fresh (without /lib/manifest-helpers/hoon))
      'missing transitive dependency:'  (fresh (without /sur/manifest/base/hoon))
  ==
++  test-ford-prelude-diagnostics
  ^-  tang
  ?~  expected  ~[leaf+"manifest Ford diagnostic expectations are missing"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"manifest Ford diagnostics differ" leaf+(trip got)]
  ~
++  test-reader-dependency-snapshot
  ^-  tang
  =/  evidence=(each iexternals:jibb @t)  (readers sources)
  ?:  ?=(%| -.evidence)
    ~[leaf+"snapshot readers failed" leaf+(trip p.evidence)]
  =/  snapshot=(unit *)  (reader-dependencies:jibb-import p.evidence sources)
  ?~  snapshot  ~[leaf+"successful readers did not yield dependency metadata"]
  =/  saved=reader-snapshot:jibb-import  ;;(reader-snapshot:jibb-import u.snapshot)
  ?~  sources.saved  ~[leaf+"successful readers produced an empty dependency closure"]
  ?.  =(5 (lent sources.saved))  ~[leaf+"shared dependency paths were not deduplicated"]
  ?.  =(snapshot (reader-dependencies:jibb-import (flop p.evidence) (flop sources)))
    ~[leaf+"reader or inventory order changed the dependency snapshot"]
  =/  unchanged=(list jbundle:jibb)
    :~  sources
        (flop sources)
        [[/sur/unrelated/hoon 'an unused source need not compile'] sources]
        [[/sur/manifest/collections/hoon 'a lower priority source need not compile'] sources]
    ==
  ?.  (levy unchanged |=(bundle=jbundle:jibb (reader-dependencies-valid:jibb-import u.snapshot bundle)))
    ~[leaf+"unchanged selections or unrelated sources invalidated the snapshot"]
  =/  invalidated=(list jbundle:jibb)
    :~  changed-base
        (without /sur/manifest/base/hoon)
        preferred-base
        duplicate-base
        (changed /sur/manifest-collections/hoon 'root changed')
        (changed /lib/manifest-helpers/hoon 'library changed')
    ==
  ?:  (lien invalidated |=(bundle=jbundle:jibb (reader-dependencies-valid:jibb-import u.snapshot bundle)))
    ~[leaf+"changed, deleted, duplicated or newly preferred source reused a snapshot"]
  ?.  (reader-dependencies-valid:jibb-import u.snapshot sources)
    ~[leaf+"restoring exact sources did not restore snapshot validity"]
  ?^  (reader-dependencies:jibb-import p.evidence changed-base)
    ~[leaf+"stale reader evidence produced dependency metadata"]
  ?^  (reader-dependencies:jibb-import (weld p.evidence p.evidence) sources)
    ~[leaf+"duplicate reader declarations produced dependency metadata"]
  =/  malformed=(list *)
    :~  ~
        [0 1]
        [%reader-dependencies-2 ~ ~]
        [%reader-dependencies-1 [i.sources.saved sources.saved] bindings.saved]
        [%reader-dependencies-1 sources.saved ~[[/sur/absent/hoon %sur %manifest-collections /sur/manifest-collections/hoon]]]
        [%reader-dependencies-1 sources.saved ~[[/sur/manifest-collections/hoon %mar %manifest-collections /sur/manifest-collections/hoon]]]
        [%reader-dependencies-1 42 ~]
    ==
  ?:  (lien malformed |=(raw=* (reader-dependencies-valid:jibb-import raw sources)))
    ~[leaf+"malformed or unknown snapshot was accepted"]
  =/  failed=(list *)
    :~  [%| 'reader failed']
        [%unsupported 'unknown result']
        [%& [%generic 2 [%apply %map ~[[%param 0] [%param 1]]]]]
        [%& [%generic-ford 2]]
        [%& 42]
    ==
  ?:  (lien failed |=(raw=* ?=([~ *] (reader-dependencies:jibb-import ~[[%manifest-collections %table raw]] sources))))
    ~[leaf+"failed or unknown reader result produced dependency metadata"]
  =/  empty=(unit *)  (reader-dependencies:jibb-import ~ sources)
  ?~  empty  ~[leaf+"empty readers did not produce an empty snapshot"]
  ?.  (reader-dependencies-valid:jibb-import u.empty ~)
    ~[leaf+"empty snapshot depended on unrelated sources"]
  =/  plain=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
  =/  cor=type  -:(~(mint ut -:!>(..zuse)) %noun (ream plain))
  =/  read=(each imported:jibb-import @t)
    (read-generic-source:jibb-import %plain %table /sur/plain/hoon plain cor)
  ?:  ?=(%| -.read)  ~[leaf+"self-contained reader failed" leaf+(trip p.read)]
  =/  plain-files=jbundle:jibb  ~[[/sur/plain/hoon plain]]
  =/  plain-snapshot=(unit *)
    (reader-dependencies:jibb-import ~[[%plain %table read]] plain-files)
  ?~  plain-snapshot  ~[leaf+"legacy self-contained evidence lost snapshot support"]
  ?.  (reader-dependencies-valid:jibb-import u.plain-snapshot plain-files)
    ~[leaf+"self-contained snapshot rejected its unchanged source"]
  ?:  (reader-dependencies-valid:jibb-import u.plain-snapshot ~)
    ~[leaf+"self-contained snapshot ignored its missing root"]
  ~
--
