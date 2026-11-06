/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  capital  %txt  /tests/type-deferred-cast/call-capital/txt
/*  capital-expected  %txt  /tests/type-deferred-cast/call-capital-expected/txt
/*  unrelated  %txt  /tests/type-deferred-cast/call-unrelated/txt
/*  unrelated-expected  %txt  /tests/type-deferred-cast/call-unrelated-expected/txt
/*  wrong-tag  %txt  /tests/type-deferred-cast/wrong-tag/txt
/*  wrong-tag-expected  %txt  /tests/type-deferred-cast/wrong-tag-expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  test-deferred-call-capital
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb /tests/deferred-cast/jibb (text capital) ~ ~ ~ prepared)
  ?.  =((to-wain:format (cat 3 actual '\0a')) capital-expected)
    ~[leaf+"deferred call lost the capital or forcing-site diagnostic" leaf+(trip actual)]
  ~
++  test-deferred-call-unrelated
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb /tests/deferred-cast/jibb (text unrelated) ~ ~ ~ prepared)
  ?.  =((to-wain:format (cat 3 actual '\0a')) unrelated-expected)
    ~[leaf+"an unrelated capital was specialized" leaf+(trip actual)]
  ~
++  test-deferred-cast-tag-owner
  ^-  tang
  =/  prepared=(unit iprelude:jibb)  (prepare-groups:jibb-prelude-fixture prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]])
  ?~  prepared  ~[leaf+"prelude did not check"]
  =/  actual=@t  (golden-types-with-prepared-prelude:jibb /tests/deferred-cast/jibb (text wrong-tag) ~ ~ ~ prepared)
  ?.  =((to-wain:format (cat 3 actual '\0a')) wrong-tag-expected)
    ~[leaf+"deferred tag lost its owning definition or source sites" leaf+(trip actual)]
  ~
--
