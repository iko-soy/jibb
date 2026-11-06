::  The Hoon reader and full checker agree on unrestricted and @uw atoms.
/+  jibb, jibb-import
|%
++  test-import-aura
  ^-  tang
  =/  sur=@t  (of-wain:format ~['|%' '+$  bare  @' '+$  wide  @uw' '--'])
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  bare  (read-named:jibb-import %fixture %bare cor)
  =/  wide  (read-named:jibb-import %fixture %wide cor)
  ?.  =([%& [%atom %$ ~]] bare)  ~[leaf+"reader changed the bare atom"]
  ?.  =([%& [%atom %uw ~]] wide)  ~[leaf+"reader changed the @uw atom"]
  ?.  =(`[%any-atom ~] (import-to-itype:jibb p.bare))  ~[leaf+"bare @ did not cross the checker bridge"]
  ?.  =(`[%atom %uw] (import-to-itype:jibb p.wide))  ~[leaf+"@uw did not cross the checker bridge"]
  =/  src=@t  (of-wain:format ~['/- fixture' '++ bare-id |= x=bare.fixture x' '++ wide-id |= x=wide.fixture x'])
  =/  file=path  /ui/probe/jibb
  =/  ext=(list [module=term name=term result=*])  ~[[%fixture %bare bare] [%fixture %wide wide]]
  =/  result  (infer-jibb-file-detailed:jibb file src ext ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.result)  ~[leaf+"full checker rejected imported atom molds"]
  ~
--
