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
::  A built page: HTML, or an error with its status, to serve as it is; or
::  a page with data, prepared by the compiler of the desk at rev, which
::  renders it per request.  html is & for HTML and | for plain text.
+$  cached-page
  $%  [%static status=@ud html=? body=@t]
      [%data rev=@ud page=*]
  ==
::  How the host answers one request: a response now, or a page with data
::  for the agent to run through the desk's compiler.
+$  served
  $%  [%payload result=payload]
      [%data =desk rev=@ud page=* site=(list @t) head=?]
  ==
::  What the desk's +page-request gives back, read by the host as a mold.
+$  page-step
  $%  [%done title=@t html=@t]
      [%scry agent=@tas path=path receive=*]
      [%fail status=@ud message=@t html=@t]
  ==
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
      uses=(list [module=term name=term])
  ==
::  What the desk's +module-outline says of one module.
+$  outline
  $:  jibb=(list path)
      surs=(list term)
      marks=(list term)
      main=?
      uses=(list [module=term name=term])
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
      [%client at=path]
      [%style ~]
      [%render at=path]
      [%publish ~]
  ==
::  A build in progress.  check-keys, client-keys and render-keys name the
::  store entries the build uses; served holds the pages it has decided.
::  While waiting holds a file, Clay's answer, not a Behn wake, resumes it.
::  library is the desk's browser library, which pages with islands load.
+$  build
  $:  rev=@ud
      base=path
      steps=(list build-step)
      waiting=(unit path)
      env=@uv
      modules=(map path module-info)
      order=(list path)
      sites=(list [at=path site=(list @t)])
      assets=(list static-file)
      theme=path
      renderer=path
      prelude=@uv
      buildable=(map path ?)
      sur-files=(map term path)
      mark-files=(map term path)
      sur-sources=(list [module=term at=path source=@t])
      sur-keys=(map term @uv)
      mark-keys=(map term @uv)
      wanted=(map term (list term))
      check-keys=(map path @uv)
      client-keys=(map path @uv)
      render-keys=(map path @uv)
      library=(unit [url=@t js=@t])
      routes=(list (list @t))
      style=(unit [key=@uv result=(each [url=@t css=@t lang=@t] @t)])
      conflicts=(map path @t)
      served=(map (list @t) cached-page)
      checked=@ud
      rendered=@ud
      failure=(unit @t)
  ==
::  A file under /ui/static: its application path, the URL it is served at,
::  its media type and bytes, as the desk's +render-checked takes them.
+$  static-file  [at=path url=@t type=@t data=octs]
::  The URLs a desk has put in Eyre's cache: ~ while its last build uses one,
::  then the time it expires.
+$  cached-urls  (map @t (unit @da))
::  A check or render records the revision whose build computed it.
+$  checked  [rev=@ud result=(each [kind=@tas interface=* artifact=*] @t)]
+$  rendered  [rev=@ud result=(each @t @t)]
::  An island or store module's JavaScript, at the URL that names it.
+$  client  [rev=@ud kind=@tas result=(each [url=@t hash=@t js=@t] @t)]
::  What a page with islands gives the browser, as the desk's compiler
::  takes it: the library's URL, the ship, each island module's hash by
::  its path and each store module's by its name.
+$  client-context
  $:  library=@t
      ship=@p
      islands=(map @t @t)
      stores=(list [module=@t hash=@t])
      section=(unit @t)
  ==
