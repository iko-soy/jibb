/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-static-element
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  at=path  /ui/pages/sealed/jibb
  =/  good=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at '++ main (text "hello")\0a' ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.good)  ~[leaf+"sealed static main failed" leaf+(trip message.p.good)]
  ?.  =(kind.p.good %static-page)  ~[leaf+"sealed element did not produce a static page"]
  =/  bad=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at '++ main ^- (element !!) [%island 5]\0a' ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"forged island main was accepted"]
  ~
--
