return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local ORDER = { "hp", "atk", "def", "spa", "spd", "spe" }
  local PCT = { easy = 0, normal = 0.25, hard = 0.5, veryhard = 0.75, hell = 1 }
  local function modePct()
    local mode = S.opt("difficulty", "vanilla")
    if mode == nil or mode == "vanilla" then return nil end
    return PCT[mode], mode
  end
  local function spread()
    local pct, mode = modePct()
    if pct == nil then return nil end
    local cap = 510
    if mod.exports and type(mod.exports.evTotalCapFor) == "function" then
      local ok, c = pcall(mod.exports.evTotalCapFor, "enemy")
      if ok and tonumber(c) then cap = tonumber(c) end
    end
    local iv, total = 0, 0
    if mode ~= "easy" then
      iv = math.floor(31 * pct + 0.5)
      total = math.floor(cap * pct)
    end
    local per = math.floor(total / 6)
    local rem = total % 6
    return iv, per, rem
  end
  local function applyTo(mon, iv, per, rem)
    if type(mon) ~= "table" or mon.isEgg then return end
    mon.ivs = mon.ivs or {}
    mon.evs = mon.evs or {}
    for i, key in ipairs(ORDER) do
      mon.ivs[key] = iv
      local v = per
      if i <= rem then v = v + 1 end
      if v > 252 then v = 252 end
      mon.evs[key] = v
    end
  end
  local okB, Bridge = pcall(require, "src.core.game3.battle_bridge")
  if okB and type(Bridge) == "table" and type(Bridge.start) == "function" then
    if not Bridge.__ptDifficultyWrapped then
      Bridge.__ptDifficultyWrapped = true
      local nativeStart = Bridge.start
      Bridge.start = function(mArg, game, foe, opts)
        pcall(function()
          local iv, per, rem = spread()
          if iv == nil then return end
          if type(opts) == "table" and opts.wild == true then return end
          if type(foe) == "table" and foe.wild == true then return end
          local party = type(foe) == "table" and foe.party or nil
          if type(party) ~= "table" or #party == 0 then return end
          for i = 1, #party do applyTo(party[i], iv, per, rem) end
        end)
        return nativeStart(mArg, game, foe, opts)
      end
    end
  end
  mod.events:on("battle.started", function(ev)
    local iv, per, rem = spread()
    if iv == nil then return end
    local battle = ev and ev.battle
    if type(battle) ~= "table" or S.isWild(battle) then return end
    if ev and ev.kind == "wild" then return end
    S.visitSides(battle, nil, function(mon)
      applyTo(mon, iv, per, rem)
      S.recalc(mon)
    end)
  end, 900)
  mod.log:info("pokemon-trainer: difficulty installed")
end
