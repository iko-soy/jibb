::  Fixed static-page build facade. Jibb owns element-to-vnode rendering in
::  /lib/jibb/renderer.jibb; this library orchestrates checked Nock execution,
::  authenticates the seal representation, checks the theme and every link
::  and image a page uses, and serializes the page and the theme's stylesheet.
/+  jibb, jibb-core, jibb-js, jibb-lower, jibb-nock
|%
::  A file under /ui/static, at its application path, with the URL the host
::  serves it at, its media type and its bytes.
+$  static-asset  [at=path url=@t type=@t data=octs]
::  routes are the sites of the desk's pages, with _ and __ segments as in
::  their file names; links must name one of them or a static file.
+$  static-request
  $:  at=path
      source=@t
      base=@t
      renderer-at=path
      renderer-source=@t
      theme-at=path
      theme-source=@t
      modules=jbundle:jibb
      assets=(list static-asset)
      externals=iexternals:jibb
      marks=imark-externals:jibb
      routes=(list (list @t))
  ==
+$  static-output  [title=@t html=@t]
+$  tones-view  [normal=@t background=@t accent=@t danger=@t muted=@t]
+$  theme-view
  $:  space=[s1=@t s2=@t s3=@t]
      tones=tones-view
      wide=@t
      lang=@t
      zone=@t
      font=(unit path)
      dark=(unit [tones=tones-view])
  ==
+$  render-origin  [file=path line=@ud col=@ud]
+$  render-error  [message=@t origin=(unit render-origin)]
+$  vnode
  $~  [%text '']
  $%  [%text words=@t]
      [%node tag=@t attrs=(list vattr) kids=(list vnode)]
      [%link target=path label=@t origin=(unit render-origin)]
      [%link-unsafe target=@t label=@t]
      [%image source=path description=@t origin=(unit render-origin)]
      [%image-unsafe source=[url=@t width=@ud height=@ud] description=@t]
  ==
+$  vattr  [name=@t value=@t]
::  islands maps each island module's path to the hash naming its
::  JavaScript; inside is set while rendering an island's first view, where
::  alone controls may render.
+$  renderer-context
  [skin=noun nodes=(map @tas noun) attrs=noun islands=(map @t @t) inside=?]
+$  renderer-entry  [tag=@tas name=term]
::  What serializing a page needs besides its tree.  client is what a
::  page with islands gives the browser.
+$  page-context
  $:  base=@t
      assets=(list static-asset)
      routes=(list (list @t))
      client=(unit client-context)
  ==
::  The browser library's URL, the ship, each island module's hash by its
::  path, each store module's hash by the name its pokes and watches give
::  it, such as stores/cart, and for a page under a catch-all route the
::  section the route covers, as /app, whose links the browser follows.
+$  client-context
  $:  library=@t
      ship=@p
      islands=(map @t @t)
      stores=(list [module=@t hash=@t])
      section=(unit @t)
  ==
::
++  prepare-lowering
  |=  $:  public=@t
          private=@t
          groups=(list iprelude-group-source:jibb)
          modules=jbundle:jibb
          externals=iexternals:jibb
      ==
  ^-  (unit iprelude-lowering:jibb)
  (prepare-prelude-with-group-evidence-for-lowering:jibb public private groups modules externals)
::
++  join-text
  |=  [separator=@t pieces=(list @t)]
  ^-  @t
  ?~  pieces  ''
  =/  out=@t  i.pieces
  =/  rest=(list @t)  t.pieces
  |-
  ?~  rest  out
  $(rest t.rest, out (rap 3 ~[out separator i.rest]))
::
++  default-theme-source
  ^-  @t
  %-  join-text
  :-  '\0a'
  :~  '++ theme  ^- theme'
      '  [ space=[s1="4px" s2="8px" s3="16px"]'
      '    tones=[normal="#222" background="#fff" accent="#17734f" danger="#b3261e" muted="#5f5f5f"]'
      '    wide="60rem"'
      '    lang="en"'
      '    zone="UTC"'
      '    font=~'
      '    dark=~'
      ''
  ==
::
++  read-render-origin
  |=  value=noun
  ^-  (unit [origin=render-origin sealed=noun])
  =/  read=(unit [tag=@t file=path line=@ud col=@ud sealed=noun])
    (mole |.(;;([tag=@t file=path line=@ud col=@ud sealed=noun] value)))
  ?~  read  ~
  ?.  =('jibb.host.render-origin.v1' tag.u.read)  ~
  `[[file.u.read line.u.read col.u.read] sealed.u.read]
::
++  render-origin-native
  |=  [file=path line=@ud col=@ud value=noun]
  ?^  (read-render-origin value)  value
  ['jibb.host.render-origin.v1' file line col value]
::
++  raw-seal-native
  |=  value=noun
  ['jibb.private.seal.v1' value]
::
++  native-value
  |=  id=name:jibb-core
  ^-  (unit noun)
  ?.  ?=(%own -.id)  ~
  ::  Every native the lowering emits, as Hoon's own gate where one has
  ::  the native's sample; the JavaScript natives keep the same samples.
  ?+  name.id  ~
    %raw-seal          `raw-seal-native
    %render-origin     `render-origin-native
    %join             `join-text
    %scot             `scot
    %scow             `scow
    %raw-format-tape  `scow
    %gth              `gth
    %add              `add
    %dec              `dec
    %eq               `|=([a=* b=*] =(a b))
    %lent             `lent
    %trip             `trip
    %tuba             `tuba
    %tufa             `tufa
    %crip             `crip
    %raw-crip         `crip
    %year             `year
    %yore             `yore
    %bit-not          `not
    %parse-atom       `parse-atom-native
    %map-get          `|=([a=(map * *) b=*] (~(get by a) b))
    %map-put          `|=([a=(map * *) b=[* *]] (~(put by a) -.b +.b))
  ==
::
::  [valid value]: text that does not parse, or whose parse crashes, as a
::  BC year zero does, is invalid.
++  parse-atom-native
  |=  [aura=@tas text=@ta]
  ^-  [? @]
  =/  parsed=(each (unit @) tang)  (mule |.((slaw aura text)))
  ?:  ?=(%| -.parsed)  [| 0]
  ?~  p.parsed  [| 0]
  [& u.p.parsed]
::
++  native-names
  |=  e=expr:jibb-core
  ^-  (list name:jibb-core)
  ?-  -.e
    %lit     ~
    %var     ~
    %native  ~[name.e]
    %crash   ~
    %cons    (weld $(e hed.e) $(e tal.e))
    %slot    $(e body.e)
    %edit    (weld $(e body.e) $(e value.e))
    %cell    $(e body.e)
    %eq      (weld $(e left.e) $(e right.e))
    %if      :(weld $(e test.e) $(e yes.e) $(e no.e))
    %let     (weld $(e value.e) $(e body.e))
    %rec
      =/  in-arms=(list name:jibb-core)
        %-  zing
        (turn arms.e |=(a=rec-arm:jibb-core ^$(e fun.a)))
      (weld in-arms $(e body.e))
    %lam     $(e body.e)
    %app     (weld $(e fun.e) $(e sample.e))
    %trace   (weld $(e message.e) $(e body.e))
  ==
::
++  unique-names
  |=  names=(list name:jibb-core)
  ^-  (list name:jibb-core)
  =/  out=(list name:jibb-core)  ~
  |-
  ?~  names  (flop out)
  ?:  (lien out |=(n=name:jibb-core =(n i.names)))  $(names t.names)
  $(names t.names, out [i.names out])
::
++  native-registry
  |=  expressions=(list expr:jibb-core)
  ^-  (each native-registry:jibb-nock @t)
  =/  names=(list name:jibb-core)
    (unique-names (zing (turn expressions native-names)))
  =/  out=native-registry:jibb-nock  *(map name:jibb-core noun)
  |-
  ?~  names  [%& out]
  =/  implementation=(unit noun)  (native-value i.names)
  ?~  implementation
    [%| (rap 3 ~['static build: authenticated native implementation is missing: ' (print-name:jibb-core i.names)])]
  $(names t.names, out (~(put by out) i.names u.implementation))
::
++  execute-linked
  |=  [label=@t e=expr:jibb-core registry=native-registry:jibb-nock]
  ^-  (each noun @t)
  =/  result=outcome:jibb-core  (run:jibb-nock e registry)
  ?:  ?=(%crash -.result)  [%| (cat 3 label ' crashed during Nock execution')]
  [%& val.result]
::
++  apply-linked
  |=  [label=@t fun=noun sample=noun]
  ^-  (each noun @t)
  =/  result=outcome:jibb-core
    (execute:jibb-nock fun [9 2 10 [6 [1 sample]] [0 1]])
  ?:  ?=(%crash -.result)  [%| (cat 3 label ' crashed during Nock execution')]
  [%& val.result]
::
++  render-failure
  |=  [message=@t origin=(unit render-origin)]
  ^-  render-error
  [message origin]
::
++  annotate-rendered-vnode
  |=  [origin=(unit render-origin) raw=noun]
  ^-  noun
  ?.  ?=(^ raw)  raw
  ?:  ?=([%link * * *] raw)
    =/  target=path  ;;(path +<.raw)
    =/  label=@t  ;;(@t +>-.raw)
    [%link target label origin]
  ?:  ?=([%image * * *] raw)
    =/  source=path  ;;(path +<.raw)
    =/  description=@t  ;;(@t +>-.raw)
    [%image source description origin]
  ?:  ?=([%link * *] raw)
    =/  link=[%link target=path label=@t]  ;;([%link target=path label=@t] raw)
    [%link target.link label.link origin]
  ?:  ?=([%image * *] raw)
    =/  image=[%image source=path description=@t]
      ;;([%image source=path description=@t] raw)
    [%image source.image description.image origin]
  raw
::
++  render-static-node
  |=  [ctx=renderer-context origin=(unit render-origin) raw=noun]
  ^-  (each vnode render-error)
  ?.  ?=(^ raw)  [%| (render-failure 'static renderer: malformed node' origin)]
  ?.  ?=(@ -.raw)  [%| (render-failure 'static renderer: malformed node tag' origin)]
  =/  tag=@tas  ;;(@tas -.raw)
  =/  found=(unit noun)  (~(get by nodes.ctx) tag)
  ?~  found  [%| (render-failure 'static renderer: no checked node renderer' origin)]
  =/  rendered=(each noun @t)
    (apply-linked 'static renderer' u.found [skin.ctx +.raw])
  ?:  ?=(%| -.rendered)  [%| (render-failure p.rendered origin)]
  =/  decoded=(each vnode tang)
    (mule |.(;;(vnode (annotate-rendered-vnode origin p.rendered))))
  ?:  ?=(%| -.decoded)
    [%| (render-failure 'static renderer: malformed rendered node' origin)]
  [%& p.decoded]
::
++  render-static-attributes
  |=  [ctx=renderer-context origin=(unit render-origin) raw=noun]
  ^-  (each (list vattr) render-error)
  ?~  raw  [%& ~]
  ?.  ?=(^ raw)  [%| (render-failure 'static renderer: malformed attributes' origin)]
  =/  first=(each noun @t)
    (apply-linked 'static attribute renderer' attrs.ctx [skin.ctx -.raw])
  ?:  ?=(%| -.first)  [%| (render-failure p.first origin)]
  =/  rest=(each (list vattr) render-error)  $(raw +.raw)
  ?:  ?=(%| -.rest)  rest
  =/  decoded=(each (list vattr) tang)  (mule |.(;;((list vattr) p.first)))
  ?:  ?=(%| -.decoded)
    [%| (render-failure 'static renderer: malformed rendered attributes' origin)]
  [%& (weld p.decoded p.rest)]
::
++  render-static-children
  |=  [ctx=renderer-context origin=(unit render-origin) children=noun]
  ^-  (each (list vnode) render-error)
  ?~  children  [%& ~]
  ?.  ?=(^ children)
    [%| (render-failure 'static renderer: malformed element children' origin)]
  =/  first=(each vnode render-error)  (render-static-element ctx -.children)
  ?:  ?=(%| -.first)  first
  =/  rest=(each (list vnode) render-error)  $(children +.children)
  ?:  ?=(%| -.rest)  rest
  [%& [p.first p.rest]]
::
++  render-static-layout
  |=  [ctx=renderer-context origin=(unit render-origin) tag=@tas raw=noun]
  ^-  (each vnode render-error)
  ?.  ?=(^ raw)
    [%| (render-failure 'static renderer: malformed layout payload' origin)]
  =/  attrs=(each (list vattr) render-error)
    (render-static-attributes ctx origin -.raw)
  ?:  ?=(%| -.attrs)  attrs
  =/  kids=(each (list vnode) render-error)
    (render-static-children ctx origin +.raw)
  ?:  ?=(%| -.kids)  kids
  (render-static-node ctx origin [tag p.attrs p.kids])
::
++  render-static-element
  |=  [ctx=renderer-context wrapped=noun]
  ^-  (each vnode render-error)
  =/  found=(unit [origin=render-origin sealed=noun])
    (read-render-origin wrapped)
  =/  origin=(unit render-origin)  ?~(found ~ `origin.u.found)
  =/  sealed=noun  ?~(found wrapped sealed.u.found)
  ?.  &(?=(^ sealed) =('jibb.private.seal.v1' -.sealed))
    [%| (render-failure 'static renderer: element lost its authenticated seal' origin)]
  =/  raw=noun  +.sealed
  ?.  ?=(^ raw)  [%| (render-failure 'static renderer: malformed element' origin)]
  ?.  ?=(@ -.raw)  [%| (render-failure 'static renderer: malformed element tag' origin)]
  =/  tag=@tas  ;;(@tas -.raw)
  ?+  tag  [%| (render-failure (crip "static renderer: unsupported element {(trip tag)}") origin)]
    %island
      ?:  inside.ctx
        [%| (render-failure 'static renderer: an island cannot hold another island' origin)]
      (render-island ctx origin +.raw)
    ?(%button %toggle %field %form)
      ?.  inside.ctx
        [%| (render-failure (crip "a {(trip tag)} is a control, which renders only inside an island") origin)]
      (render-control ctx origin tag +.raw)
    %each  (render-each ctx origin +.raw)
    %table  (render-table ctx origin +.raw)
    ?(%text %heading %link %link-unsafe %image %image-unsafe)
      (render-static-node ctx origin raw)
    ?(%row %column %wrap %stack)  (render-static-layout ctx origin tag +.raw)
    %para
      =/  kids=(each (list vnode) render-error)
        (render-static-children ctx origin +.raw)
      ?:  ?=(%| -.kids)  kids
      (render-static-node ctx origin [%para p.kids])
    %el
      ?.  ?=(^ +.raw)  [%| (render-failure 'static renderer: malformed el payload' origin)]
      =/  attrs=(each (list vattr) render-error)
        (render-static-attributes ctx origin +<.raw)
      ?:  ?=(%| -.attrs)  attrs
      =/  kid=(each vnode render-error)  (render-static-element ctx +>.raw)
      ?:  ?=(%| -.kid)  kid
      (render-static-node ctx origin [%el p.attrs p.kid])
  ==
