return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local okP, P = pcall(require, "src.core.game3.pokemon")
  local native = (okP and P and type(P.gainEVs) == "function") and P.gainEVs or nil
  local DEBUG = false
  local ORDER = { "hp", "atk", "def", "spa", "spd", "spe" }
  local AWARD = 4
  local function flatOn()
    return S.opt("ev_4", false) == true
  end
  local function capFor(mon)
    local side = "player"
    if type(mon) == "table" and mon.ptEvCap1512 then side = "enemy" end
    if mod.exports and type(mod.exports.evTotalCapFor) == "function" then
      local ok, c = pcall(mod.exports.evTotalCapFor, side)
      if ok and tonumber(c) then return tonumber(c) end
    end
    return 510
  end
  local function pkrsActive(mon)
    local ok, v = pcall(function() return mon.pokerus end)
    if ok and tonumber(v) ~= nil then return tonumber(v) ~= 0 end
    local ok2, v2 = pcall(function() return mon.pkrs end)
    if ok2 and tonumber(v2) ~= nil then return tonumber(v2) ~= 0 end
    return false
  end
  local function multFor(mon)
    local m = 1
    if pkrsActive(mon) then m = m * 2 end
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
        local it = nil
        pcall(function() it = mon.item end)
        if it == nil then pcall(function() it = mon.heldItem end) end
        local okF, fx = pcall(H.effectOf, it)
        if okF and fx == want then m = m * 2 end
      end
    end
    return m
  end
  local yieldCache = {}
  local evLogBudget = 200
  local firstAwardLog = false
  local pendingClones = {}
  local function deepSpecies(t, depth)
    if type(t) ~= "table" or (depth or 0) > 3 then return nil end
    local s = t.species
    if type(s) == "number" or type(s) == "string" then return s end
    s = t.speciesId
    if type(s) == "number" or type(s) == "string" then return s end
    for _, k in ipairs({ "mon", "def", "base", "data" }) do
      local v = deepSpecies(t[k], (depth or 0) + 1)
      if v ~= nil then return v end
    end
    return nil
  end
  local function evLog(...)
    if not DEBUG then return end
    if evLogBudget <= 0 then return end
    evLogBudget = evLogBudget - 1
    mod.log:warn("pokemon-trainer: EVGAIN " .. string.format(...))
  end
  local function cachedYield(species, nativeFn)
    local ck = tostring(species)
    local hit = yieldCache[ck]
    if hit then return hit end
    if type(nativeFn) ~= "function" then return nil end
    local scratch = { evs = {} }
    for _, key in ipairs(ORDER) do scratch.evs[key] = 0 end
    if not pcall(nativeFn, scratch, species) then return nil end
    local y = {}
    for _, key in ipairs(ORDER) do y[key] = tonumber(scratch.evs[key]) or 0 end
    yieldCache[ck] = y
    return y
  end
  local function shallow(v)
    if type(v) ~= "table" then
      local s = tostring(v)
      if #s > 40 then s = string.sub(s, 1, 40) .. ".." end
      return type(v) .. ":" .. s
    end
    local parts, n = {}, 0
    for k, vv in pairs(v) do
      n = n + 1
      if #parts < 10 then
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(vv)
      end
    end
    return "table#" .. n .. "{" .. table.concat(parts, ",") .. "}"
  end
  local function speciesOfMon(m)
    if type(m) ~= "table" then return nil end
    return m.species ~= nil and m.species
      or m.speciesId ~= nil and m.speciesId or nil
  end
  local function directYield(species)
    if not (okP and P and type(P.evYield) == "function") then return nil end
    local ok, y = pcall(P.evYield, species)
    if not ok or type(y) ~= "table" then return nil end
    local t, any = {}, false
    for _, k in ipairs(ORDER) do
      local v = tonumber(y[k])
      if v ~= nil then t[k] = v any = true end
    end
    if any then return t end
    return nil
  end
  local function snap(mon)
    mon.evs = mon.evs or {}
    local before = {}
    for _, key in ipairs(ORDER) do before[key] = tonumber(mon.evs[key]) or 0 end
    return before
  end
  local function totalOf(mon)
    local t = 0
    for _, key in ipairs(ORDER) do t = t + (tonumber(mon.evs[key]) or 0) end
    return t
  end
  local function flatAward(mon, before, cap, tag, species)
    local gained = {}
    for _, key in ipairs(ORDER) do
      if (tonumber(mon.evs[key]) or 0) > before[key] then
        gained[#gained + 1] = key
      end
    end
    if #gained == 0 then
      if not (cap and cap > 510 and species ~= nil) then return 0 end
      local y = directYield(species) or cachedYield(species, native)
      if not y then
        evLog("%s flat NO-YIELD sp=%s", tag or "flat", tostring(species))
        return 0
      end
      local award = AWARD * multFor(mon)
      local gave = 0
      for _, key in ipairs(ORDER) do
        if (tonumber(y[key]) or 0) > 0 then
          local cur = tonumber(mon.evs[key]) or 0
          local give = math.min(award, 252 - cur, cap - totalOf(mon))
          if give > 0 then mon.evs[key] = cur + give gave = gave + give end
        end
      end
      evLog("%s flat-native gave=%d final=%d", tag or "flat", gave, totalOf(mon))
      return gave
    end
    for _, key in ipairs(gained) do mon.evs[key] = before[key] end
    local award = AWARD * multFor(mon)
    local gave = 0
    for _, key in ipairs(gained) do
      local cur = tonumber(mon.evs[key]) or 0
      local give = math.min(award, 252 - cur, cap - totalOf(mon))
      if give > 0 then mon.evs[key] = cur + give gave = gave + give end
    end
    evLog("%s flat gave=%d final=%d", tag or "flat", gave, totalOf(mon))
    return gave
  end
  local function topUp(mon, species, before, cap, nativeFn, tag)
    local y = directYield(species) or cachedYield(species, nativeFn)
    if not y then
      evLog("%s sp=%s NO-YIELD", tag, tostring(species))
      return
    end
    local m = multFor(mon)
    local yTot, gave = 0, 0
    for _, key in ipairs(ORDER) do yTot = yTot + (tonumber(y[key]) or 0) end
    local detail = {}
    for _, key in ipairs(ORDER) do
      local want = math.min(252, before[key] + (tonumber(y[key]) or 0) * m)
      local cur = tonumber(mon.evs[key]) or 0
      if want > cur then
        local give = math.min(want - cur, cap - totalOf(mon))
        if give > 0 then mon.evs[key] = cur + give gave = gave + give end
        detail[#detail + 1] = key .. ":w" .. want .. "/c" .. cur .. "/g" .. give
      end
    end
    local bTot = 0
    for _, key in ipairs(ORDER) do bTot = bTot + before[key] end
    evLog("%s sp=%s cap=%d before=%d yield=%d mult=%d gave=%d final=%d %s",
      tag, tostring(species), cap, bTot, yTot, m, gave, totalOf(mon),
      gave == 0 and ("detail:" .. table.concat(detail, " ")) or "")
  end
  if not native then
    mod.log:warn("pokemon-trainer: EV gain has no gainEVs seam")
    return
  end
  if not P.__ptEv4Wrapped then
    P.__ptEv4Wrapped = true
    P.gainEVs = function(mon, species, ...)
      local flat = flatOn()
      if type(mon) ~= "table" then return native(mon, species, ...) end
      local cap = capFor(mon)
      if not flat and cap <= 510 then
        evLog("passthrough sp=%s cap=%d", tostring(species), cap)
        return native(mon, species, ...)
      end
      local before = snap(mon)
      local r = native(mon, species, ...)
      local ok, err = pcall(function()
        if flat then
          flatAward(mon, before, cap, "benchF", species)
        else
          topUp(mon, species, before, cap, native, "bench")
        end
      end)
      if not ok then evLog("bench ERR %s", tostring(err)) end
      return r
    end
  end
  local okE, E = pcall(require, "src.core.game3.battle.experience")
  if okE and E and type(E.awardFoe) == "function"
      and not E.__ptEvAwardWrapped then
    E.__ptEvAwardWrapped = true
    local nativeAward = E.awardFoe
    E.awardFoe = function(...)
      local nargs = select("#", ...)
      local args = { ... }
      local mons, seenM = {}, {}
      local function consider(m)
        if type(m) ~= "table" or seenM[m] then return end
        if type(m.evs) ~= "table" then return end
        seenM[m] = true
        mons[#mons + 1] = m
      end
      local function considerList(list)
        if type(list) ~= "table" then return end
        for _, b in pairs(list) do
          consider(b)
          if type(b) == "table" then consider(b.mon) end
        end
      end
      for i = 1, nargs do
        local a = args[i]
        if type(a) == "table" then
          consider(a.mon)
          consider(a.winner)
          consider(a.player)
          considerList(a.battlers)
          considerList(a.party)
          considerList(a.playerParty)
        end
      end
      local active = flatOn()
      local caps, befores = {}, {}
      for _, m in ipairs(mons) do
        caps[m] = capFor(m)
        if active or caps[m] > 510 then
          befores[m] = snap(m)
        end
      end
      local rets = {}
      local function capture(...)
        local n = select("#", ...)
        for i = 1, n do rets[i] = select(i, ...) end
        rets.n = n
      end
      mod.exports.ptBenchPaid = {}
      capture(nativeAward(...))
      local benchPaid = mod.exports.ptBenchPaid or {}
      mod.exports.ptBenchPaid = {}
      local okPost, postErr = pcall(function()
        if not firstAwardLog then
          firstAwardLog = true
          local parts = {}
          for i = 1, nargs do parts[#parts + 1] = shallow(args[i]) end
          evLog("award nargs=%d mons=%d %s", nargs, #mons,
            table.concat(parts, " "))
        end
        for _, m in ipairs(mons) do
          local sp = {}
          for _, k in ipairs(ORDER) do sp[#sp + 1] = tonumber(m.evs[k]) or 0 end
          local hasB = befores[m] ~= nil
          local hpV, eggV = "?", "?"
          pcall(function() hpV = tostring(m.hp) end)
          pcall(function() eggV = tostring(m.isEgg) end)
          evLog("awardmon cap=%d evTot=%d spread=%s hasBefore=%s hp=%s egg=%s",
            caps[m] or -1, totalOf(m), table.concat(sp, "/"), tostring(hasB), hpV, eggV)
        end
        if DEBUG then
        local okSess, sessParty = pcall(function()
          local R = require("src.core.game3.runtime")
          local s = R.getSession()
          return s and s.party or nil
        end)
        if okSess and type(sessParty) == "table" then
          for i, pm in ipairs(sessParty) do
            if type(pm) == "table" and type(pm.evs) == "table" then
              local same = false
              for _, m in ipairs(mons) do if m == pm then same = true break end end
              evLog("sessparty slot=%d evTot=%d inAwardList=%s", i, totalOf(pm), tostring(same))
            end
          end
        end
        end
        local loserSp, loserVia = nil, "none"
        local okL, errL = pcall(function()
        for i = 1, nargs do
          local a = args[i]
          if type(a) == "table" and (a.fainted == true or a.flank ~= nil) then
            loserSp = deepSpecies(a, 0)
            if loserSp ~= nil then loserVia = "foe-arg" break end
          end
        end
        if loserSp == nil then
          for i = 1, nargs do
            local a = args[i]
            if type(a) == "table" then
              loserSp = deepSpecies(a.loser, 0)
              if loserSp ~= nil then loserVia = "loser-field" break end
            end
          end
        end
        if loserSp == nil then
          for i = 1, nargs do
            local a = args[i]
            if type(a) == "table" and type(a.enemy) == "table" then
              loserSp = deepSpecies(a.enemy, 0)
              if loserSp ~= nil then loserVia = "enemy-field" break end
            end
          end
        end
        end)
        if not okL then evLog("loserSp ERR %s", tostring(errL)) end
        evLog("loserSp=%s via=%s", tostring(loserSp), loserVia)
        pcall(function()
          for i = 1, nargs do
            local a = args[i]
            if type(a) == "table" and (a.fainted == true or a.flank ~= nil) then
              local sp = a.species ~= nil and a.species or a.speciesId
              local nm = a.name or a.nickname
                or (type(a.mon) == "table" and (a.mon.name or a.mon.nickname))
              local nat, metaName, yv = nil, nil, nil
              if okP and P and type(P.national) == "function" then
                local o, n = pcall(P.national, sp)
                if o then nat = n end
              end
              if okP and P and type(P.speciesMeta) == "function" then
                local o, mm = pcall(P.speciesMeta, sp)
                if o and type(mm) == "table" then
                  metaName = mm.name or mm.speciesName or mm.species
                end
              end
              local y = directYield(sp)
              if type(y) == "table" then
                yv = (y.hp or 0) .. "/" .. (y.atk or 0) .. "/" .. (y.def or 0)
                  .. "/" .. (y.spa or 0) .. "/" .. (y.spd or 0) .. "/" .. (y.spe or 0)
              end
              evLog("foeprobe sp=%s nat=%s name=%s meta=%s evy=%s",
                tostring(sp), tostring(nat), tostring(nm),
                tostring(metaName), tostring(yv))
              break
            end
          end
        end)
        for _, m in ipairs(mons) do
          local before = befores[m]
          local skip = nil
          if not before then skip = "no-before"
          else
            local okG, pass = pcall(function()
              return not m.isEgg and (tonumber(m.hp) or 1) > 0
            end)
            if not okG then skip = "guard-ERR:" .. tostring(pass)
            elseif not pass then skip = "guard-false" end
          end
          if skip then
            evLog("awardskip %s evTot=%d", skip, totalOf(m))
          else
            local okM, errM = pcall(function()
              if active then flatAward(m, before, caps[m], "awardF", loserSp)
              else topUp(m, loserSp, before, caps[m], native, "award") end
            end)
            if not okM then evLog("award ERR %s", tostring(errM)) end
            local idx = tonumber(m.partyIndex)
            if idx then
              local cp = { evs = {}, species = speciesOfMon(m) }
              for _, k in ipairs(ORDER) do
                cp.evs[k] = tonumber(m.evs[k]) or 0
              end
              pendingClones[idx] = cp
            end
          end
        end
      end)
      if not okPost and DEBUG then mod.log:warn("pokemon-trainer: EVGAIN post ERR " .. tostring(postErr)) end
      if type(rets[1]) == "table" and type(benchPaid) == "table" and #benchPaid > 0 then
        for _, e in ipairs(benchPaid) do
          if type(e) == "table" and type(e.mon) == "table" and type(e.result) == "table" then
            rets[1][#rets[1] + 1] = {
              mon = e.mon, partyIndex = e.partyIndex, battler = nil,
              expGetterBattlerId = e.battlerId or 0, amount = e.amount,
              boosted = e.boosted, result = e.result,
            }
          end
        end
        if DEBUG then
          mod.log:warn("pokemon-trainer: EVGAIN benched=%d out=%d", #benchPaid, #rets[1])
        end
      end
      return unpack(rets, 1, rets.n)
    end
  end
  if mod.events and type(mod.events.on) == "function"
      and not mod.__ptEvEndedHook then
    mod.__ptEvEndedHook = true
    mod.events:on("battle.ended", function(ev)
      if not next(pendingClones) then return end
      pcall(function()
        local party = nil
        local b = type(ev) == "table" and ev.battle or nil
        if type(b) == "table" then
          for _, k in ipairs({ "playerParty", "party" }) do
            if type(b[k]) == "table" and #b[k] > 0 then party = b[k] break end
          end
        end
        if not party then
          local okR, R = pcall(require, "src.core.game3.runtime")
          if okR and R and type(R.getSession) == "function" then
            local okS, s = pcall(R.getSession)
            if okS and type(s) == "table"
                and type(s.party) == "table" and #s.party > 0 then
              party = s.party
            end
          end
        end
        local cap = 1512
        if mod.exports and type(mod.exports.evTotalCapFor) == "function" then
          local ok, c = pcall(mod.exports.evTotalCapFor, "player")
          if ok and tonumber(c) then cap = tonumber(c) end
        end
        for idx, rec in pairs(pendingClones) do
          pendingClones[idx] = nil
          local real = nil
          if type(party) == "table" then
            for _, cand in ipairs({ idx, idx - 1, idx + 1 }) do
              local m = party[cand]
              if type(m) == "table" and tostring(speciesOfMon(m))
                  == tostring(rec.species) then
                real = m
                break
              end
            end
          end
          if type(real) == "table" then
            real.evs = real.evs or {}
            local bTot, fixed = 0, 0
            for _, k in ipairs(ORDER) do
              bTot = bTot + (tonumber(real.evs[k]) or 0)
            end
            local function totNow()
              local t = 0
              for _, k in ipairs(ORDER) do
                t = t + (tonumber(real.evs[k]) or 0)
              end
              return t
            end
            for _, k in ipairs(ORDER) do
              local want = math.min(252, tonumber(rec.evs[k]) or 0)
              local cur = tonumber(real.evs[k]) or 0
              if want > cur then
                local give = math.min(want - cur, cap - totNow())
                if give > 0 then
                  real.evs[k] = cur + give
                  fixed = fixed + give
                end
              end
            end
            evLog("evcheck idx=%d sp=%s before=%d fixed=%d final=%d",
              idx, tostring(rec.species), bTot, fixed, totNow())
          else
            evLog("evcheck idx=%d NO-MATCH sp=%s", idx,
              tostring(rec.species))
          end
        end
      end)
    end)
  end
  mod.log:info("pokemon-trainer: EV gain installed (raised caps + 4 EVS)")
end
