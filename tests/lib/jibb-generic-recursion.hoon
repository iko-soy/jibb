::  Source-backed recursive identities; this is not a runtime element model.
/+  jibb
/*  real-prelude     %jibb  /lib/jibb/prelude/jibb
/*  real-internal    %jibb  /lib/jibb/internal/jibb
/*  tree             %txt   /tests/type-generic-recursion/tree/txt
/*  changed          %txt   /tests/type-generic-recursion/tree-changed/txt
/*  alias            %txt   /tests/type-generic-recursion/alias/txt
/*  client           %txt   /tests/type-generic-recursion/client/txt
/*  bad-mold         %txt   /tests/type-generic-recursion/bad-mold/txt
/*  bad-constructor  %txt   /tests/type-generic-recursion/bad-constructor/txt
/*  bad-parameter    %txt   /tests/type-generic-recursion/bad-parameter/txt
/*  local-shadow     %txt   /tests/type-generic-recursion/local-shadow/txt
/*  local-distinct   %txt   /tests/type-generic-recursion/local-distinct/txt
/*  local-only       %txt   /tests/type-generic-recursion/local-only/txt
/*  list-shadow      %txt   /tests/type-generic-recursion/list-shadow/txt
/*  chain            %txt   /tests/type-generic-recursion/chain/txt
/*  bad-match        %txt   /tests/type-generic-recursion/bad-match/txt
/*  expected         %txt   /tests/type-generic-recursion/expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  altered-list-source
  |=  pre=@t
  ^-  (unit @t)
  =/  lines=wain  (to-wain:format pre)
  =/  old=@t  '  [i=A t=(list A)]'
  =/  matches=(list @t)  (skim lines |=(line=@t =(line old)))
  ?.  =(1 (lent matches))  ~
  =/  changed=wain  (turn lines |=(line=@t ?:(=(line old) '  [i=@t t=(list A)]' line)))
  `(text changed)
++  result-line
  |=  [label=@t ok=?]
  ^-  @t
  (crip "{(trip label)}: {?:(ok "ok" "BAD")}")
++  generic-output
  |=  [pre=@t internal=@t tree=@t changed=@t alias=@t client=@t invalid=(list [label=@t src=@t]) shadow=@t chain=@t]
  ^-  @t
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb pre internal)
  ?~  prep  'BAD prelude preparation'
  =/  module=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb tree ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.module)  (cat 3 'BAD recursive module: ' p.module)
  =/  scheme=(unit ischeme:jibb)  (find-jibb-mold:jibb %element iface.p.module)
  ?~  scheme  'BAD missing recursive mold'
  ?.  ?=(%grec -.typ.u.scheme)  'BAD missing recursive identity'
  =/  typ=itype:jibb  typ.u.scheme
  ?>  ?=(%grec -.typ)
  =/  t=itype:jibb  typ(args ~[[%atom %t]])
  ?>  ?=(%grec -.t)
  =/  p=itype:jibb  typ(args ~[[%atom %p]])
  =/  variable=itype:jibb  typ(args ~[[%var 91]])
  =/  other=itype:jibb  t(at /ui/other/jibb)
  =/  numeric=itype:jibb  [%cell t [%nvar 99]]
  =/  chain-parsed=(each module:jibb error:jibb)  (parse:jibb /ui/tree/jibb chain)
  ?:  ?=(%| -.chain-parsed)  'BAD chain source parse'
  =/  chain-molds=imolds:jibb  (collect-simple-molds:jibb defs.p.chain-parsed)
  =/  chain-shape=(unit shape:jibb)  (find-simple-mold:jibb %chain chain-molds)
  ?~  chain-shape  'BAD chain source mold'
  =/  no-index=istate:jibb  *istate:jibb
  =.  no-index  no-index(at /ui/tree/jibb, molds chain-molds, top-molds ~[%chain], prelude `iface.u.prep)
  =/  checks=(list [label=@t ok=?])
    :~  ['source module complete' ?=([%& *] module)]
        ['generic mold quantified' =(1 (lent vars.u.scheme))]
        ['distinct arguments decline' ?=(~ (itype-unify:jibb t p ~))]
        ['distinct origins decline' ?=(~ (itype-unify:jibb t other ~))]
        ['occurs check' ?=(~ (itype-unify:jibb [%var 91] variable ~))]
        ['cell construction stays opaque' =(%unknown -:(itype-fit:jibb [%cell [%atom %tas] [%atom %t]] t ~ 0))]
        ['noun construction stays opaque' =(%unknown -:(itype-fit:jibb [%noun ~] t ~ 0))]
        ['unindexed recursion declined' ?=(~ (simple-source-generic-recursive:jibb %chain u.chain-shape ~[[%atom %t]] no-index))]
        ['alteration rejects missing line' ?=(~ (altered-list-source 'absent'))]
        ['alteration rejects repeated line' ?=(~ (altered-list-source (text ~['  [i=A t=(list A)]' '  [i=A t=(list A)]'])))]
        ['gate freedom unknown' =(%unknown verdict:(gate-free-type:jibb t 64 ~))]
        ['gate defaulting conservative' &((itype-has-gate:jibb t) =(numeric (default-decimals:jibb numeric)))]
    ==
  =/  invalid-lines=(list @t)
    %+  turn  invalid
    |=  c=[label=@t src=@t]
    =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/tree/jibb src.c)
    =/  r=jfile-result:jibb
      (infer-jibb-file:jibb /ui/tree/jibb src.c ~ ~ ~ ~[/ui/tree/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
    (result-line label.c &(?=(%& -.parsed) ?=(%| -.r)))
  =/  shadow-result=jfile-result:jibb
    (infer-jibb-file:jibb /ui/tree/jibb shadow ~ ~ ~ ~[/ui/tree/jibb] values.u.prep ~ ~ `iface.u.prep)
  =/  altered-source=(unit @t)  (altered-list-source pre)
  ?~  altered-source  'BAD canonical list source was missing or repeated'
  =/  altered=@t  u.altered-source
  =/  altered-prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb altered internal)
  =/  altered-result=jfile-result:jibb
    ?~  altered-prep  [%| 'altered prelude unavailable']
    (infer-jibb-file:jibb /ui/tree/jibb tree ~ ~ ~ ~[/ui/tree/jibb] values.u.altered-prep molds.u.altered-prep ~ `iface.u.altered-prep)
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /tests/tree/client/jibb client)
  ?:  ?=(%| -.parsed)  'BAD client parse'
  =/  modules=jbundle:jibb  ~[[/ui/tree/jibb tree] [/ui/tree-two/jibb tree] [/ui/tree-alias/jibb alias]]
  =/  first=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%| -.first)  'BAD import resolution'
  =/  reuse=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep cache.p.first `iface.u.prep)
  =/  changed-modules=jbundle:jibb  ~[[/ui/tree/jibb changed] [/ui/tree-two/jibb tree] [/ui/tree-alias/jibb alias]]
  =/  stale=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ changed-modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep cache.p.first `iface.u.prep)
  =/  fresh=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ changed-modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  =/  duplicate-modules=jbundle:jibb  [[/ui/tree/jibb tree] modules]
  =/  duplicate=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ duplicate-modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep cache.p.first `iface.u.prep)
  =/  cycle=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ modules ~[/ui/tree/jibb] values.u.prep molds.u.prep cache.p.first `iface.u.prep)
  =/  prelude-other=ifile:jibb  iface.u.prep(source ~)
  =/  mismatch=jimports-result:jibb
    (resolve-jibb-imports:jibb imports.p.parsed ~ ~ modules ~[/tests/tree/client/jibb] values.u.prep molds.u.prep cache.p.first `prelude-other)
  =/  old=(unit ifile:jibb)  (find-jibb-interface:jibb %first resolved.p.first)
  =/  new=(unit ifile:jibb)  ?:(?=(%& -.fresh) (find-jibb-interface:jibb %first resolved.p.fresh) ~)
  =/  shape-changed=?
    ?~  old  |
    ?~  new  |
    =/  a=(unit ischeme:jibb)  (find-jibb-mold:jibb %element u.old)
    =/  b=(unit ischeme:jibb)  (find-jibb-mold:jibb %element u.new)
    ?~  a  |
    ?~  b  |
    ?.  &(?=(%grec -.typ.u.a) ?=(%grec -.typ.u.b))  |
    !=(proof.typ.u.a proof.typ.u.b)
  =/  reuse-ok=?  ?:(?=(%| -.reuse) | =(resolved.p.first resolved.p.reuse))
  =/  shadow-parsed=(each module:jibb error:jibb)  (parse:jibb /ui/tree/jibb shadow)
  =/  altered-parsed=(each module:jibb error:jibb)  (parse:jibb /lib/jibb/prelude/jibb altered)
  =/  more=(list [label=@t ok=?])
    :~  ['unreserved local list shadow declined' &(?=(%& -.shadow-parsed) ?=(%| -.shadow-result))]
        ['altered prelude list declined' &(?=(%& -.altered-parsed) ?=(%| -.altered-result))]
        ['cached source reuse' reuse-ok]
        ['changed source invalidates cache' ?=(%| -.stale)]
        ['changed source fresh proof' &(?=(%& -.fresh) shape-changed)]
        ['duplicate source declined' ?=(%| -.duplicate)]
        ['active import cycle declined' ?=(%| -.cycle)]
        ['changed prelude invalidates cache' ?=(%| -.mismatch)]
    ==
  =/  lines=(list @t)  (weld (turn checks result-line) (weld invalid-lines (turn more result-line)))
  =/  report=@t  (golden-types-with-prepared-prelude:jibb /tests/tree/client/jibb client ~ ~ modules prep)
  (cat 3 (of-wain:format lines) (cat 3 '\0a' report))
++  test-generic-recursion
  ^-  tang
  ?~  tree  ~[leaf+"recursive source is missing"]
  ?~  changed  ~[leaf+"changed recursive source is missing"]
  ?~  alias  ~[leaf+"recursive alias is missing"]
  ?~  client  ~[leaf+"recursive client is missing"]
  ?~  bad-mold  ~[leaf+"invalid mold fixture is missing"]
  ?~  bad-constructor  ~[leaf+"constructor fixture is missing"]
  ?~  bad-match  ~[leaf+"match fixture is missing"]
  ?~  bad-parameter  ~[leaf+"parameter fixture is missing"]
  ?~  local-shadow  ~[leaf+"local shadow fixture is missing"]
  ?~  local-distinct  ~[leaf+"distinct local shadow fixture is missing"]
  ?~  local-only  ~[leaf+"local recursion fixture is missing"]
  ?~  list-shadow  ~[leaf+"list shadow fixture is missing"]
  ?~  chain  ~[leaf+"unindexed chain fixture is missing"]
  ?~  expected  ~[leaf+"recursive expected output is missing"]
  =/  invalid=(list [label=@t src=@t])
    :~  ['unused mold hole declined' (text bad-mold)]
        ['invalid constructor declined' (text bad-constructor)]
        ['invalid matching declined' (text bad-match)]
        ['nonuniform recursion declined' (text bad-parameter)]
        ['identical local shadow declined' (text local-shadow)]
        ['different local shadow declined' (text local-distinct)]
        ['local recursion declined' (text local-only)]
    ==
  =/  actual=@t  (generic-output real-prelude real-internal (text tree) (text changed) (text alias) (text client) invalid (text list-shadow) (text chain))
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+"generic recursion output differs from expected"]
  ~
--
