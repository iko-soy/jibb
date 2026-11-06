/+  jibb
|%
++  test-public-noun-equality
  ^-  tang
  =/  proof=itype:jibb  [%refined [%atom %ud]]
  =/  noun=itype:jibb  [%noun ~]
  ?.  ?=(^ (itype-unify:jibb proof noun ~))  ~[leaf+"concrete proof did not compare as public noun"]
  ?.  ?=(^ (itype-unify:jibb noun proof ~))  ~[leaf+"concrete noun comparison was not symmetric"]
  =/  original=isub:jibb  (itype-bind:jibb 0 proof ~)
  ?:  ?=(^ (itype-unify:jibb [%var 0] noun original))  ~[leaf+"shared root kept stale private evidence"]
  ?:  ?=(^ (itype-unify:jibb noun [%var 0] original))  ~[leaf+"reverse shared root kept stale private evidence"]
  ?:  ?=(^ (itype-unify:jibb proof [%atom %ud] ~))  ~[leaf+"public noun was narrowed to its private proof"]
  ~
++  test-nested-root-preservation
  ^-  tang
  =/  gate=itype:jibb  [%refined [%fn [%atom %t] [%atom %ud]]]
  =/  known=itype:jibb  [%cell gate [%atom %t]]
  =/  unknown=itype:jibb  [%cell [%noun ~] [%atom %t]]
  =/  original=isub:jibb  (itype-bind:jibb 0 known ~)
  ?:  ?=(^ (itype-unify:jibb [%var 0] unknown original))  ~[leaf+"a nested proof leaked through a bound structural root"]
  ?:  ?=(^ (itype-unify:jibb unknown [%var 0] original))  ~[leaf+"a nested proof leaked through a reverse structural root"]
  ?.  ?=(^ (itype-unify:jibb known unknown ~))  ~[leaf+"two concrete records could not compare by their public fields"]
  ~
--
