::  A settled record reports its missing field and its lexical binding.
/+  jibb
/*  expected  %txt  /tests/type-known-field-error/expected/txt
|%
++  report
  ^-  @t
  =/  cases=(list [label=@t source=@t])
    :~  ['sample record' '++ f |= p=[a=@ud b=@ud] c.p\0a']
        ['global record' '++ record [a="hi" b=~zod]\0a++ missing c.record\0a']
        ['local record' '++ f |= n=@ud\0a  ++ record [a=n b="hi"]\0a  c.record\0a']
        ['nested record' '++ f |= p=[inner=[a=@ud b=@ud] other=@t] c.inner.p\0a']
        ['missing intermediate field' '++ f |= p=[a=@ud b=@ud] value.absent.p\0a']
        ['forward record' '++ missing c.record\0a++ record [a="hi" b=~zod]\0a']
        ['unresolved record' '++ f |= p c.p\0a']
        ['valid field' '++ f |= p=[a=@ud b=@ud] a.p\0a']
    ==
  %-  of-wain:format
  %+  turn  cases
  |=  [label=@t source=@t]
  (cat 3 label (cat 3 '\0a' (golden-types:jibb /ui/fields/jibb source)))
++  test-known-field-error
  ^-  tang
  =/  actual=@t  report
  ?.  =((to-wain:format (cat 3 actual '\0a')) expected)
    ~[leaf+(trip actual)]
  ~
--
