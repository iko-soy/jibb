/+  jibb
|%
++  test-nominal-origin
  ^-  tang
  =/  cases=(list itype:jibb)  ~[[%atom %t]]
  =/  original=itype:jibb  [%union cases `[/ui/a/jibb %choice] `'choice' ~]
  =/  alias=itype:jibb  [%union cases `[/ui/a/jibb %choice] `'renamed' ~]
  =/  other=itype:jibb  [%union cases `[/ui/b/jibb %choice] `'choice' ~]
  =/  unnamed=itype:jibb  [%union cases ~ ~ ~]
  =/  same=ifit:jibb  (itype-fit:jibb original alias ~ 0)
  ?.  ?=(%ok -.same)  ~[leaf+"same-origin alias rejected"]
  =/  distinct=ifit:jibb  (itype-fit:jibb original other ~ 0)
  ?.  ?=(%bad -.distinct)  ~[leaf+"distinct named origins were not rejected"]
  =/  reverse=ifit:jibb  (itype-fit:jibb other original ~ 0)
  ?.  ?=(%bad -.reverse)  ~[leaf+"reversed distinct origins were not rejected"]
  =/  unresolved=ifit:jibb  (itype-fit:jibb original unnamed ~ 0)
  ?.  ?=(%unknown -.unresolved)  ~[leaf+"an unnamed origin was treated as nominally distinct"]
  =/  unresolved-reverse=ifit:jibb  (itype-fit:jibb unnamed original ~ 0)
  ?.  ?=(%unknown -.unresolved-reverse)  ~[leaf+"reversed unnamed origin was treated as nominally distinct"]
  ~
--
