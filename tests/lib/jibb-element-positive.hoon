/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-public-constructors
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  ?~  (find-jibb-mold:jibb %element iface.u.prepared)  ~[leaf+"element type missing"]
  ?~  (ienv-lookup:jibb %text values.iface.u.prepared)  ~[leaf+"text constructor missing"]
  ?~  (ienv-lookup:jibb %button values.iface.u.prepared)  ~[leaf+"button constructor missing"]
  =/  src=@t  '+$ msg\0a  %add\0a  %sub\0a++ caption (text "hello")\0a++ action ^- (element msg) (button "Add" %add)\0a++ content ^- (element msg) (row ~ ~[caption action])\0a'
  =/  at=path  /tests/sealed-element/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"source-backed element constructors failed" leaf+(trip message.p.checked)]
  =/  action=(unit ischeme:jibb)  (ienv-lookup:jibb %action values.iface.p.checked)
  ?~  action  ~[leaf+"action not exported"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.action)
  ?~  shown  ~[leaf+"action did not realize"]
  ?.  =((show-itype:jibb u.shown ~) "(element msg)")  ~[leaf+"element public name changed"]
  ~
++  test-island-data
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  src=@t  '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ p (program init update view subs)\0a++ child (island p "seed")\0a'
  =/  at=path  /tests/sealed-island/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"typed island constructor failed" leaf+(trip message.p.checked)]
  =/  bad=@t  (cat 3 src '++ wrong (island p ~zod)\0a')
  =/  rejected=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at bad ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.rejected)  ~[leaf+"island data inconsistent with init was accepted"]
  ~
++  test-element-type-arguments
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/sealed-arguments/jibb
  =/  src=@t  '+$ first %one\0a+$ second %two\0a++ action ^- (element first) (button "One" %one)\0a++ wrong ^- (element second) action\0a'
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.checked)  ~[leaf+"element with incompatible message type was accepted"]
  ~
++  test-sealed-program-kind
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/sealed-program/jibb
  =/  src=@t  '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ main (program init update view subs)\0a'
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"sealed program kind failed" leaf+(trip message.p.checked)]
  ?.  =(%island kind.p.checked)  ~[leaf+"sealed program kind was not island"]
  ~
--
