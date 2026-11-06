/+  jibb
|%
++  test-three-slot-source-faces
  ^-  tang
  =/  source=@t  '++ named |= [one=@t two=@p three=[value=@ud]] three\0a++ chosen ^- $-([@t @p [value=@ud]] [value=@ud]) named\0a'
  =/  at=path  /tests/gate-sample/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  chosen=(unit ischeme:jibb)  (ienv-lookup:jibb %chosen values.iface.p.result)
  ?~  chosen  ~[leaf+"cast gate was omitted"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.chosen)
  ?~  typ  ~[leaf+"cast gate did not close"]
  ?.  ?=(%fn -.u.typ)  ~[leaf+"cast gate was not a gate"]
  =/  expected=itype:jibb
    [%cell [%slot %one [%atom %t]] [%cell [%slot %two [%atom %p]] [%slot %three [%face %value [%atom %ud]]]]]
  ?.  =(sample.u.typ expected)
    ~[leaf+(weld "cast gate lost sample/value labels: " (show-itype:jibb u.typ ~))]
  ~
--
