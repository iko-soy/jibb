::  /lib/jibb-lower.hoon: checked Jibb tree to Core lowering and linking
::
::  This library never parses source or invokes inference or coverage.  Every
::  name, axis, recursive group, match row, and projection comes from the
::  checked-module artifact produced by /lib/jibb.hoon.
::
::  Public API:
::    +lower-checked-module  checked-module:jibb       (each module:jibb-core @t)
::    +link-entry           [term checked cache]      (each expr:jibb-core @t)
::    +link-checked-entry   [entry checked cache]     (each expr:jibb-core @t)
::    +link-module-value    [path checked cache]      (each expr:jibb-core @t)
::    +link-render-entry    [term checked cache]      render-only element origins
::
/+  jibb, jibb-core
|%
+$  lowering-state  [root=checked-module:jibb next=@ud render=?]
+$  lowered  (each [value=expr:jibb-core state=lowering-state] @t)
+$  entry
  $%  [%definition at=path name=term]
      [%module at=path]
  ==
+$  linked-definition  [at=path name=term value=expr:jibb-core order=@ud]
+$  linked-node  [at=path members=(list term) definitions=(list linked-definition)]
+$  link-reference  [at=path name=term]
+$  link-state
  [root=checked-module:jibb cache=jlowering-cache:jibb reachable=(list linked-definition) lowered=(list [at=path value=module:jibb-core]) render=?]
+$  decision-pattern  [cov=pattern:coverage:jibb src=(unit pattern:jibb)]
+$  decision-row  [arm=@ud pats=(list decision-pattern)]
+$  decision-column  [value=expr:jibb-core domain=domain:coverage:jibb]
::
++  fail
  |=  [message=tape at=(unit span:jibb)]
  ^-  @t
  ?~  at  (crip message)
  (crip "{message} at {(scow %ud line.beg.u.at)}:{(scow %ud col.beg.u.at)}")
::
++  occurrence-id
  |=  e=expr:jibb
  ^-  lowering-occurrence-id:jibb
  [(span-of:jibb e) %expression]
::
++  find-occurrence
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-occurrence:jibb)
  ?~  occurrences.root  ~
  ?:  =(id id.i.occurrences.root)  `i.occurrences.root
  $(occurrences.root t.occurrences.root)
::
++  find-reference
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-reference:jibb)
  ?~  references.root  ~
  ?:  =(id id.i.references.root)  `i.references.root
  $(references.root t.references.root)
::
++  find-wing
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-wing:jibb)
  ?~  wings.root  ~
  ?:  =(id id.i.wings.root)  `i.wings.root
  $(wings.root t.wings.root)
::
++  find-edit
  |=  [at=span:jibb names=(list term) root=checked-module:jibb]
  ^-  (unit lowering-edit:jibb)
  ?~  edits.root  ~
  ?:  &(=(at at.i.edits.root) =(names names.i.edits.root))  `i.edits.root
  $(edits.root t.edits.root)
::
++  find-binder
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-binder:jibb)
  ?~  binders.root  ~
  ?:  =(id id.i.binders.root)  `i.binders.root
  $(binders.root t.binders.root)
::
++  find-match
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-match:jibb)
  ?~  matches.root  ~
  ?:  =(id id.i.matches.root)  `i.matches.root
  $(matches.root t.matches.root)
::
++  find-projection
  |=  [id=lowering-occurrence-id:jibb root=checked-module:jibb]
  ^-  (unit lowering-projection:jibb)
  ?~  projections.root  ~
  ?:  =(id id.i.projections.root)  `i.projections.root
  $(projections.root t.projections.root)
::
++  fresh
  |=  state=lowering-state
  ^-  [name:jibb-core lowering-state]
  =/  n=@t  (cat 3 '_' (scot %ud next.state))
  [[%generated n] state(next +(next.state))]
::
++  null
  ^-  expr:jibb-core
  [%lit [%n 0 '~']]
::
++  literal
  |=  lit=lit:jibb
  ^-  expr:jibb-core
  [%lit [aura.lit val.lit txt.lit]]
::
++  term-literal
  |=  name=term
  ^-  expr:jibb-core
  [%lit [%tas name (cat 3 '%' name)]]
::
++  hex-digit
  |=  n=@ud
  ^-  @t
  ?:  (lth n 10)  (crip ~[(add '0' n)])
  (crip ~[(add 'a' (sub n 10))])
::
++  escaped-string-pieces
  |=  cs=tape
  ^-  (list @t)
  ?~  cs  ~
  =/  c=@  i.cs
  =/  first=@t
    ?:  |(=('\\' c) =('"' c) =('{' c))  (cat 3 '\\' (crip ~[c]))
    ?:  |((lth c 32) =(127 c))
      (rap 3 ~['\\' (hex-digit (div c 16)) (hex-digit (mod c 16))])
    (crip ~[c])
  [first $(cs t.cs)]
::
++  string-literal
  |=  text=@t
  ^-  expr:jibb-core
  =/  txt=@t  (rap 3 ~['"' (rap 3 (escaped-string-pieces (trip text))) '"'])
  [%lit [%t text txt]]
::
++  knot-literal
  |=  knot=@ta
  ^-  expr:jibb-core
  [%lit [%ta knot (cat 3 '~.' knot)]]
::
++  make-slot
  |=  [axis=@ body=expr:jibb-core]
  ^-  expr:jibb-core
  ?:  =(0 axis)  [%slot 0 body]
  ?:  =(1 axis)  body
  ?:  ?=(%slot -.body)  [%slot (peg axis.body axis) body.body]
  [%slot axis body]
::
++  make-if
  |=  [test=expr:jibb-core yes=expr:jibb-core no=expr:jibb-core]
  ^-  expr:jibb-core
  ?:  ?=([%lit [%f *]] test)
    ?:  =(0 val.lit.test)  yes
    ?:  =(1 val.lit.test)  no
    [%if test yes no]
  [%if test yes no]
::
++  make-app
  |=  [fun=expr:jibb-core sample=expr:jibb-core]
  ^-  expr:jibb-core
  ?:  ?=(%lam -.fun)  [%let sample.fun sample body.fun]
  [%app fun sample]
::
++  make-cons-list
  |=  items=(list expr:jibb-core)
  ^-  expr:jibb-core
  ?~  items  null
  [%cons i.items $(items t.items)]
::
++  make-arguments
  |=  items=(list expr:jibb-core)
  ^-  (unit expr:jibb-core)
  ?~  items  ~
  ?~  t.items  `i.items
  `[%cons i.items (need $(items t.items))]
::
++  compose-steps
  |=  steps=(list iwstep:jibb)
  ^-  (unit @)
  ?~  steps  ~
  =/  axis=@  axis.i.steps
  |-
  ?~  t.steps  `axis
  $(t.steps t.t.steps, axis (peg axis axis.i.t.steps))
::
++  core-path
  |=  at=path
  ^-  path
  =/  no-ext=(list @ta)  (scag (dec (lent at)) at)
  ?~  no-ext  at
  ?:  ?=(%ui i.no-ext)  t.no-ext
  no-ext
::
++  definition-name-as
  |=  [definition=lowering-definition:jibb name=term]
  ^-  name:jibb-core
  ?-  -.definition
    %local    [%own name]
    %own      [%own name]
    %prelude  [%own name]
    %import   [%qualified (core-path at.definition) name]
    %module   [%qualified (core-path at.definition) %$]
  ==
::
++  definition-name
  |=  d=lowering-definition:jibb
  ^-  name:jibb-core
  ?-  -.d
    %local    (definition-name-as d name.d)
    %own      (definition-name-as d name.d)
    %prelude  (definition-name-as d name.d)
    %import   (definition-name-as d name.d)
    %module   (definition-name-as d %$)
  ==
++  lower-module-reference
  |=  [names=(list term) at=path]
  ^-  (each expr:jibb-core @t)
  ?~  names  [%| 'cannot lower an empty whole-module reference']
  =/  remaining=(list term)  names
  |-
  ?~  remaining  [%| 'cannot lower an empty whole-module reference']
  =/  value=expr:jibb-core
    [%var [%qualified (core-path at) i.remaining]]
  ?~  t.remaining  [%& value]
  =/  rest=(each expr:jibb-core @t)  $(remaining t.remaining)
  ?:  ?=(%| -.rest)  rest
  [%& [%cons value p.rest]]
++  native-print
  |=  [aura=@ta value=expr:jibb-core]
  ^-  expr:jibb-core
  [%app [%native [%own %scot]] [%cons (term-literal aura) value]]
++  lower-pure
  |=  state=lowering-state
  ^-  lowered
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  sample=expr:jibb-core  [%var -.made]
  [%& [[%lam -.made [%cons (term-literal %pure) sample]] +.made]]
++  lower-poke
  |=  [at=path agent=term mark=term state=lowering-state]
  ^-  lowered
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  sample=expr:jibb-core  [%var -.made]
  =/  raw=expr:jibb-core
    [%cons (term-literal %agent) [%cons (term-literal agent) [%cons (term-literal mark) sample]]]
  [%& [[%lam -.made raw] +.made]]
++  sample-variables
  |=  [count=@ud axis=@ sample=expr:jibb-core]
  ^-  (list expr:jibb-core)
  ?:  =(0 count)  ~
  ?:  =(1 count)  ~[(make-slot axis sample)]
  :-  (make-slot (mul 2 axis) sample)
  $(count (dec count), axis +((mul 2 axis)))
