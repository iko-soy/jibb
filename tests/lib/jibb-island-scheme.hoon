/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-island-gate-free-scheme
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude missing"]
  =/  src=@t  '++ exported island\0a'
  =/  at=path  /tests/island-signature/jibb
  =/  report=@t  (golden-types-with-prepared-prelude:jibb at src ~ ~ ~ prepared)
  =/  expected=@t  'module kind: library\0a++ exported: $-([p=[init=$-(Data Model) [update=$-([Msg Model] [Model (list (cmd Msg))]) [view=$-(Model (element Msg)) subs=$-(Model (list (sub Msg)))]]] data=Data] (element !!)) where Data contains no gates, Model contains no gates'
  ?.  =(report expected)  ~[leaf+"island lost its published gate-free constraints" leaf+(trip report)]
  ~
--
