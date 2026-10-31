# Jibb — an Elm-architecture UI language for Urbit

Oct 29, 2026 · @iko

## Summary

Jibb is a Hoon dialect for Urbit frontends. `.jibb` files live in the desk under the `%jibb` mark; each desk's vendored Jibb compiles them, run by one shared host, so `|commit` is the only build step. Elm architecture, a small layout vocabulary, and three stages fixed by module kind:

- **Build**, per commit: pages without data, as HTML, plus the stylesheet.
- **Publish**, per request, in the host: pages with data, from a fresh scry. The host serves every page, to the owner only.
- **Client**, in the browser: islands' `update`, `subs` and `view`, and stores, as JavaScript.

A page without islands ships no JavaScript.

**Goals**: no prebuild; familiar to Hoon programmers; a typed Elm architecture; Hoon's data end to end; no HTML or CSS outside the theme; static by default.

**Non-goals**: agent logic, refinement types, transactions, JavaScript interop beyond Jibb's effects.

*Name*: four letters like the vanes, after the jib, a boat's front sail.

## What Urbit allows

Everything needed exists. The one limit: marks can't follow imports, so the host compiles.

| Mechanism | Gives Jibb | Limit |
| --- | --- | --- |
| [Marks](https://docs.urbit.org/urbit-os/kernel/clay/marks) | `%jibb` stores text, merged by line | A conversion can't scry, so can't follow imports |
| Clay | The host reads each desk's `/ui`, static files included, and hears of commits | Every version of every file is kept |
| Gall | One host agent serves every Jibb desk | Agent names are ship-wide |
| [Eyre `%set-response`](https://github.com/urbit/urbit/releases/tag/urbit-os-v2.139) | Responses without an Arvo event | Keyed by the full request target; entries outlive their agent; auth-flagged entries give non-owners a bare 403 |
| [Eyre noun channels](https://github.com/urbit/urbit/pull/6472) | Pokes and watches as nouns | Needs `jam`, `cue`, `@uw` and an event stream over `fetch` in the browser |
| [Docket](https://docs.urbit.org/build-on-urbit/userspace/dist/docket) | `site+/path`: an agent-served site | One `site` or glob clause per desk |

## Prior art

| Project | What it is | Jibb takes |
| --- | --- | --- |
| [Sail](https://docs.urbit.org/hoon/sail) | Hoon's HTML markup | Rendering in the agent |
| [Udon](https://docs.urbit.org/hoon/udon) | Markdown-like source under its own `%udon` mark, compiled by `;>` | A source language under its own mark |
| [Rudder](https://github.com/Fang-/suite) | Routing for Sail pages | Page routing |
| [Mast](https://github.com/R-JG/mast) | Display state in the agent, HTML diffs over a channel | One generic client script; channels as transport |
| [Docket](https://docs.urbit.org/build-on-urbit/userspace/dist/docket) | One agent serving every desk's front end | One shared host |
| [Elm architecture](https://guide.elm-lang.org/architecture/) | `Model`, `Msg`, `update`, `view`, [effects](https://guide.elm-lang.org/effects/), [keyed nodes](https://guide.elm-lang.org/optimization/keyed.html) | The program model, effects as data, keyed diffing in `each` |
| [elm-ui](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/) | Layout without HTML or CSS | Rows, columns, `el`, wrapping, paragraphs, padding, fill |
| [elm-pages frozen views](https://elm-pages.com/docs/frozen-views/) | `Html Never` content kept out of the bundle | `(element !!)` |
| [Astro islands](https://docs.astro.build/en/concepts/islands/) | HTML by default; marked components hydrate | Islands |
| [Qwik resumability](https://qwik.dev/docs/concepts/resumable/) | State serialised into HTML; the client resumes | A jammed model; `init` never runs in the browser |
| [@urbit/nockjs](https://github.com/urbit/nockjs), [@urbit/aura](https://github.com/urbit/aura-js) | Nouns and aura printing in JavaScript; aura-js lacks `@dr` | References for Jibb's own codec |

## Architecture

Clay stores files; each desk's compiler, run by the shared host, places each module at its kind's stage; only island and store code reaches the browser.

&#91;embedded content: Jibb pipeline · source to browser in three stages\]

## The language

Hoon's runes and literals in an indentation layout, over Hoon's nouns and molds, so pokes, facts and scries need no conversion. The **Grammar** tab defines it.

### Importing Hoon types

`/-` and `/%` translate each mold a module uses from `/sur` files and marks:

| Hoon | Jibb |
| --- | --- |
| `$%`, `$?` | A union if its cases differ as nouns, else an error where used |
| `$@` | A union with an atom case |
| `$^` | A union if its cases differ as nouns, else an error where used |
| `$~` | Dropped |
| `map`, `set`, `qeu`, `jar`, `jug` | The same, by name, checked with `apt` on arrival |
| `mop` | `(mop K V)`, read with `on` |
| Other `$\|` | Its base type |
| `%0`, `%&`, `%\|` | Tags |
| Recursive molds, such as `json` | Recursive, matched by name |
| Records with duplicate field names; cores, gates, vases, signed and float auras | An error where used |

Unused molds are skipped, so unsupported constructs elsewhere in a `/sur` file are fine. A union without a name, as a field's `?(%approve %deny)`, imports too, though Jibb can't write one. Messages and printed types show its cases separated by spaces, as `%approve %deny`; this notation is print-only.

## Prelude

Hoon's standard library regrouped, written in Jibb and vendored as `/lib/jibb/prelude`; an island's bundle carries only what it uses. The exported inventory includes all names from the Hoon library sections listed below, excluding the groups explicitly left out. Jetted prelude functions have working Jibb implementations; the compiler recognizes their shapes and uses the Hoon versions so jets can fire. They may take gates as arguments (Core language). Private helpers and low-level primitives live in a separate internal prelude module, imported without exposing them; foundational public gates are implemented in Jibb on top of those primitives. This source-backed internal module defines `poke`; the public prelude re-exports it as an ordinary transparent type, so ordinary modules can construct and inspect its values. The prelude also holds `eq`, `not`, `page`, `program`, `store`, `pure`, `island`, and the layout elements and molds.

| Group | Hoon | Jibb |
| --- | --- | --- |
| Arithmetic | [1a](https://docs.urbit.org/hoon/stdlib/1a), [2g](https://docs.urbit.org/hoon/stdlib/2g) | Jibb gates over shared atom-constrained type variables, using private low-level primitives: `add`, `sub`, `div`, `mod`, `gth`, `max`, `pow` |
| Units | [2a](https://docs.urbit.org/hoon/stdlib/2a) | `fall`, `need`, `bind`, `biff`, `clap`; `clap` takes two units of the same type and a gate combining two values of that type into one of that type |
| Lists | [2b](https://docs.urbit.org/hoon/stdlib/2b) | `turn`, `weld`, `snag`, `lent`, `sort`, `skim`; `(roll xs init f)` takes a start |
| Maps, sets, queues | [2h](https://docs.urbit.org/hoon/stdlib/2h)–[2m](https://docs.urbit.org/hoon/stdlib/2m), [2o](https://docs.urbit.org/hoon/stdlib/2o) | Plain gates over Hoon's trees, such as `(get.by m k)`; `rep.by` and `rep.in` take a start; ordered maps through lull's `on`, as `(get.on lte m k)` |
| Function helpers | [2n](https://docs.urbit.org/hoon/stdlib/2n) | `same`, `head`, `tail`, `cork`, `cury` |
| Text | [4b](https://docs.urbit.org/hoon/stdlib/4b) | `crip`, `trip`, `cass`, `cuss`, `trim`, `tufa`, `tuba` |
| Atom printing | [4a](https://docs.urbit.org/hoon/stdlib/4a), [4j](https://docs.urbit.org/hoon/stdlib/4j)–[4m](https://docs.urbit.org/hoon/stdlib/4m) | `scot`, `scow`, `slav`, `slaw`. `print-date` prints Urbit-style in the theme's zone, to the minute, as `~2026.10.29..14.30`, from a zone table jibb-dev keeps current. Numbers print as Hoon does, as `1.000` |
| Time | [3c](https://docs.urbit.org/hoon/stdlib/3c) | `yore`, `year` |
| Data molds | [1c](https://docs.urbit.org/hoon/stdlib/1c), [2q](https://docs.urbit.org/hoon/stdlib/2q), [3g](https://docs.urbit.org/hoon/stdlib/3g) | `unit`, `list`, `pair`, `tape`, `path`, `coin`, `dime` and the rest; Hoon's 3g `tone` is `tone.hoon`, distinct from the styling type, and its 1c `step` is `step.hoon` |
| Bits | [2c](https://docs.urbit.org/hoon/stdlib/2c), [2d](https://docs.urbit.org/hoon/stdlib/2d) | Jibb's `not` negates a loobean; Hoon's bitwise `not` is exposed as `not.bit` |
| Hashing and ordering | [2e](https://docs.urbit.org/hoon/stdlib/2e), [2f](https://docs.urbit.org/hoon/stdlib/2f) | Natives behind maps and sets; `aor` exposed |
| Signed and floats | [3a](https://docs.urbit.org/hoon/stdlib/3a), [3b](https://docs.urbit.org/hoon/stdlib/3b) | Left out; `@s…` and `@r…` auras are errors, imported ones included |
| Parsers | [4d](https://docs.urbit.org/hoon/stdlib/4d)–[4i](https://docs.urbit.org/hoon/stdlib/4i), parser helpers in 4j and 4l | Left out, except the explicitly listed `slav` and `slaw` |
| The rest | [1b](https://docs.urbit.org/hoon/stdlib/1b), [2p](https://docs.urbit.org/hoon/stdlib/2p), [3d](https://docs.urbit.org/hoon/stdlib/3d), [3f](https://docs.urbit.org/hoon/stdlib/3f), [4c](https://docs.urbit.org/hoon/stdlib/4c), [4n](https://docs.urbit.org/hoon/stdlib/4n), [4o](https://docs.urbit.org/hoon/stdlib/4o), [5a](https://docs.urbit.org/hoon/stdlib/5a)–[5f](https://docs.urbit.org/hoon/stdlib/5f) | Left out; `jam`, `cue` and `fein` run inside the runtime |

The prelude's `(like A)` mold describes a result with a product of type `A`. Its value gate `(like convert result)` maps a present product with `convert=$-(A B)` and returns `(like B)`, preserving the position and remaining input; an absent result stays absent.

Maps are Hoon's trees on both sides, so equal maps are equal nouns. Requests check incoming maps and sets with `apt`.

## The Elm architecture on Urbit

A module's kind is the type of its `main`:

| Kind | `main` | Runs | Ships JavaScript |
| --- | --- | --- | --- |
| Page | `(element !!)` | At commit | Only its islands' |
| Page with data | `(page load view)` | In the host, per request | Only its islands' |
| Island | `(program init update view subs)` | `init` and the first view with its page; the rest in the browser | Yes |
| Store | `(store init update)` | In the browser, shared by a page's islands | With its islands |

A module without `main` is a library. The host reads a few other names per file kind, listed in the Grammar tab. Pages embed islands as `island main.todo-list ts`, an `(element !!)`:

- `main.todo-list` is a record of exactly `init`, `update`, `view` and `subs`, whose types fix the data, model and messages. `subs` is required, as in Elm's `Browser.element`; `|=(m ~)` means none.
- `ts` is the island's data, checked against `init`'s sample.
- `(element !!)` means no messages reach the page. It also keeps islands out of islands, since an island's view is an `(element M)`.

`init` runs on the ship at the page's stage, and the first view renders into the page with the model jammed in. On start, the browser runs `view` on that model, binds the result to the server's nodes by key, and replaces the subtree if they differ. Island data and models can't hold gates; the checker names the field.

**Loading.** A page with data renders in the host per request, from a fresh scry.

- `load`, `page`'s first argument, maps route parameters to one `ask`: `++ load |=(~ (todos.todo same))` without parameters.
- The host scries the ask's path per request, so the agent must answer a peek there; nothing is watched or kept. A path case can name a separate scry path.
- Pages read full state only; folds matter only to islands.
- Route parameters are `load`'s sample, bound by name and parsed by aura: `/ui/blog/_slug.jibb` has `++ load |=([slug=@ta] (post.api slug same))`.
- `(pure x)` is an ask without an agent; an app's catch-all page passes its path with it.
- A rejected path is a 404.

Loads and renders run in Nock.

**Access.** Every page is private: the host serves it per request, only to the owner, and sends anyone else to `/~/login?redirect=…`. Public pages are left for a later version.

**Errors.** A rejected path, an unparseable parameter or a crashing render gets Jibb's error page, 404 or 500; no error is cached. A control rendered outside an island is rejected: at commit for pages without data, per request otherwise. There's no step limit yet, so an endless render stalls the ship, as in Hoon.

- A crashing island shows the standard crash notice: in the page's HTML for `init` or the first view. In the browser, a crash in `update`, `view` or `subs` drops the message and keeps the model, DOM and watches.

**Effects.** Commands and subscriptions are library values:

```jibb
+$ cmd |$ [M]
  [%poke p=poke reply=$-((unit @t) M)]
  [%go url=@t]
  [%wait gap=@dr msg=M]
  [%now reply=$-(@da M)]
  [%who reply=$-(@p M)]
+$ sub |$ [M]
  [%watch a=(ask M)]
  [%every gap=@dr reply=$-(@da M)]
  [%url reply=$-(path M)]
```

- `poke`, `ask` and `qath` are transparent types defined in the internal prelude and re-exported normally. Derived gates and `pure` also construct requests. A derived poke constructor such as `(todo-action.todo [%add draft.m])` checks its value and supplies the agent and mark, so one island can poke several agents. The agent's mark rechecks on the ship; a nack's `tang` reaches the reply as text. Store constructors poke the store in the browser.
- A request such as `(todos.todo |=%got)` comes from a declared path or a store's `state`; its reply always gets full state. A path with diffs also takes a fold, `(changes.todo |=%got apply)`, which the runtime applies first. Facts are checked; a bad one crashes the reply, which counts as a crashed `update`.
- Islands read agents only by watching. A watch's first fact must be full state, so watching a request whose path case has a separate `scry=` path is a type error in an island. The checker must prove a request is watchable; unknown watchability is also a type error. The runtime acks facts, rewatches after a kick or a dropped connection and reseeds from the first fact; a refused watch shows the crash notice.
- Watches match by agent and path, timers by gap, and the newest reply is always used. After each `update`, `subs` is diffed to start and stop watches and timers. `%now` and `%every` give the time, `%who` the owner's `@p` from `/~/name`; `%wait` is a one-shot delay.

Inputs send a message per `input` event, and one per IME composition, so validation runs as you type; only commands reach the ship. After every event, controls reset to the latest view, so a toggle whose poke fails unchecks. A field's text is rewritten only when it differs, which keeps the caret. Fields are read-only until their island starts.

**Island lifecycle.**

- `init` runs on the ship with the page's data and returns only the model, jammed into the page; the browser resumes from it at start. A reload starts from the model the page is served with.
- A crash in `update` drops the message, keeps the model and shows the standard notice.
- Stores share state between a page's islands. A store module, written like an API file, has `state`, `+$ poke` and `++ main (store init update)`, where `update` applies a poke. The store's `+$ poke` is a declaration, not a mold. Islands import it with `/=` and use its derived gates: a constructor per poke type, and `(state.cart |=%got)`, whose first fact is the current state and each later fact the next.
- A store runs in the browser from its `init` when its first island starts, and lasts as long as the page. Islands keep what they watch in their own models.
- An app is a page whose view is one island under a catch-all route; its `load` passes the path with `pure`. The island's `%url` subscription delivers the path at start and after every change, back and forward included. `go` pushes history, and `go` or `link` within the section changes the island without a reload. Focus then moves to the new view's first heading, which screen readers announce.

## Layout and styling

Elements are ordinary gates with their own signatures. Containers take attribute lists, and `el` adds attributes to anything. Spaces and colours are theme tokens. Text elements come from `text`, as `(text "hi")`. The attribute union is `attr`, so helpers can declare `^- (list attr)`.

| Element | Arguments | Purpose |
| --- | --- | --- |
| `row`, `column`, `wrap` | `attrs kids` | Containers |
| `stack` | `attrs kids` | A column, then a row from the `wide` breakpoint up |
| `el` | `attrs kid` | Adds attributes; `el`'s values win |
| `para` | `kids` | Flowing text |
| `text` | A cord | Text |
| `heading` | `level words` | `<h1>` to `<h6>` |
| `each` | `(list [key=K el=(element M)])` | Keyed children; repeated keys match in order |
| `table` | Columns `(list [header=@t width=length align=align])`, rows `(list [key=K cells=(list (element M))])` | A table with keyed rows |
| `image`, `image-unsafe` | Application path and description; `[url=@t width=@ud height=@ud]` and description, respectively | Boxed to its aspect ratio before loading, never wider than its container; static images are sized from the file; `""` marks it decorative |
| `link`, `link-unsafe` | Application path and label; unchecked cord and label, respectively | See Links and URLs |
| `button` | `label msg` | A control |
| `toggle` | `on label msg` | A control |
| `field` | `label value reply` | A control; `reply` turns its text into a message, as `\|=%typed` |
| `form` | `msg kids` | A control; Enter in a field sends the nearest form's `msg` |
| `island` | `program data` | Embeds an island |

Controls work only in islands; the host rejects a page that renders one outside an island.

| Attribute | Values |
| --- | --- |
| `pad`, `gap` | `%s0` to `%s3`; `gap` on containers only |
| `width` | `[%chars n]`, `[%fill n]`, `%shrink`; `[%fill n]` below 1 counts as 1 |
| `align` | `%start`, `%center`, `%end` |
| `role` | `%body`, `%caption`, `%label` |
| `tone` | `%normal`, `%muted`, `%accent`, `%danger`; danger is also marked `!` and announced |

The same attribute twice in a literal list is an error; otherwise the last wins.

- Rows lay out left to right, centred vertically; columns top to bottom. Children take their content's width unless they fill.
- `[%fill n]` shares leftover space in proportion to `n`, `%shrink` takes the content's width, and `[%chars n]` is `n` widths of `0`.
- Empty elements take no room and no gap.
- Nothing exceeds the page's width: long words break, and wide content scrolls in its own box.

The theme, `++ theme` in `/ui/theme.jibb`, uses the prelude's `theme` mold, with a default for desks without one. It requires `s1` to `s3` (`s0` is zero), five tones, with `normal` the text and `background` the page colour, the page's language, and the time zone dates print in. `wide` is the breakpoint where `stack` becomes a row. Dark tones go under `dark`, used when the reader prefers dark. An optional `font` is an application path to a static font. Tokens become CSS custom properties and `wide` a media query; values must be CSS lengths or colours, and each tone needs 4.5:1 contrast with its background.

```jibb
++ theme  ^- theme
  [ space=[s1="4px" s2="8px" s3="16px"]
    tones=[normal="#222" background="#fff" accent="#17734f" danger="#b3261e" muted="#5f5f5f"]
    wide="60rem"
    lang="en"
    zone="UTC"
    font=`%/static/fonts/inter.woff2
    dark=[tones=[normal="#eee" background="#111" accent="#4c9" danger="#f28b82" muted="#aaa"]]
```

Style attributes compile to atomic classes in one stylesheet built from the theme, so islands can't compute a missing class. `[%chars n]` and `[%fill n]` become inline styles.

### Links and URLs

Both backends escape all text and attributes. In-app links are application paths, `%/blog` or `%/blog/(slug.p)`, checked at compile time against routes and static files; parameters print by aura, and the base path is implicit. They carry no query or fragment, so apps keep their state in the path.

Links, images and navigation also accept two kinds of unchecked cord, through declarations separate from the application-path forms: a root-relative path to another app on the ship, such as `"/apps/groups"`, and an `https`, `mailto` or `tel` URL. `link-unsafe`, `image-unsafe` and `go-unsafe` are the unchecked forms. Both navigation declarations produce the `[%go url=@t]` command; `go` converts the application path to a cord, including the app's base path. A cord starting `//` or `/\` is neither. Any other cord, such as `javascript:`, is drawn as text, and `go` ignores it. External links open in a new tab with `noopener`. Pages send a Content-Security-Policy allowing scripts only from the ship.

## Stages

A module's kind fixes where it runs; nothing infers stages.

| Stage | Runs | Where | Output |
| --- | --- | --- | --- |
| Build | Pages without data | The host, per commit | HTML and the stylesheet |
| Publish | Pages with data | The host, in Nock, per request | HTML |
| Client | Islands' `update`, `subs` and `view`; stores | The browser, in JavaScript | DOM patches from a keyed diff |

- **Islands follow their page**: `init` and the first view run wherever the page renders, and the model is jammed into the HTML.
- **Re-render, then diff**: each message that changes the model re-runs `view`, and a virtual-DOM diff patches the DOM. Children of `each` are keyed, as in Elm's `Html.Keyed`, so focus survives reordering.
- **Functions have no stage**: a gate compiles for whichever side calls it.
- **No JavaScript needed**: pages render without it, and islands show their server-rendered state, with controls `aria-disabled` and fields read-only until they start.
- **Holes later**: compiling views to static HTML plus small functions of the model is an optimisation that changes no types or errors, so it waits.

## The mark

`%jibb` stores source as text and nothing else. Conversions can't follow imports, so the host compiles, and `|commit` never loads the compiler.

### `/mar/jibb.hoon`

```hoon
|_  src=@t
++  grab
  |%
  ++  mime  |=([p=mite q=octs] q.q)      ::  from Unix on |commit
  ++  noun  @t
  ++  txt   of-wain:format
  --
++  grow
  |%
  ++  mime  [/text/x-jibb (as-octs:mimes:html src)]
  ++  txt   (to-wain:format src)
  ++  noun  src
  --
++  grad  %txt                           ::  line diffs and merges, as %hoon does
--
```

- Text, like `%hoon`: `|commit` never fails on a half-written file, and Clay merges by line.
- Compiled modules are cached by their hash, their imports' hashes, Hoon files included, and the desk's compiler, so a commit recompiles only what changed. Import cycles are errors.
- Relinking prints each error with its file, line, column and an excerpt.
- Each app desk vendors `jibb-dev`, as with `base-dev`: compiler, prelude, browser library, and the `%jibb` and static-file marks. It also needs base-dev's `txt`, `txt-diff`, `js`, `bill` and `kelvin` marks, docket's `docket-0`, and a `sys.kelvin`. The `%jibb` desk holds only the shared host and its threads.

### Linking

On every commit, the host reads each Jibb desk's `/ui`, and that desk's compiler rebuilds what changed and relinks, checking modules in dependency order and resolving `/-` and `/%` through Clay. There's no other build path: marks can't follow imports, and `/~` builds only `.hoon` files.

The host is one Gall agent on the `%jibb` desk, serving every Jibb desk, so app agents stay plain Hoon; it never reads their state. A desk opts in by vendoring Jibb and naming its base path in docket's `site+`. The host is thin: it binds paths, watches desks, caches and serves. Each desk's Jibb builds and renders everything else, HTML shell, CSP and error pages included, through a few entry points fixed across releases, so desks upgrade independently. The host clears a desk's cache entries when it's suspended or uninstalled, and accepts pokes only from the ship.

### Agent APIs

Each agent Jibb talks to has `/ui/api/<agent>.jibb`, declaring its pokes in `+$ poke` and its paths in `+$ paths`, over types from the agent's own marks through `/%`. Importing it gives derived gates: a constructor per poke type, which pokes with that type's mark, and a request per path, which checks what comes back. Clashing derived names are errors.

```jibb
::  /ui/api/todo.jibb
/-  todo
/%  %todo-action
/%  %todos
/%  %todo-update
/%  %todo-item

+$ item item.todo
+$ poke todo-action
+$ paths
  [%todos /todos todos]
  [%changes /changes (facts todos todo-update)]
  [%todo-by-id /todo/[id=@ud] todo-item]
```

A path case is a request name, a path and a type. A plain mold is full state, which a watch's first fact must carry. `(facts full diff …)` adds diffs, told apart by mark, and its request takes a fold, here `$-([[%todo-update todo-update] todos] todos)`. Pages scry the path, so the agent must answer a peek there. A case can name another scry path, as in `[%changes /updates (facts todos todo-update) scry=/todos]`, used only by pages.

`poke` and `paths` are declarations, not molds. An API module re-exports its `/%` types, not `/-` faces or `/=` modules.

Any mark name works: `/%  %todo-action-1` gives the type `todo-action-1`, poked with `%todo-action-1`. Helper molds such as `item` come from the `/sur` file through `/-`. The marks are the agent author's:

```hoon
::  /mar/todo-action.hoon, written with the agent
/-  todo
|_  a=action:todo
++  grab  |%  ++  noun  action:todo  --
++  grow  |%  ++  noun  a  --
++  grad  %noun
--
```

Jibb calls this type `todo-action`, after its mark. Jibb's own types never cross to the ship, so they need no marks.

### Routing by file path

Pages route by their path under `/ui`; islands, stores and libraries are only imported.

| File | URL |
| --- | --- |
| `/ui/index.jibb` | `/apps/my-app` |
| `/ui/blog/index.jibb` | `/apps/my-app/blog` |
| `/ui/blog/_slug.jibb` | `/apps/my-app/blog/{slug}`; `_` marks a parameter |
| `/ui/settings/__rest.jibb` | `/apps/my-app/settings` and below; `__` marks a catch-all, passed to `load` as a path |

- One URL per page, with no trailing slash; other forms and query strings get the same page.
- A literal beats a parameter, which beats a catch-all. Two parameters at one level, `blog.jibb` beside `blog/index.jibb`, and a catch-all beside `index.jibb` are errors. Folders can be parameters: `/ui/_user/posts.jibb`.
- Parameters bind to `load`'s sample by name, which must have exactly those fields; a catch-all's is a `path`.
- `/apps/my-app/~jibb/` and `/apps/my-app/static/` belong to the host.

Typed segments share one notation across routes, application paths and agent paths. `@ta` and `@tas` are raw text, checked as knots, as `/blog/my-post`; other auras print and parse as Hoon does, so `@ud` is `1.000`. The host splits the raw URL, so dots stay inside segments; a segment that doesn't parse is a 404. `%/todo/(id)` and `[%todo-by-id /todo/[id=@ud] todo-item]` print the same way.

### Desk layout

```
::  an app desk
/mar/jibb.hoon  /mar/png.hoon  …     marks                 from jibb-dev
/lib/jibb.hoon  /lib/jibb/prelude    compiler and prelude  from jibb-dev
/lib/jibb/runtime/js                 browser library       from jibb-dev
/mar/txt.hoon  /mar/js.hoon  …       marks                 from base-dev
/mar/docket-0.hoon                   docket's mark         from landscape
/sys.kelvin                          the desk's kelvin
/sur/todo.hoon  /mar/todo-*.hoon     the %todo agent's types and marks
/app/my-app.hoon                     your agent, unchanged
/ui/api/todo.jibb                    the %todo agent's API
/ui/index.jibb  /ui/blog/_slug.jibb  pages
/ui/todo-list.jibb                   an island
/ui/stores/cart.jibb                 a store
/ui/theme.jibb                       theme
/ui/static/img/logo.png              static files
/ui/tests/todo.jibb                  tests: each test- arm is one test
desk.bill                            %my-app
desk.docket-0                        site+/apps/my-app, with docket's other clauses

::  the %jibb desk, installed once per ship
/app/jibb.hoon                       the shared host
/ted/clear.hoon  /ted/test.hoon      -jibb!clear, -jibb!test
```

The `%todo` and `%blog` agents run on their own desks; this desk copies their `/sur` and `/mar` files.

## Client runtime and Eyre

Islands compile to small JavaScript modules sharing one hand-written library; pages without islands load neither.

- **Two backends.** Each module lowers to the core language (Core language), which both backends compile: Nock on the ship for rendering and `init`, with natives calling jets, and JavaScript in the browser for `update`, `subs` and `view`. Differential tests under Node, from jibb-dev, keep them in agreement.
- **Shared library**, under 20 KB: its own noun codec (`jam`, `cue`, `@uw`, treaps, aura printing), the channel client, a keyed DOM differ, stores and URL subscriptions. It reads events over `fetch`, since `EventSource` can't send `x-channel-format`, deletes its channel on `pagehide`, and opens a fresh one when a reconnect gets a 404.

### What a page with an island looks like

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>My ship</title>
  <link rel="stylesheet" href="/apps/my-app/~jibb/s/0v1a2b3.css">
</head>
<body>
<main>
  … server-rendered HTML …
  <div data-jibb-island="0v4c5d6">
    … initial HTML …
    <script type="application/x-jibb-state">… jammed model, @uw-encoded …</script>
  </div>
</main>
<script type="module" src="/apps/my-app/~jibb/lib.0v7e8f9.js" async></script>
</body>
</html>
```

The title is the first `heading 1`, and the language comes from the theme. `data-jibb-island` names the module by hash, so a shared island loads once; each instance keeps its state block in its own element. Every island starts as soon as the library loads.

### Eyre integration

- The host binds each desk's base path, from its `site+` clause, with `%connect`.
- The host serves every page itself, per request and only to the owner, sending anyone else to the login page; no page enters Eyre's cache.
- CSS, the library, island modules and static files sit at content-hashed, immutable paths, cached with `%set-response` and served without an Arvo event. They're public, since only pages carry data, and each build's files stay a day after replacement so open tabs keep working.
- A commit re-renders every page without data, which the host then serves from its copy.
- The cache is ship-wide and outlives its agent. The host caches only under each desk's base path and clears a desk's entries on suspend or uninstall; run `-jibb!clear` before uninstalling `%jibb`.
- Cache hits skip Eyre's other handling, such as HTTPS redirects and CORS.

### Static files

Images and fonts live under `/ui/static/`, committed with the desk, so installers get them; jibb-dev's marks store them as they are.

- Pages refer to them by application path, as `(image %/static/img/logo.png "The logo")`. A missing file is a compile error, and images are sized from the file.
- Each file is served from Eyre's cache at a URL with a short hash of its bytes, such as `/apps/my-app/static/0v1.7rq2a/img/logo.png`, marked immutable; a changed file gets a new URL.
- Clay keeps every version, and cache hits ignore `Range`, so audio, video and large image sets stay out for now.

## Worked examples

One page per stage.

### 1. Static: `/ui/about.jibb`

```jibb
++ main view

++ view
  column ~[width+[%fill 1] pad+%s3 gap+%s2] ~[
    heading 1 "About this ship"
    para ~[(text "Hosted on Urbit. This page ships no JavaScript.")]
    el ~[tone+%accent] (link %/blog "Read the blog")
```

An `(element !!)`: build stage, one HTML file plus the stylesheet, rendered on commit, titled "About this ship".

### 2. Published: `/ui/blog/index.jibb`

```jibb
/-  blog
/=  api   /ui/api/blog
/=  card  /ui/components/card

++ main (page load view)
++ load |=(~ (posts.api same))

++ view |= ps=(list post.blog)
  column ~[gap+%s2] (turn ps card.card)
```

A `page`: each request scries `%blog` and renders in Nock.

### 3. Interactive: `/ui/todo-list.jibb` and `/ui/index.jibb`

```jibb
/=  todo  /ui/api/todo

++ main (program init update view subs)

+$ model [todos=(list item.todo) draft=@t error=(unit @t)]
+$ msg
  [%typed text=@t]
  %submit
  [%toggled id=@ud]
  [%got todos=(list item.todo)]
  [%acked err=(unit @t)]

++ init |= ts=(list item.todo)
  [ts "" ~]

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

++ subs |= m=model
  ~[[%watch (todos.todo |=%got)]]

++ view |= m=model
  column ~[gap+%s2] ~[
    heading 2 "Todos"
    each (turn todos.m row-of)
    row ~[gap+%s1] ~[
      el ~[width+[%fill 1]] (field "New todo" draft.m |=%typed)
      button "Add" %submit
    el ~[tone+%danger] (text (fall error.m ""))

++ row-of |= t=item.todo
  [id.t (toggle done.t text.t [%toggled id.t])]
```

```jibb
/=  todo       /ui/api/todo
/=  todo-list  /ui/todo-list

++ main (page load view)
++ load |=(~ (todos.todo same))

++ view |= ts=(list item.todo)
  column ~[pad+%s3] ~[
    heading 1 "My ship"
    island main.todo-list ts
```

| Part | Stage | Becomes |
| --- | --- | --- |
| The page's view, "My ship" | Publish | HTML from a fresh scry per request, served only to the owner |
| The island's `init` and first view | Publish, with its page | HTML in the page, with the jammed model |
| `update`, `subs`, `view` | Client | A JavaScript module, loaded with the page; model changes re-run `view` and patch the DOM |
| `[%add …]`, `[%toggle …]` | Ship | One poke each: an Arvo event per command, not per keystroke |

### Opting in

A desk becomes a Jibb app by vendoring jibb-dev and naming its base path in docket, here `site+/apps/my-app`. The host on the `%jibb` desk binds it, builds `/ui` with the desk's compiler and serves it. Install `%jibb` first; until then the tile opens Eyre's 404. The app's agent, `/app/my-app.hoon`, is unchanged.

## Sources

- [Marks](https://docs.urbit.org/urbit-os/kernel/clay/marks) and [fas runes](https://docs.urbit.org/hoon/rune/fas), docs.urbit.org
- [Sail](https://docs.urbit.org/hoon/sail) and [Udon](https://docs.urbit.org/hoon/udon), docs.urbit.org
- [Docket files](https://docs.urbit.org/build-on-urbit/userspace/dist/docket), docs.urbit.org
- [urbit-os v2.139 release: Eyre cache and noun channels](https://github.com/urbit/urbit/releases/tag/urbit-os-v2.139); [eyre: add cache, PR #5927](https://github.com/urbit/urbit/pull/5927); [eyre: noun channels, PR #6472](https://github.com/urbit/urbit/pull/6472)
- [Publication caches for Eyre](https://gist.github.com/Fang-/1939a5b51fb2f821d960e05b74ad5f9f), an earlier design proposal; Eyre shipped `%set-response` instead
- [Mast](https://github.com/R-JG/mast), [Fang-/suite (Rudder)](https://github.com/Fang-/suite)
- [Elm architecture](https://guide.elm-lang.org/architecture/), [effects](https://guide.elm-lang.org/effects/) and [keyed nodes](https://guide.elm-lang.org/optimization/keyed.html); [elm-ui](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/)
- [elm-pages frozen views](https://elm-pages.com/docs/frozen-views/), [Astro islands](https://docs.astro.build/en/concepts/islands/), [Qwik resumability](https://qwik.dev/docs/concepts/resumable/)
- [@urbit/nockjs](https://github.com/urbit/nockjs), [@urbit/aura](https://github.com/urbit/aura-js)
