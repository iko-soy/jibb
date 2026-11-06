/+  jibb
|%
++  test-value-path
  ^-  tang
  =/  parsed=(each module:jibb error:jibb)
    (parse:jibb /tests/path/jibb '++ init |= input=@t [input [%zero ~zod]]\0a')
  ?:  ?=(%| -.parsed)  ~[leaf+"fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?~  ds  ~[leaf+"fixture missing definition"]
  ?.  ?=(%value -.i.ds)  ~[leaf+"fixture missing value"]
  =/  typed=(unit expr:jibb)
    (diagnostic-source-type-path:jibb val.i.ds ~[%product %tail %tail])
  ?~  typed  ~[leaf+"type route did not find nested field"]
  ?.  ?=(%lit -.u.typed)  ~[leaf+"type route found wrong expression"]
  ?.  =(txt.lit.u.typed '~zod')  ~[leaf+"type route found wrong literal"]
  ?^  (diagnostic-source-type-path:jibb val.i.ds ~[%sample])  ~[leaf+"sample source was guessed"]
  ~
++  test-fit-ancestry
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  tag=itype:jibb  [%tag 1 [%term %tas %tagged '%tagged'] |]
  =/  left=itype:jibb  [%cell tag [%atom %t]]
  =/  right=itype:jibb  [%cell [%var 0] [%atom %t]]
  =/  forcing=expr:jibb  [%wing site ~[%x]]
  =/  parts=(unit (list icore-edge:jibb))  (icore-fit-parts:jibb left right ~ site site %owner ~)
  ?~  parts  ~[leaf+"decomposition declined"]
  =/  wrapped=(unit (list icore-edge:jibb))
    (icore-guarded-wrap:jibb u.parts %owner ~ forcing | ~ ~[[left right ~ ~]])
  ?~  wrapped  ~[leaf+"decomposition lost guard"]
  ?~  u.wrapped  ~[leaf+"decomposition lost children"]
  =/  pending=icore-edge:jibb  i.u.wrapped
  ?.  ?=(%guarded-fit -.pending)  ~[leaf+"pending child lost guard"]
  ?~  ancestors.pending  ~[leaf+"pending child lost its parent"]
  ?.  =(left.i.ancestors.pending left)  ~[leaf+"left parent changed"]
  ?.  =(right.i.ancestors.pending right)  ~[leaf+"right parent changed"]
  ?.  =(sub.i.ancestors.pending ~)  ~[leaf+"parent snapshot changed"]
  ~
++  test-fit-root-path
  ^-  tang
  =/  source=itype:jibb  [%cell [%atom %ud] [%cell [%atom %p] [%atom %t]]]
  =/  sub=isub:jibb  (itype-bind:jibb 0 source ~)
  =/  draft=itype:jibb  [%slot %draft [%atom %t]]
  =/  left-tail=itype:jibb  [%cell draft [%atom %t]]
  =/  right-tail=itype:jibb  [%cell [%atom %p] [%atom %t]]
  =/  left=itype:jibb  [%cell [%atom %ud] left-tail]
  =/  ancestors=(list ifit-ancestor:jibb)
    ~[[draft [%atom %p] sub ~] [left-tail right-tail sub ~] [left [%var 0] sub ~]]
  =/  found=(unit [id=@ud path=(list idiagnostic-fit-step:jibb) sub=isub:jibb])
    (diagnostic-fit-root:jibb [%atom %t] [%atom %p] ancestors ~)
  ?~  found  ~[leaf+"shared root path was not found"]
  ?.  =(id.u.found 0)  ~[leaf+"wrong shared root"]
  ?.  =(path.u.found ~[%tail %head])  ~[leaf+"wrong source field path"]
  =/  ambiguous=(list ifit-ancestor:jibb)
    ~[[[%cell [%atom %t] [%atom %t]] [%cell [%atom %p] [%atom %p]] sub ~]]
  ?^  (diagnostic-fit-root:jibb [%atom %t] [%atom %p] ambiguous ~)  ~[leaf+"ambiguous child position was guessed"]
  ?^  (diagnostic-fit-root:jibb [%atom %ud] [%atom %p] ancestors ~)  ~[leaf+"unrelated child gained provenance"]
  ~
++  test-call-origin
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  first=expr:jibb  [%wing site ~[%init]]
  =/  second=expr:jibb  [%wing site ~[%later]]
  =/  model=itype:jibb  [%cell [%atom %ud] [%cell [%atom %p] [%atom %t]]]
  =/  sub=isub:jibb  (itype-bind:jibb 1 model ~)
  =/  actual=itype:jibb  [%cell [%fn [%atom %t] [%var 1]] [%atom %p]]
  =/  expected=itype:jibb  [%cell [%fn [%atom %t] [%var 0]] [%atom %t]]
  =/  found=(unit [source=expr:jibb typ=itype:jibb path=(list idiagnostic-fit-step:jibb) sub=isub:jibb])
    (diagnostic-call-origin:jibb ~[first second] actual expected 0 sub 2)
  ?~  found  ~[leaf+"first successful binding was not traced"]
  ?.  =(source.u.found first)  ~[leaf+"wrong source argument"]
  ?.  =(typ.u.found [%var 1])  ~[leaf+"actual root identity lost"]
  ?.  =(path.u.found ~[%product])  ~[leaf+"wrong gate product path"]
  =/  repeated=itype:jibb  [%cell [%fn [%var 0] [%var 0]] [%atom %t]]
  =/  both=itype:jibb  [%cell [%fn [%var 1] [%var 1]] [%atom %p]]
  ?^  (diagnostic-call-origin:jibb ~[first second] both repeated 0 sub 2)  ~[leaf+"ambiguous repeated occurrence was guessed"]
  ~
++  test-call-origin-tag-identity
  ^-  tang
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  first=expr:jibb  [%wing site ~[%init]]
  =/  tag=itype:jibb  [%tag 2 [%null %n 0 '~'] |]
  =/  model=itype:jibb  [%cell [%atom %ud] [%cell [%atom %p] tag]]
  =/  sub=isub:jibb  (itype-bind:jibb 1 model ~)
  =/  actual=itype:jibb  [%fn [%atom %t] [%var 1]]
  =/  expected=itype:jibb  [%fn [%atom %t] [%var 0]]
  =/  result=(unit [source=expr:jibb typ=itype:jibb path=(list idiagnostic-fit-step:jibb) sub=isub:jibb])
    (diagnostic-call-origin-tag:jibb ~[first] actual expected 0 ~[%tail %tail] tag sub 3)
  ?~  result  ~[leaf+"the exact pending tag lost its source"]
  ?.  =(typ.u.result [%var 1])  ~[leaf+"pending tag lost actual root identity"]
  =/  other=itype:jibb  [%tag 3 [%null %n 0 '~'] |]
  ?^  (diagnostic-call-origin-tag:jibb ~[first] actual expected 0 ~[%tail %tail] other sub 4)  ~[leaf+"equal literal from another occurrence was accepted"]
  ~
++  test-local-origin-aliases
  ^-  tang
  =/  parsed=(each module:jibb error:jibb)
    (parse:jibb /tests/path/jibb '++ first second\0a++ second |= x=@t x\0a')
  ?:  ?=(%| -.parsed)  ~[leaf+"alias fixture did not parse"]
  =/  found=(unit [name=term value=expr:jibb])
    (diagnostic-local-value-source:jibb %first defs.p.parsed ~ 32)
  ?~  found  ~[leaf+"direct local alias lost its definition"]
  ?.  =(name.u.found %second)  ~[leaf+"local alias followed the wrong definition"]
  ?.  ?=(?(%gate %gate-wide) -.value.u.found)  ~[leaf+"local alias lost the gate source"]
  =/  cyclic=(each module:jibb error:jibb)
    (parse:jibb /tests/path/jibb '++ first second\0a++ second first\0a')
  ?:  ?=(%| -.cyclic)  ~[leaf+"cycle fixture did not parse"]
  ?^  (diagnostic-local-value-source:jibb %first defs.p.cyclic ~ 32)  ~[leaf+"cyclic aliases acquired an origin"]
  ?^  (diagnostic-local-value-source:jibb %missing defs.p.parsed ~ 32)  ~[leaf+"missing source acquired an origin"]
  ~
--
