::  The host's planning for desks, Eyre bindings and the expiry timer:
::  dockets read again on commits, bindings removed on the wire that made
::  them, bindings older hosts left taken back, and a timer set again on
::  load, since Gall drops a suspended agent's wakes.
/+  jibb-host
|%
++  two-routes
  ^-  registry:jibb-host
  [~[[%my-app /apps/my-app] [%blog /apps/blog]] ~ (sy ~[%my-app %blog %new])]
++  connect
  |=  [=desk base=path]
  ^-  card:agent:gall
  [%pass /bind/[desk] %arvo %e %connect [~ base] %jibb]
++  disconnect
  |=  [=desk base=path]
  ^-  card:agent:gall
  [%pass /bind/[desk] %arvo %e %disconnect [~ base]]
::  A routed desk whose docket names another base is disconnected from the
::  old one and bound at the new; one whose site+ went, or that no longer
::  vendors Jibb, is disconnected; an unchanged one is left alone.
++  test-docket-changes-move-routes
  ^-  tang
  =/  same=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%my-app `/apps/my-app]])
  ?.  =([two-routes ~ ~ ~] same)  ~[leaf+"an unchanged docket changed the routes"]
  =/  moved=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%my-app `/apps/moved]])
  ?.  =(~[(disconnect %my-app /apps/my-app) (connect %my-app /apps/moved)] cards.moved)
    ~[leaf+"a changed base was not disconnected and bound again"]
  ?.  =(~[[%my-app /apps/my-app]] dropped.moved)  ~[leaf+"the old route's files and builds were kept"]
  ?.  =(~[[%blog /apps/blog]] routes.registry.moved)  ~[leaf+"the old base stayed routed"]
  ?.  =(~[[%my-app /apps/moved]] pending.registry.moved)  ~[leaf+"the new base was not pending"]
  =/  gone=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%blog ~]])
  ?.  =(~[(disconnect %blog /apps/blog)] cards.gone)  ~[leaf+"a desk without a site+ kept its binding"]
  ?.  =(~[[%blog /apps/blog]] dropped.gone)  ~[leaf+"a desk without a site+ kept its route"]
  ?.  =(~[[%my-app /apps/my-app]] routes.registry.gone)  ~[leaf+"dropping one desk dropped another"]
  ?.  =(~ pending.registry.gone)  ~[leaf+"a desk without a site+ was bound"]
  ::  A live desk that newly vendors Jibb with a site+ is bound.
  =/  found=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%new `/apps/new]])
  ?.  =(~[(connect %new /apps/new)] cards.found)  ~[leaf+"a desk newly vendoring Jibb was not bound"]
  ::  Two desks may swap bases: every old base goes before a new one is
  ::  claimed.
  =/  swapped=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%my-app `/apps/blog] [%blog `/apps/my-app]])
  ?.  =(~ refused.swapped)  ~[leaf+"swapping two bases refused a claim"]
  ?.  =(~ routes.registry.swapped)  ~[leaf+"a swapped base stayed routed"]
  ?.  =(~[[%blog /apps/my-app] [%my-app /apps/blog]] pending.registry.swapped)
    ~[leaf+"swapped bases were not both bound"]
  =/  swap-cards=(list card:agent:gall)
    :~  (disconnect %my-app /apps/my-app)
        (disconnect %blog /apps/blog)
        (connect %my-app /apps/blog)
        (connect %blog /apps/my-app)
    ==
  ?.  =(swap-cards cards.swapped)  ~[leaf+"swapped bases were not disconnected before being bound"]
  ::  A pending bind whose base changed is disconnected, in case Eyre bound
  ::  it, and the new base is bound.
  =/  waiting=registry:jibb-host  [~ ~[[%new /apps/new]] (sy ~[%new])]
  =/  rebound=site-update:jibb-host
    (update-sites:jibb-host %jibb waiting ~[[%new `/apps/newer]])
  ?.  =(~[(disconnect %new /apps/new) (connect %new /apps/newer)] cards.rebound)
    ~[leaf+"a pending bind's changed base was not bound again"]
  ?.  =(~ dropped.rebound)  ~[leaf+"a pending bind was reported as a published route"]
  ?.  =(~[[%new /apps/newer]] pending.registry.rebound)  ~[leaf+"the pending base was not replaced"]
  ::  A move onto another desk's base is refused, and the desk is unrouted.
  =/  clash=site-update:jibb-host
    (update-sites:jibb-host %jibb two-routes ~[[%my-app `/apps/blog]])
  =/  why=@t
    'jibb: %my-app\'s docket site+ /apps/blog is %blog\'s base path, so %my-app is not served'
  ?.  =(~[[%my-app why]] refused.clash)  ~[leaf+"a move onto another desk's base was not refused"]
  ?.  =(~[[%blog /apps/blog]] routes.registry.clash)  ~[leaf+"a refused move took the other desk's route"]
  ?.  =(~[(disconnect %my-app /apps/my-app)] cards.clash)  ~[leaf+"a refused move kept its old binding"]
  ~
::  Eyre removes a binding only for the duct that made it, so a desk's
::  disconnect goes on its connect's wire, and Eyre's answer for a base the
::  desk no longer claims is not taken for its pending bind.
++  test-bindings-end-on-their-own-wire
  ^-  tang
  =/  r=route:jibb-host  [%blog /apps/my-app/blog]
  =/  made=card:agent:gall  (bind-card:jibb-host %jibb r)
  =/  ended=card:agent:gall  (disconnect-card:jibb-host r)
  ?>  ?=([%pass * *] made)
  ?>  ?=([%pass * *] ended)
  ?.  =(p.made p.ended)  ~[leaf+"a disconnect went on another wire than its connect"]
  ?.  =((disconnect %blog /apps/my-app/blog) ended)  ~[leaf+"the disconnect card was malformed"]
  =/  waiting=registry:jibb-host  [~ ~[[%blog /apps/new]] (sy ~[%blog])]
  =/  stale=transition:jibb-host
    (acknowledge-bind:jibb-host waiting %blog & [~ /apps/old])
  ?.  =([waiting ~] stale)  ~[leaf+"an answer for an old base published the new one"]
  =/  ours=transition:jibb-host
    (acknowledge-bind:jibb-host waiting %blog & [~ /apps/new])
  ?.  =(~[[%blog /apps/new]] routes.registry.ours)  ~[leaf+"the pending bind's own answer was ignored"]
  ~
::  Hosts before this one disconnected on another wire, which Eyre ignored,
::  so a retired desk's binding stayed.  Once running, the host takes back
::  each binding for it, with no site, that no route or pending bind holds.
++  test-stale-bindings-are-taken-back
  ^-  tang
  =/  reg=registry:jibb-host
    [~[[%my-app /apps/my-app]] ~[[%blog /apps/blog]] (sy ~[%my-app %blog])]
  =/  bindings=*
    :~  [[~ /apps/my-app] ~ [%app %jibb]]
        [[~ /apps/blog] ~ [%app %jibb]]
        [[~ /apps/gone] ~[/gall/use/jibb/nonce/zod/disconnect/gone] [%app %jibb]]
        [[~ /apps/other] ~ [%app %other]]
        [[`'example.com' /apps/elsewhere] ~ [%app %jibb]]
        [[~ /apps/login] ~ [%authentication ~]]
    ==
  =/  expected=(list card:agent:gall)
    :~  [%pass /sweep %arvo %e %connect [~ /apps/gone] %jibb]
        [%pass /sweep %arvo %e %disconnect [~ /apps/gone]]
    ==
  ?.  =(expected (stale-bindings:jibb-host %jibb reg bindings))
    ~[leaf+"the stale binding was not connected and disconnected on the sweep's wire"]
  ?.  =(~ (stale-bindings:jibb-host %jibb reg [%not-a-list 1]))
    ~[leaf+"a noun that is not Eyre's bindings was swept"]
  ?.  =([%pass /sweep %arvo %b %wait ~2026.11.16] (sweep-card:jibb-host ~2026.11.16))
    ~[leaf+"the sweep did not wait for Behn"]
  ~
::  One timer, for the earliest retired file of any desk.  A timer already
::  set for it stays within a run, is moved for an earlier file, and is
::  cancelled when no file needs it.
++  test-expiry-timer-plan
  ^-  tang
  =/  now=@da  ~2026.11.16
  =/  soon=@da  (add now ~h1)
  =/  later=@da  (add now ~h2)
  =/  desks=(list cached-urls:jibb-host)
    :~  (malt `(list [@t (unit @da)])`~[['/a' ~] ['/b' `later]])
        (malt `(list [@t (unit @da)])`~[['/c' `soon]])
        ~
    ==
  ?.  =(`soon (soonest-expiry:jibb-host desks))  ~[leaf+"the timer was not for the earliest file"]
  ?.  =(~ (soonest-expiry:jibb-host ~[(malt `(list [@t (unit @da)])`~[['/a' ~]])]))
    ~[leaf+"files still in use set a timer"]
  ?.  =([`soon ~] (timer-plan:jibb-host `soon `soon))  ~[leaf+"a timer already set was set again"]
  =/  moved=[timer=(unit @da) cards=(list card:agent:gall)]
    (timer-plan:jibb-host `later `soon)
  ?.  =(`soon timer.moved)  ~[leaf+"the timer did not move to the earlier file"]
  ?.  =(~[[%pass /expire %arvo %b %rest later] [%pass /expire %arvo %b %wait soon]] cards.moved)
    ~[leaf+"a moved timer was not cancelled and set"]
  ?.  =([~ ~[[%pass /expire %arvo %b %rest soon]]] (timer-plan:jibb-host `soon ~))
    ~[leaf+"a timer no file needs was not cancelled"]
  ~
