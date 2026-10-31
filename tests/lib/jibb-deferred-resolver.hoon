::  Source-level normal resolver and report integration; no island claim.
/+  jibb
/*  good  %txt  /tests/type-deferred-resolver/good/txt
/*  conflict  %txt  /tests/type-deferred-resolver/conflict/txt
/*  missing  %txt  /tests/type-deferred-resolver/missing/txt
/*  hole  %txt  /tests/type-deferred-resolver/hole/txt
/*  duplicate  %txt  /tests/type-deferred-resolver/duplicate/txt
/*  face  %txt  /tests/type-deferred-resolver/face/txt
/*  store  %txt  /tests/type-deferred-resolver/store/txt
/*  stability-early  %txt  /tests/type-deferred-resolver/stability-early/txt
/*  stability-late  %txt  /tests/type-deferred-resolver/stability-late/txt
/*  stability-simple-early  %txt  /tests/type-deferred-resolver/stability-simple-early/txt
/*  stability-simple-late  %txt  /tests/type-deferred-resolver/stability-simple-late/txt
/*  stability-output-early  %txt  /tests/type-deferred-resolver/stability-output-early/txt
/*  stability-output-late  %txt  /tests/type-deferred-resolver/stability-output-late/txt
/*  stability-slot-early  %txt  /tests/type-deferred-resolver/stability-slot-early/txt
/*  stability-slot-late  %txt  /tests/type-deferred-resolver/stability-slot-late/txt
/*  public  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  expected  %txt  /tests/type-deferred-resolver/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  case-no-fallback
  |=  [source=@t public=@t internal=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prep  'BAD prelude'
  =/  plain=(each module:jibb error:jibb)  (parse:jibb /ui/test/jibb source)
  ?:  ?=(%| -.plain)  'BAD source parse:jibb'
  ?.  (module-scope-valid:jibb p.plain values.u.prep molds.u.prep)  'BAD prelude scope'
  =/  prelude-result=jfile-result:jibb  (infer-jibb-file:jibb /ui/test/jibb source ~ ~ ~ ~[/ui/test/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.prelude-result)  'BAD prepared prelude fallback'
  =/  imported-source=@t  (cat 3 '/= dep /ui/dep\0a' source)
  =/  dependencies=jbundle:jibb  ~[[/ui/dep/jibb '++ value 1']]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/test/jibb imported-source)
  ?:  ?=(%| -.parsed)  'BAD import source parse:jibb'
  =/  deps=jimports-result:jibb  (resolve-jibb-imports:jibb imports.p.parsed ~ ~ dependencies ~[/ui/test/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.deps)  'BAD dependency resolution'
  =/  imported-result=jfile-result:jibb  (infer-jibb-file:jibb /ui/test/jibb imported-source ~ ~ dependencies ~[/ui/test/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.imported-result)  'BAD imported fallback'
  'prelude and import fallback declined'
++  resolver-report
  |=  [good=@t conflict=@t missing=@t hole=@t duplicate=@t face=@t store=@t public=@t internal=@t]
  ^-  @t
  =/  lines=(list @t)
    =/  at=path  /ui/obligation/jibb
    =/  expect-reject
      |=  [label=@t source=@t]
      ^-  @t
      =/  parsed  (parse:jibb at source)
      ?:  ?=(%| -.parsed)  (crip "BAD-{(trip label)}-parse")
      =/  got=jfile-result:jibb  (infer-jibb-file:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
      ?:(?=(%| -.got) (crip "{(trip label)} rejected without interface") (crip "BAD-{(trip label)}-published"))
    =/  result=jfile-result:jibb  (infer-jibb-file:jibb at good ~ ~ ~ ~[at] ~ ~ ~ ~)
    ?:  ?=(%| -.result)  ~[(crip "BAD-valid: {(trip p.result)}")]
    =/  iface=ifile:jibb  iface.p.result
    =/  built=(unit ischeme:jibb)  (ienv-lookup:jibb %built values.iface)
    ?~  built  ~['BAD-missing-built']
    =/  text=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal values.iface)
    =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal-ship values.iface)
    ?~  text  ~['BAD-missing-text']
    ?~  ship  ~['BAD-missing-ship']
    =/  report=@t  (golden-types-with-marks:jibb at good ~ ~)
    =/  store-at=path  /ui/stores/test/jibb
    =/  store-parsed  (parse:jibb store-at store)
    ?:  ?=(%| -.store-parsed)  ~['BAD-store-parse']
    =/  store-result=jfile-result:jibb  (infer-jibb-file:jibb store-at store ~ ~ ~ ~[store-at] ~ ~ ~ ~)
    =/  shown=itype:jibb  (canonical-itype:jibb typ.u.built vars.u.built)
    :~  ?:(?=(^ vars.u.built) 'interface retains independent polymorphism' 'BAD-principal')
        ?:(?=([%atom %t] typ.u.text) 'text use inferred' 'BAD-text')
        ?:(?=([%atom %p] typ.u.ship) 'ship use inferred' 'BAD-ship')
        (crip "stored built: {(show-itype:jibb shown ~)}")
        report
        (expect-reject 'conflict' conflict)
        (expect-reject 'missing' missing)
        (expect-reject 'hole' hole)
        (expect-reject 'duplicate' duplicate)
        (expect-reject 'face' face)
        ?:(?=(%| -.store-result) 'store declined without interface' 'BAD-store-published')
        'conflict report:'
        (golden-types-with-marks:jibb at conflict ~ ~)
        'store report:'
        (golden-types-with-marks:jibb store-at store ~ ~)
    ==
  =.  lines  (snoc lines (case-no-fallback good public internal))
  (of-wain:format lines)
++  test-deferred-resolver
  ^-  tang
  =/  result=@t  (resolver-report (text good) (text conflict) (text missing) (text hole) (text duplicate) (text face) (text store) public internal)
  ?.  =((to-wain:format (cat 3 result '\0a')) expected)  ~[leaf+"deferred resolver report differs"]
  =/  closed=itype:jibb  [%cell [%face %foo [%atom %t]] [%atom %t]]
  =/  open=itype:jibb  [%cell [%face %foo [%var 500]] [%atom %t]]
  =/  tag=itype:jibb  [%tag 501 *lit:jibb |]
  ?.  (dg-stable-call-fit:jibb closed closed [%atom %t] ~ &)  ~[leaf+"closed positional fit declined"]
  ?:  (dg-stable-call-fit:jibb open open [%atom %t] ~ &)  ~[leaf+"open positional face accepted"]
  ?:  (dg-stable-call-fit:jibb closed closed tag ~ &)  ~[leaf+"pending positional result accepted"]
  ?.  (dg-stable-call-fit:jibb open open [%atom %t] ~ |)  ~[leaf+"equal single argument declined"]
  =/  samples=(list wain)
    ~[stability-early stability-late stability-simple-early stability-simple-late stability-output-early stability-output-late stability-slot-early stability-slot-late]
  |-
  ?~  samples  ~
  ?~  i.samples  ~[leaf+"deferred stability source missing"]
  =/  at=path  /ui/stability/jibb
  =/  src=@t  (text i.samples)
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"deferred stability source does not parse"]
  =/  result=jfile-result:jibb  (infer-jibb-file:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"unstable deferred fit published an interface"]
  $(samples t.samples)
--
