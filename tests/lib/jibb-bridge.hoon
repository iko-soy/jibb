::  Exercise the same Hoon importer/checker boundary under eval and Clay.
/+  jibb, jibb-import
/*  sur       %txt  /tests/type-import/sur/txt
/*  source    %txt  /tests/type-import/source/txt
/*  expected  %txt  /tests/type-import/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-import-bridge
  ^-  tang
  ?~  sur  ~[leaf+"import bridge /sur fixture is missing"]
  ?~  source  ~[leaf+"import bridge source is missing"]
  ?~  expected  ~[leaf+"import bridge expected output is missing"]
  =/  got  (bridge-output (text sur) (text source))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"import bridge output differs from tests/type-import/expected.txt"]
  ~
++  bridge-output
  |=  [sur-text=@t src=@t]
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) sur-text)
  =/  read
    |=  name=term
    (read-mold-in:jibb-import %fixture name (~(play ut cor) (ream (cat 3 '*' name))) cor)
  =/  external=(list [module=term name=term result=*])
    :~  [%fixture %title (read %title)]
        [%fixture %pair (read %pair)]
        [%fixture %faced (read %faced)]
        [%fixture %constant (read %constant)]
        [%fixture %choice (read %choice)]
        [%fixture %failed [%| 'unsupported Hoon type']]
        [%fixture %duplicate [%& [%atom %t ~]]]
        [%fixture %duplicate [%& [%atom %ud ~]]]
        [%missing %title [%& [%atom %t ~]]]
    ==
  (golden-types-imports:jibb /test/jibb src external)
--
