/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-body-context
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  at=path  /tests/body-context/jibb
  =/  cases=(list [label=tape source=@t bad=?])
    :~  ["unit atom through a local value" '++ keep |= [condition=? value=@] ^- (unit @)\0a  ++ held value\0a  ?- condition\0a  %.y `held\0a  %.n ~\0a' |]
        ["unit atom through a local record" '++ keep |= [condition=? value=@] ^- (unit @)\0a  ++ parsed ^- [valid=? value=@] [condition value]\0a  ?- valid.parsed\0a  %.y `value.parsed\0a  %.n ~\0a' |]
        ["nested local bodies" '++ keep |= [condition=? value=@] ^- (unit @)\0a  ++ held value\0a  ?- condition\0a  %.y\0a    ++ again held\0a    `again\0a  %.n ~\0a' |]
        ["wrong payload through local value" '++ keep |= [condition=? value=@t] ^- (unit @ud)\0a  ++ held value\0a  ?- condition\0a  %.y `held\0a  %.n ~\0a' &]
    ==
  %+  murn  cases
  |=  c=[label=tape source=@t bad=?]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source.c ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.result)
    ?:(bad.c `leaf+(weld label.c ": accepted incompatible payload") ~)
  ?:  bad.c
    =/  rendered=tape  (trip message.p.result)
    ?.  &((contains rendered "@ud") (contains rendered "@t") (contains rendered "/tests/body-context.jibb:4:"))
      `leaf+(weld label.c (weld ": wrong diagnostic: " rendered))
    ~
  `leaf+(weld label.c (weld ": " (trip message.p.result)))
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?:  =(needle (scag (lent needle) hay))  &
  ?~  hay  |
  $(hay t.hay)
--
