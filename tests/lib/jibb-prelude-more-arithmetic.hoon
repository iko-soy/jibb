::  Prepared public arithmetic helpers keep one shared aura per call.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  check-generic-wrappers
  |=  [names=(list term) env=ienv:jibb]
  ^-  tang
  ?~  names  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb i.names env)
  ?~  found  ~[leaf+"generic wrapper missing"]
  ?.  ?=([@ ~] vars.u.found)  ~[leaf+"generic wrapper lost its aura variable"]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  display  ~[leaf+"generic wrapper display failed"]
  =/  typ=itype:jibb  (canonical-itype:jibb u.display vars.u.found)
  ?.  =((show-itype:jibb typ ~) "$-([A A] A)")  ~[leaf+"generic wrapper signature differs"]
  =/  ids=(list @ud)  (itype-vars:jibb typ)
  ?~  ids  ~[leaf+"generic wrapper has no variable"]
  ?.  (itype-var-is-restricted:jibb i.ids typ)  ~[leaf+"generic wrapper allows loobeans"]
  $(names t.names)
++  test-prelude-more-arithmetic
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude not prepared"]
  =/  cases=(list [name=term want=tape])
    ~[[%dvr "$-([A A] [p=A q=A])"] [%div "$-([A A] A)"] [%mod "$-([A A] A)"] [%pow "$-([A A] A)"]]
  =/  todo=(list [name=term want=tape])  cases
  |-  ^-  tang
  ?~  todo
    =/  src=@t  (of-wain:format ~['++ div-decimal ^- @ud (div 7 3)' '' '++ div-hexadecimal ^- @ux (div 0x7 0x3)' '' '++ div-duration ^- @dr (div ~s7 ~s3)' '' '++ mod-decimal ^- @ud (mod 7 3)' '' '++ mod-hexadecimal ^- @ux (mod 0x7 0x3)' '' '++ mod-duration ^- @dr (mod ~s7 ~s3)' '' '++ pow-decimal ^- @ud (pow 7 3)' '' '++ pow-hexadecimal ^- @ux (pow 0x7 0x3)' '' '++ pow-duration ^- @dr (pow ~s7 ~s3)' '' '++ generic-pow |= args=[A A]' '  ?- args' '  [a b] (pow a b)' '' '++ generic-div |= args=[A A]' '  ?- args' '  [a b] (div a b)' '' '++ generic-mod |= args=[A A]' '  ?- args' '  [a b] (mod a b)'])
    =/  at=path  /tests/prelude-more-arithmetic/jibb
    =/  out=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
    ?:  ?=(%| -.out)  ~[leaf+(trip message.p.out)]
    =/  generic-errors=tang  (check-generic-wrappers ~[%generic-div %generic-mod %generic-pow] values.iface.p.out)
    ?^  generic-errors  generic-errors
    =/  expected=(list [name=term aura=@ta])
      ~[[%div-decimal %ud] [%div-hexadecimal %ux] [%div-duration %dr] [%mod-decimal %ud] [%mod-hexadecimal %ux] [%mod-duration %dr] [%pow-decimal %ud] [%pow-hexadecimal %ux] [%pow-duration %dr]]
    |-
    ?~  expected  ~
    =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.expected values.iface.p.out)
    ?~  found  ~[leaf+"arithmetic instance missing"]
    =/  displayed=(unit itype:jibb)  (scheme-display-type:jibb u.found)
    ?~  displayed  ~[leaf+"arithmetic instance could not be rendered"]
    ?.  =(u.displayed [%atom aura.i.expected])  ~[leaf+"arithmetic instance lost its aura"]
    $(expected t.expected)
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.todo values.iface.u.prep)
  ?~  found  ~[leaf+"prelude arithmetic helper missing"]
  ?.  ?=([@ ~] vars.u.found)  ~[leaf+"arithmetic helper lost its one generic aura"]
  =/  displayed=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  displayed  ~[leaf+"arithmetic helper could not be rendered"]
  =/  typ=itype:jibb  (canonical-itype:jibb u.displayed vars.u.found)
  ?.  =((show-itype:jibb typ ~) want.i.todo)  ~[leaf+"arithmetic helper has the wrong signature"]
  =/  ids=(list @ud)  (itype-vars:jibb typ)
  ?~  ids  ~[leaf+"arithmetic helper has no variable"]
  ?.  (itype-var-is-restricted:jibb i.ids typ)  ~[leaf+"arithmetic helper lost its non-loobean atom constraint"]
  $(todo t.todo)
++  test-prelude-more-arithmetic-loobean
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude not prepared"]
  =/  names=(list term)  ~[%div %mod %pow]
  =/  at=path  /ui/helpers/jibb
  |-
  ?~  names  ~
  =/  source=@t  (crip "++ bad ({(trip i.names)} %.y %.n)")
  =/  out=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.out)  ~[leaf+"loobean arithmetic was accepted"]
  =/  expected=@t
    (of-wain:format ~['++ bad: types do not unify' '/ui/helpers.jibb:1:9: expected type has type A where A is an atom other than ?' source '        ^' '/ui/helpers.jibb:1:13: actual type has type ?' source '            ^'])
  ?.  =(message.p.out expected)  ~[leaf+"loobean diagnostic differs: {(trip message.p.out)}"]
  $(names t.names)
--
