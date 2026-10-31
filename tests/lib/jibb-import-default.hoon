::  Source-aware $~ proof over a real Tlon mold and adversarial controls.
/+  jibb-import
/*  tlon      %txt  /tests/type-import-default/tlon/txt
/*  controls  %txt  /tests/type-import-default/controls/txt
/*  parent    %txt  /tests/type-import-default/parent/txt
/*  expected  %txt  /tests/type-import-default/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  projection
  |=  [label=@t cor=type name=term]
  ^-  @t
  =/  got  (read-named:jibb-import %example name cor)
  (crip "{(trip label)}: {(show-result:jibb-import got)}")
++  fixture-output
  |=  [tlon=@t controls=@t parent=@t]
  ^-  @t
  =/  tc=type  -:(ride -:!>(..zuse) tlon)
  =/  cc=type  -:(ride -:!>(..zuse) controls)
  =/  pc=type  -:(ride -:!>(..zuse) parent)
  =/  context=type  [%cell [%face %base pc] -:!>(..zuse)]
  =/  sc=type  -:(ride context controls)
  =/  four=(unit hoon)  (local-arm-source:jibb-import cc %inner-four)
  =/  five=(unit hoon)  (local-arm-source:jibb-import cc %inner-deep)
  =/  bound=@t
    ?:  |(?=(~ four) ?=(~ five))  'wrapper source missing'
    ?~  (tagged-source-code:jibb-import u.four %inner-four)  'four rejected'
    ?^  (tagged-source-code:jibb-import u.five %inner-deep)  'five accepted'
    'four accepted; five rejected'
  =/  bad=*  [%bcsg [%rock %n 0] [%bccn 1]]
  =/  malformed=(each (unit spec) tang)
    (mule |.((tagged-default-union:jibb-import ;;(spec bad) 4)))
  =/  malformed-status=@t
    ?:  ?=(%| -.malformed)  'rejected'
    ?~  p.malformed  'rejected'
    'accepted'
  (of-wain:format ~[(projection 'saga' tc %saga) (projection 'saga-envelope' tc %saga-envelope) (projection 'outer-good' cc %outer-good) (projection 'outer-overlap' cc %outer-bad) (projection 'recursive-overlap' cc %outer-bad-rec) (projection 'mutual-recursion' cc %outer-mutual) (projection 'shadow' sc %outer-good) (crip "default-wrapper-bound: {(trip bound)}") (crip "malformed-wrapper: {(trip malformed-status)}")])
++  test-import-default
  ^-  tang
  ?~  tlon  ~[leaf+"Tlon default fixture missing"]
  ?~  controls  ~[leaf+"default controls missing"]
  ?~  parent  ~[leaf+"default shadow source missing"]
  ?~  expected  ~[leaf+"default expected output missing"]
  =/  got=@t  (fixture-output (text tlon) (text controls) (text parent))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"default-wrapper golden differs"]
  ~
--
