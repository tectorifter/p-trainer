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
  local MOVE_FIELD_LABELS = { "RELEARN", "TM", "EGG", "TUTOR" }
  local MOVE_COST = 5000
  local IV_COST = 200
  local EV_COST = 125
  local NATURE_COST = 2000
  local ABILITY_COST = 5000
  local EV_PER_STAT = 252
  local TAB_IV, TAB_EV, TAB_NAT, TAB_GENDER = 1, 2, 3, 4
  local TAB_MOVES, TAB_ABILITY, TAB_HIDDEN = 5, 6, 7
  local TAB_LABELS = { "IV", "EV", "NAT", "M/F", "MOVES", "ABIL", "HID" }
  local TAB_WIDTHS = { 22, 22, 30, 30, 42, 36, 26 }
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
    if type(move) == "number" then
      local name = gen3MoveName(move)
      if name then return string.upper(name) end
      return nil
    end
    if type(move) ~= "table" then return nil end
    if type(move.id) == "string" and move.id ~= "" then
      return string.upper(move.id)
    end
    local num = tonumber(move.moveId or move.move or move.id)
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
  local BASESTAT_FNS = { "baseStats", "stats", "base" }
  local baseRecCache = {}
  local function nativeBaseRec(species)
    if species == nil then return nil end
    local hit = baseRecCache[species]
    if hit ~= nil then return hit ~= false and hit or nil end
    local P = g3Pokemon()
    if P then
      for _, fname in ipairs(BASESTAT_FNS) do
        if type(P[fname]) == "function" then
          local ok, rec = pcall(P[fname], species)
          if ok and type(rec) == "table" then
            local good = true
            for _, key in ipairs(STAT_ORDER) do
              local v = statOf(rec, key)
              if not (tonumber(v) and tonumber(v) > 0) then good = false break end
            end
            if good then
              baseRecCache[species] = rec
              return rec
            end
          end
        end
      end
    end
    baseRecCache[species] = false
    return nil
  end
  local function nativeBaseStat(species, key)
    return statOf(nativeBaseRec(species), key)
  end
  local poolCache = {}
  local function moveLearnMod()
    local ok, ML = pcall(require, "src.core.game3.move_learn")
    if ok and type(ML) == "table" then return ML end
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
  local function pushMoveId(out, seen, moveId, level)
    local id = tonumber(moveId)
    if not id or id < 1 or seen[id] then return end
    local name = gen3MoveName(id)
    if not name or name == "" then return end
    seen[id] = true
    out[#out + 1] = { id = id, name = name, level = tonumber(level) }
  end
  local function nativeMovePools(mon)
    local empty = { relearn = {}, tm = {}, egg = {}, tutor = {} }
    local P = g3Pokemon()
    if not P then return empty end
    local sp = speciesNum(mon)
    if not sp then return empty end
    local level = 100
    if type(mon) == "table" then level = tonumber(mon.level) or 100 end
    local key = sp .. ":" .. level
    local hit = poolCache[key]
    if hit then return hit end
    local pools = { relearn = {}, tm = {}, egg = {}, tutor = {} }
    local seenR, seenT, seenE, seenU = {}, {}, {}, {}
    local ML = moveLearnMod()
    if ML and type(ML.relearnableMoves) == "function" and type(mon) == "table" then
      local ok, ids = pcall(ML.relearnableMoves, mon)
      if ok and type(ids) == "table" then
        for _, id in ipairs(ids) do pushMoveId(pools.relearn, seenR, id, nil) end
      end
    end
    if #pools.relearn == 0 and type(P.learnset) == "function" then
      local ok, set = pcall(P.learnset, sp)
      if ok and type(set) == "table" then
        for _, e in ipairs(set) do
          local lv, mv
          if type(e) == "table" then
            lv = tonumber(e[1] or e.level)
            mv = tonumber(e[2] or e.move)
          else
            mv = tonumber(e)
          end
          if mv and (lv == nil or lv <= level) then
            pushMoveId(pools.relearn, seenR, mv, lv)
          end
        end
      end
    end
    if type(P.canLearnTmIndex) == "function" and type(P.moveFromTmItem) == "function" then
      for idx = 0, 57 do
        local okC, can = pcall(P.canLearnTmIndex, sp, idx)
        if okC and can then
          local okM, mid = pcall(P.moveFromTmItem, 289 + idx)
          if okM and tonumber(mid) then
            local isHm = false
            if type(P.isHmMove) == "function" then
              local okH, h = pcall(P.isHmMove, tonumber(mid))
              isHm = okH and h == true
            end
            if not isHm then pushMoveId(pools.tm, seenT, tonumber(mid), nil) end
          end
        end
      end
    end
    if type(P.eggMoves) == "function" then
      local ok, list = pcall(P.eggMoves, sp)
      if ok and type(list) == "table" then
        for _, id in ipairs(list) do pushMoveId(pools.egg, seenE, id, nil) end
      end
    end
    if ML and type(ML.tutorMoveCount) == "function"
        and type(ML.canLearnTutorMove) == "function"
        and type(ML.tutorMove) == "function" then
      local okN, n = pcall(ML.tutorMoveCount)
      n = (okN and tonumber(n)) or 0
      for tut = 0, n - 1 do
        local okC, can = pcall(ML.canLearnTutorMove, sp, tut)
        if okC and can then
          local okM, mid = pcall(ML.tutorMove, tut)
          if okM and tonumber(mid) then pushMoveId(pools.tutor, seenU, tonumber(mid), nil) end
        end
      end
    end
    poolCache[key] = pools
    return pools
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
  local FrlgWhite = nil
  if isGen3Boot then
    local okF, found = pcall(require, "src.ui.game3.frlg_font")
    if okF and type(found) == "table" and type(found.draw) == "function" then
      Frlg = found
      if type(found.COLOR) == "table" then
        FrlgNormal = found.COLOR.NORMAL
        FrlgWhite = found.COLOR.WHITE
      end
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
  local function wprint(text, x, y)
    if Frlg and FrlgWhite then
      local okD, drawn = pcall(Frlg.draw, tostring(text or ""),
        SX(x), SX(y), { colors = FrlgWhite, small = true })
      if okD and (tonumber(drawn) or 0) > 0 then return true end
    end
    tprint(text, x, y)
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
  local C_SAGE_A = { 0.66, 0.71, 0.47 }
  local textH = 10
  do
    if Frlg and type(Frlg.face) == "function" then
      local okF, face = pcall(Frlg.face, { small = true })
      if okF and type(face) == "table" and tonumber(face.height) then
        textH = tonumber(face.height)
      end
    end
  end
  local function cy(y, h)
    return math.floor(y + (h - textH) / 2 + 0.5)
  end
  local function textW(s)
    s = tostring(s or "")
    if Frlg and type(Frlg.measure) == "function" then
      local okM, w = pcall(Frlg.measure, s, { small = true })
      if okM and tonumber(w) then return tonumber(w) end
    end
    return #s * 6
  end
  local function cx(x, w, s)
    return math.floor(x + (w - textW(s)) / 2 + 0.5)
  end
  local C_SAGE_B = { 0.64, 0.69, 0.45 }
  local C_MAGENTA = { 0.62, 0.27, 0.62 }
  local C_MAGENTA_DK = { 0.42, 0.17, 0.42 }
  local C_CREAM = { 0.97, 0.94, 0.83 }
  local C_STATLBL = { 0.78, 0.85, 0.58 }
  local C_HDRBLUE = { 0.15, 0.44, 0.66 }
  local C_ORANGE = { 0.90, 0.42, 0.11 }
  local C_NAVY = { 0.12, 0.15, 0.26 }
  local C_PANELBLUE = { 0.10, 0.22, 0.55 }
  local C_WHITE = { 1, 1, 1 }
  local function rrClamp(w, h, r)
    r = tonumber(r) or 3
    if r < 0 then r = 0 end
    local m = math.floor(math.min(SX(w), SX(h)) / 2)
    if r > m then r = m end
    return r
  end
  local function fillR(x, y, w, h, c, r)
    local G = love.graphics
    G.setColor(c[1], c[2], c[3], 1)
    G.rectangle("fill", SX(x), SX(y), SX(w), SX(h), rrClamp(w, h, r))
    G.setColor(0, 0, 0, 1)
  end
  local function boxR(x, y, w, h, fc, lc, r)
    fillR(x, y, w, h, fc, r)
    local G = love.graphics
    G.setColor(lc[1], lc[2], lc[3], 1)
    G.rectangle("line", SX(x) + 0.5, SX(y) + 0.5, SX(w), SX(h),
      rrClamp(w, h, r))
    G.setColor(0, 0, 0, 1)
  end
  local function selectBox(x, y, w, h, fc)
    fillR(x, y, w, h, fc, 3)
    local G = love.graphics
    G.setColor(C_ORANGE[1], C_ORANGE[2], C_ORANGE[3], 1)
    G.rectangle("line", SX(x) - 0.5, SX(y) - 0.5, SX(w) + 1, SX(h) + 1, 4)
    G.rectangle("line", SX(x) + 0.5, SX(y) + 0.5, SX(w) - 1, SX(h) - 1, 2)
    G.setColor(0, 0, 0, 1)
  end
  local function stripeBg(w, h)
    local G = love.graphics
    G.setColor(C_SAGE_A[1], C_SAGE_A[2], C_SAGE_A[3], 1)
    G.rectangle("fill", 0, 0, w, h)
    local yy = 0
    local flip = false
    while yy < h do
      if flip then
        G.setColor(C_SAGE_B[1], C_SAGE_B[2], C_SAGE_B[3], 1)
        G.rectangle("fill", 0, yy, w, 8)
      end
      yy = yy + 8
      flip = not flip
    end
    G.setColor(0, 0, 0, 1)
  end
  local function pageDots(n, cur, y)
    local dx = 233 - n * 10
    for i = 1, n do
      if i == cur then fillR(dx, y, 6, 6, C_WHITE, 2)
      else fillR(dx, y, 6, 6, C_MAGENTA_DK, 2) end
      dx = dx + 10
    end
  end
  local Screen = {}
  Screen.__index = Screen
  function Screen.new(game, mon)
    local self = setmetatable({
      game = game, mon = mon,
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
    local base = nativeBaseStat(mon and mon.species, key)
    if base then
      return gen3Stat(base, self.ivs[key] or 0, self.evs[key] or 0,
        level, self.nature, key, key == "hp")
    end
    return statOf(mon.stats, key)
  end
  function Screen:buildMoveList()
    self.moveList = {}
    self.moveNote = nil
    local mon = self.mon
    local P = g3Pokemon()
    local known = {}
    if mon and type(mon.moves) == "table" then
      for i = 1, 4 do
        local id = nil
        if P and type(P.moveIdAt) == "function" then
          local ok, v = pcall(P.moveIdAt, mon, i)
          if ok then id = tonumber(v) end
        else
          local m = mon.moves[i]
          if type(m) == "number" then id = m
          elseif type(m) == "table" then id = tonumber(m.id or m.move or m.moveId) end
        end
        if id and id > 0 then known[id] = true end
      end
    end
    local level = tonumber(mon and mon.level) or 5
    local cats = { "relearn", "tm", "egg", "tutor" }
    local pools = nativeMovePools(mon)
    local want = pools[cats[self.category] or "relearn"] or {}
    for _, e in ipairs(want) do
      if e.level == nil or e.level <= level then
        if not known[e.id] then
          known[e.id] = true
          self.moveList[#self.moveList + 1] = e
        end
      end
    end
    table.sort(self.moveList, function(a, b) return a.name < b.name end)
    if #self.moveList == 0 then self.moveNote = "NO MOVE DATA" end
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
      local picked = self.abilities[self.abilityIdx]
      if picked == nil or tonumber(picked) == 0 then
        self.abilityIdx = self.baseAbilityIdx
      end
    end
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
  function Screen:moveCost()
    if self.category == 1 then return 0 end
    return MOVE_COST
  end
  function Screen:learnMove(slot)
    local mon = self.mon
    local moveId = tonumber(self.pending and self.pending.id)
    if type(mon) ~= "table" or not moveId then
      self.status = "NO MOVE"
      return
    end
    local name = self.pending.name or gen3MoveName(moveId) or ("MOVE " .. moveId)
    if not gen3MoveName(moveId) then
      self.status = "MOVE NOT IN ROM DATA"
      return
    end
    local save = liveSave()
    local teachCost = self:moveCost()
    if moneyOf(save) < teachCost then
      self.status = "NOT ENOUGH MONEY"
      return
    end
    mon.moves = mon.moves or {}
    local pp = gen3MovePp(moveId)
    mon.moves[slot] = moveId
    if type(mon.pp) ~= "table" then mon.pp = {} end
    if type(mon.maxPp) ~= "table" then mon.maxPp = {} end
    mon.pp[slot] = pp
    mon.maxPp[slot] = pp
    setMoney(save, moneyOf(save) - teachCost)
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
    local cur = self.abilities[self.abilityIdx]
    if cur == nil or tonumber(cur) == 0 then
      self.status = "NO SECONDARY ABILITY"
      self.abilityWarnT = 1.0
    elseif self.status == "NO SECONDARY ABILITY" then
      self.status = ""
      self.abilityWarnT = nil
    end
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
      self.focus = "tabs"
    elseif pressed("down") then
      self.focus = "tabs"
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
      self.category = ((self.category - 2) % 4) + 1
      self.moveIndex = 1
      self:buildMoveList()
      return
    end
    if pressed("right") then
      self.category = (self.category % 4) + 1
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
      local e = self.moveList[self.moveIndex]
      if not e then
        self.status = self.moveNote or "NO MOVES"
        return
      end
      self.pending = { kind = "move", id = e.id, name = e.name }
      return
    end
    if pressed("b") then
      self.mode = "stats"
      self.pending = nil
      self.pickingSlot = false
    end
  end
  function Screen:moveSlotCount()
    local mon = self.mon
    local P = g3Pokemon()
    local n = 0
    for i = 1, 4 do
      local id = nil
      if P and type(P.moveIdAt) == "function" then
        local ok, v = pcall(P.moveIdAt, mon, i)
        if ok then id = tonumber(v) end
      elseif mon and type(mon.moves) == "table" then
        local m = mon.moves[i]
        if type(m) == "number" then id = m
        elseif type(m) == "table" then
          id = tonumber(m.id or m.move or m.moveId)
        end
      end
      if id and id > 0 then n = n + 1 end
    end
    return n
  end
  function Screen:updateSlotPicker(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    local count = self:moveSlotCount()
    if count < 1 then count = 1 end
    if pressed("up") then
      self.slotIndex = math.max(1, self.slotIndex - 1)
    elseif pressed("down") then
      self.slotIndex = math.min(math.max(count, 1), self.slotIndex + 1)
    elseif pressed("a") then
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
      local n = self:moveSlotCount()
      if n >= 4 then
        self.pickingSlot = true
        self.slotIndex = 1
      else
        local slot = math.min(math.max(n + 1, 1), 4)
        self:learnMove(slot)
      end
    elseif pressed("b") then
      self.pending = nil
      self.pickingSlot = false
    end
  end
  function Screen:update(dt)
    local input = self.game and self.game.input
    if not input then return end
    local ok, err = pcall(function()
      if self.pickingSlot then self:updateSlotPicker(input) return end
      if self.pending then self:updateConfirm(input) return end
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
    local total = 0
    for i, w in ipairs(TAB_WIDTHS) do total = total + w end
    total = total + (#TAB_WIDTHS - 1)
    local x = 5 + math.floor((230 - total) / 2 + 0.5)
    for i, label in ipairs(TAB_LABELS) do
      local w = TAB_WIDTHS[i]
      if self.page == i and self.focus ~= "apply" then
        selectBox(x, 18, w, 14, C_CREAM)
      else
        boxR(x, 18, w, 14, C_CREAM, C_NAVY)
      end
      tprint(label, cx(x, w, label), cy(18, 14) - 1)
      x = x + w + 1
    end
  end
  function Screen:drawTable()
    local TX = 14
    fillR(TX, 34, 211, 13, C_HDRBLUE)
    wprint("STATS", TX + 12, cy(34, 13) - 2)
    wprint("IV", TX + 57, cy(34, 13) - 2)
    wprint("EV", TX + 99, cy(34, 13) - 2)
    wprint("VALUE", TX + 147, cy(34, 13) - 2)
    local topY = 48
    local blockH = #STAT_ORDER * 13
    fillR(TX, topY, 211, blockH, C_CREAM, 3)
    fillR(TX, topY, 52, blockH, C_STATLBL, 3)
    fillR(TX + 52, topY, 1, blockH, C_NAVY)
    fillR(TX + 94, topY, 1, blockH, C_NAVY)
    fillR(TX + 136, topY, 1, blockH, C_NAVY)
    for k = 1, #STAT_ORDER - 1 do
      fillR(TX, topY + k * 13, 211, 1, C_NAVY)
    end
    do
      local G = love.graphics
      G.setColor(C_NAVY[1], C_NAVY[2], C_NAVY[3], 1)
      G.rectangle("line", SX(TX) + 0.5, SX(topY) + 0.5,
        SX(211), SX(blockH), rrClamp(211, blockH, 3))
      G.setColor(0, 0, 0, 1)
    end
    local y = topY
    for i, key in ipairs(STAT_ORDER) do
      local selRow = self.focus == "rows" and self.row == i
        and (self.page == TAB_IV or self.page == TAB_EV)
      if selRow then
        selectBox(TX, y, 211, 12, C_CREAM)
        fillR(TX, y, 52, 12, C_STATLBL, 3)
        fillR(TX + 52, y, 1, 12, C_NAVY)
        fillR(TX + 94, y, 1, 12, C_NAVY)
        fillR(TX + 136, y, 1, 12, C_NAVY)
        cursor(TX + 2, y + 3)
      end
      local ty = cy(y, 12)
      tprint(STAT_LABEL[key], TX + 12, ty)
      tprint(tostring(self.ivs[key]), TX + 57, ty)
      tprint(tostring(self.evs[key]), TX + 99, ty)
      local v = self:preview(key)
      tprint(v == nil and "---" or tostring(v), TX + 147, ty)
      y = y + 13
    end
    return y
  end
  function Screen:drawValueStrip(y)
    if self.page == TAB_IV or self.page == TAB_EV then
      local set = self:buttons()
      local bx = 8
      for i, b in ipairs(set) do
        local selB = self.focus == "rows" and self.col == i
        local bw = 54
        if #set > 4 then bw = 31 end
        if selB then selectBox(bx, y, bw, 13, C_CREAM)
        else boxR(bx, y, bw, 13, C_CREAM, C_NAVY) end
        tprint(b, cx(bx, bw, b), y - 1)
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
      note = "Future Scope"
    end
    boxR(70, y, 100, 13, C_CREAM, C_NAVY)
    tprint(val, cx(70, 100, val), y - 1)
    tprint(note, 177, y - 1)
    return y + 15
  end
  function Screen:drawCostBand(y)
    local msg = self.status ~= "" and self.status
      or ("COST " .. tostring(self:pendingCost()))
    boxR(5, y - 1, 160, 14, C_WHITE, C_NAVY)
    tprint(msg, 8, cy(y - 1, 14) - 1)
    if self.focus == "apply" then
      selectBox(172, y - 1, 63, 14, C_CREAM)
    else
      boxR(172, y - 1, 63, 14, C_CREAM, C_ORANGE)
    end
    tprint("APPLY", cx(172, 63, "APPLY"), cy(y - 1, 14) - 1)
    return y + 15
  end
  function Screen:drawStatsPage()
    local focused = (self.focus == "tabs")
    self:drawTabs(focused)
    local y = self:drawTable()
    y = self:drawValueStrip(y + 1)
    self:drawCostBand(y)
  end
  local moveInfoCache = {}
  local TYPE_ID_BY_NAME = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4,
    ROCK = 5, BUG = 6, GHOST = 7, STEEL = 8, MYSTERY = 9,
    FIRE = 10, WATER = 11, GRASS = 12, ELECTRIC = 13, PSYCHIC = 14,
    ICE = 15, DRAGON = 16, DARK = 17,
  }
  local GEN3_PHYSICAL = {
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [8] = true,
  }
  local splitClassCache = nil
  local function splitClass(moveNum)
    if splitClassCache == nil then
      splitClassCache = false
      local ok, body = pcall(mod.read, mod, "battle/damage_split_data.lua")
      if ok and type(body) == "string" then
        local okC, chunk = pcall(loadstring, body, "@damage_split_data.lua")
        if okC and type(chunk) == "function" then
          local okR, data = pcall(chunk)
          if okR and type(data) == "table" then splitClassCache = data end
        end
      end
    end
    if type(splitClassCache) == "table" then return splitClassCache[moveNum] end
    return nil
  end
  local function splitOn()
    local ok, v = pcall(function() return mod.options:get("damage_split") end)
    return ok and v == true
  end
  local DAMAGING_FX = {
    OHKO = true, SONICBOOM = true, LOW_KICK = true, COUNTER = true,
    LEVEL_DAMAGE = true, DRAGON_RAGE = true, BIDE = true, PSYWAVE = true,
    SUPER_FANG = true, FLAIL = true, RETURN = true, PRESENT = true,
    FRUSTRATION = true, MAGNITUDE = true, HIDDEN_POWER = true,
    MIRROR_COAT = true, ENDEAVOR = true,
  }
  local FIXED_SPECIAL = {
    [101] = true, [82] = true, [243] = true, [149] = true,
    [49] = true, [237] = true,
  }
  local FIXED_PHYSICAL_IDS = {
    [12] = true, [32] = true, [67] = true, [68] = true,
    [69] = true, [90] = true, [117] = true, [162] = true,
    [175] = true, [179] = true, [216] = true, [217] = true,
    [218] = true, [222] = true, [283] = true, [329] = true,
  }
  local function moveInfo(moveId, moveName)
    moveId = tonumber(moveId)
    if not moveId then return nil end
    local cacheKey = moveId .. (splitOn() and ":s" or ":v")
    local hit = moveInfoCache[cacheKey]
    if hit ~= nil then return hit ~= false and hit or nil end
    local info = { power = "---", accuracy = "---", pp = "---",
      typeId = 0, category = "status", desc = nil }
    local P = g3Pokemon()
    if P and type(P.battleMove) == "function" then
      local ok, row = pcall(P.battleMove, moveId)
      if ok and type(row) == "table" then
        local power = tonumber(row.power) or 0
        local acc = tonumber(row.accuracy) or 0
        info.power = power >= 2 and tostring(power) or "---"
        info.accuracy = acc > 0 and tostring(acc) or "---"
        info.pp = tostring(tonumber(row.pp) or "---")
        local tid = tonumber(row.type)
        if tid == nil and row.type ~= nil then
          tid = TYPE_ID_BY_NAME[tostring(row.type):upper()]
        end
        info.typeId = tid or 0
        local fx = type(row.effect) == "string"
          and string.upper(row.effect) or nil
        local damaging = power >= 2 or (fx and DAMAGING_FX[fx])
          or FIXED_PHYSICAL_IDS[moveId] or FIXED_SPECIAL[moveId]
        if damaging then
          local cls = splitOn() and splitClass(moveId) or nil
          if cls ~= "physical" and cls ~= "special" then cls = nil end
          if not cls and splitOn() and FIXED_SPECIAL[moveId] then
            cls = "special"
          end
          if cls then
            info.category = cls
          else
            info.category = GEN3_PHYSICAL[info.typeId] and "physical" or "special"
          end
        end
      end
    end
    do
      local okS, SummaryData = pcall(require, "src.core.game3.summary_data")
      if okS and type(SummaryData) == "table"
          and type(SummaryData.moveDescription) == "function" then
        local descName = moveName or gen3MoveName(moveId) or ""
        local okD, desc = pcall(SummaryData.moveDescription, moveId, descName)
        if okD and type(desc) == "string" and desc ~= "" then
          info.desc = desc
        end
      end
    end
    moveInfoCache[cacheKey] = info
    return info
  end
  local TYPE_EN = {
    "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND",
    "ROCK", "BUG", "GHOST", "STEEL", "MYSTERY",
    "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC",
    "ICE", "DRAGON", "DARK",
  }
  local TYPE_COLORS = {
    [0] = { 0.66, 0.66, 0.47 }, [1] = { 0.75, 0.19, 0.16 },
    [2] = { 0.66, 0.56, 0.94 }, [3] = { 0.63, 0.25, 0.63 },
    [4] = { 0.88, 0.75, 0.41 }, [5] = { 0.72, 0.63, 0.22 },
    [6] = { 0.66, 0.72, 0.13 }, [7] = { 0.44, 0.35, 0.60 },
    [8] = { 0.72, 0.72, 0.82 }, [9] = { 0.41, 0.63, 0.56 },
    [10] = { 0.94, 0.50, 0.19 }, [11] = { 0.41, 0.56, 0.94 },
    [12] = { 0.47, 0.78, 0.31 }, [13] = { 0.97, 0.82, 0.19 },
    [14] = { 0.97, 0.35, 0.53 }, [15] = { 0.60, 0.85, 0.85 },
    [16] = { 0.44, 0.22, 0.97 }, [17] = { 0.44, 0.35, 0.28 },
  }
  local function typeName(tid)
    tid = tonumber(tid) or 0
    local okR, RomText = pcall(require, "src.core.game3.rom_text")
    if okR and RomText and type(RomText.at) == "function" then
      local okN, n = pcall(RomText.at, "gTypeNames", tid)
      if okN and type(n) == "string" and n ~= "" then return n end
    end
    return TYPE_EN[tid + 1] or "NORMAL"
  end
  local function drawTypeLabel(name, tid, x, y)
    local G = love and love.graphics
    local text = tostring(name or "NORMAL"):upper()
    local tw = math.ceil(textW(text)) + 8
    if tw < 32 then tw = 32 end
    local bg = TYPE_COLORS[tonumber(tid) or 0] or TYPE_COLORS[0]
    G.setColor(bg[1], bg[2], bg[3], 1)
    G.rectangle("fill", x, y, tw, 12, 3)
    G.setColor(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1)
    G.rectangle("line", x + 0.5, y + 0.5, tw - 1, 11, 3)
    wprint(text, cx(x, tw, text), cy(y, 12) - 2)
    G.setColor(0, 0, 0, 1)
    return tw
  end
  local function drawSplitBadge(cat, x, y)
    local G = love and love.graphics
    if not G then return end
    local w, h = 32, 12
    local bg = cat == "physical" and { 0.94, 0.42, 0.20 }
      or cat == "special" and { 0.35, 0.50, 0.90 }
      or { 0.62, 0.62, 0.45 }
    G.setColor(bg[1], bg[2], bg[3], 1)
    G.rectangle("fill", x, y, w, h, 3)
    G.setColor(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3)
    local cx, cy = x + w / 2, y + h / 2
    G.setColor(1, 1, 1, 1)
    if cat == "physical" then
      local r = 4
      G.setLineWidth(2)
      for k = 0, 2 do
        local a = k * math.pi / 3
        G.line(cx - math.cos(a) * r, cy - math.sin(a) * r,
          cx + math.cos(a) * r, cy + math.sin(a) * r)
      end
      G.setLineWidth(1)
    elseif cat == "special" then
      G.circle("line", cx, cy, 4.5)
      G.circle("line", cx, cy, 2.8)
      G.circle("fill", cx, cy, 1.2)
    else
      G.circle("line", cx, cy, 4.2)
      G.circle("fill", cx + 1.5, cy, 1.6)
    end
    G.setColor(0, 0, 0, 1)
  end
  local function drawTypeRow(info, x, y)
    local G = love and love.graphics
    if not info or not G then
      tprint("TYPE " .. (info and tostring(info.typeId) or "---"), x, y)
      return
    end
    local tid = tonumber(info.typeId) or 0
    local labelW = 26
    if Frlg and type(Frlg.measure) == "function" then
      local okM, w = pcall(Frlg.measure, "TYPE ", { small = true })
      if okM and tonumber(w) then labelW = math.ceil(tonumber(w)) end
    end
    tprint("TYPE ", x, cy(SX(y - 1), 12))
    local bx, by = SX(x + labelW), SX(y - 1)
    local typeW = 32
    local drewNative = false
    local okS, Chrome = pcall(require, "src.ui.game3.summary_chrome")
    if okS and Chrome and type(Chrome.drawTypeBadge) == "function" then
      local okI, img = pcall(Chrome.menuInfoImage)
      if okI and img ~= nil then
        drewNative = pcall(Chrome.drawTypeBadge, tid, bx, by) and true or false
      end
    end
    if not drewNative then
      typeW = drawTypeLabel(typeName(tid), tid, bx, by)
    end
    drawSplitBadge(info.category, bx + typeW + 4, by)
  end
  local function drawWrapped(text, x, y, maxChars, maxRows)
    local rows = 0
    local words = {} 
    for w in string.gmatch(tostring(text or ""), "%S+") do
      words[#words + 1] = w
    end
    local line = ""
    local function flush()
      if line ~= "" and rows < maxRows then
        tprint(line, x, y + rows * 10)
        rows = rows + 1
      end
      line = ""
    end
    for _, w in ipairs(words) do
      local trial = line == "" and w or (line .. " " .. w)
      if #trial > maxChars then
        flush()
        line = w
      else
        line = trial
      end
    end
    flush()
    return rows
  end
  function Screen:drawMovesPage()
    local mon = self.mon
    local title = gen3SpeciesName(mon) .. " Lv" .. tostring(mon.level or "?")
    fillR(5, 3, 230, 14, C_MAGENTA, 3)
    wprint(title .. " " .. MOVE_FIELD_LABELS[self.category], 9, 2)
    pageDots(#MOVE_FIELD_LABELS, self.category, 7)
    local top = 19
    local pitch = 13
    local visible = 9
    local listW = 118
    local infoX = 128
    boxR(5, top, listW, 122, C_CREAM, C_PANELBLUE)
    if self.moveNote and #self.moveList == 0 then
      tprint(self.moveNote, 12, top + 2)
    end
    local off = 0
    if #self.moveList > visible then
      off = clamp(self.moveIndex - 5, 0, #self.moveList - visible)
    end
    for r = 1, visible do
      local i = off + r
      local entry = self.moveList[i]
      local name = entry and entry.name
      if name then
        local yy = top + (r - 1) * pitch
        tprint(string.upper(name), 21, yy)
        if i == self.moveIndex then cursor(12, yy + 3) end
      end
    end
    do
      local sel = self.moveList[self.moveIndex]
      boxR(infoX, top, 107, 122, C_CREAM, C_PANELBLUE)
      if sel then
        local info = moveInfo(sel.id, sel.name)
        fillR(infoX + 3, top + 2, 101, 12, C_MAGENTA)
        wprint(string.upper(sel.name or "?"), infoX + 6, cy(top + 2, 12) - 2)
        drawTypeRow(info, infoX + 5, top + 16)
        tprint("POW " .. (info and info.power or "---"), infoX + 5, top + 28)
        tprint("ACC " .. (info and info.accuracy or "---"), infoX + 5, top + 40)
        tprint("PP " .. (info and info.pp or "---"), infoX + 5, top + 52)
        if info and info.desc then
          boxR(infoX + 4, top + 64, 99, 54, C_WHITE, C_NAVY)
          drawWrapped(info.desc, infoX + 7, top + 66, 15, 5)
        end
      else
        tprint("NO MOVE", infoX + 5, top + 2)
      end
    end
    boxR(5, 142, 230, 13, C_WHITE, C_NAVY, 3)
    tprint("A LEARN B BACK", 8, cy(142, 13))
    do
      local cost = self:moveCost()
      tprint(cost > 0 and tostring(cost) or "FREE", 200, cy(142, 13))
    end
    if self.status ~= "" then tprint(self.status, 100, cy(142, 13)) end
    if self.pickingSlot then
      boxR(35, 30, 170, 112, C_CREAM, C_NAVY, 4)
      tprint("FORGET WHICH?", 45, 36)
      local moves = (self.mon and self.mon.moves) or {}
      for i = 1, math.max(#moves, 1) do
        local n = slotMoveName(moves[i]) or "---"
        tprint(n, 55, 36 + i * 13)
        if i == self.slotIndex then cursor(43, 36 + i * 13 + 3) end
      end
      tprint("A OK B CANCEL", 45, 128)
    elseif self.pending then
      boxR(35, 45, 170, 62, C_CREAM, C_NAVY, 4)
      tprint("TEACH " .. string.upper(self.pending.name or "?"), 45, 53)
      local dialogCost = self:moveCost()
      tprint(dialogCost > 0 and ("FOR " .. tostring(dialogCost) .. "?") or "FOR FREE?", 45, 67)
      tprint("A YES B NO", 45, 87)
    end
  end
  function Screen:panelSize()
    return STATS_W, STATS_H
  end
  function Screen:draw()
    local ok, err = pcall(function()
      local G = love.graphics
      G.push("all")
      local okInner, errInner = pcall(function()
        stripeBg(STATS_W, STATS_H)
        drawBorder(STATS_W, STATS_H)
        local function part(name, fn)
          local okP, errP = pcall(fn)
          if not okP then
            pcall(mod.log.warn, mod.log,
              "pokemon-trainer: TRAIN draw section '%s' failed: %s",
              tostring(name), tostring(errP))
          end
        end
        if self.mode == "moves" then
          part("moves", function() self:drawMovesPage() end)
        else
          part("title", function()
            local mon = self.mon
            local title = gen3SpeciesName(mon) .. " Lv"
              .. tostring(mon.level or "?")
            fillR(5, 3, 230, 14, C_MAGENTA, 3)
            wprint(title, 9, 2)
          end)
          part("tabs", function() self:drawTabs(self.focus == "tabs") end)
          part("table", function() self:drawTable() end)
          part("values", function()
            local y = 48 + #STAT_ORDER * 13 + 1
            y = self:drawValueStrip(y)
            self:drawCostBand(y)
          end)
        end
      end)
      G.pop()
      G.setColor(1, 1, 1, 1)
      if not okInner then error(errInner, 0) end
    end)
    if not ok then
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
        if scr.abilityWarnT and scr.abilityWarnT > 0 then
          local step = tonumber(dt) or 0
          if step <= 0 then step = 1 / 60 end
          scr.abilityWarnT = scr.abilityWarnT - step
          if scr.abilityWarnT <= 0 then
            scr.abilityWarnT = nil
            scr.abilityIdx = 1
            if scr.status == "NO SECONDARY ABILITY" then scr.status = "" end
          end
        end
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
