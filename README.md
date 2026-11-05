# pokemon-trainer

The backstage pass to your own team — plus a mischievous set of
levers for the whole region. Part TRAIN editor, part battle lab:
sculpt your party to perfection, then twist Hoenn itself until it
fights back exactly as hard as you want.

## TRAIN: your Pokémon, your specs

Open the party menu in the field and there's a new row: TRAIN.
Never on eggs, never mid-battle — just you and your roster, alone.

- **Page one** edits IVs, EVs, nature and gender, and swaps ability
  slot 1/2 for 5000 on commit. (The HIDDEN tab is a stub for now —
  it reports, it doesn't touch.)
- **Page two (MOVES)** teaches from four lists drawn from the
  game's own data: RELEARN (level-up moves at its level, free), TM,
  EGG and TUTOR (5000 each), with a forget-slot picker. Even HM
  slots can be replaced. Build the moveset the level-up chart
  always denied you.
- **1512 EVS** (OFF / NPC / PLAYER / BOTH): shatter the 510 total —
  252 per stat stays, the ceiling becomes 1512 for whichever side
  you choose. Safari-plus's matching toggle covers your side too;
  `mod.exports.evTotalCap(scope, side)` is the single shared rule.

## Battle systems: remix Hoenn

Every one of these is a mod setting, off (or vanilla) by default.
Flip them and the region reshapes around you:

- **DAMAGE SPLIT** — the gen 4 physical/special split, all 354
  moves reclassed (52 change hands), burn, screens, Choice Band,
  Guts and Counter bookkeeping following along. Gen 3's
  type-dictates-everything days are over.
- **ITEM REUSE** — your roster's held items come home. Anything
  consumed, flung, thieved or knocked off mid-battle is handed back
  afterwards into the slots that stayed empty. Experiment freely.
- **EXP SHARE** — OFF, or generations 1, 2, 3, 6, each
  period-accurate, hooked to gen 3's own seam with EVs paid and
  vanilla level-up presentation.
- **DOUBLES** — trainers with 2+ Pokémon force the game's own
  native double battle — but only when you can field two usable
  mons. Wilds stay single.
- **REMATCHES** — talk to any beaten trainer and ask for another
  go: same intro, same battle, same defeat line, same prize money.
- **LV ADAPT** — shift every trainer team around your strongest
  mon: -5 / +5 / +10, or 0 to park them exactly at your level. Each
  team's own level gaps survive the shift. Wilds skip the queue.
- **DIFFICULTY** — EASY (0 IV / 0 EV) through HELL (full 31s and a
  complete EV spread, 252 everywhere under 1512 cover). Pick your
  poison; wilds are exempt.
- **4 EVS** — every defeated mon yields a flat 4 EVs in its native
  stat(s) instead of its ROM yield. Macho Brace doubles to 8.
- **GYM TEAMS** — leaders and the Elite Four fill to 6 with mons of
  their specialty, staged to the team's level so low-level teams
  field first stages, never finals — and the ace moves to the last
  slot, so it is fought last. Follows poke-ecology's GEN toggles
  when present.
- **MACHO BRACE** — the Oldale mart clerk sells one for 2500.
- **ENEMY EVO** — enemy trainer mons evolve when their level allows
  it (level evos at level; trade/happiness at 25; stones at 35;
  Wurmple's coin flip at 7...). Everstone holders, eggs and wilds
  are spared, moves are kept.

## Layout

- `main.lua` — entry: options, EV-cap exports, boots everything.
- `shared.lua` — roster walks, side split, wild check, stat recompute.
- `train/train_screen.lua` — the TRAIN editor + party-menu injection.
- `battle/item_reuse.lua`, `battle/exp_share.lua`, `battle/doubles.lua`,
- `battle/level_adapt.lua`, `battle/difficulty.lua` — battle systems.
- `battle/enemy_evo.lua` — enemy trainer evolution at battle start.
- `battle/gym_teams.lua` — gym/E4 team fill via the `trainer.party` hook.
- `overworld/rematch.lua` — the `world.talk` rematch question.

## Verify

luaparse 5.1 clean on all .lua files; page_refresh with no console errors.

## Credits

- Move physical/special classes (`battle/damage_split_data.lua`) sourced from
- PokeAPI (https://pokeapi.co/docs/v2#moves, `move.damage_class`). Pokemon
- move data is (c) Nintendo / Creatures Inc. / GAME FREAK inc.
