::  tools/testdata/ship-stub.hoon: a stand-in for /lib/jibb.hoon on the ship
::
::  tools/ship test --stub (and sync --stub) puts this file on the
::  jibb-dev desk in place of jibb-dev/lib/jibb.hoon, so the generated
::  tests and the runner can be tested without the compiler.  It has
::  only the golden arm, with the library's signature:
::
::    tokens: "file: <file>", then each line of the source, numbered
::    tree:   "lines: <how many>", then "first: <the first line>"
::
::  A line is what comes before a newline; a final newline doesn't
::  start another line.  A source whose first line is "crash" crashes,
::  under a ~| trace, so a case can test how -test reports a crash.
::  Nothing here loops or makes a huge atom: -test runs as one event, so
::  either would hold up the whole ship.
::
|%
++  golden-types
  |=  [file=path src=@t]
  ^-  @t
  (crip "type of {(spud file)}: {(a-co:co (met 3 src))} bytes")
::
++  golden
  |=  [file=path src=@t]
  ^-  [tokens=@t tree=@t]
  =/  lines=wain  (split src)
  =/  first=@t  ?~(lines '' i.lines)
  ?:  =('crash' first)
    ~|  [%ship-stub-crash file]
    !!
  :-  (of-wain:format [(crip "file: {(spud file)}") (number lines)])
  %-  of-wain:format
  :~  (crip "lines: {(a-co:co (lent lines))}")
      (after 'first:' first)
  ==
::
::  +split: the lines, without the empty one after a final newline
::
++  split
  |=  src=@t
  ^-  wain
  =/  lines=wain  (to-wain:format src)
  ?~  lines  ~
  ?.  =('' (rear lines))  lines
  (snip `wain`lines)
::
::  +number: "1| text", or "1|" for an empty line
::
++  number
  |=  lines=wain
  ^-  wain
  =|  n=@ud
  |-  ^-  wain
  ?~  lines  ~
  :-  (after (cat 3 (crip (a-co:co +(n))) '|') i.lines)
  $(lines t.lines, n +(n))
::
::  +after: a label and some text, with a space between unless the text
::  is empty, so no line ends in a space
::
++  after
  |=  [label=@t text=@t]
  ^-  @t
  ?:  =('' text)  label
  (rap 3 ~[label ' ' text])
--
