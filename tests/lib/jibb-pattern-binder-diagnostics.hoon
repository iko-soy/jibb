/+  jibb
|%
++  test-pattern-binder-diagnostics
  ^-  tang
  =/  first=span:jibb  [[1 5] [1 6]]
  =/  second=span:jibb  [[1 10] [1 11]]
  =/  one=pattern:jibb  [%bind first %x]
  =/  two=pattern:jibb  [%bind second %x]
  =/  nested=pattern:jibb  [%cell *span:jibb ~[one [%cell *span:jibb ~[two]]]]
  =/  duplicate=(unit idiag:jibb)  (coverage-binder-diagnostic:jibb ~[nested] ~ ~ *(map term span:jibb))
  ?~  duplicate  ~[leaf+"duplicate binder was not diagnosed"]
  ?.  =(sites.u.duplicate ~[[first "first binder"] [second "repeated binder"]])
    ~[leaf+"duplicate binder sites changed"]
  =/  outer=(unit idiag:jibb)  (coverage-binder-diagnostic:jibb ~[one] ~[[%x [[%atom %t] ~ ~]]] ~ *(map term span:jibb))
  ?~  outer  ~[leaf+"outer binder shadow was not diagnosed"]
  ?.  =(sites.u.outer ~[[first "shadowing binder"]])  ~[leaf+"outer binder site changed"]
  =/  global=(unit idiag:jibb)  (coverage-binder-diagnostic:jibb ~[one] ~ ~[%x] *(map term span:jibb))
  ?~  global  ~[leaf+"global shadow was not diagnosed"]
  ?^  (coverage-binder-diagnostic:jibb ~[one] ~ ~ *(map term span:jibb))
    ~[leaf+"a fresh binder was rejected"]
  ~
--
