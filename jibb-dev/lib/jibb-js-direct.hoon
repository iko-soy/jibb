::  Strict, bounded direct evaluation of compiled view-template holes.
::  Keep emitted text and traversal in step with js/core/direct-template.mjs.
::  Virtual cells and seals are materialized only when an ordinary operation
::  needs them; strict discarded work and operand checks stay in source order.
/+  jibb-core, jibb-js-template
|%
+$  value
  $~  [%actual '0n' ~]
  $%  [%atom val=@ code=@t]
      [%actual code=@t known=(unit value:jibb-js-template)]
      [%native name=@t code=@t]
      [%cell id=@ hed=value tal=value]
      [%seal id=@ body=value]
      [%closure id=@ sample=name:jibb-core body=expr:jibb-core env=@ code=(unit @t) source=environment:jibb-js-template shared=?]
  ==
+$  frame
  $:  parent=(unit @)
      values=(map name:jibb-core value)
      captured=environment:jibb-js-template
  ==
+$  site  [e=expr:jibb-core refs=(map name:jibb-core @t) code=@t]
+$  origin  [code=@t sample=value]
+$  state
  $:  left=@ud
      next=@ud
      serial=@ud
      work=@ud
      sites=(list site)
      frames=(map @ frame)
      lines=(list @t)
      cache=(map @ @t)
      forced=(list [id=@ val=value])
      origins=(map @ origin)
  ==
+$  evaluated  [val=value s=state]
+$  rendered  [out=@t s=state]
::
++  tick
  |=  s=state
  ^-  (unit state)
  ?~  left.s  ~
  `s(left (dec left.s))
::
++  identify
  |=  s=state
  ^-  [id=@ s=state]
  [serial.s s(serial +(serial.s))]
::
++  fresh
  |=  s=state
  ^-  [out=@t s=state]
  [(rap 3 ~['$v' (crip (a-co:co next.s))]) s(next +(next.s))]
::
++  emit
  |=  [code=@t s=state]
  ^-  evaluated
  =/  made=rendered  (fresh s(work +(work.s)))
  [[%actual out.made ~] s.made(lines [(rap 3 ~['const ' out.made ' = ' code ';']) lines.s.made])]
::
++  new-env
  |=  [f=frame s=state]
  ^-  [env=@ s=state]
  =/  made=[id=@ s=state]  (identify s)
  [id.made s.made(frames (~(put by frames.s.made) id.made f))]
::
++  bind
  |=  [env=@ name=name:jibb-core val=value s=state]
  ^-  [env=@ s=state]
  (new-env [`env (~(put by *(map name:jibb-core value)) name val) ~] s)
::
++  atom
  |=  val=@
  ^-  value
  [%atom val (rap 3 ~['BigInt("' (crip (a-co:co val)) '")'])]
::
++  imported
  |=  [v=value:jibb-js-template code=(unit @t) s=state]
  ^-  (unit evaluated)
  ?+  -.v
    ?~  code  ~
    `[[%actual u.code ~] s]
    %bound  $(v val.v, code `ref.v)
    %atom
      =/  made=value  (atom val.v)
      ?~  code  `[made s]
      ?>  ?=(%atom -.made)
      `[made(code u.code) s]
    %native
      =/  source=@t
        ?~  code  (rap 3 ~['natives[' (json-text:jibb-js-template name.v) ']'])
        u.code
      `[[%native name.v source] s]
    %closure
      =/  captured=[env=@ s=state]  (new-env [~ ~ env.v] s)
      =/  made=[id=@ s=state]  (identify s.captured)
      `[[%closure id.made sample.v body.v env.captured code env.v &] s.made]
  ==
::  Frames are shared across nested blocks, matching lazy import caching.
::  Only emitted statements and materialization caches are block-local.
++  lookup
  |=  [name=name:jibb-core env=@ s=state]
  ^-  (unit evaluated)
  =/  f=frame  (~(got by frames.s) env)
  =/  found=(unit value)  (~(get by values.f) name)
  ?^  found  `[u.found s]
  =/  captured=(unit value:jibb-js-template)  (~(get by captured.f) name)
  ?^  captured
    =/  made=(unit evaluated)  (imported u.captured ~ s)
    ?~  made  ~
    =.  s  s.u.made
    =.  f  f(values (~(put by values.f) name val.u.made))
    `[val.u.made s(frames (~(put by frames.s) env f))]
  ?~  parent.f  ~
  $(env u.parent.f)
