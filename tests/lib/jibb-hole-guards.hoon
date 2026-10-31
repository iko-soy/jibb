::  Verify hole defaulting and API fail-closed boundaries under eval and ship.
/+  jibb
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
|%
++  hole-guard-errors
  ^-  (list tape)
  =/  base=istate:jibb  *istate:jibb
  =.  base  base(sub ~[[0 [%nvar 1]]], holes ~[[0 *span:jibb]], next 2)
  =/  env=ienv:jibb  ~[[%outer [[%var 1] ~]]]
  =/  guarded=istate:jibb  (default-hole-numbers:jibb holes.base ~ base env &)
  =/  independent=istate:jibb  (default-hole-numbers:jibb holes.base ~ base ~ &)
  =/  explicit=istate:jibb  base(caps ~[['A' 1 *span:jibb]])
  =/  named=istate:jibb  (default-hole-numbers:jibb holes.explicit ~ explicit ~ &)
  =/  failures=(list tape)  ~
  =?  failures  !?=(~ (itype-lookup:jibb 1 sub.guarded))
    ["a captured numeric variable was defaulted" failures]
  =?  failures  !?=([~ [%atom %ud]] (itype-lookup:jibb 1 sub.independent))
    ["an independent numeric variable did not default to @ud" failures]
  =?  failures  !?=(~ (itype-lookup:jibb 1 sub.named))
    ["a written-capital numeric variable was defaulted" failures]
  ::  A named-mold hole is definite only in a valid generic scope.
  =/  hole=shape:jibb  [%hole *span:jibb ~]
  =/  outer=shape:jibb  [%generic *span:jibb ~['A'] [%fn *span:jibb [%tvar *span:jibb 'A'] hole]]
  =/  empty=shape:jibb  [%generic *span:jibb ~ hole]
  =/  dup=shape:jibb  [%generic *span:jibb ~['A' 'A'] hole]
  =/  shadow=shape:jibb  [%generic *span:jibb ~['A'] [%generic *span:jibb ~['A'] hole]]
  =/  fresh=shape:jibb  [%generic *span:jibb ~['A'] [%generic *span:jibb ~['B'] [%fn *span:jibb [%tvar *span:jibb 'A'] hole]]]
  =/  unbound=shape:jibb  [%generic *span:jibb ~['A'] [%fn *span:jibb [%tvar *span:jibb 'B'] hole]]
  =?  failures  !?=([~ [~ *]] (simple-mold-hole:jibb outer))
    ["a valid generic structural hole was not detected" failures]
  =?  failures  ?=(^ (simple-mold-hole:jibb empty))
    ["an empty generic parameter scope reported a definite hole" failures]
  =?  failures  ?=(^ (simple-mold-hole:jibb dup))
    ["duplicate generic parameters reported a definite hole" failures]
  =?  failures  ?=(^ (simple-mold-hole:jibb shadow))
    ["a shadowed generic parameter reported a definite hole" failures]
  =?  failures  ?=(^ (simple-mold-hole:jibb fresh))
    ["a nested generic scope reported a definite hole" failures]
  =?  failures  ?=(^ (simple-mold-hole:jibb unbound))
    ["an unbound capital reported a definite hole" failures]
  =/  path-good=@t  (crip "/% %todo\0a+$ paths [%one /one todo]\0a")
  =/  path-bad=@t  (cat 3 path-good '+$ unused [a=_]\0a')
  =/  path-value=@t  (cat 3 path-good '++ unused |= x=_ x\0a')
  =/  g=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb path-good)
  =/  b=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb path-bad)
  =/  v=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb path-value)
  ?.  &(?=(%& -.g) ?=(%& -.b) ?=(%& -.v))
    ["API path control sources did not parse" failures]
  =/  ext=imark-externals:jibb  ~[[%todo [%& [%atom %t ~]]]]
  =?  failures  ?=(~ (api-path-analysis:jibb p.g ext ~ ~))
    ["a valid API path was rejected" failures]
  =?  failures  ?=(^ (api-path-analysis:jibb p.b ext ~ ~))
    ["an API path ignored an unused mold hole" failures]
  =?  failures  ?=(^ (api-path-analysis:jibb p.v ext ~ ~))
    ["an API path ignored an unused value hole" failures]
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb real-prelude real-internal)
  ?~  prepared  ["actual prelude was not prepared" failures]
  =/  poke-good=@t  (crip "/% %todo\0a+$ poke todo\0a")
  =/  poke-bad=@t  (cat 3 poke-good '+$ unused [a=_]\0a')
  =/  poke-value=@t  (cat 3 poke-good '++ unused |= x=_ x\0a')
  =/  pg=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb poke-good)
  =/  pb=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb poke-bad)
  =/  pv=(each module:jibb error:jibb)  (parse:jibb /ui/api/demo/jibb poke-value)
  ?.  &(?=(%& -.pg) ?=(%& -.pb) ?=(%& -.pv))
    ["API poke control sources did not parse" failures]
  =?  failures  ?=(~ (api-poke-interface:jibb /ui/api/demo/jibb p.pg ext values.u.prepared molds.u.prepared `iface.u.prepared))
    ["a valid API poke interface was rejected" failures]
  =?  failures  ?=(^ (api-poke-interface:jibb /ui/api/demo/jibb p.pb ext values.u.prepared molds.u.prepared `iface.u.prepared))
    ["an API poke interface ignored an unused mold hole" failures]
  =?  failures  ?=(^ (api-poke-interface:jibb /ui/api/demo/jibb p.pv ext values.u.prepared molds.u.prepared `iface.u.prepared))
    ["an API poke interface ignored an unused value hole" failures]
  (flop failures)
++  test-hole-guards
  ^-  tang
  (turn hole-guard-errors |=(reason=tape leaf+reason))
--
