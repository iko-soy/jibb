::  /lib/jibb-js.hoon: Core to JavaScript, on the ship
::
::    A port of js/core/compiler.mjs for one Core expression, so the host
::    can compile each island module's linked Core for the browser.  It
::    emits the text that compiler makes for the same expression: one
::    `evaluate(runtime, natives)` export, its variables numbered in the
::    same order, with self tail calls of recursive arms as loops.  A
::    module-level gate or arm remembers its last product, unless the
::    program traces; a lambda inside a gate whose free names are all
::    module-level is made once.
::
::  API
::    +compile  expr  @t     an ES module whose evaluate returns the value
::
/+  jibb-core
|%
::  Bindings, innermost scope first; each maps a Core name to its variable.
::  depth counts the lambdas around a scope: 0 is the module's own level.
+$  scopes  (list [depth=@ud names=(map name:jibb-core @t)])
::  The emitter's state: the next variable's number, the natives used, the
::  slots of the lambdas made once, latest first, and whether the program
::  remembers products, which it does unless it traces.
+$  state  [next=@ud natives=(set @t) hoisted=(list @t) memoize=?]
::
++  compile
  |=  e=expr:jibb-core
  ^-  @t
  =/  made=[out=@t s=state]  (expression e ~ [0 ~ ~ !(has-trace e)])
  =/  slots=@t
    ?~  hoisted.s.made  ''
    (rap 3 ~['let ' (join-text ', ' (flop hoisted.s.made)) ';\0a'])
  =/  checks=(list @t)
    %+  turn  (sort ~(tap in natives.s.made) aor)
    |=(name=@t (rap 3 ~['requireNative(natives, ' (json-text name) ');']))
  %+  rap  3
  :~  '// Generated from Jibb Core. Do not edit.\0a'
      'export function evaluate(runtime, natives) {\0a'
      'const {apply, cons, slot, edit, isCell, same, requireLoobean, crash, traceLazy, memo} = runtime;\0a'
      'const requireNative = (registry, name) => {\0a'
      '  if (registry === null || typeof registry !== \'object\' || !Object.hasOwn(registry, name) || typeof registry[name] !== \'function\') {\0a'
      '    throw new TypeError(`missing native ${name}`);\0a'
      '  }\0a'
      '};\0a'
      (join-lines checks)
      '\0a'  slots  'return '  out.made  ';\0a}\0a'
  ==
::
++  join-lines
  |=  lines=(list @t)
  ^-  @t
  (join-text '\0a' lines)
::
++  join-text
  |=  [between=@t parts=(list @t)]
  ^-  @t
  ?~  parts  ''
  =/  out=@t  i.parts
  =/  rest=(list @t)  t.parts
  |-
  ?~  rest  out
  $(rest t.rest, out (rap 3 ~[out between i.rest]))
::
::  A JSON string of a name; Core names are terms, paths and generated
::  names, none of which needs an escape but these.
++  json-text
  |=  text=@t
  ^-  @t
  =/  chars=tape  (trip text)
  =|  out=tape
  |-
  ?~  chars  (rap 3 ~['"' (crip (flop out)) '"'])
  ?:  =('"' i.chars)  $(chars t.chars, out (weld (flop "\\\"") out))
  ?:  =('\\' i.chars)  $(chars t.chars, out (weld (flop "\\\\") out))
  $(chars t.chars, out [i.chars out])
::
++  fresh
  |=  s=state
  ^-  [@t state]
  [(cat 3 '$' (crip (a-co:co next.s))) s(next +(next.s))]
::
::  A new variable for a name in the innermost scope.  A name bound twice
::  in one scope is the JavaScript compiler's error too.
++  define
  |=  [n=name:jibb-core sc=scopes s=state]
  ^-  [var=@t sc=scopes s=state]
  ?>  ?=(^ sc)
  ?<  (~(has by names.i.sc) n)
  =^  var  s  (fresh s)
  [var [i.sc(names (~(put by names.i.sc) n var)) t.sc] s]
