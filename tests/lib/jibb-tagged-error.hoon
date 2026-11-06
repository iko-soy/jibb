/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-payload-site
  ^-  tang
  =/  src=@t  '+$ msg\0a  %ok\0a  %other\0a+$ action\0a  [%every gap=@dr reply=$-(@da msg)]\0a  %none\0a++ bad ^- action [%every ~zod |=(now=@da %ok)]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /tests/tagged-error/jibb src ~ ~ ~ ~[/tests/tagged-error/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"wrong payload was accepted"]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:7:26")
    ~[leaf+"wrong payload did not retain its source site" leaf+(trip message.p.result)]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:5:15")
    ~[leaf+"wrong payload did not retain its expected field site" leaf+(trip message.p.result)]
  ?.  (contains (trip message.p.result) "expected field has type @dr")
    ~[leaf+"wrong payload did not name the expected type" leaf+(trip message.p.result)]
  ?.  (contains (trip message.p.result) "actual field has type @p")
    ~[leaf+"wrong payload did not name the actual type" leaf+(trip message.p.result)]
  ~
++  test-second-field-site
  ^-  tang
  =/  src=@t  '+$ msg\0a  %ok\0a  %other\0a+$ action\0a  [%every count=@ud gap=@dr reply=$-(@da msg)]\0a  %none\0a++ bad ^- action [%every 1 ~zod |=(now=@da %ok)]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /tests/tagged-error/jibb src ~ ~ ~ ~[/tests/tagged-error/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"second wrong payload was accepted"]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:5:25")  ~[leaf+"second field declaration site missing" leaf+(trip message.p.result)]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:7:28")  ~[leaf+"second field actual site missing" leaf+(trip message.p.result)]
  ~
++  test-nested-field-site
  ^-  tang
  =/  src=@t  '+$ msg\0a  %ok\0a  %other\0a+$ action\0a  [%every header=[count=@ud gap=@dr] reply=$-(@da msg)]\0a  %none\0a++ bad ^- action [%every [count=1 gap=~zod] |=(now=@da %ok)]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /tests/tagged-error/jibb src ~ ~ ~ ~[/tests/tagged-error/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"nested wrong payload was accepted"]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:5:33")  ~[leaf+"nested field declaration site missing" leaf+(trip message.p.result)]
  ?.  (contains (trip message.p.result) "/tests/tagged-error.jibb:7:39")  ~[leaf+"nested field actual site missing" leaf+(trip message.p.result)]
  ~
++  test-earlier-tag
  ^-  tang
  =/  src=@t  '+$ msg\0a  %ok\0a  %other\0a+$ action\0a  [%every first=msg gap=@dr]\0a  %none\0a++ bad ^- action [%every %wrong ~zod]\0a'
  =/  result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /tests/tagged-error/jibb src ~ ~ ~ ~[/tests/tagged-error/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"earlier bad tag was accepted"]
  ?.  (contains (trip message.p.result) "%wrong")  ~[leaf+"later field hid the earlier bad tag" leaf+(trip message.p.result)]
  ~
++  test-unknown-priority
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  items=(list item:jibb)  ~[[site ~ [%wing site ~[%x]]] [site ~ [%lit site [%ship %p 0 '~zod']]]]
  =/  fields=(list field:jibb)  ~[[%bare site [%aura site %t]] [%bare site [%aura site %dr]]]
  =/  actual=itype:jibb  [%cell [%noun ~] [%atom %p]]
  =/  expected=itype:jibb  [%cell [%atom %t] [%atom %dr]]
  =/  state=istate:jibb  *istate:jibb
  ?^  (union-payload-field-items:jibb items fields actual expected state)
    ~[leaf+"a later mismatch bypassed an earlier unknown fit"]
  ~
++  test-both-open-priority
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  actual=itype:jibb  [%tag 0 [%term %tas %add '%add'] |]
  =/  expected=itype:jibb  [%tag 1 [%term %tas %sub '%sub'] |]
  =/  value=expr:jibb  [%lit site [%term %tas %add '%add']]
  =/  shape=shape:jibb  [%aura site %t]
  =/  state=istate:jibb  *istate:jibb
  ?^  (union-payload-field-error:jibb value actual expected shape state)
    ~[leaf+"two open tags were treated as a definite mismatch"]
  ~
--
