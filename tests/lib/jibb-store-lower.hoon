/+  jibb, jibb-core, jibb-lower, jibb-nock, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  cart-source  %txt  /my-app/ui/stores/cart/jibb
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
::
++  prepared
  ^-  (unit iprelude-lowering:jibb)
  (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
::
++  cart-core
  ^-  (each module:jibb-core @t)
  =/  made=(unit iprelude-lowering:jibb)  prepared
  ?~  made  [%| 'prelude did not prepare']
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb /ui/stores/cart/jibb (text cart-source) ~ ~ ~ ~[/ui/stores/cart/jibb] ~ u.made)
  ?:  ?=(%| -.built)  [%| message.p.built]
  (lower-checked-module:jibb-lower root.p.built)
::
++  definition-named
  |=  [name=term core=module:jibb-core]
  ^-  (unit expr:jibb-core)
  =/  remaining=(list definition:jibb-core)  defs.core
  |-
  ?~  remaining  ~
  ?:  =([%own name] name.i.remaining)  `value.i.remaining
  $(remaining t.remaining)
::
++  term-expr
  |=  name=term
  ^-  expr:jibb-core
  [%lit [%tas name (cat 3 '%' name)]]
::
++  text-expr
  |=  text=@t
  ^-  expr:jibb-core
  [%lit [%t text text]]
::
++  null-expr
  ^-  expr:jibb-core
  [%lit [%n 0 '~']]
::
++  empty-registry
  ^-  (map name:jibb-core native:jibb-core)
  *(map name:jibb-core native:jibb-core)
::
++  agrees
  |=  [got=expr:jibb-core expected=expr:jibb-core]
  ^-  ?
  =/  actual=outcome:jibb-core  (run:jibb-core got empty-registry)
  =/  wanted=outcome:jibb-core  (run:jibb-core expected empty-registry)
  =(actual wanted)
::
++  empty-nock-registry
  ^-  (map name:jibb-core noun)
  *(map name:jibb-core noun)
::
++  agrees-nock
  |=  [got=expr:jibb-core expected=expr:jibb-core]
  ^-  ?
  =/  actual=outcome:jibb-core  (run:jibb-nock got empty-nock-registry)
  =/  wanted=outcome:jibb-core  (run:jibb-core expected empty-registry)
  =(actual wanted)
::
++  test-store-derived-shapes
  ^-  tang
  =/  built=(each module:jibb-core @t)  cart-core
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  state=(unit expr:jibb-core)  (definition-named %state p.built)
  ?~  state  ~[leaf+"derived store state is missing"]
  =/  state-expected=@t
    '(def state (lam _1 (cons %store (cons "stores/cart" (cons %state (lam _2 (let _3 (slot 3 _2) (cons _3 (app _1 _3)))))))))'
  ?.  =(state-expected (print-definition:jibb-core [[%own %state] u.state]))
    ~[leaf+(trip (print-definition:jibb-core [[%own %state] u.state]))]
  =/  poke=(unit expr:jibb-core)  (definition-named %poke p.built)
  ?~  poke  ~[leaf+"derived store poke is missing"]
  =/  poke-expected=@t
    '(def poke (lam _1 (cons %poke (cons (cons %store (cons "stores/cart" (cons %poke (slot 2 _1)))) (slot 3 _1)))))'
  ?.  =(poke-expected (print-definition:jibb-core [[%own %poke] u.poke]))
    ~[leaf+(trip (print-definition:jibb-core [[%own %poke] u.poke]))]
  ~
::
++  test-store-state-full-fact
  ^-  tang
  =/  built=(each module:jibb-core @t)  cart-core
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  state=(unit expr:jibb-core)  (definition-named %state p.built)
  ?~  state  ~[leaf+"derived store state is missing"]
  =/  reply=expr:jibb-core
    [%lam [%own %reply] [%cons (term-expr %got) [%var [%own %reply]]]]
  =/  ask=expr:jibb-core  [%app u.state reply]
  =/  received=expr:jibb-core
    [%app [%slot 15 ask] [%cons null-expr (text-expr 'full')]]
  =/  expected=expr:jibb-core
    [%cons (text-expr 'full') [%cons (term-expr %got) (text-expr 'full')]]
  ?.  (agrees-nock received expected)
    ~[leaf+"initial full store fact did not reach the reply with its state" (sell !>((run:jibb-core received empty-registry)))]
  ~
::
++  test-store-poke-envelope-and-reply
  ^-  tang
  =/  built=(each module:jibb-core @t)  cart-core
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  poke=(unit expr:jibb-core)  (definition-named %poke p.built)
  ?~  poke  ~[leaf+"derived store poke is missing"]
  =/  reply=expr:jibb-core
    [%lam [%own %error] [%cons (term-expr %acked) [%var [%own %error]]]]
  =/  command=expr:jibb-core
    [%app u.poke [%cons (term-expr %toggle) reply]]
  =/  raw=expr:jibb-core  [%slot 6 command]
  =/  expected-raw=expr:jibb-core
    [%cons (term-expr %store) [%cons (text-expr 'stores/cart') [%cons (term-expr %poke) (term-expr %toggle)]]]
  =/  evaluated=evaluation:jibb-core  (evaluate:jibb-core command empty-registry)
  ?.  (agrees-nock raw expected-raw)
    ~[leaf+"store poke has the wrong raw envelope" (sell !>(val.evaluated))]
  =/  answered=expr:jibb-core  [%app [%slot 7 command] null-expr]
  =/  expected-answer=expr:jibb-core  [%cons (term-expr %acked) null-expr]
  ?.  (agrees answered expected-answer)
    ~[leaf+"store poke reply did not receive its error"]
  ~
--
