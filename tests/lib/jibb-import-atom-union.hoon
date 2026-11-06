/+  jibb, jibb-import
|%
++  test-atom-union
  ^-  tang
  =/  sur=@t  '|%\0a+$  choice  $@  @ud  $%  [%entry item=@t]  [%other id=@ud]  ==\0a+$  one  $@  @ud  [%only item=@t]\0a+$  overlap  $@  @ud  %0\0a+$  nested-overlap  $@  @ud  $?  %0  [%tag item=@t]  ==\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  result  (read-named:jibb-import %fixture %choice cor)
  ?:  ?=(%| -.result)  ~[leaf+"atom union import failed: {(trip p.result)}"]
  =/  other  (read-named:jibb-import %fixture %one cor)
  ?:  ?=(%| -.other)  ~[leaf+"single-cell atom union import failed: {(trip p.other)}"]
  =/  overlap  (read-named-diagnostic:jibb-import %fixture %overlap cor)
  ?.  =([%invalid %overlap 'Hoon union cases overlap'] overlap)
    ~[leaf+"overlapping atom union was not diagnosed"]
  =/  nested  (read-named-diagnostic:jibb-import %fixture %nested-overlap cor)
  ?.  =([%invalid %overlap 'Hoon union cases overlap'] nested)
    ~[leaf+"nested overlapping atom union was not diagnosed"]
  =/  bad-source=@t  '/- fixture\0a++ bad |= x=overlap.fixture x\0a'
  =/  bad-at=path  /tests/atom-overlap/jibb
  =/  bad-ext=iexternals:jibb  ~[[%fixture %overlap overlap]]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb bad-at bad-source bad-ext ~ ~ ~[bad-at] ~ ~ ~ ~)
  ?:  ?=(%& -.bad)  ~[leaf+"full checker accepted an overlapping atom union"]
  =/  lines=wall  (turn (to-wain:format message.p.bad) |=(line=@t (trip line)))
  ?.  (lien lines |=(line=tape =(line "++ bad: Hoon union cases overlap")))
    ~[leaf+"full checker lost the overlap message"]
  ?.  (lien lines |=(line=tape =(line "/tests/atom-overlap.jibb:2:13: invalid imported mold")))
    ~[leaf+"overlapping atom union lost its use site"]
  =/  source=@t  '/- fixture\0a++ identity |= x=choice.fixture x\0a'
  =/  at=path  /tests/import-atom-union/jibb
  =/  ext=iexternals:jibb  ~[[%fixture %choice result]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ext ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"atom union checker failed: {(trip message.p.checked)}"]
  ~
--
