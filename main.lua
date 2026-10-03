return function(mod)
  local function loadSibling(file)
    local body, readErr = mod:read(file)
    assert(body, readErr)
    local chunk, err = loadstring(body, "@" .. mod.path .. "/" .. file)
    assert(chunk, err)
    return chunk()
  end
  local function boot(label, fn)
    local ok, err = pcall(fn)
    if not ok then
      mod.log:warn("pokemon-trainer: %s failed: %s", label, tostring(err))
    end
    return ok
  end
  mod.options:define({
    {
      key = "ev_1512",
      label = "1512 EVS",
      type = "choice",
      default = "off",
      choices = { { "OFF", "off" }, { "NPC", "npc" }, { "PLAYER", "player" }, { "BOTH", "both" } },
      description = "OFF: classic 252-per-stat, 510-total EV limits. NPC: enemy trainer mons may hold 1512 total. PLAYER: your mons may hold 1512 total. BOTH: everyone may.",
    },
    {
      key = "item_reuse",
      label = "ITEM REUSE",
      type = "toggle",
      default = true,
      description = "ON (default): held items consumed or lost in battle are back after battle ends. OFF: vanilla.",
    },
    {
      key = "exp_share",
      label = "EXP SHARE",
      type = "choice",
      default = "off",
      choices = { { "OFF", "off" }, { "GEN 1", "gen1" }, { "GEN 2", "gen2" }, { "GEN 3", "gen3" }, { "GEN 6", "gen6" } },
      description = "Party-wide experience, Bulbapedia splits off the same base the engine uses: GEN 1 battlers half each, whole party shares that amount again; GEN 2/3 battlers split half, bench splits half; GEN 6 battlers full, bench half. OFF leaves the award alone.",
    },
    {
      key = "doubles",
      label = "DOUBLES",
      type = "toggle",
      default = false,
      description = "ON: trainers with 2 or more Pokemon force a native double battle. OFF: vanilla.",
    },
    {
      key = "rematches",
      label = "REMATCHES",
      type = "toggle",
      default = false,
      description = "ON: talking to a beaten trainer asks for a rematch; wins pay prize money. OFF: vanilla.",
    },
    {
      key = "lv_adapt",
      label = "LV ADAPT",
      type = "choice",
      default = "vanilla",
      choices = { { "VANILLA", "vanilla" }, { "-5 LVL", "minus5" }, { "+5 LVL", "plus5" }, { "+10 LVL", "plus10" }, { "0", "zero" } },
      description = "Adapt trainer teams to your strongest party mon: -5/+5/+10 around it, 0 exactly at it, keeping each team's own level gaps. VANILLA leaves trainers alone.",
    },
    {
      key = "difficulty",
      label = "DIFFICULTY",
      type = "choice",
      default = "vanilla",
      choices = { { "VANILLA", "vanilla" }, { "EASY", "easy" }, { "NORMAL", "normal" }, { "HARD", "hard" }, { "VERY HARD", "veryhard" }, { "HELL", "hell" } },
      description = "Enemy IVs/EVs: EASY 0, NORMAL 25%, HARD 50%, VERY HARD 75%, HELL 100% (31 IV, 252 per stat when 1512 EVS covers enemies). VANILLA leaves trainers alone.",
    },
    {
      key = "damage_split",
      label = "DAMAGE SPLIT",
      type = "toggle",
      default = false,
      description = "ON: damaging moves use gen 4 physical/special class, not gen 3 type split (52 moves change). OFF: vanilla.",
    },
    {
      key = "enemy_evo",
      label = "ENEMY EVO",
      type = "toggle",
      default = false,
      description = "ON: enemy trainer mons evolve when their level allows it (level evos at level; trade/happiness 25, or 40 for final evos of 3-stage lines; stones 35). OFF: vanilla.",
    },
  })
  mod.exports.EV_TOTAL = 510
  mod.exports.EV_TOTAL_1512 = 1512
  mod.exports.EV_PER_STAT = 252
  mod.exports.evScope = function()
    local ok, v = pcall(function() return mod.options:get("ev_1512") end)
    if ok and (v == "npc" or v == "player" or v == "both") then return v end
    return "off"
  end
  mod.exports.evTotalCap = function(scope, side)
    if scope == "both" then return 1512 end
    if scope == "npc" and side == "enemy" then return 1512 end
    if scope == "player" and side == "player" then return 1512 end
    return 510
  end
  mod.exports.evTotalCapFor = function(side)
    return mod.exports.evTotalCap(mod.exports.evScope(), side)
  end
  boot("shared", function() loadSibling("shared.lua")(mod) end)
  boot("train_screen", function() loadSibling("train/train_screen.lua")(mod) end)
  boot("item_reuse", function() loadSibling("battle/item_reuse.lua")(mod) end)
  boot("exp_share", function() loadSibling("battle/exp_share.lua")(mod) end)
  boot("damage_split", function() loadSibling("battle/damage_split.lua")(mod) end)
  boot("doubles", function() loadSibling("battle/doubles.lua")(mod) end)
  boot("enemy_evo", function() loadSibling("battle/enemy_evo.lua")(mod) end)
  boot("level_adapt", function() loadSibling("battle/level_adapt.lua")(mod) end)
  boot("difficulty", function() loadSibling("battle/difficulty.lua")(mod) end)
  boot("rematch", function() loadSibling("overworld/rematch.lua")(mod) end)
  boot("npc_stamp", function()
    local function stampParty(p)
      if type(p) ~= "table" then return end
      local list = p.party or p.mons or p
      if type(list) ~= "table" then return end
      for _, mon in ipairs(list) do
        if type(mon) == "table" then mon.ptEvCap1512 = true end
      end
    end
    mod.events:on("battle.started", function(ev)
      local okS, scope = pcall(mod.exports.evScope)
      if not (okS and (scope == "npc" or scope == "both")) then return end
      pcall(function()
        local roots = {}
        if type(ev) == "table" then roots = { ev.battle, ev } end
        for _, r in ipairs(roots) do
          if type(r) == "table" then
            for _, k in ipairs({ "enemy", "foe", "opponent", "rival", "trainer" }) do
              stampParty(r[k])
            end
          end
        end
      end)
    end)
  end)
  mod.log:info("pokemon-trainer: loaded (gen3 TRAIN port)")
end
