# pokemon-trainer — documentation

Independent Gen 3 summary-screen editor: open any party mon's
native summary and press SELECT (or F) on the skills page for
an EV / IV / APPLY / CANCEL menu opening two-column stat grids
with a CONFIRM row (IV +1, EV +4 a step, hold to repeat), and a
profile page editing nature and ability slot. Commits go through
the "This will cost XXXX, you want to proceed?" confirm; NO
backs out and drops staged changes.

## Save editor + national_dex

In the save-editor host (same detect as national_dex: Gen with
`bindGame3Data` + App session + gen 3) the mod installs no
battle/world/UI seams at all — there is nothing for it to do
there — and runs a `mods.loaded` check that refills any missing
live species names (name, reverse index, National maps) from the
merged pokemon registry. That covers the national_dex combo
failure (`Save disabled: ... no ROM species name for species
848`, a dex slot with no live name when the save hydrates).

## Costs

IV point 200, EV point 125, nature change 2000, ability-slot swap
5000, tutor/egg move 5000. The wallet is the party-menu session money.

## EV caps

252 per stat always. Total 510, or 1512 when `1512 EVS` covers the mon's
side (NPC = enemy trainers, PLAYER = the player's party, BOTH = everyone;
the safari-plus `1512 EVS` toggle also covers the player's party while that
mod is loaded).
The editor refuses staged EVs over the cap; commits apply through
the native `Pokemon.applyStats`. Battle EV gains honor the
raised total too: yields the native code would have clamped at 510 are
topped up to the side's cap (Macho Brace / Pokerus multipliers kept).

## Seams (all read from the live dev-branch engine source)