::
++  lookup
  |=  [n=name:jibb-core sc=scopes]
  ^-  @t
  ?~  sc  ~|([%unbound-core-name n] !!)
  =/  found=(unit @t)  (~(get by names.i.sc) n)
  ?^  found  u.found
  $(sc t.sc)
::
::  The depth of the scope binding a name, and of the innermost scope.
++  depth-of
  |=  [n=name:jibb-core sc=scopes]
  ^-  @ud
  ?~  sc  ~|([%unbound-core-name n] !!)
  ?:  (~(has by names.i.sc) n)  depth.i.sc
  $(sc t.sc)
::
++  scope-depth
  |=  sc=scopes
  ^-  @ud
  ?~(sc 0 depth.i.sc)
::
::  A scope inside the innermost one, as a let or rec makes, or a lambda.
++  nested
  |=  sc=scopes
  ^-  scopes
  [[(scope-depth sc) ~] sc]
::
++  inside
  |=  sc=scopes
  ^-  scopes
  [[+((scope-depth sc)) ~] sc]
::
++  has-trace
  |=  e=expr:jibb-core
  ^-  ?
  ?-  -.e
    ?(%lit %var %native %crash)  |
    %cons    |($(e hed.e) $(e tal.e))
    %slot    $(e body.e)
    %edit    |($(e body.e) $(e value.e))
    %cell    $(e body.e)
    %eq      |($(e left.e) $(e right.e))
    %if      |($(e test.e) $(e yes.e) $(e no.e))
    %let     |($(e value.e) $(e body.e))
    %rec     |((lien arms.e |=(a=rec-arm:jibb-core ^$(e fun.a))) $(e body.e))
    %lam     $(e body.e)
    %app     |($(e fun.e) $(e sample.e))
    %trace   &
  ==
::
::  The Core names an expression uses that it does not bind.
++  free-names
  |=  [e=expr:jibb-core bound=(set name:jibb-core)]
  ^-  (set name:jibb-core)
  ?-  -.e
    ?(%lit %native %crash)  ~
    %var     ?:((~(has in bound) name.e) ~ (sy ~[name.e]))
    %cons    (~(uni in $(e hed.e)) $(e tal.e))
    %slot    $(e body.e)
    %edit    (~(uni in $(e body.e)) $(e value.e))
    %cell    $(e body.e)
    %eq      (~(uni in $(e left.e)) $(e right.e))
    %if      (~(uni in (~(uni in $(e test.e)) $(e yes.e))) $(e no.e))
    %let     (~(uni in $(e value.e)) $(e body.e, bound (~(put in bound) name.e)))
    %rec
      =/  inner=(set name:jibb-core)
        (~(gas in bound) (turn arms.e |=(a=rec-arm:jibb-core name.a)))
      =/  arms=(list rec-arm:jibb-core)  arms.e
      =/  out=(set name:jibb-core)  $(e body.e, bound inner)
      |-
      ?~  arms  out
      $(arms t.arms, out (~(uni in out) ^$(e fun.i.arms, bound inner)))
    %lam     $(e body.e, bound (~(put in bound) sample.e))
    %app     (~(uni in $(e fun.e)) $(e sample.e))
    %trace   (~(uni in $(e message.e)) $(e body.e))
  ==
::
::  A lambda inside another whose every free name is bound outside all
::  lambdas is the same closure each time, so it is made once.
++  closed
  |=  [e=expr:jibb-core sc=scopes]
  ^-  ?
  %+  levy  ~(tap in (free-names e ~))
  |=(n=name:jibb-core =(0 (depth-of n sc)))
