# pokemon-trainer — documentation

Independent Gen 3 TRAIN editor: a 240x160 surface drawn 1:1 (no scaling) over an FRLG-blue surround,
tab strip (IV / EV / NAT / M-F / MOVES / ABIL / HID) in the small font face,
framed rows with a double frame on the cursor, a COST / APPLY band, and a
moves page with RELEARN / TM / EGG / TUTOR lists from the game's own data (single-column list with a detail panel (type/power/accuracy/PP/effect)); relearn moves are free, the rest cost 5000.

## Costs

IV point 200, EV point 125, nature change 2000, move 5000, ability-slot swap
5000. Gender is free. The wallet is the party-menu session money.

## EV caps

252 per stat always. Total 510, or 1512 when `1512 EVS` covers the mon's
side (NPC = enemy trainers, PLAYER = the player's party, BOTH = everyone).
TRAIN refuses staged EVs over the cap; battle-start re-applies committed
mons through the native `Pokemon.applyStats`. Battle EV gains honor the
raised total too: yields the native code would have clamped at 510 are
topped up to the side's cap (Macho Brace / Pokerus multipliers kept).

## Seams (all read from the live dev-branch engine source)

- Party row: `src.ui.game3.party_menu` (`PM.ACTIONS` + unused `STORE` id) with
- the label patched in the RSE scene manifest's `party.cursorOptions[15]`
- (`Kit.manifest` cache) on Emerald and via `RomText.at sCursorOptions/14`
- on FRLG.
- Text: `src.ui.game3.frlg_font` small face, 240x160 1:1, no scaling.
- Items: native `mon.item` / `mon.heldItem`, snapshot at `battle.started`
- (priority 1000), restore at `battle.ended` (priority -1000).
- Exp: the `exp.gain` hook (`src/core/game3/battle/experience.lua`
- `awardFoe`), per-recipient ctx with `defeatedDef/level/isTrainer/
- participants/traded/luckyEgg/expShare/mon/index/battle/loser`.
- Doubles: `src.core.game3.battle_bridge.start` opts (`double == true`
- gives a native double battle; wild excluded).
- Levels/stats/IVs/EVs: `src.core.game3.pokemon.applyStats` with an
- HP-ratio carry; foe parties are rebuilt fresh per battle, so trainer
- mutations are transient.
- Stats: base stats come from the engine's own `src.core.game3.pokemon`
- species accessors (probed by name, shape-validated, cached per species);
- the stat page projects them with the real gen 3 formula.
- Moves (all from the engine's own ROM-extracted tables, never mon memory):
- RELEARN = `MoveLearn.relearnableMoves(mon)` (same function the vanilla
- move relearner uses: learnset entries at/below the mon's level, minus
- known moves), falling back to `Pokemon.learnset(species)` filtered to
- mon level. TM = every machine index 0..57 passing
- `Pokemon.canLearnTmIndex(species, idx)`, mapped through
- `Pokemon.moveFromTmItem(289+idx)`, minus `Pokemon.isHmMove` HMs. EGG =
- `Pokemon.eggMoves(species)`. TUTOR = every tutor index below
- `MoveLearn.tutorMoveCount()` passing `MoveLearn.canLearnTutorMove`,
- mapped through `MoveLearn.tutorMove`. Picks re-validate vs ROM.
- Rematch: the `world.talk` hook (`src/core/game3/field.lua`
- `Field.interact`), beaten check via `trainer_sight.isDefeated`, flag via
- `scripting.flags.setTrainerDefeated`, question via `ui.game3.message` +
- `ui.game3.choice`, YES re-runs the trainer's own script.
- Damage split: the `battle.damage` hook swaps the attack/defense stat pair
- for moves whose gen 4 class differs from their gen 3 type class; classes
- from PokeAPI (`move.damage_class`, see Credits).

## Emerald listing fix

A plain `RomText.at` override is not enough on Emerald:
Emerald's action box reads its labels from the RSE scene manifest's
`party.cursorOptions` array (`labels[15]` for the STORE slot). This mod
writes TRAIN into that manifest entry while its row is present (restored on
strip) and keeps the `RomText.at` override for FRLG.

## Stub

HIDDEN ability: the tab reports that hidden abilities are not in this port
and changes nothing. Ability slots resolve from the native
`src.core.game3.pokemon.abilities` pair.

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

## Credits

Move physical/special classes (`battle/damage_split_data.lua`) sourced from
PokeAPI (https://pokeapi.co/docs/v2#moves, `move.damage_class`). Pokemon
move data is (c) Nintendo / Creatures Inc. / GAME FREAK inc.

