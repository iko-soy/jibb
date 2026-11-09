/+  jibb, jibb-build, jibb-host, jibb-import
=,  clay
|%
+$  card  card:agent:gall
+$  state-0  [%0 registry=registry:jibb-host]
+$  state-1  [%1 registry=registry:jibb-host pages=page-cache:jibb-host]
::  Builds in progress and compile caches are not saved: their types change
::  with the host, and a reload rebuilds them.
+$  state-2
  $:  %2
      registry=registry:jibb-host
      pages=page-cache:jibb-host
      watched=(map desk @ud)
      builds=*
      stores=*
      built=(map desk built:jibb-host)
  ==
+$  saved-3
  $:  %3
      registry=registry:jibb-host
      pages=page-cache:jibb-host
      watched=(map desk @ud)
      built=(map desk built:jibb-host)
  ==
+$  state-3
  $:  %3
      registry=registry:jibb-host
      pages=page-cache:jibb-host
      watched=(map desk @ud)
      builds=(map desk build:jibb-host)
      stores=(map desk store:jibb-host)
      built=(map desk built:jibb-host)
  ==
+$  versioned-state  $%(state-0 state-1 state-2 saved-3)
--
=|  state-3
=*  state  -
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    hc    ~(. +> bowl)
++  on-init
  ^-  (quip card _this)
  [~[tire-card:jibb-host] this]
++  on-save  !>(`saved-3`[%3 registry pages watched built])
::  Published routes and their pages survive reloads and keep serving while
::  every published desk builds again from an empty cache, renewing its
::  commit subscription.  Pending binds are retried.
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  previous=versioned-state  !<(versioned-state old)
  =.  state
    ?-  -.previous
      %3  [%3 registry.previous pages.previous watched.previous ~ ~ built.previous]
      %2  [%3 registry.previous pages.previous watched.previous ~ ~ built.previous]
      %1  [%3 registry.previous pages.previous ~ ~ ~ ~]
    ::  Legacy published bindings predate cached HTML.  Reconnect them so
    ::  their acknowledgments build pages through the same transaction.
      %0  [%3 [~ routes.registry.previous live.registry.previous] ~ ~ ~ ~ ~]
    ==
  =^  cards  state  rebuild-published:hc
  [(weld (restore-cards:jibb-host dap.bowl registry) cards) this]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  [~ this]
  =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
  =/  result=payload:jibb-host
    %:  serve:jibb-host
      routes.registry  pages  ~(key by builds)
      authenticated.req  method.request.req  url.request.req
    ==
  [(give-payload:jibb-host eyre-id result) this]
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?:  ?=([%http-response *] path)  [~ this]
  [~ this]
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%bind @ ~] wire)
    ?.  ?=([%eyre %bound *] sign-arvo)  [~ this]
    =^  cards  state  (bound:hc i.t.wire accepted.sign-arvo)
    [cards this]
  ?:  ?=([%commit @ ~] wire)
    ?.  ?=([%clay %writ *] sign-arvo)  [~ this]
    ::  A cancelled subscription ends with an empty writ.
    ?~  p.sign-arvo  [~ this]
    =^  cards  state  (commit:hc i.t.wire)
    [cards this]
  ?:  ?=([%build @ @ ~] wire)
    ?.  ?=([%behn %wake *] sign-arvo)  [~ this]
    =/  rev=(unit @ud)  (slaw %ud i.t.t.wire)
    ?~  rev  [~ this]
    =^  cards  state  (wake:hc i.t.wire u.rev)
    [cards this]
  ::  Clay's answer to a build step: an empty writ is a file that does not
  ::  build.
  ?:  ?=([%built @ @ *] wire)
    ?.  ?=([%clay %writ *] sign-arvo)  [~ this]
    =/  rev=(unit @ud)  (slaw %ud i.t.t.wire)
    ?~  rev  [~ this]
    =^  cards  state  (built-file:hc i.t.wire u.rev t.t.t.wire ?=(^ p.sign-arvo))
    [cards this]
  ?.  ?=([%desks ~] wire)  [~ this]
  ?.  ?=([%clay %tire *] sign-arvo)  [~ this]
  =/  result=(each rock:tire wave:tire)  p.sign-arvo
  ?:  ?=(%& -.result)
    =^  cards  state  (initial-rock:hc p.result)
    [cards this]
  ?.  ?=(%zest -.p.result)  [~ this]
  =/  =desk  desk.p.result
  =^  cards  state
    ?.  ?=(%live zest.p.result)  (retire:hc desk)
    (revive:hc desk)
  [cards this]
++  on-leave  |=  =path  ^-  (quip card _this)  [~ this]
++  on-agent  |=  [=wire =sign:agent:gall]  ^-  (quip card _this)  [~ this]
::  /x/build/<desk>: the revisions of its last completed build and of the
::  build in progress.  /x/modules/<desk>: the revision whose build last
::  checked each module of the completed build.
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?:  ?=([%x %routes ~] path)  ``noun+!>((lent routes.registry))
  ?:  ?=([%x %routes @ ~] path)
    ``noun+!>(?=(^ (route-for-desk:jibb-host routes.registry i.t.t.path)))
  ?:  ?=([%x %build @ ~] path)
    =/  done=(unit built:jibb-host)  (~(get by built) i.t.t.path)
    =/  running=(unit build:jibb-host)  (~(get by builds) i.t.t.path)
    ``noun+!>([?~(done ~ `rev.u.done) ?~(running ~ `rev.u.running)])
  ?:  ?=([%x %modules @ ~] path)
    =/  done=(unit built:jibb-host)  (~(get by built) i.t.t.path)
    ``noun+!>(?~(done ~ modules.u.done))
  ~
++  on-fail  |=  [=term =tang]  ^-  (quip card _this)  [~ this]
--
::  Clay scries and compiler calls stay here; jibb-host's arms are pure.
|_  =bowl:gall
++  desk-path
  |=  [=desk rev=@ud]
  ^-  path
  /[(scot %p our.bowl)]/[desk]/[(scot %ud rev)]
