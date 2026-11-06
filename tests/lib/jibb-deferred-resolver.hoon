::  Source-level normal resolver and report integration; no island claim.
/+  jibb, jibb-prelude-fixture
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
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  expected  %txt  /tests/type-deferred-resolver/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::  The same polymorphic interface must survive each successful context.
++  resolver-schemes-valid
  |=  iface=ifile:jibb
  ^-  ?
  =/  built=(unit ischeme:jibb)  (ienv-lookup:jibb %built values.iface)
  =/  text=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal values.iface)
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %reveal-ship values.iface)
  ?~  built  |
  ?~  text  |
  ?~  ship  |
  ?~  vars.u.built  |
  ?.  &(?=(~ vars.u.text) ?=([%atom %t] typ.u.text))  |
  ?.  &(?=(~ vars.u.ship) ?=([%atom %p] typ.u.ship))  |
  =/  typ=itype:jibb  (canonical-itype:jibb typ.u.built vars.u.built)
  =((crip (show-itype:jibb typ ~)) '$-(B B)')
::
++  case-checked-contexts
  |=  [source=@t public=@t internal=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture public internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  'BAD prelude'
  =/  plain=(each module:jibb error:jibb)  (parse:jibb /ui/test/jibb source)
  ?:  ?=(%| -.plain)  'BAD source parse:jibb'
  ?.  (module-scope-valid:jibb p.plain values.u.prep molds.u.prep)  'BAD prelude scope'
  =/  prelude-result=jfile-result:jibb  (infer-jibb-file:jibb /ui/test/jibb source ~ ~ ~ ~[/ui/test/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.prelude-result)  (cat 3 'BAD prepared prelude rejected: ' p.prelude-result)
  ?.  (resolver-schemes-valid iface.p.prelude-result)  'BAD prepared prelude schemes'
  =/  imported-source=@t  (cat 3 '/= dep /ui/dep\0a' source)
  =/  dependencies=jbundle:jibb  ~[[/ui/dep/jibb '++ value 1']]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/test/jibb imported-source)
  ?:  ?=(%| -.parsed)  'BAD import source parse:jibb'
  =/  deps=jimports-result:jibb  (resolve-jibb-imports:jibb imports.p.parsed ~ ~ dependencies ~[/ui/test/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.deps)  'BAD dependency resolution'
  =/  imported-result=jfile-result:jibb  (infer-jibb-file:jibb /ui/test/jibb imported-source ~ ~ dependencies ~[/ui/test/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.imported-result)  (cat 3 'BAD imported module rejected: ' p.imported-result)
  ?.  (resolver-schemes-valid iface.p.imported-result)  'BAD imported module schemes'
  'prelude and import contexts accepted with checked schemes'
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
      ?:(?=(%| -.got) (cat 3 label (cat 3 '\0a' p.got)) (crip "BAD-{(trip label)}-published"))
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
    ?:  ?=(%| -.store-result)  ~[(cat 3 'BAD-store-path library rejected: ' p.store-result)]
    ?.  (resolver-schemes-valid iface.p.store-result)  ~['BAD-store-path library schemes']
    ?^  (ienv-lookup:jibb %main values.iface.p.store-result)  ~['BAD-store-path library has main']
    ?^  (ienv-lookup:jibb %state values.iface.p.store-result)  ~['BAD-store-path library has derived state']
    ?^  (ienv-lookup:jibb %poke values.iface.p.store-result)  ~['BAD-store-path library has derived poke']
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
        'store-path library accepted with checked schemes'
        'conflict report:'
        (golden-types-with-marks:jibb at conflict ~ ~)
        'store report:'
        (golden-types-with-marks:jibb store-at store ~ ~)
    ==
  =.  lines  (snoc lines (case-checked-contexts good public internal))
  (of-wain:format lines)
++  report
  ^-  @t
  (resolver-report (text good) (text conflict) (text missing) (text hole) (text duplicate) (text face) (text store) public internal)
++  stability-case
  |=  [label=tape source=wain name=term expected-type=tape]
  ^-  tang
  ?~  source  ~[leaf+(weld label ": source missing")]
  =/  at=path  /ui/stability/jibb
  =/  src=@t  (text source)
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+(weld label ": source does not parse")]
  =/  result=jfile-result:jibb  (infer-jibb-file:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+(weld label (weld ": rejected: " (trip p.result)))]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb name values.iface.p.result)
  ?~  scheme  ~[leaf+(weld label ": result is missing")]
  ?^  vars.u.scheme  ~[leaf+(weld label ": result is not closed")]
  =/  shown=tape  (show-itype:jibb typ.u.scheme ~)
  ?.  =(shown expected-type)  ~[leaf+(weld label (weld ": wrong result type: " shown))]
  ~
++  test-deferred-resolver
  ^-  tang
  =/  result=@t  report
  ?.  =((to-wain:format (cat 3 result '\0a')) expected)  ~[leaf+"deferred resolver report differs"]
  =/  pair=tape  "[$-(@t [%got value=@t]) foo=$-(@t [%got value=@t])]"
  =/  faced=tape  "[foo=$-(@t [%got value=@t])]"
  =/  slot=tape  "[foo=[%got value=@t] @t]"
  =/  checks=(list tang)
    :~  (stability-case "early" stability-early %wrapped pair)
        (stability-case "late" stability-late %wrapped pair)
        (stability-case "simple early" stability-simple-early %wrapped faced)
        (stability-case "simple late" stability-simple-late %wrapped faced)
        (stability-case "output early" stability-output-early %value "%idle")
        (stability-case "output late" stability-output-late %value "%idle")
        (stability-case "slot early" stability-slot-early %value slot)
        (stability-case "slot late" stability-slot-late %value slot)
    ==
  (zing checks)
--