::
::  A control's message stays in the browser: only what it shows renders.
++  render-control
  |=  [ctx=renderer-context origin=(unit render-origin) tag=@tas payload=noun]
  ^-  (each vnode render-error)
  ?.  ?=(^ payload)
    [%| (render-failure (crip "static renderer: malformed {(trip tag)}") origin)]
  ?+  tag  [%| (render-failure (crip "static renderer: unsupported control {(trip tag)}") origin)]
    %button  (render-static-node ctx origin [%button -.payload])
  ::
      %toggle
    ?.  ?=([* * *] payload)  [%| (render-failure 'static renderer: malformed toggle' origin)]
    (render-static-node ctx origin [%toggle -.payload +<.payload])
  ::
      %field
    ?.  ?=([* * *] payload)  [%| (render-failure 'static renderer: malformed field' origin)]
    (render-static-node ctx origin [%field -.payload +<.payload])
  ::
      %form
    =/  kids=(each (list vnode) render-error)
      (render-static-children ctx origin +.payload)
    ?:  ?=(%| -.kids)  kids
    (render-static-node ctx origin [%form p.kids])
  ==
::
::  Keyed items: the keys are the browser's.
++  render-each
  |=  [ctx=renderer-context origin=(unit render-origin) items=noun]
  ^-  (each vnode render-error)
  =|  out=(list vnode)
  |-
  ?~  items  (render-static-node ctx origin [%each (flop out)])
  ?.  ?=([[* *] *] items)
    [%| (render-failure 'static renderer: malformed each item' origin)]
  =/  kid=(each vnode render-error)  (render-static-element ctx ->.items)
  ?:  ?=(%| -.kid)  kid
  $(items +.items, out [p.kid out])
::
::  A table: each column's head through the renderer, each row's cells in
::  table cells.
++  render-table
  |=  [ctx=renderer-context origin=(unit render-origin) payload=noun]
  ^-  (each vnode render-error)
  ?.  ?=(^ payload)  [%| (render-failure 'static renderer: malformed table' origin)]
  =/  heads=(each (list vnode) render-error)
    =|  out=(list vnode)
    =/  columns=noun  -.payload
    |-
    ?~  columns  [%& (flop out)]
    ?.  ?=(^ columns)
      [%| (render-failure 'static renderer: malformed table columns' origin)]
    =/  head=(each vnode render-error)
      (render-static-node ctx origin [%table-head -.columns])
    ?:  ?=(%| -.head)  head
    $(columns +.columns, out [p.head out])
  ?:  ?=(%| -.heads)  heads
  =/  rows=(each (list vnode) render-error)
    =|  out=(list vnode)
    =/  raw=noun  +.payload
    |-
    ?~  raw  [%& (flop out)]
    ?.  ?=([[* *] *] raw)
      [%| (render-failure 'static renderer: malformed table row' origin)]
    =/  cells=(each (list vnode) render-error)
      (render-static-children ctx origin ->.raw)
    ?:  ?=(%| -.cells)  cells
    =/  tds=(list vnode)  (turn p.cells |=(c=vnode [%node 'td' ~ ~[c]]))
    $(raw +.raw, out [[%node 'tr' ~ tds] out])
  ?:  ?=(%| -.rows)  rows
  :-  %&
  :^  %node  'table'  ~[['style:border-collapse' 'collapse'] ['style:max-width' '100%']]
  :~  [%node 'thead' ~ ~[[%node 'tr' ~ p.heads]]]
      [%node 'tbody' ~ p.rows]
  ==
::
::  An island's first view, rendered with its data at the page's stage, then
::  its model, jammed, for the browser to resume from.  Its program came
::  paired with its module's path, which names the island's JavaScript.  A
::  crash in init or the first view shows the crash notice instead. Reference
::  validation is a separate post-pass and remains a page error.
++  render-island
  |=  [ctx=renderer-context origin=(unit render-origin) payload=noun]
  ^-  (each vnode render-error)
  ?.  ?=([[@ *] *] payload)
    [%| (render-failure 'static renderer: an island lost its module' origin)]
  =/  module=@t  -<.payload
  =/  hash=(unit @t)  (~(get by islands.ctx) module)
  ?~  hash
    [%| (render-failure (crip "static renderer: {(trip module)} is not an island module this build compiled") origin)]
  =/  program=noun  ->.payload
  ?.  ?=([* * * *] program)
    [%| (render-failure 'static renderer: an island program is not init, update, view and subs' origin)]
  =/  model=(each noun @t)  (apply-linked 'island init' -.program +.payload)
  =/  view=(each noun @t)
    ?:  ?=(%| -.model)  model
    (apply-linked 'island view' +>-.program p.model)
  =/  inner=(each vnode render-error)
    (render-static-element ctx(inside &) p.view)
  ?:  |(?=(%| -.model) ?=(%| -.view) ?=(%| -.inner))
    [%& [%node 'div' ~[['data-jibb-island' u.hash] ['data-jibb-crashed' '']] ~[crash-notice]]]
  =/  state=@t  (scot %uw (jam p.model))
  :-  %&
  :^  %node  'div'  ~[['data-jibb-island' u.hash]]
  ~[p.inner [%node 'script' ~[['type' 'application/x-jibb-state']] ~[[%text state]]]]
::  The standard notice of a crashed island, as the browser shows it too.
++  crash-notice
  ^-  vnode
  :^  %node  'p'  ~[['role' 'alert'] ['class:tone' 'j-tone-danger'] ['data-jibb-notice' '']]
  ~[[%text 'This part of the page stopped working. Reloading the page may fix it.']]