++  current-rev
  |=  =desk
  ^-  @ud
  ud:.^(cass %cw /[(scot %p our.bowl)]/[desk]/[(scot %da now.bowl)])
++  watch-card
  |=  [=desk rev=@ud]
  ^-  card
  [%pass /commit/[desk] %arvo %c %warp our.bowl desk `[%next %z [%ud rev] /]]
++  unwatch-card
  |=  =desk
  ^-  card
  [%pass /commit/[desk] %arvo %c %warp our.bowl desk ~]
++  wake-card
  |=  [=desk rev=@ud]
  ^-  card
  [%pass /build/[desk]/[(scot %ud rev)] %arvo %b %wait now.bowl]
::  Gall cannot catch a failed scry, even under +mule: it fails the whole
::  event.  So a read is scried only after %u says the file exists, and a
::  build only after Clay's own answer to this request says it builds.
++  build-card
  |=  [=desk rev=@ud at=path]
  ^-  card
  :*  %pass  (weld /built/[desk]/[(scot %ud rev)] at)
      %arvo  %c  %warp  our.bowl  desk  `[%sing %a [%ud rev] at]
  ==
::
::  Lifecycle
::
++  jibb-desk
  |=  [our=@ta now=@ta =desk]
  ^-  ?
  .^(? %cu /[our]/[desk]/[now]/lib/jibb/hoon)
++  read-docket
  |=  [our=@ta now=@ta =desk]
  ^-  (unit noun)
  =/  at=path  /[our]/[desk]/[now]/desk/docket-0
  ?.  .^(? %cu at)  ~
  `.^(noun %cx at)
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
  $(ordered t.ordered, entries [[i.ordered (read-docket our now i.ordered)] entries])
++  initial-rock
  |=  rock=rock:tire
  ^-  (quip card _state)
  =/  before=(list route:jibb-host)  routes.registry
  =/  next=transition:jibb-host
    (reconcile-live:jibb-host registry (live-desks:jibb-host rock))
  =.  registry  registry.next
  =.  pages  (prune-pages:jibb-host pages live.registry)
  =/  gone=(list desk)
    %+  murn  before
    |=  r=route:jibb-host
    ?:((~(has in live.registry) desk.r) ~ `desk.r)
  =.  state  (forget gone)
  =/  found=(each (list route:jibb-host) @t)
    (discover-routes:jibb-host (discover live.registry))
  ?:  ?=(%| -.found)  ~|(p.found !!)
  =/  discovered=(list route:jibb-host)  p.found
  =/  out=(list card)  (weld cards.next (turn gone unwatch-card))
  |-
  ?~  discovered  [out state]
  =/  added=(each transition:jibb-host @t)
    (add-pending:jibb-host dap.bowl registry i.discovered)
  ?:  ?=(%| -.added)  ~|(p.added !!)
  %=  $
    discovered  t.discovered
    registry    registry.p.added
    out         (welp out cards.p.added)
  ==
::  A desk's builds, compile cache and commit subscription end with it.
++  forget
  |=  desks=(list desk)
  ^-  _state
  ?~  desks  state
  %=  $
    desks    t.desks
    pages    (~(del by pages) i.desks)
    watched  (~(del by watched) i.desks)
    builds   (~(del by builds) i.desks)
    stores   (~(del by stores) i.desks)
    built    (~(del by built) i.desks)
  ==
++  retire
  |=  =desk
  ^-  (quip card _state)
  =/  next=transition:jibb-host  (retire-desk:jibb-host registry desk)
  =/  cards=(list card)
    ?.  (~(has by watched) desk)  cards.next
    [(unwatch-card desk) cards.next]
  =.  registry  registry.next
  [cards (forget ~[desk])]
++  revive
  |=  =desk
  ^-  (quip card _state)
  =.  registry  (revive-desk:jibb-host registry desk)
  ?:  ?|  ?=(^ (route-for-desk:jibb-host routes.registry desk))
          ?=(^ (route-for-desk:jibb-host pending.registry desk))
      ==
    [~ state]
  =/  our=@ta  (scot %p our.bowl)
  =/  now=@ta  (scot %da now.bowl)
  ?.  (jibb-desk our now desk)  [~ state]
  =/  doc=(unit noun)  (read-docket our now desk)
  ?~  doc  [~ state]
  =/  site=(unit path)  (docket-site:jibb-host u.doc)
  ?~  site  [~ state]
  =/  next=(each transition:jibb-host @t)
    (add-pending:jibb-host dap.bowl registry [desk u.site])
  ?:  ?=(%| -.next)  ~|(p.next !!)
  [cards.p.next state(registry registry.p.next)]
::  Eyre bound a pending route: publish it, watch its commits and build.
++  bound
  |=  [=desk accepted=?]
  ^-  (quip card _state)
  =/  pending=?  ?=(^ (route-for-desk:jibb-host pending.registry desk))
  =/  next=transition:jibb-host
    (acknowledge-bind:jibb-host registry desk accepted)
  =.  registry  registry.next
  ?.  pending  [cards.next state]
  =/  published=(unit route:jibb-host)
    (route-for-desk:jibb-host routes.registry desk)
  ?~  published  [cards.next state]
  =^  cards  state  (watch-and-build u.published)
  [(weld cards.next cards) state]
++  watch-and-build
  |=  r=route:jibb-host
  ^-  (quip card _state)
  =/  rev=@ud  (current-rev desk.r)
  =.  watched  (~(put by watched) desk.r rev)
  =^  cards  state  (start-build r rev)
  [[(unwatch-card desk.r) (watch-card desk.r rev) cards] state]
++  rebuild-published
  ^-  (quip card _state)
  =/  routes=(list route:jibb-host)  routes.registry
  =|  cards=(list card)
  |-
  ?~  routes  [cards state]
  =^  more  state  (watch-and-build i.routes)
  $(routes t.routes, cards (weld cards more))