::
++  expression
  |=  [e=expr:jibb-core sc=scopes s=state]
  ^-  [@t state]
  ?-  -.e
      %lit  [(rap 3 ~['BigInt("' (crip (a-co:co val.lit.e)) '")']) s]
      %var  [(lookup name.e sc) s]
  ::
      %cons
    =^  hed  s  $(e hed.e)
    =^  tal  s  $(e tal.e)
    [(rap 3 ~['cons(' hed ', ' tal ')']) s]
  ::
      %slot
    =^  body  s  $(e body.e)
    [(rap 3 ~['slot(' (crip (a-co:co axis.e)) 'n, ' body ')']) s]
  ::
      %edit
    =^  body  s  $(e body.e)
    =^  value  s  $(e value.e)
    [(rap 3 ~['edit(' (crip (a-co:co axis.e)) 'n, ' body ', ' value ')']) s]
  ::
      %cell
    =^  body  s  $(e body.e)
    [(rap 3 ~['isCell(' body ')']) s]
  ::
      %eq
    =^  left  s  $(e left.e)
    =^  right  s  $(e right.e)
    [(rap 3 ~['same(' left ', ' right ')']) s]
  ::
      %if
    =^  test  s  $(e test.e)
    =^  yes  s  $(e yes.e)
    =^  no  s  $(e no.e)
    [(rap 3 ~['(requireLoobean(' test ') ? ' yes ' : ' no ')']) s]
  ::
      %let
    =^  value  s  $(e value.e)
    =/  inner=[var=@t sc=scopes s=state]  (define name.e (nested sc) s)
    =^  body  s  $(e body.e, sc sc.inner, s s.inner)
    [(rap 3 ~['(() => { const ' var.inner ' = ' value '; return ' body '; })()']) s]
  ::
      %rec
    =/  bound=[vars=(list @t) sc=scopes s=state]  (define-arms arms.e (nested sc) s)
    ::  A module-level arm remembers its last product; inside, its name is
    ::  the bare function, so its own recursion does not.
    =/  memo=?  &(memoize.s =(0 (scope-depth sc)))
    =/  decls=[out=(list @t) s=state]  (declarations arms.e vars.bound sc.bound s.bound memo)
    =^  body  s  $(e body.e, sc sc.bound, s s.decls)
    [(rap 3 ~['(() => {\0a' (join-lines out.decls) '\0areturn ' body ';\0a})()']) s]
  ::
      %lam
    =^  made  s  (lambda e sc s ~ |)
    ?:  =(0 (scope-depth sc))
      [?:(memoize.s (rap 3 ~['memo(' made ')']) made) s]
    ?.  (closed e sc)  [made s]
    =/  slot=@t  (cat 3 '$h' (crip (a-co:co (lent hoisted.s))))
    [(rap 3 ~['(' slot ' ??= ' made ')']) s(hoisted [slot hoisted.s])]
  ::
      %app
    =^  fun  s  $(e fun.e)
    =^  sample  s  $(e sample.e)
    [(rap 3 ~['apply(' fun ', ' sample ')']) s]
  ::
      %native
    =/  key=@t  (print-name:jibb-core name.e)
    [(rap 3 ~['natives[' (json-text key) ']']) s(natives (~(put in natives.s) key))]
  ::
      %crash  ['crash("explicit Core crash")' s]
  ::
      %trace
    =^  message  s  $(e message.e)
    =^  body  s  $(e body.e)
    [(rap 3 ~['traceLazy(' message ', () => ' body ')']) s]
  ==
::
::  A recursive group's arms get their variables first, in order.
++  define-arms
  |=  [arms=(list rec-arm:jibb-core) sc=scopes s=state]
  ^-  [vars=(list @t) sc=scopes s=state]
  =|  vars=(list @t)
  |-
  ?~  arms  [(flop vars) sc s]
  =/  made=[var=@t sc=scopes s=state]  (define name.i.arms sc s)
  $(arms t.arms, vars [var.made vars], sc sc.made, s s.made)
