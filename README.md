# pokemon-trainer

Gen 3 (Emerald) pokemon trainer and difficulty setting mod.

Read this if you want to know how this mod hooks to emerald and be aware of its compatibilities:
https://github.com/tectorifter/p-trainer/blob/main/SEAMS.md

## TRAIN editor

- Adds TRAIN to the field party menu. Never for eggs or battle-switch menus.
- Page one edits IVs, EVs, nature and gender; the ABILITY tab swaps ability
- slot 1/2 for 5000 on commit; the HIDDEN tab is a stub (reports, no-op).
- Page two (MOVES) teaches Egg / Relearn / Tutor moves for 5000 each, with a
- forget-slot picker; HM slots are refused.
- Option `1512 EVS`: OFF / NPC / PLAYER / BOTH (252 per stat stays; the total
- cap becomes 1512 for the chosen side). TRAIN enforces it on commit; enemy
- mons are stamped `ptEvCap1512` at battle start when the scope covers them;
- `mod.exports.evTotalCap(scope, side)` is the shared rule.

## Battle systems (0.2.x)

- `ITEM REUSE` (default ON): snapshots every roster mon's `item`/`heldItem`
- at battle start and hands back anything consumed, flung, thieved or knocked
- off after battle ends. Only empty slots are refilled, so mid-battle gains
- are kept.
- `EXP SHARE` (default OFF): OFF / GENERATION 1 / 2 / 3 / 6 with the same
- formulas as g9-Battle-Scene, hooked to Gen 3's own `exp.gain` seam. Bench
- shares are paid directly with EVs and raise `battle.exp_gained`; their
- level-up presentation follows the vanilla award.
- `DOUBLES` (default OFF): trainers fielding 2+ Pokemon force the game's own
- native double battle (`battle_bridge` `double` flag, no custom scene).
- Wild battles are untouched.
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
- `DMG SPLIT` (default OFF): gen 4 damage split per move damage category
- (Physical, Special), instead of it being decided by move's type (fire, water...)

## Layout

- `main.lua` — entry: options, EV-cap exports, boots everything.
- `options.lua` — the seven option rows (mirrored in main.lua).
- `shared.lua` — roster walks, side split, wild check, stat recompute.
- `train/train_screen.lua` — the TRAIN editor + party-menu injection.
- `battle/item_reuse.lua`, `battle/exp_share.lua`, `battle/doubles.lua`,
- `battle/level_adapt.lua`, `battle/difficulty.lua` — battle systems.
- `overworld/rematch.lua` — the `world.talk` rematch question.
