::  Check restricted numeric unifier invariants under eval and ship.
/+  jibb
|%
++  arithmetic-guard-errors
  ^-  (list tape)
  =/  one=(unit isub:jibb)  (itype-unify:jibb [%rvar 0] [%nvar 1] ~)
  =/  two=(unit isub:jibb)  (itype-unify:jibb [%nvar 1] [%rvar 0] ~)
  ?~  one  ~["restricted-then-numeric merge failed"]
  ?~  two  ~["numeric-then-restricted merge failed"]
  =/  left=itype:jibb  (itype-walk:jibb [%rvar 0] u.one)
  =/  right=itype:jibb  (itype-walk:jibb [%nvar 1] u.one)
  =/  rleft=itype:jibb  (itype-walk:jibb [%rvar 0] u.two)
  =/  rright=itype:jibb  (itype-walk:jibb [%nvar 1] u.two)
  =/  bound=(unit isub:jibb)  (itype-unify:jibb left [%atom %ux] u.one)
  =/  extra=(unit isub:jibb)  (itype-unify:jibb right [%nvar 2] u.one)
  ?~  bound  ~["combined variable did not bind to a concrete aura"]
  ?~  extra  ~["second numeric variable did not merge"]
  =/  checks=(list ?)
    :~  ?=(%rnvar -.left)
        =(left right)
        =(rleft rright)
        ?=(%rnvar -.rleft)
        =(left (itype-walk:jibb left u.one))
        ?=(~ (itype-unify:jibb left [%flag ~] u.one))
        ?=(~ (itype-unify:jibb left [%any-atom ~] u.one))
        =([%atom %ux] (itype-walk:jibb [%rvar 0] u.bound))
        =([%atom %ux] (itype-walk:jibb [%nvar 1] u.bound))
        =(left (itype-walk:jibb [%nvar 2] u.extra))
    ==
  ?:  (levy checks |=(ok=? ok))  arithmetic-face-guard-errors
  ~["combined numeric/restricted substitution invariant failed"]
++  arithmetic-face-guard-errors
  ^-  (list tape)
  =/  text=itype:jibb  [%face %outer [%face %inner [%atom %t]]]
  =/  broad=itype:jibb  [%face %outer [%face %inner [%any-atom ~]]]
  =/  different=itype:jibb  [%face %outer [%face %wrong [%atom %t]]]
  =/  raw=itype:jibb  [%var 0]
  =/  any=itype:jibb  [%any-atom ~]
  =/  sub=isub:jibb  ~[[0 text]]
  =/  flag=itype:jibb  [%face %f [%flag ~]]
  =/  restricted=itype:jibb  [%face %f [%rvar 1]]
  =/  cell=itype:jibb  [%face %f [%cell [%atom %t] [%atom %p]]]
  =/  faced-any=itype:jibb  [%face %f [%any-atom ~]]
  =/  checks=(list ?)
    :~  =(%ok -:(itype-fit:jibb text broad ~ 2))
        =(%bad -:(itype-fit:jibb broad text ~ 2))
        =(%bad -:(itype-fit:jibb text different ~ 2))
        =(%unknown -:(itype-fit:jibb raw any sub 2))
        =(%unknown -:(itype-fit:jibb any raw sub 2))
        =(%bad -:(itype-fit:jibb flag restricted ~ 2))
        =(%bad -:(itype-fit:jibb cell faced-any ~ 2))
    ==
  ?:  (levy checks |=(ok=? ok))  ~
  ~["faced atom fit or uncertainty invariant failed"]
++  test-arithmetic-guards
  ^-  tang
  (turn arithmetic-guard-errors |=(reason=tape leaf+reason))
--
