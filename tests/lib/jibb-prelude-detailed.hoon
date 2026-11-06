/+  jibb, jibb-prelude-fixture
|%
++  test-detailed-malformed
  ^-  tang
  =/  src=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)\0a'
  =/  got=(each iprelude:jibb @t)  (prepare-prelude-detailed:jibb src)
  ?:  ?=(%& -.got)  ~[leaf+"malformed prelude was accepted"]
  =/  expected=@t  '/lib/jibb/prelude.jibb:3:18: expected `]` or a field on a deeper line, found the end of the file\0a  [i=A t=(list A)\0a                 ^'
  ?.  =(p.got expected)  ~[leaf+"malformed prelude lost its parser site" leaf+(trip p.got)]
  ?^  (prepare-prelude:jibb src)  ~[leaf+"unit prelude API accepted malformed source"]
  ~
++  test-detailed-duplicate
  ^-  tang
  =/  src=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ list |$ [A] [A A]\0a'
  =/  got=(each iprelude:jibb @t)  (prepare-prelude-detailed:jibb src)
  ?:  ?=(%& -.got)  ~[leaf+"duplicate prelude mold was accepted"]
  =/  expected=@t  'definition `list` shadows an earlier definition\0a/lib/jibb/prelude.jibb:1:1: earlier definition\0a+$ list |$ [A]\0a^\0a/lib/jibb/prelude.jibb:4:1: conflicting definition\0a+$ list |$ [A] [A A]\0a^'
  ?.  =(p.got expected)  ~[leaf+"duplicate prelude lost its declaration sites" leaf+(trip p.got)]
  ?^  (prepare-prelude:jibb src)  ~[leaf+"unit prelude API accepted duplicate molds"]
  ~
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-unused-missing-alias
  ^-  tang
  =/  src=@t  '+$ bag |$ [A] (list A)\0a+$ alias |$ [A] (bag A)\0a++ unrelated 1\0a'
  =/  got=(each iprelude:jibb @t)  (prepare-prelude-detailed:jibb src)
  ?:  ?=(%& -.got)  ~[leaf+"unused missing mold was silently omitted"]
  ?^  (prepare-prelude:jibb src)  ~[leaf+"unit preparation accepted an invalid unused mold"]
  ?.  &((contains (trip p.got) "prelude mold `list` is not defined") (contains (trip p.got) "/lib/jibb/prelude.jibb:1:15:"))
    ~[leaf+"unused missing mold lost its declaration site" leaf+(trip p.got)]
  ~
++  test-unused-alias-cycle
  ^-  tang
  =/  src=@t  '+$ bag |$ [A] (alias A)\0a+$ alias |$ [A] (bag A)\0a++ unrelated 1\0a'
  =/  got=(each iprelude:jibb @t)  (prepare-prelude-detailed:jibb src)
  ?:  ?=(%& -.got)  ~[leaf+"unused alias cycle was silently omitted"]
  ?^  (prepare-prelude:jibb src)  ~[leaf+"unit preparation accepted an invalid unused mold"]
  ?.  &((contains (trip p.got) "prelude mold aliases form a cycle") (contains (trip p.got) "/lib/jibb/prelude.jibb:1:") (contains (trip p.got) "/lib/jibb/prelude.jibb:2:"))
    ~[leaf+"unused alias cycle lost its source sites" leaf+(trip p.got)]
  ~
++  test-malformed-internal
  ^-  tang
  =/  public=@t  '/= internal /lib/jibb/internal\0a+$ good ?\0a'
  =/  internal=@t  '+$ broken [@t\0a'
  =/  got=(each iprelude:jibb @t)  (prepare-prelude-with-internal-detailed:jibb public internal)
  ?:  ?=(%& -.got)  ~[leaf+"malformed internal source was accepted"]
  ?.  &((contains (trip p.got) "/lib/jibb/internal.jibb:1:") (contains (trip p.got) "expected"))
    ~[leaf+"malformed internal source lost its parser site" leaf+(trip p.got)]
  ~
++  test-malformed-group
  ^-  tang
  =/  public=@t  '+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a'
  =/  groups=(list iprelude-group-source:jibb)
    ~[[%demo /lib/jibb/groups/demo/jibb '+$ broken [@t\0a']]
  =/  got=(each iprelude:jibb @t)
    (prepare-prelude-with-group-bundle-detailed:jibb public '' groups ~)
  ?:  ?=(%& -.got)  ~[leaf+"malformed group source was accepted"]
  ?.  &((contains (trip p.got) "/lib/jibb/groups/demo.jibb:1:") (contains (trip p.got) "expected"))
    ~[leaf+"malformed group lost its parser site" leaf+(trip p.got)]
  ?^  (prepare-bundle:jibb-prelude-fixture public '' groups ~)
    ~[leaf+"unit preparation accepted malformed group source"]
  ~
--
