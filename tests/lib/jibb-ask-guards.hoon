::  Source-identity and canonical template guards for the partial ask prelude.
/+  jibb
/*  public  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
|%
++  ask-guard-errors
  ^-  (list tape)
  =/  prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb public internal)
  ?~  prep  ~["source-backed prelude did not prepare"]
  ?.  =(source.iface.u.prep `public)  ~["public prelude source changed"]
  =/  ask=(unit ischeme:jibb)  (find-jibb-mold:jibb %ask iface.u.prep)
  ?~  ask  ~["ask mold unavailable"]
  ?.  ?=(%union -.typ.u.ask)  ~["ask did not retain a union identity"]
  ?.  =(origin.typ.u.ask `[/lib/jibb/internal/jibb %ask])  ~["ask private origin changed"]
  ?.  =(vars.u.ask ~[0])  ~["ask is not unary generic"]
  ?.  (identity-union-parameters:jibb vars.u.ask args.typ.u.ask)  ~["ask arguments lost their identity"]
  ?.  =((lent cases.typ.u.ask) 3)  ~["ask case count changed"]
  =/  pure=(list itype:jibb)  (skim cases.typ.u.ask |=(c=itype:jibb ?=([%cell [%const [%term %tas %pure *]] *] c)))
  =/  agent=(list itype:jibb)  (skim cases.typ.u.ask |=(c=itype:jibb ?=([%cell [%const [%term %tas %agent *]] *] c)))
  =/  store=(list itype:jibb)  (skim cases.typ.u.ask |=(c=itype:jibb ?=([%cell [%const [%term %tas %store *]] *] c)))
  ?.  &(?=([* ~] pure) ?=([* ~] agent) ?=([* ~] store))  ~["ask case identities changed"]
  =/  private=(list iwidth-dependency:jibb)
    (skim dependencies.iface.u.prep |=(d=iwidth-dependency:jibb =(at.d /lib/jibb/internal/jibb)))
  ?.  ?=([* ~] private)  ~["private source dependency missing or ambiguous"]
  ?.  =(source.i.private `internal)  ~["private source dependency changed"]
  ?.  ?=(~ (prepare-prelude-with-internal:jibb public ''))  ~["missing private source was accepted"]
  ::  A same-named public mold must not acquire the private nominal origin.
  =/  fake=@t  '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ ask |$ [M] [%local value=M]\0a'
  =/  fake-prep=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb fake internal)
  ?~  fake-prep  ~["local ask control did not prepare"]
  =/  fake-ask=(unit ischeme:jibb)  (find-jibb-mold:jibb %ask iface.u.fake-prep)
  ?~  fake-ask  ~["local ask control did not infer"]
  =/  fake-type=itype:jibb  typ.u.fake-ask
  =/  stolen=?
    ?:(?=(%union -.fake-type) =(origin.fake-type `[/lib/jibb/internal/jibb %ask]) |)
  ?:  stolen  ~["local ask acquired private origin"]
  =/  deps=(list [label=@t src=@t])
    :~  ['missing list' '/= internal /lib/jibb/internal\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['altered list' '/= internal /lib/jibb/internal\0a+$ list |$ [A] ~\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['duplicate list' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['missing unit' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['altered unit' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  %wrong\0a  [~ u=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['duplicate unit' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ unit |$ [A]\0a  ~\0a  [~ u=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
        ['changed unit face' '/= internal /lib/jibb/internal\0a+$ list |$ [A]\0a  ~\0a  [i=A t=(list A)]\0a+$ unit |$ [A]\0a  ~\0a  [~ other=A]\0a+$ ask |$ [M] (ask.internal M)\0a']
    ==
  =/  failures=(list tape)
    %+  turn  deps
    |=  item=[label=@t src=@t]
    =/  changed=(unit iprelude:jibb)  (prepare-prelude-with-internal:jibb src.item internal)
    ?~  changed  ""
    =/  leaked=(unit ischeme:jibb)  (find-jibb-mold:jibb %ask iface.u.changed)
    ?~  leaked  ""
    (trip label.item)
  =.  failures  (skim failures |=(t=tape !=(t "")))
  ?^  failures  failures
  =/  absent=(unit @)  ~
  =/  zero=(unit @)  `0
  ?.  !=(absent zero)  ~["absent state was conflated with present zero"]
  ~
++  test-ask-guards
  ^-  tang
  (turn ask-guard-errors |=(reason=tape leaf+reason))
--
