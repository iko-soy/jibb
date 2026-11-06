/+  jibb
/*  base-prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  test-legacy-prelude-fails-closed
  ^-  tang
  =/  public=@t  base-prelude
  ?^  (prepare-prelude-with-internal:jibb public internal)  ~[leaf+"legacy entry published a prelude with a missing group mold"]
  ?~  (prepare-prelude:jibb '++ identity |= x x\0a')  ~[leaf+"ordinary source-only prelude stopped working"]
  ?^  (prepare-prelude:jibb '+$ invalid missing.mold\0a')  ~[leaf+"legacy entry published an unresolved mold"]
  ~
--
