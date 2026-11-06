/+  jibb
|%
++  test-recursive-any-atom
  ^-  tang
  =/  owner=@t  '+$ payload @'
  =/  source=@t
    (of-wain:format ~['/= atoms /ui/atoms' '+$ atom-tree' '  %done' '  [%node value=payload.atoms next=atom-tree]' '++ typed ^- atom-tree [%node value=%.y next=%done]'])
  =/  file=path  /tests/recursive-any-atom/jibb
  =/  modules=jbundle:jibb  ~[[/ui/atoms/jibb owner]]
  =/  good=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.good)  ~[leaf+(weld "recursive unrestricted atom rejected: " (trip message.p.good))]
  =/  bad-source=@t
    (of-wain:format ~['/= atoms /ui/atoms' '+$ atom-tree' '  %done' '  [%node value=payload.atoms next=atom-tree]' '++ typed ^- atom-tree [%node value=|=(x=@t x) next=%done]'])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb file bad-source)
  ?:  ?=(%| -.parsed)  ~[leaf+"gate-valued negative did not parse"]
  =/  bad=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file bad-source ~ ~ modules ~[file] ~ ~ ~ ~)
  ?:  ?=(%& -.bad)  ~[leaf+"a gate was accepted as an unrestricted atom"]
  ~
++  test-recursive-reordered-any-atom
  ^-  tang
  =/  owner=@t  '+$ payload @'
  =/  source=@t
    (of-wain:format ~['/= atoms /ui/atoms' '+$ atom-tree' '  [%node value=payload.atoms next=atom-tree]' '  %done' '++ typed ^- atom-tree [%node value=%.y next=%done]'])
  =/  file=path  /tests/recursive-any-atom/jibb
  =/  modules=jbundle:jibb  ~[[/ui/atoms/jibb owner]]
  =/  good=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ modules ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.good)  ~[leaf+(weld "reordered recursive atom rejected: " (trip message.p.good))]
  ~
--
