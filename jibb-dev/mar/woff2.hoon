::  /mar/woff2.hoon: a WOFF2 font under /ui/static, stored as its bytes
::
::    Static files are served as they are, so the length is kept with the
::    bytes: a file may end in zero bytes.
|_  dat=octs
++  grow
  |%
  ++  mime  [/font/woff2 dat]
  --
++  grab
  |%
  ++  mime  |=([p=mite q=octs] q)
  ++  noun  octs
  --
++  grad  %mime
--
