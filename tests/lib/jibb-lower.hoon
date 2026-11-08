/+  jibb, jibb-core, jibb-lower, jibb-import, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  todo-sur  %txt  /my-app/sur/todo/hoon
/*  todo-action  %txt  /my-app/mar/todo-action/hoon
/*  todos  %txt  /my-app/mar/todos/hoon
/*  todo-update  %txt  /my-app/mar/todo-update/hoon
/*  todo-item  %txt  /my-app/mar/todo-item/hoon
/*  todo-api  %txt  /my-app/ui/api/todo/jibb
/*  todo-source  %txt  /my-app/ui/todo-list/jibb
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  mark-text
  |=  lines=wain
  ^-  @t
  (text (skip lines |=(line=@t =('/-' (end [3 2] line)))))
++  check
  |=  [at=path src=@t modules=jbundle:jibb]
  ^-  jlowering-result:jibb
  (check-jibb-file-for-lowering:jibb at src ~ ~ modules ~[at] ~ ~ ~ ~)
++  lower-source
  |=  [at=path src=@t]
  ^-  (each module:jibb-core @t)
  =/  built=jlowering-result:jibb  (check at src ~)
  ?:  ?=(%| -.built)  [%| message.p.built]
  (lower-checked-module:jibb-lower root.p.built)
++  test-core-path-direct
  ^-  tang
  =/  actual=path  (core-path:jibb-lower /tests/lower/basic/jibb)
  ?.  =(actual /tests/lower/basic)  ~[leaf+(spud actual)]
  ~
::
++  test-literals-cells-and-erasure
  ^-  tang
  =/  built=(each module:jibb-core @t)
    (lower-source /tests/lower/basic/jibb '++ value ^- [@ud [@t @tas]] [42 ["ok" %yes]]\0a')
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  expected=@t
    '(module tests/lower/basic (def value (cons 42 (cons "ok" %yes))))'
  ?.  =(expected (print-module:jibb-core p.built))
    ~[leaf+(trip (print-module:jibb-core p.built))]
  ~
++  expect-source
  |=  [src=@t expected=@t]
  ^-  tang
  =/  built=(each module:jibb-core @t)  (lower-source /tests/lower/case/jibb src)
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  actual=@t  (print-module:jibb-core p.built)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-gates-wings-edits-and-calls
  ^-  tang
  =/  src=@t
    '+$ msg @t\0a++ update |= [=msg m=[draft=@t count=@ud]]\0a  ++ local |= x=@t x\0a  [m(draft=(local msg) count=1) draft.m]\0a'
  =/  expected=@t
    '(module tests/lower/case (def update (lam _1 (let msg (slot 2 _1) (let m (slot 3 _1) (let local (lam x x) (cons (edit 3 (edit 2 m (app local msg)) 1) (slot 2 m))))))))'
  (expect-source src expected)
++  test-static-values-and-constructors
  ^-  tang
  =/  src=@t
    '+$ reply [%acked @ud]\0a++ constructor ^- $-(@ud reply) |=%acked\0a'
  =/  expected=@t
    '(module tests/lower/case (def constructor (lam _1 (cons %acked _1))))'
  (expect-source src expected)
++  test-loobean-match
  ^-  tang
  =/  src=@t  '++ choose |= b=? ?- b\0a  %.y 1\0a  %.n 0\0a'
  =/  expected=@t  '(module tests/lower/case (def choose (lam b (if b 1 0))))'
  (expect-source src expected)
++  test-union-match-and-source-once
  ^-  tang
  =/  src=@t
    '+$ choice\0a  [%left @t]\0a  [%right @ud]\0a++ identity |= c=choice c\0a++ render |= c=choice\0a  ?- (identity c)\0a    [%left t] t\0a    [%right n] "number"\0a'
  =/  expected=@t
    '(module tests/lower/case (def identity (lam c c)) (def render (lam c (let _1 (app identity c) (let _2 (slot 2 _1) (if (eq _2 %left) (let t (slot 3 _1) t) (let n (slot 3 _1) "number")))))))'
  (expect-source src expected)
++  test-top-level-mutual-recursion-module
  ^-  tang
  =/  src=@t
    '++ ping |= x=@ud (pong x)\0a++ pong |= x=@ud (ping x)\0a'
  =/  expected=@t
    '(module tests/lower/case (def ping (lam x (app pong x))) (def pong (lam x (app ping x))))'
  (expect-source src expected)
++  test-projection-source-once
  ^-  tang
  =/  src=@t  '++ exact |= x=[a=@t b=@p c=?] ^- [a=@t b=@p] (proj x)\0a'
  =/  expected=@t
    '(module tests/lower/case (def exact (lam x (let _1 x (cons (slot 2 _1) (slot 6 _1))))))'
  (expect-source src expected)
++  test-unavailable-printer-fails-closed
  ^-  tang
  =/  built=(each module:jibb-core @t)
    (lower-source /tests/lower/case/jibb '++ traced\0a  ~& 42\0a    "done"\0a')
  ?.  ?=(%| -.built)  ~[leaf+"numeric trace acquired a guessed printer"]
  ?.  =('printer native ID is unavailable for this checked type at 2:6' p.built)
    ~[leaf+(trip p.built)]
  ~
++  linker-fixture
  ^-  (each [root=checked-module:jibb cache=jlowering-cache:jibb] @t)
  =/  dep-at=path  /tests/lower/dep/jibb
  =/  root-at=path  /tests/lower/root/jibb
  =/  dep=@t
    '++ unused 99\0a++ base 40\0a++ shared |= x=@ud x\0a++ ping |= x=@ud (pong x)\0a++ pong |= x=@ud (ping x)\0a'
  =/  src=@t
    '/= dep /tests/lower/dep\0a++ unused-root !!\0a++ answer [base.dep (shared.dep 2)]\0a++ call (ping.dep 1)\0a'
  =/  built=jlowering-result:jibb
    (check root-at src ~[[dep-at dep]])
  ?:  ?=(%| -.built)  [%| message.p.built]
  [%& [root.p.built cache.p.built]]
++  test-linker-prunes-and-shares-dependencies
  ^-  tang
  =/  fixture=(each [root=checked-module:jibb cache=jlowering-cache:jibb] @t)  linker-fixture
  ?:  ?=(%| -.fixture)  ~[leaf+(trip p.fixture)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %answer root.p.fixture cache.p.fixture)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  expected=@t
    '(let tests/lower/dep:base 40 (let tests/lower/dep:shared (lam x x) (let answer (cons tests/lower/dep:base (app tests/lower/dep:shared 2)) answer)))'
  =/  actual=@t  (print-expr:jibb-core p.linked)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  =/  again=(each expr:jibb-core @t)
    (link-entry:jibb-lower %answer root.p.fixture cache.p.fixture)
  ?:  ?=(%| -.again)  ~[leaf+(trip p.again)]
  ?.  =(p.linked p.again)  ~[leaf+"linking was not deterministic"]
  =/  missing=(each expr:jibb-core @t)  (link-entry:jibb-lower %answer root.p.fixture ~)
  ?.  ?=(%| -.missing)  ~[leaf+"interface-only import recovery linked"]
  ?.  =('unresolved linked definition /tests/lower/dep/jibb:base' p.missing)
    ~[leaf+(trip p.missing)]
  ~
++  test-linker-mutual-recursion
  ^-  tang
  =/  fixture=(each [root=checked-module:jibb cache=jlowering-cache:jibb] @t)  linker-fixture
  ?:  ?=(%| -.fixture)  ~[leaf+(trip p.fixture)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %call root.p.fixture cache.p.fixture)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  expected=@t
    '(rec ((tests/lower/dep:ping (lam x (app tests/lower/dep:pong x))) (tests/lower/dep:pong (lam x (app tests/lower/dep:ping x)))) (let call (app tests/lower/dep:ping 1) call))'
  =/  actual=@t  (print-expr:jibb-core p.linked)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-linker-whole-module-name-order
  ^-  tang
  =/  fixture=(each [root=checked-module:jibb cache=jlowering-cache:jibb] @t)  linker-fixture
  ?:  ?=(%| -.fixture)  ~[leaf+(trip p.fixture)]
  =/  linked=(each expr:jibb-core @t)
    (link-module-value:jibb-lower /tests/lower/dep/jibb root.p.fixture cache.p.fixture)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  expected=@t
    '(let tests/lower/dep:unused 99 (let tests/lower/dep:base 40 (let tests/lower/dep:shared (lam x x) (rec ((tests/lower/dep:ping (lam x (app tests/lower/dep:pong x))) (tests/lower/dep:pong (lam x (app tests/lower/dep:ping x)))) (cons tests/lower/dep:base (cons tests/lower/dep:ping (cons tests/lower/dep:pong (cons tests/lower/dep:shared tests/lower/dep:unused))))))))'
  =/  actual=@t  (print-expr:jibb-core p.linked)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-source-whole-module-reference
  ^-  tang
  =/  dep-at=path  /tests/lower/whole-dep/jibb
  =/  root-at=path  /tests/lower/whole-root/jibb
  =/  modules=jbundle:jibb  ~[[dep-at '++ base 40\0a++ shared |= x=@ud x\0a']]
  =/  built=jlowering-result:jibb
    (check root-at '/= dep /tests/lower/whole-dep\0a++ whole dep\0a' modules)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  refs=(list lowering-reference:jibb)  references.root.p.built
  ?.  ?=([* ~] refs)  ~[leaf+"whole-module occurrence identity is missing"]
  ?.  =(definition.i.refs [%module dep-at ~[%base %shared]])
    ~[leaf+"whole-module checked identity differs"]
  =/  lowered=(each module:jibb-core @t)
    (lower-checked-module:jibb-lower root.p.built)
  ?:  ?=(%| -.lowered)  ~[leaf+(trip p.lowered)]
  =/  expected=@t
    '(module tests/lower/whole-root (def whole (cons tests/lower/whole-dep:base tests/lower/whole-dep:shared)))'
  ?.  =(expected (print-module:jibb-core p.lowered))
    ~[leaf+(trip (print-module:jibb-core p.lowered))]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %whole root.p.built cache.p.built)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  expected-linked=@t
    '(let tests/lower/whole-dep:base 40 (let tests/lower/whole-dep:shared (lam x x) (let whole (cons tests/lower/whole-dep:base tests/lower/whole-dep:shared) whole)))'
  ?.  =(expected-linked (print-expr:jibb-core p.linked))
    ~[leaf+(trip (print-expr:jibb-core p.linked))]
  ~
++  todo-reader-inputs
  ^-  [marks=imark-externals:jibb externals=iexternals:jibb]
  =/  todo=type  -:(ride -:!>(..zuse) (text todo-sur))
  =/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
  =/  ma=*  (read-mark:jibb-import %todo-action -:(ride subject (mark-text todo-action)))
  =/  mt=*  (read-mark:jibb-import %todos -:(ride subject (mark-text todos)))
  =/  mu=*  (read-mark:jibb-import %todo-update -:(ride subject (mark-text todo-update)))
  =/  mi=*  (read-mark:jibb-import %todo-item -:(ride subject (mark-text todo-item)))
  =/  marks=imark-externals:jibb
    ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi]]
  =/  item-input=*  (read-named:jibb-import %todo %item todo)
  [marks ~[[%todo %item item-input]]]
++  authenticated-test-native
  |=  definition=lowering-definition:jibb
  ^-  (unit term)
  ?.  ?=(%prelude -.definition)  ~
  ?.  =(at.definition /lib/jibb/prelude/jibb)  ~
  ?.  (lien `(list term)`~[%gth %lent %tuba %trip] |=(n=term =(n name.definition)))  ~
  `name.definition
++  authenticate-update-natives
  |=  root=checked-module:jibb
  ^-  checked-module:jibb
  =/  references=(list lowering-reference:jibb)
    %+  turn  references.root
    |=  reference=lowering-reference:jibb
    reference(native (authenticated-test-native definition.reference))
  root(references references)
++  tape-starts
  |=  [needle=tape hay=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =(i.needle i.hay)  $(needle t.needle, hay t.hay)
  |
++  tape-drop
  |=  [count=@ud hay=tape]
  ^-  tape
  ?:  |(=(0 count) ?=(~ hay))  hay
  $(count (dec count), hay t.hay)
++  tape-skip-to
  |=  [needle=tape hay=tape]
  ^-  tape
  ?~  hay  ~
  ?:  (tape-starts needle hay)  hay
  $(hay t.hay)
++  tape-take-to
  |=  [needle=tape hay=tape]
  ^-  tape
  =|  out=tape
  |-
  ?~  hay  (flop out)
  ?:  (tape-starts needle hay)  (flop out)
  $(hay t.hay, out [i.hay out])
++  tape-replace
  |=  [needle=tape replacement=tape hay=tape]
  ^-  @t
  =|  out=tape
  |-
  ?~  hay  (crip (flop out))
  ?:  (tape-starts needle hay)
    $(hay (tape-drop (lent needle) hay), out (weld (flop replacement) out))
  $(hay t.hay, out [i.hay out])
++  ordinary-doc-update
  ^-  @t
  =/  block=tape
    (tape-skip-to "++ update" (trip (text todo-source)))
  =/  hay=tape  (tape-take-to "\0a++ subs" block)
  =/  renamed=@t  (tape-replace "poke.todo" "todo-action.todo" hay)
  =/  added=@t
    (tape-replace "(todo-action.todo [%add draft.m] |=%acked)" "[%poke (todo-action.todo [%add draft.m]) |=%acked]" (trip renamed))
  =/  toggled=@t
    (tape-replace "(todo-action.todo [%toggle id] |=%acked)" "[%poke (todo-action.todo [%toggle id]) |=%acked]" (trip added))
  (tape-replace "++ update |= [=msg m=model]" "++ update ^- $-([msg model] [model (list (cmd msg))]) |= [=msg m=model]" (trip toggled))
++  test-doc-update-lowering-modulo-derived-import
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"real prelude did not prepare"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]  todo-reader-inputs
  =/  at=path  /tests/lower/todo-update/jibb
  =/  api-at=path  /tests/lower/todo-api/jibb
  =/  api=@t
    '+$ item [id=@ud done=? text=@t]\0a+$ poke\0a  [%add text=@t]\0a  [%toggle id=@ud]\0a++ todo-action |= action=poke ^- raw-poke !!\0a'
  =/  prefix=@t
    '/= todo /tests/lower/todo-api\0a+$ model [todos=(list item.todo) draft=@t error=(unit @t)]\0a+$ msg\0a  [%typed text=@t]\0a  %submit\0a  [%toggled id=@ud]\0a  [%got todos=(list item.todo)]\0a  [%acked err=(unit @t)]\0a'
  =/  src=@t  (rap 3 ~[prefix ordinary-doc-update])
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering:jibb at src externals.inputs marks.inputs ~[[api-at api]] ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  (authenticate-update-natives root.p.built)
  =/  lowered=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root)
  ?:  ?=(%| -.lowered)  ~[leaf+(trip p.lowered)]
  =/  updates=(list definition:jibb-core)
    (skim defs.p.lowered |=(d=definition:jibb-core =([%own %update] name.d)))
  ?.  ?=([* ~] updates)  ~[leaf+"lowered update definition is missing"]
  =/  actual=@t  (print-definition:jibb-core i.updates)
  =/  expected=@t
    '(def update (lam _1 (let msg (slot 2 _1) (let m (slot 3 _1) (if (cell? msg) (let _2 (slot 2 msg) (if (eq _2 %typed) (let t (slot 3 msg) (if (app (native gth) (cons (app (native lent) (app (native tuba) (app (native trip) t))) 80)) (cons (edit 7 (edit 6 m t) (cons ~ "Too long")) ~) (cons (edit 7 (edit 6 m t) ~) ~))) (if (eq _2 %toggled) (let id (slot 3 msg) (cons m (cons (cons %poke (cons (app tests/lower/todo-api:todo-action (cons %toggle id)) (lam _3 (cons %acked _3)))) ~))) (if (eq _2 %got) (let ts (slot 3 msg) (cons (edit 2 m ts) ~)) (let err (slot 3 msg) (cons (edit 7 m err) ~)))))) (cons (edit 6 m "") (cons (cons %poke (cons (app tests/lower/todo-api:todo-action (cons %add (slot 6 m))) (lam _4 (cons %acked _4)))) ~)))))))'
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-unchanged-todo-and-real-derived-api-lower
  ^-  tang
  =/  prepared=(unit iprelude-lowering:jibb)  prepared-for-lowering
  ?~  prepared  ~[leaf+"real prelude did not prepare for lowering"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]  todo-reader-inputs
  =/  api-at=path  /ui/api/todo/jibb
  =/  modules=jbundle:jibb  ~[[api-at (text todo-api)]]
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb /ui/todo-list/jibb (text todo-source) externals.inputs marks.inputs modules ~[/ui/todo-list/jibb] ~ u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  api=(unit checked-module:jibb)  (find-jlowering-cache:jibb api-at cache.p.built)
  ?~  api  ~[leaf+"real derived API published no checked artifact"]
  =/  api-core=(each module:jibb-core @t)  (lower-checked-module:jibb-lower u.api)
  ?:  ?=(%| -.api-core)  ~[leaf+(trip p.api-core)]
  =/  names=(list term)
    (murn defs.p.api-core |=(d=definition:jibb-core ?:(?=(%own -.name.d) `name.name.d ~)))
  ?.  (levy `(list term)`~[%todo-action %todos %changes %todo-by-id] |=(n=term (lien names |=(have=term =(n have)))))
    ~[leaf+(trip (print-module:jibb-core p.api-core))]
  =/  constructors=(list definition:jibb-core)
    (skim defs.p.api-core |=(d=definition:jibb-core =([%own %todo-action] name.d)))
  ?.  ?=([* ~] constructors)  ~[leaf+"derived mark constructor is missing"]
  =/  expected-constructor=@t
    '(def todo-action (lam _1 (cons %agent (cons %todo (cons %todo-action _1)))))'
  ?.  =(expected-constructor (print-definition:jibb-core i.constructors))
    ~[leaf+(trip (print-definition:jibb-core i.constructors))]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %update root.p.built cache.p.built)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  lowered=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root.p.built)
  ?:  ?=(%| -.lowered)  ~[leaf+(trip p.lowered)]
  =/  updates=(list definition:jibb-core)
    (skim defs.p.lowered |=(d=definition:jibb-core =([%own %update] name.d)))
  ?.  ?=([* ~] updates)  ~[leaf+"unchanged todo update did not lower"]
  =/  actual=@t  (print-definition:jibb-core i.updates)
  =/  derived-refs=(list lowering-reference:jibb)
    (skim references.root.p.built |=(r=lowering-reference:jibb &(?=(^ derived.r) ?=(%poke -.u.derived.r))))
  ?~  derived-refs  ~[leaf+"todo poke has no derived reference plan" (sell !>(references.root.p.built))]
  =/  expected=@t
    '(def update (lam _1 (let msg (slot 2 _1) (let m (slot 3 _1) (if (cell? msg) (let _2 (slot 2 msg) (if (eq _2 %typed) (let t (slot 3 msg) (if (app (native gth) (cons (app (native lent) (app (native tuba) (app (native trip) t))) 80)) (cons (edit 7 (edit 6 m t) (cons ~ "Too long")) ~) (cons (edit 7 (edit 6 m t) ~) ~))) (if (eq _2 %toggled) (let id (slot 3 msg) (cons m (cons (cons %poke (cons (app api/todo:todo-action (cons %toggle id)) (lam _3 (cons %acked _3)))) ~))) (if (eq _2 %got) (let ts (slot 3 msg) (cons (edit 2 m ts) ~)) (let err (slot 3 msg) (cons (edit 7 m err) ~)))))) (cons (edit 6 m "") (cons (cons %poke (cons (app api/todo:todo-action (cons %add (slot 6 m))) (lam _4 (cons %acked _4)))) ~)))))))'
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ?.  (tape-starts "(def update (lam _1" (trip actual))
    ~[leaf+(trip actual)]
  ~
++  test-derived-command-helper-as-value
  ^-  tang
  =/  prepared=(unit iprelude-lowering:jibb)  prepared-for-lowering
  ?~  prepared  ~[leaf+"real prelude did not prepare for lowering"]
  =/  inputs=[marks=imark-externals:jibb externals=iexternals:jibb]  todo-reader-inputs
  =/  api-at=path  /ui/api/todo/jibb
  =/  modules=jbundle:jibb  ~[[api-at (text todo-api)]]
  =/  src=@t  '/= todo /ui/api/todo\0a++ helper poke.todo\0a'
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb /tests/lower/poke-value/jibb src externals.inputs marks.inputs modules ~[/tests/lower/poke-value/jibb] ~ u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  lowered=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root.p.built)
  ?:  ?=(%| -.lowered)  ~[leaf+(trip p.lowered)]
  =/  helpers=(list definition:jibb-core)
    (skim defs.p.lowered |=(d=definition:jibb-core =([%own %helper] name.d)))
  ?.  ?=([* ~] helpers)  ~[leaf+"derived command helper did not lower"]
  =/  expected=@t
    '(def helper (lam _1 (cons %poke (cons (app api/todo:todo-action (slot 2 _1)) (slot 3 _1)))))'
  =/  actual=@t  (print-definition:jibb-core i.helpers)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-prelude-lists-units-paths-and-text-trace
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"real prelude did not prepare"]
  =/  at=path  /tests/lower/prelude-values/jibb
  =/  src=@t
    '++ describe |= xs=(list @ud)\0a  ?- xs\0a    ~ 0\0a    [x *] x\0a++ values |= t=@t\0a  ~& t\0a    [~[1 2] `t]\0a++ path /posts/~zod\0a'
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  lowered=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root.p.built)
  ?:  ?=(%| -.lowered)  ~[leaf+(trip p.lowered)]
  =/  actual=@t  (print-module:jibb-core p.lowered)
  =/  expected=@t
    '(module tests/lower/prelude-values (def describe (lam xs (if (cell? xs) (let x (slot 2 xs) x) 0))) (def values (lam t (trace t (cons (cons 1 (cons 2 ~)) (cons ~ t))))) (def path (cons ~.posts (cons ~.~zod ~))))'
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-local-mutual-recursion-source-order
  ^-  tang
  =/  src=@t
    '++ run |= x=@ud\0a  ++ even |= n=@ud (odd n)\0a  ++ odd |= n=@ud (even n)\0a  (even x)\0a'
  =/  expected=@t
    '(module tests/lower/case (def run (lam x (rec ((even (lam n (app odd n))) (odd (lam n (app even n)))) (app even x)))))'
  (expect-source src expected)
++  test-native-identity-is-explicit
  ^-  tang
  =/  prelude=ifile:jibb  *ifile:jibb
  =.  prelude
    prelude(values ~[[%forty [[%atom %ud] ~ ~]]], at /lib/jibb/prelude/jibb)
  =/  at=path  /tests/lower/native/jibb
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering:jibb at '++ answer forty\0a' ~ ~ ~ ~[at] ~[%forty] ~ ~ `prelude)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  =/  plain=(each module:jibb-core @t)  (lower-checked-module:jibb-lower root)
  ?:  ?=(%| -.plain)  ~[leaf+(trip p.plain)]
  ?.  =('(module tests/lower/native (def answer forty))' (print-module:jibb-core p.plain))
    ~[leaf+"unregistered reference did not remain a plain definition"]
  =/  references=(list lowering-reference:jibb)
    (turn references.root |=(r=lowering-reference:jibb r(native `%forty-native)))
  =/  registered=checked-module:jibb  root(references references)
  =/  native=(each module:jibb-core @t)  (lower-checked-module:jibb-lower registered)
  ?:  ?=(%| -.native)  ~[leaf+(trip p.native)]
  ?.  =('(module tests/lower/native (def answer (native forty-native)))' (print-module:jibb-core p.native))
    ~[leaf+"authenticated native identity was not emitted"]
  =/  unresolved=(each expr:jibb-core @t)  (link-entry:jibb-lower %answer root cache.p.built)
  ?.  ?=(%| -.unresolved)  ~[leaf+"unregistered prelude definition linked"]
  ~
++  test-projection-reordering-fails-closed
  ^-  tang
  =/  built=jlowering-result:jibb
    (check /tests/lower/reorder/jibb '++ exact ^- [a=@t b=@p] (proj [a="hi" b=~zod])\0a' ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  root=checked-module:jibb  root.p.built
  ?.  ?=([* ~] projections.root)  ~[leaf+"projection plan is missing"]
  =/  projection=lowering-projection:jibb  i.projections.root
  =/  changed=lowering-projection:jibb
    projection(plan plan.projection(steps (flop steps.plan.projection)))
  =/  lowered=(each module:jibb-core @t)
    (lower-checked-module:jibb-lower root(projections ~[changed]))
  ?.  ?=(%| -.lowered)  ~[leaf+"projection reorder was guessed"]
  ?.  =('projection field reordering is undecided; refusing to guess at 1:26' p.lowered)
    ~[leaf+(trip p.lowered)]
  ~
++  test-pair-lowers-from-checked-evidence
  ^-  tang
  =/  built=(each module:jibb-core @t)
    (lower-source /tests/lower/pair/jibb '++ pair ^- [@tas @ud] gap+42\0a')
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  expected=@t  '(module tests/lower/pair (def pair (cons %gap 42)))'
  ?.  =(expected (print-module:jibb-core p.built))
    ~[leaf+(trip (print-module:jibb-core p.built))]
  ~
++  test-unface-lowers-from-checked-evidence
  ^-  tang
  =/  built=(each module:jibb-core @t)
    (lower-source /tests/lower/unface/jibb '++ unfaced |= t=@t (unface [a=t])\0a')
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  expected=@t  '(module tests/lower/unface (def unfaced (lam t t)))'
  ?.  =(expected (print-module:jibb-core p.built))
    ~[leaf+(trip (print-module:jibb-core p.built))]
  ~
++  prepared-for-lowering
  ^-  (unit iprelude-lowering:jibb)
  (prepare-prelude-with-group-evidence-for-lowering:jibb prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] (bundle:jibb-prelude-fixture ~) evidence:jibb-prelude-fixture)
++  lower-with-real-prelude
  |=  [at=path src=@t]
  ^-  (each [root=checked-module:jibb cache=jlowering-cache:jibb core=module:jibb-core] @t)
  =/  prepared=(unit iprelude-lowering:jibb)  prepared-for-lowering
  ?~  prepared  [%| 'real prelude did not prepare for lowering']
  =/  prepared-paths=(list path)
    (turn cache.u.prepared |=(entry=[at=path artifact=checked-module:jibb] at.entry))
  ?.  ?=(^ (find-jlowering-cache:jibb /lib/jibb/prelude/jibb cache.u.prepared))
    [%| (crip "prepared cache lacks public prelude: {(scow %ud (lent prepared-paths))} entries")]
  ?.  ?=(^ (find-jlowering-cache:jibb /lib/jibb/internal/jibb cache.u.prepared))
    [%| 'prepared cache lacks private internal prelude']
  =/  built=jlowering-result:jibb
    (check-jibb-file-for-lowering-prepared:jibb at src ~ ~ ~ ~[at] ~ u.prepared)
  ?:  ?=(%| -.built)  [%| message.p.built]
  =/  lowered=(each module:jibb-core @t)
    (lower-checked-module:jibb-lower root.p.built)
  ?:  ?=(%| -.lowered)  lowered
  [%& [root.p.built cache.p.built p.lowered]]
++  test-authenticated-interpolation-and-printers
  ^-  tang
  =/  built=(each [root=checked-module:jibb cache=jlowering-cache:jibb core=module:jibb-core] @t)
    (lower-with-real-prelude /tests/lower/interpolation/jibb '++ greet |= day=@t "Since {day}"\0a++ traced\0a  ~& 42\0a    "done"\0a')
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  expected=@t
    '(module tests/lower/interpolation (def greet (lam day (app (native join) (cons "" (cons "Since " (cons day ~)))))) (def traced (trace (app (native scot) (cons %ud 42)) "done")))'
  =/  actual=@t  (print-module:jibb-core core.p.built)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ?.  ?=(^ (find-jlowering-cache:jibb /lib/jibb/prelude/jibb cache.p.built))
    ~[leaf+"public prelude checked artifact was not retained" (sell !>((turn cache.p.built |=(entry=[at=path artifact=checked-module:jibb] at.entry))))]
  ?.  ?=(^ (find-jlowering-cache:jibb /lib/jibb/internal/jibb cache.p.built))
    ~[leaf+"private prelude checked artifact was not retained"]
  ~
++  test-derived-pure-lowers-as-lambda
  ^-  tang
  =/  built=(each [root=checked-module:jibb cache=jlowering-cache:jibb core=module:jibb-core] @t)
    (lower-with-real-prelude /tests/lower/pure/jibb '++ answer (pure 42)\0a')
  ?:  ?=(%| -.built)  ~[leaf+(trip p.built)]
  =/  expected=@t
    '(module tests/lower/pure (def answer (let _1 42 (cons %pure _1))))'
  =/  actual=@t  (print-module:jibb-core core.p.built)
  ?.  =(expected actual)  ~[leaf+(trip actual)]
  ~
++  test-unregistered-interpolation-still-fails-closed
  ^-  tang
  =/  built=(each module:jibb-core @t)
    (lower-source /tests/lower/interpolation/jibb '++ greet |= day=@t "Since {day}"\0a')
  ?.  ?=(%| -.built)  ~[leaf+"interpolation acquired a guessed join native"]
  ?.  (tape-starts "interpolation requires an authenticated join native ID" (trip p.built))
    ~[leaf+(trip p.built)]
  ~
++  test-nested-wing-edit-axes
  ^-  tang
  =/  src=@t
    '++ nested |= m=[cart=[flag=? open=?] other=@ud]\0a  [m(open.cart=%.y) open.cart.m]\0a'
  =/  expected=@t
    '(module tests/lower/case (def nested (lam m (cons (edit 5 m %.y) (slot 5 m)))))'
  (expect-source src expected)
++  test-unused-local-remains-strict
  ^-  tang
  =/  expected=@t
    '(module tests/lower/case (def answer (let unused (crash) 42)))'
  (expect-source '++ answer\0a  ++ unused !!\0a  42\0a' expected)
++  test-linker-direct-recursion
  ^-  tang
  =/  built=jlowering-result:jibb
    (check /tests/lower/direct-rec/jibb '++ loop |= x=@ud (loop x)\0a' ~)
  ?:  ?=(%| -.built)  ~[leaf+(trip message.p.built)]
  =/  linked=(each expr:jibb-core @t)
    (link-entry:jibb-lower %loop root.p.built cache.p.built)
  ?:  ?=(%| -.linked)  ~[leaf+(trip p.linked)]
  =/  expected=@t  '(rec ((loop (lam x (app loop x)))) loop)'
  ?.  =(expected (print-expr:jibb-core p.linked))
    ~[leaf+(trip (print-expr:jibb-core p.linked))]
  ~
--
