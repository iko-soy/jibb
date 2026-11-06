/+  jibb
|%
++  test-meet-idempotence
  ^-  tang
  =/  gate=itype:jibb  [%fn [%atom %t] [%atom %t]]
  =/  atom=itype:jibb  [%atom %p]
  =/  choice=itype:jibb  [%refined [%union ~[gate atom] ~ ~ ~]]
  =/  one=itype:jibb  [%refined gate]
  =/  again=(unit itype:jibb)  (itype-evidence-meet:jibb one choice ~ 256)
  ?.  =(again `choice)  ~[leaf+"repeated proof evidence changed the joined result"]
  =/  reverse=(unit itype:jibb)  (itype-evidence-meet:jibb choice one ~ 256)
  ?.  =(reverse `choice)  ~[leaf+"reversing a proof join lost an alternative"]
  =/  unknown=(unit itype:jibb)  (itype-evidence-meet:jibb [%noun ~] choice ~ 256)
  ?.  =(unknown `[%noun ~])  ~[leaf+"unknown value retained private proof"]
  ~
++  test-source-evidence-isolated
  ^-  tang
  =/  src=@t  '++ gate |= x=@t x\0a++ known ^- * gate\0a++ atom ^- * ~zod\0a++ first [val=known marker="first"]\0a++ other [val=atom marker="second"]\0a++ second |= [x=A y=A] y\0a++ output (second first other)\0a'
  =/  at=path  /tests/evidence-source-isolated/jibb
  =/  checked=jfile-detailed-result:jibb  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"independent records were rejected" leaf+(trip message.p.checked)]
  =/  first=(unit ischeme:jibb)  (ienv-lookup:jibb %first values.iface.p.checked)
  =/  output=(unit ischeme:jibb)  (ienv-lookup:jibb %output values.iface.p.checked)
  ?~  first  ~[leaf+"first record omitted"]
  ?~  output  ~[leaf+"result record omitted"]
  =/  ft=(unit itype:jibb)  (scheme-display-type:jibb u.first)
  =/  ot=(unit itype:jibb)  (scheme-display-type:jibb u.output)
  ?~  ft  ~[leaf+"first record did not realize"]
  ?~  ot  ~[leaf+"result record did not realize"]
  =/  fp=(list itype:jibb)  (record-fields-named:jibb %val u.ft ~)
  =/  op=(list itype:jibb)  (record-fields-named:jibb %val u.ot ~)
  ?.  ?=([[%refined [%fn *]] ~] fp)  ~[leaf+"joining separate values changed the first record proof"]
  ?:  ?=([[%refined [%fn *]] ~] op)  ~[leaf+"second record inherited the first record proof"]
  ~
--
