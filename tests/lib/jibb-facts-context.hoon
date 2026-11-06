/+  jibb
|%
++  check-facts-error
  |=  [source=@t line=@ud col=@ud]
  ^-  tang
  =/  at=path  /ui/facts-test/jibb
  =/  result=jfile-detailed-result:jibb
    (infer-jibb-file-detailed:jibb at source ~ ~ ~ ~[at] ~ ~ ~ ~)
  ?:  ?=(%& -.result)  ~[leaf+"misplaced facts was accepted"]
  =/  note=tape  "`(facts ...)` is allowed only in an API's `+$ paths`"
  =/  expected=@t
    (rap 3 ~[(show-error:jibb source [at line col note]) '\0a' (show-error:jibb source [at line +(col) note])])
  ?.  =(message.p.result expected)  ~[leaf+"misplaced facts diagnostic differs: {(trip message.p.result)}"]
  ~
++  test-facts-context
  ^-  tang
  =/  mold=tang  (check-facts-error '+$ wrong (facts @t @ud)' 1 10)
  ?^  mold  mold
  =/  sample=tang  (check-facts-error '++ f |= x=(facts @t @ud) 0' 1 11)
  ?^  sample  sample
  =/  cast=tang  (check-facts-error '++ f ^- (facts @t @ud) 0' 1 9)
  ?^  cast  cast
  =/  nested=tang
    (check-facts-error (of-wain:format ~['++ f |= x=@t' '  ++ inner ^- (facts @t @ud) 0' '  inner']) 2 15)
  ?^  nested  nested
  =/  api-at=path  /ui/api/test/jibb
  =/  api-source=@t
    (of-wain:format ~['+$ paths' '  [%changes /changes (facts @t @ud)]'])
  =/  parsed=(each module:jibb error:jibb)  (parse:jibb api-at api-source)
  ?:  ?=(%| -.parsed)  ~[leaf+"API path facts control did not parse"]
  ?^  (facts-outside-api-paths:jibb api-at defs.p.parsed)
    ~[leaf+"facts was rejected inside an API paths declaration"]
  =/  other=(each module:jibb error:jibb)  (parse:jibb api-at '+$ other (facts @t @ud)')
  ?:  ?=(%| -.other)  ~[leaf+"API non-path facts control did not parse"]
  ?~  (facts-outside-api-paths:jibb api-at defs.p.other)
    ~[leaf+"facts in an unrelated API mold was accepted"]
  ~
--
