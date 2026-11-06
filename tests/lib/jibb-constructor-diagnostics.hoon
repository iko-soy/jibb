/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-known-constructor-type
  ^-  tang
  =/  src=@t  '+$ msg\0a  [%got value=@p]\0a  %other\0a++ call |= callback=$-(@t M) (callback "hi")\0a++ wrong ^- msg (call |=%got)\0a'
  =/  got=@t  (golden-types:jibb /tests/constructor/jibb src)
  ?.  (contains (trip got) "constructor `%got` sample does not fit its case payload")
    ~[leaf+"constructor payload mismatch was not explained" leaf+(trip got)]
  ?.  &((contains (trip got) "/tests/constructor.jibb:2:15: case payload has type @p") (contains (trip got) "/tests/constructor.jibb:5:23: constructor sample has type @t"))
    ~[leaf+"constructor payload and sample sites or types differ" leaf+(trip got)]
  ~
++  test-report-does-not-bind-variables
  ^-  tang
  =/  got=itype:jibb  (diagnostic-context-type:jibb [%cell [%var 4] [%atom %t]] [%cell [%atom %p] [%atom %t]] ~ 5)
  ?.  =(got [%cell [%var 4] [%atom %t]])
    ~[leaf+"diagnostic specialized an ordinary type variable"]
  =/  tag=lit:jibb  [%term %tas %got '%got']
  =/  actual=itype:jibb  [%tag 0 tag &]
  =/  target=itype:jibb
    [%fn [%atom %t] [%union ~[[%cell [%const tag] [%atom %t]] [%cell [%const tag] [%atom %p]]] ~ ~ ~]]
  =/  ambiguous=itype:jibb  (diagnostic-context-type:jibb actual target ~ 1)
  ?.  =(actual ambiguous)
    ~[leaf+"diagnostic chose one of two constructor cases"]
  ~
++  test-infinite-call-type
  ^-  tang
  =/  got=@t  (golden-types:jibb /tests/occurs/jibb '++ bad |= x (x x)\0a')
  ?.  (contains (trip got) "call requires an infinite type: its gate occurs inside its own sample")
    ~[leaf+"occurs check lost its reason" leaf+(trip got)]
  ?.  &((contains (trip got) "/tests/occurs.jibb:1:14:") (contains (trip got) "/tests/occurs.jibb:1:16:"))
    ~[leaf+"occurs check lost its conflicting sites" leaf+(trip got)]
  ~
--
