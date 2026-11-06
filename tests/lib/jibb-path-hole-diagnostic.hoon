::  Keep the typed mold-path hole distinct from invalid expression syntax.
/+  jibb
|%
++  test-path-hole-diagnostic
  ^-  tang
  =/  actual=@t  (golden-types:jibb /ui/paths/jibb '+$ p /todo/[id=_]\0a')
  =/  expected=@t
    (of-wain:format ~['+$ p: type hole must be determined by its definition' '/ui/paths.jibb:1:12: unresolved type hole' '+$ p /todo/[id=_]' '           ^'])
  ?.  =(actual expected)  ~[leaf+(trip actual)]
  ~
--
