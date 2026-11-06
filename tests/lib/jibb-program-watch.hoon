::  Direct request-value watchability for a synthetic program over the real todo API.
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
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
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
::
++  program-watch-prepared
  |=  [public=@t private=@t]
  ^-  (unit iprelude:jibb)
  (prepare-groups:jibb-prelude-fixture public private ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
::
++  program-watch-detailed
  |=  [at=path src=@t externals=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  program-watch-source
  |=  [extra=@t subscriptions=@t]
  ^-  @t
  (program-watch-source-with-main extra subscriptions '++ main (program init update view subs)\0a')
++  program-watch-source-with-main
  |=  [extra=@t subscriptions=@t main=@t]
  ^-  @t
  %+  rap  3
  :~  '/= api /ui/api/todo\0a'
      '+$ model [count=@ud]\0a'
      '+$ msg\0a  [%got todos=(list item.api)]\0a  [%one item=todo-item.api]\0a  %other\0a'
      extra
      main
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
  =/  helper=@t  '/= api /ui/api/todo\0a++ request |= reply (todos.api reply)\0a'
  =/  modules=jbundle:jibb  ~[[api-at api] [/lib/watch-helper/jibb helper]]
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
    ?~  (program-value-watch-diagnostic:jibb checked ~ resolved iface.u.prepared graph.c)
      `label.c
    ~
  ?^  evidence-failures  ~[(weld "bad evidence passed watchability: " i.evidence-failures)]
  =/  ordinary-values=ienv:jibb
    (skim values.api-iface |=(entry=[name=term scheme=ischeme:jibb] !=(%todos name.entry)))
  =/  forged=ifile:jibb
    api-iface(values [[%todos [[%fn [%atom %t] [%atom %t]] ~ ~]] ordinary-values])
  ?~  (program-value-watch-diagnostic:jibb checked ~ ~[[%api forged]] iface.u.prepared u.graph.checked)
    ~["same-named non-derived member passed watchability"]
  =/  group=iprelude-group:jibb
    [%cached-api at.api-iface values.api-iface molds.api-iface derived.api-iface elaborations.api-iface dependencies.api-iface source.api-iface graph.api-iface ~]
  =/  cached-prelude=ifile:jibb  iface.u.prepared(groups [group groups.iface.u.prepared])
  ?~  (program-value-watch-diagnostic:jibb checked ~ ~[[%api forged]] cached-prelude u.graph.checked)
    ~["group closure replaced the selected forged interface"]
  =/  detached=ifile:jibb  api-iface(graph `u.graph.api-iface(requests ~))
  ?~  (program-value-watch-diagnostic:jibb checked ~ ~[[%api detached]] iface.u.prepared u.graph.checked)
    ~["evidence outside the selected interface passed watchability"]
  =/  incoherent=irequest-evidence:jibb  evidence(name.path.path %other)
  =/  api-others=(list irequest-evidence:jibb)
    (skim requests.u.graph.api-iface |=(r=irequest-evidence:jibb !&(=(api-at.r api-at) =(%todos name.r))))
  =/  incoherent-api=ifile:jibb  api-iface(graph `u.graph.api-iface(requests [incoherent api-others]))
  =/  incoherent-graph=irequest-graph:jibb  u.graph.checked(requests [incoherent others])
  ?~  (program-value-watch-diagnostic:jibb checked ~ ~[[%api incoherent-api]] iface.u.prepared incoherent-graph)
    ~["inconsistent request case names passed watchability"]
  =/  valid=(list [label=tape src=@t])
    :~  :-  "parameterized todo-by-id"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (todo-by-id.api 1 |=%one)]]\0a')
        :-  "diff changes"
        (program-watch-source '++ fold |= [d=[%todo-update todo-update.api] s=todos.api] s\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (changes.api |=%got fold)]]\0a')
        :-  "several watches"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (todos.api |=%got)] [%watch (todo-by-id.api 1 |=%one)]]\0a')
        :-  "timer with a watch"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%every ~s1 |=(now=@da %other)] [%watch (todos.api |=%got)]]\0a')
        :-  "request helper"
        (program-watch-source '++ request ^- (ask msg) (todos.api |=%got)\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request]]\0a')
        :-  "request alias"
        (program-watch-source '++ request todos.api\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (request |=%got)]]\0a')
    ==
  =.  valid
    %+  weld  valid
    :~  :-  "branch subscriptions"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ?- (eq count.state 0)\0a    %.y ~[[%watch (todos.api |=%got)]]\0a    %.n ~\0a')
        :-  "list concatenation"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    (weld ~[[%watch (todos.api |=%got)]] ~[[%every ~s1 |=(now=@da %other)]])\0a')
        :-  "identity helper"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (same (todos.api |=%got))]]\0a')
        :-  "independent repeated generic arguments"
        (program-watch-source '++ choose |= [a=A b=A] a\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (choose (todos.api |=%got) (pure %other))]]\0a')
        :-  "transitive imported helper"
        (cat 3 '/= helper /lib/watch-helper\0a' (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (request.helper |=%got)]]\0a'))
        :-  "cast faced holder"
        (program-watch-source '++ holder ^- [request=(ask msg) extra=@t] [(todos.api |=%got) "ok"]\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request.holder]]\0a')
        :-  "record change retains request"
        (program-watch-source '++ holder ^- [request=(ask msg) extra=@t] [(todos.api |=%got) "ok"]\0a++ revised holder(extra="changed")\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request.revised]]\0a')
        :-  "single faced holder"
        (program-watch-source '++ holder ^- [request=(ask msg)] (todos.api |=%got)\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request.holder]]\0a')
        :-  "program builder alias"
        (program-watch-source-with-main '++ build program\0a' direct-subs '++ main (build init update view subs)\0a')
        :-  "program value alias"
        (program-watch-source-with-main '++ p (program init update view subs)\0a' direct-subs '++ main p\0a')
        :-  "hand built program"
        (program-watch-source-with-main '' direct-subs '++ main ^- (program @t model msg) [init update view subs]\0a')
        :-  "subscriptions gate alias"
        (program-watch-source-with-main '++ listen subs\0a' direct-subs '++ main (program init update view listen)\0a')
    ==
  =/  valid-failures=(list tape)
    %+  murn  valid
    |=  c=[label=tape src=@t]
    =/  result=jfile-detailed-result:jibb
      (program-watch-detailed at src.c externals marks modules u.prepared)
    ?:  ?=(%| -.result)  `[(weld label.c (weld ": rejected: " (trip message.p.result)))]
    ~
  =/  negatives=(list [label=tape src=@t])
    :~  :-  "pure watch"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (pure %other)]]\0a')
        :-  "correctly typed hand-built agent"
        program-watch-agent-source
        :-  "multi-item subscriptions"
        (program-watch-source '++ first ^- (sub msg) [%watch (todos.api |=%got)]\0a++ second ^- (sub msg) [%watch (pure %other)]\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[first second]\0a')
    ==
  =.  negatives
    %+  weld  negatives
    :~  :-  "bad alternate branch"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ?- (eq count.state 0)\0a    %.y ~[[%watch (todos.api |=%got)]]\0a    %.n ~[[%watch (pure %other)]]\0a')
        :-  "proof cannot cross repeated arguments"
        (program-watch-source '++ choose |= [a=A b=A] b\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch (choose (todos.api |=%got) (pure %other))]]\0a')
        :-  "record change replaces proof"
        (program-watch-source '++ holder ^- [request=(ask msg) extra=@t] [(todos.api |=%got) "ok"]\0a++ revised holder(request=(pure %other))\0a' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    ~[[%watch request.revised]]\0a')
        :-  "bad concatenated request"
        (program-watch-source '' '++ subs |= state=model\0a  ^- (list (sub msg))\0a    (weld ~[[%watch (todos.api |=%got)]] ~[[%watch (pure %other)]])\0a')
    ==
  %+  weld  valid-failures
  %+  murn  negatives
  |=  c=[label=tape src=@t]
  =/  bad=jfile-detailed-result:jibb
    (program-watch-detailed at src.c externals marks modules u.prepared)
  ?:  ?=(%& -.bad)  `[(weld label.c ": accepted")]
  ?.  &((contains (trip message.p.bad) "an island may watch only a request whose origin is proved watchable") &((contains (trip message.p.bad) "watch subscription") (contains (trip message.p.bad) "this request has no watchability proof")))
    `[(weld label.c (weld ": wrong watch diagnostic: " (trip message.p.bad)))]
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
    (program-watch-errors prelude internal (text sur) (mark-text action) (mark-text todos) (mark-text update) (mark-text item) (text api))
  (turn failures |=(reason=tape leaf+reason))
--
