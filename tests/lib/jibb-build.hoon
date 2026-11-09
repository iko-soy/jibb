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
++  theme-without-font
  ^-  @t
  %-  text
  :~  '++ theme  ^- theme'
      '  [ space=[s1="4px" s2="8px" s3="16px"]'
      '    tones=[normal="#222" background="#fff" accent="#17734f" danger="#b3261e" muted="#5f5f5f"]'
      '    wide="60rem"'
      '    lang="en"'
      '    zone="UTC"'
      '    font=~'
      '    dark=~'
  ==
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
    (build-static:jibb-build (request /ui/about/jibb (text about-source) theme-without-font '/apps/my-app' ~) u.prep)
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
    (build-static:jibb-build (request /ui/escape/jibb source theme-without-font '/apps/my-app' ~) u.prep)
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  (expect-html html.p.built ~['<title>A &lt;B&gt; &amp; C</title>' 'Fish &amp; &lt;ships&gt;' 'href="/outside?a=1&amp;b=&lt;two&gt;"' 'Away &amp; elsewhere'])
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
    (build-static:jibb-build (request /ui/dynamic/jibb dynamic theme-without-font '/apps/my-app' ~) u.prep)
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
