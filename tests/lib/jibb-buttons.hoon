::  Full checking for the Grammar's documented buttons library only.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  source  %jibb  /my-app/ui/components/buttons/jibb
/*  valid  %txt  /tests/type-buttons/valid/txt
/*  expected  %txt  /tests/type-buttons/expected/txt
/*  error  %txt  /tests/type-buttons/error/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  buttons-detailed
  |=  [src=@t prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  =/  at=path  /ui/components/buttons/jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  buttons-legacy
  |=  [src=@t prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  =/  at=path  /ui/components/buttons/jibb
  (infer-jibb-file:jibb at src ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  buttons-interface-errors
  |=  [label=tape checked=ifile:jibb]
  ^-  (list tape)
  =/  labelled=(unit ischeme:jibb)  (ienv-lookup:jibb %labelled values.checked)
  ?~  labelled  ~[(weld label ": labelled is missing")]
  =/  wide=(unit ischeme:jibb)  (ienv-lookup:jibb %wide values.checked)
  ?~  wide  ~[(weld label ": wide is missing")]
  =/  lt=itype:jibb  (canonical-itype:jibb typ.u.labelled vars.u.labelled)
  =/  wt=itype:jibb  (canonical-itype:jibb typ.u.wide vars.u.wide)
  =/  actual=@t
    (of-wain:format ~[(crip "labelled: {(show-itype:jibb lt ~)}") (crip "wide: {(show-itype:jibb wt ~)}")])
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[(weld label ": valid definition types differ")]
  ~
::
++  buttons-error-matches
  |=  actual=@t
  ^-  ?
  =((to-wain:format (cat 3 actual '\0a')) error)
::
++  buttons-errors
  |=  [public=@t private=@t full=@t valid-source=@t]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  ~["buttons prelude did not prepare"]
  =/  detailed=jfile-detailed-result:jibb  (buttons-detailed valid-source u.prepared)
  =/  legacy=jfile-result:jibb  (buttons-legacy valid-source u.prepared)
  =/  failures=(list tape)
    ?:  ?=(%| -.detailed)
      ~[(weld "detailed valid buttons rejected: " (trip message.p.detailed))]
    (buttons-interface-errors "detailed" iface.p.detailed)
  =?  failures  ?=(%| -.legacy)
    [(weld "legacy valid buttons rejected: " (trip p.legacy)) failures]
  =?  failures  ?=(%& -.legacy)
    (weld (buttons-interface-errors "legacy" iface.p.legacy) failures)
  =/  detailed-full=jfile-detailed-result:jibb  (buttons-detailed full u.prepared)
  =?  failures  ?=(%& -.detailed-full)
    ["detailed full buttons accepted" failures]
  =?  failures  ?=(%| -.detailed-full)
    ?:  (buttons-error-matches message.p.detailed-full)  failures
    ["detailed full buttons error or location differs" failures]
  =/  legacy-full=jfile-result:jibb  (buttons-legacy full u.prepared)
  =?  failures  ?=(%& -.legacy-full)
    ["legacy full buttons accepted" failures]
  =?  failures  ?=(%| -.legacy-full)
    ?:  (buttons-error-matches p.legacy-full)  failures
    ["legacy full buttons error or location differs" failures]
  failures
::
++  test-buttons
  ^-  tang
  =/  failures=(list tape)  (buttons-errors prelude internal source (text valid))
  (turn failures |=(reason=tape leaf+reason))
--