::
::  Theme checks.  Spaces and wide are CSS lengths; tones are hex colours,
::  each needing 4.5:1 contrast with its background, dark tones included;
::  lang is a language tag; a font must be a static font file.
::
++  check-theme
  |=  [skin=theme-view assets=(list static-asset)]
  ^-  (each (unit static-asset) @t)
  =/  lengths=(list [name=tape value=@t])
    :~  ["space.s1" s1.space.skin]
        ["space.s2" s2.space.skin]
        ["space.s3" s3.space.skin]
        ["wide" wide.skin]
    ==
  =/  bad=(list [name=tape value=@t])
    (skip lengths |=(l=[name=tape value=@t] (css-length value.l)))
  ?^  bad
    [%| (crip "theme: {name.i.bad} is {(trip value.i.bad)}, not a CSS length such as 16px or 1.5rem")]
  ::  wide is a media query's width, which cannot be a percentage.
  ?:  =('%' (rear (trip wide.skin)))
    [%| (crip "theme: wide is {(trip wide.skin)}, but a media query needs a length such as 60rem, not a percentage")]
  ?.  (language-tag lang.skin)
    [%| (crip "theme: lang is {(trip lang.skin)}, not a language tag such as en or pt-BR")]
  =/  light=(each ~ @t)  (check-tones "tones" tones.skin)
  ?:  ?=(%| -.light)  light
  =/  dark=(each ~ @t)
    ?~  dark.skin  [%& ~]
    (check-tones "dark.tones" tones.u.dark.skin)
  ?:  ?=(%| -.dark)  dark
  ?~  font.skin  [%& ~]
  =/  asset=(unit static-asset)  (find-asset assets u.font.skin)
  ?~  asset  [%| (crip "missing static asset: {(spud u.font.skin)}")]
  ?~  (font-format type.u.asset)
    [%| (crip "theme: font {(spud u.font.skin)} is not a font file")]
  [%& asset]
::
++  check-tones
  |=  [label=tape tones=tones-view]
  ^-  (each ~ @t)
  =/  named=(list [name=tape value=@t])
    :~  ["normal" normal.tones]
        ["background" background.tones]
        ["accent" accent.tones]
        ["danger" danger.tones]
        ["muted" muted.tones]
    ==
  =/  bad=(list [name=tape value=@t])
    (skip named |=(n=[name=tape value=@t] ?=(^ (hex-colour value.n))))
  ?^  bad
    [%| (crip "theme: {label}.{name.i.bad} is {(trip value.i.bad)}, not a hex colour such as #17734f")]
  =/  back=[r=@ud g=@ud b=@ud]  (need (hex-colour background.tones))
  =/  low=(list [name=tape value=@t])
    %+  skip  named
    |=  n=[name=tape value=@t]
    ?|  =("background" name.n)
        (gte (contrast (need (hex-colour value.n)) back) 450)
    ==
  ?~  low  [%& ~]
  =/  ratio=@ud  (contrast (need (hex-colour value.i.low)) back)
  :-  %|
  %-  crip
  "theme: {label}.{name.i.low} {(trip value.i.low)} has contrast {(ratio-text ratio)}:1 with {label}.background {(trip background.tones)}; text needs 4.5:1"
::
++  css-length
  |=  value=@t
  ^-  ?
  =/  text=tape  (trip value)
  ?:  =("0" text)  &
  =/  digits=@ud  0
  =/  dot=?  |
  |-
  ?~  text  |
  ?:  &((gte i.text '0') (lte i.text '9'))  $(text t.text, digits +(digits))
  ?:  &(=('.' i.text) !dot)  $(text t.text, dot &)
  ?:  =(0 digits)  |
  %+  lien  `(list tape)`~["px" "rem" "em" "ch" "ex" "vw" "vh" "vmin" "vmax" "%"]
  |=(unit=tape =(unit `tape`text))
::
++  language-tag
  |=  value=@t
  ^-  ?
  =/  text=tape  (trip value)
  ?~  text  |
  ?.  |(&((gte i.text 'a') (lte i.text 'z')) &((gte i.text 'A') (lte i.text 'Z')))  |
  %+  levy  t.text
  |=  c=@tD
  ?|  &((gte c 'a') (lte c 'z'))
      &((gte c 'A') (lte c 'Z'))
      &((gte c '0') (lte c '9'))
      =('-' c)
  ==
::
++  hex-colour
  |=  value=@t
  ^-  (unit [r=@ud g=@ud b=@ud])
  =/  text=tape  (trip value)
  ?.  ?=([%'#' *] text)  ~
  =/  digits=(list (unit @ud))  (turn t.text hex-digit)
  ?.  (levy digits |=(d=(unit @ud) ?=(^ d)))  ~
  =/  ds=(list @ud)  (turn digits |=(d=(unit @ud) (need d)))
  ?:  ?=([@ @ @ ~] ds)
    `[(mul 17 i.ds) (mul 17 i.t.ds) (mul 17 i.t.t.ds)]
  ?.  ?=([@ @ @ @ @ @ ~] ds)  ~
  :-  ~
  :+  (add (mul 16 i.ds) i.t.ds)
    (add (mul 16 i.t.t.ds) i.t.t.t.ds)
  (add (mul 16 i.t.t.t.t.ds) i.t.t.t.t.t.ds)
::
++  hex-digit
  |=  c=@tD
  ^-  (unit @ud)
  ?:  &((gte c '0') (lte c '9'))  `(sub c '0')
  ?:  &((gte c 'a') (lte c 'f'))  `(add 10 (sub c 'a'))
  ?:  &((gte c 'A') (lte c 'F'))  `(add 10 (sub c 'A'))
  ~
::
::  +contrast: the WCAG ratio (L1 + 0.05) / (L2 + 0.05), times 100, rounded
::  down, so 450 is 4.5:1.  Relative luminance is in units of 10^-7.
++  contrast
  |=  [one=[r=@ud g=@ud b=@ud] two=[r=@ud g=@ud b=@ud]]
  ^-  @ud
  =/  a=@ud  (luminance one)
  =/  b=@ud  (luminance two)
  (div (mul 100 (add (max a b) 500.000)) (add (min a b) 500.000))
::
++  luminance
  |=  colour=[r=@ud g=@ud b=@ud]
  ^-  @ud
  %+  div
    ;:  add
      (mul 2.126 (snag r.colour srgb-linear))
      (mul 7.152 (snag g.colour srgb-linear))
      (mul 722 (snag b.colour srgb-linear))
    ==
  10.000
::
++  ratio-text
  |=  ratio=@ud
  ^-  tape
  =/  hundredths=@ud  (mod ratio 100)
  =/  fraction=tape  (a-co:co hundredths)
  "{(a-co:co (div ratio 100))}.{?:((lth hundredths 10) "0" "")}{fraction}"
::
::  +srgb-linear: each sRGB channel byte as linear light, in units of 10^-7
++  srgb-linear
  ^-  (list @ud)
  :~
  0  3.035  6.071  9.106  12.141  15.176  18.212  21.247
  24.282  27.317  30.353  33.465  36.765  40.247  43.914  47.770
  51.815  56.054  60.488  65.121  69.954  74.990  80.232  85.681
  91.341  97.212  103.298  109.601  116.122  122.865  129.830  137.021
  144.438  152.085  159.963  168.074  176.420  185.002  193.824  202.886
  212.190  221.739  231.534  241.576  251.869  262.412  273.209  284.260
  295.568  307.134  318.960  331.048  343.398  356.013  368.895  382.044
  395.462  409.152  423.114  437.350  451.862  466.651  481.718  497.066
  512.695  528.606  544.803  561.285  578.054  595.112  612.461  630.100
  648.033  666.259  684.782  703.601  722.719  742.136  761.854  781.874
  802.198  822.827  843.762  865.005  886.556  908.417  930.590  953.075
  975.873  998.987  1.022.417  1.046.165  1.070.231  1.094.617  1.119.324  1.144.354
  1.169.707  1.195.384  1.221.388  1.247.718  1.274.377  1.301.365  1.328.683  1.356.333
  1.384.316  1.412.633  1.441.285  1.470.273  1.499.598  1.529.262  1.559.265  1.589.608
  1.620.294  1.651.322  1.682.694  1.714.411  1.746.474  1.778.884  1.811.642  1.844.750
  1.878.208  1.912.017  1.946.178  1.980.693  2.015.563  2.050.787  2.086.369  2.122.308
  2.158.605  2.195.262  2.232.280  2.269.659  2.307.400  2.345.506  2.383.976  2.422.811
  2.462.013  2.501.583  2.541.521  2.581.829  2.622.507  2.663.556  2.704.978  2.746.773
  2.788.943  2.831.487  2.874.408  2.917.706  2.961.383  3.005.438  3.049.873  3.094.689
  3.139.887  3.185.468  3.231.432  3.277.781  3.324.515  3.371.636  3.419.144  3.467.041
  3.515.326  3.564.001  3.613.068  3.662.526  3.712.377  3.762.621  3.813.260  3.864.294
  3.915.725  3.967.552  4.019.778  4.072.402  4.125.426  4.178.851  4.232.677  4.286.905
  4.341.536  4.396.572  4.452.012  4.507.858  4.564.110  4.620.770  4.677.838  4.735.315
  4.793.202  4.851.499  4.910.208  4.969.330  5.028.865  5.088.813  5.149.177  5.209.956
  5.271.151  5.332.764  5.394.795  5.457.245  5.520.114  5.583.404  5.647.115  5.711.248
  5.775.804  5.840.784  5.906.188  5.972.018  6.038.273  6.104.956  6.172.066  6.239.604
  6.307.571  6.375.969  6.444.797  6.514.056  6.583.748  6.653.873  6.724.432  6.795.425
  6.866.853  6.938.718  7.011.019  7.083.758  7.156.935  7.230.551  7.304.607  7.379.104
  7.454.042  7.529.422  7.605.245  7.681.511  7.758.222  7.835.378  7.912.979  7.991.027
  8.069.523  8.148.466  8.227.858  8.307.699  8.387.990  8.468.732  8.549.926  8.631.572
  8.713.671  8.796.224  8.879.231  8.962.694  9.046.612  9.130.987  9.215.819  9.301.109
  9.386.857  9.473.065  9.559.734  9.646.862  9.734.453  9.822.506  9.911.021  10.000.000
  ==
::
++  font-format
  |=  type=@t
  ^-  (unit @t)
  ?:  =('font/woff2' type)  `'woff2'
  ?:  =('font/woff' type)  `'woff'
  ?:  =('font/ttf' type)  `'truetype'
  ?:  =('font/otf' type)  `'opentype'
  ~
