/+  jibb, jibb-import
|%
++  zuse-type
  ^-  type
  -:!>(..zuse)
::
++  real-source
  ^-  @t
  '|%\0a+$  item  [id=@ud text=@t]\0a--\0a'
::
++  stale-source
  ^-  @t
  '|%\0a+$  item  [id=@t text=@t]\0a--\0a'
::
++  real-core
  ^-  type
  -:(ride zuse-type real-source)
::
++  build-subject
  ^-  type
  [%cell [%face %real real-core] zuse-type]
::
++  mark-core
  ^-  type
  -:(ride build-subject '|_  a=item:real\0a++  grab  |%  ++  noun  item:real  --\0a++  grow  |%  ++  noun  a  --\0a++  grad  %noun\0a--\0a')
::
++  valid-inputs
  ^-  (list [module=term at=path source=@t])
  ~[[%real /sur/real/hoon real-source]]
::
++  raw-item
  ^-  type
  (~(play ut real-core) (ream '*item'))
::
++  declarations
  =,  jibb-import
  |=  inputs=(list [module=term at=path source=@t])
  ^-  (list mark-source-declaration)
  (mark-source-declarations inputs raw-item build-subject)
::
++  read-external
  =,  jibb-import
  |=  inputs=(list [module=term at=path source=@t])
  ^-  (each mark-source @t)
  (read-mark-source %external-mark inputs mark-core)
::
++  body-matches
  =,  jibb-import
  |=  got=(each mark-source @t)
  ^-  tang
  =/  expected=(each imported @t)  (read-mark %external-mark mark-core)
  ?:  ?=(%| -.expected)  ~[leaf+"valid mark fixture was rejected"]
  ?:  ?=(%| -.got)  ~[leaf+"source evidence changed a semantic error"]
  ?.  =(p.expected body.p.got)
    ~[leaf+"source evidence changed the imported semantic body"]
  ~
::
++  expect-no-origin
  =,  jibb-import
  |=  inputs=(list [module=term at=path source=@t])
  ^-  tang
  =/  got=(each mark-source @t)  (read-external inputs)
  =/  errors=tang  (body-matches got)
  ?^  errors  errors
  ?:  ?=(%| -.got)  ~[leaf+"source evidence changed a semantic error"]
  ?^  origin.p.got  ~[leaf+"unauthenticated origin was published"]
  ~
::
++  test-valid-source
  =,  jibb-import
  ^-  tang
  =/  got=(each mark-source @t)  (read-external valid-inputs)
  =/  errors=tang  (body-matches got)
  ?^  errors  errors
  =/  found=(list mark-source-declaration)  (declarations valid-inputs)
  ?.  ?=([* ~] found)  ~[leaf+"valid source declaration was not unique"]
  =/  declaration=mark-source-declaration  i.found
  ?.  &(=(module.declaration %real) =(name.declaration %item))
    ~[leaf+"declaration was selected by mark spelling or shape"]
  ?.  &(=(at.declaration /sur/real/hoon) =(source.declaration real-source))
    ~[leaf+"authenticated source text or path changed"]
  ?:  ?=(%| -.got)  ~[leaf+"source evidence changed a semantic error"]
  ?~  origin.p.got  ~[leaf+"authenticated declaration text did not provide a source site"]
  ?.  =(site.u.origin.p.got [[2 5] [2 5]])  ~[leaf+"declaration text site differs"]
  ?.  =(module.u.origin.p.got %real)  ~[leaf+"wrong origin module"]
  ?.  =(name.u.origin.p.got %item)  ~[leaf+"wrong origin declaration"]
  ?.  =(at.u.origin.p.got /sur/real/hoon)  ~[leaf+"wrong origin path"]
  ?.  =(source.u.origin.p.got real-source)  ~[leaf+"wrong origin source"]
  (expect-no-origin ~)
::
++  test-stale-source
  ^-  tang
  =/  inputs=(list [module=term at=path source=@t])
    ~[[%real /sur/real/hoon stale-source]]
  ?.  =(~ (declarations inputs))  ~[leaf+"stale rebuilt core was authenticated"]
  (expect-no-origin inputs)
::
++  test-duplicate-source
  ^-  tang
  =/  inputs=(list [module=term at=path source=@t])
    (weld valid-inputs valid-inputs)
  =/  found=(list mark-source-declaration:jibb-import)  (declarations inputs)
  ?.  ?=([* * ~] found)  ~[leaf+"duplicate declarations were not retained for the ambiguity check"]
  (expect-no-origin inputs)
