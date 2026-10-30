# Core language

Oct 29, 2026 · @iko

After checking, every Jibb module lowers to the core language: Nock's operations on nouns, plus a lambda calculus with names. The Nock and JavaScript backends both compile it, and an interpreter for it, written in Hoon, is the reference both are tested against. Rules marked *proposed* aren't decided yet.

## Nodes

Fifteen kinds of node: seven that build and test nouns, each one Nock operation; five for control; and natives, crashes and traces.

| Node | Value |
| --- | --- |
| `42`, `%add`, `"milk"` | The atom written, in Jibb's literal syntax |
| `x` | The value bound to `x` |
| `(cons e f)` | The cell of `e` and `f` |
| `(slot n e)` | The value at axis `n` of `e`; crashes if there is none, as Nock 0 does |
| `(edit n e v)` | `e` with axis `n` replaced by `v`; crashes if `e` has no axis `n`, as Nock 10 does |
| `(cell? e)` | `%.y` if `e` is a cell, else `%.n`, as Nock 3 |
| `(eq e f)` | `%.y` if the two nouns are equal, else `%.n`, as Nock 5 |
| `(if c t f)` | `t` if `c` is `%.y`, `f` if it's `%.n`; crashes on anything else, as Nock 6 does |
| `(let x e b)` | `b`, with `x` bound to `e` |
| `(rec ((f l) …) b)` | `b`, with each `f` bound to its `lam`, all visible to each other |
| `(lam x b)` | A function of one sample, bound to `x` in `b` |
| `(app f e)` | `f` called with `e` as its sample |
| `(native n)` | The native function `n` |
| `(crash)` | A crash, as `!!` |
| `(trace m b)` | Prints the cord `m`, then is `b`, as `~&` |

Literals keep the aura they were written with, but only for printing and as a hint to the JavaScript backend. A call with several arguments passes one cell, as Nock's gates take one sample.

## Values and invariants

A value is a noun or a function. A function can sit inside a cell, but it isn't a noun: each backend represents it its own way, and it never crosses between ship and browser.

The front end guarantees the backends:

- **No shadowing.** No binding hides another: Jibb forbids it, and generated names start with `_`, which Jibb names can't.
- **`rec` binds functions.** Every right side of a `rec` is a `lam`.
- **Functions aren't taken apart.** `cell?`, `eq`, `slot` and `edit` never get a function itself, and `eq` never compares nouns that contain one. Island data and models are already first-order. So are `eq`'s arguments and map and set keys, and a gate never tells a union's cases apart.
- **Strict evaluation.** A call's sample is evaluated before the call, and a node's parts in text order; `if` evaluates only the branch it takes. Only `trace` and `crash` can observe the order, and differential tests compare results and whether a program crashes, not traces. So the backends may evaluate a node's parts in another order, as Nock 10 does with edit's v and e.
- **Crashes stay crashes.** Where types already guarantee a test, the backends still crash on a violation, as Nock does, instead of carrying on.

## Text form

S-expressions, so each stage's output can be printed, read back and tested on its own, and backend work can start on hand-written programs.

```
expr   = literal | name
       | "(" "cons" expr expr ")"
       | "(" "slot" axis expr ")"
       | "(" "edit" axis expr expr ")"
       | "(" "cell?" expr ")"
       | "(" "eq" expr expr ")"
       | "(" "if" expr expr expr ")"
       | "(" "let" name expr expr ")"
       | "(" "rec" "(" { "(" name lam ")" } ")" expr ")"
       | lam
       | "(" "app" expr expr ")"
       | "(" "native" name ")"
       | "(" "crash" ")"
       | "(" "trace" expr expr ")" ;
lam    = "(" "lam" name expr ")" ;
module = "(" "module" path { "(" "def" name expr ")" } ")" ;
name   = jname | path ":" jname | "_" ( letter | digit ) { letter | digit } ;   (* own or prelude, imported, generated *)
axis   = digit { digit } ;                                (* at least 1 *)
```

- `literal` is Jibb's literal syntax, and the form a literal was written in is the aura the printer writes it back with.
- `jname` is a Jibb name; `path` is a module's path under `/ui`, as in `api/todo:todo-action`.
- Whitespace separates items, and `::` starts a comment. Source positions aren't written, so golden tests don't change when lines move; the printer can add them as comments.

## Lowering from Jibb

Types, faces and casts leave nothing behind; everything else lowers by these rules.

