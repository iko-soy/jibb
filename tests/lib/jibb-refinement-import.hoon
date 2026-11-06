/+  jibb
|%
++  test-imported-builder
  ^-  tang
  =/  owner=@t  '++ pack |= [initial=S updater=$-([A S] S)] ^- [init=S update=*] [initial updater]\0a'
  =/  src=@t  '/= dep /ui/builder\0a++ start 0\0a++ apply |= [a=@t s=@ud] s\0a++ built (pack.dep start apply)\0a'
  =/  at=path  /ui/consumer/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~[[/ui/builder/jibb owner]] ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"imported builder did not check" leaf+(trip message.p.checked)]
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb %built values.iface.p.checked)
  ?~  found  ~[leaf+"imported builder did not publish its result"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  shown  ~[leaf+"imported result did not realize"]
  =/  updates=(list itype:jibb)  (record-fields-named:jibb %update u.shown ~)
  ?.  ?=([[%refined [%fn *]] ~] updates)  ~[leaf+"imported builder lost checked gate evidence"]
  ~
--
