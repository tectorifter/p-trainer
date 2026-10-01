return function(mod)
  local Font = require("src.render.Font")
  local GameVersion = require("src.core.GameVersion")
  local gen = 1
  do
    local okGen, value = pcall(function()
      return GameVersion.generation(GameVersion.get())
    end)
    if okGen and (value == 1 or value == 2 or value == 3) then gen = value end
  end
  local isGen3Boot = (gen == 3)
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
  local MOVE_FIELD_LABELS = { "RELEARN", "EGG", "TUTOR" }
  local HM_MOVES = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    ROCKSMASH = true, WATERFALL = true, DIVE = true,
  }
  local MOVE_COST = 5000
  local IV_COST = 200
  local EV_COST = 125
  local NATURE_COST = 2000
  local ABILITY_COST = 5000
  local EV_PER_STAT = 252
  local TAB_IV, TAB_EV, TAB_NAT, TAB_GENDER = 1, 2, 3, 4
  local TAB_MOVES, TAB_ABILITY, TAB_HIDDEN = 5, 6, 7
  local TAB_LABELS = { "IV", "EV", "NAT", "M/F", "MOVES", "ABIL", "HID" }
  local TAB_WIDTHS = { 26, 26, 32, 32, 48, 38, 30 }
  local function clamp(v, lo, hi)
    v = tonumber(v) or 0
    if v < lo then return lo end
    if v > hi then return hi end
    return v
  end
  local function g3Pokemon()
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if ok and type(P) == "table" then return P end
    return nil
  end
  local function gen3SpeciesName(mon)
    local P = g3Pokemon()
    if P and type(P.name) == "function" and mon then
      local ok, name = pcall(P.name, mon.species)
      if ok and type(name) == "string" and name ~= "" then return name end
    end
    if mon and mon.species ~= nil then return tostring(mon.species) end
    return "???"
  end
  local function gen3NatureId(mon)
    local P = g3Pokemon()
    if P and type(P.natureId) == "function" and mon then
      local ok, id = pcall(P.natureId, mon.personality)
      if ok and type(id) == "number" then return id % 25 end
    end
    return nil
  end
  local function gen3GenderOf(mon)
    if type(mon) ~= "table" then return nil end
    if mon.gender == "M" then return "male" end
    if mon.gender == "F" then return "female" end
    return nil
  end
  local function gen3SetPersonality(mon, wantNature, wantGender, wantParity)
    if type(mon) ~= "table" then return false end
    local P = g3Pokemon()
    if not (P and type(P.gender) == "function") then return false end
    local cur = tonumber(mon.personality) or 0
    local function ok(p)
      if wantNature ~= nil and (p % 25) ~= wantNature then return false end
      if wantParity ~= nil and (p % 2) ~= wantParity then return false end
      if wantGender ~= nil then
        local gok, g = pcall(P.gender, mon.species, p)
        if not gok then return false end
        if wantGender == "male" and g ~= "M" then return false end
        if wantGender == "female" and g ~= "F" then return false end
      end
      return true
    end
    if ok(cur) then return false end
    for p = 0, 26000 do
      if ok(p) then mon.personality = p return true end
    end
    return false
  end
  local function gen3MoveName(numId)
    local P = g3Pokemon()
    if P and type(P.moveName) == "function" then
      local ok, name = pcall(P.moveName, tonumber(numId))
      if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
  end
  local function gen3MoveIdByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local P = g3Pokemon()
    if not (P and type(P.moveName) == "function") then return nil end
    local want = string.upper(name)
    for n = 1, 600 do
      local ok, mname = pcall(P.moveName, n)
      if ok and type(mname) == "string" and string.upper(mname) == want then
        return n
      end
    end
    return nil
  end
  local function gen3MovePp(numId)
    local P = g3Pokemon()
    if P and type(P.movePp) == "function" then
      local ok, pp = pcall(P.movePp, tonumber(numId))
      if ok and tonumber(pp) then return tonumber(pp) end
    end
    return 10
  end
  local function slotMoveName(move)
    if type(move) ~= "table" then return nil end
    if type(move.id) == "string" and move.id ~= "" then
      return string.upper(move.id)
    end
    local num = tonumber(move.moveId or move.move)
    if num then
      local name = gen3MoveName(num)
      if name then return string.upper(name) end
    end
    return nil
  end
  local gen3Session = nil
  local gen3Committed = setmetatable({}, { __mode = "k" })
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
  local function ndStatsBySpecies(species)
    local nd = mod.find and mod.find("national_dex")
    local ex = nd and nd.exports
    if not (ex and type(ex.statsBySpecies) == "function") then return nil end
    local ok, rec = pcall(ex.statsBySpecies, species)
    if ok and type(rec) == "table" then return rec end
    return nil
  end
  local function baseStatOf(rec, key)
    if type(rec) ~= "table" then return nil end
    local bs = rec.baseStats or rec.base
    if type(bs) ~= "table" then return nil end
    for _, k in ipairs(STAT_KEYS[key] or { key }) do
      if tonumber(bs[k]) then return tonumber(bs[k]) end
    end
    return nil
  end
  local function natureMult(nature, stat)
    local m = NATURE_MOD[nature]
    if not m then return 1 end
    if m.up == stat then return 1.1 end
    if m.down == stat then return 0.9 end
    return 1
  end
  local function gen3Stat(base, iv, ev, level, nature, key, isHp)
    local v = math.floor(((2 * base + iv + math.floor(ev / 4)) * level) / 100)
    if isHp then return v + level + 10 end
    return math.floor((v + 5) * natureMult(nature, key))
  end
  local STATS_W, STATS_H = 240, 160
  local function SX(v) return math.floor(v + 0.5) end
  local Frlg = nil
  local FrlgNormal = nil
  if isGen3Boot then
    local okF, found = pcall(require, "src.ui.game3.frlg_font")
    if okF and type(found) == "table" and type(found.draw) == "function" then
      Frlg = found
      if type(found.COLOR) == "table" then FrlgNormal = found.COLOR.NORMAL end
    end
  end
  local function tprint(text, x, y)
    if Frlg then
      local okDraw, drawn = pcall(Frlg.draw, tostring(text or ""), SX(x),
        SX(y), { colors = FrlgNormal, small = true })
      if okDraw and (tonumber(drawn) or 0) > 0 then return true end
    end
    if not isGen3Boot then
      Font.draw(text, SX(x), SX(y))
      return true
    end
    return false
  end
  local function cursor(x, y)
    if isGen3Boot then
      local G = love.graphics
      G.setColor(0.91, 0.22, 0.22, 1)
      local px, py = SX(x), SX(y)
      G.polygon("fill", px, py, px, py + 7, px + 6, py + 3)
      G.setColor(0, 0, 0, 1)
      return
    end
    Font.drawCode(0xED, SX(x), SX(y))
  end
  local function frame(x, y, w, h, level)
    local G = love.graphics
    if (level or 1) > 1 then
      G.setColor(0.12, 0.12, 0.12, 1)
      G.rectangle("line", SX(x) + 0.5, SX(y) + 0.5, SX(w), SX(h))
      G.rectangle("line", SX(x) + 1.5, SX(y) + 1.5,
        math.max(0, SX(w) - 2), math.max(0, SX(h) - 2))
    else
      G.setColor(1, 1, 1, 1)
      G.rectangle("line", SX(x) + 0.5, SX(y) + 0.5, SX(w), SX(h))
    end
    G.setColor(0, 0, 0, 1)
  end
  local function drawBorder(w, h)
    if isGen3Boot then
      local G = love.graphics
      G.setColor(0.10, 0.22, 0.50, 1)
      G.rectangle("line", 0.5, 0.5, w - 1, h - 1)
      G.setColor(0.16, 0.35, 0.72, 1)
      G.rectangle("line", 2.5, 2.5, w - 5, h - 5)
      G.setColor(0, 0, 0, 1)
      return
    end
    Font.drawBox(0, 0, w / 8, h / 8)
  end
  local Screen = {}
  Screen.__index = Screen
  function Screen.new(game, mon)
    local def = nil
    if mon then def = ndStatsBySpecies(mon.species) end
    local self = setmetatable({
      game = game, mon = mon, def = def,
      mode = "stats", focus = "tabs", page = TAB_IV, row = 1, col = 1,
      nature = nil, gender = nil, baseNature = nil, baseGender = nil,
      category = 1, moveIndex = 1, moveList = {}, moveNote = nil,
      pending = nil, pickingSlot = false, slotIndex = 1,
      status = "", broken = false,
      ivs = {}, evs = {}, baseIvs = {}, baseEvs = {},
      abilities = {}, abilityIdx = 1, baseAbilityIdx = 1,
    }, Screen)
    local nid = gen3NatureId(mon)
    if nid ~= nil and G3_NATURES[nid + 1] then
      self.nature = G3_NATURES[nid + 1]
    else
      self.nature = mon.nature or "Hardy"
    end
    self.baseNature = self.nature
    self.gender = gen3GenderOf(mon) or mon.gender
    self.baseGender = self.gender
    do
      local P = g3Pokemon()
      local list = {}
      if P and type(P.abilities) == "function" and mon then
        local ok, pair = pcall(P.abilities, mon.species)
        if ok and type(pair) == "table" then
          for i = 1, 2 do
            if pair[i] ~= nil then list[#list + 1] = pair[i] end
          end
        end
      end
      if #list == 0 and mon and mon.ability ~= nil then
        list = { mon.ability }
      end
      self.abilities = list
      local idx = nil
      if tonumber(mon.abilityNum) and list[tonumber(mon.abilityNum) + 1] then
        idx = tonumber(mon.abilityNum) + 1
      else
        for i, a in ipairs(list) do
          if a == mon.ability then idx = i break end
        end
      end
      self.abilityIdx = idx or 1
      self.baseAbilityIdx = self.abilityIdx
    end
    for _, key in ipairs(STAT_ORDER) do
      self.ivs[key] = clamp(mon.ivs and statOf(mon.ivs, key) or 15, 0, 31)
      self.evs[key] = clamp(mon.evs and statOf(mon.evs, key) or 0, 0, EV_PER_STAT)
    end
    for _, key in ipairs(STAT_ORDER) do
      self.baseIvs[key] = self.ivs[key]
      self.baseEvs[key] = self.evs[key]
    end
    self:buildMoveList()
    return self
  end
  function Screen:evTotal()
    local total = 0
    for _, key in ipairs(STAT_ORDER) do total = total + (self.evs[key] or 0) end
    return total
  end
  function Screen:abilityName(i)
    local a = self.abilities[i or self.abilityIdx]
    if type(a) == "table" then return tostring(a.name or a.id or "?") end
    if a ~= nil then return tostring(a) end
    return "?"
  end
  function Screen:pendingCost()
    local cost = 0
    for _, key in ipairs(STAT_ORDER) do
      cost = cost + IV_COST
        * math.abs((self.ivs[key] or 0) - (self.baseIvs[key] or 0))
      cost = cost + EV_COST
        * math.abs((self.evs[key] or 0) - (self.baseEvs[key] or 0))
    end
    if self.nature ~= self.baseNature then cost = cost + NATURE_COST end
    if self.abilityIdx ~= self.baseAbilityIdx then cost = cost + ABILITY_COST end
    return cost
  end
  function Screen:hasChanges()
    if self:pendingCost() > 0 then return true end
    return (self.gender or "") ~= (self.baseGender or "")
  end
  function Screen:preview(key)
    local mon = self.mon
    local level = tonumber(mon.level) or 5
    local base = baseStatOf(self.def, key)
    if base then
      return gen3Stat(base, self.ivs[key] or 0, self.evs[key] or 0,
        level, self.nature, key, key == "hp")
    end
    return statOf(mon.stats, key)
  end
  local function moveEntryName(entry)
    if type(entry) == "string" then return entry end
    if type(entry) == "table" then
      for _, k in ipairs({ "move", "name", "id", "moveId" }) do
        if type(entry[k]) == "string" and entry[k] ~= "" then return entry[k] end
      end
    end
    return nil
  end
  function Screen:buildMoveList()
    self.moveList = {}
    self.moveNote = nil
    local mon = self.mon
    local spec = mon and ndStatsBySpecies(mon.species) or nil
    if not (spec and type(spec.movesByMethod) == "table") then
      self.moveNote = "NO MOVE DATA"
      return
    end
    local byMethod = spec.movesByMethod
    local pools = nil
    if self.category == 1 then
      pools = { byMethod.levelup, byMethod.level_up, byMethod.relearn,
        byMethod.levelUp }
    elseif self.category == 2 then
      pools = { byMethod.egg }
    else
      pools = { byMethod.tutor }
    end
    local known = {}
    if mon and type(mon.moves) == "table" then
      for _, m in ipairs(mon.moves) do
        local n = slotMoveName(m)
        if n then known[n] = true end
      end
    end
    local seen = {}
    for _, pool in ipairs(pools) do
      if type(pool) == "table" then
        for _, entry in ipairs(pool) do
          local n = moveEntryName(entry)
          if n then
            local up = string.upper(n)
            if not known[up] and not seen[up] then
              seen[up] = true
              self.moveList[#self.moveList + 1] = n
            end
          end
        end
      end
    end
    table.sort(self.moveList)
    if self.moveIndex > #self.moveList then
      self.moveIndex = math.max(1, #self.moveList)
    end
  end
  function Screen:commit()
    local mon = self.mon
    if type(mon) ~= "table" then
      self.status = "NO POKEMON"
      return
    end
    if not self:hasChanges() then
      self.status = "NOTHING TO APPLY"
      return
    end
    local cost = self:pendingCost()
    local save = liveSave()
    if moneyOf(save) < cost then
      self.status = "NOT ENOUGH MONEY"
      return
    end
    local oldMax = mon.stats and statOf(mon.stats, "hp") or nil
    local oldHp = tonumber(mon.hp) or nil
    mon.ivs = mon.ivs or {}
    mon.evs = mon.evs or {}
    for _, key in ipairs(STAT_ORDER) do
      mon.ivs[key] = self.ivs[key]
      mon.evs[key] = self.evs[key]
    end
    local wantNature = nil
    for i, n in ipairs(G3_NATURES) do
      if n == self.nature then wantNature = i - 1 break end
    end
    local parity = nil
    if tonumber(mon.personality) then parity = tonumber(mon.personality) % 2 end
    gen3SetPersonality(mon, wantNature, self.gender, parity)
    if self.abilityIdx ~= self.baseAbilityIdx then
      local P = g3Pokemon()
      local pair = nil
      if P and type(P.abilities) == "function" then
        local ok, res = pcall(P.abilities, mon.species)
        if ok and type(res) == "table" then pair = res end
      end
      local picked = self.abilities[self.abilityIdx]
      local writeVal = picked
      if type(picked) == "table" then writeVal = picked.name or picked.id end
      if pair and pair[self.abilityIdx] ~= nil then
        writeVal = pair[self.abilityIdx]
      end
      mon.ability = writeVal
      mon.abilityId = writeVal
      mon.abilityNum = self.abilityIdx - 1
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
      self.baseIvs[key] = self.ivs[key]
      self.baseEvs[key] = self.evs[key]
    end
    self.baseNature = self.nature
    self.baseGender = self.gender
    self.baseAbilityIdx = self.abilityIdx
    setMoney(save, moneyOf(save) - cost)
    gen3Committed[mon] = true
    self.status = "TRAINING COMPLETE"
  end
  function Screen:learnMove(slot)
    local mon = self.mon
    local name = self.pending and self.pending.name
    if type(mon) ~= "table" or type(name) ~= "string" then
      self.status = "NO MOVE"
      return
    end
    local numId = gen3MoveIdByName(name)
    if not numId then
      self.status = "MOVE NOT IN ROM DATA"
      return
    end
    local save = liveSave()
    if moneyOf(save) < MOVE_COST then
      self.status = "NOT ENOUGH MONEY"
      return
    end
    mon.moves = mon.moves or {}
    local pp = gen3MovePp(numId)
    mon.moves[slot] = { moveId = numId, pp = pp }
    if type(mon.pp) == "table" then mon.pp[slot] = pp end
    if type(mon.maxPp) == "table" then mon.maxPp[slot] = pp end
    setMoney(save, moneyOf(save) - MOVE_COST)
    self.pending = nil
    self.pickingSlot = false
    self.status = "LEARNED " .. string.upper(name)
    self:buildMoveList()
  end
  local BTN_IV = { "+", "-", "0", "31" }
  local BTN_EV = { "0", "252", "+128", "+64", "+32", "+16", "+4" }
  function Screen:buttons()
    if self.page == TAB_EV then return BTN_EV end
    return BTN_IV
  end
  function Screen:applyButton(key)
    local set = self:buttons()
    if self.col > #set then self.col = #set end
    local btn = set[self.col]
    if self.page == TAB_IV then
      if btn == "+" then self.ivs[key] = clamp(self.ivs[key] + 1, 0, 31)
      elseif btn == "-" then self.ivs[key] = clamp(self.ivs[key] - 1, 0, 31)
      elseif btn == "0" then self.ivs[key] = 0
      elseif btn == "31" then self.ivs[key] = 31 end
      return
    end
    local cap = playerEvCap()
    local room = cap - (self:evTotal() - self.evs[key])
    if btn == "0" then
      self.evs[key] = 0
      return
    end
    if btn == "252" then
      self.evs[key] = clamp(math.min(EV_PER_STAT, math.max(0, room)),
        0, EV_PER_STAT)
      return
    end
    local step = tonumber(string.match(btn, "%+(%d+)")) or 0
    if step > 0 then
      if room <= 0 then
        self.status = "EV LIMIT " .. tostring(cap)
        return
      end
      self.evs[key] = clamp(
        math.min(self.evs[key] + step, self.evs[key] + room, EV_PER_STAT),
        0, EV_PER_STAT)
    end
  end
  function Screen:cycleNature(dir)
    local idx = 1
    for i, n in ipairs(G3_NATURES) do
      if n == self.nature then idx = i break end
    end
    idx = ((idx - 1 + dir) % #G3_NATURES) + 1
    self.nature = G3_NATURES[idx]
  end
  function Screen:cycleGender()
    if self.gender == "male" then self.gender = "female"
    elseif self.gender == "female" then self.gender = "male"
    else self.gender = "male" end
  end
  function Screen:cycleAbility(dir)
    if #self.abilities < 2 then
      self.status = "ONE ABILITY"
      return
    end
    self.abilityIdx = ((self.abilityIdx - 1 + dir) % #self.abilities) + 1
  end
  function Screen:updateStats(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    if self.focus == "tabs" then
      if pressed("left") then
        self.page = ((self.page - 2) % 7) + 1
        self.col = 1
      elseif pressed("right") then
        self.page = (self.page % 7) + 1
        self.col = 1
      elseif pressed("down") or pressed("up") then
        self.focus = "apply"
      elseif pressed("a") then
        if self.page == TAB_MOVES then
          self.mode = "moves"
          self.moveIndex = 1
          self:buildMoveList()
        elseif self.page == TAB_HIDDEN then
          self.status = "HIDDEN ABILITY IS A STUB IN THIS PORT"
        elseif self.page == TAB_ABILITY then
          self:cycleAbility(1)
        elseif self.page == TAB_NAT then
          self:cycleNature(1)
        elseif self.page == TAB_GENDER then
          self:cycleGender()
        else
          self.focus = "rows"
        end
      elseif pressed("b") then
        self.game.stack:pop()
      end
      return
    end
    if self.focus == "rows" then
      local key = STAT_ORDER[self.row]
      if pressed("up") then
        self.row = self.row - 1
        if self.row < 1 then self.row = 1 self.focus = "tabs" end
      elseif pressed("down") then
        self.row = self.row + 1
        if self.row > #STAT_ORDER then self.row = #STAT_ORDER self.focus = "apply" end
      elseif pressed("left") then
        self.col = ((self.col - 2) % #self:buttons()) + 1
      elseif pressed("right") then
        self.col = (self.col % #self:buttons()) + 1
      elseif pressed("a") then
        self:applyButton(key)
      elseif pressed("b") then
        self.focus = "tabs"
      end
      return
    end
    if pressed("up") then
      if self.page == TAB_IV or self.page == TAB_EV then
        self.focus = "rows"
        self.row = #STAT_ORDER
      else
        self.focus = "tabs"
      end
    elseif pressed("down") then
      self.focus = "tabs"
    elseif pressed("left") then
      if self.page == TAB_NAT then self:cycleNature(-1)
      elseif self.page == TAB_GENDER then self:cycleGender()
      elseif self.page == TAB_ABILITY then self:cycleAbility(-1)
      elseif self.page == TAB_HIDDEN then
        self.status = "HIDDEN ABILITY IS A STUB IN THIS PORT"
      end
    elseif pressed("right") then
      if self.page == TAB_NAT then self:cycleNature(1)
      elseif self.page == TAB_GENDER then self:cycleGender()
      elseif self.page == TAB_ABILITY then self:cycleAbility(1)
      elseif self.page == TAB_HIDDEN then
        self.status = "HIDDEN ABILITY IS A STUB IN THIS PORT"
      end
    elseif pressed("a") then
      self:commit()
    elseif pressed("b") then
      self.focus = "tabs"
    end
  end
  function Screen:updateMoves(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    if pressed("left") then
      self.category = ((self.category - 2) % 3) + 1
      self.moveIndex = 1
      self:buildMoveList()
      return
    end
    if pressed("right") then
      self.category = (self.category % 3) + 1
      self.moveIndex = 1
      self:buildMoveList()
      return
    end
    if pressed("up") then
      self.moveIndex = math.max(1, self.moveIndex - 1)
      return
    end
    if pressed("down") then
      self.moveIndex = math.min(math.max(1, #self.moveList), self.moveIndex + 1)
      return
    end
    if pressed("a") then
      local name = self.moveList[self.moveIndex]
      if not name then
        self.status = self.moveNote or "NO MOVES"
        return
      end
      self.pending = { kind = "move", name = name }
      return
    end
    if pressed("b") then
      self.mode = "stats"
      self.pending = nil
      self.pickingSlot = false
    end
  end
  function Screen:updateSlotPicker(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    local count = #(self.mon.moves or {})
    if count < 1 then count = 1 end
    if pressed("up") then
      self.slotIndex = math.max(1, self.slotIndex - 1)
    elseif pressed("down") then
      self.slotIndex = math.min(math.max(count, 1), self.slotIndex + 1)
    elseif pressed("a") then
      local cur = self.mon.moves and self.mon.moves[self.slotIndex]
      local curName = slotMoveName(cur)
      if curName and HM_MOVES[curName] then
        self.status = "HM MOVES CANNOT BE FORGOTTEN"
        return
      end
      self:learnMove(self.slotIndex)
    elseif pressed("b") then
      self.pickingSlot = false
      self.pending = nil
    end
  end
  function Screen:updateConfirm(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    if pressed("a") then
      local mon = self.mon
      local full = mon and type(mon.moves) == "table" and #mon.moves >= 4
      if full then
        self.pickingSlot = true
        self.slotIndex = 1
      else
        local slot = mon and type(mon.moves) == "table" and (#mon.moves + 1) or 1
        if slot > 4 then slot = 4 end
        self:learnMove(slot)
      end
    elseif pressed("b") then
      self.pending = nil
    end
  end
  function Screen:update(dt)
    local input = self.game and self.game.input
    if not input then return end
    local ok, err = pcall(function()
      if self.pending then self:updateConfirm(input) return end
      if self.pickingSlot then self:updateSlotPicker(input) return end
      if self.mode == "moves" then self:updateMoves(input)
      else self:updateStats(input) end
    end)
    if not ok then
      self.broken = true
      pcall(mod.log.warn, mod.log, "pokemon-trainer: TRAIN update failed: %s",
        tostring(err))
    end
    self.game.input = nil
  end
  function Screen:drawTabs(focused)
    local x = 5
    for i, label in ipairs(TAB_LABELS) do
      local w = TAB_WIDTHS[i]
      if self.page == i then
        local G = love.graphics
        G.setColor(0.55, 0.70, 0.95, 1)
        G.rectangle("fill", SX(x), SX(19), SX(w), SX(14))
        G.setColor(0, 0, 0, 1)
      end
      local lvl = 1
      if self.page == i then lvl = 2 end
      frame(x, 19, w, 14, lvl)
      tprint(label, x + 3, 21)
      x = x + w + 1
    end
  end
  function Screen:drawTable()
    tprint("STAT", 17, 35)
    tprint("IV", 62, 35)
    tprint("EV", 104, 35)
    tprint("VAL", 152, 35)
    local y = 48
    for i, key in ipairs(STAT_ORDER) do
      local lvl = 1
      if self.focus == "rows" and self.row == i
          and (self.page == TAB_IV or self.page == TAB_EV) then lvl = 2 end
      frame(5, y, 211, 12, lvl)
      if lvl == 2 then cursor(7, y + 3) end
      tprint(STAT_LABEL[key], 17, y + 1)
      tprint(tostring(self.ivs[key]), 62, y + 1)
      tprint(tostring(self.evs[key]), 104, y + 1)
      local v = self:preview(key)
      tprint(v == nil and "---" or tostring(v), 152, y + 1)
      y = y + 13
    end
    return y
  end
  function Screen:drawValueStrip(y)
    if self.page == TAB_IV or self.page == TAB_EV then
      local set = self:buttons()
      local bx = 8
      for i, b in ipairs(set) do
        local lvl = 1
        if self.focus == "rows" and self.col == i then lvl = 2 end
        local bw = 54
        if #set > 4 then bw = 31 end
        frame(bx, y, bw, 13, lvl)
        if #set > 4 then tprint(b, bx + 3, y + 1)
        else tprint(b, bx + 22, y + 1) end
        bx = bx + bw + 1
      end
      return y + 15
    end
    local val = ""
    local note = ""
    if self.page == TAB_NAT then
      val = self.nature or "?"
      local m = NATURE_MOD[self.nature]
      if m then
        note = "+" .. (STAT_LABEL[m.up] or m.up) .. " -"
          .. (STAT_LABEL[m.down] or m.down)
      else
        note = "NEUTRAL"
      end
    elseif self.page == TAB_GENDER then
      val = self.gender == "male" and "M"
        or (self.gender == "female" and "F" or "?")
      note = "A: SWITCH"
    elseif self.page == TAB_ABILITY then
      val = self:abilityName()
      note = "A: SWAP 5000"
    elseif self.page == TAB_HIDDEN then
      val = "STUB"
      note = "NOT IN THIS PORT"
    end
    frame(5, y, 100, 13, 1)
    tprint(val, 10, y + 1)
    tprint(note, 112, y + 1)
    return y + 15
  end
  function Screen:drawCostBand(y)
    local msg = self.status ~= "" and self.status
      or ("COST " .. tostring(self:pendingCost()))
    tprint(msg, 8, y + 1)
    local lvl = 1
    if self.focus == "apply" then lvl = 2 end
    frame(172, y - 1, 63, 14, lvl)
    tprint("APPLY", 184, y + 1)
    return y + 15
  end
  function Screen:drawStatsPage()
    local focused = (self.focus == "tabs")
    self:drawTabs(focused)
    local y = self:drawTable()
    y = self:drawValueStrip(y + 1)
    self:drawCostBand(y)
  end
  function Screen:drawMovesPage()
    frame(5, 3, 230, 15, 1)
    tprint("MOVES " .. MOVE_FIELD_LABELS[self.category], 10, 5)
    tprint("5000", 200, 5)
    local top = 21
    local pitch = 13
    local visible = 9
    if self.moveNote and #self.moveList == 0 then
      tprint(self.moveNote, 12, top + 2)
    end
    local off = 0
    if #self.moveList > visible then
      off = clamp(self.moveIndex - 5, 0, #self.moveList - visible)
    end
    for r = 1, visible do
      local i = off + r
      local name = self.moveList[i]
      if name then
        local col = 0
        local yy = top + (r - 1) * pitch
        if r > 5 then col = 1 yy = top + (r - 6) * pitch end
        local x = 12 + col * 112
        tprint(string.upper(name), x + 9, yy)
        if i == self.moveIndex then cursor(x, yy + 3) end
      end
    end
    tprint("A BUY B BACK", 8, 147)
    if self.status ~= "" then tprint(self.status, 100, 147) end
    if self.pending then
      frame(35, 45, 170, 62, 2)
      tprint("TEACH " .. string.upper(self.pending.name or "?"), 45, 53)
      tprint("FOR 5000?", 45, 67)
      tprint("A YES B NO", 45, 87)
    elseif self.pickingSlot then
      frame(35, 30, 170, 112, 2)
      tprint("FORGET WHICH?", 45, 36)
      local moves = (self.mon and self.mon.moves) or {}
      for i = 1, math.max(#moves, 1) do
        local n = slotMoveName(moves[i]) or "---"
        tprint(n, 55, 36 + i * 13)
        if i == self.slotIndex then cursor(43, 36 + i * 13 + 3) end
      end
      tprint("A OK B CANCEL", 45, 128)
    end
  end
  function Screen:panelSize()
    return STATS_W, STATS_H
  end
  function Screen:draw()
    local ok, err = pcall(function()
      local G = love.graphics
      G.push("all")
      G.setColor(0.96, 0.93, 0.82, 1)
      G.rectangle("fill", 0, 0, STATS_W, STATS_H)
      G.setColor(0, 0, 0, 1)
      drawBorder(STATS_W, STATS_H)
      local mon = self.mon
      local title = gen3SpeciesName(mon) .. " Lv" .. tostring(mon.level or "?")
      frame(5, 3, 230, 14, 1)
      tprint(title, 9, 4)
      if self.mode == "moves" then self:drawMovesPage()
      else self:drawStatsPage() end
      G.pop()
      G.setColor(1, 1, 1, 1)
    end)
    if not ok then
      self.broken = true
      pcall(mod.log.warn, mod.log, "pokemon-trainer: TRAIN draw failed: %s",
        tostring(err))
    end
  end
  if isGen3Boot then
    local okPM, PM = pcall(require, "src.ui.game3.party_menu")
    local okStack, Stack3 = pcall(require, "src.ui.game3.stack")
    if okPM and type(PM) == "table" and okStack and type(Stack3) == "table"
        and type(PM.handleInput) == "function"
        and not PM.__ptTrainWrapped then
      PM.__ptTrainWrapped = true
      local okAudio, Audio = pcall(require, "src.core.game3.audio")
      if not Frlg then
        mod.log:warn("pokemon-trainer: TRAIN not injected -- no gen3 font")
      else
      local screenRef = {}
      local TrainG3 = {}
      TrainG3.open = false
      function TrainG3.isOpen() return TrainG3.open end
      function TrainG3.update(dt)
        local scr = screenRef.current
        if not scr then return end
        scr.game.input = nil
        scr:update(dt)
        if scr.broken then
          screenRef.current = nil
          TrainG3.open = false
          pcall(Stack3.pop, "pttrain")
        end
      end
      function TrainG3.draw()
        local scr = screenRef.current
        if not scr then return end
        local G = love.graphics
        local W, H = 240, 160
        local okD, Display = pcall(require, "src.core.game3.display")
        if okD and type(Display) == "table" then
          W = tonumber(Display.W) or W
          H = tonumber(Display.H) or H
        end
        G.setColor(0.16, 0.35, 0.72, 1)
        G.rectangle("fill", 0, 0, W, H)
        local w, h = scr:panelSize()
        local ox = math.floor((W - w) / 2 + 0.5)
        local oy = math.floor((H - h) / 2 + 0.5)
        G.push("all")
        G.translate(ox, oy)
        scr:draw()
        G.pop()
        G.setColor(1, 1, 1, 1)
      end
      function TrainG3.handleInput(input)
        if not input then return end
        local scr = screenRef.current
        if not scr then
          TrainG3.open = false
          pcall(Stack3.pop, "pttrain")
          return
        end
        scr.game.input = input
        scr:update(0)
        scr.game.input = nil
        if scr.broken then
          screenRef.current = nil
          TrainG3.open = false
          pcall(Stack3.pop, "pttrain")
        end
      end
      function TrainG3.close()
        screenRef.current = nil
        TrainG3.open = false
        pcall(Stack3.pop, "pttrain")
      end
      local CARRIER = "STORE"
      local trainHere = false
      local function carrierPresent()
        if not trainHere then return false end
        local acts = PM.ACTIONS
        if type(acts) ~= "table" then return false end
        for _, a in ipairs(acts) do if a == CARRIER then return true end end
        return false
      end
      do
        local okRT, RomText = pcall(require, "src.core.game3.rom_text")
        if okRT and type(RomText) == "table"
            and type(RomText.at) == "function"
            and not RomText.__ptTrainWrapped then
          RomText.__ptTrainWrapped = true
          local nativeAt = RomText.at
          RomText.at = function(key, idx, ...)
            if carrierPresent() then
              if key == "sCursorOptions" and idx == 14 then
                return "TRAIN"
              end
              local okR, res = pcall(nativeAt, key, idx, ...)
              if not okR or res == nil or res == "" then
                return "TRAIN"
              end
              return res
            end
            return nativeAt(key, idx, ...)
          end
        end
      end
      local emeraldLabelOriginal = nil
      local emeraldLabelPatched = false
      local function setEmeraldTrainLabel(want)
        local okP, Profile = pcall(require, "src.core.game3.profile")
        if not okP then return false end
        local famOk, fam = pcall(Profile.family, PM._session)
        if not (famOk and (fam == "rse" or fam == "emerald")) then return false end
        local okS, Kit = pcall(require, "src.ui.game3.rse.scene_kit")
        if not (okS and type(Kit) == "table"
            and type(Kit.manifest) == "function") then return false end
        local okR, row = pcall(Profile.forSession, PM._session)
        local prow = okR and type(row) == "table" and row.ui
          and row.ui.party or nil
        local sub = type(prow) == "table" and prow.manifest or nil
        if type(sub) ~= "string" then return false end
        local okM, m = pcall(Kit.manifest, sub)
        local labels = okM and type(m) == "table" and m.party
          and m.party.cursorOptions or nil
        if type(labels) ~= "table" then return false end
        if want then
          if not emeraldLabelPatched then
            emeraldLabelOriginal = labels[15]
            emeraldLabelPatched = true
          end
          labels[15] = "TRAIN"
        else
          if emeraldLabelPatched then
            labels[15] = emeraldLabelOriginal
            emeraldLabelPatched = false
          end
        end
        return true
      end
      local function trainAllowedSession()
        local okP, Profile = pcall(require, "src.core.game3.profile")
        if not (okP and type(Profile) == "table"
            and type(Profile.family) == "function") then return true end
        local okF, fam = pcall(Profile.family, PM._session)
        if not okF then return true end
        if fam == nil then return true end
        return fam == "frlg" or fam == "rse" or fam == "emerald"
      end
      local function engineOwnsTrain()
        local f = mod.find and mod.find("g9-battle-engine")
        if not (f and f.options and type(f.options.get) == "function") then
          return false
        end
        local ok, v = pcall(f.options.get, "train_screen")
        if not (ok and v == "true") then return false end
        local okP, Profile = pcall(require, "src.core.game3.profile")
        if okP and type(Profile) == "table"
            and type(Profile.family) == "function" then
          local okF, fam = pcall(Profile.family, PM._session)
          if okF and fam == "frlg" then return true end
        end
        return false
      end
      local function openGen3Train()
        local mon = PM._party and PM._party[PM.cursor]
        if type(mon) ~= "table" or mon.isEgg then return end
        gen3Session = PM._session
        local fakeGame = { data = nil, input = nil, stack = {} }
        fakeGame.stack.pop = function()
          screenRef.current = nil
          TrainG3.open = false
          pcall(Stack3.pop, "pttrain")
        end
        fakeGame.stack.push = function() end
        local ok, scr = pcall(Screen.new, fakeGame, mon)
        if not (ok and scr) then
          mod.log:warn("pokemon-trainer: TRAIN screen failed to open (%s)",
            tostring(scr))
          return
        end
        scr.game.input = { wasPressed = function() return false end,
          isDown = function() return false end }
        local okUp = pcall(scr.update, scr, 0)
        scr.game.input = nil
        if not (okUp and not scr.broken) then
          mod.log:warn("pokemon-trainer: TRAIN screen failed its open "
            .. "self-test, not pushing")
          return
        end
        local okDrawSelf = pcall(scr.draw, scr)
        if not (okDrawSelf and not scr.broken) then
          mod.log:warn("pokemon-trainer: TRAIN screen failed its draw "
            .. "self-test, not pushing")
          return
        end
        screenRef.current = scr
        TrainG3.open = true
        local okPush = pcall(Stack3.push, "pttrain", TrainG3,
          { hideBelow = true, fullscreen = true })
        if not okPush then
          screenRef.current = nil
          TrainG3.open = false
          mod.log:warn("pokemon-trainer: TRAIN screen failed to push")
        end
      end
      local function fieldList(acts)
        if type(acts) ~= "table" then return false end
        local hasSummary, hasCancel = false, false
        for _, a in ipairs(acts) do
          if a == "SUMMARY" then hasSummary = true end
          if a == "CANCEL" then hasCancel = true end
          if a == "SHIFT" or a == "SEND OUT" or a == "ENTER"
              or a == "NO ENTRY" then return false end
        end
        return hasSummary and hasCancel
      end
      local function ensureTrain()
        local acts = PM.ACTIONS
        local function strip()
          if type(acts) == "table" then
            for i = #acts, 1, -1 do
              if acts[i] == CARRIER then table.remove(acts, i) end
            end
            if PM.actionCursor > #acts then
              PM.actionCursor = math.max(1, #acts)
            end
          end
          trainHere = false
          setEmeraldTrainLabel(false)
        end
        if type(acts) ~= "table" then
          trainHere = false
          setEmeraldTrainLabel(false)
          return
        end
        if not trainAllowedSession() then strip() return end
        if engineOwnsTrain() then strip() return end
        if fieldList(acts) then
          if PM._previousMode == "battle_switch" then strip() return end
          local mon = PM._party and PM._party[PM.cursor]
          if type(mon) == "table" and mon.isEgg then strip() return end
          for _, a in ipairs(acts) do
            if a == CARRIER then
              trainHere = true
              setEmeraldTrainLabel(true)
              return
            end
          end
          for i, a in ipairs(acts) do
            if a == "CANCEL" then
              table.insert(acts, i, CARRIER)
              trainHere = true
              setEmeraldTrainLabel(true)
              return
            end
          end
          acts[#acts + 1] = CARRIER
          trainHere = true
          setEmeraldTrainLabel(true)
        else
          strip()
        end
      end
      local nativeHandle = PM.handleInput
      PM.handleInput = function(input)
        if PM.mode == "action" then ensureTrain() end
        if PM.mode == "action" and input
            and type(input.wasPressed) == "function"
            and input:wasPressed("a") then
          local acts = PM.ACTIONS
          if type(acts) == "table" and trainHere
              and acts[PM.actionCursor] == CARRIER then
            if okAudio and Audio and type(Audio.playSe) == "function" then
              pcall(Audio.playSe, "SE_SELECT")
            end
            openGen3Train()
            return
          end
        end
        return nativeHandle(input)
      end
      end
    end
    mod.events:on("battle.started", function()
      local P = g3Pokemon()
      if not (P and type(P.applyStats) == "function") then return end
      for mon in pairs(gen3Committed) do
        if type(mon) == "table" and not mon.isEgg then
          pcall(P.applyStats, mon)
        end
      end
    end)
  end
  mod.log:info("pokemon-trainer: TRAIN party screen installed (Gen %d)", gen)
end
