::  Fixed static-page build facade. Jibb owns element-to-vnode rendering in
::  /lib/jibb/renderer.jibb; this library orchestrates checked Nock execution,
::  authenticates the seal representation, and serializes the resulting tree.
/+  jibb, jibb-core, jibb-lower, jibb-nock
|%
+$  static-request
  $:  at=path
      source=@t
      base=@t
      renderer-at=path
      renderer-source=@t
      theme-at=path
      theme-source=@t
      modules=jbundle:jibb
      assets=(list path)
      externals=iexternals:jibb
      marks=imark-externals:jibb
  ==
+$  static-output  [title=@t html=@t]
+$  theme-view
  $:  space=[s1=@t s2=@t s3=@t]
      tones=[normal=@t background=@t accent=@t danger=@t muted=@t]
      wide=@t
      lang=@t
      zone=@t
      font=(unit path)
      dark=*
  ==
+$  vnode
  $~  [%text '']
  $%  [%text words=@t]
      [%node tag=@t attrs=(list vattr) kids=(list vnode)]
      [%link target=path label=@t]
  ==
+$  vattr  [name=@t value=@t]
+$  renderer-context  [skin=noun nodes=(map @tas noun) attrs=noun]
+$  renderer-entry  [tag=@tas name=term]
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
    ?(%text %heading %link %link-unsafe)  (render-static-node ctx raw)
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
++  check-theme-assets
  |=  [skin=theme-view assets=(list path)]
  ^-  (each ~ @t)
  ?~  font.skin  [%& ~]
  ?:  (lien assets |=(at=path =(at u.font.skin)))  [%& ~]
  [%| (crip "missing static asset: {(spud u.font.skin)}")]
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
++  serialize-attributes
  |=  [base=@t attrs=(list vattr)]
  ^-  @t
  =/  ordinary=(list @t)  ~
  =/  styles=(list @t)  ~
  |-
  ?~  attrs
    =/  all=(list @t)  ordinary
    =?  all  ?=(^ styles)
      (weld all ~[(rap 3 ~['style="' (escape-html (join-text '; ' styles)) '"'])])
    ?~  all  ''
    (cat 3 ' ' (join-text ' ' all))
  =/  style-prefix=@t  (end [3 6] name.i.attrs)
  ?:  =('style:' style-prefix)
    =/  style-name=@t  (rsh [3 6] name.i.attrs)
    =/  one=@t  (rap 3 ~[style-name ': ' value.i.attrs])
    $(attrs t.attrs, styles (weld styles ~[one]))
  =/  one=@t  (rap 3 ~[name.i.attrs '="' (escape-html value.i.attrs) '"'])
  $(attrs t.attrs, ordinary (weld ordinary ~[one]))
::
++  serialize-vnodes
  |=  [base=@t nodes=(list vnode)]
  ^-  @t
  ?~  nodes  ''
  (cat 3 (serialize-vnode base i.nodes) $(nodes t.nodes))
::
++  serialize-vnode
  |=  [base=@t node=vnode]
  ^-  @t
  ?-  -.node
    %text  (escape-html words.node)
    %node
      (rap 3 ~['<' tag.node (serialize-attributes base attrs.node) '>' (serialize-vnodes base kids.node) '</' tag.node '>'])
    %link
      =/  href=@t  (escape-html (application-href base target.node))
      (rap 3 ~['<a href="' href '">' (escape-html label.node) '</a>'])
  ==
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
    ?(%text %link)  ~
    %node
      ?:  &(=('h1' tag.node) ?=([[%text *] ~] kids.node))
        `words.i.kids.node
      (title-children kids.node)
  ==
::
++  render-document
  |=  [base=@t skin=theme-view tree=vnode]
  ^-  static-output
  =/  title=@t  (fall (vnode-title tree) 'Jibb page')
  =/  body-style=@t
    (rap 3 ~['color: ' normal.tones.skin '; background: ' background.tones.skin])
  =/  pieces=(list @t)
    :~  '<!doctype html><html lang="'
        (escape-html lang.skin)
        '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'
        (escape-html title)
        '</title></head><body style="'
        (escape-html body-style)
        '"><main>'
        (serialize-vnode base tree)
        '</main></body></html>'
    ==
  =/  html=@t  (rap 3 pieces)
  [title html]
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
::    and is not routed. A module that does not parse has no imports; its
::    check reports the parse error.
++  module-outline
  |=  [at=path source=@t]
  ^-  [jibb=(list path) surs=(list term) marks=(list term) main=?]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  [~ ~ ~ &]
  :^    %+  murn  imports.p.parsed
        |=  i=import:jibb
        ?.  ?=(%jibb -.i)  ~
        `(weld path.i `path`~[%jibb])
      (collect-sur-imports:jibb imports.p.parsed)
    (collect-mark-imports:jibb imports.p.parsed)
  ?=(^ (program-main-def:jibb defs.p.parsed))
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
  (render-checked base.request root.p.page root.p.skin root.p.renderer artifacts prepared assets.request)
::
::  +render-checked: a static page's HTML from checked artifacts
::
::    artifacts holds the modules that the page, theme and renderer import;
::    the prelude's come from prepared. Nothing is checked again here.
++  render-checked
  |=  $:  base=@t
          page=checked-module:jibb
          theme=checked-module:jibb
          renderer=checked-module:jibb
          artifacts=jlowering-cache:jibb
          prepared=iprelude-lowering:jibb
          assets=(list path)
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
  =/  assets-ok=(each ~ @t)  (check-theme-assets skin-view assets)
  ?:  ?=(%| -.assets-ok)  assets-ok
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
  [%& (render-document base skin-view p.tree)]
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
