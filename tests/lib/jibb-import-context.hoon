/+  jibb
|%
++  failure-text
  |=  [file=path source=@t bundle=jbundle:jibb]
  ^-  @t
  =/  result  (infer-jibb-file-detailed:jibb file source ~ ~ bundle ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  'unexpectedly accepted'
  message.p.result
++  report
  ^-  @t
  =/  missing=@t  (failure-text /ui/root/jibb '/= item /ui/missing\0a++ value 1\0a' ~)
  =/  duplicate=@t  (failure-text /ui/root/jibb '/= item /ui/item\0a++ value 1\0a' ~[[/ui/item/jibb '++ x 1\0a'] [/ui/item/jibb '++ x 2\0a']])
  =/  internal=@t  (failure-text /ui/root/jibb '/= internal /lib/jibb/internal\0a' ~)
  =/  primitives=@t  (failure-text /ui/root/jibb '/= primitives /lib/jibb/primitives\0a' ~)
  =/  nested=@t  (failure-text /ui/root/jibb '/= child /ui/a\0a' ~[[/ui/a/jibb '/= item /ui/missing\0a']])
  =/  prelude=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a'
  =/  shadow=@t  (golden-types-with-prelude:jibb /ui/root/jibb '++ f |= x=(list @t)\0a  +$ list @t\0a  x\0a' ~ ~ ~ prelude)
  (of-wain:format ~['missing' missing 'duplicate' duplicate 'internal' internal 'primitives' primitives 'nested' nested 'prelude-shadow' shadow])
++  test-import-context
  ^-  tang
  =/  expected=@t  'missing\0amodule source missing: /ui/missing/jibb\0a/ui/root.jibb:1:1: imports /ui/missing.jibb here\0a/= item /ui/missing\0a^\0aduplicate\0aduplicate module sources: /ui/item/jibb\0a/ui/root.jibb:1:1: imports /ui/item.jibb here\0a/= item /ui/item\0a^\0ainternal\0athe prelude internal module is private\0a/ui/root.jibb:1:1: imports /lib/jibb/internal.jibb here\0a/= internal /lib/jibb/internal\0a^\0aprimitives\0athe prelude primitive interface is private\0a/ui/root.jibb:1:1: imports /lib/jibb/primitives.jibb here\0a/= primitives /lib/jibb/primitives\0a^\0anested\0amodule source missing: /ui/missing/jibb\0a/ui/a.jibb:1:1: imports /ui/missing.jibb here\0a/= item /ui/missing\0a^\0aprelude-shadow\0a++ f: local mold `list` shadows an imported or prelude name\0a/lib/jibb/prelude.jibb:1:4: earlier binding\0a+$ list |$ [A]\0a   ^\0a/ui/root.jibb:2:3: conflicting local mold\0a  +$ list @t\0a  ^\0a'
  ?.  =((cat 3 report '\0a') expected)
    ~[leaf+"import source context differs"]
  ~
++  test-without-source
  ^-  tang
  =/  parsed  (parse:jibb /ui/root/jibb '/= item /ui/missing\0a')
  ?:  ?=(%| -.parsed)  ~[leaf+"import source did not parse"]
  =/  result  (resolve-jibb-imports-detailed:jibb imports.p.parsed ~ ~ ~ ~ ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"missing source was accepted"]
  ?.  =(message.p.result 'module source missing: /ui/missing/jibb')
    ~[leaf+"source-free resolver did not retain its raw error"]
  =/  state=istate:jibb  *istate:jibb
  ?^  (source-prelude-mold-site:jibb %list state)
    ~[leaf+"missing prelude source invented a declaration"]
  ~
--
