# pokemon-trainer

Standalone Gen 3 (Emerald) TRAIN editor. Adds a TRAIN row to the
Emerald/RSE field party menus.

## TRAIN editor

- Adds TRAIN to the field party menu. Never for eggs or battle-switch menus.
- Page one edits IVs, EVs, nature and gender; the ABILITY tab swaps ability
- slot 1/2 for 5000 on commit; the HIDDEN tab is a stub (reports, no-op).
- Page two (MOVES) teaches from four lists drawn from the game's own data:
- RELEARN (level-up moves at its level, free), TM, EGG and TUTOR (5000
- each), with a forget-slot picker; HM slots can be replaced.
- Option `1512 EVS`: OFF / NPC / PLAYER / BOTH (252 per stat stays; the total
- cap becomes 1512 for the chosen side). TRAIN enforces it on commit; enemy
- mons are stamped `ptEvCap1512` at battle start when the scope covers them;
- `mod.exports.evTotalCap(scope, side)` is the shared rule.

## Battle systems (0.2.x)

- `DAMAGE SPLIT` (default OFF): damaging moves use their gen 4 physical/special
- class (52 of 354 change, classes from PokeAPI — see Credits) instead of the gen 3 type-based
- split. Implemented in the live `battle.damage` hook by swapping the attack/defense
- stat pair the formula reads; burn, screens, Choice Band/Hustle/Guts and
- Marvel Scale are re-attributed to the new class, Counter/Mirror Coat bookkeeping
- follows it too. Struggle, fixed-damage and OHKO moves are untouched.

- `ITEM REUSE` (default ON): snapshots every roster mon's `item`/`heldItem`
- at battle start and hands back anything consumed, flung, thieved or knocked
- off after battle ends. Only empty slots are refilled, so mid-battle gains
- are kept.
- `EXP SHARE` (default OFF): OFF / GENERATION 1 / 2 / 3 / 6 with period-accurate party splits,
- hooked to Gen 3's own `exp.gain` seam. Bench
- shares are paid directly with EVs and raise `battle.exp_gained`; their
- level-up presentation follows the vanilla award.
- `DOUBLES` (default OFF): trainers fielding 2+ Pokemon force the game's own
- native double battle (`battle_bridge` `double` flag, no custom scene),
- but only when the player can field two usable mons (otherwise vanilla
- single). Wild battles are untouched.
- `REMATCHES` (default OFF): talking to a beaten trainer asks "Battle
- again?"; YES re-runs that trainer's own native script (intro, battle,
- defeat line, prize money, flag), NO keeps the after-battle line.
- `LV ADAPT` (default VANILLA): -5 / +5 / +10 shift trainer teams around
- your strongest party mon, 0 parks them exactly at it. Each team's own
- level gaps are kept (levels are recomputed from a per-mon original
- baseline), wild battles are skipped.
- `DIFFICULTY` (default VANILLA): EASY (0 IV / 0 EV), NORMAL (25%), HARD
- (50%), VERY HARD (75%), HELL (100% = 31 IV and a full EV spread). The EV
- share of the raised budget follows `1512 EVS`: HELL with NPC/BOTH cover is
- 252 in every stat. Wild battles are skipped.
<<<<<<< HEAD
- `ENEMY EVO` (default OFF): enemy trainer mons evolve when their level
- allows it. Level evos at their level; trade/happiness at 25 (40 for final
- evos of 3-stage lines); stones and Feebas at 35; Wurmple random at 7;
- Eevee/Tyrogue random at 25+; Nincada 20-24 Ninjask, 25+ random
- Ninjask/Shedinja; Slowpoke Slowking at 25, either at 37. Eggs, wilds and
- Everstone holders are skipped; moves are kept.
=======
- `DMG SPLIT` (default OFF): gen 4 damage split per move damage category
- (Physical, Special), instead of it being decided by move's type (fire, water...)
>>>>>>> fd2f62697012c3097ca6c3c9f99a233cb59fc351

## Layout

- `main.lua` — entry: options, EV-cap exports, boots everything.
- `options.lua` — the eight option rows (mirrored in main.lua).
- `shared.lua` — roster walks, side split, wild check, stat recompute.
- `train/train_screen.lua` — the TRAIN editor + party-menu injection.
- `battle/item_reuse.lua`, `battle/exp_share.lua`, `battle/doubles.lua`,
- `battle/level_adapt.lua`, `battle/difficulty.lua` — battle systems.
- `battle/enemy_evo.lua` — enemy trainer evolution at battle start.
- `overworld/rematch.lua` — the `world.talk` rematch question.

## Verify

luaparse 5.1 clean on all .lua files; page_refresh with no console errors.

## Credits

- Move physical/special classes (`battle/damage_split_data.lua`) sourced from
- PokeAPI (https://pokeapi.co/docs/v2#moves, `move.damage_class`). Pokemon
- move data is (c) Nintendo / Creatures Inc. / GAME FREAK inc.
