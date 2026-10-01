# pokemon-trainer — documentation

Independent Gen 3 TRAIN port. Design matches g9-battle-engine's Gen 3 TRAIN
screen: a 240x160 surface drawn 1:1 (no scaling) over an FRLG-blue surround,
tab strip (IV / EV / NAT / M-F / MOVES / ABIL / HID) in the small font face,
framed rows with a double frame on the cursor, a COST / APPLY band, and a
moves page with a category header that names the list it shows
(RELEARN / EGG / TUTOR, scrolling two-column list).

## Costs

IV point 200, EV point 125, nature change 2000, move 5000, ability-slot swap
5000. Gender is free. The wallet is the party-menu session money.

## EV caps

252 per stat always. Total 510, or 1512 when `1512 EVS` covers the mon's
side (NPC = enemy trainers, PLAYER = the player's party, BOTH = everyone).
TRAIN refuses staged EVs over the cap; battle-start re-applies committed
mons through the native `Pokemon.applyStats`.

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
- Rematch: the `world.talk` hook (`src/core/game3/field.lua`
- `Field.interact`), beaten check via `trainer_sight.isDefeated`, flag via
- `scripting.flags.setTrainerDefeated`, question via `ui.game3.message` +
- `ui.game3.choice`, YES re-runs the trainer's own script.

## Emerald listing fix

g9-battle-engine 4.9.x strips its TRAIN row on RSE-family sessions and only
prints it through FRLG's `sCursorOptions/14` label slot, so TRAIN never
lists on Emerald — and a plain `RomText.at` override is not enough there
either: Emerald's action box reads its labels from the RSE scene manifest's
`party.cursorOptions` array (`labels[15]` for the STORE slot). This mod
writes TRAIN into that manifest entry while its row is present (restored on
strip) and keeps the `RomText.at` override for FRLG.

## Stub

HIDDEN ability: the tab reports that hidden abilities are not in this port
and changes nothing. Ability slots resolve from the native
`src.core.game3.pokemon.abilities` pair.
