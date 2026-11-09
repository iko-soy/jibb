::  /lib/jibb-host.hoon: shared host discovery, routing and HTTP policy
::
::  Clay scries stay in the agent.  Every transformation of discovered routes,
::  binding state, lifecycle state, requests and response cards is pure here.
::
=,  eyre
=,  clay
|%
+$  route  [desk=desk base=path]
+$  route-match  [route=route remaining=(list @t)]
+$  docket-entry  [desk=desk docket=(unit noun)]
+$  payload  simple-payload:http
+$  cached-page  [status=@ud result=(each @t @t)]
+$  desk-pages  [pages=(map (list @t) cached-page) error=(unit @t)]
+$  page-cache  (map desk desk-pages)
+$  registry
  $:  routes=(list route)
      pending=(list route)
      live=(set desk)
  ==
+$  transition  [registry=registry cards=(list card:agent:gall)]
::
::  Incremental builds.  A commit starts a build of the desk at that Clay
::  revision.  The build is a list of steps, run one compiler step per Behn
::  wake.  Every step's result is cached under a hash of its inputs, so a
::  module is checked again only when its own source, a source it imports,
::  or the reader results or prelude it uses changed.  The compiler's
::  certificates bind the same closure; a mismatch there is an error.
::
::  A module's imports, from the desk's own compiler.  main says it may be
::  a page: it defines main, or does not parse.  A failed library is not
::  routed.
+$  module-info
  $:  at=path
      source=@t
      hash=@uv
      jibb=(list path)
      surs=(list term)
      marks=(list term)
      main=?
  ==
::  A %build step asks Clay whether a Hoon file builds: Gall cannot catch
::  a failed scry, so a build that may fail is never scried first.
+$  build-step
  $%  [%build at=path]
      [%scan ~]
      [%prelude ~]
      [%sur name=term]
      [%mark name=term]
      [%check at=path]
      [%render at=path]
      [%publish ~]
  ==
::  A build in progress.  check-keys and render-keys name the store
::  entries the build uses; served holds the pages it has decided.  While
::  waiting holds a file, Clay's answer, not a Behn wake, resumes it.
+$  build
  $:  rev=@ud
      base=path
      steps=(list build-step)
      waiting=(unit path)
      env=@uv
      modules=(map path module-info)
      order=(list path)
      sites=(list [at=path site=(list @t)])
      assets=(list path)
      theme=path
      renderer=path
      prelude=@uv
      buildable=(map path ?)
      sur-files=(map term path)
      mark-files=(map term path)
      sur-sources=(list [module=term at=path source=@t])
      sur-keys=(map term @uv)
      mark-keys=(map term @uv)
      check-keys=(map path @uv)
      render-keys=(map path @uv)
      served=(map (list @t) cached-page)
      checked=@ud
      rendered=@ud
      failure=(unit @t)
  ==
::  A check or render records the revision whose build computed it.
+$  checked  [rev=@ud result=(each [kind=@tas interface=* artifact=*] @t)]
+$  rendered  [rev=@ud result=(each @t @t)]
::  The compiler's nouns are opaque here: each desk builds with its own.
+$  store
  $:  imports=(map @uv [jibb=(list path) surs=(list term) marks=(list term) main=?])
      preludes=(map @uv (each * @t))
      surs=(map @uv [hash=@uv value=(each (list [module=term name=term result=*]) @t)])
      marks=(map @uv [hash=@uv value=*])
      checks=(map @uv checked)
      renders=(map @uv rendered)
  ==
::  The last completed build: its revision, and when each module checked.
+$  built  [rev=@ud modules=(list [at=path rev=@ud])]
::
::  The desk's compiler and importer must build before the scan uses them.
++  new-build
  |=  [rev=@ud base=path]
  ^-  build
  =|  fresh=build
  =/  steps=(list build-step)
    ~[[%build /lib/jibb-build/hoon] [%build /lib/jibb-import/hoon] [%scan ~]]
  fresh(rev rev, base base, steps steps)
