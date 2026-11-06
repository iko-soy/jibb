::  Transactional direct-program initializer context, without UI execution.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
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
/*  initializer-missing  %txt  /tests/type-program-main/initializer-missing/txt
/*  initializer-tag  %txt  /tests/type-program-main/initializer-tag/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  program-init-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
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
  ?:  ?=(%| -.detailed)  ~[(weld "contextual direct program init was rejected: " (trip message.p.detailed))]
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
  ?.  =((show-itype:jibb typ.u.init ~) expected)
    ~["contextual init interface type differs: {(show-itype:jibb typ.u.init ~)}"]
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
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
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
++  program-init-message-negative
  |=  [at=path src=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-init-detailed at src ~ prepared)
  ?:  ?=(%& -.detailed)  ~["inconsistent message: structured check accepted"]
  ?.  ?=(~ overlap.p.detailed)  ~["inconsistent message: unexpected overlap evidence"]
  =/  legacy=jfile-result:jibb  (program-init-legacy at src ~ prepared)
  ?:  ?=(%& -.legacy)  ~["inconsistent message: legacy check accepted"]
  ?.  =(p.legacy message.p.detailed)  ~["inconsistent message: legacy boundary differs"]
  =/  rendered=tape  (trip message.p.detailed)
  ?.  (contains rendered "++ main: call's sample and argument types do not unify")
    ~[(weld "inconsistent message: wrong headline: " rendered)]
  ?.  (contains rendered "/tests/program-main/initializer.jibb:8:10: called gate has type $-([init=")
    ~[(weld "inconsistent message: wrong called-gate site: " rendered)]
  =/  sites=tape
    %-  trip
    (of-wain:format ~['++ main (program init update view subs)' '         ^' '/tests/program-main/initializer.jibb:8:30: argument has type message' '++ main (program init update view subs)' '                             ^'])
  ?.  (contains rendered sites)
    ~[(weld "inconsistent message: wrong excerpts or argument site: " rendered)]
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
  (show-error:jibb src [at line col (weld "nothing fixes the union of " (weld literal "; add a `^-`"))])
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
    ;:  weld
      (program-init-positive at island `downstream u.prepared)
      (program-init-positive /ui/api/program-main/jibb island ~ u.prepared)
      (program-init-positive /ui/stores/program-main/jibb island ~ u.prepared)
      (program-init-alternates alternates u.prepared)
    ==
  ?.  =(6 (lent negatives))  ~["contextual negative fixture count differs"]
  =/  cases=(list [label=@t at=path src=@t boundary=@t])
    :~  :-  'incompatible error field'
        [at (snag 0 negatives) (of-wain:format ~['++ init: value does not fit its expected type' '/tests/program-main/initializer.jibb:1:33: expected field type has type @t' '+$ model [xs=(list @t) draft=@t error=@t]' '                                ^' '/tests/program-main/initializer.jibb:6:32: value has type ~' '++ init |= ts=(list @t) [ts "" ~]' '                               ^'])]
        :-  'earlier tuple mismatch'
        [at (snag 1 negatives) (of-wain:format ~['++ init: value does not fit its expected type' '/tests/program-main/initializer.jibb:1:24: expected field type has type @t' '+$ model [xs=(list @t) draft=@t error=(unit @t)]' '                       ^' '/tests/program-main/initializer.jibb:6:29: value has type @p' '++ init |= ts=(list @t) [ts ~zod ~]' '                            ^'])]
        :-  'inconsistent model'
        [at (snag 2 negatives) (of-wain:format ~['++ main: record molds `model` and `other` do not unify' '/tests/program-main/initializer.jibb:1:4: expected record mold' '+$ model [xs=(list @t) draft=@t error=(unit @t)]' '   ^' '/tests/program-main/initializer.jibb:2:4: actual record mold' '+$ other [xs=(list @t) draft=@t error=(unit @t) extra=@ud]' '   ^'])]
        :-  'missing initializer'
        [at (snag 4 negatives) (cat 3 '++ main: unknown name `init`\0a' (show-error:jibb (snag 4 negatives) [at 5 18 "unknown name"]))]
        :-  'unrelated pending tag'
        [at (snag 5 negatives) (cat 3 '++ orphan: nothing fixes the union of %unrelated; add a `^-`\0a' (program-init-pending at (snag 5 negatives) 12 6 "%unrelated"))]
    ==
  ;:  weld
    positives
    (program-init-negative-cases cases u.prepared)
    (program-init-message-negative at (snag 3 negatives) u.prepared)
  ==
::
++  test-program-init
  ^-  tang
  =/  negatives=(list @t)
    :~  (text initializer-error)
        (text initializer-earlier)
        (text initializer-model)
        (text initializer-message)
        (text initializer-missing)
        (text initializer-tag)
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
