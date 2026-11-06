/+  jibb
|%
++  test-import-source
  ^-  tang
  =/  state=istate:jibb  *istate:jibb
  =.  at.state  /tests/mold-shadow/jibb
  =.  local-source.state  `'/= lib /ui/lib\0a++ f |= x\0a  +$ lib @t\0a  x\0a'
  =/  origin=(unit idsite:jibb)  (source-import-binding-site:jibb %lib state)
  ?~  origin  ~[leaf+"import binding source was lost"]
  =/  found=idsite:jibb  u.origin
  ?:  ?=(%external -.found)  ~[leaf+"local import was marked external"]
  ?.  =(beg.at.found [1 4])  ~[leaf+"import binding site differs"]
  ?^  (source-import-binding-site:jibb %other state)
    ~[leaf+"an unrelated import supplied a binding"]
  =.  local-source.state  ~
  ?^  (source-import-binding-site:jibb %lib state)
    ~[leaf+"missing source invented a binding"]
  ~
--
