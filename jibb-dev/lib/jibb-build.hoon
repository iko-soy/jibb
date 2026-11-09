::  Fixed static-page build facade. Jibb owns element-to-vnode rendering in
::  /lib/jibb/renderer.jibb; this library orchestrates checked Nock execution,
::  authenticates the seal representation, checks the theme and every link
::  and image a page uses, and serializes the page and the theme's stylesheet.
/+  jibb, jibb-core, jibb-lower, jibb-nock
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
+$  vnode
  $~  [%text '']
  $%  [%text words=@t]
      [%node tag=@t attrs=(list vattr) kids=(list vnode)]
      [%link target=path label=@t]
      [%link-unsafe target=@t label=@t]
      [%image source=path description=@t]
      [%image-unsafe source=[url=@t width=@ud height=@ud] description=@t]
  ==
+$  vattr  [name=@t value=@t]
+$  renderer-context  [skin=noun nodes=(map @tas noun) attrs=noun]
+$  renderer-entry  [tag=@tas name=term]
::  What serializing a page needs besides its tree.
+$  page-context  [base=@t assets=(list static-asset) routes=(list (list @t))]
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
++  raw-seal-native
  |=  value=noun
  ['jibb.private.seal.v1' value]
::
++  native-value
  |=  id=name:jibb-core
  ^-  (unit noun)
  ?.  ?=(%own -.id)  ~
  ?+  name.id  ~
    %raw-seal          `raw-seal-native
    %join             `join-text
    %scot             `scot
    %gth              `gth
    %raw-format-tape  `scow
    %raw-crip         `crip
    %scow             `scow
    %crip             `crip
  ==
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
++  render-static-node
  |=  [ctx=renderer-context raw=noun]
  ^-  (each vnode @t)
  ?.  ?=(^ raw)  [%| 'static renderer: malformed node']
  ?.  ?=(@ -.raw)  [%| 'static renderer: malformed node tag']
  =/  tag=@tas  ;;(@tas -.raw)
  =/  found=(unit noun)  (~(get by nodes.ctx) tag)
  ?~  found  [%| 'static renderer: no checked node renderer']
  =/  rendered=(each noun @t)
    (apply-linked 'static renderer' u.found [skin.ctx +.raw])
  ?:  ?=(%| -.rendered)  rendered
  [%& ;;(vnode p.rendered)]
::
++  render-static-attributes
  |=  [ctx=renderer-context raw=noun]
  ^-  (each (list vattr) @t)
  ?~  raw  [%& ~]
  ?.  ?=(^ raw)  [%| 'static renderer: malformed attributes']
  =/  first=(each noun @t)
    (apply-linked 'static attribute renderer' attrs.ctx [skin.ctx -.raw])
  ?:  ?=(%| -.first)  first
  =/  rest=(each (list vattr) @t)  $(raw +.raw)
  ?:  ?=(%| -.rest)  rest
  [%& (weld ;;((list vattr) p.first) p.rest)]
::
++  render-static-children
  |=  [ctx=renderer-context children=noun]
  ^-  (each (list noun) @t)
  ?~  children  [%& ~]
  ?.  ?=(^ children)  [%| 'static renderer: malformed element children']
  =/  first=(each vnode @t)  (render-static-element ctx -.children)
  ?:  ?=(%| -.first)  first
  =/  rest=(each (list noun) @t)  $(children +.children)
  ?:  ?=(%| -.rest)  rest
  [%& [p.first p.rest]]
::
++  render-static-layout
  |=  [ctx=renderer-context tag=@tas raw=noun]
  ^-  (each vnode @t)
  ?.  ?=(^ raw)  [%| 'static renderer: malformed layout payload']
  =/  attrs=(each (list vattr) @t)  (render-static-attributes ctx -.raw)
  ?:  ?=(%| -.attrs)  attrs
  =/  kids=(each (list noun) @t)  (render-static-children ctx +.raw)
  ?:  ?=(%| -.kids)  kids
  (render-static-node ctx [tag p.attrs p.kids])
