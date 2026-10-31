::  Path-declaration evidence retains sources, scope and reader-derived graphs.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  api  %txt  /tests/type-api-paths/scry/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  synthetic-evidence-status
  ^-  @t
  ::  A deliberately partial prelude preserves names even when inference fails.
  =/  public=@t  '++ forbidden (missing "x")\0a+$ hidden (missing @t)\0a'
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude:jibb public)
  ?~  prepared  'partial prelude did not prepare'
  ?.  (lien values.u.prepared |=(x=term =(%forbidden x)))  'unavailable value not reserved'
  ?.  ?=(~ (ienv-lookup:jibb %forbidden values.iface.u.prepared))  'forbidden value unexpectedly inferred'
  ?.  (lien molds.u.prepared |=(x=term =(%hidden x)))  'unavailable mold not reserved'
  ?.  ?=(~ (find-jibb-mold:jibb %hidden iface.u.prepared))  'hidden mold unexpectedly inferred'
  =/  api=@t  '/= dep /ui/dep\0a/% %todo\0a+$ paths [%items /items todo]\0a'
  =/  dep=@t  '/= leaf /ui/leaf\0a++ value thing.leaf\0a'
  =/  leaf=@t  '++ thing "x"\0a'
  =/  marks=imark-externals:jibb  ~[[%todo [%& [%atom %t ~]]]]
  =/  externals=iexternals:jibb  ~[[%unused %other [%& [%atom %p ~]]]]
  =/  modules=jbundle:jibb  ~[[/ui/dep/jibb dep] [/ui/leaf/jibb leaf]]
  =/  result  (api-path-evidence-source:jibb /ui/api/demo/jibb api externals marks modules prepared)
  ?:  ?=(%| -.result)  p.result
  =/  evidence=iapi-path-evidence:jibb  p.result
  ?.  =(at.evidence /ui/api/demo/jibb)  'API path not retained'
  ?.  =(source.evidence api)  'API source not retained'
  ?.  =(prepared.evidence u.prepared)  'complete prepared prelude not retained'
  ?.  =(source.iface.prepared.evidence `public)  'prelude source not retained'
  ?.  =(externals.evidence externals)  'external reader graph not retained'
  ?.  =(marks.evidence marks)  'mark reader graph not retained'
  =/  d=(unit ifile:jibb)  (find-jibb-cache:jibb /ui/dep/jibb dependencies.evidence)
  ?~  d  'dependency not retained'
  ?.  =(source.u.d `dep)  'dependency source not retained'
  =/  l=(unit ifile:jibb)  (find-jibb-cache:jibb /ui/leaf/jibb dependencies.evidence)
  ?~  l  'transitive dependency not retained'
  ?.  =(source.u.l `leaf)  'transitive dependency source not retained'
  ?.  ?=([* ~] paths.evidence)  'incorrect path count'
  ?.  =(full.path.i.paths.evidence %todo)  'full mark name not retained'
  ?.  =([%atom %t] full.i.paths.evidence)  'full mark type not retained'
  ?.  =(%watchable (api-path-watchability:jibb `evidence %items))  'normal path not watchable'
  ?.  =(%unknown (api-path-watchability:jibb `evidence %missing))  'missing path not unknown'
  ?.  =(%unknown (api-path-watchability:jibb ~ %items))  'missing evidence not unknown'
  =/  dup=iapi-path-evidence:jibb  evidence(paths [i.paths.evidence paths.evidence])
  ?.  =(%unknown (api-path-watchability:jibb `dup %items))  'duplicate case query not unknown'
  =/  scry=@t  '/% %todo\0a+$ paths [%items /items todo scry=/peek]\0a'
  =/  sr  (api-path-evidence-source:jibb /ui/api/demo/jibb scry ~ marks ~ prepared)
  ?:  ?=(%| -.sr)  'scry declaration rejected'
  ?.  =(%not-watchable (api-path-watchability:jibb `p.sr %items))  'scry path watchable'
  =/  clash=@t  '/% %todo\0a+$ paths [%forbidden /one todo]\0a'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb clash ~ marks ~ prepared))  'reserved value did not reject derived path'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb api externals ~ modules prepared))  'missing mark accepted'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb api externals (weld marks marks) modules prepared))  'duplicate mark accepted'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/demo/jibb api externals marks modules prepared))  'non-API path accepted'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb api externals marks modules ~))  'missing prelude accepted'
  =/  direct=@t  '/= secret /lib/jibb/internal\0a/% %todo\0a+$ paths [%items /items todo]\0a'
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb direct ~ marks ~ prepared))  'direct private import accepted'
  =/  indirect=jbundle:jibb  ~[[/ui/dep/jibb '/= secret /lib/jibb/internal\0a++ value "x"\0a']]
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb api ~ marks indirect prepared))  'transitive private import accepted'
  =/  cyclic=jbundle:jibb  ~[[/ui/dep/jibb '/= back /ui/dep\0a++ value "x"\0a']]
  ?.  ?=([%| *] (api-path-evidence-source:jibb /ui/api/demo/jibb api ~ marks cyclic prepared))  'cycle accepted'
  'normal watchable; scry not watchable; missing and duplicate unknown'
++  real-evidence-status
  |=  [prelude=@t internal=@t sur=@t action=@t todos=@t update=@t item=@t api=@t]
  ^-  @t
  =/  prepared  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  'prelude did not prepare'
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item))
  =/  marks=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  result  (api-path-evidence-source:jibb /ui/api/todo/jibb api ~ marks ~ prepared)
  ?:  ?=(%| -.result)  p.result
  =/  evidence=iapi-path-evidence:jibb  p.result
  ?.  =(source.evidence api)  'API source not retained'
  ?.  =(marks.evidence marks)  'mark reader graphs not retained'
  ?.  =((lent paths.evidence) 3)  'incorrect path count'
  =/  changes=(list iapi-path-typed:jibb)
    (skim paths.evidence |=(p=iapi-path-typed:jibb =(%changes name.path.p)))
  ?.  ?=([* ~] changes)  'changes path missing'
  ?.  =(full.path.i.changes %todos)  'full mark missing'
  ?.  ?=([* ~] diffs.i.changes)  'diff missing'
  ?.  =(name.i.diffs.i.changes %todo-update)  'diff mark missing'
  =/  by-id=(list iapi-path-typed:jibb)
    (skim paths.evidence |=(p=iapi-path-typed:jibb =(%todo-by-id name.path.p)))
  ?.  ?=([* ~] by-id)  'by-id path missing'
  ?.  ?=(^ scry.path.i.by-id)  'scry path missing'
  =/  typed=(list pseg:jibb)  (skim segments.path.i.by-id |=(p=pseg:jibb ?=(%typed -.p)))
  ?.  ?=([* ~] typed)  'typed path missing'
  ?>  ?=(%typed -.i.typed)
  ?.  &(=(name.i.typed %id) =(aura.i.typed %ud))  'typed path incorrect'
  ?.  =(%watchable (api-path-watchability:jibb `evidence %todos))  'watchable todos not proved'
  ?.  =(%not-watchable (api-path-watchability:jibb `evidence %todo-by-id))  'scry-only case incorrectly classified'
  ?.  =(%unknown (api-path-watchability:jibb `evidence %missing))  'unknown case incorrectly classified'
  =/  original  (api-path-analysis-source:jibb /ui/api/todo/jibb api ~ marks ~ prepared)
  ?:  ?=(%| -.original)  'original analyzer rejected todo source'
  ?.  =(paths.evidence p.original)  'typed path evidence differs from original analyzer'
  ?.  =(prepared.evidence u.prepared)  'actual complete prepared prelude not retained'
  =/  todo-full=(unit itype:jibb)  (find-imported-mark:jibb %todos marks ~[%todo-action %todos %todo-update %todo-item])
  =/  todo-diff=(unit itype:jibb)  (find-imported-mark:jibb %todo-update marks ~[%todo-action %todos %todo-update %todo-item])
  ?~  todo-full  'real full reader type unavailable'
  ?~  todo-diff  'real diff reader type unavailable'
  ?.  =(full.i.changes u.todo-full)  'real full reader type differs'
  ?.  =(typ.i.diffs.i.changes u.todo-diff)  'real diff reader type differs'
  'real todo path evidence passed'
++  test-api-evidence-synthetic
  ^-  tang
  =/  outcome=@t  synthetic-evidence-status
  ?:  =(outcome 'normal watchable; scry not watchable; missing and duplicate unknown')  ~
  ~[leaf+(trip outcome)]
++  test-api-evidence-real
  ^-  tang
  ?~  sur  ~[leaf+"API evidence fixture sur is missing"]
  ?~  action  ~[leaf+"API evidence fixture action is missing"]
  ?~  todos  ~[leaf+"API evidence fixture todos is missing"]
  ?~  update  ~[leaf+"API evidence fixture update is missing"]
  ?~  item  ~[leaf+"API evidence fixture item is missing"]
  ?~  api  ~[leaf+"API evidence fixture api is missing"]
  =/  outcome=@t  (real-evidence-status prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api))
  ?:  =(outcome 'real todo path evidence passed')  ~
  ~[leaf+(trip outcome)]
--
