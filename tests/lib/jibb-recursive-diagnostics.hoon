::  Recursive groups preserve errors, and value cycles name their edges.
/+  jibb, jibb-prelude-fixture
/*  expected  %txt  /tests/type-recursive-diagnostics/expected/txt
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
|%
++  report
  ^-  @t
  =/  cases=(list [name=@t src=@t])
    :~  ['alias' '++ loop loop\0a']
        ['two aliases' '++ first second\0a++ second first\0a']
        ['value through gate' '++ value ^- @ud (read ~)\0a++ read |= ~ value\0a']
        ['record through gate' '++ value [x=(read ~) y=0]\0a++ read |= ~ x.value\0a']
        ['mutual mismatch' '++ first |= n=@ud (second n)\0a++ second |= n=@ud (first "bad")\0a']
    ==
  =/  lines=(list @t)
    %+  turn  cases
    |=  [name=@t src=@t]
    =/  r  (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
    =/  legacy  (infer-jibb-file:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
    ?:  |(?=(%& -.r) ?=(%& -.legacy))  'invalid cycle or call was accepted'
    ?.  =(message.p.r p.legacy)  'detailed and legacy errors differ'
    (cat 3 (cat 3 name '\0a') message.p.r)
  (of-wain:format lines)
++  test-recursive-diagnostics
  ^-  tang
  ?.  =((to-wain:format (cat 3 report '\0a')) expected)
    ~[leaf+"recursive group diagnostics differ"]
  ~
++  test-recursive-positive
  ^-  tang
  =/  src=@t
    '++ first |= n=@ud ^- @ud (second n)\0a++ second |= n=@ud\0a  ?- n\0a  0 0\0a  * (first n)\0a'
  =/  r  (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
  ?:  ?=(%| -.r)  ~[leaf+(trip message.p.r)]
  =/  names=(list term)  ~[%first %second]
  |-
  ?~  names  ~
  =/  found=(unit ischeme:jibb)  (ienv-lookup:jibb i.names values.iface.p.r)
  ?~  found  ~[leaf+"recursive gate is missing"]
  ?.  &(=(typ.u.found [%fn [%atom %ud] [%atom %ud]]) ?=(~ vars.u.found))
    ~[leaf+"recursive gate type changed"]
  $(names t.names)
++  test-dependency-sites
  ^-  tang
  =/  sources=(list @t)
    :~  '++ outer |= target=@ud target\0a'
        '++ outer |= xs=@ud\0a  ?- xs\0a  target target\0a'
        '++ outer\0a  ++ target 0\0a  target\0a'
    ==
  |-
  ?~  sources  ~
  =/  parsed  (parse:jibb /ui/cycle/jibb i.sources)
  ?:  ?=(%| -.parsed)  ~[leaf+"dependency-site fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] ds)  ~[leaf+"dependency-site fixture changed shape"]
  =/  d=def:jibb  i.ds
  ?>  ?=(%value -.d)
  ?^  (dependency-site:jibb %target ~[val.d])
    ~[leaf+"lexically bound name became a global dependency"]
  ?^  (dependency-expr:jibb val.d)
    ~[leaf+"a local binder created a dependency graph edge"]
  $(sources t.sources)
++  test-dependency-captures
  ^-  tang
  =/  src=@t
    '++ outer |= sample=@ud\0a  ++ local |= input=@ud (external input)\0a  ?- sample\0a  0 (local sample)\0a  * (other sample)\0a'
  =/  parsed  (parse:jibb /ui/cycle/jibb src)
  ?:  ?=(%| -.parsed)  ~[leaf+"capture fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] ds)  ~[leaf+"capture fixture changed shape"]
  =/  d=def:jibb  i.ds
  ?>  ?=(%value -.d)
  ?.  =((dependency-expr:jibb val.d) ~[%external %other])
    ~[leaf+"lexical dependency traversal lost a captured global or retained a local"]
  ~
++  test-cycle-through-prelude
  ^-  tang
  =/  prep=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prep  ~[leaf+"prelude did not prepare"]
  =/  src=@t  '++ title (lent title)\0a'
  =/  r
    (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] values.u.prep molds.u.prep ~ `iface.u.prep)
  ?:  ?=(%& -.r)  ~[leaf+"self-dependent list length was accepted"]
  =/  want=@t
    (of-wain:format ~['++ title: non-gate value `title` depends on itself through the cycle title -> title' '/ui/cycle.jibb:1:4: definition in cycle' '++ title (lent title)' '   ^' '/ui/cycle.jibb:1:16: `title` depends on `title` here' '++ title (lent title)' '               ^'])
  ?.  =(want message.p.r)  ~[leaf+(trip message.p.r)]
  ~
++  test-recursive-error-order
  ^-  tang
  =/  src=@t
    '++ pending %add\0a++ first |= n=@ud (second n)\0a++ second |= n=@ud (first "bad")\0a'
  =/  r  (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.r)  ~[leaf+"pending tag and bad recursive argument were accepted"]
  =/  want=@t
    (of-wain:format ~['++ pending: nothing fixes the union of %add; add a `^-`' '/ui/cycle.jibb:1:12: nothing fixes the union of %add; add a `^-`' '++ pending %add' '           ^'])
  ?.  =(want message.p.r)  ~[leaf+(trip message.p.r)]
  ~
++  test-later-context-after-error
  ^-  tang
  =/  src=@t
    '+$ message %add\0a++ pending %add\0a++ first |= n=@ud (second n)\0a++ second |= n=@ud (first "bad")\0a++ fixed ^- message pending\0a'
  =/  r  (infer-jibb-file-detailed:jibb /ui/cycle/jibb src ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.r)  ~[leaf+"bad recursive argument was accepted"]
  =/  want=@t
    (of-wain:format ~['++ second: inline gate result does not unify with @ud: @t versus @ud' '/ui/cycle.jibb:4:27: actual type has type @t' '++ second |= n=@ud (first "bad")' '                          ^' '/ui/cycle.jibb:4:21: call context has type @ud' '++ second |= n=@ud (first "bad")' '                    ^'])
  ?.  =(want message.p.r)  ~[leaf+(trip message.p.r)]
  ~
++  test-failed-group-rollback
  ^-  tang
  =/  src=@t
    '+$ wanted\0a  %add\0a  %desired\0a+$ wrong\0a  %add\0a  %forbidden\0a++ pending %add\0a++ first |= n=@ud\0a  ++ constrain ^- wrong pending\0a  (second n)\0a++ second |= n=@ud (first "bad")\0a++ fixed ^- wanted pending\0a'
  =/  at=path  /ui/cycle/jibb
  =/  parsed  (parse:jibb at src)
  ?:  ?=(%| -.parsed)  ~[leaf+"rollback fixture did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  =/  names=(list term)  (global-value-names:jibb ds)
  =/  molds=imolds:jibb  (collect-simple-molds:jibb ds)
  =/  top=(list term)  (turn molds |=(m=[name=term body=shape:jibb] name.m))
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(molds molds, globals names, top-molds top, at at, in-mold |, jrec-fuel 256, general-defer &)
  =/  graph=iadj:jibb  (graph-make-forward:jibb ds (graph-nameset:jibb names ~) ~)
  =/  groups=icomponents:jibb  (graph-components-for:jibb names graph)
  =/  index=(map term icore-definition:jibb)  (icore-definition-index:jibb ds ~ 0)
  =/  r  (icore-components:jibb groups index graph ~ state ~ ~)
  ?~  r  ~[leaf+"failed group prevented independent inference"]
  ?~  failure.u.r  ~[leaf+"failed group diagnostic was lost"]
  ?.  =(owner.u.failure.u.r %second)  ~[leaf+"rollback lost the original failure"]
  =/  final=(unit istate:jibb)  (icore-solve:jibb state.u.r)
  ?~  final  ~[leaf+"a failed group left incompatible constraints"]
  ?^  core-error.u.final  ~[leaf+"a failed group left a deferred error"]
  ?^  queue.u.final  ~[leaf+"independent context did not settle the earlier tag"]
  =/  fixed=(unit ischeme:jibb)  (ienv-lookup:jibb %fixed env.u.r)
  ?~  fixed  ~[leaf+"independent definition was not inferred"]
  =/  typ=itype:jibb  (itype-normalize:jibb typ.u.fixed sub.u.final)
  ?.  ?=(%union -.typ)  ~[leaf+"independent context lost its union"]
  ?~  origin.typ  ~[leaf+"independent context lost its union origin"]
  ?.  =(name.u.origin.typ %wanted)  ~[leaf+"failed group leaked its union binding"]
  =/  baseline=(unit istate:jibb)  (icore-solve-full:jibb state.u.r)
  ?~  baseline  ~[leaf+"baseline solver rejected the rolled-back state"]
  ?.  =(u.final(wake ~) u.baseline(wake ~))
    ~[leaf+"failed group left stale wake state"]
  ~
++  test-independent-error-priority
  ^-  tang
  =/  cycle=@t  '++ loop loop\0a'
  =/  gates=@t  '++ first |= n=@ud (second n)\0a++ second |= n=@ud (first "bad")\0a'
  =/  cycle-first=@t
    (of-wain:format ~['++ loop: non-gate value `loop` depends on itself through the cycle loop -> loop' '/ui/cycle.jibb:1:4: definition in cycle' '++ loop loop' '   ^' '/ui/cycle.jibb:1:9: `loop` depends on `loop` here' '++ loop loop' '        ^'])
  =/  gate-first=@t
    (of-wain:format ~['++ second: inline gate result does not unify with @ud: @t versus @ud' '/ui/cycle.jibb:2:27: actual type has type @t' '++ second |= n=@ud (first "bad")' '                          ^' '/ui/cycle.jibb:2:21: call context has type @ud' '++ second |= n=@ud (first "bad")' '                    ^'])
  =/  cases=(list [src=@t want=@t])
    ~[[(cat 3 cycle gates) cycle-first] [(cat 3 gates cycle) gate-first]]
  |-
  ?~  cases  ~
  =/  r  (infer-jibb-file-detailed:jibb /ui/cycle/jibb src.i.cases ~ ~ ~ ~[/ui/cycle/jibb] ~ ~ ~ ~)
  ?:  ?=(%& -.r)  ~[leaf+"independent invalid groups were accepted"]
  ?.  =(want.i.cases message.p.r)  ~[leaf+(trip message.p.r)]
  $(cases t.cases)
--
