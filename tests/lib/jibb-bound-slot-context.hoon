::  Bound variables still denote only the type under an expected slot.
/+  jibb
/*  source  %jibb  /tests/golden/generic-bound-union-slot/source/jibb
|%
++  test-bound-union-slot
  ^-  tang
  =/  choice=itype:jibb  [%union ~[[%const [%term %tas %yes '%yes']] [%const [%term %tas %no '%no']]] `[/tests/slot/jibb %choice] `%choice ~]
  ?>  ?=(%union -.choice)
  =/  other=itype:jibb  choice(origin `[/tests/other/jibb %choice])
  =/  sub=isub:jibb  (isub-from-bindings:jibb ~[[0 choice]])
  =/  widened=ifit:jibb  (itype-fit:jibb [%var 0] [%slot %kid [%noun ~]] sub 1)
  ?.  ?=(%ok -.widened)  ~[leaf+"bound union did not fit a noun sample slot"]
  =/  matching=ifit:jibb  (itype-fit:jibb [%var 0] [%slot %kid choice] sub 1)
  ?.  ?=(%ok -.matching)  ~[leaf+"bound union did not fit its own nominal slot"]
  =/  mismatch=ifit:jibb  (itype-fit:jibb [%var 0] [%slot %kid other] sub 1)
  ?:  ?=(%ok -.mismatch)  ~[leaf+"slot fit erased a distinct union origin"]
  =/  labels=ifit:jibb  (itype-fit:jibb [%slot %left choice] [%slot %right choice] sub 1)
  ?:  ?=(%ok -.labels)  ~[leaf+"slot fit erased an explicit conflicting label"]
  =/  faces=ifit:jibb  (itype-fit:jibb [%face %left choice] [%face %right choice] sub 1)
  ?:  ?=(%ok -.faces)  ~[leaf+"slot fit erased an explicit conflicting value face"]
  ~
++  test-generic-union-constructor-core
  ^-  tang
  =/  at=path  /tests/slot/jibb
  =/  parsed  (parse:jibb at source)
  ?:  ?=(%| -.parsed)  ~[leaf+(trip (show-error:jibb source p.parsed))]
  =/  molds=imolds:jibb  (collect-simple-molds:jibb defs.p.parsed)
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at at, molds molds, top-molds ~[%node], globals (global-value-names:jibb defs.p.parsed), in-mold |, jrec-fuel 256)
  =/  checked=(unit iresolved:jibb)  (icore-resolve:jibb defs.p.parsed state)
  ?~  checked  ~[leaf+"generic union constructor did not resolve in the shared core"]
  =/  wrapped=(unit ischeme:jibb)  (ienv-lookup:jibb %wrapped env.u.checked)
  ?~  wrapped  ~[leaf+"generic union result missing"]
  =/  typ=(unit itype:jibb)  (scheme-display-type:jibb u.wrapped)
  ?~  typ  ~[leaf+"generic union graph did not close"]
  ?.  =("(node @t)" (show-itype:jibb u.typ ~))
    ~[leaf+"generic union lost its nominal context"]
  =/  ship=(unit ischeme:jibb)  (ienv-lookup:jibb %wrapped-ship env.u.checked)
  ?~  ship  ~[leaf+"independent ship instantiation missing"]
  =/  ship-type=(unit itype:jibb)  (scheme-display-type:jibb u.ship)
  ?~  ship-type  ~[leaf+"ship instantiation graph did not close"]
  ?.  =("(node @p)" (show-itype:jibb u.ship-type ~))
    ~[leaf+"independent ship instantiation lost its nominal context"]
  =/  constructor=(unit ischeme:jibb)  (ienv-lookup:jibb %wrap-node env.u.checked)
  ?~  constructor  ~[leaf+"generic constructor missing"]
  ?.  ?=([@ ~] vars.u.constructor)
    ~[leaf+"constructor was specialized by a caller"]
  =/  constructor-type=(unit itype:jibb)  (scheme-display-type:jibb u.constructor)
  ?~  constructor-type  ~[leaf+"generic constructor graph did not close"]
  =/  generic-type=itype:jibb  (canonical-itype:jibb u.constructor-type vars.u.constructor)
  ?.  =("$-((node M) (node M))" (show-itype:jibb generic-type ~))
    ~[leaf+"constructor lost its shared generic parameter"]
  ~
++  test-recursive-positional-labels
  ^-  tang
  =/  site=span:jibb  [[1 1] [3 18]]
  =/  key=gkey:jibb  [/tests/recursive-slots/jibb site %trail]
  =/  nil=gnode:jibb  [%const [%null %n 0 '~']]
  =/  body=gnode:jibb  [%union ~[nil [%cell [%atom %ta] [%ref key ~]]]]
  =/  graph=(map gkey:jibb gdef:jibb)
    (~(put by *(map gkey:jibb gdef:jibb)) key [site & ~ ~ body])
  =/  trail=itype:jibb  [%mrec at.key site %trail `%trail graph ~]
  =/  direct=ifit:jibb  (itype-fit:jibb trail [%slot %source trail] ~ 0)
  ?.  ?=(%ok -.direct)  ~[leaf+"recursive value did not fit its positional label"]
  =/  faced=ifit:jibb  (itype-fit:jibb [%face %value trail] trail ~ 0)
  ?.  ?=(%ok -.faced)  ~[leaf+"recursive value face hid its canonical type"]
  =/  sub=isub:jibb  (isub-from-bindings:jibb ~[[0 trail]])
  =/  bound=ifit:jibb  (itype-fit:jibb [%var 0] [%slot %source trail] sub 1)
  ?.  ?=(%ok -.bound)  ~[leaf+"bound recursive value did not fit its positional label"]
  ?>  ?=(%mrec -.trail)
  =/  foreign=itype:jibb  trail(at /tests/foreign-slots/jibb)
  =/  wrong=ifit:jibb  (itype-fit:jibb trail [%slot %source foreign] ~ 0)
  ?:  ?=(%ok -.wrong)  ~[leaf+"positional label erased a recursive origin"]
  =/  labels=ifit:jibb  (itype-fit:jibb [%slot %left trail] [%slot %right trail] ~ 0)
  ?:  ?=(%ok -.labels)  ~[leaf+"recursive fit erased conflicting positional labels"]
  ~
--
