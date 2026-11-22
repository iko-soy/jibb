::  The standard each union preserves its arguments and does not mistake
::  a same-named local mold for the standard library's each.
/+  jibb, jibb-import
|%
++  test-import-each
  ^-  tang
  =/  src=@t
    (rap 3 (turn ~['|%' '+$  either  (each @ud @t)' '+$  wrapped  (each (list @ud) (map @ud @t))' '+$  bad  (each $?(@t @ud) @t)' '--'] |=(line=@t (cat 3 line '\0a'))))
  =/  cor=type  -:(ride -:!>(..zuse) src)
  =/  either  (read-named:jibb-import %fixture %either cor)
  =/  wrapped  (read-named:jibb-import %fixture %wrapped cor)
  =/  bad  (read-named:jibb-import %fixture %bad cor)
  ?.  ?=([%& [%fork *]] either)  ~[leaf+"standard each did not import as a union"]
  ?.  ?=([%& [%fork *]] wrapped)  ~[leaf+"each with collection arguments did not import"]
  ?:  ?=(%& -.bad)  ~[leaf+"each accepted an overlapping union argument"]
  ?.  =(p.bad 'a Hoon union needs a source-level disjointness check')
    ~[leaf+"bad each diagnostic differs: {(trip p.bad)}"]
  =/  shadow-src=@t
    (rap 3 (turn ~['|%' '++  each  |$([a b] [left=a right=b])' '+$  local  (each @ud @t)' '--'] |=(line=@t (cat 3 line '\0a'))))
  =/  shadow=type  -:(ride -:!>(..zuse) shadow-src)
  =/  local  (read-named:jibb-import %fixture %local shadow)
  ?:  ?=([%& [%fork *]] local)  ~[leaf+"a shadowed each was mistaken for the standard union"]
  =/  at=path  /ui/probe/jibb
  =/  local-text=@t  (of-wain:format ~['/- fixture' '++ id |= x=local.fixture x' '++ pair ^- local.fixture [left=1 right="hi"]'])
  =/  local-ext=(list [module=term name=term result=*])  ~[[%fixture %local local]]
  =/  local-checked  (infer-jibb-file-detailed:jibb at local-text local-ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.local-checked)  ~[leaf+"full checker rejected shadowed local each: {(trip message.p.local-checked)}"]
  =/  ext=(list [module=term name=term result=*])  ~[[%fixture %either either]]
  =/  text=@t  (of-wain:format ~['/- fixture' '++ id |= x=either.fixture x' '++ yes ^- either.fixture [%& p=1]' '++ no ^- either.fixture [%| p="hi"]'])
  =/  checked  (infer-jibb-file-detailed:jibb at text ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"full checker rejected standard each: {(trip message.p.checked)}"]
  ~
--