::
::  The part of a catch-all page's route before its catch-all, as /app for
::  /ui/app/__rest: the section an app's links stay in (Decisions: Apps).
::  ~ for other pages, and for a route with a parameter before its
::  catch-all, whose section is not one address.
++  page-section
  |=  site=(list @t)
  ^-  (unit @t)
  =/  parts=(list @t)  (flop site)
  ?~  parts  ~
  ?.  =('__' (end [3 2] i.parts))  ~
  =/  before=(list @t)  (flop t.parts)
  ?:  (lien before |=(p=@t =('_' (end 3 p))))  ~
  `(rap 3 (turn before |=(p=@t (cat 3 '/' p))))
::  The compiler's nouns are opaque here: each desk builds with its own.
+$  store
  $:  imports=(map @uv outline)
      preludes=(map @uv (each * @t))
      surs=(map @uv [hash=@uv value=(each (list [module=term name=term result=*]) @t)])
      marks=(map @uv [hash=@uv value=*])
      checks=(map @uv checked)
      styles=(map @uv (each [css=@t lang=@t] @t))
      renders=(map @uv rendered)
      prepares=(map @uv prepared)
      clients=(map @uv client)
  ==
::  A page with data, prepared by the compiler of the build at rev.
+$  prepared  [rev=@ud result=(each * @t)]
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
::  wanted names the molds the modules use from the file, declared or not.
++  sur-key
  |=  [env=@uv module=term source=@t surs=@uv wanted=(list term)]
  ^-  @uv
  (sham [%jibb-sur-3 env module (sham source) surs wanted])
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
::  A static file's URL names its bytes, so the URLs stand for the files.
++  style-key
  |=  [env=@uv theme=@uv base=path urls=(list @t)]
  ^-  @uv
  (sham [%jibb-style-1 env theme base urls])
++  render-key
  |=  $:  env=@uv
          page=@uv
          theme=@uv
          renderer=@uv
          base=path
          urls=(list @t)
          routes=(list (list @t))
          stylesheet=@t
      ==
  ^-  @uv
  (sham [%jibb-render-2 env page theme renderer base urls routes stylesheet])
::  A module's JavaScript follows from what checked it; its URL from base.
++  client-key
  |=  [check=@uv base=path]
  ^-  @uv
  (sham [%jibb-client-1 check base])
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
  =/  client-keys=(set @uv)  (silt ~(val by client-keys.b))
  =/  style-keys=(set @uv)  ?~(style.b ~ (silt ~[key.u.style.b]))
  :*  (malt (skim ~(tap by imports.s) |=([k=@uv *] (~(has in import-keys) k))))
      (malt (skim ~(tap by preludes.s) |=([k=@uv *] =(k prelude.b))))
      (malt (skim ~(tap by surs.s) |=([k=@uv *] (~(has in sur-keys) k))))
      (malt (skim ~(tap by marks.s) |=([k=@uv *] (~(has in mark-keys) k))))
      (malt (skim ~(tap by checks.s) |=([k=@uv *] (~(has in check-keys) k))))
      (malt (skim ~(tap by styles.s) |=([k=@uv *] (~(has in style-keys) k))))
      (malt (skim ~(tap by renders.s) |=([k=@uv *] (~(has in render-keys) k))))
      (malt (skim ~(tap by prepares.s) |=([k=@uv *] (~(has in render-keys) k))))
      (malt (skim ~(tap by clients.s) |=([k=@uv *] (~(has in client-keys) k))))
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
::  A request's site: its path's segments, decoded, without the query or
::  fragment.  A final segment keeps its dots, unlike Eyre's +apat, which
::  splits off an extension.  Empty segments, as from a trailing slash, are
::  dropped; a segment that does not decode stays as it was sent.
++  target-site
  |=  url=@t
  ^-  (list @t)
  =/  text=tape  (trip url)
  =/  end=@ud  (lent text)
  =/  query=(unit @ud)  (find "?" text)
  =/  hash=(unit @ud)  (find "#" text)
  =?  end  ?=(^ query)  (min end u.query)
  =?  end  ?=(^ hash)  (min end u.hash)
  ?~  (parse-target url)  ~
  %+  murn  (split-slash (scag end text))
  |=  part=tape
  ?~  part  ~
  `(fall (rush (crip part) smeg:de-purl:html) (crip part))
++  split-slash
  |=  text=tape
  ^-  (list tape)
  =|  out=(list tape)
  =|  part=tape
  |-
  ?~  text  (flop [(flop part) out])
  ?:  =('/' i.text)  $(text t.text, out [(flop part) out], part ~)
  $(text t.text, part [i.text part])
