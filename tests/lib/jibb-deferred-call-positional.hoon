/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  expected  %txt  /tests/type-deferred-cast/positional-expected/txt
|%
++  report
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  =/  file=path  /tests/call-positional/jibb
  =/  a=@t  '+$ msg\0a  %hit\0a  %miss\0a++ expects |= [node=(element msg) payload=[label=@t count=@ud]] payload\0a++ pending (button "x" %hit)\0a++ result (expects pending [label="hi" count=5])\0a'
  =/  b=@t  '+$ msg\0a  %hit\0a  %miss\0a++ result (expects pending [label="hi" count=5])\0a++ pending (button "x" %hit)\0a++ expects |= [node=(element msg) payload=[label=@t count=@ud]] payload\0a'
  =/  c=@t  '+$ msg\0a  %hit\0a  %miss\0a++ expects |= [node=(element msg) payload=[label=@t count=@ud]] payload\0a++ pending (button "x" %hit)\0a++ bad (expects pending [label=~zod count=5])\0a'
  =/  d=@t  '+$ msg\0a  %hit\0a  %miss\0a++ expects |= [node=(element msg) payload=[label=@t count=@ud]] payload\0a++ pending (button "x" %typo)\0a++ result (expects pending [label="hi" count=5])\0a'
  (of-wain:format ~['forward:' (golden-types-with-prepared-prelude:jibb file a ~ ~ ~ prep) 'reverse:' (golden-types-with-prepared-prelude:jibb file b ~ ~ ~ prep) 'wrong payload:' (golden-types-with-prepared-prelude:jibb file c ~ ~ ~ prep) 'wrong tag:' (golden-types-with-prepared-prelude:jibb file d ~ ~ ~ prep)])
++  test-deferred-call-positional
  ^-  tang
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"deferred positional call types or diagnostic sites differ"]
  ~
--
