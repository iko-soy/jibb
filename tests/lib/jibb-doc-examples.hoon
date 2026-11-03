::  Full checking for doc fragments in their intended module/prelude contexts.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  imports  %jibb  /tests/golden/doc-grammar-01-imports/source/jibb
/*  view-day  %jibb  /tests/golden/doc-grammar-03-view-day/source/jibb
/*  step  %jibb  /tests/golden/doc-grammar-04-step/source/jibb
/*  cmd-sub  %jibb  /tests/golden/doc-overview-01-cmd-sub/source/jibb
/*  todo-sur  %txt  /my-app/sur/todo/hoon
/*  todo-action  %txt  /my-app/mar/todo-action/hoon
/*  blog-sur  %txt  /my-app/sur/blog/hoon
/*  card  %txt  /my-app/ui/components/card/jibb
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
++  doc-detailed
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  doc-legacy
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  (infer-jibb-file:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  doc-reader-inputs
  |=  [sur=@t action=@t blog=@t]
  ^-  [marks=imark-externals:jibb externals=iexternals:jibb]
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  todo-subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  action-result=*  (read-mark:jibb-import %todo-action -:(ride todo-subject action))
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  posts=type  -:(ride -:!>(..zuse) blog)
  =/  post-input=*  (read-named:jibb-import %blog %post posts)
  :_  ~[[%todo %item item-input] [%blog %post post-input]]
  ~[[%todo-action action-result]]
::
++  doc-value-errors
  |=  [label=tape name=term expected=@t checked=ifile:jibb]
  ^-  (list tape)
  =/  value=(unit ischeme:jibb)  (ienv-lookup:jibb name values.checked)
  ?~  value  ~[(weld label ": value is missing")]
  =/  printed=itype:jibb  (canonical-itype:jibb typ.u.value vars.u.value)
  =/  actual=@t  (crip (show-itype:jibb printed ~))
  ?.  =(actual expected)  ~[(weld label (weld ": type was " (trip actual)))]
  ~
::
++  doc-positive
  |=  [label=tape at=path src=@t name=term expected=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (doc-detailed at src ~ ~ ~ prepared)
  ?:  ?=(%| -.detailed)  ~[(weld label (weld ": detailed rejected: " (trip message.p.detailed)))]
  =/  legacy=jfile-result:jibb  (doc-legacy at src ~ ~ ~ prepared)
  ?:  ?=(%| -.legacy)  ~[(weld label (weld ": legacy rejected: " (trip p.legacy)))]
  =/  failures=(list tape)
    (doc-value-errors (weld label ": detailed") name expected iface.p.detailed)
  =?  failures  !=(values.iface.p.detailed values.iface.p.legacy)
    [(weld label ": detailed and legacy values differ") failures]
  =?  failures  !=(molds.iface.p.detailed molds.iface.p.legacy)
    [(weld label ": detailed and legacy molds differ") failures]
  (weld failures (doc-value-errors (weld label ": legacy") name expected iface.p.legacy))
::
++  doc-cmd-prelude
  |=  prepared=iprelude:jibb
  ^-  iprelude:jibb
  =/  excluded=(list term)  ~[%cmd %sub]
  =/  kept=imold-types:jibb
    (skim molds.iface.prepared |=(m=[name=term template=ischeme:jibb] !(lien excluded |=(n=term =(n name.m)))))
  =/  names=(list term)
    (skim molds.prepared |=(n=term !(lien excluded |=(x=term =(x n)))))
  [iface.prepared(molds kept) values.prepared names]
::
++  doc-cmd-interface-errors
  |=  [label=tape checked=ifile:jibb original=ifile:jibb]
  ^-  (list tape)
  =/  failures=(list tape)  ~
  =/  names=(list term)  ~[%cmd %sub]
  |-
  ?~  names  failures
  =/  actual=(unit ischeme:jibb)  (find-jibb-mold:jibb i.names checked)
  =/  expected=(unit ischeme:jibb)  (find-jibb-mold:jibb i.names original)
  ?~  actual  $(names t.names, failures [(weld label ": mold is missing") failures])
  ?~  expected  $(names t.names, failures [(weld label ": canonical mold is missing") failures])
  =/  actual-type=itype:jibb  (canonical-itype:jibb typ.u.actual vars.u.actual)
  =/  expected-type=itype:jibb  (canonical-itype:jibb typ.u.expected vars.u.expected)
  =/  shown=@t  (crip (show-itype:jibb actual-type ~))
  =/  expected-shown=@t  (crip (show-itype:jibb expected-type ~))
  ?.  =(shown expected-shown)
    $(names t.names, failures [(weld label (weld ": mold scheme was " (trip shown))) failures])
  $(names t.names)
::
++  doc-cmd-errors
  |=  [src=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  at=path  /lib/jibb/prelude/jibb
  =/  reduced=iprelude:jibb  (doc-cmd-prelude prepared)
  =/  detailed=jfile-detailed-result:jibb  (doc-detailed at src ~ ~ ~ reduced)
  ?:  ?=(%| -.detailed)  ~[(weld "cmd/sub detailed rejected: " (trip message.p.detailed))]
  =/  legacy=jfile-result:jibb  (doc-legacy at src ~ ~ ~ reduced)
  ?:  ?=(%| -.legacy)  ~[(weld "cmd/sub legacy rejected: " (trip p.legacy))]
  =/  failures=(list tape)
    (doc-cmd-interface-errors "cmd/sub detailed" iface.p.detailed iface.prepared)
  =?  failures  !=(molds.iface.p.detailed molds.iface.p.legacy)
    ["cmd/sub detailed and legacy molds differ" failures]
  (weld failures (doc-cmd-interface-errors "cmd/sub legacy" iface.p.legacy iface.prepared))
::
++  doc-import-errors
  |=  [src=@t sur=@t action=@t blog=@t card-source=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  at=path  /ui/imports/jibb
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]
    (doc-reader-inputs sur action blog)
  =/  modules=jbundle:jibb  ~[[/ui/components/card/jibb card-source]]
  =/  detailed=jfile-detailed-result:jibb
    (doc-detailed at src externals.inputs marks.inputs modules prepared)
  ?:  ?=(%| -.detailed)  ~[(weld "imports detailed rejected: " (trip message.p.detailed))]
  =/  legacy=jfile-result:jibb
    (doc-legacy at src externals.inputs marks.inputs modules prepared)
  ?:  ?=(%| -.legacy)  ~[(weld "imports legacy rejected: " (trip p.legacy))]
  =/  use-source=@t
    %+  rap  3
    :~  src
        '++ use-item |= i=item.todo i\0a'
        '++ use-action |= a=todo-action a\0a'
        '++ use-card card.card\0a'
    ==
  =/  used=jfile-detailed-result:jibb
    (doc-detailed at use-source externals.inputs marks.inputs modules prepared)
  ?:  ?=(%| -.used)  ~[(weld "import consumers rejected: " (trip message.p.used))]
  =/  used-legacy=jfile-result:jibb
    (doc-legacy at use-source externals.inputs marks.inputs modules prepared)
  ?:  ?=(%| -.used-legacy)  ~[(weld "legacy import consumers rejected: " (trip p.used-legacy))]
  =/  failures=(list tape)  ~
  =/  missing-module=jfile-detailed-result:jibb
    (doc-detailed at use-source externals.inputs marks.inputs ~ prepared)
  =?  failures  ?=(%& -.missing-module)  ["imports accepted a missing Jibb module" failures]
  =/  missing-mark=jfile-detailed-result:jibb
    (doc-detailed at use-source externals.inputs ~ modules prepared)
  =?  failures  ?=(%& -.missing-mark)  ["imports accepted a missing mark" failures]
  =/  missing-sur=jfile-detailed-result:jibb
    (doc-detailed at use-source ~ marks.inputs modules prepared)
  =?  failures  ?=(%& -.missing-sur)  ["imports accepted missing /sur molds" failures]
  failures
::
++  doc-examples-errors
  |=  [public=@t private=@t import-source=@t view-source=@t step-source=@t cmd-source=@t sur=@t action=@t blog=@t card-source=@t]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  ~["doc-example prelude did not prepare"]
  ;:  weld
    (doc-positive "view-day" /ui/view-day/jibb view-source %view '$-([day=@da n=@ud] (element M))' u.prepared)
    (doc-positive "step" /ui/step/jibb step-source %describe '$-(step @t)' u.prepared)
    (doc-cmd-errors cmd-source u.prepared)
    (doc-import-errors import-source sur action blog card-source u.prepared)
  ==
::
++  test-doc-examples
  ^-  tang
  =/  failures=(list tape)
    (doc-examples-errors prelude internal imports view-day step cmd-sub (text todo-sur) (mark-text todo-action) (text blog-sur) (text card))
  (turn failures |=(reason=tape leaf+reason))
--
