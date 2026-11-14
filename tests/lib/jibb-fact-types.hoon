::  Synthetic evidence tests complement real reader/receiver integration in
::  jibb-recursive-facts. They exercise malformed or conflicting certificates
::  that a successful full checker must never produce.
/+  jibb, jibb-fact-types
|%
++  root
  ^-  itype:jibb
  [%recursive %forest %chain `'chain.forest']
::
++  body
  ^-  *
  :+  %fork
    [%atom %n `0]
  ~[[%cell [%face %value [%atom %ud ~]] [%face %next [%ref %forest %chain]]]]
::
++  expected
  ^-  itype:jibb
  :*  %union
      ~[[%const [%null %n 0 '~']] [%cell [%slot %value [%atom %ud]] [%slot %next root]]]
      ~  ~  ~
  ==
::
++  external
  ^-  iexternals:jibb
  ~[[%forest %chain [%& body]]]
::
++  marked
  |=  node=*
  ^-  imark-externals:jibb
  ~[[%tree [%& [%mark-source [%named %forest %chain node] ~]]]]
::
++  test-authenticated-recursive-bodies
  ^-  tang
  =/  alias=iexternals:jibb
    ~[[%alias %selected [%& [%apply %list ~[[%named %forest %chain body]]]]]]
  =/  second=imark-externals:jibb
    ~[[%tree-diff [%& [%cell [%atom %ud ~] [%named %forest %chain body]]]]]
  =/  duplicate=imark-externals:jibb
    (weld (marked body) second)
  =/  results=(list (each itype:jibb @t))
    :~  (recursive-view:jibb-fact-types root external ~)
        (recursive-view:jibb-fact-types root alias ~)
        (recursive-view:jibb-fact-types root ~ duplicate)
        (recursive-view:jibb-fact-types root external duplicate)
    ==
  |-
  ?~  results  ~
  ?.  =(i.results [%& expected])
    ~[leaf+"authenticated recursive body changed its exact type"]
  $(results t.results)
::
++  test-unrelated-evidence-and-display-labels
  ^-  tang
  =/  noise=iexternals:jibb
    :~  [%other %unsupported [%| 'unsupported unrelated mold']]
        [%other %generic [%& [%generic-source 1 %unsupported]]]
    ==
  =/  marks=imark-externals:jibb
    :~  [%bad [%| 'unsupported unrelated mark']]
        [%malformed [%& [%mark-source ~]]]
    ==
  =/  got=(each itype:jibb @t)
    (recursive-view:jibb-fact-types root (weld noise external) marks)
  ?.  =(got [%& expected])
    ~[leaf+"unrelated reader failures affected a checked recursive mold"]
  =/  renamed=itype:jibb  [%recursive %forest %chain `'display-only']
  =/  wanted=itype:jibb
    [%union ~[[%const [%null %n 0 '~']] [%cell [%slot %value [%atom %ud]] [%slot %next renamed]]] ~ ~ ~]
  =/  label-result=(each itype:jibb @t)
    (recursive-view:jibb-fact-types renamed external ~)
  ?.  =(label-result [%& wanted])
    ~[leaf+"recursive body lookup used or discarded a display label"]
  ~
::
++  test-invalid-recursive-evidence
  ^-  tang
  =/  changed=*
    [%fork ~[[%atom %n `0] [%cell [%face %value [%atom %ux ~]] [%face %next [%ref %forest %chain]]]]]
  =/  conflict=imark-externals:jibb
    (weld (marked body) (marked changed))
  =/  repeated=*
    [%fork ~[[%atom %n `0] [%cell [%face %value [%atom %ud ~]] [%cell [%face %value [%atom %ud ~]] [%face %next [%ref %forest %chain]]]]]]
  =/  wrong=*
    [%fork ~[[%atom %n `0] [%cell [%face %value [%atom %ud ~]] [%face %next [%ref %other %chain]]]]]
  =/  checks=(list [got=(each itype:jibb @t) want=@t])
    :~  [(recursive-view:jibb-fact-types root ~ ~) 'recursive mold has no authenticated reader body']
        [(recursive-view:jibb-fact-types root ~ ~[[%tree [%& body]]]) 'recursive mold has no authenticated reader body']
        [(recursive-view:jibb-fact-types root (weld external external) ~) 'ambiguous authenticated recursive mold binding']
        [(recursive-view:jibb-fact-types root ~ conflict) 'conflicting authenticated recursive mold bodies']
        [(recursive-view:jibb-fact-types root ~ (marked repeated)) 'recursive mold reader body has malformed or repeated fields']
        [(recursive-view:jibb-fact-types root ~ (marked wrong)) 'recursive mold reader body is unsupported']
        [(recursive-view:jibb-fact-types root ~ (marked [%fork [[%atom %n `0] 17]])) 'recursive mold reader body has malformed or repeated fields']
        [(recursive-view:jibb-fact-types root ~ (marked [%atom %ud ~])) 'recursive mold reader body has no matching recursive reference']
        [(recursive-view:jibb-fact-types [%recursive %other %chain ~] external ~) 'recursive mold has no authenticated reader body']
    ==
  |-
  ?~  checks  ~
  ?.  =(got.i.checks [%| want.i.checks])
    ~[leaf+"invalid recursive evidence did not fail with its exact reason" leaf+(trip want.i.checks)]
  $(checks t.checks)
--
