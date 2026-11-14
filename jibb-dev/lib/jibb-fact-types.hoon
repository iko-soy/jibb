::  Recover an imported recursive fact's body from its checked reader evidence.
::  Names and display labels alone never supply a representation. Only an exact
::  /sur reader binding or an explicit named boundary can authenticate a body.
/+  jibb
|%
+$  found  (each (unit *) @t)
::
++  merge-found
  |=  [left=found right=found]
  ^-  found
  ?:  ?=(%| -.left)  left
  ?:  ?=(%| -.right)  right
  ?~  p.left  right
  ?~  p.right  left
  ?.  =(u.p.left u.p.right)
    [%| 'conflicting authenticated recursive mold bodies']
  left
::
::  Traverse only descriptor constructors. Unsupported unrelated reader inputs
::  are irrelevant; a matching boundary is validated in full before expansion.
++  named-body
  |=  [node=* module=term name=term]
  ^-  found
  ?@  node  [%& ~]
  ?+  -.node  [%& ~]
    %named
      ?.  ?=([%named @ @ *] node)  [%& ~]
      =/  n=[%named module=@ name=@ body=*]
        ;;([%named module=@ name=@ body=*] node)
      =/  own=found
        ?:  &(=(module module.n) =(name name.n))  [%& `body.n]
        [%& ~]
      (merge-found own $(node body.n))
    %face
      ?.  ?=([%face @ *] node)  [%& ~]
      $(node +>.node)
    %cell
      ?.  ?=([%cell * *] node)  [%& ~]
      (merge-found $(node +<.node) $(node +>.node))
    %fork  (named-bodies +.node module name)
    %apply
      ?.  ?=([%apply @ *] node)  [%& ~]
      (named-bodies +>.node module name)
  ==
::
++  named-bodies
  |=  [nodes=* module=term name=term]
  ^-  found
  ?@  nodes  [%& ~]
  (merge-found (named-body -.nodes module name) $(nodes +.nodes))
::
++  external-bodies
  |=  [externals=iexternals:jibb module=term name=term]
  ^-  found
  ?~  externals  [%& ~]
  =/  result=*  result.i.externals
  =/  here=found
    ?@  result  [%& ~]
    ?.  ?=(%& -.result)  [%& ~]
    (named-body +.result module name)
  (merge-found here $(externals t.externals))
::
++  mark-bodies
  |=  [marks=imark-externals:jibb module=term name=term]
  ^-  found
  ?~  marks  [%& ~]
  =/  result=*  result.i.marks
  =/  here=found
    ?@  result  [%& ~]
    ?.  ?=(%& -.result)  [%& ~]
    =/  payload=*  +.result
    ?@  payload  [%& ~]
    ::  Guard the wrapper's axes before using the shared reader accessor.
    ?:  &(?=(%mark-source -.payload) !?=([%mark-source * *] payload))
      [%& ~]
    =/  body=(unit *)  (imported-mark-body:jibb result)
    ?~  body  [%& ~]
    (named-body u.body module name)
  (merge-found here $(marks t.marks))
::
++  external-root
  |=  [externals=iexternals:jibb module=term name=term]
  ^-  found
  =/  roots=iexternals:jibb
    (skim externals |=(e=[module=term name=term result=*] &(=(module module.e) =(name name.e))))
  ?~  roots  [%& ~]
  ?^  t.roots  [%| 'ambiguous authenticated recursive mold binding']
  =/  result=*  result.i.roots
  ?@  result  [%& ~]
  ?.  ?=(%& -.result)  [%& ~]
  =/  body=*  +.result
  ::  Match the same root rule as +find-imported-mold-prelude. A named
  ::  descriptor instead supplies its own owner through +named-body.
  =/  proof=(unit irec-pattern:jibb)  (rec-pattern:jibb body module name)
  ?~  proof  [%& ~]
  ?.  has.u.proof  [%& ~]
  [%& `body]
