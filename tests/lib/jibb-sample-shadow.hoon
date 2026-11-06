/+  jibb
/*  expected  %txt  /tests/type-sample-shadow/expected/txt
|%
++  report
  ^-  @t
  =/  file=path  /tests/sample-shadow/jibb
  =/  one=@t  '++ original 1\0a++ bad |= [x=@ud original=@t] x\0a'
  =/  nested=@t  '++ bad |= x=@t |=(y=@ud |=(x=@p y))\0a'
  =/  repeated=@t  '++ bad |= [x=@t [y=@ud x=@p]] y\0a'
  =/  good=@t  '++ okay |= x=@t |=(y=@ud x)\0a'
  =/  a=@t  (golden-types-with-modules:jibb file one ~ ~ ~)
  =/  b=@t  (golden-types-with-modules:jibb file nested ~ ~ ~)
  =/  c=@t  (golden-types-with-modules:jibb file repeated ~ ~ ~)
  =/  d=@t  (golden-types-with-modules:jibb file good ~ ~ ~)
  (of-wain:format ~['module:' a 'nested:' b 'repeated:' c 'good:' d])
++  test-sample-shadow
  ^-  tang
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"sample shadow diagnostics differ"]
  ~
++  test-sample-shadow-without-source
  ^-  tang
  =/  site=span:jibb  [[2 7] [2 14]]
  =/  binds=(list ishadow-binding:jibb)  ~[[%missing site]]
  =/  diag=(unit idiag:jibb)  (shadow-sample-fallback:jibb binds ~ ~[%missing] ~)
  ?~  diag  ~[leaf+"sample shadow was lost without source"]
  ?.  =(msg.u.diag "sample `missing` shadows a name already in scope")
    ~[leaf+"sample shadow name was lost"]
  ?.  =(sites.u.diag ~[[site "conflicting sample binding"]])
    ~[leaf+"sample shadow invented an earlier source"]
  ~
--
