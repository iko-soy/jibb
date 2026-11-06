/+  jibb
|%
++  contains
  |=  [hay=tape needle=tape]
  ^-  ?
  ?~  needle  &
  ?~  hay  |
  ?:  =((scag (lent needle) `tape`hay) needle)  &
  $(hay t.hay)
++  test-final-branch-decimal-hint
  ^-  tang
  =/  src=@t  '++ value |= b=? ?- b\0a  %.y ~s1\0a  %.n 2\0a'
  =/  got=@t  (golden-types:jibb /tests/branch-decimal/jibb src)
  ?.  (contains (trip got) "`2` is a @ud, not a @dr; write ~s2")
    ~[leaf+"deferred branch lost decimal hint" leaf+(trip got)]
  ?.  &((contains (trip got) "/tests/branch-decimal.jibb:3:7: decimal") (contains (trip got) "/tests/branch-decimal.jibb:2:7: expected type has type @dr"))
    ~[leaf+"deferred branch lost conflicting source sites" leaf+(trip got)]
  ~
++  test-later-branch-context
  ^-  tang
  =/  src=@t  '++ value |= b=? ?- b\0a  %.y ~s1\0a  %.n 2\0a++ used ^- @ (value %.y)\0a'
  =/  got=@t  (golden-types:jibb /tests/branch-decimal/jibb src)
  ?.  =(got 'module kind: library\0a++ value: $-(? @)\0a++ used: @')
    ~[leaf+"branch diagnostic ran before later common context" leaf+(trip got)]
  ~
++  test-nontagged-record-is-not-a-union
  ^-  tang
  =/  got=@t  (golden-types:jibb /tests/record/jibb '++ value ^- [@ud @tas] gap+%s2\0a')
  ?:  (contains (trip got) "has no case")
    ~[leaf+"ordinary record was reported as a tagged union" leaf+(trip got)]
  ?.  (contains (trip got) "cast mold has type [@ud @tas]")
    ~[leaf+"record diagnostic lost expected type" leaf+(trip got)]
  ?.  (contains (trip got) "tag `%gap`")
    ~[leaf+"record diagnostic lost actual head constraint" leaf+(trip got)]
  ~
++  test-call-retains-prefix-type
  ^-  tang
  =/  got=@t  (golden-types:jibb /tests/call/jibb '++ matching |= pair=[A A] pair\0a++ bad (matching ~zod "hi")\0a')
  ?.  (contains (trip got) "called gate has type $-([@p @p] [@p @p])")
    ~[leaf+"prefix argument did not explain the concrete expected type" leaf+(trip got)]
  ?.  (contains (trip got) "argument has type @t")
    ~[leaf+"call lost the actual conflicting type" leaf+(trip got)]
  ~
--
