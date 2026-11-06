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
++  test-prelude-groups
  ^-  tang
  =/  group=@t  (of-wain:format ~['+$ token @t' '++ identity |= value=@t value'])
  =/  sources=(list iprelude-group-source:jibb)  ~[[%widget /lib/jibb/groups/widget/jibb group]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon sources))
  ?~  prep  ~[leaf+"valid group did not prepare"]
  =/  source=@t  (of-wain:format ~['++ sample |= x=token.widget (identity.widget x)'])
  =/  file=path  /tests/prelude-groups/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  sample=(unit ischeme:jibb)  (ienv-lookup:jibb %sample values.iface.p.result)
  ?~  sample  ~[leaf+"qualified group value did not resolve"]
  =/  actual=(unit itype:jibb)  (scheme-display-type:jibb u.sample)
  ?~  actual  ~[leaf+"qualified group result did not realize"]
  ?.  =((show-itype:jibb u.actual ~) "$-(@t @t)")
    ~[leaf+(weld "qualified group has the wrong type: " (show-itype:jibb u.actual ~))]
  ~
++  test-prelude-group-rejections
  ^-  tang
  =/  source=@t  '++ value 0'
  =/  duplicate=(list iprelude-group-source:jibb)
    ~[[%widget /tests/group/one/jibb source] [%widget /tests/group/two/jibb source]]
  ?^  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon duplicate))  ~[leaf+"duplicate group face was accepted"]
  =/  invalid=(list iprelude-group-source:jibb)  ~[[%widget /tests/group/bad/jibb '++ value (']]
  ?^  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon invalid))  ~[leaf+"invalid group source was accepted"]
  ~
++  test-prelude-group-transitive-report
  ^-  tang
  =/  inner=@t  (of-wain:format ~['+$ widget-tree |$ [A]' '  %done' '  [%node value=A next=(widget-tree A)]'])
  =/  outer=@t  (of-wain:format ~['/= source /lib/jibb/groups/other' '++ fetch ^- (widget-tree.source @t) %done'])
  =/  sources=(list iprelude-group-source:jibb)
    ~[[%widget /lib/jibb/groups/widget/jibb outer] [%other /lib/jibb/groups/other/jibb inner]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon sources))
  ?~  prep
    =/  base=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
    ?~  base  ~[leaf+"ordinary prelude did not prepare"]
    =/  bundle=jbundle:jibb  ~[[/lib/jibb/groups/widget/jibb outer] [/lib/jibb/groups/other/jibb inner]]
    =/  first=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb /lib/jibb/groups/widget/jibb outer ~ ~ bundle ~[/lib/jibb/groups/widget/jibb] values.u.base molds.u.base ~ `iface.u.base)
    ?:  ?=(%| -.first)  ~[leaf+(weld "cross-group source: " (trip message.p.first))]
    =/  second=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb /lib/jibb/groups/other/jibb inner ~ ~ bundle ~[/lib/jibb/groups/other/jibb] values.u.base molds.u.base ~ `iface.u.base)
    ?:  ?=(%| -.second)  ~[leaf+(weld "other group source: " (trip message.p.second))]
    ~[leaf+"cross-group sources passed individually but bundle preparation declined"]
  =/  file=path  /tests/prelude-groups/jibb
  =/  src=@t  '++ direct fetch.widget'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  printed=@t  (render-full-types-with-prelude:jibb file src checked `iface.u.prep)
  ?.  (contains (trip printed) "widget-tree.other @t")
    ~[leaf+(weld "cross-group result lacks a usable source-qualified name: " (trip printed))]
  ~
++  test-hoon-group-source
  ^-  tang
  =/  group=@t  hoon-source
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon groups))
  ?~  prep  ~[leaf+"checked hoon group did not prepare"]
  =/  file=path  /tests/prelude-groups/jibb
  =/  src=@t  (of-wain:format ~['++ zero ^- tone.hoon [%0 product="value"]' '++ amount ^- step.hoon 0x1f'])
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  forged=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb /lib/jibb/groups/hoon/jibb '+$ tone @t' ~ ~ ~ ~[/lib/jibb/groups/hoon/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.forged)  ~[leaf+"different source at a group path bypassed public shadowing"]
  =/  outsider=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file '+$ tone @t' ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.outsider)  ~[leaf+"ordinary source bypassed public shadowing"]
  ~
++  test-prelude-group-shadow-dependency
  ^-  tang
  =/  inner=@t  hoon-source
  =/  outer=@t  (of-wain:format ~['/= other /lib/jibb/groups/hoon' '++ fetch ^- tone.other [%0 product="value"]'])
  =/  groups=(list iprelude-group-source:jibb)
    ~[[%widget /lib/jibb/groups/widget/jibb outer] [%hoon /lib/jibb/groups/hoon/jibb inner]]
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal (with-hoon groups))
  ?~  prep
    =/  detailed=(each iprelude:jibb @t)
      (prepare-bundle-detailed:jibb-prelude-fixture prelude internal (with-hoon groups) ~)
    ?:  ?=(%| -.detailed)  ~[leaf+(trip p.detailed)]
    ~[leaf+"group preparation returned no interface without a diagnostic"]
  =/  file=path  /tests/prelude-groups/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file '++ direct fetch.widget' ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  ~
++  test-prelude-private-dependency
  ^-  tang
  =/  hidden=@t  (of-wain:format ~['+$ hidden-tree |$ [A]' '  %done' '  [%node value=A next=(hidden-tree A)]'])
  =/  outer=@t  (of-wain:format ~['/= secret /lib/jibb/private/trees' '++ fetch ^- (hidden-tree.secret @t) %done'])
  =/  groups=(list iprelude-group-source:jibb)  ~[[%widget /lib/jibb/groups/widget/jibb outer]]
  =/  modules=jbundle:jibb  ~[[/lib/jibb/private/trees/jibb hidden]]
  =/  prep=(unit iprelude:jibb)  (prepare-bundle:jibb-prelude-fixture prelude internal (with-hoon groups) modules)
  ?~  prep  ~[leaf+"private dependency did not prepare"]
  =/  file=path  /tests/prelude-groups/jibb
  =/  src=@t  '++ direct fetch.widget'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  printed=@t  (render-full-types-with-prelude:jibb file src checked `iface.u.prep)
  ?.  (contains (trip printed) "/= types-1 /lib/jibb/private/trees")
    ~[leaf+(weld "private dependency lacks a provenance legend: " (trip printed))]
  ?.  (contains (trip printed) "hidden-tree.types-1 @t")
    ~[leaf+(weld "private dependency has no usable reported mold: " (trip printed))]
  =/  forged=jbundle:jibb  ~[[/lib/jibb/private/trees/jibb '+$ hidden-tree @t']]
  =/  conflicting=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ forged ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.conflicting)  ~[leaf+"conflicting source replaced a checked private dependency"]
  =/  inaccessible=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file '++ direct ^- (hidden-tree.secret @t) %done' ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.inaccessible)  ~[leaf+"private dependency leaked into source scope"]
  ~
