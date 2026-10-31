::  Hoon translations of curried Jibb pair constructors vs Hoon 2n arms.
::  This does not execute Jibb, lower code or verify jet recognition.
^-  @t
=/  make-lead  |=  a=*  |=  b=*  [a b]
=/  make-late  |=  b=*  |=  a=*  [a b]
=/  items=(list *)
  :~  0
      1
      'hello'
      [1 2]
      |=(x=@ud x)
  ==
=/  xs=(list *)  items
|-
?~  xs  'Hoon lead/late reference: 50 comparisons passed'
=/  ys=(list *)  items
=/  good=?
  |-
  ?~  ys  &
  ?.  =(((make-lead i.xs) i.ys) ((lead i.xs) i.ys))  |
  ?.  =(((make-late i.xs) i.ys) ((late i.xs) i.ys))  |
  $(ys t.ys)
?.  good  'BAD pair mismatch'
$(xs t.xs)