::
++  after-block
  |=  [outer=state inner=state]
  ^-  state
  outer(left left.inner, next next.inner, serial serial.inner, work work.inner, frames frames.inner, origins origins.inner)
::
++  body
  |=  [s=state result=@t]
  ^-  @t
  (rap 3 ~[(join-text:jibb-core '\0a' (flop lines.s)) '\0areturn ' result ';\0a'])
::
++  reference
  |=  v=value
  ^-  (unit @t)
  ?-  -.v
    %atom  `code.v
    %actual  `code.v
    %native  `code.v
    %closure  code.v
    ?(%cell %seal)  ~
  ==
::  The Core names a node uses but does not bind. Capture order is the
::  JavaScript sort order of their printed names, not map iteration order.
++  free-names
  |=  [e=expr:jibb-core bound=(set name:jibb-core)]
  ^-  (set name:jibb-core)
  ?-  -.e
    ?(%lit %native %crash)  ~
    %var  ?:((~(has in bound) name.e) ~ (sy ~[name.e]))
    %cons  (~(uni in $(e hed.e)) $(e tal.e))
    %slot  $(e body.e)
    %cell  $(e body.e)
    %edit  (~(uni in $(e body.e)) $(e value.e))
    %eq  (~(uni in $(e left.e)) $(e right.e))
    %if  (~(uni in (~(uni in $(e test.e)) $(e yes.e))) $(e no.e))
    %let  (~(uni in $(e value.e)) $(e body.e, bound (~(put in bound) name.e)))
    %rec
      =/  inner=(set name:jibb-core)
        (~(gas in bound) (turn arms.e |=(a=rec-arm:jibb-core name.a)))
      =/  arms=(list rec-arm:jibb-core)  arms.e
      =/  out=(set name:jibb-core)  $(e body.e, bound inner)
      |-
      ?~  arms  out
      $(arms t.arms, out (~(uni in out) ^$(e fun.i.arms, bound inner)))
    %lam  $(e body.e, bound (~(put in bound) sample.e))
    %app  (~(uni in $(e fun.e)) $(e sample.e))
    %trace  (~(uni in $(e message.e)) $(e body.e))
  ==
::
++  captures
  |=  [names=(list name:jibb-core) env=@ s=state]
  ^-  (unit [values=(map name:jibb-core value) s=state])
  =|  values=(map name:jibb-core value)
  |-
  ?~  names  `[values s]
  =/  captured=(unit evaluated)  (lookup i.names env s)
  ?~  captured  ~
  =/  ref=(unit rendered)  (force val.u.captured s.u.captured)
  ?~  ref  ~
  =/  v=value  val.u.captured
  =.  v  ?:(?=(%atom -.v) v(code out.u.ref) [%actual out.u.ref ~])
  $(names t.names, s s.u.ref, values (~(put by values) i.names v))
::  Hoisted callbacks share the ordinary emitter's lazy slot. A structural
::  match without exactly one compatible lexical environment declines the
::  direct path rather than choosing a callback by source spelling.
++  compatible
  |=  [refs=(list [name:jibb-core @t]) env=@ s=state]
  ^-  (unit [yes=? s=state])
  ?~  refs  `[& s]
  =/  value=(unit evaluated)  (lookup -.i.refs env s)
  ?~  value  ~
  =/  ref=(unit @t)  (reference val.u.value)
  ?~  ref  `[| s.u.value]
  ?.  =(u.ref +.i.refs)  `[| s.u.value]
  $(refs t.refs, s s.u.value)
::
++  hoisted
  |=  [e=expr:jibb-core env=@ s=state]
  ^-  (unit [ref=(unit @t) s=state])
  =/  sites=(list site)  (skim sites.s |=(item=site =(e e.item)))
  ?~  sites  `[~ s]
  =/  remaining=(list site)  sites
  =|  found=(list @t)
  |-
  ?~  remaining
    ?.  =(1 (lent found))  ~
    ?>  ?=(^ found)
    `[`i.found s]
  =/  matches=(unit [yes=? s=state])  (compatible ~(tap by refs.i.remaining) env s)
  ?~  matches  ~
  $(remaining t.remaining, s s.u.matches, found ?:(yes.u.matches [code.i.remaining found] found))
