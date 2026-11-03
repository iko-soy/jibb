::  Full-module check of several sources in one eval.  Bind `src` to a
::  file whose sections each start with a line "#### <label>"; each
::  section is checked on its own as /ui/probe/jibb against the real
::  prelude.  Bind: prelude, internal, src.
=/  prepared=iprelude  (need (prepare-prelude-with-internal prelude internal))
=/  at=path  /ui/probe/jibb
=/  lines=wain  (to-wain:format src)
=|  out=(list [label=@t body=wain])
=|  cur=(unit [label=@t body=wain])
=/  sections=(list [label=@t body=wain])
  |-
  ?~  lines
    (flop ?~(cur out [[label.u.cur (flop body.u.cur)] out]))
  ?:  =('#### ' (end [3 5] i.lines))
    =?  out  ?=(^ cur)  [[label.u.cur (flop body.u.cur)] out]
    $(lines t.lines, cur `[(rsh [3 5] i.lines) ~])
  ?~  cur  $(lines t.lines)
  $(lines t.lines, body.u.cur [i.lines body.u.cur])
^-  tape
%-  zing
%+  turn  sections
|=  [label=@t body=wain]
^-  tape
=/  text=@t  (of-wain:format body)
=/  r=jfile-detailed-result
  (infer-jibb-file-detailed at text ~ ~ ~ ~[at] values.prepared molds.prepared ~ `iface.prepared)
=/  head=tape  "#### {(trip label)}\0a"
?:  ?=(%| -.r)  `tape`(zing `(list tape)`~[head "REJECTED: " (trip message.p.r) "\0a"])
=/  ms=(list tape)
  %+  turn  molds.iface.p.r
  |=  [name=term s=ischeme]
  "+$ {(trip name)}: {(show-itype (canonical-itype typ.s vars.s) ~)}\0a"
=/  vals=(list tape)
  %+  turn  values.iface.p.r
  |=  [name=term s=ischeme]
  "++ {(trip name)}: {(show-itype (canonical-itype typ.s vars.s) ~)}\0a"
`tape`(zing `(list tape)`~[head "CHECKED\0a" `tape`(zing ms) `tape`(zing vals)])
