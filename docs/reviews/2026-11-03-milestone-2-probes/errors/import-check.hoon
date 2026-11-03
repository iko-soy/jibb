=>  [lib=jibb-lib reader=reader prelude=prelude internal=internal ..zuse]
=/  prepared=iprelude:lib  (need (prepare-prelude-with-internal:lib prelude internal))
=/  sur=@t
  '''
  |%
  +$  signed  @sd
  +$  flt  @rd
  +$  gat  $-(@t @t)
  +$  vas  vase
  +$  dup  [a=@ud a=@t]
  +$  ovl  $%([%a @t] [%a @ud])
  +$  ovl2  $?(@t @ud)
  +$  cel  $^([@t @t] [@ud @ud])
  +$  good  @t
  +$  cor  _^|(|=(a=@ a))
  --
  '''
=/  cor=type  -:(ride -:!>(..zuse) sur)
=/  conv
  |=  d=import-diagnostic:reader
  ^-  *
  ?-  -.d
    %ok  [%& value.d]
    %invalid  d
    %unsupported  [%| message.d]
  ==
=/  names=(list term)  ~[%signed %flt %gat %vas %dup %ovl %ovl2 %cel %good %cor]
=/  ext=(list [module=term name=term result=*])
  %+  turn  names
  |=  n=term
  =/  r  (mule |.((read-named-diagnostic:reader %fix n cor)))
  ?:  ?=(%| -.r)  [%fix n [%| 'reader crashed']]
  [%fix n (conv p.r)]
=/  raw=(list [term *])
  %+  turn  names
  |=  n=term
  =/  r  (mule |.((read-named-diagnostic:reader %fix n cor)))
  ?:  ?=(%| -.r)  [n %crash]
  [n p.r]
=/  mark-src=@t
  '''
  |_  a=@t
  ++  grab  |%  ++  noun  @t  --
  ++  grow  |%  ++  noun  a  --
  ++  grad  %noun
  --
  '''
=/  mcor=type  -:(ride -:!>(..zuse) mark-src)
=/  full-mark=*  (read-mark:reader %full mcor)
=/  marks=(list [mark=term result=*])  ~[[%full full-mark]]
=/  probes=(list [label=@t at=path src=@t mods=jbundle:lib])
  :~  ['I1-signed' /ui/probe/jibb '/- fix\0a++ a |= x=signed.fix x\0a' ~]
      ['I2-float' /ui/probe/jibb '/- fix\0a++ a |= x=flt.fix x\0a' ~]
      ['I3-gate' /ui/probe/jibb '/- fix\0a++ a |= x=gat.fix x\0a' ~]
      ['I3b-core' /ui/probe/jibb '/- fix\0a++ a |= x=cor.fix x\0a' ~]
      ['I4-vase' /ui/probe/jibb '/- fix\0a++ a |= x=vas.fix x\0a' ~]
      ['I5-dupfields' /ui/probe/jibb '/- fix\0a++ a |= x=dup.fix x\0a' ~]
      ['I6-overlap-cen' /ui/probe/jibb '/- fix\0a++ a |= x=ovl.fix x\0a' ~]
      ['I7-overlap-wut' /ui/probe/jibb '/- fix\0a++ a |= x=ovl2.fix x\0a' ~]
      ['I8-overlap-ket' /ui/probe/jibb '/- fix\0a++ a |= x=cel.fix x\0a' ~]
      ['I9-good-unused-bad' /ui/probe/jibb '/- fix\0a++ a |= x=good.fix x\0a' ~]
      ['M1-cycle' /ui/probe/jibb '/=  a /ui/a\0a++ v (identity.a "hi")\0a' ~[[/ui/a/jibb '/=  b /ui/b\0a++ identity |=(x (identity.b x))\0a'] [/ui/b/jibb '/=  a /ui/a\0a++ identity |=(x (identity.a x))\0a']]]
      ['M1b-root-cycle' /ui/probe/jibb '/=  a /ui/a\0a++ v 1\0a' ~[[/ui/a/jibb '/=  p /ui/probe\0a++ w 2\0a']]]
      ['M2-derived-clash' /ui/probe/jibb '/= api /ui/api/demo\0a++ x 1\0a' ~[[/ui/api/demo/jibb '/% %full\0a+$ paths\0a  [%plain /plain full]\0a  [%other /other full]\0a++ plain 5\0a']]]
      ['M2b-derived-clash-root' /ui/api/demo/jibb '/% %full\0a+$ paths\0a  [%plain /plain full]\0a  [%other /other full]\0a++ plain 5\0a' ~]
      ['M2c-derived-face-clash' /ui/api/demo/jibb '/% %full\0a/- plain\0a+$ paths\0a  [%plain /plain full]\0a' ~]
      ['M2d-poke-clash' /ui/api/demo/jibb '/% %full\0a+$ poke full\0a++ poke "bad"\0a' ~]
      ['M3-facts-in-library' /ui/probe/jibb '/% %full\0a+$ x (facts full full)\0a' ~]
      ['M3b-facts-in-api-other-mold' /ui/api/demo/jibb '/% %full\0a+$ paths\0a  [%plain /plain full]\0a+$ x (facts full full)\0a' ~]
      ['M4-shadow-import-face' /ui/probe/jibb '/=  lib /ui/lib\0a++ f |= lib=@t lib\0a' ~[[/ui/lib/jibb '++ identity |=(x x)\0a']]]
      ['M4b-shadow-import-value' /ui/probe/jibb '/=  lib /ui/lib\0a++ lib 1\0a' ~[[/ui/lib/jibb '++ identity |=(x x)\0a']]]
      ['M5-api-ok' /ui/api/demo/jibb '/% %full\0a+$ paths\0a  [%plain /plain full]\0a' ~]
  ==
=/  out=(list tape)
  %+  turn  probes
  |=  [label=@t at=path src=@t mods=jbundle:lib]
  ^-  tape
  =/  r  (mule |.((infer-jibb-file-detailed:lib at src ext marks mods ~[at] values.prepared molds.prepared ~ `iface.prepared)))
  =/  head=tape  "#### {(trip label)}\0a"
  ?:  ?=(%| -.r)  `tape`(weld head "CRASH\0a")
  =/  res  p.r
  ?:  ?=(%| -.res)  `tape`(zing `(list tape)`~[head "REJECTED: " (trip message.p.res) "\0a"])
  =/  vals=(list tape)
    %+  turn  values.iface.p.res
    |=  [name=term s=ischeme:lib]
    ^-  tape
    "++ {(trip name)}: {(show-itype:lib (canonical-itype:lib typ.s vars.s) ~)}\0a"
  `tape`(zing `(list tape)`~[head "CHECKED\0a" `tape`(zing vals)])
=/  rawt=tape
  %-  zing
  %+  turn  raw
  |=  [n=term v=*]
  ^-  tape
  =/  desc=tape
    ?@  v  "atom"
    ?:  ?=([%invalid @ @] v)  "invalid {(trip ;;(@t +<.v))}: {(trip ;;(@t +>.v))}"
    ?:  ?=([%unsupported @] v)  "unsupported: {(trip ;;(@t +.v))}"
    ?:  ?=([%ok *] v)  "ok"
    "other"
  "{(trip n)}: {desc}\0a"
^-  tape  (zing `(list tape)`~[`tape`(zing out) "#### RAW\0a" rawt])
