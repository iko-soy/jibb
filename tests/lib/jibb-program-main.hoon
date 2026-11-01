::  Narrow closed program-main checking, without execution or watchability claims.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
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
  =/  extra=@t  '\0a+$ element |$ [M] [%node item=M]\0a+$ program |$ [D X M]\0a  [init=$-(D X) update=$-([M X] [X (list (cmd M))]) view=$-(X (element M)) subs=$-(X (list (sub M)))]\0a++ program |= [init=$-(D X) update=$-([M X] [X (list (cmd M))]) view=$-(X (element M)) subs=$-(X (list (sub M)))]\0a  ^- (program D X M) [init update view subs]\0a'
  (prepare-prelude-with-internal:jibb (cat 3 public extra) private)
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
  =/  parsed  (parse:jibb at island)
  ?:  ?=(%| -.parsed)  ~["program source no longer parses"]
  =/  main-def=(unit def:jibb)  (program-main-def:jibb defs.p.parsed)
  ?~  main-def  ~["program main definition is missing"]
  =/  parts  (program-main-parts:jibb u.main-def)
  ?~  parts  ~["program main parts are missing"]
  ?:  (program-main-closed:jibb u.parts defs.p.parsed values.checked ~ ~ u.graph.checked)
    ~["program kind was accepted without its source-backed prelude"]
  =/  program-scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %program values.iface.u.prepared)
  ?~  program-scheme  ~["synthetic program scheme is missing"]
  ?.  ?=(%fn -.typ.u.program-scheme)  ~["synthetic program value is not a gate"]
  =/  broken-values=ienv:jibb
    (skim values.iface.u.prepared |=(entry=[name=term scheme=ischeme:jibb] !=(%program name.entry)))
  =/  broken=ifile:jibb
    iface.u.prepared(values [[%program [[%fn sample.typ.u.program-scheme [%atom %ud]] vars.u.program-scheme]] broken-values])
  =/  malformed=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at island ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `broken)
  ?:  ?=(%& -.malformed)  ~["program result was not checked against the program mold"]
  =/  kind-error=@t  (crip "module kind needs unsupported inference: {(spud at)}")
  ?.  =(message.p.malformed kind-error)  ~["malformed program failed before the kind check"]
  =/  open=jfile-detailed-result:jibb
    (program-main-detailed at (snag 6 negatives) ~ u.prepared)
  ?:  ?=(%& -.open)  ~["open program message was accepted"]
  =/  other-values=ienv:jibb
    (skim values.checked |=(entry=[name=term scheme=ischeme:jibb] !=(%main name.entry)))
  =/  open-values=ienv:jibb  [[%main u.main(vars ~[0])] other-values]
  ?:  (program-main-closed:jibb u.parts defs.p.parsed open-values `iface.u.prepared ~ u.graph.checked)
    ~["generic main scheme passed the closure check"]
  =/  model=itype:jibb  [%face %count [%atom %ud]]
  ?.  =(u.init [[%fn [%atom %t] model] ~])  ~["init interface type differs"]
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
  ?:  ?=(%| -.imported)  ~["ordinary downstream program import was rejected"]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~["downstream imported initializer is missing"]
  ?.  =(u.use u.init)  ~["downstream imported initializer type differs"]
  ?.  =(7 (lent negatives))  ~["focused negative fixture count differs"]
  =/  cases=(list [label=@t at=path src=@t])
    :~  ['gate in model' at (snag 0 negatives)]
        ['gate in data' at (snag 1 negatives)]
        ['nonempty subs' at (snag 2 negatives)]
        ['mismatched model' at (snag 3 negatives)]
        ['arbitrary main' at (snag 4 negatives)]
        ['store path' /ui/stores/program-main/jibb island]
        ['program alias' at (snag 5 negatives)]
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
