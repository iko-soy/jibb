::  The exact todo island through real readers: partial reports only.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  api  %txt  /tests/type-api-paths/api/txt
/*  source  %txt  /tests/type-gate-free/todo/txt
/*  expected  %txt  /tests/type-todo-partial/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  todo-island-report
  |=  [public=@t private=@t sur-text=@t action-text=@t todos-text=@t update-text=@t item-text=@t api-text=@t source-text=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  todo=type  -:(ride -:!>(..zuse) sur-text)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action-text))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos-text))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update-text))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item-text))
  =/  marks=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  inputs=iexternals:jibb  ~[[%todo %item item-input]]
  =/  modules=jbundle:jibb  ~[[/ui/api/todo/jibb api-text]]
  =/  at=path  /ui/todo-list/jibb
  =/  normal=@t  (golden-types-with-prepared-prelude:jibb at source-text inputs marks modules prepared)
  =/  missing-mark=imark-externals:jibb  (skim marks |=(x=[mark=term result=*] !=(%todo-update mark.x)))
  =/  duplicate-mark=imark-externals:jibb  [[%todo-action ma] marks]
  =/  negative=(list [label=@t externals=iexternals:jibb marks=imark-externals:jibb])
    :~  ['missing-mark' inputs missing-mark]
        ['duplicate-mark' inputs duplicate-mark]
        ['missing-selected-sur' ~ marks]
    ==
  =/  failures=(list @t)
    %+  turn  negative
    |=  c=[label=@t externals=iexternals:jibb marks=imark-externals:jibb]
    =/  bad  (infer-jibb-file:jibb /ui/api/todo/jibb api-text externals.c marks.c ~ ~[/ui/api/todo/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
    ?:  ?=(%| -.bad)  (cat 3 label.c ': rejected')
    (cat 3 label.c ': BAD accepted')
  =/  missing-module=@t  (golden-types-with-prepared-prelude:jibb at source-text inputs marks ~ prepared)
  (of-wain:format (weld ~['unchanged todo: partial inference only' normal 'negative API imports'] (weld failures ~['missing module: partial report' missing-module])))
++  test-todo-partial
  ^-  tang
  ?~  source  ~[leaf+"todo source fixture is missing"]
  ?~  expected  ~[leaf+"todo partial report is missing"]
  =/  report=@t  (todo-island-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source))
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"unchanged todo partial report differs from its golden"]
  ~
--
