/+  jibb
|%
++  contains
  |=  [text=tape pattern=tape]
  ^-  ?
  ?~  pattern  &
  ?~  text  |
  ?:  =((scag (lent pattern) `tape`text) pattern)  &
  $(text t.text)
++  check
  |=  [src=@t modules=jbundle:jibb file=path expected=tape]
  ^-  tang
  =/  got=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ modules ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.got)  ~[leaf+"invalid union pattern was accepted"]
  =/  text=tape  (trip message.p.got)
  ?.  (contains text "choice has no case `%c`")  ~[leaf+text]
  ?.  (contains text expected)  ~[leaf+text]
  ?.  (contains text ":8:5: tag literal has type %c")  ~[leaf+text]
  ~
++  test-local-union-pattern
  ^-  tang
  =/  src=@t  (of-wain:format ~['+$ choice' '  %a' '  %b' '++ f |= v=choice' '  ?- v' '    %a "a"' '    %b "b"' '    %c "c"'])
  (check src ~ /ui/probe/jibb "/ui/probe.jibb:1:4: matched union has type choice")
++  test-imported-union-pattern
  ^-  tang
  =/  src=@t  (of-wain:format ~['/= types /ui/types' '++ f |= v=choice.types' '  ?- v' '    %a "a"' '    %b "b"' '    %c "c"'])
  =/  module=@t  (of-wain:format ~['+$ choice' '  %a' '  %b'])
  =/  got=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb /ui/probe/jibb src ~ ~ ~[[/ui/types/jibb module]] ~[/ui/probe/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.got)  ~[leaf+"invalid imported union pattern was accepted"]
  =/  text=tape  (trip message.p.got)
  ?.  (contains text "choice.types has no case `%c`")  ~[leaf+text]
  ?.  (contains text "/ui/types.jibb:1:4: matched union has type choice.types")  ~[leaf+text]
  ?.  (contains text "/ui/probe.jibb:6:5: tag literal has type %c")  ~[leaf+text]
  ~
--
