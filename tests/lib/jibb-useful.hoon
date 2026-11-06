::  The matrix works over typed noun domains and returns actual witnesses.
/+  jibb
|%
++  test-usefulness
  =,  coverage:jibb
  ^-  tang
  =/  wild=pattern  [%wild ~]
  =/  yes=pattern  [%literal 0]
  =/  no=pattern  [%literal 1]
  =/  bool=domain  [%union ~[[%literal 0] [%literal 1]]]
  =/  missing=answer  (useful ~[~[yes]] ~[wild] ~[bool] ~ 100)
  ?.  =(missing [%yes ~[1]])  ~[leaf+"missing loobean has no correct witness"]
  =/  covered=answer  (useful ~[~[yes] ~[no]] ~[wild] ~[bool] ~ 100)
  ?.  ?=(%no -.covered)  ~[leaf+"both loobeans did not cover the subject"]
  =/  move=domain  [%cell [%literal %move] [%cell [%atom ~] [%atom ~]]]
  =/  any-move=pattern  [%cell [%literal %move] [%cell wild wild]]
  =/  left-move=pattern  [%cell [%literal %move] [%cell [%literal %left] wild]]
  =/  dead=answer  (useful ~[~[any-move]] ~[left-move] ~[move] ~ 100)
  ?.  ?=(%no -.dead)  ~[leaf+"nested arm covered by an earlier arm is useful"]
  =/  open=answer  (useful ~[~[yes]] ~[wild] ~[[%atom ~]] ~ 100)
  ?.  ?=([%yes [@ ~]] open)  ~[leaf+"open atom has no witness"]
  ?:  =(0 i.witness.open)  ~[leaf+"open atom witness was already covered"]
  =/  list-type=domain  [%union ~[[%literal 0] [%cell [%atom ~] [%ref 0]]]]
  =/  graph=bindings  ~[[0 list-type]]
  =/  cons=pattern  [%cell wild wild]
  =/  nonempty=answer  (useful ~[~[yes]] ~[wild] ~[[%ref 0]] graph 100)
  ?.  ?=([%yes [[* *] ~]] nonempty)  ~[leaf+"recursive list lacks a nonempty witness"]
  =/  complete=answer  (useful ~[~[yes] ~[cons]] ~[wild] ~[[%ref 0]] graph 100)
  ?.  ?=(%no -.complete)  ~[leaf+"list nil and cell did not cover the list"]
  =/  broken=answer  (useful ~[~[wild wild]] ~[wild] ~[bool] ~ 100)
  ?.  ?=(%unknown -.broken)  ~[leaf+"ragged matrix was not rejected"]
  =/  loop-graph=bindings  ~[[0 [%ref 0]]]
  =/  exhausted=answer  (useful ~ ~[wild] ~[[%ref 0]] loop-graph 3)
  ?.  ?=(%unknown -.exhausted)  ~[leaf+"unproductive recursion did not fail closed"]
  ~
++  test-usefulness-adapter
  =,  jibb
  ^-  tang
  =/  got=(unit coverage-type-result)
    (coverage-type [%collection %list ~[[%atom %ud]]] ~ [0 ~ ~] 100)
  ?~  got  ~[leaf+"list type did not produce a coverage domain"]
  =/  wild=pattern:coverage  [%wild ~]
  =/  nil=pattern:coverage  [%literal 0]
  =/  cons=pattern:coverage  [%cell wild wild]
  =/  complete=answer:coverage
    (useful:coverage ~[~[nil] ~[cons]] ~[wild] ~[domain.u.got] graph.state.u.got 100)
  ?.  ?=(%no -.complete)  ~[leaf+"adapted list domain is not covered"]
  =/  missing=answer:coverage
    (useful:coverage ~[~[nil]] ~[wild] ~[domain.u.got] graph.state.u.got 100)
  ?.  ?=([%yes [[* *] ~]] missing)  ~[leaf+"adapted list has no cell witness"]
  =/  pat=pattern  [%cell *span ~[[%lit *span [%number %ud 2 '2']] [%bind *span %rest]]]
  =/  converted=(unit pattern:coverage)  (coverage-pattern pat)
  ?.  =(converted `[%cell [%literal 2] [%wild ~]])
    ~[leaf+"nested parser pattern was not normalized"]
  ~
--
