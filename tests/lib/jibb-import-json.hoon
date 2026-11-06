::  The standard recursive Hoon json mold is imported through a /sur alias.
/+  jibb, jibb-import
|%
++  test-import-json
  ^-  tang
  =/  sur=@t  '|%\0a+$  entry  json\0a--\0a'
  =/  cor=type  -:(ride -:!>(..zuse) sur)
  =/  imported  (read-named:jibb-import %fixture %entry cor)
  ?:  ?=(%| -.imported)
    ~[leaf+"json import was rejected: {(trip p.imported)}"]
  =/  source=@t  '/- fixture\0a++ identity |= x=entry.fixture x\0a'
  =/  at=path  /tests/import-json/jibb
  =/  externals=iexternals:jibb  ~[[%fixture %entry imported]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source externals ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)
    ~[leaf+"full checker rejected imported json: {(trip message.p.checked)}"]
  ~
--
