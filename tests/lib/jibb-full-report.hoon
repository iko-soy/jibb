/+  jibb, jibb-import, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  buttons-source  %jibb  /my-app/ui/components/buttons/jibb
/*  buttons-error  %txt  /tests/type-buttons/error/txt
|%
++  test-full-report-prototype
  ^-  tang
  =/  at=path  /tests/report/jibb
  =/  src=@t  '+$ word @t\0a++ value "hi"\0a'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"valid fixture failed" leaf+(trip message.p.checked)]
  =/  actual=@t  (render-full-types:jibb at src checked)
  ?.  =(actual (golden-types:jibb at src))  ~[leaf+"golden type entry point did not use the full checker"]
  =/  expected=@t  'module kind: library\0a+$ word: @t\0a++ value: @t'
  ?.  =(actual expected)  ~[leaf+"checked report differs" leaf+(trip actual)]
  =/  bad=@t  '++ broken missing'
  =/  rejected=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at bad ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.rejected)  ~[leaf+"invalid fixture was accepted"]
  ?.  =((render-full-types:jibb at bad rejected) message.p.rejected)
    ~[leaf+"full diagnostic was not preserved exactly"]
  ~
++  check-kind-template
  |=  [name=term kind=checked-kind:jibb args=(list itype:jibb) prelude=ifile:jibb]
  ^-  tang
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb name prelude)
  ?~  mold  ~[leaf+"prelude mold missing"]
  =/  typ=(unit itype:jibb)  (template-apply:jibb u.mold args)
  ?~  typ  ~[leaf+"template application failed"]
  =/  iface=ifile:jibb  prelude(values ~[[%main [u.typ ~ ~]]])
  =/  result=(unit checked-kind:jibb)  (checked-main-kind:jibb iface `prelude)
  ?.  =(result `kind)  ~[leaf+"kind classification differs" leaf+(trip name)]
  ~
++  test-checked-main-kind
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed to prepare"]
  =/  no-main=ifile:jibb  iface.u.prepared(values ~)
  ?.  =((checked-main-kind:jibb no-main `iface.u.prepared) `%library)  ~[leaf+"missing main is not library"]
  =/  invalid=ifile:jibb  no-main(values ~[[%main [[%atom %t] ~ ~]]])
  ?^  (checked-main-kind:jibb invalid `iface.u.prepared)  ~[leaf+"unrecognized main was assigned a kind"]
  =/  generic=ifile:jibb  no-main(values ~[[%main [[%var 0] ~[0] ~]]])
  ?^  (checked-main-kind:jibb generic `iface.u.prepared)  ~[leaf+"generic main was assigned a closed kind"]
  =/  store-template=(unit ischeme:jibb)  (find-jibb-mold:jibb %store iface.u.prepared)
  ?~  store-template  ~[leaf+"store template missing"]
  =/  store-type=(unit itype:jibb)  (template-apply:jibb u.store-template ~[[%atom %ud]])
  ?~  store-type  ~[leaf+"store specialization failed"]
  =/  fake-molds=imold-types:jibb
    [[%program u.store-template] (skim molds.iface.u.prepared |=(entry=[name=term template=ischeme:jibb] !=(%program name.entry)))]
  =/  ambiguous-prelude=ifile:jibb  iface.u.prepared(molds fake-molds)
  =/  ambiguous=ifile:jibb  no-main(values ~[[%main [u.store-type ~ ~]]])
  ?^  (checked-main-kind:jibb ambiguous `ambiguous-prelude)  ~[leaf+"ambiguous main was assigned a kind"]
  (zing `(list tang)`~[(check-kind-template %element %static-page ~[[%empty ~]] iface.u.prepared) (check-kind-template %page %page ~[[%atom %t] [%atom %ud]] iface.u.prepared) (check-kind-template %store %store ~[[%atom %ud]] iface.u.prepared) (check-kind-template %store %store ~[[%face %callback [%fn [%atom %t] [%atom %t]]]] iface.u.prepared) (check-kind-template %program %island ~[[%atom %t] [%atom %ud] [%atom %tas]] iface.u.prepared)])

++  check-real-kind
  |=  [name=tape src=@t expected=checked-kind:jibb prepared=iprelude:jibb]
  ^-  tang
  =/  at=path  /ui/probe/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(weld name ": full checker rejected") leaf+(trip message.p.checked)]
  =/  kind=(unit checked-kind:jibb)  `kind.p.checked
  ?.  =(kind `expected)  ~[leaf+(weld name ": checked kind differs")]
  ~
++  test-real-checked-kind
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed to prepare"]
  =/  static=@t  '++ main (text "hi")'
  ::  /ui/probe has no route parameters, so its load takes ~.
  =/  page=@t  (of-wain:format ~['++ main (page load view)' '++ load |=(~ (pure 1))' '++ view |= x=@ud (text "hi")'])
  =/  store=@t  (of-wain:format ~['+$ state @ud' '+$ poke %hit' '++ main (store init update)' '++ init ^- state 0' '++ update |= [a=poke s=state] s'])
  =/  island=@t  (of-wain:format ~['+$ model @ud' '+$ msg %hit' '++ main (program init update view subs)' '++ init |= d=@t ^- model 0' '++ update |= [m=msg s=model] ^- [model (list (cmd msg))] [s ~]' '++ view |= s=model ^- (element msg) (text "hi")' '++ subs |= s=model ^- (list (sub msg)) ~'])
  (zing `(list tang)`~[(check-real-kind "static page" static %static-page u.prepared) (check-real-kind "data page" page %page u.prepared) (check-real-kind "store" store %store u.prepared) (check-real-kind "island" island %island u.prepared)])

++  starts-text
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?.  =(i.hay i.needle)  |
  $(hay t.hay, needle t.needle)
++  contains-text
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  (starts-text hay needle)  &
  $(hay t.hay)
++  test-full-report-import
  ^-  tang
  =/  at=path  /tests/consumer/jibb
  =/  dep=path  /tests/dependency/jibb
  =/  src=@t  '/= other /tests/dependency\0a++ value text.other\0a'
  =/  good=@t  '++ text "hi"\0a'
  =/  result=@t  (full-types-in-context:jibb at src ~ ~ ~[[dep good]] ~)
  ?.  =(result (golden-types-with-modules:jibb at src ~ ~ ~[[dep good]]))
    ~[leaf+"golden import entry point did not use the full checker"]
  ?.  =('module kind: library\0a++ value: @t' result)
    ~[leaf+"full report lost checked import type" leaf+(trip result)]
  =/  bad=@t  '++ text missing\0a'
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~[[dep bad]] ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.checked)  ~[leaf+"invalid imported source was accepted"]
  =/  shown=@t  (full-types-in-context:jibb at src ~ ~ ~[[dep bad]] ~)
  ?.  =(shown message.p.checked)  ~[leaf+"imported checker diagnostic was not preserved exactly"]
  ?.  (contains-text (trip shown) "/tests/dependency")
    ~[leaf+"imported diagnostic did not name its source"]
  ~

++  test-full-report-buttons
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/components/buttons/jibb
  =/  result=@t  (full-types-in-context:jibb at buttons-source ~ ~ ~ prepared)
  ?.  =(result (golden-types-with-prepared-prelude:jibb at buttons-source ~ ~ ~ prepared))
    ~[leaf+"golden prelude entry point did not use the full checker"]
  =/  header=@t  '++ add-button: nothing fixes the union of %add; add a `^-`'
  ?.  =((to-wain:format (cat 3 result '\0a')) [header buttons-error])
    ~[leaf+"full report did not preserve the exact buttons error and excerpts" leaf+(trip result)]
  ~

++  test-full-report-hoon-import
  ^-  tang
  =/  sur=@t  '|%\0a+$  wide  @uw\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  wide  (read-named:jibb-import %fixture %wide cor)
  ?:  ?=(%| -.wide)  ~[leaf+"Hoon mold import failed"]
  =/  src=@t  '/- fixture\0a++ wide-id |= x=wide.fixture x\0a'
  =/  file=path  /tests/hoon-import/jibb
  =/  ext=(list [module=term name=term result=*])  ~[[%fixture %wide wide]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ext ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"full checker rejected imported mold" leaf+(trip message.p.checked)]
  =/  external=(list [module=term name=term result=*])  ~[[%fixture %wide [%ok p.wide]]]
  =/  actual=@t  (golden-types-with-reader-diagnostics:jibb file src external ~)
  ?.  =(actual (render-full-types:jibb file src checked))
    ~[leaf+"reader diagnostic type entry did not report the full checker result" leaf+(trip actual)]
  ?.  (contains-text (trip actual) "@uw")  ~[leaf+"imported aura missing from full report"]
  ~

++  test-full-report-api
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/api/demo/jibb
  =/  src=@t  '/% %todo\0a+$ paths [%items /items todo]\0a'
  =/  marks=imark-externals:jibb  ~[[%todo [%& [%atom %t ~]]]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ marks ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+"API fixture was rejected" leaf+(trip message.p.checked)]
  ?.  =(%library kind.p.checked)  ~[leaf+"API without main is not a library"]
  =/  shown=@t  (full-types-in-context:jibb at src ~ marks ~ prepared)
  ?.  (contains-text (trip shown) "module kind: library\0a+$ paths: API paths declaration")
    ~[leaf+"API paths report differs" leaf+(trip shown)]
  ?.  (contains-text (trip shown) "++ items:")
    ~[leaf+"generated API request type missing from report" leaf+(trip shown)]
  =/  poke=@t  '/% %todo\0a+$ poke todo\0a'
  =/  poke-report=@t  (full-types-in-context:jibb at poke ~ marks ~ prepared)
  ?.  (contains-text (trip poke-report) "module kind: library\0a+$ poke: API poke declaration")
    ~[leaf+"API poke report differs" leaf+(trip poke-report)]
  ?.  (contains-text (trip poke-report) "++ poke:")
    ~[leaf+"generated API poke type missing from report" leaf+(trip poke-report)]
  ~

--
