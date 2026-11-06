/+  jibb, jibb-import
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-imported-generic-map
  ^-  tang
  =/  sur=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  imported  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon sur cor)
  ?.  ?=([%& [%generic-source *]] imported)  ~[leaf+"reader did not certify table"]
  =/  ext=iexternals:jibb  ~[[%fixture %table imported]]
  =/  src=@t  '/- fixture\0a++ identity |= value=(table.fixture @t @p) value\0a++ generic |= value=(table.fixture A @t) value\0a'
  =/  result=@t  (golden-types-with-modules:jibb /ui/test/jibb src ext ~ ~)
  ?.  &((contains (trip result) "module kind: library") (contains (trip result) "(map @t @p)") (contains (trip result) "contains no gates"))
    ~[leaf+"generic map did not check with its constraint" leaf+(trip result)]
  =/  bad=@t  '/- fixture\0a++ wrong |= value=(table.fixture $-(@t @t) @ud) value\0a'
  =/  rejected=@t  (golden-types-with-modules:jibb /ui/test/jibb bad ext ~ ~)
  ?:  (contains (trip rejected) "module kind: library")
    ~[leaf+"gate-bearing map key was accepted" leaf+(trip rejected)]
  ~
++  test-generic-descriptor-validation
  ^-  tang
  =/  bad1=*  [%& [%generic 2 [%apply %map ~[[%param 0] [%param 2]]]]]
  =/  bad2=*  [%& [%generic 1 [%apply %bogus ~[[%param 0]]]]]
  =/  ex1=iexternals:jibb  ~[[%fixture %table bad1]]
  =/  ex2=iexternals:jibb  ~[[%fixture %table bad2]]
  ?^  (find-imported-generic:jibb %fixture %table ex1 ~[%fixture] *ifile:jibb)
    ~[leaf+"out-of-range generic parameter was accepted"]
  ?^  (find-imported-generic:jibb %fixture %table ex2 ~[%fixture] *ifile:jibb)
    ~[leaf+"unrecognized collection was accepted"]
  ?^  (find-imported-generic:jibb %fixture %table ex1 ~ *ifile:jibb)
    ~[leaf+"unimported generic module was accepted"]
  ~
++  test-qualified-name-is-not-evidence
  ^-  tang
  =/  sur=@t  '|%\0a++  map  |$  [item]  (list item)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  result  (read-generic-source:jibb-import %fixture %map /sur/fixture/hoon sur cor)
  ?.  ?=([%& [%generic-source *]] result)  ~[leaf+"list forwarding source was not certified"]
  =/  ext=iexternals:jibb  ~[[%fixture %map result]]
  =/  src=@t  '/- fixture\0a++ okay |= value=(map.fixture $-(@t @t)) value\0a'
  =/  report=@t  (golden-types-with-modules:jibb /ui/test/jibb src ext ~ ~)
  ?.  (contains (trip report) "module kind: library")
    ~[leaf+"qualified name falsely imposed a map key restriction" leaf+(trip report)]
  ~
--
