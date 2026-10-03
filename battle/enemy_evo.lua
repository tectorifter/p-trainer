return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local FRIENDSHIP, FDAY, FNIGHT = 1, 2, 3
  local LEVEL, TRADE, TRADE_ITEM, ITEM = 4, 5, 6, 7
  local ATK_GT, ATK_EQ, ATK_LT = 8, 9, 10
  local NINJASK_M, SHEDINJA_M, BEAUTY = 13, 14, 15
  local STONE_LVL, BEAUTY_LVL = 35, 35
  local TRADE_TWO, TRADE_THREE = 25, 40
  local WURMPLE_LVL, EEVEE_LVL, TYROGUE_LVL = 7, 25, 25
  local SHEDINJA_LVL, SLOWKING_LVL, SLOWPOKE_SPLIT = 25, 25, 37
  local EVERSTONE_ID = 195
  local function evoOn()
    return S.opt("enemy_evo", false) == true
  end
  local function rowMethod(evo)
    return tonumber(evo.method or evo[1]) or 0
  end
  local function rowParam(evo)
    return tonumber(evo.param or evo[2]) or 0
  end
  local function rowTarget(evo)
    return tonumber(evo.target or evo[3]) or 0
  end
  local nameIds = {}
  local function namedId(P, name)
    local cached = nameIds[name]
    if cached ~= nil then
      if cached == false then return nil end
      return cached
    end
    local ok, id = pcall(P.speciesFromName, name)
    if ok and tonumber(id) then
      nameIds[name] = tonumber(id)
      return tonumber(id)
    end
    nameIds[name] = false
    return nil
  end
  local graph = nil
  local function getGraph(P)
    if graph then return graph end
    local pre, kids = {}, {}
    for id = 1, 1024 do
      local okN, n = pcall(P.name, id)
      if okN and type(n) == "string" and n ~= "" and n ~= "??????????" then
        local okR, rows = pcall(P.evolutions, id)
        if okR and type(rows) == "table" then
          for _, evo in ipairs(rows) do
            if type(evo) == "table" then
              local t = rowTarget(evo)
              if t > 0 then
                if pre[t] == nil then pre[t] = id end
                kids[id] = kids[id] or {}
                kids[id][#kids[id] + 1] = t
              end
            end
          end
        end
      end
    end
    local infoCache = {}
    local function lineInfo(s)
      local hit = infoCache[s]
      if hit then return hit end
      local root = s
      local seenUp = {}
      while pre[root] and not seenUp[root] do
        seenUp[root] = true
        root = pre[root]
      end
      local dmap, stack, mx = { [root] = 0 }, { root }, 0
      while #stack > 0 do
        local cur = table.remove(stack)
        local cd = dmap[cur] or 0
        for _, t in ipairs(kids[cur] or {}) do
          if dmap[t] == nil then
            dmap[t] = cd + 1
            if cd + 1 > mx then mx = cd + 1 end
            stack[#stack + 1] = t
          end
        end
      end
      local out = { stages = mx + 1, depth = dmap[s] or 0, maxDepth = mx }
      infoCache[s] = out
      return out
    end
    graph = { lineInfo = lineInfo }
    return graph
  end
  local function exoticThreshold(P, s, t)
    local si = getGraph(P).lineInfo(s)
    if si.stages >= 3 then
      local ti = getGraph(P).lineInfo(t)
      if (ti.depth or 0) >= (si.maxDepth or 0) then return TRADE_THREE end
    end
    return TRADE_TWO
  end
  local function everstoneHeld(mon)
    local raw = mon.item or mon.heldItem
    if tonumber(raw) == EVERSTONE_ID then return true end
    if type(raw) == "string" and string.find(string.upper(raw), "EVERSTONE", 1, true) then
      return true
    end
    return false
  end
  local function applyTarget(P, EVO, mon, target)
    local ok, changed = pcall(EVO.apply, mon, target, nil, nil, "enemy_evo")
    if ok and changed then return true end
    if type(mon) == "table" then
      if mon.species ~= nil then mon.species = target end
      if mon.speciesId ~= nil then mon.speciesId = target end
      S.recalc(mon)
      return true
    end
    return false
  end
  local function pick(list)
    if #list == 0 then return nil end
    return list[math.random(#list)]
  end
  local function rowTargets(rows)
    local out = {}
    for _, evo in ipairs(rows) do
      if type(evo) == "table" then
        local t = rowTarget(evo)
        if t > 0 then out[#out + 1] = t end
      end
    end
    return out
  end
  local function atkDefOf(mon)
    local atk = tonumber(mon.attack or mon.atk) or 0
    local def = tonumber(mon.defense or mon.def) or 0
    return atk, def
  end
  local function evolveOnce(P, EVO, mon)
    local s = P.speciesOf(mon) or tonumber(mon.species or mon.speciesId)
    if not s then return false end
    local L = tonumber(mon.level) or 0
    if L <= 0 then return false end
    local okR, rows = pcall(P.evolutions, s)
    if not (okR and type(rows) == "table") or #rows == 0 then return false end
    local eevee = namedId(P, "EEVEE")
    local tyrogue = namedId(P, "TYROGUE")
    local wurmple = namedId(P, "WURMPLE")
    local nincada = namedId(P, "NINCADA")
    local slowpoke = namedId(P, "SLOWPOKE")
    if wurmple and s == wurmple then
      if L < WURMPLE_LVL then return false end
      local t = pick(rowTargets(rows))
      if t then return applyTarget(P, EVO, mon, t) end
      return false
    end
    if eevee and s == eevee then
      if L < EEVEE_LVL then return false end
      local t = pick(rowTargets(rows))
      if t then return applyTarget(P, EVO, mon, t) end
      return false
    end
    if tyrogue and s == tyrogue then
      if L >= TYROGUE_LVL then
        local t = pick(rowTargets(rows))
        if t then return applyTarget(P, EVO, mon, t) end
        return false
      end
    end
    if nincada and s == nincada then
      local ninja, shed, ninjaParam = nil, nil, 20
      for _, evo in ipairs(rows) do
        if type(evo) == "table" then
          local m = rowMethod(evo)
          if m == NINJASK_M then
            ninja = rowTarget(evo)
            ninjaParam = rowParam(evo)
          elseif m == SHEDINJA_M then
            shed = rowTarget(evo)
          end
        end
      end
      if L >= SHEDINJA_LVL and ninja and ninja > 0 and shed and shed > 0 then
        return applyTarget(P, EVO, mon, pick({ ninja, shed }))
      end
      if ninja and ninja > 0 and ninjaParam <= L then
        return applyTarget(P, EVO, mon, ninja)
      end
      return false
    end
    if slowpoke and s == slowpoke then
      local bro, king, broParam = nil, nil, SLOWPOKE_SPLIT
      for _, evo in ipairs(rows) do
        if type(evo) == "table" then
          local m = rowMethod(evo)
          if m == LEVEL then
            bro = rowTarget(evo)
            broParam = rowParam(evo)
          elseif m == TRADE_ITEM or m == TRADE then
            king = rowTarget(evo)
          end
        end
      end
      if L >= SLOWPOKE_SPLIT and bro and bro > 0 and broParam <= L and king and king > 0 then
        return applyTarget(P, EVO, mon, pick({ bro, king }))
      end
      if L >= SLOWKING_LVL and king and king > 0 then
        return applyTarget(P, EVO, mon, king)
      end
      return false
    end
    local cands = {}
    for _, evo in ipairs(rows) do
      if type(evo) == "table" then
        local m, param, t = rowMethod(evo), rowParam(evo), rowTarget(evo)
        if t > 0 then
          if m == LEVEL or m == NINJASK_M then
            if param <= L then cands[#cands + 1] = t end
          elseif m == ATK_GT or m == ATK_EQ or m == ATK_LT then
            if param <= L then
              local atk, def = atkDefOf(mon)
              if (m == ATK_GT and atk > def)
                or (m == ATK_EQ and atk == def)
                or (m == ATK_LT and atk < def) then
                cands[#cands + 1] = t
              end
            end
          elseif m == FRIENDSHIP or m == FDAY or m == FNIGHT or m == TRADE or m == TRADE_ITEM then
            if exoticThreshold(P, s, t) <= L then cands[#cands + 1] = t end
          elseif m == ITEM or m == BEAUTY then
            if (m == ITEM and STONE_LVL or BEAUTY_LVL) <= L then cands[#cands + 1] = t end
          end
        end
      end
    end
    local t = pick(cands)
    if t then return applyTarget(P, EVO, mon, t) end
    return false
  end
  local function evolveMon(P, EVO, mon)
    if type(mon) ~= "table" or mon.isEgg then return end
    if everstoneHeld(mon) then return end
    local L = tonumber(mon.level) or 0
    if mon.ptEnemyEvoAt == L then return end
    for _ = 1, 6 do
      local ok, moved = pcall(evolveOnce, P, EVO, mon)
      if not (ok and moved) then break end
    end
    mon.ptEnemyEvoAt = tonumber(mon.level) or 0
  end
  local function foePartyOf(foe)
    if type(foe) ~= "table" then return nil end
    local p = foe.party
    if type(p) == "table" and #p > 0 then return p end
    return nil
  end
  local function runOnFoe(foe)
    if not evoOn() then return end
    local P = S.g3Pokemon()
    if not P then return end
    local okE, EVO = pcall(require, "src.core.game3.evolution")
    if not (okE and EVO and type(EVO.apply) == "function") then return end
    local party = foePartyOf(foe)
    if not party then return end
    for i = 1, #party do
      pcall(evolveMon, P, EVO, party[i])
    end
    if type(foe) == "table" and type(party[1]) == "table" then
      if tonumber(party[1].level) then foe.level = party[1].level end
      if party[1].species ~= nil then foe.species = party[1].species end
    end
  end
  local okB, Bridge = pcall(require, "src.core.game3.battle_bridge")
  if okB and type(Bridge) == "table" and type(Bridge.start) == "function" then
    if not Bridge.__ptEnemyEvoWrapped then
      Bridge.__ptEnemyEvoWrapped = true
      local nativeStart = Bridge.start
      Bridge.start = function(mArg, game, foe, opts)
        pcall(function()
          if type(opts) == "table" and opts.wild == true then return end
          if type(foe) == "table" and foe.wild == true then return end
          runOnFoe(foe)
        end)
        return nativeStart(mArg, game, foe, opts)
      end
    end
  end
  mod.events:on("battle.started", function(ev)
    if not evoOn() then return end
    local battle = ev and ev.battle
    if type(battle) ~= "table" or S.isWild(battle) then return end
    if ev and ev.kind == "wild" then return end
    local P = S.g3Pokemon()
    if not P then return end
    local okE, EVO = pcall(require, "src.core.game3.evolution")
    if not (okE and EVO and type(EVO.apply) == "function") then return end
    local lists = {}
    if type(battle.foeParty) == "table" then lists[#lists + 1] = battle.foeParty end
    if type(battle.enemyParty) == "table" then lists[#lists + 1] = battle.enemyParty end
    if #lists == 0 and battle.enemy and battle.enemy.mon then
      pcall(evolveMon, P, EVO, battle.enemy.mon)
      return
    end
    for _, list in ipairs(lists) do
      for i = 1, #list do pcall(evolveMon, P, EVO, list[i]) end
    end
  end, 850)
  mod.log:info("pokemon-trainer: enemy evo installed")
end
