/+  jibb-import
|%
++  test-forwarding
  ^-  tang
  =/  src=@t  '|%\0a++  table  |$  [key value]  (map key value)\0a++  swapped  |$  [a b]  (map b a)\0a++  repeat  |$  [a]  (map a a)\0a++  nested  |$  [a b]  (map a (list b))\0a++  opaque  |$  [a]  [a a]\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) src)
  =/  a  (generic-source-proof:jibb-import %table cor)
  =/  b  (generic-source-proof:jibb-import %swapped cor)
  =/  c  (generic-source-proof:jibb-import %repeat cor)
  =/  d  (generic-source-proof:jibb-import %nested cor)
  ?.  =(a [~ [%generic 2 [%apply %map ~[[%param 0] [%param 1]]]]])
    ~[leaf+"direct forwarding differs"]
  ?.  =(b [~ [%generic 2 [%apply %map ~[[%param 1] [%param 0]]]]])
    ~[leaf+"permutation differs"]
  ?.  =(c [~ [%generic 1 [%apply %map ~[[%param 0] [%param 0]]]]])
    ~[leaf+"repeated parameter differs"]
  ?.  =(d [~ [%generic 2 [%apply %map ~[[%param 0] [%apply %list ~[[%param 1]]]]]]])
    ~[leaf+"nested standard forwarding differs"]
  ?^  (generic-source-proof:jibb-import %opaque cor)
    ~[leaf+"arbitrary cell generator got a collection proof"]
  ~
++  test-provenance
  ^-  tang
  =/  src=@t  '|%\0a++  map  |$  [a b]  [a b]\0a++  spoof  |$  [a b]  (map a b)\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) src)
  ?^  (generic-source-proof:jibb-import %spoof cor)
    ~[leaf+"shadowed map acquired standard provenance"]
  ?^  (generic-source-proof:jibb-import %spoof [%atom %ud ~])
    ~[leaf+"non-core input acquired provenance"]
  ?^  (generic-source-proof:jibb-import %map -:!>(..zuse))
    ~[leaf+"unselected standard subject acquired a local proof"]
  =/  good=@t  '|%\0a++  table  |$  [a b]  (map a b)\0a--\0a'
  =/  source-core=type  -:(ride -:!>(..zuse) good)
  =/  certified  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon good source-core)
  ?.  ?=([%& [%generic-source *]] certified)
    ~[leaf+"matching Hoon source did not produce a certificate"]
  =/  wrong-path  (read-generic-source:jibb-import %fixture %table /sur/other/hoon good source-core)
  ?:  ?=(%& -.wrong-path)  ~[leaf+"a different Hoon source path was accepted"]
  =/  changed=@t  '|%\0a++  table  |$  [a b]  (map b a)\0a--\0a'
  =/  stale  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon changed source-core)
  ?:  ?=(%& -.stale)  ~[leaf+"changed source was accepted for a stale core"]
  =/  commented=@t  (cat 3 good ':: changed\0a')
  =/  comment-proof  (read-generic-source:jibb-import %fixture %table /sur/fixture/hoon commented source-core)
  ?.  ?=(%& -.comment-proof)  ~[leaf+"equivalent commented source was not readable"]
  ?:  =(certified comment-proof)  ~[leaf+"certificate did not retain source bytes"]
  ~
--
