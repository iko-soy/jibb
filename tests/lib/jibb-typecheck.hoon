::  Check the partial inference unifier on the ship against its golden output.
/+  jibb
/*  expected  %txt  /tests/checker/unification/txt
|%
++  report
  ^-  @t
  =/  failures=(list tape)  itype-unify-test:jibb
  ?~  failures  'unification passed'
  (of-wain:format (turn failures crip))
++  test-unification
  ^-  tang
  ?~  expected  ~[leaf+"unification golden is missing"]
  =/  got=@t  report
  ?:  =((to-wain:format (cat 3 got '\0a')) expected)  ~
  ~[leaf+"unification output differs from tests/checker/unification.txt"]
--
