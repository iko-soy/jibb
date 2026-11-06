# Prelude inventory: source audit

This inventory records the Hoon 135 sections selected by Overview, the checked milestone-2 Jibb interfaces, and the names deliberately left out of the checked prelude. The first-level arms of selected Hoon doors are listed separately. `step.hoon` and `tone.hoon` are qualified to distinguish them from unrelated Jibb names.

The source is the fake ship's `%base` `/sys/hoon.hoon` (Hoon version 135), read through Clay with `tools/ship scry /cx/=base=/sys/hoon/hoon --raw`. SHA-256: `ef538ced0877230f02ff86f9fb7a0abc6833bb1cf0e8675742b4d6ce478fcc92`. It differs in bytes from [upstream Hoon at the inspected commit](https://github.com/urbit/urbit/blob/5a187fededc4582a34fcd6055c67bb63e0917b94/pkg/arvo/sys/hoon.hoon); verify against the actual target ship when updating this inventory.

The private internal prelude defines `raw-poke`, the recursive `qath` mold, and the generic `ask` cases. The public prelude re-exports their interfaces and defines `pure`; full-check tests cover the recursive path representation, request types, and source-backed imports. Lowering and runtime execution are separate work.

The public prelude declares the generic `cmd` mold and the `program` and `page` records. The full checker validates their source-backed interfaces and derives supported API/store command and request helpers; runtime execution remains separate work.

The public prelude defines the UI `length`, `align`, `role`, `tone`, and `attr` molds. Its generic `element` is a private sealed type: checked public constructors create elements, while raw node literals do not gain the seal. The keyed `each` and `table` constructors infer a gate-free constraint on their key type, including nested values; the key restriction remains visible through generic wrappers and aliases. The focused UI suites cover constructor interfaces and opacity; rendering and runtime execution remain separate work.

The public prelude defines the approved generic `store` record `[init=S update=*]` and its builder, whose update argument is `$-([A S] S)` while the result exposes only `S`. Store coverage checks both exact schemes, ordinary and multi-case action declarations, derived generic poke/state gates, malformed-prelude controls and downstream structural imports. The local `+$ poke` remains an ordinary action mold. Store declaration checking and watch evidence are implemented; lowering, decoding and execution remain later-milestone work.

The public prelude also defines the exact `theme` mold: three space cords, five normal tone cords, `wide`, `lang` and `zone` cords, `(unit qath)` for `font`, and a unit containing the same five dark tone cords. The shared `type-theme` fixture fully checks the byte-identical real theme and its structural downstream import, including dark absent/present and malformed-field negatives. It does not implement contrast checking, rendering, routing or any other theme behavior.

Hoon `+$` arms are marked **mold** below; `++` arms can be gates, doors, or mold generators. Jibb’s loobean `not` and Hoon’s bitwise `not.bit` are distinct. The final section records the candidates deliberately left out, including the Overview exclusion for parser helpers outside 3g other than `slav` and `slaw`.

## 1a

`add`, `dec`, `div`, `dvr`, `gte`, `gth`, `lte`, `lth`, `max`, `min`, `mod`, `mul`, `sub`.

The source-backed `gth` gate calls a compiler-supplied private comparison interface. The full checker accepts supported equal-aura atom arguments, including loobeans, and returns `?`; lowering, jet recognition and execution remain unfinished. The public `add` and `dec` gates are written in Jibb over private primitive interfaces. The full checker infers a shared atom type that excludes loobeans, including through supported generic calls. The Jibb-written `max`, `min`, `lth`, `gte` and `lte` gates compose `gth` and ordinary Jibb control flow; supported calls infer a shared atom constraint. `sub` recursively decrements its two operands, and `mul` uses repeated addition. The full checker retains their shared arithmetic constraint and distinct decimal, hex and duration calls; loobean multiplication reports its gate and argument sites ([jibb-prelude-arithmetic](../tests/lib/jibb-prelude-arithmetic.hoon)). Primitive execution and jet recognition remain unfinished.

## 1c

`bite` (mold), `bloq` (mold), `each`, `gate` (mold), `list`, `lone`, `lest`, `mold` (mold), `pair`, `pole`, `qual`, `quip`, `step`, `trap`, `tree`, `trel`, `unit`.

The public prelude defines `gate` and `mold` as `$-(* *)`; the [focused suite](../tests/lib/jibb-prelude-gate-mold.hoon) checks their exported types and ordinary callers through the full checker. The suite passed eval and fake-ship checks.

