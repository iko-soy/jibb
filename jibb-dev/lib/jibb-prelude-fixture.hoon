/+  jibb, jibb-import
/*  collection-source  %hoon  /sur/jibb-collections/hoon
|%
++  source
  ^-  @t
  collection-source
++  evidence
  ^-  iexternals:jibb
  =/  src=@t  source
  =/  at=path  /sur/jibb-collections/hoon
  =/  cor=type  -:(ride -:!>(..zuse) src)
  ~[[%jibb-collections %table (read-generic-source:jibb-import %jibb-collections %table at src cor)]]
++  bundle
  |=  modules=jbundle:jibb
  ^-  jbundle:jibb
  =/  entry=jsource:jibb  [/sur/jibb-collections/hoon source]
  ?~  modules  ~[entry]
  [i.modules $(modules t.modules)]
++  prepare-groups
  |=  [src=@t internal=@t groups=(list iprelude-group-source:jibb)]
  ^-  (unit iprelude:jibb)
  (prepare-prelude-with-group-evidence:jibb src internal groups (bundle ~) evidence)
++  prepare-bundle
  |=  [src=@t internal=@t groups=(list iprelude-group-source:jibb) modules=jbundle:jibb]
  ^-  (unit iprelude:jibb)
  (prepare-prelude-with-group-evidence:jibb src internal groups (bundle modules) evidence)
++  prepare-bundle-detailed
  |=  [src=@t internal=@t groups=(list iprelude-group-source:jibb) modules=jbundle:jibb]
  ^-  (each iprelude:jibb @t)
  (prepare-prelude-with-group-evidence-detailed:jibb src internal groups (bundle modules) evidence)
++  golden-bundle
  |=  [file=path src=@t ext=iexternals:jibb marks=imark-externals:jibb modules=jbundle:jibb public=@t internal=@t groups=(list iprelude-group-source:jibb) private=jbundle:jibb]
  ^-  @t
  (golden-types-with-prelude-and-group-evidence:jibb file src ext marks modules public internal groups (bundle private) evidence)
--
