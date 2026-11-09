/+  jibb, jibb-build, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  renderer-source  %jibb  /lib/jibb/renderer/jibb
/*  about-source  %txt  /my-app/ui/about/jibb
/*  theme-source  %txt  /my-app/ui/theme/jibb
|%
++  prepared
  ^-  (unit iprelude-lowering:jibb)
  (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
++  test-probe
  ^-  tang
  =/  prep=(unit iprelude-lowering:jibb)  prepared
  ?~  prep  ~[leaf+"no prep"]
  =/  request=static-request:jibb-build
    :*  /ui/about/jibb
        '++ main (text "hi")'
        '/apps/my-app'
        /lib/jibb/renderer/jibb
        renderer-source
        /ui/theme/jibb
        default-theme-source:jibb-build
        ~
        ~
        ~
        ~
        ~
    ==
  =/  page=jlowering-result:jibb
    (check-static:jibb-build request u.prep)
  ?:  ?=(%| -.page)  ~[leaf+(trip message.p.page)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %main root.p.page cache.p.page)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  registry=(each native-registry:jibb-nock @t)
    (native-registry:jibb-build ~[p.linked])
  ?:  ?=(%| -.registry)  ~[leaf+(trip p.registry)]
  ?.  (~(has by p.registry) [%own %raw-seal])  ~[leaf+"raw seal missing from registry"]
  =/  made  (mock [0 (emit:jibb-nock p.linked p.registry)] |=(^ ~))
  ?.  ?=(%0 -.made)  ~[leaf+"single text main crashed during Nock execution"]
  ?.  =(p.made ['jibb.private.seal.v1' %text 'hi'])
    ~[leaf+"single text main returned the wrong sealed element"]
  ~
--
