# Prelude inventory: source audit

This is a working inventory, not a completed prelude interface. It lists top-level arms in the Hoon sections selected for inclusion, before checking each signature, unsupported mold, parser exclusion, collision, grouping or Jibb implementation. The first-level arms in selected Hoon doors are listed separately; each still needs classification and a Jibb signature. @iko chose to include all of 3g, with its `tone` exposed as `tone.hoon`, distinct from Jibb's styling type.

The source is the fake ship's `%base` `/sys/hoon.hoon` (Hoon version 135), read through Clay with `tools/ship scry /cx/=base=/sys/hoon/hoon --raw`. SHA-256: `ef538ced0877230f02ff86f9fb7a0abc6833bb1cf0e8675742b4d6ce478fcc92`. It differs in bytes from [upstream Hoon at the inspected commit](https://github.com/urbit/urbit/blob/5a187fededc4582a34fcd6055c67bb63e0917b94/pkg/arvo/sys/hoon.hoon); verify against the actual target ship when updating this inventory.

The vendored prelude defines `poke` in its private internal module and re-exports it as a transparent type. The partial checker resolves its supported source shape and a narrow imported API constructor; complete checking of the private body, other API shapes, effect lowering and runtime execution remain unfinished. `ask` and `qath` are not yet defined there.

Hoon `+$` arms are marked **mold** below; `++` arms can be gates, doors or mold generators, and need individual inspection. Jibb's loobean `not` and Hoon's bitwise `not.bit` are distinct. Parser helpers outside 3g are excluded from the intended prelude except the specifically listed `slav` and `slaw`; the raw candidates below still need to be classified.

## 1a

`add`, `dec`, `div`, `dvr`, `gte`, `gth`, `lte`, `lth`, `max`, `min`, `mod`, `mul`, `sub`.

## 1c

`bite` (mold), `bloq` (mold), `each`, `gate` (mold), `list`, `lone`, `lest`, `mold` (mold), `pair`, `pole`, `qual`, `quip`, `step`, `trap`, `tree`, `trel`, `unit`.

@iko chose to expose Hoon `step` as `step.hoon`, so it does not clash with the Grammar's `step` example. Hoon's `step` uses `@u`. @iko chose one-way widening across Hoon aura families, such as `@ud` and `@ux` into `@u` and `@tD` into `@t`; the reverse needs a check (see [question 19](open-questions.md)). The prelude group needed to expose `step.hoon` is not implemented. Hoon's `bite` is a union of `bloq` and `[bloq=bloq step=step]`; its declaration awaits that group.

## 2a

`biff`, `bind`, `bond`, `both`, `clap`, `clef`, `drop`, `fall`, `flit`, `hunt`, `lift`, `mate`, `need`, `some`.

The following is an audit of the Hoon 135 bodies, not a completed Jibb interface. The partial checker infers `fall`, `need`, `some`, `bind`, `biff`, `both`, `clap`, `clef` and `flit`; the remaining written implementations have been parsed, but complete checker validation remains outstanding. Backend validation remains outstanding for all of them.

| Name | Hoon behavior | Jibb status |
| --- | --- | --- |
| `biff` | Applies a gate returning a unit to a present value; absent stays absent. | Written |
| `bind` | Applies a gate to a present value and wraps the result; absent stays absent. | Written |
| `bond` | Calls a fallback trap for an absent unit, otherwise returns its value. | Missing |
| `both` | Returns a unit of both values when both units are present. | Written |
| `clap` | Returns the present unit if only one is present; combines both values with a gate if both are present. | Written with one shared type for both units and the combining gate, as @iko chose |
| `clef` | Applies a gate returning a unit when both inputs are present; otherwise returns an absent unit. | Written |
| `drop` | Converts an absent unit to an empty list and a present unit to a singleton. | Written |
| `fall` | Returns the value of a present unit or the supplied fallback. | Written; inferred by the partial checker |
| `flit` | Returns a gate that wraps a value only if it satisfies the predicate. | Written |
| `hunt` | Returns the only present unit or chooses between two present values with an ordering gate. | Missing |
| `lift` | Takes a mold and a unit, then applies the mold to a present value as `bind` does. | Missing; Jibb molds are not callable values |
| `mate` | Returns the present unit if only one is present; when both are present it returns one if their values are equal and crashes otherwise. | Missing |
| `need` | Extracts a present value and crashes on an absent unit. | Written; inferred by the partial checker |
| `some` | Wraps a value in a present unit. | Written |

