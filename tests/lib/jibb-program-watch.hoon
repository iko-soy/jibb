::  Direct request-value watchability for a synthetic program over the real todo API.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  sur  %txt  /tests/type-api-paths/todo-sur/txt
/*  action  %txt  /tests/type-api-paths/todo-action/txt
/*  todos  %txt  /tests/type-api-paths/todos/txt
/*  update  %txt  /tests/type-api-paths/todo-update/txt
/*  item  %txt  /tests/type-api-paths/todo-item/txt
/*  api  %txt  /tests/type-api-paths/api/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  program-watch-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-prelude-with-internal:jibb public private)
::
++  program-watch-detailed
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-watch-source
  |=  [extra=@t subscriptions=@t]
  ^-  @t
  %+  rap  3
  :~  '/= api /ui/api/todo\0a'
      '+$ model [count=@ud]\0a'
      '+$ msg\0a  [%got todos=(list item.api)]\0a  [%one item=todo-item.api]\0a  %other\0a'
      extra
      '++ main (program init update view subs)\0a'
      '++ init |= input=@t ^- model [count=0]\0a'
      '++ update |= [m=msg state=model]\0a  ^- [model (list (cmd msg))] [state ~]\0a'
      '++ view |= state=model ^- (element msg) (text "view")\0a'
      subscriptions
  ==
::
++  program-watch-agent-source
  ^-  @t
  %+  rap  3
  :~  '/= api /ui/api/todo\0a'
      '+$ model [count=@ud]\0a'
      '++ receive |= input=[mark=@tas state=(unit *) fact=*]\0a  ^- [state=* message=@t] [state=0 message="ok"]\0a'
      '++ request-path ^- path ~[%todos]\0a'
      '++ request ^- (ask @t)\0a  [%agent api="/ui/api/todo" case=%todos agent=%todo path=request-path scry=~ receive=receive]\0a'
      '++ main (program init update view subs)\0a'
      '++ init |= input=@t ^- model [count=0]\0a'
      '++ update |= [m=@t state=model]\0a  ^- [model (list (cmd @t))] [state ~]\0a'
      '++ view |= state=model ^- (element @t) (text "ok")\0a'
      '++ subs |= state=model\0a  ^- (list (sub @t))\0a    ~[[%watch request]]\0a'
  ==
::
++  program-watch-errors
  |=  [public=@t private=@t sur=@t action=@t todos=@t update=@t item=@t api=@t]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)  (program-watch-prepared public private)
  ?~  prepared  ~["synthetic program prelude did not prepare"]
  =/  todo=type  -:(ride -:!>(..zuse) sur)
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject action))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject todos))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject update))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject item))
  =/  marks=imark-externals:jibb  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  =/  externals=iexternals:jibb  ~[[%todo %item item-input]]
  =/  api-at=path  /ui/api/todo/jibb
  =/  api-result=jfile-detailed-result:jibb
    (program-watch-detailed api-at api externals marks ~ u.prepared)
  ?:  ?=(%| -.api-result)  ~["real todo API did not check"]
  =/  api-iface=ifile:jibb  iface.p.api-result
  ?~  graph.api-iface  ~["real todo API evidence is missing"]
  =/  direct-subs=@t  '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (todos.api |=%got)]]\0a'
  =/  island=@t  (program-watch-source '' direct-subs)
  =/  at=path  /tests/program-watch/island/jibb
  =/  modules=jbundle:jibb  ~[[api-at api]]
  =/  detailed=jfile-detailed-result:jibb
    (program-watch-detailed at island externals marks modules u.prepared)
  ?:  ?=(%| -.detailed)  ~[(weld "direct request watch was rejected: " (trip message.p.detailed))]
  =/  checked=ifile:jibb  iface.p.detailed
  ?~  graph.checked  ~["program request graph evidence is missing"]
  =/  legacy=jfile-result:jibb
    (infer-jibb-file:jibb at island externals marks modules ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.legacy)  ~["legacy adapter rejected a direct request watch"]
  ?.  =(values.checked values.iface.p.legacy)  ~["structured and legacy interface values differ"]
  =/  subs=(unit ischeme:jibb)  (ienv-lookup:jibb %subs values.checked)
  =/  main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.checked)
  ?~  subs  ~["subs interface is missing"]
  ?~  main  ~["main interface is missing"]
  ?.  &(?=(~ vars.u.subs) ?=(~ (itype-vars:jibb typ.u.subs)))  ~["subs interface is not closed"]
  =/  subs-fields=(list itype:jibb)  (record-fields-named:jibb %subs typ.u.main ~)
  ?.  ?=([* ~] subs-fields)  ~["closed program does not have one subs field"]
  =/  model=(unit ischeme:jibb)  (find-jibb-mold:jibb %model checked)
  =/  msg=(unit ischeme:jibb)  (find-jibb-mold:jibb %msg checked)
  =/  list-template=(unit ischeme:jibb)  (find-jibb-mold:jibb %list iface.u.prepared)
  =/  sub=(unit ischeme:jibb)  (find-jibb-mold:jibb %sub iface.u.prepared)
  ?~  model  ~["model mold is missing"]
  ?~  msg  ~["message mold is missing"]
  ?~  list-template  ~["list mold is missing"]
  ?~  sub  ~["sub mold is missing"]
  =/  message-sub=(unit itype:jibb)  (template-apply:jibb u.sub ~[typ.u.msg])
  ?~  message-sub  ~["message subscription type did not instantiate"]
  =/  subs-result=(unit itype:jibb)  (template-apply:jibb u.list-template ~[u.message-sub])
  ?~  subs-result  ~["subscription list type did not instantiate"]
  =/  expected-subs=itype:jibb  [%fn typ.u.model u.subs-result]
  ?.  =(typ.u.subs expected-subs)  ~["subs interface has the wrong exact type"]
  ?.  =((lent requests.u.graph.checked) (lent requests.u.graph.api-iface))  ~["merged API evidence count differs"]
  ?.  (levy requests.u.graph.checked |=(r=irequest-evidence:jibb (lien requests.u.graph.api-iface |=(a=irequest-evidence:jibb =(r a)))))  ~["merged API evidence differs"]
  =/  matching=(list irequest-evidence:jibb)
    (skim requests.u.graph.checked |=(r=irequest-evidence:jibb &(=(api-at.r api-at) =(%todos name.r))))
  ?.  ?=([* ~] matching)  ~["direct todos evidence is not unique"]
  =/  evidence=irequest-evidence:jibb  i.matching
  ?.  =(api-source.evidence api)  ~["request evidence does not retain the exact API source"]
  ?.  &(?=(~ scry.path.path.evidence) ?=(~ diffs.path.evidence) ?=(~ diffs.path.path.evidence))
    ~["plain todos evidence acquired scry or diffs"]
  ?:  (lien segments.path.path.evidence |=(p=pseg:jibb !?=(%knot -.p)))  ~["plain todos evidence acquired parameters"]
  =/  consumer-at=path  /tests/program-watch/consumer/jibb
  =/  consumer=@t  '/= island-prog /tests/program-watch/island\0a++ imported subs.island-prog\0a'
  =/  imported=jfile-detailed-result:jibb
    (program-watch-detailed consumer-at consumer externals marks [[at island] modules] u.prepared)
  ?:  ?=(%| -.imported)  ~["downstream program import was rejected"]
  =/  imported-subs=(unit ischeme:jibb)  (ienv-lookup:jibb %imported values.iface.p.imported)
  ?~  imported-subs  ~["downstream imported subs is missing"]
  =/  expected-import=itype:jibb  (itype-in-import:jibb typ.u.subs checked %island-prog `iface.u.prepared)
  ?.  &(?=(~ vars.u.imported-subs) =(typ.u.imported-subs expected-import))  ~["downstream imported subs type differs"]
  =/  parsed  (parse:jibb at island)
  ?:  ?=(%| -.parsed)  ~["program source no longer parses"]
  =/  main-def=(unit def:jibb)  (program-main-def:jibb defs.p.parsed)
  ?~  main-def  ~["program main definition is missing"]
  =/  parts  (program-main-parts:jibb u.main-def)
  ?~  parts  ~["program main parts are missing"]
  =/  resolved=ijimports:jibb  ~[[%api api-iface]]
  =/  others=(list irequest-evidence:jibb)
    (skim requests.u.graph.checked |=(r=irequest-evidence:jibb !&(=(api-at.r api-at) =(%todos name.r))))
  =/  missing=irequest-graph:jibb  u.graph.checked(requests others)
  =/  mismatch=irequest-graph:jibb  u.graph.checked(requests [evidence(api-source 'mismatched') others])
  =/  scry=irequest-graph:jibb  u.graph.checked(requests [evidence(scry.path.path `~[[%knot ~.peek]]) others])
  =/  ambiguous=irequest-graph:jibb  u.graph.checked(requests [evidence requests.u.graph.checked])
  =/  evidence-cases=(list [label=tape graph=irequest-graph:jibb])
    :~  ["missing evidence" missing]
        ["API-source mismatch" mismatch]
        ["scry declaration evidence" scry]
        ["ambiguous evidence" ambiguous]
    ==
  =/  evidence-failures=(list tape)
    %+  murn  evidence-cases
    |=  c=[label=tape graph=irequest-graph:jibb]
    ?:  (program-main-closed:jibb u.parts defs.p.parsed values.checked `iface.u.prepared resolved graph.c)
      `label.c
    ~
  ?^  evidence-failures  ~[(weld "bad evidence passed watchability: " i.evidence-failures)]
  =/  ordinary-values=ienv:jibb
    (skim values.api-iface |=(entry=[name=term scheme=ischeme:jibb] !=(%todos name.entry)))
  =/  forged=ifile:jibb
    api-iface(values [[%todos [[%fn [%atom %t] [%atom %t]] ~]] ordinary-values])
  ?:  (program-main-closed:jibb u.parts defs.p.parsed values.checked `iface.u.prepared ~[[%api forged]] u.graph.checked)
    ~["same-named non-derived member passed watchability"]
  =/  detached=ifile:jibb  api-iface(graph `u.graph.api-iface(requests ~))
  ?:  (program-main-closed:jibb u.parts defs.p.parsed values.checked `iface.u.prepared ~[[%api detached]] u.graph.checked)
    ~["evidence outside the selected interface passed watchability"]
  =/  incoherent=irequest-evidence:jibb  evidence(name.path.path %other)
  =/  api-others=(list irequest-evidence:jibb)
    (skim requests.u.graph.api-iface |=(r=irequest-evidence:jibb !&(=(api-at.r api-at) =(%todos name.r))))
  =/  incoherent-api=ifile:jibb  api-iface(graph `u.graph.api-iface(requests [incoherent api-others]))
  =/  incoherent-graph=irequest-graph:jibb  u.graph.checked(requests [incoherent others])
  ?:  (program-main-closed:jibb u.parts defs.p.parsed values.checked `iface.u.prepared ~[[%api incoherent-api]] incoherent-graph)
    ~["inconsistent request case names passed watchability"]
  =/  kind-error=@t  (crip "module kind needs unsupported inference: {(spud at)}")
  =/  negatives=(list [label=tape src=@t])
    :~  :-  "pure watch"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (pure %other)]]\0a')
        :-  "correctly typed hand-built agent"
        program-watch-agent-source
        :-  "request helper"
        (program-watch-source '++ request ^- (ask msg) (todos.api |=%got)\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request]]\0a')
        :-  "request alias"
        (program-watch-source '++ request todos.api\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (request |=%got)]]\0a')
        :-  "parameterized todo-by-id"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (todo-by-id.api 1 |=%one)]]\0a')
        :-  "diff changes"
        (program-watch-source '++ fold |= [d=[%todo-update todo-update.api] s=todos.api] s\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (changes.api |=%got fold)]]\0a')
        :-  "multi-item subscriptions"
        (program-watch-source '++ first ^- (sub msg) [%watch (todos.api |=%got)]\0a++ second ^- (sub msg) [%watch (pure %other)]\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[first second]\0a')
    ==
  %+  weld  (turn evidence-failures |=(reason=tape reason))
  %+  murn  negatives
  |=  c=[label=tape src=@t]
  =/  bad=jfile-detailed-result:jibb
    (program-watch-detailed at src.c externals marks modules u.prepared)
  ?:  ?=(%& -.bad)  `[(weld label.c ": accepted")]
  ?.  =(message.p.bad kind-error)  `[(weld label.c ": did not reach watchability")]
  ~
::
++  test-program-watch
  ^-  tang
  ?~  sur  ~[leaf+"program-watch fixture sur is missing"]
  ?~  action  ~[leaf+"program-watch fixture action is missing"]
  ?~  todos  ~[leaf+"program-watch fixture todos is missing"]
  ?~  update  ~[leaf+"program-watch fixture update is missing"]
  ?~  item  ~[leaf+"program-watch fixture item is missing"]
  ?~  api  ~[leaf+"program-watch fixture api is missing"]
  =/  failures=(list tape)
    (program-watch-errors prelude internal (text sur) (text action) (text todos) (text update) (text item) (text api))
  (turn failures |=(reason=tape leaf+reason))
--
