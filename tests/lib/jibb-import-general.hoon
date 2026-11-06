::  One Hoon /sur exercises unions, atom-or-cell, maps and recursion through
::  the reader and the full Jibb module checker under eval and the ship.
/+  jibb, jibb-import
/*  sur  %txt  /tests/type-import-general/sur/txt
|%
++  test-import-general
  ^-  tang
  =/  source=@t  (cat 3 (of-wain:format sur) '\0a')
  =/  cor=type  -:(ride -:!>(..zuse) source)
  =/  choice  (read-named:jibb-import %fixture %choice cor)
  =/  atom-or  (read-named:jibb-import %fixture %atom-or cor)
  =/  keyed  (read-named:jibb-import %fixture %keyed cor)
  =/  tree  (read-named:jibb-import %fixture %tree cor)
  ?.  &(?=(%& -.choice) ?=(%& -.atom-or) ?=(%& -.keyed) ?=(%& -.tree))
    ~[leaf+"one of the /sur molds failed to import"]
  =/  external=(list [module=term name=term result=*])
    ~[[%fixture %choice choice] [%fixture %atom-or atom-or] [%fixture %keyed keyed] [%fixture %tree tree]]
  =/  jibb-source=@t
    (of-wain:format ~['/- fixture' '++ choose |= x=choice.fixture x' '++ either |= x=atom-or.fixture x' '++ table |= x=keyed.fixture x' '++ walk |= x=tree.fixture x' '++ yes ^- choice.fixture [%& a=4]' '++ no ^- choice.fixture [%| b="hi"]' '++ two ^- choice.fixture [%2 c=5]'])
  =/  at=path  /ui/probe/jibb
  =/  checked  (infer-jibb-file-detailed:jibb at jibb-source external ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"full checker rejected imported /sur molds: {(trip message.p.checked)}"]
  ~
--
