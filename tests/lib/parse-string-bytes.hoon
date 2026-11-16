::  A string's text is its bytes in order, as Hoon's cord literal reads
::  it: an escape such as \00 writes its byte (Grammar, Interpolation),
::  where crip would drop it. A zero byte at the end of a text can't be
::  kept, no atom ending in one, and Hoon's 'a\00' is 'a' too. Each
::  piece of an interpolated string is such a text, and the printers
::  write a kept zero byte back as \00, which reads as the same cord.
/+  jibb
|%
::  the texts of a source's string tokens, in order
++  texts
  |=  src=@t
  ^-  (list @t)
  %+  murn  (layout:jibb /parse/string/jibb src)
  |=  t=token:jibb
  ^-  (unit @t)
  ?+  lex.t  ~
    [%str *]       `p.lex.t
    [%str-head *]  `p.lex.t
    [%str-mid *]   `p.lex.t
    [%str-tail *]  `p.lex.t
  ==
::
++  test-string-bytes
  ^-  tang
  ::  Hoon's own cord literals, the boundary this follows
  ?.  =(3 (met 3 'a\00b'))  ~[leaf+"Hoon's 'a\\00b' is not three bytes"]
  ?.  =('a\00' 'a')  ~[leaf+"Hoon's 'a\\00' kept its trailing zero byte"]
  ?.  =('ab' (crip "a\00b"))  ~[leaf+"crip kept a zero byte"]
  ?.  =(~['nul\00end'] (texts '++ x "nul\\00end"\0a'))
    ~[leaf+"an inner \\00 escape lost its byte"]
  ?.  =(~['\00a'] (texts '++ x "\\00a"\0a'))
    ~[leaf+"a leading \\00 escape lost its byte"]
  ?.  =(~['a\00'] (texts '++ x "a\\00"\0a'))
    ~[leaf+"a trailing \\00 escape differs from Hoon's 'a\\00'"]
  ?.  =(~[''] (texts '++ x "\\00"\0a'))
    ~[leaf+"a string of one zero byte is not empty"]
  =/  pieces=(list @t)
    (texts '++ x |= b=@t "a\\00{b}x\\00y{b}\\00c"\0a')
  ?.  =(~['a\00' 'x\00y' '\00c'] pieces)
    ~[leaf+"an interpolated string's texts lost their zero bytes"]
  ?.  =(3 (met 3 (snag 1 pieces)))
    ~[leaf+"a piece's inner zero byte was dropped"]
  ::  the token printer writes the byte back, and that reads as the cord
  =/  shown=@t  (crip (show-quoted:jibb 'nul\00end'))
  ?.  =('"nul\\00end"' shown)
    ~[leaf+"the printer did not write \\00: {(trip shown)}"]
  ?.  =(~['nul\00end'] (texts (rap 3 ~['++ x ' shown '\0a'])))
    ~[leaf+"a printed string did not read back as its cord"]
  ~
--
