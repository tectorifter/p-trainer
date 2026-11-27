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
  local MOVE_FIELD_LABELS = { "RELEARN", "TM", "EGG", "TUTOR" }
  local MOVE_COST = 5000
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
  local function gen3MoveName(numId)
    local P = g3Pokemon()
    if P and type(P.moveName) == "function" then
      local ok, name = pcall(P.moveName, tonumber(numId))
      if ok and type(name) == "string" and name ~= "" then return name end
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
  local prevosCache = nil
  local function prevosOf(P, species)
    if prevosCache == nil then
      prevosCache = {}
      if type(P.evolutions) == "function"
          and type(P.name) == "function" then
        local blank = 0
        local id = 1
        while blank < 64 and id <= 65536 do
          local okN, nm = pcall(P.name, id)
          if okN and type(nm) == "string" and nm ~= ""
              and nm ~= "??????????" then
            blank = 0
            local okE, rows = pcall(P.evolutions, id)
            if okE and type(rows) == "table" then
              for _, evo in ipairs(rows) do
                local to = 0
                if type(evo) == "table" then
                  to = tonumber(evo.target or evo[3]) or 0
                end
                if to > 0 then
                  local s = prevosCache[to] or {}
                  s[#s + 1] = id
                  prevosCache[to] = s
                end
              end
            end
          else
            blank = blank + 1
          end
          id = id + 1
        end
      end
    end
    return prevosCache[species] or {}
  end
  local function lineSpecies(P, sp)
    local seen = { [sp] = true }
    local out = { sp }
    local queue = { sp }
    while #queue > 0 do
      local cur = table.remove(queue, 1)
      local nexts = {}
      for _, p in ipairs(prevosOf(P, cur)) do nexts[#nexts + 1] = p end
      if type(P.evolutions) == "function" then
        local ok, rows = pcall(P.evolutions, cur)
        if ok and type(rows) == "table" then
          for _, evo in ipairs(rows) do
            local to = 0
            if type(evo) == "table" then
              to = tonumber(evo.target or evo[3]) or 0
            end
            if to > 0 then nexts[#nexts + 1] = to end
          end
        end
      end
      for _, n in ipairs(nexts) do
        if not seen[n] then
          seen[n] = true
          out[#out + 1] = n
          queue[#queue + 1] = n
        end
      end
    end
    return out
  end
  local function pushMoveId(out, seen, moveId, level)
    local id = tonumber(moveId)
    if not id or id < 1 or seen[id] then return end
    local name = gen3MoveName(id)
    if not name or name == "" then return end
    seen[id] = true
    out[#out + 1] = { id = id, name = name, level = tonumber(level) }
  end
  local function staticPools(P, ML, sp)
    local pools = { tm = {}, egg = {}, tutor = {} }
    local seenT, seenE, seenU = {}, {}, {}
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
      for _, lineSp in ipairs(lineSpecies(P, sp)) do
        local ok, list = pcall(P.eggMoves, lineSp)
        if ok and type(list) == "table" then
          for _, id in ipairs(list) do
            pushMoveId(pools.egg, seenE, id, nil)
          end
        end
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
    return pools
  end
  local function nativeMovePools(mon)
    local empty = { relearn = {}, tm = {}, egg = {}, tutor = {} }
    local P = g3Pokemon()
    if not P then return empty end
    local sp = speciesNum(mon)
    if not sp then return empty end
    local level = 100
    if type(mon) == "table" then level = tonumber(mon.level) or 100 end
    local ML = moveLearnMod()
    local static = poolCache[sp]
    if not static then
      static = staticPools(P, ML, sp)
      poolCache[sp] = static
    end
    local pools = { relearn = {}, tm = static.tm, egg = static.egg,
      tutor = static.tutor }
    local seenR = {}
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
    return pools
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
  function Screen.new(game, mon, opts)
    local self = setmetatable({
      game = game, mon = mon,
      mode = "moves",
      category = 1, moveIndex = 1, moveList = {}, moveNote = nil,
      pending = nil, pickingSlot = false, slotIndex = 1,
      status = "", broken = false, lockedCategory = true,
    }, Screen)
    self:buildMoveList()
    if type(opts) == "table" and tonumber(opts.category) then
      self.category = clamp(tonumber(opts.category), 1, 4)
      self.moveIndex = 1
      self.lockedCategory = opts.locked and true or false
      self.pending = nil
      self.pickingSlot = false
      self:buildMoveList()
    end
    return self
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
    local showKnown = (self.category == 3)
    for _, e in ipairs(want) do
      if e.level == nil or e.level <= level then
        if showKnown or not known[e.id] then
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
    do
      local Pk = g3Pokemon()
      for i = 1, 4 do
        local id = nil
        if Pk and type(Pk.moveIdAt) == "function" then
          local ok, v = pcall(Pk.moveIdAt, mon, i)
          if ok then id = tonumber(v) end
        elseif mon and type(mon.moves) == "table" then
          local m = mon.moves[i]
          if type(m) == "number" then id = m
          elseif type(m) == "table" then
            id = tonumber(m.id or m.move or m.moveId)
          end
        end
        if id == moveId then
          self.pending = nil
          self.pickingSlot = false
          self.status = "ALREADY KNOWN"
          return
        end
      end
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
  function Screen:updateMoves(input)
    local function pressed(k)
      return input and type(input.wasPressed) == "function"
        and input:wasPressed(k)
    end
    if pressed("left") then
      if self.lockedCategory then return end
      self.category = ((self.category - 2) % 4) + 1
      self.moveIndex = 1
      self:buildMoveList()
      return
    end
    if pressed("right") then
      if self.lockedCategory then return end
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
      if self.lockedCategory then
        self.game.stack:pop()
        return
      end
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
      self:updateMoves(input)
    end)
    if not ok then
      self.broken = true
      pcall(mod.log.warn, mod.log, "pokemon-trainer: move tutor update failed: %s",
        tostring(err))
    end
    self.game.input = nil
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
              "pokemon-trainer: move tutor draw section '%s' failed: %s",
              tostring(name), tostring(errP))
          end
        end
        part("moves", function() self:drawMovesPage() end)
      end)
      G.pop()
      G.setColor(1, 1, 1, 1)
      if not okInner then error(errInner, 0) end
    end)
    if not ok then
      pcall(mod.log.warn, mod.log, "pokemon-trainer: move tutor draw failed: %s",
        tostring(err))
    end
  end
  if isGen3Boot then
    local okPM, PM = pcall(require, "src.ui.game3.party_menu")
    local okStack, Stack3 = pcall(require, "src.ui.game3.stack")
    if okPM and type(PM) == "table" and okStack and type(Stack3) == "table"
        and not PM.__ptMoveTutorWrapped then
      PM.__ptMoveTutorWrapped = true
      if not Frlg then
        mod.log:warn("pokemon-trainer: TUTOR/EGG MOVE not injected -- no gen3 font")
      else
      local layers = {}
      local function moveLayer(stackId)
        if layers[stackId] then return layers[stackId] end
        local ref = {}
        local T = {}
        T.open = false
        function T.isOpen() return T.open end
        function T.update(dt)
          local scr = ref.current
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
            ref.current = nil
            T.open = false
            pcall(Stack3.pop, stackId)
          end
        end
        function T.draw()
          local scr = ref.current
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
        function T.handleInput(input)
          if not input then return end
          local scr = ref.current
          if not scr then
            T.open = false
            pcall(Stack3.pop, stackId)
            return
          end
          scr.game.input = input
          scr:update(0)
          scr.game.input = nil
          if scr.broken then
            ref.current = nil
            T.open = false
            pcall(Stack3.pop, stackId)
          end
        end
        function T.close()
          ref.current = nil
          T.open = false
          pcall(Stack3.pop, stackId)
        end
        layers[stackId] = { layer = T, ref = ref }
        return layers[stackId]
      end
      local function tutorAllowedSession()
        local okP, Profile = pcall(require, "src.core.game3.profile")
        if not (okP and type(Profile) == "table"
            and type(Profile.family) == "function") then return true end
        local okF, fam = pcall(Profile.family, PM._session)
        if not okF then return true end
        if fam == nil then return true end
        return fam == "frlg" or fam == "rse" or fam == "emerald"
      end
      local function openGen3Moves(mon, category, stackId, lockCat)
        if type(mon) ~= "table" or mon.isEgg then return end
        gen3Session = PM._session
        local fakeGame = { data = nil, input = nil, stack = {} }
        fakeGame.stack.pop = function()
          local L = layers[stackId]
          if L then
            L.ref.current = nil
            L.layer.open = false
          end
          pcall(Stack3.pop, stackId)
        end
        fakeGame.stack.push = function() end
        local ok, scr = pcall(Screen.new, fakeGame, mon,
          { category = category, locked = lockCat })
        if not (ok and scr) then
          mod.log:warn("pokemon-trainer: move screen failed to open (%s)",
            tostring(scr))
          return
        end
        scr.game.input = { wasPressed = function() return false end,
          isDown = function() return false end }
        local okUp = pcall(scr.update, scr, 0)
        scr.game.input = nil
        if not (okUp and not scr.broken) then
          mod.log:warn("pokemon-trainer: move screen failed its open "
            .. "self-test, not pushing")
          return
        end
        local okDrawSelf = pcall(scr.draw, scr)
        if not (okDrawSelf and not scr.broken) then
          mod.log:warn("pokemon-trainer: move screen failed its draw "
            .. "self-test, not pushing")
          return
        end
        local L = moveLayer(stackId)
        L.ref.current = scr
        L.layer.open = true
        local okPush = pcall(Stack3.push, stackId, L.layer,
          { hideBelow = true, fullscreen = true })
        if not okPush then
          L.ref.current = nil
          L.layer.open = false
          mod.log:warn("pokemon-trainer: move screen failed to push")
        end
      end
      if not PM.__ptMoveTutorHandleWrapped then
        PM.__ptMoveTutorHandleWrapped = true
        local function syncTexts(list)
          local texts = {}
          for i = 1, #list do
            local act = list[i]
            if act == "TUTOR" or act == "EGG MOVE" then
              texts[i] = act
            else
              local ok, v = pcall(PM._cursorOptionText, act)
              texts[i] = (ok and v ~= nil) and v or act
            end
          end
          PM._actionTexts = { list = list, texts = texts }
        end
        local function moveRowWanted(list)
          if not tutorAllowedSession() then return false end
          if PM._previousMode == "battle_switch" then return false end
          if PM._battle then return false end
          local mon = PM._party and PM._party[PM.cursor]
          if type(mon) == "table" and mon.isEgg then return false end
          local hasSummary, hasCancel = false, false
          for i = 1, #list do
            local act = list[i]
            if type(act) ~= "string" then return false end
            if act == "SHIFT" or act == "SEND OUT" or act == "ENTER"
                or act == "NO ENTRY" then
              return false
            end
            if act == "SUMMARY" then hasSummary = true end
            if act == "CANCEL" then hasCancel = true end
          end
          return hasSummary and hasCancel
        end
        local function movePoolsFor(mon)
          if type(mon) ~= "table" or mon.isEgg then return nil end
          local ok, pools = pcall(nativeMovePools, mon)
          if ok and type(pools) == "table" then return pools end
          return nil
        end
        local function syncMoveRows()
          local list = PM.ACTIONS
          if type(list) ~= "table" then return end
          local mon = PM._party and PM._party[PM.cursor]
          local pools = movePoolsFor(mon)
          local wantTutor = moveRowWanted(list)
            and pools ~= nil and type(pools.tutor) == "table"
            and #pools.tutor > 0
          local wantEgg = moveRowWanted(list)
            and pools ~= nil and type(pools.egg) == "table"
            and #pools.egg > 0
          for _, row in ipairs({ "TUTOR", "EGG MOVE" }) do
            local at = nil
            for i = 1, #list do
              if list[i] == row then
                at = i
                break
              end
            end
            local want = (row == "TUTOR" and wantTutor)
              or (row == "EGG MOVE" and wantEgg)
            if want then
              if at == nil then
                local pos = #list + 1
                for i = 1, #list do
                  if list[i] == "CANCEL" then
                    pos = i
                    break
                  end
                end
                table.insert(list, pos, row)
                syncTexts(list)
              end
            elseif at ~= nil then
              table.remove(list, at)
              syncTexts(list)
              local cur = PM.actionCursor or 1
              if cur > #list then cur = #list end
              if cur < 1 then cur = 1 end
              PM.actionCursor = cur
            end
          end
        end
        local function tryTutorSelect(input)
          if PM.mode ~= "action" then return false end
          if not (input and input.wasPressed) then return false end
          if not input:wasPressed("a") then return false end
          local list = PM.ACTIONS
          if type(list) ~= "table" then return false end
          local row = list[PM.actionCursor or 1]
          if row ~= "TUTOR" and row ~= "EGG MOVE" then
            return false
          end
          local mon = PM._party and PM._party[PM.cursor]
          if type(mon) ~= "table" or mon.isEgg then return false end
          pcall(function()
            require("src.core.game3.audio").playSe("SE_SELECT")
          end)
          PM.mode = PM._previousMode or "list"
          if row == "TUTOR" then
            openGen3Moves(mon, 4, "pttutor", true)
          else
            openGen3Moves(mon, 3, "pteggmove", true)
          end
          return true
        end
        local origInput = PM.handleInput
        if type(origInput) == "function" then
          PM.handleInput = function(input, ...)
            local before = PM.mode
            if before == "action" then
              local okC, consumed = pcall(tryTutorSelect, input)
              if okC and consumed then return end
            end
            local r = { origInput(input, ...) }
            if before == "list" and PM.mode == "action" then
              pcall(syncMoveRows)
            end
            return (table.unpack or unpack)(r)
          end
        end
      end
      end
    end
  end
  mod.log:info("pokemon-trainer: move tutor installed (Gen %d)", gen)
end
