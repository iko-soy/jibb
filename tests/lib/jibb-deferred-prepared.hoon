::  Prepared-prelude initializer recovery remains a partial report only.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  good  %txt  /tests/type-deferred-prepared/good/txt
/*  tuple-only  %txt  /tests/type-deferred-prepared/tuple-only/txt
/*  wrong-unit  %txt  /tests/type-deferred-prepared/wrong-unit/txt
/*  wrong-draft  %txt  /tests/type-deferred-prepared/wrong-draft/txt
/*  unrelated-tag  %txt  /tests/type-deferred-prepared/unrelated-tag/txt
/*  mold-collision  %txt  /tests/type-deferred-prepared/mold-collision/txt
/*  no-final-cast  %txt  /tests/type-deferred-prepared/no-final-cast/txt
/*  no-prelude  %txt  /tests/type-deferred-prepared/no-prelude/txt
/*  main-source  %txt  /tests/type-deferred-prepared/main/txt
/*  imported  %txt  /tests/type-deferred-prepared/imported/txt
/*  expected  %txt  /tests/type-deferred-prepared/expected/txt
/*  expected-control  %txt  /tests/type-deferred-prepared/expected-control/txt
/*  expected-tuple-only  %txt  /tests/type-deferred-prepared/expected-tuple-only/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  check-prepared
  |=  [where=path source=wain valid=?]
  ^-  tang
  ?~  source  ~[leaf+"source fixture missing"]
  =/  src=@t  (text source)
  =/  parsed  (parse:jibb where src)
  ?:  ?=(%| -.parsed)  ~[leaf+"source does not parse"]
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  recovered=?  ?=(^ (dg-root-prepared:jibb where src u.prepared))
  ?.  =(valid recovered)  ~[leaf+"prepared initializer transaction result changed"]
  ~
++  check-no-prelude
  ^-  tang
  =/  at=path  /ui/prepared/jibb
  =/  src=@t  (text no-prelude)
  ?:  ?=(^ (dg-root-source:jibb at src))
    ~[leaf+"no-prelude source transaction recovered tuple initializer"]
  =/  legacy=jfile-result:jibb
    (infer-jibb-file:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.legacy)  ~[leaf+"no-prelude resolver published recovered tuple initializer"]
  ~
++  check-ordinary
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  at=path  /ui/prepared/jibb
  =/  ordinary=jfile-result:jibb
    (infer-jibb-file:jibb at (text good) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.ordinary)  ~[leaf+"ordinary full-module path published recovered initializer"]
  ~
++  check-report
  |=  [source=wain wanted=wain]
  ^-  tang
  ?~  source  ~[leaf+"report source fixture missing"]
  ?~  wanted  ~[leaf+"expected report fixture missing"]
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /ui/prepared/jibb (text source) ~ ~ ~ prepared)
  =/  report-lines=wain  (to-wain:format (cat 3 report '\0a'))
  ?~  report-lines  ~[leaf+"prepared report is empty"]
  ?.  =('partial inference; module not checked' i.report-lines)
    ~[leaf+"partial disclaimer changed"]
  ?.  =(report-lines wanted)  ~[leaf+"prepared report differs from exact recovered types"]
  ~
++  check-prepared-binding
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  at=path  /ui/prepared/jibb
  =/  src=@t  (text good)
  =/  pre=(unit ifile:jibb)  `iface.u.prepared
  =/  report
    |=  [vals=(list term) ms=(list term) p=(unit ifile:jibb) prep=(unit iprelude:jibb)]
    ^-  @t
    (golden-types-in-context-core:jibb at src ~ ~ ~ vals ms p prep)
  =/  vals=(list term)  values.u.prepared
  =/  ms=(list term)  molds.u.prepared
  ?:  =((report vals ms pre prepared) (report vals ms pre ~))
    ~[leaf+"exact prepared binding did not recover the initializer"]
  ?.  =((report ~ ms pre prepared) (report ~ ms pre ~))
    ~[leaf+"mismatched value inventory reached prepared recovery"]
  ?.  =((report vals ~ pre prepared) (report vals ~ pre ~))
    ~[leaf+"mismatched mold inventory reached prepared recovery"]
  ?.  =((report vals ms ~ prepared) (report vals ms ~ ~))
    ~[leaf+"mismatched prelude interface reached prepared recovery"]
  ~
++  test-prepared
  ^-  tang
  =/  at=path  /ui/prepared/jibb
  =/  checks=(list tang)
    :~  (check-prepared at good &)
        (check-prepared at tuple-only &)
        (check-prepared at no-prelude &)
        (check-prepared at wrong-unit |)
        (check-prepared at wrong-draft |)
        (check-prepared at unrelated-tag |)
        (check-prepared at mold-collision |)
        (check-prepared at no-final-cast |)
        (check-prepared at main-source |)
        (check-prepared at imported |)
        (check-prepared /ui/api/prepared/jibb good |)
        (check-prepared /ui/stores/prepared/jibb good |)
        check-no-prelude
        check-ordinary
        check-prepared-binding
        (check-report good expected)
        (check-report tuple-only expected-tuple-only)
        (check-report no-final-cast expected-control)
    ==
  (zing checks)
--
