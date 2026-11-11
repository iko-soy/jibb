::  Bounded analysis of authenticated Core for static DOM templates.
::  Shape proof never removes strict work. Direct residualization is a
::  separate pass; this analysis itself never changes evaluation.
::  Keep its bounds, descriptors and traversal in step with
::  js/core/view-template.mjs. Unknown children take the ordinary path.
/+  jibb-core
|%
+$  value
  $~  [%unknown ~]
  $%  [%unknown ~]
      [%atom val=@]
      [%cell hed=value tal=value]
      [%closure sample=name:jibb-core body=expr:jibb-core env=environment]
      [%native name=@t]
      [%seal body=value]
      [%bound ref=@t val=value]
  ==
+$  environment  (map name:jibb-core value)
+$  evaluation  [val=value left=@ud]
+$  shape-state  [left=@ud axes=(list @ud)]
+$  rendered  [out=@t s=shape-state]
+$  plan  [tree=@t axes=(list @ud)]
::  Lexical bindings retain their actual JavaScript references for the direct
::  hole pass. Shape analysis sees only the bound value; closure environments
::  keep the wrapper so captured unknown values remain accessible.
++  unbound
  |=  v=value
  ^-  value
  ?:  ?=(%bound -.v)  $(v val.v)
  v
::  One unit of fuel per syntax node, shared across lexical applications.
++  evaluate
  |=  [e=expr:jibb-core env=environment fuel=@ud]
  ^-  (unit evaluation)
  ?~  fuel  ~
  =.  fuel  (dec fuel)
  ?+  -.e  `[[%unknown ~] fuel]
    %lit  `[[%atom val.lit.e] fuel]
    %var  `[(unbound (~(gut by env) name.e [%unknown ~])) fuel]
    %native  `[[%native (print-name:jibb-core name.e)] fuel]
    %lam  `[[%closure sample.e body.e env] fuel]
    %cons
      =/  hed=(unit evaluation)  $(e hed.e)
      ?~  hed  ~
      =/  tal=(unit evaluation)  $(e tal.e, fuel left.u.hed)
      ?~  tal  ~
      `[[%cell val.u.hed val.u.tal] left.u.tal]
    %slot
      =/  body=(unit evaluation)  $(e body.e)
      ?~  body  ~
      `[(at-axis axis.e val.u.body) left.u.body]
    %let
      =/  made=(unit evaluation)  $(e value.e)
      ?~  made  ~
      $(e body.e, env (~(put by env) name.e val.u.made), fuel left.u.made)
    %app
      =/  fun=(unit evaluation)  $(e fun.e)
      ?~  fun  ~
      =/  arg=(unit evaluation)  $(e sample.e, fuel left.u.fun)
      ?~  arg  ~
      =/  gate=value  val.u.fun
      ?:  ?=(%closure -.gate)
        $(e body.gate, env (~(put by env.gate) sample.gate val.u.arg), fuel left.u.arg)
      ?:  &(?=(%native -.gate) =('raw-seal' name.gate))
        `[[%seal val.u.arg] left.u.arg]
      `[[%unknown ~] left.u.arg]
    %if
      =/  test=(unit evaluation)  $(e test.e)
      ?~  test  ~
      =/  condition=value  val.u.test
      ?.  ?=(%atom -.condition)  `[[%unknown ~] left.u.test]
      ?:  (gth val.condition 1)  `[[%unknown ~] left.u.test]
      $(e ?:(=(0 val.condition) yes.e no.e), fuel left.u.test)
  ==
::
++  abstract-value
  |=  [e=expr:jibb-core env=environment]
  ^-  value
  =/  made=(unit evaluation)  (evaluate e env 2.000)
  ?~  made  [%unknown ~]
  val.u.made
::  Only known cells and bounded axes can establish a projection's shape.
::  Larger Core axes still execute normally; this is an analysis limit.
++  at-axis
  |=  [axis=@ v=value]
  ^-  value
  ?:  |(=(0 axis) (gth axis 9.007.199.254.740.991))  [%unknown ~]
  ?:  =(1 axis)  v
  =/  prefix=value  $(axis (div axis 2))
  ?.  ?=(%cell -.prefix)  [%unknown ~]
  ?:(=(0 (mod axis 2)) hed.prefix tal.prefix)
::  Non-ASCII constants use text holes, preserving the runtime decoder.
++  ascii
  |=  v=value
  ^-  (unit @t)
  ?.  ?=(%atom -.v)  ~
  =/  atom=@  val.v
  |-
  ?:  =(0 atom)  `val.v
  =/  byte=@  (end 3 atom)
  ?.  &((gte byte 32) (lte byte 126))  ~
  $(atom (rsh 3 atom))
