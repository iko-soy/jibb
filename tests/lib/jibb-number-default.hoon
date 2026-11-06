/+  jibb
|%
++  core
  |=  src=@t
  ^-  (unit iresolved:jibb)
  =/  at=path  /ui/numbers/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(globals (global-value-names:jibb ds), at at, in-mold |, jrec-fuel 256)
  (icore-resolve:jibb ds state)
++  test-candidates
  ^-  tang
  =/  state=istate:jibb  *istate:jibb
  =/  result=itype:jibb  [%fn [%atom %t] [%cell [%atom %t] [%nvar 0]]]
  ?.  =((icore-number-candidates:jibb result ~ state) ~[0])
    ~[leaf+"product-only decimal was not queued"]
  =/  linked=itype:jibb  [%fn [%nvar 0] [%nvar 0]]
  ?^  (icore-number-candidates:jibb linked ~ state)
    ~[leaf+"sample-linked numeric variable was queued"]
  =/  env=ienv:jibb  ~[[%outer [[%nvar 0] ~ ~]]]
  ?^  (icore-number-candidates:jibb result env state)
    ~[leaf+"enclosing numeric variable was queued"]
  =/  sub=isub:jibb  (itype-bind:jibb 4 [%nvar 0] ~)
  =/  cap-state=istate:jibb  state(caps ~[['A' 4 *span:jibb]], sub sub)
  ?^  (icore-number-candidates:jibb result ~ cap-state)
    ~[leaf+"written capital was queued for defaulting"]
  ~
++  test-number-queue
  ^-  tang
  =/  at=span:jibb  [[2 1] [2 2]]
  =/  edge=icore-edge:jibb  [%number-default [%nvar 0] at ~ %example]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 1, queue ~[edge], general-defer &)
  =/  waiting=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  waiting  ~[leaf+"an open number was rejected"]
  ?.  =(queue.u.waiting ~[edge])  ~[leaf+"an open number did not wait"]
  =/  scheme=(unit ischeme:jibb)  (icore-generalize:jibb [%nvar 0] 0 u.waiting)
  ?~  scheme  ~[leaf+"an open number could not be generalized"]
  ?^  vars.u.scheme  ~[leaf+"a pending number generalized"]
  =.  state  u.waiting(sub (itype-bind:jibb 0 [%atom %u] sub.u.waiting))
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state)
  ?~  solved  ~[leaf+"a number fixed by context was rejected"]
  ?^  queue.u.solved  ~[leaf+"a fixed number stayed pending"]
  ~
++  test-literal-site
  ^-  tang
  =/  at=span:jibb  [[4 12] [4 13]]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(general-defer &, owner %example)
  =/  expr=expr:jibb  [%lit at [%number %ud 1 '1']]
  =/  result=iresult:jibb  (infer-fragment:jibb expr ~ state)
  ?:  ?=(%| -.result)  ~[leaf+"decimal literal was rejected"]
  ?~  queue.state.p.result  ~[leaf+"decimal origin was not queued"]
  ?.  ?=(%number-default -.i.queue.state.p.result)  ~[leaf+"decimal origin has the wrong edge"]
  ?.  =(owner.i.queue.state.p.result %example)  ~[leaf+"decimal origin lost its owner"]
  ?.  =(at.i.queue.state.p.result at)  ~[leaf+"decimal origin lost its literal site"]
  ~
++  test-local
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ outer |= x=@t' '  ++ make |= y=@t 1' '  ^- @u (make x)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"later context did not fix local decimal"]
  =/  outer=(unit ischeme:jibb)  (ienv-lookup:jibb %outer env.u.checked)
  ?~  outer  ~[leaf+"local-number gate missing"]
  ?.  ?=([%fn [%atom %t] [%atom %u]] typ.u.outer)
    ~[leaf+"local-number type differs" leaf+(show-itype:jibb typ.u.outer ~)]
  ~
