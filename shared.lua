return function(mod)
  local S = {}
  mod.exports.pt = S
  local STAT_KEYS = {
    hp = { "hp", "HP" },
    atk = { "atk", "attack", "ATK" },
    def = { "def", "defense", "DEF" },
    spa = { "spa", "specialAttack", "spAtk", "special" },
    spd = { "spd", "specialDefense", "spDef" },
    spe = { "spe", "speed", "SPE" },
  }
  function S.statOf(block, key)
    if type(block) ~= "table" then return nil end
    for _, k in ipairs(STAT_KEYS[key] or { key }) do
      if tonumber(block[k]) then return tonumber(block[k]) end
    end
    return nil
  end
  function S.opt(key, fallback)
    local ok, v = pcall(function() return mod.options:get(key) end)
    if ok and v ~= nil then
      if v == "true" then return true end
      if v == "false" then return false end
      return v
    end
    return fallback
  end
  function S.g3Pokemon()
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if ok and type(P) == "table" then return P end
    return nil
  end
  local function rawMon(who)
    local m = who and (who.mon or who) or nil
    if type(m) == "table" then return m end
    return nil
  end
  local function eachList(list, fn, seen)
    if type(list) ~= "table" then return end
    for i = 1, #list do
      local m = rawMon(list[i])
      if m and not seen[m] then seen[m] = true fn(m) end
    end
  end
  local function sessionParty(battle)
    local st = battle
    if type(st) == "table" and type(st.session) == "table" then
      local p = st.session.party
      if type(p) == "table" and #p > 0 then return p end
    end
    local ok, R = pcall(require, "src.core.game3.runtime")
    if ok and R and type(R.getSession) == "function" then
      local okS, s = pcall(R.getSession)
      if okS and type(s) == "table" and type(s.party) == "table" and #s.party > 0 then
        return s.party
      end
    end
    return nil
  end
  local function savePartyOf(battle)
    local game = type(battle) == "table" and battle.game or nil
    local sp = game and game.save and game.save.party
    if type(sp) == "table" and #sp > 0 then return sp end
    return nil
  end
  function S.visit(battle, fn)
    if type(battle) ~= "table" then return end
    local seen = {}
    local function go(who)
      local m = rawMon(who)
      if m and not seen[m] then seen[m] = true fn(m) end
    end
    go(battle.enemy)
    go(battle.player)
    for _, list in ipairs({ battle.foeParty, battle.enemyParty, battle.playerParty, battle.party }) do
      eachList(list, fn, seen)
    end
    if type(battle.battlers) == "table" then
      for _, b in pairs(battle.battlers) do go(b) end
    end
    eachList(sessionParty(battle), fn, seen)
    eachList(savePartyOf(battle), fn, seen)
  end
  function S.visitSides(battle, playerFn, enemyFn)
    if type(battle) ~= "table" then return end
    local seen = {}
    local function go(who, fn)
      local m = rawMon(who)
      if m and not seen[m] then seen[m] = true fn(m) end
    end
    if playerFn then
      go(battle.player, playerFn)
      for _, list in ipairs({ battle.playerParty, battle.party }) do
        if type(list) == "table" then
          for i = 1, #list do go(list[i], playerFn) end
        end
      end
      if type(battle.battlers) == "table" then
        for _, b in pairs(battle.battlers) do
          if type(b) == "table" and b.side == "player" then go(b, playerFn) end
        end
      end
      local sp = sessionParty(battle)
      if type(sp) == "table" then
        for i = 1, #sp do go(sp[i], playerFn) end
      end
      local sv = savePartyOf(battle)
      if type(sv) == "table" then
        for i = 1, #sv do go(sv[i], playerFn) end
      end
    end
    if enemyFn then
      go(battle.enemy, enemyFn)
      for _, list in ipairs({ battle.foeParty, battle.enemyParty }) do
        if type(list) == "table" then
          for i = 1, #list do go(list[i], enemyFn) end
        end
      end
      if type(battle.battlers) == "table" then
        for _, b in pairs(battle.battlers) do
          if type(b) == "table" and b.side == "enemy" then go(b, enemyFn) end
        end
      end
    end
  end
  function S.isWild(battle)
    if type(battle) ~= "table" then return false end
    if battle.wild == true or battle.isWild == true then return true end
    if battle.kind == "wild" or battle.type == "wild" then return true end
    if battle.battleType == "wild" then return true end
    return false
  end
  function S.topOfList(list)
    local top = 0
    if type(list) ~= "table" then return top end
    for i = 1, #list do
      local m = rawMon(list[i])
      if m and not m.isEgg then
        local lv = tonumber(m.level) or 0
        if lv > top then top = lv end
      end
    end
    return top
  end
  function S.playerTop(battle)
    local top = 0
    S.visitSides(battle, function(mon)
      if not mon.isEgg then
        local lv = tonumber(mon.level) or 0
        if lv > top then top = lv end
      end
    end, nil)
    return top
  end
  function S.recalc(mon)
    local P = S.g3Pokemon()
    if not (P and type(P.applyStats) == "function") then return false end
    local oldMax = S.statOf(mon.stats, "hp")
    local oldHp = tonumber(mon.hp)
    local ok = pcall(P.applyStats, mon)
    if not ok then return false end
    if oldMax and oldHp and oldMax > 0 then
      local newMax = S.statOf(mon.stats, "hp")
      if newMax and newMax > 0 then
        if oldHp <= 0 then mon.hp = 0
        else
          local kept = math.floor(newMax * oldHp / oldMax + 0.5)
          if kept < 1 then kept = 1 end
          if kept > newMax then kept = newMax end
          mon.hp = kept
        end
      end
    end
    return true
  end
end