::
::  +theme-stylesheet: the one stylesheet a desk's pages share
::
::    Tokens become custom properties, wide the breakpoint where stack turns
::    into a row, and dark tones a prefers-color-scheme override.  Every
::    style attribute is an atomic class; [%chars n] and [%fill n] stay
::    inline.  Heading and role sizes are the Typography decision.
++  theme-stylesheet
  |=  [skin=theme-view font=(unit static-asset)]
  ^-  @t
  =/  palette
    |=  t=tones-view
    ^-  @t
    %+  rap  3
    :~  '--j-normal:'  normal.t  ';--j-background:'  background.t
        ';--j-accent:'  accent.t  ';--j-danger:'  danger.t  ';--j-muted:'  muted.t
    ==
  =/  root=@t
    %+  rap  3
    :~  ':root{--j-s1:'  s1.space.skin  ';--j-s2:'  s2.space.skin
        ';--j-s3:'  s3.space.skin  ';'  (palette tones.skin)  ';color-scheme:light}'
    ==
  =/  dark=@t
    ?~  dark.skin  ''
    %+  rap  3
    ~['@media (prefers-color-scheme:dark){:root{' (palette tones.u.dark.skin) ';color-scheme:dark}}']
  =/  face=@t
    ?~  font  ''
    %+  rap  3
    :~  '@font-face{font-family:jibb-theme;src:url("'  url.u.font
        '") format("'  (fall (font-format type.u.font) 'woff2')
        '");font-weight:100 900;font-display:swap}'
    ==
  =/  family=@t
    =/  system=@t  'system-ui,-apple-system,"Segoe UI",Roboto,sans-serif'
    ?~(font system (cat 3 'jibb-theme,' system))
  %+  rap  3
  :~  root  dark  face
      'html{color:var(--j-normal);background:var(--j-background);font-family:'
      family
      ';font-size:100%;line-height:1.5;-webkit-text-size-adjust:100%}'
      'body{margin:0}main{overflow-wrap:anywhere}h1,h2,h3,h4,h5,h6,p{margin:0}'
      'h1{font-size:2rem;line-height:1.2;font-weight:700}'
      'h2{font-size:1.5rem;line-height:1.25;font-weight:700}'
      'h3{font-size:1.25rem;line-height:1.3;font-weight:600}'
      'h4{font-size:1.125rem;line-height:1.4;font-weight:600}'
      'h5{font-size:1rem;line-height:1.5;font-weight:600}'
      'h6{font-size:.875rem;line-height:1.5;font-weight:600}'
      'a{color:var(--j-accent)}img{display:block;max-width:100%;height:auto}'
      '.j-row,.j-wrap{display:flex;flex-direction:row;align-items:center}.j-wrap{flex-wrap:wrap}'
      '.j-column,.j-stack{display:flex;flex-direction:column}'
      '@media (min-width:'  wide.skin  '){.j-stack{flex-direction:row}}'
      '.j-row>*,.j-column>*,.j-wrap>*,.j-stack>*{min-width:0}'
      '.j-shrink{flex:0 0 auto;width:auto}'
      '.j-pad-s0{padding:0}.j-pad-s1{padding:var(--j-s1)}.j-pad-s2{padding:var(--j-s2)}.j-pad-s3{padding:var(--j-s3)}'
      '.j-gap-s0{gap:0}.j-gap-s1{gap:var(--j-s1)}.j-gap-s2{gap:var(--j-s2)}.j-gap-s3{gap:var(--j-s3)}'
      '.j-align-start{text-align:start;justify-content:flex-start}'
      '.j-align-center{text-align:center;justify-content:center}'
      '.j-align-end{text-align:end;justify-content:flex-end}'
      '.j-role-body{font-size:1rem;line-height:1.5;font-weight:400}'
      '.j-role-caption{font-size:.875rem;line-height:1.4;font-weight:400}'
      '.j-role-label{font-size:.875rem;line-height:1.25;font-weight:600}'
      '.j-tone-normal{color:var(--j-normal)}.j-tone-muted{color:var(--j-muted)}'
      '.j-tone-accent{color:var(--j-accent)}.j-tone-danger{color:var(--j-danger)}'
      '.j-tone-danger::before{content:"! "}'
      '.j-tone-normal a,.j-tone-muted a,.j-tone-accent a,.j-tone-danger a{color:inherit}'
  ==
::
::  Image sizes, read from the file.  A static image is boxed to its aspect
::  ratio before it loads, so an image whose size cannot be read fails.
::
++  image-size
  |=  [type=@t data=octs]
  ^-  (unit [width=@ud height=@ud])
  ?:  =('image/png' type)  (png-size data)
  ?:  =('image/gif' type)  (gif-size data)
  ?:  =('image/jpeg' type)  (jpeg-size data)
  ?:  =('image/webp' type)  (webp-size data)
  ?:  =('image/svg+xml' type)  (svg-size data)
  ~
::
++  byte-at
  |=  [data=octs at=@ud]
  ^-  @ud
  (cut 3 [at 1] q.data)
::
++  big-endian
  |=  [data=octs at=@ud size=@ud]
  ^-  @ud
  =|  out=@ud
  =/  i=@ud  0
  |-
  ?:  =(i size)  out
  $(i +(i), out (add (mul out 256) (byte-at data (add at i))))
::
++  little-endian
  |=  [data=octs at=@ud size=@ud]
  ^-  @ud
  (cut 3 [at size] q.data)
::
++  png-size
  |=  data=octs
  ^-  (unit [width=@ud height=@ud])
  ?.  (gte p.data 24)  ~
  ?.  =(0xa1a.0a0d.474e.5089 (cut 3 [0 8] q.data))  ~
  ?.  =('IHDR' (cut 3 [12 4] q.data))  ~
  `[(big-endian data 16 4) (big-endian data 20 4)]
::
++  gif-size
  |=  data=octs
  ^-  (unit [width=@ud height=@ud])
  ?.  (gte p.data 10)  ~
  =/  magic=@t  (cut 3 [0 6] q.data)
  ?.  |(=('GIF87a' magic) =('GIF89a' magic))  ~
  `[(little-endian data 6 2) (little-endian data 8 2)]
::
::  The first start-of-frame segment carries a JPEG's size.
++  jpeg-size
  |=  data=octs
  ^-  (unit [width=@ud height=@ud])
  ?.  &((gte p.data 4) =(0xff (byte-at data 0)) =(0xd8 (byte-at data 1)))  ~
  =/  at=@ud  2
  |-
  ?.  (lth (add at 8) p.data)  ~
  ?.  =(0xff (byte-at data at))  ~
  =/  marker=@ud  (byte-at data +(at))
  ?:  =(0xff marker)  $(at +(at))
  ?:  ?&  (gte marker 0xc0)  (lte marker 0xcf)
          !=(0xc4 marker)  !=(0xc8 marker)  !=(0xcc marker)
      ==
    `[(big-endian data (add at 7) 2) (big-endian data (add at 5) 2)]
  ?:  |(=(0x1 marker) &((gte marker 0xd0) (lte marker 0xd8)))
    $(at (add at 2))
  $(at (add at (add 2 (big-endian data (add at 2) 2))))
::
++  webp-size
  |=  data=octs
  ^-  (unit [width=@ud height=@ud])
  ?.  (gte p.data 30)  ~
  ?.  &(=('RIFF' (cut 3 [0 4] q.data)) =('WEBP' (cut 3 [8 4] q.data)))  ~
  =/  chunk=@t  (cut 3 [12 4] q.data)
  ?:  =('VP8X' chunk)
    `[+((little-endian data 24 3)) +((little-endian data 27 3))]
  ?:  =('VP8L' chunk)
    ?.  =(0x2f (byte-at data 20))  ~
    =/  bits=@ud  (little-endian data 21 4)
    `[+((end [0 14] bits)) +((cut 0 [14 14] bits))]
  ?:  =('VP8 ' chunk)
    `[(end [0 14] (little-endian data 26 2)) (end [0 14] (little-endian data 28 2))]
  ~
