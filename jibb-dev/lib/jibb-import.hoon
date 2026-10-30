::  /lib/jibb-import.hoon: a partial reader of Hoon's type graph
::
::  +read-mold accepts one selected Hoon type and its module/name, rather
::  than loading a whole /sur. The caller selects only types actually used.
::  Hoon's %hold nodes retain the generator's Hoon and its bound arguments.
::  Comparing that Hoon to the standard generators identifies collections
::  before they expand into trees. Recursive holds are tracked by identity;
::  a repeated named hold becomes a module-qualified reference.
::
::  This is not yet connected to Jibb's checker: source-level $^ overlap,
::  imported aliases, marks, ordered maps, and full error locations still
::  need work. Failures return %|; no partial tree is returned as success.
::
|%
+$  imported
  $~  [%noun ~]
  $%  [%noun ~]
      [%void ~]
      [%atom aura=term value=(unit @)]
      [%cell head=imported tail=imported]
      [%face name=term body=imported]
      [%fork cases=(list imported)]
      [%apply name=term args=(list imported)]
      [%ref module=term name=term]
      [%bad reason=@t]
  ==
+$  signatures  (list [name=term code=hoon])
+$  visiting    (list [typ=type name=(unit term)])
::
::  +code-of: the generator body, independent of its mold arguments.
::
++  code-of
  |=  text=@t
  ^-  hoon
  =/  typ=type  (~(play ut -:!>(..zuse)) (ream text))
  ?>  ?=([%hold *] typ)
  q.typ
::
++  catalog
  ^-  signatures
  :~  [%map (code-of '*(map @ud @ud)')]
      [%set (code-of '*(set @ud)')]
      [%qeu (code-of '*(qeu @ud)')]
      [%jar (code-of '*(jar @ud @ud)')]
      [%jug (code-of '*(jug @ud @ud)')]
      [%list (code-of '*(list @ud)')]
      [%unit (code-of '*(unit @ud)')]
      [%vase (code-of '*vase')]
  ==
::
++  read-mold
  |=  [module=term name=term typ=type]
  ^-  (each imported @t)
  =/  out  (walk module typ catalog ~)
  =/  err  (first-bad out)
  ?~  err  [%& out]
  [%| u.err]
::
::  +hold-name: names supplied by Hoon's %made note survive on a hold.
::
++  hold-name
  |=  h=hoon
  ^-  (unit term)
  ?:  ?=([%tsls [%note [%made *] *] *] h)
    [~ p.p.p.h]
  ~
::
::  The named wrapper records an alias before Hoon reduces it to a map.
++  hold-alias
  |=  h=hoon
  ^-  (unit term)
  ?.  ?=([%tsls [%note * *] *] h)  ~
  =/  body=hoon  q.p.h
  ?.  ?=([%cncl *] body)  ~
  ?.  ?=([%tsgr *] p.body)  ~
  ?.  ?=([%cncl *] q.p.body)  ~
  ?.  ?=([%wing *] p.q.p.body)  ~
  =/  w=wing  p.p.q.p.body
  ?:  =(w ~[%jar])  [~ %jar]
  ?:  =(w ~[%jug])  [~ %jug]
  ~
::
::  Nested aliases can be erased before their hold is exposed. Until the
::  source tree is walked in parallel, reject that input instead of
::  mistaking a jar or jug for its underlying map, or a mop for a tree.
++  has-hidden-alias
  |=  h=*
  ^-  ?
  ?:  |(=(h [%wing ~[%jar]]) =(h [%wing ~[%jug]]) =(h [%wing ~[%mop]]))  &
  ?@  h  |
  |($(h -.h) $(h +.h))
::
::  $^ is lowered to a conditional by Hoon's parser; conservatively
::  reject its distinctive test until the original branches have been
::  checked for disjointness. Other Hoon code can produce the same test,
::  so this partial reader may reject some supported molds too.
++  has-cell-union
  |=  h=*
  ^-  ?
  ?@  h  |
  ?:  =(h [%dtwt [%$ 12]])  &
  |($(h -.h) $(h +.h))
