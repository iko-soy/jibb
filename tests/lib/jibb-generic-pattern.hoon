/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  tree  %txt  /tests/type-generic-construction/tree/txt
/*  alias  %txt  /tests/type-generic-construction/alias/txt
/*  tree-no-event  %txt  /tests/type-generic-construction/tree-no-event/txt
/*  client  %txt  /tests/type-generic-pattern/client/txt
/*  no-event  %txt  /tests/type-generic-pattern/no-event/txt
/*  owner  %txt  /tests/type-generic-pattern/owner/txt
/*  owner-bad  %txt  /tests/type-generic-pattern/owner-bad/txt
/*  values  %txt  /tests/type-generic-pattern/values/txt
|%
++  source
  |=  lines=(list @t)
  ^-  @t
  (of-wain:format lines)
++  starts
  |=  [line=@t prefix=@t]
  ^-  ?
  =((scag (lent (trip prefix)) (trip line)) (trip prefix))
++  block-tail
  |=  lines=wain
  ^-  wain
  ?~  lines  ~
  ?:  (starts i.lines '++ ')  ~
  [i.lines $(lines t.lines)]
++  block
  |=  [lines=wain name=@t]
  ^-  (unit wain)
  ?~  lines  ~
  =/  prefix=@t  (crip "++ {(trip name)} ")
  ?:  (starts i.lines prefix)  `[i.lines (block-tail t.lines)]
  $(lines t.lines)
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  check-cases
  |=  [prepared=iprelude:jibb cases=(list [name=@t expected=@t]) lines=wain modules=jbundle:jibb]
  ^-  tang
  ?~  cases  ~
  =/  definition=(unit wain)  (block lines name.i.cases)
  ?~  definition  [leaf+(weld "missing fixture " (trip name.i.cases)) $(cases t.cases)]
  =/  extra=wain
    ?:  =('polymorphic-match' name.i.cases)
      ~['++ polymorphic-source ^- (node-tree.first A) [%text value="source"]']
    ~
  =/  input=@t
    (source (weld ~['/= first /ui/tree' '/= second /ui/tree-two' '/= via /ui/tree-alias'] (weld extra u.definition)))
  =/  file=path  /tests/tree/client/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file input ~ ~ modules ~[file] values.prepared molds.prepared ~ `iface.prepared)
  =/  error=(unit tape)
    ?:  =('OK' expected.i.cases)
      ?:  ?=(%| -.result)  `(trip message.p.result)
      ~
    ?:  ?=(%& -.result)  `"invalid case was accepted"
    ?:  =('REJECT' expected.i.cases)  ~
    ?.  (contains (trip message.p.result) (trip expected.i.cases))
      `(weld "wrong diagnostic: " (trip message.p.result))
    ~
  ?~  error  $(cases t.cases)
  [leaf+(weld (trip name.i.cases) (weld ": " u.error)) $(cases t.cases)]
++  test-recursive-pattern-cases
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb (source tree)] [/ui/tree-two/jibb (source tree)] [/ui/tree-alias/jibb (source alias)]]
  =/  cases=(list [name=@t expected=@t])
    :~  ['describe' 'OK']
        ['reverse' 'OK']
        ['generic-children' 'OK']
        ['alias-children' 'OK']
        ['rebuild' 'OK']
        ['wild' 'OK']
        ['whole-wild' 'OK']
        ['nested-child' 'OK']
        ['grouped' 'OK']
        ['called' 'OK']
        ['single-wild' 'OK']
        ['single-bind' 'OK']
        ['polymorphic-source' 'OK']
        ['all' 'OK']
        ['catch-tail' 'OK']
        ['nominal-result' 'OK']
        ['nominal-context' 'OK']
        ['called-all' 'OK']
        ['called-context' 'OK']
        ['called-nominal' 'OK']
        ['wrong-return' 'incompatible types']
        ['duplicate' 'covered']
        ['missing' 'missing match case']
        ['shadow' 'shadows']
        ['bad-tag' 'unreachable pattern']
        ['whole-tail' 'incompatible']
        ['unknown' 'REJECT']
        ['forbidden-bind' 'incompatible']
        ['pending' 'nothing fixes']
        ['dead' 'covered']
        ['foreign-children' 'does not fit']
        ['wrong-argument' 'does not fit']
        ['duplicate-binder' 'shadows']
        ['target-shadow' 'shadows']
        ['missing-context' 'missing match case']
        ['missing-node' 'missing match case']
        ['polymorphic-match' 'missing match case']
        ['catch-first-dead' 'covered']
        ['late-dead' 'covered']
        ['duplicate-third' 'covered']
        ['missing-again' 'missing match case']
        ['catch-pending' 'nothing fixes']
        ['called-missing' 'missing match case']
    ==
  (check-cases u.prep cases client modules)
++  test-recursive-pattern-owner
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/tree/jibb
  =/  good=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner) ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.good)  ~[leaf+(trip message.p.good)]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner-bad) ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.bad)  ~[leaf+"duplicate binder was accepted"]
  ~
++  test-recursive-pattern-no-event
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  modules=jbundle:jibb
    ~[[/ui/tree/jibb (source tree-no-event)] [/ui/tree-two/jibb (source tree-no-event)] [/ui/tree-alias/jibb (source alias)]]
  =/  cases=(list [name=@t expected=@t])
    :~  ['words' 'OK']
        ['children' 'OK']
        ['duplicate' 'covered']
        ['nested-pattern' 'missing match case']
    ==
  (check-cases u.prep cases no-event modules)
++  test-recursive-pattern-retry
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/tree/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner) ~ ~ ~ ~[file] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  =/  template=(unit ischeme:jibb)  (find-jibb-mold:jibb %node-tree iface.p.checked)
  ?~  template  ~[leaf+"recursive pattern mold missing"]
  =/  target=(unit itype:jibb)  (template-apply:jibb u.template ~[[%atom %t]])
  ?~  target  ~[leaf+"recursive pattern mold did not instantiate"]
  ?^  (coverage-type:jibb u.target ~ [0 ~ ~] 0)  ~[leaf+"coverage ignored exhausted fuel"]
  ?~  (coverage-type:jibb u.target ~ [0 ~ ~] 4.096)  ~[leaf+"recursive coverage did not unfold"]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/tree/values/jibb (source values))
  ?:  ?=(%| -.parsed)  ~[leaf+"pattern fixture did not parse"]
  ?~  defs.p.parsed  ~[leaf+"pattern fixture is empty"]
  =/  first=def:jibb  i.defs.p.parsed
  ?.  ?=(%value -.first)  ~[leaf+"pattern fixture definition missing"]
  =/  env=ienv:jibb  ~[[%x [u.target ~ ~]]]
  =/  tag=ipending:jibb  [100 [%term %tas %unrelated '%unrelated'] *span:jibb]
  =/  projection=iwprojection:jibb  *iwprojection:jibb
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 201, prelude `iface.u.prep, tags ~[tag], holes ~[[99 (span-of:jibb val.first)]], projections ~[projection])
  =/  one=iresult:jibb  (infer-fragment:jibb val.first env state)
  =/  two=iresult:jibb  (infer-fragment:jibb val.first env state)
  ?:  ?=(%| -.one)  ~[leaf+"recursive pattern did not infer"]
  ?.  =(one two)  ~[leaf+"same-state pattern retry changed its result"]
  ?.  (lien tags.state.p.one |=(entry=ipending:jibb =(entry tag)))  ~[leaf+"pending tag was lost"]
  ?.  =(holes.state holes.state.p.one)  ~[leaf+"pending hole was lost"]
  ?.  =(projections.state projections.state.p.one)  ~[leaf+"projection evidence was lost"]
  ~
--
