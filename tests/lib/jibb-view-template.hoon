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
::  Hand-written Core cases pin the descriptor protocol separately from
::  emitter parity. A read failure is always a test failure, including when
::  the expected result is ordinary rendering without a template.
++  check-template
  |=  [source=@t expected=(unit plan:jibb-js-template)]
  ^-  tang
  =/  native=native:jibb-core  |=(v=value:jibb-core [v ~])
  =/  registry=native-registry:jibb-core
    (~(put by *(map name:jibb-core native:jibb-core)) [%own %raw-seal] native)
  =/  parsed=(each expr:jibb-core @t)  (read-expr:jibb-core source registry)
  ?:  ?=(%| -.parsed)  ~[leaf+"template Core did not read" leaf+(trip p.parsed)]
  =/  actual=(unit plan:jibb-js-template)  (view-template:jibb-js-template p.parsed ~)
  ?:  =(expected actual)  ~
  ~[leaf+"template descriptor or axes differ" leaf+(trip source) leaf+(trip ?~(actual 'no plan' tree.u.actual))]
::
++  test-template-constant-attributes-and-child-holes
  ^-  tang
  %+  check-template
    '(lam state (app (native raw-seal) (cons %column (cons (cons (cons %gap %s1) (cons (cons %width (cons %chars 20)) (cons (cons %tone %muted) ~))) (cons (app (native raw-seal) (cons %heading (cons 1 "Title"))) (cons (slot 2 state) (cons (app (native raw-seal) (cons %text (slot 3 state))) ~)))))))'
  `['["column",14,[["h1",{"tabIndex":"-1"},["Title"]],-1,1]]' ~[62 507]]
::  An unknown list tail makes one hole for that complete layout, without
::  consuming the text hole that its known prefix would otherwise contain.
++  test-template-unknown-child-list
  ^-  tang
  %+  check-template
    '(lam words (app (native raw-seal) (cons %column (cons ~ (cons (app (native raw-seal) (cons %row (cons ~ (cons (app (native raw-seal) (cons %text words)) words)))) (cons (app (native raw-seal) (cons %text words)) ~))))))'
  `['["div",{"class":"j-column"},[-1,1]]' ~[30 251]]
::
++  test-template-element-hole-fallbacks
  ^-  tang
  ;:  weld
    (check-template '(lam words words)' ~)
    (check-template '(lam words (app (native raw-seal) (cons %heading (cons words "Title"))))' ~)
    (check-template '(lam words (app (native raw-seal) (cons %column (cons words ~))))' ~)
    (check-template '(lam words (app (native raw-seal) (cons %row (cons ~ words))))' ~)
    (check-template '(lam words (app (native raw-seal) (cons %button ~)))' ~)
    (check-template '(lam words (app (native raw-seal) (cons %el (cons ~ words))))' `['["div",{"class":"j-el"},[-1]]' ~[15]])
    (check-template '(lam words (app (native raw-seal) (cons %el (cons ~ (app (native raw-seal) (cons %column (cons (cons (cons %gap words) ~) ~)))))))' `['["div",{"class":"j-el"},[-1]]' ~[15]])
    (check-template '(lam words (app (native raw-seal) (cons %el (cons ~ (app (native raw-seal) (cons %heading (cons words "Title")))))))' `['["div",{"class":"j-el"},[-1]]' ~[15]])
  ==
::  Constant traversal counts atoms and cells, checking the complete noun.
::  63 list cells plus their heads and final atom fit; one more does not.
++  test-template-constant-attribute-limit
  ^-  tang
  =/  attrs=@t  '~'
  =/  left=@ud  63
  =.  attrs
    |-
    ?~  left  attrs
    $(left (dec left), attrs (rap 3 ~['(cons 0 ' attrs ')']))
  =/  prefix=@t  '(lam words (app (native raw-seal) (cons %el (cons '
  =/  suffix=@t  ' (app (native raw-seal) (cons %text "fixed"))))))'
  ;:  weld
    (check-template (rap 3 ~[prefix attrs suffix]) `['["el",14,["fixed"]]' ~])
    (check-template (rap 3 ~[prefix '(cons 0 ' attrs ')' suffix]) ~)
  ==
::  List preflight and descriptor limits remain failures of the complete
::  plan. They must not reset fuel and turn an oversized subtree into a hole.
++  test-template-list-and-descriptor-limits
  ^-  tang
  =/  values=value:jibb-js-template  [%atom 0]
  =/  left=@ud  128
  =.  values
    |-
    ?~  left  values
    $(left (dec left), values [%cell [%unknown ~] values])
  ?.  =(`& (proper-list:jibb-js-template values 128))
    ~[leaf+"128 known child-list cells did not fit preflight"]
  ?^  (proper-list:jibb-js-template [%cell [%unknown ~] values] 128)
    ~[leaf+"an oversized child list did not exhaust preflight"]
  =/  wrapper=value:jibb-js-template
    [%seal [%cell [%atom %el] [%cell [%atom 0] [%unknown ~]]]]
  =/  exact=(unit rendered:jibb-js-template)  (element:jibb-js-template wrapper 1 [2 ~])
  ?.  =(`['["div",{"class":"j-el"},[-1]]' [0 ~[15]]] exact)
    ~[leaf+"a fixed wrapper and child hole did not consume two descriptor nodes"]
  ?^  (element:jibb-js-template wrapper 1 [1 ~])
    ~[leaf+"descriptor exhaustion became an element hole"]
  =/  body=@t  'words'
  =/  depth=@ud  20
  =.  body
    |-
    ?~  depth  body
    $(depth (dec depth), body (rap 3 ~['(app (native raw-seal) (cons %el (cons ~ ' body ')))']))
  (check-template (rap 3 ~['(lam words ' body ')']) ~)
--
