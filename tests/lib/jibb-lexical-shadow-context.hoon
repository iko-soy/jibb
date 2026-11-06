/+  jibb
|%
++  test-without-source
  ^-  tang
  =/  state=istate:jibb  *istate:jibb
  =/  site=span:jibb  [[1 1] [1 2]]
  ?^  (shadow-binding-context:jibb site %local state)
    ~[leaf+"missing source invented an earlier local binding"]
  ?^  (shadow-binding-context:jibb site %pattern state)
    ~[leaf+"missing source invented an earlier pattern binding"]
  =/  pending=iresult:jibb  (unknown-value-result:jibb %later site state(globals ~[%later]))
  ?.  ?=(%| -.pending)  ~[leaf+"a pending declaration was accepted"]
  ?.  =(msg.p.pending "name is not available to partial inference")
    ~[leaf+"a pending declaration was reported as an unknown name"]
  ?.  ?=(~ sites.p.pending)  ~[leaf+"a pending declaration was made definite"]
  ~
--