::
::  +module-closure: a module and everything it imports, transitively
::
::    Only modules of the build count; an import of a missing module adds
::    nothing, and checking the importer reports it.
++  module-closure
  |=  [modules=(map path module-info) at=path]
  ^-  (list path)
  =|  seen=(set path)
  =/  pending=(list path)  ~[at]
  |-
  ?~  pending  (sort ~(tap in seen) aor)
  ?:  (~(has in seen) i.pending)  $(pending t.pending)
  =/  info=(unit module-info)  (~(get by modules) i.pending)
  ?~  info  $(pending t.pending)
  $(pending (weld jibb.u.info t.pending), seen (~(put in seen) i.pending))
::
::  +module-order: every module after the modules it imports
::
::    Depth first from each module in path order; an edge back into the
::    current path is a cycle, which checking reports, so it is skipped.
++  module-order
  |=  modules=(map path module-info)
  ^-  (list path)
  =/  roots=(list path)  (sort ~(tap in ~(key by modules)) aor)
  =|  done=(set path)
  =|  out=(list path)
  |-
  ?~  roots  (flop out)
  =/  visit=[done=(set path) out=(list path)]
    (module-visit modules i.roots done out ~)
  $(roots t.roots, done done.visit, out out.visit)
::
++  module-visit
  |=  [modules=(map path module-info) at=path done=(set path) out=(list path) active=(set path)]
  ^-  [done=(set path) out=(list path)]
  ?:  |((~(has in done) at) (~(has in active) at))  [done out]
  =/  info=(unit module-info)  (~(get by modules) at)
  ?~  info  [done out]
  =/  inner=(set path)  (~(put in active) at)
  =/  deps=(list path)  (sort jibb.u.info aor)
  |-
  ?~  deps  [(~(put in done) at) [at out]]
  =/  visit=[done=(set path) out=(list path)]
    ^$(at i.deps, active inner)
  $(deps t.deps, done done.visit, out out.visit)
::
++  closure-surs
  |=  [modules=(map path module-info) closure=(list path)]
  ^-  (list term)
  =/  all=(list term)
    %-  zing
    %+  turn  closure
    |=  at=path
    =/  info=(unit module-info)  (~(get by modules) at)
    ?~(info ~ surs.u.info)
  (sort ~(tap in (silt all)) aor)
::
++  closure-marks
  |=  [modules=(map path module-info) closure=(list path)]
  ^-  (list term)
  =/  all=(list term)
    %-  zing
    %+  turn  closure
    |=  at=path
    =/  info=(unit module-info)  (~(get by modules) at)
    ?~(info ~ marks.u.info)
  (sort ~(tap in (silt all)) aor)
::
::  +name-paths: the paths, under /sur or /mar, a /- or /% name may select
::
::    As Clay's fit-path tries them: each dash stays or becomes a path
::    separator, left to right, a dash first, as a-b-c, a-b/c, a/b-c, a/b/c.
++  name-paths
  |=  name=@ta
  ^-  (list path)
  =/  parts=(list tape)  (dash-parts (trip name))
  ?~  parts  ~
  %+  turn  (name-joins i.parts t.parts)
  |=(segments=(list tape) (turn segments |=(segment=tape (crip segment))))
++  name-joins
  |=  [current=tape rest=(list tape)]
  ^-  (list (list tape))
  ?~  rest  ~[~[current]]
  %+  weld
    $(current :(weld current "-" i.rest), rest t.rest)
  %+  turn  $(current i.rest, rest t.rest)
  |=(segments=(list tape) `(list tape)`[current segments])
++  dash-parts
  |=  text=tape
  ^-  (list tape)
  =|  current=tape
  =|  out=(list tape)
  |-
  ?~  text  (flop [(flop current) out])
  ?:  =('-' i.text)  $(text t.text, out [(flop current) out], current ~)
  $(text t.text, current [i.text current])