- Party rows: a raw `PartyMenu.handleInput` patch (Highlander
- method, in-place on the shared string list) inserts TUTOR when
- the mon has tutor moves to learn and EGG MOVE when it has egg
- moves to learn, before CANCEL on field lists only (no eggs, no
- battle or battle-switch menus, SUMMARY + CANCEL present,
- dupe-safe), syncs `PartyMenu._actionTexts` for the new rows
- (literal texts, never through the engine's option-text assert),
- and consumes A on them to open a locked move list: TUTOR locked
- to TUTOR, EGG MOVE locked to EGG (own Stack layer ids,
- `pttutor` / `pteggmove`, so layers can't collide), each teaching
- at 5000 like before. Locked lists ignore left/right and close
- on B. The EGG list unions `Pokemon.eggMoves` across the mon's
- whole evolution line (reverse map derived from live engine
- evolution data, nothing hardcoded) including known moves
- (re-teaching one reports ALREADY KNOWN, free). No
- `ui.party.submenu` subscription, so the engine keeps the raw
- string list other party mods patch.
- The full seam list lives in `seams.md`.
- Text: `src.ui.game3.frlg_font` small face, 240x160 1:1, no scaling.
- Items: native `mon.item` / `mon.heldItem`, snapshot at `battle.started`
- (priority 1000), restore at `battle.ended` (priority -1000).
- Exp: the `exp.gain` hook (`src/core/game3/battle/experience.lua`
- `awardFoe`), per-recipient ctx with `defeatedDef/level/isTrainer/
- participants/traded/luckyEgg/expShare/mon/index/battle/loser`.
- Doubles: `src.core.game3.battle_bridge.start` opts (`double == true`
- gives a native double battle; wild excluded).
- Levels/stats/IVs/EVs: `src.core.game3.pokemon.applyStats` with an
- HP-ratio carry; staged IV/EV/nature commits take effect at once.
- Rematch: the `world.talk` hook (`src/core/game3/field.lua`
- `Field.interact`), beaten check via `trainer_sight.isDefeated`, flag via
- `scripting.flags.setTrainerDefeated`, question via `ui.game3.message` +
- `ui.game3.choice`, YES re-runs the trainer's own script.
- Damage split: the `battle.damage` hook swaps the attack/defense stat pair
- for moves whose gen 4 class differs from their gen 3 type class; classes
- from PokeAPI (`move.damage_class`, see Credits).

## Nature / ability writes

Nature and ability slot go through `mon.personality` (nature =
`personality % 25`, ability slot = parity, gender = low byte vs the ROM
ratio), which is what the engine itself derives them from — no separate
nature/ability fields are trusted. Changing ability forces the matching
parity (odd = slot 2), so the pick survives engine recalculation; the
mon's gender is preserved via the native gender check, or by pinning
the personality low byte on engines without it. If no personality
satisfies the request, the commit aborts with
a `PERSONALITY FAILED` status and charges nothing.

## Summary-screen editor

The absorbed skills-inspector lives inside the native summary,
behind SELECT (or F): a small menu offers EV, IV, APPLY and
CANCEL. EV/IV opens a two-column stat grid (HP/ATK/DEF,
SPATK/SPDEF/SPEED) with a CONFIRM row under it; A on a stat
adjusts it (IV +1, EV +4, hold repeats), B steps back, and
APPLY or CONFIRM opens the cost prompt for everything staged
(NO backs out and drops staged changes). The profile page
edits nature and ability slot. Rows under a raising nature
draw in the engine's own red, under a lowering one in its
blue. Costs: IV 200/pt, EV 125/pt, nature 2000, ability slot 5000.

## Flat 4 EVs

`4 EVS` (default OFF) wraps the native `Pokemon.gainEVs`: any stat that
would gain EVs from a KO instead gains exactly 4 (Macho Brace holders
gain 8, Pokerus doubles where the mon tracks it), clamped to 252 per
stat and the side's EV total cap. The stat categories stay native — an
Attack-yielder still gives Attack. Applies to battlers and bench (Exp.
Share) alike, both sides.

## Macho Brace in Oldale

`MACHO BRACE` (default OFF) wraps the native shop UI's `show`: when the
Oldale clerk's stock list passes through, MACHO BRACE is appended (the ROM
stock pointer itself is not patchable, so the shelf is extended live at the
Shop NPC instead). The item is priced at 2500 via an `items` patch at load.
Turning OFF restores the vanilla list immediately.

## Enemy evolutions
`ENEMY EVO` (default OFF) evolves enemy trainer mons at battle start
(first battles and rematches alike: foe parties are rebuilt fresh per
battle) via the native `Evolution.apply` (species, ability, stats,
nickname rules). Eggs, wild battles and Everstone holders are skipped;
evolved mons keep their trainer-set moves.
Thresholds: level evos at their level; trade / trade-item / happiness
at 25, or 40 for final evos of 3-stage lines (line length is measured
from the live `Pokemon.evolutions` graph); stones at 35. Specials:
Wurmple random at 7; Eevee random (5 gen-3 evos) at 25+; Tyrogue vanilla
stat rule at 20, random at 25+; Nincada Ninjask at 20, random
Ninjask/Shedinja at 25+; Slowpoke Slowking at 25, random Slowbro/Slowking
at 37+. Multiple eligible targets pick randomly. Defaults chosen where
the spec was silent: Feebas (Beauty) at 35 like stones; trade-item same
as plain trade; day/night and friendship values ignored; no National Dex
gate (trainers field Hoenn mons pre-National in vanilla too).
Evolution targets from a gen disabled in poke-ecology are skipped while
that mod is present (the mon keeps its current stage); without it every
target is eligible.

## Gym teams
`GYM TEAMS` (default OFF) fills gym leader and Elite Four teams to 6 in
the `trainer.party` hook with random mons whose primary or secondary
type matches the leader's specialty: Roxanne rock (Nosepass, Geodude),
Brawly fighting (Makuhita, Meditite), Wattson electric (Manectric,
Magneton), Flannery fire (Torkoal, Camerupt), Norman
normal (Slaking, Vigoroth), Winona flying (Altaria, Skarmory), Tate and
Liza psychic (Solrock, Lunatone), Juan water (Kingdra, Crawdaunt),
Sidney dark (Absol, Shiftry), Phoebe ghost (Dusclops, Banette), Glacia
ice (Walrein, Glalie), Drake dragon (Salamence, Flygon), Wallace water
(Milotic, Gyarados). First battles and rematches alike are filled; the
listed aces are untouched by the fill but moved to the last slot, so
the ace is fought last; only the missing slots are added. Each added
slot picks an evolution line with the specialty type anywhere in it,
then fields the stage the team's top level allows under the same
conditions `ENEMY EVO` uses (level rows at their level, trade and
happiness at 25, or 40 for 3-stage finals, stones and Feebas at 35,
Wurmple at 7, Eevee and Tyrogue at 25+, Nincada and Slowpoke splits),
resolved through the shared trainer-evolution helper so the
battle-start pass keeps the arrivals as-is. Low-level teams get first
stages, high-level teams their finals. No duplicate of a species
already on the team; legendaries never join (poke-ecology's legendary
and mythical list joins the never-pick set while that mod is present).
Fill reads poke-ecology's GEN 1..9 toggles when that mod is present:
a resolved stage from a disabled gen never joins — a cross-gen line
fields its highest enabled stage at the team's level instead (Nosepass
stays Nosepass with GEN 4 off) — and without poke-ecology every species
is eligible. Added mons enter at the
team's top level with no set moves (the engine deals level-up moves).
The fill runs inside `Bridge.start` before the battle is built.

## Credits

Move physical/special classes (`battle/damage_split_data.lua`) sourced from
PokeAPI (https://pokeapi.co/docs/v2#moves, `move.damage_class`). Pokemon
move data is (c) Nintendo / Creatures Inc. / GAME FREAK inc.