::
::  An SVG's size is its root element's width and height in pixels, or else
::  the size of its viewBox.
++  svg-size
  |=  data=octs
  ^-  (unit [width=@ud height=@ud])
  =/  text=tape  (trip q.data)
  =/  start=(unit @ud)  (find "<svg" text)
  ?~  start  ~
  =/  rest=tape  (slag u.start text)
  =/  close=(unit @ud)  (find ">" rest)
  ?~  close  ~
  =/  tag=tape  (scag u.close rest)
  =/  width=(unit @ud)  (svg-number (svg-attribute tag "width"))
  =/  height=(unit @ud)  (svg-number (svg-attribute tag "height"))
  ?:  &(?=(^ width) ?=(^ height))  `[u.width u.height]
  =/  box=(unit tape)  (svg-attribute tag "viewBox")
  ?~  box  ~
  =/  numbers=(list tape)  (svg-words u.box)
  ?.  ?=([* * * * ~] numbers)  ~
  =/  w=(unit @ud)  (svg-number `i.t.t.numbers)
  =/  h=(unit @ud)  (svg-number `i.t.t.t.numbers)
  ?:  &(?=(^ w) ?=(^ h))  `[u.w u.h]
  ~
::
++  svg-attribute
  |=  [tag=tape name=tape]
  ^-  (unit tape)
  =/  key=tape  " {name}=\""
  =/  at=(unit @ud)  (find key tag)
  ?~  at  ~
  =/  rest=tape  (slag (add u.at (lent key)) tag)
  =/  stop=(unit @ud)  (find "\"" rest)
  ?~  stop  ~
  `(scag u.stop rest)
::
::  A whole or decimal number of pixels, rounded down.
++  svg-number
  |=  value=(unit tape)
  ^-  (unit @ud)
  ?~  value  ~
  =/  text=tape  u.value
  =?  text  &((gth (lent text) 2) =("px" (slag (sub (lent text) 2) text)))
    (scag (sub (lent text) 2) text)
  =/  whole=tape  (scag (fall (find "." text) (lent text)) text)
  ::  =(~ whole), not ?~: a refined tape cannot pass to the wet +levy.
  ?:  =(~ whole)  ~
  =/  digit  |=(c=@tD &((gte c '0') (lte c '9')))
  ?.  (levy whole digit)  ~
  ?.  (levy (slag +((lent whole)) text) digit)  ~
  (rush (crip whole) dem)
::
++  svg-words
  |=  text=tape
  ^-  (list tape)
  =|  word=tape
  =|  out=(list tape)
  |-
  ?~  text  (flop ?~(word out [(flop word) out]))
  ?:  |(=(' ' i.text) =(',' i.text))
    $(text t.text, word ~, out ?~(word out [(flop word) out]))
  $(text t.text, word [i.text word])
::
::  Links and images.  An application path names a static file or one of the
::  desk's pages; a page link may fill a _parameter or a __catch-all.  An
::  unchecked URL is a link only if it is root-relative or https, mailto or
::  tel; anything else, such as javascript:, is drawn as text.
::
++  find-asset
  |=  [assets=(list static-asset) at=path]
  ^-  (unit static-asset)
  ?~  assets  ~
  ?:  =(at at.i.assets)  `i.assets
  $(assets t.assets)
::
++  route-matches
  |=  [route=(list @t) target=path]
  ^-  ?
  ?~  route  ?=(~ target)
  ?:  =('__' (end [3 2] i.route))  &
  ?~  target  |
  ?:  =('_' (end [3 1] i.route))  $(route t.route, target t.target)
  ?.  =(i.route i.target)  |
  $(route t.route, target t.target)
::
++  safe-url
  |=  url=@t
  ^-  ?
  =/  text=tape  (trip url)
  ::  Browsers drop tabs and newlines inside a URL, so a "/", a tab and a
  ::  "/" would be protocol-relative: no control byte or space is allowed.
  ?:  (lien text |=(c=@tD |((lte c ' ') =(c 0x7f))))  |
  ?:  |(=("//" (scag 2 text)) =("/\\" (scag 2 text)))  |
  ?:  =("/" (scag 1 text))  &
  ?|  =("https:" (scag 6 text))
      =("mailto:" (scag 7 text))
      =("tel:" (scag 4 text))
  ==
::
++  check-references
  |=  [ctx=page-context node=vnode]
  ^-  (each ~ render-error)
  ?-  -.node
    %text          [%& ~]
    %node          (check-reference-list ctx kids.node)
    %link          (check-link ctx target.node origin.node)
    %link-unsafe   [%& ~]
    %image         (check-image ctx source.node origin.node)
    %image-unsafe  [%& ~]
  ==
::
++  check-reference-list
  |=  [ctx=page-context nodes=(list vnode)]
  ^-  (each ~ render-error)
  ?~  nodes  [%& ~]
  =/  first=(each ~ render-error)  (check-references ctx i.nodes)
  ?:  ?=(%| -.first)  first
  $(nodes t.nodes)
::
++  check-link
  |=  [ctx=page-context target=path origin=(unit render-origin)]
  ^-  (each ~ render-error)
  ?:  ?=([%static *] target)
    ?^  (find-asset assets.ctx target)  [%& ~]
    [%| (render-failure (crip "missing static asset: {(spud target)}") origin)]
  ?:  (lien routes.ctx |=(r=(list @t) (route-matches r target)))  [%& ~]
  [%| (render-failure (crip "link to a missing page: %{(spud target)}") origin)]
::
++  check-image
  |=  [ctx=page-context source=path origin=(unit render-origin)]
  ^-  (each ~ render-error)
  ?.  ?=([%static *] source)
    [%| (render-failure (crip "an image's application path must name a static file: %{(spud source)}") origin)]
  =/  asset=(unit static-asset)  (find-asset assets.ctx source)
  ?~  asset  [%| (render-failure (crip "missing static asset: {(spud source)}") origin)]
  ?~  (image-size type.u.asset data.u.asset)
    [%| (render-failure (crip "static image has no size this build can read: {(spud source)}") origin)]
  [%& ~]
::
++  last-byte
  |=  bytes=tape
  ^-  @tD
  ?~  bytes  !!
  ?~  t.bytes  i.bytes
  $(bytes t.bytes)
::
++  valid-base
  |=  base=@t
  ^-  ?
  =/  bytes=tape  (trip base)
  ?~  bytes  |
  ?~  t.bytes  |
  ?.  =('/' i.bytes)  |
  ?.  =('/' (last-byte bytes))  &
  |
::
++  url-safe
  |=  byte=@tD
  ^-  ?
  ?|  &((gte byte 'a') (lte byte 'z'))
      &((gte byte 'A') (lte byte 'Z'))
      &((gte byte '0') (lte byte '9'))
      =(byte '-')  =(byte '.')  =(byte '_')  =(byte '~')
  ==
::
++  url-encode
  |=  part=@ta
  ^-  @t
  =/  alphabet=tape  "0123456789ABCDEF"
  =/  bytes=(list @tD)  (trip part)
  =/  out=tape  ~
  |-
  ?~  bytes  (crip (flop out))
  =/  byte=@tD  i.bytes
  ?:  (url-safe byte)  $(bytes t.bytes, out [byte out])
  =/  encoded=tape
    :~  '%'
        (snag (div byte 16) alphabet)
        (snag (mod byte 16) alphabet)
    ==
  $(bytes t.bytes, out (weld encoded out))
::
++  application-href
  |=  [base=@t parts=path]
  ^-  @t
  ?~  parts  base
  $(parts t.parts, base (rap 3 ~[base '/' (url-encode i.parts)]))
::
++  escape-html
  |=  value=@t
  ^-  @t
  =/  bytes=(list @tD)  (trip value)
  =/  out=@t  ''
  |-
  ?~  bytes  out
  =/  piece=@t
    ?:  =(38 i.bytes)   '&amp;'
    ?:  =(60 i.bytes)   '&lt;'
    ?:  =(62 i.bytes)   '&gt;'
    ?:  =(34 i.bytes)   '&quot;'
    ?:  =(39 i.bytes)   '&apos;'
    (crip ~[i.bytes])
  $(bytes t.bytes, out (cat 3 out piece))
::
::  class:<family> and style:<property> attributes keep their last value
::  and each kind becomes one attribute, so a later pad replaces an earlier
::  one as the attribute rules say.
++  serialize-attributes
  |=  attrs=(list vattr)
  ^-  @t
  =|  classes=(list [key=@t value=@t])
  =|  styles=(list [key=@t value=@t])
  =|  ordinary=(list vattr)
  |-
  ?^  attrs
    =/  name=@t  name.i.attrs
    ?:  =('class:' (end [3 6] name))
      $(attrs t.attrs, classes (put-last classes (rsh [3 6] name) value.i.attrs))
    ?:  =('style:' (end [3 6] name))
      $(attrs t.attrs, styles (put-last styles (rsh [3 6] name) value.i.attrs))
    $(attrs t.attrs, ordinary (snoc ordinary i.attrs))
  =/  class=(list @t)
    ?~  classes  ~
    =/  names=@t  (join-text ' ' (turn classes |=(c=[key=@t value=@t] value.c)))
    ~[(rap 3 ~['class="' (escape-html names) '"'])]
  =/  plain=(list @t)
    (turn ordinary |=(a=vattr (rap 3 ~[name.a '="' (escape-html value.a) '"'])))
  =/  style=(list @t)
    ?~  styles  ~
    =/  rules=(list @t)
      (turn styles |=(s=[key=@t value=@t] (rap 3 ~[key.s ': ' value.s])))
    ~[(rap 3 ~['style="' (escape-html (join-text '; ' rules)) '"'])]
  =/  all=(list @t)  :(weld class plain style)
  ?~  all  ''
  (cat 3 ' ' (join-text ' ' all))
::
++  put-last
  |=  [entries=(list [key=@t value=@t]) key=@t value=@t]
  ^-  (list [key=@t value=@t])
  ?.  (lien entries |=(e=[key=@t value=@t] =(key.e key)))
    (snoc entries [key value])
  (turn entries |=(e=[key=@t value=@t] ?:(=(key.e key) [key value] e)))
::
++  serialize-vnodes
  |=  [ctx=page-context nodes=(list vnode)]
  ^-  @t
  ?~  nodes  ''
  (cat 3 (serialize-vnode ctx i.nodes) $(nodes t.nodes))
::
::  Called on a tree +check-references accepted.
++  serialize-vnode
  |=  [ctx=page-context node=vnode]
  ^-  @t
  ?-  -.node
    %text  (escape-html words.node)
    %node
      ::  An input is a void element: no children and no end tag.
      ?:  =('input' tag.node)
        (rap 3 ~['<' tag.node (serialize-attributes attrs.node) '>'])
      %+  rap  3
      :~  '<'  tag.node  (serialize-attributes attrs.node)  '>'
          (serialize-vnodes ctx kids.node)  '</'  tag.node  '>'
      ==
    %link
      =/  href=@t  (escape-html (link-href ctx target.node))
      (rap 3 ~['<a href="' href '">' (escape-html label.node) '</a>'])
    %link-unsafe
      ?.  (safe-url target.node)  (escape-html label.node)
      =/  away=@t
        ?.  =("https:" (scag 6 (trip target.node)))  ''
        ' target="_blank" rel="noopener"'
      %+  rap  3
      :~  '<a href="'  (escape-html target.node)  '"'  away  '>'
          (escape-html label.node)  '</a>'
      ==
    %image
      =/  asset=(unit static-asset)  (find-asset assets.ctx source.node)
      ?~  asset  ''
      (image-tag url.u.asset (image-size type.u.asset data.u.asset) description.node)
    %image-unsafe
      ?.  (safe-url url.source.node)  (escape-html description.node)
      =/  size=[width=@ud height=@ud]  [width.source.node height.source.node]
      (image-tag url.source.node `size description.node)
  ==
::
++  link-href
  |=  [ctx=page-context target=path]
  ^-  @t
  =/  asset=(unit static-asset)
    ?.  ?=([%static *] target)  ~
    (find-asset assets.ctx target)
  ?^  asset  url.u.asset
  (application-href base.ctx target)
::
::  "" marks a decorative image.
++  image-tag
  |=  [url=@t size=(unit [width=@ud height=@ud]) description=@t]
  ^-  @t
  =/  dimensions=@t
    ?~  size  ''
    %+  rap  3
    :~  ' width="'  (crip (a-co:co width.u.size))
        '" height="'  (crip (a-co:co height.u.size))  '"'
    ==
  %+  rap  3
  ~['<img src="' (escape-html url) '" alt="' (escape-html description) '"' dimensions '>']
::
++  title-children
  |=  kids=(list vnode)
  ^-  (unit @t)
  ?~  kids  ~
  =/  first=(unit @t)  (vnode-title i.kids)
  ?^  first  first
  $(kids t.kids)
::
++  vnode-title
  |=  node=vnode
  ^-  (unit @t)
  ?-  -.node
    ?(%text %link %link-unsafe %image %image-unsafe)  ~
    %node
      ?:  &(=('h1' tag.node) ?=([[%text *] ~] kids.node))
        `words.i.kids.node
      (title-children kids.node)
  ==
::
++  render-document
  |=  [ctx=page-context skin=theme-view stylesheet=@t tree=vnode]
  ^-  static-output
  =/  title=@t  (fall (vnode-title tree) 'Jibb page')
  =/  pieces=(list @t)
    :~  '<!doctype html><html lang="'
        (escape-html lang.skin)
        '"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="script-src \'self\'"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'
        (escape-html title)
        '</title><link rel="stylesheet" href="'
        (escape-html stylesheet)
        '">'
        ?.  &(?=(^ client.ctx) (has-island tree))  ''
        (client-scripts ctx u.client.ctx)
        '</head><body><main>'
        (serialize-vnode ctx tree)
        '</main></body></html>'
    ==
  [title (rap 3 pieces)]
::
::  A page with islands loads the browser library, a module script, which
::  runs once the page is parsed and reads the page's configuration.
++  client-scripts
  |=  [ctx=page-context client=client-context]
  ^-  @t
  =/  assets=(list [@t json])
    %+  turn  assets.ctx
    |=  asset=static-asset
    =/  size=(unit [width=@ud height=@ud])  (image-size type.asset data.asset)
    =/  fields=(list [@t json])
      ?~  size  ~[url+s+url.asset]
      :~  url+s+url.asset
          width+(numb:enjs:format width.u.size)
          height+(numb:enjs:format height.u.size)
      ==
    [(spat at.asset) (pairs:enjs:format fields)]
  =/  config=json
    %-  pairs:enjs:format
    %+  weld
      ^-  (list [@t json])
      :~  base+s+base.ctx
          ship+s+(scot %p ship.client)
          :-  'stores'
          (pairs:enjs:format (turn stores.client |=([m=@t h=@t] [m s+h])))
          assets+(pairs:enjs:format assets)
      ==
    ^-  (list [@t json])
    ?~  section.client  ~
    ~[section+s+u.section.client]
  %+  rap  3
  :~  '<script type="application/x-jibb-client">'
      (script-text (en:json:html config))
      '</script><script type="module" src="'
      (escape-html library.client)
      '"></script>'
  ==
::
::  JSON inside a script element, which ends at the first </script.
++  script-text
  |=  text=@t
  ^-  @t
  =/  bytes=(list @tD)  (trip text)
  =/  out=@t  ''
  |-
  ?~  bytes  out
  $(bytes t.bytes, out (cat 3 out ?:(=('<' i.bytes) '\\u003c' (crip ~[i.bytes]))))
::
++  has-island
  |=  tree=vnode
  ^-  ?
  ?.  ?=(%node -.tree)  |
  ?:  (lien attrs.tree |=(a=vattr =('data-jibb-island' name.a)))  &
  (lien kids.tree has-island)
::
++  renderer-entries
  ^-  (list renderer-entry)
  :~  [%row %render-row]
      [%column %render-column]
      [%wrap %render-wrap]
      [%stack %render-stack]
      [%el %render-el]
      [%para %render-para]
      [%text %render-text]
      [%heading %render-heading]
      [%link %render-link]
      [%link-unsafe %render-link-unsafe]
      [%image %render-image]
      [%image-unsafe %render-image-unsafe]
      [%each %render-each]
      [%button %render-button]
      [%toggle %render-toggle]
      [%field %render-field]
      [%form %render-form]
      [%table-head %render-table-head]
  ==
::
++  link-renderer-entries
  |=  $:  entries=(list renderer-entry)
          root=checked-module:jibb
          cache=jlowering-cache:jibb
      ==
  ^-  (each (list [tag=@tas core=expr:jibb-core]) @t)
  ?~  entries  [%& ~]
  =/  first=(each expr:jibb-core @t)
    (link-entry:jibb-lower name.i.entries root cache)
  ?:  ?=(%| -.first)  first
  =/  rest=(each (list [tag=@tas core=expr:jibb-core]) @t)
    $(entries t.entries)
  ?:  ?=(%| -.rest)  rest
  [%& [[tag.i.entries p.first] p.rest]]
::
++  execute-renderer-entries
  |=  $:  linked=(list [tag=@tas core=expr:jibb-core])
          registry=native-registry:jibb-nock
      ==
  ^-  (each (map @tas noun) @t)
  =/  out=(map @tas noun)  *(map @tas noun)
  |-
  ?~  linked  [%& out]
  =/  gate=(each noun @t)
    (execute-linked 'static renderer' core.i.linked registry)
  ?:  ?=(%| -.gate)  gate
  $(linked t.linked, out (~(put by out) tag.i.linked p.gate))
::
++  static-imports
  |=  modules=jbundle:jibb
  ^-  [surs=(list term) marks=(list term)]
  =|  surs=(list term)
  =|  marks=(list term)
  =/  entries=jbundle:jibb  modules
  |-
  ?~  entries
    [(sort ~(tap in (sy surs)) aor) (sort ~(tap in (sy marks)) aor)]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb at.i.entries source.i.entries)
  ?:  ?=(%| -.parsed)  $(entries t.entries)
  %=  $
    entries  t.entries
    surs  (weld (collect-sur-imports:jibb imports.p.parsed) surs)
    marks  (weld (collect-mark-imports:jibb imports.p.parsed) marks)
  ==
::
::  +module-outline: one module's direct imports, and whether it may be a page
::
::    The host orders its checks by the Jibb imports and reads only the Hoon
::    inputs named. main is set when the module defines main, as every page
::    does, or does not parse; a failed module without main is a library,
::    and is not routed. uses holds each name.face wing whose face is a /-
::    import, so the host can read that mold from the /sur file, declared or
::    not, and a misspelled one gets its definite diagnostic. A module that
::    does not parse has no imports; its check reports the parse error.
++  module-outline
  |=  [at=path source=@t]
  ^-  [jibb=(list path) surs=(list term) marks=(list term) main=? uses=(list [module=term name=term])]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  [~ ~ ~ & ~]
  =/  surs=(list term)  (collect-sur-imports:jibb imports.p.parsed)
  :*  %+  murn  imports.p.parsed
      |=  i=import:jibb
      ?.  ?=(%jibb -.i)  ~
      `(weld path.i `path`~[%jibb])
    ::
      surs
      (collect-mark-imports:jibb imports.p.parsed)
      ?=(^ (program-main-def:jibb defs.p.parsed))
      (sur-uses (layout:jibb at source) surs)
  ==
::
++  sur-uses
  |=  [tokens=(list token:jibb) surs=(list term)]
  ^-  (list [module=term name=term])
  =/  found=(list [module=term name=term])
    %+  murn  tokens
    |=  t=token:jibb
    ?.  ?=([%wing [@ @ ~]] lex.t)  ~
    ?.  (lien surs |=(s=term =(s i.t.p.lex.t)))  ~
    `[i.t.p.lex.t i.p.lex.t]
  (sort ~(tap in (silt found)) aor)
::
::  +check-module: check one module against checked dependencies
::
::    The host checks a desk's modules one at a time, in dependency order.
::    interfaces and artifacts hold each dependency's own result. Their
::    certificates bind only their own closures, so a result from an earlier
::    revision stays usable while its closure is unchanged; a mismatched one
::    is an error, never a silent recheck.
++  check-module
  |=  $:  at=path
          source=@t
          externals=iexternals:jibb
          marks=imark-externals:jibb
          modules=jbundle:jibb
          interfaces=jcache:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
      ==
  ^-  (each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
  =/  public=iprelude:jibb  prepared.prepared
  =/  result=jlowering-result:jibb
    %:  check-jibb-file-for-lowering-with-cache:jibb
      at  source  externals  marks  modules  ~[at]  values.public  molds.public
      interfaces  `iface.public  (weld artifacts cache.prepared)
    ==
  ?:  ?=(%| -.result)  [%| message.p.result]
  [%& [kind.p.result interface.root.p.result root.p.result]]
::
++  check-static
  |=  [request=static-request prepared=iprelude-lowering:jibb]
  ^-  jlowering-result:jibb
  (check-jibb-file-for-lowering-prepared:jibb at.request source.request externals.request marks.request modules.request ~[at.request] ~ prepared)
::
++  build-static-checked
  |=  [request=static-request prepared=iprelude-lowering:jibb page=jlowering-result:jibb]
  ^-  (each static-output @t)
  ?.  (valid-base base.request)  [%| 'static build: base must be an absolute path without a trailing slash']
  ?:  ?=(%| -.page)  [%| message.p.page]
  ?.  =(%static-page kind.p.page)
    [%| (crip "unsupported module kind for static build: {(trip kind.p.page)}")]
  =/  skin=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb theme-at.request theme-source.request externals.request marks.request modules.request ~[theme-at.request] ~ prepared)
  ?:  ?=(%| -.skin)  [%| message.p.skin]
  ?.  =(%library kind.p.skin)  [%| 'static build: theme module must be a library']
  =/  renderer=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb renderer-at.request renderer-source.request externals.request marks.request modules.request ~[renderer-at.request] ~ prepared)
  ?:  ?=(%| -.renderer)  [%| message.p.renderer]
  ?.  =(%library kind.p.renderer)  [%| 'static build: renderer module must be a library']
  =/  artifacts=jlowering-cache:jibb
    (weld cache.p.page (weld cache.p.skin cache.p.renderer))
  =/  css=(each @t @t)  (theme-css root.p.skin artifacts prepared assets.request)
  ?:  ?=(%| -.css)  css
  ::  The host's URL form: a stylesheet is named by a hash of its text.
  =/  stylesheet=@t
    (rap 3 ~[base.request '/~jibb/s/' (scot %uv (end [0 40] (sham p.css))) '.css'])
  %:  render-checked
    base.request  root.p.page  root.p.skin  root.p.renderer  artifacts
    prepared  assets.request  routes.request  stylesheet  ~
  ==
::
::  +theme-look: the desk's stylesheet and language, once its theme is
::  checked; the host gives its error pages both
++  theme-look
  |=  $:  theme=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
          assets=(list static-asset)
      ==
  ^-  (each [css=@t lang=@t] @t)
  ?.  =(%library kind.theme)  [%| 'static build: theme module must be a library']
  =/  skin=(each theme-view @t)  (theme-value theme (weld artifacts cache.prepared))
  ?:  ?=(%| -.skin)  skin
  =/  checked=(each (unit static-asset) @t)  (check-theme p.skin assets)
  ?:  ?=(%| -.checked)  checked
  [%& (theme-stylesheet p.skin p.checked) lang.p.skin]
::
::  +theme-css: the desk's stylesheet, once its theme is checked
++  theme-css
  |=  $:  theme=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
          assets=(list static-asset)
      ==
  ^-  (each @t @t)
  ?.  =(%library kind.theme)  [%| 'static build: theme module must be a library']
  =/  skin=(each theme-view @t)  (theme-value theme (weld artifacts cache.prepared))
  ?:  ?=(%| -.skin)  skin
  =/  checked=(each (unit static-asset) @t)  (check-theme p.skin assets)
  ?:  ?=(%| -.checked)  checked
  [%& (theme-stylesheet p.skin p.checked)]
::
++  theme-value
  |=  [theme=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (each theme-view @t)
  =/  core=(each expr:jibb-core @t)  (link-entry:jibb-lower %theme theme cache)
  ?:  ?=(%| -.core)  core
  =/  registry=(each native-registry:jibb-nock @t)  (native-registry ~[p.core])
  ?:  ?=(%| -.registry)  registry
  =/  value=(each noun @t)  (execute-linked 'static theme' p.core p.registry)
  ?:  ?=(%| -.value)  value
  =/  view=(each theme-view tang)  (mule |.(;;(theme-view p.value)))
  ?:  ?=(%| -.view)  [%| 'static build: the theme value is not a theme']
  [%& p.view]
::
::  +render-checked: a static page's HTML from checked artifacts
::
::    artifacts holds the modules that the page, theme and renderer import;
::    the prelude's come from prepared. Nothing is checked again here, but
::    every link and image must resolve. stylesheet is the URL the host
::    serves the desk's +theme-css at.
::  The theme and renderer a desk's pages share, linked and executed: what
::  turning an element into HTML needs besides the page's own value.
+$  render-source  [file=path source=@t]
+$  render-kit
  [ctx=renderer-context skin=theme-view registry=native-registry:jibb-nock sources=(list render-source)]
::
++  render-sources
  |=  [page=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (list render-source)
  =/  artifacts=(list checked-module:jibb)
    [page (turn cache |=(entry=[at=path artifact=checked-module:jibb] artifact.entry))]
  %+  murn  artifacts
  |=  artifact=checked-module:jibb
  ?~  source.interface.artifact  ~
  `[[at.artifact u.source.interface.artifact]]
::
++  show-render-error
  |=  [sources=(list render-source) failure=render-error]
  ^-  @t
  ?~  origin.failure  message.failure
  =/  matches=(list @t)
    %+  murn  sources
    |=  entry=render-source
    ?:(=(file.u.origin.failure file.entry) `source.entry ~)
  =/  unique=(list @t)  ~
  |-  ^-  @t
  ?^  matches
    =/  next=(list @t)
      ?:  (lien unique |=(source=@t =(source i.matches)))  unique
      (snoc unique i.matches)
    $(matches t.matches, unique next)
  ?.  ?=([* ~] unique)  message.failure
  (show-error:jibb i.unique [file.u.origin.failure line.u.origin.failure col.u.origin.failure (trip message.failure)])
::
++  prepare-kit
  |=  $:  page-core=expr:jibb-core
          page=checked-module:jibb
          theme=checked-module:jibb
          renderer=checked-module:jibb
          cache=jlowering-cache:jibb
      ==
  ^-  (each render-kit @t)
  ?.  =(%library kind.theme)  [%| 'static build: theme module must be a library']
  ?.  =(%library kind.renderer)  [%| 'static build: renderer module must be a library']
  =/  theme-core=(each expr:jibb-core @t)
    (link-entry:jibb-lower %theme theme cache)
  ?:  ?=(%| -.theme-core)  theme-core
  =/  renderer-cores=(each (list [tag=@tas core=expr:jibb-core]) @t)
    (link-renderer-entries renderer-entries renderer cache)
  ?:  ?=(%| -.renderer-cores)  renderer-cores
  =/  attribute-core=(each expr:jibb-core @t)
    (link-entry:jibb-lower %decode-attr renderer cache)
  ?:  ?=(%| -.attribute-core)  attribute-core
  =/  node-expressions=(list expr:jibb-core)
    (turn p.renderer-cores |=(entry=[tag=@tas core=expr:jibb-core] core.entry))
  =/  registry=(each native-registry:jibb-nock @t)
    (native-registry (weld ~[page-core p.theme-core p.attribute-core] node-expressions))
  ?:  ?=(%| -.registry)  registry
  =/  theme-value=(each noun @t)
    (execute-linked 'static theme' p.theme-core p.registry)
  ?:  ?=(%| -.theme-value)  theme-value
  =/  render-gates=(each (map @tas noun) @t)
    (execute-renderer-entries p.renderer-cores p.registry)
  ?:  ?=(%| -.render-gates)  render-gates
  =/  attribute-gate=(each noun @t)
    (execute-linked 'static attribute renderer' p.attribute-core p.registry)
  ?:  ?=(%| -.attribute-gate)  attribute-gate
  :-  %&
  :*  [p.theme-value p.render-gates p.attribute-gate ~ |]
      ;;(theme-view p.theme-value)
      p.registry
      (render-sources page cache)
  ==
::
::  +render-tree: an executed element as a checked HTML document
++  render-tree
  |=  [kit=render-kit context=page-context stylesheet=@t element=noun]
  ^-  (each static-output @t)
  =/  islands=(map @t @t)  ?~(client.context ~ islands.u.client.context)
  =/  tree=(each vnode render-error)
    (render-static-element ctx.kit(islands islands) element)
  ?:  ?=(%| -.tree)  [%| (show-render-error sources.kit p.tree)]
  =/  references=(each ~ render-error)  (check-references context p.tree)
  ?:  ?=(%| -.references)  [%| (show-render-error sources.kit p.references)]
  [%& (render-document context skin.kit stylesheet p.tree)]
::
++  render-checked
  |=  $:  base=@t
          page=checked-module:jibb
          theme=checked-module:jibb
          renderer=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
          assets=(list static-asset)
          routes=(list (list @t))
          stylesheet=@t
          client=(unit client-context)
      ==
  ^-  (each static-output @t)
  ?.  (valid-base base)  [%| 'static build: base must be an absolute path without a trailing slash']
  ?.  =(%static-page kind.page)
    [%| (crip "unsupported module kind for static build: {(trip kind.page)}")]
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  page-core=(each expr:jibb-core @t)
    (link-render-entry:jibb-lower %main page cache)
  ?:  ?=(%| -.page-core)  page-core
  =/  kit=(each render-kit @t)  (prepare-kit p.page-core page theme renderer cache)
  ?:  ?=(%| -.kit)  kit
  =/  page-value=(each noun @t)
    (execute-linked 'static page' p.page-core registry.p.kit)
  ?:  ?=(%| -.page-value)  page-value
  (render-tree p.kit [base assets routes client] stylesheet p.page-value)
::
::  Pages with data.  +prepare-page links and executes a page's load and
::  view at build time, with the renderer and theme; +page-request then
::  answers each request from that, binding load's sample from the URL,
::  running load, and, once the host has scried what an agent's ask names,
::  checking the answer through the ask's receiver and rendering the view.
::  A request's page is never cached.
+$  route-field  [name=term aura=@ta rest=?]
+$  data-page
  $:  load=noun
      view=noun
      kit=render-kit
      context=page-context
      stylesheet=@t
      route=(list @t)
      fields=(list route-field)
  ==
::  A request starts with %load; after a %scry step the host asks again
::  with the agent's answer, or with %reject when the scry failed.  A failed
::  step carries its rendered error page.
+$  page-input
  $%  [%load site=(list @t)]
      [%receive receive=noun mark=@tas fact=noun]
      [%reject message=@t]
  ==
+$  page-step
  $%  [%done title=@t html=@t]
      [%scry agent=@tas path=path receive=noun]
      [%fail status=@ud message=@t html=@t]
  ==
::
++  prepare-page
  |=  $:  base=@t
          page=checked-module:jibb
          theme=checked-module:jibb
          renderer=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
          assets=(list static-asset)
          routes=(list (list @t))
          stylesheet=@t
          client=(unit client-context)
      ==
  ^-  (each data-page @t)
  ?.  (valid-base base)  [%| 'static build: base must be an absolute path without a trailing slash']
  ?.  =(%page kind.page)
    [%| (crip "a page with data was expected, not a module of kind {(trip kind.page)}")]
  =/  fields=(each (list route-field) @t)  (page-route-fields page)
  ?:  ?=(%| -.fields)  fields
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  page-core=(each expr:jibb-core @t)
    (link-render-entry:jibb-lower %main page cache)
  ?:  ?=(%| -.page-core)  page-core
  =/  kit=(each render-kit @t)  (prepare-kit p.page-core page theme renderer cache)
  ?:  ?=(%| -.kit)  kit
  =/  page-value=(each noun @t)
    (execute-linked 'page' p.page-core registry.p.kit)
  ?:  ?=(%| -.page-value)  page-value
  ?.  ?=(^ p.page-value)  [%| 'static build: a page with data is not a load and a view']
  :*  %&
      -.p.page-value
      +.p.page-value
      p.kit
      [base assets routes client]
      stylesheet
      (page-route at.page)
      p.fields
  ==
::
::  +prepare-browser: an island or store module's JavaScript
::
::    The browser runs an island's update, view and subs from its module,
::    compiled from the same linked Core the ship renders its init and
::    first view with, and a page's stores from theirs.  Its evaluate
::    export returns the module's main: an island's program, or a store's
::    init and update.
++  prepare-browser
  |=  $:  module=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
      ==
  ^-  (each @t @t)
  ?.  ?=(?(%island %store) kind.module)
    [%| (crip "an island or store module was expected, not a module of kind {(trip kind.module)}")]
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  core=(each expr:jibb-core @t)  (link-entry:jibb-lower %main module cache)
  ?:  ?=(%| -.core)  core
  =/  made=(each @t tang)  (mule |.((compile:jibb-js p.core)))
  ?:  ?=(%| -.made)
    [%| (crip "static build: {(trip kind.module)} {(spud at.module)} could not be compiled to JavaScript")]
  [%& p.made]
::
::  +run-tests: a test module's test- arms, each one test, run in Nock
::
::    A test passes when its value is %.y and fails when it is %.n or
::    crashes; an arm of another type fails with that type.  The arms run
::    in name order, as Hoon's -test runs them.
+$  test-outcome  [arm=term ok=? message=@t]
++  run-tests
  |=  $:  module=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
      ==
  ^-  (list test-outcome)
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  arms=(list [name=term scheme=ischeme:jibb])
    %+  sort
      %+  skim  values.interface.module
      |=(v=[name=term scheme=ischeme:jibb] =("test-" (scag 5 (trip name.v))))
    |=([a=[name=term *] b=[name=term *]] (aor name.a name.b))
  %+  turn  arms
  |=  [name=term scheme=ischeme:jibb]
  ^-  test-outcome
  =/  typ=itype:jibb  typ.scheme
  =?  typ  ?=(%face -.typ)  body.typ
  ?.  ?=(%flag -.typ)
    [name | (crip "{(trip name)} is a {(show-itype:jibb typ.scheme ~)}, not a ?")]
  =/  core=(each expr:jibb-core @t)  (link-entry:jibb-lower name module cache)
  ?:  ?=(%| -.core)  [name | p.core]
  =/  registry=(each native-registry:jibb-nock @t)  (native-registry ~[p.core])
  ?:  ?=(%| -.registry)  [name | p.registry]
  =/  value=(each noun @t)  (execute-linked name p.core p.registry)
  ?:  ?=(%| -.value)  [name | p.value]
  ?:  =(0 p.value)  [name & '']
  [name | (crip "{(trip name)} is %.n")]
::
::  +test-programs: each test- arm of a test module, as the JavaScript the
::  browser would run and the Nock the ship would, for the Node harness,
::  which runs both and compares them.  The Nock names its natives by
::  placeholders, [[0 0] 0 %jibb-native name], which the harness gives its
::  own implementations, rather than carrying the ship's gates.
++  test-programs
  |=  $:  module=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
      ==
  ^-  (list [arm=term js=@t nock=*])
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  arms=(list [name=term scheme=ischeme:jibb])
    %+  sort
      %+  skim  values.interface.module
      |=  v=[name=term scheme=ischeme:jibb]
      =/  typ=itype:jibb  typ.scheme.v
      =?  typ  ?=(%face -.typ)  body.typ
      &(=("test-" (scag 5 (trip name.v))) ?=(%flag -.typ))
    |=([a=[name=term *] b=[name=term *]] (aor name.a name.b))
  %+  murn  arms
  |=  [name=term *]
  ^-  (unit [arm=term js=@t nock=*])
  =/  core=(each expr:jibb-core @t)  (link-entry:jibb-lower name module cache)
  ?:  ?=(%| -.core)  ~
  =/  js=(each @t tang)  (mule |.((compile:jibb-js p.core)))
  ?:  ?=(%| -.js)  ~
  =/  placeholders=native-registry:jibb-nock
    %-  malt
    %+  turn  (unique-names (native-names p.core))
    |=(n=name:jibb-core [n [[0 0] 0 %jibb-native (print-name:jibb-core n)]])
  `[name p.js (emit:jibb-nock p.core placeholders)]
::
::  A page's route, as its site with its _ and __ segments: /ui/blog/_slug
::  is ['blog' '_slug'], and an index file its folder's.
++  page-route
  |=  at=path
  ^-  (list @t)
  ?.  ?=([%ui * *] at)  ~
  =/  parts=path  (snip `path`t.at)
  ::  =(~ parts), not ?~: the wet +rear cannot take a refined list.
  ?:  =(~ parts)  ~
  =?  parts  =(%index (rear parts))  (snip parts)
  (turn parts |=(part=@ta `@t`part))
::
::  load's sample fields, in their order, from the checked main.  The
::  checker has proved they are exactly the route's parameters.
++  page-route-fields
  |=  page=checked-module:jibb
  ^-  (each (list route-field) @t)
  =/  params=(unit (list route-param:jibb))  (route-params:jibb at.page)
  ?~  params  [%& ~]
  =/  routed=(list route-param:jibb)  u.params
  ?:  =(~ routed)  [%& ~]
  ::  A catch-all alone is the sample itself, whatever its face.
  ?:  ?=([[* %&] ~] routed)  [%& ~[[name.i.routed %ta &]]]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %main values.interface.page)
  ?~  scheme  [%| 'static build: a page with data has no checked main']
  =/  resolved=(unit itype:jibb)  (scheme-display-type:jibb u.scheme)
  ?~  resolved  [%| 'static build: a page with data has no checked main']
  =/  loads=(list itype:jibb)  (record-fields-named:jibb %load u.resolved ~)
  ?.  ?=([* ~] loads)  [%| 'static build: a page with data has no load']
  =/  load=itype:jibb  (route-unface:jibb i.loads)
  ?.  ?=(%fn -.load)  [%| 'static build: a page with data has no load']
  =/  found=(unit (list [name=term typ=itype:jibb]))
    =/  faced=(unit (list [name=term typ=itype:jibb]))  (route-sample-fields:jibb sample.load)
    ?^  faced  faced
    ?.  =(1 (lent routed))  ~
    `~[[name:(snag 0 routed) sample.load]]
  ?~  found  [%| 'static build: load does not take a record of the route parameters']
  :-  %&
  %+  turn  u.found
  |=  f=[name=term typ=itype:jibb]
  =/  rest=?  (lien routed |=(r=route-param:jibb &(=(name.r name.f) rest.r)))
  =/  bare=itype:jibb  (route-unface:jibb typ.f)
  [name.f ?:(?=(%atom -.bare) aura.bare %ta) rest]
::
++  page-request
  |=  [page=data-page input=page-input]
  ^-  page-step
  ?-  -.input
      %load
    =/  sample=(each noun @t)  (route-sample route.page fields.page site.input)
    ?:  ?=(%| -.sample)  (page-fail page 404 p.sample)
    =/  ask=(each noun @t)  (apply-linked 'load' load.page p.sample)
    ?:  ?=(%| -.ask)  (page-fail page 500 'the page crashed in load')
    (page-ask page p.ask)
  ::
      %receive
    =/  received=(each noun @t)
      (apply-linked 'receive' receive.input [mark.input ~ fact.input])
    ?:  ?=(%| -.received)
      (page-fail page 500 'the agent answered with data that does not fit its type, or the page crashed reading it')
    ?.  ?=(^ p.received)  (page-fail page 500 'the page read the agent\'s answer as something other than data')
    (page-render page +.p.received)
  ::
      %reject
    (page-fail page 404 message.input)
  ==
::
++  page-fail
  |=  [page=data-page status=@ud message=@t]
  ^-  page-step
  [%fail status message (error-page lang.skin.kit.page `stylesheet.page status message)]
