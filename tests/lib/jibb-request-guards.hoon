::  Source-backed request certificate and cache boundary checks.
/+  jibb
/*  public  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  request-guard-report
  ^-  @t
  =/  prelude=@t  public
  =/  src=@t  '/% %full\0a+$ paths [%plain /plain full]\0a'
  =/  left=@t  '/= api /ui/api/demo\0a++ left |= reply=$-(@t A) (plain.api reply)\0a'
  =/  right=@t  '/= api /ui/api/demo\0a++ right |= reply=$-(@t A) (plain.api reply)\0a'
  =/  diamond=@t  '/= left /lib/left\0a/= right /lib/right\0a++ cord (left.left |=(x=@t "ok"))\0a++ ship (right.right |=(x=@t ~zod))\0a'
  =/  reverse=@t  '/= right /lib/right\0a/= left /lib/left\0a++ ship (right.right |=(x=@t ~zod))\0a++ cord (left.left |=(x=@t "ok"))\0a'
  =/  other=@t  '/= api /ui/api/other\0a++ other |= reply=$-(@t A) (plain.api reply)\0a'
  =/  twoapi=@t  '/= left /lib/left\0a/= other /lib/other-helper\0a++ cord (left.left |=(x=@t "ok"))\0a++ ship (other.other |=(x=@t ~zod))\0a'
  =/  changed=@t  '/% %full\0a+$ paths [%changed /changed full]\0a'
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prep  'prelude unavailable'
  =/  api=path  /ui/api/demo/jibb
  =/  client=path  /lib/client/jibb
  =/  left-at=path  /lib/left/jibb
  =/  right-at=path  /lib/right/jibb
  =/  marks=imark-externals:jibb  ~[[%full [%& [%atom %t ~]]]]
  =/  bundle=jbundle:jibb  ~[[api src] [left-at left] [right-at right]]
  =/  pre=(unit ifile:jibb)  `iface.u.prep
  =/  fresh  (infer-jibb-file:jibb client diamond ~ marks bundle ~[client] values.u.prep molds.u.prep ~ pre)
  ?:  ?=(%| -.fresh)  (cat 3 'diamond failed: ' p.fresh)
  =/  left-iface=(unit ifile:jibb)  (find-jibb-cache:jibb left-at cache.p.fresh)
  =/  right-iface=(unit ifile:jibb)  (find-jibb-cache:jibb right-at cache.p.fresh)
  ?~  left-iface  'left interface missing'
  ?~  right-iface  'right interface missing'
  ?~  graph.u.left-iface  'left source graph missing'
  ?~  graph.u.right-iface  'right source graph missing'
  ?.  ?=([* ~] requests.u.graph.u.left-iface)  'left source certificate missing'
  ?.  ?=([* ~] requests.u.graph.u.right-iface)  'right source certificate missing'
  =/  detached=jcache:jibb  ~[[left-at u.left-iface] [right-at u.right-iface]]
  =/  reused  (infer-jibb-file:jibb client diamond ~ marks bundle ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%| -.reused)  (cat 3 'detached helper certificates rejected: ' p.reused)
  ?~  graph.iface.p.reused  'diamond graph missing'
  ?.  ?=([* ~] requests.u.graph.iface.p.reused)  'diamond request evidence missing or duplicated'
  =/  reversed  (infer-jibb-file:jibb client reverse ~ marks bundle ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%| -.reversed)  (cat 3 'reversed diamond rejected: ' p.reversed)
  ?~  graph.iface.p.reversed  'reversed diamond graph missing'
  ?.  ?=([* ~] requests.u.graph.iface.p.reversed)  'reversed diamond duplicated request'
  =/  other-api=path  /ui/api/other/jibb
  =/  other-at=path  /lib/other-helper/jibb
  =/  multi-bundle=jbundle:jibb  ~[[api src] [left-at left] [other-api src] [other-at other]]
  =/  multi  (infer-jibb-file:jibb client twoapi ~ marks multi-bundle ~[client] values.u.prep molds.u.prep ~ pre)
  ?:  ?=(%| -.multi)  (cat 3 'different API paths failed: ' p.multi)
  ?~  graph.iface.p.multi  'different API graph missing'
  =/  all=(list irequest-evidence:jibb)  requests.u.graph.iface.p.multi
  ?.  =((lent all) 2)  'distinct API path requests were merged'
  ?.  =((lent (skim all |=(r=irequest-evidence:jibb =(api-at.r api)))) 1)  'original API identity lost'
  ?.  =((lent (skim all |=(r=irequest-evidence:jibb =(api-at.r other-api)))) 1)  'other API identity lost'
  =/  missing-api=jbundle:jibb  ~[[left-at left] [right-at right]]
  =/  absent  (infer-jibb-file:jibb client diamond ~ marks missing-api ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%& -.absent)  'missing certified API source accepted'
  =/  different-api=jbundle:jibb  ~[[api changed] [left-at left] [right-at right]]
  =/  stale  (infer-jibb-file:jibb client diamond ~ marks different-api ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%& -.stale)  'changed API source accepted'
  =/  duplicate-api=jbundle:jibb  ~[[api src] [api src] [left-at left] [right-at right]]
  =/  duplicate  (infer-jibb-file:jibb client diamond ~ marks duplicate-api ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%& -.duplicate)  'duplicate certified API sources accepted'
  =/  different-marks=imark-externals:jibb  ~[[%full [%& [%atom %p ~]]]]
  =/  stale-mark  (infer-jibb-file:jibb client diamond ~ different-marks bundle ~[client] values.u.prep molds.u.prep detached pre)
  ?:  ?=(%& -.stale-mark)  'changed reader result accepted'
  =/  changed-public=@t  (cat 3 prelude '\0a:: modified\0a')
  =/  public-prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb changed-public internal)
  ?~  public-prep  'comment-only prelude did not prepare'
  =/  stale-public  (infer-jibb-file:jibb client diamond ~ marks bundle ~[client] values.u.public-prep molds.u.public-prep detached `iface.u.public-prep)
  ?:  ?=(%& -.stale-public)  'changed public source accepted'
  =/  changed-internal=@t  (cat 3 internal '\0a:: modified\0a')
  =/  internal-prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude changed-internal)
  ?~  internal-prep  'comment-only internal did not prepare'
  =/  stale-internal  (infer-jibb-file:jibb client diamond ~ marks bundle ~[client] values.u.internal-prep molds.u.internal-prep detached `iface.u.internal-prep)
  ?:  ?=(%& -.stale-internal)  'changed internal source accepted'
  'certificate controls passed'
++  request-legacy-report
  ^-  @t
  =/  prelude=@t  public
  =/  src=@t  '/% %full\0a+$ paths [%plain /plain full]\0a'
  =/  helper=@t  '/= api /ui/api/demo\0a++ fetch |= reply=$-(@t A) (plain.api reply)\0a'
  =/  transitive=@t  '/= lib /lib/helper\0a++ cord (fetch.lib |=(x=@t "ok"))\0a++ ship (fetch.lib |=(x=@t ~zod))\0a'
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb prelude internal)
  ?~  prep  'prelude unavailable'
  =/  api=path  /ui/api/demo/jibb
  =/  client=path  /lib/client/jibb
  =/  helper-at=path  /lib/helper/jibb
  =/  marks=imark-externals:jibb  ~[[%full [%& [%atom %t ~]]]]
  =/  bundle=jbundle:jibb  ~[[api src] [helper-at helper]]
  =/  pre=(unit ifile:jibb)  `iface.u.prep
  =/  simple=@t  '++ value "old"\0a'
  =/  simple-root=@t  '/= h /lib/helper\0a++ value value.h\0a'
  =/  simple-bundle=jbundle:jibb  ~[[helper-at simple]]
  =/  simple-built  (infer-jibb-file:jibb helper-at simple ~ marks simple-bundle ~[helper-at] values.u.prep molds.u.prep ~ pre)
  ?:  ?=(%| -.simple-built)  'simple helper setup failed'
  =/  legacy=ifile:jibb  iface.p.simple-built(graph ~)
  =/  old-cache=jcache:jibb  ~[[helper-at legacy]]
  =/  rebuilt  (infer-jibb-file:jibb client simple-root ~ marks simple-bundle ~[client] values.u.prep molds.u.prep old-cache pre)
  ?:  ?=(%| -.rebuilt)  (cat 3 'legacy simple rebuild failed: ' p.rebuilt)
  =/  simple-new=(unit ifile:jibb)  (find-jibb-cache:jibb helper-at cache.p.rebuilt)
  ?~  simple-new  'rebuilt simple helper missing'
  ?~  graph.u.simple-new  'simple helper was not recertified'
  =/  upgraded  (infer-jibb-file:jibb client transitive ~ marks bundle ~[client] values.u.prep molds.u.prep old-cache pre)
  ?:  ?=(%| -.upgraded)  (cat 3 'legacy changed helper failed: ' p.upgraded)
  =/  new=(unit ifile:jibb)  (find-jibb-cache:jibb helper-at cache.p.upgraded)
  ?~  new  'rebuilt request helper missing'
  ?.  =(source.u.new `helper)  'legacy helper source survived'
  ?~  graph.u.new  'request helper graph missing'
  ?.  ?=([* ~] requests.u.graph.u.new)  'request helper evidence missing'
  =/  duplicated=jcache:jibb  ~[[helper-at legacy] [helper-at legacy]]
  =/  duplicate-rebuilt  (infer-jibb-file:jibb client simple-root ~ marks simple-bundle ~[client] values.u.prep molds.u.prep duplicated pre)
  ?:  ?=(%| -.duplicate-rebuilt)  'duplicate legacy rebuild failed'
  =/  helper-entries  (skim cache.p.duplicate-rebuilt |=(c=[at=path iface=ifile:jibb] =(at.c helper-at)))
  ?.  ?=([* ~] helper-entries)  'duplicate stale helper entries remained'
  =/  api-iface=(unit ifile:jibb)  (find-jibb-cache:jibb api cache.p.upgraded)
  ?~  api-iface  'rebuilt API interface missing'
  =/  legacy-api=ifile:jibb  u.api-iface(graph ~)
  =/  both-stale=jcache:jibb  ~[[helper-at legacy] [api legacy-api]]
  =/  child-rebuilt  (infer-jibb-file:jibb client transitive ~ marks bundle ~[client] values.u.prep molds.u.prep both-stale pre)
  ?:  ?=(%| -.child-rebuilt)  'transitive unknown child rebuild failed'
  =/  api-new=(unit ifile:jibb)  (find-jibb-cache:jibb api cache.p.child-rebuilt)
  ?~  api-new  'rebuilt transitive API missing'
  ?~  graph.u.api-new  'rebuilt transitive API has no graph'
  ?.  ?=([* ~] requests.u.graph.u.api-new)  'rebuilt transitive API request missing'
  =/  mismatched=ifile:jibb  legacy(at /lib/other/jibb)
  =/  bad-cache=jcache:jibb  ~[[helper-at mismatched]]
  =/  wrong  (infer-jibb-file:jibb client transitive ~ marks bundle ~[client] values.u.prep molds.u.prep bad-cache pre)
  ?:  ?=(%& -.wrong)  'cache key and interface path mismatch accepted'
  =/  old-client=@t  '++ text "safe"\0a'
  =/  dep=@t  '/= c /lib/client\0a++ value text.c\0a'
  =/  root=@t  '/= h /lib/helper\0a++ x value.h\0a'
  =/  cycle-bundle=jbundle:jibb  ~[[client old-client] [helper-at dep]]
  =/  cycle-legacy=ifile:jibb  legacy(source `dep)
  =/  cycle-cache=jcache:jibb  ~[[helper-at cycle-legacy]]
  =/  cycle  (infer-jibb-file:jibb client root ~ marks cycle-bundle ~[client] values.u.prep molds.u.prep cycle-cache pre)
  ?:  ?=(%& -.cycle)  'legacy ancestor cycle accepted'
  'legacy cache controls passed'
++  request-guard-errors
  ^-  (list tape)
  =/  result=@t  request-guard-report
  ?.  =(result 'certificate controls passed')  ~[(trip result)]
  =/  legacy=@t  request-legacy-report
  ?:  =(legacy 'legacy cache controls passed')  ~
  ~[(trip legacy)]
++  test-request-guard
  ^-  tang
  (turn request-guard-errors |=(reason=tape leaf+reason))
--