::
++  force
  |=  [v=value s=state]
  ^-  (unit rendered)
  =/  next=(unit state)  (tick s)
  ?~  next  ~
  =.  s  u.next
  =/  code=(unit @t)  (reference v)
  ?^  code  `[u.code s]
  ?>  ?=(?(%cell %seal %closure) -.v)
  =/  cached=(unit @t)  (~(get by cache.s) id.v)
  ?^  cached  `[u.cached s]
  =/  reuse=(unit [ref=(unit @t) s=state])
    ?:  ?=(%closure -.v)  (hoisted [%lam sample.v body.v] env.v s)
    `[~ s]
  ?~  reuse  ~
  =.  s  s.u.reuse
  ?^  ref.u.reuse  `[u.ref.u.reuse s]
  =/  origin=(unit origin)  (~(get by origins.s) id.v)
  =/  built=(unit rendered)
    ?^  origin
      =/  sample=(unit rendered)  $(v sample.u.origin)
      ?~  sample  ~
      `[(rap 3 ~['apply(' code.u.origin ', ' out.u.sample ')']) s.u.sample]
    ?-  -.v
      %cell
        =/  hed=(unit rendered)  $(v hed.v)
        ?~  hed  ~
        =/  tal=(unit rendered)  $(v tal.v, s s.u.hed)
        ?~  tal  ~
        `[(rap 3 ~['cons(' out.u.hed ', ' out.u.tal ')']) s.u.tal]
      %seal
        =/  payload=(unit rendered)  $(v body.v)
        ?~  payload  ~
        `[(rap 3 ~['apply(natives["raw-seal"], ' out.u.payload ')']) s.u.payload]
      %closure
        =/  names=(list name:jibb-core)
          %+  sort  ~(tap in (free-names [%lam sample.v body.v] ~))
          |=  [a=name:jibb-core b=name:jibb-core]
          (aor (print-name:jibb-core a) (print-name:jibb-core b))
        =/  captured=(unit [values=(map name:jibb-core value) s=state])
          (captures names env.v s)
        ?~  captured  ~
        =/  parameter=rendered  (fresh s.u.captured)
        =/  inner=state  s.parameter(lines ~)
        =/  environment=[env=@ s=state]  (new-env [~ values.u.captured ~] inner)
        =.  environment  (bind env.environment sample.v [%actual out.parameter ~] s.environment)
        =/  result=(unit evaluated)  (evaluate body.v env.environment s.environment)
        ?~  result  ~
        =/  returned=(unit rendered)  $(v val.u.result, s s.u.result)
        ?~  returned  ~
        `[(rap 3 ~['((' out.parameter ') => {\0a' (body s.u.returned out.u.returned) '})']) (after-block s.parameter s.u.returned)]
    ==
  ?~  built  ~
  =/  made=evaluated  (emit out.u.built s.u.built)
  ?>  ?=(%actual -.val.made)
  =/  remembered=state
    s.made(cache (~(put by cache.s.made) id.v code.val.made), forced [[id.v v] forced.s.made])
  `[code.val.made remembered]
::
++  check
  |=  [v=value operation=@t s=state]
  ^-  (unit state)
  ?.  |(?=(%actual -.v) &(?=(%seal -.v) ?=(%actual -.body.v)))  `s
  =/  made=(unit rendered)  (force v s)
  ?~  made  ~
  `s.u.made(lines [(rap 3 ~['checkValue(' out.u.made ', ' (json-text:jibb-js-template operation) ');']) lines.s.u.made])
::  A projection that cannot be completed virtually keeps the original
::  axis and runtime operation, including its exact validation diagnostic.
++  project
  |=  [v=value axis=@ s=state]
  ^-  (unit evaluated)
  =/  original=value  v
  =/  bounded=?  &((gte axis 1) (lte axis 9.007.199.254.740.991))
  =/  walked=(unit [val=value known=? s=state])
    ?.  bounded  `[v | s]
    =/  bits=(list @)  (flop (rip 0 axis))
    ?>  ?=(^ bits)
    =/  path=(list @)  t.bits
    |-
    ?~  path  `[v & s]
    =/  next=(unit state)  (tick s)
    ?~  next  ~
    =.  s  u.next
    ?:  ?=(%cell -.v)
      $(path t.path, v ?:(=(0 i.path) hed.v tal.v))
    ?:  &(?=(%seal -.v) =(1 i.path))
      $(path t.path, v body.v)
    `[v | s]
  ?~  walked  ~
  =.  s  s.u.walked
  =/  safe=?
    ?:  ?=(?(%actual %closure %native) -.original)  |
    ?:  ?=(%seal -.original)  ?:(?=(%actual -.body.original) | &)
    &
  ?:  &(known.u.walked safe)  `[val.u.walked s]
  =/  made=(unit rendered)  (force original s)
  ?~  made  ~
  `(emit (rap 3 ~['slot(' (crip (a-co:co axis)) 'n, ' out.u.made ')']) s.u.made)