::
::  Builds
::
::  A commit to a published desk starts a build at its new revision; one
::  already running for an older revision is abandoned, but what it
::  computed stays in the desk's store for the new one.
++  commit
  |=  =desk
  ^-  (quip card _state)
  =/  route=(unit route:jibb-host)  (route-for-desk:jibb-host routes.registry desk)
  ?~  route  [~ state]
  =/  rev=@ud  (current-rev desk)
  ::  Duplicate subscriptions report the same revision; only the first
  ::  renews the subscription, so the duplicates end here.
  ?:  (lte rev (~(gut by watched) desk 0))  [~ state]
  =.  watched  (~(put by watched) desk rev)
  =^  cards  state  (start-build u.route rev)
  [[(watch-card desk rev) cards] state]
++  start-build
  |=  [r=route:jibb-host rev=@ud]
  ^-  (quip card _state)
  =/  running=(unit build:jibb-host)  (~(get by builds) desk.r)
  ?:  &(?=(^ running) =(rev rev.u.running))  [~ state]
  :-  ~[(wake-card desk.r rev)]
  state(builds (~(put by builds) desk.r (new-build:jibb-host rev base.r)))
++  wake
  |=  [=desk rev=@ud]
  ^-  (quip card _state)
  =/  current=(unit build:jibb-host)  (~(get by builds) desk)
  ?~  current  [~ state]
  ?.  &(=(rev rev.u.current) ?=(~ waiting.u.current))  [~ state]
  (advance desk u.current)
