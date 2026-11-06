/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-printable-module
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/printable/jibb
  =/  source=@t  (of-wain:format ~['++ path |= n %/x/(n)' '++ use (path "hi")'])
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+"later known aura did not close printable constraint: {(trip message.p.result)}"]
  =/  path=(unit ischeme:jibb)  (ienv-lookup:jibb %path values.iface.p.result)
  ?~  path  ~[leaf+"checked path was not exported"]
  ?^  vars.u.path  ~[leaf+"checked path unexpectedly generalized its aura"]
  =/  forward=@t  (of-wain:format ~['++ use (path "hi")' '++ path |= n %/x/(n)'])
  =/  forward-result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at forward ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.forward-result)  ~[leaf+"forward known aura did not close printable constraint: {(trip message.p.forward-result)}"]
  =/  generic=@t  '++ bad |= [n=A z=A] %/num/((add n z))'
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at generic ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"unfixed generic aura was accepted"]
  =/  lines=wall  (turn (to-wain:format message.p.bad) |=(line=@t (trip line)))
  ?.  (lien lines |=(line=tape =(line "++ bad: a generic atom in an application path needs an aura")))
    ~[leaf+"generic path aura diagnostic differs: {(trip message.p.bad)}"]
  ~
--
