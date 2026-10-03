return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local SPLIT = {}
  do
    local ok, body = pcall(mod.read, mod, "battle/damage_split_data.lua")
    if ok and type(body) == "string" then
      local okC, chunk = pcall(loadstring, body, "@damage_split_data.lua")
      if okC and type(chunk) == "function" then
        local okR, data = pcall(chunk)
        if okR and type(data) == "table" then SPLIT = data end
      end
    end
  end
  local PHYSICAL_TYPE = {
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [8] = true,
  }
  local TYPE_BY_NAME = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4,
    ROCK = 5, BUG = 6, GHOST = 7, STEEL = 8, MYSTERY = 9,
    FIRE = 10, WATER = 11, GRASS = 12, ELECTRIC = 13, PSYCHIC = 14,
    ICE = 15, DRAGON = 16, DARK = 17,
  }
  local ATK_KEYS = { "attack", "atk" }
  local DEF_KEYS = { "defense", "def" }
  local SPA_KEYS = { "spAtk", "spa", "specialAttack" }
  local SPD_KEYS = { "spDef", "spd", "specialDefense" }
  local HP_MOVE = 237
  local LATIOS, LATIAS, CLAMPERL = 407, 408, 373
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
  local function DmgMod()
    local ok, D = pcall(require, "src.core.game3.battle.damage")
    if ok and type(D) == "table" then return D end
    return nil
  end
  local function AdapterMod()
    local ok, A = pcall(require, "src.core.game3.battle.adapter")
    if ok and type(A) == "table" then return A end
    return nil
  end
  local function abilityOf(battler, adapter)
    if type(adapter) == "table" and type(adapter.abilityOf) == "function" then
      local ok, a = pcall(adapter.abilityOf, adapter, battler)
      if ok and a ~= nil then return a end
    end
    if type(battler) ~= "table" then return nil end
    if battler.expTracedAbility ~= nil then return battler.expTracedAbility end
    local mon = battler.mon
    local id = battler.ability
    if id == nil and type(mon) == "table" then
      id = mon.ability
      if id == nil then id = mon.abilityId end
    end
    if type(id) == "string" then return id:upper():gsub("%s+", "_") end
    if tonumber(id) then
      local A = AdapterMod()
      if A and type(A.ABILITY_BY_ID) == "table" then
        return A.ABILITY_BY_ID[tonumber(id)]
      end
    end
    return nil
  end
  local function statusOf(battler)
    local s = nil
    if type(battler) == "table" then
      s = battler.status
      if s == nil and type(battler.mon) == "table" then s = battler.mon.status end
    end
    if s == 0 then return nil end
    return s
  end
  local function holdEffect(mon)
    if type(mon) ~= "table" then return nil end
    local H = HoldMod()
    if not (H and type(H.effectOf) == "function") then return nil end
    local ok, fx = pcall(H.effectOf, mon.item or mon.heldItem)
    if ok then return fx end
    return nil
  end
  local function statOf(mon, keys)
    if type(mon) ~= "table" then return 50 end
    for _, k in ipairs(keys) do
      if tonumber(mon[k]) then return tonumber(mon[k]) end
    end
    return 50
  end
  local function onSplit()
    return S.opt("damage_split", false) == true
  end
  local function moveTypeNum(view, moveNum, userMon)
    if tonumber(moveNum) == HP_MOVE then
      local D = DmgMod()
      if D and type(D.hiddenPower) == "function" and type(userMon) == "table" then
        local ok, p, t = pcall(D.hiddenPower, userMon)
        if ok and tonumber(t) then return tonumber(t) end
      end
      return nil
    end
    if type(view) == "table" and view.type ~= nil then
      if tonumber(view.type) then return tonumber(view.type) end
      if type(view.type) == "string" then
        local id = TYPE_BY_NAME[view.type:upper():gsub("%s+", "_")]
        if id ~= nil then return id end
      end
    end
    local P = PokeMod()
    if P and type(P.battleMove) == "function" and tonumber(moveNum) then
      local ok, row = pcall(P.battleMove, tonumber(moveNum))
      if ok and type(row) == "table" and tonumber(row.type) then
        return tonumber(row.type)
      end
    end
    return nil
  end
  mod.hooks:wrap("battle.damage", function(nextFn, ctx)
    if not onSplit() then return nextFn(ctx) end
    if type(ctx) ~= "table" then return nextFn(ctx) end
    local moveNum = tonumber(ctx.moveNum)
    local want = moveNum and SPLIT[moveNum]
    if not want then return nextFn(ctx) end
    local view = ctx.move
    if type(view) ~= "table" or (tonumber(view.power) or 0) <= 0 then
      return nextFn(ctx)
    end
    local user, target = ctx.user, ctx.target
    if type(user) ~= "table" or type(target) ~= "table" then return nextFn(ctx) end
    local UM = user.mon or user
    local TM = target.mon or target
    if type(UM) ~= "table" or type(TM) ~= "table" then return nextFn(ctx) end
    if user.expTransform or target.expTransform then return nextFn(ctx) end
    local mtype = moveTypeNum(view, moveNum, UM)
    if mtype == nil then return nextFn(ctx) end
    local typePhysical = PHYSICAL_TYPE[mtype] == true
    local wantPhysical = want == "physical"
    if typePhysical == wantPhysical then return nextFn(ctx) end
    local H = HoldMod()
    local HOLD = H and H.HOLD or {}
    local adapter = ctx.opts and ctx.opts.adapter
    local aAb = abilityOf(user, adapter)
    local dAb = abilityOf(target, adapter)
    local aStatus = statusOf(user)
    local dStatus = statusOf(target)
    local aBurned = aStatus == "BRN"
    local aFx = holdEffect(UM)
    local atkV = statOf(UM, ATK_KEYS)
    local spaV = statOf(UM, SPA_KEYS)
    local defV = statOf(TM, DEF_KEYS)
    local spdV = statOf(TM, SPD_KEYS)
    local aSpecies = tonumber(UM.species or UM.speciesId)
    local dSpecies = tonumber(TM.species or TM.speciesId)
    local saved = {}
    local function save(t, k)
      if type(t) == "table" and t[k] ~= nil then
        saved[#saved + 1] = { t = t, k = k, v = t[k] }
      end
    end
    local function setGroup(mon, keys, value)
      for _, k in ipairs(keys) do
        if mon[k] ~= nil then mon[k] = value end
      end
    end
    for _, k in ipairs(ATK_KEYS) do save(UM, k) end
    for _, k in ipairs(SPA_KEYS) do save(UM, k) end
    for _, k in ipairs(DEF_KEYS) do save(TM, k) end
    for _, k in ipairs(SPD_KEYS) do save(TM, k) end
    if type(user.stages) == "table" then
      save(user.stages, "attack")
      save(user.stages, "spAtk")
    end
    if type(target.stages) == "table" then
      save(target.stages, "defense")
      save(target.stages, "spDef")
    end
    local opts = ctx.opts
    if type(opts) == "table" then
      save(opts, "reflect")
      save(opts, "lightScreen")
    end
    local function restore()
      for i = #saved, 1, -1 do
        local s = saved[i]
        pcall(function() s.t[s.k] = s.v end)
      end
    end
    setGroup(UM, ATK_KEYS, spaV)
    setGroup(UM, SPA_KEYS, atkV)
    setGroup(TM, DEF_KEYS, spdV)
    setGroup(TM, SPD_KEYS, defV)
    if type(user.stages) == "table" then
      local a, s = user.stages.attack, user.stages.spAtk
      if a ~= nil then user.stages.spAtk = a end
      if s ~= nil then user.stages.attack = s end
    end
    if type(target.stages) == "table" then
      local d, s = target.stages.defense, target.stages.spDef
      if d ~= nil then target.stages.spDef = d end
      if s ~= nil then target.stages.defense = s end
    end
    if type(opts) == "table" then
      local r, l = opts.reflect, opts.lightScreen
      opts.reflect, opts.lightScreen = l, r
    end
    local gutsOn = aAb == "GUTS" and aStatus ~= nil
    if not wantPhysical then
      local mult = 1
      if aFx == HOLD.CHOICE_BAND then mult = mult * 1.5 end
      if aAb == "HUSTLE" then mult = mult * 1.5 end
      if gutsOn then mult = mult * 1.5 end
      if aAb == "HUGE_POWER" or aAb == "PURE_POWER" then mult = mult * 2 end
      if mult ~= 1 or aBurned then
        local pre = spaV
        if mult ~= 1 then pre = math.floor(pre / mult) end
        if aBurned then pre = pre * 2 end
        setGroup(UM, ATK_KEYS, pre)
      end
    else
      if (aSpecies == LATIOS or aSpecies == LATIAS)
          and aFx == HOLD.SOUL_DEW then
        setGroup(UM, SPA_KEYS, math.floor(atkV * 2 / 3))
      end
      if aSpecies == CLAMPERL and aFx == HOLD.DEEP_SEA_TOOTH then
        setGroup(UM, SPA_KEYS, math.floor(atkV / 2))
      end
      if (dSpecies == LATIOS or dSpecies == LATIAS)
          and holdEffect(TM) == HOLD.SOUL_DEW then
        setGroup(TM, SPD_KEYS, math.floor(defV * 2 / 3))
      end
      if dSpecies == CLAMPERL and holdEffect(TM) == HOLD.DEEP_SEA_SCALE then
        setGroup(TM, SPD_KEYS, math.floor(defV / 2))
      end
    end
    local ok, dmg, info = pcall(nextFn, ctx)
    restore()
    if not ok then error(dmg) end
    dmg = math.max(0, math.floor(tonumber(dmg) or 0))
    if wantPhysical then
      if aFx == HOLD.CHOICE_BAND then dmg = math.floor(dmg * 3 / 2) end
      if aAb == "HUSTLE" then dmg = math.floor(dmg * 3 / 2) end
      if gutsOn then dmg = math.floor(dmg * 3 / 2) end
      if aAb == "HUGE_POWER" or aAb == "PURE_POWER" then dmg = dmg * 2 end
      if aBurned and not gutsOn then dmg = math.floor(dmg / 2) end
    else
      if dAb == "MARVEL_SCALE" and dStatus ~= nil then
        dmg = math.floor(dmg * 2 / 3)
      end
    end
    if type(info) == "table" then info.physical = wantPhysical end
    return dmg, info
  end)
  mod.log:info("pokemon-trainer: damage split installed (73 PokeAPI moves)")
end
