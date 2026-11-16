::  The ship's markup for every element kind and attribute, rendered through
::  lib/jibb/renderer.jibb and the build facade's serializer, one case a
::  line of tests/markup-parity/expected.txt.  js/test/markup-parity.test.mjs
::  checks the browser's decoder against the same file, since hydration
::  keeps the server's DOM only when the browser's serializes the same.
::  tools/test-arms --update markup-parity writes the report there.
/+  jibb, jibb-build, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  renderer-source  %jibb  /lib/jibb/renderer/jibb
/*  expected  %txt  /tests/markup-parity/expected/txt
::  The renderer and theme, checked, linked and executed once, as a page's
::  render kit, with a page context of one 4 by 5 static image and the
::  routes the cases link to.
=/  make-kit
  |.
  ^-  (each [kit=render-kit:jibb-build context=page-context:jibb-build] @t)
  =/  prep=(unit iprelude-lowering:jibb)
    (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
  ?~  prep  [%| 'prelude did not prepare for lowering']
  =/  check
    |=  [at=path source=@t]
    ^-  jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb at source ~ ~ ~ ~[at] ~ u.prep)
  =/  page=jlowering-result:jibb  (check /ui/parity/jibb '++ main (text "parity")\0a')
  ?:  ?=(%| -.page)  [%| message.p.page]
  =/  skin=jlowering-result:jibb  (check /ui/theme/jibb default-theme-source:jibb-build)
  ?:  ?=(%| -.skin)  [%| message.p.skin]
  =/  renderer=jlowering-result:jibb  (check /lib/jibb/renderer/jibb renderer-source)
  ?:  ?=(%| -.renderer)  [%| message.p.renderer]
  =/  cache=jlowering-cache:jibb
    :(weld cache.p.page cache.p.skin cache.p.renderer cache.u.prep)
  =/  page-core=(each expr:jibb-core @t)  (link-page:jibb-build root.p.page cache)
  ?:  ?=(%| -.page-core)  [%| p.page-core]
  =/  kit=(each render-kit:jibb-build @t)
    (prepare-kit:jibb-build p.page-core root.p.page root.p.skin root.p.renderer cache)
  ?:  ?=(%| -.kit)  [%| p.kit]
  =/  png=octs
    [24 (can 3 ~[[8 0xa1a.0a0d.474e.5089] [4 (rev 3 4 13)] [4 'IHDR'] [4 (rev 3 4 4)] [4 (rev 3 4 5)]])]
  =/  dot=static-asset:jibb-build
    [/static/img/[~.dot.png] '/apps/my-app/static/0v1.abcde/img/dot.png' 'image/png' png]
  [%& p.kit ['/apps/my-app' ~[dot] ~[~ ~['blog' '_slug']] ~]]
=/  shared=(each (each [kit=render-kit:jibb-build context=page-context:jibb-build] @t) tang)
  (mule make-kit)
|%
++  seal  |=(raw=* (raw-seal-native:jibb-build raw))
++  text  |=(words=@t (seal [%text words]))
::  Render-only lowering wraps each element in its source origin.
++  origin  |=(element=* (render-origin-native:jibb-build /ui/parity/jibb 1 1 element))
::  Each case's name, whether it renders inside an island, where controls
::  may, and its element.  The JavaScript test builds the same elements.
++  cases
  ^-  (list [name=@t inside=? element=*])
  :~  ['text' | (text 'Fish & <ships> "quoted" \'single\'')]
      ['heading' | (seal [%heading 2 'Title'])]
      ['heading-clamped' | (seal [%column ~ ~[(seal [%heading 0 'Low']) (seal [%heading 9 'High'])]])]
      :+  'para-phrasing'  |
      %-  seal
      :-  %para
      :~  (text 'Read ')
          (seal [%link /blog/first-post 'the post'])
          (text ', ')
          (seal [%link-unsafe 'https://urbit.org' 'Urbit'])
          (seal [%image /static/img/[~.dot.png] 'A dot'])
          (seal [%image-unsafe ['https://urbit.org/a.png' 10 20] 'Away'])
      ==
      ['para-block' | (seal [%para ~[(text 'Status: ') (seal [%el ~[[%tone %danger]] (text 'offline')])]])]
      ['para-heading' | (seal [%para ~[(text 'Intro') (seal [%heading 2 'Title'])]])]
      ['para-empty' | (seal [%para ~])]
      ['para-each' | (seal [%para ~[(text 'See ') (seal [%each ~[[1 (text 'a')]]])]])]
      ['para-in-para' | (seal [%para ~[(seal [%para ~[(text 'inner')]])]])]
      ['para-origins' | (seal [%para ~[(origin (text 'a ')) (origin (seal [%link /blog/first-post 'b']))]])]
      ['para-origins-block' | (seal [%para ~[(origin (seal [%el ~ (text 'b')]))]])]
      :+  'row-attributes'  |
      %-  seal
      :+  %row
        ~[[%pad %s2] [%gap %s3] [%width [%fill 0]] [%align %center] [%role %body] [%tone %danger]]
      ~[(text 'all')]
      :+  'column-chars'  |
      (seal [%column ~[[%width [%chars 20]] [%align %end] [%role %caption]] ~[(text 'narrow')]])
      :+  'wrap-shrink'  |
      (seal [%wrap ~[[%width %shrink] [%gap %s1] [%tone %muted]] ~[(text 'a') (text 'b')]])
      :+  'stack-fill'  |
      (seal [%stack ~[[%width [%fill 3]] [%pad %s0] [%role %label] [%tone %accent]] ~[(text 'stacked')]])
      ::  The last attribute of a family wins completely: a later shrink
      ::  drops chars's inline number, a later tone danger's aria-live.
      :+  'el-last-wins'  |
      %-  seal
      :+  %el
        ~[[%width [%chars 5]] [%tone %danger] [%pad %s1] [%width %shrink] [%tone %normal] [%pad %s3]]
      (text 'last')
      :+  'el-back-to-chars'  |
      (seal [%el ~[[%width %shrink] [%width [%fill 2]] [%width [%chars 7]]] (text 'seven')])
      ::  Every value of every attribute, one el each.
      :+  'every-attribute'  |
      %-  seal
      :+  %column  ~
      %+  turn
        ^-  (list *)
        :~  [%pad %s0]  [%pad %s1]  [%pad %s2]  [%pad %s3]
            [%gap %s0]  [%gap %s1]  [%gap %s2]  [%gap %s3]
            [%align %start]  [%align %center]  [%align %end]
            [%role %body]  [%role %caption]  [%role %label]
            [%tone %normal]  [%tone %muted]  [%tone %accent]  [%tone %danger]
            [%width %shrink]  [%width [%chars 1]]  [%width [%fill 1]]
        ==
      |=(a=* (seal [%el ~[a] (text 'x')]))
      ['link' | (seal [%link /blog/first-post 'First & best'])]
      ['link-static' | (seal [%link /static/img/[~.dot.png] 'Dot file'])]
      ['link-home' | (seal [%link / 'Home'])]
      ['link-unsafe-https' | (seal [%link-unsafe 'https://urbit.org/?a=1&b=2' 'Urbit'])]
      ['link-unsafe-root' | (seal [%link-unsafe '/apps/groups' 'Groups'])]
      ['link-unsafe-mailto' | (seal [%link-unsafe 'mailto:a@b.c' 'Mail'])]
      ['link-unsafe-tel' | (seal [%link-unsafe 'tel:+1555' 'Call'])]
      ['link-unsafe-javascript' | (seal [%link-unsafe 'javascript:alert(1)' 'Run <me>'])]
      ['link-unsafe-protocol-relative' | (seal [%link-unsafe '//evil.example' 'Elsewhere'])]
      ['link-unsafe-backslash' | (seal [%link-unsafe '/\\evil.example' 'Back'])]
      ['link-unsafe-tab' | (seal [%link-unsafe '/\09/tabbed.example' 'Tabbed'])]
      ['link-unsafe-http' | (seal [%link-unsafe 'http://plain.example' 'Plain'])]
      ['image' | (seal [%image /static/img/[~.dot.png] 'A dot'])]
      ['image-decorative' | (seal [%image /static/img/[~.dot.png] ''])]
      ['image-unsafe-https' | (seal [%image-unsafe ['https://urbit.org/a.png' 10 20] 'Away'])]
      ['image-unsafe-root' | (seal [%image-unsafe ['/apps/x/a.png' 3 4] 'Root'])]
      ['image-unsafe-data' | (seal [%image-unsafe ['data:image/png;base64,AAAA' 1 1] 'Not "fetched"'])]
      ['each' | (seal [%each ~[[1 (text 'one')] [[%k 2] (seal [%el ~ (text 'two')])]]])]
      :+  'table'  |
      %-  seal
      :+  %table
        :~  ['Qty' %shrink %end]
            ['Name' [%fill 1] %start]
            ['Notes' [%fill 2] %center]
            ['Code' [%chars 10] %end]
        ==
      :~  [1 ~[(text '12') (text 'Ann') (text 'x') (text 'A1') (text 'extra')]]
          [2 ~[(text '3')]]
      ==
      ['table-plain' | (seal [%table ~[['A' [%chars 0] %start] ['B' %shrink %start]] ~])]
      ['table-fill-zero' | (seal [%table ~[['Z' [%fill 0] %start]] ~])]
      ['button' & (seal [%button 'Go & stop' 0])]
      ['toggle-on' & (seal [%toggle %.y 'On' 0])]
      ['toggle-off' & (seal [%toggle %.n 'Off' 0])]
      ['field' & (seal [%field 'Name' 'Ann & "Bo"' 0])]
      ['form' & (seal [%form 0 ~[(seal [%field 'Inner' '' 0]) (seal [%button 'Send' 0])]])]
      :+  'form-nested'  &
      %-  seal
      :+  %form  0
      :~  (text 'before')
          (seal [%form 0 ~[(text 'inside') (seal [%field 'Nested' '' 0])]])
          (text 'after')
      ==
      :+  'para-controls'  &
      %-  seal
      :-  %para
      :~  (text 'Pick ')
          (seal [%button 'b' 0])
          (seal [%toggle %.y 't' 0])
          (seal [%field 'f' 'v' 0])
      ==
      ['para-form' & (seal [%para ~[(seal [%form 0 ~[(text 'in form')]])]])]
  ==
::  A case's HTML, or BAD and why, which no expected file may hold.
++  render-case
  |=  $:  kit=render-kit:jibb-build
          context=page-context:jibb-build
          entry=[name=@t inside=? element=*]
      ==
  ^-  @t
  =/  tree=(each vnode:jibb-build render-error:jibb-build)
    (render-static-element:jibb-build ctx.kit(inside inside.entry) element.entry)
  ?:  ?=(%| -.tree)  (rap 3 ~['BAD ' name.entry ': ' message.p.tree])
  =/  references=(each ~ render-error:jibb-build)
    (check-references:jibb-build context p.tree)
  ?:  ?=(%| -.references)  (rap 3 ~['BAD ' name.entry ': ' message.p.references])
  (rap 3 ~[name.entry ' ' (serialize-vnode:jibb-build context p.tree)])
++  report
  ^-  @t
  ?:  ?=(%| -.shared)  (mean (flop p.shared))
  ?:  ?=(%| -.p.shared)  (cat 3 'BAD setup: ' p.p.shared)
  =/  kit=render-kit:jibb-build  kit.p.p.shared
  =/  context=page-context:jibb-build  context.p.p.shared
  %-  of-wain:format
  (turn cases |=(entry=[name=@t inside=? element=*] (render-case kit context entry)))
::  Every differing line, so one run shows them all.
++  test-server-markup-matches-expected
  ^-  tang
  =/  got=wain  (to-wain:format report)
  ?:  =(got expected)  ~
  =/  wanted=(list @t)  expected
  =/  lines=(list @t)  got
  =|  out=tang
  |-  ^-  tang
  ?~  lines
    =/  last=tank
      ?~  wanted  leaf+"the report differs from expected.txt"
      leaf+"expected.txt has more cases than the report, from {(trip i.wanted)}"
    (flop `tang`[last out])
  ?~  wanted
    (flop `tang`[leaf+"the report has a case expected.txt lacks: {(trip i.lines)}" out])
  ?:  =(i.lines i.wanted)  $(lines t.lines, wanted t.wanted)
  =/  differs=tang  ~[leaf+"wanted: {(trip i.wanted)}" leaf+"got:    {(trip i.lines)}"]
  $(lines t.lines, wanted t.wanted, out (weld differs out))
--