::
++  declarations
  |=  [arms=(list rec-arm:jibb-core) vars=(list @t) sc=scopes s=state memo=?]
  ^-  [out=(list @t) s=state]
  =|  out=(list @t)
  |-
  ?~  arms  [(flop out) s]
  ?~  vars  !!
  ?.  ?=(%lam -.fun.i.arms)  ~|([%recursive-binding-not-a-lambda name.i.arms] !!)
  =^  decl  s  (lambda fun.i.arms sc s `[var=i.vars name=name.i.arms] &)
  =?  decl  memo  (rap 3 ~['const ' i.vars ' = memo(' decl ');'])
  $(arms t.arms, vars t.vars, out [decl out])
::
::  A lambda, or a recursive arm's declaration: one whose body calls itself
::  in a tail position is a loop over its sample.
++  lambda
  |=  $:  e=expr:jibb-core
          sc=scopes
          s=state
          self=(unit [var=@t name=name:jibb-core])
          declaration=?
      ==
  ^-  [@t state]
  ?>  ?=(%lam -.e)
  =/  inner=[var=@t sc=scopes s=state]  (define sample.e (inside sc) s)
  =/  parameter=@t  var.inner
  ?:  &(declaration ?=(^ self) (self-tail body.e name.u.self))
    =^  loop  s.inner  (fresh s.inner)
    =^  current  s.inner  (fresh s.inner)
    ?>  ?=(^ sc.inner)
    =/  looped=scopes
      [i.sc.inner(names (~(put by names.i.sc.inner) sample.e current)) t.sc.inner]
    =^  body  s.inner  (tail-expression body.e looped s.inner [loop name.u.self])
    :_  s.inner
    %+  rap  3
    :~  'function '  var.u.self  '('  parameter  ') {\0alet '  loop  ' = '
        parameter  ';\0afor (;;) {\0aconst '  current  ' = '  loop  ';\0a'
        body  '\0a}\0a}'
    ==
  =^  body  s.inner  (expression body.e sc.inner s.inner)
  ?:  &(declaration ?=(^ self))
    [(rap 3 ~['function ' var.u.self '(' parameter ') { return ' body '; }']) s.inner]
  [(rap 3 ~['((' parameter ') => ' body ')']) s.inner]
::
++  self-tail
  |=  [e=expr:jibb-core name=name:jibb-core]
  ^-  ?
  ?+  -.e  |
    %app  &(?=(%var -.fun.e) =(name name.fun.e))
    %if   |($(e yes.e) $(e no.e))
    %let  $(e body.e)
    %rec  $(e body.e)
  ==
::
::  A recursive arm's body in tail position: a self call sets the loop's
::  sample and continues; anything else returns.
++  tail-expression
  |=  [e=expr:jibb-core sc=scopes s=state self=[loop=@t name=name:jibb-core]]
  ^-  [@t state]
  ?:  &(?=(%app -.e) ?=(%var -.fun.e) =(name.self name.fun.e))
    =^  sample  s  (expression sample.e sc s)
    [(rap 3 ~[loop.self ' = ' sample ';\0acontinue;']) s]
  ?:  ?=(%if -.e)
    =^  test  s  (expression test.e sc s)
    =^  yes  s  $(e yes.e)
    =^  no  s  $(e no.e)
    [(rap 3 ~['if (requireLoobean(' test ')) {\0a' yes '\0a} else {\0a' no '\0a}']) s]
  ?:  ?=(%let -.e)
    =^  value  s  (expression value.e sc s)
    =/  inner=[var=@t sc=scopes s=state]  (define name.e (nested sc) s)
    =^  body  s  $(e body.e, sc sc.inner, s s.inner)
    [(rap 3 ~['const ' var.inner ' = ' value ';\0a' body]) s]
  ?:  ?=(%rec -.e)
    =/  bound=[vars=(list @t) sc=scopes s=state]  (define-arms arms.e (nested sc) s)
    =/  decls=[out=(list @t) s=state]  (declarations arms.e vars.bound sc.bound s.bound |)
    =^  body  s  $(e body.e, sc sc.bound, s s.decls)
    [(rap 3 ~[(join-lines out.decls) '\0a' body]) s]
  =^  value  s  (expression e sc s)
  [(rap 3 ~['return ' value ';']) s]
--
