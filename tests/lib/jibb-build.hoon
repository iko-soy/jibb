/+  jibb, jibb-build, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  renderer-source  %jibb  /lib/jibb/renderer/jibb
/*  about-source  %txt  /my-app/ui/about/jibb
/*  theme-source  %txt  /my-app/ui/theme/jibb
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  prepared
  ^-  (unit iprelude-lowering:jibb)
  (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
++  request
  |=  $:  at=path
          source=@t
          skin=@t
          base=@t
          assets=(list static-asset:jibb-build)
          routes=(list (list @t))
      ==
  ^-  static-request:jibb-build
  :*  at
      source
      base
      /lib/jibb/renderer/jibb
      renderer-source
      /ui/theme/jibb
      skin
      ~
      assets
      ~
      ~
      routes
  ==
++  expect-html
  |=  [html=@t wanted=(list @t)]
  ^-  tang
  ?~  wanted  ~
  ?.  (contains (trip html) (trip i.wanted))
    ~[leaf+(trip (cat 3 'static HTML is missing: ' i.wanted)) leaf+(trip html)]
  $(wanted t.wanted)
::  A file's bytes from big-endian numbers and literal bytes, in order.
++  bytes
  |=  parts=(list [size=@ud value=@])
  ^-  octs
  =/  total=@ud  (roll (turn parts |=(p=[size=@ud value=@] size.p)) add)
  [total (can 3 (turn parts |=(p=[size=@ud value=@] [size.p value.p])))]
++  be
  |=  [size=@ud value=@ud]
  ^-  [@ud @]
  [size (rev 3 size value)]
++  png
  |=  [width=@ud height=@ud]
  ^-  octs
  (bytes ~[[8 0xa1a.0a0d.474e.5089] (be 4 13) [4 'IHDR'] (be 4 width) (be 4 height)])
++  asset
  |=  [at=path type=@t data=octs]
  ^-  static-asset:jibb-build
  [at (crip "/apps/my-app/static/0v1.abcde{(spud (slag 1 at))}") type data]
++  view
  ^-  theme-view:jibb-build
  :*  ['4px' '8px' '16px']
      ['#222' '#fff' '#17734f' '#b3261e' '#5f5f5f']
      '60rem'
      'en'
      'UTC'
      ~
      ~
  ==
++  test-real-about-document
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  built=(each static-output:jibb-build @t)
    %+  build-static:jibb-build
      (request /ui/about/jibb (text about-source) default-theme-source:jibb-build '/apps/my-app' ~ ~[~['blog']])
    u.prep
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  ?.  =('About this ship' title.p.built)  ~[leaf+"document title did not come from the first h1"]
  =/  html=@t  html.p.built
  =/  missing=tang
    %+  expect-html  html
    :~  '<!doctype html>'  '<title>About this ship</title>'
        '<meta http-equiv="Content-Security-Policy" content="script-src \'self\'">'
        '<link rel="stylesheet" href="/apps/my-app/~jibb/s/0v'
        '<div class="j-column j-pad-s3 j-gap-s2" style="flex: 1 1 0%; min-width: 0">'
        '<h1'  'About this ship'  'Hosted on Urbit. This page ships no JavaScript.'
        '<div class="j-el j-tone-accent"><a href="/apps/my-app/blog">'
    ==
  ?^  missing  missing
  ?:  (contains (trip html) "<script")  ~[leaf+"static page shipped JavaScript"]
  ?:  (contains (trip html) "color:")  ~[leaf+"a tone was drawn inline instead of through its class"]
  ~
++  test-escaping-and-unsafe-link
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  source=@t
    %-  text
    :~  '++ main'
        '  column ~ ~['
        '    heading 1 "A <B> & C"'
        '    para ~[(text "Fish & <ships>")]'
        '    link-unsafe "/outside?a=1&b=<two>" "Away & elsewhere"'
        '    link-unsafe "https://urbit.org" "Urbit"'
        '    link-unsafe "javascript:alert(1)" "Run me"'
        '    link-unsafe "//other.example" "Elsewhere"'
        '    link-unsafe "/\\09/tabbed.example" "Tabbed"'
        '    el ~[width+[%chars 20]] (text "Narrow")'
    ==
  =/  built=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/escape/jibb source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  missing=tang
    %+  expect-html  html.p.built
    :~  '<title>A &lt;B&gt; &amp; C</title>'  'Fish &amp; &lt;ships&gt;'
        'href="/outside?a=1&amp;b=&lt;two&gt;"'  'Away &amp; elsewhere'
        '<a href="https://urbit.org" target="_blank" rel="noopener">Urbit</a>'
        'Run me'  'Elsewhere'  'Tabbed'
        ::  A width's number is printed as digits, not as a knot.
        '<div class="j-el" style="flex: 0 0 20ch">Narrow</div>'
    ==
  ?^  missing  missing
  ?:  (contains (trip html.p.built) "javascript:")  ~[leaf+"a javascript: URL became a link"]
  ?:  (contains (trip html.p.built) "//other.example")  ~[leaf+"a protocol-relative URL became a link"]
  ?:  (contains (trip html.p.built) "tabbed.example")
    ~[leaf+"a URL a browser reads as protocol-relative, once it drops the tab, became a link"]
  ~
++  test-static-import-dependencies
  ^-  tang
  =/  modules=jbundle:jibb
    :~  [/ui/api/todo (text ~['/- todo' '/%  %todo-action' '++ item item.todo'])]
        [/ui/bad 'not valid Jibb']
    ==
  =/  needed=[surs=(list term) marks=(list term)]
    (static-imports:jibb-build modules)
  ?.  =(surs.needed ~[%todo])  ~[leaf+"static imports did not select exactly the declared /sur dependency"]
  ?.  =(marks.needed ~[%todo-action])  ~[leaf+"static imports did not select exactly the declared mark dependency"]
  ~
::  The molds a module may use from each /sur face, misspelled ones
::  included, so the host can read each one.
++  test-outline-sur-uses
  ^-  tang
  =/  at=path  /ui/list/jibb
  =/  source=@t
    %-  text
    :~  '/- todo'
        '++ first |= x=item.todo x'
        '++ second |= y=itme.todo y'
        '++ third |= z=(list item.todo) z'
    ==
  =/  outline=[jibb=(list path) surs=(list term) marks=(list term) main=? uses=(list [module=term name=term])]
    (module-outline:jibb-build at source)
  ?.  =(surs.outline ~[%todo])  ~[leaf+"the outline lost its /sur import"]
  ?.  =(main.outline |)  ~[leaf+"a library was outlined as a possible page"]
  ?.  =(uses.outline ~[[%todo %item] [%todo %itme]])
    ~[leaf+"the outline did not name each /sur mold the module uses, once"]
  ~
::  The host checks one module at a time against its dependencies' own
::  results, then renders from the artifacts; the page must match the
::  one-shot build of the same sources.
++  test-stepwise-build-matches-one-shot
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  note-at=path  /ui/parts/note/jibb
  =/  note=@t  (text ~['++ greeting ^- @t "First note"'])
  =/  page-at=path  /ui/notes/jibb
  =/  page=@t
    %-  text
    :~  '/= note /ui/parts/note'
        '++ main'
        '  column ~ ~['
        '    heading 1 "Notes"'
        '    para ~[(text greeting.note)]'
    ==
  =/  modules=jbundle:jibb  ~[[page-at page] [note-at note]]
  ?.  =([~[note-at] ~ ~ & ~] (module-outline:jibb-build page-at page))
    ~[leaf+"the page's outline did not name exactly its Jibb import and main"]
  ?.  =([~ ~ ~ | ~] (module-outline:jibb-build note-at note))
    ~[leaf+"a library without main was outlined as a possible page"]
  ?.  =([~ ~ ~ & ~] (module-outline:jibb-build page-at 'not valid Jibb'))
    ~[leaf+"an unparsed module named imports or was not kept as a possible page"]
  =/  lib=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build note-at note ~ ~ ~[[note-at note]] ~ ~ u.prep)
  ?:  ?=(%| -.lib)  ~[leaf+(trip p.lib)]
  ?.  =(%library kind.p.lib)  ~[leaf+"the note module was not a library"]
  =/  checked=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    %:  check-module:jibb-build
      page-at  page  ~  ~  modules
      ~[[note-at interface.p.lib]]
      ~[[note-at artifact.p.lib]]
      u.prep
    ==
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  ?.  =(%static-page kind.p.checked)  ~[leaf+"the notes page was not a static page"]
  =/  theme-at=path  /ui/theme/jibb
  =/  theme=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build theme-at default-theme-source:jibb-build ~ ~ ~[[theme-at default-theme-source:jibb-build]] ~ ~ u.prep)
  ?:  ?=(%| -.theme)  ~[leaf+(trip p.theme)]
  =/  renderer-at=path  /lib/jibb/renderer/jibb
  =/  renderer=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build renderer-at renderer-source ~ ~ ~[[renderer-at renderer-source]] ~ ~ u.prep)
  ?:  ?=(%| -.renderer)  ~[leaf+(trip p.renderer)]
  =/  css=(each @t @t)  (theme-css:jibb-build artifact.p.theme ~ u.prep ~)
  ?:  ?=(%| -.css)  ~[leaf+(trip p.css)]
  =/  stylesheet=@t
    (rap 3 ~['/apps/my-app/~jibb/s/' (scot %uv (end [0 40] (sham p.css))) '.css'])
  =/  stepwise=(each static-output:jibb-build @t)
    %:  render-checked:jibb-build
      '/apps/my-app'
      artifact.p.checked
      artifact.p.theme
      artifact.p.renderer
      ~[[note-at artifact.p.lib]]
      u.prep
      ~
      ~
      stylesheet
      ~
    ==
  ?:  ?=(%| -.stepwise)  ~[leaf+(trip p.stepwise)]
  =/  one-shot=(each static-output:jibb-build @t)
    %+  build-static:jibb-build
      :*  page-at  page  '/apps/my-app'
          renderer-at  renderer-source
          theme-at  default-theme-source:jibb-build
          modules  ~  ~  ~  ~
      ==
    u.prep
  ?.  =(one-shot stepwise)  ~[leaf+"stepwise and one-shot builds differ"]
  (expect-html html.p.stepwise ~['<title>Notes</title>' 'First note'])
::  Links name pages or static files; images name static files whose size
::  the build reads.  Every other target is a definite error.
++  test-links-images-and-routes
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  dot=static-asset:jibb-build  (asset /static/img/[~.dot.png] 'image/png' (png 640 480))
  =/  doc=static-asset:jibb-build  (asset /static/[~.doc.txt] 'text/plain' [3 'doc'])
  =/  odd=static-asset:jibb-build  (asset /static/img/[~.odd.png] 'image/png' [3 'odd'])
  =/  assets=(list static-asset:jibb-build)  ~[dot doc odd]
  =/  routes=(list (list @t))  ~[~ ~['blog' '_slug'] ~['settings' '__rest']]
  =/  build
    |=  lines=wain
    ^-  (each static-output:jibb-build @t)
    %+  build-static:jibb-build
      (request /ui/links/jibb (text lines) default-theme-source:jibb-build '/apps/my-app' assets routes)
    u.prep
  =/  good=(each static-output:jibb-build @t)
    %-  build
    :~  '++ main'
        '  column ~ ~['
        '    image %/static/img/dot.png "A dot"'
        '    image %/static/img/dot.png ""'
        '    link %/static/doc.txt "Read the doc"'
        '    link %/blog/first-post "First post"'
        '    link %/settings/a/b "Settings"'
        '    link %/ "Home"'
        '    image-unsafe [url="https://urbit.org/a.png" width=10 height=20] "Away"'
        '    image-unsafe [url="javascript:x" width=10 height=20] "Not an image"'
    ==
  ?:  ?=(%| -.good)  ~[leaf+(trip p.good)]
  =/  missing=tang
    %+  expect-html  html.p.good
    :~  '<img src="/apps/my-app/static/0v1.abcde/img/dot.png" alt="A dot" width="640" height="480">'
        '<img src="/apps/my-app/static/0v1.abcde/img/dot.png" alt="" width="640" height="480">'
        '<a href="/apps/my-app/static/0v1.abcde/doc.txt">Read the doc</a>'
        '<a href="/apps/my-app/blog/first-post">First post</a>'
        '<a href="/apps/my-app/settings/a/b">Settings</a>'
        '<a href="/apps/my-app">Home</a>'
        '<img src="https://urbit.org/a.png" alt="Away" width="10" height="20">'
        'Not an image'
    ==
  ?^  missing  missing
  ?:  (contains (trip html.p.good) "javascript:")  ~[leaf+"an unsafe image URL was kept"]
  =/  expect-error
    |=  [lines=wain line=@ud col=@ud wanted=@t]
    ^-  tang
    =/  made=(each static-output:jibb-build @t)  (build lines)
    ?:  ?=(%& -.made)  ~[leaf+(trip (cat 3 'built despite: ' wanted))]
    =/  located=@t  (show-error:jibb (text lines) [/ui/links/jibb line col (trip wanted)])
    ?:  =(located p.made)  ~
    ~[leaf+(trip (rap 3 ~['wanted\0a' located '\0agot\0a' p.made]))]
  =/  inspected-source=@t  '++ main (link %/nowhere "Gone")'
  =/  inspected=jlowering-result:jibb
    (check-static:jibb-build (request /ui/links/jibb inspected-source default-theme-source:jibb-build '/apps/my-app' assets routes) u.prep)
  ?:  ?=(%| -.inspected)  ~[leaf+(trip message.p.inspected)]
  =/  ordinary=(each expr:jibb-core @t)
    (link-entry:jibb-lower %main root.p.inspected cache.p.inspected)
  ?:  ?=(%| -.ordinary)  ~[leaf+(trip p.ordinary)]
  =/  render=(each expr:jibb-core @t)
    (link-render-entry:jibb-lower %main root.p.inspected cache.p.inspected)
  ?:  ?=(%| -.render)  ~[leaf+(trip p.render)]
  =/  ordinary-natives=(list name:jibb-core)  (native-names:jibb-build p.ordinary)
  =/  render-natives=(list name:jibb-core)  (native-names:jibb-build p.render)
  ?:  (lien ordinary-natives |=(n=name:jibb-core =(n [%own %render-origin])))
    ~[leaf+"ordinary lowering emitted the host-only origin native"]
  ?.  (lien render-natives |=(n=name:jibb-core =(n [%own %render-origin])))
    ~[leaf+(trip (print-expr:jibb-core p.render))]
  =/  page-error=tang
    (expect-error ~['++ main (link %/nowhere "Gone")'] 1 10 'link to a missing page: %/nowhere')
  ?^  page-error  page-error
  =/  deeper-error=tang
    (expect-error ~['++ main (link %/blog/a/b "Too deep")'] 1 10 'link to a missing page: %/blog/a/b')
  ?^  deeper-error  deeper-error
  =/  asset-error=tang
    (expect-error ~['++ main (image %/static/img/gone.png "Gone")'] 1 10 'missing static asset: /static/img/gone.png')
  ?^  asset-error  asset-error
  =/  place-error=tang
    %+  expect-error  ~['++ main (image %/blog/x "Not a file")']
    [1 10 'an image\'s application path must name a static file: %/blog/x']
  ?^  place-error  place-error
  %+  expect-error  ~['++ main (image %/static/img/odd.png "Odd")']
  [1 10 'static image has no size this build can read: /static/img/odd.png']
++  test-render-diagnostic-ownership
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  direct=@t
    %-  text
    :~  '++ main'
        '  column ~ ~['
        '    text "sibling"'
        '    para ~[(link %/nowhere "Nested")]'
    ==
  =/  made=(each static-output:jibb-build @t)
    %+  build-static:jibb-build
      (request /ui/direct/jibb direct default-theme-source:jibb-build '/apps/my-app' ~ ~)
    u.prep
  ?:  ?=(%& -.made)  ~[leaf+"a nested bad link rendered"]
  =/  wanted=@t
    (show-error:jibb direct [/ui/direct/jibb 4 13 "link to a missing page: %/nowhere"])
  ?.  =(wanted p.made)  ~[leaf+(trip p.made)]
  =/  library=@t
    %-  text
    :~  '++ exported ^- (element !!)'
        '  para ~[(link %/nowhere "Imported")]'
        '++ around |= kid=(element !!)'
        '  column ~ ~[kid (text "outer")]'
    ==
  =/  page=@t
    %-  text
    :~  '/= assets /ui/parts/assets'
        '++ main (around.assets exported.assets)'
    ==
  =/  modules=jbundle:jibb
    ~[[/ui/direct/jibb page] [/ui/parts/assets/jibb library]]
  =/  imported-request=static-request:jibb-build
    (request /ui/direct/jibb page default-theme-source:jibb-build '/apps/my-app' ~ ~)
  =/  imported=(each static-output:jibb-build @t)
    (build-static:jibb-build imported-request(modules modules) u.prep)
  ?:  ?=(%& -.imported)  ~[leaf+"an imported bad link rendered"]
  =/  imported-wanted=@t
    (show-error:jibb library [/ui/parts/assets/jibb 2 11 "link to a missing page: %/nowhere"])
  ?.  =(imported-wanted p.imported)  ~[leaf+(trip p.imported)]
  =/  data-source=@t
    %-  text
    :~  '++ main (page load view)'
        '++ load |= ~ (pure 0)'
        '++ view |= n=@ud'
        '  para ~[(image %/static/img/gone.png "Data")]'
    ==
  =/  data=(each data-page:jibb-build @t)
    %+  data-page-for
      (request /ui/data/jibb data-source default-theme-source:jibb-build '/apps/my-app' ~ ~)
    u.prep
  ?:  ?=(%| -.data)  ~[leaf+(trip p.data)]
  =/  failed=page-step:jibb-build  (page-request:jibb-build p.data [%load ~['data']])
  ?.  ?=(%fail -.failed)  ~[leaf+"a data page with a missing image rendered"]
  =/  data-wanted=@t
    (show-error:jibb data-source [/ui/data/jibb 4 11 "missing static asset: /static/img/gone.png"])
  ?.  =(data-wanted message.failed)  ~[leaf+(trip message.failed)]
  ?.  (contains (trip html.failed) (trip (escape-html:jibb-build data-wanted)))
    ~[leaf+"the data-page HTML lost its diagnostic"]
  ~
::
++  test-render-error-fallbacks-and-seal
  ^-  tang
  =/  origin=render-origin:jibb-build  [/ui/malformed/jibb 4 7]
  =/  wrapped=noun
    (render-origin-native:jibb-build file.origin line.origin col.origin (raw-seal-native:jibb-build 42))
  =/  again=noun  (render-origin-native:jibb-build /ui/outer/jibb 9 9 wrapped)
  ?.  =(wrapped again)  ~[leaf+"an outer call replaced an element's origin"]
  =/  malformed=(each vnode:jibb-build render-error:jibb-build)
    (render-static-element:jibb-build [~ ~ ~ ~ |] wrapped)
  ?:  ?=(%& -.malformed)  ~[leaf+"a malformed sealed element rendered"]
  ?.  =('static renderer: malformed element' message.p.malformed)
    ~[leaf+(trip message.p.malformed)]
  ?.  =(`origin origin.p.malformed)  ~[leaf+"a malformed element lost its origin"]
  =/  source=@t  (text ~['one' 'two' 'three' 'bad'])
  =/  shown=@t  (show-render-error:jibb-build ~[[file.origin source]] p.malformed)
  =/  wanted=@t
    (show-error:jibb source [file.origin line.origin col.origin "static renderer: malformed element"])
  ?.  =(wanted shown)  ~[leaf+(trip shown)]
  =/  unsupported=(each vnode:jibb-build render-error:jibb-build)
    (render-static-element:jibb-build [~ ~ ~ ~ |] (render-origin-native:jibb-build file.origin 4 7 (raw-seal-native:jibb-build [%unknown ~])))
  ?:  ?=(%& -.unsupported)  ~[leaf+"an unsupported element rendered"]
  ?.  =('static renderer: unsupported element unknown' message.p.unsupported)
    ~[leaf+(trip message.p.unsupported)]
  =/  plain=(each vnode:jibb-build render-error:jibb-build)
    (render-static-element:jibb-build [~ ~ ~ ~ |] (raw-seal-native:jibb-build 42))
  ?:  ?=(%& -.plain)  ~[leaf+"an unlocated malformed element rendered"]
  ?.  =(~ origin.p.plain)  ~[leaf+"ordinary raw sealing manufactured provenance"]
  =/  fallback=@t  (show-render-error:jibb-build ~[[file.origin source]] p.plain)
  ?.  =('static renderer: malformed element' fallback)  ~[leaf+(trip fallback)]
  =/  ambiguous=@t
    (show-render-error:jibb-build ~[[file.origin source] [file.origin 'different']] p.malformed)
  ?.  =('static renderer: malformed element' ambiguous)  ~[leaf+(trip ambiguous)]
  =/  annotated=noun  (annotate-rendered-vnode:jibb-build `origin [%link %/nowhere 'x' ~])
  ?.  ?=(%link -.annotated)  ~[leaf+"a checked link was not annotated"]
  ?.  =(`origin +>+.annotated)  ~[leaf+"a checked link kept renderer-supplied provenance"]
  =/  overwritten=noun  (annotate-rendered-vnode:jibb-build ~ annotated)
  ?.  ?=(%link -.overwritten)  ~[leaf+"a checked link changed shape"]
  ?.  =(~ +>+.overwritten)  ~[leaf+"a renderer could erase trusted provenance"]
  =/  crashed=(each vnode:jibb-build render-error:jibb-build)
    (render-island:jibb-build [~ ~ ~ (malt ~[['module' '0vtest']]) |] `origin [['module' [0 0 0 0]] ~])
  ?:  ?=(%| -.crashed)  ~[leaf+(trip message.p.crashed)]
  =/  expected=vnode:jibb-build
    [%node 'div' ~[['data-jibb-island' '0vtest'] ['data-jibb-crashed' '']] ~[crash-notice:jibb-build]]
  ?.  =(expected p.crashed)  ~[leaf+"an island renderer failure lost its crash notice"]
  ?.  =(['jibb.private.seal.v1' 42] (raw-seal-native:jibb-build 42))
    ~[leaf+"the public raw seal representation changed"]
  ~
::
++  test-theme-checks-and-stylesheet
  ^-  tang
  ::  A face: view(...) would edit the test core, since view is an arm.
  =/  skin=theme-view:jibb-build  view
  =/  good=(each (unit static-asset:jibb-build) @t)  (check-theme:jibb-build skin ~)
  ?.  =([%& ~] good)  ~[leaf+"the default theme did not pass its checks"]
  =/  pale=theme-view:jibb-build  skin(muted.tones '#999')
  ?.  =(%| -:(check-theme:jibb-build pale ~))  ~[leaf+"a low-contrast tone passed"]
  =/  pale-message=@t
    'theme: tones.muted #999 has contrast 2.84:1 with tones.background #fff; text needs 4.5:1'
  ?.  =([%| pale-message] (check-theme:jibb-build pale ~))
    ~[leaf+(trip ;;(@t +:(check-theme:jibb-build pale ~)))]
  =/  night=theme-view:jibb-build  skin(dark `['#eee' '#111' '#4c9' '#f28b82' '#333'])
  =/  dark-message=@t
    'theme: dark.tones.muted #333 has contrast 1.49:1 with dark.tones.background #111; text needs 4.5:1'
  ?.  =([%| dark-message] (check-theme:jibb-build night ~))
    ~[leaf+(trip ;;(@t +:(check-theme:jibb-build night ~)))]
  =/  named=theme-view:jibb-build  skin(accent.tones 'green')
  ?.  =([%| 'theme: tones.accent is green, not a hex colour such as #17734f'] (check-theme:jibb-build named ~))
    ~[leaf+"a named colour was accepted"]
  =/  wide=theme-view:jibb-build  skin(wide 'wide')
  ?.  =([%| 'theme: wide is wide, not a CSS length such as 16px or 1.5rem'] (check-theme:jibb-build wide ~))
    ~[leaf+"a word was accepted as a length"]
  =/  percent=theme-view:jibb-build  skin(wide '50%')
  =/  percent-message=@t
    'theme: wide is 50%, but a media query needs a length such as 60rem, not a percentage'
  ?.  =([%| percent-message] (check-theme:jibb-build percent ~))
    ~[leaf+"a percentage was accepted as the layout's breakpoint"]
  ?.  =([%& ~] (check-theme:jibb-build skin(s1.space '.25rem', s3.space '5%') ~))
    ~[leaf+"a fractional or percentage space was rejected"]
  =/  lang=theme-view:jibb-build  skin(lang 'en"><script>')
  ?.  =(%| -:(check-theme:jibb-build lang ~))  ~[leaf+"a malformed language tag was accepted"]
  =/  font=path  /static/fonts/[~.inter.woff2]
  =/  fonted=theme-view:jibb-build  skin(font `font)
  ?.  =([%| 'missing static asset: /static/fonts/inter.woff2'] (check-theme:jibb-build fonted ~))
    ~[leaf+"a missing font was accepted"]
  =/  not-font=static-asset:jibb-build  (asset font 'image/png' (png 1 1))
  ?.  =([%| 'theme: font /static/fonts/inter.woff2 is not a font file'] (check-theme:jibb-build fonted ~[not-font]))
    ~[leaf+"an image was accepted as a font"]
  =/  inter=static-asset:jibb-build  (asset font 'font/woff2' [4 'wOF2'])
  =/  found=(each (unit static-asset:jibb-build) @t)  (check-theme:jibb-build fonted ~[inter])
  ?.  =([%& `inter] found)  ~[leaf+"the theme's font file was not found"]
  =/  css=@t  (theme-stylesheet:jibb-build night `inter)
  =/  missing=tang
    %+  expect-html  css
    :~  ':root{--j-s1:4px;--j-s2:8px;--j-s3:16px;--j-normal:#222;--j-background:#fff;'
        '@media (prefers-color-scheme:dark){:root{--j-normal:#eee;--j-background:#111;'
        '@font-face{font-family:jibb-theme;src:url("/apps/my-app/static/0v1.abcde/fonts/inter.woff2") format("woff2")'
        '@media (min-width:60rem){.j-stack{flex-direction:row}}'
        '.j-pad-s3{padding:var(--j-s3)}'  '.j-tone-danger{color:var(--j-danger)}'
        'h1{font-size:2rem;line-height:1.2;font-weight:700}'
        '.j-role-caption{font-size:.875rem;line-height:1.4;font-weight:400}'
    ==
  ?^  missing  missing
  ?:  (contains (trip (theme-stylesheet:jibb-build skin ~)) "@font-face")
    ~[leaf+"a theme without a font declared one"]
  ~
++  test-image-sizes
  ^-  tang
  =/  gif=octs  (bytes ~[[6 'GIF89a'] [2 320] [2 200]])
  =/  jpeg=octs
    %-  bytes
    :~  [2 0xd8ff]  [2 0xe0ff]  (be 2 16)  [14 0]
        [2 0xc0ff]  (be 2 17)  [1 8]  (be 2 300)  (be 2 400)  [10 0]
    ==
  =/  webp=octs
    (bytes ~[[4 'RIFF'] [4 22] [4 'WEBP'] [4 'VP8X'] [4 10] [4 0] [3 127] [3 63]])
  =/  svg=octs  [76 '<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="16" class="x">']
  =/  boxed=octs  [52 '<svg viewBox="0 0 48.5 32" xmlns="http://w3.org/x">']
  =/  cases=(list [name=tape type=@t data=octs wanted=(unit [@ud @ud])])
    :~  ["png" 'image/png' (png 640 480) `[640 480]]
        ["gif" 'image/gif' gif `[320 200]]
        ["jpeg" 'image/jpeg' jpeg `[400 300]]
        ["webp" 'image/webp' webp `[128 64]]
        ["svg" 'image/svg+xml' svg `[24 16]]
        ["viewBox" 'image/svg+xml' boxed `[48 32]]
        ["truncated png" 'image/png' [12 0xa1a.0a0d.474e.5089] ~]
        ["unknown type" 'image/x-thing' (png 1 1) ~]
    ==
  |-
  ?~  cases  ~
  ?.  =(wanted.i.cases (image-size:jibb-build type.i.cases data.i.cases))
    ~[leaf+"{name.i.cases} size was read wrongly"]
  $(cases t.cases)
++  test-unsupported-kind-and-missing-asset
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  dynamic=@t
    %-  text
    :~  '++ main (page load view)'
        '++ load |=(~ (pure ~))'
        '++ view |= value=~ (text "dynamic")'
    ==
  =/  rejected=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/dynamic/jibb dynamic default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%& -.rejected)  ~[leaf+"dynamic page was accepted by the static facade"]
  ?.  =(p.rejected 'unsupported module kind for static build: page')
    ~[leaf+(trip p.rejected)]
  =/  missing=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/about/jibb (text about-source) (text theme-source) '/apps/my-app' ~ ~[~['blog']]) u.prep)
  ?:  ?=(%& -.missing)  ~[leaf+"missing theme font was accepted"]
  ?.  =(p.missing 'missing static asset: /static/fonts/inter.woff2')
    ~[leaf+(trip p.missing)]
  ~
::  A page with data, prepared as the host prepares one.
++  data-page-for
  |=  [request=static-request:jibb-build prep=iprelude-lowering:jibb]
  ^-  (each data-page:jibb-build @t)
  =/  page=jlowering-result:jibb  (check-static:jibb-build request prep)
  ?:  ?=(%| -.page)  [%| message.p.page]
  =/  skin=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb theme-at.request theme-source.request externals.request marks.request modules.request ~[theme-at.request] ~ prep)
  ?:  ?=(%| -.skin)  [%| message.p.skin]
  =/  renderer=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb renderer-at.request renderer-source.request externals.request marks.request modules.request ~[renderer-at.request] ~ prep)
  ?:  ?=(%| -.renderer)  [%| message.p.renderer]
  =/  artifacts=jlowering-cache:jibb  (weld cache.p.page (weld cache.p.skin cache.p.renderer))
  %:  prepare-page:jibb-build
    base.request  root.p.page  root.p.skin  root.p.renderer  artifacts  prep
    assets.request  routes.request  '/apps/my-app/~jibb/s/0v1.css'  ~
  ==
++  test-pages-with-data
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  source=@t
    %-  text
    :~  '++ main (page load view)'
        '++ load |= n=@ud (pure n)'
        ''
        '++ view |= n=@ud'
        '  column ~ ~['
        '    heading 1 "Number {n}"'
    ==
  =/  made=(each data-page:jibb-build @t)
    (data-page-for (request /ui/numbered/[~._n]/jibb source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.made)  ~[leaf+(trip p.made)]
  ?.  =(~[[%n %ud |]] fields.p.made)  ~[leaf+"load's sample fields were not read from its type"]
  ?.  =(~['numbered' '_n'] route.p.made)  ~[leaf+"the page lost its route"]
  =/  twelve=page-step:jibb-build  (page-request:jibb-build p.made [%load ~['numbered' '12']])
  ?.  ?=(%done -.twelve)  ~[leaf+"a page with data did not render"]
  ?.  =('Number 12' title.twelve)  ~[leaf+(trip title.twelve)]
  ?.  (contains (trip html.twelve) "<link rel=\"stylesheet\" href=\"/apps/my-app/~jibb/s/0v1.css\">")
    ~[leaf+"a page with data lost its stylesheet"]
  =/  word=page-step:jibb-build  (page-request:jibb-build p.made [%load ~['numbered' 'twelve']])
  ?.  ?=(%fail -.word)  ~[leaf+"an unparseable parameter rendered"]
  ?.  =(404 status.word)  ~[leaf+"an unparseable parameter was not a 404"]
  ?.  =('the segment twelve is not a @ud, as the route parameter n needs' message.word)
    ~[leaf+(trip message.word)]
  ?.  (contains (trip html.word) "<h1>Not found</h1><pre>the segment twelve is not a @ud")
    ~[leaf+"the 404 was not Jibb's error page"]
  =/  short=page-step:jibb-build  (page-request:jibb-build p.made [%load ~['numbered']])
  ?.  &(?=(%fail -.short) =(404 status.short))  ~[leaf+"a missing parameter was not a 404"]
  ::  A catch-all page takes the rest of the path, any length, as its sample.
  =/  rest-source=@t
    %-  text
    :~  '++ main (page load view)'
        '++ load |=(p=path (pure p))'
        ''
        '++ view |= p=path'
        '  column ~ ~['
        '    heading 1 "Depth {(lent p)}"'
    ==
  =/  rest=(each data-page:jibb-build @t)
    (data-page-for (request /ui/docs/[~.__rest]/jibb rest-source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.rest)  ~[leaf+(trip p.rest)]
  =/  deep=page-step:jibb-build  (page-request:jibb-build p.rest [%load ~['docs' 'a' 'b']])
  ?.  &(?=(%done -.deep) =('Depth 2' title.deep))  ~[leaf+"a catch-all did not take the rest of the path"]
  =/  none=page-step:jibb-build  (page-request:jibb-build p.rest [%load ~['docs']])
  ?.  &(?=(%done -.none) =('Depth 0' title.none))  ~[leaf+"a catch-all did not match its folder"]
  =/  bad=page-step:jibb-build  (page-request:jibb-build p.rest [%load ~['docs' 'A B']])
  ?.  &(?=(%fail -.bad) =(404 status.bad))  ~[leaf+"a segment of a catch-all that is not a knot was not a 404"]
  ~
++  test-page-scries-an-agent
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  source=@t
    %-  text
    :~  '++ main (page load view)'
        '++ load |= slug=@ta'
        '  ^- (ask @t)'
        '  [%agent api="/ui/api/notes" case=%note agent=%notes path=~[%note slug] scry=~ receive=receive]'
        '++ receive |= input=[mark=@tas state=(unit *) fact=*]'
        '  ^- [state=* message=@t] [state=0 message="from the agent"]'
        ''
        '++ view |= words=@t'
        '  column ~ ~['
        '    heading 1 words'
    ==
  =/  made=(each data-page:jibb-build @t)
    (data-page-for (request /ui/notes/[~._slug]/jibb source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.made)  ~[leaf+(trip p.made)]
  =/  first=page-step:jibb-build  (page-request:jibb-build p.made [%load ~['notes' 'hello']])
  ?.  ?=(%scry -.first)  ~[leaf+"an agent's ask did not ask the host to scry"]
  ?.  =([%notes /note/hello] [agent.first path.first])  ~[leaf+"the scry named another agent or path"]
  =/  done=page-step:jibb-build  (page-request:jibb-build p.made [%receive receive.first %noun 42])
  ?.  ?=(%done -.done)  ~[leaf+"the agent's answer did not render"]
  ?.  =('from the agent' title.done)  ~[leaf+(trip title.done)]
  =/  why=@t  'the agent %notes did not answer /note/hello'
  =/  rejected=page-step:jibb-build  (page-request:jibb-build p.made [%reject why])
  ?.  &(?=(%fail -.rejected) =(404 status.rejected) =(why message.rejected))
    ~[leaf+"a rejected path was not a 404"]
  ~
++  test-route-parameters-are-checked
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  cases=(list [at=path load=@t wanted=tape])
    :~  [/ui/numbered/[~._n]/jibb '++ load |=(~ (pure 0))' "the route parameter `n` must be an atom"]
        [/ui/[~._a]/[~._b]/jibb '++ load |= n=@ud (pure n)' "load's sample must be a record of the route parameters"]
        [/ui/[~._a]/[~._b]/jibb '++ load |= [a=@ta c=@ud] (pure c)' "has no field `b` for the route parameter `_b`"]
        [/ui/numbered/jibb '++ load |= n=@ud (pure n)' "a page with no route parameters takes ~"]
        [/ui/numbered/[~._n]/jibb '++ load |= n=[@ud @ud] (pure 0)' "the route parameter `n` must be an atom"]
        [/ui/[~.__rest]/jibb '++ load |= rest=@ta (pure 0)' "a catch-all page takes the rest of the path as load's sample"]
        [/ui/[~._user]/[~.__rest]/jibb '++ load |= [user=@ta rest=@ud] (pure 0)' "the catch-all `rest` takes the rest of the path"]
    ==
  |-
  ?~  cases  ~
  =/  source=@t
    (text ~['++ main (page load view)' load.i.cases '' '++ view |= n=@ud' '  column ~ ~[(text "x")]'])
  =/  checked=jlowering-result:jibb
    (check-static:jibb-build (request at.i.cases source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%& -.checked)  ~[leaf+"{(spud at.i.cases)} with {(trip load.i.cases)} checked"]
  ?.  (contains (trip message.p.checked) wanted.i.cases)  ~[leaf+(trip message.p.checked)]
  ?.  (contains (trip message.p.checked) "++ main:")  ~[leaf+"the route error was not reported at main"]
  $(cases t.cases)
::  An island renders its init's first view on the ship, with its model
::  for the browser, and the page loads the browser library; the island's
::  module compiles to the JavaScript the browser runs.
++  test-islands-render-their-first-view
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  island-at=path  /ui/counter/jibb
  =/  island=@t
    %-  text
    :~  '++ main (program init update view subs)'
        ''
        '+$ model [count=@ud draft=@t]'
        '+$ msg'
        '  %add'
        '  [%typed text=@t]'
        ''
        '++ init |= n=@ud'
        '  [count=n draft=""]'
        ''
        '++ update |= [=msg m=model]'
        '  ?- msg'
        '  %add        [m(count=(add 1 count.m)) ~]'
        '  [%typed t]  [m(draft=t) ~]'
        ''
        '++ subs |= m=model ~'
        ''
        '++ view |= m=model'
        '  column ~ ~['
        '    (text "Count {count.m}")'
        '    field "Draft" draft.m |=%typed'
        '    button "Add" %add'
    ==
  =/  page-at=path  /ui/counting/jibb
  =/  page=@t
    %-  text
    :~  '/= counter /ui/counter'
        '++ main'
        '  column ~ ~['
        '    heading 1 "Counting"'
        '    island main.counter 41'
    ==
  =/  modules=jbundle:jibb  ~[[page-at page] [island-at island]]
  =/  counter=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build island-at island ~ ~ ~[[island-at island]] ~ ~ u.prep)
  ?:  ?=(%| -.counter)  ~[leaf+(trip p.counter)]
  ?.  =(%island kind.p.counter)  ~[leaf+"the counter module was not an island"]
  =/  checked=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    %:  check-module:jibb-build
      page-at  page  ~  ~  modules
      ~[[island-at interface.p.counter]]
      ~[[island-at artifact.p.counter]]
      u.prep
    ==
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  ?.  =(%static-page kind.p.checked)  ~[leaf+"the counting page was not a static page"]
  =/  theme-at=path  /ui/theme/jibb
  =/  theme=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build theme-at default-theme-source:jibb-build ~ ~ ~[[theme-at default-theme-source:jibb-build]] ~ ~ u.prep)
  ?:  ?=(%| -.theme)  ~[leaf+(trip p.theme)]
  =/  renderer-at=path  /lib/jibb/renderer/jibb
  =/  renderer=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build renderer-at renderer-source ~ ~ ~[[renderer-at renderer-source]] ~ ~ u.prep)
  ?:  ?=(%| -.renderer)  ~[leaf+(trip p.renderer)]
  =/  client=client-context:jibb-build
    :*  '/apps/my-app/~jibb/r/0vlib.js'
        ~zod
        (malt ~[['/ui/counter/jibb' '0vcounter']])
        ~[['stores/cart' '0vcart']]
        `'/app'
    ==
  =/  render
    |=  context=(unit client-context:jibb-build)
    ^-  (each static-output:jibb-build @t)
    %:  render-checked:jibb-build
      '/apps/my-app'
      artifact.p.checked
      artifact.p.theme
      artifact.p.renderer
      ~[[island-at artifact.p.counter]]
      u.prep
      ~
      ~
      '/apps/my-app/~jibb/s/0v1.css'
      context
    ==
  =/  rendered=(each static-output:jibb-build @t)  (render `client)
  ?:  ?=(%| -.rendered)  ~[leaf+(trip p.rendered)]
  =/  state=@t  (scot %uw (jam [41 '']))
  =/  html=tang
    %+  expect-html  html.p.rendered
    :~  '<div data-jibb-island="0vcounter">'
        'Count 41'
        '<input type="text" value="" aria-label="Draft" readonly="">'
        '<button type="button">Add</button>'
        (rap 3 ~['<script type="application/x-jibb-state">' state '</script></div>'])
        ::  A JSON object's keys come in its map's order.
        '<script type="application/x-jibb-client">{'
        '"base":"/apps/my-app"'
        '"ship":"~zod"'
        '"stores":{"stores/cart":"0vcart"}'
        '"assets":{}'
        '"section":"/app"'
        '}</script><script type="module" src="/apps/my-app/~jibb/r/0vlib.js"></script></head>'
    ==
  ?^  html  html
  ::  A page whose build compiled no island module for it cannot render one.
  =/  alone=(each static-output:jibb-build @t)  (render ~)
  ?:  ?=(%& -.alone)  ~[leaf+"an island rendered without its compiled module"]
  =/  alone-message=@t
    (show-error:jibb page [/ui/counting/jibb 5 5 "static renderer: /ui/counter/jibb is not an island module this build compiled"])
  ?.  =(p.alone alone-message)
    ~[leaf+(trip p.alone)]
  =/  js=(each @t @t)
    (prepare-browser:jibb-build artifact.p.counter ~[[island-at artifact.p.counter]] u.prep)
  ?:  ?=(%| -.js)  ~[leaf+(trip p.js)]
  =/  script=tang
    %+  expect-html  p.js
    :~  'export function evaluate(runtime, natives) {'
        'requireNative(natives, "raw-seal");'
    ==
  ?^  script  script
  =/  page-js=(each @t @t)
    (prepare-browser:jibb-build artifact.p.checked ~[[island-at artifact.p.counter]] u.prep)
  ?:  ?=(%& -.page-js)  ~[leaf+"a page was compiled for the browser"]
  ?.  =(p.page-js 'an island or store module was expected, not a module of kind static-page')
    ~[leaf+(trip p.page-js)]
  ~
++  test-island-view-reference-errors-are-located
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  island-at=path  /ui/broken-island/jibb
  =/  island=@t
    %-  text
    :~  '++ main (program init update view subs)'
        '++ init |= n=@ud n'
        '++ update |= [msg=@ud model=@ud] [model ~]'
        '++ subs |= model=@ud ~'
        '++ view |= model=@ud'
        '  para ~[(link %/nowhere "Island")]'
    ==
  =/  page-at=path  /ui/island-errors/jibb
  =/  page=@t
    (text ~['/= broken /ui/broken-island' '++ main (island main.broken 0)'])
  =/  modules=jbundle:jibb  ~[[page-at page] [island-at island]]
  =/  checked-request=static-request:jibb-build
    (request page-at page default-theme-source:jibb-build '/apps/my-app' ~ ~)
  =/  checked=jlowering-result:jibb
    (check-static:jibb-build checked-request(modules modules) u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  skin=jlowering-result:jibb
    (check-static:jibb-build (request /ui/theme/jibb default-theme-source:jibb-build default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.skin)  ~[leaf+(trip message.p.skin)]
  =/  renderer=jlowering-result:jibb
    (check-static:jibb-build (request /lib/jibb/renderer/jibb renderer-source default-theme-source:jibb-build '/apps/my-app' ~ ~) u.prep)
  ?:  ?=(%| -.renderer)  ~[leaf+(trip message.p.renderer)]
  =/  client=client-context:jibb-build
    :*  '/apps/my-app/~jibb/r/0vlib.js'
        ~zod
        (malt ~[[(crip (spud island-at)) '0visland']])
        ~
        ~
    ==
  =/  rendered=(each static-output:jibb-build @t)
    %:  render-checked:jibb-build
        '/apps/my-app'
        root.p.checked
        root.p.skin
        root.p.renderer
        (weld cache.p.checked (weld cache.p.skin cache.p.renderer))
        u.prep
        ~
        ~
        '/apps/my-app/~jibb/s/0v1.css'
        `client
    ==
  ?:  ?=(%& -.rendered)  ~[leaf+"an island's bad link became HTML or a crash notice"]
  =/  wanted=@t
    (show-error:jibb island [island-at 6 11 "link to a missing page: %/nowhere"])
  ?.  =(wanted p.rendered)  ~[leaf+(trip p.rendered)]
  ~
::
::  -jibb!test's runner: each test- arm passes when it is %.y; one that is
::  %.n, crashes, or is not a ? fails, with why; other arms are not tests.
++  test-run-tests-reports-each-arm
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  at=path  /ui/tests/sums/jibb
  =/  source=@t
    %-  text
    :~  '++ test-adds  (eq (add 2 2) 4)'
        '++ test-fails  (eq (add 2 2) 5)'
        '++ test-crashes  ^- ?  !!'
        '++ test-is-a-number  42'
        '++ helper  7'
    ==
  =/  checked=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build at source ~ ~ ~[[at source]] ~ ~ u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  =/  outcomes=(list test-outcome:jibb-build)
    (run-tests:jibb-build artifact.p.checked ~[[at artifact.p.checked]] u.prep)
  =/  wanted=(list test-outcome:jibb-build)
    :~  [%test-adds & '']
        [%test-crashes | 'test-crashes crashed during Nock execution']
        [%test-fails | 'test-fails is %.n']
        [%test-is-a-number | 'test-is-a-number is a @ud, not a ?']
    ==
  ?:  =(wanted outcomes)  ~
  :~  leaf+"the test outcomes differ"
      leaf+"wanted {<wanted>}"
      leaf+"got {<outcomes>}"
  ==
::  The Node harness's programs: each test- arm that is a ?, as JavaScript
::  and as Nock whose natives are placeholders; the ship runs that Nock
::  with its own gates in their place to the same values.
++  test-test-programs-for-the-node-harness
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  at=path  /ui/tests/sums/jibb
  =/  source=@t
    %-  text
    :~  '++ test-adds  (eq (add 2 2) 4)'
        '++ test-fails  (eq (add 2 2) 5)'
        '++ test-is-a-number  42'
    ==
  =/  checked=(each [kind=checked-kind:jibb interface=ifile:jibb artifact=checked-module:jibb] @t)
    (check-module:jibb-build at source ~ ~ ~[[at source]] ~ ~ u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip p.checked)]
  =/  programs=(list [arm=term js=@t nock=*])
    (test-programs:jibb-build artifact.p.checked ~[[at artifact.p.checked]] u.prep)
  ?.  =(~[%test-adds %test-fails] (turn programs |=(p=[arm=term *] arm.p)))
    ~[leaf+"the harness's programs are not exactly the ? arms, in name order"]
  ?>  ?=([* * ~] programs)
  =/  js=tang
    (expect-html js.i.programs ~['export function evaluate(runtime, natives) {' 'requireNative(natives, "add");'])
  ?^  js  js
  ::  The ship's own gates in the placeholders' places give the same value.
  =/  swap
    |=  formula=*
    ^-  *
    ?@  formula  formula
    ?:  ?=([[%0 %0] %0 %jibb-native @] formula)
      ?:  =('add' +>+.formula)  add
      |=([a=* b=*] =(a b))
    [$(formula -.formula) $(formula +.formula)]
  =/  adds=outcome:jibb-core  (execute:jibb-nock 0 (swap nock.i.programs))
  =/  fails=outcome:jibb-core  (execute:jibb-nock 0 (swap nock.i.t.programs))
  ?.  &(=([%ok 0] adds) =([%ok 1] fails))
    ~[leaf+"the placeholder Nock did not run to %.y and %.n: {<[adds fails]>}"]
  ~
--
