::  Transactional direct-program update result context, without UI execution.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
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
  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
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
  ?:  ?=(%| -.detailed)
    ~[(weld "contextual direct program update was rejected: " (trip message.p.detailed))]
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
++  program-update-report
  |=  [at=path src=@t owner=term summary=tape sites=(list [line=@ud col=@ud note=tape])]
  ^-  @t
  =/  heading=@t  (crip "++ {(trip owner)}: {summary}")
  =/  excerpts=(list @t)
    %+  turn  sites
    |=  site=[line=@ud col=@ud note=tape]
    (show-error:jibb src [at line.site col.site note.site])
  (of-wain:format [heading excerpts])
::
++  program-update-negative
  |=  [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-update-detailed at src ~ prepared)
  ?:  ?=(%& -.detailed)  ~[(weld (trip label) ": structured check accepted")]
  ?.  ?=(~ overlap.p.detailed)  ~[(weld (trip label) ": unexpected overlap evidence")]
  ?.  =(message.p.detailed boundary)
    ~[(weld (weld (trip label) ": rejected at the wrong boundary: ") (trip message.p.detailed))]
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
++  program-update-kind-positive
  |=  [label=@t at=path src=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-update-detailed at src ~ prepared)
  ?:  ?=(%| -.detailed)
    ~[(weld (weld (trip label) ": valid island was rejected: ") (trip message.p.detailed))]
  ?.  =(%island kind.p.detailed)  ~[(weld (trip label) ": directory changed the inferred module kind")]
  =/  legacy=jfile-result:jibb  (program-update-legacy at src ~ prepared)
  ?:  ?=(%| -.legacy)  ~[(weld (trip label) ": legacy adapter rejected a valid island")]
  ?.  =(values.iface.p.detailed values.iface.p.legacy)  ~[(weld (trip label) ": structured and legacy values differ")]
  ~
::
++  program-update-errors
  |=  [public=@t private=@t island=@t downstream=@t negatives=(list @t)]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)  (program-update-prepared public private)
  ?~  prepared  ~["synthetic program prelude did not prepare for contextual update"]
  ?.  =(8 (lent negatives))  ~["contextual update negative fixture count differs"]
  =/  at=path  /tests/program-update/island/jibb
  =/  without-cmd=iprelude:jibb
    =/  kept=imold-types:jibb
      (skim molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] !=(%cmd name.m)))
    [iface.u.prepared(molds kept) values.u.prepared molds.u.prepared]
  =/  without-list=iprelude:jibb
    =/  kept=imold-types:jibb
      (skim molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] !=(%list name.m)))
    [iface.u.prepared(molds kept) values.u.prepared molds.u.prepared]
  =/  cases=(list [label=@t at=path src=@t boundary=@t prepared=iprelude:jibb])
    :~  :-  'wrong result constructor'
        :^    at  (snag 0 negatives)
        (program-update-report at (snag 0 negatives) %update "nothing fixes the union of %noop; add a `^-`" ~[[10 28 "nothing fixes the union of %noop; add a `^-`"]])  u.prepared
        :-  'inconsistent model'
        :^    at  (snag 1 negatives)
        (program-update-report at (snag 1 negatives) %update "branch arm does not fit its expected type" ~[[8 3 "expected branch result has type @ud"] [10 18 "branch arm has type @t"]])  u.prepared
        :-  'inconsistent message'
        :^    at  (snag 2 negatives)
        (program-update-report at (snag 2 negatives) %main "call's sample and argument types do not unify" ~[[4 10 "called gate has type $-([init=$-(@t @ud) [update=$-([event=%other current=[count=@ud]] [count=@ud (list (cmd %other))]) [view=$-(@ud (element %other)) subs=$-(@ud (list (sub %other)))]]] [init=$-(@t @ud) [update=$-([%other @ud] [@ud (list (cmd %other))]) [view=$-(@ud (element %other)) subs=$-(@ud (list (sub %other)))]]])"] [4 30 "argument has type %noop"]])  u.prepared
        :-  'malformed sample'
        :^    at  (snag 3 negatives)
        (program-update-report at (snag 3 negatives) %main "local sample `update` does not unify with [%noop @ud]: %noop versus [%noop @ud]" ~[[5 14 "written gate sample"] [3 10 "call context has type [$-(Data Model) [$-([Msg Model] [Model (list (cmd Msg))]) [$-(Model (element Msg)) $-(Model (list (sub Msg)))]]]"]])  u.prepared
        :-  'non-two-slot sample'
        :^    at  (snag 4 negatives)
        (program-update-report at (snag 4 negatives) %main "call's sample and argument types do not unify" ~[[3 10 "called gate has type $-([init=$-(@t [count=@ud]) [update=$-([event=%noop @ud] [count=@ud (list (cmd %noop))]) [view=$-([count=@ud] (element %noop)) subs=$-([count=@ud] (list (sub %noop)))]]] [init=$-(@t @ud) [update=$-([%noop @ud] [@ud (list (cmd %noop))]) [view=$-(@ud (element %noop)) subs=$-(@ud (list (sub %noop)))]]])"] [3 23 "argument has type [%noop [current=[count=@ud] extra=@ud]]"]])  u.prepared
        :-  'non-main same source'
        :^    at  (snag 5 negatives)
        (program-update-report at (snag 5 negatives) %update "nothing fixes the union of ~; add a `^-`" ~[[8 20 "nothing fixes the union of ~; add a `^-`"]])  u.prepared
        :-  'unrelated pending tag'
        :^    at  (snag 6 negatives)
        (program-update-report at (snag 6 negatives) %dangling "nothing fixes the union of %unrelated; add a `^-`" ~[[16 13 "nothing fixes the union of %unrelated; add a `^-`"]])  u.prepared
        :-  'missing canonical cmd'
        :^    at  island
        (program-update-report at island %main "island main needs closed, gate-free data and model types" ~[[5 4 "main has type [init=$-(@t [count=@ud]) [update=$-([message count=@ud] [count=@ud (list (cmd message))]) [view=$-([count=@ud] (element message)) subs=$-([count=@ud] (list (sub message)))]]]"]])  without-cmd
        :-  'missing canonical list'
        :^    at  (snag 7 negatives)
        (program-update-report at (snag 7 negatives) %update "nothing fixes the union of ~; add a `^-`" ~[[9 20 "nothing fixes the union of ~; add a `^-`"]])  without-list
    ==
  %-  zing
  :~  (program-update-positive at island downstream u.prepared)
      (program-update-negative-cases cases)
      (program-update-kind-positive 'API path' /ui/api/program-update/jibb island u.prepared)
      (program-update-kind-positive 'store path' /ui/stores/program-update/jibb island u.prepared)
  ==
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
