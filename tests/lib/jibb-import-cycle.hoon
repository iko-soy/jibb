::  Full import-cycle errors retain every traversed edge's own source.
/+  jibb
/*  expected  %txt  /tests/type-import-cycle/expected/txt
|%
++  failure-text
  |=  [file=path source=@t bundle=jbundle:jibb]
  ^-  @t
  =/  result
    (infer-jibb-file-detailed:jibb file source ~ ~ bundle ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  'cycle unexpectedly accepted'
  =/  legacy
    (infer-jibb-file:jibb file source ~ ~ bundle ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.legacy)  'legacy checker accepted cycle'
  ?.  =(message.p.result p.legacy)  'detailed and legacy diagnostics differ'
  message.p.result
++  report
  ^-  @t
  =/  source=@t  ':: root\0a/= leaf /ui/leaf\0a/= loop /ui/a\0a++ value 1\0a'
  =/  bundle=jbundle:jibb
    :~  [/ui/leaf/jibb '++ value 0\0a']
        [/ui/a/jibb ':: first edge\0a/= next /ui/b\0a']
        [/ui/b/jibb ':: closing edge\0a/= back /ui/a\0a']
    ==
  =/  indirect=@t  (failure-text /ui/root/jibb source bundle)
  =/  self=@t  (failure-text /ui/self/jibb '/= self /ui/self\0a' ~)
  =/  root=@t
    (failure-text /ui/root/jibb '/= child /ui/a\0a' ~[[/ui/a/jibb '/= root /ui/root\0a']])
  (of-wain:format ~[indirect self root])
++  test-import-cycle
  ^-  tang
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"import cycle diagnostics differ from expected"]
  ~
++  test-shared-import
  ^-  tang
  =/  source=@t  '/= left /ui/leaf\0a/= right /ui/leaf\0a++ pair [item.left item.right]\0a'
  =/  bundle=jbundle:jibb  ~[[/ui/leaf/jibb '++ item 3\0a']]
  =/  result
    (infer-jibb-file-detailed:jibb /ui/root/jibb source ~ ~ bundle ~[/ui/root/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  ~
--
