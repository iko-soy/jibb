/+  jibb
|%
++  root
  ^-  path
  /sur/my/table/hoon
++  source
  ^-  @t
  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
++  sources
  ^-  jbundle:jibb
  :~  [root source]
      [/sur/dep/base/hoon '|%\0a+$  item  @ud\0a--\0a']
      [/lib/assist/hoon '|%\0a++  value  42\0a--\0a']
  ==
++  bindings
  ^-  (list igeneric-binding:jibb)
  :~  [root %sur %dep-base /sur/dep/base/hoon]
      [/sur/dep/base/hoon %lib %assist /lib/assist/hoon]
  ==
::  These are envelope controls at the existing trusted-reader boundary.
::  Real source reconstruction and collection provenance have separate tests.
++  descriptor
  |=  [files=jbundle:jibb edges=(list igeneric-binding:jibb)]
  ^-  *
  [%generic-ford 2 [%apply %map ~[[%param 0] [%param 1]]] root source [0 0] 1 files edges]
++  evidence
  ^-  iexternals:jibb
  ~[[%my-table %table [%& (descriptor sources bindings)]]]
++  test-ford-evidence-envelope
  ^-  tang
  =/  original=jbundle:jibb  sources
  ?~  original  ~[leaf+"source fixture is empty"]
  =/  raw=*  (descriptor sources bindings)
  =/  normalized=(unit igeneric-evidence:jibb)  (import-generic-evidence:jibb raw)
  ?~  normalized  ~[leaf+"valid Ford evidence envelope was rejected"]
  ?.  &(ford.u.normalized =(sources.u.normalized sources) =(bindings.u.normalized bindings))
    ~[leaf+"Ford source closure or bindings were changed"]
  ?~  (find-imported-generic:jibb %my-table %table evidence ~[%my-table] *ifile:jibb)
    ~[leaf+"nested root path lost its imported generic"]
  ?^  (find-imported-generic:jibb %my-table %table evidence ~ *ifile:jibb)
    ~[leaf+"unimported Ford module acquired evidence"]
  ?^  (find-imported-generic:jibb %my-table %table (weld evidence evidence) ~[%my-table] *ifile:jibb)
    ~[leaf+"duplicate Ford reader result was accepted"]
  =/  bads=(list [label=@t raw=*])
    :~  ['missing closure root' (descriptor t.original bindings)]
        ['duplicate closure path' (descriptor [i.original sources] bindings)]
        ['root source mismatch' (descriptor [[root 'different'] t.original] bindings)]
        ['unsupported source folder' (descriptor (weld sources `jbundle:jibb`~[[/mar/extra/hoon source]]) bindings)]
        ['missing binding owner' (descriptor sources ~[[/sur/missing/hoon %lib %assist /lib/assist/hoon]])]
        ['missing binding target' (descriptor sources ~[[root %lib %missing /lib/missing/hoon]])]
        ['binding name mismatch' (descriptor sources ~[[root %sur %other /sur/dep/base/hoon]])]
        ['binding folder mismatch' (descriptor sources ~[[root %mar %assist /lib/assist/hoon]])]
        ['empty closure' (descriptor ~ ~)]
        ['malformed closure' [%generic-ford 2 [%apply %map ~[[%param 0] [%param 1]]] root source [0 0] 1 42 ~]]
        ['unknown evidence variant' [%generic-other raw]]
    ==
  |-
  ?~  bads  ~
  ?^  (import-generic-evidence:jibb raw.i.bads)
    ~[leaf+(trip label.i.bads) leaf+"malformed Ford evidence was accepted"]
  $(bads t.bads)
++  test-ford-evidence-source-binding
  ^-  tang
  =/  original=jbundle:jibb  sources
  ?~  original  ~[leaf+"source fixture is empty"]
  ?.  (prelude-external-evidence-valid:jibb evidence sources)
    ~[leaf+"matching Ford evidence was not bound"]
  =/  unrelated=jbundle:jibb  (weld sources `jbundle:jibb`~[[/sur/unrelated/hoon source]])
  ?.  (prelude-external-evidence-valid:jibb evidence unrelated)
    ~[leaf+"unrelated source invalidated Ford evidence"]
  =/  repeated=iexternals:jibb
    ~[[%my-table %table [%& (descriptor sources (weld bindings bindings))]]]
  ?.  (prelude-external-evidence-valid:jibb repeated sources)
    ~[leaf+"repeated ordered header bindings were rejected"]
  =/  bads=(list [label=@t files=jbundle:jibb])
    :~  ['missing transitive source' (scag 2 sources)]
        ['changed transitive source' (weld (scag 2 sources) `jbundle:jibb`~[[/lib/assist/hoon 'changed']])]
        ['comment-only transitive source change' (weld (scag 2 sources) `jbundle:jibb`~[[/lib/assist/hoon '|%\0a++  value  42\0a--\0a:: same value, different source bytes\0a']])]
        ['duplicate transitive source' (weld sources `jbundle:jibb`~[[/lib/assist/hoon 'changed']])]
        ['changed root source' [[root 'changed'] t.original]]
        ['higher priority root' (weld sources `jbundle:jibb`~[[/sur/my-table/hoon source]])]
        ['higher priority dependency' (weld sources `jbundle:jibb`~[[/sur/dep-base/hoon source]])]
    ==
  |-
  ?~  bads  ~
  ?:  (prelude-external-evidence-valid:jibb evidence files.i.bads)
    ~[leaf+(trip label.i.bads) leaf+"stale Ford evidence was accepted"]
  $(bads t.bads)
++  test-ford-path-precedence
  ^-  tang
  ?.  (import-generic-selected:jibb %sur %version-1 /sur/version/1/hoon `jbundle:jibb`~[[/sur/version/1/hoon source]])
    ~[leaf+"a numeric later path segment lost its dashed module name"]
  =/  paths=(list path)
    ~[/sur/a-b-c/hoon /sur/a/b-c/hoon /sur/a-b/c/hoon /sur/a/b/c/hoon]
  =/  all=jbundle:jibb  (turn paths |=(at=path [at source]))
  =/  first=?  &
  |-
  ?~  paths  ~
  =/  files=jbundle:jibb  (turn paths |=(at=path [at source]))
  ?.  (import-generic-selected:jibb %sur %a-b-c i.paths files)
    ~[leaf+"first present dash/slash candidate was rejected"]
  ?.  =(first (import-generic-selected:jibb %sur %a-b-c i.paths all))
    ~[leaf+"a later dash/slash candidate overrode the first"]
  ?:  (import-generic-selected:jibb %sur %different i.paths files)
    ~[leaf+"unrelated module spelling selected a path"]
  $(paths t.paths, first |)
--
