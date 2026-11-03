::  The full checker reports the names and sites of module scope conflicts.
/+  jibb
|%
++  test-full-scope
  ^-  tang
  =/  file=path  /ui/probe/jibb
  =/  dup=@t  (of-wain:format ~['++ foo 1' '++ foo 2'])
  =/  dup-result  (infer-jibb-file-detailed:jibb file dup ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.dup-result)  ~[leaf+"duplicate definition was accepted"]
  =/  dup-expected=@t
    (of-wain:format ~['definition `foo` shadows an earlier definition' '/ui/probe.jibb:1:1: earlier definition' '++ foo 1' '^' '/ui/probe.jibb:2:1: conflicting definition' '++ foo 2' '^'])
  ?.  =(dup-expected message.p.dup-result)  ~[leaf+"duplicate definition diagnostic differs"]
  =/  reserved=@t  '++ proj 1'
  =/  reserved-result  (infer-jibb-file-detailed:jibb file reserved ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.reserved-result)  ~[leaf+"reserved definition was accepted"]
  =/  reserved-expected=@t
    (of-wain:format ~['`proj` is reserved and cannot be bound' '/ui/probe.jibb:1:1: reserved name' '++ proj 1' '^'])
  ?.  =(reserved-expected message.p.reserved-result)  ~[leaf+"reserved definition diagnostic differs"]
  =/  collision=@t  (of-wain:format ~['/= foo /ui/other' '++ foo 1'])
  =/  collision-result  (infer-jibb-file-detailed:jibb file collision ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.collision-result)  ~[leaf+"definition shadowing import was accepted"]
  =/  collision-expected=@t
    (of-wain:format ~['definition `foo` shadows an import' '/ui/probe.jibb:1:1: import' '/= foo /ui/other' '^' '/ui/probe.jibb:2:1: conflicting definition' '++ foo 1' '^'])
  ?.  =(collision-expected message.p.collision-result)  ~[leaf+"import conflict diagnostic differs"]
  =/  prelude-source=@t  '++ add |= n n'
  =/  iface=ifile:jibb  [~ ~ /lib/jibb/prelude/jibb ~ ~ ~ `prelude-source ~]
  =/  shadows=@t  '++ add 1'
  =/  shadow-result  (infer-jibb-file-detailed:jibb file shadows ~ ~ ~ ~[file] ~[%add] ~ ~ `iface)
  ?:  ?=(%& -.shadow-result)  ~[leaf+"prelude shadow was accepted"]
  =/  shadow-expected=@t
    (of-wain:format ~['definition `add` shadows a prelude name' '/ui/probe.jibb:1:1: conflicting definition' '++ add 1' '^' '/lib/jibb/prelude.jibb:1:1: prelude declaration' '++ add |= n n' '^'])
  ?.  =(shadow-expected message.p.shadow-result)  ~[leaf+"prelude shadow diagnostic differs"]
  =/  nested=@t  '++ test |=(proj proj)'
  =/  nested-result  (infer-jibb-file-detailed:jibb file nested ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.nested-result)  ~[leaf+"reserved sample was accepted"]
  ~
--
