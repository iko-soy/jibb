::  Unification compresses paths without mutating an abandoned state.
/+  jibb
|%
++  test-find
  ^-  tang
  =/  initial=istate:jibb  *istate:jibb
  ?:  |(globals-imports.initial general-defer.initial)
    ~[leaf+"inference modes must be disabled in a fresh state"]
  =/  source=isub:jibb  (isub-from-bindings:jibb ~[[0 [%var 1]] [1 [%var 2]] [2 [%atom %t]]])
  =/  found=[typ=itype:jibb sub=isub:jibb]  (itype-find:jibb [%var 0] source)
  ?.  =(typ.found [%atom %t])  ~[leaf+"find returned the wrong root"]
  ?.  =((itype-lookup:jibb 0 sub.found) `[%var 2])  ~[leaf+"find did not compress to the root variable"]
  ?.  =((itype-lookup:jibb 1 sub.found) `[%var 2])  ~[leaf+"find changed a direct root edge"]
  =/  again=[typ=itype:jibb sub=isub:jibb]  (itype-find:jibb [%var 0] sub.found)
  ?.  =(sub.again sub.found)  ~[leaf+"finding a compressed path changed it again"]
  ?.  =((itype-lookup:jibb 0 source) `[%var 1])  ~[leaf+"find changed its input"]
  =/  refined=isub:jibb  (itype-bind:jibb 2 [%face %name [%atom %t]] sub.found)
  ?.  =((itype-walk:jibb [%var 0] refined) [%face %name [%atom %t]])
    ~[leaf+"compression disconnected a later root refinement"]
  =/  constrained=isub:jibb  (isub-from-bindings:jibb ~[[0 [%var 1]] [1 [%fvar 1]]])
  =/  free=[typ=itype:jibb sub=isub:jibb]  (itype-find:jibb [%var 0] constrained)
  ?.  =(typ.free [%fvar 1])  ~[leaf+"find lost a gate-free root"]
  =/  through=(unit isub:jibb)  (itype-unify:jibb [%var 2] [%var 0] constrained)
  ?~  through  ~[leaf+"unification lost a constrained root"]
  ?.  =((itype-walk:jibb [%var 2] u.through) [%fvar 1])
    ~[leaf+"a gate-free restriction was lost through an alias"]
  =/  pending=isub:jibb  (isub-from-bindings:jibb ~[[0 [%var 1]]])
  ?.  ?=(^ (itype-unify:jibb [%var 1] [%var 0] pending))
    ~[leaf+"unifying an alias with its own root failed"]
  ?:  ?=(^ (itype-unify:jibb [%var 0] [%fn [%var 1] [%atom %t]] pending))
    ~[leaf+"occurs check accepted a cycle through an alias"]
  ?.  =((itype-lookup:jibb 0 pending) `[%var 1])  ~[leaf+"failed unification changed its input"]
  =/  levels=(map @ud @ud)  (ilevel-register:jibb 2 3 2 ~)
  =.  levels  (ilevel-register:jibb 0 3 1 levels)
  ?.  =((~(get by levels) 2) `2)  ~[leaf+"outer registration changed an inner allocation"]
  =/  lowered=[levels=(map @ud @ud) seen=(map @ud @ud)]
    (ilevel-lower-tree:jibb (named-var:jibb 'A' 2) 0 ~ levels ~)
  =.  levels  levels.lowered
  ?.  =((~(get by levels) 2) `0)  ~[leaf+"captured variable level was not lowered"]
  =/  nested-levels=(map @ud @ud)  (ilevel-register:jibb 1 3 2 ~)
  =/  nested-sub=isub:jibb  (isub-from-bindings:jibb ~[[0 [%cell [%var 1] [%var 2]]]])
  =.  nested-levels  (ilevel-propagate:jibb nested-sub nested-sub nested-levels)
  ?.  &(=((~(get by nested-levels) 1) `0) =((~(get by nested-levels) 2) `0))
    ~[leaf+"binding an outer variable did not lower its contained variables"]
  =/  pair=itype:jibb  [%cell [%atom %t] [%atom %p]]
  =/  linked=(unit isub:jibb)  (itype-unify:jibb [%var 0] [%var 1] (isub-from-bindings:jibb ~[[0 pair]]))
  ?~  linked  ~[leaf+"a variable did not link to a bound root"]
  ?.  =((itype-lookup:jibb 1 u.linked) `[%var 0])
    ~[leaf+"unification copied a structural binding instead of linking it"]
  =/  fitted=ifit:jibb  (itype-fit:jibb [%var 0] [%var 1] (isub-from-bindings:jibb ~[[0 pair]]) 2)
  ?.  ?=(%ok -.fitted)  ~[leaf+"fit did not link a bound root"]
  ?.  =((itype-lookup:jibb 1 sub.fitted) `[%var 0])
    ~[leaf+"fit copied a structural binding instead of linking it"]
  ~
++  test-level-index
  ^-  tang
  =/  levels=(map @ud @ud)  (~(put by *(map @ud @ud)) 0 0)
  =.  levels  (~(put by levels) 1 2)
  =.  levels  (~(put by levels) 2 3)
  =/  initial=istate:jibb  *istate:jibb
  =.  initial  initial(sub (isub-from-bindings:jibb ~[[0 [%var 1]]]), levels levels)
  =/  first=istate:jibb  (ilevel-refresh:jibb initial)
  ?.  =((~(get by levels.first) 1) `0)  ~[leaf+"initial index did not lower an alias"]
  ?.  =((~(get by sub-index.first) 0) `[%var 1])  ~[leaf+"initial index lost a binding"]
  =/  extended=istate:jibb  first(sub (itype-bind:jibb 1 [%cell [%var 2] [%atom %t]] sub.first))
  =/  next=istate:jibb  (ilevel-refresh:jibb extended)
  ?.  =((~(get by levels.next) 2) `0)  ~[leaf+"new binding did not lower its contained variable"]
  ?.  =((~(get by sub-index.next) 1) `[%cell [%var 2] [%atom %t]])
    ~[leaf+"incremental index missed the new binding"]
  =/  branch=istate:jibb  next(sub (isub-from-bindings:jibb ~[[2 [%atom %p]]]))
  =/  rebuilt=istate:jibb  (ilevel-refresh:jibb branch)
  ?.  ?=(~ (~(get by sub-index.rebuilt) 0))  ~[leaf+"transactional rebuild retained a discarded binding"]
  ?.  =((~(get by sub-index.rebuilt) 2) `[%atom %p])  ~[leaf+"transactional rebuild lost its binding"]
  =/  a=@ud  (named-var:jibb 'A' 4)
  =/  b=@ud  (named-var:jibb 'B' 4)
  =/  shared=(map @ud @ud)  (~(put by *(map @ud @ud)) 0 0)
  =.  shared  (~(put by shared) 4 3)
  =.  shared  (~(put by shared) 5 3)
  =.  shared  (~(put by shared) 6 3)
  =/  named=istate:jibb  *istate:jibb
  =.  named  (ilevel-refresh:jibb named(sub (isub-from-bindings:jibb ~[[a [%var 5]] [b [%var 6]]]), levels shared))
  =.  named  (ilevel-refresh:jibb named(sub (itype-bind:jibb 0 [%var a] sub.named)))
  ?.  &(=(`0 (~(get by levels.named) 5)) =(`0 (~(get by levels.named) 6)))
    ~[leaf+"lowering a shared allocation did not visit all named bindings"]
  ~
--
