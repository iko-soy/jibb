::  The Hoon port of the Core-to-JavaScript compiler, jibb-js, against the
::  text js/core/compiler.mjs emits for the same Core.  tests/js-emit holds
::  each case's Core, natives and expected module; node
::  tools/js-emit-update.mjs regenerates them, and js/test/emit.test.mjs
::  keeps them equal to the JavaScript compiler's output.
/+  jibb-core, jibb-js
/*  core-0  %txt  /tests/js-emit/fixture-arbitrary-precision-atom/core/txt
/*  natives-0  %txt  /tests/js-emit/fixture-arbitrary-precision-atom/natives/txt
/*  js-0  %txt  /tests/js-emit/fixture-arbitrary-precision-atom/js/txt
/*  core-1  %txt  /tests/js-emit/fixture-cell-construction-and-projection/core/txt
/*  natives-1  %txt  /tests/js-emit/fixture-cell-construction-and-projection/natives/txt
/*  js-1  %txt  /tests/js-emit/fixture-cell-construction-and-projection/js/txt
/*  core-2  %txt  /tests/js-emit/fixture-immutable-edit/core/txt
/*  natives-2  %txt  /tests/js-emit/fixture-immutable-edit/natives/txt
/*  js-2  %txt  /tests/js-emit/fixture-immutable-edit/js/txt
/*  core-3  %txt  /tests/js-emit/fixture-structural-equality/core/txt
/*  natives-3  %txt  /tests/js-emit/fixture-structural-equality/natives/txt
/*  js-3  %txt  /tests/js-emit/fixture-structural-equality/js/txt
/*  core-4  %txt  /tests/js-emit/fixture-lazy-selected-branch/core/txt
/*  natives-4  %txt  /tests/js-emit/fixture-lazy-selected-branch/natives/txt
/*  js-4  %txt  /tests/js-emit/fixture-lazy-selected-branch/js/txt
/*  core-5  %txt  /tests/js-emit/fixture-strict-unused-let/core/txt
/*  natives-5  %txt  /tests/js-emit/fixture-strict-unused-let/natives/txt
/*  js-5  %txt  /tests/js-emit/fixture-strict-unused-let/js/txt
/*  core-6  %txt  /tests/js-emit/fixture-lexical-closure-and-native-sample/core/txt
/*  natives-6  %txt  /tests/js-emit/fixture-lexical-closure-and-native-sample/natives/txt
/*  js-6  %txt  /tests/js-emit/fixture-lexical-closure-and-native-sample/js/txt
/*  core-7  %txt  /tests/js-emit/fixture-mutual-recursion/core/txt
/*  natives-7  %txt  /tests/js-emit/fixture-mutual-recursion/natives/txt
/*  js-7  %txt  /tests/js-emit/fixture-mutual-recursion/js/txt
/*  core-8  %txt  /tests/js-emit/fixture-higher-order-native-callback/core/txt
/*  natives-8  %txt  /tests/js-emit/fixture-higher-order-native-callback/natives/txt
/*  js-8  %txt  /tests/js-emit/fixture-higher-order-native-callback/js/txt
/*  core-9  %txt  /tests/js-emit/fixture-explicit-crash/core/txt
/*  natives-9  %txt  /tests/js-emit/fixture-explicit-crash/natives/txt
/*  js-9  %txt  /tests/js-emit/fixture-explicit-crash/js/txt
/*  core-10  %txt  /tests/js-emit/fixture-malformed-runtime-axis/core/txt
/*  natives-10  %txt  /tests/js-emit/fixture-malformed-runtime-axis/natives/txt
/*  js-10  %txt  /tests/js-emit/fixture-malformed-runtime-axis/js/txt
/*  core-11  %txt  /tests/js-emit/extra-self-tail-loop/core/txt
/*  natives-11  %txt  /tests/js-emit/extra-self-tail-loop/natives/txt
/*  js-11  %txt  /tests/js-emit/extra-self-tail-loop/js/txt
/*  core-12  %txt  /tests/js-emit/extra-tail-rec-arm/core/txt
/*  natives-12  %txt  /tests/js-emit/extra-tail-rec-arm/natives/txt
/*  js-12  %txt  /tests/js-emit/extra-tail-rec-arm/js/txt
/*  core-13  %txt  /tests/js-emit/extra-nested-lets/core/txt
/*  natives-13  %txt  /tests/js-emit/extra-nested-lets/natives/txt
/*  js-13  %txt  /tests/js-emit/extra-nested-lets/js/txt
/*  core-14  %txt  /tests/js-emit/extra-trace/core/txt
/*  natives-14  %txt  /tests/js-emit/extra-trace/natives/txt
/*  js-14  %txt  /tests/js-emit/extra-trace/js/txt
/*  core-15  %txt  /tests/js-emit/extra-closed-inner-lambda/core/txt
/*  natives-15  %txt  /tests/js-emit/extra-closed-inner-lambda/natives/txt
/*  js-15  %txt  /tests/js-emit/extra-closed-inner-lambda/js/txt
/*  core-16  %txt  /tests/js-emit/extra-checked-view-template/core/txt
/*  natives-16  %txt  /tests/js-emit/extra-checked-view-template/natives/txt
/*  js-16  %txt  /tests/js-emit/extra-checked-view-template/js/txt
/*  core-17  %txt  /tests/js-emit/extra-view-template-trace/core/txt
/*  natives-17  %txt  /tests/js-emit/extra-view-template-trace/natives/txt
/*  js-17  %txt  /tests/js-emit/extra-view-template-trace/js/txt
/*  core-18  %txt  /tests/js-emit/extra-view-template-recursive/core/txt
/*  natives-18  %txt  /tests/js-emit/extra-view-template-recursive/natives/txt
/*  js-18  %txt  /tests/js-emit/extra-view-template-recursive/js/txt
/*  core-19  %txt  /tests/js-emit/extra-view-template-inner/core/txt
/*  natives-19  %txt  /tests/js-emit/extra-view-template-inner/natives/txt
/*  js-19  %txt  /tests/js-emit/extra-view-template-inner/js/txt
/*  core-20  %txt  /tests/js-emit/extra-view-template-closed-inner/core/txt
/*  natives-20  %txt  /tests/js-emit/extra-view-template-closed-inner/natives/txt
/*  js-20  %txt  /tests/js-emit/extra-view-template-closed-inner/js/txt
/*  core-21  %txt  /tests/js-emit/extra-view-template-branches/core/txt
/*  natives-21  %txt  /tests/js-emit/extra-view-template-branches/natives/txt
/*  js-21  %txt  /tests/js-emit/extra-view-template-branches/js/txt
/*  core-22  %txt  /tests/js-emit/extra-view-template-limits/core/txt
/*  natives-22  %txt  /tests/js-emit/extra-view-template-limits/natives/txt
/*  js-22  %txt  /tests/js-emit/extra-view-template-limits/js/txt
/*  core-23  %txt  /tests/js-emit/extra-view-template-child-holes/core/txt
/*  natives-23  %txt  /tests/js-emit/extra-view-template-child-holes/natives/txt
/*  js-23  %txt  /tests/js-emit/extra-view-template-child-holes/js/txt
/*  core-24  %txt  /tests/js-emit/extra-view-template-child-fallbacks/core/txt
/*  natives-24  %txt  /tests/js-emit/extra-view-template-child-fallbacks/natives/txt
/*  js-24  %txt  /tests/js-emit/extra-view-template-child-fallbacks/js/txt
/*  core-25  %txt  /tests/js-emit/extra-view-template-constant-bounds/core/txt
/*  natives-25  %txt  /tests/js-emit/extra-view-template-constant-bounds/natives/txt
/*  js-25  %txt  /tests/js-emit/extra-view-template-constant-bounds/js/txt
/*  core-26  %txt  /tests/js-emit/extra-direct-template-operations/core/txt
/*  natives-26  %txt  /tests/js-emit/extra-direct-template-operations/natives/txt
/*  js-26  %txt  /tests/js-emit/extra-direct-template-operations/js/txt
/*  core-27  %txt  /tests/js-emit/extra-direct-template-closure/core/txt
/*  natives-27  %txt  /tests/js-emit/extra-direct-template-closure/natives/txt
/*  js-27  %txt  /tests/js-emit/extra-direct-template-closure/js/txt
/*  core-28  %txt  /tests/js-emit/extra-direct-template-sharing/core/txt
/*  natives-28  %txt  /tests/js-emit/extra-direct-template-sharing/natives/txt
/*  js-28  %txt  /tests/js-emit/extra-direct-template-sharing/js/txt
/*  core-29  %txt  /tests/js-emit/extra-direct-template-capture-fallback/core/txt
/*  natives-29  %txt  /tests/js-emit/extra-direct-template-capture-fallback/natives/txt
/*  js-29  %txt  /tests/js-emit/extra-direct-template-capture-fallback/js/txt
/*  core-30  %txt  /tests/js-emit/extra-direct-template-rec-fallback/core/txt
/*  natives-30  %txt  /tests/js-emit/extra-direct-template-rec-fallback/natives/txt
/*  js-30  %txt  /tests/js-emit/extra-direct-template-rec-fallback/js/txt
/*  core-31  %txt  /tests/js-emit/extra-direct-template-loop-capture/core/txt
/*  natives-31  %txt  /tests/js-emit/extra-direct-template-loop-capture/natives/txt
/*  js-31  %txt  /tests/js-emit/extra-direct-template-loop-capture/js/txt
/*  core-32  %txt  /tests/js-emit/extra-direct-template-fuel/core/txt
/*  natives-32  %txt  /tests/js-emit/extra-direct-template-fuel/natives/txt
/*  js-32  %txt  /tests/js-emit/extra-direct-template-fuel/js/txt
/*  core-33  %txt  /tests/js-emit/extra-direct-template-origins/core/txt
/*  natives-33  %txt  /tests/js-emit/extra-direct-template-origins/natives/txt
/*  js-33  %txt  /tests/js-emit/extra-direct-template-origins/js/txt
/*  core-34  %txt  /tests/js-emit/extra-direct-template-hoisted/core/txt
/*  natives-34  %txt  /tests/js-emit/extra-direct-template-hoisted/natives/txt
/*  js-34  %txt  /tests/js-emit/extra-direct-template-hoisted/js/txt
/*  core-35  %txt  /tests/js-emit/extra-direct-template-ambiguous/core/txt
/*  natives-35  %txt  /tests/js-emit/extra-direct-template-ambiguous/natives/txt
/*  js-35  %txt  /tests/js-emit/extra-direct-template-ambiguous/js/txt
/*  core-36  %txt  /tests/js-emit/extra-direct-template-effectful/core/txt
/*  natives-36  %txt  /tests/js-emit/extra-direct-template-effectful/natives/txt
/*  js-36  %txt  /tests/js-emit/extra-direct-template-effectful/js/txt
/*  core-37  %txt  /tests/js-emit/extra-direct-template-shape-fuel/core/txt
/*  natives-37  %txt  /tests/js-emit/extra-direct-template-shape-fuel/natives/txt
/*  js-37  %txt  /tests/js-emit/extra-direct-template-shape-fuel/js/txt
/*  core-38  %txt  /tests/js-emit/extra-direct-template-branch-sharing/core/txt
/*  natives-38  %txt  /tests/js-emit/extra-direct-template-branch-sharing/natives/txt
/*  js-38  %txt  /tests/js-emit/extra-direct-template-branch-sharing/js/txt
/*  core-39  %txt  /tests/js-emit/extra-direct-template-capture-order/core/txt
/*  natives-39  %txt  /tests/js-emit/extra-direct-template-capture-order/natives/txt
/*  js-39  %txt  /tests/js-emit/extra-direct-template-capture-order/js/txt
/*  core-40  %txt  /tests/js-emit/extra-direct-template-nested-branch-fuel/core/txt
/*  natives-40  %txt  /tests/js-emit/extra-direct-template-nested-branch-fuel/natives/txt
/*  js-40  %txt  /tests/js-emit/extra-direct-template-nested-branch-fuel/js/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (cat 3 (of-wain:format lines) '\0a')
::  A registry naming each native the case uses; the emitter never runs one.
++  registry
  |=  names=wain
  ^-  native-registry:jibb-core
  %-  malt
  %+  turn  (skip names |=(n=@t =('' n)))
  |=  n=@t
  ^-  [name:jibb-core native:jibb-core]
  [[%own `@tas`n] |=(v=value:jibb-core [v ~])]
++  check
  |=  [label=tape core=wain natives=wain js=wain]
  ^-  tang
  =/  read=(each expr:jibb-core @t)  (read-expr:jibb-core (of-wain:format core) (registry natives))
  ?:  ?=(%| -.read)  ~[leaf+"{label}: {(trip p.read)}"]
  =/  got=@t  (compile:jibb-js p.read)
  ?:  =((text js) got)  ~
  ~[leaf+"{label}: the Hoon emitter differs from js/core/compiler.mjs" leaf+(trip got)]
++  test-emitter-matches-javascript
  ^-  tang
  ;:  weld
    (check "fixture-arbitrary-precision-atom" core-0 natives-0 js-0)
    (check "fixture-cell-construction-and-projection" core-1 natives-1 js-1)
    (check "fixture-immutable-edit" core-2 natives-2 js-2)
    (check "fixture-structural-equality" core-3 natives-3 js-3)
    (check "fixture-lazy-selected-branch" core-4 natives-4 js-4)
    (check "fixture-strict-unused-let" core-5 natives-5 js-5)
    (check "fixture-lexical-closure-and-native-sample" core-6 natives-6 js-6)
    (check "fixture-mutual-recursion" core-7 natives-7 js-7)
    (check "fixture-higher-order-native-callback" core-8 natives-8 js-8)
    (check "fixture-explicit-crash" core-9 natives-9 js-9)
    (check "fixture-malformed-runtime-axis" core-10 natives-10 js-10)
    (check "extra-self-tail-loop" core-11 natives-11 js-11)
    (check "extra-tail-rec-arm" core-12 natives-12 js-12)
    (check "extra-nested-lets" core-13 natives-13 js-13)
    (check "extra-trace" core-14 natives-14 js-14)
    (check "extra-closed-inner-lambda" core-15 natives-15 js-15)
    (check "extra-checked-view-template" core-16 natives-16 js-16)
    (check "extra-view-template-trace" core-17 natives-17 js-17)
    (check "extra-view-template-recursive" core-18 natives-18 js-18)
    (check "extra-view-template-inner" core-19 natives-19 js-19)
    (check "extra-view-template-closed-inner" core-20 natives-20 js-20)
    (check "extra-view-template-branches" core-21 natives-21 js-21)
    (check "extra-view-template-limits" core-22 natives-22 js-22)
    (check "extra-view-template-child-holes" core-23 natives-23 js-23)
    (check "extra-view-template-child-fallbacks" core-24 natives-24 js-24)
    (check "extra-view-template-constant-bounds" core-25 natives-25 js-25)
    (check "extra-direct-template-operations" core-26 natives-26 js-26)
    (check "extra-direct-template-closure" core-27 natives-27 js-27)
    (check "extra-direct-template-sharing" core-28 natives-28 js-28)
    (check "extra-direct-template-capture-fallback" core-29 natives-29 js-29)
    (check "extra-direct-template-rec-fallback" core-30 natives-30 js-30)
    (check "extra-direct-template-loop-capture" core-31 natives-31 js-31)
    (check "extra-direct-template-fuel" core-32 natives-32 js-32)
    (check "extra-direct-template-origins" core-33 natives-33 js-33)
    (check "extra-direct-template-hoisted" core-34 natives-34 js-34)
    (check "extra-direct-template-ambiguous" core-35 natives-35 js-35)
    (check "extra-direct-template-effectful" core-36 natives-36 js-36)
    (check "extra-direct-template-shape-fuel" core-37 natives-37 js-37)
    (check "extra-direct-template-branch-sharing" core-38 natives-38 js-38)
    (check "extra-direct-template-capture-order" core-39 natives-39 js-39)
    (check "extra-direct-template-nested-branch-fuel" core-40 natives-40 js-40)
  ==
--
