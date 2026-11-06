/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  check
  |=  [src=@t accepts=?]
  ^-  tang
  =/  prepared=(unit iprelude:jibb)
    (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  at=path  /ui/branch-context/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  accepts
    ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
    ~
  ?:  ?=(%& -.checked)  ~[leaf+"invalid or unresolved branch was accepted"]
  ~
++  test-known-branch-context
  ^-  tang
  =/  source=@t
    %-  of-wain:format
    :~  '++ second |= p=[(unit @ud) (unit @ud)]'
        '  ?- p'
        '    [~ b] b'
        '    * ~'
        '++ first |= p=[(unit @ud) (unit @ud)]'
        '  ?- p'
        '    [a ~] ~'
        '    [a b] a'
        '++ generic |= p=[(unit A) (unit A)]'
        '  ?- p'
        '    [~ b] b'
        '    * ~'
        '++ tail-or-nil |= p=[? (list @t)]'
        '  ?- p'
        '    [%.y xs] xs'
        '    [%.n xs] ~'
    ==
  (check source &)
++  test-unfixed-branch-context
  ^-  tang
  (check '++ f |= b=?\0a  ?- b\0a    %.y %one\0a    %.n %two\0a' |)
++  test-invalid-branch-context
  ^-  tang
  (check '++ f |= [b=? x=(unit @ud)]\0a  ?- b\0a    %.y x\0a    %.n %wrong\0a' |)
--
