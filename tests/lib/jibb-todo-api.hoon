::  The exact todo API reaches partial client inference through real /sur and mark readers.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  api  %txt  /tests/type-api-paths/api/txt
/*  source  %txt  /tests/type-todo-api/source/txt
/*  negative  %txt  /tests/type-todo-api/negative/txt
/*  unsupported  %txt  /tests/type-todo-api/unsupported/txt
/*  expected  %txt  /tests/type-todo-api/expected/txt
/*  negative-expected  %txt  /tests/type-todo-api/negative-expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  todo-run
  |=  [prelude=@t internal=@t sur=@t action=@t todos=@t update=@t item=@t api=@t source=@t negative=@t unsupported=@t]
  ^-  [report=@t bad-report=@t guards=@t]
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  ['prelude unavailable' 'prelude unavailable' 'prelude unavailable']
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item))
  =/  mark-inputs=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  inputs=iexternals:jibb  ~[[%todo %item item-input]]
  =/  modules=jbundle:jibb  ~[[/ui/api/todo/jibb api]]
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /tests/type-todo-api/source/jibb source inputs mark-inputs modules prepared)
  =/  bad-report=@t  (golden-types-with-prepared-prelude:jibb /tests/type-todo-api/negative/jibb negative inputs mark-inputs modules prepared)
  =/  guards=@t
    =/  out  (infer-jibb-file:jibb /ui/api/todo/jibb api inputs mark-inputs ~ ~[/ui/api/todo/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
    ?:  ?=(%| -.out)  (cat 3 'actual API failed: ' p.out)
    =/  iface=ifile:jibb  iface.p.out
    ?.  =(source.iface `api)  'actual API source changed'
    =/  names=(list term)  (turn values.iface |=(x=[name=term scheme=ischeme:jibb] name.x))
    =/  required-values=(list term)  ~[%todo-action %todos %changes %todo-by-id]
    ?.  (levy required-values |=(x=term (lien names |=(y=term =(x y)))))  'derived value missing'
    =/  mnames=(list term)  (turn molds.iface |=(x=[name=term template=ischeme:jibb] name.x))
    =/  required-molds=(list term)  ~[%item %todo-action %todos %todo-update %todo-item]
    ?.  (levy required-molds |=(x=term (lien mnames |=(y=term =(x y)))))  'expected mold export missing'
    ?:  (lien mnames |=(x=term =(%todo x)))  '/sur import face was re-exported'
    ?~  graph.iface  'API certificate missing'
    ?.  =((lent requests.u.graph.iface) 3)  'request evidence count wrong'
    =/  missing-mark=imark-externals:jibb  (skim mark-inputs |=(x=[mark=term result=*] !=(%todo-update mark.x)))
    =/  duplicate-mark=imark-externals:jibb  [[%todo-action ma] mark-inputs]
    =/  duplicate-sur=iexternals:jibb  [[%todo %item item-input] inputs]
    =/  cases=(list [label=@t src=@t externals=iexternals:jibb marks=imark-externals:jibb])
      :~  ['missing selected sur mold' api ~ mark-inputs]
          ['duplicate selected sur mold' api duplicate-sur mark-inputs]
          ['missing mark' api inputs missing-mark]
          ['duplicate mark' api inputs duplicate-mark]
          ['unsupported request sibling' unsupported inputs mark-inputs]
          ['unrelated invalid mold' (cat 3 api '\0a+$ invalid missing\0a') inputs mark-inputs]
          ['unrelated invalid value' (cat 3 api '\0a++ invalid missing\0a') inputs mark-inputs]
          ['private import' (cat 3 '/= secret /lib/jibb/internal\0a' api) inputs mark-inputs]
      ==
    =/  failures=(list @t)
      %+  turn  cases
      |=  c=[label=@t src=@t externals=iexternals:jibb marks=imark-externals:jibb]
      =/  bad  (infer-jibb-file:jibb /ui/api/todo/jibb src.c externals.c marks.c ~ ~[/ui/api/todo/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
      ?:  ?=(%| -.bad)  ''
      (cat 3 label.c ': unexpectedly published')
    =/  bad=(list @t)  (skim failures |=(x=@t !=(x '')))
    ?~  bad  'real todo interface and atomic guards passed'
    (of-wain:format bad)
  [report bad-report guards]
++  test-todo-api
  ^-  tang
  =/  out  (todo-run prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source) (text negative) (text unsupported))
  ?.  =((to-wain:format (cat 3 report.out '\0a')) expected)
    ~[leaf+"todo API report differs from expected"]
  ?.  =((to-wain:format (cat 3 bad-report.out '\0a')) negative-expected)
    ~[leaf+"todo API negative report differs from expected"]
  ?.  =(guards.out 'real todo interface and atomic guards passed')
    ~[leaf+(trip guards.out)]
  ~
--
