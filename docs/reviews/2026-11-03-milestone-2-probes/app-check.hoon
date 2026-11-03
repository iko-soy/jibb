=/  prepared=iprelude  (need (prepare-prelude-with-internal prelude internal))
=/  todo=type  -:(ride -:!>(..zuse) sur)
=/  subject=type  [%cell [%face %todo todo] -:!>(..zuse)]
=/  ma=*  (read-mark:imp %todo-action -:(ride subject action))
=/  mt=*  (read-mark:imp %todos -:(ride subject todos))
=/  mu=*  (read-mark:imp %todo-update -:(ride subject update))
=/  mi=*  (read-mark:imp %todo-item -:(ride subject item))
=/  blog=type  -:(ride -:!>(..zuse) blogsur)
=/  blog-subject=type  [%cell [%face %blog blog] -:!>(..zuse)]
=/  mp=*  (read-mark:imp %posts -:(ride blog-subject posts))
=/  item-input=*  (read-named:imp %todo %item todo)
=/  post-input=*  (read-named:imp %blog %post blog)
=/  marks=imark-externals  ~[[%todo-action ma] [%todos mt] [%todo-update mu] [%todo-item mi] [%posts mp]]
=/  externals=iexternals  ~[[%todo %item item-input] [%blog %post post-input]]
=/  all-modules=jbundle
  :~  [/ui/api/todo/jibb todoapi]
      [/ui/todo-list/jibb todolist]
      [/ui/api/blog/jibb blogapi]
      [/ui/components/card/jibb card]
      [/ui/stores/cart/jibb cart]
  ==
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
=/  extra=jbundle
  %+  murn  sections
  |=  [label=@t body=wain]
  ^-  (unit jsource)
  =/  words=(list tape)  (rash label (more ace (star ;~(less ace next))))
  ?.  (gte (lent words) 3)  ~
  ?.  =('module' (crip (snag 1 words)))  ~
  `[(stab (crip (snag 0 words))) (of-wain:format body)]
=/  base=jbundle
  %+  weld  extra
  (skip all-modules |=(j=jsource (lien extra |=(e=jsource =(at.e at.j)))))
^-  tape
%-  zing
%+  turn  sections
|=  [label=@t body=wain]
^-  tape
=/  words=(list tape)  (rash label (more ace (star ;~(less ace next))))
=/  at=path  (stab (crip (snag 0 words)))
=/  text=@t  (of-wain:format body)
=/  modules=jbundle  (skip base |=(j=jsource =(at.j at)))
=/  r=jfile-detailed-result
  (infer-jibb-file-detailed at text externals marks modules ~[at] values.prepared molds.prepared ~ `iface.prepared)
=/  head=tape  "#### {(trip label)}\0a"
?:  ?=(%| -.r)  `tape`(zing `(list tape)`~[head "REJECTED: " (trip message.p.r) "\0a"])
=/  ms=(list tape)
  %+  turn  molds.iface.p.r
  |=  [name=term s=ischeme]
  "+$ {(trip name)}: {(show-itype (canonical-itype typ.s vars.s) ~)}\0a"
=/  vals=(list tape)
  %+  turn  values.iface.p.r
  |=  [name=term s=ischeme]
  =/  c=itype  (canonical-itype typ.s vars.s)
  "++ {(trip name)}: {(show-itype c ~)}{(show-atom-constraint c)}\0a"
`tape`(zing `(list tape)`~[head "CHECKED\0a" `tape`(zing ms) `tape`(zing vals)])
