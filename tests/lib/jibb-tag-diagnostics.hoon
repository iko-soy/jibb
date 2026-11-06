::  A payload tag never proves the presence of the same tag at the head.
/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-same-head-atom-and-cell
  ^-  tang
  =/  source=@t  '+$ msg\0a  %same\0a  [%same data=@t]\0a++ scalar ^- msg %same\0a++ cell ^- msg [%same "hi"]\0a'
  =/  actual=@t  (golden-types:jibb /tests/same-head/jibb source)
  =/  wanted=@t  'module kind: library\0a+$ msg: msg\0a++ scalar: msg\0a++ cell: msg'
  ?.  =(actual wanted)  ~[leaf+"a valid singleton was diagnosed as missing its payload" leaf+(trip actual)]
  ~
++  test-tag-position
  ^-  tang
  =/  source=@t  '+$ msg\0a  [%old item=%new]\0a  [%other item=@t]\0a++ wrong ^- msg [%new %new]\0a'
  =/  actual=@t  (golden-types:jibb /tests/tag-position/jibb source)
  ?.  (contains (trip actual) "msg has no case `%new`")
    ~[leaf+"a payload constant hid a missing head tag" leaf+(trip actual)]
  ?.  &((contains (trip actual) ":2:3:") (contains (trip actual) ":4:18:"))
    ~[leaf+"tag error did not retain its union and literal sites" leaf+(trip actual)]
  ~
++  test-ambiguous-head-payload
  ^-  tang
  =/  source=@t  '+$ msg\0a  [%same @t %text]\0a  [%same @p %ship]\0a++ text ^- msg [%same "hi" %text]\0a++ ship ^- msg [%same ~zod %ship]\0a'
  =/  actual=@t  (golden-types:jibb /tests/shared-head/jibb source)
  =/  wanted=@t  'module kind: library\0a+$ msg: msg\0a++ text: msg\0a++ ship: msg'
  ?.  =(actual wanted)  ~[leaf+"diagnostics selected a case only by its shared head" leaf+(trip actual)]
  ~
--
