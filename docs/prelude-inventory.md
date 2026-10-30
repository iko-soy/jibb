# Prelude inventory: source audit

This is a working inventory, not a completed prelude interface. It lists top-level arms in the Hoon sections selected for inclusion, before checking each signature, unsupported mold, parser exclusion, collision, grouping or Jibb implementation. The first-level arms in selected Hoon doors are listed separately; each still needs classification and a Jibb signature. `3g` is included for audit because the spec names `coin` and `dime` from it; the rest needs classification.

The source is the fake ship's `%base` `/sys/hoon.hoon` (Hoon version 135), read through Clay with `tools/ship scry /cx/=base=/sys/hoon/hoon --raw`. SHA-256: `ef538ced0877230f02ff86f9fb7a0abc6833bb1cf0e8675742b4d6ce478fcc92`. It differs in bytes from [upstream Hoon at the inspected commit](https://github.com/urbit/urbit/blob/5a187fededc4582a34fcd6055c67bb63e0917b94/pkg/arvo/sys/hoon.hoon); verify against the actual target ship when updating this inventory.

Hoon `+$` arms are marked **mold** below; `++` arms can be gates, doors or mold generators, and need individual inspection. Jibb's loobean `not` and Hoon's bitwise `not.bit` are distinct. Parser helpers are excluded from the intended prelude except the specifically listed `slav` and `slaw`; the raw candidates below still need to be classified.

## 1a

`add`, `dec`, `div`, `dvr`, `gte`, `gth`, `lte`, `lth`, `max`, `min`, `mod`, `mul`, `sub`.

## 1c

`bite` (mold), `bloq` (mold), `each`, `gate` (mold), `list`, `lone`, `lest`, `mold` (mold), `pair`, `pole`, `qual`, `quip`, `step`, `trap`, `tree`, `trel`, `unit`.

## 2a

`biff`, `bind`, `bond`, `both`, `clap`, `clef`, `drop`, `fall`, `flit`, `hunt`, `lift`, `mate`, `need`, `some`.

## 2b

`snoc`, `lure`, `fand`, `find`, `flop`, `gulf`, `homo`, `join`, `bake`, `lent`, `levy`, `lien`, `limo`, `murn`, `oust`, `reap`, `rear`, `reel`, `roll`, `scag`, `skid`, `skim`, `skip`, `slag`, `snag`, `snip`, `sort`, `spin`, `spun`, `swag`, `turn`, `weld`, `snap`, `into`, `welp`, `zing`.

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

`coin` (mold), `dime` (mold), `edge` (mold), `hair` (mold), `like`, `nail` (mold), `pint` (mold), `rule` (mold), `spot` (mold), `tone` (mold), `toon` (mold), `wonk`.

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
