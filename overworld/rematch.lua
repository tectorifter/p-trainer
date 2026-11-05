return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local function talkOn()
    return S.opt("rematches", false) == true
  end
  local pendingTid, armedTid = nil, nil
  local function setDefeated(tid, beaten)
    pcall(function()
      local Space = require("src.core.game3.scripting.space")
      local Flags = require("src.core.game3.scripting.flags")
      Flags.setTrainerDefeated(Space.store, nil, tid, beaten)
    end)
  end
  local function playerLost(ev)
    local r = type(ev) == "table" and ev.result or nil
    if type(r) == "string" then
      local rl = string.lower(r)
      if string.find(rl, "los", 1, true) or string.find(rl, "white", 1, true)
          or string.find(rl, "black", 1, true)
          or string.find(rl, "defeat", 1, true) then
        return true
      end
      if rl == "win" or rl == "won" or rl == "victory" or rl == "winner" then
        return false
      end
    end
    local b = type(ev) == "table" and ev.battle or nil
    local party = nil
    if type(b) == "table" then party = b.playerParty or b.party end
    if type(party) ~= "table" then
      local okR, R = pcall(require, "src.core.game3.runtime")
      if okR and R and type(R.getSession) == "function" then
        local okS, s = pcall(R.getSession)
        if okS and type(s) == "table" then party = s.party end
      end
    end
    if type(party) == "table" then
      local any, alive = false, false
      for _, m in ipairs(party) do
        if type(m) == "table" then
          any = true
          if (tonumber(m.hp) or 0) > 0 and not m.isEgg then alive = true break end
        end
      end
      if any then return not alive end
    end
    return false
  end
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("battle.started", function(ev)
      if pendingTid == nil then return end
      local tid = type(ev) == "table" and ev.trainerId or nil
      if tid == nil or tid == pendingTid then armedTid = pendingTid end
    end)
    mod.events:on("battle.ended", function(ev)
      local tid = armedTid
      armedTid, pendingTid = nil, nil
      if tid == nil then return end
      if playerLost(ev) then setDefeated(tid, true) end
    end)
  end
  local function findEo(...)
    for i = 1, select("#", ...) do
      local a = select(i, ...)
      if type(a) == "table" and (a.def or a.scriptKey or a.localId) then
        return a
      end
    end
    return nil
  end
  mod.hooks:wrap("world.talk", function(nextFn, ...)
    local args = { ... }
    local game, eo = args[1], findEo(...)
    if type(nextFn) ~= "function" then return end
    if not talkOn() then return nextFn(...) end
    local okT, Sight = pcall(require, "src.core.game3.trainer_sight")
    if not (okT and Sight and type(Sight.isTrainerType) == "function") then
      return nextFn(...)
    end
    local okCheck, beaten, tid = pcall(function()
      if not Sight.isTrainerType(eo) then return false end
      local id = Sight.getTrainerId(eo)
      if id == nil then return false end
      local okS, Space = pcall(require, "src.core.game3.scripting.space")
      local store = okS and Space and Space.store or nil
      if store == nil then return false end
      return Sight.isDefeated(eo, store, nil), id
    end)
    if not (okCheck and beaten == true and tid ~= nil) then
      return nextFn(...)
    end
    local lid = 0
    if type(eo) == "table" then
      lid = eo.localId or (eo.def and (eo.def.localId or eo.def.index)) or 0
    end
    pcall(function()
      local Objects = require("src.core.game3.objects")
      Objects.freeze(lid)
      Objects.facePlayer(lid, game)
      local Message = require("src.ui.game3.message")
      local Choice = require("src.ui.game3.choice")
      Message.show("Battle again?", function()
        Choice.yesNo(function(yes)
          if yes then
            setDefeated(tid, false)
            pendingTid, armedTid = tid, nil
            pcall(Message.close, Message)
            nextFn(game, unpack(args, 2))
          else
            pcall(Message.close, Message)
            pcall(function()
              require("src.core.game3.objects").unfreeze(lid)
            end)
          end
        end)
      end)
    end)
    return true
  end, 0)
  mod.log:info("pokemon-trainer: rematches installed")
end
