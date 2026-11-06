/+  jibb
|%
++  test-scheme-alpha
  ^-  tang
  =/  a=ischeme:jibb  [[%fn [%var 30] [%var 30]] ~[30] ~]
  =/  b=ischeme:jibb  [[%fn [%var 98] [%var 98]] ~[98] ~]
  ?.  (prelude-scheme-equivalent:jibb a b)  ~[leaf+"fresh quantified IDs were not equivalent"]
  =/  independent=ischeme:jibb  [[%fn [%var 98] [%var 99]] ~[98 99] ~]
  ?:  (prelude-scheme-equivalent:jibb a independent)  ~[leaf+"independent variables were treated as shared"]
  =/  restricted=ischeme:jibb  [[%fn [%fvar 98] [%fvar 98]] ~[98] ~]
  ?:  (prelude-scheme-equivalent:jibb a restricted)  ~[leaf+"a changed variable restriction was accepted"]
  =/  free=ischeme:jibb  [[%fn [%var 98] [%var 99]] ~[98] ~]
  ?:  (prelude-scheme-equivalent:jibb a free)  ~[leaf+"a free root was accepted"]
  ~
++  test-scheme-graph-alpha
  ^-  tang
  =/  a=ischeme:jibb  [[%fn [%var 10] [%var 10]] ~[20] `[~[[10 [%fn [%var 20] [%var 20]]]] ~]]
  =/  b=ischeme:jibb  [[%fn [%var 44] [%var 44]] ~[77] `[~[[44 [%fn [%var 77] [%var 77]]]] ~]]
  ?.  (prelude-scheme-equivalent:jibb a b)  ~[leaf+"fresh structural graph IDs were not equivalent"]
  =/  split=ischeme:jibb  [[%fn [%var 44] [%var 45]] ~[77] `[~[[44 [%fn [%var 77] [%var 77]]] [45 [%fn [%var 77] [%var 77]]]] ~]]
  ?:  (prelude-scheme-equivalent:jibb a split)  ~[leaf+"independent structural values were treated as shared"]
  =/  wa=ischeme:jibb  [[%fn [%var 10] [%var 10]] ~[20] `[~[[10 [%fn [%var 20] [%var 20]]]] ~[[20 [%named %item]]]]]
  =/  wb=ischeme:jibb  [[%fn [%var 44] [%var 44]] ~[77] `[~[[44 [%fn [%var 77] [%var 77]]]] ~[[77 [%named %item]]]]]
  ?.  (prelude-scheme-equivalent:jibb wa wb)  ~[leaf+"renamed witness evidence did not match"]
  =/  wrong=ischeme:jibb  [[%fn [%var 44] [%var 44]] ~[77] `[~[[44 [%fn [%var 77] [%var 77]]]] ~[[77 [%named %other]]]]]
  ?:  (prelude-scheme-equivalent:jibb wa wrong)  ~[leaf+"different witness evidence was accepted"]
  ~
--
