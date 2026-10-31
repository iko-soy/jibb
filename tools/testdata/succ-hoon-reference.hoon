::  Compare a Hoon translation of the Jibb successor with Hoon's 2n arm.
::  This does not execute Jibb, lower code or verify jet recognition.
^-  @t
=/  next  |=  x=@  (add x 1)
=/  values=(list @)  ~[0 1 2 31 255 256 65.535 65.536 4.294.967.295 18.446.744.073.709.551.615]
|-  ^-  @t
?~  values  'Hoon successor reference: 10 comparisons passed'
?.  =((next i.values) (succ i.values))  'BAD successor mismatch'
$(values t.values)