++  request-variable
  |=  [name=term names=(list iapi-parameter:jibb) vars=(list expr:jibb-core)]
  ^-  (unit expr:jibb-core)
  ?~  names  ~
  ?~  vars  ~
  ?:  =(name name.i.names)  `i.vars
  $(names t.names, vars t.vars)
++  raw-path-aura
  |=  aura=@ta
  ^-  ?
  ?|(=(%ta aura) =(%tas aura))
::
++  lower-request-path
  |=  [segs=(list pseg:jibb) params=(list iapi-parameter:jibb) vars=(list expr:jibb-core) state=lowering-state]
  ^-  lowered
  ?~  segs  [%& [null state]]
  =/  first=lowered
    ?-  -.i.segs
      %knot      [%& [(knot-literal p.i.segs) state]]
      %inferred  [%| 'derived request contains an unresolved path hole']
      %typed
        =/  found=(unit expr:jibb-core)
          (request-variable name.i.segs params vars)
        ?~  found  [%| (fail "derived request lost a checked path parameter" `at.i.segs)]
        ?:  (raw-path-aura aura.i.segs)  [%& [u.found state]]
        ?.  (lien natives.root.state |=(n=term =(%scot n)))
          [%| (fail "derived request printer native ID is unavailable" `at.i.segs)]
        [%& [(native-print aura.i.segs u.found) state]]
    ==
  ?:  ?=(%| -.first)  first
  =/  rest=lowered  $(segs t.segs, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[%cons value.p.first value.p.rest] state.p.rest]]
++  lower-request
  |=  [evidence=irequest-evidence:jibb state=lowering-state]
  ^-  lowered
  =/  params=(unit (list iapi-parameter:jibb))
    (api-path-parameters:jibb segments.path.path.evidence ~)
  ?~  params  [%| 'derived request path parameters are not checked']
  =/  diffs=(list iapi-mark-type:jibb)  diffs.path.evidence
  =/  fold=?  ?=(^ diffs)
  =/  count=@ud  (add 1 (add (lent u.params) ?:(fold 1 0)))
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  sample=expr:jibb-core  [%var -.made]
  =/  vars=(list expr:jibb-core)  (sample-variables count 1 sample)
  =/  path=lowered  (lower-request-path segments.path.path.evidence u.params vars state.made)
  ?:  ?=(%| -.path)  path
  =/  scry=lowered
    ?~  scry.path.path.evidence  [%& [null state.p.path]]
    =/  built=lowered
      (lower-request-path u.scry.path.path.evidence u.params vars state.p.path)
    ?:  ?=(%| -.built)  built
    [%& [[%cons null value.p.built] state.p.built]]
  ?:  ?=(%| -.scry)  scry
  =/  reply=expr:jibb-core  (snag (lent u.params) vars)
  =/  receive-made=[name=name:jibb-core state=lowering-state]
    (fresh state.p.scry)
  =/  input=expr:jibb-core  [%var -.receive-made]
  =/  fact=expr:jibb-core  (make-slot 7 input)
  ::  Generated names are numbered, as the JavaScript Core reader requires.
  =/  fact-made=[name=name:jibb-core state=lowering-state]  (fresh +.receive-made)
  =/  state-made=[name=name:jibb-core state=lowering-state]  (fresh +.fact-made)
  =/  next-made=[name=name:jibb-core state=lowering-state]  (fresh +.state-made)
  =/  fact-var=expr:jibb-core  [%var -.fact-made]
  =/  state-var=expr:jibb-core  [%var -.state-made]
  ::  A fact is checked against its type before a typed reply or fold sees
  ::  it: the first against full state, each later one against the diff its
  ::  mark names, which the fold receives tagged with that mark.
  =/  full=lowered  (check-noun full.path.evidence fact-var +.next-made)
  ?:  ?=(%| -.full)  full
  =/  full-made=[name=name:jibb-core state=lowering-state]  (fresh state.p.full)
  =/  receive-body=lowered
    ?.  fold
      :+  %&
        :^  %let  -.fact-made  fact
        [%let -.full-made value.p.full [%cons fact-var [%app reply fact-var]]]
      +.full-made
    =/  current=expr:jibb-core  (make-slot 6 input)
    =/  mark=expr:jibb-core  (make-slot 2 input)
    =/  next=expr:jibb-core  [%var -.next-made]
    =/  diff=lowered  (check-diff diffs mark fact-var +.full-made)
    ?:  ?=(%| -.diff)  diff
    =/  diff-made=[name=name:jibb-core state=lowering-state]  (fresh state.p.diff)
    =/  folded=expr:jibb-core
      =/  fold-var=expr:jibb-core  (snag (add 1 (lent u.params)) vars)
      :^  %let  -.diff-made  value.p.diff
      [%app fold-var [%cons [%cons mark fact-var] (make-slot 3 state-var)]]
    =/  first=expr:jibb-core  [%let -.full-made value.p.full fact-var]
    :+  %&
      :^  %let  -.fact-made  fact
      :^  %let  -.state-made  current
      :^  %let  -.next-made
        [%if [%cell state-var] folded first]
      [%cons next [%app reply next]]
    +.diff-made
  ?:  ?=(%| -.receive-body)  receive-body
  =/  receive=expr:jibb-core  [%lam -.receive-made value.p.receive-body]
  =/  api=@t  (crip (spud (core-path api-at.evidence)))
  =/  agent=term  (snag 2 api-at.evidence)
  =/  fields=(list expr:jibb-core)
    :~  (term-literal %agent)
        (string-literal api)
        (term-literal name.path.path.evidence)
        (term-literal agent)
        value.p.path
        value.p.scry
        receive
    ==
  =/  body=(unit expr:jibb-core)  (make-arguments fields)
  ?~  body  [%| 'derived request lost its checked payload fields']
  [%& [[%lam -.made u.body] state.p.receive-body]]
::
::  Facts and scried state arrive from agents as untyped nouns.  +check-noun
::  makes an expression that is ~ when value, a pure expression, fits the
::  type, as a Hoon clam would check it, and crashes otherwise; a map or
::  set's order is not checked.  A type that cannot arrive in a fact, such
::  as a gate, and one not checked yet, such as a recursive mold, fail
::  closed at lowering.
++  check-zero  ^-  expr:jibb-core  [%lit [%ud 0 '0']]
++  check-one  ^-  expr:jibb-core  [%lit [%ud 1 '1']]
++  check-both
  |=  [first=expr:jibb-core second=expr:jibb-core state=lowering-state]
  ^-  [expr:jibb-core lowering-state]
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  [[%let -.made first second] +.made]
++  check-unsupported
  |=  [typ=itype:jibb why=tape]
  ^-  lowered
  [%| (crip "a fact of type {(show-itype:jibb typ ~)} cannot be checked yet: {why}")]
++  check-noun
  |=  [typ=itype:jibb value=expr:jibb-core state=lowering-state]
  ^-  lowered
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %noun           [%& [null state]]
    %empty          [%& [[%crash ~] state]]
    ?(%atom %any-atom)  [%& [[%if [%cell value] [%crash ~] null] state]]
    %flag
      =/  bit=expr:jibb-core
        [%if [%eq value check-zero] null [%if [%eq value check-one] null [%crash ~]]]
      [%& [[%if [%cell value] [%crash ~] bit] state]]
    %const  [%& [[%if [%eq value (literal literal.typ)] null [%crash ~]] state]]
    %tag    [%& [[%if [%eq value (literal literal.typ)] null [%crash ~]] state]]
    %cell
      =/  hed=lowered  $(typ hed.typ, value (make-slot 2 value))
      ?:  ?=(%| -.hed)  hed
      =/  tal=lowered  $(typ tal.typ, value (make-slot 3 value), state state.p.hed)
      ?:  ?=(%| -.tal)  tal
      =/  both=[expr:jibb-core lowering-state]  (check-both value.p.hed value.p.tal state.p.tal)
      [%& [[%if [%cell value] -.both [%crash ~]] +.both]]
    %union          (check-union cases.typ value state)
    %collection     (check-collection typ value state)
    %fn             (check-unsupported typ "a gate cannot arrive in a fact")
    %opaque         (check-unsupported typ "its representation is private")
    ?(%recursive %mrec)  (check-unsupported typ "recursive molds are not checked yet")
    ?(%var %fvar %avar %rvar %nvar %rnvar %refined)
      (check-unsupported typ "its type is not closed")
  ==
::
::  A list, unit, set or map is checked by a recursive arm over its nodes.
++  check-collection
  |=  [typ=itype:jibb value=expr:jibb-core state=lowering-state]
  ^-  lowered
  ?>  ?=(%collection -.typ)
  =/  args=(list itype:jibb)  args.typ
  ?:  &(=(%unit name.typ) ?=([* ~] args))
    =/  item=lowered  (check-noun i.args (make-slot 3 value) state)
    ?:  ?=(%| -.item)  item
    =/  some=expr:jibb-core
      [%if [%eq (make-slot 2 value) null] value.p.item [%crash ~]]
    [%& [[%if [%cell value] some [%if [%eq value null] null [%crash ~]]] state.p.item]]
  ?:  &(=(%list name.typ) ?=([* ~] args))
    (check-tree i.args value ~[2] ~[3] state)
  ?:  &(=(%set name.typ) ?=([* ~] args))
    (check-tree i.args value ~[2] ~[6 7] state)
  ?:  &(=(%map name.typ) ?=([* * ~] args))
    (check-tree [%cell i.args i.t.args] value ~[2] ~[6 7] state)
  (check-unsupported typ "only lists, units, sets and maps are checked")
::
::  +check-tree: a recursive arm checking each node's item at the axes in
::  items and recurring at the axes in rest; ~ ends a branch
++  check-tree
  |=  [item=itype:jibb value=expr:jibb-core items=(list @) rest=(list @) state=lowering-state]
  ^-  lowered
  =/  self=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  node=[name=name:jibb-core state=lowering-state]  (fresh +.self)
  =/  at=expr:jibb-core  [%var -.node]
  =/  checks=(list expr:jibb-core)  ~
  =/  next=lowering-state  +.node
  |-
  ?^  items
    =/  one=lowered  (check-noun item (make-slot i.items at) next)
    ?:  ?=(%| -.one)  one
    $(items t.items, checks [value.p.one checks], next state.p.one)
  ?^  rest
    $(rest t.rest, checks [[%app [%var -.self] (make-slot i.rest at)] checks])
  =/  body=[expr:jibb-core lowering-state]
    =/  ordered=(list expr:jibb-core)  (flop checks)
    ?~  ordered  [null next]
    =/  out=expr:jibb-core  i.ordered
    =/  more=(list expr:jibb-core)  t.ordered
    |-
    ?~  more  [out next]
    =/  joined=[expr:jibb-core lowering-state]  (check-both out i.more next)
    $(more t.more, out -.joined, next +.joined)
  =/  arm=expr:jibb-core
    [%lam -.node [%if [%cell at] -.body [%if [%eq at null] null [%crash ~]]]]
  [%& [[%rec ~[[-.self arm]] [%app [%var -.self] value]] +.body]]
::
::  A union's cases differ as nouns.  Constants and cells headed by one are
::  told apart by those constants; what remains is one case, checked as
::  itself, or an atom case and a cell case, told apart by shape.
++  check-union
  |=  [cases=(list itype:jibb) value=expr:jibb-core state=lowering-state]
  ^-  lowered
  =/  bare=(list itype:jibb)  (turn cases check-unface)
  =/  tagged=(list [test=expr:jibb-core typ=itype:jibb])
    %+  murn  bare
    |=  c=itype:jibb
    =/  whole=(unit lit:jibb)  (check-constant c)
    ?^  whole  `[[%eq value (literal u.whole)] c]
    ?.  ?=(%cell -.c)  ~
    =/  head=(unit lit:jibb)  (check-constant (check-unface hed.c))
    ?~  head  ~
    `[[%eq (make-slot 2 value) (literal u.head)] c]
  =/  others=(list itype:jibb)
    %+  skip  bare
    |=  c=itype:jibb
    ?^  (check-constant c)  &
    ?.  ?=(%cell -.c)  |
    ?=(^ (check-constant (check-unface hed.c)))
  ::  Split before any ?~: the wet +skim cannot take a refined list.
  =/  atom=(list itype:jibb)  (skim others check-atom-shaped)
  =/  cell=(list itype:jibb)  (skim others |=(c=itype:jibb ?=(%cell -.c)))
  =/  fallback=lowered
    ?:  =(~ others)  [%& [[%crash ~] state]]
    ?:  =(1 (lent others))  (check-noun (snag 0 others) value state)
    ?.  &(=(2 (lent others)) ?=([* ~] atom) ?=([* ~] cell))
      (check-unsupported [%union cases ~ ~ ~] "its cases are not told apart by shape or constant")
    =/  yes=lowered  (check-noun i.cell value state)
    ?:  ?=(%| -.yes)  yes
    =/  no=lowered  (check-noun i.atom value state.p.yes)
    ?:  ?=(%| -.no)  no
    [%& [[%if [%cell value] value.p.yes value.p.no] state.p.no]]
  ?:  ?=(%| -.fallback)  fallback
  =/  out=expr:jibb-core  value.p.fallback
  =/  next=lowering-state  state.p.fallback
  =/  rest=(list [test=expr:jibb-core typ=itype:jibb])  (flop tagged)
  |-
  ?~  rest  [%& [out next]]
  =/  case=lowered  (check-noun typ.i.rest value next)
  ?:  ?=(%| -.case)  case
  ::  A cell headed by a constant needs a cell before its head is read.
  =/  test=expr:jibb-core
    ?.  ?=(%cell -.typ.i.rest)  test.i.rest
    [%if [%cell value] test.i.rest [%lit [%f 1 '%.n']]]
  $(rest t.rest, out [%if test value.p.case out], next state.p.case)
++  check-constant
  |=  typ=itype:jibb
  ^-  (unit lit:jibb)
  ?:  ?=(%const -.typ)  `literal.typ
  ?:  ?=(%tag -.typ)  `literal.typ
  ~
++  check-unface
  |=  typ=itype:jibb
  ^-  itype:jibb
  ?:  ?=(?(%face %slot) -.typ)  $(typ body.typ)
  typ
++  check-atom-shaped
  |=  typ=itype:jibb
  ^-  ?
  ?=(?(%atom %any-atom %flag) -.typ)
::
::  A later fact's mark names its diff; another mark crashes the receiver.
++  check-diff
  |=  [diffs=(list iapi-mark-type:jibb) mark=expr:jibb-core fact=expr:jibb-core state=lowering-state]
  ^-  lowered
  ?~  diffs  [%& [[%crash ~] state]]
  =/  one=lowered  (check-noun typ.i.diffs fact state)
  ?:  ?=(%| -.one)  one
  =/  rest=lowered  $(diffs t.diffs, state state.p.one)
  ?:  ?=(%| -.rest)  rest
  :+  %&
    [%if [%eq mark (term-literal name.i.diffs)] value.p.one value.p.rest]
  state.p.rest
++  lower-store-poke
  |=  [at=path name=term state=lowering-state]
  ^-  lowered
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  sample=expr:jibb-core  [%var -.made]
  =/  action=expr:jibb-core  (make-slot 2 sample)
  =/  reply=expr:jibb-core  (make-slot 3 sample)
  =/  module=@t  (crip (slag 1 (spud (core-path at))))
  =/  raw=expr:jibb-core
    [%cons (term-literal %store) [%cons (string-literal module) [%cons (term-literal name) action]]]
  =/  body=expr:jibb-core
    [%cons (term-literal %poke) [%cons raw reply]]
  [%& [[%lam -.made body] +.made]]
::
++  lower-store-request
  |=  [evidence=istore-request-evidence:jibb state=lowering-state]
  ^-  lowered
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  reply=expr:jibb-core  [%var -.made]
  =/  receive-made=[name=name:jibb-core state=lowering-state]
    (fresh state.made)
  =/  input=expr:jibb-core  [%var -.receive-made]
  =/  fact=expr:jibb-core  (make-slot 3 input)
  ::  Generated names are numbered, as the JavaScript Core reader requires.
  =/  fact-made=[name=name:jibb-core state=lowering-state]  (fresh +.receive-made)
  =/  fact-var=expr:jibb-core  [%var -.fact-made]
  =/  receive-body=expr:jibb-core
    [%let -.fact-made fact [%cons fact-var [%app reply fact-var]]]
  =/  receive=expr:jibb-core  [%lam -.receive-made receive-body]
  =/  module=@t  (crip (slag 1 (spud (core-path store-at.evidence))))
  =/  fields=(list expr:jibb-core)
    :~  (term-literal %store)
        (string-literal module)
        (term-literal %state)
        receive
    ==
  =/  body=(unit expr:jibb-core)  (make-arguments fields)
  ?~  body  [%| 'derived store request lost its checked payload fields']
  [%& [[%lam -.made u.body] +.fact-made]]
::
++  lower-derived
  |=  [plan=lowering-derived:jibb state=lowering-state]
  ^-  lowered
  ?-  -.plan
    %poke          (lower-poke at.plan agent.plan mark.plan state)
    %request       (lower-request evidence.plan state)
    %store-poke    (lower-store-poke at.plan name.plan state)
    %store-request  (lower-store-request evidence.plan state)
  ==
++  lower-intrinsic
  |=  [name=term state=lowering-state]
  ^-  (unit lowered)
  ?:  =(%pure name)  `(lower-pure state)
  ~
::
++  derived-definition-name
  |=  [plan=lowering-derived:jibb definition=lowering-definition:jibb]
  ^-  name:jibb-core
  ?-  -.plan
    %poke          (definition-name-as definition mark.plan)
    %request       (definition-name-as definition name.path.path.evidence.plan)
    %store-poke    (definition-name-as definition name.plan)
    %store-request  (definition-name-as definition %state)
  ==
::
++  lower-command-poke
  |=  [at=path mark=term state=lowering-state]
  ^-  lowered
  =/  made=[name=name:jibb-core state=lowering-state]  (fresh state)
  =/  sample=expr:jibb-core  [%var -.made]
  =/  action=expr:jibb-core  (make-slot 2 sample)
  =/  reply=expr:jibb-core  (make-slot 3 sample)
  =/  raw=expr:jibb-core
    [%app [%var [%qualified (core-path at) mark]] action]
  =/  body=expr:jibb-core
    [%cons (term-literal %poke) [%cons raw reply]]
  [%& [[%lam -.made body] +.made]]
::
++  lower-reference
  |=  [at=span:jibb state=lowering-state]
  ^-  lowered
  =/  ref=(unit lowering-reference:jibb)  (find-reference [at %expression] root.state)
  ?~  ref  [%| (fail "missing checked value reference" `at)]
  ?^  derived.u.ref
    ?:  ?=(%poke -.u.derived.u.ref)
      ?:  ?=(%import -.definition.u.ref)
        ?:  =(%poke name.definition.u.ref)
          (lower-command-poke at.u.derived.u.ref mark.u.derived.u.ref state)
        [%& [[%var (derived-definition-name u.derived.u.ref definition.u.ref)] state]]
      [%& [[%var (derived-definition-name u.derived.u.ref definition.u.ref)] state]]
    [%& [[%var (derived-definition-name u.derived.u.ref definition.u.ref)] state]]
  ?^  intrinsic.u.ref
    =/  special=(unit lowered)  (lower-intrinsic u.intrinsic.u.ref state)
    ?~  special  [%| (fail "unknown authenticated intrinsic identity" `at)]
    u.special
  ?^  native.u.ref
    [%& [[%native [%own u.native.u.ref]] state]]
  ?:  ?=(%module -.definition.u.ref)
    =/  whole=(each expr:jibb-core @t)
      (lower-module-reference names.definition.u.ref at.definition.u.ref)
    ?:  ?=(%| -.whole)  whole
    [%& [p.whole state]]
  [%& [[%var (definition-name definition.u.ref)] state]]
::
++  lower-expressions
  |=  [es=(list expr:jibb) state=lowering-state]
  ^-  (each [values=(list expr:jibb-core) state=lowering-state] @t)
  ?~  es  [%& [~ state]]
  =/  first=lowered  (lower-expression i.es state)
  ?:  ?=(%| -.first)  first
  =/  rest=(each [values=(list expr:jibb-core) state=lowering-state] @t)
    $(es t.es, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[value.p.first values.p.rest] state.p.rest]]
::
++  lower-items
  |=  [items=(list item:jibb) state=lowering-state]
  ^-  lowered
  ?~  items  [%| 'cannot lower an empty tuple']
  =/  first=lowered  (lower-expression val.i.items state)
  ?:  ?=(%| -.first)  first
  ?~  t.items  first
  =/  rest=lowered  $(items t.items, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[%cons value.p.first value.p.rest] state.p.rest]]
