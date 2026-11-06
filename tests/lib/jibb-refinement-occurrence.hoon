/+  jibb
|%
++  test-distinct-values
  ^-  tang
  =/  gate=itype:jibb  [%refined [%fn [%atom %t] [%atom %ud]]]
  =/  number=itype:jibb  [%refined [%atom %ud]]
  =/  first=ifit:jibb  (itype-fit:jibb gate [%var 0] ~ 1)
  ?.  ?=(%ok -.first)  ~
  =/  same=ifit:jibb  (itype-fit:jibb gate [%var 0] sub.first next.first)
  ?.  ?=(%ok -.same)  ~[leaf+"identical gate evidence did not fit twice"]
  =/  unknown=ifit:jibb  (itype-fit:jibb [%noun ~] [%var 0] sub.first next.first)
  =/  leaked=?
    ?.  ?=(%ok -.unknown)  |
    =((itype-walk:jibb [%var 0] sub.unknown) gate)
  ?:  leaked  ~[leaf+"an unknown value inherited a gate proof"]
  =/  second=ifit:jibb  (itype-fit:jibb number [%var 0] sub.first next.first)
  ?.  ?=(%ok -.second)  ~
  =/  published=itype:jibb  (itype-walk:jibb [%var 0] sub.second)
  ?:  =(published gate)  ~[leaf+"a different value inherited the first argument's gate proof"]
  =/  expected=itype:jibb  [%refined [%union ~[[%fn [%atom %t] [%atom %ud]] [%atom %ud]] ~ ~ ~]]
  ?.  =(published expected)  ~[leaf+"distinct proofs were not retained as alternatives"]
  ?.  =((itype-walk:jibb [%var 0] sub.first) gate)  ~[leaf+"later meet mutated its prior snapshot"]
  ~
++  test-source-distinct-values
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ gate-value ^- * gate\0a++ number-value ^- * 5\0a++ second |= [x=A y=A] y\0a++ result (second gate-value number-value)\0a'
  =/  at=path  /tests/evidence-occurrence/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result values.iface.p.checked)
  ?~  result  ~[leaf+"accepted module omitted result"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?~  shown  ~[leaf+"accepted result did not realize"]
  ?:  ?=([%refined [%fn *]] u.shown)  ~[leaf+"number result inherited the first gate's proof"]
  ~
++  test-same-value-evidence
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ first ^- * gate\0a++ second ^- * gate\0a++ choose |= [x=A y=A] y\0a++ result (choose first second)\0a'
  =/  at=path  /tests/evidence-occurrence/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"identical checked evidence was rejected" leaf+(trip message.p.checked)]
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result values.iface.p.checked)
  ?~  result  ~[leaf+"same-proof result was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?.  ?=([~ [%refined [%fn *]]] shown)  ~[leaf+"same-proof result lost gate evidence"]
  ~
++  test-distinct-source-remains-valid
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ gate-value ^- * gate\0a++ atom-value ^- * ~zod\0a++ second |= [x=A y=A] y\0a++ result (second gate-value atom-value)\0a'
  =/  at=path  /tests/evidence-occurrence/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"ordinary distinct noun values were rejected" leaf+(trip message.p.checked)]
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result values.iface.p.checked)
  ?~  result  ~[leaf+"distinct result was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?~  shown  ~[leaf+"distinct result did not realize"]
  ?:  ?=([%refined [%fn *]] u.shown)  ~[leaf+"distinct result retained only the gate proof"]
  ?.  ?=([%refined [%union *]] u.shown)  ~[leaf+"distinct result lost its evidence alternatives"]
  ?.  =((show-itype:jibb u.shown ~) "*")  ~[leaf+"private evidence changed the public result type"]
  =/  state=itype:jibb  [%atom %ud]
  =/  action=itype:jibb  [%atom %t]
  =/  main=ischeme:jibb  [[%cell [%face %init state] [%face %update u.shown]] ~ ~]
  ?:  (store-main-evidence:jibb main action state)  ~[leaf+"mixed gate and atom evidence was accepted as a store update"]
  ~
++  test-unknown-does-not-leak
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ gate-value ^- * gate\0a++ opaque |= x=* x\0a++ second |= [x=A y=A] y\0a++ result (second gate-value (opaque ~zod))\0a'
  =/  at=path  /tests/evidence-occurrence/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"ordinary unknown noun was rejected" leaf+(trip message.p.checked)]
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result values.iface.p.checked)
  ?~  result  ~[leaf+"unknown result was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?~  shown  ~[leaf+"unknown result did not realize"]
  ?:  ?=(%refined -.u.shown)  ~[leaf+"unknown value inherited a previous proof"]
  ~
--
