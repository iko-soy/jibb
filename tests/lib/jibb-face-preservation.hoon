::  Safe result propagation retains every argument face, including nested
::  gate fields; adding a result face alone must not discard value faces.
/+  jibb
|%
++  test-face-preservation
  ^-  tang
  =/  txt=itype:jibb  [%atom %t]
  =/  value=itype:jibb  [%cell [%face %field txt] txt]
  =/  gate=itype:jibb  [%fn txt value]
  =/  named-gate=itype:jibb  [%face %foo gate]
  ?.  (itype-preserves-faces:jibb gate named-gate ~)
    ~[leaf+"a result that wraps the complete gate was declined"]
  ?:  (itype-preserves-faces:jibb gate [%face %foo [%fn txt [%cell txt txt]]] ~)
    ~[leaf+"a result that lost a nested gate value face was accepted"]
  ?:  (itype-preserves-faces:jibb gate [%face %foo [%fn txt [%cell [%face %other txt] txt]]] ~)
    ~[leaf+"a result that renamed a value face was accepted"]
  ?:  (itype-preserves-faces:jibb value [%cell [%face %field txt] [%atom %ud]] ~)
    ~[leaf+"a result with a different underlying type was accepted"]
  =/  pair=itype:jibb  [%cell gate gate]
  ?.  (itype-preserves-faces:jibb pair [%cell gate named-gate] ~)
    ~[leaf+"a result with one added positional face was declined"]
  ~
--
