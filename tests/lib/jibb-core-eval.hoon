::  Direct-AST tests for the independent Hoon Core reference interpreter.
::  No reader, printer, surface parser, checker, lowering, or backend is used.
/+  jibb-core
|%
++  empty-registry
  ^-  native-registry:jibb-core
  *(map name:jibb-core native:jibb-core)
::
++  own
  |=  n=@tas
  ^-  name:jibb-core
  [%own n]
::
++  lit
  |=  val=@
  ^-  expr:jibb-core
  [%lit [%ud val (scot %ud val)]]
::
++  var
  |=  n=name:jibb-core
  ^-  expr:jibb-core
  [%var n]
::
++  note
  |=  [message=@t body=expr:jibb-core]
  ^-  expr:jibb-core
  [%trace [%lit [%t message message]] body]
::
++  yes  (lit 0)
++  no   (lit 1)
::
++  inc-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  [[%atom +(val.v)] ~]
::
++  dec-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%atom -.v)  !!
  ?:  =(0 val.v)  !!
  [[%atom (dec val.v)] ~]
::
++  add-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%cell -.v)  !!
  ?.  ?=(%atom -.hed.v)  !!
  ?.  ?=(%atom -.tal.v)  !!
  [[%atom (add val.hed.v val.tal.v)] ~]
::
++  fail-native
  ^-  native:jibb-core
  |=  v=value:jibb-core
  !!
::
::  A higher-order native calls Core closures through the same evaluator and
::  explicit registry as an ordinary application.
++  apply-twice-native
  |=  registry=native-registry:jibb-core
  ^-  native:jibb-core
  |=  v=value:jibb-core
  ?.  ?=(%cell -.v)  !!
  =/  once=evaluation:jibb-core
    (apply-value:jibb-core hed.v tal.v registry)
  =/  twice=evaluation:jibb-core
    (apply-value:jibb-core hed.v val.once registry)
  [val.twice (weld traces.once traces.twice)]
::
++  registry
  ^-  native-registry:jibb-core
  =/  r=native-registry:jibb-core  empty-registry
  =.  r  (~(put by r) (own %inc) inc-native)
  =.  r  (~(put by r) (own %dec) dec-native)
  =.  r  (~(put by r) (own %add) add-native)
  =.  r  (~(put by r) (own %fail) fail-native)
  (~(put by r) (own %apply-twice) (apply-twice-native r))
::
++  ok
  |=  [e=expr:jibb-core expected=noun]
  ^-  ?
  =/  got=outcome:jibb-core  (run:jibb-core e registry)
  &(?=(%ok -.got) =(expected val.got))
::
++  crashes
  |=  e=expr:jibb-core
  ^-  ?
  =/  got=outcome:jibb-core  (run:jibb-core e registry)
  ?=(%crash -.got)
::
++  traced-ok
  |=  [e=expr:jibb-core expected=noun messages=(list @t)]
  ^-  ?
  =/  got=execution:jibb-core  (run-traced:jibb-core e registry)
  &(?=(%ok -.out.got) =(expected val.out.got) =(messages traces.got))
::
++  tail-expr
  |=  [steps=@ leaf=expr:jibb-core]
  ^-  expr:jibb-core
  ?:  =(0 steps)  leaf
  [%cons (lit steps) $(steps (dec steps))]
::
++  test-core-literals-names-and-cons
  ^-  tang
  =/  huge  340.282.366.920.938.463.463.374.607.431.768.211.456
  ?.  (ok (lit huge) huge)  ~[leaf+"literal lost arbitrary precision"]
  =/  x=name:jibb-core  (own %x)
  ?.  (ok [%let x (lit 40) (var x)] 40)  ~[leaf+"let/name returned the wrong value"]
  =/  generated=name:jibb-core  [%generated '_1']
  ?.  (ok [%let generated (lit 41) (var generated)] 41)
    ~[leaf+"generated name did not resolve"]
  =/  qualified=name:jibb-core  [%qualified /api/todo %action]
  ?.  (ok [%let qualified (lit 42) (var qualified)] 42)
    ~[leaf+"qualified name did not resolve"]
  ?.  (ok [%cons (lit 1) [%cons (lit 2) (lit 3)]] [1 2 3])
    ~[leaf+"cons returned the wrong cell"]
  ~