::  An attribute noun is fixed only when every reachable part is known.
::  Its independent fuel limit must not become an ordinary element hole.
++  constant
  |=  [v=value fuel=@ud]
  ^-  (unit [known=? left=@ud])
  ?~  fuel  ~
  =.  fuel  (dec fuel)
  ?:  ?=(%atom -.v)  `[& fuel]
  ?.  ?=(%cell -.v)  `[| fuel]
  =/  hed=(unit [known=? left=@ud])  $(v hed.v)
  ?~  hed  ~
  ?.  known.u.hed  hed
  $(v tal.v, fuel left.u.hed)
::  Check the complete child-list spine before recording descendant holes.
::  An unknown tail uses one whole element hole; an exhausted limit declines
::  the complete plan, just like descriptor or Core analysis exhaustion.
++  proper-list
  |=  [v=value fuel=@ud]
  ^-  (unit ?)
  ?:  ?=(%cell -.v)
    ?~  fuel  ~
    $(v tal.v, fuel (dec fuel))
  `&(?=(%atom -.v) =(0 val.v))
::
++  json-text
  |=  text=@t
  ^-  @t
  =/  chars=tape  (trip text)
  =|  out=tape
  |-
  ?~  chars  (rap 3 ~['"' (crip (flop out)) '"'])
  ?:  =('"' i.chars)  $(chars t.chars, out (weld (flop "\\\"") out))
  ?:  =('\\' i.chars)  $(chars t.chars, out (weld (flop "\\\\") out))
  $(chars t.chars, out [i.chars out])
::  Each element and text leaf consumes one node; used axes fit JS numbers.
++  point
  |=  [axis=@ s=shape-state]
  ^-  (unit shape-state)
  ?:  |(=(0 left.s) (gth axis 9.007.199.254.740.991))  ~
  `s(left (dec left.s))
::
++  words
  |=  [v=value axis=@ s=shape-state]
  ^-  (unit rendered)
  =/  next=(unit shape-state)  (point axis s)
  ?~  next  ~
  =.  s  u.next
  =/  text=(unit @t)  (ascii v)
  ?^  text  `[(json-text u.text) s]
  `[(crip (a-co:co (lent axes.s))) s(axes [axis axes.s])]
::  Negative descriptors refer to complete ordinary element subtrees.
::  Text and element holes share one encounter-ordered axis list.
++  element-hole
  |=  [axis=@ s=shape-state]
  ^-  (unit rendered)
  `[(rap 3 ~['-' (crip (a-co:co +((lent axes.s))))]) s(axes [axis axes.s])]
::
++  children
  |=  [v=value axis=@ s=shape-state]
  ^-  (unit rendered)
  =|  out=(list @t)
  |-
  ?:  ?=(%cell -.v)
    =/  made=(unit rendered)  (element hed.v (mul axis 2) s)
    ?~  made  ~
    $(v tal.v, axis +((mul axis 2)), s s.u.made, out [out.u.made out])
  ?.  &(?=(%atom -.v) =(0 val.v))  ~
  `[(rap 3 ~['[' (join-text:jibb-core ',' (flop out)) ']']) s]
