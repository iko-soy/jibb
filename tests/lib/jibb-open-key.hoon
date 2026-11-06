::  Full unchanged todo island through real readers, without UI execution.
/+  jibb, jibb-import, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  sur  %txt  /my-app/sur/todo/hoon
/*  action  %txt  /my-app/mar/todo-action/hoon
/*  todos  %txt  /my-app/mar/todos/hoon
/*  update  %txt  /my-app/mar/todo-update/hoon
/*  item  %txt  /my-app/mar/todo-item/hoon
/*  api  %txt  /my-app/ui/api/todo/jibb
/*  source  %txt  /my-app/ui/todo-list/jibb
/*  wrong-model  %txt  /tests/type-todo-full/wrong-model/txt
/*  wrong-message  %txt  /tests/type-todo-full/wrong-message/txt
/*  wrong-result  %txt  /tests/type-todo-full/wrong-result/txt
/*  ambiguous-mapper  %txt  /tests/type-todo-full/ambiguous-mapper/txt
/*  open-key  %txt  /tests/type-todo-full/open-key/txt
/*  alias  %txt  /tests/type-todo-full/alias/txt
/*  wrong-watch  %txt  /tests/type-todo-full/wrong-watch/txt
/*  non-gate-view  %txt  /tests/type-todo-full/non-gate-view/txt
/*  cast-init  %txt  /tests/type-todo-full/cast-init/txt
/*  expected  %txt  /tests/type-todo-full/expected/txt
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
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
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
++  report
  ^-  @t
  (todo-full-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text open-key))
::
++  todo-full-legacy-report
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t src=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
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
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
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
  |=  [api=@t label=@t src=@t externals=iexternals:jibb marks=imark-externals:jibb prepared=iprelude:jibb]
  ^-  @t
  =/  at=path  /ui/todo-list/jibb
  =/  structured=jfile-detailed-result:jibb
    (todo-full-detailed at src externals marks ~[[/ui/api/todo/jibb api]] prepared)
  ?:  ?=(%& -.structured)  (cat 3 label ': BAD accepted')
  message.p.structured
::
++  starts-with-tape
  |=  [needle=tape hay=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?.  =(i.needle i.hay)  |
  $(needle t.needle, hay t.hay)
++  contains-tape
  |=  [needle=tape hay=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  (starts-with-tape needle hay)  &
  $(hay t.hay)
++  caret-line
  |=  line=tape
  ^-  ?
  ?~  line  |
  ?:  =(i.line ' ')  $(line t.line)
  ?.  =(i.line '^')  |
  (levy t.line |=(ch=@tD |(=(ch '~') =(ch ' '))))
::
++  test-open-key
  ^-  tang
  =/  got=@t  (todo-full-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text open-key))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"empty-key todo did not retain the expected program interface" leaf+(trip got)]
  ~
--
