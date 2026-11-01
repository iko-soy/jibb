::  Transactional direct-program update result context, without UI execution.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  source  %txt  /tests/type-program-update/source/txt
/*  consumer  %txt  /tests/type-program-update/consumer/txt
/*  wrong-result  %txt  /tests/type-program-update/wrong-result/txt
/*  wrong-model  %txt  /tests/type-program-update/wrong-model/txt
/*  wrong-message  %txt  /tests/type-program-update/wrong-message/txt
/*  malformed-sample  %txt  /tests/type-program-update/malformed-sample/txt
/*  three-slot-sample  %txt  /tests/type-program-update/three-slot-sample/txt
/*  non-main  %txt  /tests/type-program-update/non-main/txt
/*  unrelated-tag  %txt  /tests/type-program-update/unrelated-tag/txt
/*  missing-list  %txt  /tests/type-program-update/missing-list/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  program-update-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-prelude-with-internal:jibb public private)
::
++  program-update-detailed
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-update-legacy
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  (infer-jibb-file:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-update-positive
  |=  [at=path src=@t downstream=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-update-detailed at src ~ prepared)
  ?:  ?=(%| -.detailed)  ~["contextual direct program update was rejected"]
  =/  checked=ifile:jibb  iface.p.detailed
  =/  legacy=jfile-result:jibb  (program-update-legacy at src ~ prepared)
  ?:  ?=(%| -.legacy)  ~["legacy adapter rejected contextual update"]
  ?.  =(values.checked values.iface.p.legacy)  ~["contextual structured and legacy values differ"]
  =/  update=(unit ischeme:jibb)  (ienv-lookup:jibb %update values.checked)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  update  ~["contextual update interface is missing"]
  ?~  main  ~["contextual main interface is missing"]
  ?.  ?=(~ vars.u.update)  ~["contextual update interface is not closed"]
  =/  expected=tape  "$-([event=message current=[count=@ud]] [count=@ud (list (cmd message))])"
  ?.  =((show-itype:jibb typ.u.update ~) expected)  ~["contextual update interface type differs"]
  ?.  ?=(~ vars.u.main)  ~["contextual main interface is not closed"]
  =/  fields=(list itype:jibb)  (record-fields-named:jibb %update typ.u.main ~)
  ?.  ?=([* ~] fields)  ~["contextual main update field is missing"]
  =/  main-expected=tape  "$-([message count=@ud] [count=@ud (list (cmd message))])"
  ?.  =((show-itype:jibb i.fields ~) main-expected)  ~["contextual main update field differs"]
  ?~  source.checked  ~["contextual program source evidence is missing"]
  ?.  =(u.source.checked src)  ~["contextual program source evidence differs"]
  ?~  graph.checked  ~["contextual program request graph is missing"]
  =/  consumer-at=path  /tests/program-update/consumer/jibb
  =/  imported=jfile-detailed-result:jibb
    (program-update-detailed consumer-at downstream ~[[at src]] prepared)
  ?:  ?=(%| -.imported)  ~[(weld "downstream contextual update import was rejected: " (trip message.p.imported))]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~["downstream contextual update is missing"]
  =/  imported-expected=tape  "$-([message.island-prog count=@ud] [count=@ud (list (cmd message.island-prog))])"
  ?.  =((show-itype:jibb typ.u.use ~) imported-expected)  ~["downstream contextual update type differs"]
  ?.  ?=(~ vars.u.use)  ~["downstream contextual update is not closed"]
  ~
::
++  program-update-negative
  |=  [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-update-detailed at src ~ prepared)
  ?:  ?=(%& -.detailed)  ~[(weld (trip label) ": structured check accepted")]
  ?.  ?=(~ overlap.p.detailed)  ~[(weld (trip label) ": unexpected overlap evidence")]
  ?.  =(message.p.detailed boundary)  ~[(weld (trip label) ": rejected at the wrong boundary")]
  =/  legacy=jfile-result:jibb  (program-update-legacy at src ~ prepared)
  ?:  ?=(%& -.legacy)  ~[(weld (trip label) ": legacy check accepted")]
  ?.  =(p.legacy boundary)  ~[(weld (trip label) ": legacy boundary differs")]
  ~
::
++  program-update-negative-cases
  |=  [cases=(list [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb])]
  ^-  (list tape)
  ?~  cases  ~
  %+  weld
    (program-update-negative label.i.cases at.i.cases src.i.cases boundary.i.cases prepared.i.cases)
  $(cases t.cases)
::
++  program-update-errors
  |=  [public=@t private=@t island=@t downstream=@t negatives=(list @t)]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)  (program-update-prepared public private)
  ?~  prepared  ~["synthetic program prelude did not prepare for contextual update"]
  ?.  =(8 (lent negatives))  ~["contextual update negative fixture count differs"]
  =/  at=path  /tests/program-update/island/jibb
  =/  definitions=@t  (crip "module definitions need unsupported inference: {(spud at)}")
  =/  without-cmd=iprelude:jibb
    =/  kept=imold-types:jibb
      (skim molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] !=(%cmd name.m)))
    [iface.u.prepared(molds kept) values.u.prepared molds.u.prepared]
  =/  without-list=iprelude:jibb
    =/  kept=imold-types:jibb
      (skim molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] !=(%list name.m)))
    [iface.u.prepared(molds kept) values.u.prepared molds.u.prepared]
  =/  cases=(list [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb])
    :~  ['wrong result constructor' at (snag 0 negatives) definitions u.prepared]
        ['inconsistent model' at (snag 1 negatives) definitions u.prepared]
        ['inconsistent message' at (snag 2 negatives) definitions u.prepared]
        ['malformed sample' at (snag 3 negatives) definitions u.prepared]
        ['non-two-slot sample' at (snag 4 negatives) definitions u.prepared]
        ['non-main same source' at (snag 5 negatives) definitions u.prepared]
        ['unrelated pending tag' at (snag 6 negatives) definitions u.prepared]
        ['missing canonical cmd' at island definitions without-cmd]
        ['missing canonical list' at (snag 7 negatives) definitions without-list]
        :-  'API path'
        [/ui/api/program-update/jibb island 'module kind needs unsupported inference: /ui/api/program-update/jibb' u.prepared]
        :-  'store path'
        [/ui/stores/program-update/jibb island 'module kind needs unsupported inference: /ui/stores/program-update/jibb' u.prepared]
    ==
  %+  weld
    (program-update-positive at island downstream u.prepared)
  (program-update-negative-cases cases)
::
++  test-program-update
  ^-  tang
  =/  negatives=(list @t)
    :~  (text wrong-result)
        (text wrong-model)
        (text wrong-message)
        (text malformed-sample)
        (text three-slot-sample)
        (text non-main)
        (text unrelated-tag)
        (text missing-list)
    ==
  (turn (program-update-errors prelude internal (text source) (text consumer) negatives) |=(reason=tape leaf+reason))
--
