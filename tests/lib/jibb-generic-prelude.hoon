/+  jibb, jibb-import
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-grouped-reader-evidence
  ^-  tang
  =/  sur=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  cert  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon sur cor)
  ?.  ?=([%& [%generic-source *]] cert)  ~[leaf+"Hoon map forwarding source was not certified"]
  =/  externals=iexternals:jibb  ~[[%fixture %table cert]]
  =/  modules=jbundle:jibb  ~[[/sur/fixture/hoon sur]]
  =/  group=@t  '/- fixture\0a+$ standard-map |$ [K V] (table.fixture K V)\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  public=@t  '+$ map |$ [K V] (standard-map.hoon K V)\0a'
  =/  built=(unit iprelude:jibb)  (prepare-prelude-with-group-evidence:jibb public '' groups modules externals)
  ?~  built  ~[leaf+"certified grouped prelude did not prepare"]
  =/  checked-groups=(list iprelude-group:jibb)  groups.iface.u.built
  ?~  checked-groups  ~[leaf+"checked group was not retained"]
  ?~  graph.i.checked-groups  ~[leaf+"group reader evidence graph was not retained"]
  ?.  =(externals.u.graph.i.checked-groups externals)  ~[leaf+"group lost exact reader evidence"]
  =/  valid=@t  '++ identity |= value=(map @t @p) value\0a++ generic |= value=(map A @t) value\0a'
  =/  good=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb valid ~ ~ ~ built)
  ?.  &((contains (trip good) "module kind: library") (contains (trip good) "(map @t @p)") (contains (trip good) "contains no gates"))
    ~[leaf+"checked prelude lost map type or key constraint" leaf+(trip good)]
  =/  bad=@t  '++ wrong |= value=(map $-(@t @t) @ud) value\0a'
  =/  rejected=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb bad ~ ~ ~ built)
  =/  expected=@t
    (of-wain:format ~['++ wrong: map keys cannot contain gates' '/lib/jibb/prelude.jibb:1:4: earlier binding' '+$ map |$ [K V] (standard-map.hoon K V)' '   ^' '/ui/test.jibb:1:20: collection has type (map A B) where A contains no gates' '++ wrong |= value=(map $-(@t @t) @ud) value' '                   ^' '/ui/test.jibb:1:24: key has type $-(@t @t)' '++ wrong |= value=(map $-(@t @t) @ud) value' '                       ^'])
  ?.  =(rejected expected)  ~[leaf+"map key diagnostic lost its type or sites" leaf+(trip rejected)]
  =/  original=@t  '++ m |= [g=$-(@ud @ud) mp=(map $-(@ud @ud) @ud)] (put.by mp g 1)\0a'
  =/  original-error=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb original ~ ~ ~ built)
  =/  original-expected=@t
    (of-wain:format ~['++ m: map keys cannot contain gates' '/lib/jibb/prelude.jibb:1:4: earlier binding' '+$ map |$ [K V] (standard-map.hoon K V)' '   ^' '/ui/test.jibb:1:12: key argument' '++ m |= [g=$-(@ud @ud) mp=(map $-(@ud @ud) @ud)] (put.by mp g 1)' '           ^' '/ui/test.jibb:1:28: collection has type (map A B) where A contains no gates' '++ m |= [g=$-(@ud @ud) mp=(map $-(@ud @ud) @ud)] (put.by mp g 1)' '                           ^' '/ui/test.jibb:1:32: key has type $-(@ud @ud)' '++ m |= [g=$-(@ud @ud) mp=(map $-(@ud @ud) @ud)] (put.by mp g 1)' '                               ^'])
  ?.  =(original-error original-expected)  ~[leaf+"original map key probe lost its diagnostic" leaf+(trip original-error)]
  =/  uncertain=@t  '++ open |= value=(map * @ud) value\0a'
  =/  unknown=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb uncertain ~ ~ ~ built)
  ?:  (contains (trip unknown) "map keys cannot contain gates")
    ~[leaf+"an unknown key was reported as a proven gate" leaf+(trip unknown)]
  ?^  (prepare-prelude-with-group-bundle:jibb public '' groups modules)
    ~[leaf+"legacy source-only group preparation fabricated Hoon evidence"]
  ?^  (prepare-prelude-with-group-evidence:jibb public '' groups ~ externals)
    ~[leaf+"missing Hoon source was accepted"]
  =/  changed=jbundle:jibb  ~[[/sur/fixture/hoon (cat 3 sur ':: changed\0a')]]
  ?^  (prepare-prelude-with-group-evidence:jibb public '' groups changed externals)
    ~[leaf+"changed Hoon source reused a stale descriptor"]
  ?^  (prepare-prelude-with-group-evidence:jibb public '' groups modules ~[[%fixture %table cert] [%fixture %table cert]])
    ~[leaf+"duplicate reader evidence was accepted"]
  ~
++  test-group-error-retains-reader-evidence
  ^-  tang
  =/  sur=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  cert  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon sur cor)
  =/  evidence=iexternals:jibb  ~[[%fixture %table cert]]
  =/  modules=jbundle:jibb  ~[[/sur/fixture/hoon sur]]
  =/  group=@t  '/- fixture\0a+$ standard-map |$ [K V] (table.fixture K V)\0a++ wrong ^- @t 4\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  public=@t  '+$ map |$ [K V] (standard-map.hoon K V)\0a'
  =/  result  (prepare-prelude-with-group-evidence-detailed:jibb public '' groups modules evidence)
  ?:  ?=(%& -.result)  ~[leaf+"invalid grouped value was accepted"]
  ?.  &((contains (trip p.result) "++ wrong") (contains (trip p.result) "/lib/jibb/groups/hoon.jibb:3:"))
    ~[leaf+"group diagnostic lost the real owner or source" leaf+(trip p.result)]
  ~

--
