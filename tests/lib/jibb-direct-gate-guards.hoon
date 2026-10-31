::  Direct layout evidence must retain provenance and final face constraints.
/+  jibb
|%
++  direct-evidence-errors
  ^-  (list tape)
  =/  pre=@t  '++ apply |= [f=$-([A B] B) n=@t] f\0a'
  =/  dupe=@t  '++ apply |= [f=$-([A B] B) n=@t] f\0a++ apply |= [f=$-([A B] B) n=@t] f\0a'
  =/  root=@t  '++ target |= [a=@t b=@p] b\0a++ main (apply target "x")\0a'
  =/  parsed  (parse:jibb /tests/test/jibb root)
  ?>  ?=(%& -.parsed)
  =/  ds=(list def:jibb)  defs.p.parsed
  ?>  ?=(^ ds)
  ?>  ?=(^ t.ds)
  ?>  ?=(%value -.i.t.ds)
  =/  expr=expr:jibb  val.i.t.ds
  =?  expr  ?=(%group -.expr)  inner.expr
  =/  txt=itype:jibb  [%atom %t]
  =/  ship=itype:jibb  [%atom %p]
  =/  target=itype:jibb  [%fn [%cell [%face %a txt] [%face %b ship]] ship]
  =/  expected-fn=itype:jibb  [%fn [%cell [%var 0] [%var 1]] [%var 1]]
  =/  expected-sample=itype:jibb  [%cell [%face %f expected-fn] [%face %n txt]]
  =/  actual=itype:jibb  [%cell target txt]
  =/  scheme=ischeme:jibb  [[%fn expected-sample expected-fn] ~[0 1]]
  =/  changed=ischeme:jibb  [[%fn expected-sample ship] ~[0 1]]
  =/  iface=ifile:jibb  [~[[%apply scheme]] ~ /lib/jibb/prelude/jibb ~ ~ ~ `pre ~]
  =/  stale=ifile:jibb  iface(values ~[[%apply changed]])
  =/  dup=ifile:jibb  iface(source `dupe)
  =/  env=ienv:jibb  ~[[%target [target ~]]]
  =/  registry=(map term def:jibb)  (direct-checked-gates:jibb ds env)
  =/  evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `iface)
  ?>  ?=(^ evidence)
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(globals ~[%apply %target %main], prelude `iface, gate-defs registry, head-evidence evidence, next 10)
  =/  good=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st)
  =/  bad=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st(prelude `stale))
  =/  dupe-evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `dup)
  =/  head=(unit def:jibb)  (~(get by gates.u.evidence) %apply)
  ?>  ?=(^ head)
  =/  head-sample=(unit sample:jibb)  (direct-gate-sample:jibb u.head)
  ?>  ?=(^ head-sample)
  ?>  ?=(%cell -.u.head-sample)
  ?>  ?=(%call -.expr)
  =/  pos=ifit:jibb  (direct-positional-fit:jibb args.expr items.u.head-sample actual expected-sample env st ~ 10)
  =/  checks=(list @t)
  :~
    ?:(?=(%ok -.pos) 'positional-fit-ok' 'BAD-positional-fit')
    ?:(?=(^ good) 'original-evidence-usable' 'BAD-original-evidence')
    ?:  &(?=(~ bad) =(source.iface source.stale) =(at.iface at.stale) !=(values.iface values.stale))
      'changed-value-scheme-rejected'
    'BAD-stale-evidence'
    ?:(?=(~ dupe-evidence) 'duplicate-source-rejected' 'BAD-duplicate-source')
  ==

  ?:  =(checks ~['positional-fit-ok' 'original-evidence-usable' 'changed-value-scheme-rejected' 'duplicate-source-rejected'])  ~
  ~["direct-evidence-errors direct gate guard failed"]
