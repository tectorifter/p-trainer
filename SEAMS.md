# pokemon-trainer seams

Every engine function the mod wraps, and every hook/event/option it
touches. Direct `Bridge.start` / `shop_menu.show` / `gainEVs`
replacements use `__pt*Wrapped` idempotence flags: a second boot (or
a late module load) re-installs nothing. Hook-composed rows
(`ui.party.submenu`, `trainer.party`, `world.talk`, `exp.gain`,
`battle.damage`) call through to native first and only transform
real results. Unless noted, wrappers call through when the mod's
option is OFF, the result is nil, or the arguments aren't ours. No
mod save keys — TRAIN commits write straight to the mon (personality,
EVs, moves); everything else is session state.

Boot (`main.lua`): options define, EV-cap exports (`evScope` /
`evTotalCap` / `evTotalCapFor`, which reads safari-plus'
`evTotalCap` live for the player side), then shared →
train_screen → item_reuse → exp_share → damage_split → doubles →
enemy_evo → gym_teams → level_adapt → difficulty → rematch →
ev_flat4 → macho_brace → npc_stamp, each step pcall-isolated (the
boot wrapper logs the label and continues).

## TRAIN row (`train/train_screen.lua`)

- `ui.party.submenu` hook (next-first composition): appends
  `{ label = "TRAIN", onSelect }` before CANCEL. Gates, all
  pass-through: truthy `ctx.battle`, egg mons, non-field sessions,
  `PM._previousMode == "battle_switch"`, SHIFT / SEND OUT / ENTER /
  NO ENTRY rows present, SUMMARY + CANCEL both absent, and an
  existing TRAIN row (dupe-safe).
- `battle.started`: re-applies `Pokemon.applyStats` to every
  committed gen-3 mon (non-eggs), so staged IV/EV/nature commits
  take effect on the next battle.
- Screen: `src.render.Font` small face, 240x160 1:1 over an
  FRLG-blue surround, `src.core.GameVersion` gen check, a draw
  self-test before `Stack3.push("pttrain", ...)` (hideBelow +
  fullscreen); a failed self-test or push only warns.
- Writes: IVs/EVs via staged stats + `applyStats` (HP-ratio carry),
  nature/ability/gender via `mon.personality`, moves from the
  engine's own learnset/TM/egg/tutor tables with a forget-slot
  picker; TRAIN costs come out of the party-menu session money.

## Battle systems (`battle/*.lua`)

- Item reuse (`item_reuse.lua`): `battle.started` snapshots every
  roster mon's `item` / `heldItem`; `battle.ended` hands back
  consumed, flung, thieved or knocked-off items into slots left
  empty. Mid-battle gains are kept.
- Exp share (`exp_share.lua`): `exp.gain` hook (`awardFoe`) pays
  bench shares per generation split (1/2/3/6) with EVs and raises
  `battle.exp_gained`; `battle.ended` (priority -1000) clears the
  per-battle paid tables.
- Damage split (`damage_split.lua`): `battle.damage` hook swaps the
  attack/defense stat pair the formula reads for moves whose gen 4
  class differs from their gen 3 type class (burn, screens, Choice
  Band/Hustle/Guts, Marvel Scale and Counter/Mirror Coat follow the
  new class; Struggle, fixed-damage and OHKO moves untouched).
- Doubles (`doubles.lua`): direct `Bridge.start` wrap (guarded
  `Bridge.__ptDoublesWrapped`): sets a copied opts table's
  `double = true` (plus `foe.doubleBattle`) when the option is ON,
  the fight is a non-double trainer battle, the foe fields 2+, and
  the player can field two usable mons
  (`Party.monsStateToDoubles` vs `PLAYER_HAS_TWO_USABLE_MONS`,
  fail-open when the API is absent). Wilds never qualify.
- Difficulty (`difficulty.lua`): direct `Bridge.start` wrap plus
  `battle.started` to stage enemy IVs/EVs per tier (HELL = 31 IV +
  full spread, EV share follows 1512 EVS cover). Wilds skipped.
- Level adapt (`level_adapt.lua`): direct `Bridge.start` wrap plus
  `battle.started` to shift trainer teams around the player's
  strongest mon (-5/+5/+10/0) from a per-mon original baseline,
  keeping each team's own gaps. Wilds skipped.
