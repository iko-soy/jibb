/+  jibb
|%
++  check
  |=  source=@t
  ^-  jfile-detailed-result:jibb
  =/  at=path  /tests/capitals/jibb
  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
++  test-merged-capitals
  ^-  tang
  =/  src=@t  '++ uncertain |= x=A ^- [first=B rest=@t] [x "hi"]\0a'
  =/  result=jfile-detailed-result:jibb  (check src)
  ?:  ?=(%& -.result)  ~[leaf+"distinct capitals were unified"]
  =/  expected=@t  '++ uncertain: distinct type variables `A` and `B` must not be forced equal; use the same capital for a shared type\0a/tests/capitals.jibb:1:19: first type variable\0a++ uncertain |= x=A ^- [first=B rest=@t] [x "hi"]\0a                  ^\0a/tests/capitals.jibb:1:31: second type variable\0a++ uncertain |= x=A ^- [first=B rest=@t] [x "hi"]\0a                              ^'
  ?.  =(expected message.p.result)  ~[leaf+"merged-capital diagnostic differs" leaf+(trip message.p.result)]
  ~
++  test-distinct-capitals
  ^-  tang
  =/  result=jfile-detailed-result:jibb  (check '++ both |= [x=A y=B] [x y]\0a')
  ?:  ?=(%| -.result)  ~[leaf+"independent capitals were rejected" leaf+(trip message.p.result)]
  ~
++  test-earlier-open-tag
  ^-  tang
  =/  src=@t  '++ first %open\0a++ uncertain |= x=A ^- [first=B rest=@t] [x "hi"]\0a'
  =/  result=jfile-detailed-result:jibb  (check src)
  ?:  ?=(%& -.result)  ~[leaf+"earlier open tag was accepted"]
  =/  expected=@t  '++ first: nothing fixes the union of %open; add a `^-`\0a/tests/capitals.jibb:1:10: nothing fixes the union of %open; add a `^-`\0a++ first %open\0a         ^'
  ?.  =(expected message.p.result)  ~[leaf+"earlier error priority changed" leaf+(trip message.p.result)]
  ~
--