::  Clay answered whether a file builds; the build goes on in this event.
++  built-file
  |=  [=desk rev=@ud at=path ok=?]
  ^-  (quip card _state)
  =/  current=(unit build:jibb-host)  (~(get by builds) desk)
  ?~  current  [~ state]
  ?.  &(=(rev rev.u.current) =(`at waiting.u.current))  [~ state]
  %+  advance  desk
  u.current(waiting ~, buildable (~(put by buildable.u.current) at ok))
::  Run steps until one has done compiler work, then wait for the next
::  wake.  Steps whose results are cached cost nothing and run on.  A
::  %build step waits for Clay instead.
++  advance
  |=  [=desk b=build:jibb-host]
  ^-  (quip card _state)
  =/  s=store:jibb-host  (~(gut by stores) desk *store:jibb-host)
  |-
  ?~  steps.b  (publish desk b s)
  =/  step=build-step:jibb-host  i.steps.b
  =/  rest=build:jibb-host  b(steps t.steps.b)
  ?:  ?=(%publish -.step)  (publish desk rest s)
  ?:  ?=(%build -.step)
    ?:  (~(has by buildable.rest) at.step)  $(b rest)
    :-  ~[(build-card desk rev.b at.step)]
    %=  state
      builds  (~(put by builds) desk rest(waiting `at.step))
      stores  (~(put by stores) desk s)
    ==
  =/  made=(each [work=? b=build:jibb-host s=store:jibb-host] tang)
    (mule |.((run-step desk step rest s)))
  =/  next=[work=? b=build:jibb-host s=store:jibb-host]
    ?:  ?=(%& -.made)  p.made
    =/  message=@t  (trace-error 'static build: Clay source read or compiler execution failed' p.made)
    [& rest(failure `message) s]
  ?^  failure.b.next  (publish desk b.next s.next)
  ?.  work.next  $(b b.next, s s.next)
  :-  ~[(wake-card desk rev.b)]
  state(builds (~(put by builds) desk b.next), stores (~(put by stores) desk s.next))
++  run-step
  |=  [=desk step=build-step:jibb-host b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  ?-  -.step
    %build    [| b s]
    %scan     (scan-step desk b s)
    %prelude  (prelude-step desk b s)
    %sur      (sur-step desk name.step b s)
    %mark     (mark-step desk name.step b s)
    %check    (check-step desk at.step b s)
    %render   (render-step desk at.step b s)
    %publish  [| b s]
  ==
::  A completed build replaces the pages it was built for, failed pages
::  included (doc question: see docs/open-questions.md).  A desk-level
::  failure keeps the store, so the next build reuses what still holds.
++  publish
  |=  [=desk b=build:jibb-host s=store:jibb-host]
  ^-  (quip card _state)
  =/  served=desk-pages:jibb-host
    ?^  failure.b  [~ failure.b]
    [served.b ~]
  =/  kept=store:jibb-host  ?^(failure.b s (prune-store:jibb-host s b))
  :-  ~
  %-  (slog (build-report desk b s))
  %=  state
    pages   (~(put by pages) desk served)
    builds  (~(del by builds) desk)
    stores  (~(put by stores) desk kept)
    built   (~(put by built) desk [rev.b (built-modules:jibb-host s b)])
  ==
::  Each error this build found, with its file, line, column and excerpt.
++  build-report
  |=  [=desk b=build:jibb-host s=store:jibb-host]
  ^-  tang
  =/  head=tape  "jibb: %{(trip desk)} revision {(scow %ud rev.b)}"
  ?^  failure.b
    ~[leaf+"{head} failed to build" leaf+(trip u.failure.b)]
  =/  checks=(list tank)
    %+  murn  ~(val by check-keys.b)
    |=  key=@uv
    =/  entry=(unit checked:jibb-host)  (~(get by checks.s) key)
    ?~  entry  ~
    ?.  &(=(rev.b rev.u.entry) ?=(%| -.result.u.entry))  ~
    `leaf+(trip p.result.u.entry)
  =/  renders=(list tank)
    %+  murn  ~(val by render-keys.b)
    |=  key=@uv
    =/  entry=(unit rendered:jibb-host)  (~(get by renders.s) key)
    ?~  entry  ~
    ?.  &(=(rev.b rev.u.entry) ?=(%| -.result.u.entry))  ~
    `leaf+(trip p.result.u.entry)
  =/  summary=tape
    "{head}: checked {(scow %ud checked.b)} modules, rendered {(scow %ud rendered.b)} pages"
  [leaf+summary (weld checks renders)]
::
::  Build steps.  Each reads Clay at the build's own revision.
::
++  scan-step
  |=  [=desk b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  ?.  (~(gut by buildable.b) /lib/jibb-build/hoon |)
    [& b(failure `'static build: /lib/jibb-build.hoon does not build') s]
  ?.  (~(gut by buildable.b) /lib/jibb-import/hoon |)
    [& b(failure `'static build: /lib/jibb-import.hoon does not build') s]
  =/  pre=path  (desk-path desk rev.b)
  =/  files=(list path)  .^((list path) %ct pre)
  =/  assets=(list path)
    %+  turn
      (skim files |=(at=path ?=(^ (prefix:jibb-host /ui/static at))))
    application-asset:jibb-host
  =/  sources=(list path)  (sort (skim files ui-file) aor)
  =/  bundle=(each (list [at=path source=@t]) @t)  (read-all pre sources)
  ?:  ?=(%| -.bundle)  [& b(failure `p.bundle) s]
  =/  renderer-at=path  /lib/jibb/renderer/jibb
  =/  renderer=(each @t @t)  (read-clay pre renderer-at)
  ?:  ?=(%| -.renderer)  [& b(failure `p.renderer) s]
  =/  builder=vase  (builder-vase pre)
  =/  theme-at=path  /ui/theme/jibb
  =/  theme=(each @t @t)
    ?:  (has-file files theme-at)  (read-clay pre theme-at)
    [%& !<(@t (slap builder (ream 'default-theme-source')))]
  ?:  ?=(%| -.theme)  [& b(failure `p.theme) s]
  ::  The compiler, prelude, renderer and collection reader identify the
  ::  build environment; the prelude step reports a missing reader.
  =/  collections=path  /sur/jibb-collections/hoon
  =/  env=@uv
    %-  sham
    :+  %jibb-env-1
      .^(@uvI %cz (weld pre /lib))
    ?.((has-file files collections) 0v0 .^(@uvI %cz (weld pre collections)))
  =/  roots=(list [at=path source=@t])
    ?:  (lien p.bundle |=(m=[at=path source=@t] =(at.m theme-at)))
      (snoc p.bundle [renderer-at p.renderer])
    (weld p.bundle ~[[theme-at p.theme] [renderer-at p.renderer]])
  =/  table=[modules=(map path module-info:jibb-host) s=store:jibb-host]
    (module-table env (slap builder (ream 'module-outline')) roots s)
  =/  modules=(map path module-info:jibb-host)  modules.table
  =.  s  s.table
  ::  Every /sur source supplies mark origins.  Only the Hoon files the
  ::  modules import are read for types, found as Clay finds them.
  =/  sur-sources=(each (list [module=term at=path source=@t]) @t)
    %+  read-named  pre
    %+  murn  files
    |=(at=path (bind (hoon-name:jibb-host %sur at) |=(name=term [name at])))
  ?:  ?=(%| -.sur-sources)  [& b(failure `p.sur-sources) s]
  =/  all=(list path)  ~(tap in ~(key by modules))
  =/  sur-files=(map term path)
    (fit-files files %sur (closure-surs:jibb-host modules all))
  =/  mark-files=(map term path)
    (fit-files files %mar (closure-marks:jibb-host modules all))
  =/  mark-sources=(each (list [module=term at=path source=@t]) @t)
    (read-named pre ~(tap by mark-files))
  ?:  ?=(%| -.mark-sources)  [& b(failure `p.mark-sources) s]
  =/  surs-hash=@uv  (sham p.sur-sources)
  =/  mars-hash=@uv
    ?.  (lien files |=(at=path ?=([%mar *] at)))  0v0
    .^(@uvI %cz (weld pre /mar))
  =/  sur-keys=(map term @uv)
    %-  malt
    %+  murn  p.sur-sources
    |=  [module=term at=path source=@t]
    ?.  =(`at (~(get by sur-files) module))  ~
    `[module (sur-key:jibb-host env module source surs-hash)]
  =/  mark-keys=(map term @uv)
    %-  malt
    %+  turn  p.mark-sources
    |=  [module=term at=path source=@t]
    [module (mark-key:jibb-host env module source surs-hash mars-hash)]
  =/  prelude=@uv  (prelude-key:jibb-host env)
  =/  order=(list path)  (module-order:jibb-host modules)
  =/  sites=(list [at=path site=(list @t)])
    %+  murn  sources
    |=  at=path
    =/  site=(unit (list @t))  (page-site:jibb-host at)
    ?~(site ~ `[at u.site])
  =/  setup=(list build-step:jibb-host)
    ?:((~(has by preludes.s) prelude) ~ ~[[%prelude ~]])
  ::  A Hoon file is read for types only once Clay says it builds.
  =/  readers=(list build-step:jibb-host)
    %+  weld
      %-  step-pairs
      %+  murn  ~(tap by sur-keys)
      |=  [n=term k=@uv]
      ^-  (unit [build-step:jibb-host build-step:jibb-host])
      ?:  (~(has by surs.s) k)  ~
      `[[%build (~(got by sur-files) n)] [%sur n]]
    %-  step-pairs
    %+  murn  ~(tap by mark-keys)
    |=  [n=term k=@uv]
    ^-  (unit [build-step:jibb-host build-step:jibb-host])
    ?:  (~(has by marks.s) k)  ~
    `[[%build (~(got by mark-files) n)] [%mark n]]
  =/  checks=(list build-step:jibb-host)
    (turn order |=(at=path [%check at]))
  =/  renders=(list build-step:jibb-host)
    (turn sites |=([at=path *] [%render at]))
  =/  steps=(list build-step:jibb-host)
    :(weld setup readers checks renders `(list build-step:jibb-host)`~[[%publish ~]])
  :+  &
    %=  b
      steps        steps
      env          env
      modules      modules
      order        order
      sites        sites
      assets       assets
      theme        theme-at
      renderer     renderer-at
      prelude      prelude
      sur-files    sur-files
      mark-files   mark-files
      sur-sources  p.sur-sources
      sur-keys     sur-keys
      mark-keys    mark-keys
    ==
  s
++  prelude-step
  |=  [=desk b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  =/  made=(each (each * @t) tang)  (mule |.((prepare-clay (desk-path desk rev.b))))
  =/  value=(each * @t)
    ?:  ?=(%& -.made)  p.made
    [%| (trace-error 'static build: compiler crashed while preparing the prelude' p.made)]
  [& b s(preludes (~(put by preludes.s) prelude.b value))]
++  sur-step
  |=  [=desk name=term b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  =/  key=@uv  (~(got by sur-keys.b) name)
  =/  at=path  (~(got by sur-files.b) name)
  =/  files=(list [module=term at=path source=@t])
    (skim sur-sources.b |=(f=[module=term at=path source=@t] =(at.f at)))
  ?>  ?=([* ~] files)
  =/  value=(each (list [module=term name=term result=*]) @t)
    ?.  (~(gut by buildable.b) at |)
      [%| (crip "static build: cannot build imported Hoon source {(show-file:jibb at)}")]
    =/  made=(each (each (list [module=term name=term result=*]) @t) tang)
      (mule |.((read-sur (desk-path desk rev.b) i.files)))
    ?:  ?=(%| -.made)
      [%| (trace-error (crip "static build: Hoon reader crashed on {(show-file:jibb at)}") p.made)]
    ?:  ?=(%& -.p.made)  p.made
    [%| (crip "{(show-file:jibb at)}: {(trip p.p.made)}")]
  [& b s(surs (~(put by surs.s) key [(sham value) value]))]
++  mark-step
  |=  [=desk name=term b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  =/  key=@uv  (~(got by mark-keys.b) name)
  =/  pre=path  (desk-path desk rev.b)
  =/  at=path  (~(got by mark-files.b) name)
  =/  value=*
    ?.  (~(gut by buildable.b) at |)
      [%| (crip "Hoon mark could not be built through Clay: {(show-file:jibb at)}")]
    =/  made=(each * tang)
      %-  mule  |.
      =/  built=vase  .^(vase %ca (weld pre at))
      =/  read-mark=vase  (slap (reader-vase pre) (ream 'read-mark-source-diagnostic'))
      +:(slym read-mark [name sur-sources.b p.built])
    ?:  ?=(%& -.made)  p.made
    [%| (trace-error (crip "static build: Hoon mark reader crashed on {(show-file:jibb at)}") p.made)]
  [& b s(marks (~(put by marks.s) key [(sham value) value]))]
++  check-step
  |=  [=desk at=path b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  =/  info=module-info:jibb-host  (~(got by modules.b) at)
  =/  closure=(list path)  (module-closure:jibb-host modules.b at)
  =/  surs=(list term)  (closure-surs:jibb-host modules.b closure)
  =/  marks=(list term)  (closure-marks:jibb-host modules.b closure)
  =/  key=@uv
    %:  check-key:jibb-host
      env.b
      prelude.b
      (turn closure |=(p=path [p hash:(~(got by modules.b) p)]))
      (turn surs |=(n=term [n (sur-hash b s n)]))
      (turn marks |=(n=term [n (mark-hash b s n)]))
    ==
  =.  check-keys.b  (~(put by check-keys.b) at key)
  ?:  (~(has by checks.s) key)  [| b s]
  =/  result=(each [kind=@tas interface=* artifact=*] @t)
    (check-module desk at info closure surs marks b s)
  [& b(checked +(checked.b)) s(checks (~(put by checks.s) key [rev.b result]))]
++  render-step
  |=  [=desk at=path b=build:jibb-host s=store:jibb-host]
  ^-  [work=? b=build:jibb-host s=store:jibb-host]
  =/  site=(list @t)
    =/  found=(list [at=path site=(list @t)])
      (skim sites.b |=(e=[at=path site=(list @t)] =(at.e at)))
    ?~(found ~ site.i.found)
  =/  page=(each [kind=@tas interface=* artifact=*] @t)  (check-result b s at)
  ::  Libraries, islands and stores are only imported.  A module that fails
  ::  to check shows its error at its route only if it may be a page.
  ?:  ?=(%| -.page)
    ?.  main:(~(got by modules.b) at)  [| b s]
    [| (serve-page b site (failed-page:jibb-host p.page)) s]
  ?:  =(%page kind.p.page)  [| (serve-page b site dynamic-page:jibb-host) s]
  ?.  =(%static-page kind.p.page)  [| b s]
  =/  theme=(each [kind=@tas interface=* artifact=*] @t)  (check-result b s theme.b)
  ?:  ?=(%| -.theme)  [| (serve-page b site (failed-page:jibb-host p.theme)) s]
  =/  renderer=(each [kind=@tas interface=* artifact=*] @t)  (check-result b s renderer.b)
  ?:  ?=(%| -.renderer)  [| (serve-page b site (failed-page:jibb-host p.renderer)) s]
  =/  key=@uv
    %:  render-key:jibb-host
      env.b
      (~(got by check-keys.b) at)
      (~(got by check-keys.b) theme.b)
      (~(got by check-keys.b) renderer.b)
      base.b
      assets.b
    ==
  =.  render-keys.b  (~(put by render-keys.b) at key)
  =/  cached=(unit rendered:jibb-host)  (~(get by renders.s) key)
  ?^  cached  [| (serve-page b site (rendered-page result.u.cached)) s]
  =/  result=(each @t @t)
    (render-page desk at b s artifact.p.page artifact.p.theme artifact.p.renderer)
  :+  &
    (serve-page b(rendered +(rendered.b)) site (rendered-page result))
  s(renders (~(put by renders.s) key [rev.b result]))
::
::  Step helpers
::
++  trace-error
  |=  [message=@t trace=tang]
  ^-  @t
  =/  lines=wall  (zing (turn (flop trace) |=(line=tank (wash [0 80] line))))
  (of-wain:format [message (turn lines crip)])
++  read-clay
  |=  [pre=path at=path]
  ^-  (each @t @t)
  ?.  .^(? %cu (weld pre at))
    [%| (crip "static build: cannot read Clay source {(show-file:jibb at)}")]
  [%& .^(@t %cx (weld pre at))]
++  read-all
  |=  [pre=path paths=(list path)]
  ^-  (each (list [at=path source=@t]) @t)
  =|  out=(list [at=path source=@t])
  |-
  ?~  paths  [%& (flop out)]
  =/  source=(each @t @t)  (read-clay pre i.paths)
  ?:  ?=(%| -.source)  source
  $(paths t.paths, out [[i.paths p.source] out])
++  read-named
  |=  [pre=path files=(list [module=term at=path])]
  ^-  (each (list [module=term at=path source=@t]) @t)
  =|  out=(list [module=term at=path source=@t])
  |-
  ?~  files  [%& (flop out)]
  =/  source=(each @t @t)  (read-clay pre at.i.files)
  ?:  ?=(%| -.source)  source
  $(files t.files, out [[module.i.files at.i.files p.source] out])
++  has-file
  |=  [files=(list path) at=path]
  ^-  ?
  (lien files |=(f=path =(f at)))
::  Only the named Hoon files the modules import; unused ones never build.
++  step-pairs
  |=  pairs=(list [build-step:jibb-host build-step:jibb-host])
  ^-  (list build-step:jibb-host)
  ?~  pairs  ~
  [-.i.pairs +.i.pairs $(pairs t.pairs)]
::  The file each /- or /% name selects, as Clay's fit-path finds it.  A
::  name with no file is left out; checking an importer reports it.
++  fit-files
  |=  [files=(list path) folder=@ta names=(list term)]
  ^-  (map term path)
  %-  malt
  %+  murn  names
  |=  name=term
  =/  found=(list path)
    %+  skim
      %+  turn  (name-paths:jibb-host name)
      |=(segments=path `path`[folder (snoc segments %hoon)])
    |=(at=path (has-file files at))
  ?~(found ~ `[name i.found])
::  A /- or /% import in the closure that names no file, with its importer.
++  missing-import
  |=  [b=build:jibb-host closure=(list path)]
  ^-  (unit @t)
  =/  infos=(list module-info:jibb-host)
    (murn closure |=(p=path (~(get by modules.b) p)))
  |-
  ?~  infos  ~
  =/  file=tape  (show-file:jibb at.i.infos)
  =/  sur=(list term)  (skip surs.i.infos |=(n=term (~(has by sur-files.b) n)))
  ?^  sur
    `(crip "static build: {file} imports /- {(trip i.sur)}, which has no /sur file")
  =/  mark=(list term)  (skip marks.i.infos |=(n=term (~(has by mark-files.b) n)))
  ?^  mark
    `(crip "static build: {file} imports /% %{(trip i.mark)}, which has no /mar file")
  $(infos t.infos)
++  ui-file
  |=  at=path
  ^-  ?
  ?.  ?=([%ui *] at)  |
  =/  reversed=(list @ta)  (flop t.at)
  &(?=(^ reversed) =(%jibb i.reversed))
++  builder-vase
  |=  pre=path
  ^-  vase
  .^(vase %ca (weld pre /lib/jibb-build/hoon))
++  reader-vase
  |=  pre=path
  ^-  vase
  .^(vase %ca (weld pre /lib/jibb-import/hoon))
++  module-table
  |=  [env=@uv gate=vase roots=(list [at=path source=@t]) s=store:jibb-host]
  ^-  [modules=(map path module-info:jibb-host) s=store:jibb-host]
  =|  out=(map path module-info:jibb-host)
  |-
  ?~  roots  [out s]
  =/  hash=@uv  (sham source.i.roots)
  =/  key=@uv  (imports-key:jibb-host env at.i.roots hash)
  =/  found=(unit [jibb=(list path) surs=(list term) marks=(list term) main=?])
    (~(get by imports.s) key)
  =/  outline=[jibb=(list path) surs=(list term) marks=(list term) main=?]
    ?^  found  u.found
    !<  [jibb=(list path) surs=(list term) marks=(list term) main=?]
    (slam gate !>([at.i.roots source.i.roots]))
  %=  $
    roots      t.roots
    out        (~(put by out) at.i.roots [at.i.roots source.i.roots hash outline])
    imports.s  (~(put by imports.s) key outline)
  ==
::  The prelude a desk's compiler prepares is the one its own manifest,
::  /lib/jibb/prelude-groups.txt, names, as the eval tools read it: groups
::  with their faces, private sources, and certified collection readers.
++  prepare-clay
  |=  pre=path
  ^-  (each * @t)
  =/  public=(each @t @t)  (read-clay pre /lib/jibb/prelude/jibb)
  ?:  ?=(%| -.public)  public
  =/  private=(each @t @t)  (read-clay pre /lib/jibb/internal/jibb)
  ?:  ?=(%| -.private)  private
  =/  manifest-at=path  /lib/jibb/prelude-groups/txt
  ?.  .^(? %cu (weld pre manifest-at))
    [%| 'static build: cannot read /lib/jibb/prelude-groups.txt']
  =/  manifest=(each prelude-manifest @t)
    (read-manifest .^(wain %cx (weld pre manifest-at)))
  ?:  ?=(%| -.manifest)  manifest
  =/  groups=(each (list iprelude-group-source:jibb) @t)
    =|  out=(list iprelude-group-source:jibb)
    =/  entries=(list [face=term at=path])  groups.p.manifest
    |-
    ?~  entries  [%& (flop out)]
    =/  source=(each @t @t)  (read-clay pre at.i.entries)
    ?:  ?=(%| -.source)  source
    $(entries t.entries, out [[face.i.entries at.i.entries p.source] out])
  ?:  ?=(%| -.groups)  groups
  =/  sources=(each (list [at=path source=@t]) @t)  (read-all pre sources.p.manifest)
  ?:  ?=(%| -.sources)  sources
  =/  reader-files=(list path)
    %+  sort
      ~(tap in (silt (turn readers.p.manifest |=(r=[module=term at=path name=term] at.r))))
    aor
  =/  reader-sources=(each (list [at=path source=@t]) @t)  (read-all pre reader-files)
  ?:  ?=(%| -.reader-sources)  reader-sources
  =/  read-generic=vase  (slap (reader-vase pre) (ream 'read-generic-source'))
  =/  externals=(each iexternals:jibb @t)
    =|  out=iexternals:jibb
    =/  entries=(list [module=term at=path name=term])  readers.p.manifest
    |-
    ?~  entries  [%& (flop out)]
    =/  file=tape  (show-file:jibb at.i.entries)
    =/  found=(list [at=path source=@t])
      (skim p.reader-sources |=(f=[at=path source=@t] =(at.f at.i.entries)))
    ?~  found  [%| (crip "static build: cannot read the prelude reader {file}")]
    =/  core=(each type tang)  (mule |.(-:(ride -:!>(..zuse) source.i.found)))
    ?:  ?=(%| -.core)  [%| (crip "static build: cannot rebuild the prelude reader {file}")]
    =/  read=(each imported:jibb-import @t)
      !<  (each imported:jibb-import @t)
      %+  slam  read-generic
      !>([module.i.entries name.i.entries at.i.entries source.i.found p.core])
    ?:  ?=(%| -.read)
      [%| (crip "static build: prelude reader {file} {(trip name.i.entries)}: {(trip p.read)}")]
    $(entries t.entries, out [[module.i.entries name.i.entries read] out])
  ?:  ?=(%| -.externals)  externals
  =/  modules=jbundle:jibb  (weld p.sources p.reader-sources)
  =/  prepare=vase  (slap (builder-vase pre) (ream 'prepare-lowering'))
  =/  prepared=vase
    (slym prepare [p.public p.private p.groups modules p.externals])
  ?~  +.prepared  [%| 'static build: checked Clay prelude did not prepare']
  [%& +>.prepared]
::  A manifest line is `group FACE /path`, `source /path` or
::  `reader MODULE /sur/MODULE ARM`, with `#` starting a comment.
+$  prelude-manifest
  $:  groups=(list [face=term at=path])
      sources=(list path)
      readers=(list [module=term at=path name=term])
  ==
++  read-manifest
  |=  lines=wain
  ^-  (each prelude-manifest @t)
  =|  groups=(list [face=term at=path])
  =|  sources=(list path)
  =|  readers=(list [module=term at=path name=term])
  =/  number=@ud  1
  |-
  ?~  lines  [%& (flop groups) (flop sources) (flop readers)]
  =/  words=(list tape)  (manifest-words i.lines)
  =/  bad=@t  (crip "static build: invalid prelude manifest entry at line {(scow %ud number)}")
  ?~  words  $(lines t.lines, number +(number))
  ?:  =("group" i.words)
    ?.  ?=([* * ~] t.words)  [%| bad]
    =/  face=(unit term)  (rush (crip i.t.words) sym)
    =/  at=(unit path)  (rush (crip i.t.t.words) stap)
    ?:  |(?=(~ face) ?=(~ at))  [%| bad]
    $(lines t.lines, number +(number), groups [[u.face (snoc u.at %jibb)] groups])
  ?:  =("source" i.words)
    ?.  ?=([* ~] t.words)  [%| bad]
    =/  at=(unit path)  (rush (crip i.t.words) stap)
    ?~  at  [%| bad]
    $(lines t.lines, number +(number), sources [(snoc u.at %jibb) sources])
  ?.  =("reader" i.words)  [%| bad]
  ?.  ?=([* * * ~] t.words)  [%| bad]
  =/  module=(unit term)  (rush (crip i.t.words) sym)
  =/  at=(unit path)  (rush (crip i.t.t.words) stap)
  =/  name=(unit term)  (rush (crip i.t.t.t.words) sym)
  ?:  |(?=(~ module) ?=(~ at) ?=(~ name))  [%| bad]
  ?.  =(u.at /sur/[u.module])  [%| bad]
  $(lines t.lines, number +(number), readers [[u.module (snoc u.at %hoon) u.name] readers])
++  manifest-words
  |=  line=@t
  ^-  (list tape)
  =/  text=tape  (trip line)
  =/  comment=(unit @ud)  (find "#" text)
  =?  text  ?=(^ comment)  (scag u.comment text)
  =|  word=tape
  =|  out=(list tape)
  |-
  ?~  text  (flop ?~(word out [(flop word) out]))
  ?:  |(=(' ' i.text) =('\09' i.text))
    $(text t.text, word ~, out ?~(word out [(flop word) out]))
  $(text t.text, word [i.text word])
::  Called only once Clay has said the file builds.
++  read-sur
  |=  [pre=path file=[module=term at=path source=@t]]
  ^-  (each (list [module=term name=term result=*]) @t)
  =/  built=vase  .^(vase %ca (weld pre at.file))
  =/  read-module=vase  (slap (reader-vase pre) (ream 'read-module'))
  !<  (each (list [module=term name=term result=*]) @t)
  (slam read-module !>([module.file at.file source.file p.built]))
++  sur-hash
  |=  [b=build:jibb-host s=store:jibb-host name=term]
  ^-  (unit @uv)
  =/  key=(unit @uv)  (~(get by sur-keys.b) name)
  ?~  key  ~
  =/  entry=(unit [hash=@uv value=(each (list [module=term name=term result=*]) @t)])
    (~(get by surs.s) u.key)
  ?~(entry ~ `hash.u.entry)
++  mark-hash
  |=  [b=build:jibb-host s=store:jibb-host name=term]
  ^-  (unit @uv)
  =/  key=(unit @uv)  (~(get by mark-keys.b) name)
  ?~  key  ~
  =/  entry=(unit [hash=@uv value=*])  (~(get by marks.s) u.key)
  ?~(entry ~ `hash.u.entry)
++  check-result
  |=  [b=build:jibb-host s=store:jibb-host at=path]
  ^-  (each [kind=@tas interface=* artifact=*] @t)
  =/  missing=@t  (crip "static build: {(spud at)} was not checked")
  =/  key=(unit @uv)  (~(get by check-keys.b) at)
  ?~  key  [%| missing]
  =/  entry=(unit checked:jibb-host)  (~(get by checks.s) u.key)
  ?~  entry  [%| missing]
  result.u.entry
::  Each dependency's own checked interface and artifact; a failed one is
::  left out, so its importer's check reports the failure in context.
++  check-module
  |=  $:  =desk
          at=path
          info=module-info:jibb-host
          closure=(list path)
          surs=(list term)
          marks=(list term)
          b=build:jibb-host
          s=store:jibb-host
      ==
  ^-  (each [kind=@tas interface=* artifact=*] @t)
  =/  prepared=(each * @t)
    (~(gut by preludes.s) prelude.b [%| 'static build: checked Clay prelude did not prepare'])
  ?:  ?=(%| -.prepared)  [%| p.prepared]
  =/  missing=(unit @t)  (missing-import b closure)
  ?^  missing  [%| u.missing]
  =/  sur-values=(list (each (list [module=term name=term result=*]) @t))
    %+  murn  surs
    |=  name=term
    =/  key=(unit @uv)  (~(get by sur-keys.b) name)
    ?~  key  ~
    =/  entry=(unit [hash=@uv value=(each (list [module=term name=term result=*]) @t)])
      (~(get by surs.s) u.key)
    ?~(entry ~ `value.u.entry)
  =/  failed=(list @t)
    %+  murn  sur-values
    |=(v=(each (list [module=term name=term result=*]) @t) ?:(?=(%| -.v) `p.v ~))
  ?^  failed  [%| i.failed]
  =/  externals=(list [module=term name=term result=*])
    %-  zing
    %+  murn  sur-values
    |=(v=(each (list [module=term name=term result=*]) @t) ?:(?=(%& -.v) `p.v ~))
  =/  mark-externals=(list [mark=term result=*])
    %+  murn  marks
    |=  name=term
    =/  key=(unit @uv)  (~(get by mark-keys.b) name)
    ?~  key  ~
    =/  entry=(unit [hash=@uv value=*])  (~(get by marks.s) u.key)
    ?~(entry ~ `[name value.u.entry])
  =/  modules=(list [at=path source=@t])
    (turn closure |=(p=path [p source:(~(got by modules.b) p)]))
  =/  deps=(list [at=path interface=* artifact=*])
    %+  murn  closure
    |=  p=path
    ?:  =(p at)  ~
    =/  entry=(each [kind=@tas interface=* artifact=*] @t)  (check-result b s p)
    ?:  ?=(%| -.entry)  ~
    `[p interface.p.entry artifact.p.entry]
  =/  gate=vase  (slap (builder-vase (desk-path desk rev.b)) (ream 'check-module'))
  =/  made=(each vase tang)
    %-  mule  |.
    %+  slym  gate
    :*  at
        source.info
        externals
        mark-externals
        modules
        (turn deps |=(d=[at=path interface=* artifact=*] [at.d interface.d]))
        (turn deps |=(d=[at=path interface=* artifact=*] [at.d artifact.d]))
        p.prepared
    ==
  ?:  ?=(%| -.made)
    [%| (trace-error (crip "static build: compiler crashed while checking {(spud at)}") p.made)]
  ;;((each [kind=@tas interface=* artifact=*] @t) q.p.made)
++  render-page
  |=  [=desk at=path b=build:jibb-host s=store:jibb-host page=* theme=* renderer=*]
  ^-  (each @t @t)
  =/  prepared=(each * @t)
    (~(gut by preludes.s) prelude.b [%| 'static build: checked Clay prelude did not prepare'])
  ?:  ?=(%| -.prepared)  [%| p.prepared]
  =/  closure=(list path)
    =/  paths=(list path)
      ;:  weld
        (module-closure:jibb-host modules.b at)
        (module-closure:jibb-host modules.b theme.b)
        (module-closure:jibb-host modules.b renderer.b)
      ==
    (sort ~(tap in (silt paths)) aor)
  =/  artifacts=(list [at=path artifact=*])
    %+  murn  closure
    |=  p=path
    =/  entry=(each [kind=@tas interface=* artifact=*] @t)  (check-result b s p)
    ?:  ?=(%| -.entry)  ~
    `[p artifact.p.entry]
  =/  gate=vase  (slap (builder-vase (desk-path desk rev.b)) (ream 'render-checked'))
  =/  made=(each vase tang)
    %-  mule  |.
    (slym gate [(crip (spud base.b)) page theme renderer artifacts p.prepared assets.b])
  ?:  ?=(%| -.made)  [%| 'static build: compiler crashed while rendering page']
  =/  output=(each [title=@t html=@t] @t)  ;;((each [title=@t html=@t] @t) q.p.made)
  ?:  ?=(%| -.output)  [%| p.output]
  [%& html.p.output]
++  serve-page
  |=  [b=build:jibb-host site=(list @t) page=cached-page:jibb-host]
  ^-  build:jibb-host
  b(served (~(put by served.b) site page))
++  rendered-page
  |=  result=(each @t @t)
  ^-  cached-page:jibb-host
  ?:  ?=(%& -.result)  (successful-page:jibb-host p.result)
  (failed-page:jibb-host p.result)
--
