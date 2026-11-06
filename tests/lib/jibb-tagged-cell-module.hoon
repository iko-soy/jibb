/+  jibb
|%
++  check-module
  |=  [source=@t okay=?]
  ^-  tang
  =/  at=path  /ui/tagged/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  okay
    ?:  ?=(%| -.result)  ~[leaf+"valid module was rejected: {(trip message.p.result)}"]
    =/  value=(unit ischeme:jibb)  (ienv-lookup:jibb %one values.iface.p.result)
    ?~  value  ~[leaf+"tagged value was not exported"]
    ?.  =((show-itype:jibb typ.u.value ~) "msg")  ~[leaf+"tagged value did not retain named union: {(show-itype:jibb typ.u.value ~)}"]
    ~
  ?:  ?=(%& -.result)  ~[leaf+"invalid tagged cell was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ one: msg has no case `%other`' '/ui/tagged.jibb:1:4: expected union has type msg' '+$ msg' '   ^' '/ui/tagged.jibb:2:3: expected union has type msg' '  %submit' '  ^' '/ui/tagged.jibb:4:8: expected union has type msg' '++ one [%other 1]' '       ^' '/ui/tagged.jibb:4:9: tag literal has type %other' '++ one [%other 1]' '        ^'])
  ?.  =(message.p.result expected)
    ~[leaf+"wrong tagged-cell error: {(trip message.p.result)}"]
  ~
++  test-tagged-cell-module
  ^-  tang
  =/  cases=(list [source=@t okay=?])
    :~  [(of-wain:format ~['+$ msg' '  %submit' '  [%toggled @ud]' '++ one [%toggled 1]' '++ use ^- msg one']) &]
        [(of-wain:format ~['+$ msg' '  %submit' '  [%toggled @ud]' '++ use ^- msg one' '++ one [%toggled 1]']) &]
        [(of-wain:format ~['+$ msg' '  %submit' '  [%toggled @ud]' '++ one [%other 1]' '++ use ^- msg one']) |]
    ==
  |-
  ?~  cases  ~
  =/  result=tang  (check-module source.i.cases okay.i.cases)
  ?^  result  result
  $(cases t.cases)
--
