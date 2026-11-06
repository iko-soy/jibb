/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  test-recursive-gate-freedom
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not prepare"]
  =/  source=@t
    (of-wain:format ~['+$ safe-tree |$ [A]' '  %done' '  [%node value=A next=(safe-tree A)]' '+$ gate-tree |$ [A]' '  %done' '  [%node event=$-(@t A) next=(gate-tree A)]'])
  =/  file=path  /tests/recursive-gate-free/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ ~ ~[file] values.u.prepared molds.u.prepared ~ `iface.u.prepared)
  ?:  ?=(%| -.result)  ~[leaf+(trip message.p.result)]
  =/  safe=(unit ischeme:jibb)  (find-jibb-mold:jibb %safe-tree iface.p.result)
  =/  bad=(unit ischeme:jibb)  (find-jibb-mold:jibb %gate-tree iface.p.result)
  ?~  safe  ~[leaf+"safe recursive mold missing"]
  ?~  bad  ~[leaf+"gate-bearing recursive mold missing"]
  =/  safe-type=(unit itype:jibb)  (template-apply:jibb u.safe ~[[%atom %t]])
  =/  bad-type=(unit itype:jibb)  (template-apply:jibb u.bad ~[[%atom %t]])
  ?~  safe-type  ~[leaf+"safe recursive mold did not instantiate"]
  ?~  bad-type  ~[leaf+"gate-bearing recursive mold did not instantiate"]
  ?~  (itype-gate-free-form:jibb u.safe-type ~ 1.024)  ~[leaf+"gate-free recursive data was not proven"]
  ?^  (itype-gate-free-form:jibb u.bad-type ~ 1.024)  ~[leaf+"gate-bearing recursive data was accepted"]
  =/  safe-verdict=igate-free:jibb  (gate-free-type:jibb u.safe-type 1.024 ~)
  ?.  =(%yes verdict.safe-verdict)  ~[leaf+"recursive data verdict was not proven gate-free"]
  =/  bad-verdict=igate-free:jibb  (gate-free-type:jibb u.bad-type 1.024 ~)
  ?.  =(%no verdict.bad-verdict)  ~[leaf+"recursive gate witness was not found"]
  ?~  path.bad-verdict  ~[leaf+"recursive gate witness has no path"]
  =/  sibling=igate-free:jibb  (gate-free-type:jibb [%cell [%fn [%atom %t] [%atom %t]] u.safe-type] 1.024 ~)
  ?.  =(%no verdict.sibling)  ~[leaf+"gate next to inhabited recursive data was missed"]
  =/  open=(unit itype:jibb)  (template-apply:jibb u.safe ~[[%var 77]])
  ?~  open  ~[leaf+"generic recursive mold did not instantiate"]
  =/  open-verdict=igate-free:jibb  (gate-free-type:jibb u.open 1.024 ~)
  ?.  =(%unknown verdict.open-verdict)  ~[leaf+"an unconstrained recursive argument was declared gate-free"]
  =/  zero=igate-free:jibb  (gate-free-type:jibb u.safe-type 0 ~)
  ?.  =(%unknown verdict.zero)  ~[leaf+"recursive gate-freedom ignored its proof budget"]
  =/  constrained=(unit igf-form:jibb)  (itype-gate-free-form:jibb u.open ~ 1.024)
  ?~  constrained  ~[leaf+"generic recursive data could not receive its gate-free constraint"]
  =/  bound=itype:jibb  (itype-walk:jibb [%var 77] sub.u.constrained)
  ?.  ?=(%fvar -.bound)  ~[leaf+"recursive generic lost its gate-free constraint"]
  ~
--
