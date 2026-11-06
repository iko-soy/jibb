/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-local-island-watch
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /tests/local-island-watch/jibb
  =/  cases=(list [label=@t src=@t bad=?])
    :~  ['local empty island' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ p (program init update view subs)\0a++ main (island p "seed")\0a' |]
        ['local pure watch' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~[[%watch (pure %ok)]]\0a++ p (program init update view subs)\0a++ main (island p "seed")\0a' &]
        ['island through generic helper' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~[[%watch (pure %ok)]]\0a++ p (program init update view subs)\0a++ embed |= [p1 d] (island p1 d)\0a++ main (embed p "seed")\0a' &]
        ['discarded call argument' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~[[%watch (pure %ok)]]\0a++ p (program init update view subs)\0a++ discard |= [unused=A kept=B] kept\0a++ main (discard (island p "seed") (^- (element !!) (text "ok")))\0a' &]
        ['discarded record field' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~[[%watch (pure %ok)]]\0a++ p (program init update view subs)\0a++ record [hidden=(island p "seed") visible=(^- (element !!) (text "ok"))]\0a++ main visible.record\0a' &]
        ['overwritten record field' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~[[%watch (pure %ok)]]\0a++ p (program init update view subs)\0a++ record [visible=(island p "seed") extra=0]\0a++ revised record(visible=(^- (element !!) (text "ok")))\0a++ main visible.revised\0a' &]
        ['empty island through helper' '+$ model @ud\0a+$ msg %ok\0a++ init |= data=@t ^- model 0\0a++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]\0a++ view |= s=model ^- (element msg) (text "ok")\0a++ subs |= s=model ^- (list (sub msg)) ~\0a++ p (program init update view subs)\0a++ embed |= [p1 d] (island p1 d)\0a++ main (embed p "seed")\0a' |]
    ==
  %+  murn  cases
  |=  c=[label=@t src=@t bad=?]
  =/  out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src.c ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.out)
    ?.  bad.c  ~
    `leaf+(weld (trip label.c) ": unproved request was accepted")
  =/  rendered=tape  (trip message.p.out)
  ?.  bad.c  `leaf+(weld (trip label.c) (weld ": valid program rejected: " rendered))
  ?.  (contains rendered "watch")  `leaf+(weld (trip label.c) (weld ": missing watch diagnostic: " rendered))
  ?.  (contains rendered "/tests/local-island-watch.jibb:6:")  `leaf+(weld (trip label.c) (weld ": missing subscription site: " rendered))
  ~
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
--
