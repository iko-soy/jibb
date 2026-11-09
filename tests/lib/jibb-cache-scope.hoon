::  An interface certificate binds the sources of its own import closure and
::  the reader results it was checked with, for the same /sur modules and
::  marks.  A host may reuse it after a change outside that closure; a change
::  inside it is an error, never a silent recheck.
/+  jibb
|%
+$  result  jfile-detailed-result:jibb
++  check
  |=  $:  at=path
          source=@t
          modules=jbundle:jibb
          externals=iexternals:jibb
          marks=imark-externals:jibb
          cache=jcache:jibb
      ==
  ^-  result
  (infer-jibb-file-detailed:jibb at source externals marks modules ~[at] ~ ~ cache ~)
++  leaf-at  `path`/ui/leaf/jibb
++  middle-at  `path`/ui/middle/jibb
++  top-at  `path`/ui/top/jibb
++  other-at  `path`/ui/other/jibb
++  leaf  (of-wain:format ~['+$ msg' '  [%typed text=@t]' '  %add'])
++  leaf-changed  (of-wain:format ~['+$ msg' '  [%typed text=@t]' '  %add' '  %remove'])
++  middle  (of-wain:format ~['/= leaf /ui/leaf' '+$ wrapped [%wrapped msg.leaf]'])
++  top  (of-wain:format ~['/= middle /ui/middle' '+$ outer [%outer wrapped.middle]'])
++  other  (of-wain:format ~['+$ other @t'])
++  other-changed  (of-wain:format ~['+$ other @ud'])
++  bad-middle  (of-wain:format ~['/= leaf /ui/leaf' '++ bad ^- msg.leaf %submitt'])
++  stale
  |=  r=result
  ^-  ?
  ?:  ?=(%& -.r)  |
  &(=(message.p.r 'cached module evidence needs unsupported inference') ?=(~ overlap.p.r))