::
++  test-core-slot-and-edit
  ^-  tang
  =/  triple=expr:jibb-core  [%cons (lit 1) [%cons (lit 2) (lit 3)]]
  ?.  (ok [%slot 1 triple] [1 2 3])  ~[leaf+"slot 1 did not return the whole value"]
  ?.  (ok [%slot 2 triple] 1)  ~[leaf+"slot 2 did not select the head"]
  ?.  (ok [%slot 3 triple] [2 3])  ~[leaf+"slot 3 did not select the tail"]
  ?.  (ok [%slot 6 triple] 2)  ~[leaf+"slot 6 took the wrong path"]
  ?.  (ok [%slot 7 triple] 3)  ~[leaf+"slot 7 took the wrong path"]
  ?.  (ok [%edit 1 (lit 0) (lit 9)] 9)  ~[leaf+"edit 1 did not replace the whole value"]
  ?.  (ok [%edit 2 triple (lit 9)] [9 2 3])  ~[leaf+"edit 2 returned the wrong cell"]
  ?.  (ok [%edit 3 triple (lit 9)] [1 9])  ~[leaf+"edit 3 returned the wrong cell"]
  ?.  (ok [%edit 6 triple (lit 9)] [1 9 3])  ~[leaf+"edit 6 returned the wrong cell"]
  ?.  (ok [%edit 7 triple (lit 9)] [1 2 9])  ~[leaf+"edit 7 returned the wrong cell"]
  ~
::
++  test-core-cell-eq-if-and-let
  ^-  tang
  ?.  (ok [%cell (lit 0)] 1)  ~[leaf+"cell? accepted an atom as a cell"]
  ?.  (ok [%cell [%cons (lit 0) (lit 1)]] 0)  ~[leaf+"cell? rejected a cell"]
  ?.  (ok [%eq (lit 9) (lit 9)] 0)  ~[leaf+"eq rejected equal atoms"]
  ?.  (ok [%eq (lit 9) (lit 10)] 1)  ~[leaf+"eq accepted unequal atoms"]
  =/  left=expr:jibb-core  [%cons (lit 1) [%cons (lit 2) (lit 3)]]
  =/  same=expr:jibb-core  [%cons (lit 1) [%cons (lit 2) (lit 3)]]
  =/  different=expr:jibb-core  [%cons (lit 1) [%cons (lit 3) (lit 2)]]
  ?.  (ok [%eq left same] 0)  ~[leaf+"eq was not structural"]
  ?.  (ok [%eq left different] 1)  ~[leaf+"eq missed a nested difference"]
  ?.  (ok [%if yes (lit 42) [%crash ~]] 42)  ~[leaf+"yes branch was not selected"]
  ?.  (ok [%if no [%crash ~] (lit 42)] 42)  ~[leaf+"no branch was not selected"]
  ?.  (ok [%if [%eq (lit 1) (lit 1)] (lit 1) (lit 2)] 1)
    ~[leaf+"computed loobean test returned the wrong branch"]
  =/  x=name:jibb-core  (own %unused)
  ?.  (ok [%let x (lit 1) (lit 42)] 42)  ~[leaf+"ordinary unused let failed"]
  ~
::
++  test-core-closures-and-higher-order-calls
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  y=name:jibb-core  (own %y)
  =/  f=name:jibb-core  (own %f)
  ?.  (ok [%app [%lam x (var x)] (lit 42)] 42)  ~[leaf+"identity application failed"]
  =/  increment=expr:jibb-core
    [%lam x [%app [%native (own %inc)] (var x)]]
  ?.  (ok [%app [%lam f [%app (var f) (lit 41)]] increment] 42)
    ~[leaf+"higher-order Core call failed"]
  =/  closure=expr:jibb-core
    :*  %let  x  (lit 40)
        [%lam y [%app [%native (own %add)] [%cons (var x) (var y)]]]
    ==
  ?.  (ok [%app closure (lit 2)] 42)  ~[leaf+"lexical closure lost captured state"]
  ?.  (ok [%app [%app [%lam x [%lam y [%app [%native (own %add)] [%cons (var x) (var y)]]]] (lit 40)] (lit 2)] 42)
    ~[leaf+"returned closure lost its lexical environment"]
  ?.  (ok [%app [%slot 2 [%cons increment (lit 0)]] (lit 41)] 42)
    ~[leaf+"function inside a cell could not be projected and called"]
  ?.  (ok [%cell [%cons increment (lit 0)]] 0)
    ~[leaf+"a cell containing a function was rejected as a container"]
  ?.  (ok [%slot 3 [%edit 3 [%cons increment (lit 0)] (lit 42)]] 42)
    ~[leaf+"edit rejected a cell containing a function"]
  ~
