::  Check the explicit mark boundary under eval and on the fake ship.
/+  jibb
/*  declared   %txt  /tests/type-mark/declared/txt
/*  missing    %txt  /tests/type-mark/missing/txt
/*  sur        %txt  /tests/type-mark/sur/txt
/*  collision  %txt  /tests/type-mark/collision/txt
/*  expected   %txt  /tests/type-mark/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-mark-bridge
  ^-  tang
  ?~  declared   ~[leaf+"mark bridge declared fixture is missing"]
  ?~  missing    ~[leaf+"mark bridge missing fixture is missing"]
  ?~  sur        ~[leaf+"mark bridge /sur fixture is missing"]
  ?~  collision  ~[leaf+"mark bridge collision fixture is missing"]
  ?~  expected   ~[leaf+"mark bridge expected output is missing"]
  =/  got  (bridge-output (text declared) (text missing) (text sur) (text collision))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"mark bridge output differs from tests/type-mark/expected.txt"]
  ~
++  bridge-output
  |=  [declared=@t missing=@t sur=@t collision=@t]
  ^-  @t
  (of-wain:format ~[(golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%& [%atom %t ~]]]]) (golden-types-with-marks:jibb /test/jibb missing ~ ~[[%label [%& [%atom %t ~]]]]) (golden-types-with-marks:jibb /test/jibb sur ~ ~[[%label [%& [%atom %t ~]]]]) (golden-types-with-marks:jibb /test/jibb collision ~ ~[[%label [%& [%atom %t ~]]]]) (golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%| 'failed']]]) (golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%& [%atom %t ~]]] [%label [%& [%atom %ud ~]]]]) (golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%& [%face %x [%fork ~]]]]]) (golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%& [%face 'Bad' [%atom %t ~]]]]]) (golden-types-with-marks:jibb /test/jibb declared ~ ~[[%label [%& [%face %$ [%atom %t ~]]]]])])
--
