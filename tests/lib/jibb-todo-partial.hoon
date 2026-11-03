::  The exact todo island through real readers: partial reports only.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /my-app/sur/todo/hoon
/*  action  %txt  /my-app/mar/todo-action/hoon
/*  todos  %txt  /my-app/mar/todos/hoon
/*  update  %txt  /my-app/mar/todo-update/hoon
/*  item  %txt  /my-app/mar/todo-item/hoon
/*  api  %txt  /my-app/ui/api/todo/jibb
/*  source  %txt  /my-app/ui/todo-list/jibb
/*  expected  %txt  /tests/type-todo-partial/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::  A mark's text without its /- lines, which Ford resolves and ride
::  can't parse.
++  mark-text
  |=  lines=wain
  ^-  @t
  (text (skip lines |=(line=@t =('/-' (end [3 2] line)))))
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
++  report
  ^-  @t
  (todo-island-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text source))
++  test-todo-partial
  ^-  tang
  ?~  source  ~[leaf+"todo source fixture is missing"]
  ?~  expected  ~[leaf+"todo partial report is missing"]
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"unchanged todo partial report differs from its golden"]
  ~
--
