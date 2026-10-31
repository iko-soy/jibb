::  Explicit proj retains lowering evidence and is reserved for API bindings.
/+  jibb
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
|%
++  proj-guard-errors
  ^-  (list tape)
  =/  src=@t  '++ exact ^- [a=@t b=@p] (proj [a="hi" b=~zod])\0a++ wider ^- [a=@t b=@p] (proj [a="hi" b=~zod c=%.y])\0a++ effect |= x=@t\0a  ~& "effect"\0a    x\0a++ traced ^- [a=@t b=@p] (proj [a="hi" b=~zod c=(effect "once")])\0a'
  =/  result=jfile-result:jibb  (infer-jibb-file:jibb /ui/record/jibb src ~ ~ ~ ~ ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~["proj evidence fixture did not infer"]
  =/  defs=(list iwidth-definition:jibb)  elaborations.iface.p.result
  =/  exact=(list iwidth-definition:jibb)  (skim defs |=(d=iwidth-definition:jibb =(%exact name.d)))
  =/  wider=(list iwidth-definition:jibb)  (skim defs |=(d=iwidth-definition:jibb =(%wider name.d)))
  =/  traced=(list iwidth-definition:jibb)  (skim defs |=(d=iwidth-definition:jibb =(%traced name.d)))
  ?~  exact  ~["exact-width proj lacks lowering evidence"]
  ?~  wider  ~["wider proj lacks lowering evidence"]
  ?~  traced  ~["traced proj lacks lowering evidence"]
  ?:  |(!=(1 (lent projections.i.exact)) !=(1 (lent projections.i.wider)))
    ~["proj evidence has an unexpected number of actions"]
  ?~  projections.i.exact  ~["exact-width proj action is missing"]
  =/  call=expr:jibb  original.i.projections.i.exact
  ?.  ?=(%call -.call)  ~["exact-width proj did not retain its call"]
  ?.  ?=(%wing -.head.call)  ~["exact-width proj head is not a wing"]
  ?.  =(names.head.call ~[%proj])  ~["exact-width proj head is not proj"]
  ?.  =(steps.i.projections.i.exact ~[[%a 2] [%b 3]])  ~["exact-width proj has incorrect field axes"]
  ?:  !=(1 (lent projections.i.traced))  ~["traced proj has an unexpected number of actions"]
  ?~  projections.i.traced  ~["traced proj action is missing"]
  =/  traced-call=expr:jibb  original.i.projections.i.traced
  ?.  ?=(%call -.traced-call)  ~["traced proj did not retain its call"]
  ?.  ?=([* ~] args.traced-call)  ~["traced proj did not retain one source expression"]
  =/  traced-record=expr:jibb  i.args.traced-call
  ?.  ?=(%tuple -.traced-record)  ~["traced proj source is not a record"]
  =/  fields=(list item:jibb)  items.traced-record
  ?~  fields  ~["traced proj source lacks first field"]
  ?~  t.fields  ~["traced proj source lacks second field"]
  ?~  t.t.fields  ~["traced proj source lacks discarded field"]
  =/  effect=expr:jibb  val.i.t.t.fields
  ?.  ?=(%group -.effect)  ~["discarded effect source was not retained"]
  ?.  ?=(%call -.inner.effect)  ~["discarded effect call was not retained"]
  =/  valid-src=@t  '/% %todo\0a+$ paths [%safe /proj todo]\0a'
  =/  clash-src=@t  '/% %todo\0a+$ paths [%proj /safe todo]\0a'
  =/  poke-src=@t  '/% %proj\0a+$ poke proj\0a'
  =/  valid=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb valid-src)
  =/  clash=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb clash-src)
  =/  poke=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb poke-src)
  ?:  |(?=(%| -.valid) ?=(%| -.clash) ?=(%| -.poke))  ~["API reservation controls did not parse"]
  =/  todo=imark-externals:jibb  ~[[%todo [%& [%atom %t ~]]]]
  =/  proj-mark=imark-externals:jibb  ~[[%proj [%& [%atom %t ~]]]]
  =/  good=(unit (list iapi-path-typed:jibb))  (api-path-analysis:jibb p.valid todo ~ ~)
  =/  bad=(unit (list iapi-path-typed:jibb))  (api-path-analysis:jibb p.clash todo ~ ~)
  ?~  good  ~["a literal /proj path was rejected"]
  ?^  bad  ~["an API-derived proj path name was accepted"]
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb real-prelude real-internal)
  ?~  prepared  ~["real prelude did not prepare"]
  =/  derived=(unit ifile:jibb)
    (api-poke-interface:jibb /ui/api/demo/jibb p.poke proj-mark values.u.prepared molds.u.prepared `iface.u.prepared)
  ?^  derived  ~["an API-derived proj poke name was accepted"]
  proj-graph-errors
++  proj-graph-errors
  ^-  (list tape)
  =/  child=@t  '++ owned ^- [a=@t b=@p] (proj [a="hi" b=~zod c=%.y])\0a++ exported owned\0a'
  =/  parent=@t  '/= dep /ui/dep\0a++ answer exported.dep\0a'
  =/  bundle=jbundle:jibb  ~[[/ui/dep/jibb child]]
  =/  built=jfile-result:jibb  (infer-jibb-file:jibb /ui/root/jibb parent ~ ~ bundle ~[/ui/root/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.built)  ~["imported projection module did not infer"]
  =/  dep=(unit ifile:jibb)  (find-jibb-cache:jibb /ui/dep/jibb cache.p.built)
  ?~  dep  ~["imported module cache is missing"]
  =/  owned=(list iwidth-definition:jibb)  (skim elaborations.u.dep |=(d=iwidth-definition:jibb =(%owned name.d)))
  ?~  owned  ~["imported module projection evidence is missing"]
  =/  private=@t  '/= core /lib/jibb/primitives\0a++ pick |= x=[a=@t b=@p] a.x\0a++ project (pick (proj [a="hi" b=~zod c=%.y]))\0a'
  =/  public=@t  '/= internal /lib/jibb/internal\0a++ exposed project.internal\0a++ local ^- [a=@t b=@p] (proj [a="hi" b=~zod c=%.y])\0a'
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public private)
  ?~  prep  ~["source prelude did not prepare"]
  =/  local=(list iwidth-definition:jibb)  (skim elaborations.iface.u.prep |=(d=iwidth-definition:jibb =(%local name.d)))
  ?~  local  ~["public prelude projection evidence is missing"]
  =/  deps=(list iwidth-dependency:jibb)  dependencies.iface.u.prep
  =/  private-deps=(list iwidth-dependency:jibb)  (skim deps |=(d=iwidth-dependency:jibb =(at.d /lib/jibb/internal/jibb)))
  ?~  private-deps  ~["private prelude dependency is missing"]
  =/  private-defs=(list iwidth-definition:jibb)  (skim definitions.i.private-deps |=(d=iwidth-definition:jibb =(%project name.d)))
  ?~  private-defs  ~["private dependency projection evidence is missing"]
  ~
++  test-proj-guards
  ^-  tang
  (turn proj-guard-errors |=(reason=tape leaf+reason))
--