::
++  render-static-element
  |=  [ctx=renderer-context sealed=noun]
  ^-  (each vnode @t)
  ?.  &(?=(^ sealed) =('jibb.private.seal.v1' -.sealed))
    [%| 'static renderer: element lost its authenticated seal']
  =/  raw=noun  +.sealed
  ?.  ?=(^ raw)  [%| 'static renderer: malformed element']
  ?.  ?=(@ -.raw)  [%| 'static renderer: malformed element tag']
  =/  tag=@tas  ;;(@tas -.raw)
  ?+  tag  [%| (crip "static renderer: unsupported element {(trip tag)}")]
    %island  [%| 'static renderer: islands are not supported yet']
    ?(%text %heading %link %link-unsafe %image %image-unsafe)
      (render-static-node ctx raw)
    ?(%row %column %wrap %stack)  (render-static-layout ctx tag +.raw)
    %para
      =/  kids=(each (list noun) @t)  (render-static-children ctx +.raw)
      ?:  ?=(%| -.kids)  kids
      (render-static-node ctx [%para p.kids])
    %el
      ?.  ?=(^ +.raw)  [%| 'static renderer: malformed el payload']
      =/  attrs=(each (list vattr) @t)  (render-static-attributes ctx +<.raw)
      ?:  ?=(%| -.attrs)  attrs
      =/  kid=(each vnode @t)  (render-static-element ctx +>.raw)
      ?:  ?=(%| -.kid)  kid
      (render-static-node ctx [%el p.attrs p.kid])
  ==
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
  ^-  (each ~ @t)
  ?-  -.node
    %text          [%& ~]
    %node          (check-reference-list ctx kids.node)
    %link          (check-link ctx target.node)
    %link-unsafe   [%& ~]
    %image         (check-image ctx source.node)
    %image-unsafe  [%& ~]
  ==
::
++  check-reference-list
  |=  [ctx=page-context nodes=(list vnode)]
  ^-  (each ~ @t)
  ?~  nodes  [%& ~]
  =/  first=(each ~ @t)  (check-references ctx i.nodes)
  ?:  ?=(%| -.first)  first
  $(nodes t.nodes)
::
++  check-link
  |=  [ctx=page-context target=path]
  ^-  (each ~ @t)
  ?:  ?=([%static *] target)
    ?^  (find-asset assets.ctx target)  [%& ~]
    [%| (crip "missing static asset: {(spud target)}")]
  ?:  (lien routes.ctx |=(r=(list @t) (route-matches r target)))  [%& ~]
  [%| (crip "link to a missing page: %{(spud target)}")]
::
++  check-image
  |=  [ctx=page-context source=path]
  ^-  (each ~ @t)
  ?.  ?=([%static *] source)
    [%| (crip "an image's application path must name a static file: %{(spud source)}")]
  =/  asset=(unit static-asset)  (find-asset assets.ctx source)
  ?~  asset  [%| (crip "missing static asset: {(spud source)}")]
  ?~  (image-size type.u.asset data.u.asset)
    [%| (crip "static image has no size this build can read: {(spud source)}")]
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
        '"></head><body><main>'
        (serialize-vnode ctx tree)
        '</main></body></html>'
    ==
  [title (rap 3 pieces)]
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
    prepared  assets.request  routes.request  stylesheet
  ==
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
      ==
  ^-  (each static-output @t)
  ?.  (valid-base base)  [%| 'static build: base must be an absolute path without a trailing slash']
  ?.  =(%static-page kind.page)
    [%| (crip "unsupported module kind for static build: {(trip kind.page)}")]
  ?.  =(%library kind.theme)  [%| 'static build: theme module must be a library']
  ?.  =(%library kind.renderer)  [%| 'static build: renderer module must be a library']
  =/  cache=jlowering-cache:jibb  (weld artifacts cache.prepared)
  =/  page-core=(each expr:jibb-core @t)
    (link-entry:jibb-lower %main page cache)
  ?:  ?=(%| -.page-core)  page-core
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
    (native-registry (weld ~[p.page-core p.theme-core p.attribute-core] node-expressions))
  ?:  ?=(%| -.registry)  registry
  =/  theme-value=(each noun @t)
    (execute-linked 'static theme' p.theme-core p.registry)
  ?:  ?=(%| -.theme-value)  theme-value
  =/  skin-view=theme-view  ;;(theme-view p.theme-value)
  =/  page-value=(each noun @t)
    (execute-linked 'static page' p.page-core p.registry)
  ?:  ?=(%| -.page-value)  page-value
  =/  render-gates=(each (map @tas noun) @t)
    (execute-renderer-entries p.renderer-cores p.registry)
  ?:  ?=(%| -.render-gates)  render-gates
  =/  attribute-gate=(each noun @t)
    (execute-linked 'static attribute renderer' p.attribute-core p.registry)
  ?:  ?=(%| -.attribute-gate)  attribute-gate
  =/  ctx=renderer-context  [p.theme-value p.render-gates p.attribute-gate]
  =/  tree=(each vnode @t)
    (render-static-element ctx p.page-value)
  ?:  ?=(%| -.tree)  tree
  =/  context=page-context  [base assets routes]
  =/  references=(each ~ @t)  (check-references context p.tree)
  ?:  ?=(%| -.references)  references
  [%& (render-document context skin-view stylesheet p.tree)]
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
