::  Static and direct data-page kind checks, without rendering or execution.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  todo-api  %txt  /tests/type-page-main/todo-api/txt
/*  todo-island  %txt  /tests/type-page-main/todo-island/txt
/*  blog-sur  %txt  /tests/type-page-main/blog-sur/txt
/*  posts  %txt  /tests/type-page-main/posts-mark/txt
/*  blog-api  %txt  /tests/type-page-main/blog-api/txt
/*  card  %txt  /tests/type-page-main/card/txt
/*  about  %txt  /tests/type-page-main/static/txt
/*  blog-index  %txt  /tests/type-page-main/blog-index/txt
/*  index  %txt  /tests/type-page-main/index/txt
/*  ctor-page  %txt  /tests/type-page-main/ctor-page/txt
/*  wrong-static  %txt  /tests/type-page-main/wrong-static/txt
/*  arbitrary-main  %txt  /tests/type-page-main/arbitrary-main/txt
/*  page-alias  %txt  /tests/type-page-main/page-alias/txt
/*  indirect-load  %txt  /tests/type-page-main/indirect-load/txt
/*  pure-load  %txt  /tests/type-page-main/pure-load/txt
/*  hand-built-load  %txt  /tests/type-page-main/hand-built-load/txt
/*  typed-load  %txt  /tests/type-page-main/typed-load/txt
/*  diff-load  %txt  /tests/type-page-main/diff-load/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  page-main-detailed
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  page-main-reader-inputs
  |=  [sur=@t action=@t todos=@t update=@t item=@t blog-sur=@t posts=@t]
  ^-  [marks=imark-externals:jibb externals=iexternals:jibb]
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  todo-subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride todo-subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride todo-subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride todo-subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride todo-subject item))
  =/  blog=type  -:(ride -:!>(..zuse) blog-sur)
  =/  blog-subject=type  [%cell [%face %blog blog] -:!>(..zuse)]
  =/  mp=*  (read-mark:jibb-import %posts -:(ride blog-subject posts))
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  post-input=*  (read-named:jibb-import %blog %post blog)
  :_  ~[[%todo %item item-input] [%blog %post post-input]]
  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi] [%posts mp]]
::
++  page-main-positive
  |=  [label=tape at=path src=@t expected=@t consumer-at=path consumer=@t face=term externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb
    (page-main-detailed at src externals marks modules prepared)
  ?:  ?=(%| -.detailed)
    ~[(weld label (weld ": rejected: " (trip message.p.detailed)))]
  =/  checked=ifile:jibb  iface.p.detailed
  ?~  graph.checked  ~[(weld label ": request graph is missing")]
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  main  ~[(weld label ": main is missing")]
  ?.  &(?=(~ vars.u.main) ?=(~ (itype-vars:jibb typ.u.main)))
    ~[(weld label ": main is not closed")]
  =/  actual=@t  (crip (show-itype:jibb typ.u.main ~))
  ?.  =(actual expected)
    ~[(weld label (weld ": main type was " (trip actual)))]
  =/  imported=jfile-detailed-result:jibb
    (page-main-detailed consumer-at consumer externals marks modules prepared)
  ?:  ?=(%| -.imported)
    ~[(weld label (weld ": downstream import rejected: " (trip message.p.imported)))]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~[(weld label ": downstream main is missing")]
  =/  expected-import=itype:jibb
    (itype-in-import:jibb typ.u.main checked face `iface.prepared)
  ?.  &(?=(~ vars.u.use) =(typ.u.use expected-import))
    ~[(weld label ": downstream main type differs")]
  ~
::
++  page-main-negative
  |=  [label=@t at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  (list tape)
  =/  bad=jfile-detailed-result:jibb
    (page-main-detailed at src externals marks modules prepared)
  ?:  ?=(%& -.bad)  ~[(weld (trip label) ": accepted")]
  ~
::
++  page-main-errors
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t todo-api=@t todo-island=@t blog-sur=@t posts=@t blog-api=@t card=@t about=@t blog-index=@t index=@t ctor-page=@t negatives=(list [label=@t src=@t])]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  ~["page prelude did not prepare"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (page-main-reader-inputs sur action todos update item blog-sur posts)
  =/  modules=jbundle:jibb
    :~  [/ui/api/todo/jibb todo-api]
        [/ui/todo-list/jibb todo-island]
        [/ui/api/blog/jibb blog-api]
        [/ui/components/card/jibb card]
        [/ui/about/jibb about]
        [/ui/blog/index/jibb blog-index]
        [/ui/index/jibb index]
        [/tests/page-main/ctor/jibb ctor-page]
    ==
  =/  about-consumer=@t  '/= about-page /ui/about\0a++ imported main.about-page\0a'
  =/  blog-consumer=@t  '/= blog-page /ui/blog/index\0a++ imported main.blog-page\0a'
  =/  index-consumer=@t  '/= index-page /ui/index\0a++ imported main.index-page\0a'
  =/  ctor-consumer=@t  '/= ctor-page /tests/page-main/ctor\0a++ imported main.ctor-page\0a'
  =/  positives=(list (list tape))
    :~  (page-main-positive "about" /ui/about/jibb about '(element !!)' /tests/page-main/about-consumer/jibb about-consumer %about-page externals.inputs marks.inputs modules u.prepared)
        (page-main-positive "blog index" /ui/blog/index/jibb blog-index '[load=$-(~ (ask (list [title=@t slug=@ta]))) view=$-((list [title=@t slug=@ta]) (element !!))]' /tests/page-main/blog-consumer/jibb blog-consumer %blog-page externals.inputs marks.inputs modules u.prepared)
        (page-main-positive "index" /ui/index/jibb index '[load=$-(~ (ask (list [id=@ud [done=? text=@t]]))) view=$-((list [id=@ud [done=? text=@t]]) (element !!))]' /tests/page-main/index-consumer/jibb index-consumer %index-page externals.inputs marks.inputs modules u.prepared)
        (page-main-positive "constructor reply" /tests/page-main/ctor/jibb ctor-page '[load=$-(~ (ask [%got todos=(list [id=@ud [done=? text=@t]])])) view=$-([%got todos=(list [id=@ud [done=? text=@t]])] (element !!))]' /tests/page-main/ctor-consumer/jibb ctor-consumer %ctor-page externals.inputs marks.inputs modules u.prepared)
    ==
  =/  failures=(list tape)  (zing positives)
  ?^  failures  failures
  =/  at=path  /ui/index/jibb
  =/  checked-result=jfile-detailed-result:jibb
    (page-main-detailed at index externals.inputs marks.inputs modules u.prepared)
  ?:  ?=(%| -.checked-result)  ~["index disappeared before evidence controls"]
  =/  checked=ifile:jibb  iface.p.checked-result
  ?~  graph.checked  ~["index graph disappeared before evidence controls"]
  =/  parsed  (parse:jibb at index)
  ?:  ?=(%| -.parsed)  ~["index source no longer parses"]
  =/  main=(unit def:jibb)  (program-main-def:jibb defs.p.parsed)
  ?~  main  ~["index main definition is missing"]
  =/  parts=(unit [load=term view=term])  (page-main-parts:jibb u.main)
  ?~  parts  ~["index page parts are missing"]
  =/  others=(list irequest-evidence:jibb)
    (skim requests.u.graph.checked |=(r=irequest-evidence:jibb !&(=(api-at.r /ui/api/todo/jibb) =(%todos name.r))))
  =/  missing=irequest-graph:jibb  u.graph.checked(requests others)
  =/  resolved=ijimports:jibb
    =/  found=(unit ifile:jibb)
      =/  api=jfile-detailed-result:jibb
        (page-main-detailed /ui/api/todo/jibb todo-api externals.inputs marks.inputs modules u.prepared)
      ?:  ?=(%| -.api)  ~
      `iface.p.api
    ?~  found  ~
    ~[[%todo u.found]]
  ?.  ?=([* ~] resolved)  ~["todo API evidence control did not check"]
  ?:  (page-main-closed:jibb u.parts defs.p.parsed values.checked `iface.u.prepared resolved missing)
    ~["unknown request evidence passed data-page checking"]
  =/  store=(list tape)
    (page-main-negative 'store path' /ui/stores/about/jibb about externals.inputs marks.inputs modules u.prepared)
  ?^  store  store
  (zing (turn negatives |=(c=[label=@t src=@t] (page-main-negative label.c /ui/index/jibb src.c externals.inputs marks.inputs modules u.prepared))))
::
++  test-page-main
  ^-  tang
  =/  negatives=(list [label=@t src=@t])
    :~  ['wrong static message' (text wrong-static)]
        ['arbitrary main' (text arbitrary-main)]
        ['page alias' (text page-alias)]
        ['indirect load' (text indirect-load)]
        ['pure load' (text pure-load)]
        ['hand-built load' (text hand-built-load)]
        ['typed load' (text typed-load)]
        ['diff load' (text diff-load)]
    ==
  =/  failures=(list tape)
    (page-main-errors prelude internal (text sur) (text action) (text todos) (text update) (text item) (text todo-api) (text todo-island) (text blog-sur) (text posts) (text blog-api) (text card) (text about) (text blog-index) (text index) (text ctor-page) negatives)
  (turn failures |=(reason=tape leaf+reason))
--
