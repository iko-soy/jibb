/+  jibb
|%
++  test-tagged-flag
  ^-  tang
  =/  at=path  /ui/flagged/jibb
  =/  ordinary=@t  '++ one [%.y 1]'
  =/  plain=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at ordinary ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.plain)  ~[leaf+"uncontextualized flag tuple failed: {(trip message.p.plain)}"]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %one values.iface.p.plain)
  ?~  scheme  ~[leaf+"flag tuple was not exported"]
  ?.  =((show-itype:jibb typ.u.scheme ~) "[? @ud]")  ~[leaf+"flag tuple has the wrong default type"]
  ::  Imported `%&` is the same noun as source `%.y`.
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb at ordinary)
  ?:  ?=(%| -.parsed)  ~[leaf+"flag tuple did not parse"]
  =/  defs=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] defs)  ~[leaf+"flag tuple definition missing"]
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(general-defer &, owner %one)
  =/  inferred=iresult:jibb  (infer-fragment:jibb val.i.defs ~ st)
  ?:  ?=(%| -.inferred)  ~[leaf+"flag tuple inference failed"]
  ?.  ?=(%var -.typ.p.inferred)  ~[leaf+"flag tuple did not wait for context"]
  =/  imported=lit:jibb  [%term %f 0 '%&']
  =/  union=itype:jibb  [%union ~[[%cell [%const imported] [%atom %ud]]] `[at %choice] `%choice ~]
  =/  bound=isub:jibb  (itype-bind:jibb id.typ.p.inferred union sub.state.p.inferred)
  =/  fitted=(unit istate:jibb)  (icore-solve:jibb state.p.inferred(sub bound))
  ?~  fitted  ~[leaf+"flag noun did not fit the imported case"]
  ?^  queue.u.fitted  ~[leaf+"flag noun left its imported case open"]
  =/  wrong=@t
    (of-wain:format ~['+$ choice' '  [%.n @ud]' '  [%other @t]' '++ one [%.y 42]' '++ use ^- choice one'])
  =/  rejected=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at wrong ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.rejected)  ~[leaf+"missing flag case was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ one: choice has no case `%.y`' '/ui/flagged.jibb:1:4: expected union has type choice' '+$ choice' '   ^' '/ui/flagged.jibb:2:3: expected union has type choice' '  [%.n @ud]' '  ^' '/ui/flagged.jibb:4:8: expected union has type choice' '++ one [%.y 42]' '       ^' '/ui/flagged.jibb:4:9: tag literal has type %.y' '++ one [%.y 42]' '        ^'])
  ?.  =(message.p.rejected expected)  ~[leaf+"flag case diagnostic differs: {(trip message.p.rejected)}"]
  =/  cases=(list @t)
    :~  (of-wain:format ~['+$ choice' '  [%.y @ud]' '  [%.n @t]' '++ one [%.y 42]' '++ use ^- choice one'])
        (of-wain:format ~['+$ choice' '  [%.y @ud]' '  [%.n @t]' '++ use ^- choice one' '++ one [%.y 42]'])
    ==
  |-
  ?~  cases  ~
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at i.cases ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"flag-headed union case failed: {(trip message.p.checked)}"]
  =/  value=(unit ischeme:jibb)  (ienv-lookup:jibb %one values.iface.p.checked)
  ?~  value  ~[leaf+"flag case was not exported"]
  ?.  =((show-itype:jibb typ.u.value ~) "choice")  ~[leaf+"flag case lost its union type"]
  $(cases t.cases)
--
