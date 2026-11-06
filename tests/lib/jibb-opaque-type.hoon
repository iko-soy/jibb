/+  jibb
|%
++  test-opaque-fit
  ^-  tang
  =/  origin=[at=path name=term]  [/lib/jibb/primitives/jibb %sealed]
  =/  other=[at=path name=term]  [/lib/jibb/other/jibb %sealed]
  =/  concrete=itype:jibb  [%opaque origin `'%element' ~[[%atom %t]] [%atom %t]]
  =/  variable=itype:jibb  [%opaque origin `'%element' ~[[%var 0]] [%var 0]]
  =/  foreign=itype:jibb  [%opaque other `'%element' ~[[%atom %t]] [%atom %t]]
  =/  yes=ifit:jibb  (itype-fit:jibb concrete variable ~ 1)
  ?.  ?=(%ok -.yes)  ~[leaf+"matching seal did not fit"]
  ?.  =((itype-walk:jibb [%var 0] sub.yes) [%atom %t])  ~[leaf+"seal payload did not bind the type argument"]
  =/  wrong=itype:jibb  [%opaque origin `'%element' ~[[%atom %ud]] [%atom %ud]]
  =/  wrong-fit=ifit:jibb  (itype-fit:jibb concrete wrong ~ 1)
  ?:  ?=(%ok -.wrong-fit)  ~[leaf+"incompatible seal payloads fitted"]
  =/  reverse-fit=ifit:jibb  (itype-fit:jibb wrong concrete ~ 1)
  ?:  ?=(%ok -.reverse-fit)  ~[leaf+"reverse incompatible seal payloads fitted"]
  =/  foreign-fit=ifit:jibb  (itype-fit:jibb concrete foreign ~ 1)
  ?:  ?=(%ok -.foreign-fit)  ~[leaf+"different seal origins fitted"]
  =/  raw-fit=ifit:jibb  (itype-fit:jibb [%cell [%atom %ud] [%atom %t]] concrete ~ 1)
  ?:  ?=(%ok -.raw-fit)  ~[leaf+"a raw cell constructed a seal"]
  =/  noun-fit=ifit:jibb  (itype-fit:jibb concrete [%noun ~] ~ 1)
  ?.  ?=(%ok -.noun-fit)  ~[leaf+"a sealed value did not fit a noun"]
  ~
--
