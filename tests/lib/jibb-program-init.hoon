::  Transactional direct-program initializer context, without UI execution.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  initializer  %txt  /tests/type-program-main/initializer/txt
/*  initializer-consumer  %txt  /tests/type-program-main/initializer-consumer/txt
/*  initializer-unfaced  %txt  /tests/type-program-main/initializer-unfaced/txt
/*  initializer-pun  %txt  /tests/type-program-main/initializer-pun/txt
/*  initializer-alias  %txt  /tests/type-program-main/initializer-alias/txt
/*  initializer-open-update  %txt  /tests/type-program-main/initializer-open-update/txt
/*  initializer-open-view  %txt  /tests/type-program-main/initializer-open-view/txt
/*  initializer-nested-branch  %txt  /tests/type-program-main/initializer-nested-branch/txt
/*  initializer-error  %txt  /tests/type-program-main/initializer-error/txt
/*  initializer-earlier  %txt  /tests/type-program-main/initializer-earlier/txt
/*  initializer-model  %txt  /tests/type-program-main/initializer-model/txt
/*  initializer-message  %txt  /tests/type-program-main/initializer-message/txt
/*  initializer-generic  %txt  /tests/type-program-main/initializer-generic/txt
/*  initializer-missing  %txt  /tests/type-program-main/initializer-missing/txt
/*  initializer-tag  %txt  /tests/type-program-main/initializer-tag/txt
/*  initializer-no-main  %txt  /tests/type-program-main/initializer-no-main/txt
/*  initializer-subs  %txt  /tests/type-program-main/initializer-subs/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  program-init-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-prelude-with-internal:jibb public private)
::
++  program-init-detailed
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-init-legacy
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  (infer-jibb-file:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-init-positive
  |=  [at=path src=@t downstream=(unit @t) prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-init-detailed at src ~ prepared)
  ?:  ?=(%| -.detailed)  ~["contextual direct program init was rejected"]
  =/  checked=ifile:jibb  iface.p.detailed
  =/  legacy=jfile-result:jibb  (program-init-legacy at src ~ prepared)
  ?:  ?=(%| -.legacy)  ~["legacy adapter rejected contextual init"]
  ?.  =(values.checked values.iface.p.legacy)  ~["contextual structured and legacy values differ"]
  =/  init=(unit ischeme:jibb)  (ienv-lookup:jibb %init values.checked)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  init  ~["contextual init interface is missing"]
  ?~  main  ~["contextual main interface is missing"]
  ?.  ?=(~ vars.u.init)  ~["contextual init interface is not closed"]
  =/  expected=tape  "$-((list @t) [xs=(list @t) [draft=@t error=(unit @t)]])"
  ?.  =((show-itype:jibb typ.u.init ~) expected)  ~["contextual init interface type differs"]
  ?.  ?=(~ vars.u.main)  ~["contextual main interface is not closed"]
  =/  fields=(list itype:jibb)  (record-fields-named:jibb %init typ.u.main ~)
  ?.  =(fields ~[typ.u.init])  ~["contextual main initializer field differs"]
  ?~  source.checked  ~["contextual program source evidence is missing"]
  ?.  =(u.source.checked src)  ~["contextual program source evidence differs"]
  ?~  graph.checked  ~["contextual program request graph is missing"]
  ?~  downstream  ~
  =/  consumer-at=path  /tests/program-main/initializer-consumer/jibb
  =/  imported=jfile-detailed-result:jibb
    (program-init-detailed consumer-at u.downstream ~[[at src]] prepared)
  ?:  ?=(%| -.imported)  ~[(weld "downstream contextual initializer import was rejected: " (trip message.p.imported))]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~["downstream contextual initializer is missing"]
  ?.  =((show-itype:jibb typ.u.use ~) expected)  ~["downstream contextual initializer type differs"]
  ?.  =(u.use u.init)  ~["downstream contextual initializer scheme differs"]
  ~
::
++  program-init-negative
  |=  [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-init-detailed at src ~ prepared)
  ?:  ?=(%& -.detailed)  ~[(weld (trip label) ": structured check accepted")]
  ?.  ?=(~ overlap.p.detailed)  ~[(weld (trip label) ": unexpected overlap evidence")]
  ?.  =(message.p.detailed boundary)
    ~[(weld (weld (trip label) ": rejected at the wrong boundary: ") (trip message.p.detailed))]
  =/  legacy=jfile-result:jibb  (program-init-legacy at src ~ prepared)
  ?:  ?=(%& -.legacy)  ~[(weld (trip label) ": legacy check accepted")]
  ?.  =(p.legacy boundary)  ~[(weld (trip label) ": legacy boundary differs")]
  ~
::
++  program-init-negative-cases
  |=  [cases=(list [label=@t at=path src=@t boundary=@t]) prepared=iprelude:jibb]
  ^-  (list tape)
  ?~  cases  ~
  %+  weld
    (program-init-negative label.i.cases at.i.cases src.i.cases boundary.i.cases prepared)
  $(cases t.cases)
::
++  program-init-pending
  |=  [at=path src=@t line=@ud col=@ud literal=tape]
  ^-  @t
  (show-error:jibb src [at line col (weld "nothing fixes the union of " literal)])
::
::  Each alternate writes update, view or subs another way (one faced mold,
::  a pun, an alias, generic in the model, generic view and subs samples), or
::  gives init a body only ordinary inference takes (a branch over a nested
::  call's union), and its initializer must check like the island's.
++  program-init-alternates
  |=  [alternates=(list [name=@ta src=@t]) prepared=iprelude:jibb]
  ^-  (list tape)
  ?~  alternates  ~
  %+  weld
    %+  turn
      (program-init-positive /tests/program-main/[name.i.alternates]/jibb src.i.alternates ~ prepared)
    |=(reason=tape (weld (weld (trip name.i.alternates) ": ") reason))
  $(alternates t.alternates)
::
++  program-init-errors
  |=  [public=@t private=@t island=@t downstream=@t alternates=(list [name=@ta src=@t]) negatives=(list @t)]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)  (program-init-prepared public private)
  ?~  prepared  ~["synthetic program prelude did not prepare for contextual init"]
  =/  at=path  /tests/program-main/initializer/jibb
  =/  positives=(list tape)
    %+  weld
      (program-init-positive at island `downstream u.prepared)
    (program-init-alternates alternates u.prepared)
  ?.  =(9 (lent negatives))  ~["contextual negative fixture count differs"]
  =/  definitions=@t  (crip "module definitions need unsupported inference: {(spud at)}: ++ main")
  =/  cases=(list [label=@t at=path src=@t boundary=@t])
    :~  ['incompatible error field' at (snag 0 negatives) (program-init-pending at (snag 0 negatives) 6 32 "~")]
        ['earlier tuple mismatch' at (snag 1 negatives) (program-init-pending at (snag 1 negatives) 6 34 "~")]
        ['inconsistent model' at (snag 2 negatives) (program-init-pending at (snag 2 negatives) 7 32 "~")]
        ::  init checks against update's model; main rejects the other message
        ['inconsistent message' at (snag 3 negatives) definitions]
        ['missing/generic data sample' at (snag 4 negatives) (program-init-pending at (snag 4 negatives) 6 22 "~")]
        ['missing initializer' at (snag 5 negatives) definitions]
        ['unrelated pending tag' at (snag 6 negatives) (program-init-pending at (snag 6 negatives) 12 6 "%unrelated")]
        ['non-main same source' at (snag 7 negatives) (program-init-pending at (snag 7 negatives) 6 32 "~")]
        ['init and subs unresolved' at (snag 8 negatives) (program-init-pending at (snag 8 negatives) 6 32 "~")]
        :-  'API path'
        [/ui/api/program-main/jibb island 'module kind needs unsupported inference: /ui/api/program-main/jibb']
        :-  'store path'
        [/ui/stores/program-main/jibb island 'module kind needs unsupported inference: /ui/stores/program-main/jibb']
    ==
  (weld positives (program-init-negative-cases cases u.prepared))
::
++  test-program-init
  ^-  tang
  =/  negatives=(list @t)
    :~  (text initializer-error)
        (text initializer-earlier)
        (text initializer-model)
        (text initializer-message)
        (text initializer-generic)
        (text initializer-missing)
        (text initializer-tag)
        (text initializer-no-main)
        (text initializer-subs)
    ==
  =/  alternates=(list [name=@ta src=@t])
    :~  [%initializer-unfaced (text initializer-unfaced)]
        [%initializer-pun (text initializer-pun)]
        [%initializer-alias (text initializer-alias)]
        [%initializer-open-update (text initializer-open-update)]
        [%initializer-open-view (text initializer-open-view)]
        [%initializer-nested-branch (text initializer-nested-branch)]
    ==
  (turn (program-init-errors prelude internal (text initializer) (text initializer-consumer) alternates negatives) |=(reason=tape leaf+reason))
--