::
::  Convert one authenticated unfolding. Its complete root was already checked
::  by +rec-pattern, including disjoint forks, exact references, and arities.
::  Keep nominal references intact so the validator can close its own cycles.
++  body-type
  |=  [node=* root=itype:jibb]
  ^-  (unit itype:jibb)
  ?.  ?=(%recursive -.root)  ~
  ?@  node  ~
  ?+  -.node  (import-to-itype:jibb node)
    %ref
      ?.  ?=([%ref @ @] node)  ~
      ?.  &(=(module.root +<.node) =(name.root +>.node))  ~
      `root
    %named
      =/  typ=(unit itype:jibb)  (import-to-itype:jibb node)
      ?~  typ  ~
      ?.  ?=(%recursive -.u.typ)  ~
      ?:  &(=(module.root module.u.typ) =(name.root name.u.typ))  `root
      typ
    %face
      ?.  ?=([%face @ *] node)  ~
      ?.  (jibb-face-name:jibb +<.node)  ~
      =/  body=(unit itype:jibb)  $(node +>.node)
      ?~  body  ~
      `[%face (@tas +<.node) u.body]
    %cell
      ?.  ?=([%cell * *] node)  ~
      =/  left=(unit itype:jibb)  $(node +<.node)
      ?~  left  ~
      =/  right=(unit itype:jibb)  $(node +>.node)
      ?~  right  ~
      =/  head=itype:jibb  u.left
      =/  tail=itype:jibb  u.right
      =?  head  ?=(%face -.head)  [%slot name.head body.head]
      =?  tail  ?=(%face -.tail)  [%slot name.tail body.tail]
      `[%cell head tail]
    %fork
      ::  Preserve the reader bridge's special representation of Hoon ?.
      ?:  |(=(+.node ~[[%atom %f `0] [%atom %f `1]]) =(+.node ~[[%atom %f `1] [%atom %f `0]]))
        `[%flag ~]
      =/  cases=(unit (list itype:jibb))  (body-types +.node root)
      ?~  cases  ~
      ?~  u.cases  ~
      ?~  t.u.cases  ~
      `[%union u.cases ~ ~ ~]
    %apply
      ?.  ?=([%apply @ *] node)  ~
      =/  name=term  (@tas +<.node)
      =/  arity=@ud
        ?:  ?=(?(%list %unit %set %qeu) name)  1
        ?:  ?=(?(%map %mop %jar %jug) name)  2
        0
      ?:  =(arity 0)  ~
      =/  args=(unit (list itype:jibb))  (body-types +>.node root)
      ?~  args  ~
      ?.  =(arity (lent u.args))  ~
      ::  +rec-pattern admits no gates or opaque values, including through
      ::  this root's references. Do not treat a nominal key as an open type.
      `[%collection name u.args]
  ==
::
++  body-types
  |=  [nodes=* root=itype:jibb]
  ^-  (unit (list itype:jibb))
  ?@  nodes  ?:(=(nodes 0) `~ ~)
  =/  first=(unit itype:jibb)  (body-type -.nodes root)
  ?~  first  ~
  =/  rest=(unit (list itype:jibb))  $(nodes +.nodes)
  ?~  rest  ~
  `[u.first u.rest]
::
++  recursive-view
  |=  [typ=itype:jibb externals=iexternals:jibb marks=imark-externals:jibb]
  ^-  (each itype:jibb @t)
  ?.  ?=(%recursive -.typ)  [%| 'expected an imported recursive mold']
  =/  root=found  (external-root externals module.typ name.typ)
  =/  named=found  (external-bodies externals module.typ name.typ)
  =/  marked=found  (mark-bodies marks module.typ name.typ)
  =/  found=found  (merge-found root (merge-found named marked))
  ?:  ?=(%| -.found)  [%| p.found]
  ?~  p.found  [%| 'recursive mold has no authenticated reader body']
  =/  body=*  u.p.found
  ?.  (imported-faces-valid:jibb body)
    [%| 'recursive mold reader body has malformed or repeated fields']
  =/  proof=(unit irec-pattern:jibb)  (rec-pattern:jibb body module.typ name.typ)
  ?~  proof  [%| 'recursive mold reader body is unsupported']
  ?.  has.u.proof  [%| 'recursive mold reader body has no matching recursive reference']
  =/  view=(unit itype:jibb)  (body-type body typ)
  ?~  view  [%| 'recursive mold reader body could not be expanded']
  [%& u.view]
--
