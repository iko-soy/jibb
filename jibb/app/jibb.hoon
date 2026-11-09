/+  jibb, jibb-build, jibb-host, jibb-import
=,  clay
|%
+$  card  card:agent:gall
+$  state-0  [%0 registry=registry:jibb-host]
+$  state-1  [%1 registry=registry:jibb-host pages=page-cache:jibb-host]
+$  versioned-state  $%(state-0 state-1)
--
^-  agent:gall
=|  state-1
=*  state  -
|_  =bowl:gall
+*  this  .
++  on-init
  ^-  (quip card _this)
  [~[tire-card:jibb-host] this]
++  on-save  !>(state)
::  Published routes survive reloads; only pending binds are retried.
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  previous=versioned-state  !<(versioned-state old)
  =/  restored=state-1
    ?:  ?=(%1 -.previous)  previous
    ::  Legacy published bindings predate cached HTML.  Reconnect them so
    ::  their acknowledgments build pages through the same transaction.
    [%1 [~ routes.registry.previous live.registry.previous] ~]
  [(restore-cards:jibb-host dap.bowl registry.restored) this(state restored)]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  [~ this]
  =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
  =/  result=payload:jibb-host
    (request-response:jibb-host routes.registry pages authenticated.req method.request.req url.request.req)
  [(give-payload:jibb-host eyre-id result) this]
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?:  ?=([%http-response *] path)  [~ this]
  [~ this]
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  |^
  ?:  ?=([%bind @ ~] wire)
    ?.  ?=([%eyre %bound *] sign-arvo)  [~ this]
    =/  accepted=?  accepted.sign-arvo
    =/  =desk  i.t.wire
    =/  next=transition:jibb-host
      (acknowledge-bind:jibb-host registry desk accepted)
    =/  published=(unit route:jibb-host)
      (route-for-desk:jibb-host routes.registry.next desk)
    =?  pages  ?=(^ published)
      (~(put by pages) desk (build-route u.published))
    [cards.next this(registry registry.next)]
  ?.  ?=([%desks ~] wire)  [~ this]
  ?.  ?=([%clay %tire *] sign-arvo)  [~ this]
  =/  result=(each rock:tire wave:tire)  p.sign-arvo
  ?:  ?=(%& -.result)  (initial-rock p.result)
  ?.  ?=(%zest -.p.result)  [~ this]
  =/  =desk  desk.p.result
  ?.  ?=(%live zest.p.result)  (retire desk)
  (revive desk)
  ++  jibb-desk
    |=  [our=@ta now=@ta =desk]
    ^-  ?
    =/  read=(each noun tang)
      (mule |.(.^(noun %cx /[our]/[desk]/[now]/lib/jibb/hoon)))
    ?=(%& -.read)
  ++  desk-error
    |=  message=@t
    ^-  desk-pages:jibb-host
    [*(map (list @t) cached-page:jibb-host) `message]
  ++  trace-error
    |=  [message=@t trace=tang]
    ^-  @t
    =/  lines=wall  (zing (turn (flop trace) |=(line=tank (wash [0 80] line))))
    (rap 3 ~[message '\0a' (crip (zing lines))])
  ++  read-clay
    |=  [pre=path at=path]
    ^-  (each @t @t)
    =/  read=(each @t tang)  (mule |.(.^(@t %cx (weld pre at))))
    ?:  ?=(%| -.read)
      [%| (crip "static build: cannot read Clay source {(spud at)}")]
    read
  ++  read-modules
    |=  [pre=path paths=(list path)]
    ^-  (each jbundle:jibb @t)
    =|  modules=jbundle:jibb
    |-
    ?~  paths  [%& (flop modules)]
    =/  source=(each @t @t)  (read-clay pre i.paths)
    ?:  ?=(%| -.source)  source
    $(paths t.paths, modules [[i.paths p.source] modules])
  ++  prepare-clay
    |=  [pre=path reader=vase prepare=vase]
    ^-  (each * @t)
    =/  public=(each @t @t)  (read-clay pre /lib/jibb/prelude/jibb)
    ?:  ?=(%| -.public)  public
    =/  private=(each @t @t)  (read-clay pre /lib/jibb/internal/jibb)
    ?:  ?=(%| -.private)  private
    =/  hoon=(each @t @t)  (read-clay pre /lib/jibb/groups/hoon/jibb)
    ?:  ?=(%| -.hoon)  hoon
    =/  bit=(each @t @t)  (read-clay pre /lib/jibb/groups/bit/jibb)
    ?:  ?=(%| -.bit)  bit
    =/  collections=(each @t @t)  (read-clay pre /sur/jibb-collections/hoon)
    ?:  ?=(%| -.collections)  collections
    =/  core=(each type tang)
      (mule |.(-:(ride -:!>(..zuse) p.collections)))
    ?:  ?=(%| -.core)  [%| 'static build: cannot rebuild the Clay collection reader']
    =/  read-generic=vase  (slap reader (ream 'read-generic-source'))
    =/  table=(each imported:jibb-import @t)
      !<  (each imported:jibb-import @t)
      (slam read-generic !>([%jibb-collections %table /sur/jibb-collections/hoon p.collections p.core]))
    ?:  ?=(%| -.table)  table
    =/  keys=(each imported:jibb-import @t)
      !<  (each imported:jibb-import @t)
      (slam read-generic !>([%jibb-collections %keys /sur/jibb-collections/hoon p.collections p.core]))
    ?:  ?=(%| -.keys)  keys
    =/  groups=(list iprelude-group-source:jibb)
      :~  [%hoon /lib/jibb/groups/hoon/jibb p.hoon]
          [%bit /lib/jibb/groups/bit/jibb p.bit]
      ==
    =/  externals=iexternals:jibb
      :~  [%jibb-collections %table table]
          [%jibb-collections %keys keys]
      ==
    =/  modules=jbundle:jibb  ~[[/sur/jibb-collections/hoon p.collections]]
    =/  prepared=vase
      (slym prepare [p.public p.private groups modules externals])
    ?~  +.prepared  [%| 'static build: checked Clay prelude did not prepare']
    [%& +>.prepared]
  ++  application-inputs
    |=  [pre=path reader=vase files=(list path) surs=(list term) used-marks=(list term)]
    ^-  (each [externals=iexternals:jibb marks=imark-externals:jibb] @t)
    =/  sur-paths=(list path)
      %+  skim  files
      |=  at=path
      ?&  ?=([%sur @ %hoon ~] at)
          (lien surs |=(module=term =(module ;;(term +6.at))))
      ==
    =/  mar-paths=(list path)
      %+  skim  files
      |=  at=path
      ?&  ?=([%mar @ %hoon ~] at)
          (lien used-marks |=(mark=term =(mark ;;(term +6.at))))
      ==
    =/  read-module=vase  (slap reader (ream 'read-module'))
    =/  read-mark=vase  (slap reader (ream 'read-mark-source-diagnostic'))
    =/  sur-data=(each [sources=(list [module=term at=path source=@t]) externals=iexternals:jibb] @t)
      |-
      ?~  sur-paths  [%& [~ ~]]
      =/  at=path  i.sur-paths
      =/  module=term  ;;(term +6.at)
      =/  source=(each @t @t)  (read-clay pre at)
      ?:  ?=(%| -.source)  [%| p.source]
      =/  built=(each vase tang)  (mule |.(.^(vase %ca (weld pre at))))
      ?:  ?=(%| -.built)
        [%| (crip "static build: cannot build imported Hoon source {(spud at)}")]
      =/  read=(each iexternals:jibb @t)
        !<  (each iexternals:jibb @t)
        (slam read-module !>([module at p.source -.p.built]))
      ?:  ?=(%| -.read)  [%| p.read]
      =/  rest=(each [sources=(list [module=term at=path source=@t]) externals=iexternals:jibb] @t)
        $(sur-paths t.sur-paths)
      ?:  ?=(%| -.rest)  rest
      [%& [[[module at p.source] sources.p.rest] (weld p.read externals.p.rest)]]
    ?:  ?=(%| -.sur-data)  [%| p.sur-data]
    =/  marks=(each imark-externals:jibb @t)
      |-
      ?~  mar-paths  [%& ~]
      =/  at=path  i.mar-paths
      =/  mark=term  ;;(term +6.at)
      =/  built=(each vase tang)  (mule |.(.^(vase %ca (weld pre at))))
      =/  read=*
        ?:  ?=(%| -.built)  [%| 'Hoon mark could not be built through Clay']
        +:(slym read-mark [mark sources.p.sur-data -.p.built])
      =/  rest=(each imark-externals:jibb @t)  $(mar-paths t.mar-paths)
      ?:  ?=(%| -.rest)  rest
      [%& [[mark read] p.rest]]
    ?:  ?=(%| -.marks)  [%| p.marks]
    [%& [externals.p.sur-data p.marks]]
  ++  ui-file
    |=  at=path
    ^-  ?
    ?.  ?=([%ui *] at)  |
    =/  reversed=(list @ta)  (flop t.at)
    &(?=(^ reversed) =(%jibb i.reversed))
  ++  build-route-clay
    |=  r=route:jibb-host
    ^-  desk-pages:jibb-host
    =/  pre=path  /[(scot %p our.bowl)]/[desk.r]/[(scot %da now.bowl)]
    =/  files=(list path)  .^((list path) %ct pre)
    =/  assets=(list path)
      %+  turn
        (skim files |=(at=path ?=(^ (prefix:jibb-host /ui/static at))))
      application-asset:jibb-host
    =/  sources=(list path)  (skim files ui-file)
    =/  modules=(each jbundle:jibb @t)  (read-modules pre sources)
    ?:  ?=(%| -.modules)  (desk-error p.modules)
    =/  renderer=(each @t @t)  (read-clay pre /lib/jibb/renderer/jibb)
    ?:  ?=(%| -.renderer)  (desk-error p.renderer)
    =/  builder=vase  .^(vase %ca (weld pre /lib/jibb-build/hoon))
    =/  reader=vase  .^(vase %ca (weld pre /lib/jibb-import/hoon))
    =/  prepare=vase  (slap builder (ream 'prepare-lowering'))
    =/  imports=vase  (slap builder (ream 'static-imports'))
    =/  check=vase  (slap builder (ream 'check-static'))
    =/  build=vase  (slap builder (ream 'build-static-checked'))
    =/  kind=vase  (slap builder (ream 'static-kind'))
    =/  default-theme=@t  !<(@t (slap builder (ream 'default-theme-source')))
    =/  skin=(each @t @t)
      ?:  (lien files |=(at=path =(at /ui/theme/jibb)))
        (read-clay pre /ui/theme/jibb)
      [%& default-theme]
    ?:  ?=(%| -.skin)  (desk-error p.skin)
    =/  needed=[surs=(list term) marks=(list term)]
      !<  [surs=(list term) marks=(list term)]
      (slam imports !>(p.modules))
    =/  inputs=(each [externals=iexternals:jibb marks=imark-externals:jibb] @t)
      (application-inputs pre reader files surs.needed marks.needed)
    ?:  ?=(%| -.inputs)  (desk-error p.inputs)
    =/  prepared=(each * @t)
      (prepare-clay pre reader prepare)
    ?:  ?=(%| -.prepared)  (desk-error p.prepared)
    =|  pages=(map (list @t) cached-page:jibb-host)
    =/  entries=jbundle:jibb  p.modules
    |-
    ?~  entries  [pages ~]
    =/  site=(unit (list @t))  (page-site:jibb-host at.i.entries)
    ?~  site  $(entries t.entries)
    =/  page-at=path  at.i.entries
    =/  page-source=@t  source.i.entries
    =/  page-base=@t  (crip (spud base.r))
    =/  renderer-source=@t  p.renderer
    =/  theme-source=@t  p.skin
    =/  page-modules=jbundle:jibb  p.modules
    =/  page-assets=(list path)  assets
    =/  request=static-request:jibb-build
      :*  page-at
          page-source
          page-base
          /lib/jibb/renderer/jibb
          renderer-source
          /ui/theme/jibb
          theme-source
          page-modules
          page-assets
          externals.p.inputs
          marks.p.inputs
      ==
    =/  checked=(each vase tang)
      (mule |.((slym check [request p.prepared])))
    =/  kind-result=(each checked-kind:jibb @t)
      ?:  ?=(%| -.checked)  [%| 'static build: compiler crashed while checking page']
      !<  (each checked-kind:jibb @t)
      (slym kind +.p.checked)
    =/  page=(unit cached-page:jibb-host)
      ?:  ?=(%| -.kind-result)
        `(failed-page:jibb-host p.kind-result)
      ?:  !?=(?(%static-page %page) p.kind-result)  ~
      ?:  =(%page p.kind-result)
        `(failed-page:jibb-host 'unsupported module kind for static build: page')
      =/  made=(each (each static-output:jibb-build @t) tang)
        %-  mule
        |.
        !<  (each static-output:jibb-build @t)
        (slym build [request p.prepared +.p.checked])
      ?:  ?=(%| -.made)
        `(failed-page:jibb-host 'static build: compiler crashed while rendering page')
      ?:  ?=(%| -.p.made)
        `(failed-page:jibb-host p.p.made)
      `(successful-page:jibb-host html.p.p.made)
    ?~  page  $(entries t.entries)
    $(entries t.entries, pages (~(put by pages) u.site u.page))
  ++  build-route
    |=  r=route:jibb-host
    ^-  desk-pages:jibb-host
    =/  made=(each desk-pages:jibb-host tang)
      (mule |.((build-route-clay r)))
    ?:  ?=(%& -.made)  p.made
    (desk-error (trace-error 'static build: Clay source read or compiler execution failed' p.made))
  ++  discover
    |=  live=(set desk)
    ^-  (list docket-entry:jibb-host)
    =/  our=@ta  (scot %p our.bowl)
    =/  now=@ta  (scot %da now.bowl)
    =/  desks=(set desk)  .^((set desk) %cd /[our]/[%$]/[now])
    =/  ordered=(list desk)  (sort ~(tap in desks) aor)
    =|  entries=(list docket-entry:jibb-host)
    |-
    ?~  ordered  (flop entries)
    ?.  (~(has in live) i.ordered)  $(ordered t.ordered)
    ?.  (jibb-desk our now i.ordered)  $(ordered t.ordered)
    =/  read=(each noun tang)
      (mule |.(.^(noun %cx /[our]/[i.ordered]/[now]/desk/docket-0)))
    =/  doc=(unit noun)  ?:(?=(%| -.read) ~ `p.read)
    $(ordered t.ordered, entries [[i.ordered doc] entries])
  ++  initial-rock
    |=  rock=rock:tire
    ^-  (quip card _this)
    =/  next=transition:jibb-host
      (reconcile-live:jibb-host registry (live-desks:jibb-host rock))
    =.  registry  registry.next
    =.  pages  (prune-pages:jibb-host pages live.registry)
    =/  found=(each (list route:jibb-host) @t)
      (discover-routes:jibb-host (discover live.registry))
    ?:  ?=(%| -.found)  ~|(p.found !!)
    =/  discovered=(list route:jibb-host)  p.found
    =/  out=(list card)  cards.next
    |-
    ?~  discovered  [out this]
    =/  added=(each transition:jibb-host @t)
      (add-pending:jibb-host dap.bowl registry i.discovered)
    ?:  ?=(%| -.added)  ~|(p.added !!)
    %=  $
      discovered  t.discovered
      registry    registry.p.added
      out         (welp out cards.p.added)
    ==
  ++  retire
    |=  =desk
    ^-  (quip card _this)
    =/  next=transition:jibb-host  (retire-desk:jibb-host registry desk)
    =.  pages  (~(del by pages) desk)
    [cards.next this(registry registry.next)]
  ++  revive
    |=  =desk
    ^-  (quip card _this)
    =.  registry  (revive-desk:jibb-host registry desk)
    ?:  ?|  ?=(^ (route-for-desk:jibb-host routes.registry desk))
            ?=(^ (route-for-desk:jibb-host pending.registry desk))
        ==
      [~ this]
    =/  our=@ta  (scot %p our.bowl)
    =/  now=@ta  (scot %da now.bowl)
    ?.  (jibb-desk our now desk)  [~ this]
    =/  read=(each noun tang)
      (mule |.(.^(noun %cx /[our]/[desk]/[now]/desk/docket-0)))
    ?:  ?=(%| -.read)  [~ this]
    =/  site=(unit path)  (docket-site:jibb-host p.read)
    ?~  site  [~ this]
    =/  next=(each transition:jibb-host @t)
      (add-pending:jibb-host dap.bowl registry [desk u.site])
    ?:  ?=(%| -.next)  ~|(p.next !!)
    =/  made=transition:jibb-host  p.next
    [cards.made this(registry registry.made)]
  --
++  on-leave  |=  =path  ^-  (quip card _this)  [~ this]
++  on-agent  |=  [=wire =sign:agent:gall]  ^-  (quip card _this)  [~ this]
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?:  ?=([%x %routes ~] path)  ``noun+!>((lent routes.registry))
  ?:  ?=([%x %routes @ ~] path)
    ``noun+!>(?=(^ (route-for-desk:jibb-host routes.registry i.t.t.path)))
  ~
++  on-fail  |=  [=term =tang]  ^-  (quip card _this)  [~ this]
--
