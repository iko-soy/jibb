::  The host's per-request read for a page with data: a %gx scry of the
::  agent at the path its load named, as a noun.  Gall cannot recover from
::  a failed scry, so the host runs it here: an agent that rejects the path
::  ends this thread, not the host's event, and the page answers 404.
/-  spider
/+  strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=/  [agent=@tas at=path]  !<([@tas path] arg)
;<  =bowl:spider  bind:m  get-bowl:strandio
=/  base=path  /(scot %p our.bowl)/[agent]/(scot %da now.bowl)
(pure:m !>(.^(* %gx (weld base (snoc at %noun)))))