++  late-face-errors
  ^-  (list tape)
  =/  pre=@t  '++ apply |= [first=[foo=A] second=A f=$-([C D] D)] f\0a'
  =/  dupe=@t  '++ apply |= [f=$-([A B] B) n=@t] f\0a++ apply |= [f=$-([A B] B) n=@t] f\0a'
  =/  root=@t  '++ target |= [a=@t b=@p] b\0a++ main (apply x y target)\0a'
  =/  parsed  (parse:jibb /tests/test/jibb root)
  ?>  ?=(%& -.parsed)
  =/  ds=(list def:jibb)  defs.p.parsed
  ?>  ?=(^ ds)
  ?>  ?=(^ t.ds)
  ?>  ?=(%value -.i.t.ds)
  =/  expr=expr:jibb  val.i.t.ds
  =?  expr  ?=(%group -.expr)  inner.expr
  =/  txt=itype:jibb  [%atom %t]
  =/  ship=itype:jibb  [%atom %p]
  =/  target=itype:jibb  [%fn [%cell [%face %a txt] [%face %b ship]] ship]
  =/  expected-fn=itype:jibb  [%fn [%cell [%var 1] [%var 2]] [%var 2]]
  =/  expected-sample=itype:jibb  [%cell [%face %first [%face %foo [%var 0]]] [%cell [%face %second [%var 0]] [%face %f expected-fn]]]
  =/  actual=itype:jibb  [%cell [%var 0] [%cell txt target]]
  =/  scheme=ischeme:jibb  [[%fn expected-sample expected-fn] ~[0 1]]
  =/  changed=ischeme:jibb  [[%fn expected-sample ship] ~[0 1]]
  =/  iface=ifile:jibb  [~[[%apply scheme]] ~ /lib/jibb/prelude/jibb ~ ~ ~ `pre ~]
  =/  stale=ifile:jibb  iface(values ~[[%apply changed]])
  =/  dup=ifile:jibb  iface(source `dupe)
  =/  env=ienv:jibb  ~[[%target [target ~]]]
  =/  registry=(map term def:jibb)  (direct-checked-gates:jibb ds env)
  =/  evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `iface)
  ?>  ?=(^ evidence)
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(globals ~[%apply %target %main], prelude `iface, gate-defs registry, head-evidence evidence, next 10)
  =/  good=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st)
  =/  bad=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st(prelude `stale))
  =/  dupe-evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `dup)
  =/  head=(unit def:jibb)  (~(get by gates.u.evidence) %apply)
  ?>  ?=(^ head)
  =/  head-sample=(unit sample:jibb)  (direct-gate-sample:jibb u.head)
  ?>  ?=(^ head-sample)
  ?>  ?=(%cell -.u.head-sample)
  ?>  ?=(%call -.expr)
  =/  pos=ifit:jibb  (direct-positional-fit:jibb args.expr items.u.head-sample actual expected-sample env st ~ 10)
  =/  checks=(list @t)
  :~
    ?:  ?=(%ok -.pos)
      ?:((itype-positional-slot-face-asym:jibb [%var 0] [%face %foo [%var 0]] sub.pos) 'LATE-FACE-ASYMMETRY' 'no-late-asymmetry')
    'no-positional-fit'
    ?:(?=(%ok -.pos) 'positional-fit-ok' 'BAD-positional-fit')
    ?:(?=(^ good) 'original-evidence-usable' 'late-face-rejected')
    ?:  &(?=(~ bad) =(source.iface source.stale) =(at.iface at.stale) !=(values.iface values.stale))
      'changed-value-scheme-rejected'
    'BAD-stale-evidence'
    ?:(?=(~ dupe-evidence) 'duplicate-source-rejected' 'BAD-duplicate-source')
  ==

  ?:  =(checks ~['LATE-FACE-ASYMMETRY' 'positional-fit-ok' 'late-face-rejected' 'changed-value-scheme-rejected' 'duplicate-source-rejected'])  ~
  ~["late-face-errors direct gate guard failed"]
