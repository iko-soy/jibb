/+  jibb
|%
++  test-list-cell-fit
  ^-  tang
  =/  list=itype:jibb  [%collection %list ~[[%atom %t]]]
  =/  actual=itype:jibb  [%cell [%atom %t] list]
  =/  positive=ifit:jibb  (itype-fit:jibb actual list ~ 10)
  ?.  ?=(%ok -.positive)  ~[leaf+"valid nonempty list cell did not fit"]
  =/  bad-head=itype:jibb  [%cell [%atom %ud] list]
  =/  head-fit=ifit:jibb  (itype-fit:jibb bad-head list ~ 10)
  ?:  ?=(%ok -.head-fit)  ~[leaf+"mismatched list element was accepted"]
  =/  bad-tail=itype:jibb  [%cell [%atom %t] [%atom %ud]]
  =/  tail-fit=ifit:jibb  (itype-fit:jibb bad-tail list ~ 10)
  ?:  ?=(%ok -.tail-fit)  ~[leaf+"non-list tail was accepted"]
  =/  unknown=itype:jibb  [%cell [%var 0] [%var 1]]
  =/  fit=ifit:jibb  (itype-fit:jibb unknown list ~ 10)
  ?.  ?=(%ok -.fit)  ~[leaf+"known list context did not fix its cell components"]
  ?.  =((itype-normalize:jibb [%var 0] sub.fit) [%atom %t])  ~[leaf+"list element context was lost"]
  ?.  =((itype-normalize:jibb [%var 1] sub.fit) list)  ~[leaf+"list tail context was lost"]
  =/  faced=itype:jibb  [%cell [%face %x [%atom %t]] list]
  =/  faced-fit=ifit:jibb  (itype-fit:jibb faced list ~ 10)
  ?:  ?=(%ok -.faced-fit)  ~[leaf+"list fit discarded an element value face"]
  =/  same-list=itype:jibb  [%collection %list ~[[%face %x [%atom %t]]]]
  =/  same-cell=itype:jibb  [%cell [%face %x [%atom %t]] same-list]
  =/  same-fit=ifit:jibb  (itype-fit:jibb same-cell same-list ~ 10)
  ?.  ?=(%ok -.same-fit)  ~[leaf+"matching element value face was rejected"]
  =/  generic-list=itype:jibb  [%collection %list ~[[%var 2]]]
  =/  generic-fit=ifit:jibb  (itype-fit:jibb faced generic-list ~ 10)
  ?:  ?=(%ok -.generic-fit)  ~[leaf+"list fit erased a faced generic element"]
  =/  set=itype:jibb  [%collection %set ~[[%atom %t]]]
  =/  set-fit=ifit:jibb  (itype-fit:jibb actual set ~ 10)
  ?:  ?=(%ok -.set-fit)  ~[leaf+"list cell was accepted as a set"]
  ~
--
