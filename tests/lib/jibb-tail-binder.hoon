/+  jibb, jibb-prelude-fixture
/*  prelude  %jibb  /lib/jibb/prelude/jibb
/*  internal  %jibb  /lib/jibb/internal/jibb
/*  standard-group  %jibb  /lib/jibb/groups/hoon/jibb
/*  full-source  %jibb  /tests/golden/inline-pattern-tag-name-ok/source/jibb
|%
++  test-tail-binder
  ^-  tang
  =/  source=@t  '+$ step\0a  [%move %left n=@ud]\0a  [%move %right n=@ud]\0a  [text=@t %draft]\0a  [text=@t %sent at=@da]\0a  %stop\0a++ rest |= s=step\0a  ?- s\0a    [%move left] "move"\0a    [t %draft] t\0a    [t %sent sent-at] t\0a    %stop "stop"\0a'
  =/  got=@t  (golden-bundle:jibb-prelude-fixture /tests/tail-binder/jibb source ~ ~ ~ prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] ~)
  ?.  =(got 'module kind: library\0a+$ step: step\0a++ rest: $-(step @t)')  ~[leaf+(trip got)]
  ~
++  test-atom-head-proof
  ^-  tang
  ?.  (coverage-atom-head:jibb [%const [%term %tas %move '%move']])  ~[leaf+"literal atom was not recognized"]
  ?.  (coverage-atom-head:jibb [%slot %text [%atom %t]])  ~[leaf+"positional text slot was not recognized"]
  ?:  (coverage-atom-head:jibb [%face %value [%atom %t]])  ~[leaf+"value face was discarded"]
  ?:  (coverage-atom-head:jibb [%var 0])  ~[leaf+"unresolved head was treated as an atom"]
  ?:  (coverage-atom-head:jibb [%cell [%atom %t] [%atom %ud]])  ~[leaf+"cell was treated as an atom"]
  ~
++  test-tail-retains-all-possible-cases
  ^-  tang
  =/  mv=itype:jibb  [%const [%term %tas %move '%move']]
  =/  le=itype:jibb  [%const [%term %tas %left '%left']]
  =/  ri=itype:jibb  [%const [%term %tas %right '%right']]
  =/  dr=itype:jibb  [%const [%term %tas %draft '%draft']]
  =/  se=itype:jibb  [%const [%term %tas %sent '%sent']]
  =/  ln=itype:jibb  [%cell le [%slot %n [%atom %ud]]]
  =/  rn=itype:jibb  [%cell ri [%slot %n [%atom %ud]]]
  =/  sn=itype:jibb  [%cell se [%slot %at [%atom %da]]]
  =/  cases=(list itype:jibb)  ~[[%cell mv ln] [%cell mv rn] [%cell [%slot %text [%atom %t]] dr] [%cell [%slot %text [%atom %t]] sn]]
  =/  typ=itype:jibb  [%union cases ~ ~ ~]
  =/  pat=pattern:jibb  [%cell *span:jibb ~[[%lit *span:jibb [%term %tas %move '%move']] [%bind *span:jibb %tail]]]
  =/  parts=(unit coverage-parts:jibb)  (coverage-project:jibb pat typ ~ 1.024)
  ?~  parts  ~[leaf+"overlapping atom head did not project"]
  ?.  ?=(%union -.tail.u.parts)  ~[leaf+"possible tails were collapsed"]
  =/  got=(list itype:jibb)  cases.tail.u.parts
  ?.  =(4 (lent got))  ~[leaf+"possible tail cases were lost"]
  ?.  ?&  (lien got |=(v=itype:jibb =(v ln)))
          (lien got |=(v=itype:jibb =(v rn)))
          (lien got |=(v=itype:jibb =(v dr)))
          (lien got |=(v=itype:jibb =(v sn)))
      ==
    ~[leaf+"a possible tail case was lost"]
  ~
++  test-full-pattern-fixture
  ^-  tang
  =/  got=@t  (golden-bundle:jibb-prelude-fixture /tests/tail-binder/jibb full-source ~ ~ ~ prelude internal ~[[%hoon /lib/jibb/groups/hoon/jibb standard-group]] ~)
  =/  wanted=@t
    (of-wain:format ~['module kind: library' '+$ step: step' '+$ colour: colour' '+$ shape: shape' '++ describe: $-(step @t)' '++ elsewhere: $-(step @t)' '++ rest: $-(step @t)' '++ aura: $-(shape @t)' '++ other-union: $-(shape @t)' '++ sample: $-(step @t)' '++ sample-bare: $-(step @t)' '++ atom: $-(@tas @t)' '++ noun: $-(* @t)'])
  ?.  =(got wanted)  ~[leaf+(trip got)]
  ~
--