::
::  An ask: pure data, or an agent's path, scried per request; the host
::  scries a case's separate scry path when it has one.  Stores run in the
::  browser, so a page cannot load from one.
++  page-ask
  |=  [page=data-page ask=noun]
  ^-  page-step
  ?:  ?=([%pure *] ask)  (page-render page +.ask)
  ?:  ?=([%store *] ask)  (page-fail page 500 'a page cannot load from a store, which runs in the browser')
  =/  read=(unit [%agent api=@t case=@tas agent=@tas path=path scry=(unit path) receive=*])
    %-  mole  |.
    ;;([%agent api=@t case=@tas agent=@tas path=path scry=(unit path) receive=*] ask)
  ?~  read  (page-fail page 500 'load returned something other than an ask')
  ?.  ((sane %tas) agent.u.read)  (page-fail page 500 'load returned an ask with a malformed agent name')
  [%scry agent.u.read (fall scry.u.read path.u.read) receive.u.read]
::
++  page-render
  |=  [page=data-page data=noun]
  ^-  page-step
  =/  element=(each noun @t)  (apply-linked 'view' view.page data)
  ?:  ?=(%| -.element)  (page-fail page 500 'the page crashed in its view')
  =/  out=(each static-output @t)
    (render-tree kit.page context.page stylesheet.page p.element)
  ?:  ?=(%| -.out)  (page-fail page 500 p.out)
  [%done title.p.out html.p.out]
