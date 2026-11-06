::  A local may generalize its own variables, but never an outer capture.
/+  jibb
|%
++  test-levels-local
  ^-  tang
  =/  at=path  /ui/levels/jibb
  =/  valid=@t
    (of-wain:format ~['++ outer |= x' '  ++ id |= y y' '  ~& (id "text")' '    (id ~zod)'])
  =/  good  (infer-jibb-file-detailed:jibb at valid ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.good)  ~[leaf+(trip message.p.good)]
  =/  invalid=@t
    (of-wain:format ~['++ outer |= x' '  ++ capture |= y x' '  ~& ^- @ud (capture 0)' '    ^- @t (capture 0)'])
  =/  bad  (infer-jibb-file-detailed:jibb at invalid ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.bad)  ~[leaf+"a local generalized its captured outer variable"]
  =/  expected=@t
    (of-wain:format ~['++ outer: cast mold and expression type do not unify' '/ui/levels.jibb:4:8: cast mold has type @t' '    ^- @t (capture 0)' '       ^' '/ui/levels.jibb:4:11: expression has type @ud' '    ^- @t (capture 0)' '          ^'])
  ?.  =(expected message.p.bad)  ~[leaf+(trip message.p.bad)]
  ~
--
