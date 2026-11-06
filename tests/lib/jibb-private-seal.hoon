/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  test-private-seal-interface
  ^-  tang
  =/  primitive=ifile:jibb  private-primitive-interface:jibb
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %opaque primitive)
  ?~  mold  ~[leaf+"private opaque mold missing"]
  =/  gate=(unit ischeme:jibb)  (ienv-lookup:jibb %raw-seal values.primitive)
  ?~  gate  ~[leaf+"private seal gate missing"]
  =/  applied=(unit itype:jibb)  (template-apply:jibb u.mold ~[[%atom %t]])
  ?~  applied  ~[leaf+"private opaque mold did not instantiate"]
  ?.  ?=(%opaque -.u.applied)  ~[leaf+"seal type missing"]
  ?.  =(origin.u.applied [/lib/jibb/primitives/jibb %seal])  ~[leaf+"seal origin was lost"]
  ?.  =(body.u.applied [%atom %t])  ~[leaf+"seal payload was lost"]
  =/  internal-iface=(unit ifile:jibb)  (infer-private-internal:jibb internal prelude)
  ?~  internal-iface  ~[leaf+"private source seal did not check"]
  ?~  (find-jibb-mold:jibb %opaque u.internal-iface)  ~[leaf+"private source mold missing"]
  ?~  (ienv-lookup:jibb %seal values.u.internal-iface)  ~[leaf+"private source gate missing"]
  ~
--
