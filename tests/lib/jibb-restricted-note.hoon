/+  jibb
|%
++  test-restricted-note
  ^-  tang
  =/  rn=itype:jibb  [%fn [%cell [%rnvar 0] [%rnvar 0]] [%rnvar 0]]
  =/  r=itype:jibb  [%fn [%rvar 0] [%rvar 0]]
  =/  a=itype:jibb  [%fn [%avar 0] [%avar 0]]
  =/  n=itype:jibb  [%fn [%nvar 0] [%nvar 0]]
  ?.  =((show-atom-constraint:jibb rn) " where A is an atom other than ?")
    ~[leaf+"restricted decimal lost its non-loobean constraint"]
  ?.  =((show-atom-constraint:jibb r) " where A is an atom other than ?")
    ~[leaf+"restricted variable lost its non-loobean constraint"]
  ?.  =((show-atom-constraint:jibb a) " where A is an atom")
    ~[leaf+"ordinary atom variable acquired a non-loobean restriction"]
  ?.  =((show-atom-constraint:jibb n) " where A is an atom")
    ~[leaf+"ordinary decimal variable acquired a non-loobean restriction"]
  ~
--