++  reused
  |=  [at=path old=ifile:jibb r=result]
  ^-  ?
  ?:  ?=(%| -.r)  |
  =(`old (find-jibb-cache:jibb at cache.p.r))
++  test-unrelated-source-keeps-interface
  ^-  tang
  =/  first=result  (check leaf-at leaf ~[[leaf-at leaf] [other-at other]] ~ ~ ~)
  ?:  ?=(%| -.first)  ~[leaf+"leaf did not check: {(trip message.p.first)}"]
  ::  Only /ui/other changed since the leaf checked.
  =/  later=jbundle:jibb  ~[[leaf-at leaf] [middle-at middle] [other-at other-changed]]
  =/  cached=result  (check middle-at middle later ~ ~ ~[[leaf-at iface.p.first]])
  ?:  ?=(%| -.cached)
    ~[leaf+"an unrelated change rejected a cached import: {(trip message.p.cached)}"]
  ?.  (reused leaf-at iface.p.first cached)
    ~[leaf+"the cached import was checked again instead of reused"]
  =/  fresh=result  (check middle-at middle later ~ ~ ~)
  ?:  ?=(%| -.fresh)  ~[leaf+"the importer did not check without a cache"]
  ?.  =(iface.p.fresh iface.p.cached)
    ~[leaf+"reusing the import changed the importer's interface"]
  ~
++  test-closure-change-rejects-interface
  ^-  tang
  =/  first=result  (check leaf-at leaf ~[[leaf-at leaf]] ~ ~ ~)
  ?:  ?=(%| -.first)  ~[leaf+"leaf did not check"]
  =/  changed=jbundle:jibb  ~[[leaf-at leaf-changed] [middle-at middle]]
  =/  direct=result  (check middle-at middle changed ~ ~ ~[[leaf-at iface.p.first]])
  ?.  (stale direct)  ~[leaf+"a changed import source reused its old interface"]
  ::  The importer's certificate binds the leaf's source too.
  =/  mid=result  (check middle-at middle ~[[leaf-at leaf] [middle-at middle]] ~ ~ ~)
  ?:  ?=(%| -.mid)  ~[leaf+"middle did not check"]
  =/  later=jbundle:jibb  ~[[leaf-at leaf-changed] [middle-at middle] [top-at top]]
  =/  transitive=result  (check top-at top later ~ ~ ~[[middle-at iface.p.mid]])
  ?.  (stale transitive)
    ~[leaf+"a changed transitive import reused its importer's old interface"]
  =/  unchanged=jbundle:jibb  ~[[leaf-at leaf] [middle-at middle] [top-at top] [other-at other]]
  =/  kept=result  (check top-at top unchanged ~ ~ ~[[middle-at iface.p.mid]])
  ?.  (reused middle-at iface.p.mid kept)
    ~[leaf+"an unchanged transitive closure was not reused"]
  ~
++  test-reader-results-compare-their-own-modules
  ^-  tang
  ::  The leaf is checked with reader results it does not use.  They are in
  ::  its certificate even so: a change to them rejects it, while results
  ::  for other modules and marks do not.
  =/  externals=iexternals:jibb  ~[[%fixture %thing 1]]
  =/  marks=imark-externals:jibb  ~[[%fixture-action 1]]
  =/  first=result  (check leaf-at leaf ~[[leaf-at leaf]] externals marks ~)
  ?:  ?=(%| -.first)  ~[leaf+"leaf did not check with unused reader results"]
  =/  old=ifile:jibb  iface.p.first
  =/  bundle=jbundle:jibb  ~[[leaf-at leaf] [middle-at middle]]
  =/  more-externals=iexternals:jibb
    (weld externals `iexternals:jibb`~[[%unrelated %thing 2]])
  =/  more-marks=imark-externals:jibb
    (weld marks `imark-externals:jibb`~[[%unrelated-action 2]])
  =/  kept=result  (check middle-at middle bundle more-externals more-marks ~[[leaf-at old]])
  ?.  (reused leaf-at old kept)
    ~[leaf+"another module's reader results rejected the cached import"]
  =/  sur-changed=iexternals:jibb  ~[[%fixture %thing 3] [%unrelated %thing 2]]
  ?.  (stale (check middle-at middle bundle sur-changed more-marks ~[[leaf-at old]]))
    ~[leaf+"a changed /sur reader result reused the interface"]
  =/  mark-changed=imark-externals:jibb  ~[[%fixture-action 3]]
  ?.  (stale (check middle-at middle bundle more-externals mark-changed ~[[leaf-at old]]))
    ~[leaf+"a changed mark reader result reused the interface"]
  ?.  (stale (check middle-at middle bundle ~ marks ~[[leaf-at old]]))
    ~[leaf+"missing /sur reader results reused the interface"]
  ~
++  test-cached-import-keeps-diagnostic-excerpt
  ^-  tang
  =/  first=result  (check leaf-at leaf ~[[leaf-at leaf] [other-at other]] ~ ~ ~)
  ?:  ?=(%| -.first)  ~[leaf+"leaf did not check"]
  =/  later=jbundle:jibb  ~[[leaf-at leaf] [middle-at bad-middle] [other-at other-changed]]
  =/  fresh=result  (check middle-at bad-middle later ~ ~ ~)
  =/  cached=result  (check middle-at bad-middle later ~ ~ ~[[leaf-at iface.p.first]])
  ?:  ?=(%& -.fresh)  ~[leaf+"the missing case checked"]
  ?:  ?=(%& -.cached)  ~[leaf+"the missing case checked with a cached import"]
  ?.  =(message.p.fresh message.p.cached)
    :~  leaf+"a cached import changed the diagnostic"
        leaf+(trip message.p.fresh)
        leaf+(trip message.p.cached)
    ==
  ::  The union's declaration sites come from the cached import's own source.
  =/  expected=@t
    %-  of-wain:format
    :~  '++ bad: msg.leaf has no case `%submitt`'
        '/ui/leaf.jibb:1:4: expected union has type msg.leaf'
        '+$ msg'
        '   ^'
        '/ui/leaf.jibb:2:3: expected union has type msg.leaf'
        '  [%typed text=@t]'
        '  ^'
        '/ui/middle.jibb:2:11: expected union has type msg.leaf'
        '++ bad ^- msg.leaf %submitt'
        '          ^'
        '/ui/middle.jibb:2:20: tag literal has type %submitt'
        '++ bad ^- msg.leaf %submitt'
        '                   ^'
    ==
  ?.  =(expected message.p.cached)  ~[leaf+(trip message.p.cached)]
  ~
--
