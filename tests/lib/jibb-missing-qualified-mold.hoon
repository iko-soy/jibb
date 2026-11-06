/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
++  test-missing-qualified-mold
  ^-  tang
  =/  at=path  /tests/missing-mold/jibb
  =/  dep=@t  '+$ yes @t\0a++ missing |= x=@t x\0a'
  =/  modules=jbundle:jibb  ~[[/tests/dep/jibb dep]]
  =/  src=@t  '/= dep /tests/dep\0a++ bad |= x=missing.dep x\0a'
  =/  got=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.got)  ~[leaf+"missing exported mold was accepted"]
  =/  expected=@t  '++ bad: module `dep` has no mold `missing`\0a/tests/missing-mold.jibb:1:4: earlier binding\0a/= dep /tests/dep\0a   ^\0a/tests/missing-mold.jibb:2:13: unknown module mold\0a++ bad |= x=missing.dep x\0a            ^'
  ?.  =(message.p.got expected)  ~[leaf+"missing mold diagnostic differs" leaf+(trip message.p.got)]
  =/  valid=@t  '/= dep /tests/dep\0a++ ok |= x=yes.dep x\0a'
  =/  good=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at valid ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.good)  ~[leaf+"exported mold was rejected" leaf+(trip message.p.good)]
  =/  bad-module=@t  '/= dep /tests/absent\0a++ bad |= x=missing.dep x\0a'
  =/  missing=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at bad-module ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.missing)  ~[leaf+"missing module was accepted"]
  ?.  (contains (trip message.p.missing) "module source missing")  ~[leaf+"missing member hid missing module" leaf+(trip message.p.missing)]
  =/  nested=@t  '/= dep /tests/dep\0a+$ local [item=missing.dep]\0a++ val |= x=local x\0a'
  =/  nested-out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at nested ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.nested-out)  ~[leaf+"nested missing mold was accepted"]
  ?.  (contains (trip message.p.nested-out) "module `dep` has no mold `missing`")  ~[leaf+"nested missing mold lost its owner" leaf+(trip message.p.nested-out)]
  =/  applied=@t  '/= dep /tests/dep\0a++ bad |= x=(missing.dep @t) x\0a'
  =/  applied-out=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at applied ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.applied-out)  ~[leaf+"missing generic mold was accepted"]
  ?.  (contains (trip message.p.applied-out) "module `dep` has no mold `missing`")  ~[leaf+"missing generic mold lost its owner" leaf+(trip message.p.applied-out)]
  ~
--
