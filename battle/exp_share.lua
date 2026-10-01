return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local MODES = { off = true, gen1 = true, gen2 = true, gen3 = true, gen6 = true }
  local function mode()
    local v = S.opt("exp_share", "off")
    if MODES[v] then return v end
    return "off"
  end
  local function aliveMon(mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
      and (tonumber(mon.level) or 1) < 100
  end
  local function playerPartyOf(battle)
    if type(battle) ~= "table" then return {} end
    for _, list in ipairs({ battle.playerParty, battle.party }) do
      if type(list) == "table" and #list > 0 then return list end
    end
    local game = battle.game
    local saveParty = game and game.save and game.save.party
    if type(saveParty) == "table" and #saveParty > 0 then return saveParty end
    return {}
  end
  local function shares(m, party, activeSet)
    local out = {}
    if type(party) ~= "table" then return out end
    local aliveParty, aliveActive = {}, {}
    local activeCount = 0
    for _, mon in ipairs(party) do
      if type(mon) == "table" then
        if activeSet and activeSet[mon] then
          activeCount = activeCount + 1
          if aliveMon(mon) then aliveActive[#aliveActive + 1] = mon end
        end
        if aliveMon(mon) then aliveParty[#aliveParty + 1] = mon end
      end
    end
    local n = activeCount
    if n == 0 then n = #aliveActive end
    if n == 0 then n = 1 end
    local P = #party
    if m == "gen1" then
      for _, mon in ipairs(aliveActive) do
        out[#out + 1] = { mon = mon, split = 2 * n }
      end
      if P > 0 then
        for _, mon in ipairs(aliveParty) do
          out[#out + 1] = { mon = mon, split = math.max(1, 2 * n * P) }
        end
      end
    elseif m == "gen2" or m == "gen3" then
      for _, mon in ipairs(aliveActive) do
        out[#out + 1] = { mon = mon, split = 2 * n }
      end
      local H = #aliveParty
      if H > 0 then
        for _, mon in ipairs(aliveParty) do
          out[#out + 1] = { mon = mon, split = 2 * H }
        end
      end
    elseif m == "gen6" then
      for _, mon in ipairs(aliveActive) do
        out[#out + 1] = { mon = mon, split = 1 }
      end
      for _, mon in ipairs(aliveParty) do
        if not (activeSet and activeSet[mon]) then
          out[#out + 1] = { mon = mon, split = 2 }
        end
      end
    end
    return out
  end
  local awards = setmetatable({}, { __mode = "k" })
  local function mults(amount, ctx)
    if ctx.luckyEgg then amount = math.floor(amount * 150 / 100) end
    if ctx.isTrainer then amount = math.floor(amount * 150 / 100) end
    if ctx.traded then amount = math.floor(amount * 150 / 100) end
    return amount
  end
  local function baseFor(share, ctx)
    local E = 0
    if type(ctx.defeatedDef) == "table" then
      E = tonumber(ctx.defeatedDef.baseExp) or 0
    end
    local lv = tonumber(ctx.level) or 1
    local full = math.floor(E * math.max(1, lv) / 7)
    if full < 1 then full = 1 end
    return math.max(1, math.floor(full / math.max(1, share.split)))
  end
  mod.hooks:wrap("exp.gain", function(nextFn, ctx)
    if mode() == "off" then return nextFn(ctx) end
    if type(ctx) ~= "table" or type(ctx.mon) ~= "table" then return nextFn(ctx) end
    local m = mode()
    local battle = ctx.battle
    local loser = ctx.loser
    local key = loser or false
    local st = awards[key]
    if not st then
      local party = playerPartyOf(battle)
      local activeSet = {}
      local mapped = false
      if loser and type(loser.participants) == "table" then
        for pi in pairs(loser.participants) do
          local mon = party[tonumber(pi) or -1]
          if type(mon) == "table" then activeSet[mon] = true mapped = true end
        end
      end
      st = { map = {}, benchPaid = false, party = party, battle = battle,
        foe = loser, activeSet = activeSet, mapped = mapped }
      awards[key] = st
      local set = activeSet
      if not mapped then set = {} end
      for _, share in ipairs(shares(m, party, set)) do
        local list = st.map[share.mon]
        if not list then list = {} st.map[share.mon] = list end
        list[#list + 1] = share
      end
    end
    if not st.benchPaid then
      st.benchPaid = true
      pcall(function()
        local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
        local okE, Experience = pcall(require, "src.core.game3.battle.experience")
        for mon, list in pairs(st.map) do
          if mon ~= ctx.mon and aliveMon(mon) then
            local full = 0
            for _, share in ipairs(list) do
              full = full + baseFor(share, ctx)
            end
            local amount = mults(full, {
              luckyEgg = false, isTrainer = ctx.isTrainer, traded = false })
            if okP and Pokemon and type(Pokemon.gainEVs) == "function" then
              local sp = ctx.loser and (ctx.loser.species
                or (ctx.loser.mon and ctx.loser.mon.species))
              pcall(Pokemon.gainEVs, mon, sp)
            end
            if okE and Experience and type(Experience.apply) == "function" then
              local okA, result = pcall(Experience.apply, mon, amount)
              if okA and type(result) == "table" then
                pcall(mod.events.emit, mod.events, "battle.exp_gained", {
                  battle = battle, mon = mon,
                  gained = result.gained or amount,
                  levels = result.levels,
                })
              end
            end
          end
        end
      end)
    end
    local list = st.map[ctx.mon]
    if not list then return nextFn(ctx) end
    local full = 0
    for _, share in ipairs(list) do
      full = full + baseFor(share, ctx)
    end
    return mults(full, ctx)
  end, 0)
  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    for k, st in pairs(awards) do
      if k == false or (battle ~= nil and st.battle == battle) then
        awards[k] = nil
      end
    end
  end, -1000)
  mod.log:info("pokemon-trainer: exp share installed (off/gen1/gen2/gen3/gen6)")
end