::
++  element
  |=  [v=value axis=@ s=shape-state]
  ^-  (unit rendered)
  =/  next=(unit shape-state)  (point axis s)
  ?~  next  ~
  =.  s  u.next
  ?.  ?=(%seal -.v)  (element-hole axis s)
  ?.  ?=(%cell -.body.v)  (element-hole axis s)
  =/  tag=(unit @t)  (ascii hed.body.v)
  ?~  tag  (element-hole axis s)
  =/  payload=value  tal.body.v
  ::  A seal is [seal-tag raw], and raw is [tag payload].
  =/  at=@  (add (mul axis 4) 3)
  ?+  u.tag  (element-hole axis s)
    %text  (words payload at s)
    %heading
      ?.  ?=(%cell -.payload)  (element-hole axis s)
      ?.  ?=(%atom -.hed.payload)  (element-hole axis s)
      =/  level=@  (min 6 (max 1 val.hed.payload))
      =/  child=(unit rendered)  (words tal.payload +((mul at 2)) s)
      ?~  child  ~
      `[(rap 3 ~['["h' (crip (a-co:co level)) '",{"tabIndex":"-1"},[' out.u.child ']]']) s.u.child]
    ?(%row %column %wrap %stack %el)
      ?.  ?=(%cell -.payload)  (element-hole axis s)
      =/  fixed=(unit [known=? left=@ud])  (constant hed.payload 128)
      ?~  fixed  ~
      ?.  known.u.fixed  (element-hole axis s)
      =/  proper=(unit ?)
        ?:  =('el' u.tag)  `&
        (proper-list tal.payload 128)
      ?~  proper  ~
      ?.  u.proper  (element-hole axis s)
      =/  empty=?  &(?=(%atom -.hed.payload) =(0 val.hed.payload))
      =/  attrs-axis=@  (mul at 2)
      =/  after-attrs=(unit shape-state)
        ?:  empty  `s
        (point attrs-axis s)
      ?~  after-attrs  ~
      =.  s  u.after-attrs
      =/  kids=(unit rendered)
        ?:  =('el' u.tag)
          =/  child=(unit rendered)  $(v tal.payload, axis +((mul at 2)))
          ?~  child  ~
          `[(rap 3 ~['[' out.u.child ']']) s.u.child]
        (children tal.payload +((mul at 2)) s)
      ?~  kids  ~
      =/  prefix=@t
        ?:  empty  (rap 3 ~['["div",{"class":"j-' u.tag '"},'])
        (rap 3 ~['[' (json-text u.tag) ',' (crip (a-co:co attrs-axis)) ','])
      `[(rap 3 ~[prefix out.u.kids ']']) s.u.kids]
    %para
      =/  proper=(unit ?)  (proper-list payload 128)
      ?~  proper  ~
      ?.  u.proper  (element-hole axis s)
      =/  kids=(unit rendered)  (children payload at s)
      ?~  kids  ~
      `[(rap 3 ~['["p",{},' out.u.kids ']']) s.u.kids]
  ==
::  Shape bounds are independent of the abstract Core evaluation budget.
++  value-template
  |=  value=value
  ^-  (unit plan)
  =/  tree=(unit rendered)  (element value 1 [128 ~])
  ?~  tree  ~
  ?:  =('-' (end 3 out.u.tree))  ~
  `[out.u.tree (flop axes.s.u.tree)]
::  Compute a gate's plan with an unknown sample at its lexical definition.
++  view-template
  |=  [e=expr:jibb-core env=environment]
  ^-  (unit plan)
  (view-template-with-sample e env [%unknown ~])
::
++  view-template-with-sample
  |=  [e=expr:jibb-core env=environment sample=value]
  ^-  (unit plan)
  ?.  ?=(%lam -.e)  ~
  (value-template (abstract-value body.e (~(put by env) sample.e sample)))
--
