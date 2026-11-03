::  Full-module diagnostics retain their inference sites.
/+  jibb
|%
++  test-full-diagnostics
  ^-  tang
  =/  file=path  /ui/probe/jibb
  =/  source=@t  (of-wain:format ~['++ inc |= n=@ud n' '++ top (inc %.y)'])
  =/  result  (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"wrong argument was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ top: call\'s sample and argument types do not unify' '/ui/probe.jibb:2:9: called gate has type $-(@ud @ud)' '++ top (inc %.y)' '        ^' '/ui/probe.jibb:2:13: argument has type ?' '++ top (inc %.y)' '            ^'])
  ?.  =(expected message.p.result)  ~[leaf+"full checker lost the argument diagnostic"]
  =/  forward=@t  (of-wain:format ~['++ top (inc 5)' '++ inc |= n=@ud n'])
  =/  ok  (infer-jibb-file-detailed:jibb file forward ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.ok)  ~[leaf+"forward definition did not resolve"]
  ::  An earlier open tag and an earlier shadow must not be hidden by a
  ::  definite call mismatch in another unresolved definition.
  =/  pending-source=@t  (of-wain:format ~['++ x %add' '++ inc |= n=@ud n' '++ bad (inc %.y)'])
  =/  pending-result  (infer-jibb-file-detailed:jibb file pending-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.pending-result)  ~[leaf+"open tag was accepted"]
  =/  pending-expected=@t
    (of-wain:format ~['/ui/probe.jibb:1:6: nothing fixes the union of %add' '++ x %add' '     ^'])
  ?.  =(pending-expected message.p.pending-result)  ~[leaf+"earlier pending tag was masked"]
  ::  A forward dependency precedes its user even when its source line is
  ::  after a separate mismatch.
  =/  dependency-source=@t  (of-wain:format ~['++ wrapper x' '++ inc |= n=@ud n' '++ bad (inc %.y)' '++ x %add'])
  =/  dependency-result  (infer-jibb-file-detailed:jibb file dependency-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.dependency-result)  ~[leaf+"forward open tag was accepted"]
  =/  dependency-expected=@t
    (of-wain:format ~['/ui/probe.jibb:4:6: nothing fixes the union of %add' '++ x %add' '     ^'])
  ?.  =(dependency-expected message.p.dependency-result)  ~[leaf+"dependency diagnostic order differs"]
  =/  shadow-source=@t  (of-wain:format ~['++ inc |= n=@ud n' '++ before |= inc 0' '++ bad (inc %.y)'])
  =/  shadow-result  (infer-jibb-file-detailed:jibb file shadow-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.shadow-result)  ~[leaf+"shadowing sample was accepted"]
  =/  shadow-expected=@t
    (of-wain:format ~['/ui/probe.jibb:2:14: sample `inc` shadows a name already in scope' '++ before |= inc 0' '             ^'])
  ?.  =(shadow-expected message.p.shadow-result)  ~[leaf+"earlier sample shadow was masked"]
  =/  reversed-source=@t  (of-wain:format ~['++ inc |= n=@ud n' '++ bad (inc %.y)' '++ x %add'])
  =/  reversed-result  (infer-jibb-file-detailed:jibb file reversed-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.reversed-result)  ~[leaf+"call mismatch was accepted"]
  =/  reversed-expected=@t
    (of-wain:format ~['++ bad: call\'s sample and argument types do not unify' '/ui/probe.jibb:2:9: called gate has type $-(@ud @ud)' '++ bad (inc %.y)' '        ^' '/ui/probe.jibb:2:13: argument has type ?' '++ bad (inc %.y)' '            ^'])
  ?.  =(reversed-expected message.p.reversed-result)  ~[leaf+"earlier mismatch was masked"]
  ~
--
