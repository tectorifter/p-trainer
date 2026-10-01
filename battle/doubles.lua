return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local okB, Bridge = pcall(require, "src.core.game3.battle_bridge")
  if not (okB and type(Bridge) == "table" and type(Bridge.start) == "function") then
    mod.log:warn("pokemon-trainer: doubles not installed -- no battle bridge")
    return
  end
  if Bridge.__ptDoublesWrapped then return end
  Bridge.__ptDoublesWrapped = true
  local nativeStart = Bridge.start
  Bridge.start = function(mArg, game, foe, opts)
    local ok, err = pcall(function()
      if S.opt("doubles", false) == true and type(opts) == "table"
          and opts.wild == false and opts.double ~= true
          and not opts.twoOpponents then
        local party = foe and foe.party
        if type(party) == "table" and #party >= 2 then
          opts.double = true
          if type(foe) == "table" then foe.doubleBattle = true end
        end
      end
    end)
    if not ok then
      mod.log:warn("pokemon-trainer: doubles forcing failed: %s", tostring(err))
    end
    return nativeStart(mArg, game, foe, opts)
  end
  mod.log:info("pokemon-trainer: doubles installed")
end