::
++  match-signature
  |=  [h=hoon sig=signatures]
  ^-  (unit term)
  ?~  sig  ~
  ?:  =(h code.i.sig)  [~ name.i.sig]
  $(sig t.sig)
::
++  find-seen
  |=  [typ=type seen=visiting]
  ^-  (unit (unit term))
  ?~  seen  ~
  ?:  =(typ typ.i.seen)  [~ name.i.seen]
  $(seen t.seen)
::
++  walk
  |=  [module=term typ=type sig=signatures seen=visiting]
  ^-  imported
  ?-  typ
    %noun  [%noun ~]
    %void  [%void ~]
    [%atom *]
      ?:  |(=('s' (cut 3 [0 1] p.typ)) =('r' (cut 3 [0 1] p.typ)))
        [%bad 'signed and float auras cannot be imported']
      [%atom p.typ q.typ]
    [%cell *]  [%cell $(typ p.typ) $(typ q.typ)]
    [%core *]  [%bad 'cores and gates cannot be imported']
    [%face *]
      ?@  p.typ  [%face p.typ $(typ q.typ)]
      [%bad 'a complex Hoon face needs translation']
    [%fork *]
      =/  cases=(list imported)
        (turn ~(tap in:..zuse p.typ) |=(t=type ^$(typ t)))
      [%fork (sort cases |=(pair=[imported imported] (dor -.pair +.pair)))]
    [%hint *]  $(typ q.typ)
    [%hold *]
      =/  named=(unit term)  (match-signature q.typ sig)
      ?^  named
        =/  name  u.named
        ?:  =(%vase name)  [%bad 'vases cannot be imported']
        =/  first=type
          (~(play ut p.typ) (ream ?:(|(=(%map name) =(%jar name) =(%jug name)) '*key' '*item')))
        =/  first-import  $(typ first)
        ?:  |(=(%map name) =(%jar name) =(%jug name))
          =/  second=type  (~(play ut p.typ) (ream '*value'))
          [%apply name ~[first-import $(typ second)]]
        [%apply name ~[first-import]]
      =/  prior=(unit (unit term))  (find-seen typ seen)
      ?^  prior
        ?~  u.prior  [%bad 'an anonymous recursive Hoon mold cannot be named']
        [%ref module u.u.prior]
      =/  nm  (hold-name q.typ)
      ?:  =(nm [~ %vase])  [%bad 'vases cannot be imported']
      ?:  (has-cell-union q.typ)
        [%bad 'a Hoon $^ union needs a source-level disjointness check']
      =/  alias  (hold-alias q.typ)
      ?:  &(?=(~ alias) (has-hidden-alias q.typ))
        [%bad 'a nested jar, jug or mop needs source-aware import']
      =/  body  $(typ ~(repo ut typ), seen [[typ nm] seen])
      ?~  alias  body
      ?.  ?=([%apply %map [* [%apply * [* ~]] ~]] body)
        [%bad 'a Hoon collection alias could not be recovered']
      =/  inner  i.args.i.t.args.body
      ?:  &(?=(%jar u.alias) ?=(%list name.i.t.args.body))
        [%apply %jar ~[i.args.body inner]]
      ?:  &(?=(%jug u.alias) ?=(%set name.i.t.args.body))
        [%apply %jug ~[i.args.body inner]]
      [%bad 'a Hoon collection alias could not be recovered']
  ==
::
++  first-bad
  |=  out=imported
  ^-  (unit @t)
  ?-  out
    [%noun *]  ~
    [%void *]  ~
    [%atom *]  ~
    [%ref *]  ~
    [%bad *]  [~ reason.out]
    [%face *]  $(out body.out)
    [%cell *]
      =/  err  $(out head.out)
      ?~  err  $(out tail.out)
      err
    [%fork *]  (first-bads cases.out)
    [%apply *]  (first-bads args.out)
  ==