::
++  test-core-recursion
  ^-  tang
  =/  n=name:jibb-core  (own %n)
  =/  loop=name:jibb-core  (own %loop)
  =/  dec-n=expr:jibb-core  [%app [%native (own %dec)] (var n)]
  =/  countdown-body=expr:jibb-core
    [%if [%eq (var n) (lit 0)] (lit 42) [%app (var loop) dec-n]]
  =/  countdown=expr:jibb-core
    [%rec ~[[loop [%lam n countdown-body]]] [%app (var loop) (lit 100)]]
  ?.  (ok countdown 42)  ~[leaf+"self recursion returned the wrong result"]
  =/  even=name:jibb-core  (own %even)
  =/  odd=name:jibb-core  (own %odd)
  =/  even-body=expr:jibb-core
    [%if [%eq (var n) (lit 0)] yes [%app (var odd) dec-n]]
  =/  odd-body=expr:jibb-core
    [%if [%eq (var n) (lit 0)] no [%app (var even) dec-n]]
  =/  arms=(list rec-arm:jibb-core)
    ~[[even [%lam n even-body]] [odd [%lam n odd-body]]]
  =/  mutual=expr:jibb-core
    [%rec arms [%cons [%app (var even) (lit 10)] [%cons [%app (var odd) (lit 10)] [%cons [%app (var even) (lit 11)] [%app (var odd) (lit 11)]]]]]
  ?.  (ok mutual [0 1 1 0])  ~[leaf+"mutual recursion returned the wrong loobeans"]
  =/  projected=expr:jibb-core
    [%rec ~[[loop [%lam n countdown-body]]] [%app [%slot 2 [%cons (var loop) (lit 0)]] (lit 5)]]
  ?.  (ok projected 42)  ~[leaf+"recursive closure in a cell failed"]
  ~
::
++  test-core-explicit-native-registry
  ^-  tang
  ?.  (ok [%app [%native (own %inc)] (lit 41)] 42)  ~[leaf+"registered native returned the wrong value"]
  =/  huge  340.282.366.920.938.463.463.374.607.431.768.211.456
  ?.  (ok [%app [%native (own %add)] [%cons (lit huge) (lit 1)]] (add huge 1))
    ~[leaf+"native arithmetic lost arbitrary precision"]
  =/  missing=expr:jibb-core  [%app [%native (own %inc)] (lit 1)]
  =/  missing-result=outcome:jibb-core  (run:jibb-core missing empty-registry)
  ?.  ?=(%crash -.missing-result)
    ~[leaf+"native spelling manufactured authentication"]
  =/  lookalike=expr:jibb-core  [%native [%qualified /prelude %inc]]
  ?.  (crashes lookalike)  ~[leaf+"qualified lookalike native was authenticated"]
  ?.  (crashes [%native (own %not-registered)])  ~[leaf+"unknown native did not fail closed"]
  ?.  (crashes [%app [%native (own %fail)] (lit 1)])  ~[leaf+"native failure escaped the crash runner"]
  ~
::
++  test-core-higher-order-native-callback
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  callback=expr:jibb-core
    [%lam x [%app [%native (own %inc)] (var x)]]
  =/  e=expr:jibb-core
    [%app [%native (own %apply-twice)] [%cons callback (lit 40)]]
  ?.  (ok e 42)  ~[leaf+"higher-order native did not call its Core callback twice"]
  =/  captured=name:jibb-core  (own %captured)
  =/  add-captured=expr:jibb-core
    :*  %let  captured  (lit 1)
        [%lam x [%app [%native (own %add)] [%cons (var x) (var captured)]]]
    ==
  =/  with-closure=expr:jibb-core
    [%app [%native (own %apply-twice)] [%cons add-captured (lit 40)]]
  ?.  (ok with-closure 42)  ~[leaf+"native callback lost its lexical closure"]
  =/  traced-callback=expr:jibb-core
    [%lam x (note 'callback' [%app [%native (own %inc)] (var x)])]
  =/  traced=expr:jibb-core
    [%app [%native (own %apply-twice)] [%cons traced-callback (lit 40)]]
  ?.  (traced-ok traced 42 ~['callback' 'callback'])
    ~[leaf+"native callback traces were lost or reordered"]
  ~
::
++  test-core-strictness-and-lazy-if
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  strict-crashes=(list expr:jibb-core)
    :~  [%let x [%crash ~] (lit 42)]
        [%app [%lam x (lit 42)] [%crash ~]]
        [%app [%crash ~] (lit 42)]
        [%cons [%crash ~] (lit 1)]
        [%cons (lit 1) [%crash ~]]
        [%slot 1 [%crash ~]]
        [%edit 1 [%crash ~] (lit 1)]
        [%edit 1 (lit 1) [%crash ~]]
        [%cell [%crash ~]]
        [%eq [%crash ~] (lit 1)]
        [%eq (lit 1) [%crash ~]]
        [%trace [%crash ~] (lit 42)]
        [%if [%crash ~] (lit 1) (lit 2)]
    ==
  |-
  ?~  strict-crashes  ~
  ?.  (crashes i.strict-crashes)  ~[leaf+"strict expression did not evaluate a crashing part"]
  $(strict-crashes t.strict-crashes)
