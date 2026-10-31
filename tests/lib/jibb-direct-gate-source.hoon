::  Exercise direct-source gate layouts through a synthetic program scaffold.
/+  jibb
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
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
  ::  This element is test-only; it does not prescribe a runtime shape.
  =/  extra=@t  '\0a+$ element |$ [M] [%node item=M]\0a+$ program |$ [D X M]\0a  [init=$-(D X) update=$-([M X] [X (list (cmd M))]) view=$-(X (element M)) subs=$-(X (list (sub M)))]\0a++ program |= [init=$-(D X) update=$-([M X] [X (list (cmd M))]) view=$-(X (element M)) subs=$-(X (list (sub M)))]\0a  ^- (program D X M) [init update view subs]\0a++ choose-layout |= [f=$-([A B] C) value=[A B]] (f value)\0a++ higher |= [f=$-([@t [x=@t y=@p]] @t) marker=?] f\0a++ higher-generic |= [f=$-([@t X] X) state=X] state\0a'
  (prepare-prelude-with-internal:jibb (cat 3 prelude extra) internal)
++  direct-gate-source-output
  |=  [src=@t prepared=(unit iprelude:jibb)]
  ^-  @t
  (golden-types-with-prepared-prelude:jibb /tests/sub/client/jibb src ~ ~ ~ prepared)
++  direct-gate-projection-errors
  |=  prepared=(unit iprelude:jibb)
  ^-  (list tape)
  ?~  prepared  ~["synthetic prelude did not prepare"]
  =/  src=@t  '+$ message\0a  %start\0a  %stop\0a+$ record [count=@ud label=@t]\0a++ init-record |= input=@t ^- record [count=0 label=input]\0a++ view-record |= state=record ^- (element message) [%node %start]\0a++ subs-record |= state=record ^- (list (sub message)) ~\0a++ update-proj-good |= [msg=message state=record]\0a  ^- [record (list (cmd message))]\0a    [(proj [count=0 label="projected" extra=%.y]) ~]\0a++ program-projection (program init-record update-proj-good view-record subs-record)\0a'
  =/  out=jfile-result:jibb  (infer-jibb-file:jibb /tests/direct/client/jibb src ~ ~ ~ ~[/tests/direct/client/jibb] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.out)  ~["projection-bearing module did not infer"]
  =/  defs=(list iwidth-definition:jibb)  (skim elaborations.iface.p.out |=(d=iwidth-definition:jibb =(%update-proj-good name.d)))
  ?~  defs  ~["projection-bearing update lost its elaboration"]
  ?~  projections.i.defs  ~["projection action is missing"]
  ?:  !=(1 (lent projections.i.defs))  ~["unexpected projection action count"]
  ?.  =(steps.i.projections.i.defs ~[[%count 2] [%label 6]])  ~["projection axes changed"]
  ~
++  test-direct-gate-source
  ^-  tang
  ?~  source  ~[leaf+"direct gate source is missing"]
  ?~  expected  ~[leaf+"direct gate expected output is missing"]
  =/  prepared=(unit iprelude:jibb)  (direct-gate-prepared real-prelude real-internal)
  =/  errors=(list tape)  (direct-gate-projection-errors prepared)
  ?^  errors  (turn errors |=(reason=tape leaf+reason))
  =/  got=@t  (direct-gate-source-output (text source) prepared)
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"direct gate source output differs from its golden"]
  ~
--
