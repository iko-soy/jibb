::  The importer fixtures and their golden output, read as text so -test
::  does not try to compile the fixture /sur files as test programs.
/+  jibb-import
/*  small     %txt  /tests/importer/small/txt
/*  epic      %txt  /tests/importer/tlon-epic/txt
/*  expected  %txt  /tests/importer/tree/txt
|%
++  lines-to-cord
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  test-importer-golden
  ^-  tang
  ?~  small  ~[leaf+"small importer fixture is missing"]
  ?~  epic  ~[leaf+"Tlon importer fixture is missing"]
  ?~  expected  ~[leaf+"importer golden output is missing"]
  =/  actual  (fixture-output:jibb-import (lines-to-cord small) (lines-to-cord epic))
  ?.  =(actual expected)
    ~[leaf+"importer projection differs from tests/importer/tree.txt"]
  ~
--
