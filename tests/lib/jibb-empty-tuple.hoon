::  Empty expression tuples and cell molds are errors at their own sites.
/+  jibb
|%
++  test-empty-tuple
  ^-  tang
  =/  file=path  /ui/empty/jibb
  =/  source=@t  '++ x []'
  =/  result  (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"empty tuple was accepted"]
  =/  expected=@t
    (of-wain:format ~['/ui/empty.jibb:1:7: an empty `[]` is not a valid tuple' '++ x []' '      ^'])
  ?.  =(expected message.p.result)  ~[leaf+"empty tuple lost its diagnostic: {(trip message.p.result)}"]
  =/  mold-source=@t  '+$ item [@ud []]'
  =/  mold-result  (infer-jibb-file-detailed:jibb file mold-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.mold-result)  ~[leaf+"empty cell mold was accepted"]
  =/  mold-expected=@t
    (of-wain:format ~['/ui/empty.jibb:1:15: an empty `[]` is not a valid cell mold' '+$ item [@ud []]' '              ^'])
  ?.  =(mold-expected message.p.mold-result)  ~[leaf+"empty cell mold lost its diagnostic: {(trip message.p.mold-result)}"]
  =/  cast-source=@t  '++ x ^- [] 0'
  =/  cast-result  (infer-jibb-file-detailed:jibb file cast-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.cast-result)  ~[leaf+"empty cast mold was accepted"]
  =/  cast-expected=@t
    (of-wain:format ~['/ui/empty.jibb:1:10: an empty `[]` is not a valid cell mold' '++ x ^- [] 0' '         ^'])
  ?.  =(cast-expected message.p.cast-result)  ~[leaf+"empty cast mold lost its diagnostic: {(trip message.p.cast-result)}"]
  =/  contextual-source=@t  '++ x ^- [a=@ud b=@ud] []'
  =/  contextual-result  (infer-jibb-file-detailed:jibb file contextual-source ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.contextual-result)  ~[leaf+"contextual empty tuple was accepted"]
  =/  contextual-expected=@t
    (of-wain:format ~['/ui/empty.jibb:1:24: an empty `[]` is not a valid tuple' '++ x ^- [a=@ud b=@ud] []' '                       ^'])
  ?.  =(contextual-expected message.p.contextual-result)  ~[leaf+"contextual empty tuple lost its diagnostic: {(trip message.p.contextual-result)}"]
  ~
--
