::  The host's per-request read for a page with data. The agent's %u peek
::  decides whether the path exists; only a present path is read as %gx.
::  A failed probe or read fails the thread, which is the page's 500.
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
=/  present=?  .^(? %gu (weld base at))
?.  present  (pure:m !>(`(unit *)`~))
=/  value=*  .^(* %gx (weld base (snoc at %noun)))
(pure:m !>(`(unit *)``value))
