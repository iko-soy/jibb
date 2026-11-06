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
--
