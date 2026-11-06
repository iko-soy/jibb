::  A checked interface must not print away hidden generic arguments.
/+  jibb
/*  source  %jibb  /tests/golden/types-generic-union-escaping/source/jibb
/*  base  %jibb  /tests/golden/types-generic-union-escaping/modules/ui/base/jibb
/*  mid  %jibb  /tests/golden/types-generic-union-escaping/modules/ui/mid/jibb
/*  visible  %jibb  /tests/golden/types-union-phantom-generic/source/jibb
|%
++  test-hidden-generic-report
  ^-  tang
  =/  at=path  /tests/golden/types-generic-union-escaping/source/jibb
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb base] [/ui/mid/jibb mid]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"module failed before reporting" leaf+(trip message.p.result)]
  =/  actual=@t  (render-full-types:jibb at source result)
  =/  expected=@t  'module kind: library\0a/= types-1 /ui/base\0a++ text-value: (phantom.types-1 @t)\0a++ ship-value: (phantom.types-1 @p)'
  ?.  =(expected actual)  ~[leaf+"hidden generic import alias differs" leaf+(trip actual)]
  ~
++  test-visible-generic-report
  ^-  tang
  =/  actual=@t  (golden-types:jibb /tests/visible/jibb visible)
  =/  expected=@t  'module kind: library\0a+$ phantom: (phantom A)\0a++ example: (phantom @t)'
  ?.  =(expected actual)  ~[leaf+"visible generic should print its name and argument" leaf+(trip actual)]
  ~
++  test-hidden-second-generic-report
  ^-  tang
  =/  at=path  /tests/golden/types-generic-union-escaping/source/jibb
  =/  src=@t  '/=  mid /ui/mid\0a\0a++ ship-value ship.mid\0a'
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb base] [/ui/mid/jibb mid]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"module failed before reporting" leaf+(trip message.p.result)]
  =/  actual=@t  (render-full-types:jibb at src result)
  =/  expected=@t  'module kind: library\0a/= types-1 /ui/base\0a++ ship-value: (phantom.types-1 @p)'
  ?.  =(expected actual)  ~[leaf+"second hidden generic import alias differs" leaf+(trip actual)]
  ~
++  test-hidden-generated-and-recursive
  ^-  tang
  =/  hidden=itype:jibb  [%union ~ ~ ~ ~[[%atom %t]]]
  =/  generated=ienv:jibb  ~[[%derived [hidden ~ ~]]]
  =/  found=(unit [name=term reason=tape])  (full-report-hidden-generated:jibb generated ~)
  ?~  found  ~[leaf+"generated hidden generic was not rejected"]
  ?.  &(=(%derived name.u.found) =(reason.u.found "generic union name is not available in this scope"))
    ~[leaf+"generated helper diagnostic differs"]
  =/  recursive=itype:jibb  [%recursive %base %node ~]
  =/  reason=(unit tape)  (full-report-hidden-reason:jibb recursive)
  ?.  =(`"recursive mold name is not available in this scope" reason)
    ~[leaf+"hidden recursive mold did not report its construct"]
  ~
++  test-report-import-name-collision
  ^-  tang
  =/  at=path  /tests/golden/types-generic-union-escaping/source/jibb
  =/  src=@t  '/= types-1 /ui/mid\0a++ value text-value.types-1\0a'
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb base] [/ui/mid/jibb mid]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"module failed before reporting" leaf+(trip message.p.result)]
  =/  actual=@t  (render-full-types:jibb at src result)
  =/  expected=@t  'module kind: library\0a/= types-2 /ui/base\0a++ value: (phantom.types-2 @t)'
  ?.  =(expected actual)  ~[leaf+"report import shadows a source name" leaf+(trip actual)]
  ~
++  test-hidden-distinct-origins
  ^-  tang
  =/  at=path  /tests/golden/types-generic-union-escaping/source/jibb
  =/  middle=@t  '/= left /ui/base\0a/= right /ui/other\0a++ first ^- (phantom.left @t) %yes\0a++ second ^- (phantom.right @p) %yes\0a'
  =/  src=@t  '/= mid /ui/mid\0a++ first first.mid\0a++ second second.mid\0a'
  =/  modules=jbundle:jibb  ~[[/ui/base/jibb base] [/ui/other/jibb base] [/ui/mid/jibb middle]]
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"module failed before reporting" leaf+(trip message.p.result)]
  =/  actual=@t  (render-full-types:jibb at src result)
  =/  expected=@t  'module kind: library\0a/= types-1 /ui/other\0a/= types-2 /ui/base\0a++ first: (phantom.types-2 @t)\0a++ second: (phantom.types-1 @p)'
  ?.  =(expected actual)  ~[leaf+"hidden nominal origins collapsed or changed" leaf+(trip actual)]
  ~
--
