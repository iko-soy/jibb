::  Full checking for the documented theme mold and real app theme only.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  source  %txt  /tests/type-theme/source/txt
/*  dark-absent  %txt  /tests/type-theme/dark-absent/txt
/*  wrong-nested-aura  %txt  /tests/type-theme/wrong-nested-aura/txt
/*  missing-field  %txt  /tests/type-theme/missing-field/txt
/*  wrong-font  %txt  /tests/type-theme/wrong-font/txt
/*  wrong-dark  %txt  /tests/type-theme/wrong-dark/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  theme-detailed
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  theme-positive
  |=  [label=tape src=@t expected=tape prepared=iprelude:jibb]
  ^-  (list tape)
  =/  at=path  /ui/theme/jibb
  =/  detailed=jfile-detailed-result:jibb
    (theme-detailed at src ~ prepared)
  ?:  ?=(%| -.detailed)
    ~[(weld label (weld ": rejected: " (trip message.p.detailed)))]
  =/  checked=ifile:jibb  iface.p.detailed
  =/  theme=(unit ischeme:jibb)  (ienv-lookup:jibb %theme values.checked)
  ?~  theme  ~[(weld label ": theme is missing")]
  ?.  &(?=(~ vars.u.theme) ?=(~ (itype-vars:jibb typ.u.theme)))
    ~[(weld label ": theme is not closed")]
  =/  actual=tape  (show-itype:jibb typ.u.theme ~)
  ?.  =(actual expected)
    ~[(weld label (weld ": theme type was " actual))]
  =/  consumer-at=path  /tests/theme/consumer/jibb
  =/  consumer=@t  '/= app-theme /ui/theme\0a++ imported theme.app-theme\0a'
  =/  imported=jfile-detailed-result:jibb
    (theme-detailed consumer-at consumer ~[[at src]] prepared)
  ?:  ?=(%| -.imported)
    ~[(weld label (weld ": downstream import rejected: " (trip message.p.imported)))]
  =/  use=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  use  ~[(weld label ": downstream theme is missing")]
  =/  expected-import=itype:jibb
    (itype-in-import:jibb typ.u.theme checked %app-theme `iface.prepared)
  ?.  &(?=(~ vars.u.use) =(typ.u.use expected-import))
    ~[(weld label ": downstream theme type differs")]
  ~
::
++  theme-negative
  |=  [label=tape src=@t prepared=iprelude:jibb]
  ^-  (list tape)
  =/  bad=jfile-detailed-result:jibb
    (theme-detailed /ui/theme/jibb src ~ prepared)
  ?:  ?=(%& -.bad)  ~[(weld label ": accepted")]
  ~
::
++  theme-errors
  |=  [public=@t private=@t source=@t dark-absent=@t wrong-nested-aura=@t missing-field=@t wrong-font=@t wrong-dark=@t]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  ~["theme prelude did not prepare"]
  =/  expected=tape  "[space=[s1=@t [s2=@t s3=@t]] [tones=[normal=@t [background=@t [accent=@t [danger=@t muted=@t]]]] [wide=@t [lang=@t [zone=@t [font=(unit qath.internal) dark=(unit [tones=[normal=@t [background=@t [accent=@t [danger=@t muted=@t]]]]])]]]]]]"
  =/  negatives=(list [label=tape src=@t])
    :~  ["wrong nested aura" wrong-nested-aura]
        ["missing required field" missing-field]
        ["wrong font type" wrong-font]
        ["wrong dark type" wrong-dark]
    ==
  =/  positives=(list (list tape))
    :~  (theme-positive "dark present" source expected u.prepared)
        (theme-positive "dark absent" dark-absent expected u.prepared)
    ==
  =/  failures=(list tape)  (zing positives)
  ?^  failures  failures
  (zing (turn negatives |=(c=[label=tape src=@t] (theme-negative label.c src.c u.prepared))))
::
++  test-theme
  ^-  tang
  =/  failures=(list tape)
    (theme-errors prelude internal (text source) (text dark-absent) (text wrong-nested-aura) (text missing-field) (text wrong-font) (text wrong-dark))
  (turn failures |=(reason=tape leaf+reason))
--