::  Gall drops the wakes of a suspended agent.  A load sets the saved timer
::  again even when it is still for the earliest file: before, the host
::  kept it, and a timer whose wake was dropped never fired again.
++  test-expiry-timer-set-again-on-load
  ^-  tang
  =/  soon=@da  ~2026.11.16..01.00.00
  =/  loaded=[timer=(unit @da) cards=(list card:agent:gall)]
    (rearm-timer:jibb-host `soon `soon)
  ?.  =(`soon timer.loaded)  ~[leaf+"the timer was not kept for the earliest file"]
  ?.  =(~[[%pass /expire %arvo %b %rest soon] [%pass /expire %arvo %b %wait soon]] cards.loaded)
    ~[leaf+"a load did not cancel and set the saved timer"]
  ?.  =([~ ~] (rearm-timer:jibb-host ~ ~))  ~[leaf+"a load with no retired files set a timer"]
  =/  fresh=[timer=(unit @da) cards=(list card:agent:gall)]
    (rearm-timer:jibb-host ~ `soon)
  ?.  =([`soon ~[[%pass /expire %arvo %b %wait soon]]] fresh)
    ~[leaf+"a load without a saved timer did not set one"]
  ~
::  A wake at or after the timer's time is its own; one before it is
::  stray, from a timer set before a reload, and leaves the timer set, and
::  nothing has expired by then.
++  test-stray-wakes-are-harmless
  ^-  tang
  =/  now=@da  ~2026.11.16
  =/  soon=@da  (add now ~h1)
  ?.  =(~ (woken-timer:jibb-host `now now))  ~[leaf+"the timer's own wake left it set"]
  ?.  =(~ (woken-timer:jibb-host `now soon))  ~[leaf+"a late wake left its timer set"]
  ?.  =(`soon (woken-timer:jibb-host `soon now))  ~[leaf+"a stray wake cleared a timer still set"]
  ?.  =(~ (woken-timer:jibb-host ~ now))  ~[leaf+"a wake with no timer set one"]
  =/  urls=cached-urls:jibb-host  (malt `(list [@t (unit @da)])`~[['/a' `soon] ['/b' ~]])
  =/  expired=[cached-urls:jibb-host (list card:agent:gall)]  (expire-urls:jibb-host urls now)
  ?.  =([urls ~] expired)  ~[leaf+"a stray wake expired a file whose day is not over"]
  ?.  =([`soon ~] (timer-plan:jibb-host `soon (soonest-expiry:jibb-host ~[urls])))
    ~[leaf+"after a stray wake the timer was set again"]
  ~
