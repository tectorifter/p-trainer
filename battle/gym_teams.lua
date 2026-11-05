return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local ROCK, FIGHTING = 5, 1
  local ELECTRIC, FIRE = 13, 10
  local NORMAL, FLYING = 0, 2
  local PSYCHIC, WATER = 14, 11
  local DARK, GHOST = 17, 7
  local ICE, DRAGON = 15, 16
  local SPECIALTY = {
    [265] = ROCK, [770] = ROCK, [771] = ROCK, [772] = ROCK, [773] = ROCK,
    [266] = FIGHTING, [774] = FIGHTING, [775] = FIGHTING,
    [776] = FIGHTING, [777] = FIGHTING,
    [267] = ELECTRIC, [778] = ELECTRIC, [779] = ELECTRIC,
    [780] = ELECTRIC, [781] = ELECTRIC,
    [268] = FIRE, [782] = FIRE, [783] = FIRE, [784] = FIRE, [785] = FIRE,
    [269] = NORMAL, [786] = NORMAL, [787] = NORMAL,
    [788] = NORMAL, [789] = NORMAL,
    [270] = FLYING, [790] = FLYING, [791] = FLYING,
    [792] = FLYING, [793] = FLYING,
    [271] = PSYCHIC, [794] = PSYCHIC, [795] = PSYCHIC,
    [796] = PSYCHIC, [797] = PSYCHIC,
    [272] = WATER, [798] = WATER, [799] = WATER,
    [800] = WATER, [801] = WATER,
    [261] = DARK,
    [262] = GHOST,
    [263] = ICE,
    [264] = DRAGON,
    [335] = WATER,
  }
  local LEGEND = {
    [144] = true, [145] = true, [146] = true, [150] = true, [151] = true,
    [243] = true, [244] = true, [245] = true, [249] = true, [250] = true,
    [251] = true,
    [377] = true, [378] = true, [379] = true, [380] = true, [381] = true,
    [382] = true, [383] = true, [384] = true, [385] = true, [386] = true,
  }
  local GEN_HI = { 151, 251, 386, 493, 649, 721, 809, 905, 1025 }
  local function genOfNat(nat)
    nat = math.floor(tonumber(nat) or 0)
    if nat < 1 then return 0 end
    for g = 1, 9 do
      if nat <= GEN_HI[g] then return g end
    end
    return 0
  end
  local function ecoMod()
    local ok, m = pcall(function() return mod.find("poke-ecology") end)
    if ok and type(m) == "table" then return m end
    return nil
  end
  local function genOn(eco, g)
    if g < 1 or g > 9 then return true end
    if eco == nil then return true end
    local v = nil
    pcall(function()
      if eco.options and type(eco.options.get) == "function" then
        v = eco.options:get("gen" .. g)
      end
    end)
    if v == nil then return true end
    return v ~= false
  end
  local function natOf(P, id)
    local nat = nil
    pcall(function()
      if P ~= nil and type(P.national) == "function" then
        nat = math.floor(tonumber(P.national(id)) or 0)
      end
    end)
    if nat == nil or nat <= 0 then return nil end
    return nat
  end
  local function speciesGenOk(P, eco, id)
    local nat = natOf(P, id)
    if nat == nil then return true end
    return genOn(eco, genOfNat(nat))
  end
  local function ecoLegend(eco, id)
    if eco == nil then return false end
    id = math.floor(tonumber(id) or 0)
    if id <= 0 then return false end
    local hit = false
    pcall(function()
      local ex = eco.exports
      if type(ex) == "table" then
        local a = ex.peLegendaries
        local b = ex.peDexLegendaries
        if (type(a) == "table" and a[id] == true)
          or (type(b) == "table" and b[id] == true) then
          hit = true
        end
      end
    end)
    return hit
  end
  local TEAM_SIZE = 6
  local function fillOn()
    return S.opt("gym_teams", false) == true
  end
  local lineCache = {}
  local function linesFor(spec, P)
    local hit = lineCache[spec]
    if hit then return hit end
    local out = {}
    if P then
      local named, targeted = {}, {}
      for id = 1, 1024 do
        local okN, n = pcall(P.name, id)
        if okN and type(n) == "string" and n ~= "" and n ~= "??????????" then
          named[id] = true
          local okR, rows = pcall(P.evolutions, id)
          if okR and type(rows) == "table" then
            for _, evo in ipairs(rows) do
              if type(evo) == "table" then
                local t = tonumber(evo.target or evo[3]) or 0
                if t > 0 then targeted[t] = true end
              end
            end
          end
        end
      end
      local kidCache = {}
      local function kids(id)
        local hitK = kidCache[id]
        if hitK then return hitK end
        local ks = {}
        local okR, rows = pcall(P.evolutions, id)
        if okR and type(rows) == "table" then
          for _, evo in ipairs(rows) do
            if type(evo) == "table" then
              local t = tonumber(evo.target or evo[3]) or 0
              if t > 0 and named[t] then ks[#ks + 1] = t end
            end
          end
        end
        kidCache[id] = ks
        return ks
      end
      for root = 1, 1024 do
        if named[root] and not targeted[root] then
          local seen, stack, mem = {}, { root }, {}
          while #stack > 0 do
            local cur = table.remove(stack)
            if not seen[cur] then
              seen[cur] = true
              mem[#mem + 1] = cur
              for _, k in ipairs(kids(cur)) do
                if not seen[k] then stack[#stack + 1] = k end
              end
            end
          end
          local bad, match = false, false
          for _, sid in ipairs(mem) do
            if LEGEND[sid] then bad = true break end
            local okT, t = pcall(P.types, sid)
            if okT and type(t) == "table" and (t[1] == spec or t[2] == spec) then
              match = true
            end
          end
          if not bad and match then out[#out + 1] = { root = root } end
        end
      end
    end
    lineCache[spec] = out
    return out
  end
  local function resolveStage(root, level)
    if type(S.evolveTrainerMon) ~= "function" then return root end
    local mon = { speciesId = root, level = level }
    local ok, res = pcall(S.evolveTrainerMon, mon)
    if not ok then return root end
    local id = tonumber(res) or tonumber(mon.speciesId) or tonumber(mon.species)
    if id and id > 0 then return math.floor(id) end
    return root
  end
  local function speciesNum(P, m)
    local sid = tonumber(m.speciesId) or tonumber(m.species)
    if sid then return math.floor(sid) end
    if type(m.species) == "string" then
      local okN, id = pcall(P.speciesFromName, m.species)
      if okN and tonumber(id) then return math.floor(tonumber(id)) end
    end
    return nil
  end
  local function padParty(tid, party)
    local spec = SPECIALTY[tonumber(tid)]
    if spec == nil then return party end
    if type(party) ~= "table" or #party == 0 then return party end
    local P = S.g3Pokemon()
    if not P then return party end
    local have, top = {}, 0
    for _, m in ipairs(party) do
      if type(m) == "table" then
        local sid = speciesNum(P, m)
        if sid then have[sid] = true end
        local lv = tonumber(m.level)
        if lv and lv > top then top = lv end
      end
    end
    if top <= 0 then return party end
    local need = TEAM_SIZE - #party
    if need <= 0 then return party end
    local eco = ecoMod()
    local options = {}
    for _, line in ipairs(linesFor(spec, P)) do
      local sid = resolveStage(line.root, top)
      if sid > 0 and not have[sid] and not LEGEND[sid] and not ecoLegend(eco, sid)
        and speciesGenOk(P, eco, sid) then
        have[sid] = true
        options[#options + 1] = sid
      end
    end
    if #options == 0 then return party end
    local out = {}
    for i, m in ipairs(party) do out[i] = m end
    for _ = 1, need do
      if #options == 0 then break end
      local sid = table.remove(options, math.random(#options))
      local okN, n = pcall(P.name, sid)
      if okN and type(n) == "string" and n ~= "" then
        out[#out + 1] = { species = n, level = top }
      end
    end
    if #out == #party then return party end
    return out
  end
  local function aceLast(party, ace)
    if ace == nil or type(party) ~= "table" or #party < 2 then return party end
    local idx = nil
    for i, m in ipairs(party) do if m == ace then idx = i break end end
    if idx == nil or idx == #party then return party end
    local out = {}
    for i, m in ipairs(party) do out[i] = m end
    table.remove(out, idx)
    out[#out + 1] = ace
    return out
  end
  mod.hooks:wrap("trainer.party", function(nextFn, class, tid, party)
    local out = nextFn(class, tid, party)
    if not fillOn() then return out end
    if SPECIALTY[tonumber(tid)] == nil then return out end
    local ace, lv = nil, nil
    if type(out) == "table" then
      for _, m in ipairs(out) do
        if type(m) == "table" then
          local l = tonumber(m.level)
          if l and (lv == nil or l >= lv) then lv = l ace = m end
        end
      end
    end
    local ok, padded = pcall(padParty, tid, out)
    if ok and type(padded) == "table" and #padded > 0 then out = padded end
    local okA, fixed = pcall(aceLast, out, ace)
    if okA and type(fixed) == "table" and #fixed > 0 then return fixed end
    return out
  end)
  mod.log:info("pokemon-trainer: gym teams installed")
end
