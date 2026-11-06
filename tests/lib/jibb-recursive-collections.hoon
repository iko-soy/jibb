/+  jibb
|%
++  test-recursive-collections
  ^-  tang
  =/  names=(list term)  ~[%unit %set %qeu %map %mop %jar %jug]
  =/  bad=(list term)
    %+  skim  names
    |=  name=term
    =/  args=(list *)
      ?:  |(=(name %unit) =(name %set) =(name %qeu))  ~[[%ref %notes %node]]
      ~[[%atom %t ~] [%ref %notes %node]]
    =/  node=*
      [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %item]] [%apply name args]]]]
    =/  found=(unit itype:jibb)
      (find-imported-mold:jibb %notes %node ~[[%notes %node [%& node]]] ~[%notes])
    !?=([~ [%recursive *]] found)
  =/  positives=tang
    %+  turn  bad
    |=  name=term
    leaf+"recursive {(trip name)} was rejected"
  =/  unsafe=(list term)
    %+  skim  names
    |=  name=term
    =/  one=?  |(=(name %unit) =(name %set) =(name %qeu))
    =/  foreign=(list *)  ?:(one ~[[%ref %other %node]] ~[[%atom %t ~] [%ref %other %node]])
    =/  overlap=(list *)  ?:(one ~[[%ref %notes %node]] ~[[%atom %t ~] [%ref %notes %node]])
    =/  node=*
      [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %item]] [%apply name foreign]]]]
    =/  overlapped=*
      [%fork ~[[%atom %n [~ 0]] [%apply name overlap]]]
    =/  f=(unit itype:jibb)
      (find-imported-mold:jibb %notes %node ~[[%notes %node [%& node]]] ~[%notes])
    =/  o=(unit itype:jibb)
      (find-imported-mold:jibb %notes %node ~[[%notes %node [%& overlapped]]] ~[%notes])
    |(?=([~ [%recursive *]] f) ?=([~ [%recursive *]] o))
  =/  negatives=tang
    %+  turn  unsafe
    |=  name=term
    leaf+"recursive {(trip name)} accepted an unsafe origin or overlap"
  (weld positives negatives)
--