::
++  test-wrong-path
  ^-  tang
  =/  inputs=(list [module=term at=path source=@t])
    ~[[%real /sur/decoy/hoon real-source]]
  ?.  =(~ (declarations inputs))  ~[leaf+"wrong source path was authenticated"]
  (expect-no-origin inputs)
::
++  test-same-shaped-decoy
  =,  jibb-import
  ^-  tang
  =/  decoy=[module=term at=path source=@t]
    [%decoy /sur/decoy/hoon real-source]
  =/  both=(list [module=term at=path source=@t])
    [decoy valid-inputs]
  =/  found=(list mark-source-declaration)  (declarations both)
  ?.  ?=([* ~] found)  ~[leaf+"real declaration was not selected beside a decoy"]
  ?.  =(module.i.found %real)  ~[leaf+"same-shaped decoy won by list order"]
  ?.  =(~ (declarations ~[decoy]))  ~[leaf+"absent faced decoy was authenticated"]
  =/  errors=tang  (expect-no-origin ~[decoy])
  ?^  errors  errors
  =/  got=(each mark-source @t)  (read-external both)
  =/  body-errors=tang  (body-matches got)
  ?^  body-errors  body-errors
  ?:  ?=(%| -.got)  ~[leaf+"real evidence beside a decoy changed the semantic result"]
  ?~  origin.p.got  ~[leaf+"real evidence beside a decoy lost its origin"]
  ?.  =(module.u.origin.p.got %real)  ~[leaf+"real evidence beside a decoy selected the wrong origin"]
  ~
::
++  test-declaration-spot
  =,  jibb-import
  ^-  tang
  =/  at=path  /sur/real/hoon
  =/  site=mark-source-span  [[2 3] [2 28]]
  =/  plain=hoon  [%ktcl [%name %item [%base [%atom %ud]]]]
  =/  declaration=mark-source-declaration
    [%real %item at real-source [%dbug [at site] plain]]
  ?.  =((mark-declaration-site declaration) `site)
    ~[leaf+"real declaration spot was not recovered"]
  ?.  =(~ (mark-declaration-site declaration(arm plain)))
    ~[leaf+"declaration without debug evidence gained a site"]
  =/  other=mark-source-span  [[9 1] [9 2]]
  =/  ambiguous=hoon  [%dbug [at other] arm.declaration]
  ?.  =(~ (mark-declaration-site declaration(arm ambiguous)))
    ~[leaf+"conflicting declaration spots were not ambiguous"]
  =/  foreign=hoon  [%dbug [/sur/decoy/hoon site] plain]
  ?.  =(~ (mark-declaration-site declaration(arm foreign)))
    ~[leaf+"spot path did not match authenticated source path"]
  ~
::
++  test-semantic-error-preserved
  =,  jibb-import
  ^-  tang
  =/  bad=type  [%atom %ud ~]
  =/  expected=(each imported @t)  (read-mark %bad bad)
  =/  got=(each mark-source @t)  (read-mark-source %bad valid-inputs bad)
  ?:  ?=(%& -.expected)  ~[leaf+"invalid mark fixture unexpectedly succeeded"]
  ?.  =(got [%| p.expected])  ~[leaf+"semantic mark error was not preserved"]
  ~
::
++  test-checker-envelope-body
  ^-  tang
  =/  got=(each mark-source:jibb-import @t)  (read-external valid-inputs)
  ?:  ?=(%| -.got)  ~[leaf+"valid source-aware mark was rejected"]
  =/  unwrapped=(unit *)  (imported-mark-body:jibb got)
  ?~  unwrapped  ~[leaf+"checker rejected the source-aware envelope"]
  ?.  =(u.unwrapped body.p.got)  ~[leaf+"checker changed the source-aware semantic body"]
  =/  legacy=(each imported:jibb-import @t)  (read-mark:jibb-import %external-mark mark-core)
  =/  old=(unit *)  (imported-mark-body:jibb legacy)
  ?~  old  ~[leaf+"checker rejected a legacy mark result"]
  ?.  =(u.old u.unwrapped)  ~[leaf+"legacy and source-aware bodies differ"]
  =/  externals=imark-externals:jibb  ~[[%external-mark got]]
  ?:  ?=(~ (imported-mark-origin:jibb %external-mark externals ~[%external-mark]))
    ~[leaf+"unique direct mark evidence lost its origin"]
  ?.  ?=(~ (imported-mark-origin:jibb %item externals ~[%item]))
    ~[leaf+"another mark's declaration manufactured an origin"]
  =/  duplicates=imark-externals:jibb
    ~[[%external-mark got] [%external-mark got]]
  ?.  ?=(~ (imported-mark-origin:jibb %external-mark duplicates ~[%external-mark]))
    ~[leaf+"duplicate direct mark evidence manufactured an origin"]
  ~
--
