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
  =/  at=path  /ui/probe/jibb
  =/  src=(list [label=@t text=@t])
    :~  ['pure' (of-wain:format ~['++ main (page load view)' '++ load |= x=@ud (pure x)' '++ view |= x=@ud (text "hi")'])]
        ['alias' (of-wain:format ~['++ main this-page' '++ this-page (page load view)' '++ load |= x=@ud (pure x)' '++ view |= x=@ud (text "hi")'])]
        ['contextual pure list' (of-wain:format ~['++ main (page load view)' '++ load |=(~ (pure ~))' '++ view |= xs=(list @ud) (text "hi")'])]
    ==
  =/  errors=(list tape)  ~
  |-
  ?~  src  (turn (flop errors) |=(reason=tape leaf+reason))
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at text.i.src ~ ~ ~ ~[at] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)
    $(src t.src, errors [(weld (trip label.i.src) (weld ": " (trip message.p.result))) errors])
  $(src t.src)
--
