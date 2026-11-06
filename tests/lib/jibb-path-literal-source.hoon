/+  jibb
|%
++  check
  |=  [public=@t accepts=?]
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude:jibb public)
  ?~  prepared  ~[leaf+"path test prelude did not prepare"]
  =/  at=path  /ui/path-test/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at '++ value /posts/~zod' ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  accepts
    ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
    ~
  ?:  ?=(%& -.checked)  ~[leaf+"a path literal bypassed the checked prelude mold"]
  =/  expected=@t
    (of-wain:format ~['++ value: path literal needs the checked prelude path mold' '/ui/path-test.jibb:1:10: path literal' '++ value /posts/~zod' '         ^'])
  ?.  =(expected message.p.checked)  ~[leaf+(trip message.p.checked)]
  ~
++  test-path-literal-source
  ^-  tang
  =/  list-source=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a'
  (weld (check (cat 3 list-source '+$ path (list @ta)\0a') &) (check (cat 3 list-source '+$ path (list @ud)\0a') |))
++  test-path-literal-missing
  ^-  tang
  (check '++ identity |= x x\0a' |)
--