::  Only Eyre watches a request's response.  It watches as whoever sent the
::  request, a logged-out reader's guest @p included, so the watcher's
::  ship tells nothing; its duct, starting with Eyre's wire, does.  Another
::  ship's watch comes through Gall's wire, and an agent's through its own.
++  test-only-eyre-waits-for-responses
  ^-  tang
  =/  at=path  /http-response/[~.eyre_1]
  =/  eyre=duct  ~[/eyre/watch-response/[~.eyre_1] /http-server/request]
  =/  remote=duct  ~[/gall/sys/req/nec/jibb /ames/flow]
  =/  agent=duct  ~[/gall/use/spider/nonce/zod/out/zod/jibb/thread]
  =/  watching
    |=  watchers=(list [duct ship path])
    ^-  bitt:gall
    (malt watchers)
  ?.  =(`~.eyre_1 (response-path:jibb-host at (watching ~[[eyre ~zod at]])))
    ~[leaf+"the owner's request was refused its response"]
  ?.  =(`~.eyre_1 (response-path:jibb-host at (watching ~[[eyre ~sampel-palnet at]])))
    ~[leaf+"a logged-out reader's request, which Eyre watches as a guest, was refused"]
  ?.  =(~ (response-path:jibb-host at (watching ~[[remote ~nec at]])))
    ~[leaf+"another ship could watch a response"]
  ?.  =(~ (response-path:jibb-host at (watching ~[[eyre ~zod at] [remote ~nec at]])))
    ~[leaf+"a response another ship also watches was accepted"]
  ?.  =(~ (response-path:jibb-host at (watching ~[[agent ~zod at]])))
    ~[leaf+"an agent could watch a response"]
  ?.  =(`~.eyre_1 (response-path:jibb-host at (watching ~[[eyre ~zod at] [remote ~nec /other]])))
    ~[leaf+"a watch of another path refused Eyre's"]
  ?.  =(~ (response-path:jibb-host /other (watching ~[[eyre ~zod /other]])))
    ~[leaf+"another path was taken for a response"]
  ?.  =(~ (response-path:jibb-host /http-response/a/b (watching ~[[eyre ~zod /http-response/a/b]])))
    ~[leaf+"a longer path was taken for a response"]
  ~
--
