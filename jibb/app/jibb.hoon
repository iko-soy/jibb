/+  jibb-host
=,  clay
|%
+$  card  card:agent:gall
+$  state-0  [%0 registry=registry:jibb-host]
+$  versioned-state  $%(state-0)
--
^-  agent:gall
=|  state-0
=*  state  -
|_  =bowl:gall
+*  this  .
++  on-init
  ^-  (quip card _this)
  |^
  =/  our=@ta  (scot %p our.bowl)
  =/  now=@ta  (scot %da now.bowl)
  =/  rock=rock:tire  .^(rock:tire %cx /[our]//[now]/tire)
  =/  live=(set desk)  (live-desks:jibb-host rock)
  =/  found=(each transition:jibb-host @t)
    (initialize:jibb-host dap.bowl (discover our now live) live)
  ?:  ?=(%| -.found)  ~|(p.found !!)
  =/  next=transition:jibb-host  p.found
  :_  this(registry registry.next)
  [tire-card:jibb-host cards.next]
  ++  discover
    |=  [our=@ta now=@ta live=(set desk)]
    ^-  (list docket-entry:jibb-host)
    =/  desks=(set desk)  .^((set desk) %cd /[our]/[%$]/[now])
    =/  ordered=(list desk)  (sort ~(tap in desks) aor)
    =|  entries=(list docket-entry:jibb-host)
    |-
    ?~  ordered  (flop entries)
    ?.  (~(has in live) i.ordered)  $(ordered t.ordered)
    =/  read=(each noun tang)
      (mule |.(.^(noun %cx /[our]/[i.ordered]/[now]/desk/docket-0)))
    =/  doc=(unit noun)  ?:(?=(%| -.read) ~ `p.read)
    $(ordered t.ordered, entries [[i.ordered doc] entries])
  --
++  on-save  !>(state)
::  Published routes survive reloads; only pending binds are retried.
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  restored=state-0  !<(state-0 old)
  [(restore-cards:jibb-host dap.bowl registry.restored) this(state restored)]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  [~ this]
  =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
  =/  result=payload:jibb-host
    %^  request-response:jibb-host  routes.registry  authenticated.req
    [method.request.req url.request.req]
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
    =/  next=transition:jibb-host
      (acknowledge-bind:jibb-host registry i.t.wire accepted)
    [cards.next this(registry registry.next)]
  ?.  ?=([%desks ~] wire)  [~ this]
  ?.  ?=([%clay %tire *] sign-arvo)  [~ this]
  =/  result=(each rock:tire wave:tire)  +>.sign-arvo
  ?:  ?=(%& -.result)  (initial-rock p.result)
  ?.  ?=(%zest -.p.result)  [~ this]
  =/  =desk  desk.p.result
  ?.  ?=(%live zest.p.result)  (retire desk)
  (revive desk)
  ++  initial-rock
    |=  rock=rock:tire
    ^-  (quip card _this)
    =/  next=transition:jibb-host
      (reconcile-live:jibb-host registry (live-desks:jibb-host rock))
    [cards.next this(registry registry.next)]
  ++  retire
    |=  =desk
    ^-  (quip card _this)
    =/  next=transition:jibb-host  (retire-desk:jibb-host registry desk)
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
  ~
++  on-fail  |=  [=term =tang]  ^-  (quip card _this)  [~ this]
--
