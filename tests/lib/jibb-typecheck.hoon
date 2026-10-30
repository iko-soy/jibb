::  Check the partial inference unifier on the ship against its golden output.
/+  jibb
/*  expected  %txt  /tests/checker/unification/txt
|%
++  test-unification
  ^-  tang
  ?~  expected  ~[leaf+"unification golden is missing"]
  =/  failures=(list tape)  itype-unify-test:jibb
  =/  actual=wain
    ?~  failures  ~['unification passed']
    (turn failures crip)
  ?:  =(actual expected)  ~
  ~[leaf+"unification output differs from tests/checker/unification.txt"]
--
