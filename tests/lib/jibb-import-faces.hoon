::  A duplicate field must be proved from the source record, not a
::  flattened Hoon type graph that may have lost nested boundaries.
/+  jibb, jibb-import
|%
++  test-import-faces
  ^-  tang
  =/  source=@t
    (rap 3 (turn ~['|%' '+$  repeated  [field=@ud field=@t]' '+$  nested  [outer=[field=@ud field=@t] ok=@ud]' '+$  separate  [left=[field=@ud] right=[field=@t]]' '+$  ovl2  $?(@t @ud)' '+$  cel  $^([@t @t] [@ud @ud])' '--'] |=(line=@t (cat 3 line '\0a'))))
  =/  cor=type  -:(ride -:!>(..zuse) source)
  =/  repeated  (read-named-diagnostic:jibb-import %fixture %repeated cor)
  =/  nested  (read-named-diagnostic:jibb-import %fixture %nested cor)
  =/  separate  (read-named-diagnostic:jibb-import %fixture %separate cor)
  ?.  =([%invalid %face 'Hoon record repeats field `field`'] repeated)
    ~[leaf+"direct duplicate record face was not reported"]
  ?.  =([%invalid %face 'Hoon record repeats field `field`'] nested)
    ~[leaf+"nested duplicate record face was not reported"]
  ?.  ?=([%ok *] separate)
    ~[leaf+"fields in separate nested records were treated as duplicates"]
  =/  ovl2  (read-named-diagnostic:jibb-import %fixture %ovl2 cor)
  =/  cel  (read-named-diagnostic:jibb-import %fixture %cel cor)
  ?.  ?=([%invalid %overlap *] ovl2)
    ~[leaf+"overlapping $? atoms were not reported"]
  ?.  ?=([%invalid %overlap *] cel)
    ~[leaf+"overlapping $^ cells were not reported"]
  =/  external=(list [module=term name=term result=*])  ~[[%fixture %repeated repeated]]
  =/  jibb-source=@t  (of-wain:format ~['/- fixture' '++ keep |= x=repeated.fixture x'])
  =/  at=path  /ui/probe/jibb
  =/  checked  (infer-jibb-file-detailed:jibb at jibb-source external ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.checked)  ~[leaf+"full checker accepted a repeated imported field"]
  =/  lines=wall  (turn (to-wain:format message.p.checked) |=(line=@t (trip line)))
  ?.  (lien lines |=(line=tape =(line "++ keep: Hoon record repeats field `field`")))
    ~[leaf+"full checker lost the repeated-field diagnostic: {(trip message.p.checked)}"]
  ?.  (lien lines |=(line=tape =(line "/ui/probe.jibb:2:14: invalid imported mold")))
    ~[leaf+"full checker did not locate the repeated-field use"]
  ~
::
::  Each $: is a record of its own, as the written-record check reads
::  Jibb's: a nested record's faces don't repeat its parent's. Hoon's type
::  graph merges a nested $: in a record's last field into the record's
::  own cells, so the reader decides from the source, following local
::  molds; with no +$ source, a repeat in one cell is still definite, and
::  one only along a spine of cells fails closed as unverified.
++  test-import-face-scopes
  ^-  tang
  =/  lines=(list @t)
    :~  '|%'
        '+$  tail  [a=@t [b=@ud a=@p]]'
        '+$  spine  [a=@t b=@ud a=@p]'
        '+$  via  [a=@ b=twin]'
        '+$  twin  [c=@ c=@]'
        '+$  via-flat  [a=@ b=flat]'
        '+$  flat  [c=@ d=@ c=@]'
        '+$  via-tail  [a=@ other]'
        '+$  other  [b=@ a=@]'
        '++  arm-pair  ,[a=@ a=@]'
        '++  arm-spine  ,[a=@ b=@ a=@]'
        '--'
    ==
  =/  source=@t  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
  =/  cor=type  -:(ride -:!>(..zuse) source)
  =/  read
    |=  name=term
    (read-named-diagnostic:jibb-import %fixture name cor)
  =/  tail  (read %tail)
  ?.  ?=([%ok *] tail)
    ~[leaf+"a nested record's repeated face was read as one record's"]
  ?.  ?=([%ok *] (read %via-tail))
    ~[leaf+"a referenced record's face was read as its parent's"]
  ?.  =([%invalid %face 'Hoon record repeats field `a`'] (read %spine))
    ~[leaf+"a repeated face in one record was not reported"]
  ?.  =([%invalid %face 'Hoon record repeats field `c`'] (read %via))
    ~[leaf+"a referenced record's repeated face was not reported"]
  ?.  =([%invalid %face 'Hoon record repeats field `c`'] (read %via-flat))
    ~[leaf+"a referenced flat record's repeated face was not reported"]
  ?.  =([%invalid %face 'Hoon record repeats field `a`'] (read %arm-pair))
    ~[leaf+"a repeated face in one cell was not reported without source"]
  =/  spine  (read %arm-spine)
  =/  why=@t
    %+  rap  3
    :~  'Hoon record fields could not be verified: `a` repeats along '
        'nested cells, and the source does not show which are one record'
    ==
  ?.  =([%unsupported why] spine)
    ~[leaf+"an unverifiable repeated face did not fail closed"]
  ::  a successful read reaches the checker as the host passes it,
  ::  [%& node] (+read-module-result); a diagnostic as it is
  =/  external=(list [module=term name=term result=*])
    ~[[%fixture %tail [%& value.tail]] [%fixture %arm-pair (read %arm-pair)]]
  =/  at=path  /ui/probe/jibb
  =/  keep=@t  (of-wain:format ~['/- fixture' '++ keep |= x=tail.fixture x'])
  =/  kept  (infer-jibb-file-detailed:jibb at keep external ~ ~ ~[at] ~ ~ ~ ~)
  ?.  ?=(%& -.kept)
    ~[leaf+"full checker rejected a nested record's repeated face"]
  =/  pair=@t  (of-wain:format ~['/- fixture' '++ keep |= x=arm-pair.fixture x'])
  =/  checked  (infer-jibb-file-detailed:jibb at pair external ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.checked)  ~[leaf+"full checker accepted a repeated face in one cell"]
  =/  got=wall  (turn (to-wain:format message.p.checked) |=(line=@t (trip line)))
  ?.  (lien got |=(line=tape =(line "++ keep: Hoon record repeats field `a`")))
    ~[leaf+"full checker lost the definite repeated-field diagnostic: {(trip message.p.checked)}"]
  ?.  (lien got |=(line=tape =(line "/ui/probe.jibb:2:14: invalid imported mold")))
    ~[leaf+"full checker did not locate the repeated-field use"]
  ~
--
