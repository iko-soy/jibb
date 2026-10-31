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
++  noun-synthetic
  ^-  @t
  =/  tests=(list [name=@t val=*])
    :~  ['noun' [%noun ~]]
        ['malformed' [%noun 1]]
        ['noun-atom' [%fork ~[[%noun ~] [%atom %ud ~]]]]
        ['noun-cell' [%fork ~[[%noun ~] [%cell [%atom %t ~] [%atom %ud ~]]]]]
        ['nested-overlap' [%fork ~[[%cell [%atom %tas `0] [%noun ~]] [%cell [%atom %tas `0] [%atom %ud ~]]]]]
        ['separate-tags' [%fork ~[[%cell [%atom %tas `%a] [%noun ~]] [%cell [%atom %tas `%b] [%atom %ud ~]]]]]
        ['unknown-gate' [%fork ~[[%noun ~] [%gate ~]]]]
        ['unknown-empty' [%fork ~[[%noun ~] [%void ~]]]]
    ==
  =/  out=wall
    %+  turn  tests
    |=  t=[name=@t val=*]
    =/  got=(unit itype:jibb)  (import-to-itype:jibb val.t)
    "{(trip name.t)}: {?~(got "unsupported" (show-itype:jibb u.got ~))}"
  (of-wain:format (turn out |=(line=tape (crip line))))
::
::  Recursive list arguments must be valid, same-origin graphs. The
::  entire imported recursive mold remains nominal and does not unfold.
++  recursive-list-synthetic
  ^-  @t
  =/  tests=(list [name=@t node=* good=?])
    :~  ['valid' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %notes %node]]]]]] &]
        ['wrong-module' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %other %node]]]]]] |]
        ['wrong-name' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %notes %other]]]]]] |]
        ['two-arguments' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %notes %node] [%atom %t ~]]]]]] |]
        ['no-argument' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~]]]] |]
        ['other-collection' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %set ~[[%ref %notes %node]]]]]] |]
        ['malformed-reference' [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %notes]]]]]] |]
        ['null-overlap' [%fork ~[[%atom %n [~ 0]] [%apply %list ~[[%ref %notes %node]]]]] |]
        ['duplicate-faces' [%fork ~[[%atom %n [~ 0]] [%cell [%face %dup [%atom %tas [~ %branch]]] [%face %dup [%apply %list ~[[%ref %notes %node]]]]]]] |]
    ==
  =/  out=wall
    %+  turn  tests
    |=  test=[name=@t node=* good=?]
    =/  got=(unit itype:jibb)
      (find-imported-mold:jibb %notes %node ~[[%notes %node [%& node.test]]] ~[%notes])
    =/  yes=?  ?=([~ [%recursive *]] got)
    "recursive-list {(trip name.test)}: {?:(=(yes good.test) "ok" "BAD")}"
  (of-wain:format (turn out |=(line=tape (crip line))))
::
++  named-recursive-synthetic
  ^-  @t
  =/  good=*
    [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%apply %list ~[[%ref %notes %node]]]]]]
  =/  duplicate=*
    [%fork ~[[%atom %n [~ 0]] [%cell [%face %dup [%atom %tas [~ %branch]]] [%face %dup [%apply %list ~[[%ref %notes %node]]]]]]]
  =/  tests=(list [name=@t node=* good=?])
    :~  ['valid' [%named %notes %node good] &]
        ['wrong-module' [%named %notes %node [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%ref %other %node]]]]] |]
        ['wrong-name' [%named %notes %node [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%ref %notes %other]]]]] |]
        ['no-reference' [%named %notes %node [%fork ~[[%atom %n [~ 0]] [%cell [%atom %tas [~ %branch]] [%atom %ud ~]]]]] |]
        ['overlap' [%named %notes %node [%fork ~[[%atom %n [~ 0]] [%apply %list ~[[%ref %notes %node]]]]]] |]
        ['duplicate-faces' [%named %notes %node duplicate] |]
        ['malformed' [%named %notes %node] |]
        ['wrong-arity' [%named %notes %node [%apply %list ~[[%ref %notes %node] [%atom %t ~]]]] |]
        ['bare-reference' [%named %notes %node [%ref %notes %node]] |]
        ['non-fork' [%named %notes %node [%cell [%atom %ud ~] [%ref %notes %node]]] |]
    ==
  =/  out=wall
    %+  turn  tests
    |=  test=[name=@t node=* good=?]
    =/  got=(unit itype:jibb)
      (find-imported-mold:jibb %notes %outer ~[[%notes %outer [%& [%cell [%atom %ud ~] node.test]]]] ~[%notes])
    =/  yes=?  ?=([~ [%cell [%atom %ud] [%recursive %notes %node *]]] got)
    "named-recursive {(trip name.test)}: {?:(=(yes good.test) "ok" "BAD")}"
  (of-wain:format (turn out |=(line=tape (crip line))))
::
::
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
        [%fixture %zero-choice (read %zero-choice)]
        [%fixture %zero-nested (read %zero-nested)]
        [%fixture %zero-lookalike (read %zero-lookalike)]
        [%fixture %flag-forward [%& [%fork ~[[%atom %f [~ 0]] [%atom %f [~ 1]]]]]]
        [%fixture %flag-reverse [%& [%fork ~[[%atom %f [~ 1]] [%atom %f [~ 0]]]]]]
        [%fixture %flag-open [%& [%atom %f ~]]]
        [%fixture %flag-invalid [%& [%atom %f [~ 2]]]]
        [%fixture %flag-duplicate [%& [%fork ~[[%atom %f [~ 0]] [%atom %f [~ 0]]]]]]
        [%fixture %flag-null-overlap [%& [%fork ~[[%atom %f [~ 0]] [%atom %n [~ 0]]]]]]
        [%fixture %flag-term-overlap [%& [%fork ~[[%atom %f [~ 0]] [%atom %tas [~ 0]]]]]]
        [%fixture %flag-extra [%& [%fork ~[[%atom %f [~ 0]] [%atom %f [~ 1]] [%atom %tas [~ 2]]]]]]
        [%fixture %flag-faced [%& [%fork ~[[%face %x [%atom %f [~ 0]]] [%atom %tas [~ 2]]]]]]
        [%fixture %flag-malformed [%& [%fork [[%atom %f [~ 0]] 7]]]]
        [%fixture %zero-nonzero [%& [%atom %n [~ 1]]]]
        [%fixture %zero-overlap [%& [%fork ~[[%atom %n [~ 0]] [%atom %tas [~ 0]]]]]]
        [%fixture %zero-flag-overlap [%& [%fork ~[[%atom %n [~ 0]] [%atom %f [~ 0]]]]]]
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
  =/  unit-prelude=@t  (crip "+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a")
  =/  unit-client=@t
    (crip "/- fixture\0a++ canonical ^- (unit @t) `\"hi\"\0a++ lookalike ^- zero-lookalike.fixture `\"hi\"\0a")
  =/  unit-report=@t
    (golden-types-with-prelude:jibb /ui/unit-client/jibb unit-client external ~ ~ unit-prelude)
  (cat 3 report (cat 3 (crip "\0areader-collapsed: {(show-result:jibb-import (read %collapsed))}\0a") (cat 3 hidden (cat 3 '\0a' (cat 3 unit-report (cat 3 '\0a' (cat 3 noun-synthetic (cat 3 '\0a' (cat 3 recursive-list-synthetic (cat 3 '\0a' named-recursive-synthetic))))))))))
--
