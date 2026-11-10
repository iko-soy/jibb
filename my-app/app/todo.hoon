::  Fixture for the documented examples; not supplied by the design doc.
::  The ship's todos, which worked example 3 reads: the page scries
::  /x/todos per request, and its island watches /todos, whose every fact
::  is every todo, and pokes todo-action.  /changes gives every todo
::  first, then a todo-update per change; /x/todo/<id> gives one todo.
/-  todo
|%
+$  card  card:agent:gall
+$  state-0  [%0 next=@ud todos=(list item:todo)]
--
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
++  on-init
  ^-  (quip card _this)
  [~ this(next 2, todos ~[[1 | 'Water the plants']])]
++  on-save  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  [~ this(state !<(state-0 old))]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  =(src.bowl our.bowl)
  ?>  ?=(%todo-action mark)
  =/  =action:todo  !<(action:todo vase)
  =^  change=update:todo  state
    ?-  -.action
        %add
      =/  new=item:todo  [next | text.action]
      [[%added new] state(next +(next), todos (snoc todos new))]
    ::
        %toggle
      :-  [%toggled id.action]
      %=  state
        todos  (turn todos |=(i=item:todo ?.(=(id.i id.action) i i(done !done.i))))
      ==
    ==
  :_  this
  :~  [%give %fact ~[/todos] todos+!>(todos)]
      [%give %fact ~[/changes] todo-update+!>(change)]
  ==
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?>  =(src.bowl our.bowl)
  ?+  path  !!
    [%todos ~]    [~[[%give %fact ~ todos+!>(todos)]] this]
    [%changes ~]  [~[[%give %fact ~ todos+!>(todos)]] this]
  ==
++  on-leave  |=(=path ^-((quip card _this) [~ this]))
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  [~ ~]
    [%x %todos ~]  ``todos+!>(todos)
  ::
      [%x %todo @ ~]
    =/  id=(unit @ud)  (slaw %ud i.t.t.path)
    ?~  id  [~ ~]
    =/  found=(list item:todo)  (skim todos |=(i=item:todo =(id.i u.id)))
    ?~  found  [~ ~]
    ``todo-item+!>(i.found)
  ==
++  on-agent  |=([=wire =sign:agent:gall] ^-((quip card _this) [~ this]))
++  on-arvo  |=([=wire =sign-arvo] ^-((quip card _this) [~ this]))
++  on-fail  |=([=term =tang] ^-((quip card _this) [~ this]))
--
