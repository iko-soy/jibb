/+  jibb
/*  expected  %txt  /tests/type-sample-shadow/origins-expected/txt
|%
++  report
  ^-  @t
  =/  file=path  /tests/sample-shadow/jibb
  =/  imported=@t  '/= card /lib/card\0a++ bad |= [x=@ud card=@t] x\0a'
  =/  lib=@t  '++ public 1\0a'
  =/  prelude=@t  '++ taken |= a a\0a'
  =/  hidden=@t  '++ bad |= [x=@ud taken=@t] x\0a'
  =/  local=@t  '++ bad |= x=@t\0a  ++ thing x\0a  |=(thing=@t thing)\0a'
  =/  branch=@t  '++ bad |= a=*\0a  ?- a\0a  z |=(z=@t z)\0a'
  =/  earlier=@t  '++ first %open\0a++ original 1\0a++ bad |= [x=@ud original=@t] x\0a'
  =/  a=@t  (golden-types-with-modules:jibb file imported ~ ~ ~[[/lib/card/jibb lib]])
  =/  b=@t  (golden-types-with-prelude:jibb file hidden ~ ~ ~ prelude)
  =/  c=@t  (golden-types-with-modules:jibb file local ~ ~ ~)
  =/  d=@t  (golden-types-with-modules:jibb file branch ~ ~ ~)
  =/  e=@t  (golden-types-with-modules:jibb file earlier ~ ~ ~)
  (of-wain:format ~['import:' a 'prelude:' b 'local:' c 'branch:' d 'earlier:' e])
++  test-sample-shadow-origins
  ^-  tang
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"sample shadow diagnostics differ"]
  ~
--
