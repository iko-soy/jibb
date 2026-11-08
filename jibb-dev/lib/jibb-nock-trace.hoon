::  /lib/jibb-nock-trace.hoon: test-oriented Nock execution with slog traces
::
::  API
::    +execute-traced  [subject=noun formula=noun]  execution:jibb-core
::    +run-traced      [expr native-registry]       execution:jibb-core
::
::  This generic evaluator is intentionally separate from the production
::  emitter and raw mock runner. It retains completed slog messages on crashes.
::
/+  jibb-core, jibb-nock, jibb-nock-checked
|%
++  decode-slog-clue
  |=  clue=noun
  ^-  (unit @t)
  ?@  clue  ~
  ?^  -.clue  ~
  ?@  +.clue  ~
  ?.  =(%leaf -.+.clue)  ~
  =|  chars=(list @)
  =/  rest=noun  +.+.clue
  |-
  ^-  (unit @t)
  ?~  rest  `(crip (flop chars))
  ?@  rest  ~
  ?^  -.rest  ~
  ?.  (lth -.rest 256)  ~
  $(rest +.rest, chars [-.rest chars])
::
++  evaluate-traced  !.
  |=  [subject=noun formula=noun]
  =/  trace-printer=noun
    =/  printed=noun
      %-  emit:jibb-nock
      :_  ~
      [%trace [%lit [%ud 0 '0']] [%lit [%ud 0 '0']]]
    =/  hint=noun
      =/  result  (mock [printed [0 13]] |=(^ ~))
      ?>(?=(%0 -.result) p.result)
    =/  result  (mock [hint [0 63]] |=(^ ~))
    ?>(?=(%0 -.result) p.result)
  =|  traces=(list @t)
  |^  ^-  execution:jibb-core
      ?+  formula  [[%crash ~] traces]
          [^ *]
        =/  head=execution:jibb-core  $(formula -.formula)
        ?.  ?=(%ok -.out.head)  head
        =/  tail=execution:jibb-core
          $(formula +.formula, traces traces.head)
        ?.  ?=(%ok -.out.tail)  tail
        [[%ok val.out.head val.out.tail] traces.tail]
      ::
          [%0 axis=@]
        =/  part  (frag axis.formula subject)
        ?~  part  [[%crash ~] traces]
        [[%ok u.part] traces]
      ::
          [%1 constant=*]
        [[%ok constant.formula] traces]
      ::
          [%2 subject=* formula=*]
        =/  new-subject=execution:jibb-core  $(formula subject.formula)
        ?.  ?=(%ok -.out.new-subject)  new-subject
        =/  new-formula=execution:jibb-core
          $(formula formula.formula, traces traces.new-subject)
        ?.  ?=(%ok -.out.new-formula)  new-formula
        %=  $
          subject  val.out.new-subject
          formula  val.out.new-formula
          traces   traces.new-formula
        ==
      ::
          [%3 argument=*]
        =/  argument=execution:jibb-core  $(formula argument.formula)
        ?.  ?=(%ok -.out.argument)  argument
        [[%ok .?(val.out.argument)] traces.argument]
      ::
          [%4 argument=*]
        =/  argument=execution:jibb-core  $(formula argument.formula)
        ?.  ?=(%ok -.out.argument)  argument
        ?^  val.out.argument  [[%crash ~] traces.argument]
        [[%ok .+(val.out.argument)] traces.argument]
      ::
          [%5 a=* b=*]
        =/  a=execution:jibb-core  $(formula a.formula)
        ?.  ?=(%ok -.out.a)  a
        =/  b=execution:jibb-core
          $(formula b.formula, traces traces.a)
        ?.  ?=(%ok -.out.b)  b
        [[%ok =(val.out.a val.out.b)] traces.b]
      ::
          [%6 test=* yes=* no=*]
        =/  result=execution:jibb-core  $(formula test.formula)
        ?.  ?=(%ok -.out.result)  result
        ?+  val.out.result  [[%crash ~] traces.result]
          %&  $(formula yes.formula, traces traces.result)
          %|  $(formula no.formula, traces traces.result)
        ==
      ::
          [%7 subject=* next=*]
        =/  new-subject=execution:jibb-core  $(formula subject.formula)
        ?.  ?=(%ok -.out.new-subject)  new-subject
        %=  $
          subject  val.out.new-subject
          formula  next.formula
          traces   traces.new-subject
        ==
      ::
          [%8 head=* next=*]
        =/  head=execution:jibb-core  $(formula head.formula)
        ?.  ?=(%ok -.out.head)  head
        %=  $
          subject  [val.out.head subject]
          formula  next.formula
          traces   traces.head
        ==
      ::
          [%9 axis=@ core=*]
        =/  core=execution:jibb-core  $(formula core.formula)
        ?.  ?=(%ok -.out.core)  core
        =/  arm  (frag axis.formula val.out.core)
        ?~  arm  [[%crash ~] traces.core]
        ::  The final invocation of our fixed printer has no callbacks left.
        ::  Use the mink jet for its standard-library arithmetic; the message
        ::  formula has already been evaluated by the traced Nock 10 below.
        ::  The printer's payload depends on the emission environment; its
        ::  fixed battery identifies the gate without rejecting that payload.
        ?:  ?&  =(2 axis.formula)
                =((frag 2 val.out.core) (frag 2 trace-printer))
            ==
          =/  printed  (mink [val.out.core u.arm] |=(^ ~))
          ?-  -.printed
            %0  [[%ok product.printed] traces.core]
            %1  [[%crash ~] traces.core]
            %2  [[%crash ~] traces.core]
          ==
        %=  $
          subject  val.out.core
          formula  u.arm
          traces   traces.core
        ==
      ::
          [%10 [axis=@ value=*] target=*]
        ?:  =(0 axis.formula)  [[%crash ~] traces]
        =/  target=execution:jibb-core  $(formula target.formula)
        ?.  ?=(%ok -.out.target)  target
        =/  value=execution:jibb-core
          $(formula value.formula, traces traces.target)
        ?.  ?=(%ok -.out.value)  value
        =/  mutant=(unit)
          (edit axis.formula val.out.target val.out.value)
        ?~  mutant  [[%crash ~] traces.value]
        [[%ok u.mutant] traces.value]
      ::
          [%11 tag=@ next=*]
        =/  next=execution:jibb-core  $(formula next.formula)
        ?.  ?=(%ok -.out.next)  next
        =/  product=noun
          .*  subject
          [11 tag.formula 1 val.out.next]
        [[%ok product] traces.next]
      ::
          [%11 [tag=@ clue=*] next=*]
        =/  clue=execution:jibb-core  $(formula clue.formula)
        ?.  ?=(%ok -.out.clue)  clue
        =/  message=(unit @t)
          ?:(=(%slog tag.formula) (decode-slog-clue val.out.clue) ~)
        =/  next=execution:jibb-core
          %=  $
            formula  next.formula
            traces   ?~(message traces.clue [u.message traces.clue])
          ==
        ?.  ?=(%ok -.out.next)  next
        ?:  =(%slog tag.formula)  [[%ok val.out.next] traces.next]
        =/  product=noun
          .*  subject
          [11 [tag.formula 1 val.out.clue] 1 val.out.next]
        [[%ok product] traces.next]
      ::
          [%12 ref=* path=*]
        =/  ref=execution:jibb-core  $(formula ref.formula)
        ?.  ?=(%ok -.out.ref)  ref
        =/  path=execution:jibb-core  $(formula path.formula, traces traces.ref)
        ?.  ?=(%ok -.out.path)  path
        [[%crash ~] traces.path]
      ==
  ::
  ++  frag
    |=  [axis=@ value=noun]
    ^-  (unit)
    ?:  =(0 axis)  ~
    |-  ^-  (unit)
    ?:  =(1 axis)  `value
    ?@  value  ~
    =/  pick  (cap axis)
    %=  $
      axis   (mas axis)
      value  ?-(pick %2 -.value, %3 +.value)
    ==
  ::
  ++  edit
    |=  [axis=@ target=noun value=noun]
    ^-  (unit)
    ?:  =(1 axis)  `value
    ?@  target  ~
    =/  pick  (cap axis)
    =/  mutant
      %=  $
        axis    (mas axis)
        target  ?-(pick %2 -.target, %3 +.target)
      ==
    ?~  mutant  ~
    ?-  pick
      %2  `[u.mutant +.target]
      %3  `[-.target u.mutant]
    ==
  --
::
++  execute-traced
  |=  [subject=noun formula=noun]
  ^-  execution:jibb-core
  =/  result=execution:jibb-core  (evaluate-traced subject formula)
  result(traces (flop traces.result))
::
++  run-traced
  |=  [e=expr:jibb-core registry=native-registry:jibb-nock]
  ^-  execution:jibb-core
  (execute-traced 0 (emit:jibb-nock e registry))
::
++  execute-checked-traced
  |=  [subject=noun formula=noun]
  ^-  execution:jibb-core
  =/  result=execution:jibb-core  (evaluate-traced subject formula)
  =.  traces.result  (flop traces.result)
  ?:  ?=(%crash -.out.result)  result
  =/  tried=(each noun tang)
    %-  mule
    |.
    (canonical:jibb-nock-checked val.out.result)
  ?-  -.tried
    %|  result(out [%crash ~])
    %&  result(out [%ok p.tried])
  ==
::
++  run-checked-traced
  |=  [e=expr:jibb-core registry=native-registry:jibb-nock-checked]
  ^-  execution:jibb-core
  (execute-checked-traced 0 (emit:jibb-nock-checked e registry))
--
