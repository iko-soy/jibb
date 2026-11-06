/+  jibb
|%
++  test-seal-tag-deferral
  ^-  tang
  =/  hit=lit:jibb  [%term %tas %hit '%hit']
  =/  typo=lit:jibb  [%term %tas %typo '%typo']
  =/  expected=itype:jibb  [%union ~[[%const hit]] `[/tests/tags/jibb %msg] ~ ~]
  =/  open=itype:jibb  [%tag 0 typo |]
  =/  forward=ifit:jibb  (itype-opaque-fit-args:jibb ~[open] ~[expected] ~ 1)
  ?.  ?=(%unknown -.forward)  ~[leaf+"open mismatched tag did not remain deferred"]
  =/  reverse=ifit:jibb  (itype-opaque-fit-args:jibb ~[expected] ~[open] ~ 1)
  ?.  ?=(%unknown -.reverse)  ~[leaf+"reverse open mismatched tag did not remain deferred"]
  =/  closed=ifit:jibb  (itype-opaque-fit-args:jibb ~[[%const typo]] ~[expected] ~ 1)
  ?.  ?=(%bad -.closed)  ~[leaf+"closed mismatched seal argument was not rejected"]
  =/  good=ifit:jibb  (itype-opaque-fit-args:jibb ~[[%tag 0 hit |]] ~[expected] ~ 1)
  ?.  ?=(%ok -.good)  ~[leaf+"matching tag did not acquire its union context"]
  ~
--