++  symmetric-face-errors
  ^-  (list tape)
  =/  pre=@t  '++ apply |= [first=[foo=A] second=A f=$-([C D] D)] f\0a'
  =/  dupe=@t  '++ apply |= [f=$-([A B] B) n=@t] f\0a++ apply |= [f=$-([A B] B) n=@t] f\0a'
  =/  root=@t  '++ target |= [a=@t b=@p] b\0a++ main (apply x y target)\0a'
  =/  parsed  (parse:jibb /tests/test/jibb root)
  ?>  ?=(%& -.parsed)
  =/  ds=(list def:jibb)  defs.p.parsed
  ?>  ?=(^ ds)
  ?>  ?=(^ t.ds)
  ?>  ?=(%value -.i.t.ds)
  =/  expr=expr:jibb  val.i.t.ds
  =?  expr  ?=(%group -.expr)  inner.expr
  =/  txt=itype:jibb  [%atom %t]
  =/  ship=itype:jibb  [%atom %p]
  =/  target=itype:jibb  [%fn [%cell [%face %a txt] [%face %b ship]] ship]
  =/  expected-fn=itype:jibb  [%fn [%cell [%var 1] [%var 2]] [%var 2]]
  =/  expected-sample=itype:jibb  [%cell [%face %first [%face %foo [%var 0]]] [%cell [%face %second [%var 0]] [%face %f expected-fn]]]
  =/  actual=itype:jibb  [%cell [%face %foo [%var 0]] [%cell txt target]]
  =/  scheme=ischeme:jibb  [[%fn expected-sample expected-fn] ~[0 1]]
  =/  changed=ischeme:jibb  [[%fn expected-sample ship] ~[0 1]]
  =/  iface=ifile:jibb  [~[[%apply scheme]] ~ /lib/jibb/prelude/jibb ~ ~ ~ `pre ~]
  =/  stale=ifile:jibb  iface(values ~[[%apply changed]])
  =/  dup=ifile:jibb  iface(source `dupe)
  =/  env=ienv:jibb  ~[[%target [target ~]]]
  =/  registry=(map term def:jibb)  (direct-checked-gates:jibb ds env)
  =/  evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `iface)
  ?>  ?=(^ evidence)
  =/  st=istate:jibb  *istate:jibb
  =.  st  st(globals ~[%apply %target %main], prelude `iface, gate-defs registry, head-evidence evidence, next 10)
  =/  good=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st)
  =/  bad=(unit ifit:jibb)  (direct-gate-call-fit:jibb expr actual expected-sample env st(prelude `stale))
  =/  dupe-evidence=(unit igate-prelude-evidence:jibb)  (direct-prelude-evidence:jibb ds `dup)
  =/  head=(unit def:jibb)  (~(get by gates.u.evidence) %apply)
  ?>  ?=(^ head)
  =/  head-sample=(unit sample:jibb)  (direct-gate-sample:jibb u.head)
  ?>  ?=(^ head-sample)
  ?>  ?=(%cell -.u.head-sample)
  ?>  ?=(%call -.expr)
  =/  pos=ifit:jibb  (direct-positional-fit:jibb args.expr items.u.head-sample actual expected-sample env st ~ 10)
  =/  checks=(list @t)
  :~
    ?:  ?=(%ok -.pos)
      ?:((itype-positional-slot-face-asym:jibb [%face %foo [%var 0]] [%face %foo [%var 0]] sub.pos) 'LATE-FACE-ASYMMETRY' 'symmetric-after-later-binding')
    'no-positional-fit'
    ?:(?=(%ok -.pos) 'positional-fit-ok' 'BAD-positional-fit')
    ?:(?=(^ good) 'original-evidence-usable' 'BAD-original-evidence')
    ?:  &(?=(~ bad) =(source.iface source.stale) =(at.iface at.stale) !=(values.iface values.stale))
      'changed-value-scheme-rejected'
    'BAD-stale-evidence'
    ?:(?=(~ dupe-evidence) 'duplicate-source-rejected' 'BAD-duplicate-source')
  ==

  ?:  =(checks ~['symmetric-after-later-binding' 'positional-fit-ok' 'original-evidence-usable' 'changed-value-scheme-rejected' 'duplicate-source-rejected'])  ~
  ~["symmetric-face-errors direct gate guard failed"]
++  direct-gate-guard-errors
  ^-  (list tape)
  (weld direct-evidence-errors (weld late-face-errors symmetric-face-errors))
++  test-direct-gate-guards
  ^-  tang
  (turn direct-gate-guard-errors |=(reason=tape leaf+reason))
--