::
::  A Clay path keeps a file's extension as its last segment; an application
::  path keeps it in the name, as /static/img/logo.png.
++  application-asset
  |=  at=path
  ^-  path
  =/  rest=path  ?.(?=([%ui *] at) at t.at)
  =/  back=(list @ta)  (flop rest)
  ?.  ?=([@ @ *] back)  rest
  (flop [(rap 3 ~[i.t.back '.' i.back]) t.t.back])
::
::  Static files.  Each is public and immutable at a URL naming a hash of its
::  bytes, cached by Eyre, which serves it without an Arvo event.  A file a
::  newer build no longer uses stays a day, for pages already open.
::
++  static-type
  |=  mark=@ta
  ^-  (unit @t)
  ?+  mark  ~
    %png    `'image/png'
    %jpg    `'image/jpeg'
    %jpeg   `'image/jpeg'
    %gif    `'image/gif'
    %webp   `'image/webp'
    %svg    `'image/svg+xml'
    %ico    `'image/x-icon'
    %woff   `'font/woff'
    %woff2  `'font/woff2'
    %ttf    `'font/ttf'
    %otf    `'font/otf'
    %pdf    `'application/pdf'
    %css    `'text/css; charset=utf-8'
    %txt    `'text/plain; charset=utf-8'
    %js     `'text/javascript; charset=utf-8'
  ==
::
++  short-hash
  |=  data=*
  ^-  @t
  (scot %uv (end [0 40] (sham data)))
::
++  static-url
  |=  [base=path at=path data=octs]
  ^-  @t
  =/  rest=path  ?:(?=([%static *] at) t.at at)
  (rap 3 ~[(spat base) '/static/' (short-hash data) (spat rest)])
::
++  stylesheet-url
  |=  [base=path css=@t]
  ^-  @t
  (rap 3 ~[(spat base) '/~jibb/s/' (short-hash css) '.css'])
::  An island or store module, and the browser library, by their text.
++  module-url
  |=  [base=path js=@t]
  ^-  @t
  (rap 3 ~[(spat base) '/~jibb/m/' (short-hash js) '.js'])
++  library-url
  |=  [base=path js=@t]
  ^-  @t
  (rap 3 ~[(spat base) '/~jibb/r/' (short-hash js) '.js'])
::  The name a store's pokes and watches give it: its path under /ui
::  without the mark, as stores/cart for /ui/stores/cart/jibb.
++  store-name
  |=  at=path
  ^-  @t
  =/  parts=path  (scag (dec (lent at)) at)
  =?  parts  ?=([%ui *] parts)  t.parts
  (crip (slag 1 (spud parts)))
::
++  static-payload
  |=  [type=@t data=octs]
  ^-  payload
  :_  `data
  :-  200
  ~[['content-type' type] ['cache-control' 'public, max-age=31536000, immutable']]
::
++  cache-card
  |=  [url=@t entry=(unit payload)]
  ^-  card:agent:gall
  :*  %pass  /eyre/cache  %arvo  %e  %set-response  url
      ?~(entry ~ `[| %payload u.entry])
  ==
::
::  +publish-urls: put a build's files in Eyre's cache and retire the rest
++  publish-urls
  |=  [old=cached-urls new=(list [url=@t =payload]) now=@da]
  ^-  [cached-urls (list card:agent:gall)]
  =/  fresh=(set @t)  (silt (turn new |=(n=[url=@t =payload] url.n)))
  =/  cards=(list card:agent:gall)
    %+  murn  new
    |=  n=[url=@t =payload]
    ?:  =(`~ (~(get by old) url.n))  ~
    `(cache-card url.n `payload.n)
  =/  retired=cached-urls
    %-  malt
    %+  murn  ~(tap by old)
    |=  [url=@t expiry=(unit @da)]
    ?:  (~(has in fresh) url)  ~
    `[url ?~(expiry `(add now ~d1) expiry)]
  =/  current=cached-urls  (malt (turn new |=(n=[url=@t =payload] [url.n ~])))
  [(~(uni by retired) current) cards]
