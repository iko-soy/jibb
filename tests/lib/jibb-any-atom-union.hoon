/+  jibb
|%
++  test-any-atom-union
  ^-  tang
  =/  atom=itype:jibb  [%any-atom ~]
  =/  cell=itype:jibb  [%cell [%slot %width [%atom %ud]] [%slot %offset [%atom %u]]]
  ?.  (import-cases-disjoint:jibb ~[atom cell])  ~[leaf+"atom and cell were not proven disjoint"]
  ?.  (import-cases-disjoint:jibb ~[cell atom])  ~[leaf+"disjoint proof depended on source order"]
  ?:  (import-cases-disjoint:jibb ~[atom [%atom %t]])  ~[leaf+"unrestricted atom was treated as disjoint from text"]
  ?:  (import-cases-disjoint:jibb ~[atom [%const [%null %n 0 '~']]])  ~[leaf+"unrestricted atom was treated as disjoint from null"]
  ?:  (import-cases-disjoint:jibb ~[atom [%var 0]])  ~[leaf+"an unknown type was treated as disjoint"]
  ?:  (import-cases-disjoint:jibb ~[atom [%noun ~]])  ~[leaf+"noun was treated as disjoint from atom"]
  =/  target=itype:jibb  [%union ~[atom cell] ~ ~ ~]
  =/  numeric=ifit:jibb  (itype-fit:jibb [%nvar 9] target ~ 10)
  ?.  ?=(%ok -.numeric)  ~[leaf+"numeric variable did not fit an unrestricted atom case"]
  ?.  ?=(~ sub.numeric)  ~[leaf+"union selection narrowed the numeric aura"]
  =/  open=ifit:jibb  (itype-fit:jibb [%fvar 11] target ~ 12)
  ?.  ?=(%unknown -.open)  ~[leaf+"a gate-free variable was incorrectly assumed to be an atom"]
  =/  file=path  /tests/any-atom-union/jibb
  =/  only=@t  (of-wain:format ~['+$ shape' '  @' '  [width=@ud offset=@u]'])
  =/  mold-result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file only ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.mold-result)  ~[leaf+(weld "ordinary source mold was rejected: " (trip message.p.mold-result))]
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %shape iface.p.mold-result)
  ?~  mold  ~[leaf+"ordinary source mold was not exported"]
  =/  src=@t  (of-wain:format ~['+$ shape' '  @' '  [width=@ud offset=@u]' '++ one ^- shape 4' '++ two ^- shape [width=4 offset=0x1f]'])
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file src ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+(weld "ordinary source union was rejected: " (trip message.p.checked))]
  =/  overlap=@t  (of-wain:format ~['+$ bad' '  @' '  @t'])
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file overlap ~ ~ ~ ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.bad)  ~[leaf+"overlapping atom union was accepted"]
  ~
--