## 2b

`snoc`, `lure`, `fand`, `find`, `flop`, `gulf`, `homo`, `join`, `bake`, `lent`, `levy`, `lien`, `limo`, `murn`, `oust`, `reap`, `rear`, `reel`, `roll`, `scag`, `skid`, `skim`, `skip`, `slag`, `snag`, `snip`, `sort`, `spin`, `spun`, `swag`, `turn`, `weld`, `snap`, `into`, `welp`, `zing`.

The current prelude writes `snoc`, `lure`, `flop`, `join`, `levy`, `lien`, `murn`, `rear`, `reel`, `roll`, `skim`, `skip`, `snip`, `turn` and `weld`. `murn` keeps the present products of its gate in order; `join` inserts a separator between items; `snip` drops the last item, and `rear` returns it or crashes on an empty list. The folds take an explicit initial value as the Prelude table specifies. The partial checker infers `snoc`, `lure`, `weld` and `turn` using the validated prelude `list` mold; most other list helpers remain unsupported by that fragment. Backend validation remains outstanding for all of them.

## 2c

`bex`, `can`, `cat`, `cut`, `end`, `fil`, `hew`, `lsh`, `met`, `rap`, `rep`, `rev`, `rig`, `rip`, `rsh`, `run`, `rut`, `sew`, `swp`, `xeb`, `fe`.

## 2d

`con`, `clz`, `ctz`, `dis`, `ham`, `mix`, `not`.

## 2e

`muk`, `mug`.

## 2f

`aor`, `dor`, `gor`, `mor`.

## 2g

`pow`, `sqt`.

## 2h

`in`.

## 2i

`by`.

## 2j

`ja`, `ju`.

## 2k

`to`.

## 2l

`malt`, `molt`, `silt`.

## 2m

`ly`, `my`, `sy`, `nl`.

## 2n

`aftr`, `cork`, `corl`, `cury`, `curr`, `fore`, `head`, `same`, `succ`, `tail`, `test`, `lead`, `late`.

## 2o

`jar`, `jug`, `map`, `qeu`, `set`.

## 2q

`axis` (mold), `bean` (mold), `flag` (mold), `char` (mold), `cord` (mold), `byts` (mold), `date` (mold), `knot` (mold), `noun` (mold), `path` (mold), `pith` (mold), `stud` (mold), `tang` (mold), `iota` (mold), `tank` (mold), `tape` (mold), `tour` (mold), `tarp` (mold), `term` (mold), `wain` (mold), `wall` (mold).

## 3c

`year`, `yore`, `yell`, `yule`, `yall`, `yawn`, `yelp`, `yo`.

## 3g

Hoon 135's `3g` section has exactly 12 exports: ten `+$` molds (`coin`, `dime`, `edge`, `hair`, `nail`, `pint`, `rule`, `spot`, `tone`, `toon`) and two wet `++` gates (`like`, `wonk`). @iko included the whole section, so the parser-related names below stay in the inventory. Hoon's compiler-result `tone` is exposed as `tone.hoon`; the styling type keeps `tone`.