::  +hoon-name: the /- or /% name of a Hoon file under folder, if any
++  hoon-name
  |=  [folder=@ta at=path]
  ^-  (unit term)
  ?.  ?=([@ *] at)  ~
  ?.  =(folder i.at)  ~
  =/  rev=(list @ta)  (flop t.at)
  ?.  ?=([%hoon ^] rev)  ~
  =/  segments=(list tape)  (turn (flop t.rev) trip)
  ?~  segments  ~
  =/  joined=tape  i.segments
  =/  rest=(list tape)  t.segments
  |-
  ?~  rest  `(crip joined)
  $(joined :(weld joined "-" i.rest), rest t.rest)
::
::  Cache keys.  env names the desk's compiler, prelude and collection
::  reader; every other key includes it.
++  imports-key
  |=  [env=@uv at=path hash=@uv]
  ^-  @uv
  (sham [%jibb-imports-1 env at hash])
++  prelude-key
  |=  env=@uv
  ^-  @uv
  (sham [%jibb-prelude-1 env])
::  A /sur file's type also depends on the /sur files it imports, and a
::  mark's on the /sur and /mar files it imports; its origin evidence is
::  read against every /sur source.  So surs hashes every /sur source and
::  mars the /mar tree; env covers /lib.
++  sur-key
  |=  [env=@uv module=term source=@t surs=@uv]
  ^-  @uv
  (sham [%jibb-sur-2 env module (sham source) surs])
++  mark-key
  |=  [env=@uv mark=term source=@t surs=@uv mars=@uv]
  ^-  @uv
  (sham [%jibb-mark-2 env mark (sham source) surs mars])
::  The closure's sources and the hashes of the reader results it uses.
++  check-key
  |=  $:  env=@uv
          prelude=@uv
          sources=(list [at=path hash=@uv])
          surs=(list [module=term hash=(unit @uv)])
          marks=(list [mark=term hash=(unit @uv)])
      ==
  ^-  @uv
  (sham [%jibb-check-1 env prelude sources surs marks])
++  render-key
  |=  [env=@uv page=@uv theme=@uv renderer=@uv base=path assets=(list path)]
  ^-  @uv
  (sham [%jibb-render-1 env page theme renderer base assets])
::
::  +prune-store: only the entries a completed build used
::
::    Entries an abandoned build computed for a later revision are dropped
::    too; that build starts again from its own scan.
++  prune-store
  |=  [s=store b=build]
  ^-  store
  =/  import-keys=(set @uv)
    %-  silt
    %+  turn  ~(val by modules.b)
    |=(m=module-info (imports-key env.b at.m hash.m))
  =/  sur-keys=(set @uv)  (silt ~(val by sur-keys.b))
  =/  mark-keys=(set @uv)  (silt ~(val by mark-keys.b))
  =/  check-keys=(set @uv)  (silt ~(val by check-keys.b))
  =/  render-keys=(set @uv)  (silt ~(val by render-keys.b))
  :*  (malt (skim ~(tap by imports.s) |=([k=@uv *] (~(has in import-keys) k))))
      (malt (skim ~(tap by preludes.s) |=([k=@uv *] =(k prelude.b))))
      (malt (skim ~(tap by surs.s) |=([k=@uv *] (~(has in sur-keys) k))))
      (malt (skim ~(tap by marks.s) |=([k=@uv *] (~(has in mark-keys) k))))
      (malt (skim ~(tap by checks.s) |=([k=@uv *] (~(has in check-keys) k))))
      (malt (skim ~(tap by renders.s) |=([k=@uv *] (~(has in render-keys) k))))
  ==
::
::  +built-modules: when each module of a build last checked
++  built-modules
  |=  [s=store b=build]
  ^-  (list [at=path rev=@ud])
  %+  sort
    %+  murn  ~(tap by check-keys.b)
    |=  [at=path key=@uv]
    =/  entry=(unit checked)  (~(get by checks.s) key)
    ?~(entry ~ `[at rev.u.entry])
  |=([a=[at=path *] b=[at=path *]] (aor at.a at.b))
