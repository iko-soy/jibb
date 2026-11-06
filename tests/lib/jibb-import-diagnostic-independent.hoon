/+  jibb, jibb-import
/*  sur       %txt  /tests/type-import-diagnostic/sur/txt
/*  mark      %txt  /tests/type-import-diagnostic/mark/txt
/*  original  %txt  /tests/type-import-diagnostic/source/txt
/*  nested    %txt  /tests/type-import-diagnostic/nested/txt
/*  expected  %txt  /tests/type-import-diagnostic/independent-expected/txt
|%
++  text
  |=  lines=wain
  ^-  @t
  (rap 3 (turn lines |=(line=@t (cat 3 line '\0a'))))
++  report
  ^-  @t
  =/  cor=type  -:(ride -:!>(..zuse) (text sur))
  =/  mark-cor=type  -:(ride -:!>(..zuse) (text mark))
  =/  ext=(list [module=term name=term result=*])
    :~  [%fixture %signed (read-named-diagnostic:jibb-import %fixture %signed cor)]
        [%fixture %core (read-named-diagnostic:jibb-import %fixture %core cor)]
        [%fixture %good (read-named-diagnostic:jibb-import %fixture %good cor)]
        [%foo %bad [%invalid %aura 'signed and float auras cannot be imported']]
    ==
  =/  marks=(list [name=term result=*])
    ~[[%bad-mark (read-mark-diagnostic:jibb-import %bad-mark mark-cor)]]
  =/  real-valid=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '++ valid |= x=good.fixture x' '++ unused-valid "ok"' '' '' '' '' '' '' '']) ext marks)
  =/  real-sample=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '' '' '++ sample |= x=signed.fixture x' '' '' '' '' '' '']) ext marks)
  =/  real-nested=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '+$ box [ok=@t nested=[bad=core.fixture]]' '' '' '' '++ nested |= x=box x' '' '' '' '' '']) ext marks)
  =/  real-alias=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '+$ alias signed.fixture' '' '' '' '' '' '++ alias-use ^- alias 1' '' '' '' '']) ext marks)
  =/  real-mark=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '' '' '' '' '' '++ mark-use |= x=bad-mark x' '' '' '']) ext marks)
  =/  real-core-sample=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '' '' '' '' '' '' '++ core-sample |= x=core.fixture x' '' '']) ext marks)
  =/  real-core-cast=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '' '' '' '' '' '' '' '++ core-cast ^- core.fixture !!' '']) ext marks)
  =/  real-signed-cast=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/-  fixture' '/%  %bad-mark' '' '' '' '' '' '' '' '' '' '' '++ signed-cast ^- signed.fixture !!']) ext marks)
  =/  nested-sample=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '++ nested |= [a=@t b=bad.foo] a' '' '' '' '' '' '' '']) ext marks)
  =/  nested-cast=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '' '++ cast ^- [a=@t b=bad.foo] !!' '' '' '' '' '' '']) ext marks)
  =/  nested-function=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '' '' '++ func ^- $-(@t bad.foo) !!' '' '' '' '' '']) ext marks)
  =/  nested-alias=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '+$ alias bad.foo' '' '' '' '' '++ alias-use ^- alias !!' '' '' '' '']) ext marks)
  =/  nested-unknown-first=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '' '' '' '' '++ first-unsupported ^- [a=* b=bad.foo] !!' '' '' '']) ext marks)
  =/  nested-recursive-first=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '+$ recursive recursive' '' '' '' '' '' '++ recursive-first ^- [a=recursive b=bad.foo] !!' '' '']) ext marks)
  =/  nested-shadow=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '' '' '' '' '' '' '++ shadow |= [a=@t [a=bad.foo b=@t]] a' '']) ext marks)
  =/  nested-first-invalid=@t  (golden-types-with-reader-diagnostics:jibb /ui/test/jibb (text ~['/- foo' '' '' '' '' '' '' '' '' '' '++ first-invalid |= [a=bad.foo b=bad.foo] a']) ext marks)
  (of-wain:format ~['real-valid:' real-valid 'real-sample:' real-sample 'real-nested:' real-nested 'real-alias:' real-alias 'real-mark:' real-mark 'real-core-sample:' real-core-sample 'real-core-cast:' real-core-cast 'real-signed-cast:' real-signed-cast 'nested-sample:' nested-sample 'nested-cast:' nested-cast 'nested-function:' nested-function 'nested-alias:' nested-alias 'nested-unknown-first:' nested-unknown-first 'nested-recursive-first:' nested-recursive-first 'nested-shadow:' nested-shadow 'nested-first-invalid:' nested-first-invalid])
++  test-independent-import-diagnostics
  ^-  tang
  ?~  expected  ~[leaf+"independent diagnostic expected output is missing"]
  ?.  =((text original) (text ~['/-  fixture' '/%  %bad-mark' '+$ alias signed.fixture' '+$ box [ok=@t nested=[bad=core.fixture]]' '++ valid |= x=good.fixture x' '++ unused-valid "ok"' '++ sample |= x=signed.fixture x' '++ nested |= x=box x' '++ alias-use ^- alias 1' '++ mark-use |= x=bad-mark x' '++ core-sample |= x=core.fixture x' '++ core-cast ^- core.fixture !!' '++ signed-cast ^- signed.fixture !!']))  ~[leaf+"original fixture changed; regenerate independent cases"]
  ?.  =((text nested) (text ~['/- foo' '+$ alias bad.foo' '+$ recursive recursive' '++ nested |= [a=@t b=bad.foo] a' '++ cast ^- [a=@t b=bad.foo] !!' '++ func ^- $-(@t bad.foo) !!' '++ alias-use ^- alias !!' '++ first-unsupported ^- [a=* b=bad.foo] !!' '++ recursive-first ^- [a=recursive b=bad.foo] !!' '++ shadow |= [a=@t [a=bad.foo b=@t]] a' '++ first-invalid |= [a=bad.foo b=bad.foo] a']))  ~[leaf+"nested fixture changed; regenerate independent cases"]
  =/  got=@t  report
  ?.  =((to-wain:format (cat 3 got '\0a')) expected)
    ~[leaf+"independent imported-mold diagnostics differ"]
  ~
--
