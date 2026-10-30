::  Fixture for the documented examples; not supplied by the design doc.
|%
+$  item  [id=@ud done=? text=@t]
+$  action
  $%  [%add text=@t]
      [%toggle id=@ud]
  ==
+$  update
  $%  [%added item=item]
      [%toggled id=@ud]
  ==
--
