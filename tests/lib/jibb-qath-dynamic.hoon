::  Dynamic application path segments are checked and retain source sites.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-qath-dynamic
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/qath-test/jibb
  =/  source=@t
    (of-wain:format ~['++ blog |= slug=@t %/blog/(slug)' '++ item |= id=@ud %/items/(id)' '++ static %/blog' '++ number %/items/(42)' '++ computed %/items/((add 1 2))'])
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+"dynamic paths were rejected: {(trip message.p.result)}"]
  =/  invalid=@t  '++ bad %/blog/([1 2])'
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at invalid ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"cell path segment was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ bad: an application path segment must be an atom' '/ui/qath-test.jibb:1:16: non-atom segment has type [@ud @ud]' '++ bad %/blog/([1 2])' '               ^' '/ui/qath-test.jibb:1:8: path requires a printable atom' '++ bad %/blog/([1 2])' '       ^'])
  ?.  =(expected message.p.bad)  ~[leaf+"cell segment lost its diagnostic: {(trip message.p.bad)}"]
  =/  generic=@t  '++ bad |= [n=A z=A] %/num/((add n z))'
  =/  unknown=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at generic ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.unknown)  ~[leaf+"generic-aura path segment was accepted"]
  =/  generic-expected=@t
    (of-wain:format ~['++ bad: a generic atom in an application path needs an aura' '/ui/qath-test.jibb:1:28: atom with a generic aura' '++ bad |= [n=A z=A] %/num/((add n z))' '                           ^' '/ui/qath-test.jibb:1:14: capital `A` keeps its type generic' '++ bad |= [n=A z=A] %/num/((add n z))' '             ^'])
  ?.  =(generic-expected message.p.unknown)
    ~[leaf+"generic path segment lost its aura diagnostic: {(trip message.p.unknown)}"]
  =/  decimal-generic=@t  '++ bad |= n=A %/num/((add n 1))'
  =/  decimal-result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at decimal-generic ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.decimal-result)  ~[leaf+"generic arithmetic aura was defaulted"]
  =/  decimal-expected=@t
    (of-wain:format ~['++ bad: a generic atom in an application path needs an aura' '/ui/qath-test.jibb:1:22: atom with a generic aura' '++ bad |= n=A %/num/((add n 1))' '                     ^' '/ui/qath-test.jibb:1:13: capital `A` keeps its type generic' '++ bad |= n=A %/num/((add n 1))' '            ^'])
  ?.  =(decimal-expected message.p.decimal-result)
    ~[leaf+"generic arithmetic aura diagnostic differs: {(trip message.p.decimal-result)}"]
  ~
--
