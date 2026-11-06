::  Local mold scope errors use the full checker and retain both sites.
/+  jibb
/*  outer  %txt  /tests/type-local-mold-scope/outer/txt
/*  duplicate  %txt  /tests/type-local-mold-scope/duplicate/txt
/*  reserved  %txt  /tests/type-local-mold-scope/reserved/txt
/*  sample  %txt  /tests/type-local-mold-scope/sample/txt
/*  pattern  %txt  /tests/type-local-mold-scope/pattern/txt
/*  field  %txt  /tests/type-local-mold-scope/field/txt
/*  expected  %txt  /tests/type-local-mold-scope/expected/txt
|%
++  report
  ^-  @t
  =/  sources=(list wain)  ~[outer duplicate reserved sample pattern field]
  =/  reports=(list @t)
    %+  turn  sources
    |=  source=wain
    (golden-types:jibb /ui/local-scope/jibb (of-wain:format source))
  (of-wain:format reports)
++  test-local-mold-scope
  ^-  tang
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"local mold diagnostics differ from full-check expectations"]
  ~
--
