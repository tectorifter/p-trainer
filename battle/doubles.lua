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
  local function playerHasTwo(game)
    local okP, Party = pcall(require, "src.core.game3.party")
    if not (okP and Party and type(Party.monsStateToDoubles) == "function"
        and Party.PLAYER_HAS_TWO_USABLE_MONS ~= nil) then
      return true
    end
    local party = nil
    local okR, R = pcall(require, "src.core.game3.runtime")
    if okR and R and type(R.getSession) == "function" then
      local okS, s = pcall(R.getSession)
      if okS and type(s) == "table" then party = s.party end
    end
    if party == nil and type(game) == "table" then
      party = (game.save and game.save.party) or game.party
    end
    if type(party) ~= "table" then return true end
    local ok, st = pcall(Party.monsStateToDoubles, party)
    if not ok then return true end
    return st == Party.PLAYER_HAS_TWO_USABLE_MONS
  end
  Bridge.start = function(mArg, game, foe, opts)
    local ok, err = pcall(function()
      if S.opt("doubles", false) == true and type(opts) == "table"
          and not opts.wild and opts.double ~= true
          and not opts.twoOpponents then
        local party = foe and foe.party
        if type(party) == "table" and #party >= 2 and playerHasTwo(game) then
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