::
++  lower-list
  |=  [items=(list expr:jibb) state=lowering-state]
  ^-  lowered
  ?~  items  [%& [null state]]
  =/  first=lowered  (lower-expression i.items state)
  ?:  ?=(%| -.first)  first
  =/  rest=lowered  $(items t.items, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[%cons value.p.first value.p.rest] state.p.rest]]
::
++  lower-path
  |=  [segs=(list @ta) state=lowering-state]
  ^-  lowered
  [%& [(make-cons-list (turn segs knot-literal)) state]]
::
::  The Grammar splices @t, @ta, @tas and the rest of Hoon's @t family as
::  text, and tapes once packed; other atoms print by aura.
++  atom-text-type
  |=  typ=itype:jibb
  ^-  ?
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %atom           =('t' (end 3 aura.typ))
    %const          =('t' (end 3 aura.literal.typ))
    *               |
  ==
++  tape-type
  |=  typ=itype:jibb
  ^-  ?
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %collection     &(=(%list name.typ) ?=([* ~] args.typ) (atom-text-type i.args.typ))
    *               |
  ==
++  printer-aura
  |=  typ=itype:jibb
  ^-  (unit @ta)
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %atom           `aura.typ
    %const          `aura.literal.typ
    %flag           `%f
    *               ~
  ==
::
++  lower-printed
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  =/  found=(unit lowering-occurrence:jibb)
    (find-occurrence (occurrence-id e) root.state)
  ?~  found  [%| (fail "missing checked printer occurrence" `(span-of:jibb e))]
  =/  value=lowered  (lower-expression e state)
  ?:  ?=(%| -.value)  value
  ?:  (atom-text-type typ.u.found)  value
  ?:  (tape-type typ.u.found)
    ?.  (lien natives.root.state |=(n=term =(%crip n)))
      [%| (fail "tape interpolation requires an authenticated crip native ID" `(span-of:jibb e))]
    [%& [[%app [%native [%own %crip]] value.p.value] state.p.value]]
  =/  aura=(unit @ta)  (printer-aura typ.u.found)
  ?~  aura  [%| (fail "printer native ID is unavailable for this checked type" `(span-of:jibb e))]
  ?.  (lien natives.root.state |=(n=term =(%scot n)))
    [%| (fail "printer native ID is unavailable for this checked type" `(span-of:jibb e))]
  =/  printed=expr:jibb-core  (native-print u.aura value.p.value)
  [%& [printed state.p.value]]
::
++  path-text-type
  |=  typ=itype:jibb
  ^-  ?
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %atom           (raw-path-aura aura.typ)
    %const          (raw-path-aura aura.literal.typ)
    *               |
  ==
::
++  lower-printed-path
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  =/  found=(unit lowering-occurrence:jibb)
    (find-occurrence (occurrence-id e) root.state)
  ?~  found  [%| (fail "missing checked path-printer occurrence" `(span-of:jibb e))]
  =/  value=lowered  (lower-expression e state)
  ?:  ?=(%| -.value)  value
  ?:  (path-text-type typ.u.found)  value
  =/  aura=(unit @ta)  (printer-aura typ.u.found)
  ?~  aura  [%| (fail "path-printer native ID is unavailable for this checked type" `(span-of:jibb e))]
  ?.  (lien natives.root.state |=(n=term =(%scot n)))
    [%| (fail "path-printer native ID is unavailable for this checked type" `(span-of:jibb e))]
  =/  printed=expr:jibb-core  (native-print u.aura value.p.value)
  [%& [printed state.p.value]]
::
++  lower-pieces
  |=  [pieces=(list piece:jibb) state=lowering-state]
  ^-  lowered
  ?~  pieces  [%& [null state]]
  =/  first=lowered
    ?-  -.i.pieces
      %text  [%& [(string-literal p.i.pieces) state]]
      %expr  (lower-printed p.i.pieces state)
    ==
  ?:  ?=(%| -.first)  first
  =/  rest=lowered  $(pieces t.pieces, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[%cons value.p.first value.p.rest] state.p.rest]]
