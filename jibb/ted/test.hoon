::  -jibb!test %desk: run the desk's tests, each test- arm of each module
::  under /ui/tests, from the host's build of the desk's current revision,
::  waiting for that build if it is still running.  It prints one line a
::  test and gives every outcome.
/-  spider
/+  strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
=/  =desk  -:!<([desk ~] arg)
;<  =bowl:spider  bind:m  get-bowl:strandio
=/  rev=@ud  ud:.^(cass:clay %cw /(scot %p our.bowl)/[desk]/(scot %da now.bowl))
=/  tries=@ud  600
|-  ^-  form:m
=*  loop  $
;<  =bowl:spider  bind:m  get-bowl:strandio
=/  base=path  /(scot %p our.bowl)/jibb/(scot %da now.bowl)
=/  build=[done=(unit @ud) running=(unit @ud)]
  .^([(unit @ud) (unit @ud)] %gx (weld base /build/[desk]/noun))
?.  &(?=(~ running.build) ?=(^ done.build) (gte u.done.build rev))
  ?:  =(0 tries)
    %+  strand-fail:strandio  %jibb-test
    ~[leaf+"the host has not built %{(trip desk)} at revision {(scow %ud rev)}"]
  ;<  ~  bind:m  (sleep:strandio ~s1)
  loop(tries (dec tries))
=/  results=(each (list [at=path tests=(list [arm=term ok=? message=@t])]) @t)
  .^((each (list [at=path tests=(list [arm=term ok=? message=@t])]) @t) %gx (weld base /test/[desk]/noun))
?:  ?=(%| -.results)  (strand-fail:strandio %jibb-test ~[leaf+(trip p.results)])
::  A typed loop: +zing of tank lists is a fuse-loop.
=/  lines=(list tank)
  =/  modules=(list [at=path tests=(list [arm=term ok=? message=@t])])  p.results
  =|  out=(list tank)
  |-
  ?~  modules  (flop out)
  =/  tests=(list [arm=term ok=? message=@t])  tests.i.modules
  |-
  ?~  tests  ^$(modules t.modules)
  =/  line=tape
    ?:  ok.i.tests  "OK      {(spud at.i.modules)} {(trip arm.i.tests)}"
    "FAILED  {(spud at.i.modules)} {(trip arm.i.tests)}: {(trip message.i.tests)}"
  $(tests t.tests, out [leaf+line out])
%-  (slog lines)
(pure:m !>(p.results))
