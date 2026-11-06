::  Exhaustiveness and dead arms for nested patterns through the full checker.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-coverage-branch
  ^-  tang
  =/  at=path  /ui/probe/jibb
  =/  good=@t
    (of-wain:format ~['+$ action' '  [%move dir=? amount=@ud]' '  %stop' '++ act |= x=action' '  ?- x' '    [%move %.y n] n' '    [%move %.n n] n' '    %stop 0'])
  =/  accepted=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at good ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.accepted)  ~[leaf+"exhaustive nested match rejected: {(trip message.p.accepted)}"]
  =/  missing=@t
    (of-wain:format ~['+$ action' '  [%move dir=? amount=@ud]' '  %stop' '++ act |= x=action' '  ?- x' '    [%move %.y n] n' '    %stop 0'])
  =/  missing-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at missing ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.missing-result)  ~[leaf+"incomplete nested match was accepted"]
  =/  missing-expected=@t
    (of-wain:format ~['++ act: missing match case [%move [%.n 0]]' '/ui/probe.jibb:2:4: missing case is declared here' '  [%move dir=? amount=@ud]' '   ^' '/ui/probe.jibb:5:3: non-exhaustive match' '  ?- x' '  ^' '/ui/probe.jibb:5:6: subject has type action' '  ?- x' '     ^'])
  ?.  =(missing-expected message.p.missing-result)
    ~[leaf+"missing match witness or sites differ: {(trip message.p.missing-result)}"]
  =/  dead=@t
    (of-wain:format ~['+$ action' '  [%move dir=? amount=@ud]' '  %stop' '++ act |= x=action' '  ?- x' '    [%move * *] 1' '    [%move %.y n] n' '    %stop 0'])
  =/  dead-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at dead ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.dead-result)  ~[leaf+"covered nested arm was accepted"]
  =/  dead-expected=@t
    (of-wain:format ~['++ act: branch arm is covered by earlier arms' '/ui/probe.jibb:6:5: covering arm' '    [%move * *] 1' '    ^' '/ui/probe.jibb:7:5: covered arm' '    [%move %.y n] n' '    ^'])
  ?.  =(dead-expected message.p.dead-result)
    ~[leaf+"covering and covered arm sites differ: {(trip message.p.dead-result)}"]
  =/  cell=@t
    (of-wain:format ~['++ demo |= x=[@ud @ud]' '  ^- @ud' '  ?- x' '    [0 *] 1' '    [* *] 2'])
  =/  cell-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at cell ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.cell-result)  ~[leaf+"exhaustive cell literals rejected: {(trip message.p.cell-result)}"]
  =/  bad-aura=@t
    (of-wain:format ~['++ demo |= x=@ud' '  ^- @ud' '  ?- x' '    "hi" 1' '    * 2'])
  =/  invalid=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at bad-aura ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.invalid)  ~[leaf+"string pattern was accepted against @ud"]
  =/  bad-expected=@t
    (of-wain:format ~['++ demo: pattern literal does not fit the subject type' '/ui/probe.jibb:4:5: pattern' '    "hi" 1' '    ^' '/ui/probe.jibb:3:6: subject has type @ud' '  ?- x' '     ^'])
  ?.  =(bad-expected message.p.invalid)  ~[leaf+"literal aura mismatch lost its sites" leaf+(trip message.p.invalid)]
  =/  ship=@t
    (of-wain:format ~['++ demo |= x=@p' '  ^- @ud' '  ?- x' '    ~zod 1' '    * 2'])
  =/  ship-result=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at ship ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.ship-result)  ~[leaf+"matching ship pattern rejected: {(trip message.p.ship-result)}"]
  ~
++  test-list-and-unit
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['++ first |= xs=(list @ud)' '  ^- @ud' '  ?- xs' '    ~ 0' '    [i t] i' '++ unwrap |= x=(unit @ud)' '  ^- @ud' '  ?- x' '    ~ 0' '    [~ value] value'])
  =/  at=path  /ui/probe/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"list or unit coverage rejected: {(trip message.p.checked)}"]
  ~
++  test-faced-pattern-bind
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ msg' '  [%typed text=@t]' '  %submit' '++ chars |= x=msg' '  ^- (list @tD)' '  ?- x' '    [%typed t] (trip t)' '    %submit ~'])
  =/  at=path  /ui/probe/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"pattern binder kept the field face: {(trip message.p.checked)}"]
  ~
--
