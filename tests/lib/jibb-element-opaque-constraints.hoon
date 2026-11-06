/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-gate-free-island-values
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/island-value/jibb
  =/  gate-model=@t  '+$ model [cb=$-(@t @t)]\0a+$ msg %ok\0a++ init |= data=@t ^- model [cb=|=(x=@t x)]\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ p (program init update view subs)\0a++ main (island p "seed")\0a'
  =/  gate-data=@t  '+$ model @ud\0a+$ msg %ok\0a++ init |= data=$-(@t @t) ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ p (program init update view subs)\0a++ main (island p |=(x=@t x))\0a'
  =/  cases=(list [name=tape src=@t])  ~[["model" gate-model] ["data" gate-data]]
  %+  murn  cases
  |=  c=[name=tape src=@t]
  =/  out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src.c ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.out)  `leaf+(weld name.c " gate was accepted in an island value")
  ~
--
