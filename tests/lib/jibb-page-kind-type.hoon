::  A page's type, not the spelling of its builder or load, sets its kind.
/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-page-kind-type
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  ::  A page whose load takes x has the route parameter _x.
  =/  with-x=path  /ui/probe/[~._x]/jibb
  =/  src=(list [label=@t at=path text=@t])
    :~  ['pure' with-x (of-wain:format ~['++ main (page load view)' '++ load |= x=@ud (pure x)' '++ view |= x=@ud (text "hi")'])]
        ['alias' with-x (of-wain:format ~['++ main this-page' '++ this-page (page load view)' '++ load |= x=@ud (pure x)' '++ view |= x=@ud (text "hi")'])]
        ['contextual pure list' /ui/probe/jibb (of-wain:format ~['++ main (page load view)' '++ load |=(~ (pure ~))' '++ view |= xs=(list @ud) (text "hi")'])]
    ==
  =/  errors=(list tape)  ~
  |-
  ?~  src  (turn (flop errors) |=(reason=tape leaf+reason))
  =/  at=path  at.i.src
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at text.i.src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)
    $(src t.src, errors [(weld (trip label.i.src) (weld ": " (trip message.p.result))) errors])
  $(src t.src)
--
