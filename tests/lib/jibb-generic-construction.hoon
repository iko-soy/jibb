/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  owner-positive  %txt  /tests/type-generic-construction/owner-positive/txt
/*  owner-negative  %txt  /tests/type-generic-construction/owner-negative/txt
/*  alias  %txt  /tests/type-generic-construction/alias/txt
/*  tree-no-event  %txt  /tests/type-generic-construction/tree-no-event/txt
/*  sibling-values  %txt  /tests/type-generic-construction/sibling-values/txt
|%
++  source
  |=  lines=(list @t)
  ^-  @t
  (of-wain:format lines)
++  test-recursive-tree-owner
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/tree/jibb
  =/  ok=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner-positive) ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.ok)  ~[leaf+(trip message.p.ok)]
  =/  template=(unit ischeme:jibb)  (find-jibb-mold:jibb %node-tree iface.p.ok)
  ?~  template  ~[leaf+"recursive tree mold missing"]
  =/  applied=(unit [typ=itype:jibb sub=isub:jibb])  (template-apply-sub:jibb u.template ~[[%atom %t]] ~)
  ?~  applied  ~[leaf+"recursive tree mold did not instantiate"]
  ?^  (rg-unfold-view:jibb typ.u.applied 0)  ~[leaf+"recursive view ignored exhausted fuel"]
  =/  view=(unit [view=itype:jibb left=@ud])  (rg-unfold-view:jibb typ.u.applied 4.096)
  ?~  view  ~[leaf+"recursive tree view did not unfold"]
  ?.  ?=(%union -.view.u.view)  ~[leaf+"recursive tree view lost its cases"]
  =/  leaf-value=(unit ischeme:jibb)  (ienv-lookup:jibb %made-leaf values.iface.p.ok)
  =/  node-value=(unit ischeme:jibb)  (ienv-lookup:jibb %made-node values.iface.p.ok)
  ?~  leaf-value  ~[leaf+"recursive leaf missing"]
  ?~  node-value  ~[leaf+"recursive nested node missing"]
  =/  leaf-type=(unit itype:jibb)  (scheme-display-type:jibb u.leaf-value)
  =/  node-type=(unit itype:jibb)  (scheme-display-type:jibb u.node-value)
  ?~  leaf-type  ~[leaf+"recursive leaf type could not be realized"]
  ?~  node-type  ~[leaf+"recursive node type could not be realized"]
  ?.  =((show-itype:jibb u.leaf-type ~) "(node-tree @t)")  ~[leaf+"leaf type changed"]
  ?.  =((show-itype:jibb u.node-type ~) "(node-tree @t)")  ~[leaf+"node type changed"]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner-negative) ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%& -.bad)  ~[leaf+"wrong recursive field type was accepted"]
  ~
++  test-recursive-tree-bad-values
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/recursive-tree-bad/jibb
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb (source owner-positive)] [/ui/tree-two/jibb (source owner-positive)]]
  =/  cases=(list [name=@t code=@t])
    :~  ['wrong event' '++ bad ^- (node-tree.first @p) [%node event=text-event children=~]']
        ['wrong leaf' '++ bad ^- (node-tree.first @t) [%text value=~zod]']
        ['wrong label' '++ bad ^- (node-tree.first @t) [%text other="hi"]']
        ['unknown tag' '++ bad ^- (node-tree.first @t) [%missing value="hi"]']
        ['unresolved tag' '++ bad |= x=(node-tree.first @t) [%missing x]']
        ['foreign child' '++ bad |= x=(node-tree.second @t) ^- (node-tree.first @t) [%node event=text-event children=~[x]]']
        ['extra field' '++ bad ^- (node-tree.first @t) [%text value="hi" extra="bad"]']
        ['wrong child' '++ bad ^- (node-tree.first @t) [%node event=text-event children=~["bad"]]']
        ['wrong children' '++ bad ^- (node-tree.first @t) [%node event=text-event children="bad"]']
        ['swapped labels' '++ bad ^- (node-tree.first @t) [%node children=~ event=text-event]']
        ['foreign type' '++ bad |= x=(node-tree.second @p) ^- (node-tree.first @t) [%node event=text-event children=~[x]]']
        ['wrong argument' '++ bad |= x=(node-tree.first @p) ^- (node-tree.first @t) [%node event=text-event children=~[x]]']
    ==
  =/  failures=(list @t)
    %+  turn  cases
    |=  c=[name=@t code=@t]
    =/  input=@t  (source ~['/= first /ui/tree' '/= second /ui/tree-two' '++ text-event |= value=@t value' code.c])
    =/  result=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb file input ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
    ?:(?=(%& -.result) name.c '')
  =/  failures=(list @t)  (skim failures |=(name=@t !=(name '')))
  (turn failures |=(name=@t leaf+(weld (trip name) " was accepted")))
++  test-recursive-tree-aliases
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/recursive-tree-alias/jibb
  =/  modules=jbundle:jibb
    ~[[/ui/tree/jibb (source owner-positive)] [/ui/tree-two/jibb (source owner-positive)] [/ui/tree-alias/jibb (source alias)]]
  =/  input=@t
    (source ~['/= first /ui/tree' '/= via /ui/tree-alias' '++ text-event |= x=@t x' '++ ship-event |= x=@t ~zod' '++ via-leaf ^- (alias.via @t) [%text value="x"]' '++ via-node ^- (alias.via @p) [%node event=ship-event children=~]' '++ cross-alias |= x=(alias.via @t) ^- (node-tree.first @t) [%node event=text-event children=~[x]]' '++ keep-generic |= f=$-(@t A) ^- (node-tree.first A) [%node event=f children=~[[%text value="x"]]]'])
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file input ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  leaf-scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %via-leaf values.iface.p.result)
  =/  node-scheme=(unit ischeme:jibb)  (ienv-lookup:jibb %via-node values.iface.p.result)
  =/  cross=(unit ischeme:jibb)  (ienv-lookup:jibb %cross-alias values.iface.p.result)
  =/  generic=(unit ischeme:jibb)  (ienv-lookup:jibb %keep-generic values.iface.p.result)
  ?~  leaf-scheme  ~[leaf+"alias leaf missing"]
  ?~  node-scheme  ~[leaf+"alias node missing"]
  ?~  cross  ~[leaf+"same-origin alias use missing"]
  ?~  generic  ~[leaf+"generic constructor missing"]
  =/  leaf-type=(unit itype:jibb)  (scheme-display-type:jibb u.leaf-scheme)
  =/  node-type=(unit itype:jibb)  (scheme-display-type:jibb u.node-scheme)
  ?~  leaf-type  ~[leaf+"alias leaf type did not realize"]
  ?~  node-type  ~[leaf+"alias node type did not realize"]
  ?.  ?=(%mrec -.u.leaf-type)  ~[leaf+"alias leaf lost recursive identity"]
  ?.  ?=(%mrec -.u.node-type)  ~[leaf+"alias node lost recursive identity"]
  ?.  &(=(at.u.leaf-type /ui/tree/jibb) =(args.u.leaf-type ~[[%atom %t]]))
    ~[leaf+"alias leaf origin or argument changed"]
  ?.  &(=(at.u.node-type /ui/tree/jibb) =(args.u.node-type ~[[%atom %p]]))
    ~[leaf+"alias node origin or argument changed"]
  ?.  =(1 (lent vars.u.generic))  ~[leaf+"generic constructor lost its quantified parameter"]
  =/  bads=(list [name=@t src=@t])
    :~  ['alias foreign origin' '++ bad |= x=(node-tree.second @t) ^- (alias.via @t) [%node event=text-event children=~[x]]']
        ['alias wrong argument' '++ bad |= x=(alias.via @p) ^- (node-tree.first @t) [%node event=text-event children=~[x]]']
    ==
  =/  failures=(list @t)
    %+  turn  bads
    |=  item=[name=@t src=@t]
    =/  bad-source=@t  (source ~['/= first /ui/tree' '/= second /ui/tree-two' '/= via /ui/tree-alias' '++ text-event |= x=@t x' src.item])
    =/  bad=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb file bad-source ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
    ?:(?=(%& -.bad) name.item '')
  (turn (skim failures |=(name=@t !=(name ''))) |=(name=@t leaf+(weld (trip name) " was accepted")))
++  test-recursive-tree-no-event
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /tests/recursive-no-event/jibb
  =/  modules=jbundle:jibb
    ~[[/ui/tree/jibb (source tree-no-event)] [/ui/tree-two/jibb (source tree-no-event)]]
  =/  good=@t
    (source ~['/= first /ui/tree' '++ leaf ^- (node-tree.first @t) [%text value="x"]' '++ node ^- (node-tree.first @p) [%node children=~]' '++ nested ^- (node-tree.first @t) [%node children=~[[%text value="x"]]]' '++ generic |= x=A ^- (node-tree.first A) [%node children=~]'])
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file good ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  nested=(unit ischeme:jibb)  (ienv-lookup:jibb %nested values.iface.p.result)
  ?~  nested  ~[leaf+"nested recursive tree missing"]
  =/  nested-type=(unit itype:jibb)  (scheme-display-type:jibb u.nested)
  ?~  nested-type  ~[leaf+"nested recursive tree type did not realize"]
  ?.  ?=(%mrec -.u.nested-type)  ~[leaf+"nested recursive tree lost its identity"]
  ?.  &(=(at.u.nested-type /ui/tree/jibb) =(args.u.nested-type ~[[%atom %t]]))
    ~[leaf+"nested recursive tree changed origin or argument"]
  =/  bads=(list [name=@t src=@t])
    :~  ['foreign child' '++ bad |= x=(node-tree.second @t) ^- (node-tree.first @t) [%node children=~[x]]']
        ['wrong children' '++ bad ^- (node-tree.first @t) [%node children="x"]']
    ==
  =/  failures=(list @t)
    %+  turn  bads
    |=  item=[name=@t src=@t]
    =/  input=@t  (source ~['/= first /ui/tree' '/= second /ui/tree-two' src.item])
    =/  checked=jfile-detailed-result:jibb
      (infer-jibb-file-detailed:jibb file input ~ ~ modules ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
    ?:(?=(%& -.checked) name.item '')
  (turn (skim failures |=(name=@t !=(name ''))) |=(name=@t leaf+(weld (trip name) " was accepted")))
++  test-recursive-context-retry
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  file=path  /ui/tree/jibb
  =/  owner=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file (source owner-positive) ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.owner)  ~[leaf+(trip message.p.owner)]
  =/  template=(unit ischeme:jibb)  (find-jibb-mold:jibb %node-tree iface.p.owner)
  ?~  template  ~[leaf+"recursive mold missing"]
  =/  target=(unit itype:jibb)  (template-apply:jibb u.template ~[[%atom %t]])
  ?~  target  ~[leaf+"recursive mold did not instantiate"]
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/tree/values/jibb (source sibling-values))
  ?:  ?=(%| -.parsed)  ~[leaf+"recursive values failed to parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([* [* [* [* ~]]]] ds)  ~[leaf+"recursive fixture shape changed"]
  =/  first=def:jibb  i.ds
  =/  sibling=def:jibb  i.t.t.t.ds
  ?.  &(?=(%value -.first) ?=(%value -.sibling))  ~[leaf+"recursive values missing"]
  =/  env=ienv:jibb  ~[[%text-event [[%fn [%atom %t] [%atom %t]] ~ ~]]]
  =/  tag=ipending:jibb  [100 [%term %tas %unrelated '%unrelated'] *span:jibb]
  =/  projection=iwprojection:jibb  *iwprojection:jibb
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(next 201, prelude `iface.u.prepared, tags ~[tag], holes ~[[99 (span-of:jibb val.first)]], projections ~[projection])
  =/  failed=iresult:jibb  (infer-call-context-arg:jibb val.first u.target env state(jrec-fuel 0) (span-of:jibb val.first))
  =/  retry-failed=iresult:jibb  (infer-call-context-arg:jibb val.first u.target env state(jrec-fuel 0) (span-of:jibb val.first))
  ?.  ?=(%| -.failed)  ~[leaf+"exhausted recursive fuel was accepted"]
  ?.  =(failed retry-failed)  ~[leaf+"failed recursive retry changed its result"]
  =/  successful=iresult:jibb  (infer-call-context-arg:jibb val.first u.target env state(jrec-fuel 4.096) (span-of:jibb val.first))
  =/  retry=iresult:jibb  (infer-call-context-arg:jibb val.first u.target env state(jrec-fuel 4.096) (span-of:jibb val.first))
  ?:  ?=(%| -.successful)  ~[leaf+"recursive constructor did not infer"]
  ?.  =(successful retry)  ~[leaf+"recursive retry changed its result"]
  ?.  =(typ.p.successful u.target)  ~[leaf+"recursive construction lost nominal identity"]
  ?.  (lien tags.state.p.successful |=(entry=ipending:jibb =(entry tag)))  ~[leaf+"unrelated pending tag was lost"]
  ?.  =(holes.state holes.state.p.successful)  ~[leaf+"unrelated pending hole was lost"]
  ?.  =(projections.state projections.state.p.successful)  ~[leaf+"projection evidence was lost"]
  =/  siblings=iresult:jibb  (infer-call-context-arg:jibb val.sibling u.target env state(jrec-fuel 4.096) (span-of:jibb val.sibling))
  ?:  ?=(%| -.siblings)  ~[leaf+"recursive siblings did not infer"]
  ?.  (lth jrec-fuel.state.p.siblings 4.096)  ~[leaf+"recursive siblings did not spend their shared budget"]
  ~
--
