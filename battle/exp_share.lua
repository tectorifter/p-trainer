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
      and (tonumber(mon.level) or 1) < 100 and not mon.isEgg
  end
  local function ExpMod()
    local ok, E = pcall(require, "src.core.game3.battle.experience")
    if ok and type(E) == "table" then return E end
    return nil
  end
  local function PokeMod()
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if ok and type(P) == "table" then return P end
    return nil
  end
  local function HoldMod()
    local ok, H = pcall(require, "src.core.game3.battle.held_items")
    if ok and type(H) == "table" then return H end
    return nil
  end
  local function partyOf(battle)
    if type(battle) == "table" and type(battle.playerParty) == "table" then
      return battle.playerParty
    end
    if type(battle) == "table" then
      if type(battle.party) == "table" and #battle.party > 0 then
        return battle.party
      end
      local game = battle.game
      local saveParty = game and game.save and game.save.party
      if type(saveParty) == "table" and #saveParty > 0 then return saveParty end
    end
    return {}
  end
  local function sentInOf(battle, loser)
    local set = {}
    if type(loser) == "table" and type(loser.participants) == "table" then
      for pi in pairs(loser.participants) do
        pi = tonumber(pi)
        if pi then set[pi] = true end
      end
    end
    if not next(set) and type(battle) == "table"
        and type(battle.player) == "table" then
      set[tonumber(battle.player.partyIndex) or 1] = true
    end
    return set
  end
  local function isHolder(mon)
    if type(mon) ~= "table" then return false end
    local H = HoldMod()
    if not (H and type(H.effectOf) == "function" and H.HOLD) then return false end
    local ok, fx = pcall(H.effectOf, mon.item or mon.heldItem)
    return ok and fx == H.HOLD.EXP_SHARE
  end
  local function foeSpeciesOf(loser)
    if type(loser) ~= "table" then return nil end
    if loser.species ~= nil then return loser.species end
    if type(loser.mon) == "table" then
      return loser.mon.species or loser.mon.speciesId
    end
    return nil
  end
  local function baseAmount(ctx, loser)
    local foeLevel = 1
    if type(loser) == "table" then
      if type(loser.mon) == "table" and tonumber(loser.mon.level) then
        foeLevel = tonumber(loser.mon.level)
      elseif tonumber(loser.level) then
        foeLevel = tonumber(loser.level)
      elseif tonumber(ctx.level) then
        foeLevel = tonumber(ctx.level)
      end
    elseif tonumber(ctx.level) then
      foeLevel = tonumber(ctx.level)
    end
    foeLevel = math.max(1, foeLevel)
    local E = ExpMod()
    local sp = foeSpeciesOf(loser)
    if E and type(E.expYield) == "function" and sp ~= nil then
      local ok, y = pcall(E.expYield, sp)
      if ok and tonumber(y) then
        return math.floor(tonumber(y) * foeLevel / 7)
      end
    end
    if type(ctx.defeatedDef) == "table"
        and tonumber(ctx.defeatedDef.baseExp) then
      return math.floor(tonumber(ctx.defeatedDef.baseExp) * foeLevel / 7)
    end
    return 0
  end
  local function boosted(amount, per, isTrainer)
    if per.luckyEgg then amount = math.floor(amount * 150 / 100) end
    if isTrainer then amount = math.floor(amount * 150 / 100) end
    if per.traded then amount = math.floor(amount * 150 / 100) end
    if amount < 1 then amount = 1 end
    return amount
  end
  local function sharesFor(m, full, n, H, P)
    if m == "gen6" then
      return math.max(1, full), math.max(1, math.floor(full / 2))
    end
    local half = math.floor(full / 2)
    local battler = math.max(1, math.floor(half / math.max(1, n)))
    if m == "gen1" then
      return battler, math.max(1, math.floor(battler / math.max(1, P)))
    end
    return battler, math.max(1, math.floor(half / math.max(1, H)))
  end
  local paid = setmetatable({}, { __mode = "k" })
  mod.hooks:wrap("exp.gain", function(nextFn, ctx)
    local m = mode()
    if m == "off" then return nextFn(ctx) end
    if type(ctx) ~= "table" or type(ctx.mon) ~= "table" then return nextFn(ctx) end
    local battle = ctx.battle
    local loser = ctx.loser
    local party = partyOf(battle)
    if #party == 0 then return nextFn(ctx) end
    local sentIn = sentInOf(battle, loser)
    local full = baseAmount(ctx, loser)
    local n, H, P = 0, 0, 0
    for i = 1, 6 do
      if party[i] ~= nil then P = P + 1 end
      if aliveMon(party[i]) then
        if sentIn[i] then n = n + 1 else H = H + 1 end
      end
    end
    local battlerAmt, benchAmt = sharesFor(m, full, n, H, P)
    if not paid[loser or false] then
      paid[loser or false] = true
      pcall(function()
        local E = ExpMod()
        local Pkm = PokeMod()
        if not (E and type(E.apply) == "function") then return end
        for i = 1, 6 do
          local mon = party[i]
          if aliveMon(mon) and not sentIn[i] and not isHolder(mon)
              and mon ~= ctx.mon then
            local per = { luckyEgg = false, traded = false }
            if type(E.recipientOpts) == "function" then
              local okR, r = pcall(E.recipientOpts, battle, mon)
              if okR and type(r) == "table" then per = r end
            end
            local amount = boosted(benchAmt, per, ctx.isTrainer)
            if Pkm and type(Pkm.gainEVs) == "function" then
              pcall(Pkm.gainEVs, mon, foeSpeciesOf(loser))
            end
            local okA, result = pcall(E.apply, mon, amount)
            if okA and type(result) == "table" then
              if Pkm and type(Pkm.adjustFriendship) == "function"
                  and Pkm.FRIENDSHIP_EVENT_GROW_LEVEL ~= nil then
                local fctx = {}
                if type(Pkm.currentMapSec) == "function" then
                  local okM, ms = pcall(Pkm.currentMapSec,
                    battle and battle.session)
                  if okM then fctx = { mapSec = ms } end
                end
                for _ = 1, #result.levels do
                  pcall(Pkm.adjustFriendship, mon,
                    Pkm.FRIENDSHIP_EVENT_GROW_LEVEL, fctx)
                end
              end
              pcall(mod.events.emit, mod.events, "battle.exp_gained", {
                battle = battle, mon = mon,
                gained = result.gained or amount, levels = result.levels,
              })
            end
          end
        end
      end)
    end
    local pi = tonumber(ctx.index)
    local mine = (pi and sentIn[pi]) and battlerAmt or benchAmt
    return boosted(mine, {
      luckyEgg = ctx.luckyEgg and true or false,
      traded = ctx.traded and true or false,
    }, ctx.isTrainer)
  end, 0)
  mod.events:on("battle.ended", function()
    for k in pairs(paid) do paid[k] = nil end
  end, -1000)
  mod.log:info("pokemon-trainer: exp share installed (off/gen1/gen2/gen3/gen6)")
end
