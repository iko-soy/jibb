/+  jibb
|%
++  test-branch
  ^-  tang
  =/  src=@t  '++ update |= [a=@t s=@ud] s\0a++ other |= [a=@t s=@ud] s\0a++ choice |= x=?\0a  ?- x\0a    %.y ^- * update\0a    %.n ^- * other\0a++ result (choice %.y)\0a++ init ^- @ud 0\0a++ main ^- [init=@ud update=*] [init (choice %.y)]\0a'
  =/  at=path  /tests/refinement/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"branch source did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(globals (global-value-names:jibb ds), at at, in-mold |, jrec-fuel 256)
  =/  checked=icore-output:jibb  (icore-check:jibb ds state)
  ?~  result.checked
    ?~  error.checked  ~[leaf+"branch core declined without a reason"]
    ~[leaf+(trip owner.u.error.checked) leaf+msg.diag.u.error.checked]
  =/  choice=(unit ischeme:jibb)  (ienv-lookup:jibb %choice env.u.result.checked)
  ?~  choice  ~[leaf+"choice not published"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.choice)
  ?~  shown  ~[leaf+"choice did not realize"]
  ?.  ?=([%fn * [%refined [%fn *]]] u.shown)  ~[leaf+"choice lost checked branch evidence"]
  =/  result=(unit ischeme:jibb)  (ienv-lookup:jibb %result env.u.result.checked)
  ?~  result  ~[leaf+"result not published"]
  =/  got=(unit itype:jibb)  (scheme-display-type:jibb u.result)
  ?~  got  ~[leaf+"result did not realize"]
  ?.  ?=([%refined [%fn *]] u.got)  ~[leaf+"call lost checked branch evidence"]
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main env.u.result.checked)
  ?~  main  ~[leaf+"main not published"]
  =/  main-type=(unit itype:jibb)  (scheme-display-type:jibb u.main)
  ?~  main-type  ~[leaf+"main did not realize"]
  =/  fields=(list itype:jibb)  (record-fields-named:jibb %update u.main-type ~)
  ?.  ?=([[%refined [%fn *]] ~] fields)  ~[leaf+"store cast lost branch gate evidence"]
  ~
--
