/+  jibb
|%
++  test-tagged-fixedpoint
  ^-  tang
  =/  src=@t  (of-wain:format ~['++ x [%.y %foo]' '++ y [%.n value=~.x]'])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/fixed/jibb src)
  ?:  ?=(%| -.parsed)  ~[leaf+"flag dependency controls did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] [%value *] ~] ds)  ~[leaf+"flag dependency definitions are missing"]
  =/  outer=expr:jibb  val.i.ds
  =/  inner=expr:jibb  val.i.t.ds
  =/  site=span:jibb  *span:jibb
  =/  lit=lit:jibb  [%term %tas %foo '%foo']
  =/  tag=itype:jibb  [%tag 0 lit |]
  =/  first=icore-edge:jibb  [%tagged-cell [%cell [%flag ~] tag] [%var 1] outer site %x ~ ~ ~ ~ ~ ~ 0 ~]
  =/  second=icore-edge:jibb  [%tagged-cell [%cell [%flag ~] [%face %value [%atom %tas]]] [%var 2] inner site %y ~ ~ ~ ~ ~ ~ 0 ~]
  =/  state=istate:jibb  *istate:jibb
  =.  state
    state(next 4, general-defer &, queue ~[first [%tag 0 lit | site] [%fit tag [%var 3] site site %$ ~] [%wing [%var 2] ~[%value] [%var 3] site] second])
  =/  settled=(unit istate:jibb)  (icore-settle-defaults:jibb state)
  ?~  settled  ~[leaf+"dependent flag defaults failed"]
  ?^  queue.u.settled  ~[leaf+"dependent flag defaults stopped before reaching a fixed point"]
  =/  outer-type=itype:jibb  (itype-walk:jibb [%var 1] sub.u.settled)
  ?.  ?=(%cell -.outer-type)
    ~[leaf+"outer flag tuple did not acquire its default type"]
  ~
--
