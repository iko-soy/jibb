::  /lib/jibb-core.hoon: independent Core AST and reference interpreter
::
::  API
::    +evaluate-env  [expr environment native-registry]  evaluation
::    +evaluate      [expr native-registry]              evaluation
::    +apply-value   [value value native-registry]       evaluation
::    +run-traced    [expr native-registry]              execution
::    +run           [expr native-registry]              outcome
::
::  Functions are values and may occur in cells, but are not nouns. Recursive
::  environments are finite frames: looking up a recursive arm makes a closure
::  over a freshly assembled frame for its group. Native lookup uses only the
::  explicit registry supplied by the caller.
::
|%
+$  literal  [aura=@ta val=@ txt=@t]
+$  name
  $~  [%own %x]
  $%  [%own name=@tas]
      [%qualified at=path name=@tas]
      [%generated name=@t]
  ==
+$  expr
  $~  [%lit [%ud 0 '0']]
  $%  [%lit lit=literal]
      [%var name=name]
      [%cons hed=expr tal=expr]
      [%slot axis=@ body=expr]
      [%edit axis=@ body=expr value=expr]
      [%cell body=expr]
      [%eq left=expr right=expr]
      [%if test=expr yes=expr no=expr]
      [%let name=name value=expr body=expr]
      [%rec arms=(list rec-arm) body=expr]
      [%lam sample=name body=expr]
      [%app fun=expr sample=expr]
      [%native name=name]
      [%crash ~]
      [%trace message=expr body=expr]
  ==
+$  rec-arm  [name=name fun=expr]
+$  value
  $~  [%atom 0]
  $%  [%atom val=@]
      [%cell hed=value tal=value]
      [%closure sample=name body=expr env=environment]
      [%native name=name run=native]
  ==
+$  native  $-(value evaluation)
+$  native-registry  (map name native)
+$  binding
  $~  [%value [%own %x] [%atom 0]]
  $%  [%value name=name val=value]
      [%recursive name=name sample=name body=expr arms=(list rec-arm) parent=environment]
  ==
+$  environment  (list binding)
+$  evaluation  [val=value traces=(list @t)]
+$  outcome
  $~  [%crash ~]
  $%  [%ok val=noun]
      [%crash ~]
  ==
+$  execution  [out=outcome traces=(list @t)]
::
::  Convert a complete value to a noun, rejecting functions at any depth.
::
++  value-noun
  |=  v=value
  ^-  noun
  ?-  -.v
    %atom                val.v
    %cell                [$(v hed.v) $(v tal.v)]
    ?(%closure %native)  !!
  ==
