/+  jibb
|%
++  check
  |=  src=@t
  ^-  tang
  =/  at=path  /ui/generic-match/jibb
  =/  checked=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at src ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%| -.checked)  ~[leaf+(trip message.p.checked)]
  ~
++  test-generic-tagged-payload
  ^-  tang
  %-  check
  %-  of-wain:format
  :~  '+$ result |$ [V E]'
      '  [%ok value=V]'
      '  [%err error=E]'
      '++ either-value |= r=(result A A)'
      '  ?- r'
      '    [%ok value] value'
      '    [%err error] error'
      '++ reused |= r=(result A A)'
      '  ?- r'
      '    [%ok item] item'
      '    [%err item] item'
  ==
++  test-generic-recursive-list
  ^-  tang
  %-  check
  %-  of-wain:format
  :~  '+$ list |$ [A]'
      '  ~'
      '  [i=A t=(list A)]'
      '++ weld |= args=[(list A) (list A)]'
      '  ?- args'
      '    [xs ys]'
      '      ^- (list A)'
      '      ?- xs'
      '        ~ ys'
      '        [item rest] [item (weld rest ys)]'
  ==
--
