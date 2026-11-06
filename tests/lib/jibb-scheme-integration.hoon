/+  jibb
|%
++  test-face-marker-safety
  ^-  tang
  =/  value=itype:jibb  [%face %name [%atom %t]]
  =/  slot=itype:jibb  [%slot %name [%atom %t]]
  ?:  (icore-faces-compatible:jibb value slot ~)
    ~[leaf+"a value face was treated as a positional slot"]
  ?:  (icore-nominal-faces-agree:jibb value slot ~)
    ~[leaf+"nominal fitting erased value-face provenance"]
  ?^  (itype-unify:jibb value slot ~)
    ~[leaf+"mixed marker unification erased value-face provenance"]
  =/  fit=ifit:jibb  (itype-fit:jibb value slot ~ 0)
  ?:  ?=(%ok -.fit)  ~[leaf+"mixed marker fitting erased value-face provenance"]
  ~
++  test-live-graph
  ^-  tang
  =/  root=itype:jibb  [%fn [%var 1] [%var 1]]
  =/  typ=itype:jibb  [%fn [%slot %arg [%var 0]] [%var 0]]
  =/  scheme=ischeme:jibb  [typ ~[1] `[[[0 root] ~] [[0 [%named %count]] ~]]]
  =/  closed=(unit ischeme:jibb)  (graph-close-scheme:jibb scheme ~)
  ?~  closed  ~[leaf+"closed graph was rejected"]
  =/  state=istate:jibb  *istate:jibb
  =/  first=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb u.closed state)
  ?~  first  ~[leaf+"first graph instance failed"]
  ?.  ?=([%fn [%slot %arg [%var *]] [%var *]] typ.u.first)
    ~[leaf+"graph instance did not retain its shared value"]
  ?.  =(body.sample.typ.u.first product.typ.u.first)
    ~[leaf+"graph sample and result lost shared identity"]
  =/  seen=(unit iface-witness:jibb)
    (itype-witness-get:jibb id.product.typ.u.first sub.state.u.first)
  ?.  ?=([~ [%named %count]] seen)  ~[leaf+"graph instance lost its face witness"]
  =/  second=(unit [typ=itype:jibb state=istate:jibb])
    (instantiate-scheme:jibb u.closed state.u.first)
  ?~  second  ~[leaf+"second graph instance failed"]
  ?.  ?=(%fn -.typ.u.second)  ~[leaf+"second graph is not a gate"]
  ?:  =(product.typ.u.first product.typ.u.second)  ~[leaf+"graph instances shared a root"]
  =/  escaped=ischeme:jibb  [typ ~[1] `[[[0 [%fn [%var 1] [%var 9]]] ~] ~]]
  ?^  (graph-close-scheme:jibb escaped ~)  ~[leaf+"unresolved enclosing root escaped"]
  =/  conflicted=ischeme:jibb  [typ ~[1] `[[[0 root] ~] [[0 [%conflict ~]] ~]]]
  ?^  (graph-close-scheme:jibb conflicted ~)  ~[leaf+"conflicting graph witness escaped"]
  ~
++  test-core-identity
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ pass-fn |= f=$-([A B] C) f' '++ update |= [msg=@t state=@ud] msg' '++ pass-named (pass-fn update)'])
  =/  at=path  /ui/identity/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"identity source failed to parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(globals (global-value-names:jibb ds), at at, in-mold |, jrec-fuel 256)
  =/  checked=icore-output:jibb  (icore-check:jibb ds state)
  ?~  result.checked
    ?~  error.checked  ~[leaf+"shared core declined identity without an error"]
    ~[leaf+msg.diag.u.error.checked]
  =/  pass=(unit ischeme:jibb)  (ienv-lookup:jibb %pass-fn env.u.result.checked)
  ?~  pass  ~[leaf+"shared core omitted pass-fn"]
  ?~  graph.u.pass  ~[leaf+"shared core lost the generic identity graph" leaf+(show-itype:jibb typ.u.pass ~)]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.pass)
  ?~  display  ~[leaf+"published generic graph failed display"]
  ?.  ?=([%fn [%fn * *] [%fn * *]] u.display)
    ~[leaf+"generic graph did not display its structural gate" leaf+(show-itype:jibb u.display ~)]
  ?.  =(sample.u.display product.u.display)
    ~[leaf+"generic graph display lost its shared type"]
  =/  named=(unit ischeme:jibb)  (ienv-lookup:jibb %pass-named env.u.result.checked)
  ?~  named  ~[leaf+"shared core omitted pass-named"]
  ?.  =((show-itype:jibb typ.u.named ~) "$-([msg=@t state=@ud] @t)")
    ~[leaf+"shared core erased gate faces" leaf+(show-itype:jibb typ.u.named ~)]
  ~
++  test-independent-gates
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ choose |= [left=$-([A B] C) right=$-([A B] C)] left' '++ one |= [first=@t second=@ud] first' '++ two |= [other=@t different=@ud] other' '++ selected (choose one two)'])
  =/  at=path  /ui/independent/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  selected=(unit ischeme:jibb)  (ienv-lookup:jibb %selected values.iface.p.checked)
  ?~  selected  ~[leaf+"independent gate selection missing"]
  ?.  =((show-itype:jibb typ.u.selected ~) "$-([first=@t second=@ud] @t)")
    ~[leaf+"separate same-shaped gate contaminated returned faces" leaf+(show-itype:jibb typ.u.selected ~)]
  ~
++  test-conflicting-gate-faces
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ expect |= f=$-([first=@t second=@ud] @t) f' '++ other |= [different=@t second=@ud] different' '++ wrong (expect other)'])
  =/  at=path  /ui/conflicting-faces/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.checked)  ~[leaf+"conflicting named gate samples were accepted"]
  ~
++  test-import-named-union
  ^-  tang
  =/  owner=@t
    (of-wain:format ~['+$ msg' '  %go' '  %stop' '++ pass-fn |= f=$-([msg A] A) f'])
  =/  src=@t
    (of-wain:format ~['/= dep /ui/named' '++ update |= [e=msg.dep state=@ud] state' '++ pass-named (pass-fn.dep update)'])
  =/  at=path  /ui/use-named/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~[[/ui/named/jibb owner]] ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  pass=(unit ischeme:jibb)  (ienv-lookup:jibb %pass-named values.iface.p.result)
  ?~  pass  ~[leaf+"imported generic named-union gate missing"]
  ?.  =((show-itype:jibb typ.u.pass ~) "$-([e=msg.dep state=@ud] @ud)")
    ~[leaf+"imported graph lost its named union or gate faces" leaf+(show-itype:jibb typ.u.pass ~)]
  ~
++  test-direct-identity
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ pass-fn |= f=$-([A B] C) f' '++ update |= [msg=@t state=@ud] msg' '++ pass-named (pass-fn update)'])
  =/  at=path  /ui/identity/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  pass=(unit ischeme:jibb)  (ienv-lookup:jibb %pass-named values.iface.p.result)
  ?~  pass  ~[leaf+"generic pass result missing"]
  ?.  ?=(~ vars.u.pass)  ~[leaf+"named gate unexpectedly generalized"]
  ?.  =((show-itype:jibb typ.u.pass ~) "$-([msg=@t state=@ud] @t)")
    ~[leaf+"generic identity erased gate faces" leaf+(show-itype:jibb typ.u.pass ~)]
  ~
++  test-import-identity
  ^-  tang
  =/  owner=@t  (of-wain:format ~['++ pass-fn |= f=$-([A B] C) f'])
  =/  src=@t
    (of-wain:format ~['/= dep /ui/identity' '++ update |= [msg=@t state=@ud] msg' '++ pass-named (pass-fn.dep update)'])
  =/  at=path  /ui/use-identity/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~[[/ui/identity/jibb owner]] ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  pass=(unit ischeme:jibb)  (ienv-lookup:jibb %pass-named values.iface.p.result)
  ?~  pass  ~[leaf+"imported generic pass result missing"]
  ?.  =((show-itype:jibb typ.u.pass ~) "$-([msg=@t state=@ud] @t)")
    ~[leaf+"imported generic identity erased gate faces" leaf+(show-itype:jibb typ.u.pass ~)]
  ~
--
