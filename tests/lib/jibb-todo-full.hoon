::  Full unchanged todo island through real readers, without UI execution.
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
/*  wrong-model  %txt  /tests/type-todo-full/wrong-model/txt
/*  wrong-message  %txt  /tests/type-todo-full/wrong-message/txt
/*  wrong-result  %txt  /tests/type-todo-full/wrong-result/txt
/*  ambiguous-mapper  %txt  /tests/type-todo-full/ambiguous-mapper/txt
/*  open-key  %txt  /tests/type-todo-full/open-key/txt
/*  alias  %txt  /tests/type-todo-full/alias/txt
/*  wrong-watch  %txt  /tests/type-todo-full/wrong-watch/txt
/*  non-gate-view  %txt  /tests/type-todo-full/non-gate-view/txt
/*  expected  %txt  /tests/type-todo-full/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  todo-full-detailed
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  todo-full-reader-inputs
  |=  [sur=@t action=@t todos=@t update=@t item=@t]
  ^-  [marks=imark-externals:jibb externals=iexternals:jibb]
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item))
  =/  marks=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  [marks ~[[%todo %item item-input]]]
::
++  todo-full-report
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t src=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs sur action todos update item)
  =/  marks=imark-externals:jibb  marks.inputs
  =/  externals=iexternals:jibb  externals.inputs
  =/  api-at=path  /ui/api/todo/jibb
  =/  at=path  /ui/todo-list/jibb
  =/  modules=jbundle:jibb  ~[[api-at api]]
  =/  detailed=jfile-detailed-result:jibb
    (todo-full-detailed at src externals marks modules u.prepared)
  ?:  ?=(%| -.detailed)  (cat 3 'full todo rejected: ' message.p.detailed)
  =/  checked=ifile:jibb  iface.p.detailed
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  main  'full todo main missing'
  (cat 3 'full todo accepted\0a' (crip (show-itype:jibb typ.u.main ~)))
::
++  todo-full-legacy-report
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t src=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs sur action todos update item)
  =/  marks=imark-externals:jibb  marks.inputs
  =/  externals=iexternals:jibb  externals.inputs
  =/  api-at=path  /ui/api/todo/jibb
  =/  at=path  /ui/todo-list/jibb
  =/  modules=jbundle:jibb  ~[[api-at api]]
  =/  legacy=jfile-result:jibb
    (infer-jibb-file:jibb at src externals marks modules ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.legacy)  (cat 3 'legacy full todo rejected: ' p.legacy)
  =/  checked=ifile:jibb  iface.p.legacy
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  main  'legacy full todo main missing'
  (cat 3 'full todo accepted\0a' (crip (show-itype:jibb typ.u.main ~)))
::
++  todo-full-import-report
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t src=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs sur action todos update item)
  =/  at=path  /ui/todo-list/jibb
  =/  root=jfile-detailed-result:jibb
    (todo-full-detailed at src externals.inputs marks.inputs ~[[/ui/api/todo/jibb api]] u.prepared)
  ?:  ?=(%| -.root)  (cat 3 'full todo root rejected: ' message.p.root)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.root)
  ?~  main  'full todo root main missing'
  =/  consumer-at=path  /tests/todo-full/consumer/jibb
  =/  consumer=@t  '/= island-prog /ui/todo-list\0a++ imported main.island-prog\0a'
  =/  imported=jfile-detailed-result:jibb
    (todo-full-detailed consumer-at consumer externals.inputs marks.inputs ~[[at src] [/ui/api/todo/jibb api]] u.prepared)
  ?:  ?=(%| -.imported)  (cat 3 'downstream full todo import rejected: ' message.p.imported)
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  'downstream imported main missing'
  =/  expected-import=itype:jibb
    (itype-in-import:jibb typ.u.main iface.p.root %island-prog `iface.u.prepared)
  ?.  &(?=(~ vars.u.use) =(typ.u.use expected-import))  'downstream main type differs'
  'downstream import accepted'
::
++  todo-full-negative-report
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t label=@t src=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs sur action todos update item)
  =/  at=path  /ui/todo-list/jibb
  =/  structured=jfile-detailed-result:jibb
    (todo-full-detailed at src externals.inputs marks.inputs ~[[/ui/api/todo/jibb api]] u.prepared)
  ?:  ?=(%& -.structured)  (cat 3 label ': BAD accepted')
  (cat 3 label ': rejected')
::
++  test-todo-full
  ^-  tang
  =/  report=@t
    (todo-full-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source))
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"full todo report differs"]
  =/  legacy=@t
    (todo-full-legacy-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source))
  ?.  =((to-wain:format (cat 3 legacy '\0a')) expected)
    ~[leaf+"legacy full todo report differs"]
  =/  imported=@t
    (todo-full-import-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source))
  ?.  =(imported 'downstream import accepted')
    ~[leaf+"downstream full todo import differs"]
  =/  negatives=(list [label=@t src=@t])
    :~  ['wrong model' (text wrong-model)]
        ['wrong message' (text wrong-message)]
        ['wrong result' (text wrong-result)]
        ['ambiguous mapper' (text ambiguous-mapper)]
        ['open key' (text open-key)]
        ['mapper alias' (text alias)]
        ['wrong watch' (text wrong-watch)]
        ['non-gate view' (text non-gate-view)]
    ==
  =/  bad=(list @t)
    %+  murn  negatives
    |=  c=[label=@t src=@t]
    =/  expected=@t  (cat 3 label.c ': rejected')
    =/  actual=@t
      (todo-full-negative-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) label.c src.c)
    ?.  =(expected actual)  `actual
    ~
  ?^  bad  (turn bad |=(reason=@t leaf+(trip reason)))
  ~
--
