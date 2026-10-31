::  Bounded closed-cell branch context; no runtime or island claim.
/+  jibb
/*  public    %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  good      %txt   /tests/type-cell-branch/good/txt
/*  bad       %txt   /tests/type-cell-branch/bad/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-cell-branch
  ^-  tang
  ?~  good  ~[leaf+"cell branch good source missing"]
  ?~  bad  ~[leaf+"cell branch bad source missing"]
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prep  ~[leaf+"cell branch prelude unavailable"]
  =/  a  (parse:jibb /tests/branch/jibb (text good))
  =/  b  (parse:jibb /tests/branch/jibb (text bad))
  ?:  |(?=(%| -.a) ?=(%| -.b))  ~[leaf+"cell branch source parse failed"]
  =/  ad=(list def:jibb)  defs.p.a
  =/  bd=(list def:jibb)  defs.p.b
  ?.  &(?=([* ~] ad) ?=([* ~] bd) ?=(%value -.i.ad) ?=(%value -.i.bd))
    ~[leaf+"cell branch declarations unavailable"]
  =/  unit-scheme=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit iface.u.prep)
  ?~  unit-scheme  ~[leaf+"cell branch unit unavailable"]
  =/  computed=(unit itype:jibb)  (template-apply:jibb u.unit-scheme ~[[%atom %t]])
  ?~  computed  ~[leaf+"cell branch unit instantiation failed"]
  =/  expected=itype:jibb  [%cell [%atom %t] u.computed]
  =/  env=ienv:jibb  ~[[%flag [[%flag ~] ~]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(prelude `iface.u.prep, jrec-fuel 256)
  =/  original=iresult:jibb  (infer-fragment:jibb val.i.bd env state)
  =/  failed=iresult:jibb  (infer-closed-cell-branch:jibb val.i.bd expected env state (span-of:jibb val.i.bd))
  =/  success=iresult:jibb  (infer-closed-cell-branch:jibb val.i.ad expected env state (span-of:jibb val.i.ad))
  =/  hidden=isub:jibb  ~[[55 [%face %x [%atom %t]]]]
  ?.  (closed-cell-branch-eligible:jibb val.i.bd expected ~)  ~[leaf+"negative branch is not eligible"]
  ?.  ?=(%| -.original)  ~[leaf+"original negative branch unexpectedly inferred"]
  ?.  =(original failed)  ~[leaf+"failed retry changed the original result"]
  ?.  ?=(%& -.success)  ~[leaf+"valid closed branch did not infer"]
  ?:  (closed-cell-branch-eligible:jibb val.i.ad expected hidden)  ~[leaf+"structural substitution accepted"]
  =/  atom=expr:jibb  *expr:jibb
  =/  nodes=(list expr:jibb)  (reap 512 atom)
  ?.  (closed-cell-retry-safe:jibb nodes 512)  ~[leaf+"exact source budget rejected"]
  ?:  (closed-cell-retry-safe:jibb [atom nodes] 512)  ~[leaf+"source budget exceeded"]
  =/  binding=ibinding:jibb  [55 [%atom %t]]
  =/  subs=isub:jibb  (reap 512 binding)
  ?.  (closed-cell-sub-safe:jibb subs 512)  ~[leaf+"exact substitution budget rejected"]
  ?:  (closed-cell-sub-safe:jibb [binding subs] 512)  ~[leaf+"substitution budget exceeded"]
  =/  nested=expr:jibb  [%branch *span:jibb atom ~]
  ?:  (closed-cell-retry-safe:jibb ~[nested] 512)  ~[leaf+"recursive retry was not excluded"]
  ~
--
