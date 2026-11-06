/+  jibb, jibb-import
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-shared-source-readers
  ^-  tang
  =/  sur=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a++  keys  |$  [key]  (set key)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  table  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon sur cor)
  =/  keys  (read-generic-source:jibb-import %fixture %keys /sur/fixture/hoon sur cor)
  ?.  &(?=([%& [%generic-source *]] table) ?=([%& [%generic-source *]] keys))
    ~[leaf+"both generators were not source-certified"]
  =/  externals=iexternals:jibb  ~[[%fixture %table table] [%fixture %keys keys]]
  =/  modules=jbundle:jibb  ~[[/sur/fixture/hoon sur]]
  =/  group=@t  '/- fixture\0a+$ maps |$ [K V] (table.fixture K V)\0a+$ sets |$ [K] (keys.fixture K)\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  public=@t  '+$ map |$ [K V] (maps.hoon K V)\0a+$ set |$ [K] (sets.hoon K)\0a'
  =/  built=(unit iprelude:jibb)  (prepare-prelude-with-group-evidence:jibb public '' groups modules externals)
  ?~  built  ~[leaf+"shared-source generators did not prepare"]
  =/  changed=@t  (cat 3 sur ':: changed\0a')
  =/  changed-keys  (read-generic-source:jibb-import %fixture %keys /sur/fixture/hoon changed cor)
  ?.  ?=([%& [%generic-source *]] changed-keys)  ~[leaf+"commented source did not parse"]
  =/  stale=iexternals:jibb  ~[[%fixture %table table] [%fixture %keys changed-keys]]
  ?^  (prepare-prelude-with-group-evidence:jibb public '' groups modules stale)
    ~[leaf+"a stale descriptor sharing the source path was accepted"]
  =/  src=@t  '++ map-id |= value=(map @ud @t) value\0a++ set-id |= value=(set @p) value\0a'
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb src ~ ~ ~ built)
  ?.  &((contains (trip report) "++ map-id: $-((map @ud @t) (map @ud @t))") (contains (trip report) "++ set-id: $-((set @p) (set @p))"))
    ~[leaf+"shared-source generators lost their collection identities" leaf+(trip report)]
  ~
--
