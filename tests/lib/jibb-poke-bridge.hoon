::  Source-backed private poke and poke-only API boundary under eval and ship.
/+  jibb, jibb-import
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  mark  %txt  /tests/type-poke/mark/txt
/*  api  %txt  /tests/type-poke/api/txt
/*  client  %txt  /tests/type-poke/client/txt
/*  direct  %txt  /tests/type-poke/direct/txt
/*  alias  %txt  /tests/type-poke/alias/txt
/*  public  %txt  /tests/type-poke/public/txt
/*  fake  %txt  /tests/type-poke/fake/txt
/*  exported  %txt  /tests/type-poke/exported/txt
/*  transitive  %txt  /tests/type-poke/transitive/txt
/*  inner  %txt  /tests/type-poke/inner/txt
/*  impostor-client  %txt  /tests/type-poke/impostor-client/txt
/*  impostor  %txt  /tests/type-poke/impostor/txt
/*  expected  %txt  /tests/type-poke/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-poke-bridge
  ^-  tang
  ?~  mark  ~[leaf+"poke bridge mark fixture is missing"]
  ?~  api  ~[leaf+"poke bridge API fixture is missing"]
  ?~  client  ~[leaf+"poke bridge client fixture is missing"]
  ?~  direct  ~[leaf+"poke bridge direct import fixture is missing"]
  ?~  alias  ~[leaf+"poke bridge alias fixture is missing"]
  ?~  public  ~[leaf+"poke bridge public fixture is missing"]
  ?~  fake  ~[leaf+"poke bridge fake fixture is missing"]
  ?~  exported  ~[leaf+"poke bridge export fixture is missing"]
  ?~  transitive  ~[leaf+"poke bridge transitive fixture is missing"]
  ?~  inner  ~[leaf+"poke bridge inner fixture is missing"]
  ?~  impostor-client  ~[leaf+"poke bridge impostor client is missing"]
  ?~  impostor  ~[leaf+"poke bridge impostor fixture is missing"]
  ?~  expected  ~[leaf+"poke bridge expected output is missing"]
  =/  got  (bridge-output prelude internal (text mark) (text api) (text client) (text direct) (text alias) (text public) (text fake) (text exported) (text transitive) (text inner) (text impostor-client) (text impostor))
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"poke bridge output differs from tests/type-poke/expected.txt"]
  ~
++  preparation-controls
  |=  [prelude=@t internal=@t]
  ^-  @t
  =/  alternate=@t  (crip "+$ poke\0a  [%pet name=@t]\0a  %empty\0a")
  =/  tiny-prelude=@t  (crip "/= internal /lib/jibb/internal\0a+$ poke poke.internal\0a")
  =/  source=@t  (crip "++ zero ^- poke %empty\0a++ pet ^- poke [%pet \"cat\"]\0a++ look |= x=poke\0a  ?- x\0a    [%pet name] name\0a    %empty \"\"\0a")
  =/  no-source=?  ?=(~ (prepare-prelude:jibb prelude))
  =/  malformed=?  ?=(~ (prepare-prelude-with-internal:jibb prelude (crip "+$ poke\0a")))
  =/  empty=?  ?=(~ (prepare-prelude-with-internal:jibb prelude ''))
  =/  report  (golden-types-with-prelude-and-internal:jibb /ui/test/jibb source ~ ~ ~ tiny-prelude alternate)
  (of-wain:format ~[(crip "source-less={?:(no-source "rejected" "BAD")} malformed={?:(malformed "rejected" "BAD")} empty={?:(empty "rejected" "BAD")}") report])
::
++  bridge-output
  |=  [prelude=@t internal=@t mark=@t api=@t client=@t direct=@t alias=@t public=@t fake=@t exported=@t transitive=@t inner=@t impostor-client=@t impostor=@t]
  ^-  @t
  =/  prepared=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prepared  'source-backed prelude preparation failed'
  =/  cor=type  -:(ride -:!>(..zuse) mark)
  =/  mark-result=*  (read-mark:jibb-import %todo-action cor)
  =/  marks=(list [mark=term result=*])  ~[[%todo-action mark-result]]
  =/  modules=(list [at=path source=@t])
    ~[[/ui/api/todo/jibb api] [/lib/jibb/internal/jibb internal] [/ui/internal/jibb fake] [/ui/public/jibb public] [/ui/inner/jibb inner]]
  =/  a  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ marks modules prepared)
  =/  b  (golden-types-with-prepared-prelude:jibb /ui/test/jibb direct ~ marks modules prepared)
  =/  c  (golden-types-with-prepared-prelude:jibb /ui/test/jibb alias ~ marks modules prepared)
  =/  d  (golden-types-with-prepared-prelude:jibb /ui/test/jibb exported ~ marks modules prepared)
  =/  e  (golden-types-with-prepared-prelude:jibb /ui/test/jibb transitive ~ marks modules prepared)
  =/  missing-marks=(list [mark=term result=*])  ~
  =/  duplicate-marks=(list [mark=term result=*])  ~[[%todo-action mark-result] [%todo-action mark-result]]
  =/  f  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ missing-marks modules prepared)
  =/  g  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ duplicate-marks modules prepared)
  =/  extra-api=@t  (crip "/% %todo-action\0a+$ poke todo-action\0a+$ paths\0a  [%state /state @t]\0a")
  =/  extra-modules=(list [at=path source=@t])  ~[[/ui/api/todo/jibb extra-api]]
  =/  h  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ marks extra-modules prepared)
  =/  spoof-modules=(list [at=path source=@t])  ~[[/lib/jibb/internal/jibb impostor]]
  =/  i  (golden-types-with-prepared-prelude:jibb /ui/test/jibb impostor-client ~ ~ spoof-modules prepared)
  =/  no-declaration=@t  (crip "+$ poke todo-action\0a")
  =/  no-declaration-modules=(list [at=path source=@t])  ~[[/ui/api/todo/jibb no-declaration]]
  =/  j  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ marks no-declaration-modules prepared)
  =/  collision=@t  (crip "/% %todo-action\0a+$ poke todo-action\0a++ todo-action \"bad\"\0a")
  =/  collision-modules=(list [at=path source=@t])  ~[[/ui/api/todo/jibb collision]]
  =/  k  (golden-types-with-prepared-prelude:jibb /ui/test/jibb client ~ marks collision-modules prepared)
  =/  wrong-path-source=@t  (crip "/= todo /ui/wrong/todo\0a++ test (todo-action.todo \"ok\")\0a")
  =/  wrong-path-modules=(list [at=path source=@t])  ~[[/ui/wrong/todo/jibb api]]
  =/  l  (golden-types-with-prepared-prelude:jibb /ui/test/jibb wrong-path-source ~ marks wrong-path-modules prepared)
  (of-wain:format ~[(preparation-controls prelude internal) a b c d e f g h i j k l])
--
