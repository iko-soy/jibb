/+  jibb-host
|%
++  example-docket
  ^-  noun
  [1 'My App' 'info' 0x17.734f [%site /apps/my-app] ~ [0 1 0] '' 'MIT']
++  example-routes
  ^-  (list route:jibb-host)
  :~  [%my-app /apps/my-app]
      [%blog /apps/my-app/blog]
  ==
++  example-registry
  ^-  registry:jibb-host
  [~ ~ (sy ~[%my-app %blog %other])]
++  status
  |=  result=payload:jibb-host
  ^-  @ud
  status-code:(payload-header:jibb-host result)
++  test-docket-extraction-and-validation
  ^-  tang
  =/  doc=noun  example-docket
  =/  site=(unit path)  (docket-site:jibb-host doc)
  ?.  =(`/apps/my-app site)  ~[leaf+"docket site+ was not retained"]
  =/  glob=noun
    [1 'My App' 'info' 0x17.734f [%glob %main 0v0 %http ''] ~ [0 1 0] '' 'MIT']
  ?.  ?=(~ (docket-site:jibb-host glob))
    ~[leaf+"a glob docket became an agent-served site"]
  =/  bad-version=noun
    [2 'My App' 'info' 0x17.734f [%site /apps/my-app] ~ [0 1 0] '' 'MIT']
  ?.  ?=(~ (docket-site:jibb-host bad-version))
    ~[leaf+"an unsupported docket version was accepted"]
  =/  bad-path=noun
    [1 'My App' 'info' 0x17.734f [%site /apps/my-app] ~ [0 1 0] '' 'MIT']
  =.  +127.bad-path  [%cell 'tail']
  ?.  ?=(~ (docket-site:jibb-host bad-path))
    ~[leaf+"a malformed site path was cast to a route"]
  =/  entries=(list docket-entry:jibb-host)
    :~  [%my-app `doc]
        [%ignored ~]
        [%glob `glob]
    ==
  =/  found=(each (list route:jibb-host) @t)
    (discover-routes:jibb-host entries)
  ?:  ?=(%| -.found)  ~[leaf+(trip p.found)]
  ?.  =(~[[%my-app /apps/my-app]] p.found)
    ~[leaf+"missing, glob and site dockets were not distinguished"]
  ~
++  test-discovery-collisions-are-atomic
  ^-  tang
  =/  valid=(each (list route:jibb-host) @t)
    (validate-routes:jibb-host example-routes)
  ?:  ?=(%| -.valid)  ~[leaf+(trip p.valid)]
  =/  duplicate=(each (list route:jibb-host) @t)
    (validate-routes:jibb-host [[%other /apps/my-app] example-routes])
  ?.  ?=(%| -.duplicate)  ~[leaf+"duplicate base paths were accepted"]
  =/  same-desk=(each (list route:jibb-host) @t)
    (validate-routes:jibb-host [[%my-app /apps/other] example-routes])
  ?.  ?=(%| -.same-desk)  ~[leaf+"one desk received two base paths"]
  =/  invalid=(each (list route:jibb-host) @t)
    (validate-routes:jibb-host [[%my-app ~] ~])
  ?.  ?=(%| -.invalid)  ~[leaf+"an empty base path was accepted"]
  =/  entries=(list docket-entry:jibb-host)
    :~  [%my-app `example-docket]
        [%other `example-docket]
    ==
  =/  start=(each transition:jibb-host @t)
    (initialize:jibb-host %jibb entries (sy ~[%my-app %blog %other]))
  ?.  ?=(%| -.start)
    ~[leaf+"colliding discovery produced bind cards"]
  ~
++  test-longest-whole-segment-routing
  ^-  tang
  =/  site=(list @t)  ~['apps' 'my-app' 'blog' 'first-post']
  =/  found=(unit route-match:jibb-host)
    (route-request:jibb-host example-routes site)
  ?~  found  ~[leaf+"nested app route did not match"]
  ?.  =(%blog desk.route.u.found)  ~[leaf+"literal longer route did not win"]
  ?.  =(~['first-post'] remaining.u.found)
    ~[leaf+"route remainder was not preserved"]
  =/  query=(unit route-match:jibb-host)
    (route-request:jibb-host example-routes (target-site:jibb-host '/apps/my-app/blog?draft=1'))
  ?~  query  ~[leaf+"a query prevented route matching"]
  ?.  =(%blog desk.route.u.query)  ~[leaf+"the query changed the selected route"]
  ?.  =(~ remaining.u.query)  ~[leaf+"the query became a path segment"]
  =/  missing=(unit route-match:jibb-host)
    (route-request:jibb-host example-routes ~['apps' 'other'])
  ?.  ?=(~ missing)  ~[leaf+"unregistered route matched an app"]
  =/  outside=(unit route-match:jibb-host)
    (route-request:jibb-host example-routes ~['apps' 'my-appish'])
  ?.  ?=(~ outside)  ~[leaf+"a segment prefix matched as a whole segment"]
  ?.  =(~ (target-site:jibb-host 'not-an-origin-form-target'))
    ~[leaf+"a malformed request target was parsed as a route"]
  ~
++  test-admission-methods-and-placeholder-responses
  ^-  tang
  =/  denied=payload:jibb-host
    (request-response:jibb-host example-routes | %'POST' '/apps/my-app?tab=1&x=2')
  =/  expected=payload:jibb-host
    [[307 ~[['location' '/~/login?redirect=%2Fapps%2Fmy-app%3Ftab%3D1%26x%3D2']]] ~]
  ?.  =(expected denied)  ~[leaf+"login redirect lost the exact original target"]
  =/  allowed=(each ~ payload:jibb-host)
    (authorize:jibb-host & '/apps/my-app')
  ?.  ?=(%& -.allowed)  ~[leaf+"the owner was redirected"]
  =/  missing=payload:jibb-host
    (request-response:jibb-host example-routes & %'GET' '/apps/other')
  ?.  =(404 (status missing))  ~[leaf+"unknown route did not produce 404"]
  =/  asset=payload:jibb-host
    (request-response:jibb-host example-routes & %'GET' '/apps/my-app/static/missing.js')
  ?.  =(404 (status asset))  ~[leaf+"unknown asset did not produce 404"]
  =/  post=payload:jibb-host
    (request-response:jibb-host example-routes & %'POST' '/apps/my-app')
  ?.  =(405 (status post))  ~[leaf+"unsupported method did not produce 405"]
  ?.  ?=(^ (find ~[['allow' 'GET, HEAD']] headers.response-header.post))
    ~[leaf+"405 response did not advertise supported methods"]
  =/  get=payload:jibb-host
    (request-response:jibb-host example-routes & %'GET' '/apps/my-app/blog/first-post')
  ?.  =(501 (status get))  ~[leaf+"matched route did not expose the renderer placeholder"]
  =/  head=payload:jibb-host
    (request-response:jibb-host example-routes & %'HEAD' '/apps/my-app')
  ?.  =(501 (status head))  ~[leaf+"HEAD was rejected with GET implemented"]
  ~
++  test-response-cards
  ^-  tang
  =/  result=payload:jibb-host  (text-response:jibb-host 200 'ok')
  =/  cards=(list card:agent:gall)  (give-payload:jibb-host %test result)
  =/  header=response-header:http  [200 ~[['content-type' 'text/plain; charset=utf-8']]]
  =/  body=(unit octs)  `[2 'ok']
  =/  expected=(list card:agent:gall)
    :~  [%give %fact ~[/http-response/test] %http-response-header !>(header)]
        [%give %fact ~[/http-response/test] %http-response-data !>(body)]
        [%give %kick ~[/http-response/test] ~]
    ==
  ?.  =(expected cards)  ~[leaf+"response cards changed their header/data/kick shape"]
  =/  redirect=payload:jibb-host  (login-redirect:jibb-host '/a?x=1&y=2')
  ?.  =(307 (status redirect))  ~[leaf+"login response was not a 307"]
  ?.  =(~ data.redirect)  ~[leaf+"login redirect unexpectedly had a body"]
  ~
++  test-binding-admission-and-failure
  ^-  tang
  =/  entries=(list docket-entry:jibb-host)  ~[[%my-app `example-docket]]
  =/  start=(each transition:jibb-host @t)
    (initialize:jibb-host %jibb entries (sy ~[%my-app %blog %other]))
  ?:  ?=(%| -.start)  ~[leaf+(trip p.start)]
  =/  made=transition:jibb-host  p.start
  ?.  =(~ routes.registry.made)  ~[leaf+"an unacknowledged route was published"]
  ?.  =(1 (lent pending.registry.made))  ~[leaf+"discovery did not record its pending bind"]
  ?.  =(1 (lent cards.made))  ~[leaf+"discovery did not emit exactly one bind"]
  =/  expected=card:agent:gall
    [%pass /bind/my-app %arvo %e %connect [~ /apps/my-app] %jibb]
  ?.  =(~[expected] cards.made)  ~[leaf+"Eyre connect card was malformed"]
  =/  denied=transition:jibb-host
    (acknowledge-bind:jibb-host registry.made %my-app |)
  ?.  =(~ routes.registry.denied)  ~[leaf+"failed binding published a route"]
  ?.  =(~ pending.registry.denied)  ~[leaf+"failed binding remained pending"]
  ?.  =(~ cards.denied)  ~[leaf+"failed binding emitted a lifecycle card"]
  =/  accepted=transition:jibb-host
    (acknowledge-bind:jibb-host registry.made %my-app &)
  ?.  =(1 (lent routes.registry.accepted))  ~[leaf+"accepted binding was not published"]
  ?.  =(~ pending.registry.accepted)  ~[leaf+"accepted binding remained pending"]
  =/  restored=(list card:agent:gall)
    (restore-cards:jibb-host %jibb registry.made)
  ?.  =(2 (lent restored))  ~[leaf+"load did not resubscribe and retry pending binds"]
  ?.  =(tire-card:jibb-host (snag 0 restored))  ~[leaf+"load did not restore Clay tire subscription"]
  =/  expected-tire=card:agent:gall  [%pass /desks %arvo %c %tire `~]
  ?.  =(expected-tire tire-card:jibb-host)  ~[leaf+"tire card did not subscribe"]
  ~
++  test-lifecycle-disconnect-and-late-ack
  ^-  tang
  =/  reg=registry:jibb-host
    [example-routes ~ (sy ~[%my-app %blog])]
  =/  retired=transition:jibb-host  (retire-desk:jibb-host reg %blog)
  =/  expected=card:agent:gall
    [%pass /disconnect/blog %arvo %e %disconnect [~ /apps/my-app/blog]]
  ?.  =(~[expected] cards.retired)  ~[leaf+"suspending a desk did not disconnect its route"]
  ?.  ?=(~ (route-for-desk:jibb-host routes.registry.retired %blog))
    ~[leaf+"suspended desk remained routable"]
  ?.  !(~(has in live.registry.retired) %blog)
    ~[leaf+"suspended desk remained live"]
  =/  pending-reg=registry:jibb-host
    [~ example-routes (sy ~[%my-app %blog])]
  =/  stopped=transition:jibb-host  (retire-desk:jibb-host pending-reg %blog)
  =/  late=transition:jibb-host
    (acknowledge-bind:jibb-host registry.stopped %blog &)
  ?.  =(~[expected] cards.late)  ~[leaf+"late accepted bind was not disconnected"]
  ?.  =(~ routes.registry.late)  ~[leaf+"late accepted bind republished a suspended desk"]
  =/  revived=registry:jibb-host  (revive-desk:jibb-host registry.late %blog)
  =/  rebound=(each transition:jibb-host @t)
    (add-pending:jibb-host %jibb revived [%blog /apps/my-app/blog])
  ?:  ?=(%| -.rebound)  ~[leaf+(trip p.rebound)]
  =/  accepted=transition:jibb-host
    (acknowledge-bind:jibb-host registry.p.rebound %blog &)
  ?.  =(1 (lent routes.registry.accepted))
    ~[leaf+"resumed desk did not become routable after acknowledgment"]
  =/  reconciled=transition:jibb-host
    (reconcile-live:jibb-host reg (sy ~[%my-app]))
  ?.  =(~[expected] cards.reconciled)
    ~[leaf+"full tire snapshot did not remove deleted desks"]
  ~
--