::
++  first-bads
  |=  xs=(list imported)
  ^-  (unit @t)
  ?~  xs  ~
  =/  err  (first-bad i.xs)
  ?~  err  $(xs t.xs)
  err
::  +fixture-test: shared golden expectations for eval and the ship.
++  fixture-test
  |=  [small=@t epic=@t]
  ^-  (list @t)
  =/  sc=type  -:(ride -:!>(..zuse) small)
  =/  ec=type  -:(ride -:!>(..zuse) epic)
  =/  sample
    |=  name=term
    (read-mold %small name (~(play ut sc) (ream (cat 3 '*' name))))
  =/  tlon
    |=  name=term
    (read-mold %epic name (~(play ut ec) (ream (cat 3 '*' name))))
  =/  errors=(list @t)  ~
  =/  expect-action=imported
    [%fork ~[[%cell [%atom %tas [~ %add]] [%face %text [%atom %t ~]]] [%cell [%atom %tas [~ %remove]] [%face %id [%atom %ud ~]]]]]
  =/  errors  ?:  =((sample %action) [%& expect-action])  errors
    ['union cases and faces' errors]
  =/  expect-map=imported
    [%apply %map ~[[%atom %ud ~] [%cell [%face %id [%atom %ud ~]] [%face %text [%atom %t ~]]]]]
  =/  errors  ?:  =((sample %items) [%& expect-map])  errors
    ['map and its arguments' errors]
  =/  expect-optional=imported
    [%fork ~[[%cell [%face %name [%atom %t ~]] [%face %stamp [%atom %ud ~]]] [%atom %ud ~]]]
  =/  errors  ?:  =((sample %optional) [%& expect-optional])  errors
    ['atom-or-cell union' errors]
  =/  expect-containers=imported
    [%cell [%apply %set ~[[%atom %ud ~]]] [%cell [%apply %qeu ~[[%atom %ud ~]]] [%cell [%apply %list ~[[%atom %t ~]]] [%apply %unit ~[[%atom %ud ~]]]]]]
  =/  errors  ?:  =((sample %containers) [%& expect-containers])  errors
    ['set queue list and unit' errors]
  =/  expect-chain=imported
    [%fork ~[[%cell [%face %value [%atom %ud ~]] [%face %next [%ref %small %chain]]] [%atom %n [~ 0]]]]
  =/  errors  ?:  =((sample %chain) [%& expect-chain])  errors
    ['recursive reference' errors]
  =/  expect-jar=imported  [%apply %jar ~[[%atom %ud ~] [%atom %t ~]]]
  =/  expect-jug=imported  [%apply %jug ~[[%atom %ud ~] [%atom %t ~]]]
  =/  errors  ?:  =((sample %jar-test) [%& expect-jar])  errors
    ['jar name and arguments' errors]
  =/  errors  ?:  =((sample %jug-test) [%& expect-jug])  errors
    ['jug name and arguments' errors]
  =/  errors  ?:  =((sample %nested-jar) [%| 'a nested jar, jug or mop needs source-aware import'])  errors
    ['nested jar is explicitly unsupported' errors]
  =/  errors  ?:  =((sample %signed) [%| 'signed and float auras cannot be imported'])  errors
    ['signed aura rejected' errors]
  =/  errors  ?:  =((sample %float) [%| 'signed and float auras cannot be imported'])  errors
    ['float aura rejected' errors]
  =/  errors  ?:  =((sample %gate-test) [%| 'cores and gates cannot be imported'])  errors
    ['gate rejected' errors]
  =/  errors  ?:  =((read-mold %std %vase (~(play ut -:!>(..zuse)) (ream '*vase'))) [%| 'vases cannot be imported'])  errors
    ['vase rejected' errors]
  =/  errors  ?:  =((sample %valid-cell) [%| 'a Hoon $^ union needs a source-level disjointness check'])  errors
    ['cell union pending disjointness check' errors]
  =/  errors  ?:  =((sample %invalid-cell) [%| 'a Hoon $^ union needs a source-level disjointness check'])  errors
    ['overlapping cell union is not accepted' errors]
  =/  expect-saga=imported
    [%fork ~[[%cell [%atom %tas [~ %chi]] [%atom %n [~ 0]]] [%cell [%atom %tas [~ %lev]] [%atom %n [~ 0]]] [%cell [%atom %tas [~ %dex]] [%face %ver [%atom %ud ~]]]]]
  =/  errors  ?:  =((tlon %saga) [%& expect-saga])  errors
    ['Tlon saga union' errors]
  =/  errors  ?:  =((tlon %epic) [%& [%atom %ud ~]])  errors
    ['Tlon epic atom' errors]
  errors

