# Jibb grammar

Oct 29, 2026 · @iko

The syntax the compiler accepts.

## Lexical rules

- **Indentation is structure**: a deeper line continues the line above; returning to an earlier indentation closes every block since. Spaces only; blank and comment-only lines don't count.
- **Layout tokens**: a deeper line emits INDENT, the same depth NEWLINE, a shallower one a DEDENT per closed level, then NEWLINE.
- **Open brackets**: a bracket open at line end takes one item per deeper line and closes at the first line that isn't deeper, with no closer. Brackets opened and closed on one line work as usual. A mold's `[` and `(` open the same way, with one field or mold per deeper line. A line may leave several brackets open: the deeper lines go to the last one, or to the body of the last rune, and the others close with it, so `(column ~ ~[` above its items needs no `)`.
- **Tight forms**: `a+b`, `a.b`, `` `x ``, `|=%got` and the openers `~[`, `|=(`, `$?(`, `$-(` take no spaces. A `(` right after a wing is a change: `m(note=text)` changes, `m (note text)` calls. `%/` starts an application path, `%/blog/(slug)`.
- **Spacing**: one space between items; more for alignment. That is style, which the formatter keeps: the parser takes one or more spaces between items, and allows spaces after an opener, before a closer and at the end of a line. Faces `name=value`, puns `=name` and typed path segments `[id=@ud]` take no spaces, and a rune is followed by one.
- **Comments**: `::` to the end of the line, outside strings; inside a string, `::` is text.
- **Names**: Hoon terms; lowercase letters, digits and hyphens, starting with a letter.

## Literals

| Form | Example | Type |
| --- | --- | --- |
| Decimal | `1.000` | `@ud`, or any aura by context; groups of three, as in Hoon |
| Hexadecimal | `0x1f` | `@ux` |
| Base 32 | `0v5.fdf99` | `@uv` |
| Ship | `~zod`, `~sampel-palnet` | `@p` |
| Date | `~2026.10.23`, `~2026.10.23..14.30.00` | `@da` |
| Duration | `~s30`, `~h1.m30` | `@dr` |
| Knot | `~.my-post` | `@ta` |
| String | `"milk"`, `"Since {day}"` | `@t`, a cord; `{…}` prints by aura; tapes come from `trip`; there is no `'…'` form |
| Term | `%add`, `%1.000` | A union's case, or that constant atom where an atom is expected; a numeric term is `%` and a decimal as Hoon writes it, so `%1.000`, never `%1000` |
| Loobean | `%.y`, `%.n` | `?` |
| Null | `~` | A constant: the `~` case of any union with one, such as `(unit A)`, `(list A)`, `(map K V)` or `(set A)` |
| Unit | `` `x `` | `(unit A)` |
| Cell | `[a b c]`, `[text="milk" done=%.n]` | A tuple; a record when faced; a cons where a list is expected |
| List | `~[1 2 3]` | `(list A)` |
| Term-headed pair | `gap+%s2` | `[%gap %s2]`, any operand after the `+` |
| Path | `/posts/~zod` | `path` |
| Application path | `%/blog`, `%/blog/(slug)` | `qath`, checked against routes and static files; no query or fragment |

Every literal reads exactly as Hoon reads it: `1000` is an error (write `1.000`), `~2026.2.31` is `~2026.3.3`, years BC and sub-second groups are dates, and `~2026.10.29..14.30`, the minute form `print-date` writes, is not a literal.

## Expressions

- **Call**: `f a b`; parentheses only group. A call open in parentheses puts its head and first arguments on the first line, then one argument per indented line; a `(` alone at the end of a line puts the head on the first indented line.
- **Lists**: `~[a b c]`, or `~[` at line end with one item per line. On one line, whitespace separates items, so calls need parentheses: `~[(text "hi")]`, which the checker suggests for `~[text "hi"]`. On indented lines, each line is an item.
- **Faced cells**: `[text="milk" done=%.n]`, or one `name=value` per line of an open bracket. A change takes the same items, as `m(done=%.y)`.
- **Pairs and units**: `gap+%s2` and `` `x `` bind tighter than calls, so `pad+%s3 gap+%s2` is two items.
- **Wing** `title.p`, also for imports and prelude groups, which are records: `card.card`, `space.theme.theme`, `get.by`. **Change** `m(draft="x" error=~)`.
- **Inline gate**: `|=(p=post.blog title.p)`, or `|=(p title.p)` when the call fixes the type. A bare name in a sample always binds. `|=%got` is case `%got`'s constructor, typed by the gate expected. A bare name binds at any depth of a sample, so `|= [a=@ b]` binds `a` and `b`.
- **Interpolation**: `{…}` holds any expression; `\{` writes a brace and `\"` a quote; no `<…>`. Strings take Hoon's escapes: `\\` writes a backslash, and `\` with two lowercase hex digits writes that byte, as `\0a` a line feed; any other `\` is an error. A string and each `{…}` close on the line they open, and `::` inside a string is text.
- **No operators**: `eq a b`, `not x`, `gth a b` are gates.

## Runes

A rune's first children sit on its line, the last taking the rest of it; the others follow, indented.

- `++` **luslus**: defines a value, at top level or as local names at the start of any body (a gate's, an arm's, a `^-`'s, a `~&`'s or a `++`'s), visible to each other and the final expression. Gates may call themselves and their siblings; other values can't refer to themselves, so `++ title (trim title)` is an error.
- `+$` **lusbuc**: defines a mold, likewise; molds may be recursive.
- `|=` **bartis**: a gate with a faced sample, `m=model`, `=msg` (`msg=msg`) or `[a=@ b=@]`; the body on the same line or below.
- `$?` **bucwut**: a union, one case per line or `$?(%a %b)`; cases must differ as nouns.
- `?-` **wuthep**: the only branch, exhaustive; the subject on its line, then arms of a pattern and an expression or body. Conditions switch on `%.y` and `%.n`.
- `^-` **kethep**: a cast; the mold on its line, the expression after it or below.
- `~&` **sigpam**: prints the value on its line, then runs the body below; output goes to the ship's log or the browser's console.
- `!!` **zapzap**: a crash, an expression of any type; as a mold, the empty mold. It is an operand, so `f !!` and `~[!!]` need no parentheses.
- `$-` **buchep**: a gate's mold, `$-(sample product)`.
- `|$` **barbuc**: a generic mold, `|$ [A] mold`.

Only `|=`, `$?` and `$-` have wide forms: `|=(sample expr)`, `$?(case case)`, `$-(mold mold)`. Their children are operands, so calls inside need parentheses.

Left out on purpose:

- `|%`, `|_`, `|*`: modules are records.
- `$%`: `$?` covers unions.
- `?+`, `?:`: `?-` is the branch.
- `.=`, `?!`, `=(a b)`, `!x`: `eq` and `not` are gates.
- `=/`: `++` defines values.
- `|-`, `$(…)`: gates recurse by name.
- `~|`: `~&` covers debugging.
- `*mold`: no defaults.
- `=>`, `=<`, `.*` and `a:b`: names never shadow, and `.` reads imports too.
- `!>` and vase runes, `/+`: code also runs in the browser.
- Sail's `;` runes: layout is Jibb's elements.
- Tall forms such as `:~`, `:*`, `%:` and `%=`, the closers `==` and `--`, and other wide forms such as `^-(…)` and `?-(…)`: indentation covers them.
- `@s…` and `@r…` auras: errors wherever used, imports included.

## Imports

Imports come first:

```jibb
/-  todo                         ::  the molds from /sur/todo.hoon this module uses
/%  %todo-action                 ::  a mark's type, named todo-action
/=  card    /ui/components/card  ::  a Jibb module
```

`/%` names a type after its mark, so it takes no face, and any mark name works; Hoon's `/%` binds the mark's core instead. Derived constructors such as `todo-action.todo` supply the agent and mark, so code never writes one. API modules re-export their `/%` types, not `/-` faces or `/=` modules. Import cycles are errors.

## Modules

A file is a module: imports, then definitions.

- `+$ name mold` defines a mold; `++ name expr` a value.
- Names may refer to each other in any order, and no name may shadow one already in scope, imports and the prelude included.
- Molds and values have separate namespaces, told apart by position: `todo-action.todo` is a mold and its constructor, `todos.todo` a mold and a request.
- `main`'s type decides the kind: `(element !!)` a page; `(page R D)` a page with data, from parameters `R` to data `D`; `(program D X M)` an island, with data, model and messages; `(store S)` a store with state `S`. They're built by `(page load view)`, `(program init update view subs)` and `(store init update)`. A module without `main` is a library.
- Everything is exported and read through the import's face, as `card.card`. Only the prelude has private names.
- An API module, `/ui/api/<agent>.jibb`, also exports derived gates: a constructor per `poke` type, adding the agent and mark, and a request per `paths` case, taking a reply over full state, plus a fold for `(facts full diff …)`. A store exports a constructor per `poke` type and a `state` request. Clashing derived names are errors.

Names the host reads, by file:

| File | Names |
| --- | --- |
| Any module | `main`, the kind |
| A store | `state`, `poke` |
| `/ui/api/<agent>.jibb` | `poke`, `paths` |
| `/ui/theme.jibb` | `theme` |
| Under `/ui/tests` | `test-…` arms, one test each |

Every other name is free.

## Molds

A mold is only a type: never called on a noun, and with no default. Types are inferred, Hindley–Milner with aura variables: every expression has a principal type, and there is no subtyping.

- **Atoms**: `@` and auras such as `@ud`, `@t`, `@p`, `@da`; `?` is a loobean. `@` is an atom whose aura isn't known yet, fixed by what it meets: `add` takes `[@ @]` and returns `@`, all one aura, so `(add n 1)` with `n=@ud` is a `@ud`. Different auras never unify. A bare `@` in a `+$` is one aura variable per module, `@ud` if unfixed.
- **Constants**: `%add`, `~` and the loobeans have one value each.
- **Records and tuples**: `[text=@t done=?]`, `[@t ?]`. Faces are part of the type, so `[a=@ b=@]` and `[x=@ y=@]` don't unify. A record too long for one line can leave its `[` open, with one field per deeper line, as an expression's bracket does.
- **Unions**: `$?`; tags take their union from context, as Tag resolution describes. Cases must differ as nouns: at some position of their right-nested cells, one is an atom and the other a cell, or both are different constants. `*`, type variables and molds that can be either, such as `(list A)` or `?`, overlap both. A union whose cases don't all differ is rejected.
- **Containers**: `(list A)`, `(unit A)`, `(set A)`, `(map K V)`, `(mop K V)`, `(qeu A)`, `(jar K V)`, `(jug K V)`.
- **Gates**: `$-(A B)`. Type variables are capitals, generalized per `++`.
- **Paths**: `/todos` is constant, `/` empty, and `/todo/[id=@ud]` typed by aura. `%/blog/(slug)` is an `qath`, checked against routes and static files.
- **Generic molds**: `+$ result |$ [V E] $?` with cases below.
- **Any noun**: `*`. **Empty**: `!!`.
- **Opaque**: `poke`, `ask` and `qath`, built only by derived gates, `pure` and application-path literals. `(facts full diff …)` appears only in an API file's `paths`.
- **Identity**: recursive molds go by name and module.

## Tag resolution

A tag literal or `~` gets a fresh type variable and a pending constraint: the variable must become a union with a matching case, or an atom type the term fits. Once unification fixes the variable, each constraint is checked against the union's cases or, for `@tas`, `@ta`, `@` or `*`, makes the tag that constant atom. A literal that matches nothing is an error naming the union, such as "msg has no case %submitt".

- A constraint records the literal's shape, such as `[@t %draft]`, and matches cases by shape and shared tag positions; a literal in a field position is checked against that field.
- `|=%typed` is a case's constructor: against `$-(@t M)` it is `|=(t [%typed t])`, requiring `M` to have a case `[%typed @t]`. It works for cases tagged at their head; a bare tag is always a value.
- A constrained variable, and any it mentions, doesn't generalize; it stays open until something in the module fixes it. An island's `main` fixes its messages, so islands resolve their own tags.
- A constraint still open when its module is checked is an error asking for a `^-`; the checker never guesses. Library helpers can cast, as in `^- (list attr)`.
- Wing access, changes and `?-` on a type not yet known wait the same way.
- Patterns need none of this; they're checked against the subject's type.

```jibb
::  /ui/components/buttons.jibb, a library with no main
++ add-button |= label=@t
  button label %add                ::  error: nothing fixes the union of %add
++ labelled |= [label=@t msg=M]
  button label msg                 ::  fine: the caller's union
++ wide  ^- (list attr)
  ~[width+[%fill 1] pad+%s2]       ::  fine: the cast fixes the tags
```

## Literals by context

Number and cell literals resolve like tags: each waits for its context and takes a default when its `++` is checked.

| Literal | Can become | Default |
| --- | --- | --- |
| Tag `%a`, or `~` | A union's case or a constant atom | None: an error asking for a `^-` |
| Number `5` | Any aura | `@ud` |
| Cell `[x xs]` | A tuple, a record, a cons | A tuple |

- In `{…}`, an atom prints by its aura: `@ud` as `1.000`, `@da` as a UTC date with sub-seconds, `@p` as a ship, and a bare `@` as `@ud`. `@t`, `@ta`, `@tas` and tapes splice as text; any other cell is an error asking for a printer. For readers, `print-date` prints in the theme's zone, Urbit-style, to the minute, as `~2026.10.29..14.30`; numbers keep Hoon's form.
- String literals are always cords, so an element needs `text`, as `(text "{n} items")`.
- Where a list is expected, `[x xs]` is `x` in front of `xs`.
- A typed segment prints and parses by aura, whether `[id=@ud]` in an agent's paths, a `_` route parameter typed by `load`'s sample, or a `(…)` segment of an application path; `@ta` and `@tas` are raw text.

```jibb
++ view |= [day=@da n=@ud]
  column ~[gap+%s1] ~[
    (text "Updated {day}")     ::  day printed as a date
    (text "{n} items")         ::  n printed as @ud
```

## Patterns

Arms are tried in order. Every case needs an arm or a catch-all, `*` or a bare name. An arm that earlier arms cover, such as a second `%add` or anything after `[%move * *]`, is an error, and a case that should fail says `!!`. A name in a pattern always binds anew, so compare values with `?- (eq a b)`. Patterns take terms, numbers, strings without `{…}`, ships, loobeans and `~`, not lists or pairs.

| Pattern | Matches | Binds |
| --- | --- | --- |
| `%add` | The term | Nothing |
| `%.y`, `%.n` | Yes, no | Nothing |
| `[%add t]` | A cell headed by `%add` | `t`, the rest |
| `[t %draft]` | A pair ending in `%draft` | `t` |
| `[%move %left n]` | Tagged `%move`, then `%left` | `n` |
| `~` | Null | Nothing |
| `[~ x]` | A unit holding a value | `x` |
| `1.000`, `"milk"`, `~zod` | That literal | Nothing |
| `[a b]` | Any cell; `b` is the rest | `a`, `b` |
| `*` | Anything | Nothing |
| `x` | Anything | `x` |

Tags can sit anywhere in a case, and a case can carry several:

```jibb
+$ step $?
  [%move %left n=@ud]
  [%move %right n=@ud]
  [text=@t %draft]
  [text=@t %sent at=@da]
  %stop

++ describe |= s=step
  ?- s
    [%move %left n]   "left {n}"
    [%move %right n]  "right {n}"
    [t %draft]        t
    [t %sent at]      t
    %stop             "stop"
```

Leaving out `%stop` is an error naming it; to crash instead, write `%stop !!`.

## The grammar in EBNF

```
(* Layout: a deeper line emits INDENT, a line at the same depth NEWLINE, and a
   shallower one a DEDENT for each level it closes, then NEWLINE. Blank and
   comment-only lines emit nothing. A bracket left open at the end of a line
   takes the deeper lines below as its items and needs no closer. When a line leaves
   several brackets open, the deeper lines go to the last one, or to the body
   of the last rune, and the others close with it. *)

module     = { import NEWLINE } { definition NEWLINE } ;
import     = "/-" name | "/%" term | "/=" name pathlit ;
definition = "+$" name ( mold | INDENT mold DEDENT )
           | "++" name ( expr | body ) ;

body       = INDENT { definition NEWLINE } expr DEDENT ;
expr       = rune | call ;
call       = operand { operand } ;
operand    = literal | qath | ref | change | pair | unit | group | list | tuple
           | gate | ctor | pathlit | "!!" ;
ref        = wing ;
wing       = name { "." name } ;
change     = wing "(" { item } ")" | wing "(" { item } open ;   (* no space before "("; items named *)
pair       = name "+" operand ;                           (* [%name operand] *)
unit       = "`" operand ;                                (* [~ operand] *)
group      = "(" expr ")" | "(" { operand } open ;
list       = "~[" { operand } "]" | "~[" { operand } open ;
tuple      = "[" { item } "]" | "[" { item } open ;
item       = [ name "=" ] operand ;
open       = INDENT line { NEWLINE line } DEDENT ;
line       = [ name "=" ] expr ;
qath       = "%/" [ asegment { "/" asegment } ] ;
asegment   = knot | "(" expr ")" ;      (* checked against the routes *)
gate       = "|=(" ( field | name ) operand ")" ;    (* the one wide expression *)
ctor       = "|=" term ;                             (* a case's constructor *)

rune       = "|=" field ( expr | body )
           | "^-" mold ( expr | body )
           | "~&" expr body
           | "?-" expr INDENT arm { NEWLINE arm } DEDENT ;
arm        = pattern ( expr | body ) ;     (* every case covered; see Patterns *)

mold       = aura | "*" | "!!" | "?" | "~" | term | loobean | ref | typevar
           | pathmold
           | "(" ref mold { mold } ")" | "(" ref { mold } mlines
           | "[" field { field } "]" | "[" { field } flines
           | "$?" INDENT mold { NEWLINE mold } DEDENT
           | "$?(" mold { mold } ")"
           | "$-(" mold mold ")"
           | "|$" "[" typevar { typevar } "]" mold ;
field      = [ name "=" ] mold | "=" name ;     (* =msg is msg=msg *)
mlines     = INDENT mold { NEWLINE mold } DEDENT ;    (* a mold's ( left open *)
flines     = INDENT field { NEWLINE field } DEDENT ;  (* a mold's [ left open *)
pathmold   = "/" [ segment { "/" segment } ] ;
segment    = knot | "[" name "=" aura "]" ;

pattern    = term | number | string | ship | loobean | "~" | "*" | name
           | "[" pattern { pattern } "]" ;

literal    = number | string | ship | date | duration | knotlit
           | term | loobean | "~" ;
number     = decimal | "0x" hex | "0v" base32 ;
pathlit    = "/" knot { "/" knot } ;
term       = "%" name | "%" decimal | "%&" | "%|" ;
loobean    = "%.y" | "%.n" ;
aura       = "@" { lower } [ upper ] ;
typevar    = upper ;
name       = lower { lower | digit | "-" } ;
knot       = { lower | digit | "-" | "." | "~" | "_" } ;
```

## Example: a store and an island

```jibb
::  /ui/stores/cart.jibb
+$ state [items=(list @t) open=?]
+$ cart-action $?
  [%add item=@t]
  %toggle
+$ poke cart-action

++ main (store init update)
++ init ^- state [~ %.n]
++ update |= [a=cart-action s=state]
  ?- a
    [%add item]  s(items=[item items.s])
    %toggle      s(open=(not open.s))
```

```jibb
::  /ui/basket.jibb
/=  cart  /ui/stores/cart

++ main (program init update view subs)

+$ model [cart=state.cart note=@t]
+$ msg $?
  [%noted text=@t]
  %add
  %toggle
  [%got cart=state.cart]
  [%acked err=(unit @t)]

++ init |= ~
  [[~ %.n] ""]

++ update |= [=msg m=model]
  ?- msg
    [%noted t]     [m(note=t) ~]
    %add           [m(note="") ~[[%poke (cart-action.cart [%add note.m]) |=%acked]]]
    %toggle        [m ~[[%poke (cart-action.cart %toggle) |=%acked]]]
    [%got c]       [m(cart=c) ~]
    [%acked err]   [m ~]

++ subs |= m=model
  ~[[%watch (state.cart |=%got)]]

++ view |= m=model
  column ~[gap+%s1] ~[
    (text "{(lent items.cart.m)} items")
    field "Item" note.m |=%noted
    button "Add" %add
```

A store is written like an API file: `state`, `+$ poke` and `(store init update)`. Islands poke it with derived constructors and watch it with `(state.cart |=%got)`, whose first fact is the current state and each later fact the next. It runs in the browser, shared by the page's islands.
