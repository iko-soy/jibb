/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /tests/type-bit/internal/jibb
/*  hoon  %jibb  /lib/jibb/groups/hoon/jibb
/*  bit  %jibb  /tests/type-bit/bit/jibb
|%
++  test-forged-group-marker
  ^-  tang
  =/  prep=(each iprelude:jibb @t)
    (prepare-bundle-detailed:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb hoon] [%bit /lib/jibb/groups/bit/jibb bit]] ~)
  ?:  ?=(%| -.prep)  ~[leaf+(trip p.prep)]
  =/  private=(unit ifile:jibb)  (infer-private-internal:jibb internal prelude)
  ?~  private  ~[leaf+"private source did not prepare"]
  =/  at=path  /lib/jibb/groups/bit/jibb
  =/  markers=(list iprelude-group:jibb)  (prelude-group-markers:jibb ~[[%bit at bit]])
  =/  forged=ifile:jibb  iface.p.prep(groups markers)
  =/  cache=jcache:jibb  ~[[/lib/jibb/internal/jibb u.private]]
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at bit ~ ~ ~ ~[at] values.p.prep molds.p.prep cache `forged)
  ?:  ?=(%& -.got)  ~[leaf+"forged unchecked group marker authorized a private import"]
  ~
--
