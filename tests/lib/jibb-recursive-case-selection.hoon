/+  jibb
|%
++  test-disjoint-case-selection
  ^-  tang
  =/  end=lit:jibb  [%term %tas %end '%end']
  =/  link=lit:jibb  [%term %tas %link '%link']
  =/  case=itype:jibb  [%cell [%const link] [%atom %ud]]
  =/  target=itype:jibb  [%union ~[[%const end] case] ~ ~ ~]
  =/  chosen=(unit itype:jibb)  (contextual-tagged-case:jibb target %link ~)
  ?~  chosen  ~[leaf+"distinct atom case prevented tagged-cell selection"]
  ?.  =(u.chosen case)  ~[leaf+"wrong tagged case selected"]
  ?>  ?=(%union -.target)
  =.  target  target(cases ~[[%noun ~] case])
  ?^  (contextual-tagged-case:jibb target %link ~)  ~[leaf+"overlapping noun rival was ignored"]
  =.  target  target(cases ~[[%var 17] case])
  ?^  (contextual-tagged-case:jibb target %link ~)  ~[leaf+"open rival was ignored"]
  =.  target  target(cases ~[case case])
  ?^  (contextual-tagged-case:jibb target %link ~)  ~[leaf+"duplicate cell case was accepted"]
  ~
--