::
::  Nock axes are arbitrary-precision atoms. cap/mas consume one path bit per
::  step rather than converting an axis to a machine integer.
::
++  slot-inner
  |=  [axis=@ v=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  =(1 axis)  v
  ?.  ?=(%cell -.v)  !!
  ?-  (cap axis)
    %2  $(axis (mas axis), v hed.v)
    %3  $(axis (mas axis), v tal.v)
  ==
::
++  slot-value
  |=  [axis=@ v=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  ?=(%closure -.v)  !!
  ?:  ?=(%native -.v)  !!
  (slot-inner axis v)
::
++  edit-value
  |=  [axis=@ old=value new=value]
  ^-  value
  ?:  =(0 axis)  !!
  ?:  ?=(%closure -.old)  !!
  ?:  ?=(%native -.old)  !!
  ?:  =(1 axis)  new
  ?.  ?=(%cell -.old)  !!
  ?-  (cap axis)
    %2  [%cell $(axis (mas axis), old hed.old) tal.old]
    %3  [%cell hed.old $(axis (mas axis), old tal.old)]
  ==
::
++  lookup
  |=  [n=name env=environment]
  ^-  value
  ?~  env  !!
  ?.  =(n name.i.env)  $(env t.env)
  ?-  -.i.env
    %value      val.i.env
    %recursive  [%closure sample.i.env body.i.env (rec-env arms.i.env parent.i.env)]
  ==
::
++  rec-env
  |=  [arms=(list rec-arm) parent=environment]
  ^-  environment
  =/  made=(list binding)
    %+  turn  arms
    |=  arm=rec-arm
    ?>  ?=(%lam -.fun.arm)
    [%recursive name.arm sample.fun.arm body.fun.arm arms parent]
  (weld made parent)
::
++  apply-value
  |=  [fun=value sample=value registry=native-registry]
  ^-  evaluation
  ?-  -.fun
    ?(%atom %cell)  !!
    %closure
      (evaluate-env body.fun [[%value sample.fun sample] env.fun] registry)
    %native
      (run.fun sample)
  ==
::
++  evaluate-env
  |=  [e=expr env=environment registry=native-registry]
  ^-  evaluation
  ?-  -.e
    %lit   [[%atom val.lit.e] ~]
    %var   [(lookup name.e env) ~]
    %cons
      =/  hed  (evaluate-env hed.e env registry)
      =/  tal  (evaluate-env tal.e env registry)
      [[%cell val.hed val.tal] (weld traces.hed traces.tal)]
    %slot
      =/  body  (evaluate-env body.e env registry)
      [(slot-value axis.e val.body) traces.body]
    %edit
      =/  body  (evaluate-env body.e env registry)
      =/  val  (evaluate-env value.e env registry)
      [(edit-value axis.e val.body val.val) (weld traces.body traces.val)]
    %cell
      =/  body  (evaluate-env body.e env registry)
      ?:  ?=(%closure -.val.body)  !!
      ?:  ?=(%native -.val.body)  !!
      [[%atom ?:(?=(%cell -.val.body) 0 1)] traces.body]
    %eq
      =/  left  (evaluate-env left.e env registry)
      =/  right  (evaluate-env right.e env registry)
      =/  same=?  =((value-noun val.left) (value-noun val.right))
      [[%atom ?:(same 0 1)] (weld traces.left traces.right)]
    %if
      =/  test  (evaluate-env test.e env registry)
      ?.  ?=(%atom -.val.test)  !!
      ?.  |(=(0 val.val.test) =(1 val.val.test))  !!
      =/  branch=expr  ?:(=(0 val.val.test) yes.e no.e)
      =/  result  (evaluate-env branch env registry)
      result(traces (weld traces.test traces.result))
    %let
      =/  val  (evaluate-env value.e env registry)
      =/  body  (evaluate-env body.e [[%value name.e val.val] env] registry)
      body(traces (weld traces.val traces.body))
    %rec
      (evaluate-env body.e (rec-env arms.e env) registry)
    %lam
      [[%closure sample.e body.e env] ~]
    %app
      =/  fun  (evaluate-env fun.e env registry)
      =/  sample  (evaluate-env sample.e env registry)
      =/  called  (apply-value val.fun val.sample registry)
      called(traces (weld (weld traces.fun traces.sample) traces.called))
    %native
      =/  found  (~(get by registry) name.e)
      ?~  found  !!
      [[%native name.e u.found] ~]
    %crash
      !!
    %trace
      =/  message  (evaluate-env message.e env registry)
      ?.  ?=(%atom -.val.message)  !!
      ~&  val.val.message
      =/  body  (evaluate-env body.e env registry)
      body(traces (weld traces.message [val.val.message traces.body]))
  ==
::
++  evaluate
  |=  [e=expr registry=native-registry]
  ^-  evaluation
  (evaluate-env e ~ registry)
::
::  The sole trap is outside both evaluation and canonical noun conversion.
::  A crash in either phase has the same canonical result.
::
++  run-traced
  |=  [e=expr registry=native-registry]
  ^-  execution
  =/  tried=(each [val=noun traces=(list @t)] tang)
    %-  mule
    |.
    =/  got=evaluation  (evaluate e registry)
    [(value-noun val.got) traces.got]
  ?:  ?=(%| -.tried)  [[%crash ~] ~]
  [[%ok val.p.tried] traces.p.tried]
::
++  run
  |=  [e=expr registry=native-registry]
  ^-  outcome
  out:(run-traced e registry)
--
