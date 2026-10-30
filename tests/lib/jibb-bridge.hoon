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
    (read-named:jibb-import %fixture name cor)
  =/  external=(list [module=term name=term result=*])
    :~  [%fixture %title (read %title)]
        [%fixture %pair (read %pair)]
        [%fixture %faced (read %faced)]
        [%fixture %nested (read %nested)]
        [%fixture %constant (read %constant)]
        [%fixture %choice (read %choice)]
        [%fixture %chain (read %chain)]
        [%second %chain (read-named:jibb-import %second %chain cor)]
        [%fixture %other (read %other)]
        [%fixture %alias (read %alias)]
        [%fixture %foreign-ref [%& [%cell [%atom %ud ~] [%ref %other %foreign-ref]]]]
        [%fixture %overlap-ref [%& [%fork ~[[%atom %n [~ 0]] [%atom %tas [~ 0]] [%cell [%atom %ud ~] [%ref %fixture %overlap-ref]]]]]]
        [%fixture %raw-ref [%& [%ref %fixture %raw-ref]]]
        [%fixture %raw-null [%& [%atom %n [~ 0]]]]
        [%fixture %texts (read %texts)]
        [%fixture %numbers (read %numbers)]
        [%fixture %maybe (read %maybe)]
        [%fixture %tagged-list (read %tagged-list)]
        [%fixture %buckets (read %buckets)]
        [%fixture %collection-rec (read %collection-rec)]
        [%fixture %bad-kind [%& [%apply %unknown ~[[%atom %t ~]]]]]
        [%fixture %raw-rec [%& [%ref %fixture %chain]]]
        [%fixture %bad-arity [%& [%apply %list ~[[%atom %t ~] [%atom %ud ~]]]]]
        [%fixture %bad-argument [%& [%apply %list ~[[%fork ~[[%atom %tas [~ %a]] [%atom %tas [~ %a]]]]]]]]
        [%fixture %nested-choice (read %nested-choice)]
        [%fixture %collapsed (read %collapsed)]
        [%fixture %dollar (read %dollar)]
        [%fixture %dollar-choice (read %dollar-choice)]
        [%fixture %overlap [%& [%fork ~[[%atom %tas [~ %a]] [%atom %tas [~ %a]]]]]]
        [%fixture %malformed [%& [%fork [[%atom %tas [~ %a]] 42]]]]
        [%fixture %one-case [%& [%fork ~[[%atom %tas [~ %a]]]]]]
        [%fixture %bad-term [%& [%fork ~[[%atom %tas [~ %a]] [%atom %tas [~ 'Bad']]]]]]
        [%fixture %nested-overlap [%& [%face %status [%fork ~[[%atom %tas [~ %a]] [%atom %tas [~ %a]]]]]]]
        [%fixture %failed [%| 'unsupported Hoon type']]
        [%fixture %duplicate [%& [%atom %t ~]]]
        [%fixture %duplicate [%& [%atom %ud ~]]]
        [%missing %title [%& [%atom %t ~]]]
    ==
  =/  report=@t  (golden-types-imports:jibb /test/jibb src external)
  =/  dep=@t  (crip "/- fixture\0a++ chain-id |= x=chain.fixture x\0a")
  =/  root=@t  (crip "/= helper /ui/helper\0a++ use chain-id.helper\0a")
  =/  prelude=@t  (crip "++ prelude-id |= x x\0a")
  =/  modules=(list [at=path source=@t])  ~[[~[%ui %helper %jibb] dep]]
  =/  hidden=@t  (golden-types-with-prelude:jibb /ui/main/jibb root external ~ modules prelude)
  (cat 3 report (cat 3 (crip "\0areader-collapsed: {(show-result:jibb-import (read %collapsed))}\0a") hidden))
--
