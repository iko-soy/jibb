::  Deferred initializer and constructor constraints through the full checker.
::  Prepared and source-taking entry points publish the same full result.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
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
/*  expected-errors  %txt  /tests/type-deferred-prepared/expected-errors/txt
/*  expected-control  %txt  /tests/type-deferred-prepared/expected-control/txt
/*  expected-tuple-only  %txt  /tests/type-deferred-prepared/expected-tuple-only/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  check-prepared
  |=  [where=path source=wain valid=? prepared=(unit iprelude:jibb)]
  ^-  tang
  ?~  source  ~[leaf+"source fixture missing"]
  =/  src=@t  (text source)
  =/  parsed  (parse:jibb where src)
  ?:  ?=(%| -.parsed)  ~[leaf+"source does not parse"]
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  checked=jfile-result:jibb
    (infer-jibb-file:jibb where src ~ ~ ~ ~[where] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?.  =(valid ?=(%& -.checked))
    ~[leaf+(weld "prepared initializer result changed: " ?:(?=(%| -.checked) (trip p.checked) "unexpected acceptance"))]
  ~
++  check-no-prelude
  ^-  tang
  =/  at=path  /ui/prepared/jibb
  =/  src=@t  (text no-prelude)
  =/  checked=jfile-result:jibb
    (infer-jibb-file:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  =/  final=(unit ischeme:jibb)  (ienv-lookup:jibb %final values.iface.p.checked)
  =/  initial=(unit ischeme:jibb)  (ienv-lookup:jibb %initial values.iface.p.checked)
  ?~  final  ~[leaf+"no-prelude final gate is missing"]
  ?~  initial  ~[leaf+"no-prelude initializer is missing"]
  ?.  &(=(typ.u.final typ.u.initial) ?=(~ vars.u.final) ?=(~ vars.u.initial))
    ~[leaf+"no-prelude later context did not close the initializer"]
  ~
++  check-ordinary
  |=  prepared=(unit iprelude:jibb)
  ^-  tang
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  at=path  /ui/prepared/jibb
  =/  ordinary=jfile-result:jibb
    (infer-jibb-file:jibb at (text good) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.ordinary)  ~[leaf+(trip p.ordinary)]
  ~
++  check-report
  |=  [source=wain wanted=wain prepared=(unit iprelude:jibb)]
  ^-  tang
  ?~  source  ~[leaf+"report source fixture missing"]
  ?~  wanted  ~[leaf+"expected report fixture missing"]
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /ui/prepared/jibb (text source) ~ ~ ~ prepared)
  =/  report-lines=wain  (to-wain:format (cat 3 report '\0a'))
  ?~  report-lines  ~[leaf+"prepared report is empty"]
  ?.  =(report-lines wanted)  ~[leaf+"prepared report differs from exact checked types"]
  ~
++  check-prepared-binding
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude unavailable"]
  =/  at=path  /ui/prepared/jibb
  =/  src=@t  (text good)
  =/  cached=@t  (golden-types-with-prepared-prelude:jibb at src ~ ~ ~ prepared)
  =/  supplied=@t  (golden-bundle:jibb-prelude-fixture at src ~ ~ ~ prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] ~)
  ?.  =(cached supplied)  ~[leaf+"prepared and source-taking full reports differ"]
  ~
++  errors-report
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  'prelude unavailable'
  =/  cases=(list [label=@t source=wain])
    :~  ['wrong unit' wrong-unit]
        ['wrong draft' wrong-draft]
        ['unrelated tag' unrelated-tag]
        ['mold collision' mold-collision]
        ['no final cast' no-final-cast]
        ['ordinary gate main' main-source]
        ['missing import' imported]
    ==
  =/  at=path  /ui/prepared/jibb
  %-  of-wain:format
  %+  turn  cases
  |=  [label=@t source=wain]
  =/  checked=jfile-result:jibb
    (infer-jibb-file:jibb at (text source) ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  (cat 3 label (cat 3 '\0a' ?:(?=(%| -.checked) p.checked 'unexpected acceptance')))
++  good-report
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  'prelude unavailable'
  (golden-types-with-prepared-prelude:jibb /ui/prepared/jibb (text good) ~ ~ ~ prepared)
++  report
  good-report
++  test-prepared-errors
  ^-  tang
  =/  actual=@t  errors-report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected-errors)
    ~[leaf+(trip actual)]
  ~
++  test-prepared
  ^-  tang
  =/  at=path  /ui/prepared/jibb
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  =/  checks=(list tang)
    :~  (check-prepared at good & prepared)
        (check-prepared at tuple-only & prepared)
        (check-prepared at no-prelude & prepared)
        (check-prepared at wrong-unit | prepared)
        (check-prepared at wrong-draft | prepared)
        (check-prepared at unrelated-tag | prepared)
        (check-prepared at mold-collision | prepared)
        (check-prepared at no-final-cast | prepared)
        (check-prepared at main-source | prepared)
        (check-prepared at imported | prepared)
        (check-prepared /ui/api/prepared/jibb good & prepared)
        (check-prepared /ui/stores/prepared/jibb good & prepared)
        check-no-prelude
        (check-ordinary prepared)
        check-prepared-binding
        (check-report good expected prepared)
        (check-report tuple-only expected-tuple-only prepared)
        (check-report no-final-cast expected-control prepared)
    ==
  (zing checks)
--
