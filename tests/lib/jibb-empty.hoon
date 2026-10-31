::  Source-backed empty-mold checks; no backend/runtime claim.
/+  jibb
/*  real-prelude   %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
/*  good           %txt   /tests/type-empty/good/txt
/*  overlap        %txt   /tests/type-empty/overlap/txt
/*  dead           %txt   /tests/type-empty/dead/txt
/*  missing        %txt   /tests/type-empty/missing/txt
/*  standard-good  %txt   /tests/type-empty/standard-good/txt
/*  list-dead      %txt   /tests/type-empty/list-dead/txt
/*  unit-dead      %txt   /tests/type-empty/unit-dead/txt
/*  late-cap       %txt   /tests/type-empty/late-cap/txt
/*  list-live      %txt   /tests/type-empty/list-live/txt
/*  list-open      %txt   /tests/type-empty/list-open/txt
/*  face-source    %txt   /tests/type-empty/face-source/txt
/*  expected       %txt   /tests/type-empty/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  line
  |=  [label=@t ok=?]
  ^-  @t
  (crip "{(trip label)}: {?:(ok "ok" "BAD")}")
++  face-retained
  |=  [source=@t prelude=ifile:jibb]
  ^-  ?
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/empty/jibb source)
  ?:  ?=(%| -.parsed)  |
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([* ~] ds)  |
  =/  d=def:jibb  i.ds
  ?.  ?=(%value -.d)  |
  =/  typ=itype:jibb  [%collection %list ~[[%empty ~]]]
  =/  env=ienv:jibb  ~[[%xs [typ ~]]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(prelude `prelude, jrec-fuel 256)
  =/  expected=itype:jibb  [%cell [%atom %t] [%atom %t]]
  =/  result=(unit iresult:jibb)
    (empty-list-null-branch:jibb val.d env state `[expected (span-of:jibb val.d)])
  ?~  result  |
  ?:  ?=(%| -.u.result)  |
  (itype-has-face:jibb typ.p.u.result sub.state.p.u.result)
++  empty-output
  |=  [pre=@t internal=@t good=@t overlap=@t dead=@t missing=@t standard-good=@t list-dead=@t unit-dead=@t late-cap=@t list-live=@t list-open=@t face-source=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb pre internal)
  ?~  prep  'BAD prelude preparation'
  =/  f=path  /tests/empty/jibb
  =/  valid=jfile-result:jibb  (infer-jibb-file:jibb f good ~ ~ ~ ~[f] ~ ~ ~ ~)
  ?:  ?=(%| -.valid)  'BAD checked empty source'
  =/  never=(unit ischeme:jibb)  (find-jibb-mold:jibb %never iface.p.valid)
  ?~  never  'BAD never export'
  =/  select=(unit ischeme:jibb)  (ienv-lookup:jibb %select values.iface.p.valid)
  ?~  select  'BAD select export'
  =/  split=(unit ischeme:jibb)  (find-jibb-mold:jibb %split iface.p.valid)
  ?~  split  'BAD split export'
  ?.  ?=(%fn -.typ.u.select)  'BAD select gate'
  =/  selected=itype:jibb  sample.typ.u.select
  =?  selected  ?=(%face -.selected)  body.selected
  =/  parsed-overlap=(each module:jibb error:jibb)  (parse:jibb f overlap)
  =/  parsed-dead=(each module:jibb error:jibb)  (parse:jibb f dead)
  =/  parsed-missing=(each module:jibb error:jibb)  (parse:jibb f missing)
  =/  parsed-list=(each module:jibb error:jibb)  (parse:jibb f list-dead)
  =/  parsed-unit=(each module:jibb error:jibb)  (parse:jibb f unit-dead)
  =/  invalid=jfile-result:jibb  (infer-jibb-file:jibb f overlap ~ ~ ~ ~[f] ~ ~ ~ ~)
  =/  dead-result=jfile-result:jibb  (infer-jibb-file:jibb f dead ~ ~ ~ ~[f] ~ ~ ~ ~)
  =/  missing-result=jfile-result:jibb  (infer-jibb-file:jibb f missing ~ ~ ~ ~[f] ~ ~ ~ ~)
  =/  standard=jfile-result:jibb  (infer-jibb-file:jibb f standard-good ~ ~ ~ ~[f] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  only=(unit ischeme:jibb)
    ?-  -.standard
      %&  (ienv-lookup:jibb %list-only values.iface.p.standard)
      %|  ~
    ==
  =/  only-context=(unit ischeme:jibb)
    ?-  -.standard
      %&  (ienv-lookup:jibb %list-only-context values.iface.p.standard)
      %|  ~
    ==
  =/  only-good=?
    ?~  only  |
    ?.  ?=(%fn -.typ.u.only)  |
    =/  sample=itype:jibb  sample.typ.u.only
    =?  sample  ?=(%face -.sample)  body.sample
    &(=(sample [%collection %list ~[[%empty ~]]]) =(product.typ.u.only [%atom %t]))
  =/  parsed-live=(each module:jibb error:jibb)  (parse:jibb f list-live)
  =/  parsed-open=(each module:jibb error:jibb)  (parse:jibb f list-open)
  =/  live-result=jfile-result:jibb  (infer-jibb-file:jibb f list-live ~ ~ ~ ~[f] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  open-result=jfile-result:jibb  (infer-jibb-file:jibb f list-open ~ ~ ~ ~[f] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  bad-list=jfile-result:jibb  (infer-jibb-file:jibb f list-dead ~ ~ ~ ~[f] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  bad-unit=jfile-result:jibb  (infer-jibb-file:jibb f unit-dead ~ ~ ~ ~[f] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  atom=itype:jibb  [%atom %t]
  =/  void=itype:jibb  [%empty ~]
  =/  fn=itype:jibb  [%fn atom atom]
  =/  impossible=itype:jibb  [%cell fn [%face %field void]]
  =/  singleton=itype:jibb  [%collection %list ~[void]]
  =/  proof=(unit [empty=? left=@ud])  (itype-empty-proof:jibb impossible ~ 4)
  =/  list-proof=(unit [empty=? left=@ud])  (itype-empty-proof:jibb singleton ~ 4)
  =/  fn-proof=(unit [empty=? left=@ud])  (itype-empty-proof:jibb [%fn void void] ~ 4)
  =/  unknown=(unit [empty=? left=@ud])  (itype-empty-proof:jibb [%var 23] ~ 4)
  =/  too-short=(unit [empty=? left=@ud])  (itype-empty-proof:jibb [%face %field void] ~ 1)
  =/  enough=(unit [empty=? left=@ud])  (itype-empty-proof:jibb [%face %field void] ~ 2)
  =/  empty-fit=ifit:jibb  (itype-fit:jibb void atom ~ 17)
  =/  nested-fit=ifit:jibb  (itype-fit:jibb impossible atom ~ 17)
  =/  atom-fit=ifit:jibb  (itype-fit:jibb atom void ~ 17)
  =/  cap=icaps:jibb  ~[['A' 23 *span:jibb]]
  =/  open-live=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb [%var 23] ~ ~ 4)
  =/  capital-live=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb [%var 23] ~ cap 4)
  =/  bound-empty=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb [%var 23] ~[[23 void]] cap 4)
  =/  opaque=itype:jibb  [%recursive %opaque %mold ~]
  =/  opaque-live=(unit [result=?(%yes %no %unknown) left=@ud])  (itype-inhabited-proof:jibb opaque ~ ~ 4)
  =/  rejected-cases=(unit (list itype:jibb))  (itype-live-cases:jibb ~[opaque] ~ ~ 4)
  =/  no-gates=igate-free:jibb  (gate-free-type:jibb impossible 8 ~)
  =/  list-gates=igate-free:jibb  (gate-free-type:jibb singleton 8 ~)
  =/  checks=(list [label=@t ok=?])
    :~  ['empty mold exported' =([%empty ~] typ.u.never)]
        ['live union selector preserves type' &(=(typ.u.split selected) =([%atom %t] product.typ.u.select))]
        ['overlap parses and is rejected' &(?=(%& -.parsed-overlap) ?=(%| -.invalid))]
        ['dead empty case parses and is rejected' &(?=(%& -.parsed-dead) ?=(%| -.dead-result))]
        ['missing live case parses and is rejected' &(?=(%& -.parsed-missing) ?=(%| -.missing-result))]
        ['standard list and unit identities checked' ?=(%& -.standard)]
        ['single null list gate keeps its exact sample and result' only-good]
        ['contextual single null list gate checks' ?=(^ only-context)]
        ['contextual single null list arm retains faces' (face-retained face-source iface.u.prep)]
        ['one null arm on inhabited list declines' &(?=(%& -.parsed-live) ?=(%| -.live-result))]
        ['one null arm on generic list declines' &(?=(%& -.parsed-open) ?=(%| -.open-result))]
        ['empty list nonempty arm parses and is rejected' &(?=(%& -.parsed-list) ?=(%| -.bad-list))]
        ['empty unit present arm parses and is rejected' &(?=(%& -.parsed-unit) ?=(%| -.bad-unit))]
        ['nested empty proof' ?:(?=(~ proof) | empty.u.proof)]
        ['list of empty is inhabited' ?:(?=(~ list-proof) | !empty.u.list-proof)]
        ['gate returning empty is not empty' ?:(?=(~ fn-proof) | !empty.u.fn-proof)]
        ['unbound type not proved empty' ?:(?=(~ unknown) | !empty.u.unknown)]
        ['unbound inference type reachability unknown' ?:(?=(~ open-live) | =(%unknown result.u.open-live))]
        ['written capital can have a value' ?:(?=(~ capital-live) | =(%yes result.u.capital-live))]
        ['bound empty capital is unreachable' ?:(?=(~ bound-empty) | =(%no result.u.bound-empty))]
        ['opaque recursion reachability unknown' ?:(?=(~ opaque-live) | =(%unknown result.u.opaque-live))]
        ['opaque union case declines coverage proof' ?=(~ rejected-cases)]
        ['one proof node exhausted' ?=(~ too-short)]
        ['two proof nodes succeed' ?:(?=(~ enough) | &(empty.u.enough =(0 left.u.enough)))]
        ['empty fits a concrete type' ?=(%ok -.empty-fit)]
        ['empty cell fits a concrete type' ?=(%ok -.nested-fit)]
        ['inhabited atom does not fit empty' ?=(%bad -.atom-fit)]
        ['empty gate-bearing cell is gate-free' &(=(%yes verdict.no-gates) !inhabited.no-gates)]
        ['list of empty is gate-free and inhabited' &(=(%yes verdict.list-gates) inhabited.list-gates)]
    ==
  =/  report=@t  (golden-types-in-context:jibb f good ~ ~ ~ ~ ~ ~)
  =/  overlap-report=@t  (golden-types-in-context:jibb f overlap ~ ~ ~ ~ ~ ~)
  =/  dead-report=@t  (golden-types-in-context:jibb f dead ~ ~ ~ ~ ~ ~)
  =/  missing-report=@t  (golden-types-in-context:jibb f missing ~ ~ ~ ~ ~ ~)
  =/  list-report=@t  (golden-types-with-prepared-prelude:jibb f list-dead ~ ~ ~ prep)
  =/  unit-report=@t  (golden-types-with-prepared-prelude:jibb f unit-dead ~ ~ ~ prep)
  =/  late-report=@t  (golden-types-with-prepared-prelude:jibb f late-cap ~ ~ ~ prep)
  (rap 3 ~[(of-wain:format (turn checks line)) '\0a' report '\0a' overlap-report '\0a' dead-report '\0a' missing-report '\0a' list-report '\0a' unit-report '\0a' late-report])
++  test-empty
  ^-  tang
  ?~  good  ~[leaf+"empty source missing"]
  ?~  overlap  ~[leaf+"overlap source missing"]
  ?~  dead  ~[leaf+"dead case source missing"]
  ?~  missing  ~[leaf+"missing case source missing"]
  ?~  standard-good  ~[leaf+"standard type source missing"]
  ?~  list-dead  ~[leaf+"empty list source missing"]
  ?~  unit-dead  ~[leaf+"empty unit source missing"]
  ?~  late-cap  ~[leaf+"late capital source missing"]
  ?~  list-live  ~[leaf+"inhabited list source missing"]
  ?~  list-open  ~[leaf+"generic list source missing"]
  ?~  face-source  ~[leaf+"face source missing"]
  ?~  expected  ~[leaf+"expected output missing"]
  =/  actual=@t
    (empty-output real-prelude real-internal (text good) (text overlap) (text dead) (text missing) (text standard-good) (text list-dead) (text unit-dead) (text late-cap) (text list-live) (text list-open) (text face-source))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"empty mold output differs from expected"]
  ~
--
