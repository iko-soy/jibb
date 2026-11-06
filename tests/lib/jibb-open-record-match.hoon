/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-open-record-match
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  src=@t  (of-wain:format ~['++ first |= [a=A b=B]' '  ?- [p=a q=b]' '    [x y] x'])
  =/  at=path  /tests/open-record-match/jibb
  =/  out=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.out)  ~[leaf+(trip message.p.out)]
  =/  first=(unit ischeme:jibb)  (ienv-lookup:jibb %first values.iface.p.out)
  ?~  first  ~[leaf+"first missing"]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.first)
  ?~  display  ~[leaf+"cannot display first scheme"]
  =/  printed=tape  (show-itype:jibb (canonical-itype:jibb u.display vars.u.first) ~)
  ?.  =(printed "$-([a=A b=B] A)")  ~[leaf+"wrong first interface: {printed}"]
  ~
--
