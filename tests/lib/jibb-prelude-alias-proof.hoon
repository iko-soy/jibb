/+  jibb
|%
++  test-conservative-alias-diagnostics
  ^-  tang
  =/  source=@t  '+$ alias |$ [A B] (alias A)\0a'
  =/  iface=ifile:jibb  *ifile:jibb
  =.  at.iface  /lib/jibb/prelude/jibb
  =.  source.iface  `source
  =/  state=istate:jibb  *istate:jibb
  =.  prelude.state  `iface
  =/  site=span:jibb  [[1 1] [1 8]]
  =/  one=shape:jibb  [%apply site ~[%alias] ~[[%aura site %t]]]
  ?^  (prelude-alias-diagnostic:jibb one state)
    ~[leaf+"an arity mismatch was mistaken for an alias cycle"]
  =/  two=shape:jibb  [%apply site ~[%alias] ~[[%aura site %t] [%aura site %p]]]
  ?^  (prelude-alias-diagnostic:jibb two state)
    ~[leaf+"a recursive call with wrong arity was mistaken for a cycle"]
  ?^  (prelude-source-alias-errors:jibb source *ifile:jibb)
    ~[leaf+"an unused wrong-arity alias was mistaken for a cycle"]
  =/  productive=@t  '+$ node |$ [A]\0a  ~\0a  [value=A next=(node A)]\0a'
  ?^  (prelude-source-alias-errors:jibb productive *ifile:jibb)
    ~[leaf+"a productive recursive mold was mistaken for an alias cycle"]
  =/  no-source=ifile:jibb  iface
  =.  source.no-source  ~
  =.  prelude.state  `no-source
  ?^  (prelude-alias-diagnostic:jibb one state)
    ~[leaf+"missing prelude source invented an alias diagnostic"]
  ~
--
