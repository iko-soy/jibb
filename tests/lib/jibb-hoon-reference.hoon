::  Hoon translations of Jibb prelude gates against the Hoon arms they
::  stand for: zing, lead and late, and succ. They don't execute Jibb,
::  test lowering or prove jet recognition.
|%
::  +zing: Jibb's recursion, translated, against Hoon's zing
++  test-zing-reference
  ^-  tang
  =/  flatten
    |=  xss=(list (list @ud))
    ^-  (list @ud)
    ?~  xss  ~
    (weld i.xss $(xss t.xss))
  =/  cases=(list (list (list @ud)))
    :~  ~
        ~[~]
        ~[~[1 2] ~ ~[3]]
        ~[~[0] ~[3 2 1] ~]
    ==
  %+  murn  cases
  |=  xss=(list (list @ud))
  ?:  =((flatten xss) (zing xss))  ~
  `leaf+"flattening differs from zing on {<xss>}"
::  +lead and +late: curried pair constructors, translated, against Hoon's
::  on every pair of five nouns, a gate among them
++  test-lead-late-reference
  ^-  tang
  =/  make-lead  |=(a=* |=(b=* [a b]))
  =/  make-late  |=(b=* |=(a=* [a b]))
  ::  Each noun has a name for the failure message: printing a gate
  ::  would print its whole subject.
  =/  items=(list [name=tape noun=*])
    :~  ["0" 0]
        ["1" 1]
        ["'hello'" 'hello']
        ["[1 2]" [1 2]]
        ["a gate" |=(x=@ud x)]
    ==
  %-  zing
  %+  turn  items
  |=  [xn=tape x=*]
  %+  murn  items
  |=  [yn=tape y=*]
  ?.  =(((make-lead x) y) ((lead x) y))
    `leaf+"lead differs on {xn} and {yn}"
  ?.  =(((make-late x) y) ((late x) y))
    `leaf+"late differs on {xn} and {yn}"
  ~
::  +succ: the successor, translated, against Hoon's succ
++  test-succ-reference
  ^-  tang
  =/  next  |=(x=@ (add x 1))
  =/  values=(list @)
    :~  0  1  2  31  255  256  65.535  65.536  4.294.967.295
        18.446.744.073.709.551.615
    ==
  %+  murn  values
  |=  x=@
  ?:  =((next x) (succ x))  ~
  `leaf+"successor differs from succ on {<x>}"
--
