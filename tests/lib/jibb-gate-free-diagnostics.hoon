::  Gate-free island diagnostics use the inferred type and proven source sites.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  valid  %txt  /tests/type-program-main/source/txt
/*  gate-model  %txt  /tests/type-program-main/gate-model/txt
/*  gate-data  %txt  /tests/type-program-main/gate-data/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  check
  |=  [src=@t prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  =/  at=path  /tests/program-main/island/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
++  test-gate-free-diagnostics
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  model=jfile-detailed-result:jibb  (check (text gate-model) u.prepared)
  ?:  ?=(%& -.model)  ~[leaf+"gate-bearing model was accepted"]
  =/  model-want=@t  '++ main: island model field `callback` contains a gate\0a/tests/program-main/island.jibb:4:21: gate-bearing island type\0a+$ model [count=@ud callback=$-(@t @t)]\0a                    ^\0a/tests/program-main/island.jibb:5:10: island main\0a++ main (program init update view subs)\0a         ^'
  ?.  =(model-want message.p.model)  ~[leaf+"model gate diagnostic differs" leaf+(trip message.p.model)]
  =/  data=jfile-detailed-result:jibb  (check (text gate-data) u.prepared)
  ?:  ?=(%& -.data)  ~[leaf+"gate-bearing data was accepted"]
  =/  data-want=@t  '++ main: island data field `input` contains a gate\0a/tests/program-main/island.jibb:6:12: gate-bearing island type\0a++ init |= input=$-(@t @t) ^- model [count=0]\0a           ^\0a/tests/program-main/island.jibb:5:10: island main\0a++ main (program init update view subs)\0a         ^'
  ?.  =(data-want message.p.data)  ~[leaf+"data gate diagnostic differs" leaf+(trip message.p.data)]
  =/  good=jfile-detailed-result:jibb  (check (text valid) u.prepared)
  ?:  ?=(%| -.good)  ~[leaf+"gate-free island rejected" leaf+(trip message.p.good)]
  ~
++  test-no-guessed-gate
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  declaration=def:jibb  [%value site %main [%crash site ~]]
  =/  unknown=ischeme:jibb  [[%face %init [%fn [%noun ~] [%noun ~]]] ~ ~]
  ?^  (program-gate-free-diagnostic:jibb unknown declaration ~ ~ ~)
    ~[leaf+"an unknown type was reported as a proven gate"]
  =/  gate=itype:jibb  [%fn [%atom %t] [%atom %t]]
  =/  empty=itype:jibb  [%cell [%face %callback gate] [%empty ~]]
  =/  impossible=ischeme:jibb  [[%face %init [%fn [%atom %t] empty]] ~ ~]
  ?^  (program-gate-free-diagnostic:jibb impossible declaration ~ ~ ~)
    ~[leaf+"an uninhabited model was reported as containing a value gate"]
  =/  parsed=(each module:jibb error:jibb)
    (parse:jibb /tests/gates/jibb '+$ one [callback=$-(@t @t)]\0a+$ two [callback=$-(@t @t)]\0a')
  ?:  ?=(%| -.parsed)  ~[leaf+"ambiguous mold fixture did not parse"]
  =/  model=itype:jibb  [%face %callback gate]
  =/  molds=imold-types:jibb  ~[[%one [model ~ ~]] [%two [model ~ ~]]]
  =/  model-main=ischeme:jibb  [[%face %init [%fn [%atom %t] model]] ~ ~]
  =/  initial=def:jibb  [%value [[2 1] [2 8]] %init [%crash site ~]]
  =/  diagnostic=(unit idiag:jibb)  (program-gate-free-diagnostic:jibb model-main declaration `initial defs.p.parsed molds)
  ?~  diagnostic  ~[leaf+"a definite model gate was not reported"]
  ?~  sites.u.diagnostic  ~[leaf+"gate diagnostic has no site"]
  ?:  ?=(%external -.i.sites.u.diagnostic)  ~[leaf+"unexpected external diagnostic site"]
  ?.  =(at.i.sites.u.diagnostic at.initial)  ~[leaf+"an ambiguous mold site was guessed"]
  =/  data-main=ischeme:jibb  [[%face %init [%fn gate [%atom %t]]] ~ ~]
  =/  named=def:jibb  [%value site %init [%gate site [%bind site %input] [%crash site ~]]]
  =/  named-result=(unit idiag:jibb)  (program-gate-free-diagnostic:jibb data-main declaration `named ~ ~)
  ?~  named-result  ~[leaf+"a named data gate was not reported"]
  ?.  =(msg.u.named-result "island data field `input` contains a gate")
    ~[leaf+"the direct data sample name was lost" leaf+msg.u.named-result]
  =/  bare=def:jibb  [%value site %init [%gate site [%bare site [%aura site %t]] [%crash site ~]]]
  =/  bare-result=(unit idiag:jibb)  (program-gate-free-diagnostic:jibb data-main declaration `bare ~ ~)
  ?~  bare-result  ~[leaf+"a bare data gate was not reported"]
  ?.  =(msg.u.bare-result "island data contains a gate")
    ~[leaf+"a bare data sample invented a field name" leaf+msg.u.bare-result]
  =/  source-free=(unit idiag:jibb)  (program-gate-free-diagnostic:jibb data-main declaration ~ ~ ~)
  ?~  source-free  ~[leaf+"a source-free data gate was not reported"]
  ?.  =(msg.u.source-free "island data contains a gate")
    ~[leaf+"a missing initializer invented a field name" leaf+msg.u.source-free]
  =/  nested-main=ischeme:jibb  [[%face %init [%fn [%cell [%face %callback gate] [%atom %t]] [%atom %t]]] ~ ~]
  =/  nested-result=(unit idiag:jibb)  (program-gate-free-diagnostic:jibb nested-main declaration `named ~ ~)
  ?~  nested-result  ~[leaf+"a nested data gate was not reported"]
  ?.  =(msg.u.nested-result "island data field `input.callback` contains a gate")
    ~[leaf+"the nested data witness path was replaced" leaf+msg.u.nested-result]
  ~
--
