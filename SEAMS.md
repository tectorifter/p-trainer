# pokemon-trainer seams

Every engine function the mod wraps, and every hook/event/option it
touches. Direct `Bridge.start` / `shop_menu.show` / `gainEVs`
replacements use `__pt*Wrapped` idempotence flags: a second boot (or
a late module load) re-installs nothing. Hook-composed rows
(`trainer.party`, `world.talk`, `exp.gain`,
`battle.damage`) call through to native first and only transform
real results. The summary-screen editor adds no party rows and
subscribes to no party hook. Unless noted, wrappers call through when
the mod's option is OFF, the result is nil, or the arguments aren't
ours. No mod save keys — summary commits write straight to the mon
(personality, EVs, moves); everything else is session state.

Boot (`main.lua`): options define, EV-cap exports (`evScope` /
`evTotalCap` / `evTotalCapFor`, which reads safari-plus'
`evTotalCap` live for the player side), save-editor detect, then shared →
move_tutor → summary_inspector → item_reuse → exp_share → damage_split → doubles →
enemy_evo → gym_teams → level_adapt → difficulty → rematch →
ev_flat4 → macho_brace → npc_stamp, each step pcall-isolated (the
boot wrapper logs the label and continues).
In the save-editor host (Gen + App session + gen 3, same detect as
national_dex) only shared + `overworld/editor_guard.lua` boot: no
battle/world/UI seams install there, and a `mods.loaded` check
refills any missing live species names from the merged pokemon
registry (the dex-848 save-editor failure).

## Move tutor (`train/move_tutor.lua`)

- Raw `PartyMenu.handleInput` patch, Highlander's method: on the
  list-to-action transition the shared string `ACTIONS` table is
  edited in place (TUTOR inserted before CANCEL while the mon has
  unlearned tutor moves, EGG MOVE while it has unlearned egg
  moves; stale rows removed when gates fail),
  `PartyMenu._actionTexts` is rebuilt
  for the new rows (literal texts for TUTOR/EGG MOVE, fresh
  compute per row, so inserts/removals
  by either mod can never misalign labels), and A on a row is
  consumed to open a locked move screen: TUTOR opens the move
  list locked to TUTOR on `pttutor`, EGG MOVE locked to EGG on
  `pteggmove` (own stack ids, so layers can't collide). The EGG
  list unions `Pokemon.eggMoves` across the mon's whole evolution
  line (reverse map derived from live engine evolution data,
  nothing hardcoded) including known moves
  (re-teaching one reports ALREADY KNOWN, free). Locked lists
  cost 5000 a teach, ignore left/right,
  and close on B. Gates, all pass-through: truthy
  `PartyMenu._battle`, egg mons, non-field sessions,
  `PM._previousMode == "battle_switch"`, SHIFT / SEND OUT / ENTER /
  NO ENTRY rows present, SUMMARY + CANCEL both absent. Non-string lists
  (another mod's hook layer active) are left fully alone. No
  `ui.party.submenu` subscription, so the engine keeps the raw
  string list Highlander's sort/RENAME/RELEARN patches drive on.

## Summary screen (`train/summary_inspector.lua`)

- Hooks each native summary skin once (FireRed/LeafGreen menu,
- Emerald `rse/summary_menu` draw, Ruby/Sapphire `rs/summary_menu`),
- the same single-wrap style as the national-dex marks: native
- runs first, this draws after it, and input passes through unless
- the editor owns the key. SELECT (or F) opens a small EV /
  IV / APPLY / CANCEL menu on the skills page; EV/IV opens a
  two-column stat grid (HP/ATK/DEF, SPATK/SPDEF/SPEED) with
  nature-raised rows in the engine's own red and nature-lowered
  rows in its blue, plus a CONFIRM row under it. APPLY opens the
  cost prompt for everything staged. A on a stat adjusts it
  (up +1 IV / +4 EV with hold-repeat, down -1 / -4; EVs clamp
  to the side's total cap), B steps back a level, and A/START on
  CONFIRM opens the cost prompt. While the HUD is open A/B/
  arrows stay inside it (B can't leave the summary); closing it
  returns to the native keys. Draw wraps are re-asserted on every
  summary open, so a national-dex-style boot-time rebuild of a
  skin draw can't strand the overlay. The profile
  page edits
  nature (A cycles at 2000) and ability slot (A enters slot cycling
  over the mon's own registered abilities, A confirms, 5000);
  START or B-after-changes opens "This will cost XXXX, you want to
  proceed?" (YES/NO, IV 200/pt, EV 125/pt). NO backs out of the
  editor and drops staged changes. Commits rewrite staged
  IVs/EVs + `personality` + ability + `applyStats` (HP-ratio carry).
  Eggs, enemy parties, trade/factory contexts, move-select
  mode, box copies and battles pass straight through to native.
  Wraps once (no per-frame re-wrapping); a leftover standalone
  inspector copy installed later still eats keys first, so remove it.

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
  level adapt, enemy evo, rematch tracking, NPC
  1512 stamp), `battle.ended` (item restore, exp-share clearing,
  EV-clone reconcile, rematch tracking).
