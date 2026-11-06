/+  jibb
|%
++  test-distinct-nested-values
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ known ^- * gate\0a++ atom ^- * ~zod\0a++ second |= [x=A y=A] y\0a++ output (second [val=known] [val=atom])\0a'
  =/  at=path  /tests/refinement-nested/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"distinct nested values were rejected" leaf+(trip message.p.checked)]
  =/  out=(unit ischeme:jibb)  (ienv-lookup:jibb %output values.iface.p.checked)
  ?~  out  ~[leaf+"output missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.out)
  ?~  typ  ~[leaf+"output did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "*")  ~[leaf+"a generic capital retained the outer val face" leaf+(show-itype:jibb u.typ ~)]
  ?:  ?=([%refined [%fn *]] u.typ)  ~[leaf+"atom inherited a stale gate proof"]
  ~
++  test-unknown-nested-value
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ known ^- * gate\0a++ opaque |= x=* x\0a++ second |= [x=A y=A] y\0a++ output (second [val=known] [val=(opaque ~zod)])\0a'
  =/  at=path  /tests/refinement-nested-unknown/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"unknown nested value was rejected" leaf+(trip message.p.checked)]
  =/  out=(unit ischeme:jibb)  (ienv-lookup:jibb %output values.iface.p.checked)
  ?~  out  ~[leaf+"output missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.out)
  ?~  typ  ~[leaf+"output did not realize"]
  ?.  =((show-itype:jibb u.typ ~) "*")  ~[leaf+"a generic capital retained the outer val face" leaf+(show-itype:jibb u.typ ~)]
  ?:  ?=([%refined [%fn *]] u.typ)  ~[leaf+"unknown value inherited a stale gate proof"]
  ~
--
