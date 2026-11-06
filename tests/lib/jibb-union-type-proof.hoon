/+  jibb
|%
++  test-type-disjointness
  ^-  tang
  =/  at=path  /tests/type-union-proof/jibb
  =/  good=@t
    (of-wain:format ~['+$ pair-tag |$ [A B] [%wrapped A B]' '+$ choice' '  (pair-tag @t @ud)' '  [%other @p]' '++ id |= x=choice x'])
  =/  nested=@t
    (of-wain:format ~['+$ tagged |$ [A] [%wrapped A]' '+$ choice' '  (tagged (tagged @t))' '  [%other @p]' '++ id |= x=choice x'])
  =/  bad=@t
    (of-wain:format ~['+$ pair-tag |$ [A B] [%wrapped A B]' '+$ choice' '  (pair-tag @t @ud)' '  [%wrapped @p @ud]' '++ id |= x=choice x'])
  =/  good-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at good ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.good-result)  ~[leaf+"distinct two-parameter alias union rejected: {(trip message.p.good-result)}"]
  =/  nested-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at nested ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.nested-result)  ~[leaf+"nested alias union rejected: {(trip message.p.nested-result)}"]
  =/  bad-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at bad ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.bad-result)  ~[leaf+"overlapping generic alias cases accepted"]
  =/  expected=@t
    (of-wain:format ~['module mold choice has overlapping cases' '/tests/type-union-proof.jibb:3:3: first union case' '  (pair-tag @t @ud)' '  ^' '/tests/type-union-proof.jibb:4:3: overlapping case' '  [%wrapped @p @ud]' '  ^'])
  ?.  =(message.p.bad-result expected)  ~[leaf+"overlap diagnostic differed: {(trip message.p.bad-result)}"]
  ~
--
