/+  jibb-import
|%
++  context-source
  ^-  @t
  '/-  chosen=one, chosen=two\0a/+  *three\0a|%\0a+$  from-alias  value:chosen\0a+$  from-open  value\0a++  table  |$  [key val]  (map key val)\0a--\0a'
++  context-sources
  ^-  (list ford-source:jibb-import)
  :~  [/sur/root/hoon context-source]
      [/sur/one/hoon '|%\0a+$  value  @ud\0a--\0a']
      [/sur/two/hoon '|%\0a+$  value  @t\0a--\0a']
      [/lib/three/hoon '|%\0a+$  value  @p\0a--\0a']
  ==
++  test-import-context-and-closure
  ^-  tang
  =/  files=(list ford-source:jibb-import)
    %+  weld  context-sources
    ^-  (list ford-source:jibb-import)
    ~[[/sur/unrelated/hoon 'not Hoon'] [/sur/unrelated/hoon 'different invalid source']]
  =/  built=(each ford-rebuilt:jibb-import @t)
    (rebuild-source:jibb-import /sur/root/hoon files)
  ?:  ?=(%| -.built)  ~[leaf+"alias/open import reconstruction failed" leaf+(trip p.built)]
  =/  alias=(each imported:jibb-import @t)
    (read-named:jibb-import %root %from-alias cor.p.built)
  ?.  =(alias [%& [%atom %t ~]])
    ~[leaf+"the later aliased import did not take precedence"]
  =/  opened=(each imported:jibb-import @t)
    (read-named:jibb-import %root %from-open cor.p.built)
  ?.  =(opened [%& [%atom %p ~]])
    ~[leaf+"an open library import did not supply its unqualified mold"]
  ?.  &(=(4 (lent sources.p.built)) =((malt context-sources) (malt sources.p.built)))
    ~[leaf+"the reconstruction closure lost exact bytes or retained an unused source"]
  =/  edges=(list ford-binding:jibb-import)
    :~  [/sur/root/hoon %sur %one /sur/one/hoon]
        [/sur/root/hoon %sur %two /sur/two/hoon]
        [/sur/root/hoon %lib %three /lib/three/hoon]
    ==
  ?.  =(edges bindings.p.built)
    ~[leaf+"dependency bindings lost header order or selected paths"]
  =/  proof=(each imported:jibb-import @t)
    (read-generic-bundle:jibb-import %root %table /sur/root/hoon (flop files))
  ?.  ?=([%& [%generic-ford *]] proof)
    ~[leaf+"safe standard forwarding through alias/open imports was not certified"]
  ?.  &(=(2 arity.p.proof) =([%apply %map ~[[%param 0] [%param 1]]] body.p.proof))
    ~[leaf+"the generic certificate changed collection arguments"]
  ?.  &(=(sources.p.built sources.p.proof) =(edges bindings.p.proof))
    ~[leaf+"input inventory order changed the canonical generic evidence"]
  ?.  &(=(/sur/root/hoon at.p.proof) =(context-source source.p.proof) =((sham cor.p.built) scope.p.proof))
    ~[leaf+"the generic certificate lost its exact selected source or scope"]
  =/  failure=@t  'exact dependency reconstruction failure'
  =/  wet=*
    (read-module-result-fallback:jibb-import %root %table /sur/root/hoon context-source cor.p.built failure)
  ?.  =(wet [%unsupported failure])
    ~[leaf+"a failed generic reconstruction lost its supplied diagnostic"]
  =/  concrete=*
    (read-module-result-fallback:jibb-import %root %from-alias /sur/root/hoon context-source cor.p.built failure)
  ?.  =(concrete alias)
    ~[leaf+"a failed generic reconstruction changed an ordinary imported mold"]
  =/  absent=*
    (read-module-result-fallback:jibb-import %root %absent /sur/root/hoon context-source cor.p.built failure)
  ?.  =(absent [%invalid %missing 'Hoon mold `absent` is not declared'])
    ~[leaf+"a failed reconstruction erased the definite missing-mold diagnostic"]
  ~
