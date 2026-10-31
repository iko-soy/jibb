::  Compare a Hoon translation of Jibb zing's recursion with Hoon's zing.
::  This does not run Jibb, test lowering, or prove jet recognition.
^-  @t
=/  flatten  |=  xss=(list (list @ud))
  ^-  (list @ud)
  ?~  xss  ~
  (weld i.xss $(xss t.xss))
=/  cases=(list (list (list @ud)))
  :~  ~
      ~[~]
      ~[~[1 2] ~ ~[3]]
      ~[~[0] ~[3 2 1] ~]
  ==
|-
?~  cases  'Hoon flattening reference: 4 cases passed'
?.  =((flatten i.cases) (zing i.cases))  'BAD Hoon flattening mismatch'
$(cases t.cases)
