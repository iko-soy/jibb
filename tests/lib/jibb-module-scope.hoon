::  Exercise supplied prelude scope and fail-closed module imports.
/+  jibb
/*  expected  %txt  /tests/type-module-scope/expected/txt
/*  real-prelude  %jibb  /lib/jibb/prelude/jibb
/*  real-internal  %jibb  /lib/jibb/internal/jibb
/*  real-source  %jibb  /tests/golden/types-prelude-interface/source/jibb
/*  real-left  %jibb  /tests/golden/types-prelude-interface/modules/ui/left/jibb
/*  real-right  %jibb  /tests/golden/types-prelude-interface/modules/ui/right/jibb
/*  real-expected  %txt  /tests/golden/types-prelude-interface/types/txt
|%
++  test-module-scope
  ^-  tang
  ?~  expected  ~[leaf+"module scope expected output is missing"]
  =/  got  scope-output
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"module scope output differs from tests/type-module-scope/expected.txt"]
  ~
++  scope-output
  ^-  @t
  =/  source=@t  (crip "/= dep /ui/dep\0a++ identity |= x=value.dep x\0a++ atom mold.dep\0a")
  =/  dep=@t  (crip "+$ value @t\0a++ mold ~zod\0a")
  =/  prelude=@t  (crip "++ value |= x x\0a+$ mold @t\0a")
  =/  fixtures=(list [at=path source=@t])  ~[[~[%ui %dep %jibb] dep]]
  =/  okay  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures prelude)
  =/  empty  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures '')
  =/  bad  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures (crip "+$"))
  =/  duplicate-value=@t  (crip "++ foo |=(x x)\0a++ foo |=(x x)\0a")
  =/  duplicate-mold=@t  (crip "+$ foo @t\0a+$ foo @p\0a")
  =/  bad-value  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures duplicate-value)
  =/  bad-mold  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ fixtures duplicate-mold)
  =/  conflict=@t  (crip "/= value /ui/dep\0a++ identity |= x x\0a")
  =/  collision  (golden-types-with-prelude:jibb /ui/main/jibb conflict ~ ~ fixtures prelude)
  =/  library=@t  (crip "++ pass |=(x x)\0a")
  =/  duplicate-source=@t  (crip "/= dep /ui/dup\0a++ main-value 1\0a")
  =/  duplicates=(list [at=path source=@t])
    ~[[~[%ui %dup %jibb] library] [~[%ui %dup %jibb] library]]
  =/  duplicate  (golden-types-with-prelude:jibb /ui/main/jibb duplicate-source ~ ~ duplicates prelude)
  =/  after-source=@t  (crip "/= first /ui/safe\0a/= second /ui/dup\0a++ main-value 1\0a")
  =/  after-fixtures=(list [at=path source=@t])
    [[~[%ui %safe %jibb] library] duplicates]
  =/  after  (golden-types-with-prelude:jibb /ui/main/jibb after-source ~ ~ after-fixtures prelude)
  (of-wain:format ~[okay empty bad bad-value bad-mold collision duplicate after real-parity list-guard self-prelude-guards unit-construction-guard open-list-guard primitive-guards])
::
++  primitive-guards
  ^-  @t
  =/  prepared  (prepare-prelude-with-internal:jibb real-prelude real-internal)
  ?~  prepared  'private primitive preparation failed'
  =/  direct=@t  (crip "/= hidden /lib/jibb/primitives\0a++ attempt 1\0a")
  =/  transitive=@t  (crip "/= relay /ui/relay\0a++ attempt value.relay\0a")
  =/  relay=@t  (crip "/= hidden /lib/jibb/primitives\0a++ value 1\0a")
  =/  fake=@t  (crip "++ raw-add |= x x\0a")
  =/  fixtures=(list [at=path source=@t])
    ~[[/lib/jibb/primitives/jibb fake] [/ui/relay/jibb relay]]
  =/  expected=@t  (crip "partial inference; module not checked\0athe prelude primitive interface is private")
  =/  a  (golden-types-with-prepared-prelude:jibb /ui/direct/jibb direct ~ ~ fixtures prepared)
  =/  b  (golden-types-with-prepared-prelude:jibb /ui/transitive/jibb transitive ~ ~ fixtures prepared)
  =/  c  (golden-types-with-prepared-prelude:jibb /lib/jibb/internal/jibb direct ~ ~ fixtures prepared)
  ?.  &(=(a expected) =(b expected) =(c expected))
    'private primitive import guard failed'
  =/  bad-internal=@t  (crip "/= core /lib/jibb/not-primitives\0a+$ poke @t\0a")
  =/  bad-public=@t  (crip "/= core /lib/jibb/primitives\0a++ identity |= x x\0a")
  ?^  (prepare-prelude-with-internal:jibb real-prelude bad-internal)
    'invalid internal primitive source accepted'
  ?^  (prepare-prelude-with-internal:jibb bad-public real-internal)
    'public primitive import accepted'
  'private primitive source and import guards passed'
::
++  real-parity
  ^-  @t
  =/  fixtures=(list [at=path source=@t])
    ~[[~[%ui %left %jibb] real-left] [~[%ui %right %jibb] real-right]]
  =/  prepared  (prepare-prelude-with-internal:jibb real-prelude real-internal)
  ?~  prepared  'real prelude preparation failed'
  =/  wrapper  (golden-types-with-prelude-and-internal:jibb /tests/golden/types-prelude-interface/source/jibb real-source ~ ~ fixtures real-prelude real-internal)
  =/  actual  (golden-types-with-prepared-prelude:jibb /tests/golden/types-prelude-interface/source/jibb real-source ~ ~ fixtures prepared)
  ?.  =(wrapper actual)  'real prelude prepared/wrapper mismatch'
  ?.  =((to-wain:format (cat 3 actual '\0a')) real-expected)  'real prelude output differs from golden'
  'real prelude prepared/wrapper and golden match'
::
++  list-guard
  ^-  @t
  =/  source=@t  (crip "/- fixture\0a++ imported |= x=texts.fixture x\0a++ imported-branch |= b=?\0a  ^- texts.fixture\0a    ?- b\0a      %.y ~[]\0a      %.n [\"hi\" ~]\0a++ imported-cons ^- texts.fixture [\"hi\" ~]\0a++ imported-empty ^- texts.fixture ~\0a++ imported-pattern |= xs=texts.fixture\0a  ?- xs\0a    ~ !!\0a    [item rest] item\0a++ imported-literal ^- texts.fixture ~[\"hi\"]\0a++ literal ^- (list @t) ~[\"hi\"]\0a++ bridge |= x=texts.fixture ^- (list @t) x\0a")
  =/  ext=(list [module=term name=term result=*])
    ~[[%fixture %texts [%& [%apply %list ~[[%atom %t ~]]]]]]
  =/  omitted=@t  (crip "++ same |=(x x)\0a")
  =/  changed=@t  (crip "+$ list |$ [A] [A A]\0a")
  =/  malformed=@t  (crip "+$ list |$ [A]\0a")
  =/  a  (golden-types-with-prelude:jibb /ui/main/jibb source ext ~ ~ omitted)
  =/  b  (golden-types-with-prelude:jibb /ui/main/jibb source ext ~ ~ changed)
  =/  c  (golden-types-with-prelude:jibb /ui/main/jibb source ext ~ ~ malformed)
  (of-wain:format ~[a b c])
::
++  self-prelude-guards
  ^-  @t
  =/  src=@t  (crip "++ attempt (helper \"hi\")\0a")
  =/  altered=@t  (crip "+$ list |$ [A] [A A]\0a++ helper |= x=@t ^- (list @t) [x x]\0a")
  =/  omitted=@t  (crip "++ helper |= x=@t ^- (list @t) [x x]\0a")
  =/  shadow=@t  (crip "+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a++ helper |= x=@t\0a  +$ list @t\0a  ^- list x\0a")
  =/  malformed=@t  (crip "+$ list |$ [A]\0a")
  =/  alias-source=@t  (crip "++ attempt (helper \"hi\")\0a++ direct |= x=hidden x\0a")
  =/  alias-prelude=@t  (crip "+$ list |$ [A] [A A]\0a+$ hidden (list @t)\0a++ helper |= x=hidden x\0a")
  =/  a  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ altered)
  =/  b  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ omitted)
  =/  c  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ shadow)
  =/  d  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ malformed)
  =/  e  (golden-types-with-prelude:jibb /ui/main/jibb alias-source ~ ~ ~ alias-prelude)
  (of-wain:format ~[a b c d e])
::
++  unit-construction-guard
  ^-  @t
  =/  src=@t  (crip "++ x `\"hi\"\0a")
  =/  omitted=@t  (crip "++ same |=(x x)\0a")
  =/  altered=@t  (crip "+$ unit |$ [A] [A A]\0a")
  =/  malformed=@t  (crip "+$ unit |$ [A]\0a")
  =/  local=@t  (crip "+$ unit |$ [A] [A A]\0a++ x `\"hi\"\0a")
  =/  a  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ omitted)
  =/  b  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ altered)
  =/  c  (golden-types-with-prelude:jibb /ui/main/jibb src ~ ~ ~ malformed)
  =/  d  (golden-types-with-prelude:jibb /ui/main/jibb local ~ ~ ~ omitted)
  (of-wain:format ~[a b c d])
::
++  open-list-guard
  ^-  @t
  =/  source=@t  (crip "++ x ~[\"hi\"]\0a++ empty ~[]\0a")
  =/  omitted=@t  (crip "++ same |=(x x)\0a")
  =/  changed=@t  (crip "+$ list |$ [A] [A A]\0a")
  =/  malformed=@t  (crip "+$ list |$ [A]\0a")
  =/  a  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ ~ omitted)
  =/  b  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ ~ changed)
  =/  c  (golden-types-with-prelude:jibb /ui/main/jibb source ~ ~ ~ malformed)
  (of-wain:format ~[a b c])
--
