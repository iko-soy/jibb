::  The template compiler's real input comes through the full checker and
::  authenticated linker, not hand-written lookalike constructor names.
/+  jibb, jibb-core, jibb-js-template, jibb-lower, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  source  %jibb  /tests/view-template/source/jibb
/*  expected  %txt  /tests/view-template/core/txt
|%
++  test-checked-view-template-core
  ^-  tang
  =/  prepared=(unit iprelude-lowering:jibb)
    (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
  ?~  prepared  ~[leaf+"template prelude did not prepare"]
  =/  at=path  /ui/template/jibb
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb at source ~ ~ ~ ~[at] ~ u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %view root.p.built cache.p.built)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  actual=@t  (print-expr:jibb-core p.linked)
  ?.  =((of-wain:format expected) actual)
    ~[leaf+"checked template source changed its linked Core" leaf+(trip actual)]
  ~
::  A direct authenticated Core expression also pins the descriptor and
::  axes independently of the JavaScript emitter's text fixtures.
++  test-template-descriptor
  ^-  tang
  =/  text=expr:jibb-core
    [%lam [%own %words] [%app [%native [%own %raw-seal]] [%cons [%lit [%tas %text '%text']] [%var [%own %words]]]]]
  =/  made=(unit plan:jibb-js-template)  (view-template:jibb-js-template text ~)
  ?~  made  ~[leaf+"authenticated text did not yield a template"]
  ?.  =([tree='0' axes=~[7]] u.made)  ~[leaf+"text template descriptor or hole axis differs"]
  =/  fake=expr:jibb-core
    [%lam [%own %words] [%app [%var [%own %raw-seal]] [%cons [%lit [%tas %text '%text']] [%var [%own %words]]]]]
  ?^  (view-template:jibb-js-template fake ~)
    ~[leaf+"a source spelling manufactured template provenance"]
  ~
--