++  test-public-prelude-uses-group
  ^-  tang
  =/  hoon=@t
    (of-wain:format ~['/- jibb-collections' '+$ step @u' '+$ map |$ [K V] (table.jibb-collections K V)'])
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb hoon]]
  =/  public=@t  prelude
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public internal groups)
  ?~  prep
    =/  detailed=(each iprelude:jibb @t)
      (prepare-bundle-detailed:jibb-prelude-fixture public internal groups ~)
    ?:  ?=(%| -.detailed)  ~[leaf+(trip p.detailed)]
    ~[leaf+"public prelude preparation returned no interface without a diagnostic"]
  =/  bite=(unit ischeme:jibb)  (find-jibb-mold:jibb %bite iface.u.prep)
  ?~  bite  ~[leaf+"group-dependent public mold was omitted"]
  =/  shape=(unit itype:jibb)  (scheme-display-type:jibb u.bite)
  ?~  shape  ~[leaf+"group-dependent mold did not realize"]
  ?.  ?=(%union -.u.shape)  ~[leaf+"bite is not a union"]
  =/  pair=itype:jibb  [%cell [%slot %bloq [%any-atom ~]] [%slot %step [%atom %u]]]
  ?.  =(cases.u.shape ~[[%any-atom ~] pair])  ~[leaf+"bite did not retain its exact atom and faced tuple cases"]
  =/  file=path  /tests/prelude-groups/jibb
  =/  src=@t  (of-wain:format ~['++ by-bloq ^- bite 3' '++ by-pair ^- bite [bloq=3 step=0x1f]'])
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  bad-src=@t  '++ bad ^- bite [bloq=3 step="wrong"]'
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file bad-src)
  ?:  ?=(%| -.parsed)  ~[leaf+"invalid bite control did not parse"]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file bad-src ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.bad)  ~[leaf+"bite accepted a nonnumeric step"]
  ~
++  test-group-bootstrap-preserves-schemes
  ^-  tang
  =/  before=ifile:jibb  *ifile:jibb
  =.  values.before  ~[[%value [[%atom %t] ~ ~]]]
  =.  molds.before  ~[[%model [[%atom %ud] ~ ~]]]
  =/  extended=ifile:jibb  before(values [[%later [[%atom %p] ~ ~]] values.before])
  ?.  (prelude-retains-checked-schemes:jibb before extended)  ~[leaf+"valid extension discarded checked bootstrap schemes"]
  =/  changed=ifile:jibb  extended(values ~[[%value [[%atom %p] ~ ~]]])
  ?:  (prelude-retains-checked-schemes:jibb before changed)  ~[leaf+"changed bootstrap value scheme was accepted"]
  =/  missing=ifile:jibb  extended(molds ~)
  ?:  (prelude-retains-checked-schemes:jibb before missing)  ~[leaf+"missing bootstrap mold scheme was accepted"]
  ~
--