- Enemy evo (`enemy_evo.lua`): direct `Bridge.start` wrap plus
  `battle.started` to evolve enemy trainer mons via native
  `Evolution.apply` (level at level; trade/happiness 25, 40 for
  3-stage finals; stones/Feebas 35; Wurmple 7; Eevee/Tyrogue 25+;
  Nincada/Shedinja and Slowpoke splits). Eggs, wilds and Everstone
  holders skipped; moves kept; poke-ecology disabled gens skipped
  while that mod is present.
- Gym teams (`gym_teams.lua`): `trainer.party` hook (next-first):
  fills listed leader/E4 teams to 6 with specialty-type lines at the
  team's top level (staged under enemy-evo conditions), moves the
  ace (highest-level original mon) to the last slot, never dupes a
  species or picks a legendary (poke-ecology legend/mythical sets
  join while present); GEN-gated stages fall back to the highest
  enabled stage. Runs before the battle is built.
- 4 EVs (`ev_4.lua`): direct `Pokemon.gainEVs` wrap — any stat that
  would gain from a KO gains exactly 4 (8 with Macho Brace, Pokerus
  kept), clamped to 252 per stat and the side's total cap; a
  `battle.ended` subscriber reconciles pending clones to
  `evTotalCapFor("player")`.
- NPC 1512 stamp (`main.lua` npc_stamp): `battle.started` flags
  `ptEvCap1512` on enemy-side mons when the scope covers NPCs, so
  the EV math tops up to 1512 instead of 510.

## Overworld (`overworld/*.lua`)

- Rematch (`rematch.lua`): `world.talk` hook (next-first): for a
  beaten trainer (`trainer_sight.isTrainerType` / `getTrainerId` /
  `isDefeated` against the `scripting.space` store) freezes and
  faces the object and asks "Battle again?" (`ui.game3.message` +
  `ui.game3.choice`); YES clears the defeat flag
  (`scripting.flags.setTrainerDefeated`) so the re-run native talk
  replays the intro, battle, defeat line and prize money, while
  `battle.started` / `battle.ended` track the pending rematch and
  re-mark defeat only on player wins.
- Macho Brace (`macho_brace.lua`): prices MACHO BRACE at 2500 via
  `mod.content.items:patch` at load, and wraps
  `src.ui.game3.shop_menu.show` (guarded `SM.__ptShopWrapped`) to
  append it to the Oldale Town mart stock
  (`EM_OLDALE_TOWN_MART`, numeric shelf of 1-60 rows) while the
  option is ON. The ROM stock pointer is never patched; OFF
  restores the vanilla list immediately.

## Other mods (read-only contracts)

- `safari-plus` (`mod.find`, guarded): its `evTotalCap` export
  covers the player side at 1512 while its `1512 EVS` toggle is ON.
  Absent or erroring behaves exactly as before.
- `poke-ecology` (`mod.find`, guarded): GEN 1..9 toggles gate enemy
  evolutions and gym-team fills; its legendary/mythical slot sets
  join the never-pick set. Absent behaves exactly as before.
- Outgoing surface other mods use: `mod.exports.EV_TOTAL` (510) /
  `EV_TOTAL_1512` (1512) / `EV_PER_STAT` (252),
  `mod.exports.evScope()` / `evTotalCap(scope, side)` /
  `evTotalCapFor(side)`, `mod.exports.ptBenchPaid`.

## Options, save, events

- Options (`main.lua`): `ev_1512` (OFF/NPC/PLAYER/BOTH, default
  OFF), `item_reuse` (ON), `exp_share` (OFF/GEN 1/2/3/6),
  `doubles` (OFF), `rematches` (OFF), `lv_adapt` (VANILLA),
  `difficulty` (VANILLA), `damage_split` (OFF), `enemy_evo` (OFF),
  `gym_teams` (OFF), `ev_4` (OFF), `macho_brace` (OFF).
- Save keys: none.
- Events subscribed: `battle.started` (item snapshot, difficulty,
  level adapt, enemy evo, rematch tracking, TRAIN stat re-apply, NPC
  1512 stamp), `battle.ended` (item restore, exp-share clearing,
  EV-clone reconcile, rematch tracking).