::  A compact diagnostic projection for importer golden files. This is
::  not the Jibb type printer: it exposes constants and recursive refs.
++  show-import
  |=  out=imported
  ^-  tape
  ?-  out
    [%noun *]  "*"
    [%void *]  "!!"
    [%atom *]
      ?~  value.out  "@{(trip aura.out)}"
      ?:  =(%tas aura.out)  "{(trip (scot %tas u.value.out))}"
      "@{(trip aura.out)}:{(trip (scot %ud u.value.out))}"
    [%cell *]  "[{(show-import head.out)} {(show-import tail.out)}]"
    [%face *]  "{(trip name.out)}={(show-import body.out)}"
    [%fork *]  "(union {(show-imports cases.out)})"
    [%apply *]  "({(trip name.out)} {(show-imports args.out)})"
    [%ref *]  "{(trip name.out)}.{(trip module.out)}"
    [%bad *]  "error: {(trip reason.out)}"
  ==
::
++  show-imports
  |=  xs=(list imported)
  ^-  tape
  ?~  xs  ""
  ?~  t.xs  (show-import i.xs)
  "{(show-import i.xs)} {$(xs t.xs)}"
::
++  show-result
  |=  result=(each imported @t)
  ^-  tape
  ?-  result
    [%& *]  (show-import p.result)
    [%| *]  "error: {(trip p.result)}"
  ==
::
++  fixture-output
  |=  [small=@t epic=@t]
  ^-  wain
  =/  sc=type  -:(ride -:!>(..zuse) small)
  =/  ec=type  -:(ride -:!>(..zuse) epic)
  =/  sample
    |=  name=term
    (read-mold %small name (~(play ut sc) (ream (cat 3 '*' name))))
  =/  tlon
    |=  name=term
    (read-mold %epic name (~(play ut ec) (ream (cat 3 '*' name))))
  =/  vase  (read-mold %std %vase (~(play ut -:!>(..zuse)) (ream '*vase')))
  :~  (crip "action: {(show-result (sample %action))}")
      (crip "optional: {(show-result (sample %optional))}")
      (crip "items: {(show-result (sample %items))}")
      (crip "containers: {(show-result (sample %containers))}")
      (crip "chain: {(show-result (sample %chain))}")
      (crip "jar: {(show-result (sample %jar-test))}")
      (crip "jug: {(show-result (sample %jug-test))}")
      (crip "nested-jar: {(show-result (sample %nested-jar))}")
      (crip "signed: {(show-result (sample %signed))}")
      (crip "float: {(show-result (sample %float))}")
      (crip "gate: {(show-result (sample %gate-test))}")
      (crip "vase: {(show-result vase)}")
      (crip "valid-cell: {(show-result (sample %valid-cell))}")
      (crip "invalid-cell: {(show-result (sample %invalid-cell))}")
      (crip "tlon-saga: {(show-result (tlon %saga))}")
      (crip "tlon-epic: {(show-result (tlon %epic))}")
  ==

--