++  test-scheme-numeric-constraint
  ^-  tang
  =/  scheme=ischeme:jibb  [[%fn [%nvar 0] [%nvar 0]] ~[0] ~]
  =/  state=istate:jibb  *istate:jibb
  =/  fresh-unit=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb scheme state)
  ?~  fresh-unit  ~[leaf+"scheme instantiation failed"]
  =/  fresh=[typ=itype:jibb state=istate:jibb]  u.fresh-unit
  ?.  ?=([%fn [%nvar *] [%nvar *]] typ.fresh)
    ~[leaf+"numeric scheme lost its permitted-aura constraint"]
  =/  renamed=itype:jibb  (canonical-itype:jibb typ.scheme vars.scheme)
  ?.  ?=([%fn [%nvar *] [%nvar *]] renamed)
    ~[leaf+"canonical numeric scheme lost its permitted-aura constraint"]
  =/  restricted=ischeme:jibb  [[%fn [%rnvar 0] [%rnvar 0]] ~[0] ~]
  =/  other-unit=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb restricted state)
  ?~  other-unit  ~[leaf+"scheme instantiation failed"]
  =/  other=[typ=itype:jibb state=istate:jibb]  u.other-unit
  ?.  ?=([%fn [%rnvar *] [%rnvar *]] typ.other)
    ~[leaf+"restricted numeric constraint was lost"]
  =/  intersect=ischeme:jibb  [[%fn [%nvar 0] [%rvar 0]] ~[0] ~]
  =/  both-unit=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb intersect state)
  ?~  both-unit  ~[leaf+"scheme instantiation failed"]
  =/  both=[typ=itype:jibb state=istate:jibb]  u.both-unit
  ?.  ?=([%fn [%rnvar *] [%rnvar *]] typ.both)
    ~[leaf+"numeric and arithmetic constraint intersection was lost"]
  ?^  (itype-unify:jibb sample.typ.fresh [%atom %dr] ~)
    ~[leaf+"numeric scheme admitted a duration aura"]
  ?~  (itype-unify:jibb sample.typ.fresh [%atom %u] ~)
    ~[leaf+"numeric scheme rejected an unsigned aura"]
  ~
++  test-sample-polymorphism
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ choose |= [x=? y]' '  ?- x' '    %.y y' '    %.n 1' '++ as-ship (choose %.y ~zod)' '++ as-duration (choose %.y ~s5)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"sample-linked decimal was not generalized"]
  =/  choose=(unit ischeme:jibb)  (ienv-lookup:jibb %choose env.u.checked)
  ?~  choose  ~[leaf+"sample-linked decimal gate missing"]
  ?~  vars.u.choose  ~[leaf+"sample-linked decimal became monomorphic"]
  =/  display=(unit itype:jibb)  (scheme-display-type:jibb u.choose)
  ?~  display  ~[leaf+"generic exported scheme failed display"]
  ?.  =((show-itype:jibb u.display ~) "$-([x=? y=B] B)")
    ~[leaf+"generic exported scheme differs" leaf+(show-itype:jibb u.display ~)]
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %as-ship env.u.checked)
  =/  duration=(unit ischeme:jibb)  (ienv-lookup:jibb %as-duration env.u.checked)
  ?~  ship  ~[leaf+"ship instantiation missing"]
  ?~  duration  ~[leaf+"duration instantiation missing"]
  ?.  ?=([%atom %p] typ.u.ship)  ~[leaf+"ship instantiation lost its aura"]
  ?.  ?=([%atom %dr] typ.u.duration)  ~[leaf+"duration instantiation lost its aura"]
  =/  fresh-unit=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb u.choose *istate:jibb)
  ?~  fresh-unit  ~[leaf+"scheme instantiation failed"]
  =/  fresh=[typ=itype:jibb state=istate:jibb]  u.fresh-unit
  ?.  ?=(%fn -.typ.fresh)
    ~[leaf+"generic conditional did not export a gate"]
  =/  resolved=(unit isub:jibb)  (itype-unify:jibb product.typ.fresh [%atom %dr] sub.state.fresh)
  ?~  resolved
    ~[leaf+"generic sample-linked decimal rejected a duration aura" leaf+(show-itype:jibb typ.fresh ~)]
  =/  sample=itype:jibb  (itype-normalize:jibb sample.typ.fresh u.resolved)
  ?.  =((show-itype:jibb sample ~) "[x=? y=@dr]")
    ~[leaf+"generic sample interface rendered incorrectly" leaf+(show-itype:jibb sample ~)]
  ?.  |(?=([%cell * [%face %y [%atom %dr]]] sample) ?=([%cell * [%slot %y [%atom %dr]]] sample))
    ~[leaf+"duration did not reach the generic sample" leaf+(show-itype:jibb sample ~)]
  ~
