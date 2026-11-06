::  Partial API path analysis from real Ford-style todo marks.
/+  jibb, jibb-import, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  sur  %txt  /my-app/sur/todo/hoon
/*  action  %txt  /my-app/mar/todo-action/hoon
/*  todos  %txt  /my-app/mar/todos/hoon
/*  update  %txt  /my-app/mar/todo-update/hoon
/*  item  %txt  /my-app/mar/todo-item/hoon
/*  api  %txt  /my-app/ui/api/todo/jibb
/*  missing-decl  %txt  /tests/type-api-paths/missing-decl/txt
/*  value-clash  %txt  /tests/type-api-paths/value-clash/txt
/*  poke-clash  %txt  /tests/type-api-paths/poke-clash/txt
/*  scry  %txt  /tests/type-api-paths/scry/txt
/*  scry-bad  %txt  /tests/type-api-paths/scry-bad/txt
/*  expected  %txt  /tests/type-api-paths/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::  A mark's text without its /- lines, which Ford resolves and ride
::  can't parse.
++  mark-text
  |=  lines=wain
  ^-  @t
  (text (skip lines |=(line=@t =('/-' (end [3 2] line)))))
++  report
  ^-  @t
  (of-wain:format (fixture-output prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api) (text missing-decl) (text value-clash) (text poke-clash) (text scry) (text scry-bad)))
++  test-api-path-analysis
  ^-  tang
  ?~  sur  ~[leaf+"API path fixture sur is missing"]
  ?~  action  ~[leaf+"API path fixture action is missing"]
  ?~  todos  ~[leaf+"API path fixture todos is missing"]
  ?~  update  ~[leaf+"API path fixture update is missing"]
  ?~  item  ~[leaf+"API path fixture item is missing"]
  ?~  api  ~[leaf+"API path fixture api is missing"]
  ?~  missing-decl  ~[leaf+"API path fixture missing-decl is missing"]
  ?~  value-clash  ~[leaf+"API path fixture value-clash is missing"]
  ?~  poke-clash  ~[leaf+"API path fixture poke-clash is missing"]
  ?~  scry  ~[leaf+"API path fixture scry is missing"]
  ?~  scry-bad  ~[leaf+"API path fixture scry-bad is missing"]
  ?~  expected  ~[leaf+"API path expected output is missing"]
  =/  got=@t  report
  ::  A definite error's report spans several lines of expected.txt.
  ?.  =((to-wain:format got) expected)  ~[leaf+"API path analysis output differs from expected.txt"]
  ~
++  show-result
  |=  [label=@t result=(each (list iapi-path-typed:jibb) @t)]
  ^-  @t
  ?:  ?=(%| -.result)
    (crip "{(trip label)}: {(trip p.result)}")
  (crip "{(trip label)}: accepted {<(lent p.result)>} path cases")
++  show-path
  |=  item=iapi-path-typed:jibb
  ^-  @t
  =/  info=iapi-path:jibb  path.item
  =/  diff-text=tape
    (zing (turn diffs.item |=(d=iapi-mark-type:jibb " {(trip name.d)}={(show-itype:jibb typ.d ~)}")))
  =/  params=tape
    (zing (turn segments.info |=(s=pseg:jibb ?:(?=(%typed -.s) " {(trip name.s)}=@{(trip aura.s)}" ""))))
  (crip "{(trip name.info)}: full={(show-itype:jibb full.item ~)} diffs:{diff-text} parameters:{params}")
++  standard-unit
  |=  typ=itype:jibb
  ^-  ?
  ?.  ?=(%union -.typ)  |
  ?.  =(origin.typ `[/lib/jibb/prelude/jibb %unit])  |
  ?.  =(label.typ `%unit)  |
  =(args.typ ~[[%atom %t]])
++  unit-detail
  |=  result=(each (list iapi-path-typed:jibb) @t)
  ^-  @t
  ?:  ?=(%| -.result)  'unit marks: rejected'
  ?.  ?=([* ~] p.result)  'unit marks: wrong path count'
  =/  item=iapi-path-typed:jibb  i.p.result
  ?.  ?=([* ~] diffs.item)  'unit marks: wrong diff count'
  ?:  &((standard-unit full.item) (standard-unit typ.i.diffs.item))
    'unit marks: canonical'
  'unit marks: opaque'
++  unit-poke-detail
  |=  interface=(unit ifile:jibb)
  ^-  @t
  ?~  interface  'unit poke: rejected'
  =/  mark=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit-full u.interface)
  ?~  mark  'unit poke: missing export'
  ?.  ?=(~ vars.u.mark)  'unit poke: generic export'
  ?:  (standard-unit typ.u.mark)  'unit poke: canonical'
  'unit poke: opaque'
++  scry-detail
  |=  result=(each (list iapi-path-typed:jibb) @t)
  ^-  @t
  ?.  ?=([%& [* * * ~]] result)  'scry metadata: missing path'
  =/  item=iapi-path-typed:jibb  i.t.t.p.result
  =/  value=(unit (list pseg:jibb))  scry.path.item
  ?~  value  'scry metadata: missing'
  ?.  ?=([[%knot *] [%typed *] ~] u.value)  'scry metadata: unexpected segments'
  =/  segment=pseg:jibb  i.t.u.value
  ?>  ?=(%typed -.segment)
  (crip "scry metadata: {(trip name.segment)}=@{(trip aura.segment)}")
++  fixture-output
  |=  [prelude=@t internal=@t sur=@t action=@t todos=@t update=@t item=@t api=@t missing-decl=@t value-clash=@t poke-clash=@t scry-source=@t scry-bad-source=@t]
  ^-  wain
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~['prelude preparation failed']
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item))
  =/  marks=(list [mark=term result=*])  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  missing=(list [mark=term result=*])  ~[[%todo-action ma] [%todos mt] [%todo-item mi]]
  =/  duplicate=(list [mark=term result=*])  [[%todos mt] marks]
  =/  file=path  /ui/api/todo/jibb
  =/  ok  (api-path-analysis-source:jibb file api ~ marks ~ prepared)
  =/  unit-node=*  [%apply %unit ~[[%atom %t ~]]]
  =/  unit-marks=imark-externals:jibb  ~[[%unit-full [%& unit-node]] [%unit-diff [%& unit-node]]]
  =/  unit-api=@t  '/% %unit-full\0a/% %unit-diff\0a+$ paths [%items /items (facts unit-full unit-diff)]\0a'
  =/  unit-ok  (api-path-analysis-source:jibb /ui/api/unit/jibb unit-api ~ unit-marks ~ prepared)
  =/  unit-poke-source=@t  '/% %unit-full\0a+$ poke unit-full\0a'
  =/  unit-poke-parsed=(each module:jibb error:jibb)  (parse:jibb /ui/api/unit/jibb unit-poke-source)
  =/  unit-poke=(unit ifile:jibb)
    ?:  ?=(%| -.unit-poke-parsed)  ~
    (api-poke-interface:jibb /ui/api/unit/jibb p.unit-poke-parsed unit-marks values.u.prepared molds.u.prepared `iface.u.prepared)
  =/  miss  (api-path-analysis-source:jibb file api ~ missing ~ prepared)
  =/  dup  (api-path-analysis-source:jibb file api ~ duplicate ~ prepared)
  =/  undeclared  (api-path-analysis-source:jibb file missing-decl ~ marks ~ prepared)
  =/  clash  (api-path-analysis-source:jibb file value-clash ~ marks ~ prepared)
  =/  poke  (api-path-analysis-source:jibb file poke-clash ~ marks ~ prepared)
  =/  wrong  (api-path-analysis-source:jibb /ui/todo/jibb api ~ marks ~ prepared)
  =/  unprepared  (api-path-analysis-source:jibb file api ~ marks ~ ~)
  =/  scry-ok  (api-path-analysis-source:jibb file scry-source ~ marks ~ prepared)
  =/  scry-bad  (api-path-analysis-source:jibb file scry-bad-source ~ marks ~ prepared)
  =/  private-source=@t  (cat 3 '/= secret /lib/jibb/internal\0a' api)
  =/  private  (api-path-analysis-source:jibb file private-source ~ marks ~ prepared)
  =/  indirect-source=@t  (cat 3 '/= local /ui/local\0a' api)
  =/  indirect-modules=jbundle:jibb  ~[[/ui/local/jibb '/= secret /lib/jibb/internal\0a++ thing "x"\0a']]
  =/  indirect  (api-path-analysis-source:jibb file indirect-source ~ marks indirect-modules prepared)
  =/  cycle-source=@t  (cat 3 '/= aa /ui/aa\0a' api)
  =/  cycle-modules=jbundle:jibb  ~[[/ui/aa/jibb '/= bb /ui/bb\0a++ first "x"\0a'] [/ui/bb/jibb '/= aa /ui/aa\0a++ second "x"\0a']]
  =/  cycle  (api-path-analysis-source:jibb file cycle-source ~ marks cycle-modules prepared)
  =/  lines=wain
    :~  'partial API path analysis only; no module check or request interface'
        (show-result 'todo' ok)
    ==
  =.  lines  ?:(?=(%& -.ok) (weld lines (turn p.ok show-path)) lines)
  =.  lines  ?:(?=(%& -.unit-ok) (weld lines (turn p.unit-ok show-path)) lines)
  (weld lines ~[(unit-detail unit-ok) (unit-poke-detail unit-poke) (show-result 'missing mark' miss) (show-result 'duplicate mark' dup) (show-result 'undeclared mark' undeclared) (show-result 'value collision' clash) (show-result 'poke collision' poke) (show-result 'scry matching parameters' scry-ok) (scry-detail scry-ok) (show-result 'scry unknown parameter' scry-bad) (show-result 'wrong path' wrong) (show-result 'missing prelude' unprepared) (show-result 'private import' private) (show-result 'indirect private import' indirect) (show-result 'cycle' cycle)])
--
