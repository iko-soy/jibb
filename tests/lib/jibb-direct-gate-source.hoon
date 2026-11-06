::  Check every original gate-layout example through the common module checker.
::  Dependency slices preserve original lines, so each error has its own site.
/+  jibb, jibb-prelude-fixture
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %txt  /tests/type-direct-gate/source/txt
/*  expected  %txt  /tests/type-direct-gate/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  direct-gate-prepared
  |=  [prelude=@t internal=@t]
  ^-  (unit iprelude:jibb)
  ::  Program and element come from the real prelude; only layout helpers are synthetic.
  =/  extra=@t  '\0a++ choose-layout |= [f=$-([A B] C) value=[A B]] (f value)\0a++ higher |= [f=$-([@t [x=@t y=@p]] @t) marker=?] f\0a++ higher-generic |= [f=$-([@t X] X) state=X] state\0a'
  (prepare-groups:jibb-prelude-fixture (cat 3 prelude extra) internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
++  direct-gate-source-output
  |=  [src=@t prepared=(unit iprelude:jibb)]
  ^-  @t
  (golden-types-with-prepared-prelude:jibb /tests/sub/client/jibb src ~ ~ ~ prepared)
++  direct-gate-projection-errors
  |=  prepared=(unit iprelude:jibb)
  ^-  (list tape)
  ?~  prepared  ~["synthetic prelude did not prepare"]
  =/  src=@t  '+$ message\0a  %start\0a  %stop\0a+$ record [count=@ud label=@t]\0a++ init-record |= input=@t ^- record [count=0 label=input]\0a++ view-record |= state=record ^- (element message) (text "view")\0a++ subs-record |= state=record ^- (list (sub message)) ~\0a++ update-proj-good |= [msg=message state=record]\0a  ^- [record (list (cmd message))]\0a    [(proj [count=0 label="projected" extra=%.y]) ~]\0a++ program-projection (program init-record update-proj-good view-record subs-record)\0a'
  =/  out=jfile-result:jibb  (infer-jibb-file:jibb /tests/direct/client/jibb src ~ ~ ~ ~[/tests/direct/client/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.out)  ~["projection-bearing module did not infer"]
  =/  defs=(list iwidth-definition:jibb)  (skim elaborations.iface.p.out |=(d=iwidth-definition:jibb =(%update-proj-good name.d)))
  ?~  defs  ~["projection-bearing update lost its elaboration"]
  ?~  projections.i.defs  ~["projection action is missing"]
  ?:  !=(1 (lent projections.i.defs))  ~["unexpected projection action count"]
  ?.  =(steps.i.projections.i.defs ~[[%count 2] [%label 6]])  ~["projection axes changed"]
  ~
++  selected-source
  |=  [lines=wain ds=(list def:jibb) selected=ivisited:jibb]
  ^-  @t
  =/  row=@ud  1
  =/  active=?  &
  =/  out=wain  ~
  |-
  ?~  lines  (text (flop out))
  =/  next=(unit [keep=? rest=(list def:jibb)])
    ?~  ds  ~
    ?.  =(row line.beg.at.i.ds)  ~
    `[|(?=(%mold -.i.ds) ?=(^ (~(get by selected) name.i.ds))) t.ds]
  =?  active  ?=(^ next)  keep.u.next
  =?  ds  ?=(^ next)  rest.u.next
  $(lines t.lines, row +(row), out [?:(active i.lines '') out])
++  layout-reports
  |=  [src=wain prepared=iprelude:jibb]
  ^-  @t
  =/  at=path  /tests/sub/client/jibb
  =/  parsed  (parse:jibb at (text src))
  ?:  ?=(%| -.parsed)  'layout fixture did not parse'
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  names=(list term)  (global-value-names:jibb ds)
  =/  graph=iadj:jibb  (graph-make-forward:jibb ds (graph-nameset:jibb names ~) ~)
  =/  entries=(list @t)
    %+  turn  ds
    |=  d=def:jibb
    ::  Keep every written mold. The selected gate and its dependencies
    ::  are checked together, with all other source lines left blank.
    =/  closure=icresult:jibb  (graph-collect:jibb ~[name.d] ~ ~ graph)
    =/  selected=ivisited:jibb  seen.closure
    ::  This example intentionally shadows the independent update gate.
    =?  selected  =(%local-shadow name.d)  (~(put by selected) %update &)
    =/  isolated=@t  (selected-source src ds selected)
    =/  checked=jfile-result:jibb
      (infer-jibb-file:jibb at isolated ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
    ?:  ?=(%| -.checked)  p.checked
    =/  line=(unit (list @t))  (full-report-lines:jibb ~[d] iface.p.checked isolated)
    ?~  line  'checked layout definition has no printable type'
    (of-wain:format u.line)
  (of-wain:format entries)
++  report
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (direct-gate-prepared real-prelude real-internal)
  ?~  prepared  'layout prelude did not prepare'
  (layout-reports source u.prepared)
++  test-direct-gate-source
  ^-  tang
  ?~  source  ~[leaf+"direct gate source is missing"]
  ?~  expected  ~[leaf+"direct gate expected output is missing"]
  =/  prepared=(unit iprelude:jibb)  (direct-gate-prepared real-prelude real-internal)
  =/  errors=(list tape)  (direct-gate-projection-errors prepared)
  ?^  errors  (turn errors |=(reason=tape leaf+reason))
  ?~  prepared  ~[leaf+"layout prelude did not prepare"]
  =/  got=@t  (layout-reports source u.prepared)
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"direct gate source output differs from its golden"]
  ~
--