::
++  noun-path
  |=  value=noun
  ^-  (unit path)
  ?~  value  [~ ~]
  ?@  value  ~
  ?^  -.value  ~
  =/  tail=(unit path)  $(value +.value)
  ?~  tail  ~
  [~ ;;(@ta -.value) u.tail]
::
++  docket-site
  |=  doc=noun
  ^-  (unit path)
  ::  Check the complete docket spine before selecting its href.  In
  ::  particular, never cast an arbitrary cell tail to a path.
  ?.  ?=([%1 @ @ @ * * [@ @ @] @ @] doc)  ~
  =/  href=noun  +62.doc
  ?.  ?=([%site *] href)  ~
  (noun-path +.href)
::
++  valid-route
  |=  r=route
  ^-  ?
  &(?=(^ base.r) ?=(^ (trip desk.r)))
::
++  validate-routes
  |=  routes=(list route)
  ^-  (each (list route) @t)
  =|  kept=(list route)
  |-
  ?~  routes  [%& (flop kept)]
  ?.  (valid-route i.routes)  [%| 'invalid Jibb host route']
  ?:  (lien kept |=(r=route =(base.r base.i.routes)))
    [%| 'duplicate Jibb host base path']
  ?:  (lien kept |=(r=route =(desk.r desk.i.routes)))
    [%| 'duplicate Jibb host desk']
  $(routes t.routes, kept [i.routes kept])
::
++  discover-routes
  |=  entries=(list docket-entry)
  ^-  (each (list route) @t)
  =|  routes=(list route)
  |-
  ?~  entries  (validate-routes (flop routes))
  ?~  docket.i.entries  $(entries t.entries)
  =/  site=(unit path)  (docket-site u.docket.i.entries)
  ?~  site  $(entries t.entries)
  $(entries t.entries, routes [[desk.i.entries u.site] routes])
::
++  live-desks
  |=  rock=rock:tire
  ^-  (set desk)
  =|  desks=(set desk)
  =/  entries=(list [=desk =zest wic=(set weft)])  ~(tap by rock)
  |-
  ?~  entries  desks
  =?  desks  ?=(%live zest.i.entries)
    (~(put in desks) desk.i.entries)
  $(entries t.entries)
::
++  parse-target
  |=  url=@t
  ^-  (unit [pork quay])
  (rush url ;~(plug apat:de-purl:html yque:de-purl:html))
::
++  target-site
  |=  url=@t
  ^-  (list @t)
  =/  parsed=(unit [pork quay])  (parse-target url)
  ?~  parsed  ~
  +5.u.parsed
::
++  application-asset
  |=  at=path
  ^-  path
  ?.  ?=([%ui *] at)  at
  t.at
::
++  prefix
  |=  [base=(list @t) site=(list @t)]
  ^-  (unit (list @t))
  ?~  base  `site
  ?~  site  ~
  ?.  =(i.base i.site)  ~
  $(base t.base, site t.site)
::
++  better-match
  |=  [a=route-match b=route-match]
  ^-  route-match
  ?:  (gth (lent base.route.a) (lent base.route.b))  a
  b
::
++  route-request
  |=  [routes=(list route) site=(list @t)]
  ^-  (unit route-match)
  =|  best=(unit route-match)
  |-
  ?~  routes  best
  =/  remaining=(unit (list @t))
    (prefix (turn base.i.routes |=(part=@ta (crip (trip part)))) site)
  =/  next=(unit route-match)
    ?~  remaining  best
    =/  candidate=route-match  [i.routes u.remaining]
    `?~(best candidate (better-match candidate u.best))
  $(routes t.routes, best next)
