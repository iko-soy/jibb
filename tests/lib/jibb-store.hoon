::  Unchanged cart store and basket, derived requests, and rejection guards.
/+  jibb
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  cart      %txt   /my-app/ui/stores/cart/jibb
/*  basket    %txt   /my-app/ui/basket/jibb
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  store-detailed
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-detailed-result:jibb
  (infer-jibb-file-detailed:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  store-legacy
  |=  [at=path src=@t modules=jbundle:jibb prepared=iprelude:jibb]
  ^-  jfile-result:jibb
  (infer-jibb-file:jibb at src ~ ~ modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
::
++  store-cart-source
  |=  [poke=@t main=@t init=@t update=@t extra=@t]
  ^-  @t
  %+  rap  3
  :~  '+$ state [items=(list @t) open=?]\0a'
      poke  main  init  update  extra
  ==
::
++  store-basket-source
  |=  [update=@t subs=@t extra=@t]
  ^-  @t
  %+  rap  3
  :~  '/= cart /ui/stores/cart\0a'
      '++ main (program init update view subs)\0a'
      '+$ model [cart=state.cart note=@t]\0a'
      '+$ msg\0a  [%noted text=@t]\0a  %add\0a  %toggle\0a  [%got cart=state.cart]\0a  [%acked err=(unit @t)]\0a'
      '++ init |= ~\0a  [[~ %.n] ""]\0a'
      update  subs
      '++ view |= m=model\0a  column ~[gap+%s1] ~[\0a    (text "{(lent items.cart.m)} items")\0a    field "Item" note.m |=%noted\0a    button "Add" %add\0a'
      extra
  ==
::
++  store-consumer-source
  ^-  @t
  %+  rap  3
  :~  '/= cart /ui/stores/cart\0a'
      '+$ local-state state.cart\0a'
      '+$ local-action poke.cart\0a'
      '++ imported-main main.cart\0a'
      '++ imported-request |= reply=$-(local-state M) (state.cart reply)\0a'
      '++ imported-poke |= action=local-action (poke.cart action same)\0a'
  ==
::
++  store-rejections
  |=  [cases=(list [label=tape at=path src=@t modules=jbundle:jibb]) prepared=iprelude:jibb]
  ^-  (list tape)
  %+  murn  cases
  |=  c=[label=tape at=path src=@t modules=jbundle:jibb]
  =/  result=jfile-detailed-result:jibb
    (store-detailed at.c src.c modules.c prepared)
  ?:  ?=(%| -.result)  ~
  `(weld label.c ": accepted")
::
++  store-evidence-failures
  |=  [cart=ifile:jibb basket=ifile:jibb src=@t prelude=ifile:jibb]
  ^-  (list tape)
  ?~  graph.cart  ~["cart evidence is missing"]
  ?~  graph.basket  ~["basket evidence is missing"]
  =/  parsed  (parse:jibb /ui/basket/jibb src)
  ?:  ?=(%| -.parsed)  ~["basket evidence source does not parse"]
  =/  main=(unit def:jibb)  (program-main-def:jibb defs.p.parsed)
  ?~  main  ~["basket evidence main is missing"]
  =/  parts=(unit [init=term update=term view=term subs=term])
    (program-main-parts:jibb u.main)
  ?~  parts  ~["basket evidence main parts are missing"]
  ?.  ?=([* ~] stores.u.graph.cart)  ~["cart store evidence is not unique"]
  =/  evidence=istore-request-evidence:jibb  i.stores.u.graph.cart
  =/  imports=ijimports:jibb  ~[[%cart cart]]
  =/  missing=irequest-graph:jibb  u.graph.basket(stores ~)
  =/  mismatch=irequest-graph:jibb
    u.graph.basket(stores ~[evidence(source 'mismatched')])
  =/  ambiguous=irequest-graph:jibb
    u.graph.basket(stores ~[evidence evidence])
  =/  many=(list istore-request-evidence:jibb)
    %+  turn  (gulf 0 255)
    |=  n=@ud
    evidence(store-at (stab (crip "/ui/stores/{(a-co:co n)}/jibb")))
  =/  oversized=irequest-graph:jibb  u.graph.basket(stores [evidence many])
  ?:  (request-graph-bounded:jibb oversized)  ~["oversized request graph was accepted"]
  =/  detached=ifile:jibb  cart(graph `u.graph.cart(stores ~))
  =/  ordinary=ienv:jibb
    (skim values.cart |=(entry=[name=term scheme=ischeme:jibb] !=(%state name.entry)))
  =/  forged=ifile:jibb
    cart(values [[%state [[%fn [%atom %t] [%atom %t]] ~]] ordinary])
  =/  without-action=ienv:jibb
    (skim values.cart |=(entry=[name=term scheme=ischeme:jibb] !=(%poke name.entry)))
  =/  forged-action=ifile:jibb
    cart(values [[%poke [[%fn [%atom %t] [%atom %t]] ~]] without-action])
  =/  graphs=(list [label=tape graph=irequest-graph:jibb])
    :~  ["missing store evidence" missing]
        ["store source mismatch" mismatch]
        ["ambiguous store evidence" ambiguous]
    ==
  =/  failures=(list tape)
    %+  murn  graphs
    |=  c=[label=tape graph=irequest-graph:jibb]
    ?:  (program-main-closed:jibb u.parts defs.p.parsed values.basket `prelude imports graph.c)
      `label.c
    ~
  =?  failures  (program-main-closed:jibb u.parts defs.p.parsed values.basket `prelude ~[[%cart detached]] u.graph.basket)
    ["evidence outside the store interface" failures]
  =?  failures  (program-main-closed:jibb u.parts defs.p.parsed values.basket `prelude ~[[%cart forged]] u.graph.basket)
    ["forged state member" failures]
  =?  failures  (program-main-closed:jibb u.parts defs.p.parsed values.basket `prelude ~[[%cart forged-action]] u.graph.basket)
    ["forged action constructor" failures]
  failures
::
++  store-errors
  |=  [public=@t private=@t cart-source=@t basket-source=@t]
  ^-  (list tape)
  =/  prepared=(unit iprelude:jibb)
    (prepare-prelude-with-internal:jibb public private)
  ?~  prepared  ~["store prelude did not prepare"]
  =/  store-value=(unit ischeme:jibb)  (ienv-lookup:jibb %store values.iface.u.prepared)
  =/  store-mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %store iface.u.prepared)
  ?~  store-value  ~["store builder is missing"]
  ?~  store-mold  ~["store mold is missing"]
  ::  The builder's variables keep the names the prelude writes, S and A.
  =/  s=@ud  (named-var:jibb 'S' 0)
  =/  a=@ud  (named-var:jibb 'A' 1)
  =/  expected-builder=itype:jibb
    [%fn [%cell [%face %init [%var s]] [%face %update [%fn [%cell [%var a] [%var s]] [%var s]]]] [%cell [%face %init [%var s]] [%face %update [%noun ~]]]]
  ?.  &(?=([@ @ ~] vars.u.store-value) =(typ.u.store-value expected-builder))  ~["store builder scheme differs"]
  =/  expected-mold=itype:jibb  [%cell [%face %init [%var 0]] [%face %update [%noun ~]]]
  ?.  &(?=([@ ~] vars.u.store-mold) =(typ.u.store-mold expected-mold))  ~["store mold scheme differs"]
  =/  cart-at=path  /ui/stores/cart/jibb
  =/  modules=jbundle:jibb  ~[[cart-at cart-source]]
  =/  detailed=jfile-detailed-result:jibb
    (store-detailed cart-at cart-source ~ u.prepared)
  ?:  ?=(%| -.detailed)  ~[(weld "cart was rejected: " (trip message.p.detailed))]
  =/  cart=ifile:jibb  iface.p.detailed
  =/  legacy=jfile-result:jibb  (store-legacy cart-at cart-source ~ u.prepared)
  ?:  ?=(%| -.legacy)  ~["legacy cart was rejected"]
  ?.  =(values.cart values.iface.p.legacy)  ~["detailed and legacy cart values differ"]
  ?.  =(molds.cart molds.iface.p.legacy)  ~["detailed and legacy cart molds differ"]
  =/  cart-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.cart)
  ?~  cart-main  ~["cart main is missing"]
  =/  actual-main=@t  (crip (show-itype:jibb typ.u.cart-main ~))
  ?.  =(actual-main '[init=[items=(list @t) open=?] update=*]')  ~["cart main type differs"]
  ?.  &(?=(~ vars.u.cart-main) ?=(~ (itype-vars:jibb typ.u.cart-main)))  ~["cart main is open"]
  =/  state=(unit ischeme:jibb)  (find-jibb-mold:jibb %state cart)
  =/  action=(unit ischeme:jibb)  (find-jibb-mold:jibb %poke cart)
  ?~  state  ~["state mold is missing"]
  ?~  action  ~["local poke action mold is missing"]
  =/  ask=(unit ischeme:jibb)  (request-compatible-ask:jibb u.prepared)
  =/  poke=(unit ischeme:jibb)  (compatible-raw-poke:jibb u.prepared)
  ?~  ask  ~["canonical ask is unavailable"]
  ?~  poke  ~["canonical poke is unavailable"]
  =/  ask-result=(unit itype:jibb)  (template-apply:jibb u.ask ~[[%var 0]])
  ?~  ask-result  ~["canonical ask did not instantiate"]
  =/  expected-state=ischeme:jibb  [[%fn [%fn typ.u.state [%var 0]] u.ask-result] ~[0]]
  =/  expected-action=(unit ischeme:jibb)  (derived-poke-command-scheme:jibb iface.u.prepared typ.u.action)
  ?~  expected-action  ~["derived action scheme did not instantiate"]
  =/  command=(unit ischeme:jibb)  (find-jibb-mold:jibb %cmd iface.u.prepared)
  =/  unit-template=(unit ischeme:jibb)  (find-jibb-mold:jibb %unit iface.u.prepared)
  ?~  command  ~["canonical cmd mold is missing"]
  ?~  unit-template  ~["canonical unit mold is missing"]
  ?.  ?=(%union -.typ.u.command)  ~["canonical cmd is not a union"]
  =/  wrong-command=ischeme:jibb  u.command(typ typ.u.command(cases ~))
  =/  wrong-command-prelude=ifile:jibb
    iface.u.prepared(molds (turn molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] ?:(=(%cmd name.m) [%cmd wrong-command] m))))
  ?.  ?=(~ (derived-poke-command-scheme:jibb wrong-command-prelude typ.u.action))
    ~["derived poke accepted a noncanonical cmd"]
  =/  wrong-unit-prelude=ifile:jibb
    iface.u.prepared(molds (turn molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] ?:(=(%unit name.m) [%unit u.command] m))))
  ?.  ?=(~ (derived-poke-command-scheme:jibb wrong-unit-prelude typ.u.action))
    ~["derived poke accepted a noncanonical unit"]
  =/  wrong-raw=ischeme:jibb  u.poke(vars ~[0])
  =/  wrong-raw-prelude=ifile:jibb
    iface.u.prepared(molds (turn molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] ?:(=(%raw-poke name.m) [%raw-poke wrong-raw] m))))
  ?.  ?=(~ (derived-poke-command-scheme:jibb wrong-raw-prelude typ.u.action))
    ~["derived poke accepted a generic raw-poke"]
  ?.  ?=(%union -.typ.u.poke)  ~["canonical raw-poke is not a union"]
  =/  wrong-raw-args=ischeme:jibb  u.poke(typ typ.u.poke(args ~[[%atom %t]]))
  =/  wrong-raw-args-prelude=ifile:jibb
    iface.u.prepared(molds (turn molds.iface.u.prepared |=(m=[name=term template=ischeme:jibb] ?:(=(%raw-poke name.m) [%raw-poke wrong-raw-args] m))))
  ?.  ?=(~ (derived-poke-command-scheme:jibb wrong-raw-args-prelude typ.u.action))
    ~["derived poke accepted raw-poke union arguments"]
  =/  state-values=(list [name=term scheme=ischeme:jibb])
    (skim values.cart |=(entry=[name=term scheme=ischeme:jibb] =(%state name.entry)))
  =/  action-values=(list [name=term scheme=ischeme:jibb])
    (skim values.cart |=(entry=[name=term scheme=ischeme:jibb] =(%poke name.entry)))
  ?.  ?=([* ~] state-values)  ~["derived state member is not unique"]
  ?.  =(scheme.i.state-values expected-state)  ~["derived state scheme differs"]
  ?.  ?=([* ~] action-values)  ~["derived poke member is not unique"]
  ?.  =(scheme.i.action-values u.expected-action)  ~["derived poke command scheme differs"]
  ?~  graph.cart  ~["cart request graph is missing"]
  ?.  ?=([* ~] stores.u.graph.cart)  ~["cart store evidence is not unique"]
  =/  evidence=istore-request-evidence:jibb  i.stores.u.graph.cart
  ?.  &(=(store-at.evidence cart-at) =(source.evidence cart-source))  ~["store evidence does not retain exact path/source"]
  ?.  &(=(state.evidence typ.u.state) =(action.evidence typ.u.action) =(%poke action-name.evidence))  ~["store evidence types differ"]
  =/  basket-result=jfile-detailed-result:jibb
    (store-detailed /ui/basket/jibb basket-source modules u.prepared)
  ?:  ?=(%| -.basket-result)  ~[(weld "basket was rejected: " (trip message.p.basket-result))]
  =/  basket=ifile:jibb  iface.p.basket-result
  =/  basket-legacy=jfile-result:jibb
    (store-legacy /ui/basket/jibb basket-source modules u.prepared)
  ?:  ?=(%| -.basket-legacy)  ~["legacy basket was rejected"]
  ?.  =(values.basket values.iface.p.basket-legacy)  ~["detailed and legacy basket values differ"]
  =/  basket-main=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.basket)
  ?~  basket-main  ~["basket main is missing"]
  =/  expected-basket=@t  '[init=$-(~ [cart=[items=(list @t) open=?] note=@t]) [update=$-([msg [cart=[items=(list @t) open=?] note=@t]] [[cart=[items=(list @t) open=?] note=@t] (list (cmd msg))]) [view=$-([cart=[items=(list @t) open=?] note=@t] (element msg)) subs=$-([cart=[items=(list @t) open=?] note=@t] (list (sub msg)))]]]'
  =/  actual-basket=@t  (crip (show-itype:jibb typ.u.basket-main ~))
  ?.  =(actual-basket expected-basket)  ~["basket main type differs"]
  ?~  graph.basket  ~["basket request graph is missing"]
  ?.  (lien stores.u.graph.basket |=(r=istore-request-evidence:jibb =(r evidence)))  ~["basket did not merge exact store evidence"]
  =/  consumer-result=jfile-detailed-result:jibb
    (store-detailed /tests/store/consumer/jibb store-consumer-source modules u.prepared)
  ?:  ?=(%| -.consumer-result)  ~["downstream store import was rejected"]
  =/  consumer=ifile:jibb  iface.p.consumer-result
  =/  imported-main=(unit ischeme:jibb)  (ienv-lookup:jibb %imported-main values.consumer)
  ?~  imported-main  ~["downstream main is missing"]
  =/  expected-import=itype:jibb  (itype-in-import:jibb typ.u.cart-main cart %cart `iface.u.prepared)
  ?.  =(typ.u.imported-main expected-import)  ~["downstream main type differs"]
  =/  local-state=(unit ischeme:jibb)  (find-jibb-mold:jibb %local-state consumer)
  =/  local-action=(unit ischeme:jibb)  (find-jibb-mold:jibb %local-action consumer)
  ?~  local-state  ~["downstream state mold is missing"]
  ?~  local-action  ~["downstream action mold is missing"]
  =/  imported-state=itype:jibb  (itype-in-import:jibb typ.u.state cart %cart `iface.u.prepared)
  =/  imported-action=itype:jibb  (itype-in-import:jibb typ.u.action cart %cart `iface.u.prepared)
  ?.  &(=(typ.u.local-state imported-state) =(typ.u.local-action imported-action))  ~["downstream molds differ"]
  ?~  (ienv-lookup:jibb %imported-request values.consumer)  ~["downstream state request is missing"]
  ?~  (ienv-lookup:jibb %imported-poke values.consumer)  ~["downstream action constructor is missing"]
  =/  direct=jfile-detailed-result:jibb
    (store-detailed /tests/direct/cart/jibb cart-source ~ u.prepared)
  ?:  ?=(%| -.direct)  ~["direct store outside /ui/stores was rejected"]
  =/  grouped=@t  (store-cart-source '+$ poke\0a  [%add item=@t]\0a  %toggle\0a' '++ main (store (init) (update))\0a' '++ init ^- state [~ %.n]\0a' '++ update |= [a=poke s=state]\0a  ?- a\0a    [%add item]  s(items=[item items.s])\0a    %toggle      s(open=(not open.s))\0a' '')
  =/  grouped-result=jfile-detailed-result:jibb
    (store-detailed /tests/direct/grouped/jibb grouped ~ u.prepared)
  ?:  ?=(%| -.grouped-result)  ~[(weld "grouped direct store main was rejected: " (trip message.p.grouped-result))]
  =/  gate-state=@t  '+$ state [callback=$-(@t @t)]\0a+$ poke %set\0a++ main (store init update)\0a++ init ^- state [callback=same]\0a++ update |= [a=poke s=state] s\0a'
  =/  gate-result=jfile-detailed-result:jibb
    (store-detailed /tests/direct/gate-state/jibb gate-state ~ u.prepared)
  ?:  ?=(%| -.gate-result)  ~["gate-bearing store state was rejected"]
  =/  evidence-failures=(list tape)  (store-evidence-failures cart basket basket-source iface.u.prepared)
  ?^  evidence-failures  evidence-failures
  =/  normal-poke=@t  '+$ poke\0a  [%add item=@t]\0a  %toggle\0a'
  =/  normal-main=@t  '++ main (store init update)\0a'
  =/  normal-init=@t  '++ init ^- state [~ %.n]\0a'
  =/  normal-update=@t  '++ update |= [a=poke s=state]\0a  ?- a\0a    [%add item]  s(items=[item items.s])\0a    %toggle      s(open=(not open.s))\0a'
  =/  cart-cases=(list [label=tape at=path src=@t modules=jbundle:jibb])
    :~  ["wrong init" /tests/store/wrong-init/jibb (store-cart-source normal-poke normal-main '++ init ^- state [~ "bad"]\0a' normal-update '') ~]
        ["wrong action" /tests/store/wrong-action/jibb (store-cart-source normal-poke normal-main normal-init '++ update |= [a=@t s=state] s\0a' '') ~]
        ["wrong result" /tests/store/wrong-result/jibb (store-cart-source normal-poke normal-main normal-init '++ update |= [a=poke s=state] "bad"\0a' '') ~]
        ["unknown poke" /tests/store/unknown-poke/jibb (store-cart-source '+$ poke missing\0a' normal-main normal-init normal-update '') ~]
        ["qualified poke" /tests/store/qualified-poke/jibb (store-cart-source '+$ poke poke.cart\0a' normal-main normal-init normal-update '') ~]
        ["duplicate poke" /tests/store/duplicate-poke/jibb (store-cart-source '+$ poke %one\0a+$ poke %two\0a' normal-main normal-init normal-update '') ~]
        ["duplicate state" /tests/store/duplicate-state/jibb (store-cart-source normal-poke normal-main normal-init normal-update '+$ state @t\0a') ~]
        ["state derived collision" /tests/store/state-collision/jibb (store-cart-source normal-poke normal-main normal-init normal-update '++ state 0\0a') ~]
        ["action derived collision" /tests/store/action-collision/jibb (store-cart-source normal-poke normal-main normal-init normal-update '++ poke 0\0a') ~]
        ["import derived collision" /tests/store/import-collision/jibb (cat 3 '/= state /ui/stores/other\0a' (store-cart-source normal-poke normal-main normal-init normal-update '')) ~]
        ["alias main" /tests/store/alias-main/jibb (store-cart-source normal-poke '++ main (build init update)\0a' normal-init normal-update '++ build store\0a') ~]
        ["hand-built main" /tests/store/hand-main/jibb (store-cart-source normal-poke '++ main [init update]\0a' normal-init normal-update '') ~]
    ==
  =/  normal-basket-update=@t  '++ update |= [=msg m=model]\0a  ?- msg\0a    [%noted t]     [m(note=t) ~]\0a    %add           [m(note="") ~[(poke.cart [%add note.m] |=%acked)]]\0a    %toggle        [m ~[(poke.cart %toggle |=%acked)]]\0a    [%got c]       [m(cart=c) ~]\0a    [%acked err]   [m ~]\0a'
  =/  normal-subs=@t  '++ subs |= m=model\0a  ~[[%watch (state.cart |=%got)]]\0a'
  =/  wrong-payload=@t  '++ update |= [=msg m=model]\0a  ?- msg\0a    [%noted t]     [m(note=t) ~]\0a    %add           [m(note="") ~[(poke.cart [%add ~zod] |=%acked)]]\0a    %toggle        [m ~[(poke.cart %toggle |=%acked)]]\0a    [%got c]       [m(cart=c) ~]\0a    [%acked err]   [m ~]\0a'
  =/  basket-cases=(list [label=tape at=path src=@t modules=jbundle:jibb])
    :~  ["wrong poke payload" /ui/basket/jibb (store-basket-source wrong-payload normal-subs '') modules]
        ["wrong state reply" /ui/basket/jibb (store-basket-source normal-basket-update '++ subs |= m=model\0a  ~[[%watch (state.cart |=%acked)]]\0a' '') modules]
        ["helper state request" /ui/basket/jibb (store-basket-source normal-basket-update '++ subs |= m=model\0a  ~[[%watch request]]\0a' '++ request ^- (ask msg) (state.cart |=%got)\0a') modules]
        ["program under store path" /ui/stores/basket/jibb basket-source modules]
    ==
  =/  page=@t  '/= cart /ui/stores/cart\0a++ main (page load view)\0a++ load |= ~ (state.cart same)\0a++ view |= s=state.cart ^- (element !!) (text "page")\0a'
  =/  page-case=[label=tape at=path src=@t modules=jbundle:jibb]
    ["store state as page load" /tests/store/page/jibb page modules]
  =/  failures=(list tape)  (store-rejections (weld cart-cases (weld basket-cases ~[page-case])) u.prepared)
  ?^  failures  failures
  ~
::
++  test-store
  ^-  tang
  =/  failures=(list tape)
    (store-errors prelude internal (text cart) (text basket))
  (turn failures |=(reason=tape leaf+reason))
--