::
++  test-core-text-evaluation-order
  ^-  tang
  ?.  (traced-ok [%cons (note 'head' (lit 1)) (note 'tail' (lit 2))] [1 2] ~['head' 'tail'])
    ~[leaf+"cons was not evaluated head then tail"]
  ?.  (traced-ok [%edit 2 (note 'target' [%cons (lit 1) (lit 2)]) (note 'replacement' (lit 9))] [9 2] ~['target' 'replacement'])
    ~[leaf+"edit was not evaluated target then replacement"]
  ?.  (traced-ok [%eq (note 'left' (lit 1)) (note 'right' (lit 1))] 0 ~['left' 'right'])
    ~[leaf+"eq was not evaluated left then right"]
  =/  x=name:jibb-core  (own %x)
  ?.  (traced-ok [%let x (note 'value' (lit 40)) (note 'body' (var x))] 40 ~['value' 'body'])
    ~[leaf+"let was not evaluated value then body"]
  =/  call=expr:jibb-core
    [%app (note 'function' [%lam x (note 'call-body' (var x))]) (note 'sample' (lit 9))]
  ?.  (traced-ok call 9 ~['function' 'sample' 'call-body'])
    ~[leaf+"application was not function, sample, then body"]
  ?.  (traced-ok [%if (note 'test' yes) (note 'selected' (lit 42)) [%crash ~]] 42 ~['test' 'selected'])
    ~[leaf+"if did not evaluate only test then selected branch"]
  ?.  (traced-ok [%if (note 'test' no) [%crash ~] (note 'selected' (lit 42))] 42 ~['test' 'selected'])
    ~[leaf+"lazy no branch was not selected correctly"]
  ~
::
++  test-core-invalid-axes-tests-and-applications
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  pair=expr:jibb-core  [%cons (lit 1) (lit 2)]
  =/  invalid=(list expr:jibb-core)
    :~  [%slot 0 pair]
        [%slot 2 (lit 0)]
        [%slot 4 pair]
        [%edit 0 pair (lit 9)]
        [%edit 2 (lit 0) (lit 9)]
        [%edit 4 pair (lit 9)]
        [%if (lit 2) (lit 1) (lit 2)]
        [%if pair (lit 1) (lit 2)]
        [%if [%lam x (var x)] (lit 1) (lit 2)]
        [%app (lit 0) (lit 1)]
        [%app pair (lit 1)]
        [%var (own %unbound)]
        [%rec ~[[(own %bad) (lit 1)]] (lit 0)]
        [%trace pair (lit 0)]
        [%crash ~]
    ==
  |-
  ?~  invalid  ~
  ?.  (crashes i.invalid)  ~[leaf+"invalid runtime operation did not crash"]
  $(invalid t.invalid)
::
++  test-core-functions-are-not-nouns
  ^-  tang
  =/  x=name:jibb-core  (own %x)
  =/  fun=expr:jibb-core  [%lam x (var x)]
  =/  fun-cell=expr:jibb-core  [%cons fun (lit 0)]
  =/  invalid=(list expr:jibb-core)
    :~  fun
        [%native (own %inc)]
        fun-cell
        [%cell fun]
        [%cell [%native (own %inc)]]
        [%eq fun fun]
        [%eq fun-cell fun-cell]
        [%eq (lit 0) fun-cell]
        [%slot 1 fun]
        [%slot 1 [%native (own %inc)]]
        [%edit 1 fun (lit 0)]
        [%edit 1 [%native (own %inc)] (lit 0)]
    ==
  |-
  ?~  invalid  ~
  ?.  (crashes i.invalid)  ~[leaf+"function was accepted as a noun"]
  $(invalid t.invalid)
::
++  test-core-arbitrary-precision-axes
  ^-  tang
  ::  Sixty-five one bits mean sixty-four tail steps after the leading bit.
  =/  axis=@  0x1.ffff.ffff.ffff.ffff
  =/  deep=expr:jibb-core  (tail-expr 64 (lit 42))
  ?.  (ok [%slot axis deep] 42)  ~[leaf+"large slot axis was truncated"]
  ?.  (ok [%slot axis [%edit axis deep (lit 99)]] 99)  ~[leaf+"large edit axis was truncated"]
  ~
::
++  test-core-trace-smoke
  ^-  tang
  =/  nested=expr:jibb-core  (note 'first' (note 'second' (lit 9)))
  ?.  (traced-ok nested 9 ~['first' 'second'])
    ~[leaf+"trace output did not precede the body's result"]
  =/  message-order=expr:jibb-core
    [%trace (note 'message' (lit 'outer')) (note 'body' (lit 7))]
  ?.  (traced-ok message-order 7 ~['message' 'outer' 'body'])
    ~[leaf+"trace message/body evaluation order was wrong"]
  ?.  (crashes (note 'before' [%crash ~]))  ~[leaf+"crashing trace body did not crash"]
  ~
--
