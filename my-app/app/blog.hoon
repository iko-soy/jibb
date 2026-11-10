::  Fixture for the documented examples; not supplied by the design doc.
::  The blog's posts, which the pages under /ui/blog read with a scry per
::  request: all of them at /x/posts, and one by slug at /x/post/<slug>.
/-  blog
|%
+$  card  card:agent:gall
+$  state-0  [%0 posts=(list post:blog)]
--
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
++  on-init
  ^-  (quip card _this)
  =/  first=post:blog  ['Hello, Urbit' ~.hello-urbit]
  =/  second=post:blog  ['Pages from a scry' ~.pages-from-a-scry]
  [~ this(posts ~[first second])]
++  on-save  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  [~ this(state !<(state-0 old))]
::  The owner adds a post as [%add title slug]; one with a slug already
::  used replaces that post.
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  =(src.bowl our.bowl)
  ?>  ?=(%noun mark)
  =/  new=post:blog  +:!<([%add post:blog] vase)
  ?>  ((sane %ta) slug.new)
  =/  kept=(list post:blog)  (skip posts |=(p=post:blog =(slug.p slug.new)))
  [~ this(posts (snoc kept new))]
++  on-watch  |=(=path ^-((quip card _this) !!))
++  on-leave  |=(=path ^-((quip card _this) [~ this]))
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  [~ ~]
    [%x %posts ~]  ``posts+!>(posts)
  ::
  ::  A post whose slug is a cell, which does not fit a post: the page that
  ::  reads it must refuse it rather than render it.
      [%x %post %malformed ~]
    ``noun+!>([title='Malformed' slug=[1 2]])
  ::
      [%x %post @ ~]
    =/  found=(list post:blog)  (skim posts |=(p=post:blog =(slug.p i.t.t.path)))
    ?~  found  [~ ~]
    ``post+!>(i.found)
  ==
++  on-agent  |=([=wire =sign:agent:gall] ^-((quip card _this) [~ this]))
++  on-arvo  |=([=wire =sign-arvo] ^-((quip card _this) [~ this]))
++  on-fail  |=([=term =tang] ^-((quip card _this) [~ this]))
--