::
++  lower-string
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%str -.e)
  ?~  pieces.e  [%& [(string-literal '') state]]
  ?:  ?=([[%text *] ~] pieces.e)
    [%& [(string-literal p.i.pieces.e) state]]
  =/  pieces=lowered  (lower-pieces pieces.e state)
  ?:  ?=(%| -.pieces)  pieces
  ?.  (lien natives.root.state |=(n=term =(%join n)))
    [%| (fail "interpolation requires an authenticated join native ID" `at.e)]
  =/  sample=expr:jibb-core
    [%cons (string-literal '') value.p.pieces]
  [%& [[%app [%native [%own %join]] sample] state.p.pieces]]
::
++  lower-qath
  |=  [segs=(list qseg:jibb) state=lowering-state]
  ^-  lowered
  ?~  segs  [%& [null state]]
  =/  first=lowered
    ?-  -.i.segs
      %knot  [%& [(knot-literal p.i.segs) state]]
      %expr  (lower-printed-path p.i.segs state)
    ==
  ?:  ?=(%| -.first)  first
  =/  rest=lowered  $(segs t.segs, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[%cons value.p.first value.p.rest] state.p.rest]]
::
++  lower-wing
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%wing -.e)
  =/  base=lowered  (lower-reference at.e state)
  ?:  ?=(%| -.base)  base
  =/  wing=(unit lowering-wing:jibb)  (find-wing [at.e %expression] root.state)
  ?~  wing
    =/  ref=(unit lowering-reference:jibb)  (find-reference [at.e %expression] root.state)
    ?~  ref  [%| (fail "missing checked wing reference" `at.e)]
    ?:  =(1 (lent names.e))  base
    ?:  &(?=(%import -.definition.u.ref) =(2 (lent names.e)))  base
    [%| (fail "missing checked wing axes" `at.e)]
  =/  steps=(list iwstep:jibb)  steps.u.wing
  |-
  ?~  steps  base
  $(steps t.steps, value.p.base (make-slot axis.i.steps value.p.base))
::
++  unface-call
  |=  e=expr:jibb
  ^-  (unit expr:jibb)
  ?.  ?=(%call -.e)  ~
  ?.  ?=(%wing -.head.e)  ~
  ?.  =(names.head.e ~[%unface])  ~
  ?.  ?=([* ~] args.e)  ~
  `i.args.e
::
::  An island's program is an island module's main, imported with /=: the
::  page's HTML names that module, which the browser runs.  The lowering
::  pairs the program with its module's path, which the prelude's island
::  seals unread; any other program fails closed here.
++  island-call
  |=  [e=expr:jibb root=checked-module:jibb]
  ^-  ?
  ?.  ?=(%call -.e)  |
  ?.  ?=(%wing -.head.e)  |
  =/  ref=(unit lowering-reference:jibb)  (find-reference [at.head.e %expression] root)
  ?~  ref  |
  =(definition.u.ref [%prelude /lib/jibb/prelude/jibb %island])
++  island-module
  |=  [e=expr:jibb root=checked-module:jibb]
  ^-  (unit path)
  ?.  ?=(%wing -.e)  ~
  =/  ref=(unit lowering-reference:jibb)  (find-reference [at.e %expression] root)
  ?~  ref  ~
  ?.  ?=(%import -.definition.u.ref)  ~
  ?.  =(%main name.definition.u.ref)  ~
  `at.definition.u.ref
++  lower-island-call
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%call -.e)
  ?.  ?=([* * ~] args.e)  [%| (fail "an island takes a program and its data" `at.e)]
  =/  module=(unit path)  (island-module i.args.e root.state)
  ?~  module
    =/  why=tape
      "an island's program must be the main of an island module imported with /=, as `island main.todo-list ts`"
    [%| (fail why `(span-of:jibb i.args.e))]
  =/  fun=lowered  (lower-expression head.e state)
  ?:  ?=(%| -.fun)  fun
  =/  program=lowered  (lower-expression i.args.e state.p.fun)
  ?:  ?=(%| -.program)  program
  =/  data=lowered  (lower-expression i.t.args.e state.p.program)
  ?:  ?=(%| -.data)  data
  =/  named=expr:jibb-core  [%cons (string-literal (crip (spud u.module))) value.p.program]
  [%& [(make-app value.p.fun [%cons named value.p.data]) state.p.data]]
::
++  derived-poke-call
  |=  [e=expr:jibb root=checked-module:jibb]
  ^-  (unit [at=path agent=term mark=term])
  ?.  ?=(%call -.e)  ~
  ?.  ?=(%wing -.head.e)  ~
  =/  ref=(unit lowering-reference:jibb)  (find-reference [at.head.e %expression] root)
  ?~  ref  ~
  ?~  derived.u.ref  ~
  ?.  ?=(%poke -.u.derived.u.ref)  ~
  =/  plan=[at=path agent=term mark=term]
    [at.u.derived.u.ref agent.u.derived.u.ref mark.u.derived.u.ref]
  `plan
::
++  lower-poke-call
  |=  [plan=[at=path agent=term mark=term] args=(list expr:jibb) state=lowering-state]
  ^-  lowered
  =/  values=(each [values=(list expr:jibb-core) state=lowering-state] @t)
    (lower-expressions args state)
  ?:  ?=(%| -.values)  values
  ?~  values.p.values  [%| 'derived poke expects an action and a reply']
  =/  action=expr:jibb-core  i.values.p.values
  ?~  t.values.p.values  [%| 'derived poke expects an action and a reply']
  =/  reply=expr:jibb-core  i.t.values.p.values
  ?.  ?=(~ t.t.values.p.values)  [%| 'derived poke expects an action and a reply']
  =/  raw=expr:jibb-core
    [%app [%var [%qualified (core-path at.plan) mark.plan]] action]
  =/  body=expr:jibb-core
    [%cons (term-literal %poke) [%cons raw reply]]
  [%& [body state.p.values]]
::
++  lower-call-result
  |=  [e=expr:jibb result=lowered state=lowering-state]
  ^-  lowered
  ?:  ?=(%| -.result)  result
  ?.  render.state  result
  ::  The prelude's own seal implementation stays byte-for-byte ordinary.
  ?:  ?|  =(at.root.state /lib/jibb/prelude/jibb)
          =(at.root.state /lib/jibb/internal/jibb)
          =(at.root.state /lib/jibb/primitives/jibb)
      ==
    result
  =/  checked=(unit lowering-occurrence:jibb)
    (find-occurrence (occurrence-id e) root.state)
  ?~  checked  result
  =/  typ=itype:jibb  typ.u.checked
  =.  typ
    |-  ^-  itype:jibb
    ?:  ?=(?(%face %slot) -.typ)  $(typ body.typ)
    ?:  ?=(%refined -.typ)  $(typ proof.typ)
    typ
  ?.  ?=(%opaque -.typ)  result
  ?.  =(origin.typ [/lib/jibb/primitives/jibb %seal])  result
  ?.  ?=(%union -.body.typ)  result
  ?.  =(origin.body.typ `[/lib/jibb/internal/jibb %element-node])  result
  =/  file=expr:jibb-core
    (make-cons-list (turn at.root.state knot-literal))
  =/  origin=expr:jibb-core
    :+  %cons  file
    [%cons [%lit [%ud line.beg.at.e (scot %ud line.beg.at.e)]] [%cons [%lit [%ud col.beg.at.e (scot %ud col.beg.at.e)]] value.p.result]]
  [%& [[%app [%native [%own %render-origin]] origin] state.p.result]]
::
++  lower-call
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%call -.e)
  =/  result=lowered
    =/  unface=(unit expr:jibb)  (unface-call e)
    ?^  unface  (lower-expression u.unface state)
    =/  derived=(unit [at=path agent=term mark=term])
      (derived-poke-call e root.state)
    ?^  derived  (lower-poke-call u.derived args.e state)
    ?:  (island-call e root.state)  (lower-island-call e state)
    =/  fun=lowered  (lower-expression head.e state)
    ?:  ?=(%| -.fun)  fun
    =/  args=(each [values=(list expr:jibb-core) state=lowering-state] @t)
      (lower-expressions args.e state.p.fun)
    ?:  ?=(%| -.args)  args
    =/  sample=(unit expr:jibb-core)  (make-arguments values.p.args)
    ?~  sample  [%| (fail "a checked call has no arguments" `at.e)]
    [%& [(make-app value.p.fun u.sample) state.p.args]]
  (lower-call-result e result state)
::
++  lower-change-edits
  |=  [edits=(list edit:jibb) base=expr:jibb-core state=lowering-state]
  ^-  lowered
  ?~  edits  [%& [base state]]
  =/  plan=(unit lowering-edit:jibb)  (find-edit at.i.edits names.i.edits root.state)
  ?~  plan  [%| (fail "missing checked record-edit axes" `at.i.edits)]
  =/  axis=(unit @)  (compose-steps steps.u.plan)
  ?~  axis  [%| (fail "empty checked record-edit axis plan" `at.i.edits)]
  =/  value=lowered  (lower-expression val.i.edits state)
  ?:  ?=(%| -.value)  value
  =/  edited=expr:jibb-core  [%edit u.axis base value.p.value]
  $(edits t.edits, base edited, state state.p.value)
::
++  sample-top-name
  |=  s=sample:jibb
  ^-  (unit term)
  ?-  -.s
    %bind  `name.s
    %face  `name.s
    %pun   `name.s
    *      ~
  ==
::
++  wrap-binder
  |=  [binder=lowering-binder:jibb subject=name:jibb-core body=expr:jibb-core]
  ^-  expr:jibb-core
  [%let [%own name.binder] (make-slot axis.binder [%var subject]) body]
::
++  sample-binder-leaf
  |=  [at=span:jibb root=checked-module:jibb]
  ^-  (each (list lowering-binder:jibb) @t)
  =/  found=(unit lowering-binder:jibb)  (find-binder [at %sample] root)
  ?~  found  [%| (fail "missing checked sample binder" `at)]
  [%& ~[u.found]]
::
++  sample-binders
  |=  [s=sample:jibb root=checked-module:jibb]
  ^-  (each (list lowering-binder:jibb) @t)
  ?-  -.s
    %bind  (sample-binder-leaf at.s root)
    %face  (sample-binder-leaf at.s root)
    %pun   (sample-binder-leaf at.s root)
    %bare  [%& ~]
    %cell
      =/  todo=(list sample:jibb)  items.s
      =|  out=(list lowering-binder:jibb)
      |-
      ?~  todo  [%& out]
      =/  first=(each (list lowering-binder:jibb) @t)  ^$(s i.todo)
      ?:  ?=(%| -.first)  first
      =/  rest=(each (list lowering-binder:jibb) @t)  $(todo t.todo, out (weld out p.first))
      rest
  ==
::
++  lower-gate
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(?(%gate %gate-wide) -.e)
  =/  top=(unit term)  (sample-top-name sample.e)
  =/  made=[name=name:jibb-core state=lowering-state]
    ?^  top  [[%own u.top] state]
    =/  generated=[name:jibb-core lowering-state]  (fresh state)
    [-.generated +.generated]
  =/  binders=(each (list lowering-binder:jibb) @t)  (sample-binders sample.e root.state.made)
  ?:  ?=(%| -.binders)  binders
  =/  body=lowered  (lower-expression body.e state.made)
  ?:  ?=(%| -.body)  body
  =/  nested=(list lowering-binder:jibb)
    %-  flop
    ?~(top p.binders (skip p.binders |=(b=lowering-binder:jibb =(1 axis.b))))
  =/  wrapped=expr:jibb-core  value.p.body
  |-
  ?~  nested
    [%& [[%lam name.made wrapped] state.p.body]]
  $(nested t.nested, wrapped (wrap-binder i.nested name.made wrapped))
::
++  lower-projection
  |=  [plan=lowering-projection:jibb state=lowering-state]
  ^-  lowered
  =/  original=expr:jibb  original.plan.plan
  ?.  ?=(%call -.original)  [%| (fail "checked projection is not a call" `at.plan.plan)]
  ?.  ?=([* ~] args.original)  [%| (fail "checked projection does not have one source" `at.plan.plan)]
  =/  scanned=(unit iwfields:jibb)  (width-scan:jibb target.plan.plan ~ 1 4.096)
  ?~  scanned  [%| (fail "checked projection target has no determinate layout" `at.plan.plan)]
  =/  target-order=(list term)  (turn order.u.scanned |=(f=iwfield:jibb name.f))
  =/  source-order=(list term)  (turn steps.plan.plan |=(s=iwstep:jibb name.s))
  ?.  =(target-order source-order)
    [%| (fail "projection field reordering is undecided; refusing to guess" `at.plan.plan)]
  =/  source=lowered  (lower-expression i.args.original state)
  ?:  ?=(%| -.source)  source
  =/  made=[name:jibb-core lowering-state]  (fresh state.p.source)
  =/  var=expr:jibb-core  [%var -.made]
  =/  fields=(list expr:jibb-core)  ~
  =/  steps=(list iwstep:jibb)  steps.plan.plan
  |-
  ?~  steps
    ?:  ?=(~ fields)  [%| (fail "cannot project an empty record" `at.plan.plan)]
    =/  fixed=expr:jibb-core
      =/  remaining=(list expr:jibb-core)  fields
      |-
      ?~  remaining  [%crash ~]
      ?~  t.remaining  i.remaining
      [%cons i.remaining $(remaining t.remaining)]
    [%& [[%let -.made value.p.source fixed] +.made]]
  =/  axis=(unit @)  (compose-steps ~[i.steps])
  ?~  axis  [%| (fail "invalid projection source axis" `at.plan.plan)]
  $(steps t.steps, fields (weld fields ~[(make-slot u.axis var)]))
