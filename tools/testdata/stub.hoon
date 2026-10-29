::  tools/testdata/stub.hoon: a stand-in for jibb-dev/lib/jibb.hoon
::
::  It has only the golden arm, written trivially, so that tools/golden
::  and tools/hoon can be tested without the compiler:
::
::    tokens: the file path, the byte and line counts, then each line
::      numbered
::    tree: the source's first line
::
::  Some first lines misbehave on purpose, to test the runner:
::
::    crash  crashes in +explode, under a ~| trace; mule catches it
::    bail   asks for a 3 GB atom, which ends the whole eval, as running
::           out of memory does; mule can't catch it
::    loop   never returns, for testing timeouts
::
::  tools/testdata/selftest also copies this file with errors put in, to
::  test that errors are reported at the right lines.
::
|%
++  golden
  |=  [file=path src=@t]
  ^-  [tokens=@t tree=@t]
  =/  lines=(list @t)  (split src)
  =/  first=@t  ?~(lines '' i.lines)
  ?:  =('crash' first)
    (explode file)
  ?:  =('bail' first)
    [(crip "{<(met 3 (lsh [3 3.000.000.000] 1))>}") '']
  ?:  =('loop' first)
    [(spin 0) '']
  :_  first
  %+  rap  3
  %+  join  '\0a'
  ^-  (list @t)
  :^    (crip "file: {(spud file)}")
      (crip "bytes: {(a-co:co (met 3 src))}")
    (crip "lines: {(a-co:co (lent lines))}")
  (number lines)
::
::  +split: lines, without the empty one after a final newline
::
++  split
  |=  src=@t
  ^-  (list @t)
  =/  len=@ud  (met 3 src)
  =|  [i=@ud start=@ud out=(list @t)]
  |-  ^-  (list @t)
  ?:  =(i len)
    %-  flop
    ?:  =(start len)  out
    [(cut 3 [start (sub i start)] src) out]
  ?.  =(10 (cut 3 [i 1] src))
    $(i +(i))
  $(i +(i), start +(i), out [(cut 3 [start (sub i start)] src) out])
::
++  number
  |=  lines=(list @t)
  ^-  (list @t)
  =/  n=@ud  1
  |-  ^-  (list @t)
  ?~  lines  ~
  :-  (rap 3 ~[(crip (a-co:co n)) '| ' i.lines])
  $(lines t.lines, n +(n))
::
++  spin
  |=  n=@ud
  ^-  @t
  $(n +(n))
::
++  explode
  |=  file=path
  ^-  [tokens=@t tree=@t]
  ~|  [%stub-crash file]
  ?>  =(1 2)
  ['' '']
--
