/+  jibb
|%
++  test-cell-fit
  ^-  tang
  =/  gate=itype:jibb  [%fn [%cell [%atom %t] [%atom %ud]] [%atom %ud]]
  =/  actual=itype:jibb  [%cell [%atom %ud] [%refined gate]]
  =/  expected=itype:jibb  [%cell [%slot %init [%atom %ud]] [%slot %update [%noun ~]]]
  =/  fit=ifit:jibb  (itype-fit:jibb actual expected ~ 0)
  ?.  ?=(%ok -.fit)  ~[leaf+"refined value could not fit a wildcard field"]
  =/  narrow=ifit:jibb  (itype-fit:jibb [%noun ~] [%slot %update [%atom %ud]] ~ 0)
  ?.  ?=(%unknown -.narrow)  ~[leaf+"unknown noun was narrowed by its field label"]
  ~
--
