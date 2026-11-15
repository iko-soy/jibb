::  Real /sur and /lib source dependencies, shared with the Clay/HTTP desks.
/+  jibb, jibb-import
/*  tables  %hoon  /tests/type-ford-imports/tables/hoon
/*  types  %hoon  /tests/type-ford-imports/ford-types/hoon
/*  helper  %hoon  /tests/type-ford-imports/ford-helpers/hoon
/*  base  %hoon  /tests/type-ford-imports/ford-base/hoon
/*  source  %jibb  /tests/type-ford-imports/source/jibb
/*  expected  %txt  /tests/type-ford-imports/expected/txt
|%
++  sources
  ^-  (list [at=path source=@t])
  :~  [/sur/tables/hoon tables]
      [/sur/ford-types/hoon types]
      [/lib/ford-helpers/hoon helper]
      [/sur/ford-base/hoon base]
  ==
::
++  changed
  |=  [at=path source=@t]
  ^-  (list [at=path source=@t])
  %+  turn  sources
  |=  entry=[at=path source=@t]
  ?:(=(at at.entry) [at source] entry)
::
++  without
  |=  at=path
  ^-  (list [at=path source=@t])
  (skip sources |=(entry=[at=path source=@t] =(at at.entry)))
::
++  changed-base
  ^-  (list [at=path source=@t])
  (changed /sur/ford-base/hoon '|%\0a+$  amount  [left=@ud right=@ud]\0a--\0a')
::
++  shadowed
  ^-  (list [at=path source=@t])
  %-  changed
  :-  /lib/ford-helpers/hoon
  '/-  ford-base\0a|%\0a+$  count  amount:ford-base\0a++  map  |$  [a b]  [a b]\0a--\0a'
::
++  checked
  |=  bundle=(list [at=path source=@t])
  ^-  (each @t @t)
  =/  enumerated=(each iexternals:jibb @t)
    (read-module-bundle:jibb-import %tables /sur/tables/hoon bundle)
  ::  A failed graph must reach the checker as the requested mold's actual
  ::  reader result, retaining both the Jibb use site and Hoon source error.
  =/  imported=iexternals:jibb
    ?:  ?=(%& -.enumerated)  p.enumerated
    :~  [%tables %table (read-module-result-bundle:jibb-import %tables %table /sur/tables/hoon bundle)]
        [%tables %sample (read-module-result-bundle:jibb-import %tables %sample /sur/tables/hoon bundle)]
    ==
  =/  at=path  /ui/ford-imports/jibb
  =/  result
    (infer-jibb-file-detailed:jibb at source imported ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  [%| message.p.result]
  [%& 'CHECKED']
::
++  test-real-ford-full-check
  ^-  tang
  =/  original=(each @t @t)  (checked sources)
  ?:  ?=(%| -.original)  ~[leaf+"real Ford source graph did not check" leaf+(trip p.original)]
  =/  changes=(list (list [at=path source=@t]))
    ~[changed-base shadowed (without /lib/ford-helpers/hoon) (without /sur/ford-base/hoon)]
  |-
  ?~  changes
    ?.  =(original (checked sources))
      ~[leaf+"restoring the exact Ford sources changed the full-check result"]
    ~
  =/  rejected=(each @t @t)  (checked i.changes)
  ?:  ?=(%& -.rejected)  ~[leaf+"invalid Ford dependency graph checked"]
  $(changes t.changes)
::
++  test-real-ford-diagnostics
  ^-  tang
  =/  wanted=@t  (of-wain:format expected)
  =/  actual=@t  report
  ?.  =(wanted actual)
    ~[leaf+"real Ford source diagnostics changed" leaf+(trip actual)]
  ~
::
++  report
  ^-  @t
  =/  original=(each @t @t)  (checked sources)
  =/  altered=(each @t @t)  (checked changed-base)
  =/  shadow=(each @t @t)  (checked shadowed)
  =/  missing=(each @t @t)  (checked (without /lib/ford-helpers/hoon))
  =/  transitive=(each @t @t)  (checked (without /sur/ford-base/hoon))
  %-  of-wain:format
  :~  'valid dependency graph:'  p.original
      'changed transitive mold:'  p.altered
      'shadowed standard map:'  p.shadow
      'missing direct library:'  p.missing
      'missing transitive source:'  p.transitive
  ==
--