::
::  +expire-urls: remove the retired files whose day is over
++  expire-urls
  |=  [urls=cached-urls now=@da]
  ^-  [cached-urls (list card:agent:gall)]
  =/  gone=(list @t)
    %+  murn  ~(tap by urls)
    |=  [url=@t expiry=(unit @da)]
    ?~  expiry  ~
    ?:((lte u.expiry now) `url ~)
  :-  (~(dif by urls) (malt (turn gone |=(url=@t [url ~]))))
  (turn gone |=(url=@t (cache-card url ~)))
::
++  next-expiry
  |=  urls=cached-urls
  ^-  (unit @da)
  =/  times=(list @da)  (murn ~(val by urls) |=(e=(unit @da) e))
  ?~  times  ~
  =/  low=@da  i.times
  =/  rest=(list @da)  t.times
  |-
  ?~  rest  `low
  $(rest t.rest, low (min low i.rest))
::
++  clear-urls
  |=  urls=cached-urls
  ^-  (list card:agent:gall)
  (turn ~(tap in ~(key by urls)) |=(url=@t (cache-card url ~)))
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
  [%static 200 & html]
::
::  A page that failed to build.  The desk's error page, when its compiler
::  could make one, or else the message as text.
++  failed-page
  |=  message=@t
  ^-  cached-page
  [%static 500 | message]
++  failed-page-html
  |=  html=@t
  ^-  cached-page
  [%static 500 & html]
::
++  html-status-response
  |=  [status=@ud html=@t]
  ^-  payload
  [[status ~[['content-type' 'text/html; charset=utf-8']]] [~ [(met 3 html) html]]]
::
::  Routes.  A page's site keeps its file's `_name` and `__name` segments.
::  A literal segment beats a parameter, which beats a catch-all, from the
::  first segment on.
++  pattern-matches
  |=  [pattern=(list @t) site=(list @t)]
  ^-  ?
  ?~  pattern  ?=(~ site)
  ?:  =('__' (end [3 2] i.pattern))  &
  ?~  site  |
  ?:  =('_' (end [3 1] i.pattern))  $(pattern t.pattern, site t.site)
  ?.  =(i.pattern i.site)  |
  $(pattern t.pattern, site t.site)
++  pattern-rank
  |=  pattern=(list @t)
  ^-  (list @ud)
  %+  turn  pattern
  |=  seg=@t
  ?:  =('__' (end [3 2] seg))  2
  ?:  =('_' (end [3 1] seg))  1
  0
++  rank-before
  |=  [a=(list @ud) b=(list @ud)]
  ^-  ?
  ?~  a  ?=(^ b)
  ?~  b  |
  ?:  (lth i.a i.b)  &
  ?:  (gth i.a i.b)  |
  $(a t.a, b t.b)
++  match-page
  |=  [pages=(map (list @t) cached-page) site=(list @t)]
  ^-  (unit [pattern=(list @t) page=cached-page])
  =/  entries=(list [pattern=(list @t) page=cached-page])  ~(tap by pages)
  =|  best=(unit [pattern=(list @t) page=cached-page rank=(list @ud)])
  |-
  ?~  entries  ?~(best ~ `[pattern.u.best page.u.best])
  ?.  (pattern-matches pattern.i.entries site)  $(entries t.entries)
  =/  rank=(list @ud)  (pattern-rank pattern.i.entries)
  ?:  &(?=(^ best) !(rank-before rank rank.u.best))  $(entries t.entries)
  $(entries t.entries, best `[pattern.i.entries page.i.entries rank])
::
::  Routes that cannot both be served: one site from two files, two
::  parameters at one level, and a catch-all beside its folder's index.
::  Each file of such a pair gets the error.
++  route-conflicts
  |=  sites=(list [at=path site=(list @t)])
  ^-  (map path @t)
  =|  out=(map path @t)
  =/  all=(list [at=path site=(list @t)])  sites
  |-
  ?~  sites  out
  =/  mine=[at=path site=(list @t)]  i.sites
  =/  others=(list [at=path site=(list @t)])
    (skip all |=(o=[at=path site=(list @t)] =(at.o at.mine)))
  =/  clash=(unit [at=path why=tape])
    |-
    ?~  others  ~
    =/  why=(unit tape)  (route-clash site.mine site.i.others)
    ?^  why  `[at.i.others u.why]
    $(others t.others)
  ?~  clash  $(sites t.sites)
  =/  message=@t
    (crip "route conflict: {(file-name at.mine)} and {(file-name at.u.clash)} {why.u.clash}")
  $(sites t.sites, out (~(put by out) at.mine message))
++  route-clash
  |=  [a=(list @t) b=(list @t)]
  ^-  (unit tape)
  ?:  =(a b)  `"both route to the same address"
  |-
  ?~  a
    ?:  ?&(?=([@ ~] b) =('__' (end [3 2] i.b)))  `"are a folder's index and its catch-all"
    ~
  ?~  b
    ?:  ?&(?=([@ ~] a) =('__' (end [3 2] i.a)))  `"are a folder's index and its catch-all"
    ~
  ::  A parameter and a catch-all may share a level: the parameter wins.
  =/  ka=@ud  (snag 0 (pattern-rank ~[i.a]))
  =/  kb=@ud  (snag 0 (pattern-rank ~[i.b]))
  ?:  &(=(1 ka) =(1 kb) !=(i.a i.b))  `"are parameters at one level"
  ?:  &(=(2 ka) =(2 kb) !=(i.a i.b))  `"are catch-alls at one level"
  ?.  =(i.a i.b)  ~
  $(a t.a, b t.b)
++  file-name
  |=  at=path
  ^-  tape
  =/  back=(list @ta)  (flop at)
  ?.  ?=([@ @ *] back)  (spud at)
  (weld (spud (flop t.t.back)) "/{(trip i.t.back)}.{(trip i.back)}")
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
  ::  /static/ belongs to the host.
  ?:  ?=([%static *] parts)  ~
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
::  +serve: a request's response when the host can give one itself
::
::    A page with data needs the desk's compiler, which only the agent can
::    run; here it is a 500.
++  serve
  |=  [routes=(list route) cache=page-cache building=(set desk) authenticated=? =method:http url=@t]
  ^-  payload
  =/  answer=served  (serve-request routes cache building authenticated method url)
  ?:  ?=(%payload -.answer)  result.answer
  (text-response 500 'a page with data runs in the agent')
::
::  +serve-request: one request, given the desks whose builds are in progress
::
::    A completed build keeps serving while the next one runs.  Static
::    files are public and Eyre answers for each one it holds, so a request
::    that reaches the host for one is a 404, logged in or not.
++  serve-request
  |=  [routes=(list route) cache=page-cache building=(set desk) authenticated=? =method:http url=@t]
  ^-  served
  =/  found=(unit route-match)  (route-request routes (target-site url))
  ?:  &(?=(^ found) (unknown-asset remaining.u.found))  [%payload not-found]
  =/  allowed=(each ~ payload)  (authorize authenticated url)
  ?:  ?=(%| -.allowed)  [%payload p.allowed]
  ?~  found  [%payload not-found]
  ?.  ?=(?(%'GET' %'HEAD') method)  [%payload method-not-allowed]
  =/  head=?  ?=(%'HEAD' method)
  =/  built=(unit desk-pages)  (~(get by cache) desk.route.u.found)
  =/  answer=served
    ?~  built
      ?:  (~(has in building) desk.route.u.found)  [%payload build-in-progress]
      [%payload not-found]
    ?^  error.u.built  [%payload (text-response 500 u.error.u.built)]
    =/  page=(unit [pattern=(list @t) page=cached-page])
      (match-page pages.u.built remaining.u.found)
    ?~  page  [%payload not-found]
    ?:  ?=(%data -.page.u.page)
      [%data desk.route.u.found rev.page.u.page page.page.u.page remaining.u.found head]
    =/  static=cached-page  page.u.page
    ?>  ?=(%static -.static)
    :-  %payload
    ?:  html.static  (html-status-response status.static body.static)
    (text-response status.static body.static)
  ?.  &(head ?=(%payload -.answer))  answer
  answer(data.result ~)
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