::
++  route-for-desk
  |=  [routes=(list route) =desk]
  ^-  (unit route)
  ?~  routes  ~
  ?:  =(desk desk.i.routes)  `i.routes
  $(routes t.routes)
::
++  drop-desk
  |=  [routes=(list route) =desk]
  ^-  (list route)
  (skip routes |=(r=route =(desk desk.r)))
::
++  binding
  |=  r=route
  ^-  binding:eyre
  [~ base.r]
::
++  bind-card
  |=  [app=term r=route]
  ^-  card:agent:gall
  [%pass /bind/[desk.r] %arvo %e %connect (binding r) app]
::
++  disconnect-card
  |=  r=route
  ^-  card:agent:gall
  [%pass /disconnect/[desk.r] %arvo %e %disconnect (binding r)]
::
++  tire-card
  ^-  card:agent:gall
  [%pass /desks %arvo %c %tire `~]
::
++  initialize
  |=  [app=term entries=(list docket-entry) live=(set desk)]
  ^-  (each transition @t)
  =/  found=(each (list route) @t)  (discover-routes entries)
  ?:  ?=(%| -.found)  found
  =/  pending=(list route)  p.found
  [%& [[~ pending live] (turn pending |=(r=route (bind-card app r)))]]
::
++  restore-cards
  |=  [app=term reg=registry]
  ^-  (list card:agent:gall)
  :-  tire-card
  (turn pending.reg |=(r=route (bind-card app r)))
::
++  add-pending
  |=  [app=term reg=registry r=route]
  ^-  (each transition @t)
  ?:  ?|  ?=(^ (route-for-desk routes.reg desk.r))
          ?=(^ (route-for-desk pending.reg desk.r))
      ==
    [%& [reg ~]]
  =/  checked=(each (list route) @t)
    (validate-routes [r (welp routes.reg pending.reg)])
  ?:  ?=(%| -.checked)  checked
  [%& [reg(pending [r pending.reg]) ~[(bind-card app r)]]]
::
++  acknowledge-bind
  |=  [reg=registry =desk accepted=?]
  ^-  transition
  =/  route=(unit route)  (route-for-desk pending.reg desk)
  ?~  route  [reg ~]
  =.  pending.reg  (drop-desk pending.reg desk)
  ?.  accepted  [reg ~]
  ?.  (~(has in live.reg) desk)
    [reg ~[(disconnect-card u.route)]]
  [reg(routes [u.route routes.reg]) ~]
::
++  reconcile-live
  |=  [reg=registry live=(set desk)]
  ^-  transition
  =|  cards=(list card:agent:gall)
  =/  old=(list route)  routes.reg
  |-
  ?~  old
    =.  routes.reg  (skip routes.reg |=(r=route !(~(has in live) desk.r)))
    [reg(live live) (flop cards)]
  =?  cards  !(~(has in live) desk.i.old)
    [(disconnect-card i.old) cards]
  $(old t.old)
::
++  retire-desk
  |=  [reg=registry =desk]
  ^-  transition
  =.  live.reg  (~(del in live.reg) desk)
  =/  route=(unit route)  (route-for-desk routes.reg desk)
  =.  routes.reg  (drop-desk routes.reg desk)
  ?~  route  [reg ~]
  [reg ~[(disconnect-card u.route)]]
::
++  revive-desk
  |=  [reg=registry =desk]
  ^-  registry
  reg(live (~(put in live.reg) desk))
::
++  login-redirect
  |=  url=@t
  ^-  payload
  =/  target=@t  (crip (en-urlt:html (trip url)))
  [[307 ~[['location' (rap 3 ~['/~/login?redirect=' target])]]] ~]
::
++  not-found
  ^-  payload
  [[404 ~] ~]
::
++  html-response
  |=  html=@t
  ^-  payload
  [[200 ~[['content-type' 'text/html; charset=utf-8']]] [~ [(met 3 html) html]]]
::
++  text-response
  |=  [status=@ud text=@t]
  ^-  payload
  [[status ~[['content-type' 'text/plain; charset=utf-8']]] [~ [(met 3 text) text]]]
::
++  method-not-allowed
  ^-  payload
  =/  text=@t  'method not allowed'
  [[405 ~[['content-type' 'text/plain; charset=utf-8'] ['allow' 'GET, HEAD']]] [~ [(met 3 text) text]]]
