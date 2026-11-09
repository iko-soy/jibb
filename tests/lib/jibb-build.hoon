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
  |=  [at=path source=@t skin=@t base=@t assets=(list path)]
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
  ==
++  expect-html
  |=  [html=@t wanted=(list @t)]
  ^-  tang
  ?~  wanted  ~
  ?.  (contains (trip html) (trip i.wanted))
    ~[leaf+(trip (cat 3 'static HTML is missing: ' i.wanted)) leaf+(trip html)]
  $(wanted t.wanted)
++  test-real-about-document
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"prelude did not prepare for lowering"]
  =/  built=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/about/jibb (text about-source) default-theme-source:jibb-build '/apps/my-app' ~) u.prep)
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  ?.  =('About this ship' title.p.built)  ~[leaf+"document title did not come from the first h1"]
  =/  html=@t  html.p.built
  =/  missing=tang
    (expect-html html ~['<!doctype html>' '<title>About this ship</title>' '<h1' 'About this ship' 'Hosted on Urbit. This page ships no JavaScript.' 'href="/apps/my-app/blog"' 'data-tone="accent"' 'color: #17734f'])
  ?^  missing  missing
  ?:  (contains (trip html) "<script")  ~[leaf+"static page shipped JavaScript"]
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
    ==
  =/  built=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/escape/jibb source default-theme-source:jibb-build '/apps/my-app' ~) u.prep)
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  (expect-html html.p.built ~['<title>A &lt;B&gt; &amp; C</title>' 'Fish &amp; &lt;ships&gt;' 'href="/outside?a=1&amp;b=&lt;two&gt;"' 'Away &amp; elsewhere'])
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
  =/  outline=[jibb=(list path) surs=(list term) marks=(list term) main=?]
    (module-outline:jibb-build page-at page)
  ?.  =(outline [~[note-at] ~ ~ &])
    ~[leaf+"the page's outline did not name exactly its Jibb import and main"]
  ?.  =([~ ~ ~ |] (module-outline:jibb-build note-at note))
    ~[leaf+"a library without main was outlined as a possible page"]
  ?.  =([~ ~ ~ &] (module-outline:jibb-build page-at 'not valid Jibb'))
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
  =/  stepwise=(each static-output:jibb-build @t)
    %:  render-checked:jibb-build
      '/apps/my-app'
      artifact.p.checked
      artifact.p.theme
      artifact.p.renderer
      ~[[note-at artifact.p.lib]]
      u.prep
      ~
    ==
  ?:  ?=(%| -.stepwise)  ~[leaf+(trip p.stepwise)]
  =/  request=static-request:jibb-build
    :*  page-at  page  '/apps/my-app'
        renderer-at  renderer-source
        theme-at  default-theme-source:jibb-build
        modules  ~  ~  ~
    ==
  =/  one-shot=(each static-output:jibb-build @t)  (build-static:jibb-build request u.prep)
  ?.  =(one-shot stepwise)  ~[leaf+"stepwise and one-shot builds differ"]
  (expect-html html.p.stepwise ~['<title>Notes</title>' 'First note'])
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
    (build-static:jibb-build (request /ui/dynamic/jibb dynamic default-theme-source:jibb-build '/apps/my-app' ~) u.prep)
  ?:  ?=(%& -.rejected)  ~[leaf+"dynamic page was accepted by the static facade"]
  ?.  =(p.rejected 'unsupported module kind for static build: page')
    ~[leaf+(trip p.rejected)]
  =/  missing=(each static-output:jibb-build @t)
    (build-static:jibb-build (request /ui/about/jibb (text about-source) (text theme-source) '/apps/my-app' ~) u.prep)
  ?:  ?=(%& -.missing)  ~[leaf+"missing theme font was accepted"]
  ?.  =(p.missing 'missing static asset: /static/fonts/inter.woff2')
    ~[leaf+(trip p.missing)]
  ~
--