::
::  load's sample from a request's site: each _ segment parsed by its
::  field's aura, the __ segment the rest of the path, as knots.  A segment
::  that does not parse is a 404.
++  route-sample
  |=  [route=(list @t) fields=(list route-field) site=(list @t)]
  ^-  (each noun @t)
  =|  bound=(list [name=term value=noun])
  |-
  ?~  route
    ?^  site  [%| 'the address has more segments than the page\'s route']
    (route-record fields bound)
  ?:  =('__' (end [3 2] i.route))
    =/  name=term  (rsh [3 2] i.route)
    ?.  (levy site |=(s=@t ((sane %ta) s)))
      [%| (crip "a segment after {(trip name)} is not a knot")]
    $(route t.route, site ~, bound [[name site] bound])
  ?~  site  [%| 'the address has fewer segments than the page\'s route']
  ?.  =('_' (end [3 1] i.route))  $(route t.route, site t.site)
  =/  name=term  (rsh [3 1] i.route)
  =/  field=(unit route-field)  (find-route-field name fields)
  ?~  field  [%| (crip "the route parameter {(trip name)} has no field in load's sample")]
  =/  value=(unit @)  (route-value aura.u.field i.site)
  ?~  value
    [%| (crip "the segment {(trip i.site)} is not a @{(trip aura.u.field)}, as the route parameter {(trip name)} needs")]
  $(route t.route, site t.site, bound [[name u.value] bound])
