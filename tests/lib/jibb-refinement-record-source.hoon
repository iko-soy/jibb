/+  jibb
|%
++  test-distinct-nested-values
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ known ^- * gate\0a++ atom ^- * ~zod\0a++ second |= [x=A y=A] y\0a++ output (second [val=known marker="first"] [val=atom marker="second"])\0a'
  =/  at=path  /tests/refinement-nested/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"distinct nested values were rejected" leaf+(trip message.p.checked)]
  =/  out=(unit ischeme:jibb)  (ienv-lookup:jibb %output values.iface.p.checked)
  ?~  out  ~[leaf+"output missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.out)
  ?~  typ  ~[leaf+"output did not realize"]
  =/  vals=(list itype:jibb)  (record-fields-named:jibb %val u.typ ~)
  ?.  ?=([* ~] vals)  ~[leaf+"output field missing" leaf+(show-itype:jibb u.typ ~)]
  ?:  ?=([[%refined [%fn *]] ~] vals)  ~[leaf+"atom inherited a stale gate proof through its record"]
  ~
++  test-unknown-nested-value
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ known ^- * gate\0a++ opaque |= x=* x\0a++ second |= [x=A y=A] y\0a++ output (second [val=known marker="first"] [val=(opaque ~zod) marker="second"])\0a'
  =/  at=path  /tests/refinement-nested-unknown/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"unknown nested value was rejected" leaf+(trip message.p.checked)]
  =/  out=(unit ischeme:jibb)  (ienv-lookup:jibb %output values.iface.p.checked)
  ?~  out  ~[leaf+"output missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.out)
  ?~  typ  ~[leaf+"output did not realize"]
  =/  vals=(list itype:jibb)  (record-fields-named:jibb %val u.typ ~)
  ?.  ?=([* ~] vals)  ~[leaf+"output field missing" leaf+(show-itype:jibb u.typ ~)]
  ?:  ?=([[%refined [%fn *]] ~] vals)  ~[leaf+"unknown nested value inherited a stale gate proof"]
  ~
--
