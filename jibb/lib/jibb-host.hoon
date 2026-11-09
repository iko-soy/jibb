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
  ?:  =('unsupported module kind for static build: page' message)
    :-  501
    :-  %|
    (cat 3 'dynamic pages are a later-stage feature: ' message)
  [500 %| message]
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
++  request-response
  |=  [routes=(list route) cache=page-cache authenticated=? =method:http url=@t]
  ^-  payload
  =/  allowed=(each ~ payload)  (authorize authenticated url)
  ?:  ?=(%| -.allowed)  p.allowed
  =/  found=(unit route-match)  (route-request routes (target-site url))
  ?~  found  not-found
  ?:  (unknown-asset remaining.u.found)  not-found
  ?.  ?=(?(%'GET' %'HEAD') method)  method-not-allowed
  =/  result=payload
    =/  built=(unit desk-pages)  (~(get by cache) desk.route.u.found)
    ?~  built  not-found
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
