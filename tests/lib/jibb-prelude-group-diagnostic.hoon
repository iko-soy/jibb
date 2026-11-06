/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  hoon-source  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  with-hoon
  |=  sources=(list iprelude-group-source:jibb)
  ^-  (list iprelude-group-source:jibb)
  ?:  (lien sources |=(entry=iprelude-group-source:jibb =(%hoon face.entry)))  sources
  (weld sources `(list iprelude-group-source:jibb)`~[[%hoon /lib/jibb/groups/hoon/jibb hoon-source]])
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-group-diagnostic-source
  ^-  tang
  =/  source=@t  '++ identity |= value=@t value'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%widget /lib/jibb/groups/widget/jibb source]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon groups))
  ?~  prep  ~[leaf+"group prelude did not prepare"]
  =/  file=path  /tests/group-diagnostic/jibb
  =/  src=@t  '++ bad (identity.widget ~zod)'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.checked)  ~[leaf+"bad qualified group call was accepted"]
  =/  msg=tape  (trip message.p.checked)
  ?.  (contains msg "/tests/group-diagnostic.jibb:1:9:")  ~[leaf+(weld "called-gate site is missing: " msg)]
  ?.  (contains msg "/tests/group-diagnostic.jibb:1:25:")  ~[leaf+(weld "argument site is missing: " msg)]
  =/  sources=(list [at=path source=@t])  (prelude-group-sources:jibb groups.iface.u.prep)
  ?.  (lien sources |=(item=[at=path source=@t] &(=(at.item /lib/jibb/groups/widget/jibb) =(source.item source))))  ~[leaf+"checked group source was not retained"]
  ?~  groups.iface.u.prep  ~[leaf+"checked group disappeared"]
  =/  group=iprelude-group:jibb  i.groups.iface.u.prep
  ?.  =((diagnostic-group-source:jibb /lib/jibb/groups/widget/jibb ~[group]) `source)  ~[leaf+"checked group graph did not prove source"]
  =.  group  group(source `'+$ forged @t', closure ~)
  ?^  (diagnostic-group-source:jibb /lib/jibb/groups/widget/jibb ~[group])  ~[leaf+"source not present in the checked bundle was trusted"]
  ~
++  test-group-union-source
  ^-  tang
  =/  source=@t  '+$ msg\0a  %foo\0a  %bar\0a++ accept |= value=msg value\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%widget /lib/jibb/groups/widget/jibb source]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon groups))
  ?~  prep  ~[leaf+"union group did not prepare"]
  =/  file=path  /tests/group-union/jibb
  =/  src=@t  '++ bad (accept.widget %wrong)'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.checked)  ~[leaf+"unknown group union case was accepted"]
  =/  msg=tape  (trip message.p.checked)
  ?.  (contains msg "/tests/group-union.jibb:1:")  ~[leaf+(weld "union use site missing: " msg)]
  ?.  (contains msg "/lib/jibb/groups/widget.jibb:2:3:")  ~[leaf+(weld "union declaration site missing: " msg)]
  ?.  (contains msg "  %foo")  ~[leaf+(weld "union declaration excerpt missing: " msg)]
  ~
++  test-group-transitive-union-source
  ^-  tang
  =/  hidden=@t  '+$ msg\0a  %foo\0a  %bar\0a'
  =/  group=@t  '/= dep /ui/private\0a++ accept |= value=msg.dep value\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%widget /lib/jibb/groups/widget/jibb group]]
  =/  modules=jbundle:jibb  ~[[/ui/private/jibb hidden]]
  =/  prep=(unit iprelude:jibb)  (prepare-bundle:jibb-prelude-fixture prelude internal (with-hoon groups) modules)
  ?~  prep  ~[leaf+"group with private imported union did not prepare"]
  =/  file=path  /tests/group-union/jibb
  =/  src=@t  '++ bad (accept.widget %wrong)'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.checked)  ~[leaf+"unknown private union case was accepted"]
  =/  msg=tape  (trip message.p.checked)
  ?.  (contains msg "/ui/private.jibb:2:3:")  ~[leaf+(weld "transitive union declaration is missing: " msg)]
  ?.  (contains msg "/tests/group-union.jibb:1:23:")  ~[leaf+(weld "tag use site is missing: " msg)]
  ~
--
