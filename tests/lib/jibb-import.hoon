::  The importer fixtures and their golden output, read as text so -test
::  does not try to compile the fixture /sur files as test programs.
/+  jibb-import
/*  small     %txt  /tests/importer/small/txt
/*  epic      %txt  /tests/importer/tlon-epic/txt
/*  presence  %txt  /tests/importer/tlon-presence/txt
/*  docs      %txt  /tests/importer/tlon-docs/txt
/*  shadow    %txt  /tests/importer/shadow/txt
/*  shadow-static  %txt  /tests/importer/shadow-static/txt
/*  ford  %txt  /tests/importer/ford/txt
/*  mark  %txt  /tests/importer/mark/txt
/*  mark-rec  %txt  /tests/importer/mark-recursive/txt
/*  mark-gate  %txt  /tests/importer/mark-gate/txt
/*  mark-basic  %txt  /tests/importer/mark-list/txt
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
  ?~  presence  ~[leaf+"Tlon presence fixture is missing"]
  ?~  docs  ~[leaf+"Tlon docs fixture is missing"]
  ?~  shadow  ~[leaf+"shadow fixture is missing"]
  ?~  shadow-static  ~[leaf+"static shadow fixture is missing"]
  ?~  ford  ~[leaf+"Ford importer fixture is missing"]
  ?~  mark  ~[leaf+"mark fixture is missing"]
  ?~  mark-rec  ~[leaf+"recursive mark fixture is missing"]
  ?~  mark-gate  ~[leaf+"gate mark fixture is missing"]
  ?~  mark-basic  ~[leaf+"list mark fixture is missing"]
  ?~  expected  ~[leaf+"importer golden output is missing"]
  =/  actual  (fixture-output:jibb-import (lines-to-cord small) (lines-to-cord epic) (lines-to-cord presence) (lines-to-cord docs) (lines-to-cord shadow) (lines-to-cord shadow-static) (lines-to-cord ford) (lines-to-cord mark) (lines-to-cord mark-rec) (lines-to-cord mark-gate) (lines-to-cord mark-basic))
  ?.  =(actual expected)
    ~[leaf+"importer projection differs from tests/importer/tree.txt"]
  ~
--
