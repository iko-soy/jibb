/+  jibb
|%
++  test-branch-value-faces
  ^-  tang
  =/  atom=itype:jibb  [%atom %t]
  =/  left=itype:jibb  [%face %left atom]
  =/  right=itype:jibb  [%face %right atom]
  ?.  (branch-value-face-conflict:jibb left right ~ 100)  ~[leaf+"different value faces did not conflict"]
  ?:  (branch-value-face-conflict:jibb left atom ~ 100)  ~[leaf+"an unnamed value incorrectly conflicted"]
  ?:  (branch-value-face-conflict:jibb left [%var 0] ~ 100)  ~[leaf+"an unresolved value incorrectly conflicted"]
  ?:  (branch-value-face-conflict:jibb [%slot %left atom] [%slot %right atom] ~ 100)  ~[leaf+"positional slot labels incorrectly conflicted"]
  =/  nested-a=itype:jibb  [%cell [%slot %a atom] [%slot %b left]]
  =/  nested-b=itype:jibb  [%cell [%slot %x atom] [%slot %y right]]
  ?.  (branch-value-face-conflict:jibb nested-a nested-b ~ 100)  ~[leaf+"nested value face conflict was lost"]
  ~
++  test-branch-face-sites
  ^-  tang
  =/  first=span:jibb  [[1 3] [1 8]]
  =/  second=span:jibb  [[2 3] [2 9]]
  =/  atom=itype:jibb  [%atom %t]
  =/  arms=(list [typ=itype:jibb at=span:jibb])
    ~[[[%face %left atom] first] [[%face %right atom] second]]
  =/  got=(unit idiag:jibb)  (branch-face-problem:jibb arms ~)
  ?~  got  ~[leaf+"conflicting faces did not report sites"]
  ?.  =(sites.u.got ~[[first "first branch result has type [left=@t]"] [second "conflicting branch result has type [right=@t]"]])
    ~[leaf+"conflicting faces did not preserve both arm sites"]
  ~

--
