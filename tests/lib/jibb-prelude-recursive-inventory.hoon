/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-prelude-recursive-inventory
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  checks=(list [name=term want=tape])
    ~[[%tank "tank"] [%tang "(list tank)"] [%coin "coin"] [%pole "(pole A)"] [%tree "(tree A)"] [%toon "toon"]]
  |-
  ?~  checks  ~
  =/  found=(unit ischeme:jibb)  (find-jibb-mold:jibb name.i.checks iface.u.prepared)
  ?~  found  ~[leaf+"prelude recursive mold {(trip name.i.checks)} was not exported"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"prelude recursive mold {(trip name.i.checks)} did not realize"]
  =/  shown=tape  (show-itype:jibb (canonical-itype:jibb u.typ vars.u.found) ~)
  ?.  =(shown want.i.checks)  ~[leaf+"prelude recursive mold {(trip name.i.checks)} had type {shown}"]
  $(checks t.checks)
--