| Jibb | Core language |
| --- | --- |
| A number, ship, date, term, loobean, `~`, or a string without `{…}` | An atom literal, keeping its aura |
| `"Since {day}"` | `(app (native join) …)` on a list of the pieces, each atom printed first by its aura's native |
| `` `x `` | `(cons ~ x)` |
| `[a b c]`, `[x=a y=b]`, `~[a b]` | Right-nested `cons` in field order; a list ends in `~` |
| `gap+%s2` | `(cons %gap %s2)` |
| `/posts/~zod`, `%/blog/(slug)` | A list of knots, typed segments printed by their aura's native; the runtime adds the base path to an application path |
| `title.p`, `space.theme.theme` | `slot` at the field's axis, nested for longer wings |
| `card.card`, an import | The qualified name `components/card:card` |
| `m(draft=t error=~)` | One `edit` per item, in order: `(edit 7 (edit 6 m t) ~)` |
| `f a b c` | `(app f (cons a (cons b c)))`: the arguments are the sample |
| `\|= [a=@ b=@] body` | `(lam _1 (let a (slot 2 _1) (let b (slot 3 _1) body)))`; a single face, as in `\|= m=model`, names the `lam` itself |
| `\|=%got` | `(lam _1 (cons %got _1))` |
| `++` definitions, at top level or in a gate | A `rec` per group of gates that call each other; a `let` per other value, in dependency order |
| `?- s` | `(let _1 s …)` around a decision tree of `if`, `cell?`, `eq` and `slot`, built by the usual pattern-matrix algorithm; binders become `let`s, and tests the types make redundant are left out |
| `?-` on a loobean | `(if s yes no)` |
| `^- t e` | `e` |
| `~& v body` | `(trace (app _p v) body)`, where `_p` is a printer derived from `v`'s type |
| `!!` | `(crash)` |
| Derived gates and `pure` | `lam`s that build the cells the runtime reads |
| Checks on incoming facts | A validator derived from the path's type, which the runtime runs on each fact |

## Example

The todo island's `update`, from worked example 3:

```jibb
++ update |= [=msg m=model]
  ?- msg
    [%typed t]
      ?- (gth (lent (tuba (trip t))) 80)
        %.y  [m(draft=t error=`"Too long") ~]
        %.n  [m(draft=t error=~) ~]
    %submit        [m(draft="") ~[[%poke (todo-action.todo [%add draft.m]) |=%acked]]]
    [%toggled id]  [m ~[[%poke (todo-action.todo [%toggle id]) |=%acked]]]
    [%got ts]      [m(todos=ts) ~]
    [%acked err]   [m(error=err) ~]
```

lowers to the program below. The model `[todos draft error]` puts `todos` at axis 2, `draft` at 6 and `error` at 7, and `%submit`, the only atom case, needs no test once `cell?` fails.

```
(def update
  (lam _1
    (let msg (slot 2 _1)
    (let m (slot 3 _1)
    (if (cell? msg)
      (let _2 (slot 2 msg)
        (if (eq _2 %typed)
          (let t (slot 3 msg)
            (if (app (native gth) (cons (app (native lent) (app (native tuba) (app (native trip) t))) 80))
              (cons (edit 7 (edit 6 m t) (cons ~ "Too long")) ~)
              (cons (edit 7 (edit 6 m t) ~) ~)))
        (if (eq _2 %toggled)
          (let id (slot 3 msg)
            (cons m (cons (cons %poke (cons (app api/todo:todo-action (cons %toggle id)) (lam _3 (cons %acked _3)))) ~)))
        (if (eq _2 %got)
          (let ts (slot 3 msg) (cons (edit 2 m ts) ~))
          (let err (slot 3 msg) (cons (edit 7 m err) ~))))))
      (cons (edit 6 m "")
            (cons (cons %poke (cons (app api/todo:todo-action (cons %add (slot 6 m))) (lam _4 (cons %acked _4)))) ~)))))))
```

## Programs and linking

- Each module lowers to `(module <path> (def name e) …)`, in source order. Its own and the prelude's definitions are named plainly, since no name may shadow another; imports are qualified, as in `api/todo:todo-action`.
- The linker builds one program per entry: on the ship, each page; in the browser, each island's `update`, `view` and `subs`, and each store. It keeps only the definitions the entry reaches, sorts them by dependency into `let`s and `rec`s, and ends with the entry.
- Values that aren't gates are computed once per program, before anything calls them; the Nock backend may compute them at build time. A value that depends on itself, even through a gate, is an error.
- A module used as a whole value is a cell of its definitions, in name order.

## Natives

- Jetted prelude functions have working Jibb implementations. Foundational gates use private low-level primitives from the internal prelude module. The compiler recognizes the functions' shapes and uses the corresponding Hoon versions, so their jets can fire. The JavaScript runtime supplies corresponding implementations; differential tests check their behavior.
- The lowering uses a few private ones: `join` for interpolation, a printer per aura, and the map and set checks in validators.
- Jetted prelude functions may take gates. On the ship a Jibb gate is shaped like Hoon's, so functions such as `turn`, `sort` and `skim` can call it. In JavaScript native implementations can use loops, which keeps long lists off the stack. Such a function only calls the gate and never takes it apart, so the invariant above still holds.

## Backends

Each node becomes a few Nock operations, or a few lines of JavaScript calling the runtime.

| Node | Nock | JavaScript |
| --- | --- | --- |
| Literal | `[1 a]` | A number or a constant atom; a cord also keeps its string |
| `x` | `[0 a]`, at `x`'s axis in the subject; a name bound by `rec` is an arm of its core, `[9 a 0 c]` with `c` the core's axis | A variable |
| `cons` | A cell of the two formulas | `cell(e, f)` |
| `slot` | `[7 e 0 n]` | `slot(n, e)` |
| `edit` | `[10 [n v] e]` | `edit(n, e, v)` |
| `cell?` | `[3 e]` | `isCell(e)` |
| `eq` | `[5 e f]` | `same(e, f)` |
| `if` | `[6 c t f]` | A conditional that crashes on anything but 0 or 1 |
| `let` | `[8 e b]`, pushing the value onto the subject | `const` |
| `rec` | A core with an arm per function, as `\|%` builds | Function declarations |
| `lam` | A gate shaped like Hoon's: `$` at axis 2, sample at 6 | A closure of one argument |
| `app` | `[9 2 10 [6 e] f]` | `f(e)`; a self call in tail position becomes a loop |
| `native` | The native's Hoon gate | The native's runtime function |
| `crash` | `[0 0]` | A thrown crash |
| `trace` | A `%slog` hint, Nock 11, carrying `[0 leaf+(trip m)]`, since `%slog` takes a priority and a tank, not a cord | `console.log`, then `b` |

Gates are shaped like Hoon's, so `app` calls a Jibb gate and a native's Hoon gate the same way, and Hoon code can call Jibb gates.
