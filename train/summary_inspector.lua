return function(mod)
  local game = nil
  do
    local okG, GV = pcall(require, "src.core.GameVersion")
    if okG and type(GV) == "table" and type(GV.get) == "function" then
      local okV, v = pcall(GV.get)
      if okV and type(v) == "string" then game = v end
    end
  end
  if game ~= "ruby" and game ~= "sapphire" and game ~= "emerald" then return end
  local Pokemon = nil
  do
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if ok and type(P) == "table" then Pokemon = P end
  end
  local SummaryData = nil
  do
    local ok, S = pcall(require, "src.core.game3.summary_data")
    if ok and type(S) == "table" then SummaryData = S end
  end
  local Frlg = nil
  do
    local ok, F = pcall(require, "src.ui.game3.frlg_font")
    if ok and type(F) == "table" and type(F.draw) == "function" then Frlg = F end
  end
  local Kit = nil
  do
    local ok, K = pcall(require, "src.ui.game3.rse.scene_kit")
    if ok and type(K) == "table" then Kit = K end
  end
  local PalText = nil
  do
    local ok, P = pcall(require, "src.ui.game3.rse.pal_text")
    if ok and type(P) == "table" and type(P.draw) == "function" then PalText = P end
  end
  local U = nil
  do
    local ok, M = pcall(require, "src.ui.game3.summary_menu")
    if ok and type(M) == "table" then U = M end
  end
  local Rse = nil
  do
    local ok, M = pcall(require, "src.ui.game3.rse.summary_menu")
    if ok and type(M) == "table" then Rse = M end
  end
  local RS = nil
  do
    local ok, M = pcall(require, "src.ui.game3.rs.summary_menu")
    if ok and type(M) == "table" then RS = M end
  end
  local function se()
    local okA, Audio = pcall(require, "src.core.game3.audio")
    if okA and type(Audio) == "table" then pcall(Audio.playSe, "SE_SELECT") end
  end
  local getNow = os.clock
  do
    local okL, L = pcall(function() return love end)
    if okL and type(L) == "table" and type(L.timer) == "table"
      and type(L.timer.getTime) == "function" then
      local okT, t = pcall(L.timer.getTime)
      if okT and type(t) == "number" then getNow = L.timer.getTime end
    end
  end
  local loveKbOk = true
  local function held(input, key)
    if type(input) == "table" and type(input.isDown) == "function" then
      local ok, v = pcall(input.isDown, input, key)
      if ok and v then return true end
    end
    if loveKbOk then
      local okL, L = pcall(function() return love end)
      if okL and type(L) == "table" and type(L.keyboard) == "table"
        and type(L.keyboard.isDown) == "function" then
        local ok, v = pcall(L.keyboard.isDown, key)
        if ok and v then return true end
      else
        loveKbOk = false
      end
    end
    return false
  end
  local STAT_ORDER = { "hp", "atk", "def", "spa", "spd", "spe" }
  local STAT_LABEL = { hp = "HP", atk = "ATK", def = "DEF",
    spa = "SPA", spd = "SPD", spe = "SPE" }
  local STAT_KEYS = {
    hp = { "hp", "HP" },
    atk = { "atk", "attack", "ATK" },
    def = { "def", "defense", "DEF" },
    spa = { "spa", "specialAttack", "spAtk", "special" },
    spd = { "spd", "specialDefense", "spDef" },
    spe = { "spe", "speed", "SPE" },
  }
  local function statOf(block, key)
    if type(block) ~= "table" then return nil end
    for _, k in ipairs(STAT_KEYS[key] or { key }) do
      if tonumber(block[k]) then return tonumber(block[k]) end
    end
    return nil
  end
  local G3_NATURES = {
    "Hardy", "Lonely", "Brave", "Adamant", "Naughty",
    "Bold", "Docile", "Relaxed", "Impish", "Lax",
    "Timid", "Hasty", "Jolly", "Naive",
    "Modest", "Mild", "Quiet", "Bashful", "Rash",
    "Calm", "Gentle", "Sassy", "Careful", "Quirky", "Serious",
  }
  local NATURE_MOD = {
    Lonely = { up = "atk", down = "def" }, Brave = { up = "atk", down = "spe" },
    Adamant = { up = "atk", down = "spa" }, Naughty = { up = "atk", down = "spd" },
    Bold = { up = "def", down = "atk" }, Relaxed = { up = "def", down = "spe" },
    Impish = { up = "def", down = "spa" }, Lax = { up = "def", down = "spd" },
    Timid = { up = "spe", down = "atk" }, Hasty = { up = "spe", down = "def" },
    Jolly = { up = "spe", down = "spa" }, Naive = { up = "spe", down = "spd" },
    Modest = { up = "spa", down = "atk" }, Mild = { up = "spa", down = "def" },
    Quiet = { up = "spa", down = "spe" }, Rash = { up = "spa", down = "spd" },
    Calm = { up = "spd", down = "atk" }, Gentle = { up = "spd", down = "def" },
    Sassy = { up = "spd", down = "spe" }, Careful = { up = "spd", down = "spa" },
  }
  local NAT_KEYS = { "hp", "atk", "def", "spa", "spd", "spe" }
  local ENG_KEYS = { hp = "hp", atk = "atk", def = "def",
    spa = "spAtk", spd = "spDef", spe = "spd" }
  local IV_COST = 200
  local EV_COST = 125
  local NATURE_COST = 2000
  local ABILITY_COST = 5000
  local EV_PER_STAT = 252
  local function clamp(v, lo, hi)
    v = tonumber(v) or 0
    if v < lo then return lo end
    if v > hi then return hi end
    return v
  end
  local function g3Pokemon()
    if type(Pokemon) == "table" then return Pokemon end
    return nil
  end
  local function speciesNum(monOrSpecies)
    local P = g3Pokemon()
    local s = monOrSpecies
    if type(s) == "table" then s = s.species end
    if P then
      if type(s) == "table" then
        local ok, n = pcall(P.speciesOf, s)
        if ok and tonumber(n) then return tonumber(n) end
      elseif type(s) == "string" and not tonumber(s)
        and type(P.speciesFromName) == "function" then
        local ok, n = pcall(P.speciesFromName, s)
        if ok and tonumber(n) then return tonumber(n) end
      end
    end
    return tonumber(s)
  end
  local function gen3NatureId(mon)
    local P = g3Pokemon()
    if P and type(P.natureId) == "function" and mon then
      local ok, id = pcall(P.natureId, mon.personality)
      if ok and type(id) == "number" then return id % 25 end
    end
    if mon and tonumber(mon.personality) then
      return tonumber(mon.personality) % 25
    end
    return nil
  end
  local function natureNameOf(mon)
    local nid = gen3NatureId(mon)
    if nid ~= nil and G3_NATURES[nid + 1] then return G3_NATURES[nid + 1] end
    if type(mon) == "table" and type(mon.nature) == "string" then
      return mon.nature
    end
    return "Hardy"
  end
  local function natureIdOf(mon)
    if SummaryData and type(SummaryData.nature) == "function" then
      local ok, id = pcall(SummaryData.nature, mon)
      if ok and tonumber(id) then return tonumber(id) % 25 end
    end
    return gen3NatureId(mon) or 0
  end
  local function natureEffect(mon, key)
    if SummaryData and type(SummaryData.natureStatModifier) == "function" then
      local ok, fx = pcall(SummaryData.natureStatModifier, natureIdOf(mon), ENG_KEYS[key] or key)
      if ok and tonumber(fx) then return tonumber(fx) end
    end
    local m = NATURE_MOD[natureNameOf(mon)]
    if not m then return 1 end
    if m.up == key then return 1.1 end
    if m.down == key then return 0.9 end
    return 1
  end
  local function gen3SetPersonality(mon, spNum, wantNature, wantGender, wantParity, genderChanged)
    if type(mon) ~= "table" then return false, "NO POKEMON" end
    if wantGender ~= "male" and wantGender ~= "female" then
      wantGender = nil
      genderChanged = false
    end
    local P = g3Pokemon()
    local cur = tonumber(mon.personality) or 0
    local haveGender = P and type(P.gender) == "function" and tonumber(spNum)
    if genderChanged and not haveGender then
      return false, "GENDER CHANGE NEEDS ENGINE DATA"
    end
    local pinLow = nil
    if not haveGender and not genderChanged then pinLow = cur % 256 end
    local function ok(p)
      if wantNature ~= nil and (p % 25) ~= wantNature then return false end
      if wantParity ~= nil and (p % 2) ~= wantParity then return false end
      if pinLow ~= nil and (p % 256) ~= pinLow then return false end
      if wantGender ~= nil then
        if not haveGender then return false end
        local gok, g = pcall(P.gender, spNum, p)
        if not gok then return false end
        if wantGender == "male" and g ~= "M" then return false end
        if wantGender == "female" and g ~= "F" then return false end
      end
      return true
    end
    if ok(cur) then return "same" end
    if pinLow ~= nil then
      for k = 0, 30 do
        local p = pinLow + 256 * k
        if ok(p) then mon.personality = p return true end
      end
      return false, "ABILITY PARITY CONFLICTS (NEEDS ENGINE GENDER DATA)"
    end
    for p = 0, 26000 do
      if ok(p) then mon.personality = p return true end
    end
    if genderChanged then return false, "GENDER CHANGE FAILED" end
    return false, "NO MATCHING PERSONALITY"
  end
  local function abilityList(mon)
    local list = {}
    local P = g3Pokemon()
    if P and type(P.abilities) == "function" and mon then
      local ok, pair = pcall(P.abilities, speciesNum(mon) or mon.species)
      if ok and type(pair) == "table" then
        for i = 1, 2 do
          if pair[i] ~= nil then list[#list + 1] = pair[i] end
        end
      end
    end
    if #list == 0 and mon and mon.ability ~= nil then
      list = { mon.ability }
    end
    return list
  end
  local function abilityIndex(list, mon)
    if tonumber(mon.abilityNum) and list[tonumber(mon.abilityNum) + 1] then
      return tonumber(mon.abilityNum) + 1
    end
    for i, a in ipairs(list) do
      if a == mon.ability then return i end
    end
    return 1
  end
  local function abilityNameOf(w)
    local a = w.abilities[w.abilityIdx]
    if type(a) == "table" then return tostring(a.name or a.id or "?") end
    if tonumber(a) then
      local P = g3Pokemon()
      if P and type(P.abilityName) == "function" then
        local ok, n = pcall(P.abilityName, tonumber(a))
        if ok and type(n) == "string" and n ~= "" then return string.upper(n) end
      end
      if tonumber(a) == 0 then return "-------" end
      return tostring(a)
    end
    if a ~= nil then return tostring(a) end
    return "?"
  end
  local gen3Session = nil
  local function playerEvCap()
    if mod.exports and type(mod.exports.evTotalCapFor) == "function" then
      local ok, cap = pcall(mod.exports.evTotalCapFor, "player")
      if ok and tonumber(cap) then return tonumber(cap) end
    end
    return 510
  end
  local function moneyOf(save)
    if type(save) == "table" then
      local player = save.player
      if type(player) == "table" and type(player.money) == "number" then
        return player.money
      end
      if tonumber(save.money) then return tonumber(save.money) end
    end
    if gen3Session and tonumber(gen3Session.money) then
      return math.max(0, math.floor(tonumber(gen3Session.money)))
    end
    return 0
  end
  local function setMoney(save, value)
    value = math.max(0, math.floor(value or 0))
    if type(save) == "table" then
      local player = save.player
      if type(player) == "table" and player.money ~= nil then
        player.money = value
        return
      end
      if save.money ~= nil then
        save.money = value
        return
      end
    end
    if gen3Session then gen3Session.money = value return end
    if type(save) == "table" then save.money = value end
  end
  local function liveSave()
    local ok, Game = pcall(require, "src.core.Game")
    if ok and type(Game) == "table" then return Game.save end
    return nil
  end
  local function battleActive()
    local ok, B = pcall(require, "src.core.game3.battle")
    if ok and type(B) == "table" and type(B.isActive) == "function" then
      local ok2, v = pcall(B.isActive)
      if ok2 and v then return true end
    end
    return false
  end
  local function isEgg(mon)
    if type(mon) ~= "table" then return true end
    if mon.isEgg then return true end
    local P = g3Pokemon()
    if P and type(P.isEgg) == "function" then
      local ok, v = pcall(P.isEgg, mon)
      if ok and v then return true end
    end
    return false
  end
  local G = { mode = 1, byMon = setmetatable({}, { __mode = "k" }),
    prompt = nil, flash = nil, lastInput = nil, rep = nil }
  local function flashQ(text)
    G.flash = { text = tostring(text or ""), untilT = getNow() + 2.5 }
  end
  local function newWork(mon)
    local w = { sel = nil, edit = nil, pro = nil, abSub = nil,
      entryAb = nil, ivs = {}, evs = {}, baseIvs = {}, baseEvs = {} }
    for _, key in ipairs(STAT_ORDER) do
      w.ivs[key] = clamp(statOf(mon.ivs, key) or 15, 0, 31)
      w.evs[key] = clamp(statOf(mon.evs, key) or 0, 0, EV_PER_STAT)
    end
    for _, key in ipairs(STAT_ORDER) do
      w.baseIvs[key] = w.ivs[key]
      w.baseEvs[key] = w.evs[key]
    end
    w.nature = natureNameOf(mon)
    w.baseNature = w.nature
    w.abilities = abilityList(mon)
    w.abilityIdx = abilityIndex(w.abilities, mon)
    w.baseAbilityIdx = w.abilityIdx
    return w
  end
  local function workFor(mon)
    local w = G.byMon[mon]
    if type(w) ~= "table" then
      w = newWork(mon)
      G.byMon[mon] = w
    end
    return w
  end
  local function resetWork(w)
    if type(w) ~= "table" then return end
    for _, key in ipairs(STAT_ORDER) do
      w.ivs[key] = w.baseIvs[key]
      w.evs[key] = w.baseEvs[key]
    end
    w.nature = w.baseNature
    w.abilityIdx = w.baseAbilityIdx
    w.pro = nil
    w.abSub = nil
    w.sel = nil
    w.edit = nil
    w.hud = nil
    w.adj = nil
  end
  local function evTotal(w)
    local total = 0
    for _, key in ipairs(STAT_ORDER) do total = total + (w.evs[key] or 0) end
    return total
  end
  local function workCost(w)
    local cost = 0
    for _, key in ipairs(STAT_ORDER) do
      cost = cost + IV_COST * math.abs((w.ivs[key] or 0) - (w.baseIvs[key] or 0))
      cost = cost + EV_COST * math.abs((w.evs[key] or 0) - (w.baseEvs[key] or 0))
    end
    if w.nature ~= w.baseNature then cost = cost + NATURE_COST end
    if w.abilityIdx ~= w.baseAbilityIdx then cost = cost + ABILITY_COST end
    return cost
  end
  local function hasChanges(w)
    return workCost(w) > 0
  end
  local GRID_COLS = { { "hp", "atk", "def" }, { "spa", "spd", "spe" } }
  local function gridKey(col, row)
    if tonumber(col) == 1 and tonumber(row) >= 1 and tonumber(row) <= 3 then
      return GRID_COLS[1][tonumber(row)]
    end
    if tonumber(col) == 2 and tonumber(row) >= 1 and tonumber(row) <= 3 then
      return GRID_COLS[2][tonumber(row)]
    end
    return nil
  end
  local function stepStat(w, kind, key, dir)
    if type(w) ~= "table" or key == nil then return end
    if kind == "iv" then
      w.ivs[key] = clamp((w.ivs[key] or 0) + dir, 0, 31)
      return
    end
    local cur = w.evs[key] or 0
    if dir > 0 then
      local room = playerEvCap() - (evTotal(w) - cur)
      if room <= 0 then
        flashQ("EV LIMIT " .. tostring(playerEvCap()))
        return
      end
      w.evs[key] = clamp(math.min(cur + 4, room, EV_PER_STAT), 0, EV_PER_STAT)
    else
      w.evs[key] = clamp(cur - 4, 0, EV_PER_STAT)
    end
  end
  local function cycleNature(w, dir)
    local idx = 1
    for i, n in ipairs(G3_NATURES) do
      if n == w.nature then idx = i break end
    end
    idx = ((idx - 1 + dir) % #G3_NATURES) + 1
    w.nature = G3_NATURES[idx]
  end
  local function natHint(nature)
    local m = NATURE_MOD[nature]
    if not m then return "NEUTRAL" end
    return "+" .. (STAT_LABEL[m.up] or m.up) .. " -" .. (STAT_LABEL[m.down] or m.down)
  end
  local function cycleAbility(w, dir)
    if #w.abilities < 2 then
      flashQ("ONE ABILITY")
      return
    end
    w.abilityIdx = ((w.abilityIdx - 1 + dir) % #w.abilities) + 1
    local cur = w.abilities[w.abilityIdx]
    if cur == nil or tonumber(cur) == 0 then
      flashQ("NO SECONDARY ABILITY")
    end
  end
  local function commitWork(mon, w)
    if not hasChanges(w) then
      flashQ("NOTHING TO CHANGE")
      return false
    end
    local cost = workCost(w)
    local save = liveSave()
    if moneyOf(save) < cost then
      flashQ("NOT ENOUGH MONEY")
      return false
    end
    local oldMax = statOf(mon.stats, "hp")
    local oldHp = tonumber(mon.hp)
    mon.ivs = mon.ivs or {}
    mon.evs = mon.evs or {}
    for _, key in ipairs(STAT_ORDER) do
      mon.ivs[key] = w.ivs[key]
      mon.evs[key] = w.evs[key]
    end
    local wantNature = nil
    for i, n in ipairs(G3_NATURES) do
      if n == w.nature then wantNature = i - 1 break end
    end
    local abChanged = (w.abilityIdx ~= w.baseAbilityIdx)
    local natChanged = (w.nature ~= w.baseNature)
    local spNum = speciesNum(mon)
    if natChanged or abChanged then
      local curPers = tonumber(mon.personality)
      local wantParity = curPers and (curPers % 2) or nil
      if abChanged then wantParity = (w.abilityIdx == 2) and 1 or 0 end
      local okP, perr = gen3SetPersonality(mon, spNum, wantNature, nil, wantParity, false)
      if not okP then
        flashQ("PERSONALITY FAILED" .. (perr and (": " .. tostring(perr)) or ""))
        return false
      end
    end
    if abChanged then
      local picked = w.abilities[w.abilityIdx]
      if picked == nil or tonumber(picked) == 0 then
        flashQ("NO SECONDARY ABILITY")
        return false
      end
      local P = g3Pokemon()
      local pair = nil
      if P and type(P.abilities) == "function" then
        local ok, res = pcall(P.abilities, spNum or mon.species)
        if ok and type(res) == "table" then pair = res end
      end
      local writeVal = picked
      if type(picked) == "table" then writeVal = picked.name or picked.id end
      if pair and pair[w.abilityIdx] ~= nil then
        writeVal = pair[w.abilityIdx]
      end
      mon.ability = writeVal
      mon.abilityId = writeVal
      mon.abilityNum = w.abilityIdx - 1
    end
    local P = g3Pokemon()
    if P and type(P.applyStats) == "function" then
      pcall(P.applyStats, mon)
    end
    if oldMax and oldHp and statOf(mon.stats, "hp") then
      local missing = math.max(0, oldMax - oldHp)
      local newMax = statOf(mon.stats, "hp")
      if oldHp > 0 then mon.hp = math.max(1, newMax - missing) end
    end
    for _, key in ipairs(STAT_ORDER) do
      w.baseIvs[key] = w.ivs[key]
      w.baseEvs[key] = w.evs[key]
    end
    w.baseNature = w.nature
    w.baseAbilityIdx = w.abilityIdx
    w.sel = nil
    w.edit = nil
    w.pro = nil
    w.abSub = nil
    w.hud = nil
    w.adj = nil
    setMoney(save, moneyOf(save) - cost)
    flashQ("TRAINING COMPLETE")
    return true
  end
  local function holderOf(layer)
    if type(layer) == "table" and type(layer._party) == "table" then
      return layer
    end
    if type(U) == "table" and type(U._party) == "table" then return U end
    return nil
  end
  local function rawMonOf(holder)
    if type(holder) ~= "table" then return nil end
    local p = holder._party
    if type(p) ~= "table" then return nil end
    local m = p[holder._cursor or 1]
    if type(m) ~= "table" then return nil end
    if holder._loaded ~= nil and holder._loaded ~= m then return nil end
    return m
  end
  local function selectMode(holder)
    local m = holder._mode
    if m == "select_move" then return true end
    local n = tonumber(m)
    if n and n >= 2 and n <= 4 then return true end
    return false
  end
  local function busy(holder)
    local s = holder._slide
    if type(s) == "table" and s.active then return true end
    if holder._fade or holder._pageTask or holder._reload then return true end
    if holder._selectSetup ~= nil then return true end
    local o = holder._opts
    if type(o) == "table" and type(o.linkBusy) == "function" then
      local ok, v = pcall(o.linkBusy)
      if ok and v then return true end
    end
    return false
  end
  local function blockedCtx(holder)
    if holder._enemyParty then return true end
    local ctx = holder._context
    if ctx == "trade" or ctx == "factory" then return true end
    return false
  end
  local function openPrompt(mon)
    G.prompt = { mon = mon, yes = false }
    G.rep = nil
    se()
  end
  local function doPromptCommit()
    local p = G.prompt
    if not p then return end
    if not p.yes then
      local mon = p.mon
      G.prompt = nil
      G.rep = nil
      if type(mon) == "table" then resetWork(workFor(mon)) end
      se()
      return
    end
    local mon = p.mon
    G.prompt = nil
    if type(mon) ~= "table" then return end
    local w = workFor(mon)
    commitWork(mon, w)
    se()
  end
  local function pressed(input, key)
    if type(input) ~= "table" then return false end
    local f = input.wasPressed
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f, input, key)
    return ok and v == true
  end
  local function armRepeat(key, mon, kind, stat)
    G.rep = { key = key, mon = mon, kind = kind, stat = stat,
      t0 = getNow(), last = getNow() }
  end
  local function promptKeys(input)
    if pressed(input, "up") or pressed(input, "down")
      or pressed(input, "left") or pressed(input, "right")
      or pressed(input, "l") or pressed(input, "r") then
      G.prompt.yes = not G.prompt.yes
      se()
      return true
    end
    if pressed(input, "a") or pressed(input, "start") then
      doPromptCommit()
      return true
    end
    if pressed(input, "b") then
      G.prompt = nil
      se()
      return true
    end
    if pressed(input, "select") then
      return true
    end
    return false
  end
  local function openHud(w)
    w.hud = "menu"
    w.mrow = 1
    w.gcol = 1
    w.grow = 1
    w.adj = nil
    G.rep = nil
  end
  local function closeHud(w)
    w.hud = nil
    w.adj = nil
    G.rep = nil
  end
  local function hudMenuKeys(input, mon, w)
    if pressed(input, "up") then
      w.mrow = w.mrow > 1 and w.mrow - 1 or 4
      se()
      return true
    end
    if pressed(input, "down") then
      w.mrow = w.mrow < 4 and w.mrow + 1 or 1
      se()
      return true
    end
    if pressed(input, "left") or pressed(input, "right")
      or pressed(input, "l") or pressed(input, "r") then
      return true
    end
    if pressed(input, "a") or pressed(input, "start") then
      if w.mrow == 1 then
        w.hud = "ev"
      elseif w.mrow == 2 then
        w.hud = "iv"
      elseif w.mrow == 3 then
        if hasChanges(w) then openPrompt(mon)
        else flashQ("NOTHING TO CHANGE") end
        return true
      else
        closeHud(w)
        se()
        return true
      end
      w.gcol = 1
      w.grow = 1
      w.adj = nil
      G.rep = nil
      se()
      return true
    end
    if pressed(input, "b") then
      closeHud(w)
      se()
      return true
    end
    return false
  end
  local function hudGridKeys(input, mon, w)
    local kind = w.hud
    if w.adj then
      if pressed(input, "up") then
        stepStat(w, kind, w.adj, 1)
        armRepeat("up", mon, kind, w.adj)
        return true
      end
      if pressed(input, "down") then
        stepStat(w, kind, w.adj, -1)
        armRepeat("down", mon, kind, w.adj)
        return true
      end
      if pressed(input, "left") or pressed(input, "right")
        or pressed(input, "l") or pressed(input, "r") then
        return true
      end
      if pressed(input, "a") or pressed(input, "b") or pressed(input, "start") then
        w.adj = nil
        G.rep = nil
        se()
        return true
      end
      return false
    end
    if pressed(input, "up") then
      if w.grow > 1 then w.grow = w.grow - 1 end
      se()
      return true
    end
    if pressed(input, "down") then
      if w.grow < 4 then w.grow = w.grow + 1 end
      se()
      return true
    end
    if pressed(input, "left") or pressed(input, "right") then
      if w.grow <= 3 then w.gcol = w.gcol == 1 and 2 or 1 end
      se()
      return true
    end
    if pressed(input, "l") or pressed(input, "r") then
      return true
    end
    if pressed(input, "a") then
      if w.grow == 4 then
        if hasChanges(w) then openPrompt(mon)
        else flashQ("NOTHING TO CHANGE") end
        return true
      end
      local key = gridKey(w.gcol, w.grow)
      if key then
        w.adj = key
        G.rep = nil
        se()
      end
      return true
    end
    if pressed(input, "start") then
      if hasChanges(w) then openPrompt(mon)
      else flashQ("NOTHING TO CHANGE") end
      return true
    end
    if pressed(input, "b") then
      w.hud = "menu"
      w.adj = nil
      G.rep = nil
      se()
      return true
    end
    return false
  end
  local function skillsKeys(input, holder, mon, w)
    if pressed(input, "select") or pressed(input, "f") then
      if w.hud then closeHud(w)
      else openHud(w) end
      se()
      return true
    end
    if not w.hud then return false end
    if w.hud == "menu" then return hudMenuKeys(input, mon, w) end
    return hudGridKeys(input, mon, w)
  end
  local function infoKeys(input, holder, mon, w)
    if w.pro == nil then
      if pressed(input, "a") then
        w.pro = { row = 1 }
        w.entryAb = w.abilityIdx
        se()
        return true
      end
      if pressed(input, "b") or pressed(input, "start") then
        if hasChanges(w) then
          openPrompt(mon)
          return true
        end
        return false
      end
      return false
    end
    local pro = w.pro
    if w.abSub then
      if pressed(input, "left") or pressed(input, "up") or pressed(input, "l") then
        cycleAbility(w, -1)
        return true
      end
      if pressed(input, "right") or pressed(input, "down") or pressed(input, "r") then
        cycleAbility(w, 1)
        return true
      end
      if pressed(input, "a") then
        w.abSub = nil
        se()
        return true
      end
      if pressed(input, "b") then
        w.abilityIdx = w.entryAb or w.abilityIdx
        w.abSub = nil
        se()
        return true
      end
      if pressed(input, "start") then
        if hasChanges(w) then openPrompt(mon)
        else flashQ("NOTHING TO CHANGE") end
        return true
      end
      if pressed(input, "select") then return true end
      return false
    end
    if pressed(input, "up") or pressed(input, "down") then
      pro.row = pro.row == 1 and 2 or 1
      se()
      return true
    end
    if pressed(input, "left") then
      if pro.row == 1 then cycleNature(w, -1) end
      return true
    end
    if pressed(input, "right") then
      if pro.row == 1 then cycleNature(w, 1) end
      return true
    end
    if pressed(input, "l") or pressed(input, "r") then
      return true
    end
    if pressed(input, "a") then
      if pro.row == 1 then
        cycleNature(w, 1)
        return true
      end
      if #w.abilities < 2 then
        flashQ("ONE ABILITY")
        return true
      end
      w.entryAb = w.abilityIdx
      w.abSub = true
      se()
      return true
    end
    if pressed(input, "b") then
      if hasChanges(w) then
        openPrompt(mon)
        return true
      end
      w.pro = nil
      se()
      return true
    end
    if pressed(input, "start") then
      if hasChanges(w) then openPrompt(mon)
      else flashQ("NOTHING TO CHANGE") end
      return true
    end
    if pressed(input, "select") then return true end
    return false
  end
  local function consume(input, layer)
    G.lastInput = input
    if battleActive() then return false end
    local holder = holderOf(layer)
    if holder == nil then return false end
    if blockedCtx(holder) then return false end
    local mon = rawMonOf(holder)
    if type(mon) ~= "table" or isEgg(mon) then
      G.prompt = nil
      G.rep = nil
      return false
    end
    if selectMode(holder) then
      G.prompt = nil
      G.rep = nil
      return false
    end
    local page = tonumber(holder._page) or 0
    if page ~= 0 and page ~= 1 then
      G.prompt = nil
      G.rep = nil
      return false
    end
    if busy(holder) then
      if G.prompt then return promptKeys(input) end
      return false
    end
    local w = workFor(mon)
    if G.prompt then
      if G.prompt.mon ~= mon then G.prompt = nil
      else return promptKeys(input) end
    end
    if page == 1 then return skillsKeys(input, holder, mon, w)
    else return infoKeys(input, holder, mon, w) end
  end
  local function repeatTick()
    local r = G.rep
    if not r then return end
    if G.prompt then
      G.rep = nil
      return
    end
    local w = G.byMon[r.mon]
    if type(w) ~= "table" then
      G.rep = nil
      return
    end
    if w.adj ~= r.stat or w.hud ~= r.kind then
      G.rep = nil
      return
    end
    local t = getNow()
    if t - r.t0 < 0.35 then return end
    if t - r.last < 0.06 then return end
    if not held(G.lastInput, r.key) then
      G.rep = nil
      return
    end
    r.last = t
    stepStat(w, r.kind, r.stat, r.key == "up" and 1 or -1)
  end
  local function gfx()
    local okL, L = pcall(function() return love end)
    if okL and type(L) == "table" and type(L.graphics) == "table" then
      return L.graphics
    end
    return nil
  end
  local function dims()
    local Wd, Ht = 240, 160
    local ok, D = pcall(require, "src.core.game3.display")
    if ok and type(D) == "table" then
      if tonumber(D.W) then Wd = tonumber(D.W) end
      if tonumber(D.H) then Ht = tonumber(D.H) end
    end
    return Wd, Ht
  end
  local function white()
    if Frlg and type(Frlg.COLOR) == "table" and Frlg.COLOR.WHITE then
      return Frlg.COLOR.WHITE
    end
    if Frlg and type(Frlg.COLOR) == "table" and Frlg.COLOR.NORMAL then
      return Frlg.COLOR.NORMAL
    end
    return nil
  end
  local function dtext(s, x, y, col)
    s = tostring(s or "")
    if Frlg then
      local ok = pcall(Frlg.draw, s, x, y, { colors = col or white() })
      if ok then return end
    end
    local Gg = gfx()
    if Gg then pcall(Gg.print, s, x, y) end
  end
  local function dmeasure(s)
    s = tostring(s or "")
    if Frlg and type(Frlg.measure) == "function" then
      local ok, w = pcall(Frlg.measure, s, {})
      if ok and tonumber(w) then return tonumber(w) end
    end
    return #s * 6
  end
  local function drawBox(x, y, w, h)
    local Gg = gfx()
    if not Gg then return end
    Gg.setColor(0.05, 0.05, 0.08, 0.94)
    Gg.rectangle("fill", x, y, w, h, 3)
    Gg.setColor(0.95, 0.95, 0.95, 1)
    Gg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3)
    Gg.setColor(1, 1, 1, 1)
  end
  local function drawCursorTri(x, y)
    local Gg = gfx()
    if not Gg then return end
    Gg.setColor(0.91, 0.22, 0.22, 1)
    Gg.polygon("fill", x, y, x, y + 7, x + 6, y + 3)
    Gg.setColor(1, 1, 1, 1)
  end
  local function drawPrompt()
    local p = G.prompt
    if not p then return end
    local w = nil
    if type(p.mon) == "table" then w = G.byMon[p.mon] end
    if type(w) ~= "table" then return end
    local Wd, Ht = dims()
    local bw, bh = 216, 66
    local bx = math.floor((Wd - bw) / 2)
    local by = math.floor((Ht - bh) / 2)
    local Gg = gfx()
    if Gg then
      Gg.setColor(0, 0, 0, 0.55)
      Gg.rectangle("fill", 0, 0, Wd, Ht)
      Gg.setColor(1, 1, 1, 1)
    end
    drawBox(bx, by, bw, bh)
    local col = white()
    dtext("This will cost " .. tostring(workCost(w)) .. ",", bx + 6, by + 6, col)
    dtext("you want to proceed?", bx + 6, by + 18, col)
    local yn = (p.yes and "> YES" or "  YES") .. "    " .. ((not p.yes) and "> NO" or "  NO")
    dtext(yn, bx + 6, by + 32, col)
    dtext("A OK  B BACK", bx + 6, by + 48, col)
  end
  local function drawProfile(mon, w)
    local Wd, Ht = dims()
    local bw, bh = 216, 96
    local bx = math.floor((Wd - bw) / 2)
    local by = math.floor((Ht - bh) / 2)
    local Gg = gfx()
    if Gg then
      Gg.setColor(0, 0, 0, 0.45)
      Gg.rectangle("fill", 0, 0, Wd, Ht)
      Gg.setColor(1, 1, 1, 1)
    end
    drawBox(bx, by, bw, bh)
    local col = white()
    local y = by + 6
    dtext(((w.pro.row == 1) and ">" or " ") .. " NATURE  " .. tostring(w.nature), bx + 8, y, col)
    dtext("   " .. natHint(w.nature), bx + 8, y + 12, col)
    dtext(((w.pro.row == 2) and ">" or " ") .. " ABILITY " .. abilityNameOf(w), bx + 8, y + 26, col)
    dtext("COST " .. tostring(workCost(w)), bx + 8, y + 40, col)
    if w.abSub then
      dtext("A OK  B BACK", bx + 8, y + 54, col)
    else
      dtext("A CYCLE  B BACK  START DONE", bx + 8, y + 54, col)
    end
    dtext("UP/DOWN PICK ROW", bx + 8, y + 68, col)
  end
  local function statTint(mon, key)
    if Frlg and type(Frlg.COLOR) == "table" then
      local fx = natureEffect(mon, key)
      if fx > 1 and Frlg.COLOR.RED then return Frlg.COLOR.RED end
      if fx < 1 and Frlg.COLOR.BLUE then return Frlg.COLOR.BLUE end
    end
    return nil
  end
  local function tintedOpts(mon, key, opts)
    local want = statTint(mon, key)
    if type(want) ~= "table" or want.fg == nil then return nil end
    local out = {}
    if type(opts) == "table" then
      for k, v in pairs(opts) do out[k] = v end
    end
    out.colors = want
    return out
  end
  local function rsStatKey(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end
    if y == 56 then
      if x >= 216 then return "spa" end
      if x >= 128 and x <= 174 then return "hp" end
      return nil
    end
    if y == 72 then
      if x >= 128 and x < 176 then return "atk" end
      if x >= 216 then return "spd" end
      return nil
    end
    if y == 88 then
      if x >= 128 and x < 176 then return "def" end
      if x >= 216 then return "spe" end
      return nil
    end
    return nil
  end
  local function frlgRowKey()
    local rows = { atk = 38, def = 51, spa = 64, spd = 77, spe = 90 }
    local okC, Chrome = pcall(require, "src.ui.game3.summary_chrome")
    if okC and type(Chrome) == "table" and type(Chrome.manifest) == "function" then
      local okM, m = pcall(Chrome.manifest)
      if okM and type(m) == "table" and type(m.coords) == "table" then
        local c = m.coords
        local function cy(k, fy)
          local r = c[k]
          if type(r) == "table" and tonumber(r.y) then return tonumber(r.y) end
          return fy
        end
        rows = { atk = cy("atk", 38), def = cy("def", 51), spa = cy("spAtk", 64),
          spd = cy("spDef", 77), spe = cy("spd", 90) }
      end
    end
    local byY = {}
    for k, v in pairs(rows) do byY[v] = k end
    return byY
  end
  local function rseMatch(man, x, y)
    if type(man) ~= "table" or type(man.pageWindows) ~= "table" then return nil end
    local sk = man.pageWindows.skills
    if type(sk) ~= "table" then return nil end
    local left, right = sk[3], sk[4]
    if type(left) == "table" and x == left.left * 8 + 4 and y == left.top * 8 + 1 then
      return "left", left
    end
    if type(right) == "table" and x == right.left * 8 + 2 and y == right.top * 8 + 1 then
      return "right", right
    end
    return nil
  end
  local function ensureTextHooks()
    if Frlg and type(Frlg.draw) == "function" and Frlg.draw ~= G.__ptSiT then
      local orig = Frlg.draw
      local T = function(text, x, y, opts)
        local a = G.textTint
        if type(a) == "table" and type(a.mon) == "table"
          and type(text) == "string" and tonumber(text) then
          if a.kind == "frlg" and type(opts) == "table" and tonumber(opts.maxWidth) == 27 then
            local key = G.frlgRowKey and G.frlgRowKey[tonumber(y)]
            if key and key ~= "hp" then
              local o2 = tintedOpts(a.mon, key, opts)
              if o2 then return orig(text, x, y, o2) end
            end
            return orig(text, x, y, opts)
          elseif a.kind == "rs" then
            local key = rsStatKey(x, y)
            if key and key ~= "hp" then
              local o2 = tintedOpts(a.mon, key, opts)
              if o2 then return orig(text, x, y, o2) end
            end
            return orig(text, x, y, opts)
          end
        end
        return orig(text, x, y, opts)
      end
      G.__ptSiT = T
      Frlg.draw = T
    end
    if PalText and type(PalText.draw) == "function" and PalText.draw ~= G.__ptSiP then
      local origP = PalText.draw
      local P = function(text, x, y, ctx)
        local a = G.textTint
        if type(a) == "table" and a.kind == "rse" and type(a.mon) == "table"
          and type(a.man) == "table" and type(ctx) == "table" and type(text) == "string" then
          local side = rseMatch(a.man, x, y)
          if side and Frlg and type(Frlg.draw) == "function"
            and type(PalText.colors) == "function" then
            local okC, base = pcall(PalText.colors, ctx.pal, ctx.colors)
            if okC and type(base) == "table" then
              local opts = { font = ctx.font, colors = base }
              local pitch = tonumber(ctx.pitch)
              if not pitch then
                if type(Frlg.linePitch) == "function" then
                  local okL, lp = pcall(Frlg.linePitch)
                  if okL and tonumber(lp) then pitch = tonumber(lp) end
                end
                if not pitch then pitch = 16 end
              end
              local st = a.mon.stats or {}
              local function sval(short, long)
                return tonumber(a.mon[long] or a.mon[short] or st[long] or st[short]) or 0
              end
              local vals = {
                tostring(tonumber(a.mon.hp) or 0) .. "/" .. tostring(tonumber(a.mon.maxHp or st.hp) or 0),
                tostring(sval("atk", "attack")), tostring(sval("def", "defense")),
                tostring(sval("spa", "spAtk")), tostring(sval("spd", "spDef")), tostring(sval("spe", "speed")),
              }
              local isLeft = side == "left"
              local rightEdge = x + Frlg.measure("0", opts) * (isLeft and 7 or 3)
              for row = 1, 3 do
                local index = row + (isLeft and 0 or 3)
                local key = STAT_ORDER[index]
                local o2 = (index == 1) and opts or (tintedOpts(a.mon, key, opts) or opts)
                local value = vals[index]
                Frlg.draw(value, rightEdge - Frlg.measure(value, o2), y + (row - 1) * pitch, o2)
              end
              return (rightEdge - x), pitch * 2
            end
          end
        end
        return origP(text, x, y, ctx)
      end
      G.__ptSiP = P
      PalText.draw = P
    end
  end
  local function drawHudMenu(mon, w)
    local Wd, Ht = dims()
    local bw, bh = 216, 84
    local bx = math.floor((Wd - bw) / 2)
    local by = math.floor((Ht - bh) / 2)
    local Gg = gfx()
    if Gg then
      Gg.setColor(0, 0, 0, 0.45)
      Gg.rectangle("fill", 0, 0, Wd, Ht)
      Gg.setColor(1, 1, 1, 1)
    end
    drawBox(bx, by, bw, bh)
    local col = white()
    dtext("Press A to edit, B to go back", bx + 6, by + 6, col)
    local rows = { "EV", "IV", "APPLY", "CANCEL" }
    for i, name in ipairs(rows) do
      local mark = (w.mrow == i) and "> " or "  "
      dtext(mark .. "[" .. name, bx + 6, by + 6 + i * 12, col)
    end
    dtext("COST " .. tostring(workCost(w)), bx + 6, by + 6 + 5 * 12, col)
  end
  local function drawHudGrid(mon, w, kind)
    local Wd, Ht = dims()
    local bw, bh = 216, 128
    local bx = math.floor((Wd - bw) / 2)
    local by = math.floor((Ht - bh) / 2)
    local Gg = gfx()
    if type(Gg) ~= "table" then return end
    Gg.setColor(0, 0, 0, 0.45)
    Gg.rectangle("fill", 0, 0, Wd, Ht)
    Gg.setColor(1, 1, 1, 1)
    drawBox(bx, by, bw, bh)
    local col = white()
    dtext((kind == "iv" and "IV" or "EV") .. " TRAINING", bx + 6, by + 6, col)
    dtext("COST " .. tostring(workCost(w)), bx + 6, by + 18, col)
    local xs = { bx + 16, bx + 116 }
    for c = 1, 2 do
      for r = 1, 3 do
        local key = GRID_COLS[c][r]
        local y = by + 34 + (r - 1) * 12
        local cur = (not w.adj) and w.gcol == c and w.grow == r
        local mark = cur and "> " or "  "
        local val = kind == "iv" and tostring(w.ivs[key] or 0) or tostring(w.evs[key] or 0)
        dtext(mark .. (STAT_LABEL[key] or key) .. " " .. val, xs[c], y, statTint(mon, key) or col)
      end
    end
    local cmark = ((not w.adj) and w.grow == 4) and "> " or "  "
    dtext(cmark .. "[ CONFIRM", bx + 6, by + 76, col)
    dtext("A EDIT  B BACK", bx + 6, by + 94, col)
    dtext("UP/DN/L/R MOVE", bx + 6, by + 106, col)
  end
  local function drawAdjustPanel(mon, w, kind)
    local Wd, Ht = dims()
    local bw, bh = 200, 66
    local bx = math.floor((Wd - bw) / 2)
    local by = math.floor((Ht - bh) / 2)
    local Gg = gfx()
    if Gg then
      Gg.setColor(0, 0, 0, 0.45)
      Gg.rectangle("fill", 0, 0, Wd, Ht)
      Gg.setColor(1, 1, 1, 1)
    end
    drawBox(bx, by, bw, bh)
    local col = white()
    local key = w.adj or "hp"
    local val = kind == "iv" and (w.ivs[key] or 0) or (w.evs[key] or 0)
    dtext((STAT_LABEL[key] or key) .. " " .. (kind == "iv" and "IV " or "EV ") .. tostring(val), bx + 8, by + 6, col)
    dtext("COST " .. tostring(workCost(w)), bx + 8, by + 20, col)
    dtext("UP/DOWN ADJUST HOLD OK", bx + 8, by + 34, col)
    dtext("A/B BACK", bx + 8, by + 48, col)
  end
  local function drawFlash()
    local f = G.flash
    if not f then return end
    if getNow() > (f.untilT or 0) then
      G.flash = nil
      return
    end
    local Wd, Ht = dims()
    local s = tostring(f.text or "")
    local bw = math.max(80, dmeasure(s) + 16)
    local bx = math.floor((Wd - bw) / 2)
    local by = Ht - 22
    drawBox(bx, by, bw, 15)
    dtext(s, bx + 8, by + 1, white())
  end
  local function editorBusy(holder)
    local s = holder._slide
    if type(s) == "table" and s.active then return true end
    if holder._fade or holder._pageTask or holder._reload then return true end
    if holder._selectSetup ~= nil then return true end
    local o = holder._opts
    if type(o) == "table" and type(o.linkBusy) == "function" then
      local ok, v = pcall(o.linkBusy)
      if ok and v then return true end
    end
    return false
  end
  local function drawOverFor(holder, mon, page)
    local okO, errO = pcall(function()
      local Gg = gfx()
      local sr, sg, sb, sa = 1, 1, 1, 1
      if Gg then pcall(function() sr, sg, sb, sa = Gg.getColor() end) end
      if G.prompt and G.prompt.mon == mon then
        drawPrompt()
      elseif page == 1 then
        local w = workFor(mon)
        if w.hud == "menu" then drawHudMenu(mon, w)
        elseif w.hud == "ev" or w.hud == "iv" then
          drawHudGrid(mon, w, w.hud)
          if w.adj then drawAdjustPanel(mon, w, w.hud) end
        end
        drawFlash()
      elseif page == 0 then
        local w = workFor(mon)
        if w.pro then drawProfile(mon, w) end
        drawFlash()
      else
        drawFlash()
      end
      if Gg then pcall(function() Gg.setColor(sr, sg, sb, sa) end) end
    end)
    if not okO then
      pcall(mod.log.warn, mod.log, "pokemon-trainer: summary overlay failed: %s", tostring(errO))
    end
  end
  local function tryConsume(input, holder)
    if battleActive() then return false end
    if type(holder) ~= "table" then return false end
    if blockedCtx(holder) then return false end
    local mon = rawMonOf(holder)
    if type(mon) ~= "table" or isEgg(mon) then return false end
    if selectMode(holder) then return false end
    local page = tonumber(holder._page) or 0
    if page ~= 0 and page ~= 1 then return false end
    if editorBusy(holder) then
      if G.prompt and G.prompt.mon == mon then return promptKeys(input) end
      return false
    end
    local w = workFor(mon)
    if G.prompt then
      if G.prompt.mon ~= mon then G.prompt = nil else return promptKeys(input) end
    end
    if page == 1 then return skillsKeys(input, holder, mon, w) end
    return infoKeys(input, holder, mon, w)
  end
  local function resetState()
    G.byMon = setmetatable({}, { __mode = "k" })
    G.prompt = nil
    G.flash = nil
    G.rep = nil
  end
  local wrapFrlgDraw, wrapRseDraw, wrapRsDraw
  local function wrapOpenMenuOnce(M)
    if type(M) ~= "table" then return end
    if type(M.openMenu) ~= "function" then return end
    if M.__ptSiO then return end
    local orig = M.openMenu
    local O = function(...)
      resetState()
      if wrapFrlgDraw then wrapFrlgDraw() end
      if wrapRseDraw then wrapRseDraw() end
      if wrapRsDraw then wrapRsDraw() end
      ensureTextHooks()
      return orig(...)
    end
    M.__ptSiO = O
    M.openMenu = O
  end
  local function wrapUpdateOnce(M)
    if type(M) ~= "table" then return end
    if type(M.update) ~= "function" then return end
    if M.__ptSiU then return end
    local orig = M.update
    local Up = function(...)
      local okR, errR = pcall(repeatTick)
      if not okR then pcall(mod.log.warn, mod.log, "pokemon-trainer: summary repeat failed: %s", tostring(errR)) end
      return orig(...)
    end
    M.__ptSiU = Up
    M.update = Up
  end
  wrapFrlgDraw = function()
    if type(U) ~= "table" then return end
    if type(U.draw) ~= "function" then return end
    if U.draw == U.__ptSiD then return end
    local origD = U.draw
    local D = function(...)
      local monT = U._party and U._party[U._cursor]
      if type(monT) == "table" and not isEgg(monT) and tonumber(U._page) == 1 then
        G.textTint = { mon = monT, kind = "frlg" }
        G.frlgRowKey = frlgRowKey()
      end
      local r1 = origD(...)
      G.textTint = nil
      G.frlgRowKey = nil
      if U.open and not U._nativeDelegate and not (U._slide and U._slide.active) then
        local skinned = false
        local okSc, Sc = pcall(require, "src.ui.game3.screens")
        if okSc and type(Sc) == "table" and type(Sc.skin) == "function" then
          local okSk, sk = pcall(Sc.skin, "summary")
          if okSk and type(sk) == "table" and type(sk.draw) == "function" then skinned = true end
        end
        if not skinned then
          local mon = U._party and U._party[U._cursor]
          if type(mon) == "table" then
            pcall(drawOverFor, U, mon, tonumber(U._page) or 0)
          end
        end
      end
      return r1
    end
    U.__ptSiD = D
    U.draw = D
  end
  local function installFrlg()
    if type(U) ~= "table" then return end
    if type(U.handleInput) == "function" and U.handleInput ~= U.__ptSiH then
      local origH = U.handleInput
      local H = function(input)
        G.lastInput = input
        local okC, res = pcall(tryConsume, input, U)
        if okC and res then return end
        if not okC then pcall(mod.log.warn, mod.log, "pokemon-trainer: summary input failed: %s", tostring(res)) end
        return origH(input)
      end
      U.__ptSiH = H
      U.handleInput = H
    end
    wrapFrlgDraw()
    if type(U.update) == "function" then wrapUpdateOnce(U) end
    ensureTextHooks()
    U._ptSi = true
  end
  wrapRseDraw = function()
    local R = Rse
    if type(R) ~= "table" then
      local ok, m = pcall(require, "src.ui.game3.rse.summary_menu")
      if ok and type(m) == "table" then R = m Rse = m end
    end
    if type(R) ~= "table" then return end
    if type(R.draw) ~= "function" then return end
    if R.draw == R.__ptSiD then return end
    local origD = R.draw
    local D = function(Sm, ...)
      local okS0, S0 = pcall(require, "src.ui.game3.summary_menu")
      local useT = nil
      if type(Sm) == "table" and type(Sm._party) == "table" then useT = Sm
      elseif okS0 and type(S0) == "table" then useT = S0 end
      if useT == nil then useT = U end
      local monT = useT and (useT._loaded or (useT._party and useT._party[useT._cursor]))
      local pageT = useT and tonumber(useT._page) or 0
      if R.page and useT then
        local okP, p = pcall(R.page, useT)
        if okP and tonumber(p) then pageT = tonumber(p) end
      end
      if type(monT) == "table" and not isEgg(monT) and pageT == 1 and PalText and Frlg then
        local manT = nil
        if Kit and type(Kit.manifest) == "function" then
          local okM, man = pcall(Kit.manifest, "rse/summary")
          if okM and type(man) == "table" then manT = man end
        end
        if manT then G.textTint = { mon = monT, kind = "rse", man = manT } end
      end
      local r1 = origD(Sm, ...)
      G.textTint = nil
      local okS, S = pcall(require, "src.ui.game3.summary_menu")
      local use = nil
      if type(Sm) == "table" and type(Sm._party) == "table" then use = Sm
      elseif okS and type(S) == "table" then use = S end
      if use == nil then use = U end
      if use and use.open then
        local mon = use._loaded or (use._party and use._party[use._cursor])
        local page = tonumber(use._page) or 0
        if R.page then
          local okP, p = pcall(R.page, use)
          if okP and tonumber(p) then page = tonumber(p) end
        end
        if type(mon) == "table" then
          pcall(drawOverFor, use, mon, page)
        end
      end
      return r1
    end
    R.__ptSiD = D
    R.draw = D
  end
  local function installRse()
    wrapRseDraw()
    ensureTextHooks()
    if type(Rse) == "table" then Rse._ptSi = true end
  end
  wrapRsDraw = function()
    local S = RS
    if type(S) ~= "table" then
      local ok, m = pcall(require, "src.ui.game3.rs.summary_menu")
      if ok and type(m) == "table" then S = m RS = m end
    end
    if type(S) ~= "table" then return end
    if type(S.draw) ~= "function" then return end
    if S.draw == S.__ptSiD then return end
    local origD = S.draw
    local D = function(...)
      local monT = S._loaded or (S._party and S._party[S._cursor])
      if type(monT) == "table" and not isEgg(monT) and tonumber(S._page) == 1 then
        G.textTint = { mon = monT, kind = "rs" }
      end
      local r1 = origD(...)
      G.textTint = nil
      if S.open and not S._pageTask and S._state == "normal" then
        local mon = S._loaded or (S._party and S._party[S._cursor])
        if type(mon) == "table" then
          pcall(drawOverFor, S, mon, tonumber(S._page) or 0)
        end
      end
      return r1
    end
    S.__ptSiD = D
    S.draw = D
  end
  local function installRs()
    local S = RS
    if type(S) ~= "table" then
      local ok, m = pcall(require, "src.ui.game3.rs.summary_menu")
      if ok and type(m) == "table" then S = m RS = m end
    end
    if type(S) ~= "table" then return end
    if type(S.handleInput) == "function" and S.handleInput ~= S.__ptSiH then
      local origH = S.handleInput
      local H = function(input)
        G.lastInput = input
        local okC, res = pcall(tryConsume, input, S)
        if okC and res then return end
        if not okC then pcall(mod.log.warn, mod.log, "pokemon-trainer: summary input failed: %s", tostring(res)) end
        return origH(input)
      end
      S.__ptSiH = H
      S.handleInput = H
    end
    wrapRsDraw()
    if type(S.update) == "function" then wrapUpdateOnce(S) end
    ensureTextHooks()
    S._ptSi = true
  end
  wrapOpenMenuOnce(U)
  wrapOpenMenuOnce(RS)
  installFrlg()
  installRse()
  installRs()
  mod.log:info("pokemon-trainer: summary inspector installed")
end
