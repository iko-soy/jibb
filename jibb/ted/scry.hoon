::  The host's per-request read for a page with data: a %gx scry of the
::  agent at the path its load named, as a noun.  Gall cannot recover from
::  a failed scry, so the host runs it here.  A path the agent does not
::  answer fails the scry, which this thread catches, giving ~, the page's
::  404; the agent's noun is [~ noun].  Any other failure fails the
::  thread, which is the page's 500.
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
=/  read=(each * tang)  (mule |.(.^(* %gx (weld base (snoc at %noun)))))
(pure:m !>(`(unit *)`?:(?=(%& -.read) `p.read ~)))
