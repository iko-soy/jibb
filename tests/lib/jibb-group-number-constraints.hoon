::  Recursive components retain the permitted arithmetic capital constraint.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  core
  |=  [source=@t prepared=iprelude:jibb]
  ^-  (unit iresolved:jibb)
  =/  at=path  /tests/group-numbers/jibb
  =/  parsed  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  ~
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at at, globals (global-value-names:jibb defs.p.parsed), in-mold |, jrec-fuel 256, prelude `iface.prepared)
  (icore-resolve:jibb defs.p.parsed state)
++  test-recursive-arithmetic-capital
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed"]
  =/  source=@t  '++ range-up |= args=[A A] ^- (list A)\0a  ?- args\0a  [start finish]\0a    ?- (gth start finish)\0a    %.y !!\0a    %.n\0a      ?- (eq start finish)\0a      %.y [start ~]\0a      %.n [start (range-up (add start 1) finish)]\0a'
  =/  checked=(unit iresolved:jibb)  (core source u.prepared)
  ?~  checked  ~[leaf+"recursive numeric capital did not generalize in the common core"]
  =/  scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %range-up env.u.checked)
  ?~  scheme  ~[leaf+"recursive gate missing"]
  =/  shown=(unit itype:jibb)  (scheme-display-type:jibb u.scheme)
  ?~  shown  ~[leaf+"recursive scheme graph did not close"]
  =/  typ=itype:jibb  (canonical-itype:jibb u.shown vars.u.scheme)
  ?.  =("$-([A A] (list A)) where A is an atom other than ?" "{(show-itype:jibb typ ~)}{(show-atom-constraint:jibb typ)}")
    ~[leaf+"recursive arithmetic scheme lost its restriction"]
  =/  valid=@t  (cat 3 source '++ nums (range-up 1 3)\0a++ hexes (range-up 0x1 0x3)\0a')
  ?~  (core valid u.prepared)  ~[leaf+"recursive arithmetic instances were not independent"]
  =/  invalid=@t  (cat 3 source '++ bad (range-up %.y %.n)\0a')
  ?^  (core invalid u.prepared)  ~[leaf+"recursive arithmetic accepted loobeans"]
  ~
++  test-mutual-arithmetic-capital
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude failed"]
  =/  source=@t  '++ first |= x=A ^- A (second (add x 1))\0a++ second |= x=A ^- A (first x)\0a'
  =/  checked=(unit iresolved:jibb)  (core source u.prepared)
  ?~  checked  ~[leaf+"mutual numeric capitals did not generalize in the common core"]
  =/  valid=@t  (cat 3 source '++ dec-result (first 1)\0a++ hex-result (second 0x1)\0a')
  ?~  (core valid u.prepared)  ~[leaf+"mutual numeric instances were not independent"]
  =/  invalid=@t  (cat 3 source '++ bad (first %.y)\0a')
  ?^  (core invalid u.prepared)  ~[leaf+"mutual arithmetic accepted a loobean"]
  ~
--
