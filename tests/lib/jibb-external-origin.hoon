/+  jibb
|%
++  test-checked-source-origin
  ^-  tang
  =/  file=path  /ui/base/jibb
  =/  source=@t  '+$ msg\0a  %ok\0a  %stop\0a'
  =/  bundle=jbundle:jibb  ~[[file source]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ bundle ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"source interface did not check"]
  =/  iface=ifile:jibb  iface.p.checked
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %msg iface)
  ?~  mold  ~[leaf+"union mold missing"]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at /ui/local/jibb, jimports ~[[%base iface]], diagnostic-sources bundle)
  =/  site=(unit idsite:jibb)  (diagnostic-external-union-site:jibb typ.u.mold state)
  ?~  site  ~[leaf+"checked imported declaration site missing"]
  ?.  ?=(%external -.u.site)  ~[leaf+"imported declaration site is local"]
  ?.  &(=(file file.u.site) =(source source.u.site) =(beg.at.u.site [2 3]))
    ~[leaf+"imported declaration does not preserve its source"]
  =/  changed=jbundle:jibb  ~[[file '+$ msg\0a  %false\0a']]
  ?^  (diagnostic-external-union-site:jibb typ.u.mold state(diagnostic-sources changed))
    ~[leaf+"a source bundle not bound to the checked graph was trusted"]
  ?~  graph.iface  ~[leaf+"checked interface graph missing"]
  =/  fake=ifile:jibb  iface(graph `u.graph.iface(paths ~))
  ?^  (diagnostic-external-union-site:jibb typ.u.mold state(jimports ~[[%base fake]]))
    ~[leaf+"an unchecked origin path was trusted"]
  ~
++  test-tagged-cell-origin
  ^-  tang
  =/  file=path  /ui/base/jibb
  =/  source=@t  '+$ msg\0a  [%ok n=@ud]\0a  %stop\0a'
  =/  bundle=jbundle:jibb  ~[[file source]]
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb file source ~ ~ bundle ~[file] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+"source interface did not check"]
  =/  iface=ifile:jibb  iface.p.checked
  =/  mold=(unit ischeme:jibb)  (find-jibb-mold:jibb %msg iface)
  ?~  mold  ~[leaf+"union mold missing"]
  =/  local=@t  '++ one [%wrong 1]'
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb /ui/local/jibb local)
  ?:  ?=(%| -.parsed)  ~[leaf+"tagged cell did not parse"]
  =/  ds=(list def:jibb)  defs.p.parsed
  ?.  ?=([[%value *] ~] ds)  ~[leaf+"tagged definition missing"]
  =/  state=istate:jibb  *istate:jibb
  =.  state  state(at /ui/local/jibb, owner %one, general-defer &, jimports ~[[%base iface]], diagnostic-sources bundle)
  =/  value=iresult:jibb  (infer-fragment:jibb val.i.ds ~ state)
  ?:  ?=(%| -.value)  ~[leaf+"tagged cell inference failed"]
  ?.  ?=(%var -.typ.p.value)  ~[leaf+"tagged cell did not defer"]
  =/  bound=isub:jibb  (itype-bind:jibb id.typ.p.value typ.u.mold sub.state.p.value)
  =/  solved=(unit istate:jibb)  (icore-solve:jibb state.p.value(sub bound))
  ?~  solved  ~[leaf+"tagged-cell error was dropped"]
  ?~  core-error.u.solved  ~[leaf+"invalid tagged-cell case was accepted"]
  =/  sites=(list idsite:jibb)  sites.diag.u.core-error.u.solved
  ?.  ?=([* * * * ~] sites)  ~[leaf+"tagged-cell error needs declaration, context, and tag sites"]
  ?.  ?=(%external -.i.sites)  ~[leaf+"tagged-cell union declaration is not external"]
  ?.  &(!=(file.i.sites /ui/local/jibb) =(file.i.sites file) =(source.i.sites source) =(beg.at.i.sites [1 4]))
    ~[leaf+"tagged-cell union declaration source differs"]
  ?.  ?=(%external -.i.t.sites)  ~[leaf+"tagged-cell case declaration is not external"]
  ?.  &(!=(file.i.t.sites /ui/local/jibb) =(file.i.t.sites file) =(source.i.t.sites source) =(beg.at.i.t.sites [2 3]))
    ~[leaf+"tagged-cell case declaration source differs"]
  ?:  ?=(%external -.i.t.t.sites)  ~[leaf+"tagged-cell context site is not local"]
  ?.  =(beg.at.i.t.t.sites [1 8])  ~[leaf+"local tagged-cell context site differs"]
  ?:  ?=(%external -.i.t.t.t.sites)  ~[leaf+"tag site is not local"]
  ?.  =(beg.at.i.t.t.t.sites [1 9])  ~[leaf+"local tagged-cell site differs"]
  ~
--
