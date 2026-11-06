::  A literal attribute list may not repeat an attribute, regardless of
::  which element helper consumes it. Test the public full checker.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  el-source  %txt  /tests/type-repeated-attributes/el-source/txt
/*  el-expected  %txt  /tests/type-repeated-attributes/el-expected/txt
/*  column-source  %txt  /tests/type-repeated-attributes/column-source/txt
/*  column-expected  %txt  /tests/type-repeated-attributes/column-expected/txt
/*  alias-source  %txt  /tests/type-repeated-attributes/alias-source/txt
/*  alias-expected  %txt  /tests/type-repeated-attributes/alias-expected/txt
/*  tuple-source  %txt  /tests/type-repeated-attributes/tuple-source/txt
/*  tuple-expected  %txt  /tests/type-repeated-attributes/tuple-expected/txt
/*  deferred-source  %txt  /tests/type-repeated-attributes/deferred-source/txt
/*  deferred-expected  %txt  /tests/type-repeated-attributes/deferred-expected/txt
/*  forward-source  %txt  /tests/type-repeated-attributes/forward-source/txt
/*  forward-expected  %txt  /tests/type-repeated-attributes/forward-expected/txt
/*  page-source  %txt  /tests/type-repeated-attributes/page-source/txt
/*  local-source  %txt  /tests/type-repeated-attributes/local-source/txt
/*  local-expected  %txt  /tests/type-repeated-attributes/local-expected/txt
|%
++  check-duplicate
  |=  [label=tape source=wain expected=wain prepared=iprelude:jibb]
  ^-  tang
  =/  at=path  /ui/probe/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at (of-wain:format source) ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
  ?:  ?=(%& -.result)  ~[leaf+(weld label ": repeated attribute was accepted")]
  ?.  =((of-wain:format expected) message.p.result)
    ~[leaf+(weld label ": diagnostic or sites differ") leaf+(trip message.p.result)]
  ~
++  test-repeated-attributes
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed to prepare"]
  (zing `(list tang)`~[(check-duplicate "el" el-source el-expected u.prepared) (check-duplicate "column" column-source column-expected u.prepared) (check-duplicate "alias" alias-source alias-expected u.prepared) (check-duplicate "tuple" tuple-source tuple-expected u.prepared) (check-duplicate "deferred" deferred-source deferred-expected u.prepared) (check-duplicate "forward" forward-source forward-expected u.prepared) (check-duplicate "static page" page-source deferred-expected u.prepared) (check-duplicate "local" local-source local-expected u.prepared)])
++  test-repeated-attributes-control
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed to prepare"]
  =/  at=path  /ui/probe/jibb
  =/  good=@t  '++ v (el ~[pad+%s1 width+[%fill 1]] (text "x"))'
  =/  control=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at good ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.control)  ~[leaf+"distinct attributes were rejected" leaf+(trip message.p.control)]
  =/  custom=@t
    (of-wain:format ~['+$ custom [%pad value=@tas]' '++ v ^- (list custom) ~[pad+%s1 pad+%s2]'])
  =/  not-attr=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at custom ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.not-attr)  ~[leaf+"unrelated named union was rejected" leaf+(trip message.p.not-attr)]
  =/  later-custom=@t
    (of-wain:format ~['+$ custom [%pad value=@tas]' '++ values ~[pad+%s1 pad+%s2]' '++ use ^- (list custom) values'])
  =/  not-attr-later=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at later-custom ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.not-attr-later)  ~[leaf+"later custom-union context was rejected" leaf+(trip message.p.not-attr-later)]
  ~
++  check-core-duplicate
  |=  [label=tape source=wain expected-owner=term prepared=iprelude:jibb]
  ^-  tang
  =/  at=path  /ui/probe/jibb
  =/  parsed  (parse:jibb at (of-wain:format source))
  ?:  ?=(%| -.parsed)  ~[leaf+(weld label ": source failed to parse")]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  molds=imolds:jibb  (collect-simple-molds:jibb ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape:jibb] name.m))
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(molds molds, globals (weld values.prepared (global-value-names:jibb ds)), top-molds top, at at, prelude `iface.prepared, jrec-fuel 256, globals-imports &)
  =/  checked=icore-output:jibb  (icore-check:jibb ds state)
  ?~  error.checked  ~[leaf+(weld label ": shared checker did not report the duplicate")]
  ?.  =(owner.u.error.checked expected-owner)  ~[leaf+(weld label ": shared checker reported the wrong definition")]
  ?.  =(msg.diag.u.error.checked "attribute `pad` is repeated")
    ~[leaf+(weld label ": shared checker reported the wrong error") leaf+msg.diag.u.error.checked]
  ~
++  test-attribute-shared-core
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed to prepare"]
  (zing `(list tang)`~[(check-core-duplicate "direct" el-source %v u.prepared) (check-core-duplicate "deferred" deferred-source %attrs u.prepared) (check-core-duplicate "local" local-source %attrs u.prepared)])

--
