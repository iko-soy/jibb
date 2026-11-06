/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-prelude-helpers
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"extra prelude failed preparation"]
  =/  todo=(list [name=term want=tape])
    :~  [%homo "$-((list A) (list A))"]
        [%fand "$-([needle=(list A) haystack=(list A)] (list @ud)) where A contains no gates"]
        [%find "$-([needle=(list A) haystack=(list A)] (unit @ud)) where A contains no gates"]
        [%spin "$-([(list A) [B $-([A B] [C B])]] [p=(list C) q=B])"]
        [%test "$-([A A] ?) where A contains no gates"]
        [%sqt "$-(A [p=A q=A]) where A is an atom other than ?"]
    ==
  |-
  ?~  todo  (check-calls u.prepared)
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.todo values.iface.u.prepared)
  ?~  found  ~[leaf+"missing extra prelude gate {(trip name.i.todo)}"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"unprintable extra prelude gate {(trip name.i.todo)}"]
  =/  shown=itype:jibb  (canonical-itype:jibb u.typ vars.u.found)
  =/  actual=tape  "{(show-itype:jibb shown ~)}{(show-atom-constraint:jibb shown)}"
  ?.  =(want.i.todo actual)
    ~[leaf+"{(trip name.i.todo)}: {actual}" leaf+"expected: {want.i.todo}"]
  $(todo t.todo)

++  check-calls
  |=  prepared=iprelude:jibb
  ^-  tang
  =/  source=@t  '++ identity-items (homo ~[1 2])\0a++ identity-ships (homo ~[~zod])\0a++ all-text (fand ~["a"] ~["a" "b" "a"])\0a++ all-nums (fand ~[1] ~[1 2 1])\0a++ first-text (find ~["a"] ~["b" "a"])\0a++ first-ships (find ~[~zod] ~[~nec ~zod])\0a++ each-label |= [item=@ud state=@ud] ["x" (add item state)]\0a++ spun-labels (spin ~[1 2] 0 each-label)\0a++ keep-code |= [item=@t state=@t] [1 item]\0a++ spun-codes (spin ~["a"] "seed" keep-code)\0a++ equal-text (test "a" "b")\0a++ equal-ships (test ~zod ~nec)\0a++ root-dec (sqt 17)\0a++ root-hex (sqt 0x11)\0a'
  =/  file=path  /tests/prelude-helpers/jibb
  =/  checked
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.prepared molds.prepared ~ `iface.prepared)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  todo=(list [name=term want=tape])
    :~  [%identity-items "(list @ud)"]
        [%identity-ships "(list @p)"]
        [%all-text "(list @ud)"]
        [%all-nums "(list @ud)"]
        [%first-text "(unit @ud)"]
        [%first-ships "(unit @ud)"]
        [%spun-labels "[p=(list @t) q=@ud]"]
        [%spun-codes "[p=(list @ud) q=@t]"]
        [%equal-text "?"]
        [%equal-ships "?"]
        [%root-dec "[p=@ud q=@ud]"]
        [%root-hex "[p=@ux q=@ux]"]
    ==
  |-
  ?~  todo  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb name.i.todo values.iface.p.checked)
  ?~  found  ~[leaf+"missing helper call {(trip name.i.todo)}"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.found)
  ?~  typ  ~[leaf+"helper call graph did not close"]
  =/  actual=tape  (show-itype:jibb u.typ ~)
  ?.  =(want.i.todo actual)
    ~[leaf+"{(trip name.i.todo)}: {actual}" leaf+"expected: {want.i.todo}"]
  $(todo t.todo)
--
