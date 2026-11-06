::  Component gates retain value faces and generic sharing through inference.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  check
  |=  src=@t
  ^-  jfile-detailed-result:jibb
  =/  at=path  /tests/program-products/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
++  test-program-products
  ^-  tang
  =/  source=@t  '++ named |= [arg=@t model=[count=@ud]] model\0a++ alias named\0a'
  =/  good=jfile-detailed-result:jibb  (check source)
  ?:  ?=(%| -.good)  ~[leaf+(trip message.p.good)]
  =/  named=(unit ischeme:jibb)  (ienv-lookup:jibb %named values.iface.p.good)
  =/  alias=(unit ischeme:jibb)  (ienv-lookup:jibb %alias values.iface.p.good)
  ?~  named  ~[leaf+"named gate was omitted"]
  ?~  alias  ~[leaf+"gate alias was omitted"]
  =/  nt=(unit itype:jibb)  (scheme-display-type:jibb u.named)
  =/  at=(unit itype:jibb)  (scheme-display-type:jibb u.alias)
  ?~  nt  ~[leaf+"named gate did not close"]
  ?~  at  ~[leaf+"gate alias did not close"]
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  expected=itype:jibb  [%fn [%cell [%slot %arg [%atom %t]] [%slot %model model]] model]
  ?.  =(u.nt expected)  ~[leaf+(weld "named gate lost a value face: " (show-itype:jibb u.nt ~))]
  ?.  =(u.at expected)  ~[leaf+(weld "gate alias lost a value face: " (show-itype:jibb u.at ~))]
  ~
++  test-program-samples
  ^-  tang
  =/  common=@t  '++ named |= [arg=@t model=[count=@ud]] model\0a++ alias named\0a'
  =/  wrong-sample=@t  (cat 3 common '++ bad ^- $-([arg=@t model=[other=@ud]] [count=@ud]) alias\0a')
  =/  wrong-product=@t  (cat 3 common '++ bad ^- $-([arg=@t model=[count=@ud]] [other=@ud]) alias\0a')
  =/  sample-check=jfile-detailed-result:jibb  (check wrong-sample)
  ?:  ?=(%& -.sample-check)  ~[leaf+"conflicting nested sample faces were accepted"]
  =/  product-check=jfile-detailed-result:jibb  (check wrong-product)
  ?:  ?=(%& -.product-check)  ~[leaf+"conflicting result faces were accepted"]
  =/  same-name=jfile-detailed-result:jibb  (check '++ named |= x=[x=@ud] x\0a')
  ?:  ?=(%| -.same-name)  ~[leaf+(trip message.p.same-name)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %named values.iface.p.same-name)
  ?~  found  ~[leaf+"single-sample gate was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  shown  ~[leaf+"single-sample gate did not close"]
  =/  faced=itype:jibb  [%face %x [%atom %ud]]
  ?.  =(u.shown [%fn faced faced])  ~[leaf+(weld "single-sample value face was lost: " (show-itype:jibb u.shown ~))]
  ~
++  test-shared-generic-gate
  ^-  tang
  =/  common=@t  '++ identity |= x=A x\0a'
  =/  good=jfile-detailed-result:jibb  (check (cat 3 common '++ selected ^- $-(@t @t) identity\0a'))
  ?:  ?=(%| -.good)  ~[leaf+"valid shared generic gate was rejected"]
  =/  bad=jfile-detailed-result:jibb  (check (cat 3 common '++ selected ^- $-(@t @ud) identity\0a'))
  ?:  ?=(%& -.bad)  ~[leaf+"sample and result instantiated a generic independently"]
  ~
++  test-hand-built-main
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    %+  rap  3
    :~  '+$ model [count=@ud]\0a'
        '+$ msg %go\0a'
        '++ main ^- (program @t model msg) [init update view subs]\0a'
        '++ init |= input=@t ^- model [count=0]\0a'
        '++ update |= [m=msg state=model] ^- [model (list (cmd msg))] [state ~]\0a'
        '++ view |= state=model ^- (element msg) (text "view")\0a'
        '++ subs |= state=model ^- (list (sub msg)) ~\0a'
    ==
  =/  at=path  /tests/program-products/hand-built/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(weld "hand-built main rejected: " (trip message.p.checked))]
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.checked)
  ?~  main  ~[leaf+"hand-built main was omitted"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.main)
  ?~  shown  ~[leaf+"hand-built main did not close"]
  =/  fields=(list itype:jibb)  (record-fields-named:jibb %update u.shown ~)
  ?.  =(1 (lent fields))  ~[leaf+"hand-built main update field was lost"]
  ?~  fields  ~[leaf+"hand-built update field is missing"]
  =/  update=itype:jibb  i.fields
  ?.  ?=(%fn -.update)  ~[leaf+"hand-built update is not a gate"]
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  =/  sample-fields=(list itype:jibb)  (record-fields-named:jibb %state sample.update ~)
  ?~  sample-fields  ~[leaf+(weld "hand-built update model field missing: " (show-itype:jibb sample.update ~))]
  ?.  =(model i.sample-fields)  ~[leaf+"hand-built update model face was lost"]
  ~

--
