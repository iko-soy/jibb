/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-store-gate-state
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude missing"]
  =/  at=path  /tests/direct/gate-state/jibb
  =/  src=@t  '+$ state [callback=$-(@t @t)]\0a+$ poke %set\0a++ main (store init update)\0a++ init ^- state [callback=same]\0a++ update |= [a=poke s=state] s\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.result)  ~[leaf+"gate-bearing store state was rejected" leaf+(trip message.p.result)]
  ?.  =(%store kind.p.result)  ~[leaf+"gate-bearing store had the wrong kind"]
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.result)
  ?~  main  ~[leaf+"store main was not exported"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.main)
  ?~  shown  ~[leaf+"store main did not realize"]
  =/  expected=itype:jibb  [%face %callback [%fn [%atom %t] [%atom %t]]]
  ?.  =((record-fields-named:jibb %init u.shown ~) ~[expected])  ~[leaf+"published store lost its callback value face" leaf+(show-itype:jibb u.shown ~)]
  ~
++  test-init-face-retention
  ^-  tang
  =/  gate=itype:jibb  [%fn [%atom %t] [%atom %t]]
  =/  expected=itype:jibb  [%face %callback gate]
  =/  added=ifit:jibb  (retained-face-fit:jibb gate expected ~ 1)
  ?.  ?=(%ok -.added)  ~[leaf+"a context could not supply a missing value face"]
  =/  wrong=ifit:jibb  (retained-face-fit:jibb [%face %other gate] expected ~ 1)
  ?:  ?=(%ok -.wrong)  ~[leaf+"a distinct source face was renamed"]
  =/  incompatible=ifit:jibb  (retained-face-fit:jibb [%fn [%atom %p] [%atom %p]] expected ~ 1)
  ?:  ?=(%ok -.incompatible)  ~[leaf+"an incompatible underlying gate fit"]
  =/  action=itype:jibb  [%const [%term %tas %set '%set']]
  =/  good=itype:jibb  [%fn [%cell action gate] gate]
  ?~  (store-proof-fits:jibb good action expected ~ 1)  ~[leaf+"contextual state faces rejected a compatible update"]
  =/  bad-sample=itype:jibb  [%fn [%cell action [%face %other gate]] gate]
  ?^  (store-proof-fits:jibb bad-sample action expected ~ 1)  ~[leaf+"update sample renamed a source face"]
  =/  bad-product=itype:jibb  [%fn [%cell action gate] [%face %other gate]]
  ?^  (store-proof-fits:jibb bad-product action expected ~ 1)  ~[leaf+"update result renamed a source face"]
  ~
--