::
++  successful-page
  |=  html=@t
  ^-  cached-page
  [200 %& html]
::
++  failed-page
  |=  message=@t
  ^-  cached-page
  [500 %| message]
::
::  A checked page with data; the host serves those from milestone 5 on.
++  dynamic-page
  ^-  cached-page
  :+  501  %|
  'dynamic pages are a later-stage feature: unsupported module kind for static build: page'
::
++  page-site
  |=  at=path
  ^-  (unit (list @t))
  ?.  ?=([%ui *] at)  ~
  =/  reversed=(list @ta)  (flop t.at)
  ?~  reversed  ~
  ?.  =(%jibb i.reversed)  ~
  =/  parts=path  (flop t.reversed)
  ?~  parts  ~
  ?:  =(~[%theme] parts)  ~
  =/  site=path
    |-
    ?~  t.parts  ?:(=(%index i.parts) ~ parts)
    [i.parts $(parts t.parts)]
  `(turn site |=(part=@ta (crip (trip part))))
::
++  prune-pages
  |=  [cache=page-cache live=(set desk)]
  ^-  page-cache
  %-  ~(gas by *(map desk desk-pages))
  (skim ~(tap by cache) |=(entry=[=desk *] (~(has in live) desk.entry)))
::
++  authorize
  |=  [authenticated=? url=@t]
  ^-  (each ~ payload)
  ?:  authenticated  [%& ~]
  [%| (login-redirect url)]
::
++  unknown-asset
  |=  remaining=(list @t)
  ^-  ?
  ?|  ?=([%'static' *] remaining)
      ?=([%'~jibb' *] remaining)
  ==
::
::  A desk whose first build is still running has no pages to serve yet.
++  build-in-progress
  ^-  payload
  =/  text=@t  'static build in progress'
  :-  [503 ~[['content-type' 'text/plain; charset=utf-8'] ['retry-after' '5']]]
  [~ [(met 3 text) text]]
::
++  request-response
  |=  [routes=(list route) cache=page-cache authenticated=? =method:http url=@t]
  ^-  payload
  (serve routes cache ~ authenticated method url)
::
::  +serve: one request, given the desks whose builds are in progress
::
::    A completed build keeps serving while the next one runs.
++  serve
  |=  [routes=(list route) cache=page-cache building=(set desk) authenticated=? =method:http url=@t]
  ^-  payload
  =/  allowed=(each ~ payload)  (authorize authenticated url)
  ?:  ?=(%| -.allowed)  p.allowed
  =/  found=(unit route-match)  (route-request routes (target-site url))
  ?~  found  not-found
  ?:  (unknown-asset remaining.u.found)  not-found
  ?.  ?=(?(%'GET' %'HEAD') method)  method-not-allowed
  =/  result=payload
    =/  built=(unit desk-pages)  (~(get by cache) desk.route.u.found)
    ?~  built
      ?:  (~(has in building) desk.route.u.found)  build-in-progress
      not-found
    ?^  error.u.built  (text-response 500 u.error.u.built)
    =/  page=(unit cached-page)
      (~(get by pages.u.built) remaining.u.found)
    ?~  page  not-found
    ?:  ?=(%| -.result.u.page)
      (text-response status.u.page p.result.u.page)
    (html-response p.result.u.page)
  ?:  ?=(%'HEAD' method)  result(data ~)
  result
::
++  payload-header
  |=  result=payload
  ^-  response-header:http
  response-header.result
::
++  give-payload
  |=  [eyre-id=@ta result=payload]
  ^-  (list card:agent:gall)
  :~  [%give %fact ~[/http-response/[eyre-id]] %http-response-header !>(response-header.result)]
      [%give %fact ~[/http-response/[eyre-id]] %http-response-data !>(data.result)]
      [%give %kick ~[/http-response/[eyre-id]] ~]
  ==
--
