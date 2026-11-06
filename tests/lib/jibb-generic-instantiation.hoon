/+  jibb, jibb-import
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-independent-instantiations
  ^-  tang
  =/  sur=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  cert  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon sur cor)
  =/  externals=iexternals:jibb  ~[[%fixture %table cert]]
  =/  modules=jbundle:jibb  ~[[/sur/fixture/hoon sur]]
  =/  group=@t  '/- fixture\0a+$ standard-map |$ [K V] (table.fixture K V)\0a'
  =/  groups=(list iprelude-group-source:jibb)  ~[[%hoon /lib/jibb/groups/hoon/jibb group]]
  =/  public=@t  '+$ map |$ [K V] (standard-map.hoon K V)\0a'
  =/  built=(unit iprelude:jibb)  (prepare-prelude-with-group-evidence:jibb public '' groups modules externals)
  ?~  built  ~[leaf+"certified grouped prelude did not prepare"]
  =/  code=@t
    '++ identity |= value=(map A @t) value\0a++ ship-map |= value=(map @p @t) (identity value)\0a++ number-map |= value=(map @ud @t) (identity value)\0a++ gate-values |= value=(map @ud $-(@t @t)) value\0a'
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb code ~ ~ ~ built)
  ?.  &((contains (trip report) "++ ship-map: $-((map @p @t) (map @p @t))") (contains (trip report) "++ number-map: $-((map @ud @t) (map @ud @t))") (contains (trip report) "++ gate-values: $-((map @ud $-(@t @t)) (map @ud $-(@t @t)))"))
    ~[leaf+"independent map instantiations were not preserved" leaf+(trip report)]
  =/  nested=@t  '++ nested |= value=(map [label=@t callback=$-(@t @t)] @ud) value\0a'
  =/  bad=@t  (golden-types-with-prepared-prelude:jibb /ui/test/jibb nested ~ ~ ~ built)
  ?.  &((contains (trip bad) "map keys cannot contain gates") (contains (trip bad) "callback=$-(@t @t)"))
    ~[leaf+"a nested gate key was not rejected with its type" leaf+(trip bad)]
  ~
--
