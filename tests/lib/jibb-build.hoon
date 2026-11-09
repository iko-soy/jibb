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
    |=  [lines=wain wanted=@t]
    ^-  tang
    =/  made=(each static-output:jibb-build @t)  (build lines)
    ?:  ?=(%& -.made)  ~[leaf+(trip (cat 3 'built despite: ' wanted))]
    ?:  =(wanted p.made)  ~
    ~[leaf+(trip (rap 3 ~['wanted ' wanted ', got ' p.made]))]
  =/  page-error=tang
    (expect-error ~['++ main (link %/nowhere "Gone")'] 'link to a missing page: %/nowhere')
  ?^  page-error  page-error
  =/  deeper-error=tang
    (expect-error ~['++ main (link %/blog/a/b "Too deep")'] 'link to a missing page: %/blog/a/b')
  ?^  deeper-error  deeper-error
  =/  asset-error=tang
    (expect-error ~['++ main (image %/static/img/gone.png "Gone")'] 'missing static asset: /static/img/gone.png')
  ?^  asset-error  asset-error
  =/  place-error=tang
    %+  expect-error  ~['++ main (image %/blog/x "Not a file")']
    'an image\'s application path must name a static file: %/blog/x'
  ?^  place-error  place-error
  %+  expect-error  ~['++ main (image %/static/img/odd.png "Odd")']
  'static image has no size this build can read: /static/img/odd.png'
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
--
