::  Source-backed mold analysis of the actual todo model; not island checking.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  api  %txt  /tests/type-api-paths/api/txt
/*  source  %txt  /tests/type-gate-free/todo/txt
/*  gate-source  %txt  /tests/type-gate-free/todo-gate/txt
/*  noun-source  %txt  /tests/type-gate-free/todo-noun/txt
/*  expected  %txt  /tests/type-gate-free/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  gate-free-source-report
  |=  [public=@t private=@t sur-text=@t action-text=@t todos-text=@t update-text=@t item-text=@t api-text=@t source-text=@t gate-text=@t noun-text=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  'prelude unavailable'
  =/  todo=type  -:(ride -:!>(..zuse) sur-text)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action-text))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos-text))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update-text))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item-text))
  =/  marks=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  inputs=iexternals:jibb  ~[[%todo %item item-input]]
  =/  modules=jbundle:jibb  ~[[/ui/api/todo/jibb api-text]]
  =/  at=path  /ui/todo-list/jibb
  =/  model  (gate-free-mold-source:jibb at source-text %model inputs marks modules prepared 256)
  ?:  ?=(%| -.model)  'todo model unavailable'
  ?.  =(%yes verdict.result.p.model)  'todo model not proven gate-free'
  ?.  &(=(at.p.model at) =(source.p.model source-text) =(name.p.model %model) =(prepared.p.model u.prepared) =(externals.p.model inputs) =(marks.p.model marks) =(modules.p.model modules))  'source evidence changed'
  ?~  dependencies.p.model  'resolved dependency evidence missing'
  ?.  ?=(%cell -.typ.mold.p.model)  'selected model scheme missing'
  ?.  &(=(256 requested.p.model) =(256 budget.p.model))  'requested budget not retained'
  =/  callback  (gate-free-mold-source:jibb at gate-text %model inputs marks modules prepared 256)
  ?:  ?=(%| -.callback)  'callback model unavailable'
  ?.  =(%no verdict.result.p.callback)  'callback was not found'
  ?~  path.result.p.callback  'callback path missing'
  ?.  (lien u.path.result.p.callback |=(part=igf-segment:jibb ?=([%field %callback] part)))  'callback field not in witness'
  =/  noun  (gate-free-mold-source:jibb at noun-text %model inputs marks modules prepared 256)
  ?:  ?=(%| -.noun)  'noun model unavailable'
  ?.  =(%unknown verdict.result.p.noun)  'noun model not unknown'
  =/  tiny=@t  '+$ sample @t\0a'
  =/  low  (gate-free-mold-source:jibb /tests/tiny/jibb tiny %sample ~ ~ ~ prepared 0)
  ?:  ?=(%| -.low)  'zero fuel unavailable'
  ?.  &(=(%unknown verdict.result.p.low) =(0 budget.p.low))  'zero fuel not unknown'
  =/  capped  (gate-free-mold-source:jibb /tests/tiny/jibb tiny %sample ~ ~ ~ prepared 999)
  ?:  ?=(%| -.capped)  'large fuel unavailable'
  ?.  &(=(999 requested.p.capped) =(256 budget.p.capped) =(%yes verdict.result.p.capped) =(255 left.result.p.capped))  'fuel cap incorrect'
  =/  matched  (gate-free-mold-source:jibb /tests/tiny/jibb tiny %sample ~ ~ ~[[/tests/tiny/jibb tiny]] prepared 256)
  ?:  ?=(%| -.matched)  'matching root source rejected'
  =/  unused-sur=@t  '/- unused\0a+$ sample @t\0a'
  =/  unused  (gate-free-mold-source:jibb /tests/tiny/jibb unused-sur %sample ~ ~ ~ prepared 256)
  ?:  ?=(%| -.unused)  'unused sur source unexpectedly required'
  =/  cycle-source=@t  '/= child /tests/child\0a+$ sample @t\0a'
  =/  child-source=@t  '/= root /tests/tiny\0a+$ child @t\0a'
  =/  cycle  (gate-free-mold-source:jibb /tests/tiny/jibb cycle-source %sample ~ ~ ~[[/tests/child/jibb child-source]] prepared 256)
  ?.  ?=(%| -.cycle)  'root import cycle accepted'
  =/  unprepared  (gate-free-mold-source:jibb /tests/tiny/jibb tiny %sample ~ ~ ~ ~ 256)
  ?.  ?=(%| -.unprepared)  'missing prelude accepted'
  =/  cases=(list [name=@t path=path src=@t mold=term external=iexternals:jibb mark=imark-externals:jibb bundle=jbundle:jibb])
    :~  ['missing mold' at source-text %missing inputs marks modules]
        ['missing API' at source-text %model inputs marks ~]
        ['missing mark' at source-text %model inputs (skim marks |=(m=[mark=term result=*] !=(%todo-update mark.m))) modules]
        ['root mismatch' at source-text %model inputs marks [[at gate-text] modules]]
        ['duplicate root' at source-text %model inputs marks [[at source-text] [at source-text] modules]]
        ['duplicate field' at (cat 3 source-text '\0a+$ duplicate [x=@t x=@p]\0a') %model inputs marks modules]
        ['invalid syntax' at '++ incomplete |=' %model inputs marks modules]
        ['private root' /lib/jibb/internal/jibb source-text %model inputs marks modules]
        ['API root' /ui/api/todo/jibb source-text %model inputs marks modules]
        ['store root poke' /ui/stores/cart/jibb '+$ poke @t\0a' %poke ~ ~ ~]
    ==
  =/  errors=(list @t)
    %+  turn  cases
    |=  c=[name=@t path=path src=@t mold=term external=iexternals:jibb mark=imark-externals:jibb bundle=jbundle:jibb]
    =/  got  (gate-free-mold-source:jibb path.c src.c mold.c external.c mark.c bundle.c prepared 256)
    ?:  ?=(%| -.got)  ''
    (cat 3 name.c ': unexpectedly succeeded')
  =/  errors  (skim errors |=(x=@t !=(x '')))
  ?^  errors  (of-wain:format errors)
  'todo model: gate-free\0acallback model: gate at callback\0anoun model: unknown\0azero fuel: unknown\0aoversized fuel: capped\0ainvalid inputs: rejected\0asource evidence: retained\0amatching root and unused sur: accepted\0aroot import cycle: rejected'
++  test-gate-free-source
  ^-  tang
  =/  actual  (gate-free-source-report prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api) (text source) (text gate-source) (text noun-source))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)  ~[leaf+"gate-free mold report differs from expected"]
  ~
--