| Hoon name | Source shape and Jibb audit |
| --- | --- |
| `coin` | A union of `[%$ p=dime]`, `[%blob p=*]`, and `[%many p=(list coin)]`. Its `$~` default is dropped: Jibb molds have no default. @iko approved `%$` as a Jibb term literal and pattern on 2026-10-30; the parser implements it and its golden cases pass under eval and on the ship. Its `%$` case uses the `dime` mold below. |
| `dime` | `[p=@ta q=@]` in Hoon. The `q` field accepts any atom, as does Jibb `@` after @iko's decision in question 15. |
| `edge` | `[p=hair q=(unit [p=* q=nail])]`: a parsing position and either no result or a result and remaining input. |
| `hair` | `[p=@ud q=@ud]`: a parsing position. |
| `like` | A wet mold builder parameterized by a gate `a=$-(* *)`; its generated gate takes a noun, builds an `edge`-shaped result, and applies `a` to the product on success. The prelude declares the generic mold `+$ like |$ [A] [p=hair q=(unit [p=A q=nail])]`. A callable Jibb value form remains open in question 18. |
| `nail` | `[p=hair q=tape]`: parsing input. |
| `pint` | `[p=[p=@ q=@] q=[p=@ q=@]]` in Hoon. The four positions accept atoms independently; Jibb `@` now has the same meaning. |
| `rule` | A gate mold `$-(nail edge)`; Hoon constructs its sample and product from the `nail` and `edge` molds. |
| `spot` | `[p=path q=pint]`: a file path and range. |
| `tone` | Three cases: `[%0 product=*]`, `[%1 block=*]`, and `[%2 trace=(list [@ta *])]`. Expose this Hoon mold as `tone.hoon`, distinct from Jibb's styling `tone`. How the prelude presents that qualified mold must agree with its eventual group implementation. |
| `toon` | Three cases: `[%0 p=*]`, `[%1 p=*]`, and `[%2 p=(list tank)]`. |
| `wonk` | A wet gate that extracts `p` from the successful `q` of an `edge` and crashes on an absent result. The prelude's Jibb gate takes `(like A)` and returns its product `A`; it has been parsed but not yet type-checked or run through a backend. |

The following shapes can be written as Jibb declarations once their referenced prelude molds are present:

```text
+$ dime [p=@ta q=@]
+$ hair [p=@ud q=@ud]
+$ nail [p=hair q=tape]
+$ edge [p=hair q=(unit [p=* q=nail])]
+$ pint [p=[p=@ q=@] q=[p=@ q=@]]
+$ rule $-(nail edge)
+$ spot [p=path q=pint]
+$ coin
  [%$ p=dime]
  [%blob p=*]
  [%many p=(list coin)]
+$ toon
  [%0 p=*]
  [%1 p=*]
  [%2 p=(list tank)]
```

The compiler-result `tone.hoon` has the three cases listed above; the qualified name is a prelude group member, not a `+$` identifier containing a dot. Question 15 in [open-questions.md](open-questions.md) records @iko's decision that `@` is an unrestricted atom, resolving the `dime` and `pint` mismatch. The callable value form of `like` remains unresolved. The new `like` mold and `wonk` gate parse, but full type and backend validation remain outstanding.

## 4a

`po`, `fa`.

## 4b

`at`, `cass`, `cuss`, `crip`, `mesc`, `runt`, `sand`, `sane`, `ruth`, `trim`, `trip`, `teff`, `taft`, `tuba`, `tufa`, `tuft`, `wack`, `wick`, `woad`, `wood`.

## 4k

`co`.

## 4m

`scot`, `scow`, `slat`, `slav`, `slaw`, `slay`, `smyt`, `spat`, `spud`, `stab`, `stap`, `stip`, `pout`, `pave`.

## Selected door arms

These are first-level Hoon arms for the container and base-conversion doors, before applying the parser and internal-helper exclusions or converting door operations to plain Jibb gates.

| Hoon door | Arms |
| --- | --- |
| `in` | `all`, `any`, `apt`, `bif`, `del`, `dif`, `dig`, `gas`, `has`, `int`, `put`, `rep`, `run`, `tap`, `uni`, `wyt` |
| `by` | `all`, `any`, `bif`, `del`, `dif`, `dig`, `apt`, `gas`, `get`, `got`, `gut`, `has`, `int`, `jab`, `mar`, `put`, `rep`, `rib`, `run`, `tap`, `uni`, `uno`, `urn`, `wyt`, `key`, `val` |
| `ja` | `get`, `add`, `zip` |
| `ju` | `del`, `gas`, `get`, `has`, `put` |
| `to` | `apt`, `bal`, `dep`, `gas`, `get`, `nip`, `nap`, `put`, `run`, `tap`, `top` |
| `po` | `ins`, `ind`, `tos`, `tod` |
| `fa` | `cha`, `tok`, `pad`, `enc`, `den` |
| `co` | `em-co`, `ed-co`, `ox-co`, `ro-co` |

The raw 4m candidates need special care: `slat`, `slay`, `stab`, `stap` and `stip` parse atoms or paths, while `slav` and `slaw` are the explicitly approved exceptions. Some door arms, such as `ins.po` and `ind.po`, also parse. The final inventory must classify each rather than expose this raw list wholesale.
