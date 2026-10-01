return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local DELTAS = { minus5 = -5, plus5 = 5, plus10 = 10, zero = 0 }
  local function modeDelta()
    local mode = S.opt("lv_adapt", "vanilla")
    if mode == nil or mode == "vanilla" then return nil end
    return DELTAS[mode]
  end
  local function rosterOf(foe)
    if type(foe) ~= "table" then return nil end
    local p = foe.party
    if type(p) == "table" and #p > 0 then return p end
    return nil
  end
  local function playerTopForBridge(game)
    local ok, R = pcall(require, "src.core.game3.runtime")
    if ok and R and type(R.getSession) == "function" then
      local okS, s = pcall(R.getSession)
      if okS and type(s) == "table" then
        local top = S.topOfList(s.party)
        if top > 0 then return top end
      end
    end
    if type(game) == "table" then
      local sp = game.save and game.save.party
      local top = S.topOfList(sp)
      if top > 0 then return top end
      top = S.topOfList(game.party)
      if top > 0 then return top end
    end
    return 0
  end
  local function adaptList(party, top, delta)
    local ace = 0
    for i = 1, #party do
      local mon = party[i]
      if type(mon) == "table" and not mon.isEgg and tonumber(mon.level) then
        if mon.ptOrigLevel == nil then mon.ptOrigLevel = tonumber(mon.level) end
        if mon.ptOrigLevel > ace then ace = mon.ptOrigLevel end
      end
    end
    if ace <= 0 or top <= 0 then return end
    local shift = top - ace + delta
    for i = 1, #party do
      local mon = party[i]
      if type(mon) == "table" and not mon.isEgg and tonumber(mon.ptOrigLevel) then
        local want = math.floor(mon.ptOrigLevel + shift + 0.5)
        if want < 1 then want = 1 end
        if want > 100 then want = 100 end
        if want ~= tonumber(mon.level) then
          mon.level = want
          S.recalc(mon)
        end
      end
    end
  end
  local okB, Bridge = pcall(require, "src.core.game3.battle_bridge")
  if okB and type(Bridge) == "table" and type(Bridge.start) == "function" then
    if not Bridge.__ptLvAdaptWrapped then
      Bridge.__ptLvAdaptWrapped = true
      local nativeStart = Bridge.start
      Bridge.start = function(mArg, game, foe, opts)
        pcall(function()
          local delta = modeDelta()
          if delta == nil then return end
          if type(opts) == "table" and opts.wild == true then return end
          if type(foe) == "table" and foe.wild == true then return end
          local party = rosterOf(foe)
          if not party then return end
          local top = playerTopForBridge(game)
          if top <= 0 then return end
          adaptList(party, top, delta)
          if type(foe) == "table" and type(party[1]) == "table" then
            if tonumber(party[1].level) then foe.level = party[1].level end
            if party[1].species ~= nil then foe.species = party[1].species end
          end
        end)
        return nativeStart(mArg, game, foe, opts)
      end
    end
  else
    mod.log:warn("pokemon-trainer: level adapt has no battle bridge")
  end
  mod.events:on("battle.started", function(ev)
    local delta = modeDelta()
    if delta == nil then return end
    local battle = ev and ev.battle
    if type(battle) ~= "table" or S.isWild(battle) then return end
    if ev and ev.kind == "wild" then return end
    local top = S.playerTop(battle)
    if top <= 0 then return end
    local lists = {}
    if type(battle.foeParty) == "table" then lists[#lists + 1] = battle.foeParty end
    if type(battle.enemyParty) == "table" then lists[#lists + 1] = battle.enemyParty end
    if #lists == 0 and battle.enemy and battle.enemy.mon then
      adaptList({ battle.enemy.mon }, top, delta)
      return
    end
    for _, list in ipairs(lists) do adaptList(list, top, delta) end
  end, 900)
  mod.log:info("pokemon-trainer: level adapt installed")
end
