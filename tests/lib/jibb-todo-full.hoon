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
/*  drop-each-unfixed  %txt  /tests/type-todo-full/drop-each-unfixed/txt
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
  (todo-full-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text source))
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
++  test-todo-full
  ^-  tang
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"full todo report differs"]
  =/  legacy=@t
    (todo-full-legacy-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text source))
  ?.  =((to-wain:format (cat 3 legacy '\0a')) expected)
    ~[leaf+"legacy full todo report differs"]
  =/  cast-report=@t
    (todo-full-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text cast-init))
  ?.  =((to-wain:format (cat 3 cast-report '\0a')) expected)
    ~[leaf+"ordinary annotated initializer was rejected"]
  =/  cast-legacy=@t
    (todo-full-legacy-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text cast-init))
  ?.  =((to-wain:format (cat 3 cast-legacy '\0a')) expected)
    ~[leaf+"legacy ordinary annotated initializer was rejected"]
  ::  Each, mapper aliases and !! are ordinary expressions, not errors.
  =/  variants=(list [label=tape src=@t])
    :~  ["two each sites" (text ambiguous-mapper)]
        ["mapper alias" (text alias)]
        ["empty key" (text open-key)]
    ==
  =/  variant-failures=(list tape)
    %+  murn  variants
    |=  v=[label=tape src=@t]
    =/  actual=@t
      (todo-full-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) src.v)
    ?:  =((to-wain:format (cat 3 actual '\0a')) expected)  ~
    `(weld label.v (weld ": " (trip actual)))
  ?^  variant-failures  (turn variant-failures |=(reason=tape leaf+reason))
  =/  imported=@t
    (todo-full-import-report prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text source))
  ?.  =(imported 'downstream import accepted')
    ~[leaf+"downstream full todo import differs"]
  ~
::
++  test-todo-full-negative-diagnostics
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item))
  ::  Each case names the required reason and the two conflicting sites.
  ::  Generic unsupported-inference or an earlier unrelated ~ cannot pass.
  =/  negatives=(list [label=@t src=@t reason=tape first=tape second=tape first-line=tape second-line=tape])
    :~          ['wrong model' (text wrong-model) "local sample `subs` does not unify with model `model`" "/ui/todo-list.jibb:5:4:" "/ui/todo-list.jibb:27:12:" "+$ model [todos=(list item.todo) draft=@t error=(unit @t)]" "++ subs |= m=[count=@ud]"]
        ['wrong message' (text wrong-message) "msg has no case `%other`" "/ui/todo-list.jibb:6:4:" "/ui/todo-list.jibb:40:32:" "+$ msg" "  [id.t (toggle done.t text.t [%other])]"]
        ['wrong result' (text wrong-result) "local result `row-of` does not unify" "/ui/todo-list.jibb:33:5:" "/ui/todo-list.jibb:40:3:" "    each (turn todos.m row-of)" "  text.t"]
        ['wrong watch' (text wrong-watch) "an island may watch only a request whose origin is proved watchable" "/ui/todo-list.jibb:28:6:" "/ui/todo-list.jibb:28:14:" "  ~[[%watch (pure %submit)]]" "  ~[[%watch (pure %submit)]]"]
        ['wrong view type' (text non-gate-view) "local definition `init` does not unify with (element msg)" "/ui/todo-list.jibb:13:1:" "/ui/todo-list.jibb:30:9:" "++ init |= ts=(list item.todo)" "++ view init"]
    ==
  =/  bad=(list @t)
    %+  murn  negatives
    |=  c=[label=@t src=@t reason=tape first=tape second=tape first-line=tape second-line=tape]
    =/  actual=@t
      (todo-full-negative-report (text api) label.c src.c externals.inputs marks.inputs u.prepared)
    =/  rendered=tape  (trip actual)
    =/  carets=@ud  (lent (skim (to-wain:format actual) |=(line=@t (caret-line (trip line)))))
    ?:  &((contains-tape reason.c rendered) (contains-tape first.c rendered) (contains-tape second.c rendered) (contains-tape first-line.c rendered) (contains-tape second-line.c rendered) (gte carets 2))  ~
    `(cat 3 label.c (cat 3 ': wrong diagnostic or sites: ' actual))
  ?^  bad  (turn bad |=(reason=@t leaf+(trip reason)))
  ~
::  Removing `each` leaves the unused mapper's message tag without context.
++  test-unused-unresolved-tag
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (todo-full-reader-inputs (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item))
  =/  file=path  /ui/todo-list/jibb
  =/  src=@t  (text drop-each-unfixed)
  =/  modules=jbundle:jibb  ~[[/ui/api/todo/jibb (text api)]]
  =/  out=jfile-detailed-result:jibb  (todo-full-detailed file src externals.inputs marks.inputs modules u.prepared)
  ?:  ?=(%& -.out)  ~[leaf+"unused unresolved message tag was accepted"]
  =/  excerpt=@t  (show-error:jibb src [file 39 32 "nothing fixes the union of %toggled; add a `^-`"])
  =/  want=@t  (cat 3 '++ row-of: nothing fixes the union of %toggled; add a `^-`\0a' excerpt)
  ?.  =(want message.p.out)  ~[leaf+"unused tag diagnostic differed" leaf+(trip message.p.out)]
  ~

--