::
++  core-free-name
  |=  [wanted=name:jibb-core e=expr:jibb-core]
  ^-  ?
  ?-  -.e
    %var      =(wanted name.e)
    %lit      |
    %native   |
    %crash    |
    %cons     |($(e hed.e) $(e tal.e))
    %slot     $(e body.e)
    %edit     |($(e body.e) $(e value.e))
    %cell     $(e body.e)
    %eq       |($(e left.e) $(e right.e))
    %if       |($(e test.e) |($(e yes.e) $(e no.e)))
    %let
      |($(e value.e) &(!=(wanted name.e) $(e body.e)))
    %rec
      ?:  (lien arms.e |=(a=rec-arm:jibb-core =(wanted name.a)))  |
      |((lien arms.e |=(a=rec-arm:jibb-core ^$(e fun.a))) $(e body.e))
    %lam      &(!=(wanted sample.e) $(e body.e))
    %app      |($(e fun.e) $(e sample.e))
    %trace    |($(e message.e) $(e body.e))
  ==
::
++  lower-definition-values
  |=  [definitions=(list def:jibb) state=lowering-state]
  ^-  (each [values=(list expr:jibb-core) state=lowering-state] @t)
  ?~  definitions  [%& [~ state]]
  ?>  ?=(%value -.i.definitions)
  =/  first=lowered  (lower-expression val.i.definitions state)
  ?:  ?=(%| -.first)  first
  =/  rest=(each [values=(list expr:jibb-core) state=lowering-state] @t)
    $(definitions t.definitions, state state.p.first)
  ?:  ?=(%| -.rest)  rest
  [%& [[value.p.first values.p.rest] state.p.rest]]
::
++  value-name
  |=  definition=def:jibb
  ^-  term
  ?>  ?=(%value -.definition)
  name.definition
::
++  member-name
  |=  [wanted=term names=(list term)]
  ^-  ?
  ?~  names  |
  ?:  =(wanted i.names)  &
  $(names t.names)
::
::
++  lower-body-components
  |=  [components=(list lowering-scc:jibb) defs=(list def:jibb) final=expr:jibb state=lowering-state]
  ^-  lowered
  ?~  components  (lower-expression final state)
  =/  members=(list term)  members.i.components
  ?~  members  [%| 'checked dependency component is empty']
  =/  selected=(list def:jibb)
    %+  murn  defs
    |=  d=def:jibb
    ?.  ?=(%value -.d)  ~
    ?.  (member-name (value-name d) members)  ~
    `d
  ?.  =((lent selected) (lent members))
    [%| 'checked dependency component does not match source definitions']
  =/  ordered=(list def:jibb)  selected
  =/  values=(each [values=(list expr:jibb-core) state=lowering-state] @t)
    (lower-definition-values ordered state)
  ?:  ?=(%| -.values)  values
  =/  rest=lowered
    $(components t.components, state state.p.values)
  ?:  ?=(%| -.rest)  rest
  =/  body=expr:jibb-core  value.p.rest
  ?~  t.members
    ?.  ?=([* ~] values.p.values)  [%| 'singleton component value count differs']
    =/  only=expr:jibb-core  i.values.p.values
    =/  binding=name:jibb-core  [%own i.members]
    ?:  (core-free-name binding only)
      ?.  ?=(%lam -.only)
        [%| (fail "a non-gate value depends on itself" ~)]
      [%& [[%rec ~[[binding only]] body] state.p.rest]]
    [%& [[%let binding only body] state.p.rest]]
  =/  arms=(each (list rec-arm:jibb-core) @t)
    =/  names=(list term)  (turn ordered value-name)
    =/  vals=(list expr:jibb-core)  values.p.values
    |-
    ?~  names
      ?~(vals [%& ~] [%| 'recursive component has too many values'])
    ?~  vals  [%| 'recursive component has too few values']
    ?.  ?=(%lam -.i.vals)
      [%| 'every right side of a recursive group must lower to a lambda']
    =/  tail=(each (list rec-arm:jibb-core) @t)  $(names t.names, vals t.vals)
    ?:  ?=(%| -.tail)  tail
    [%& [[[%own i.names] i.vals] p.tail]]
  ?:  ?=(%| -.arms)  arms
  [%& [[%rec p.arms body] state.p.rest]]
::
++  lower-body
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%body -.e)
  =/  components=(list lowering-scc:jibb)
    (skim components.root.state |=(c=lowering-scc:jibb =(scope.c `at.e)))
  =/  values=(list def:jibb)  (skim defs.e |=(d=def:jibb ?=(%value -.d)))
  ?:  &(?=(^ values) ?=(~ components))
    [%| (fail "missing checked local dependency components" `at.e)]
  (lower-body-components components values final.e state)
::
++  lower-expression
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  =/  checked=(unit lowering-occurrence:jibb)  (find-occurrence (occurrence-id e) root.state)
  ?~  checked  [%| (fail "missing checked expression occurrence" `(span-of:jibb e))]
  =/  projection=(unit lowering-projection:jibb)  (find-projection (occurrence-id e) root.state)
  ?^  projection  (lower-projection u.projection state)
  ?-  -.e
    %lit       [%& [(literal lit.e) state]]
    %str       (lower-string e state)
    %path      (lower-path segs.e state)
    %qath      (lower-qath segs.e state)
    %wing      (lower-wing e state)
    %change
      =/  base=lowered  (lower-wing [%wing at.e target.e] state)
      ?:  ?=(%| -.base)  base
      (lower-change-edits edits.e value.p.base state.p.base)
    %pair
      =/  payload=lowered  (lower-expression val.e state)
      ?:  ?=(%| -.payload)  payload
      [%& [[%cons (term-literal tag.e) value.p.payload] state.p.payload]]
    %unit
      =/  payload=lowered  (lower-expression val.e state)
      ?:  ?=(%| -.payload)  payload
      [%& [[%cons null value.p.payload] state.p.payload]]
    %group     (lower-expression inner.e state)
    %list      (lower-list items.e state)
    %tuple     (lower-items items.e state)
    ?(%gate %gate-wide)  (lower-gate e state)
    %ctor
      =/  made=[name:jibb-core lowering-state]  (fresh state)
      [%& [[%lam -.made [%cons (literal tag.e) [%var -.made]]] +.made]]
    %call      (lower-call e state)
    %cast      (lower-expression val.e state)
    %trace
      =/  message=lowered  (lower-printed val.e state)
      ?:  ?=(%| -.message)  message
      =/  body=lowered  (lower-expression then.e state.p.message)
      ?:  ?=(%| -.body)  body
      [%& [[%trace value.p.message value.p.body] state.p.body]]
    %branch    (lower-branch e state)
    %crash     [%& [[%crash ~] state]]
    %body      (lower-body e state)
  ==
::
++  lower-definition
  |=  [definition=def:jibb root=checked-module:jibb render=?]
  ^-  (each definition:jibb-core @t)
  ?.  ?=(%value -.definition)  [%| 'only value definitions lower to Core']
  =/  result=lowered  (lower-expression val.definition [root 1 render])
  ?:  ?=(%| -.result)  result
  [%& [[%own name.definition] value.p.result]]
::
++  lower-derived-definitions
  |=  [plans=(list [name=term plan=lowering-derived:jibb]) root=checked-module:jibb]
  ^-  (each (list definition:jibb-core) @t)
  ?~  plans  [%& ~]
  =/  first=lowered  (lower-derived plan.i.plans [root 1 |])
  ?:  ?=(%| -.first)  first
  =/  rest=(each (list definition:jibb-core) @t)  $(plans t.plans)
  ?:  ?=(%| -.rest)  rest
  [%& [[[%own name.i.plans] value.p.first] p.rest]]
++  lower-module
  |=  [root=checked-module:jibb render=?]
  ^-  (each module:jibb-core @t)
  =/  todo=(list def:jibb)  defs.source.root
  =|  out=(list definition:jibb-core)
  |-
  ?~  todo
    =/  derived=(each (list definition:jibb-core) @t)
      (lower-derived-definitions derived.root root)
    ?:  ?=(%| -.derived)  derived
    [%& [(core-path at.root) (weld out p.derived)]]
  ?:  ?=(%mold -.i.todo)  $(todo t.todo)
  =/  one=(each definition:jibb-core @t)  (lower-definition i.todo root render)
  ?:  ?=(%| -.one)  one
  $(todo t.todo, out (weld out ~[p.one]))
::
++  lower-checked-module
  |=  root=checked-module:jibb
  ^-  (each module:jibb-core @t)
  (lower-module root |)
::
++  lower-render-module
  |=  root=checked-module:jibb
  ^-  (each module:jibb-core @t)
  (lower-module root &)
::
++  domain-status
  |=  [d=domain:coverage:jibb graph=bindings:coverage:jibb fuel=@ud]
  ^-  ?(%empty %atom %cell %mixed)
  ?:  =(0 fuel)  %mixed
  ?-  -.d
    %empty    %empty
    %any      %mixed
    %atom     %atom
    %literal  %atom
    %cell     %cell
    %ref
      =/  found=(unit domain:coverage:jibb)  (binding:coverage:jibb id.d graph)
      ?~(found %mixed $(d u.found, fuel (dec fuel)))
    %union
      =/  cases=(list domain:coverage:jibb)  cases.d
      =/  status=?(%empty %atom %cell %mixed)  %empty
      |-
      ?~  cases  status
      =/  next=?(%empty %atom %cell %mixed)  ^$(d i.cases, fuel (dec fuel))
      =/  joined=?(%empty %atom %cell %mixed)
        ?:  =(%empty status)  next
        ?:  =(%empty next)  status
        ?:  =(status next)  status
        %mixed
      $(cases t.cases, status joined)
  ==
::
++  unique-atoms
  |=  values=(list @)
  ^-  (list @)
  =|  out=(list @)
  |-
  ?~  values  out
  ?:  (lien out |=(n=@ =(n i.values)))  $(values t.values)
  $(values t.values, out (weld out ~[i.values]))
::
++  finite-domain-literals
  |=  [d=domain:coverage:jibb graph=bindings:coverage:jibb fuel=@ud]
  ^-  (unit (list @))
  ?:  =(0 fuel)  ~
  ?-  -.d
    %empty    `~
    %literal  `~[value.d]
    %cell     `~
    ?(%any %atom)  ~
    %ref
      =/  found=(unit domain:coverage:jibb)  (binding:coverage:jibb id.d graph)
      ?~(found ~ $(d u.found, fuel (dec fuel)))
    %union
      =/  cases=(list domain:coverage:jibb)  cases.d
      =|  out=(list @)
      |-
      ?~  cases  `(unique-atoms out)
      =/  first=(unit (list @))  ^$(d i.cases, fuel (dec fuel))
      ?~  first  ~
      $(cases t.cases, out (weld out u.first))
  ==
::
++  project-domain
  |=  [d=domain:coverage:jibb graph=bindings:coverage:jibb head=? fuel=@ud]
  ^-  domain:coverage:jibb
  ?:  =(0 fuel)  [%any ~]
  ?-  -.d
    %ref
      =/  found=(unit domain:coverage:jibb)  (binding:coverage:jibb id.d graph)
      ?~(found [%any ~] $(d u.found, fuel (dec fuel)))
    %union
      =/  cases=(list domain:coverage:jibb)
        (turn cases.d |=(c=domain:coverage:jibb ^$(d c, fuel (dec fuel))))
      [%union cases]
    %cell  ?:(head head.d tail.d)
    %empty  [%empty ~]
    *       [%empty ~]
  ==