::
++  test-source-selection
  ^-  tang
  =/  literal=(each ford-pile:jibb-import @t)
    (ford-parse:jibb-import /sur/root/hoon '/~zod')
  ?:  ?=(%| -.literal)  ~[leaf+"a literal ship path was mistaken for a Ford header" leaf+(trip p.literal)]
  ?.  &(=(~ sur.p.literal) =(~ lib.p.literal))
    ~[leaf+"a literal ship path introduced a Ford dependency"]
  =/  first=ford-source:jibb-import
    [/sur/a/b-c/hoon '|%\0a+$  value  @ud\0a--\0a']
  =/  later=ford-source:jibb-import
    [/sur/a-b/c/hoon '|%\0a+$  value  @t\0a--\0a']
  =/  files=(list ford-source:jibb-import)  ~[later first]
  ?.  =([%& at.first] (ford-find:jibb-import %sur %a-b-c files))
    ~[leaf+"mixed path selection differed from pinned Clay precedence"]
  ?.  =([%& at.later] (ford-find:jibb-import %sur %a-b-c ~[later]))
    ~[leaf+"the next existing mixed path was not selected"]
  =/  wrong=(each ford-rebuilt:jibb-import @t)
    (read-module-rebuild:jibb-import %a-b-c at.later files)
  ?.  =(wrong [%| 'Hoon source path does not match its imported module'])
    ~[leaf+"a lower-priority existing root acquired the module's identity"]
  ?.  =([%| 'ambiguous Ford dependency /sur/a/b-c/hoon'] (ford-find:jibb-import %sur %a-b-c [first files]))
    ~[leaf+"duplicate selected paths were not rejected"]
  ?.  =([%| 'missing Ford dependency /lib/absent/hoon'] (ford-find:jibb-import %lib %absent files))
    ~[leaf+"a missing library did not name the requested dependency"]
  ?.  =([%| 'Ford import path search exceeds its budget'] (ford-find:jibb-import %sur %a-b-c-d-e-f-g-h-i-j-k-l files))
    ~[leaf+"an over-budget path search did not fail closed"]
  ~
::
++  failure-cases
  ^-  (list [name=@t files=(list ford-source:jibb-import) want=@t])
  :~  :-  'unsupported header'
      :-  ~[[/sur/root/hoon '/=  foo  /bar\0a|%\0a+$  value  @ud\0a--\0a']]
      %-  of-wain:format
      :~  'Hoon source /sur/root/hoon:1:2: unsupported Ford header `/=`'
          '/=  foo  /bar'
          ' ^'
      ==
      :-  'missing dependency'
      :-  ~[[/sur/root/hoon '/-  gone\0a|%\0a+$  value  @ud\0a--\0a']]
      %-  of-wain:format
      :~  'Hoon source /sur/root/hoon:1:5: missing Ford dependency /sur/gone/hoon'
          '/-  gone'
          '    ^'
      ==
      :-  'duplicate dependency'
      :-  ~[[/sur/root/hoon '/-  dep\0a|%\0a+$  value  @ud\0a--\0a'] [/sur/dep/hoon '|%\0a--\0a'] [/sur/dep/hoon '|%\0a--\0a']]
      %-  of-wain:format
      :~  'Hoon source /sur/root/hoon:1:5: ambiguous Ford dependency /sur/dep/hoon'
          '/-  dep'
          '    ^'
      ==
      :-  'transitive cycle'
      :-  ~[[/sur/root/hoon '/-  next\0a|%\0a+$  value  @ud\0a--\0a'] [/sur/next/hoon '/-  root\0a|%\0a+$  value  @ud\0a--\0a']]
      %-  of-wain:format
      :~  'Hoon source /sur/root/hoon:1:5: Hoon source /sur/next/hoon:1:5: Ford dependency cycle reaches /sur/root/hoon'
          '/-  root'
          '    ^'
          '/-  next'
          '    ^'
      ==
  ==
++  test-reconstruction-diagnostics
  ^-  tang
  =/  cases=(list [name=@t files=(list ford-source:jibb-import) want=@t])  failure-cases
  |-
  ?~  cases  ~
  =/  got=(each ford-rebuilt:jibb-import @t)
    (rebuild-source:jibb-import /sur/root/hoon files.i.cases)
  ?:  ?=(%& -.got)  ~[leaf+(trip name.i.cases) leaf+"invalid dependency graph rebuilt"]
  ?.  =(want.i.cases p.got)
    ~[leaf+(trip name.i.cases) leaf+"dependency diagnostic or source location changed" leaf+(trip p.got)]
  $(cases t.cases)
::
++  test-imported-constructor-provenance
  ^-  tang
  =/  root=@t
    '/-  *spoof\0a|%\0a++  table  |$  [key val]  (map key val)\0a--\0a'
  =/  files=(list ford-source:jibb-import)
    :~  [/sur/root/hoon root]
        [/sur/spoof/hoon '|%\0a++  map  |$  [key val]  [key val]\0a--\0a']
    ==
  =/  built=(each ford-rebuilt:jibb-import @t)
    (rebuild-source:jibb-import /sur/root/hoon files)
  ?:  ?=(%| -.built)  ~[leaf+"the shadowing source did not reconstruct" leaf+(trip p.built)]
  =/  proof=(each imported:jibb-import @t)
    (read-generic-bundle:jibb-import %root %table /sur/root/hoon files)
  ?.  =(proof [%| 'Hoon generic collection forwarding is not proven'])
    ~[leaf+"an imported gate named map acquired standard collection provenance"]
  ~
--
