/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-earlier-conflict-keeps-its-structure
  ^-  tang
  =/  src=@t  '+$ msg\0a  %add\0a  %remove\0a+$ state [title=@t choice=msg]\0a++ wrong ^- state [~zod %missing]\0a'
  =/  got=@t  (golden-types:jibb /tests/open-diagnostics/jibb src)
  ?.  (contains (trip got) "cast field `title` does not fit")
    ~[leaf+"a later tag replaced the earlier aura conflict" leaf+(trip got)]
  ?.  (contains (trip got) "/tests/open-diagnostics.jibb:4:11: expected field has type [title=@t]")
    ~[leaf+"expected title field site was lost" leaf+(trip got)]
  ?.  (contains (trip got) "/tests/open-diagnostics.jibb:5:20: expression has type @p")
    ~[leaf+"conflicting expression site was lost" leaf+(trip got)]
  ~
++  test-pending-variable-identity
  ^-  tang
  =/  tag=itype:jibb  [%tag 12 [%term %tas %go '%go'] |]
  =/  got=tape  (site-type-note:jibb "value" [%cell tag tag] ~)
  ?.  =(got "value has type [A A]; A remains unresolved for tag `%go`")
    ~[leaf+"a repeated pending variable lost its identity" leaf+got]
  =/  other=itype:jibb  [%tag 13 [%term %tas %stay '%stay'] |]
  =/  distinct=tape  (site-type-note:jibb "value" [%cell tag other] ~)
  ?.  =(distinct "value has type [A B]; A remains unresolved for tag `%go`; B remains unresolved for tag `%stay`")
    ~[leaf+"distinct pending variables collapsed" leaf+distinct]
  ~
++  test-shared-head-payload-diagnostic
  ^-  tang
  =/  src=@t  '+$ attr\0a  [%pad %s0]\0a  [%pad %s1]\0a++ wrong ^- attr pad+%s4\0a'
  =/  got=@t  (golden-types:jibb /tests/open-diagnostics/jibb src)
  ?.  (contains (trip got) "attr case `%pad` has no payload `%s4`; expected %s0 %s1")
    ~[leaf+"shared heads hid the actual rejected payload" leaf+(trip got)]
  ?.  (contains (trip got) "tag literal has type %s4")
    ~[leaf+"shared-head diagnostic lost the payload type" leaf+(trip got)]
  ~
--