++  test-recursive-product
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ first |= x=?' '  ?- x' '    %.y 1' '    %.n (second x)' '++ second |= x=? (first x)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"recursive product-only decimal did not default"]
  =/  first=(unit ischeme:jibb)  (ienv-lookup:jibb %first env.u.checked)
  =/  second=(unit ischeme:jibb)  (ienv-lookup:jibb %second env.u.checked)
  ?~  first  ~[leaf+"first recursive gate missing"]
  ?~  second  ~[leaf+"second recursive gate missing"]
  ?.  ?=([%fn [%flag ~] [%atom %ud]] typ.u.first)  ~[leaf+"first recursive gate has wrong result"]
  ?.  ?=([%fn [%flag ~] [%atom %ud]] typ.u.second)  ~[leaf+"second recursive gate has wrong result"]
  ~
++  test-recursive-sample
  ^-  tang
  =/  src=@t
    (of-wain:format ~['++ first |= [x=? y]' '  ?- x' '    %.y y' '    %.n (second x y)' '++ second |= [x=? y]' '  ?- x' '    %.y 1' '    %.n (first x y)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"recursive sample-linked decimal did not generalize"]
  =/  first=(unit ischeme:jibb)  (ienv-lookup:jibb %first env.u.checked)
  ?~  first  ~[leaf+"first recursive generic gate missing"]
  ?~  vars.u.first  ~[leaf+"recursive sample was defaulted prematurely"]
  =/  fresh-unit=(unit [typ=itype:jibb state=istate:jibb])  (instantiate-scheme:jibb u.first *istate:jibb)
  ?~  fresh-unit  ~[leaf+"scheme instantiation failed"]
  =/  fresh=[typ=itype:jibb state=istate:jibb]  u.fresh-unit
  ?.  ?=(%fn -.typ.fresh)  ~[leaf+"recursive generic is not a gate"]
  =/  resolved=(unit isub:jibb)  (itype-unify:jibb product.typ.fresh [%atom %dr] sub.state.fresh)
  ?~  resolved  ~[leaf+"recursive generic rejected duration aura"]
  =/  sample=itype:jibb  (itype-normalize:jibb sample.typ.fresh u.resolved)
  ?.  =((show-itype:jibb sample ~) "[x=? y=@dr]")
    ~[leaf+"generic sample interface rendered incorrectly" leaf+(show-itype:jibb sample ~)]
  ?.  |(?=([%cell * [%face %y [%atom %dr]]] sample) ?=([%cell * [%slot %y [%atom %dr]]] sample))
    ~[leaf+"recursive sample lost the shared aura" leaf+(show-itype:jibb sample ~)]
  ~
++  test-default
  ^-  tang
  =/  src=@t  (of-wain:format ~['++ make |= x=@t 1'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"product-only decimal did not default"]
  =/  make=(unit ischeme:jibb)  (ienv-lookup:jibb %make env.u.checked)
  ?~  make  ~[leaf+"defaulted gate missing"]
  ?.  ?=([%fn [%atom %t] [%atom %ud]] typ.u.make)
    ~[leaf+"defaulted gate has the wrong type" leaf+(show-itype:jibb typ.u.make ~)]
  ~
++  test-later
  ^-  tang
  =/  src=@t  (of-wain:format ~['++ make |= x=@t 1' '++ use |= x=@t ^- @u (make x)'])
  =/  checked=(unit iresolved:jibb)  (core src)
  ?~  checked  ~[leaf+"later context did not fix product decimal"]
  =/  make=(unit ischeme:jibb)  (ienv-lookup:jibb %make env.u.checked)
  ?~  make  ~[leaf+"later-context gate missing"]
  ?.  ?=([%fn [%atom %t] [%atom %u]] typ.u.make)
    ~[leaf+"later context was lost" leaf+(show-itype:jibb typ.u.make ~)]
  =/  wrong=@t  (of-wain:format ~['++ make |= x=@t 1' '++ use |= x=@t ^- @dr (make x)'])
  ?^  (core wrong)  ~[leaf+"a decimal fit an incompatible duration aura"]
  ~
--