::
++  branch
  |=  [e=expr:jibb-core env=@ s=state]
  ^-  (unit rendered)
  =/  base=@ud  serial.s
  =/  probe=(unit rendered)
    =/  result=(unit evaluated)  (evaluate e env s(lines ~, forced ~))
    ?~  result  ~
    =/  returned=(unit rendered)  (force val.u.result s.u.result)
    ?~  returned  ~
    `[(rap 3 ~['(() => {\0a' (body s.u.returned out.u.returned) '})()']) s.u.returned]
  ?~  probe  ~
  =/  resumed=state
    s(left left.s.u.probe, serial serial.s.u.probe, frames frames.s.u.probe)
  =/  found=(list [id=@ val=value])  (flop forced.s.u.probe)
  =|  shared=(list value)
  =|  seen=(set @)
  =/  collected=[shared=(list value) seen=(set @)]
    |-
    ?~  found  [shared seen]
    =/  old=?
      ?.  (gte id.i.found base)  &
      &(?=(%closure -.val.i.found) shared.val.i.found)
    ?.  old  $(found t.found)
    ?:  (~(has by cache.s) id.i.found)  $(found t.found)
    ?:  (~(has in seen) id.i.found)  $(found t.found)
    $(found t.found, shared [val.i.found shared], seen (~(put in seen) id.i.found))
  =/  pending=(list value)  (flop shared.collected)
  =/  outer=state  resumed
  |-
  ?~  pending
    =/  result=(unit evaluated)  (evaluate e env outer(lines ~, forced ~))
    ?~  result  ~
    =/  returned=(unit rendered)  (force val.u.result s.u.result)
    ?~  returned  ~
    `[(rap 3 ~['(() => {\0a' (body s.u.returned out.u.returned) '})()']) (after-block outer s.u.returned)]
  =/  made=(unit rendered)  (force i.pending outer)
  ?~  made  ~
  $(pending t.pending, outer s.u.made)
::  Shared residual fuel bounds repeated expansion of virtual shared cells.
::  Opaque calls may keep source-proven shape without becoming virtual values.
++  shape
  |=  [v=value s=state]
  ^-  (unit [val=value:jibb-js-template s=state])
  =/  next=(unit state)  (tick s)
  ?~  next  ~
  =.  s  u.next
  ?+  -.v  `[[%unknown ~] s]
    %atom  `[[%atom val.v] s]
    %native  `[[%native name.v] s]
    %cell
      =/  hed=(unit [val=value:jibb-js-template s=state])  $(v hed.v)
      ?~  hed  ~
      =/  tal=(unit [val=value:jibb-js-template s=state])  $(v tal.v, s s.u.hed)
      ?~  tal  ~
      `[[%cell val.u.hed val.u.tal] s.u.tal]
    %seal
      =/  payload=(unit [val=value:jibb-js-template s=state])  $(v body.v)
      ?~  payload  ~
      `[[%seal val.u.payload] s.u.payload]
    %actual  `[?~(known.v [%unknown ~] u.known.v) s]
  ==
