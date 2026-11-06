/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  source
  |=  reverse=?
  ^-  @t
  (of-wain:format (weld ~['+$ message' '  %start' '  %stop' '++ update |= [msg=message state=@ud]' '  ^- [@ud (list (cmd message))] [state ~]' '++ update-unfaced |= input=[message @ud]' '  ^- [@ud (list (cmd message))] [0 ~]' '++ select |= flag=?' '  ?- flag'] ?:(reverse ~['    %.n update-unfaced' '    %.y update'] ~['    %.y update' '    %.n update-unfaced'])))
++  check
  |=  reverse=?
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/branch-gate/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source reverse) ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  select=(unit ischeme:jibb)  (ienv-lookup:jibb %select values.iface.p.checked)
  =/  update=(unit ischeme:jibb)  (ienv-lookup:jibb %update values.iface.p.checked)
  ?~  select  ~[leaf+"selected gate missing"]
  ?~  update  ~[leaf+"named gate missing"]
  =/  st=(unit itype:jibb)  (scheme-display-type:jibb u.select)
  =/  ut=(unit itype:jibb)  (scheme-display-type:jibb u.update)
  ?~  st  ~[leaf+"selected gate scheme did not close"]
  ?~  ut  ~[leaf+"named gate scheme did not close"]
  ?.  ?=(%fn -.u.st)  ~[leaf+"selector is not a gate"]
  ?.  ?=(%fn -.product.u.st)  ~[leaf+"selected value is not a gate"]
  ?.  ?=(%fn -.u.ut)  ~[leaf+"named value is not a gate"]
  ?.  =(sample.product.u.st sample.u.ut)  ~[leaf+"selected gate sample faces differ"]
  ~
++  test-gate-branch-orders
  ^-  tang
  (weld (check |) (check &))
++  test-conflicting-gate-faces
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/branch-gate/jibb
  =/  base=@t  (of-wain:format ~['++ left |= [name=@t state=@ud] state' '++ right |= [other=@t state=@ud] state'])
  =/  base-result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file base ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.base-result)  ~[leaf+"conflicting-face control gates did not check independently"]
  =/  src=@t  (cat 3 base '\0a++ select |= flag=?\0a  ?- flag\0a    %.y left\0a    %.n right\0a')
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file src)
  ?:  ?=(%| -.parsed)  ~[leaf+"conflicting-face control did not parse"]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.checked)  ~[leaf+"branch joined distinct value faces"]
  ~
++  test-generic-gate-branch
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/branch-gate/jibb
  =/  src=@t  (of-wain:format ~['++ named |= [a=A b=B] a' '++ bare |= input=[A B]' '  ?- input' '    [first second] first' '++ select |= flag=?' '  ?- flag' '    %.y named' '    %.n bare' '++ text-result ((select %.y) "hi" ~zod)' '++ ship-result ((select %.n) ~zod "hi")'])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file src)
  ?:  ?=(%| -.parsed)  ~[leaf+"generic branch source did not parse"]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  select=(unit ischeme:jibb)  (ienv-lookup:jibb %select values.iface.p.checked)
  ?~  select  ~[leaf+"generic selector missing"]
  =/  shape=(unit itype:jibb)  (scheme-display-type:jibb u.select)
  ?~  shape  ~[leaf+"generic selector did not close"]
  ?.  ?=(%fn -.u.shape)  ~[leaf+"selector is not a gate"]
  ?.  ?=(%fn -.product.u.shape)  ~[leaf+"selector does not return a gate"]
  =/  sample=itype:jibb  sample.product.u.shape
  ?.  ?=(%cell -.sample)  ~[leaf+"selected sample is not a cell"]
  ?.  ?=([%slot %a *] hed.sample)  ~[leaf+"first selected sample face is missing"]
  ?.  ?=([%slot %b *] tal.sample)  ~[leaf+"second selected sample face is missing"]
  =/  a=(unit ischeme:jibb)  (ienv-lookup:jibb %text-result values.iface.p.checked)
  =/  b=(unit ischeme:jibb)  (ienv-lookup:jibb %ship-result values.iface.p.checked)
  ?~  a  ~[leaf+"text instance missing"]
  ?~  b  ~[leaf+"ship instance missing"]
  ?.  =(typ.u.a [%atom %t])  ~[leaf+"text instance lost its type"]
  ?.  =(typ.u.b [%atom %p])  ~[leaf+"ship instance lost its type"]
  ~
++  test-gate-sample-face-safety
  ^-  tang
  =/  bare=itype:jibb  [%cell [%atom %t] [%atom %ud]]
  =/  named=itype:jibb  [%cell [%slot %a [%atom %t]] [%slot %b [%atom %ud]]]
  ?.  (branch-gate-sample-match:jibb named bare 32)  ~[leaf+"ordinary sample slots did not match"]
  =/  wrong=itype:jibb  [%cell [%slot %other [%atom %t]] [%slot %b [%atom %ud]]]
  ?:  (branch-gate-sample-match:jibb named wrong 32)  ~[leaf+"different sample names matched"]
  =/  faced=itype:jibb  [%cell [%slot %a [%face %inside [%atom %t]]] [%slot %b [%atom %ud]]]
  ?:  (branch-gate-sample-match:jibb faced bare 32)  ~[leaf+"nested value face was discarded"]
  =/  other=itype:jibb  [%cell [%slot %a [%face %else [%atom %t]]] [%slot %b [%atom %ud]]]
  ?:  (branch-gate-sample-match:jibb faced other 32)  ~[leaf+"conflicting nested value faces matched"]
  ~
++  test-generic-gate-standalone
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/branch-gate/jibb
  =/  src=@t  (of-wain:format ~['++ named |= [a=A b=B] a' '++ bare |= input=[A B]' '  ?- input' '    [first second] first' '++ select |= flag=?' '  ?- flag' '    %.y named' '    %.n bare'])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file src)
  ?:  ?=(%| -.parsed)  ~[leaf+"standalone generic branch did not parse"]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  selected=(unit ischeme:jibb)  (ienv-lookup:jibb %select values.iface.p.checked)
  ?~  selected  ~[leaf+"standalone selector is missing"]
  ?.  =(2 (lent vars.u.selected))  ~[leaf+"standalone selector did not generalize two variables"]
  =/  shape=(unit itype:jibb)  (scheme-display-type:jibb u.selected)
  ?~  shape  ~[leaf+"standalone selector did not close"]
  ?.  ?=(%fn -.u.shape)  ~[leaf+"selector is not a gate"]
  ?.  ?=(%fn -.product.u.shape)  ~[leaf+"selector does not return a gate"]
  =/  sample=itype:jibb  sample.product.u.shape
  ?.  ?=(%cell -.sample)  ~[leaf+"selected sample is not a cell"]
  ?.  ?=([%slot %a *] hed.sample)  ~[leaf+"first sample face is missing"]
  ?.  ?=([%slot %b *] tal.sample)  ~[leaf+"second sample face is missing"]
  ?.  =(body.hed.sample product.product.u.shape)  ~[leaf+"sample/result generic identity was lost"]
  ~
--
