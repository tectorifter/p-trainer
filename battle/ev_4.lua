return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local ORDER = { "hp", "atk", "def", "spa", "spd", "spe" }
  local AWARD = 4
  local function on()
    return S.opt("ev_4", false) == true
  end
  local function totalCap()
    if mod.exports and type(mod.exports.evTotalCapFor) == "function" then
      local ok, c = pcall(mod.exports.evTotalCapFor, "player")
      if ok and tonumber(c) then return tonumber(c) end
    end
    return 510
  end
  local function multFor(mon)
    local m = 1
    if tonumber(mon.pokerus or mon.pkrs or 0) ~= 0 then m = m * 2 end
    local ok, H = pcall(require, "src.core.game3.battle.held_items")
    if ok and H and type(H.effectOf) == "function" and type(H.HOLD) == "table" then
      local want = nil
      for k, v in pairs(H.HOLD) do
        if type(k) == "string" and string.find(string.upper(k), "MACHO") then
          want = v
          break
        end
      end
      if want ~= nil then
        local okF, fx = pcall(H.effectOf, mon.item or mon.heldItem)
        if okF and fx == want then m = m * 2 end
      end
    end
    return m
  end
  local okP, P = pcall(require, "src.core.game3.pokemon")
  if not (okP and P and type(P.gainEVs) == "function") then
    mod.log:warn("pokemon-trainer: 4 EVS has no gainEVs seam")
    return
  end
  if P.__ptEv4Wrapped then return end
  P.__ptEv4Wrapped = true
  local native = P.gainEVs
  P.gainEVs = function(mon, species, ...)
    if not on() then return native(mon, species, ...) end
    if type(mon) ~= "table" then return native(mon, species, ...) end
    mon.evs = mon.evs or {}
    local before = {}
    for _, key in ipairs(ORDER) do before[key] = tonumber(mon.evs[key]) or 0 end
    local r = native(mon, species, ...)
    local gained = {}
    for _, key in ipairs(ORDER) do
      if (tonumber(mon.evs[key]) or 0) > before[key] then
        gained[#gained + 1] = key
      end
    end
    if #gained == 0 then return r end
    for _, key in ipairs(gained) do mon.evs[key] = before[key] end
    local award = AWARD * multFor(mon)
    local cap = totalCap()
    local function totalNow()
      local t = 0
      for _, key in ipairs(ORDER) do t = t + (tonumber(mon.evs[key]) or 0) end
      return t
    end
    for _, key in ipairs(gained) do
      local cur = tonumber(mon.evs[key]) or 0
      local give = math.min(award, 252 - cur, cap - totalNow())
      if give > 0 then mon.evs[key] = cur + give end
    end
    return r
  end
  mod.log:info("pokemon-trainer: 4 EVS installed")
end
