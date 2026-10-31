::  Sample labels may be peeled only at known positional call slots.
/+  jibb
|%
++  positional-face-guard-errors
  ^-  (list tape)
  =/  text-type=itype:jibb  [%atom %t]
  =/  ship-type=itype:jibb  [%atom %p]
  =/  faced=itype:jibb  [%cell [%face %x text-type] [%face %y ship-type]]
  =/  bare=itype:jibb  [%cell text-type ship-type]
  =/  actual=itype:jibb  [%cell text-type faced]
  =/  expected=itype:jibb  [%cell [%face %a text-type] [%face %b faced]]
  =/  nested=itype:jibb  [%cell [%face %a text-type] [%face %b bare]]
  =/  args=(list expr:jibb)  ~[*expr:jibb *expr:jibb]
  =/  failures=(list tape)  ~
  =?  failures  (itype-positional-face-asym:jibb args actual expected ~)
    ["expected sample labels were not peeled" failures]
  =?  failures  !(itype-positional-face-asym:jibb args actual nested ~)
    ["nested value faces were ignored" failures]
  ::  A value face matching the slot name is still part of the value.
  =/  same-actual=itype:jibb  [%cell text-type [%face %b text-type]]
  =/  same-expected=itype:jibb  [%cell [%face %a text-type] [%face %b text-type]]
  =?  failures  !(itype-positional-face-asym:jibb args same-actual same-expected ~)
    ["a same-named value face was mistaken for a sample label" failures]
  =/  deep-actual=itype:jibb  [%cell text-type [%cell [%face %b text-type] text-type]]
  =/  deep-expected=itype:jibb  [%cell [%face %a text-type] [%face %b [%cell text-type text-type]]]
  =?  failures  !(itype-positional-face-asym:jibb args deep-actual deep-expected ~)
    ["a same-named nested value face was ignored" failures]
  =/  sub=isub:jibb  ~[[0 expected]]
  =?  failures  !(itype-positional-face-asym:jibb args actual [%var 0] sub)
    ["a variable-bound expected spine was treated as structurally known" failures]
  =/  sub2=isub:jibb  ~[[0 actual]]
  =?  failures  !(itype-positional-face-asym:jibb args [%var 0] expected sub2)
    ["a variable-bound actual spine was treated as structurally known" failures]
  (flop failures)
++  test-positional-face-guards
  ^-  tang
  (turn positional-face-guard-errors |=(reason=tape leaf+reason))
--
