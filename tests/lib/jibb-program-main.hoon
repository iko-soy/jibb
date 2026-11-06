::  Full program-kind checking, aliases, closed interfaces and diagnostics.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %txt  /tests/type-program-main/source/txt
/*  consumer  %txt  /tests/type-program-main/consumer/txt
/*  gate-model  %txt  /tests/type-program-main/gate-model/txt
/*  gate-data  %txt  /tests/type-program-main/gate-data/txt
/*  nonempty-subs  %txt  /tests/type-program-main/nonempty-subs/txt
/*  mismatched-model  %txt  /tests/type-program-main/mismatched-model/txt
/*  arbitrary-main  %txt  /tests/type-program-main/arbitrary-main/txt
/*  alias-main  %txt  /tests/type-program-main/alias-main/txt
/*  open-message  %txt  /tests/type-program-main/open-message/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  program-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
::
++  program-main-detailed
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-main-legacy
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  (infer-jibb-file:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-main-negative-errors
  |=  [label=@t at=path src=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  detailed=jfile-detailed-result:jibb  (program-main-detailed at src ~ prepared)
  ?:  ?=(%& -.detailed)  ~[(weld (trip label) ": structured check accepted")]
  ?.  ?=(~ overlap.p.detailed)  ~[(weld (trip label) ": unexpected overlap evidence")]
  =/  legacy=jfile-result:jibb  (program-main-legacy at src ~ prepared)
  ?:  ?=(%& -.legacy)  ~[(weld (trip label) ": legacy check accepted")]
  ?.  =(p.legacy message.p.detailed)  ~[(weld (trip label) ": adapter messages differ")]
  ~
::
++  program-main-errors
  |=  [public=@t private=@t island=@t downstream=@t negatives=(list @t)]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (program-prepared public private)
  ?~  prepared  ~["synthetic program prelude did not prepare"]
  =/  at=path  /tests/program-main/island/jibb
  =/  detailed=jfile-detailed-result:jibb  (program-main-detailed at island ~ u.prepared)
  ?:  ?=(%| -.detailed)  ~["direct closed program main was rejected"]
  =/  checked=ifile:jibb  iface.p.detailed
  ?~  graph.checked  ~["program request graph evidence is missing"]
  =/  legacy=jfile-result:jibb  (program-main-legacy at island ~ u.prepared)
  ?:  ?=(%| -.legacy)  ~["legacy adapter rejected a closed program main"]
  ?.  =(values.checked values.iface.p.legacy)  ~["structured and legacy interface values differ"]
  =/  init=(unit ischeme:jibb)  (ienv-lookup:jibb %init values.checked)
  =/  update=(unit ischeme:jibb)  (ienv-lookup:jibb %update values.checked)
  =/  view=(unit ischeme:jibb)  (ienv-lookup:jibb %view values.checked)
  =/  subs=(unit ischeme:jibb)  (ienv-lookup:jibb %subs values.checked)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  init  ~["init interface is missing"]
  ?~  update  ~["update interface is missing"]
  ?~  view  ~["view interface is missing"]
  ?~  subs  ~["subs interface is missing"]
  ?~  main  ~["main interface is missing"]
  ?:  (program-type-closed:jibb values.checked ~)
    ~["program kind was accepted without its source-backed prelude"]
  =/  program-scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %program values.iface.u.prepared)
  ?~  program-scheme  ~["synthetic program scheme is missing"]
  ?.  ?=(%fn -.typ.u.program-scheme)  ~["synthetic program value is not a gate"]
  =/  broken-values=ienv:jibb
    (skim values.iface.u.prepared |=(entry=[name=term scheme=ischeme:jibb] !=(%program name.entry)))
  =/  broken=ifile:jibb
    iface.u.prepared(values [[%program [[%fn sample.typ.u.program-scheme [%atom %ud]] vars.u.program-scheme ~]] broken-values])
  =/  malformed=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at island ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `broken)
  ?:  ?=(%& -.malformed)  ~["program result was not checked against the program mold"]
  =/  kind-error=@t
    (of-wain:format ~['++ main: main has type @ud; expected an element, page, program, or store' '/tests/program-main/island.jibb:5:4: main has type @ud' '++ main (program (init) update view subs)' '   ^'])
  ?.  =(message.p.malformed kind-error)  ~["malformed program failed before the kind check"]
  =/  open=jfile-detailed-result:jibb
    (program-main-detailed at (snag 6 negatives) ~ u.prepared)
  ?:  ?=(%& -.open)  ~["open program message was accepted"]
  =/  other-values=ienv:jibb
    (skim values.checked |=(entry=[name=term scheme=ischeme:jibb] !=(%main name.entry)))
  =/  open-values=ienv:jibb  [[%main u.main(vars ~[0])] other-values]
  ?:  (program-type-closed:jibb open-values `iface.u.prepared)
    ~["generic main scheme passed the closure check"]
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  ?.  =(u.init [[%fn [%atom %t] model] ~ ~])  ~["init interface type differs"]
  ?.  ?=(~ vars.u.main)  ~["main interface is not closed"]
  =/  init-fields=(list itype:jibb)  (record-fields-named:jibb %init typ.u.main ~)
  =/  update-fields=(list itype:jibb)  (record-fields-named:jibb %update typ.u.main ~)
  =/  view-fields=(list itype:jibb)  (record-fields-named:jibb %view typ.u.main ~)
  =/  subs-fields=(list itype:jibb)  (record-fields-named:jibb %subs typ.u.main ~)
  ?.  =(init-fields ~[typ.u.init])  ~["main initializer field differs"]
  ?.  &(=(1 (lent update-fields)) =(1 (lent view-fields)) =(1 (lent subs-fields)))
    ~["main component fields differ"]
  ?~  source.checked  ~["program source evidence is missing"]
  ?.  =(u.source.checked island)  ~["program source evidence differs"]
  =/  consumer-at=path  /tests/program-main/consumer/jibb
  =/  imported=jfile-detailed-result:jibb
    (program-main-detailed consumer-at downstream ~[[at island]] u.prepared)
  ?:  ?=(%| -.imported)  ~[(weld "ordinary downstream program import was rejected: " (trip message.p.imported))]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~["downstream imported initializer is missing"]
  ?.  =(u.use u.init)  ~["downstream imported initializer type differs"]
  ?.  =(7 (lent negatives))  ~["focused negative fixture count differs"]
  =/  relocated=jfile-detailed-result:jibb
    (program-main-detailed /ui/stores/program-main/jibb island ~ u.prepared)
  ?:  ?=(%| -.relocated)  ~[(weld "program under stores directory rejected: " (trip message.p.relocated))]
  ?.  =(%island kind.p.relocated)  ~["stores directory changed program kind"]
  =/  api-located=jfile-detailed-result:jibb
    (program-main-detailed /ui/api/program-main/jibb island ~ u.prepared)
  ?:  ?=(%| -.api-located)  ~[(weld "program under api directory rejected: " (trip message.p.api-located))]
  ?.  =(%island kind.p.api-located)  ~["api directory changed program kind"]
  =/  aliased=jfile-detailed-result:jibb
    (program-main-detailed at (snag 5 negatives) ~ u.prepared)
  ?:  ?=(%| -.aliased)  ~[(weld "program builder alias rejected: " (trip message.p.aliased))]
  =/  alias-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.iface.p.aliased)
  ?~  alias-main  ~["program builder alias main missing"]
  ?.  =(u.alias-main u.main)  ~["program builder alias changed main's type"]
  =/  cases=(list [label=@t at=path src=@t])
    :~  ['gate in model' at (snag 0 negatives)]
        ['gate in data' at (snag 1 negatives)]
        ['nonempty subs' at (snag 2 negatives)]
        ['mismatched model' at (snag 3 negatives)]
        ['arbitrary main' at (snag 4 negatives)]
    ==
  (zing (turn cases |=(c=[label=@t at=path src=@t] (program-main-negative-errors label.c at.c src.c u.prepared))))
::
++  test-program-main
  ^-  tang
  =/  negatives=(list @t)
    :~  (text gate-model)
        (text gate-data)
        (text nonempty-subs)
        (text mismatched-model)
        (text arbitrary-main)
        (text alias-main)
        (text open-message)
    ==
  (turn (program-main-errors prelude internal (text source) (text consumer) negatives) |=(reason=tape leaf+reason))
--
