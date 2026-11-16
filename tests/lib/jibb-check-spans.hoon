::  +check-spans catches the spans a parser bug could give: its own test,
::  +check-spans-test, plants wrong ends and starts in parsed sources.
/+  jibb
/*  date-source  %jibb  /tests/golden/lex-date-ok-3/source/jibb
|%
++  test-check-spans
  ^-  tang
  (turn check-spans-test:jibb |=(reason=tape leaf+reason))
++  test-date-padding-values
  ^-  tang
  =/  parsed=(each module:jibb error:jibb)
    (parse:jibb /tests/golden/lex-date-ok-3/source/jibb date-source)
  ?:  ?=(%| -.parsed)  ~[leaf+"zero-padded dates failed to parse"]
  =/  values=(list @)
    %+  turn  defs.p.parsed
    |=  d=def:jibb
    ?.  ?=(%value -.d)  0
    ?.  ?=(%lit -.val.d)  0
    val.lit.val.d
  =/  expected=(list @)
    :~  (need (slaw %da '~2026.1.2'))
        (need (slaw %da '~2026.1.2..3.4.5'))
        (need (slaw %da '~2026.1.2..3.4.5..ffff.0000'))
    ==
  ?.  =(expected values)  ~[leaf+"zero-padded dates changed atom values"]
  ~
--
