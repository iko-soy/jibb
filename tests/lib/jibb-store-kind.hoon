/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  check
  |=  [at=path src=@t prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
++  test-kind
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  builder=(unit ischeme:jibb)  (ienv-lookup:jibb %store values.iface.u.prepared)
  ?~  builder  ~[leaf+"prelude store builder missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.builder)
  ?~  shown  ~[leaf+"prelude store builder did not realize"]
  ?.  ?=(%fn -.u.shown)  ~[leaf+"prelude store builder is not a gate"]
  =/  updates=(list itype:jibb)  (record-fields-named:jibb %update product.u.shown ~)
  ?.  ?=([[%refined [%fn *]] ~] updates)  ~[leaf+"prelude store builder discarded update evidence"]
  =/  prefix=@t  '+$ state @ud\0a+$ poke %inc\0a++ init ^- state 0\0a++ update |= [a=poke s=state] s\0a'
  =/  direct=@t  (cat 3 prefix '++ main (store init update)\0a')
  =/  alias=@t  (cat 3 prefix '++ build store\0a++ main (build init update)\0a')
  =/  hand=@t  (cat 3 prefix '++ main [init update]\0a')
  =/  forged=@t  (cat 3 prefix '++ main ^- (store state) [init 5]\0a')
  =/  d=jfile-detailed-result:jibb  (check /ui/stores/direct/jibb direct u.prepared)
  ?:  ?=(%| -.d)  ~[leaf+"direct store rejected" leaf+(trip message.p.d)]
  =/  a=jfile-detailed-result:jibb  (check /ui/stores/alias/jibb alias u.prepared)
  ?:  ?=(%| -.a)  ~[leaf+"store builder alias rejected" leaf+(trip message.p.a)]
  =/  h=jfile-detailed-result:jibb  (check /ui/stores/hand/jibb hand u.prepared)
  ?:  ?=(%| -.h)  ~[leaf+"hand-built typed store rejected" leaf+(trip message.p.h)]
  =/  published=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.h)
  ?~  published  ~[leaf+"hand-built store main missing"]
  =/  shown-main=(unit itype:jibb)  (scheme-display-type:jibb u.published)
  ?~  shown-main  ~[leaf+"hand-built store main did not realize"]
  ?.  ?=([* ~] (record-fields-named:jibb %init u.shown-main ~))  ~[leaf+"published init face missing"]
  ?.  ?=([* ~] (record-fields-named:jibb %update u.shown-main ~))  ~[leaf+"published update face missing"]
  =/  consumer=@t  '/= hand /ui/stores/hand\0a++ initial init.main.hand\0a'
  =/  imported=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb /ui/consumer/jibb consumer ~ ~ ~[[/ui/stores/hand/jibb hand]] ~[/ui/consumer/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.imported)  ~[leaf+"consumer could not use published init face" leaf+(trip message.p.imported)]
  =/  one=@t  '+$ state [count=@ud]\0a+$ poke %inc\0a++ init ^- state [count=0]\0a++ update |= [a=poke s=state] s\0a++ main [init update]\0a'
  =/  one-result=jfile-detailed-result:jibb  (check /ui/stores/one/jibb one u.prepared)
  ?:  ?=(%| -.one-result)  ~[leaf+"one-field state store rejected" leaf+(trip message.p.one-result)]
  =/  one-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.one-result)
  ?~  one-main  ~[leaf+"one-field store main missing"]
  =/  one-shown=(unit itype:jibb)  (scheme-display-type:jibb u.one-main)
  ?~  one-shown  ~[leaf+"one-field store main did not realize"]
  =/  initial=(list itype:jibb)  (record-fields-named:jibb %init u.one-shown ~)
  ?.  ?=([[%face %count [%atom %ud]] ~] initial)  ~[leaf+"one-field state value face was erased"]
  =/  same=@t  '+$ state [init=@ud]\0a+$ poke %inc\0a++ init ^- state [init=0]\0a++ update |= [a=poke s=state] s\0a++ main [init update]\0a'
  =/  same-result=jfile-detailed-result:jibb  (check /ui/stores/same/jibb same u.prepared)
  ?:  ?=(%| -.same-result)  ~[leaf+"state field named init was rejected" leaf+(trip message.p.same-result)]
  =/  f=jfile-detailed-result:jibb  (check /ui/stores/forged/jibb forged u.prepared)
  ?:  ?=(%& -.f)  ~[leaf+"non-gate update was accepted"]
  ~
++  test-generic-choice-store
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  prefix=@t  '+$ state @ud\0a+$ poke %inc\0a++ init ^- state 0\0a++ update-a |= [a=poke s=state] s\0a++ update-b |= [x=poke y=state] y\0a++ first ^- * update-a\0a++ choose |= [x=A y=A] y\0a'
  =/  good=@t  (cat 3 prefix '++ second ^- * update-b\0a++ main [init (choose first second)]\0a')
  =/  checked=jfile-detailed-result:jibb  (check /ui/stores/choice/jibb good u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"compatible checked update alternatives were rejected" leaf+(trip message.p.checked)]
  =/  bad=@t  (cat 3 prefix '++ second ^- * ~zod\0a++ main [init (choose first second)]\0a')
  =/  rejected=jfile-detailed-result:jibb  (check /ui/stores/choice-bad/jibb bad u.prepared)
  ?:  ?=(%& -.rejected)  ~[leaf+"atom alternative inherited a gate proof"]
  ~
--
