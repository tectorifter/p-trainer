# pokemon-trainer: engine seams

What this mod hooks, wraps and mutates in Gen 3 (Emerald) on gen1recomp.
If your mod touches the same seam, check the Conflict column.

| Field | Value |
|---|---|
| Mod id | `pokemon-trainer` |
| Load priority | 95 |
| Permission | `engine_internals` |
| Optional dependency | `national_dex` |

All boots are `pcall`-guarded. Every wrapper calls through to the native function.

## Compatibility rules

1. Chain `Bridge.start`. Never replace it.
2. Do not assume `exp.gain` `ctx.amount` is vanilla, or that only `ctx.mon` gains EXP/EVs.
3. Do not assume `next` runs in a `world.talk` wrap.
4. Do not restore or clear `mon.item`/`heldItem` on battle end.
5. Do not overwrite `mon.ivs`/`mon.evs` wholesale after `battle.started`.
6. Do not wrap `party_menu.handleInput` or `rom_text.at` without chaining.

Prefer the [public surface](#public-surface) over patching the same seam.

## 1. Event subscriptions (`mod.events:on`)

| Event | Prio | File | Effect | Conflict |
|---|---|---|---|---|
| `battle.started` | 1000 | `battle/item_reuse.lua` | Snapshots roster `item`/`heldItem` (weak-keyed) | none |
| `battle.started` | 900 | `battle/level_adapt.lua` | Backup level scaling on `st.foeParty` | none |
| `battle.started` | 900 | `battle/difficulty.lua` | Backup IV/EV spread on enemy side | none |
| `battle.started` | default | `train/train_screen.lua` | Re-runs `applyStats` on mons edited in TRAIN | none |
| `battle.started` | default | `main.lua` (npc_stamp) | Sets `mon.ptEvCap1512 = true` on enemy mons when `1512 EVS` covers NPCs | Overwriting `ivs`/`evs` without honoring the stamp |
| `battle.ended` | -1000 | `battle/item_reuse.lua` | Refills consumed/lost held items (empty slots only) | Restoring/clearing `item`/`heldItem` yourself |
| `battle.ended` | -1000 | `battle/exp_share.lua` | Clears per-KO award bookkeeping | none |

The two 900-priority entries are fallbacks. The primary path is the `Bridge.start` wrap (section 3).

## 2. Hook wraps (`mod.hooks:wrap`)

| Hook | Prio | File | Effect | Conflict |
|---|---|---|---|---|
| `exp.gain` | 0 | `battle/exp_share.lua` | Replaces returned amount with GEN1/2/3/6 party-share split. Pays benched mons via `Experience.apply` + `Pokemon.gainEVs`. Emits `battle.exp_gained` per bench mon | Assuming `ctx.amount` is vanilla; assuming only `ctx.mon` gains |
| `world.talk` | 0 | `overworld/rematch.lua` | REMATCHES on + beaten trainer: shows "Battle again?". YES clears defeat flag, re-runs trainer script, returns `true` (talk consumed). NO unfreezes | Assuming `next` always runs; managing defeat flags around talking |

## 3. Direct function wraps (monkey-patches)

All call through to the previous function.

### 3.1 `src.core.game3.battle_bridge.start(mArg, game, foe, opts)`

Three wrappers chain on this one function. Boot order: `doubles` → `level_adapt` → `difficulty`.

A further wrapper is safe if it calls the previous `Bridge.start`. Replacing it without chaining uninstalls one of these systems, and ours uninstalls yours.

| Order | Guard flag | File | Mutation before call-through |
|---|---|---|---|
| 1 | `Bridge.__ptDoublesWrapped` | `battle/doubles.lua` | Sets `opts.double = true` and `foe.doubleBattle = true` for non-wild trainers with 2+ party mons. Skips `twoOpponents` |
| 2 | `Bridge.__ptLvAdaptWrapped` | `battle/level_adapt.lua` | Shifts every `foe.party[].level` so the team ace matches the player's top level plus mode delta (-5/0/+5/+10, gaps preserved). Mirrors `foe.level`/`foe.species` from `party[1]` |
| 3 | `Bridge.__ptDifficultyWrapped` | `battle/difficulty.lua` | Overwrites every `foe.party[].ivs`/`.evs` (EASY 0 to HELL 31 + full spread). EV budget follows `1512 EVS` |

### 3.2 TRAIN screen

| Target | Guard flag | File | Mutation |
|---|---|---|---|
| `src.ui.game3.party_menu.handleInput` | `PM.__ptTrainWrapped` | `train/train_screen.lua` | Injects a `STORE`-carrier action relabeled TRAIN into `PM.ACTIONS`. Intercepts A on it to open the editor |
| `src.core.game3.rom_text.at` | `RomText.__ptTrainWrapped` | `train/train_screen.lua` | Returns `"TRAIN"` for `sCursorOptions[14]` while the carrier action is present |

## 4. Engine/UI state mutated

| State | Lifetime | Source |
|---|---|---|
| `m.party.cursorOptions[15] = "TRAIN"` (RSE party-menu manifest) | While editor row is present; original restored after | `train/train_screen.lua` via `src.ui.game3.rse.scene_kit` + `profile` |
| UI stack id `"pttrain"` | Pushed/popped via `src.ui.game3.stack` | `train/train_screen.lua` |
| Trainer defeat flag, via `Flags.setTrainerDefeated(store, nil, tid, false)` | One-shot, on rematch YES | `overworld/rematch.lua` |

## 5. Mon data

### Read

- `level`, `hp`, `stats`, `ivs`, `evs`, `personality`, `nature`, `gender`, `species`, `isEgg`
- `ability` / `abilityId` / `abilityNum`
- `moves` / `pp` / `maxPp`
- `item` / `heldItem`
- `loser.participants` (exp_share)
- Party menu: `PM._party`, `PM.cursor`, `PM.mode`, `PM.ACTIONS`, `PM.actionCursor`

### Written

| Field | Note |
|---|---|
| `level`, `hp`, `stats` | `stats` via `Pokemon.applyStats` |
| `ivs`, `evs` | |
| `personality` | Nature/gender retarget |
| `ability` / `abilityId` / `abilityNum` | |
| `moves` / `pp` / `maxPp` | |
| `item` / `heldItem` | Reuse refill only |
| `mon.ptOrigLevel` | Custom stamp: level baseline |
| `mon.ptEvCap1512` | Custom stamp: raised-EV-cap marker |

### Player-top lookup order

`Runtime.getSession().party` → `game.save.party` → `game.party` → `battle.playerParty`

## 6. Dependencies

Required engine modules are presence-gated. Absence is never fatal.

| Area | Modules |
|---|---|
| Core | `src.core.game3.pokemon`, `.runtime`, `.battle_bridge`, `.battle.experience`, `.trainer_sight`, `.scripting.space`, `.scripting.flags`, `.objects`, `.rom_text`, `.profile`, `.display`, `.audio`, `src.core.Game` |
| UI | `src.ui.game3.party_menu`, `.stack`, `.rse.scene_kit`, `.frlg_font` |
| Render | `src.render.Font`, `love.graphics` |


## Public surface

Use these instead of patching the same seam.

| Export | Members |
|---|---|
| `mod.exports.pt` | `statOf`, `topOfList`, `playerTop`, `visit`, `visitSides`, `isWild`, `recalc`, `opt`, `g3Pokemon` |
| `mod.exports` (EV) | `evScope()`, `evTotalCap(scope, side)`, `evTotalCapFor(side)` |
| Constants | `EV_TOTAL` (510), `EV_TOTAL_1512`, `EV_PER_STAT` (252) |

Options readable live via `mod.options:get(...)`: `ev_1512`, `item_reuse`, `exp_share`, `doubles`, `rematches`, `lv_adapt`, `difficulty`.
