::  Generic callbacks use ordinary type constraints, including late faces.
/+  jibb
/*  expected  %txt  /tests/type-direct-gate/guards-expected/txt
|%
++  report
  ^-  @t
  =/  higher=@t  '++ apply |= [f=$-([A B] B) n=@t] f\0a++ target |= [a=@t b=@p] b\0a'
  =/  faced=@t  '++ apply |= [first=[foo=A] second=A f=$-([C D] D)] f\0a++ target |= [a=@t b=@p] b\0a'
  =/  cases=(list [label=@t source=@t])
    :~  ['direct' (cat 3 higher '++ result (apply target "x")\0a')]
        ['head alias' (cat 3 higher '++ helper apply\0a++ result (helper target "x")\0a')]
        ['callback alias' (cat 3 higher '++ callback target\0a++ result (apply callback "x")\0a')]
        ['later binding' (cat 3 faced '++ result (apply [foo="x"] "y" target)\0a')]
        ['inferred face' (cat 3 faced '++ result |= x (apply x "y" target)\0a')]
        ['conflicting face' (cat 3 faced '++ result (apply [other="x"] "y" target)\0a')]
        ['conflicting aura' (cat 3 faced '++ result (apply [foo="x"] ~zod target)\0a')]
        ['distinct capitals' '++ first |= f=$-([A A] @t) f\0a++ bad |= f=$-([A B] @t) (first f)\0a']
    ==
  %-  of-wain:format
  %+  turn  cases
  |=  [label=@t source=@t]
  (cat 3 label (cat 3 '\0a' (golden-types-with-marks:jibb /ui/callback/jibb source ~ ~)))
++  test-direct-gate-guards
  ^-  tang
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+(trip actual)]
  ~
--
