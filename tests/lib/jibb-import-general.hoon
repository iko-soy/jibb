::  One Hoon /sur exercises unions, atom-or-cell, maps and recursion through
::  the reader and the full Jibb module checker under eval and the ship.
/+  jibb, jibb-import
/*  sur  %txt  /tests/type-import-general/sur/txt
/*  collections  %txt  /sur/jibb-collections/hoon
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
  =/  all=(each (list [module=term name=term result=*]) @t)
    (read-module:jibb-import %fixture /sur/fixture/hoon source cor)
  ?:  ?=(%| -.all)  ~[leaf+"module enumeration failed: {(trip p.all)}"]
  =/  names=(list term)  (turn p.all |=(e=[module=term name=term result=*] name.e))
  ?.  =(names ~[%atom-or %choice %keyed %tree])
    ~[leaf+"module enumeration missed or repeated declarations"]
  =/  selected=(list [module=term name=term result=*])
    (skim p.all |=(e=[module=term name=term result=*] =(name.e %choice)))
  ?.  ?=([* ~] selected)  ~[leaf+"module enumeration did not retain choice"]
  ?.  =(choice result.i.selected)  ~[leaf+"module enumeration changed the reader result"]
  =/  unsafe=(each (list [module=term name=term result=*]) @t)
    (read-module:jibb-import %fixture /sur/fixture/hoon source -:!>(..zuse))
  ?.  ?=(%| -.unsafe)  ~[leaf+"module enumeration accepted the standard subject as provenance"]
  =/  missing=*  (read-module-result:jibb-import %fixture %missing /sur/fixture/hoon source cor)
  ?.  ?=([%invalid %missing *] missing)  ~[leaf+"module reader lost its missing-declaration diagnostic"]
  =/  collection-source=@t  (cat 3 (of-wain:format collections) '\0a')
  =/  collection-core=type  -:(ride -:!>(..zuse) collection-source)
  =/  generic=(each (list [module=term name=term result=*]) @t)
    (read-module:jibb-import %jibb-collections /sur/jibb-collections/hoon collection-source collection-core)
  ?:  ?=(%| -.generic)  ~[leaf+"generic module enumeration failed: {(trip p.generic)}"]
  =/  table=(list [module=term name=term result=*])
    (skim p.generic |=(e=[module=term name=term result=*] =(name.e %table)))
  ?.  ?=([* ~] table)  ~[leaf+"generic module enumeration did not retain table"]
  ?.  ?=([%& [%generic-source *]] result.i.table)
    ~[leaf+"generic collection lost its source certificate"]
  =/  jibb-source=@t
    (of-wain:format ~['/- fixture' '++ choose |= x=choice.fixture x' '++ either |= x=atom-or.fixture x' '++ table |= x=keyed.fixture x' '++ walk |= x=tree.fixture x' '++ yes ^- choice.fixture [%& a=4]' '++ no ^- choice.fixture [%| b="hi"]' '++ two ^- choice.fixture [%2 c=5]'])
  =/  at=path  /ui/probe/jibb
  =/  checked  (infer-jibb-file-detailed:jibb at jibb-source external ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"full checker rejected imported /sur molds: {(trip message.p.checked)}"]
  ~
--