::
++  find-route-field
  |=  [name=term fields=(list route-field)]
  ^-  (unit route-field)
  ?~  fields  ~
  ?:  =(name name.i.fields)  `i.fields
  $(fields t.fields)
::
++  route-value
  |=  [aura=@ta seg=@t]
  ^-  (unit @)
  ?:  =(%ta aura)  ?.(((sane %ta) seg) ~ `seg)
  ?:  =(%tas aura)  ?.(((sane %tas) seg) ~ `seg)
  ?:  =(%u aura)  (slaw %ud seg)
  (slaw aura seg)
::
::  The record of the bound values, in load's field order: one field is
::  the value itself, several a cell, and none ~.
++  route-record
  |=  [fields=(list route-field) bound=(list [name=term value=noun])]
  ^-  (each noun @t)
  =/  values=(list noun)
    %+  murn  fields
    |=  f=route-field
    =/  hit=(list [name=term value=noun])  (skim bound |=(b=[name=term value=noun] =(name.b name.f)))
    ?~(hit ~ `value.i.hit)
  ?.  =((lent values) (lent fields))  [%| 'a field of load\'s sample has no route parameter']
  ?:  =(~ values)  [%& ~]
  =/  out=noun  (rear values)
  =/  rest=(list noun)  (flop (snip values))
  |-
  ?~  rest  [%& out]
  $(rest t.rest, out [i.rest out])
::
::  +error-page: Jibb's page for a request that failed, the message shown
::  to the owner as preformatted text
++  error-page
  |=  [lang=@t stylesheet=(unit @t) status=@ud message=@t]
  ^-  @t
  =/  title=@t
    ?:  =(404 status)  'Not found'
    ?:  =(500 status)  'This page failed'
    'Error'
  =/  sheet=@t
    ?~  stylesheet  ''
    (rap 3 ~['<link rel="stylesheet" href="' (escape-html u.stylesheet) '">'])
  %+  rap  3
  :~  '<!doctype html><html lang="'  (escape-html lang)
      '"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="script-src \'self\'"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'
      title  '</title>'  sheet  '</head><body><main class="j-column j-pad-s3 j-gap-s2"><h1>'
      title  '</h1><pre>'  (escape-html message)  '</pre></main></body></html>'
  ==
::
++  build-static
  |=  [request=static-request prepared=iprelude-lowering:jibb]
  ^-  (each static-output @t)
  (build-static-checked request prepared (check-static request prepared))
::
++  render-static
  |=  [request=static-request prepared=iprelude-lowering:jibb]
  ^-  (each static-output @t)
  (build-static request prepared)
--