::
++  evaluate
  |=  [e=expr:jibb-core env=@ s=state]
  ^-  (unit evaluated)
  =/  next=(unit state)  (tick s)
  ?~  next  ~
  =.  s  u.next
  ?+  -.e  ~
    %lit  `[(atom val.lit.e) s]
    %var  (lookup name.e env s)
    %native
      =/  name=@t  (print-name:jibb-core name.e)
      `[[%native name (rap 3 ~['natives[' (json-text:jibb-js-template name) ']'])] s]
    %cons
      =/  hed=(unit evaluated)  $(e hed.e)
      ?~  hed  ~
      =/  tal=(unit evaluated)  $(e tal.e, s s.u.hed)
      ?~  tal  ~
      =/  head-check=(unit state)  (check val.u.hed 'cons head' s.u.tal)
      ?~  head-check  ~
      =/  tail-check=(unit state)  (check val.u.tal 'cons tail' u.head-check)
      ?~  tail-check  ~
      =/  made=[id=@ s=state]  (identify u.tail-check)
      `[[%cell id.made val.u.hed val.u.tal] s.made]
    %slot
      =/  value=(unit evaluated)  $(e body.e)
      ?~  value  ~
      (project val.u.value axis.e s.u.value)
    %let
      =/  value=(unit evaluated)  $(e value.e)
      ?~  value  ~
      =/  inner=[env=@ s=state]  (bind env name.e val.u.value s.u.value)
      $(e body.e, env env.inner, s s.inner)
    %lam
      =/  made=[id=@ s=state]  (identify s)
      `[[%closure id.made sample.e body.e env ~ ~ |] s.made]
    %app
      =/  fun=(unit evaluated)  $(e fun.e)
      ?~  fun  ~
      =/  sample=(unit evaluated)  $(e sample.e, s s.u.fun)
      ?~  sample  ~
      =/  gate=value  val.u.fun
      ?:  ?=(%closure -.gate)
        =/  boundary=(unit [inline=? known=value:jibb-js-template s=state])
          ?~  code.gate  `[& [%unknown ~] s.u.sample]
          =/  argument=(unit [val=value:jibb-js-template s=state])  (shape val.u.sample s.u.sample)
          ?~  argument  ~
          =/  known=value:jibb-js-template
            (abstract-value:jibb-js-template body.gate (~(put by source.gate) sample.gate val.u.argument))
          `[?=(^ (value-template:jibb-js-template known)) known s.u.argument]
        ?~  boundary  ~
        =.  s  s.u.boundary
        ?.  inline.u.boundary
          ?>  ?=(^ code.gate)
          =/  sample-code=(unit rendered)  (force val.u.sample s)
          ?~  sample-code  ~
          =/  made=evaluated  (emit (rap 3 ~['apply(' u.code.gate ', ' out.u.sample-code ')']) s.u.sample-code)
          ?>  ?=(%actual -.val.made)
          `[val.made(known `known.u.boundary) s.made]
        =/  work=@ud  work.s
        =/  serial=@ud  serial.s
        =/  inner=[env=@ s=state]  (bind env.gate sample.gate val.u.sample s)
        =/  result=(unit evaluated)  $(e body.gate, env env.inner, s s.inner)
        ?~  result  ~
        =/  value=value  val.u.result
        =.  s  s.u.result
        ?~  code.gate  result
        ?.  &(=(work work.s) ?=(?(%cell %seal) -.value))  result
        ?.  (gte id.value serial)  result
        `[value s(origins (~(put by origins.s) id.value [u.code.gate val.u.sample]))]
      ?:  &(?=(%native -.gate) =('raw-seal' name.gate))
        =/  made=[id=@ s=state]  (identify s.u.sample)
        `[[%seal id.made val.u.sample] s.made]
      =/  target=(unit rendered)  (force gate s.u.sample)
      ?~  target  ~
      =/  argument=(unit rendered)  (force val.u.sample s.u.target)
      ?~  argument  ~
      `(emit (rap 3 ~['apply(' out.u.target ', ' out.u.argument ')']) s.u.argument)
    %if
      =/  test=(unit evaluated)  $(e test.e)
      ?~  test  ~
      =/  condition=value  val.u.test
      ?:  &(?=(%atom -.condition) (lte val.condition 1))
        $(e ?:(=(0 val.condition) yes.e no.e), s s.u.test)
      =/  tested=(unit rendered)  (force condition s.u.test)
      ?~  tested  ~
      =/  yes=(unit rendered)  (branch yes.e env s.u.tested)
      ?~  yes  ~
      =/  no=(unit rendered)  (branch no.e env s.u.yes)
      ?~  no  ~
      `(emit (rap 3 ~['(requireLoobean(' out.u.tested ') ? ' out.u.yes ' : ' out.u.no ')']) s.u.no)
    %edit
      =/  target=(unit evaluated)  $(e body.e)
      ?~  target  ~
      =/  value=(unit evaluated)  $(e value.e, s s.u.target)
      ?~  value  ~
      =/  left=(unit rendered)  (force val.u.target s.u.value)
      ?~  left  ~
      =/  right=(unit rendered)  (force val.u.value s.u.left)
      ?~  right  ~
      `(emit (rap 3 ~['edit(' (crip (a-co:co axis.e)) 'n, ' out.u.left ', ' out.u.right ')']) s.u.right)
    %cell
      =/  value=(unit evaluated)  $(e body.e)
      ?~  value  ~
      =/  made=(unit rendered)  (force val.u.value s.u.value)
      ?~  made  ~
      `(emit (rap 3 ~['isCell(' out.u.made ')']) s.u.made)
    %eq
      =/  left=(unit evaluated)  $(e left.e)
      ?~  left  ~
      =/  right=(unit evaluated)  $(e right.e, s s.u.left)
      ?~  right  ~
      =/  first=(unit rendered)  (force val.u.left s.u.right)
      ?~  first  ~
      =/  second=(unit rendered)  (force val.u.right s.u.first)
      ?~  second  ~
      `(emit (rap 3 ~['same(' out.u.first ', ' out.u.second ')']) s.u.second)
    %trace
      =/  message=(unit evaluated)  $(e message.e)
      ?~  message  ~
      =/  text=(unit rendered)  (force val.u.message s.u.message)
      ?~  text  ~
      =.  s  s.u.text(work +(work.s.u.text), lines [(rap 3 ~['traceLazy(' out.u.text ', () => 0n);']) lines.s.u.text])
      $(e body.e)
    %crash  `(emit 'crash("explicit Core crash")' s)
  ==
::
++  direct-holes
  |=  [e=expr:jibb-core env=environment:jibb-js-template axes=(list @ud) sites=(list site)]
  ^-  (unit @t)
  ?.  ?=(%lam -.e)  ~
  =/  s=state  [2.000 0 0 0 sites ~ ~ ~ ~ ~]
  =/  captured=[env=@ s=state]  (new-env [~ ~ env] s)
  =/  inner=[env=@ s=state]  (bind env.captured sample.e [%actual '$model' ~] s.captured)
  =/  result=(unit evaluated)  (evaluate body.e env.inner s.inner)
  ?~  result  ~
  =.  s  s.u.result
  =|  holes=(list @t)
  |-
  ?~  axes
    `(rap 3 ~['(($model) => {\0a' (body s (rap 3 ~['[' (join-text:jibb-core ', ' (flop holes)) ']'])) '})'])
  =/  value=(unit evaluated)  (project val.u.result i.axes s)
  ?~  value  ~
  =/  made=(unit rendered)  (force val.u.value s.u.value)
  ?~  made  ~
  $(axes t.axes, s s.u.made, holes [out.u.made holes])
--
