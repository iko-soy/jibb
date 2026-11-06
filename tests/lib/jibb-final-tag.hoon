/+  jibb
|%
++  check
  |=  source=@t
  ^-  jfile-detailed-result:jibb
  =/  at=path  /tests/final-tag/jibb
  (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
++  test-final-tag
  ^-  tang
  =/  out=jfile-detailed-result:jibb  (check '++ bad %add\0a')
  ?:  ?=(%& -.out)  ~[leaf+"unconstrained tag was accepted"]
  =/  expected=@t  '++ bad: nothing fixes the union of %add; add a `^-`\0a/tests/final-tag.jibb:1:8: nothing fixes the union of %add; add a `^-`\0a++ bad %add\0a       ^'
  ?.  =(expected message.p.out)  ~[leaf+"wrong final tag diagnostic" leaf+(trip message.p.out)]
  ~
++  test-later-context
  ^-  tang
  =/  out=jfile-detailed-result:jibb  (check '+$ choice\0a  %add\0a  %sub\0a++ first %add\0a++ later ^- choice first\0a')
  ?:  ?=(%| -.out)  ~[leaf+"later union context did not resolve the tag" leaf+(trip message.p.out)]
  ~
++  test-tagged-cell-context
  ^-  tang
  =/  bad=jfile-detailed-result:jibb  (check '++ bad [%add 1]\0a')
  ?:  ?=(%& -.bad)  ~[leaf+"unconstrained tagged cell was accepted"]
  =/  expected=@t  '++ bad: nothing fixes the union of %add; add a `^-`\0a/tests/final-tag.jibb:1:9: nothing fixes the union of %add; add a `^-`\0a++ bad [%add 1]\0a        ^'
  ?.  =(expected message.p.bad)  ~[leaf+"tagged-cell diagnostic differs" leaf+(trip message.p.bad)]
  =/  good=jfile-detailed-result:jibb  (check '+$ msg\0a  [%add value=@ud]\0a  %other\0a++ first [%add 1]\0a++ later ^- msg first\0a')
  ?:  ?=(%| -.good)  ~[leaf+"later context did not resolve tagged cell" leaf+(trip message.p.good)]
  =/  site=span:jibb  [[1 1] [1 2]]
  =/  bad-fit=icore-edge:jibb  [%fit [%atom %t] [%atom %ud] site site %bad ~]
  ?:  (icore-only-open-tag-edges:jibb ~[bad-fit] ~)
    ~[leaf+"an unrelated fit was treated as a tag-only obligation"]
  =/  closed-cell=icore-edge:jibb  [%tagged-cell [%cell [%atom %t] [%atom %t]] [%var 0] [%crash site ~] site %bad ~ ~ ~ ~ ~ ~ 0 ~]
  ?:  (icore-only-open-tag-edges:jibb ~[closed-cell] ~)
    ~[leaf+"a tagged-cell edge without an open tag was ignored"]
  =/  open-tag=itype:jibb  [%tag 7 [%term %tas %add '%add'] |]
  =/  open-cell=itype:jibb  [%cell open-tag [%atom %ud]]
  =/  no-context=icore-edge:jibb  [%tagged-cell open-cell [%var 0] [%crash site ~] site %bad ~ ~ ~ ~ ~ ~ 0 ~]
  ?.  (icore-only-open-tag-edges:jibb ~[no-context] ~)
    ~[leaf+"a genuinely context-free tagged cell was not recognized"]
  =/  has-context=icore-edge:jibb  [%tagged-cell open-cell [%union ~ ~ ~ ~] [%crash site ~] site %bad ~ ~ ~ ~ ~ ~ 0 ~]
  ?:  (icore-only-open-tag-edges:jibb ~[has-context] ~)
    ~[leaf+"a tagged cell with a known union was called context-free"]
  =/  noun-context=icore-edge:jibb  [%tagged-cell open-cell [%noun ~] [%crash site ~] site %bad ~ ~ ~ ~ ~ ~ 0 ~]
  ?.  (icore-only-open-tag-edges:jibb ~[noun-context] ~)
    ~[leaf+"a noun context was mistaken for a union context"]
  ~
--