@iko chose to expose Hoon `step` as `step.hoon`, so it does not clash with the Grammar's `step` example. Hoon's `step` uses `@u`. @iko chose one-way widening across Hoon aura families, such as `@ud` and `@ux` into `@u` and `@tD` into `@t`; the reverse needs a check (see [settled question 19](spec/decisions.md#settled-milestone-2-questions)). The source-backed `hoon` prelude group exports `step.hoon` and `tone.hoon`, and the public prelude defines `bite` as a union of `bloq` and `[bloq=bloq step=step.hoon]`. The grouped-prelude suites and the [type golden](../tests/golden/types-prelude-groups/types.txt) check both `bite` forms against the real group source.

## 2a

`biff`, `bind`, `bond`, `both`, `clap`, `clef`, `drop`, `fall`, `flit`, `hunt`, `lift`, `mate`, `need`, `some`.

The public prelude defines every listed unit helper except `lift`. The complete grouped prelude is checked through the common inference core; backend execution and jet recognition remain outstanding.

| Name | Hoon behavior | Jibb status |
| --- | --- | --- |
| `biff` | Applies a gate returning a unit to a present value; absent stays absent. | Written |
| `bind` | Applies a gate to a present value and wraps the result; absent stays absent. | Written |
| `bond` | Calls a fallback trap for an absent unit, otherwise returns its value. | Written and inferred as a curried gate |
| `both` | Returns a unit of both values when both units are present. | Written |
| `clap` | Returns the present unit if only one is present; combines both values with a gate if both are present. | Written with one shared type for both units and the combining gate, as @iko chose |
| `clef` | Applies a gate returning a unit when both inputs are present; otherwise returns an absent unit. | Written |
| `drop` | Converts an absent unit to an empty list and a present unit to a singleton. | Written; inferred by the full checker |
| `fall` | Returns the value of a present unit or the supplied fallback. | Written; inferred by the full checker |
| `flit` | Returns a gate that wraps a value only if it satisfies the predicate. | Written |
| `hunt` | Returns the only present unit or chooses between two present values with an ordering gate. | Written with the ordering gate first, as `(hunt ord a b)`; both ordering outcomes and absent units are inferred |
| `lift` | Takes a mold and a unit, then applies the mold to a present value as `bind` does. | Deliberately omitted; Jibb molds are not callable values |
| `mate` | Returns the present unit if only one is present; when both are present it returns one if their values are equal and crashes otherwise. | Written over `eq`; its generic payload retains the gate-free constraint |
| `need` | Extracts a present value and crashes on an absent unit. | Written; inferred by the full checker |
| `some` | Wraps a value in a present unit. | Written |

## 2b

`snoc`, `lure`, `fand`, `find`, `flop`, `gulf`, `homo`, `join`, `bake`, `lent`, `levy`, `lien`, `limo`, `murn`, `oust`, `reap`, `rear`, `reel`, `roll`, `scag`, `skid`, `skim`, `skip`, `slag`, `snag`, `snip`, `sort`, `spin`, `spun`, `swag`, `turn`, `weld`, `snap`, `into`, `welp`, `zing`.

The current prelude writes `snoc`, `lure`, `flop`, `join`, `lent`, `zing`, `levy`, `lien`, `murn`, `rear`, `reel`, `roll`, `skim`, `skip`, `snip`, `snag`, `scag`, `slag`, `reap`, `sort`, `gulf`, `oust`, `swag`, `snap`, `into`, `skid`, `turn` and `weld`. `lent` counts items by recursion and `add`; `murn` keeps the present products of its gate in order; `join` inserts a separator between items; `snip` drops the last item, and `rear` returns it or crashes on an empty list. The folds take an explicit initial value as the Prelude table specifies. The complete prelude is checked through the common inference core using the validated prelude `list` mold; the focused suites below also check exported schemes and calls. The result casts on `drop`, `skim`, `skip`, `murn`, `join`, `snip`, `levy` and `lien` state their existing result types without changing their bodies. `zing` concatenates homogeneous lists in order; Hoon’s raw `zing` can also flatten heterogeneous noun lists, which this Jibb type does not express. A Hoon translation agrees with Hoon `zing` on selected finite inputs; this is not Jibb execution. Backend validation and jet recognition remain outstanding for all of them.

The full checker infers the list helpers below and their calls with independent numeric and text item types. [jibb-prelude-lists](../tests/lib/jibb-prelude-lists.hoon) checks the exported result types; [types-prelude-list-index-sort](../tests/golden/types-prelude-list-index-sort/) keeps the source and printed types. `sort` follows Hoon's pivot partition, preserving every item. [jibb-prelude-list-edit](../tests/lib/jibb-prelude-list-edit.hoon) and its [golden](../tests/golden/types-prelude-list-edit/) add exact full-check types for the six range, editing and partition helpers; all three list/arithmetic suites passed eval and fake-ship checks. Execution and jet recognition wait for milestone 3.

| Name | Signature | Behavior |
| --- | --- | --- |
| `snag` | `$-([@ud (list A)] A)` | Zero-based index; crashes past the end. |
| `scag` | `$-([@ud (list A)] (list A))` | Takes up to the requested number of items. |
| `slag` | `$-([@ud (list A)] (list A))` | Drops up to the requested number of items. |
| `reap` | `$-([@ud A] (list A))` | Repeats a value the requested number of times. |
| `sort` | `$-([(list A) $-([A A] ?)] (list A))` | Sorts with the supplied ordering gate. |
| `gulf` | `$-([A A] (list A)) where A is an atom other than ?` | Inclusive increasing range; crashes when the first endpoint is greater. |
| `oust` | `$-([[@ud @ud] (list A)] (list A))` | Removes a slice by start and count. |
| `swag` | `$-([[@ud @ud] (list A)] (list A))` | Takes a slice by start and count. |
| `snap` | `$-([(list A) @ud A] (list A))` | Replaces the indexed item, or appends past the end. |
| `into` | `$-([(list A) @ud A] (list A))` | Inserts at the index, or appends past the end. |
| `skid` | `$-([(list A) $-(A ?)] [p=(list A) q=(list A)])` | Partitions matching and nonmatching items in input order. |

The public `homo`, `fand`, `find` and `spin` implementations now check through the common inference core. `homo` preserves an already homogeneous Jibb list, including gate elements. `fand` returns every sublist offset and `find` the first, with an empty needle returning no match as in Hoon 135. Their equality constraint excludes gate elements. `spin` maps each item while threading state and returns `[p=(list C) q=B]`. The [helper suite](../tests/lib/jibb-prelude-helpers.hoon) checks these exact schemes and independent calls under eval and on the fake ship; [helper goldens](../tests/golden/types-prelude-helpers/) include the printed full-check results.

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

`pow` and `sqt` have source-written implementations over the shared arithmetic operations. `sqt` uses bounded binary search and returns `[p=A q=A]`: the integer root and remainder. Its full-check calls preserve decimal and hexadecimal auras; a loobean argument reports both the gate and argument sites. The helper suite verifies its exported atom constraint.

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

The source-backed `cork` and `corl` compose gates forward and backward, respectively; `cury` and `curr` bind the first and second item of an unfaced pair. `succ` increments an atom through `add`; the full checker infers a shared atom type excluding loobeans. A Hoon translation agrees with Hoon on ten selected inputs; Jibb execution and jet recognition remain unverified. `lead` and `late` are curried pair constructors: `((lead a) b)` returns `[a b]`, and `((late a) b)` returns `[b a]`. Their arguments may have independent types, including gate values, and neither constructor invokes a gate. The common checker infers their polymorphic types. A Hoon translation agrees with Hoon’s helpers on selected inputs, but this is not Jibb execution; lowering and jet recognition remain to be validated by a backend.

`test` is the source-written equality helper with signature `$-([A A] ?) where A contains no gates`. Independent text and ship calls check; a gate argument fails with the required type and both source sites. It is included in the helper suite and goldens above.

## 2o

`jar`, `jug`, `map`, `qeu`, `set`.

## 2q

`axis` (mold), `bean` (mold), `flag` (mold), `char` (mold), `cord` (mold), `byts` (mold), `date` (mold), `knot` (mold), `noun` (mold), `path` (mold), `pith` (mold), `stud` (mold), `tang` (mold), `iota` (mold), `tank` (mold), `tape` (mold), `tour` (mold), `tarp` (mold), `term` (mold), `wain` (mold), `wall` (mold).

The public prelude now also defines `axis`, `bean`, `flag`, `char`, `byts`, `noun`, `tour`, `tarp`, `date`, `term`, `wain`, `wall` and `stud` from the exact Hoon 135 source cited above. `char` is `@t`; `byts` retains `wid=@ud` and `dat=@`; `date` is Hoon's parsed calendar record, not an alias for `@da`. `tarp` retains `d`, `h`, `m`, `s` and the fractional hex-word list `f`. The [data-mold golden](../tests/golden/types-prelude-data-molds/) checks each mold as a gate sample/result and checks byte fields and text lists through the full checker. The recursive `tank` and `tang` molds are exported by prelude preparation and checked by the recursive prelude inventory suite. `iota` and `pith` remain deliberately omitted as described below.

`iota` is deliberately left out for now: Hoon 135 includes signed and floating-aura payloads in its cases, while the current [Prelude decision](spec/decisions.md) rejects signed and floating auras. `pith` depends on `iota` and is also left out until that type-model conflict is resolved. No `iota` cases have been silently removed or widened to a different aura.


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
| `like` | A wet mold builder parameterized by a gate `a=$-(* *)`; its generated gate takes a noun, builds an `edge`-shaped result, and applies `a` to the product on success. The prelude declares the generic mold `+$ like |$ [A] [p=hair q=(unit [p=A q=nail])]`. The Jibb value gate maps the product of an existing result and preserves its position and remaining input; it is checked as part of the complete prelude, while backend validation remains outstanding. |
| `nail` | `[p=hair q=tape]`: parsing input. |
| `pint` | `[p=[p=@ q=@] q=[p=@ q=@]]` in Hoon. The four positions accept atoms independently; Jibb `@` now has the same meaning. |
| `rule` | A gate mold `$-(nail edge)`; Hoon constructs its sample and product from the `nail` and `edge` molds. |
| `spot` | `[p=path q=pint]`: a file path and range. |
| `tone` | Three cases: `[%0 product=*]`, `[%1 block=*]`, and `[%2 trace=(list [@ta *])]`. The source-backed `hoon` group exports this mold as `tone.hoon`, distinct from Jibb's styling `tone`. |
| `toon` | Three cases: `[%0 p=*]`, `[%1 p=*]`, and `[%2 p=(list tank)]`. |
| `wonk` | A wet gate that extracts `p` from the successful `q` of an `edge` and crashes on an absent result. The prelude's Jibb gate takes `(like A)` and returns its product `A`; it is checked as part of the complete prelude, but has not been run through a backend. |

The public prelude defines these shapes:

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

The compiler-result `tone.hoon` has the three cases listed above; the qualified name is a prelude group member, not a `+$` identifier containing a dot. Question 15 in [Decisions](spec/decisions.md#settled-milestone-2-questions) records @iko's decision that `@` is an unrestricted atom, resolving the `dime` and `pint` mismatch. The source-backed value form of `like` maps an existing result's product. Both source gates are checked as part of complete prelude preparation; backend validation for `like` and `wonk` remains outstanding.

## 4a

`po`, `fa`.

## 4b

`at`, `cass`, `cuss`, `crip`, `mesc`, `runt`, `sand`, `sane`, `ruth`, `trim`, `trip`, `teff`, `taft`, `tuba`, `tufa`, `tuft`, `wack`, `wick`, `woad`, `wood`.

The seven text names in the Overview table are available. `trip`, `crip`, `tuba` and `tufa` wrap private primitives; `cass`, `cuss` and `trim` are ordinary Jibb definitions. The full checker retains byte and codepoint auras and the item type of each independent `trim` call, including records and gates. The [text helper golden](../tests/golden/types-prelude-text-helpers/) and five wrong-argument goldens passed under eval and on the fake ship. Lowering and execution belong to milestone 3.

| Name | Checked signature |
| --- | --- |
| `trip` | `$-(@t (list @tD))` |
| `crip` | `$-((list @tD) @t)` |
| `cass`, `cuss` | `$-((list @tD) (list @tD))` |
| `trim` | `$-([@ud (list A)] [p=(list A) q=(list A)])` |
| `tuba` | `$-((list @tD) (list @c))` |
| `tufa` | `$-((list @c) (list @tD))` |

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

The 4m list includes parser candidates: `slat`, `slay`, `stab`, `stap`, and `stip` are excluded, while `slav` and `slaw` are the explicitly approved interfaces. The classification below also records the parser door arms.
## Deliberately left out of the checked prelude

The names in this section are not exported by the current checked prelude. They remain explicit omissions for this milestone; the raw Hoon inventory above is not a claim that these interfaces are available. No substitute signature or weakened key constraint is implied.

- Data and function helpers: `trap`, `lift`, `bake`, `limo`, `spun`, `welp`, `aftr`, and `fore`. `lift` requires molds as callable values; `bake`, `spun`, `aftr`, and `fore` depend on Hoon's wet-gate or sample-inspection behavior, for which the Jibb type model has no settled equivalent. `trap` needs a checked empty-sample gate mold; `limo` and `welp` do not yet have checked source definitions.
- Bit construction (2c): `bex`, `can`, `cat`, `cut`, `end`, `fil`, `hew`, `lsh`, `met`, `rap`, `rep`, `rev`, `rig`, `rip`, `rsh`, `run`, `rut`, `sew`, `swp`, `xeb`, and `fe`. These do not yet have checked Jibb definitions at Hoon's unrestricted-atom and block-size signatures.
- Bit logic (2d): `con`, `clz`, `ctz`, `dis`, `ham`, and `mix` are omitted until their unrestricted-atom signatures and private primitive dependencies are checked. The checked prelude exports `not.bit`; the existing unqualified `not` remains loobean negation.
- Hashing and ordering: `muk`, `mug`, `aor`, `dor`, `gor`, and `mor` are not yet exposed with checked source-backed interfaces.
- Collections: `in`, `by`, `ja`, `ju`, `to`, `malt`, `molt`, `silt`, `ly`, `my`, `sy`, `nl`, `jar`, `jug`, `qeu`, and `set` are omitted until their Hoon tree identity, incoming `apt` checks, and gate-free key constraints are represented together. The `map` mold itself is checked with Hoon tree identity and gate-free keys, but the tree doors and their operations remain omitted; those operations are listed individually below. `get.on` is also omitted; ordered-map comparison and tree identity are not yet available in its public interface.
- Collection door operations: `all.in`, `any.in`, `apt.in`, `bif.in`, `del.in`, `dif.in`, `dig.in`, `gas.in`, `has.in`, `int.in`, `put.in`, `rep.in`, `run.in`, `tap.in`, `uni.in`, and `wyt.in`; `all.by`, `any.by`, `bif.by`, `del.by`, `dif.by`, `dig.by`, `apt.by`, `gas.by`, `get.by`, `got.by`, `gut.by`, `has.by`, `int.by`, `jab.by`, `mar.by`, `put.by`, `rep.by`, `rib.by`, `run.by`, `tap.by`, `uni.by`, `uno.by`, `urn.by`, `wyt.by`, `key.by`, and `val.by`; `get.ja`, `add.ja`, and `zip.ja`; `del.ju`, `gas.ju`, `get.ju`, `has.ju`, and `put.ju`; `apt.to`, `bal.to`, `dep.to`, `gas.to`, `get.to`, `nip.to`, `nap.to`, `put.to`, `run.to`, `tap.to`, and `top.to`. They depend on the omitted collection types and checked operations, including the selected start argument for `rep.by` and `rep.in`.
- Data molds: `iota` and `pith` are omitted because `iota` includes signed and floating auras, which Jibb rejects. `pith` depends on `iota`.
- Time: `yell`, `yule`, `yall`, `yawn`, `yelp`, and `yo` are omitted until their source-backed calendar interfaces are checked. The public prelude provides `year` and `yore`.
- Text and formatting: `at`, `mesc`, `runt`, `sand`, `sane`, `ruth`, `teff`, `taft`, `tuft`, `wack`, `wick`, `woad`, `wood`, `smyt`, `spat`, `spud`, `pout`, and `pave` are omitted until their exact source-backed text or atom-formatting interfaces are checked. The public prelude also provides `scot`, `scow`, `slav`, and `slaw`; their checked signatures appear in [the calendar and formatting golden](../tests/golden/types-prelude-time-print-helpers/types.txt).
- Formatting doors: `po`, `fa`, and `co`, with `tos.po`, `tod.po`, `tok.fa`, `pad.fa`, `enc.fa`, `em-co.co`, `ed-co.co`, `ox-co.co`, and `ro-co.co`, are omitted until their checked conversion dependencies and public interfaces are available.

The Overview separately excludes parser helpers outside 3g, except `slav` and `slaw`. That exclusion covers 4j and 4l, as well as the parser helpers `ins.po`, `ind.po`, `cha.fa`, `den.fa`, `slat`, `slay`, `stab`, `stap`, and `stip`; they are not silently supplied with a different meaning. Signed and floating auras remain excluded as specified.
