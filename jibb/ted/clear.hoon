::  -jibb!clear: take every static file the host published out of Eyre's
::  cache.  Run it before uninstalling %jibb: the cache is ship-wide and
::  outlives the agent that filled it.
/-  spider
/+  strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
=/  m  (strand ,vase)
^-  form:m
;<  ~  bind:m  (poke-our:strandio %jibb %noun !>(%clear))
(pure:m !>('jibb: removed every static file from Eyre\'s cache'))