::
++  source-cell-parts
  |=  source=(unit pattern:jibb)
  ^-  [head=(unit pattern:jibb) tail=(unit pattern:jibb)]
  ?~  source  [~ ~]
  ?.  ?=(%cell -.u.source)  [~ ~]
  ?.  ?=([* * *] items.u.source)  [~ ~]
  =/  tail=pattern:jibb
    ?~  t.t.items.u.source  i.t.items.u.source
    [%cell at.u.source t.items.u.source]
  [`i.items.u.source `tail]
::
++  initial-decision-rows
  |=  [matrix=matrix:coverage:jibb arms=(list arm:jibb) index=@ud]
  ^-  (each (list decision-row) @t)
  ?~  matrix
    ?~(arms [%& ~] [%| 'checked match has more arms than matrix rows'])
  ?~  arms  [%| 'checked match has more matrix rows than arms']
  ?.  ?=([* ~] i.matrix)  [%| 'checked match row is not one subject column']
  =/  rest=(each (list decision-row) @t)  $(matrix t.matrix, arms t.arms, index +(index))
  ?:  ?=(%| -.rest)  rest
  [%& [[[index ~[[i.i.matrix `pat.i.arms]]]] p.rest]]
::
++  drop-first-patterns
  |=  rows=(list decision-row)
  ^-  (list decision-row)
  %+  murn  rows
  |=  row=decision-row
  ?~  pats.row  ~
  `row(pats t.pats.row)
::
++  specialize-cells
  |=  rows=(list decision-row)
  ^-  (list decision-row)
  =|  out=(list decision-row)
  |-
  ?~  rows  out
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  =/  pat=decision-pattern  i.pats.row
  =/  made=(unit decision-row)
    ?-  -.cov.pat
      %literal  ~
      %wild
        `row(pats [[[%wild ~] ~] [[%wild ~] ~] t.pats.row])
      %cell
        =/  parts=[head=(unit pattern:jibb) tail=(unit pattern:jibb)]
          (source-cell-parts src.pat)
        `row(pats [[head.cov.pat head.parts] [tail.cov.pat tail.parts] t.pats.row])
    ==
  ?~  made  $(rows t.rows)
  $(rows t.rows, out (weld out ~[u.made]))
::
++  specialize-atoms
  |=  [rows=(list decision-row) value=@ wild-only=?]
  ^-  (list decision-row)
  =|  out=(list decision-row)
  |-
  ?~  rows  out
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  =/  pat=decision-pattern  i.pats.row
  =/  keep=?
    ?-  -.cov.pat
      %wild     &
      %cell     |
      %literal  &(!wild-only =(value value.cov.pat))
    ==
  ?.  keep  $(rows t.rows)
  $(rows t.rows, out (weld out ~[row(pats t.pats.row)]))
::
++  remaining-atoms
  |=  [rows=(list decision-row) value=@]
  ^-  (list decision-row)
  =|  out=(list decision-row)
  |-
  ?~  rows  out
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  =/  pat=decision-pattern  i.pats.row
  ?:  ?=(%cell -.cov.pat)  $(rows t.rows)
  ?:  &(?=(%literal -.cov.pat) =(value value.cov.pat))  $(rows t.rows)
  $(rows t.rows, out (weld out `(list decision-row)`~[row]))
::
++  decision-literals
  |=  rows=(list decision-row)
  ^-  (list @)
  =|  out=(list @)
  |-
  ?~  rows  out
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  =/  pat=decision-pattern  i.pats.row
  ?.  ?=(%literal -.cov.pat)  $(rows t.rows)
  ?:  (lien out |=(n=@ =(n value.cov.pat)))  $(rows t.rows)
  $(rows t.rows, out (weld out ~[value.cov.pat]))
::
++  decision-has-cells
  |=  rows=(list decision-row)
  ^-  ?
  ?~  rows  |
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  ?:  ?=(%cell -.cov.i.pats.row)  &
  $(rows t.rows)
::
++  decision-has-wild
  |=  rows=(list decision-row)
  ^-  ?
  ?~  rows  |
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  ?:  ?=(%wild -.cov.i.pats.row)  &
  $(rows t.rows)
::
++  decision-all-wild
  |=  rows=(list decision-row)
  ^-  ?
  ?~  rows  &
  =/  row=decision-row  i.rows
  ?~  pats.row  |
  &(?=(%wild -.cov.i.pats.row) $(rows t.rows))
::
++  source-literal
  |=  [rows=(list decision-row) value=@]
  ^-  (unit expr:jibb-core)
  ?~  rows  ~
  =/  row=decision-row  i.rows
  ?~  pats.row  $(rows t.rows)
  =/  pat=decision-pattern  i.pats.row
  ?.  ?=(%literal -.cov.pat)  $(rows t.rows)
  ?.  =(value value.cov.pat)  $(rows t.rows)
  ?~  src.pat  ~
  ?-  -.u.src.pat
    %lit  `(literal lit.u.src.pat)
    %str  `(string-literal text.u.src.pat)
    *     ~
  ==
::
++  wrap-match-binders
  |=  [binders=(list lowering-binder:jibb) subject=name:jibb-core body=expr:jibb-core]
  ^-  expr:jibb-core
  ?~  binders  body
  $(binders t.binders, body (wrap-binder i.binders subject body))
::
++  lower-decision-arm
  |=  [index=@ud match=lowering-match:jibb arms=(list arm:jibb) subject=name:jibb-core state=lowering-state]
  ^-  lowered
  ?:  (gte index (lent arms))  [%| 'checked match arm index is out of range']
  ?:  (gte index (lent arms.match))  [%| 'checked match artifact arm index is out of range']
  =/  arm=arm:jibb  (snag index arms)
  =/  artifact=lowering-match-arm:jibb  (snag index arms.match)
  =/  body=lowered  (lower-expression val.arm state)
  ?:  ?=(%| -.body)  body
  =/  binders=(list lowering-binder:jibb)
    %+  skim  refinements.match
    |=  b=lowering-binder:jibb
    (lowering-span-contains:jibb at.artifact at.id.b)
  =/  wrapped=expr:jibb-core
    (wrap-match-binders (flop binders) subject value.p.body)
  [%& [wrapped state.p.body]]
::
++  literal-needs-test
  |=  [values=(list @) rows=(list decision-row) finite=(unit (list @))]
  ^-  ?
  ?~  values  |
  ?^  t.values  &
  ?:  (decision-has-wild rows)  &
  ?~(finite & |)
::
++  lower-atom-decisions
  |=  [values=(list @) rows=(list decision-row) cols=(list decision-column) finite=(unit (list @)) match=lowering-match:jibb arms=(list arm:jibb) subject=name:jibb-core state=lowering-state]
  ^-  lowered
  ?~  cols  [%| 'match lost its subject column']
  ?~  values
    =/  wild=(list decision-row)  (specialize-atoms rows 0 &)
    (lower-decision wild t.cols match arms subject state)
  =/  lit=(unit expr:jibb-core)  (source-literal rows i.values)
  ?~  lit  [%| (fail "checked literal pattern lost its source aura" ~)]
  =/  matching=(list decision-row)  (specialize-atoms rows i.values |)
  =/  fallback=(list decision-row)  (specialize-atoms rows i.values &)
  =/  yes=lowered  (lower-decision matching t.cols match arms subject state)
  ?:  ?=(%| -.yes)  yes
  ?:  &(?=(~ t.values) ?=(~ fallback) ?=(^ finite))
    yes
  =/  no=lowered
    $(values t.values, rows (remaining-atoms rows i.values), state state.p.yes)
  ?:  ?=(%| -.no)  no
  [%& [(make-if [%eq value.i.cols u.lit] value.p.yes value.p.no) state.p.no]]
::
++  decision-test-needed
  |=  [rows=(list decision-row) d=domain:coverage:jibb graph=bindings:coverage:jibb]
  ^-  ?
  =/  cells=?  (decision-has-cells rows)
  =/  values=(list @)  (decision-literals rows)
  =/  status=?(%empty %atom %cell %mixed)  (domain-status d graph 128)
  ?:  &(cells !?=(%cell status))  &
  (literal-needs-test values rows (finite-domain-literals d graph 128))
::
++  lower-decision
  |=  [rows=(list decision-row) cols=(list decision-column) match=lowering-match:jibb arms=(list arm:jibb) subject=name:jibb-core state=lowering-state]
  ^-  lowered
  ?~  rows  [%& [[%crash ~] state]]
  ?~  cols
    (lower-decision-arm arm.i.rows match arms subject state)
  =/  first-wild=?  (decision-all-wild rows)
  ?:  first-wild
    (lower-decision (drop-first-patterns rows) t.cols match arms subject state)
  =/  current=decision-column  i.cols
  =/  rows-now=(list decision-row)  rows
  =/  cols-now=(list decision-column)  cols
  ?:  &(!?=(%var -.value.current) (decision-test-needed rows-now domain.current graph.match))
    =/  generated=[name:jibb-core lowering-state]  (fresh state)
    =/  old=expr:jibb-core  value.current
    =/  var=expr:jibb-core  [%var -.generated]
    =/  rebound=(list decision-column)  [[var domain.current] t.cols]
    =/  result=lowered
      (lower-decision rows-now rebound match arms subject +.generated)
    ?:  ?=(%| -.result)  result
    [%& [[%let -.generated old value.p.result] state.p.result]]
  =/  d=domain:coverage:jibb  domain.current
  =/  status=?(%empty %atom %cell %mixed)  (domain-status d graph.match 128)
  =/  cells=?  (decision-has-cells rows-now)
  ?:  &(!cells !?=(%cell status))
    =/  values=(list @)  (decision-literals rows-now)
    =/  finite=(unit (list @))  (finite-domain-literals d graph.match 128)
    (lower-atom-decisions values rows-now cols-now finite match arms subject state)
  ?:  cells
    =/  cell-rows=(list decision-row)  (specialize-cells rows-now)
    =/  atom-rows=(list decision-row)
      %+  skim  rows-now
      |=  row=decision-row
      ?~(pats.row | !?=(%cell -.cov.i.pats.row))
    =/  head=domain:coverage:jibb  (project-domain d graph.match & 128)
    =/  tail=domain:coverage:jibb  (project-domain d graph.match | 128)
    =/  next=(list decision-column)
      [[(make-slot 2 value.current) head] [(make-slot 3 value.current) tail] t.cols]
    =/  yes=lowered  (lower-decision cell-rows next match arms subject state)
    ?:  ?=(%| -.yes)  yes
    ?:  ?=(%cell status)  yes
    =/  no=lowered  (lower-decision atom-rows t.cols match arms subject state.p.yes)
    ?:  ?=(%| -.no)  no
    [%& [(make-if [%cell value.current] value.p.yes value.p.no) state.p.no]]
  (lower-atom-decisions (decision-literals rows-now) rows-now cols-now ~ match arms subject state)
::
++  flag-subject
  |=  typ=itype:jibb
  ^-  ?
  ?-  -.typ
    ?(%face %slot)  $(typ body.typ)
    %flag           &
    *               |
  ==
::
++  loobean-arm
  |=  [arms=(list arm:jibb) value=@ud]
  ^-  (unit @ud)
  =/  index=@ud  0
  |-
  ?~  arms  ~
  =/  arm=arm:jibb  i.arms
  ?.  ?=(%lit -.pat.arm)  $(arms t.arms, index +(index))
  ?.  ?=(%loobean form.lit.pat.arm)  $(arms t.arms, index +(index))
  ?:  =(value val.lit.pat.arm)  `index
  $(arms t.arms, index +(index))
::
++  lower-generic-branch
  |=  [e=expr:jibb match=lowering-match:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%branch -.e)
  =/  rows=(each (list decision-row) @t)  (initial-decision-rows matrix.match arms.e 0)
  ?:  ?=(%| -.rows)  rows
  =/  source=lowered  (lower-expression subject.e state)
  ?:  ?=(%| -.source)  source
  =/  existing=(unit name:jibb-core)
    ?:(?=(%var -.value.p.source) `name.value.p.source ~)
  =/  made=[name=name:jibb-core state=lowering-state]
    ?^  existing  [u.existing state.p.source]
    =/  generated=[name:jibb-core lowering-state]  (fresh state.p.source)
    [-.generated +.generated]
  =/  cols=(list decision-column)  ~[[[%var name.made] domain.match]]
  =/  result=lowered  (lower-decision p.rows cols match arms.e name.made state.made)
  ?:  ?=(%| -.result)  result
  ?^  existing  result
  [%& [[%let name.made value.p.source value.p.result] state.p.result]]
::
++  lower-branch
  |=  [e=expr:jibb state=lowering-state]
  ^-  lowered
  ?>  ?=(%branch -.e)
  =/  match=(unit lowering-match:jibb)  (find-match [at.e %expression] root.state)
  ?~  match  [%| (fail "missing checked match artifact" `at.e)]
  ?.  &((flag-subject subject.u.match) =(2 (lent arms.e)))
    (lower-generic-branch e u.match state)
  =/  yes=(unit @ud)  (loobean-arm arms.e 0)
  =/  no=(unit @ud)  (loobean-arm arms.e 1)
  ?:  |(?=(~ yes) ?=(~ no))  (lower-generic-branch e u.match state)
  =/  test=lowered  (lower-expression subject.e state)
  ?:  ?=(%| -.test)  test
  =/  yes-body=lowered  (lower-decision-arm u.yes u.match arms.e [%generated '_flag'] state.p.test)
  ?:  ?=(%| -.yes-body)  yes-body
  =/  no-body=lowered  (lower-decision-arm u.no u.match arms.e [%generated '_flag'] state.p.yes-body)
  ?:  ?=(%| -.no-body)  no-body
  [%& [(make-if value.p.test value.p.yes-body value.p.no-body) state.p.no-body]]
::
++  tape-before
  |=  [a=tape b=tape]
  ^-  ?
  ?~  a  ?=(^ b)
  ?~  b  |
  ?:  =(i.a i.b)  $(a t.a, b t.b)
  (lth i.a i.b)
::
++  path-before
  |=  [a=path b=path]
  ^-  ?
  (tape-before (spud (core-path a)) (spud (core-path b)))
::
++  term-before
  |=  [a=term b=term]
  ^-  ?
  (tape-before (trip a) (trip b))
::
++  sort-terms
  |=  names=(list term)
  ^-  (list term)
  (sort names |=([a=term b=term] (term-before a b)))
::
++  core-name-member
  |=  [wanted=name:jibb-core names=(list name:jibb-core)]
  ^-  ?
  ?~  names  |
  ?:  =(wanted i.names)  &
  $(names t.names)
::
++  free-core-names
  |=  [e=expr:jibb-core bound=(list name:jibb-core)]
  ^-  (list name:jibb-core)
  ?-  -.e
    %var      ?:((core-name-member name.e bound) ~ ~[name.e])
    %lit      ~
    %native   ~
    %crash    ~
    %cons     (weld $(e hed.e) $(e tal.e))
    %slot     $(e body.e)
    %edit     (weld $(e body.e) $(e value.e))
    %cell     $(e body.e)
    %eq       (weld $(e left.e) $(e right.e))
    %if       (weld $(e test.e) (weld $(e yes.e) $(e no.e)))
    %let
      (weld $(e value.e) $(e body.e, bound [name.e bound]))
    %rec
      =/  names=(list name:jibb-core)  (turn arms.e |=(a=rec-arm:jibb-core name.a))
      =/  inner=(list name:jibb-core)  (weld names bound)
      =/  in-arms=(list name:jibb-core)
        %-  zing
        (turn arms.e |=(a=rec-arm:jibb-core ^$(e fun.a, bound inner)))
      (weld in-arms $(e body.e, bound inner))
    %lam      $(e body.e, bound [sample.e bound])
    %app      (weld $(e fun.e) $(e sample.e))
    %trace    (weld $(e message.e) $(e body.e))
  ==
::
++  unique-core-names
  |=  names=(list name:jibb-core)
  ^-  (list name:jibb-core)
  =|  out=(list name:jibb-core)
  |-
  ?~  names  out
  ?:  (core-name-member i.names out)  $(names t.names)
  $(names t.names, out (weld out ~[i.names]))
::
++  reference-before
  |=  [a=link-reference b=link-reference]
  ^-  ?
  ?:  =(at.a at.b)  (term-before name.a name.b)
  (path-before at.a at.b)
::
++  reference-from-name
  |=  [n=name:jibb-core at=path state=link-state]
  ^-  (unit link-reference)
  ?-  -.n
    %own
      =/  cached=(each [value=module:jibb-core state=link-state] @t)
        (lower-module-cached at state)
      ?:  ?=(%| -.cached)  ~
      ?^  (module-definition name.n value.p.cached)  `[[at name.n]]
      `[[/lib/jibb/prelude/jibb name.n]]
    %qualified  `[[(weld at.n `path`~[%jibb]) name.n]]
    %generated  ~
  ==
::
++  definition-references
  |=  [definition=linked-definition state=link-state]
  ^-  (each (list link-reference) @t)
  =/  names=(list name:jibb-core)  (unique-core-names (free-core-names value.definition ~))
  =|  out=(list link-reference)
  |-
  ?~  names  [%& (sort out |=([a=link-reference b=link-reference] (reference-before a b)))]
  =/  ref=(unit link-reference)  (reference-from-name i.names at.definition state)
  ?~  ref  [%| 'a generated name escaped its lexical scope']
  $(names t.names, out (weld out ~[u.ref]))
::
++  find-artifact
  |=  [at=path state=link-state]
  ^-  (unit checked-module:jibb)
  ?:  =(at at.root.state)  `root.state
  =/  cache=jlowering-cache:jibb  cache.state
  |-
  ?^  cache
    ?:  =(at at.i.cache)  `artifact.i.cache
    $(cache t.cache)
  =/  artifacts=(list checked-module:jibb)
    [root.state (turn cache.state |=(entry=[at=path artifact=checked-module:jibb] artifact.entry))]
  =/  matches=(list checked-module:jibb)
    %+  skim  artifacts
    |=  artifact=checked-module:jibb
    =(at (weld (core-path at.artifact) `path`~[%jibb]))
  ?:  ?=([* ~] matches)  `i.matches
  ~
::
++  lower-module-cached
  |=  [at=path state=link-state]
  ^-  (each [value=module:jibb-core state=link-state] @t)
  =/  cached=(list [at=path value=module:jibb-core])  lowered.state
  |-
  ?^  cached
    ?:  =(at at.i.cached)  [%& [value.i.cached state]]
    $(cached t.cached)
  =/  artifact=(unit checked-module:jibb)  (find-artifact at state)
  ?~  artifact  [%| (crip "missing checked dependency artifact: {(spud at)}")]
  =/  lowered=(each module:jibb-core @t)
    ?:(render.state (lower-render-module u.artifact) (lower-checked-module u.artifact))
  ?:  ?=(%| -.lowered)  lowered
  [%& [p.lowered state(lowered [[at p.lowered] lowered.state])]]
::
++  linked-name
  |=  [root=path at=path name=term]
  ^-  name:jibb-core
  ?:  =(root at)  [%own name]
  [%qualified (core-path at) name]
::
++  qualify-expression
  |=  [e=expr:jibb-core at=path names=(list term)]
  ^-  expr:jibb-core
  ?-  -.e
    %var
      ?.  ?=(%own -.name.e)  e
      ?.  (member-name name.name.e names)  e
      e(name [%qualified (core-path at) name.name.e])
    %lit      e
    %native   e
    %crash    e
    %cons     e(hed $(e hed.e), tal $(e tal.e))
    %slot     e(body $(e body.e))
    %edit     e(body $(e body.e), value $(e value.e))
    %cell     e(body $(e body.e))
    %eq       e(left $(e left.e), right $(e right.e))
    %if       e(test $(e test.e), yes $(e yes.e), no $(e no.e))
    %let      e(value $(e value.e), body $(e body.e))
    %rec
      =/  arms=(list rec-arm:jibb-core)
        (turn arms.e |=(a=rec-arm:jibb-core a(fun ^$(e fun.a))))
      e(arms arms, body $(e body.e))
    %lam      e(body $(e body.e))
    %app      e(fun $(e fun.e), sample $(e sample.e))
    %trace   e(message $(e message.e), body $(e body.e))
  ==
::
++  qualify-prelude-references
  |=  [e=expr:jibb-core names=(list term) bound=(list name:jibb-core)]
  ^-  expr:jibb-core
  ?-  -.e
    %var
      ?.  ?=(%own -.name.e)  e
      ?:  (core-name-member name.e bound)  e
      ?:  (member-name name.name.e names)  e
      e(name [%qualified (core-path /lib/jibb/prelude/jibb) name.name.e])
    %lit      e
    %native   e
    %crash    e
    %cons     e(hed $(e hed.e), tal $(e tal.e))
    %slot     e(body $(e body.e))
    %edit     e(body $(e body.e), value $(e value.e))
    %cell     e(body $(e body.e))
    %eq       e(left $(e left.e), right $(e right.e))
    %if       e(test $(e test.e), yes $(e yes.e), no $(e no.e))
    %let
      =/  value=expr:jibb-core  $(e value.e)
      e(value value, body $(e body.e, bound [name.e bound]))
    %rec
      =/  inner=(list name:jibb-core)
        (weld (turn arms.e |=(a=rec-arm:jibb-core name.a)) bound)
      =/  arms=(list rec-arm:jibb-core)
        (turn arms.e |=(a=rec-arm:jibb-core a(fun ^$(e fun.a, bound inner))))
      e(arms arms, body $(e body.e, bound inner))
    %lam      e(body $(e body.e, bound [sample.e bound]))
    %app      e(fun $(e fun.e), sample $(e sample.e))
    %trace    e(message $(e message.e), body $(e body.e))
  ==
::
++  module-definition
  |=  [name=term m=module:jibb-core]
  ^-  (unit expr:jibb-core)
  =/  defs=(list definition:jibb-core)  defs.m
  |-
  ?~  defs  ~
  =/  definition=definition:jibb-core  i.defs
  ?.  ?=(%own -.name.definition)  $(defs t.defs)
  ?:  =(name name.name.definition)  `value.definition
  $(defs t.defs)
::
++  module-definition-names
  |=  m=module:jibb-core
  ^-  (list term)
  %+  murn  defs.m
  |=  d=definition:jibb-core
  ?:(?=(%own -.name.d) `name.name.d ~)
::
++  definition-order
  |=  [name=term m=module:jibb-core]
  ^-  @ud
  =/  defs=(list definition:jibb-core)  defs.m
  =/  index=@ud  0
  |-
  ?~  defs  index
  =/  definition=definition:jibb-core  i.defs
  ?:  &(?=(%own -.name.definition) =(name name.name.definition))  index
  $(defs t.defs, index +(index))
::
++  top-component
  |=  [name=term artifact=checked-module:jibb]
  ^-  (list term)
  =/  components=(list lowering-scc:jibb)  components.artifact
  |-
  ?~  components  ~[name]
  =/  component=lowering-scc:jibb  i.components
  ?:  &(?=(~ scope.component) (member-name name members.component))
    members.component
  $(components t.components)
::
++  reachable-definition
  |=  [at=path name=term state=link-state]
  ^-  ?
  (lien reachable.state |=(d=linked-definition &(=(at at.d) =(name name.d))))
::
++  reach-references
  |=  [references=(list link-reference) state=link-state]
  ^-  (each link-state @t)
  ?~  references  [%& state]
  =/  first=(each link-state @t)  (reach-definition at.i.references name.i.references state)
  ?:  ?=(%| -.first)  first
  $(references t.references, state p.first)
::
++  reach-component
  |=  [at=path members=(list term) state=link-state]
  ^-  (each link-state @t)
  ?~  members  [%& state]
  =/  first=(each link-state @t)  (reach-definition at i.members state)
  ?:  ?=(%| -.first)  first
  $(members t.members, state p.first)
::
++  reach-definition
  |=  [at=path name=term state=link-state]
  ^-  (each link-state @t)
  ?:  (reachable-definition at name state)  [%& state]
  =/  artifact=(unit checked-module:jibb)  (find-artifact at state)
  ?~  artifact  [%| (crip "unresolved linked definition {(spud at)}:{(trip name)}")]
  =/  lowered=(each [value=module:jibb-core state=link-state] @t)
    (lower-module-cached at state)
  ?:  ?=(%| -.lowered)  lowered
  =/  value=(unit expr:jibb-core)  (module-definition name value.p.lowered)
  ?~  value  [%| (crip "linked definition is missing: {(spud at)}:{(trip name)}")]
  =/  names=(list term)  (module-definition-names value.p.lowered)
  =/  local=expr:jibb-core
    ?:  =(at at.root.state)  u.value
    (qualify-expression u.value at names)
  =/  actual=expr:jibb-core
    (qualify-prelude-references local names ~)
  =/  definition=linked-definition
    [at name actual (definition-order name value.p.lowered)]
  =/  with=link-state
    state.p.lowered(reachable [definition reachable.state.p.lowered])
  =/  group=(each link-state @t)
    (reach-component at (top-component name u.artifact) with)
  ?:  ?=(%| -.group)  group
  =/  references=(each (list link-reference) @t)  (definition-references definition state)
  ?:  ?=(%| -.references)  references
  (reach-references p.references p.group)
::
++  reachable-modules
  |=  definitions=(list linked-definition)
  ^-  (list path)
  =|  out=(list path)
  |-
  ?~  definitions
    (sort out |=([a=path b=path] (path-before a b)))
  ?:  (lien out |=(p=path =(p at.i.definitions)))  $(definitions t.definitions)
  $(definitions t.definitions, out (weld out ~[at.i.definitions]))
::
++  node-definitions
  |=  [at=path members=(list term) reachable=(list linked-definition)]
  ^-  (list linked-definition)
  =|  out=(list linked-definition)
  |-
  ?~  members  out
  =/  found=(list linked-definition)
    (skim reachable |=(d=linked-definition &(=(at at.d) =(i.members name.d))))
  ?.  ?=([* ~] found)  $(members t.members)
  $(members t.members, out (weld out ~[i.found]))
::
++  nodes-for-module
  |=  [at=path state=link-state]
  ^-  (each (list linked-node) @t)
  =/  artifact=(unit checked-module:jibb)  (find-artifact at state)
  ?~  artifact  [%| 'reachable module lost its checked artifact']
  =/  components=(list lowering-scc:jibb)
    (skim components.u.artifact |=(c=lowering-scc:jibb ?=(~ scope.c)))
  =|  out=(list linked-node)
  |-
  ?~  components
    ?~(out [%| 'reachable module has no checked dependency components'] [%& out])
  =/  members=(list term)
    %+  skim  members.i.components
    |=  name=term
    (reachable-definition at name state)
  ?~  members  $(components t.components)
  =/  definitions=(list linked-definition)  (node-definitions at members reachable.state)
  ?.  =((lent definitions) (lent members))
    [%| 'recursive group was only partly retained']
  =/  ordered=(list linked-definition)
    (sort definitions |=([a=linked-definition b=linked-definition] (lth order.a order.b)))
  =/  ordered-names=(list term)  (turn ordered |=(d=linked-definition name.d))
  $(components t.components, out (weld out `(list linked-node)`~[[at ordered-names ordered]]))
::
++  build-linked-nodes
  |=  state=link-state
  ^-  (each (list linked-node) @t)
  =/  modules=(list path)  (reachable-modules reachable.state)
  =|  out=(list linked-node)
  |-
  ?~  modules  [%& out]
  =/  first=(each (list linked-node) @t)  (nodes-for-module i.modules state)
  ?:  ?=(%| -.first)  first
  $(modules t.modules, out (weld out p.first))
::
++  emitted-definition
  |=  [ref=link-reference emitted=(list linked-definition)]
  ^-  ?
  (lien emitted |=(d=linked-definition &(=(at.ref at.d) =(name.ref name.d))))
::
++  same-node-reference
  |=  [ref=link-reference node=linked-node]
  ^-  ?
  &(=(at.ref at.node) (member-name name.ref members.node))
::
++  node-ready
  |=  [node=linked-node emitted=(list linked-definition) state=link-state]
  ^-  (each ? @t)
  =/  definitions=(list linked-definition)  definitions.node
  |-
  ?~  definitions  [%& &]
  =/  references=(each (list link-reference) @t)  (definition-references i.definitions state)
  ?:  ?=(%| -.references)  references
  =/  refs=(list link-reference)  p.references
  |-
  ?~  refs  ^$(definitions t.definitions)
  ?:  (same-node-reference i.refs node)  $(refs t.refs)
  ?.  (emitted-definition i.refs emitted)  [%& |]
  $(refs t.refs)
::
++  node-order
  |=  node=linked-node
  ^-  @ud
  =/  definitions=(list linked-definition)  definitions.node
  ?~  definitions  0
  =/  best=@ud  order.i.definitions
  |-
  ?~  t.definitions  best
  $(t.definitions t.t.definitions, best (min best order.i.t.definitions))
::
++  node-before
  |=  [a=linked-node b=linked-node]
  ^-  ?
  ?:  =(at.a at.b)
    =/  oa=@ud  (node-order a)
    =/  ob=@ud  (node-order b)
    ?:  =(oa ob)
      ?:  |(?=(~ members.a) ?=(~ members.b))  |
      (term-before i.members.a i.members.b)
    (lth oa ob)
  (path-before at.a at.b)
::
++  remove-linked-node
  |=  [nodes=(list linked-node) chosen=linked-node]
  ^-  (list linked-node)
  ?~  nodes  ~
  ?:  =(i.nodes chosen)  $(nodes t.nodes)
  [i.nodes $(nodes t.nodes)]
::
++  emit-linked-nodes
  |=  [pending=(list linked-node) emitted=(list linked-definition) state=link-state]
  ^-  (each (list linked-node) @t)
  ?~  pending  [%& ~]
  =/  ready=(list linked-node)  ~
  =/  todo=(list linked-node)  pending
  |-
  ?~  todo
    ?~  ready  [%| 'linked dependency groups contain an unresolved cycle']
    =/  ordered=(list linked-node)  (sort ready |=([a=linked-node b=linked-node] (node-before a b)))
    ?~  ordered  [%| 'linked dependency ordering lost every group']
    =/  chosen=linked-node  i.ordered
    =/  remaining=(list linked-node)
      (remove-linked-node pending chosen)
    =/  rest=(each (list linked-node) @t)
      ^$(pending remaining, emitted (weld emitted definitions.chosen))
    ?:  ?=(%| -.rest)  rest
    [%& [chosen p.rest]]
  =/  ok=(each ? @t)  (node-ready i.todo emitted state)
  ?:  ?=(%| -.ok)  ok
  ?:  p.ok
    $(todo t.todo, ready (weld ready ~[i.todo]))
  $(todo t.todo)
::
++  wrap-linked-node
  |=  [node=linked-node root=path body=expr:jibb-core]
  ^-  (each expr:jibb-core @t)
  ?~  definitions.node  [%| 'cannot emit an empty dependency group']
  ?~  t.definitions.node
    =/  definition=linked-definition  i.definitions.node
    =/  binding=name:jibb-core  (linked-name root at.definition name.definition)
    ?:  (core-free-name binding value.definition)
      ?.  ?=(%lam -.value.definition)
        [%| 'a linked non-gate value depends on itself']
      [%& [%rec ~[[binding value.definition]] body]]
    [%& [%let binding value.definition body]]
  =/  arms=(list rec-arm:jibb-core)
    %+  turn  definitions.node
    |=  definition=linked-definition
    [(linked-name root at.definition name.definition) value.definition]
  ?.  (levy arms |=(a=rec-arm:jibb-core ?=(%lam -.fun.a)))
    [%| 'a linked recursive group contains a non-lambda value']
  [%& [%rec arms body]]
::
++  wrap-linked-program
  |=  [nodes=(list linked-node) root=path body=expr:jibb-core]
  ^-  (each expr:jibb-core @t)
  ?~  nodes  [%& body]
  =/  rest=(each expr:jibb-core @t)  $(nodes t.nodes)
  ?:  ?=(%| -.rest)  rest
  (wrap-linked-node i.nodes root p.rest)
::
++  module-entry-expression
  |=  [at=path root=path state=link-state]
  ^-  (each expr:jibb-core @t)
  =/  names=(list term)
    (sort-terms (turn (skim reachable.state |=(d=linked-definition =(at at.d))) |=(d=linked-definition name.d)))
  ?~  names  [%| 'cannot link an empty module value']
  =/  expressions=(list expr:jibb-core)
    (turn names |=(name=term [%var (linked-name root at name)]))
  =/  remaining=(list expr:jibb-core)  expressions
  |-
  ?~  remaining  [%| 'cannot link an empty module value']
  ?~  t.remaining  [%& i.remaining]
  =/  rest=(each expr:jibb-core @t)  $(remaining t.remaining)
  ?:  ?=(%| -.rest)  rest
  [%& [%cons i.remaining p.rest]]
::
++  link-entry-mode
  |=  [requested=entry root=checked-module:jibb cache=jlowering-cache:jibb render=?]
  ^-  (each expr:jibb-core @t)
  =/  initial=link-state  [root cache ~ ~ render]
  =/  reached=(each link-state @t)
    ?-  -.requested
      %definition  (reach-definition at.requested name.requested initial)
      %module
        =/  artifact=(unit checked-module:jibb)  (find-artifact at.requested initial)
        ?~  artifact  [%| (crip "missing whole-module artifact: {(spud at.requested)}")]
        =/  ordinary=(list term)
          %+  murn  defs.source.u.artifact
          |=  d=def:jibb
          ?:(?=(%value -.d) `name.d ~)
        =/  generated=(list term)
          (turn derived.u.artifact |=(d=[name=term plan=lowering-derived:jibb] name.d))
        (reach-component at.requested (sort-terms (weld ordinary generated)) initial)
    ==
  ?:  ?=(%| -.reached)  reached
  =/  nodes=(each (list linked-node) @t)  (build-linked-nodes p.reached)
  ?:  ?=(%| -.nodes)  nodes
  =/  emitted=(each (list linked-node) @t)  (emit-linked-nodes p.nodes ~ p.reached)
  ?:  ?=(%| -.emitted)  emitted
  =/  body=(each expr:jibb-core @t)
    ?-  -.requested
      %definition  [%& [%var (linked-name at.root at.requested name.requested)]]
      %module      (module-entry-expression at.requested at.root p.reached)
    ==
  ?:  ?=(%| -.body)  body
  (wrap-linked-program p.emitted at.root p.body)
::
++  link-checked-entry
  |=  [requested=entry root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (each expr:jibb-core @t)
  (link-entry-mode requested root cache |)
::
++  link-render-entry
  |=  [name=term root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (each expr:jibb-core @t)
  (link-entry-mode [%definition at.root name] root cache &)
::
++  link-entry
  |=  [name=term root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (each expr:jibb-core @t)
  (link-checked-entry [%definition at.root name] root cache)
::
++  link-module-value
  |=  [at=path root=checked-module:jibb cache=jlowering-cache:jibb]
  ^-  (each expr:jibb-core @t)
  (link-checked-entry [%module at] root cache)
--
